# tinyNPU

tinyNPU v29 is a minimal SystemVerilog RTL scaffold for a fixed 4x4 signed int8
matrix multiply accelerator tile with a simple testbench-friendly register bus.

## Current Status

- Fixed 4x4 signed int8 matrix multiply: `C = A x B`, with signed int32 C results.
- Simple always-ready register bus with CTRL/STATUS, A/B scratchpads, and C result storage.
- Optional APB-lite-style wrapper around the existing simple-bus core.
- Optional synthesizable DMA descriptor wrapper with a DMA-control FSM and abstract external memory port.
- Optional AXI4-Lite control wrapper around the DMA descriptor wrapper.
- Optional AXI read-DMA wrapper with AXI4-Lite control, single-beat AXI reads
  for A/B loads, and an abstract write port for C stores.
- Optional full single-beat AXI DMA wrapper with AXI4-Lite control, AXI reads
  for A/B loads, and AXI writes for C stores.
- DMA done IRQ support on the descriptor wrapper and AXI4-Lite wrapper.
- DMA-style model with testbench-only descriptor registers and memory movement.
- Default MAC variant is `row4`, an unpipelined four-lane row MAC FSM.
- Selectable `serial`, `row4`, `row4_pipe`, `row4_pipe2`, and `full16` MAC
  variants for area/latency/timing-oriented comparison.
- Directed, edge-case, bus protocol, control/status, and deterministic random golden-model verification.
- Lightweight simulation assertions/checkers and bounded-latency checking.
- Coverage-style scenario reporting for tested functional/control/bus cases.
- DMA memory-port fixed-latency and deterministic backpressure testing.
- Reusable simulation-only memory-port assertions for the abstract DMA memory port.
- DMA descriptor-wrapper performance reporting by memory mode and FSM phase.
- DMA memory/core timeout handling with error codes and error IRQ verification.
- AXI read-DMA verification for AR backpressure, delayed RVALID, RRESP errors,
  timeout handling, and done IRQ behavior.
- AXI DMA verification for AR/RVALID and AW/W/B backpressure, RRESP/BRESP
  errors, read/write timeouts, and done IRQ behavior.
- Generic Yosys synthesis for all variants.
- ASIC-style OpenLane 2/SKY130 flow results for the row4 `tinynpu_top` core,
  including generated GDS/DEF/netlist artifacts and captured DRC/LVS/timing
  metrics.
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
make sim-axi-lite
make sim-axi-read-dma
make sim-axi-dma
make synth
make synth-apb
make synth-dma-desc
make synth-axi-lite
make synth-axi-read-dma
make synth-axi-dma
make results
make sim-serial
make synth-serial
make results-serial
make sim-row4-pipe
make synth-row4-pipe
make sim-row4-pipe2
make synth-row4-pipe2
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

## ASIC-Style Flow Results

The completed Dockerized OpenLane 2 run for the row4 `tinynpu_top` core is
summarized in [docs/asic_flow_results.md](docs/asic_flow_results.md). The
captured runs produced final GDS/DEF/netlist artifacts and reported clean
DRC/LVS for the documented row4, row4_pipe, and row4_pipe2 targets, while
timing and electrical closure issues remain. The same page also records a
controlled clock sweep; 50 MHz closes setup for the original row4 RTL in this
flow, but no swept target is signoff clean. This is a local ASIC-style
RTL-to-GDS flow result, not a shuttle/fab submission or signoff-clean claim.

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
  |     |-- serial / row4 / row4_pipe / row4_pipe2 / full16
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

There is no SRAM macro, burst engine, or outstanding memory transaction support
in v29. APB is available as an optional wrapper around the existing simple-bus
core. A second optional wrapper adds
synthesizable descriptor registers at `0x100`-`0x120`, while forwarding
`0x000`-`0x0ff` to the APB core wrapper. Its DMA-control FSM runs
`LOAD_A -> LOAD_B -> START_CORE -> WAIT_CORE -> STORE_C` and moves matrix data
over a simple single-beat ready/valid memory port. This memory port is an
abstract integration step, not AXI. `mem_valid` remains asserted until
`mem_ready`, and `mem_addr`, `mem_we`, and write data remain stable while a
request is stalled.

v25 adds `tinynpu_axi_lite_wrapper`, an optional AXI4-Lite slave for software
control only. It translates AXI4-Lite register accesses into the descriptor
wrapper's APB-style interface and passes the abstract memory port through
unchanged. The wrapper supports one outstanding read and one outstanding write,
returns OKAY responses, has no bursts or IDs, and ignores partial writes unless
`WSTRB == 4'b1111`.

v26 added an `irq` output to `tinynpu_dma_descriptor_wrapper` and passes it
through `tinynpu_axi_lite_wrapper`. v27 adds real timeout/error handling:
`DMA_ERROR_CODE` reports memory timeout (`1`) or core timeout (`2`), and
`DMA_CONFIG[15:0]` / `DMA_CONFIG[31:16]` configure memory/core timeout cycles
with zero selecting defaults. Error IRQ behavior is now stimulus-verified.
Polling `DMA_STATUS` is unchanged.

v28 adds `tinynpu_axi_read_dma_wrapper`, an optional AXI4-Lite controlled wrapper
with an AXI4 read master for A/B loads. It uses single-beat reads only
(`ARLEN = 0`) and converts descriptor word addresses to AXI byte addresses with
`<< 2`. C stores still use a separate abstract write port. RRESP errors report
`DMA_ERROR_CODE = 3`; handshake timeouts use error code `1`. There is still no
AXI write master and no burst support.

v29 adds `tinynpu_axi_dma_wrapper`, an optional full single-beat AXI DMA wrapper.
It keeps AXI4-Lite descriptor control, uses AXI reads for A/B loads, and uses
AXI writes for C stores. Writes are sequenced as AW, W, then B with `AWLEN = 0`,
`AWSIZE = 3'b010`, `WSTRB = 4'b1111`, and `WLAST = 1`. BRESP errors report
`DMA_ERROR_CODE = 4`. There is still no burst support and no multiple
outstanding AXI transactions.

## Full AXI DMA Milestone

`tinynpu_axi_dma_wrapper` is the top-level full-DMA integration wrapper for the
current project freeze. It combines AXI4-Lite descriptor/control registers,
single-beat AXI4 reads for A/B loads, single-beat AXI4 writes for C result
stores, descriptor done/error status, configurable memory/core timeouts, and a
combined done/error `irq` output.

The full-DMA milestone is intentionally scoped to one transaction at a time:
each A/B element is loaded by one AXI read, each C element is stored by one AXI
write, and there are no bursts, IDs, or multiple outstanding transactions. This
is the integration point to freeze before moving focus to ASIC flow work.

## Design Layers

The repo separates synthesizable RTL from optional wrappers and testbench-only
models:

- MAC datapaths and `tinynpu_top` are synthesizable accelerator RTL.
- `tinynpu_apb_wrapper` is a synthesizable APB-lite-style adapter.
- `tinynpu_dma_descriptor_wrapper` is a synthesizable descriptor/status wrapper with a DMA-control FSM and abstract memory port.
- `tinynpu_axi_lite_wrapper` is a synthesizable AXI4-Lite control wrapper around the DMA descriptor wrapper.
- `tinynpu_axi_read_dma_wrapper` is a synthesizable AXI4-Lite controlled wrapper with an AXI read master for A/B loads and an abstract C write port.
- `tinynpu_axi_dma_wrapper` is a synthesizable full single-beat AXI DMA wrapper with AXI reads for A/B and AXI writes for C.
- `tb/tb_tinynpu_apb_dma_model.sv` is a testbench-only DMA-style model.

See `docs/design_layers.md` and `docs/source_manifest.md` for the full layer and
source breakdown.

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
- synthesizable DMA descriptor-wrapper tests for descriptor read/write, DMA memory movement, core launch, busy core-window blocking, and forwarded core access
- AXI4-Lite control-wrapper tests for descriptor programming, forwarded core access, DMA launch/polling, channel stalls, invalid/unaligned access, and WSTRB behavior
- AXI read-DMA wrapper tests for AXI A/B loads, abstract C stores, AR backpressure, delayed RVALID, RRESP errors, timeout handling, and done IRQ behavior
- AXI DMA wrapper tests for AXI A/B loads, AXI C stores, AR/RVALID and AW/W/B backpressure, RRESP/BRESP errors, read/write timeout handling, and done IRQ behavior
- descriptor-wrapper and AXI-Lite done IRQ assertion, pending status, clear behavior, and disabled-IRQ behavior
- descriptor-wrapper memory/core timeout handling, error code reporting, error IRQ assertion/clear, and recovery after timeout
- fixed-latency and deterministic random-backpressure tests for the descriptor wrapper memory port
- reusable memory-port assertions for valid hold, stable stalled requests, and X/Z checks
- descriptor-wrapper DMA performance reporting for `always_ready`, `fixed_latency`, and `random_backpressure` memory modes
- descriptor-driven DMA-style APB system-flow tests for external-memory load, compute, poll, and store-back behavior
- reset mid-operation recovery
- invalid bus read/write behavior
- 50 deterministic random golden-model tests by default
- lightweight checkers compiled with `-DTINYNPU_SIM_ASSERT`
- bounded operation latency with `MAX_OPERATION_CYCLES = 200`
- coverage-style scenario summaries emitted by `sim/run_sim.py`
- descriptor-wrapper performance summaries emitted by `sim/run_dma_descriptor_wrapper_sim.py`

`make sim` enables the checkers by default. The default `row4` regression
currently observes a 26-cycle accepted-start-to-done latency. The `serial`
baseline observes 66 cycles. The timing-oriented `row4_pipe` variant observes
42 cycles, and `row4_pipe2` observes 58 cycles. The `full16` variant observes 8
cycles.

The simulation checkers cover:

- busy and done are mutually exclusive
- a start write while busy is not accepted
- every accepted start reaches done within the latency bound
- reset clears busy/done status
- C storage remains stable while done is sticky and no new start is accepted
- DMA memory-port requests remain valid and stable while stalled

## Synthesis

Run generic Yosys synthesis:

```sh
make synth
make synth-apb
make synth-dma-desc
make synth-axi-lite
make synth-axi-read-dma
make synth-axi-dma
make synth-serial
make synth-row4-pipe
make synth-row4-pipe2
make synth-full16
```

Variant-specific outputs are written under:

- `build/synth/row4/`
- `build/synth/apb/`
- `build/synth/dma_desc/`
- `build/synth/axi_lite/`
- `build/synth/axi_read_dma/`
- `build/synth/axi_dma/`
- `build/synth/serial/`
- `build/synth/row4_pipe/`
- `build/synth/row4_pipe2/`
- `build/synth/full16/`

This is a generic Yosys synthesis check, not a technology-mapped PPA flow. It
does not use a standard-cell library, timing constraints, floorplanning, or
place-and-route yet.

## Development Checks

Run lightweight static repository checks:

```sh
make check
```

Validate the ASIC-flow scaffold without launching physical design:

```sh
make asic-check
```

Run the longer commit-readiness flow:

```sh
make precommit
```

`make precommit` runs `make check`, `make golden`, `make compare`, APB wrapper
simulation/synthesis, descriptor-wrapper simulation/synthesis, AXI-Lite,
AXI read-DMA, and full AXI DMA simulation/synthesis, and the descriptor-driven
APB DMA-style simulation model. See `docs/development.md` for the recommended
local workflow.

## Results Artifacts

Structured run artifacts are written under `build/`:

- `build/sim/sim_summary.json`
- `build/synth/synth_summary.json`
- `build/results/results_summary.json`

Variant-specific summaries are written under:

- `build/sim/row4/`, `build/sim/serial/`, and `build/sim/full16/`
- `build/synth/row4/`, `build/synth/serial/`, and `build/synth/full16/`
- `build/sim/apb/`, `build/sim/apb_dma/`, and `build/sim/dma_desc_wrapper/`
- `build/sim/axi_lite/`, `build/sim/axi_read_dma/`, and `build/sim/axi_dma/`
- `build/synth/apb/`, `build/synth/dma_desc/`, `build/synth/axi_lite/`,
  `build/synth/axi_read_dma/`, and `build/synth/axi_dma/`

Each `build/sim/<variant>/` directory contains:

- `sim_summary.json`
- `coverage_summary.json`

`make results` records the default `row4` variant. `make results-serial` records
the serial baseline. `make results-full16` records the full16 variant.
`make compare` runs and records all three.
Human-readable notes live in:

- `docs/results.md`
- `docs/design_layers.md`
- `docs/source_manifest.md`
- `docs/roadmap.md`
- `docs/architecture_variants.md`
- `docs/coverage.md`
- `docs/performance.md`
- `docs/asic_flow_plan.md`
- `docs/bus_protocol.md`
- `docs/development.md`
- `docs/memory_architecture.md`
- `docs/apb_wrapper.md`
- `docs/dma_model.md`
- `docs/dma_descriptor_wrapper.md`
