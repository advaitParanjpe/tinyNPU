#!/usr/bin/env python3

import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_DIR = REPO_ROOT / "build" / "sim" / "axis_stream"
SUMMARY_PATH = BUILD_DIR / "sim_summary.json"


def run(cmd):
    print("+ " + " ".join(str(part) for part in cmd), flush=True)
    return subprocess.run(cmd, cwd=REPO_ROOT)


def run_capture(cmd):
    print("+ " + " ".join(str(part) for part in cmd), flush=True)
    result = subprocess.run(cmd, cwd=REPO_ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout, end="")
    return result.returncode, result.stdout


def main():
    iverilog = shutil.which("iverilog")
    vvp = shutil.which("vvp")
    if not iverilog:
      print("ERROR: iverilog not found in PATH", file=sys.stderr)
      return 1
    if not vvp:
      print("ERROR: vvp not found in PATH", file=sys.stderr)
      return 1

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    sim_out = BUILD_DIR / "tinynpu_axis_stream_tile_core.vvp"

    sources = [
        "rtl/tinynpu_mac_row4_pipe2.sv",
        "rtl/tinynpu_axis_stream_tile_core.sv",
        "tb/tb_tinynpu_axis_stream_tile_core.sv",
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
        *sources,
    ]
    rc = run(compile_cmd).returncode
    if rc != 0:
        return rc

    rc, output = run_capture([vvp, str(sim_out)])
    status = "passed" if rc == 0 and "tinyNPU AXIS STREAM SIM PASS" in output else "failed"
    summary = {
        "status": status,
        "tests_passed": None,
        "interface": "AXI4-Stream subset: tvalid/tready/tdata/tlast",
        "input_packet": "16 int8 A values followed by 16 int8 B values, row-major, tlast on final B beat",
        "output_packet": "16 int32 C values, row-major, tlast on final C beat",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    for line in output.splitlines():
        if line.startswith("AXIS stream tests passed:"):
            summary["tests_passed"] = int(line.split(":", 1)[1].strip())
    SUMMARY_PATH.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Wrote AXIS stream simulation summary to {SUMMARY_PATH.relative_to(REPO_ROOT)}")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
