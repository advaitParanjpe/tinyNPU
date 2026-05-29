# tinyNPU DMA Descriptor Wrapper

`rtl/tinynpu_dma_descriptor_wrapper.sv` is an optional synthesizable APB-lite
wrapper that adds software-visible DMA descriptor registers around the existing
`tinynpu_apb_wrapper` core interface.

The wrapper stores descriptor registers and runs a small DMA-control FSM that
uses a simple abstract external memory port to load A/B data, launch the wrapped
tinyNPU core, and store C results. This is still not AXI and does not support
bursts or outstanding memory transactions.

v25 adds an optional AXI4-Lite control wrapper above this block. That wrapper
does not change this module's APB-style register interface or abstract memory
port; it only translates AXI4-Lite software accesses into descriptor-wrapper
register transactions. See `docs/axi_lite_wrapper.md`.

v28 adds `tinynpu_axi_read_dma_wrapper` as a separate optional wrapper that uses
AXI4 reads for A/B loads and an abstract write port for C stores. This
descriptor wrapper remains the APB-style abstract-memory implementation and is
kept intact.
v29 adds `tinynpu_axi_dma_wrapper` as a separate optional wrapper that uses AXI4
reads for A/B loads and AXI4 writes for C stores. This descriptor wrapper is
unchanged.

## External Memory Port

The wrapper exposes this single-beat ready/valid memory port:

| Signal | Direction | Description |
| --- | --- | --- |
| `mem_valid` | output | memory transaction request |
| `mem_we` | output | `0` read, `1` write |
| `mem_addr[31:0]` | output | external memory word address |
| `mem_wdata[31:0]` | output | write data for stores |
| `mem_rdata[31:0]` | input | read data for loads |
| `mem_ready` | input | transaction accepted/data valid |
| `irq` | output | descriptor done/error interrupt request |

`mem_valid` remains asserted until `mem_ready`. `mem_addr`, `mem_we`, and
`mem_wdata` remain stable while `mem_valid && !mem_ready`. For reads,
`mem_rdata` is sampled only when `mem_valid && mem_ready`. For writes,
`mem_wdata` is accepted only when `mem_valid && mem_ready`. There are no byte
strobes, bursts, outstanding transactions, or memory error responses.

## Address Map

| Address range | Behavior |
| --- | --- |
| `0x000`-`0x0ff` | Forwarded to `tinynpu_apb_wrapper` using `paddr[7:0]` |
| `0x100`-`0x120` | Handled by descriptor registers in this wrapper |

The wrapper uses a 12-bit APB address so descriptor registers can live above the
existing tinyNPU 8-bit APB address space.

## Descriptor Registers

| Address | Name | Description |
| --- | --- | --- |
| `0x100` | `DMA_CTRL` | bit 0: start; bit 1: clear_done; bit 2: clear_error |
| `0x104` | `DMA_STATUS` | bit 0: busy; bit 1: done; bit 2: error |
| `0x108` | `DMA_A_EXT_BASE` | external memory word address for A |
| `0x10c` | `DMA_B_EXT_BASE` | external memory word address for B |
| `0x110` | `DMA_C_EXT_BASE` | external memory word address for C |
| `0x114` | `DMA_CONFIG` | bits `[15:0]`: memory timeout cycles; bits `[31:16]`: core timeout cycles; zero fields select defaults |
| `0x118` | `DMA_ERROR_CODE` | `0`: no error; `1`: memory timeout; `2`: core timeout |
| `0x11c` | `DMA_IRQ_ENABLE` | bit 0: done IRQ enable; bit 1: error IRQ enable |
| `0x120` | `DMA_IRQ_STATUS` | bit 0: done IRQ pending; bit 1: error IRQ pending |

Invalid descriptor reads return `0`. Invalid descriptor writes are ignored.
Writes to `DMA_ERROR_CODE` and `DMA_IRQ_STATUS` are ignored. `pslverr` remains
`0`.

## Current Behavior

When software writes `DMA_CTRL.start` while idle, the wrapper starts this FSM:

```text
IDLE -> LOAD_A -> LOAD_B -> START_CORE -> WAIT_CORE -> STORE_C -> DONE
```

`LOAD_A` reads 16 words starting at `DMA_A_EXT_BASE` and writes each
`mem_rdata[7:0]` value into the tinyNPU A scratchpad. `LOAD_B` does the same for
`DMA_B_EXT_BASE` and the B scratchpad. `STORE_C` reads 16 signed int32 C result
words from the core and writes them to external memory starting at
`DMA_C_EXT_BASE`.

`START_CORE` issues an internal APB write to the wrapped core CTRL register.
`WAIT_CORE` issues internal APB reads to the wrapped core STATUS register until
core done is observed. `DONE` clears busy and sets sticky descriptor done.

A start write while busy is ignored and does not set error.

If `DMA_STATUS.error` is set, new starts are ignored until software writes
`DMA_CTRL.clear_error`. `DMA_CTRL.clear_done` clears sticky done.
`DMA_CTRL.clear_error` clears error, error IRQ pending, and `DMA_ERROR_CODE`.

## Timeout And Error Handling

v27 adds timeout/error handling:

- Memory timeout applies while `LOAD_A`, `LOAD_B`, or `STORE_C` waits for
  `mem_ready`.
- Core timeout applies while `WAIT_CORE` polls for wrapped-core done.
- On timeout, the wrapper aborts the operation, clears busy, sets sticky done,
  sets error, records `DMA_ERROR_CODE`, sets error IRQ pending, and returns to
  idle.

`DMA_CONFIG[15:0]` configures memory timeout cycles. `DMA_CONFIG[31:16]`
configures core timeout cycles. A zero field uses the default of 1024 cycles.
Reads of `DMA_STATUS`, `DMA_ERROR_CODE`, and `DMA_IRQ_STATUS` do not clear any
state.

## Interrupts

v26 adds an `irq` output for descriptor done/error events:

```text
irq = (DMA_IRQ_ENABLE.done && DMA_IRQ_STATUS.done_pending) ||
      (DMA_IRQ_ENABLE.error && DMA_IRQ_STATUS.error_pending)
```

`done_irq_pending` is set when the DMA FSM reaches normal done.
`error_irq_pending` is set on memory or core timeout. Done and error IRQ
behavior are both stimulus-verified.

Reset clears `DMA_IRQ_ENABLE`, IRQ pending bits, and `irq`. Reading
`DMA_IRQ_STATUS` does not clear pending bits. `DMA_IRQ_STATUS` writes are
ignored in v27. Software clears done pending with `DMA_CTRL.clear_done` and
clears error pending with `DMA_CTRL.clear_error`. Polling `DMA_STATUS` remains
supported.

Forwarded core reads preserve the one-wait-state read behavior of
`tinynpu_apb_wrapper` while the descriptor FSM is idle.

While the descriptor FSM is busy:

- descriptor-region accesses continue to work
- external core-window reads return `0`
- external core-window writes are ignored
- the internal FSM owns the wrapped core APB path

Descriptor-register accesses are ready in the APB access phase.

## Testbench Model vs Synthesizable Wrapper

- The DMA-style model in `tb/tb_tinynpu_apb_dma_model.sv` is testbench-only and
  performs simulated memory movement.
- The DMA descriptor wrapper is synthesizable RTL in
  `tinynpu_dma_descriptor_wrapper`.
- The DMA descriptor wrapper performs real movement over its abstract memory
  port, but it is not an AXI/AHB DMA engine.

## Backpressure Verification

`tb/tb_tinynpu_dma_descriptor_wrapper.sv` verifies the memory port in three
modes:

- always-ready memory
- fixed-latency memory
- deterministic random backpressure

The testbench also monitors that a stalled memory request keeps address,
direction, and write data stable until `mem_ready` completes the transaction.
The reusable simulation-only checker in `rtl/tinynpu_mem_port_assertions.sv` is
compiled under `TINYNPU_SIM_ASSERT` for this regression. It fails simulation if
`mem_valid` drops during a stall, if address/direction/write data change while
stalled, or if request signals contain X/Z values when active.

## Performance Reporting

`make sim-dma-desc` also emits DMA performance measurements by memory mode and
FSM phase. The runner writes `build/sim/dma_desc_wrapper/perf_summary.json` with
total cycles and average `LOAD_A`, `LOAD_B`, `START_CORE`, `WAIT_CORE`, and
`STORE_C` cycles for `always_ready`, `fixed_latency`, and
`random_backpressure`. Timeout/error tests are excluded from the normal
performance averages. These are simulation measurements over the abstract
memory port, not AXI timing.

## Future Path

- Replace the abstract memory port with a real SoC memory bus master.
- Add memory-bus error responses beyond timeout.
- Add burst transfers, byte strobes, memory error responses, and longer
  randomized backpressure regressions.
