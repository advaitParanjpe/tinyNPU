#!/usr/bin/env python3

import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_DIR = REPO_ROOT / "build" / "sim" / "apb"


def run(cmd):
    print("+ " + " ".join(str(part) for part in cmd), flush=True)
    result = subprocess.run(cmd, cwd=REPO_ROOT)
    return result.returncode


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
    sim_out = BUILD_DIR / "tinynpu_apb_wrapper.vvp"

    sources = [
        "rtl/tinynpu_pkg.sv",
        "rtl/tinynpu_assertions.sv",
        "rtl/tinynpu_mac_serial.sv",
        "rtl/tinynpu_mac_row4.sv",
        "rtl/tinynpu_mac_full16.sv",
        "rtl/tinynpu_mac_array.sv",
        "rtl/tinynpu_scratchpad_i8.sv",
        "rtl/tinynpu_result_buffer_i32.sv",
        "rtl/tinynpu_top.sv",
        "rtl/tinynpu_apb_wrapper.sv",
        "tb/tb_tinynpu_apb_wrapper.sv",
    ]

    compile_cmd = [
        iverilog,
        "-g2012",
        "-Wall",
        "-DTINYNPU_SIM_ASSERT",
        "-I",
        ".",
        "-I",
        "rtl",
        "-o",
        str(sim_out),
    ]
    compile_cmd.extend(sources)

    rc = run(compile_cmd)
    if rc != 0:
        return rc

    return run([vvp, str(sim_out)])


if __name__ == "__main__":
    sys.exit(main())
