# tinyNPU Roadmap

## Completed

- Fixed 4x4 signed int8 matrix multiply core.
- Simple register bus with CTRL/STATUS and A/B/C storage.
- MAC variants: `serial`, `row4`, and `full16`.
- APB-lite-style wrapper around the core.
- Synthesizable DMA descriptor wrapper with DMA FSM and abstract memory port.
- Optional AXI4-Lite control wrapper around the DMA descriptor wrapper.
- Optional AXI read-DMA wrapper for single-beat A/B loads.
- Descriptor done IRQ support on the descriptor and AXI-Lite wrappers.
- DMA memory/core timeout handling, error codes, and error IRQ verification.
- Fixed-latency and deterministic backpressure tests for the abstract memory port.
- Reusable simulation-only checker for the abstract memory port.
- Testbench-only DMA-style external-memory movement model.
- Directed, edge, bus, APB, descriptor, random, and checker-based simulation.
- Generic Yosys synthesis and structured result summaries.

## Next

- Memory latency model for system-level simulation.
- AXI write master for C result stores.
- Burst transfers for AXI A/B loads and C stores.
- Memory error-response model beyond timeout for the abstract memory port.
- Technology-mapped synthesis setup and initial timing/PPA estimates.

## Later

- Broader interrupt/status refinement.
- Full memory-bus backpressure and outstanding-transaction handling.
- SRAM macro integration.
- Formal checks for control/status behavior.
- Functional coverage with a simulator that supports it.
- Optional OpenROAD flow.
