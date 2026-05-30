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

The `row4_pipe`, `row4_pipe2`, `row4_pipe2_dupa`, and `row4_pipe3` ASIC targets are separate
OpenLane configurations. They preserve the existing row4 OpenLane target and
use the same 10 ns / 100 MHz SDC while defining `TINYNPU_MAC_ROW4_PIPE`,
`TINYNPU_MAC_ROW4_PIPE2`, `TINYNPU_MAC_ROW4_PIPE2_DUPA`, or
`TINYNPU_MAC_ROW4_PIPE3` for synthesis. Their ASIC source lists are limited to
the shared defs include, the selected MAC variant, `tinynpu_mac_array`, the A/B
scratchpad, the C result buffer, and `tinynpu_top`.

| Variant | OpenLane config | Run directory | Clock | Flow | Latency / generic cells | Setup WNS/TNS (ns) | Setup violations | Slew violations | Max-cap violations | Antenna violations | DRC/LVS | Utilization | Std-cell area (um^2) | Power (W) | Status |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- |
| row4 | `openlane/tinynpu_top/config.json` | `openlane/tinynpu_top/runs/RUN_2026-05-30_00-36-33` | 10 ns / 100 MHz | Complete | 26 cyc / 14,514 | -5.831 / -372.767 | 319 | 3,003 | 29 | 2 | Clean / clean | 20.89% | 128,222 | 0.02816 | Not clean |
| row4_pipe | `openlane/tinynpu_top_row4_pipe/config.json` | `openlane/tinynpu_top_row4_pipe/runs/RUN_2026-05-30_01-55-41` | 10 ns / 100 MHz | Complete | 42 cyc / 15,026 | -1.901 / -45.687 | 178 | 2,882 | 21 | 0 | Clean / clean | 18.99% | 116,558 | 0.02282 | Not clean |
| row4_pipe2 | `openlane/tinynpu_top_row4_pipe2/config.json` | `openlane/tinynpu_top_row4_pipe2/runs/RUN_2026-05-30_02-58-13` | 10 ns / 100 MHz | Complete | 58 cyc / 15,198 | -0.343 / -1.588 | 21 | 3,150 | 10 | 0 | Clean / clean | 19.50% | 119,655 | 0.02683 | Not clean |
| row4_pipe2_dupa | `openlane/tinynpu_top_row4_pipe2_dupa/config.json` | `openlane/tinynpu_top_row4_pipe2_dupa/runs/RUN_2026-05-30_04-42-51` | 10 ns / 100 MHz | Complete | 58 cyc / 15,198 | -0.314 / -1.716 | 16 | 3,199 | 20 | 0 | Clean / clean | 19.42% | 119,197 | 0.02008 | Not clean |
| row4_pipe3 | `openlane/tinynpu_top_row4_pipe3/config.json` | `openlane/tinynpu_top_row4_pipe3/runs/RUN_2026-05-30_03-42-10` | 10 ns / 100 MHz | Complete | 74 cyc / 11,966 | -0.260 / -0.469 | 4 | 4,566 | 25 | 1 | Clean / clean | 20.00% | 122,740 | 0.01924 | Not clean |

The row4_pipe run improves 10 ns setup WNS/TNS and reduces setup, slew, and
max-cap violation counts relative to the row4 baseline in this flow. row4_pipe2
adds an operand-select pipeline cut before product generation and further
improves setup WNS/TNS and setup violation count. The row4_pipe2 row above uses
the retained physical-tuning run for that target. row4_pipe2_dupa is derived
from row4_pipe2 and duplicates the selected A operand into lane-local registers
before the inferred signed multipliers, preserving the 58-cycle observed latency.
It slightly improves WNS and setup violation count versus tuned row4_pipe2, but
TNS, max-slew count, and max-cap count do not improve, so it is not a clear
closure win. The run is DRC/LVS/antenna clean after OpenLane antenna repair; the
console cell report showed substantial antenna-cell insertion, so this should be
treated as a physical-flow result rather than evidence that the RTL change alone
solved antenna risk. row4_pipe3 splits product generation into registered
low/high partial-product and product-sum stages, which further improves setup
WNS/TNS and reduces setup violations. It is still not timing closed or signoff
clean: max-slew and max-cap violations remain, and the 10 ns row4_pipe3 run
reports one antenna pin/net violation despite clean DRC and LVS.

## Selected 95 MHz Implementation Target

The selected realistic implementation target is row4_pipe2 at 10.5 ns, about
95.2 MHz. This target is separate from the preserved 10 ns / 100 MHz row4_pipe2
exploration run. It starts from the retained tuned row4_pipe2 physical-flow
settings and uses a row4_pipe2-specific 10.5 ns SDC.

| Item | Value |
| --- | --- |
| OpenLane config | `openlane/tinynpu_top_row4_pipe2_95mhz/config.json` |
| SDC | `openlane/tinynpu_top_row4_pipe2_95mhz/tinynpu_top_10p5.sdc` |
| Run directory | `openlane/tinynpu_top_row4_pipe2_95mhz/runs/RUN_2026-05-30_05-02-21` |
| Flow status | Complete, `flow__errors__count = 0` |
| Clock target | 10.5 ns / 95.2 MHz on `clk` |
| PDK / standard-cell library | `sky130A` / `sky130_fd_sc_hd` |
| Die / core area | 640,000 um^2 / 613,701 um^2 |
| Utilization | 19.47% |
| Std-cell count / area | 24,398 / 119,487 um^2 |
| Setup WNS / TNS / violations | -0.301 ns / -0.604 ns / 6 |
| Hold WNS / TNS / violations | 0 ns / 0 ns / 0 |
| Max-slew violations | 3,008 |
| Max-cap violations | 15 |
| Antenna violations | 1 pin on 1 net |
| DRC | Magic 0 errors, KLayout 0 errors |
| LVS | Passed, 0 LVS errors |
| Power estimate | 0.02555 W total, with 0.01462 W internal, 0.01093 W switching, and 0.000000116 W leakage |
| Status | Not setup-clean and not signoff-clean |

Primary final artifacts for this run are:

| Artifact | Path |
| --- | --- |
| GDS | `openlane/tinynpu_top_row4_pipe2_95mhz/runs/RUN_2026-05-30_05-02-21/final/gds/tinynpu_top.gds` |
| DEF | `openlane/tinynpu_top_row4_pipe2_95mhz/runs/RUN_2026-05-30_05-02-21/final/def/tinynpu_top.def` |
| Gate-level netlist | `openlane/tinynpu_top_row4_pipe2_95mhz/runs/RUN_2026-05-30_05-02-21/final/nl/tinynpu_top.nl.v` |
| Post-route netlist | `openlane/tinynpu_top_row4_pipe2_95mhz/runs/RUN_2026-05-30_05-02-21/final/pnl/tinynpu_top.pnl.v` |
| Metrics | `openlane/tinynpu_top_row4_pipe2_95mhz/runs/RUN_2026-05-30_05-02-21/final/metrics.csv` |

The 100 MHz row4_pipe2 run remains the aggressive exploration target and is
still slightly negative: WNS/TNS -0.343 / -1.588 ns with 21 setup violations.
The 95 MHz target is the realistic selected implementation target, but this
specific OpenLane run is still not setup-clean. Because setup did not close,
no additional electrical-cleanup experiment was kept for this target. The run
also has max-slew, max-cap, and antenna violations, so it is not signoff-clean.

## Selected Implementation Frequency Sweep

After the 10.5 ns / 95.2 MHz selected row4_pipe2 target remained setup-negative,
two lower-clock row4_pipe2 targets were run as separate OpenLane configurations.
These runs preserve the documented 10 ns and 10.5 ns results and change only the
row4_pipe2 ASIC target clock period/SDC.

| Target | OpenLane config | Run directory | Flow | Setup WNS/TNS (ns) | Setup violations | Hold WNS/TNS/violations | Slew violations | Max-cap violations | Antenna violations | DRC/LVS | Utilization | Std-cell area (um^2) | Power (W) | Status |
| --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- |
| 10.5 ns / 95.2 MHz | `openlane/tinynpu_top_row4_pipe2_95mhz/config.json` | `openlane/tinynpu_top_row4_pipe2_95mhz/runs/RUN_2026-05-30_05-02-21` | Complete | -0.301 / -0.604 | 6 | 0 / 0 / 0 | 3,008 | 15 | 1 | Clean / clean | 19.47% | 119,487 | 0.02555 | Not clean |
| 10.75 ns / 93.0 MHz | `openlane/tinynpu_top_row4_pipe2_93mhz/config.json` | `openlane/tinynpu_top_row4_pipe2_93mhz/runs/RUN_2026-05-30_05-19-41` | Complete | -0.260 / -0.504 | 7 | 0 / 0 / 0 | 3,320 | 15 | 1 | Clean / clean | 19.43% | 119,239 | 0.02488 | Not clean |
| 11.0 ns / 90.9 MHz | `openlane/tinynpu_top_row4_pipe2_91mhz/config.json` | `openlane/tinynpu_top_row4_pipe2_91mhz/runs/RUN_2026-05-30_05-33-13` | Complete | -0.172 / -0.238 | 4 | 0 / 0 / 0 | 3,258 | 17 | 0 | Clean / clean | 19.44% | 119,321 | 0.02426 | Not clean |

The 11.0 ns run improves WNS/TNS relative to the 10.5 ns and 10.75 ns selected
targets and is antenna/DRC/LVS clean, but it is still not setup-clean. Because
the requested condition for an electrical-cleanup pass was setup closure at
11.0 ns, no 11.0 ns cleanup pass was run. None of the selected row4_pipe2
frequency-sweep targets is signoff clean: setup remains negative at all three
periods, and max-slew/max-cap violations remain throughout.

The highest frequency target that is closest to signoff-clean is still not
closed. Among these selected row4_pipe2 targets, 11.0 ns / 90.9 MHz is the best
documented implementation point because it has the least-negative setup result,
hold is clean, antenna is clean, and DRC/LVS are clean. It should be described
as the best current ASIC-style implementation attempt, not as timing-closed or
signoff-clean.

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
- DRC and LVS are clean in the documented row4, row4_pipe, row4_pipe2,
  row4_pipe2_dupa, and row4_pipe3 runs, but these results are not signoff clean.
- At 10 ns / 100 MHz, timing, max slew, and max capacitance issues remain for
  row4, row4_pipe, row4_pipe2, row4_pipe2_dupa, and row4_pipe3. Some row4 sweep
  runs and the documented row4_pipe3 run also report antenna violations.
- The 100 MHz clock is a bring-up target, not a closed timing target for this
  implementation. The 95 MHz row4_pipe2 target is the selected realistic
  implementation target, but the documented 10.5 ns run still has setup,
  max-slew, max-cap, and antenna violations. The 50 MHz sweep point closes setup
  only, not full signoff.
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
