# tinyNPU Roadmap

## Completed

- Fixed 4x4 signed int8 matrix multiply core.
- Simple register bus with CTRL/STATUS and A/B/C storage.
- MAC variants: `serial`, `row4`, and `full16`.
- APB-lite-style wrapper around the core.
- Synthesizable DMA descriptor wrapper with DMA-control FSM skeleton.
- Testbench-only DMA-style external-memory movement model.
- Directed, edge, bus, APB, descriptor, random, and checker-based simulation.
- Generic Yosys synthesis and structured result summaries.

## Next

- Real DMA data mover RTL behind the descriptor FSM.
- Memory latency model for system-level simulation.
- Optional AXI/AHB memory interface.
- Descriptor-driven hardware load/store sequence.
- Technology-mapped synthesis setup and initial timing/PPA estimates.

## Later

- Interrupt/status/error refinement.
- Burst transfers and backpressure handling.
- SRAM macro integration.
- Formal checks for control/status behavior.
- Functional coverage with a simulator that supports it.
- Optional OpenROAD flow.
