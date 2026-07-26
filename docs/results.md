# tinyNPU Results

These results come from local simulation and generic Yosys synthesis. They are
useful for tracking relative RTL changes, but they are not technology-mapped
area, timing, or power numbers.

| version | variant | datapath | max latency cycles | total cells | relative latency | relative cells | coverage-style status | notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| v24 | row4 | 4-lane row MAC | 26 | 14514 | 1.00x | 1.00x | scenario summary generated | Default datapath; generic gates only |
| v24 | serial | serial MAC baseline | 66 | 10347 | 2.54x | 0.71x | scenario summary generated | Lower cell count, higher latency; generic gates only |
| v24 | full16 | 16-lane full parallel MAC | 8 | 34149 | 0.31x | 2.35x | scenario summary generated | Lowest latency, highest generic cell count |
| current | systolic4x4 | output-stationary 4x4 PE array | 17 | 23911 | 0.65x | 1.65x | scenario summary generated | 100 MHz setup/hold closed in the documented OpenLane run; generic cells shown here |

APB wrapper synthesis is tracked separately because it changes the integration
top, not the MAC datapath comparison.

| version | top | wrapped core | total cells | notes |
| --- | --- | --- | ---: | --- |
| v24 | `tinynpu_apb_wrapper` | row4 | 14560 | Generic Yosys only; APB wrapper around default core |
| v24 | `tinynpu_dma_descriptor_wrapper` | row4 | 17054 | Generic Yosys only; descriptor registers plus DMA FSM, abstract external memory port, and APB-wrapped core; no AXI |
| v25 | `tinynpu_axi_lite_wrapper` | row4 | 17356 | Generic Yosys only; AXI4-Lite control wrapper plus descriptor wrapper and abstract memory port; no full AXI memory master |
| v26 | `tinynpu_dma_descriptor_wrapper` | row4 | 17091 | Adds descriptor done/error IRQ registers and an `irq` output; no AXI |
| v26 | `tinynpu_axi_lite_wrapper` | row4 | 17393 | Passes descriptor `irq` through AXI4-Lite control wrapper; no full AXI memory master |
| v27 | `tinynpu_dma_descriptor_wrapper` | row4 | 17839 | Adds memory/core timeout handling, `DMA_ERROR_CODE`, and verified error IRQ behavior |
| v27 | `tinynpu_axi_lite_wrapper` | row4 | 18141 | AXI4-Lite wrapper with descriptor timeout/error IRQ path; no full AXI memory master |
| v28 | `tinynpu_axi_read_dma_wrapper` | row4 | 19053 | AXI4-Lite control plus single-beat AXI read master for A/B and abstract C write port; no AXI write master or bursts |
| v29 | `tinynpu_axi_dma_wrapper` | row4 | 19692 | AXI4-Lite control plus single-beat AXI read master for A/B and AXI write master for C; no bursts or outstanding transactions |

## Full AXI DMA Milestone Results

Latest local `make sim-axi-dma` and `make synth-axi-dma` results:

| top | simulation | named tests | Yosys cells | wires | wire bits | notes |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `tinynpu_axi_dma_wrapper` | passed | 12 | 19692 | 6671 | 56226 | AXI4-Lite control, single-beat AXI reads for A/B, single-beat AXI writes for C |

The 12 full-DMA simulation tests are `axi_dma_identity`,
`axi_dma_mixed_signed`, `axi_dma_ar_backpressure`, `axi_dma_rvalid_delay`,
`axi_dma_aw_backpressure`, `axi_dma_w_backpressure`, `axi_dma_bvalid_delay`,
`axi_dma_rresp_error`, `axi_dma_read_timeout`, `axi_dma_bresp_error`,
`axi_dma_write_timeout`, and `axi_dma_irq_done`.

The descriptor-driven APB DMA-style testbench still exists as a higher-level
simulation model. The synthesizable descriptor wrapper now has its own abstract
memory port and data-movement tests.
v24 adds simulation performance reporting for the descriptor wrapper. It does
not change synthesis, so RTL synthesis size is unchanged from v21-v23.

## Streaming Milestone Results

The AXI4-Stream work is simulation-only in this release. It is not included in
the OpenLane ASIC targets and is not an ASIC timing-closure claim.

| top | command | simulation | tests | key metrics | notes |
| --- | --- | --- | ---: | --- | --- |
| `tinynpu_axis_stream_tile_core` | `make sim-axis-stream` | passed | 13 | tile-at-a-time | AXI4-Stream subset with input/output backpressure and malformed-frame tests |
| `tinynpu_axis_stream_npu` | `make sim-axis-stream-npu` | passed | 11 | 156-cycle first tile, 64 cycles/tile steady state, 63 cycles/tile observed input acceptance | Double-buffered single-clock prototype with load/compute/output overlap observed |
| `tinynpu_axis_stream_npu` | `make sim-axis-stream-npu-systolic4x4` | passed | 11 | 115-cycle first tile, 64 cycles/tile steady state, 63 cycles/tile observed input acceptance | Same stream and ping-pong-buffer architecture with the systolic compute engine |

For the double-buffered stream NPU, throughput estimates are frequency
dependent: `tiles/s = f_clk / 64`, and each 4x4 tile is 64 MACs. The documented
examples are 1.40625M tiles/s and 90M MAC/s at 90 MHz, or 1.5625M tiles/s and
100M MAC/s at 100 MHz. These are arithmetic estimates from simulation cycle
counts, not production-NPU or signoff-clean claims.

## DMA Descriptor Wrapper Performance

Measured by `make sim-dma-desc` over the abstract memory port:

| memory mode | tests | min total | max total | avg total | avg LOAD_A | avg LOAD_B | avg START_CORE | avg WAIT_CORE | avg STORE_C |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| always_ready | 6 | 168 | 177 | 175.5 | 29.5 | 32.0 | 1.0 | 31.0 | 80.0 |
| fixed_latency | 2 | 369 | 369 | 369.0 | 95.0 | 96.0 | 1.0 | 31.0 | 144.0 |
| random_backpressure | 3 | 367 | 369 | 367.7 | 94.3 | 96.7 | 1.0 | 31.0 | 142.7 |

These are simulation cycle counts, not AXI timing.

v25 adds AXI4-Lite control-wrapper simulation with `make sim-axi-lite`. The
AXI-Lite wrapper can program descriptor registers, access the forwarded core
region, start DMA, poll status, and read results while the data-moving memory
port remains the existing abstract ready/valid interface.

v26 adds done IRQ tests to both descriptor-wrapper and AXI-Lite wrapper
simulations. Error IRQ logic is present, but not stimulus-verified because the
current DMA wrapper has no normal memory-error source.

v27 adds real timeout/error stimulus. Descriptor-wrapper simulation verifies
memory timeout, core timeout, error code reporting, error IRQ clear behavior,
start blocked while error is sticky, and recovery after timeout. AXI-Lite
simulation verifies memory-timeout error IRQ behavior through the AXI-Lite
control path.

v28 adds AXI read-DMA wrapper simulation with `make sim-axi-read-dma`. It
verifies AXI read loading of A/B, abstract C store-back, AR backpressure,
delayed RVALID, RRESP error code `3`, timeout behavior, and done IRQ
assertion/clear. There is no AXI write master or burst support yet.

v29 adds full single-beat AXI DMA wrapper simulation with `make sim-axi-dma`.
It verifies AXI read loading of A/B, AXI write store-back of C, ARREADY
backpressure, delayed RVALID, AWREADY backpressure, WREADY backpressure,
delayed BVALID, RRESP error code `3`, BRESP error code `4`, read/write timeout
behavior, and done IRQ assertion/clear. Burst and multiple-outstanding AXI
behavior remain out of scope.

Relative values use the default `row4` variant as the baseline. Synthesis is
generic Yosys only, not technology-mapped PPA.

Coverage-style status means the simulation flow emitted
`build/sim/<variant>/coverage_summary.json` from observed passing scenario tests
and enabled checker status. It is scenario coverage, not full UVM-style
functional coverage.
