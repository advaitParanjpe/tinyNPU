#!/usr/bin/env python3

import shutil
import subprocess
import sys
import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_DIR = REPO_ROOT / "build"
SIM_BUILD_DIR = BUILD_DIR / "sim"
LATEST_SIM_SUMMARY = SIM_BUILD_DIR / "sim_summary.json"
JSON_VECTORS = REPO_ROOT / "tests" / "test_vectors" / "generated_matmul_tests.json"
SVH_VECTORS = REPO_ROOT / "tests" / "test_vectors" / "generated_matmul_tests.svh"


def run(cmd):
    print("+ " + " ".join(str(part) for part in cmd), flush=True)
    result = subprocess.run(cmd, cwd=REPO_ROOT)
    if result.returncode != 0:
        return result.returncode
    return 0


def run_capture(cmd):
    print("+ " + " ".join(str(part) for part in cmd), flush=True)
    result = subprocess.run(cmd, cwd=REPO_ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout, end="")
    return result.returncode, result.stdout


def write_sim_summary(output, returncode, seed, num_random_tests, mac_variant, summary_path):
    summary_path.parent.mkdir(parents=True, exist_ok=True)

    def match_int(pattern):
        match = re.search(pattern, output)
        return int(match.group(1)) if match else None

    status = "passed" if returncode == 0 and "tinyNPU SIM PASS" in output else "failed"
    summary = {
        "status": status,
        "directed_tests_passed": match_int(r"Directed tests passed:\s+(\d+)"),
        "generated_random_tests_passed": match_int(r"Generated random tests passed:\s+(\d+)"),
        "max_observed_latency_cycles": match_int(r"Max observed latency:\s+(\d+) cycles"),
        "assertions_enabled": "Assertions/checkers: enabled" in output,
        "mac_variant": mac_variant,
        "seed": seed,
        "num_random_tests": num_random_tests,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    missing = [key for key in ("directed_tests_passed", "generated_random_tests_passed", "max_observed_latency_cycles") if summary[key] is None]
    if status == "passed" and missing:
        summary["status"] = "parse_failed"
        summary["parse_error"] = "Missing summary fields: " + ", ".join(missing)

    summary_text = json.dumps(summary, indent=2) + "\n"
    summary_path.write_text(summary_text)
    LATEST_SIM_SUMMARY.write_text(summary_text)
    print(f"Wrote simulation summary to {summary_path.relative_to(REPO_ROOT)}")
    return summary


def parse_args():
    parser = argparse.ArgumentParser(description="Compile and run tinyNPU simulation")
    parser.add_argument("--num-random-tests", type=int, default=50)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--mac-variant", choices=("row4", "serial", "full16"), default="row4")
    return parser.parse_args()


def main():
    args = parse_args()

    iverilog = shutil.which("iverilog")
    vvp = shutil.which("vvp")
    if not iverilog:
        print("ERROR: iverilog not found in PATH", file=sys.stderr)
        return 1
    if not vvp:
        print("ERROR: vvp not found in PATH", file=sys.stderr)
        return 1

    BUILD_DIR.mkdir(exist_ok=True)
    variant_build_dir = SIM_BUILD_DIR / args.mac_variant
    variant_build_dir.mkdir(parents=True, exist_ok=True)
    LATEST_SIM_SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    sim_out = variant_build_dir / "tinynpu_top.vvp"
    sim_summary = variant_build_dir / "sim_summary.json"

    vector_cmd = [
        sys.executable,
        "model/golden_matmul.py",
        "--generate-json",
        "--generate-svh",
        "--num-tests",
        str(args.num_random_tests),
        "--seed",
        str(args.seed),
        "--out",
        str(JSON_VECTORS),
        "--svh-out",
        str(SVH_VECTORS),
    ]
    rc = run(vector_cmd)
    if rc != 0:
        return rc

    sources = [
        "rtl/tinynpu_pkg.sv",
        "rtl/tinynpu_assertions.sv",
        "rtl/tinynpu_mac_serial.sv",
        "rtl/tinynpu_mac_row4.sv",
        "rtl/tinynpu_mac_full16.sv",
        "rtl/tinynpu_mac_array.sv",
        "rtl/tinynpu_top.sv",
        "tb/tb_tinynpu_top.sv",
    ]

    compile_cmd = [
        iverilog,
        "-g2012",
        "-Wall",
        "-DTINYNPU_SIM_ASSERT",
        "-I",
        ".",
        "-o",
        str(sim_out),
    ]
    if args.mac_variant == "serial":
        compile_cmd.append("-DTINYNPU_MAC_SERIAL")
    elif args.mac_variant == "full16":
        compile_cmd.append("-DTINYNPU_MAC_FULL16")
    compile_cmd.extend(sources)
    rc = run(compile_cmd)
    if rc != 0:
        return rc

    rc, output = run_capture([vvp, str(sim_out)])
    summary = write_sim_summary(output, rc, args.seed, args.num_random_tests, args.mac_variant, sim_summary)
    if summary["status"] == "parse_failed":
        print("ERROR: failed to parse simulation summary", file=sys.stderr)
        return 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
