# Changelog

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
