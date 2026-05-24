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

FUNCTIONAL_TESTS = (
    "identity",
    "all_zeros",
    "all_ones",
    "mixed_signed",
    "max_positive",
    "min_negative_times_positive",
    "alternating_extremes",
    "sparse_single_nonzero",
)

CONTROL_STATUS_TESTS = {
    "back_to_back": ("back_to_back_first", "back_to_back_second"),
    "start_while_busy": ("start_while_busy",),
    "done_sticky_clear": ("done_sticky_clear",),
    "new_start_after_done": ("new_start_after_done",),
    "reset_mid_operation": ("reset_mid_operation",),
}

BUS_TESTS = ("invalid_bus_access",)

ASSERTION_CHECKS = (
    "busy_done_mutex",
    "busy_start_not_accepted",
    "done_bounded_after_start",
    "reset_clears_status",
    "c_stable_while_done",
)

KNOWN_COVERAGE_GAPS = (
    "No AXI/APB protocol coverage yet",
    "No SRAM macro or memory timing coverage yet",
    "No formal proof yet",
    "Only fixed 4x4 matrix size currently tested",
)


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


def passed_test_names(output):
    return set(re.findall(r"^PASS\s+([A-Za-z0-9_]+)", output, re.MULTILINE))


def write_coverage_summary(output, sim_status, seed, num_random_tests, mac_variant, coverage_path):
    coverage_path.parent.mkdir(parents=True, exist_ok=True)
    passed = passed_test_names(output)
    assertions_enabled = "Assertions/checkers: enabled" in output
    sim_passed = sim_status == "passed"

    functional = {name: name in passed for name in FUNCTIONAL_TESTS}
    control_status = {
        name: all(pass_name in passed for pass_name in pass_names)
        for name, pass_names in CONTROL_STATUS_TESTS.items()
    }
    bus = {name: name in passed for name in BUS_TESTS}
    assertions = {
        name: bool(assertions_enabled and sim_passed)
        for name in ASSERTION_CHECKS
    }

    generated_count_match = re.search(r"Generated random tests passed:\s+(\d+)", output)
    generated_passed = int(generated_count_match.group(1)) if generated_count_match else 0
    random_enabled = generated_passed == num_random_tests and num_random_tests > 0

    all_covered = (
        all(functional.values())
        and all(control_status.values())
        and all(bus.values())
        and random_enabled
        and all(assertions.values())
    )
    status = "passed" if sim_passed and all_covered else "failed"

    coverage = {
        "status": status,
        "mac_variant": mac_variant,
        "functional_tests": functional,
        "control_status_tests": control_status,
        "bus_tests": bus,
        "random_tests": {
            "enabled": random_enabled,
            "num_tests": num_random_tests,
            "seed": seed,
        },
        "assertions": {
            "enabled": assertions_enabled,
            **assertions,
        },
        "known_gaps": list(KNOWN_COVERAGE_GAPS),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    coverage_path.write_text(json.dumps(coverage, indent=2) + "\n")
    print(f"Wrote coverage summary to {coverage_path.relative_to(REPO_ROOT)}")
    return coverage


def write_sim_summary(output, returncode, seed, num_random_tests, mac_variant, summary_path, coverage_path):
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
        "coverage_summary_path": str(coverage_path.relative_to(REPO_ROOT)),
        "coverage_categories_passed": None,
        "coverage_known_gaps_count": len(KNOWN_COVERAGE_GAPS),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    missing = [key for key in ("directed_tests_passed", "generated_random_tests_passed", "max_observed_latency_cycles") if summary[key] is None]
    if status == "passed" and missing:
        summary["status"] = "parse_failed"
        summary["parse_error"] = "Missing summary fields: " + ", ".join(missing)

    coverage = write_coverage_summary(output, summary["status"], seed, num_random_tests, mac_variant, coverage_path)
    categories = (
        coverage["functional_tests"],
        coverage["control_status_tests"],
        coverage["bus_tests"],
        coverage["assertions"],
    )
    summary["coverage_categories_passed"] = sum(
        1 for category in categories if all(value for key, value in category.items() if key != "enabled")
    )
    if coverage["random_tests"]["enabled"]:
        summary["coverage_categories_passed"] += 1

    if summary["status"] == "passed" and coverage["status"] != "passed":
        summary["status"] = "coverage_failed"

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
    coverage_summary = variant_build_dir / "coverage_summary.json"

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
    summary = write_sim_summary(output, rc, args.seed, args.num_random_tests, args.mac_variant, sim_summary, coverage_summary)
    if summary["status"] == "parse_failed":
        print("ERROR: failed to parse simulation summary", file=sys.stderr)
        return 1
    if summary["status"] == "coverage_failed":
        print("ERROR: coverage summary did not pass", file=sys.stderr)
        return 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
