#!/usr/bin/env python3

import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_DIR = REPO_ROOT / "build" / "sim" / "axi_read_dma"
SUMMARY_PATH = BUILD_DIR / "sim_summary.json"

TEST_NAMES = (
    "axi_read_dma_identity",
    "axi_read_dma_mixed_signed",
    "axi_read_dma_ar_backpressure",
    "axi_read_dma_rvalid_delay",
    "axi_read_dma_rresp_error",
    "axi_read_dma_timeout",
    "axi_read_dma_irq_done",
)


def run(cmd, capture=False):
    print("+ " + " ".join(str(part) for part in cmd), flush=True)
    if capture:
        return subprocess.run(cmd, cwd=REPO_ROOT, text=True, capture_output=True)
    return subprocess.run(cmd, cwd=REPO_ROOT)


def parse_passed_tests(stdout):
    return [name for name in TEST_NAMES if f"PASS {name}" in stdout]


def write_summary(status, tests_passed=0, passed_names=None, notes=None):
    names = list(passed_names or [])
    summary = {
        "status": status,
        "top": "tinynpu_axi_read_dma_wrapper",
        "testbench": "tb_tinynpu_axi_read_dma_wrapper",
        "mac_variant": "row4",
        "axi_lite_control": True,
        "axi_read_master": True,
        "axi_write_master": False,
        "bursts_supported": False,
        "abstract_c_write_port": True,
        "tests_passed": tests_passed,
        "test_names": names,
        "axi_read_backpressure_verified": (
            "axi_read_dma_ar_backpressure" in names
            and "axi_read_dma_rvalid_delay" in names
        ),
        "axi_rresp_error_verified": "axi_read_dma_rresp_error" in names,
        "timeout_verified": "axi_read_dma_timeout" in names,
        "irq_verified": "axi_read_dma_irq_done" in names,
        "notes": notes
        or "AXI4-Lite control plus single-beat AXI4 read master for A/B; C store uses abstract write port",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    SUMMARY_PATH.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return summary


def main():
    iverilog = shutil.which("iverilog")
    vvp = shutil.which("vvp")
    if not iverilog:
        print("ERROR: iverilog not found in PATH", file=sys.stderr)
        write_summary("failed", notes="iverilog not found in PATH")
        return 1
    if not vvp:
        print("ERROR: vvp not found in PATH", file=sys.stderr)
        write_summary("failed", notes="vvp not found in PATH")
        return 1

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    sim_out = BUILD_DIR / "tinynpu_axi_read_dma_wrapper.vvp"
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
        "rtl/tinynpu_axi_read_dma_wrapper.sv",
        "tb/tb_tinynpu_axi_read_dma_wrapper.sv",
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

    compile_result = run(compile_cmd)
    if compile_result.returncode != 0:
        write_summary("failed", notes="compile failed")
        return compile_result.returncode

    sim_result = run([vvp, str(sim_out)], capture=True)
    if sim_result.stdout:
        print(sim_result.stdout, end="")
    if sim_result.stderr:
        print(sim_result.stderr, end="", file=sys.stderr)

    passed_names = parse_passed_tests(sim_result.stdout)
    status = "passed" if sim_result.returncode == 0 and len(passed_names) == len(TEST_NAMES) else "failed"
    write_summary(status, len(passed_names), passed_names)
    if status != "passed":
        print(
            f"ERROR: AXI read-DMA simulation status={status}, "
            f"passed {len(passed_names)}/{len(TEST_NAMES)} named tests",
            file=sys.stderr,
        )
        return sim_result.returncode if sim_result.returncode != 0 else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
