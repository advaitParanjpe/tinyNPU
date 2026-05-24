#!/usr/bin/env python3

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SYNTH_SUMMARY = REPO_ROOT / "build" / "synth" / "synth_summary.json"
DEFAULT_SIM_SUMMARY = REPO_ROOT / "build" / "sim" / "sim_summary.json"
DEFAULT_RESULTS = REPO_ROOT / "build" / "results" / "results_summary.json"


def load_json(path):
    if not path.exists():
        return None
    return json.loads(path.read_text())


def parse_args():
    parser = argparse.ArgumentParser(description="Save tinyNPU result snapshot")
    parser.add_argument("--version", required=True)
    parser.add_argument("--datapath", required=True)
    parser.add_argument("--mac-variant", choices=("row4", "serial", "full16"))
    parser.add_argument("--max-latency", type=int)
    parser.add_argument("--tests")
    parser.add_argument("--synth-summary", default=str(DEFAULT_SYNTH_SUMMARY))
    parser.add_argument("--sim-summary", default=str(DEFAULT_SIM_SUMMARY))
    parser.add_argument("--out", default=str(DEFAULT_RESULTS))
    return parser.parse_args()


def main():
    args = parse_args()
    synth_summary = load_json(Path(args.synth_summary))
    sim_summary = load_json(Path(args.sim_summary))

    if synth_summary is None:
        raise SystemExit(f"missing synthesis summary: {args.synth_summary}")

    mac_variant = args.mac_variant
    if mac_variant is None and sim_summary is not None:
        mac_variant = sim_summary.get("mac_variant")
    if mac_variant is None:
        mac_variant = synth_summary.get("mac_variant")
    if mac_variant is None:
        mac_variant = "row4"

    max_latency = args.max_latency
    if max_latency is None and sim_summary is not None:
        max_latency = sim_summary.get("max_observed_latency_cycles")

    tests = args.tests
    if tests is None and sim_summary is not None:
        tests = (
            f"{sim_summary.get('directed_tests_passed')} directed/control/edge + "
            f"{sim_summary.get('generated_random_tests_passed')} random + "
            f"{'checkers' if sim_summary.get('assertions_enabled') else 'no checkers'}"
        )

    entry = {
        "version": args.version,
        "mac_variant": mac_variant,
        "datapath": args.datapath,
        "tests": tests,
        "max_latency_cycles": max_latency,
        "synthesis_flow": "generic Yosys",
        "total_cells": synth_summary.get("total_cells"),
        "total_wires": synth_summary.get("total_wires"),
        "total_wire_bits": synth_summary.get("total_wire_bits"),
        "cell_counts": synth_summary.get("cell_counts", {}),
        "simulation_status": sim_summary.get("status") if sim_summary else None,
        "synthesis_status": synth_summary.get("status"),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "notes": "Generic Yosys synthesis only; not technology-mapped PPA.",
    }

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    existing = {"results": []}
    if out_path.exists():
        existing = json.loads(out_path.read_text())

    results = existing.get("results", [])
    replaced = False
    for idx, old_entry in enumerate(results):
        if old_entry.get("version") == entry["version"] and old_entry.get("mac_variant") == entry["mac_variant"]:
            results[idx] = entry
            replaced = True
            break

    if not replaced:
        results.append(entry)

    existing["results"] = results
    out_path.write_text(json.dumps(existing, indent=2) + "\n")
    print(f"Wrote result snapshot to {out_path.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
