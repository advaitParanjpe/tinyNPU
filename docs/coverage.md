# tinyNPU Coverage-Style Reporting

tinyNPU uses lightweight scenario coverage reporting. This is not full
functional coverage with covergroups or a UVM environment. The simulator wrapper
parses observed passing test names and checker status, then writes a structured
JSON summary.

## Generated Artifacts

Run one variant:

```sh
make sim
```

Run all variants:

```sh
make compare
```

Coverage summaries are written to:

- `build/sim/row4/coverage_summary.json`
- `build/sim/serial/coverage_summary.json`
- `build/sim/full16/coverage_summary.json`

The selected variant's `sim_summary.json` also records the coverage summary
path, number of passed coverage categories, and known gap count.

## Covered Now

- Functional scenarios: identity, all zeros, all ones, mixed signed values.
- Arithmetic edge cases: max positive, min negative times positive,
  alternating extremes, sparse single nonzero.
- Control/status scenarios: back-to-back operations, start while busy, sticky
  done and clear, new start after done, reset mid-operation.
- Bus behavior: invalid accesses, always-ready signaling, A/B readback, C
  read-only storage, ignored CTRL bits, and unaligned address handling.
- Random testing: deterministic golden-model vectors, 50 tests by default.
- Checker suite: busy/done mutex, start ignored while busy, bounded done after
  start, reset clears status, C stable while done is sticky.
- Variant regression: `serial`, `row4`, and `full16` through `make compare`.
- APB DMA-style descriptor-flow smoke tests through `make sim-apb-dma`.
- Synthesizable DMA descriptor-wrapper smoke tests through `make sim-dma-desc`,
  including `desc_fsm_start_done`, `desc_dma_identity`,
  `desc_dma_mixed_signed`, `desc_dma_back_to_back`,
  `desc_dma_core_window_blocked_while_busy`, and
  `desc_dma_memory_unchanged`.
- DMA memory-port backpressure smoke tests through `make sim-dma-desc`,
  including fixed-latency memory, deterministic random backpressure, and
  stalled-request stability checking.
- Descriptor-wrapper done IRQ smoke tests through `make sim-dma-desc`,
  including disabled IRQ behavior, done pending, enable-after-done, and
  clear-done behavior.
- AXI-Lite done IRQ smoke tests through `make sim-axi-lite`.
- Descriptor-wrapper timeout/error tests through `make sim-dma-desc`, including
  memory timeout, core timeout, error IRQ, error code readback, start blocked
  while error is sticky, and recovery.
- AXI-Lite memory-timeout error IRQ smoke test through `make sim-axi-lite`.
- Reusable memory-port assertions are compiled into `make sim-dma-desc` with
  `TINYNPU_SIM_ASSERT`.
- DMA descriptor-wrapper performance reporting emits per-mode cycle summaries
  from `make sim-dma-desc`.

## Known Gaps

- No full AXI/APB protocol coverage yet.
- No AXI/AHB DMA protocol coverage yet.
- No SRAM macro or memory timing coverage yet.
- No formal proof yet.
- Only fixed 4x4 matrix size currently tested.
- No memory-bus error response coverage beyond timeout.
