# tinyNPU Architecture Variants

This document tracks possible datapath variants. The default RTL remains the
4-lane row MAC.

See `docs/design_layers.md` for how these datapaths fit under the core,
optional APB wrapper, DMA descriptor wrapper, AXI-Lite control wrapper, AXI
read-DMA wrapper, full single-beat AXI DMA wrapper, and testbench-only
DMA-style model.

All variants use the same top-level bus, A/B int8 scratchpads, C int32 result
buffer, and `tinynpu_mac_array` wrapper. Only the internal MAC datapath selected
by compile-time define changes.

## Serial MAC Baseline

- Computes one C element at a time.
- Iterates row, column, and k.
- Performs one signed int8 multiply-accumulate per cycle.
- Lower arithmetic area.
- Higher latency.
- Useful as a minimum-area comparison point.

Run:

```sh
make sim-serial
make synth-serial
make results-serial
```

## 4-Lane Row MAC

- Current default.
- Computes one full C row at a time.
- Broadcasts one A value to four multiply lanes and accumulates four C columns.
- Unpipelined/balanced small-NPU datapath for v5+.

Run:

```sh
make sim
make synth
make results
```

## 4-Lane Row MAC Pipeline

- Timing-oriented ASIC variant selected with `TINYNPU_MAC_ROW4_PIPE`.
- Keeps the same top-level register interface, start/busy/done behavior, sticky
  top-level done status, and C result values as the default row4 path.
- Computes one full C row at a time like `row4`, but registers the four
  selected products before adding them into the int32 accumulators.
- Targets the previous 100 MHz OpenLane critical path through `k_q`/control,
  operand select, multiply, add, and accumulator update.
- Expected tradeoff: higher operation latency and some extra registers in
  exchange for a shorter single-cycle accumulator input path. Timing closure is
  not claimed until a 10 ns OpenLane run confirms it.

Run:

```sh
make sim-row4-pipe
make synth-row4-pipe
```

## 16-Lane Full Parallel MAC

- Computes all 16 C outputs in parallel across k.
- Maintains 16 signed int32 accumulators.
- For each `k`, updates every `C[row][col]` accumulator with `A[row][k] * B[k][col]`.
- Lower latency.
- Higher area and routing pressure.
- Useful as an upper-parallelism baseline for fixed 4x4 area/latency studies.

Run:

```sh
make sim-full16
make synth-full16
make results-full16
```

## Systolic-Style 4x4 Array

- More NPU-like dataflow.
- More complex control and data movement.
- Better stepping stone toward larger matrix engines.
- Not planned until the basic bus, verification, and synthesis flows are stable.
