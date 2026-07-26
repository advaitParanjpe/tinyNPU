#!/usr/bin/env python3

import json
import shutil
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
ROW4_CONFIG_PATH = REPO_ROOT / "openlane" / "tinynpu_top" / "config.json"
ROW4_PIPE_CONFIG_PATH = REPO_ROOT / "openlane" / "tinynpu_top_row4_pipe" / "config.json"
ROW4_PIPE2_CONFIG_PATH = REPO_ROOT / "openlane" / "tinynpu_top_row4_pipe2" / "config.json"
ROW4_PIPE2_95_CONFIG_PATH = REPO_ROOT / "openlane" / "tinynpu_top_row4_pipe2_95mhz" / "config.json"
ROW4_PIPE2_93_CONFIG_PATH = REPO_ROOT / "openlane" / "tinynpu_top_row4_pipe2_93mhz" / "config.json"
ROW4_PIPE2_91_CONFIG_PATH = REPO_ROOT / "openlane" / "tinynpu_top_row4_pipe2_91mhz" / "config.json"
ROW4_PIPE2_DUPA_CONFIG_PATH = REPO_ROOT / "openlane" / "tinynpu_top_row4_pipe2_dupa" / "config.json"
SYSTOLIC4X4_CONFIG_PATH = REPO_ROOT / "openlane" / "tinynpu_top_systolic4x4" / "config.json"
SDC_PATH = REPO_ROOT / "constraints" / "tinynpu_top.sdc"
ROW4_EXPECTED_SOURCES = (
    "rtl/tinynpu_mac_row4.sv",
    "rtl/tinynpu_mac_array.sv",
    "rtl/tinynpu_scratchpad_i8.sv",
    "rtl/tinynpu_result_buffer_i32.sv",
    "rtl/tinynpu_top.sv",
)
ROW4_PIPE_EXPECTED_SOURCES = (
    "rtl/tinynpu_defs.svh",
    "rtl/tinynpu_mac_row4_pipe.sv",
    "rtl/tinynpu_mac_array.sv",
    "rtl/tinynpu_scratchpad_i8.sv",
    "rtl/tinynpu_result_buffer_i32.sv",
    "rtl/tinynpu_top.sv",
)
ROW4_PIPE2_EXPECTED_SOURCES = (
    "rtl/tinynpu_defs.svh",
    "rtl/tinynpu_mac_row4_pipe2.sv",
    "rtl/tinynpu_mac_array.sv",
    "rtl/tinynpu_scratchpad_i8.sv",
    "rtl/tinynpu_result_buffer_i32.sv",
    "rtl/tinynpu_top.sv",
)
ROW4_PIPE2_DUPA_EXPECTED_SOURCES = (
    "rtl/tinynpu_defs.svh",
    "rtl/tinynpu_mac_row4_pipe2_dupa.sv",
    "rtl/tinynpu_mac_array.sv",
    "rtl/tinynpu_scratchpad_i8.sv",
    "rtl/tinynpu_result_buffer_i32.sv",
    "rtl/tinynpu_top.sv",
)
SYSTOLIC4X4_EXPECTED_SOURCES = (
    "rtl/tinynpu_defs.svh",
    "rtl/tinynpu_mac_systolic4x4.sv",
    "rtl/tinynpu_mac_array.sv",
    "rtl/tinynpu_scratchpad_i8.sv",
    "rtl/tinynpu_result_buffer_i32.sv",
    "rtl/tinynpu_top.sv",
)


def fail(message):
    print(f"FAIL {message}")
    return 1


def check_config(config_path, expected_sources, expected_defines):
    if not config_path.is_file():
        return fail(f"missing {config_path.relative_to(REPO_ROOT)}")
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return fail(f"invalid OpenLane JSON {config_path.relative_to(REPO_ROOT)}: {exc}")

    required = ("DESIGN_NAME", "VERILOG_FILES", "CLOCK_PORT", "CLOCK_PERIOD")
    missing = [key for key in required if key not in config]
    if missing:
        return fail("missing config keys: " + ", ".join(missing))

    if config["DESIGN_NAME"] != "tinynpu_top":
        return fail("DESIGN_NAME must be tinynpu_top")
    if config["CLOCK_PORT"] != "clk":
        return fail("CLOCK_PORT must be clk")
    if config.get("SYNTH_DEFINES", ""):
        return fail("row4 is the default MAC; SYNTH_DEFINES should be empty")
    if config.get("VERILOG_DEFINES", []) != expected_defines:
        return fail(
            f"unexpected VERILOG_DEFINES for {config_path.relative_to(REPO_ROOT)}: "
            + ", ".join(config.get("VERILOG_DEFINES", []))
        )

    configured_sources = []
    missing_sources = []
    for entry in config["VERILOG_FILES"]:
        if not isinstance(entry, str):
            return fail("VERILOG_FILES entries must be strings")
        if not entry.startswith("dir::"):
            return fail(f"source path should use dir:: prefix: {entry}")
        source_path = (config_path.parent / entry.removeprefix("dir::")).resolve()
        configured_sources.append(str(source_path.relative_to(REPO_ROOT)))
        if not source_path.is_file():
            missing_sources.append(str(source_path.relative_to(REPO_ROOT)))
    if missing_sources:
        return fail("missing source files: " + ", ".join(missing_sources))

    if configured_sources != list(expected_sources):
        return fail("unexpected ASIC source list: " + ", ".join(configured_sources))
    return 0


def main():
    if not SDC_PATH.is_file():
        return fail(f"missing {SDC_PATH.relative_to(REPO_ROOT)}")

    rc = check_config(ROW4_CONFIG_PATH, ROW4_EXPECTED_SOURCES, [])
    if rc != 0:
        return rc
    rc = check_config(ROW4_PIPE_CONFIG_PATH, ROW4_PIPE_EXPECTED_SOURCES, ["TINYNPU_MAC_ROW4_PIPE"])
    if rc != 0:
        return rc
    rc = check_config(ROW4_PIPE2_CONFIG_PATH, ROW4_PIPE2_EXPECTED_SOURCES, ["TINYNPU_MAC_ROW4_PIPE2"])
    if rc != 0:
        return rc
    rc = check_config(ROW4_PIPE2_95_CONFIG_PATH, ROW4_PIPE2_EXPECTED_SOURCES, ["TINYNPU_MAC_ROW4_PIPE2"])
    if rc != 0:
        return rc
    rc = check_config(ROW4_PIPE2_93_CONFIG_PATH, ROW4_PIPE2_EXPECTED_SOURCES, ["TINYNPU_MAC_ROW4_PIPE2"])
    if rc != 0:
        return rc
    rc = check_config(ROW4_PIPE2_91_CONFIG_PATH, ROW4_PIPE2_EXPECTED_SOURCES, ["TINYNPU_MAC_ROW4_PIPE2"])
    if rc != 0:
        return rc
    rc = check_config(ROW4_PIPE2_DUPA_CONFIG_PATH, ROW4_PIPE2_DUPA_EXPECTED_SOURCES, ["TINYNPU_MAC_ROW4_PIPE2_DUPA"])
    if rc != 0:
        return rc
    rc = check_config(SYSTOLIC4X4_CONFIG_PATH, SYSTOLIC4X4_EXPECTED_SOURCES, ["TINYNPU_MAC_SYSTOLIC4X4"])
    if rc != 0:
        return rc

    sdc_text = SDC_PATH.read_text(encoding="utf-8")
    for token in ("create_clock", "get_ports clk", "set_input_delay", "set_output_delay"):
        if token not in sdc_text:
            return fail(f"SDC missing {token}")

    openlane = shutil.which("openlane") or shutil.which("flow.tcl")
    openroad = shutil.which("openroad")
    print("PASS asic_flow_files")
    print(f"INFO openlane_tool: {openlane or 'not found in PATH'}")
    print(f"INFO openroad_tool: {openroad or 'not found in PATH'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
