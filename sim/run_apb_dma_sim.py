#!/usr/bin/env python3

import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_DIR = REPO_ROOT / "build" / "sim" / "apb_dma"
SUMMARY_PATH = BUILD_DIR / "sim_summary.json"

TEST_NAMES = (
    "dma_desc_identity",
    "dma_desc_mixed_signed",
    "dma_desc_back_to_back",
    "dma_desc_start_while_busy",
    "dma_desc_invalid_access",
    "dma_desc_external_memory_unchanged",
)

DESCRIPTOR_REGISTERS = (
    "DMA_CTRL",
    "DMA_STATUS",
    "DMA_A_EXT_BASE",
    "DMA_B_EXT_BASE",
    "DMA_C_EXT_BASE",
    "DMA_CONFIG",
)


def run(cmd, capture=False):
    print("+ " + " ".join(str(part) for part in cmd), flush=True)
    if capture:
        return subprocess.run(cmd, cwd=REPO_ROOT, text=True, capture_output=True)
    return subprocess.run(cmd, cwd=REPO_ROOT)


def write_summary(status, tests_passed=0, passed_names=None, notes=None):
    summary = {
        "status": status,
        "top": "tinynpu_apb_wrapper",
        "testbench": "tb_tinynpu_apb_dma_model",
        "mac_variant": "row4",
        "dma_model": True,
        "descriptor_model": True,
        "tests_passed": tests_passed,
        "test_names": list(passed_names or []),
        "descriptor_registers": list(DESCRIPTOR_REGISTERS),
        "notes": notes or "Descriptor registers are simulation-only; no synthesizable DMA RTL",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    SUMMARY_PATH.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return summary


def parse_passed_tests(stdout):
    passed = []
    for name in TEST_NAMES:
        if f"PASS {name}" in stdout:
            passed.append(name)
    return passed


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
    sim_out = BUILD_DIR / "tinynpu_apb_dma_model.vvp"

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
        "tb/tb_tinynpu_apb_dma_model.sv",
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
            f"ERROR: APB DMA-model simulation status={status}, "
            f"passed {len(passed_names)}/{len(TEST_NAMES)} named tests",
            file=sys.stderr,
        )
        return sim_result.returncode if sim_result.returncode != 0 else 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
