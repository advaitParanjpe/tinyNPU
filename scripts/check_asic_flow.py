#!/usr/bin/env python3

import json
import shutil
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = REPO_ROOT / "openlane" / "tinynpu_top" / "config.json"
SDC_PATH = REPO_ROOT / "constraints" / "tinynpu_top.sdc"


def fail(message):
    print(f"FAIL {message}")
    return 1


def main():
    if not CONFIG_PATH.is_file():
        return fail(f"missing {CONFIG_PATH.relative_to(REPO_ROOT)}")
    if not SDC_PATH.is_file():
        return fail(f"missing {SDC_PATH.relative_to(REPO_ROOT)}")

    try:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return fail(f"invalid OpenLane JSON: {exc}")

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

    missing_sources = []
    for entry in config["VERILOG_FILES"]:
        if not isinstance(entry, str):
            return fail("VERILOG_FILES entries must be strings")
        if not entry.startswith("dir::"):
            return fail(f"source path should use dir:: prefix: {entry}")
        source_path = (CONFIG_PATH.parent / entry.removeprefix("dir::")).resolve()
        if not source_path.is_file():
            missing_sources.append(str(source_path.relative_to(REPO_ROOT)))
    if missing_sources:
        return fail("missing source files: " + ", ".join(missing_sources))

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

