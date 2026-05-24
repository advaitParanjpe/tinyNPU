#!/usr/bin/env python3

import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_DIR = REPO_ROOT / "build" / "sim" / "dma_desc_wrapper"
SUMMARY_PATH = BUILD_DIR / "sim_summary.json"

TEST_NAMES = (
    "desc_regs_read_write",
    "desc_fsm_start_done",
    "desc_start_while_busy",
    "desc_invalid_access",
    "forwarded_core_identity",
    "forwarded_core_invalid_unaligned",
    "desc_dma_identity",
    "desc_dma_mixed_signed",
    "desc_dma_back_to_back",
    "desc_dma_core_window_blocked_while_busy",
    "desc_dma_memory_unchanged",
    "desc_dma_fixed_latency_identity",
    "desc_dma_fixed_latency_mixed_signed",
    "desc_dma_random_backpressure_identity",
    "desc_dma_random_backpressure_back_to_back",
    "desc_dma_mem_protocol_stability",
)

FSM_STATES = (
    "IDLE",
    "LOAD_A",
    "LOAD_B",
    "START_CORE",
    "WAIT_CORE",
    "STORE_C",
    "DONE",
)


def run(cmd, capture=False):
    print("+ " + " ".join(str(part) for part in cmd), flush=True)
    if capture:
        return subprocess.run(cmd, cwd=REPO_ROOT, text=True, capture_output=True)
    return subprocess.run(cmd, cwd=REPO_ROOT)


def write_summary(status, tests_passed=0, passed_names=None, sim_stdout="", notes=None):
    summary = {
        "status": status,
        "top": "tinynpu_dma_descriptor_wrapper",
        "testbench": "tb_tinynpu_dma_descriptor_wrapper",
        "mac_variant": "row4",
        "descriptor_registers_synthesizable": True,
        "dma_fsm": True,
        "abstract_memory_port": True,
        "real_dma_rtl": True,
        "real_memory_movement": True,
        "axi": False,
        "fsm_states": list(FSM_STATES),
        "core_launch_verified": "desc_dma_identity" in (passed_names or []),
        "memory_movement_verified": (
            "desc_dma_identity" in (passed_names or [])
            and "desc_dma_mixed_signed" in (passed_names or [])
        ),
        "memory_backpressure_verified": (
            "desc_dma_fixed_latency_identity" in (passed_names or [])
            and "desc_dma_random_backpressure_identity" in (passed_names or [])
        ),
        "fixed_latency_tests": sum(
            1 for name in (passed_names or []) if name.startswith("desc_dma_fixed_latency")
        ),
        "random_backpressure_tests": sum(
            1 for name in (passed_names or []) if name.startswith("desc_dma_random_backpressure")
        ),
        "protocol_stability_checked": "desc_dma_mem_protocol_stability" in (passed_names or []),
        "stalled_transactions_observed": "desc_dma_mem_protocol_stability" in (passed_names or []),
        "mem_port_assertions_enabled": "Memory-port assertions: enabled" in sim_stdout,
        "tests_passed": tests_passed,
        "test_names": list(passed_names or []),
        "notes": notes or "Uses simple abstract ready/valid memory port; not AXI",
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
    sim_out = BUILD_DIR / "tinynpu_dma_descriptor_wrapper.vvp"

    sources = [
        "rtl/tinynpu_pkg.sv",
        "rtl/tinynpu_assertions.sv",
        "rtl/tinynpu_mem_port_assertions.sv",
        "rtl/tinynpu_mac_serial.sv",
        "rtl/tinynpu_mac_row4.sv",
        "rtl/tinynpu_mac_full16.sv",
        "rtl/tinynpu_mac_array.sv",
        "rtl/tinynpu_scratchpad_i8.sv",
        "rtl/tinynpu_result_buffer_i32.sv",
        "rtl/tinynpu_top.sv",
        "rtl/tinynpu_apb_wrapper.sv",
        "rtl/tinynpu_dma_descriptor_wrapper.sv",
        "tb/tb_tinynpu_dma_descriptor_wrapper.sv",
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
    write_summary(status, len(passed_names), passed_names, sim_stdout=sim_result.stdout)

    if status != "passed":
        print(
            f"ERROR: DMA descriptor-wrapper simulation status={status}, "
            f"passed {len(passed_names)}/{len(TEST_NAMES)} named tests",
            file=sys.stderr,
        )
        return sim_result.returncode if sim_result.returncode != 0 else 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
