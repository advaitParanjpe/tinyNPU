#!/usr/bin/env python3

import argparse
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def run(cmd):
    print("+ " + " ".join(str(part) for part in cmd), flush=True)
    return subprocess.run(cmd, cwd=REPO_ROOT)


def run_capture(cmd):
    print("+ " + " ".join(str(part) for part in cmd), flush=True)
    result = subprocess.run(cmd, cwd=REPO_ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout, end="")
    return result.returncode, result.stdout


def metric(output, name):
    match = re.search(rf"^METRIC {name}=([0-9]+)$", output, re.MULTILINE)
    return int(match.group(1)) if match else None


def parse_args():
    parser = argparse.ArgumentParser(description="Compile and run the double-buffered streaming NPU simulation")
    parser.add_argument("--mac-variant", choices=("row4_pipe2", "systolic4x4"), default="row4_pipe2")
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

    build_name = (
        "axis_stream_npu"
        if args.mac_variant == "row4_pipe2"
        else f"axis_stream_npu_{args.mac_variant}"
    )
    build_dir = REPO_ROOT / "build" / "sim" / build_name
    summary_path = build_dir / "sim_summary.json"
    build_dir.mkdir(parents=True, exist_ok=True)
    sim_out = build_dir / "tinynpu_axis_stream_npu.vvp"

    sources = [
        "rtl/tinynpu_mac_row4_pipe2.sv",
        "rtl/tinynpu_mac_systolic4x4.sv",
        "rtl/tinynpu_axis_stream_npu.sv",
        "tb/tb_tinynpu_axis_stream_npu.sv",
    ]

    compile_cmd = [
        iverilog,
        "-g2012",
        "-Wall",
        "-I",
        ".",
        "-I",
        "rtl",
        "-o",
        str(sim_out),
    ]
    if args.mac_variant == "systolic4x4":
        compile_cmd.append("-DTINYNPU_MAC_SYSTOLIC4X4")
    compile_cmd.extend(sources)
    rc = run(compile_cmd).returncode
    if rc != 0:
        return rc

    rc, output = run_capture([vvp, str(sim_out)])
    status = "passed" if rc == 0 and "tinyNPU AXIS STREAM NPU SIM PASS" in output else "failed"
    tests_match = re.search(r"^AXIS stream NPU tests passed:\s+([0-9]+)$", output, re.MULTILINE)
    summary = {
        "status": status,
        "tests_passed": int(tests_match.group(1)) if tests_match else None,
        "interface": "AXI4-Stream subset: tvalid/tready/tdata/tlast",
        "mac_variant": args.mac_variant,
        "architecture": (
            "double-buffered input A/B tiles, one "
            f"{args.mac_variant} compute engine, double-buffered C output tiles"
        ),
        "single_tile_latency_cycles": metric(output, "single_tile_latency_cycles"),
        "steady_state_cycles_per_tile": metric(output, "steady_state_cycles_per_tile"),
        "max_input_acceptance_cycles_per_tile": metric(output, "max_input_acceptance_cycles_per_tile"),
        "load_compute_output_overlap_observed": bool(metric(output, "load_compute_output_overlap_observed")),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    summary_path.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Wrote AXIS stream NPU simulation summary to {summary_path.relative_to(REPO_ROOT)}")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
