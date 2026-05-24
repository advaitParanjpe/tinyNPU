#!/usr/bin/env python3

import re
import sys
import json
from datetime import datetime, timezone
from pathlib import Path


NUMBER_RE = re.compile(r"^\s*Number of (wires|wire bits|cells):\s+(\d+)\s*$")
ALT_NUMBER_RE = re.compile(r"^\s*(\d+)\s+(wires|wire bits|cells)\s*$")
CELL_RE = re.compile(r"^\s+(\$?[A-Za-z0-9_.$]+)\s+(\d+)\s*$")
ALT_CELL_RE = re.compile(r"^\s*(\d+)\s+(\$?[A-Za-z0-9_.$]+)\s*$")


def parse_stats(text):
    summary = {}
    cells = {}
    in_cells = False

    for line in text.splitlines():
        number_match = NUMBER_RE.match(line)
        if number_match:
            key = number_match.group(1)
            summary[key] = int(number_match.group(2))
            in_cells = key == "cells"
            continue

        alt_number_match = ALT_NUMBER_RE.match(line)
        if alt_number_match:
            summary[alt_number_match.group(2)] = int(alt_number_match.group(1))
            in_cells = alt_number_match.group(2) == "cells"
            continue

        if in_cells:
            cell_match = CELL_RE.match(line)
            if cell_match:
                cells[cell_match.group(1)] = int(cell_match.group(2))
                continue

            alt_cell_match = ALT_CELL_RE.match(line)
            if alt_cell_match:
                name = alt_cell_match.group(2)
                if name.startswith("$_") or name.startswith("$"):
                    cells[name] = int(alt_cell_match.group(1))
            elif line.strip() == "":
                in_cells = False

    return summary, cells


def main():
    if len(sys.argv) not in (2, 5, 6, 7):
        print("usage: parse_yosys_stats.py <stat.txt> [<yosys.log> <netlist.v> <summary.json> [mac_variant [top_module]]]", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"ERROR: report not found: {path}", file=sys.stderr)
        return 1

    summary, cells = parse_stats(path.read_text())
    mac_variant = sys.argv[5] if len(sys.argv) >= 6 else "row4"
    top_module = sys.argv[6] if len(sys.argv) == 7 else "tinynpu_top"
    notes = "Generic Yosys synthesis only; not technology-mapped PPA."
    if top_module == "tinynpu_dma_descriptor_wrapper":
        notes = "Generic Yosys synthesis only; includes descriptor registers, DMA FSM, abstract external memory port, and wrapped tinyNPU core; no AXI, bursts, or outstanding transactions."
    elif top_module == "tinynpu_axi_lite_wrapper":
        notes = "Generic Yosys synthesis only; includes AXI4-Lite control wrapper, DMA descriptor wrapper, abstract memory port, and tinyNPU core; no full AXI memory master."

    summary_json = {
        "status": "passed",
        "top_module": top_module,
        "mac_variant": mac_variant,
        "yosys_log_path": str(Path(sys.argv[2])) if len(sys.argv) >= 5 else "build/synth/yosys.log",
        "stat_report_path": str(path),
        "netlist_path": str(Path(sys.argv[3])) if len(sys.argv) >= 5 else "build/synth/tinynpu_top_synth.v",
        "total_wires": summary.get("wires"),
        "total_wire_bits": summary.get("wire bits"),
        "total_cells": summary.get("cells"),
        "cell_counts": cells,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "notes": notes,
    }

    if len(sys.argv) >= 5:
        out_path = Path(sys.argv[4])
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(summary_json, indent=2) + "\n")

    print("Yosys synthesis summary:")
    print("  status: passed")
    print(f"  wires: {summary.get('wires', 'unknown')}")
    print(f"  wire bits: {summary.get('wire bits', 'unknown')}")
    print(f"  cells: {summary.get('cells', 'unknown')}")

    if cells:
        print("  cell types:")
        for name in sorted(cells):
            print(f"    {name}: {cells[name]}")

    if len(sys.argv) >= 5:
        print(f"  summary json: {sys.argv[4]}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
