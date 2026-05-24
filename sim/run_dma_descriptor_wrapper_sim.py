#!/usr/bin/env python3

import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILD_DIR = REPO_ROOT / "build" / "sim" / "dma_desc_wrapper"
SUMMARY_PATH = BUILD_DIR / "sim_summary.json"
PERF_SUMMARY_PATH = BUILD_DIR / "perf_summary.json"

PERF_RE = re.compile(
    r"^PERF mode=(?P<mode>\S+) test=(?P<test>\S+) total=(?P<total>\d+) "
    r"load_a=(?P<load_a>\d+) load_b=(?P<load_b>\d+) "
    r"start_core=(?P<start_core>\d+) wait_core=(?P<wait_core>\d+) "
    r"store_c=(?P<store_c>\d+)$"
)

MEMORY_MODES = ("always_ready", "fixed_latency", "random_backpressure")

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
    "desc_irq_disabled_no_assert",
    "desc_irq_done_assert_clear",
    "desc_irq_enable_after_done",
    "desc_dma_mem_timeout",
    "desc_dma_error_irq_assert_clear",
    "desc_dma_start_blocked_while_error",
    "desc_dma_recover_after_mem_timeout",
    "desc_dma_core_timeout",
    "desc_dma_recover_after_core_timeout",
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


def write_summary(status, tests_passed=0, passed_names=None, sim_stdout="", perf_summary=None, notes=None):
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
        "performance_reporting_enabled": perf_summary is not None,
        "perf_summary_path": str(PERF_SUMMARY_PATH.relative_to(REPO_ROOT)) if perf_summary is not None else None,
        "irq_supported": True,
        "irq_tests_passed": sum(1 for name in (passed_names or []) if name.startswith("desc_irq_")),
        "irq_done_verified": (
            "desc_irq_done_assert_clear" in (passed_names or [])
            and "desc_irq_enable_after_done" in (passed_names or [])
        ),
        "irq_error_verified": "desc_dma_error_irq_assert_clear" in (passed_names or []),
        "timeout_error_handling_verified": (
            "desc_dma_mem_timeout" in (passed_names or [])
            and "desc_dma_core_timeout" in (passed_names or [])
        ),
        "memory_timeout_verified": "desc_dma_mem_timeout" in (passed_names or []),
        "core_timeout_verified": "desc_dma_core_timeout" in (passed_names or []),
        "recovery_after_timeout_verified": (
            "desc_dma_recover_after_mem_timeout" in (passed_names or [])
            and "desc_dma_recover_after_core_timeout" in (passed_names or [])
        ),
        "error_irq_verified": "desc_dma_error_irq_assert_clear" in (passed_names or []),
        "error_code_register_verified": (
            "desc_dma_mem_timeout" in (passed_names or [])
            and "desc_dma_core_timeout" in (passed_names or [])
        ),
        "tests_passed": tests_passed,
        "test_names": list(passed_names or []),
        "notes": notes or "Uses simple abstract ready/valid memory port; not AXI",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    SUMMARY_PATH.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return summary


def parse_perf(stdout):
    entries = []
    for line in stdout.splitlines():
        match = PERF_RE.match(line.strip())
        if not match:
            continue
        entry = {
            "mode": match.group("mode"),
            "test": match.group("test"),
            "total_cycles": int(match.group("total")),
            "load_a_cycles": int(match.group("load_a")),
            "load_b_cycles": int(match.group("load_b")),
            "start_core_cycles": int(match.group("start_core")),
            "wait_core_cycles": int(match.group("wait_core")),
            "store_c_cycles": int(match.group("store_c")),
        }
        entries.append(entry)
    return entries


def avg(values):
    return sum(values) / len(values) if values else 0.0


def build_perf_summary(status, perf_entries):
    by_mode = {}
    for mode in MEMORY_MODES:
        mode_entries = [entry for entry in perf_entries if entry["mode"] == mode]
        if mode_entries:
            totals = [entry["total_cycles"] for entry in mode_entries]
            by_mode[mode] = {
                "tests_counted": len(mode_entries),
                "min_total_cycles": min(totals),
                "max_total_cycles": max(totals),
                "avg_total_cycles": avg(totals),
                "avg_load_a_cycles": avg([entry["load_a_cycles"] for entry in mode_entries]),
                "avg_load_b_cycles": avg([entry["load_b_cycles"] for entry in mode_entries]),
                "avg_start_core_cycles": avg([entry["start_core_cycles"] for entry in mode_entries]),
                "avg_wait_core_cycles": avg([entry["wait_core_cycles"] for entry in mode_entries]),
                "avg_store_c_cycles": avg([entry["store_c_cycles"] for entry in mode_entries]),
            }
        else:
            by_mode[mode] = {
                "tests_counted": 0,
                "min_total_cycles": None,
                "max_total_cycles": None,
                "avg_total_cycles": None,
                "avg_load_a_cycles": None,
                "avg_load_b_cycles": None,
                "avg_start_core_cycles": None,
                "avg_wait_core_cycles": None,
                "avg_store_c_cycles": None,
            }

    return {
        "status": status,
        "mac_variant": "row4",
        "memory_modes_tested": list(MEMORY_MODES),
        "modes": by_mode,
        "raw_measurements": perf_entries,
        "notes": [
            "abstract ready/valid memory port",
            "not AXI",
            "cycle counts are simulation measurements",
        ],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def write_perf_summary(perf_summary):
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    PERF_SUMMARY_PATH.write_text(json.dumps(perf_summary, indent=2) + "\n", encoding="utf-8")


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
    perf_entries = parse_perf(sim_result.stdout)
    perf_status = "passed" if status == "passed" and perf_entries else "failed"
    perf_summary = build_perf_summary(perf_status, perf_entries)
    write_perf_summary(perf_summary)
    write_summary(status, len(passed_names), passed_names, sim_stdout=sim_result.stdout, perf_summary=perf_summary)

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
