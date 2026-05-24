# tinyNPU Performance Reporting

tinyNPU records lightweight simulation performance data for the DMA descriptor
wrapper. These are cycle counts from the Icarus simulation over the abstract
ready/valid memory port. They are not AXI timing, technology timing, or PPA.

## Run

```sh
make sim-dma-desc
```

The runner writes:

- `build/sim/dma_desc_wrapper/sim_summary.json`
- `build/sim/dma_desc_wrapper/perf_summary.json`

## What Is Measured

For descriptor DMA operations, the testbench records cycles from accepted
`DMA_CTRL.start` to descriptor `done`, split by observed DMA FSM phase:

- `LOAD_A`
- `LOAD_B`
- `START_CORE`
- `WAIT_CORE`
- `STORE_C`

Measurements are grouped by memory model:

- `always_ready`
- `fixed_latency`
- `random_backpressure`

Timeout/error tests are excluded from these performance averages because they
intentionally abort the DMA operation before normal store-back completion.

## What Is Not Measured

- No AXI protocol timing.
- No burst behavior.
- No outstanding transactions.
- No memory error responses.
- Timeout/error paths are verified separately, not treated as normal throughput
  measurements.
- No post-synthesis timing.

The values are useful for comparing memory-port behavior within this simulation
flow only.
