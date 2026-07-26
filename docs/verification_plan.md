# tinyNPU Verification Plan

## Tested Now

- 4x4 signed int8 matrix multiply through the public register bus
- A/B scratchpad readback and C result-buffer readback through the bus
- Serial, row4, row4_pipe, row4_pipe2, systolic4x4, and full16 MAC datapaths
  with fixed row-major C output ordering
- Directed functional cases: identity, all zeros, all ones, mixed signed values
- Signed arithmetic edge cases: max positive, min negative times positive, alternating extremes, sparse single nonzero
- Control/status behavior: start while busy, sticky done, clear done, new start after done
- Simple bus protocol behavior: always-ready response, A/B readback,
  C read-only storage, ignored CTRL bits, invalid access handling, and unaligned
  access handling
- Focused APB wrapper behavior: identity, mixed signed, invalid/unaligned
  access, C read-only behavior, start while busy, and reset
- Synthesizable DMA descriptor-wrapper behavior: descriptor register read/write,
  FSM start/done/clear, abstract-memory load of A/B, FSM-launched core
  computation, C store-back to abstract memory, start while busy, external
  core-window blocking while busy, invalid descriptor access, and forwarded core
  identity/invalid access behavior
- DMA memory-port behavior: always-ready, fixed-latency, and deterministic
  random-backpressure operation, plus request stability while stalled
- DMA descriptor-wrapper performance reporting by memory mode and FSM phase
- AXI4-Lite control-wrapper behavior: descriptor register programming, forwarded
  core identity, descriptor-programmed DMA identity/mixed-signed operation,
  AXI-Lite channel stalls, invalid/unaligned access, and full-word-only WSTRB
  handling
- Descriptor-wrapper and AXI-Lite done IRQ behavior: disabled IRQ stays low,
  done IRQ pending is reported, enabling after done asserts IRQ, and
  `DMA_CTRL.clear_done` clears pending/IRQ
- DMA timeout/error behavior: memory timeout, core timeout, `DMA_ERROR_CODE`,
  error IRQ assertion/clear, start blocked while error is sticky, and recovery
  after timeout
- AXI read-DMA behavior: AXI single-beat reads for A/B loads, abstract C
  store-back, AR backpressure, delayed RVALID, RRESP error code reporting,
  timeout handling, and done IRQ behavior
- AXI DMA behavior: AXI single-beat reads for A/B loads, AXI single-beat writes
  for C stores, AR/RVALID and AW/W/B backpressure, RRESP/BRESP error code
  reporting, read/write timeout handling, and done IRQ behavior
- Descriptor-driven DMA-style APB system-flow behavior: descriptor programming,
  external-memory load of A/B, accelerator start, STATUS.done polling,
  C store-back, back-to-back operations, start while descriptor model is busy,
  invalid descriptor access, and unchanged unrelated external-memory regions
- Reset behavior, including reset during an active operation
- Invalid bus behavior: unmapped reads return zero and unmapped writes are ignored
- Deterministic random golden-model tests generated from a seed
- Lightweight simulation checkers enabled by `TINYNPU_SIM_ASSERT`
- Bounded latency from accepted start to done
- Coverage-style scenario summaries generated from observed passing tests

## Assertions and Checkers

- Busy/done mutual exclusion
- Start writes while busy are ignored
- Accepted starts must reach done within 200 cycles
- Reset clears busy/done status
- C output storage remains stable while done is sticky and no new start occurs
- DMA memory-port `mem_valid`, `mem_we`, and `mem_addr` are known when active
- DMA memory-port requests remain asserted and stable while stalled
- Testbench latency accounting reports accepted-start-to-done latency
- Current observed max latencies are 66 cycles for `serial`, 26 cycles for
  `row4`, 42 cycles for `row4_pipe`, 58 cycles for `row4_pipe2`, 17 cycles for
  `systolic4x4`, and 8 cycles for `full16`, bounded by a 200-cycle checker. The
  pipelined row4 and systolic variants use explicit pipeline cuts to shorten
  ASIC timing paths.

## Coverage-Style Reporting

- `sim/run_sim.py` writes `build/sim/<variant>/coverage_summary.json`
- The summary records functional, arithmetic edge, control/status, bus, random,
  and checker scenarios observed in the regression
- This is scenario coverage, not full functional coverage with covergroups

## Not Tested Yet

- Functional coverage metrics
- Full APB protocol coverage
- Full AXI/AHB protocol coverage
- Burst transfers and multiple outstanding memory transactions
- Memory bus error responses beyond AXI RRESP/BRESP and timeout
- Longer memory-port backpressure seed sweeps
- Randomized bus timing with backpressure, since `bus_ready` is currently always high
- Larger matrix sizes or configurable dimensions
- Exhaustive signed int8 operand coverage
- SRAM macro behavior or memory timing
- Formal checks
- Assertion coverage

## Future Ideas

- Add coverage bins for operand extremes, status transitions, and address regions
- Add constrained-random bus transactions around valid and invalid addresses
- Add formal verification for control/status invariants
- Add assertion coverage reporting under a simulator that supports it
- Add regression seeds and a small seed sweep target
- Extend the golden-model flow when larger matrix sizes are introduced
