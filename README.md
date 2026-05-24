# tinyNPU

tinyNPU v18 is a minimal SystemVerilog RTL scaffold for a fixed 4x4 signed int8
matrix multiply accelerator tile with a simple testbench-friendly register bus.

## Current Status

- Fixed 4x4 signed int8 matrix multiply: `C = A x B`, with signed int32 C results.
- Simple always-ready register bus with CTRL/STATUS, A/B scratchpads, and C result storage.
- Optional APB-lite-style wrapper around the existing simple-bus core.
- Optional synthesizable DMA descriptor wrapper around the APB core wrapper.
- DMA-style APB system simulation model with testbench-side descriptor registers.
- Default MAC variant is `row4`, a four-lane row MAC FSM.
- Selectable `serial`, `row4`, and `full16` MAC variants for area/latency comparison.
- Directed, edge-case, bus protocol, control/status, and deterministic random golden-model verification.
- Lightweight simulation assertions/checkers and bounded-latency checking.
- Coverage-style scenario reporting for tested functional/control/bus cases.
- Generic Yosys synthesis for all variants.
- Lightweight repository checks for commit readiness.
- `make compare` runs simulation, synthesis, and result capture for all variants.

## Requirements

- Python 3
- Icarus Verilog (`iverilog` and `vvp`) for simulation
- Yosys for synthesis
- `make`

## Run

```sh
make vectors
make check
make golden
make sim
make sim-apb
make sim-apb-dma
make sim-dma-desc
make synth
make synth-apb
make synth-dma-desc
make results
make sim-serial
make synth-serial
make results-serial
make sim-full16
make synth-full16
make results-full16
make compare
make precommit
```

The simulation builds under `build/` and writes a VCD waveform to
`build/tinynpu_top.vcd`.

`make sim` regenerates random vectors before compiling, using the default seed
and test count from `sim/run_sim.py`. It writes both `sim_summary.json` and
`coverage_summary.json` for the selected variant. `make compare` produces these
artifacts for `row4`, `serial`, and `full16`.

## Architecture

```text
testbench/Python vectors
        |
simple register bus
        |
tinynpu_top
  |-- CTRL/STATUS
  |-- A/B int8 scratchpads
  |-- MAC variant wrapper
  |     |-- serial / row4 / full16
  |-- C int32 result buffer
```

For each row, the MAC array clears four accumulators, broadcasts `A[row][k]`
across four lanes, multiplies by `B[k][0..3]`, accumulates for `k = 0..3`, and
writes the full C row. This `row4` variant is the default.

The `serial` variant computes one multiply-accumulate per cycle and is selected
only by compile-time define through the scripts. The public bus interface is the
same for all variants.

The `full16` variant updates all 16 C accumulators in parallel for each `k`,
then commits the full C matrix. It is an upper-parallelism baseline for the
fixed 4x4 design.

The A/B scratchpads and C result buffer are separate behavioral RTL modules.
They are still register-based storage, not SRAM macros.

There is no AXI, DMA data mover, SRAM macro, or real external memory interface
in v18. APB is available as an optional wrapper around the existing simple-bus
core. A second optional wrapper adds synthesizable descriptor registers at
`0x100`-`0x11f`, while forwarding `0x000`-`0x0ff` to the APB core wrapper. The
DMA-style flow still moves data only in simulation.

## Register Map

All matrix entries are row-major. `bus_ready` is always asserted. A transaction
occurs on a rising clock edge when `bus_valid && bus_ready`. Read data is a
registered response: `bus_rdata` updates after the accepted read edge and remains
stable until another read or reset.

| Address | Name | Description |
| --- | --- | --- |
| `0x00` | `CTRL` | bit 0: write `1` to start when not busy; bit 1: write `1` to clear sticky done |
| `0x04` | `STATUS` | bit 0: busy; bit 1: done |
| `0x10`-`0x4c` | `A[0]`-`A[15]` | one signed int8 per 32-bit word, stored in bits `[7:0]`; reads are sign-extended |
| `0x50`-`0x8c` | `B[0]`-`B[15]` | one signed int8 per 32-bit word, stored in bits `[7:0]`; reads are sign-extended |
| `0x90`-`0xcc` | `C[0]`-`C[15]` | signed int32 result words, read-only from the bus |

`STATUS.done` stays asserted after a completed operation until software writes
`CTRL.clear_done` or starts a new operation. C storage updates when the MAC array
finishes and remains readable until the next completed operation.

Additional bus/control behavior:

- `CTRL.start` is accepted only when the accelerator is not busy.
- Writes to `CTRL.start` while busy are ignored and do not restart or corrupt the in-flight operation.
- Undefined CTRL bits are ignored. Writing `start` and `clear_done` together while idle starts the operation and clears sticky done.
- Reset clears busy/done/control state and zeroes the internal A/B/C storage.
- Invalid or unmapped reads return `0`.
- Invalid or unmapped writes are ignored.
- Unaligned reads return `0`.
- Unaligned writes are ignored.

See `docs/bus_protocol.md` for the full simple bus contract.

## Random Vectors

Random tests are generated deterministically from a seed by
`model/golden_matmul.py`. The generated files are intentionally kept in the repo
for now because they are small and make the default regression visible:

- `tests/test_vectors/generated_matmul_tests.json`
- `tests/test_vectors/generated_matmul_tests.svh`

Generate the default 50-test set:

```sh
make vectors
```

Generate a custom set through the simulator wrapper:

```sh
python3 sim/run_sim.py --num-random-tests 100 --seed 7
```

The SystemVerilog testbench includes the generated `.svh` file and runs every
generated case through the same register bus path as the directed tests.

## Verification

The current self-checking Icarus simulation covers:

- directed functional tests: identity, zeros, ones, mixed signed values
- signed arithmetic edge cases: `127`, `-128`, alternating extremes, sparse nonzero
- control/status behavior: start while busy, sticky done, clear done, new start after done
- bus protocol behavior: always-ready signaling, A/B readback, C read-only storage, ignored CTRL bits, unaligned access handling
- focused APB wrapper tests for identity, mixed signed, invalid/unaligned access, C read-only behavior, start while busy, and reset
- synthesizable DMA descriptor-wrapper tests for descriptor read/write, status, and forwarded core access
- descriptor-driven DMA-style APB system-flow tests for external-memory load, compute, poll, and store-back behavior
- reset mid-operation recovery
- invalid bus read/write behavior
- 50 deterministic random golden-model tests by default
- lightweight checkers compiled with `-DTINYNPU_SIM_ASSERT`
- bounded operation latency with `MAX_OPERATION_CYCLES = 200`
- coverage-style scenario summaries emitted by `sim/run_sim.py`

`make sim` enables the checkers by default. The default `row4` regression
currently observes a 26-cycle accepted-start-to-done latency. The `serial`
baseline observes 66 cycles. The `full16` variant observes 8 cycles.

The simulation checkers cover:

- busy and done are mutually exclusive
- a start write while busy is not accepted
- every accepted start reaches done within the latency bound
- reset clears busy/done status
- C storage remains stable while done is sticky and no new start is accepted

## Synthesis

Run generic Yosys synthesis:

```sh
make synth
make synth-apb
make synth-dma-desc
make synth-serial
make synth-full16
```

Variant-specific outputs are written under:

- `build/synth/row4/`
- `build/synth/apb/`
- `build/synth/dma_desc/`
- `build/synth/serial/`
- `build/synth/full16/`

This is a generic Yosys synthesis check, not a technology-mapped PPA flow. It
does not use a standard-cell library, timing constraints, floorplanning, or
place-and-route yet.

## Development Checks

Run lightweight static repository checks:

```sh
make check
```

Run the longer commit-readiness flow:

```sh
make precommit
```

`make precommit` runs `make check`, `make golden`, `make compare`, APB wrapper
simulation/synthesis, descriptor-wrapper simulation/synthesis, and the
descriptor-driven APB DMA-style simulation model. See `docs/development.md` for
the recommended local workflow.

## Results Artifacts

Structured run artifacts are written under `build/`:

- `build/sim/sim_summary.json`
- `build/synth/synth_summary.json`
- `build/results/results_summary.json`

Variant-specific summaries are written under:

- `build/sim/row4/`, `build/sim/serial/`, and `build/sim/full16/`
- `build/synth/row4/`, `build/synth/serial/`, and `build/synth/full16/`
- `build/sim/apb/`, `build/sim/apb_dma/`, and `build/sim/dma_desc_wrapper/`
- `build/synth/apb/` and `build/synth/dma_desc/`

Each `build/sim/<variant>/` directory contains:

- `sim_summary.json`
- `coverage_summary.json`

`make results` records the default `row4` variant. `make results-serial` records
the serial baseline. `make results-full16` records the full16 variant.
`make compare` runs and records all three.
Human-readable notes live in:

- `docs/results.md`
- `docs/architecture_variants.md`
- `docs/coverage.md`
- `docs/bus_protocol.md`
- `docs/development.md`
- `docs/memory_architecture.md`
- `docs/apb_wrapper.md`
- `docs/dma_model.md`
- `docs/dma_descriptor_wrapper.md`
