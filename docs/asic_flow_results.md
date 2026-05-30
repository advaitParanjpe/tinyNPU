# tinyNPU ASIC-Style Flow Results

Run:

- `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33`

This page summarizes the completed Dockerized OpenLane 2 run for the row4
`tinynpu_top` ASIC-style RTL-to-GDS flow scaffold. It is a local flow result,
not a shuttle or fab submission.

## Final Artifacts

| Artifact | Path |
| --- | --- |
| Primary GDS | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/gds/tinynpu_top.gds` |
| KLayout GDS | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/klayout_gds/tinynpu_top.klayout.gds` |
| Magic GDS | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/mag_gds/tinynpu_top.magic.gds` |
| DEF | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/def/tinynpu_top.def` |
| Gate-level netlist | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/nl/tinynpu_top.nl.v` |
| Post-route netlist | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/pnl/tinynpu_top.pnl.v` |
| LEF | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/lef/tinynpu_top.lef` |
| OpenDB database | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/odb/tinynpu_top.odb` |
| SDC used in final views | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/sdc/tinynpu_top.sdc` |
| SPEF parasitics | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/spef/{min,nom,max}/tinynpu_top.*.spef` |
| SDF timing | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/sdf/*/tinynpu_top__*.sdf` |
| SPICE | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/spice/tinynpu_top.spice` |
| Final metrics | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/final/metrics.csv` |
| Timing summary | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/55-openroad-stapostpnr/summary.rpt` |
| Manufacturability summary | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/75-misc-reportmanufacturability/manufacturability.rpt` |
| LVS report | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/69-netgen-lvs/reports/lvs.netgen.rpt` |
| Antenna summary | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/46-openroad-checkantennas-1/reports/antenna_summary.rpt` |
| Magic DRC report | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/63-magic-drc/reports/drc_violations.magic.rpt` |
| KLayout DRC report | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33/64-klayout-drc/reports/drc_violations.klayout.json` |

## Results Summary

| Metric | Value |
| --- | --- |
| Flow completion status | Complete, `flow__errors__count = 0` |
| Top module | `tinynpu_top` |
| OpenLane run tag | `RUN_2026-05-30_00-36-33` |
| PDK | `sky130A` |
| Standard-cell library | `sky130_fd_sc_hd` |
| Clock target | 10.000 ns / 100 MHz on `clk` |
| Die area | 640,000 um^2, bbox `0 0 800 800` |
| Core area | 613,701 um^2, bbox `5.52 10.88 794.42 788.8` |
| Standard-cell utilization | 20.8932% |
| Standard-cell count | 25,735 |
| Standard-cell area | 128,222 um^2 |
| Macro count / macro area | 0 / 0 um^2 |
| Setup WNS | -5.831 ns |
| Setup TNS | -372.767 ns |
| Setup violation count | 319 |
| Hold WNS / TNS / violations | 0 ns / 0 ns / 0 |
| Max slew violation count | 3,003 |
| Max capacitance violation count | 29 |
| Antenna violation count | 2 pins on 2 nets |
| Routed DRC errors | 0 final detailed-route errors |
| Magic DRC | 0 errors |
| KLayout DRC | 0 errors |
| LVS | Passed, 0 device differences |
| Power-grid violations | 0 |
| Power estimate | 0.028164 W total, with 0.015421 W internal, 0.012743 W switching, and 0.000000128 W leakage |

## Limitations

- This is an ASIC-style RTL-to-GDS flow result only. The design has not been
  submitted to a shuttle or fab.
- DRC and LVS are clean in this run, but the result is not signoff clean.
- Timing, max slew, max capacitance, and antenna issues remain.
- The 100 MHz clock is a bring-up target, not a closed timing target for this
  implementation.
- The A/B scratchpads and C result buffer are register-based standard-cell
  storage in this run. The OpenLane metrics report zero macros, so these are not
  SRAM macros.
- The run uses the row4 `tinynpu_top` core source list, not the APB, descriptor,
  AXI-Lite, AXI read-DMA, or full AXI DMA wrappers.

## CV-Ready Summary

Completed a local OpenLane 2/SKY130 ASIC-style RTL-to-GDS flow for the row4
`tinynpu_top` accelerator core, producing GDS/DEF/netlist artifacts with clean
DRC/LVS in the captured run. Remaining closure work includes timing, electrical
violations, and antenna repair; this is not a tapeout or signoff-clean claim.
