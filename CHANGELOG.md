# Changelog

## v29

- Added optional `tinynpu_axi_dma_wrapper`.
- Added AXI4 write master support for C result stores.
- Completed the single-beat AXI DMA path: AXI reads load A/B and AXI writes
  store C.
- Added AXI DMA simulation for identity, mixed signed, AWREADY backpressure,
  WREADY backpressure, delayed BVALID, BRESP error, write timeout, and done IRQ
  behavior.
- Added `make sim-axi-dma` and `make synth-axi-dma`.
- Kept bursts, IDs, multiple outstanding transactions, MAC changes, and
  core/APB wrapper port changes out of scope.

## v28

- Added optional `tinynpu_axi_read_dma_wrapper`.
- Added AXI4-Lite control plus single-beat AXI4 read master loads for A/B.
- Kept C result stores on a separate abstract write port.
- Added AXI read-DMA simulation for identity, mixed signed, AR backpressure,
  delayed RVALID, RRESP error, timeout, and done IRQ behavior.
- Added `make sim-axi-read-dma` and `make synth-axi-read-dma`.
- Kept the existing descriptor wrapper, AXI-Lite control wrapper, core/APB
  wrappers, MAC variants, and v27 flows intact.
- Kept AXI write master, bursts, IDs, and multiple outstanding transactions out
  of scope.

## v27

- Added `DMA_ERROR_CODE` with memory timeout and core timeout error codes.
- Added configurable memory/core timeout fields in `DMA_CONFIG`.
- Added DMA abort/error behavior for stalled memory transactions and stuck core
  completion waits.
- Verified error IRQ assertion/clear, error code readback, start blocked while
  error is sticky, and recovery after timeout.
- Added AXI-Lite-level error IRQ coverage through a memory-timeout stimulus.
- Kept full AXI memory master, bursts, MAC changes, and core/APB wrapper port
  changes out of scope.

## v26

- Added descriptor done/error IRQ enable and pending registers to
  `tinynpu_dma_descriptor_wrapper`.
- Added an `irq` output to `tinynpu_dma_descriptor_wrapper` and passed it
  through `tinynpu_axi_lite_wrapper`.
- Added descriptor-wrapper and AXI-Lite tests for done IRQ assertion, pending
  status, clear behavior, disabled IRQ behavior, and enable-after-done behavior.
- Kept polling through `DMA_STATUS` supported.
- Kept full AXI memory master, bursts, MAC changes, and core/APB wrapper port
  changes out of scope.

## v25

- Added optional `tinynpu_axi_lite_wrapper` for AXI4-Lite control-plane access
  to the existing DMA descriptor wrapper.
- Added AXI-Lite simulation covering descriptor register read/write, forwarded
  core access, DMA launch/polling, channel stalls, invalid/unaligned access,
  and full-word-only `WSTRB` behavior.
- Added `make sim-axi-lite` and `make synth-axi-lite`.
- Kept `tinynpu_top`, `tinynpu_apb_wrapper`, MAC variants, APB support, and the
  abstract DMA memory port unchanged.
- Kept full AXI memory master, bursts, IDs, and multiple outstanding
  transactions out of scope.

## v24

- Added DMA descriptor-wrapper performance measurement in simulation.
- Reported total DMA cycles and per-phase cycles for `LOAD_A`, `LOAD_B`,
  `START_CORE`, `WAIT_CORE`, and `STORE_C`.
- Added `build/sim/dma_desc_wrapper/perf_summary.json` generation.
- Kept RTL, public interfaces, MAC variants, and synthesis results unchanged.

## v23

- Added reusable simulation-only `tinynpu_mem_port_assertions` for the abstract
  DMA memory port.
- Connected the checker to the DMA descriptor-wrapper regression under
  `TINYNPU_SIM_ASSERT`.
- Kept the v22 fixed-latency and deterministic random-backpressure tests.
- Kept AXI and synthesis-visible behavior unchanged.

## v22

- Added fixed-latency and deterministic random-backpressure modes to the DMA
  descriptor-wrapper memory model.
- Added memory-port protocol stability checking for stalled transactions.
- Added descriptor-wrapper regression cases for fixed-latency identity/mixed
  signed operations and random-backpressure identity/back-to-back operations.
- Kept AXI, bursts, outstanding transactions, and memory error responses out of
  scope.

## v21

- Added a simple word-addressed ready/valid external memory port to
  `tinynpu_dma_descriptor_wrapper`.
- Updated the descriptor-wrapper FSM so `LOAD_A`, `LOAD_B`, and `STORE_C`
  perform real data movement through the abstract memory port.
- Added descriptor-wrapper tests for end-to-end external memory to A/B
  scratchpads to core compute to external memory C store-back.
- Kept AXI, bursts, outstanding transactions, and memory error responses out of
  scope.

## v20

- Replaced descriptor-wrapper status-only start behavior with a synthesizable
  DMA-control FSM skeleton.
- Added internal FSM launch/poll of the wrapped tinyNPU core.
- Added descriptor-wrapper tests for FSM done, core launch, and blocked
  external core-window access while DMA is busy.

## v19

- Added design-layer documentation separating synthesizable RTL, optional
  wrappers, and testbench-only DMA-style models.
- Added a source manifest and concise roadmap.
- Added `make help` target for common development, simulation, and synthesis
  commands.

## v18

- Added optional synthesizable `tinynpu_dma_descriptor_wrapper`.
- Added descriptor-wrapper simulation and generic Yosys synthesis targets.
- Kept DMA memory movement out of RTL; descriptor start only updates
  descriptor status for now.

## v17

- Added simulation-only DMA descriptor registers to the APB DMA-model flow.
- Updated `make sim-apb-dma` to exercise descriptor-driven load, compute,
  poll, and store-back behavior.
- Kept descriptor registers out of synthesizable RTL.

## v16

- Added a DMA-style APB system simulation model using testbench external memory.
- Added `make sim-apb-dma` and a structured APB DMA-model simulation summary.
- Documented that this is not synthesizable DMA RTL.

## v15

- Added optional APB-lite-style wrapper around `tinynpu_top`.
- Added focused APB wrapper simulation and generic Yosys synthesis targets.

## v14

- Refactored A/B matrix storage into reusable int8 scratchpad modules.
- Refactored C result storage into a reusable int32 result-buffer module.
- Preserved the public bus interface, address map, and MAC variant behavior.

## v13

- Added `scripts/check_repo.py` for lightweight repository quality checks.
- Added `make check`, `make precommit`, and development workflow docs.

## v12

- Documented the simple register bus protocol.
- Added bus protocol tests for always-ready behavior, A/B readback, C read-only
  storage, ignored CTRL bits, and unaligned accesses.

## v11

- Added coverage-style scenario reporting from simulation output.
- Added per-variant `coverage_summary.json` artifacts and coverage documentation.

## v10

- Cleanup, reproducibility, and commit-readiness pass.
- Confirmed clean rebuild through `make clean`, `make golden`, and `make compare`.

## v9

- Added `full16`, a 16-output full-parallel MAC variant.
- Extended simulation, synthesis, and result flows to compare `serial`, `row4`, and `full16`.

## v8

- Added architecture variant framework.
- Added `serial` MAC baseline while keeping `row4` as the default.

## v7

- Added structured simulation, synthesis, and result summaries.
- Added result snapshot tooling and architecture variant documentation.

## v6

- Added generic Yosys synthesis flow and synthesis report parsing.

## v5

- Replaced the serial-style default datapath with the four-lane `row4` MAC.

## v4

- Added lightweight simulation checkers and latency measurement.

## v3

- Added control/status, reset, invalid access, and signed arithmetic edge-case tests.

## v2

- Added deterministic random golden-model test vector generation.

## v1

- Added simple register bus, CTRL/STATUS, and A/B/C storage around the MAC array.

## v0

- Created fixed 4x4 signed int8 matrix multiply RTL, Python golden model, and self-checking simulation.
