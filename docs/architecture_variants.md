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

## 4-Lane Row MAC Pipeline 2

- Timing-oriented ASIC variant selected with `TINYNPU_MAC_ROW4_PIPE2`.
- Keeps the same programmer-visible top-level behavior and C result values as
  the default row4 and row4_pipe paths.
- Adds an operand-select pipeline stage before product generation: selected A,
  selected B lanes, row/k metadata, and control-valid state are registered
  before the signed int8 multipliers.
- The following stages register products and then update the int32
  accumulators, targeting the row4_pipe critical path from `k_q`/state-dependent
  control and operand select into the product registers.
- Expected tradeoff: higher operation latency and additional registers in
  exchange for a shorter control-select-to-product-register path. Timing closure
  is not claimed until OpenLane reports setup, slew, max-cap, antenna, DRC, and
  LVS all clean.

Run:

```sh
make sim-row4-pipe2
make synth-row4-pipe2
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

- Output-stationary 4x4 processing-element array selected with
  `TINYNPU_MAC_SYSTOLIC4X4`.
- Preserves the same top-level register bus, A/B scratchpads, C result buffer,
  and start/busy/done contract as the other MAC variants.
- Skews A operands by row and moves them right while skewing B operands by
  column and moving them down. Each PE retains its own int32 C accumulator.
- Separates edge injection, operand forwarding, low/high-nibble partial
  multiplication, product combination, and accumulation with registers. This
  avoids a single select-to-8x8-multiply-to-accumulate path.
- Completes one register-controlled 4x4 tile in 17 accepted-start-to-done
  cycles in the self-checking simulation.
- Uses substantially more arithmetic and register area than the four-lane row
  engines, but is a direct stepping stone toward larger matrix engines.
- Can also replace the compute engine inside the existing double-buffered
  AXI4-Stream NPU without changing that module's stream or buffer interfaces.

Run:

```sh
make sim-systolic4x4
make synth-systolic4x4
make sim-axis-stream-npu-systolic4x4
```
