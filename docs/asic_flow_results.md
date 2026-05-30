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

## Row4 vs Pipelined Row4 Variants

The `row4_pipe` and `row4_pipe2` ASIC targets are separate OpenLane
configurations. They preserve the existing row4 OpenLane target and use the
same 10 ns / 100 MHz SDC while defining `TINYNPU_MAC_ROW4_PIPE` or
`TINYNPU_MAC_ROW4_PIPE2` for synthesis. Their ASIC source lists are limited to
the shared defs include, the selected MAC variant, `tinynpu_mac_array`, the A/B
scratchpad, the C result buffer, and `tinynpu_top`.

| Variant | OpenLane config | Run directory | Clock | Flow | Latency / generic cells | Setup WNS/TNS (ns) | Setup violations | Slew violations | Max-cap violations | Antenna violations | DRC/LVS | Utilization | Std-cell area (um^2) | Power (W) | Status |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- |
| row4 | `openlane/tinynpu_top/config.json` | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33` | 10 ns / 100 MHz | Complete | 26 cyc / 14,514 | -5.831 / -372.767 | 319 | 3,003 | 29 | 2 | Clean / clean | 20.89% | 128,222 | 0.02816 | Not clean |
| row4_pipe | `openlane/tinynpu_top_row4_pipe/config.json` | `openlane/tinynpu_top_row4_pipe/runs/RUN_2026-05-30_01-55-41` | 10 ns / 100 MHz | Complete | 42 cyc / 15,026 | -1.901 / -45.687 | 178 | 2,882 | 21 | 0 | Clean / clean | 18.99% | 116,558 | 0.02282 | Not clean |
| row4_pipe2 | `openlane/tinynpu_top_row4_pipe2/config.json` | `openlane/tinynpu_top_row4_pipe2/runs/RUN_2026-05-30_02-36-32` | 10 ns / 100 MHz | Complete | 58 cyc / 15,198 | -0.622 / -3.782 | 30 | 3,557 | 21 | 0 | Clean / clean | 19.49% | 119,605 | 0.02677 | Not clean |

The row4_pipe run improves 10 ns setup WNS/TNS and reduces setup, slew, and
max-cap violation counts relative to the row4 baseline in this flow. row4_pipe2
adds an operand-select pipeline cut before product generation and further
improves setup WNS/TNS and setup violation count. It reports clean antenna, DRC,
and LVS in this run, but still has setup, max-slew, and max-cap violations, so
it is not timing closed or signoff clean.

## Row4 Pipe Physical-Tuning Experiment

A controlled 10 ns physical-tuning experiment was run for the separate
row4_pipe OpenLane target only. RTL, wrappers, the baseline row4 target, and the
10 ns SDC target were not changed. The tested low-risk knobs were placement
density, post-global-route design repair/timing resizer enablement, tighter
slew/cap repair percentages, and higher setup-resizer buffer limits.

| Variant | Run directory | Config disposition | Setup WNS/TNS (ns) | Setup violations | Slew violations | Max-cap violations | Antenna violations | DRC/LVS | Utilization | Std-cell area (um^2) | Power (W) | Status |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- |
| row4_pipe baseline | `openlane/tinynpu_top_row4_pipe/runs/RUN_2026-05-30_01-55-41` | Retained | -1.901 / -45.687 | 178 | 2,882 | 21 | 0 | Clean / clean | 18.99% | 116,558 | 0.02282 | Not clean |
| row4_pipe physical tune 1 | `openlane/tinynpu_top_row4_pipe/runs/row4_pipe_phys_tune_1` | Discarded | -1.894 / -41.871 | 121 | 2,295 | 10 | 1 | Clean / clean | 19.50% | 119,655 | 0.02389 | Not clean; antenna regressed |

The physical-tuning run reduced TNS and the setup/slew/max-cap violation counts,
but WNS improved by only 0.007 ns and final antenna regressed from clean to one
pin/net violation. Because the experiment did not materially improve WNS and did
not preserve antenna cleanliness, the checked-in row4_pipe config was restored to
the baseline settings.

The next lowest-risk timing step is an RTL pipeline cut around the remaining
critical region: register the `k_q`/state-dependent operand-select outputs
before product generation, then perform signed int8 multiplication/product
registration in the following cycle. That targets the observed
control-select-to-product-register path directly; further OpenLane-only tuning
is unlikely to recover the remaining roughly 1.9 ns WNS by itself.

## Clock Sweep

This controlled sweep estimates the clock period the current row4 RTL can
satisfy before RTL or physical-design tuning. The sweep used temporary generated
configs under `build/asic_clock_sweep/` and varied only the OpenLane clock
period/SDC clock target. RTL, wrappers, MAC architecture, and checked-in
physical-flow settings were not changed.

| Target | Run directory | Flow | Setup WNS/TNS (ns) | Setup violations | Slew violations | Max-cap violations | Antenna violations | DRC/LVS | Utilization | Std-cell area (um^2) | Power (W) | Status |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- |
| 20 ns / 50 MHz | `openlane/tinynpu_top/runs/RUN_2026-05-30_01-02-15` | Complete | 0.000 / 0.000 | 0 | 4,230 | 36 | 2 | Clean / clean | 20.13% | 123,532 | 0.01358 | Setup clean only; not signoff clean |
| 15 ns / 66.7 MHz | `openlane/tinynpu_top/runs/RUN_2026-05-30_01-14-11` | Complete | -2.320 / -53.140 | 144 | 3,579 | 33 | 1 | Clean / clean | 20.23% | 124,154 | 0.01826 | Not clean |
| 12.5 ns / 80 MHz | `openlane/tinynpu_top/runs/RUN_2026-05-30_01-26-33` | Complete | -2.947 / -120.757 | 228 | 3,431 | 30 | 0 | Clean / clean | 20.62% | 126,548 | 0.02225 | Not clean |
| 10 ns / 100 MHz baseline | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33` | Complete | -5.831 / -372.767 | 319 | 3,003 | 29 | 2 | Clean / clean | 20.89% | 128,222 | 0.02816 | Not clean |

The only swept target that closes setup in this ASIC-style flow is 20 ns / 50
MHz. No swept target is signoff clean: all targets still have max-slew and
max-capacitance violations, and the 20 ns, 15 ns, and 10 ns runs also report
antenna violations. The 12.5 ns run's antenna-clean result should be treated as
a run-specific routing/repair outcome, not evidence that a faster clock target
fixes antenna behavior.

## Limitations

- This is an ASIC-style RTL-to-GDS flow result only. The design has not been
  submitted to a shuttle or fab.
- DRC and LVS are clean in the documented row4, row4_pipe, and row4_pipe2 runs,
  but these results are not signoff clean.
- At 10 ns / 100 MHz, timing, max slew, and max capacitance issues remain for
  row4, row4_pipe, and row4_pipe2. Some row4 sweep runs also report antenna
  violations.
- The 100 MHz clock is a bring-up target, not a closed timing target for this
  implementation. The 50 MHz sweep point closes setup only, not full signoff.
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
