# tinyNPU Verification Plan

## Tested Now

- 4x4 signed int8 matrix multiply through the public register bus
- A/B scratchpad readback and C result-buffer readback through the bus
- Serial, row4, and full16 MAC datapaths with fixed row-major C output ordering
- Directed functional cases: identity, all zeros, all ones, mixed signed values
- Signed arithmetic edge cases: max positive, min negative times positive, alternating extremes, sparse single nonzero
- Control/status behavior: start while busy, sticky done, clear done, new start after done
- Simple bus protocol behavior: always-ready response, A/B readback,
  C read-only storage, ignored CTRL bits, invalid access handling, and unaligned
  access handling
- Focused APB wrapper behavior: identity, mixed signed, invalid/unaligned
  access, C read-only behavior, start while busy, and reset
- DMA-style APB system-flow behavior: external-memory load of A/B, accelerator
  start, STATUS.done polling, C store-back, back-to-back operations, and
  unchanged unrelated external-memory regions
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
- Testbench latency accounting reports accepted-start-to-done latency
- Current observed max latencies are 66 cycles for `serial`, 26 cycles for
  `row4`, and 8 cycles for `full16`, bounded by a 200-cycle checker

## Coverage-Style Reporting

- `sim/run_sim.py` writes `build/sim/<variant>/coverage_summary.json`
- The summary records functional, arithmetic edge, control/status, bus, random,
  and checker scenarios observed in the regression
- This is scenario coverage, not full functional coverage with covergroups

## Not Tested Yet

- Functional coverage metrics
- Full APB protocol coverage
- Real DMA RTL behavior or descriptor programming
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
