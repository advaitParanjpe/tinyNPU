# tinyNPU DMA Descriptor Wrapper

`rtl/tinynpu_dma_descriptor_wrapper.sv` is an optional synthesizable APB-lite
wrapper that adds software-visible DMA descriptor registers around the existing
`tinynpu_apb_wrapper` core interface.

The wrapper stores descriptor registers and runs a small DMA-control FSM that
uses a simple abstract external memory port to load A/B data, launch the wrapped
tinyNPU core, and store C results. This is still not AXI and does not support
bursts or outstanding memory transactions.

## External Memory Port

The v21 wrapper adds this single-beat ready/valid memory port:

| Signal | Direction | Description |
| --- | --- | --- |
| `mem_valid` | output | memory transaction request |
| `mem_we` | output | `0` read, `1` write |
| `mem_addr[31:0]` | output | external memory word address |
| `mem_wdata[31:0]` | output | write data for stores |
| `mem_rdata[31:0]` | input | read data for loads |
| `mem_ready` | input | transaction accepted/data valid |

For reads, `mem_rdata` is sampled when `mem_valid && mem_ready`. For writes,
`mem_wdata` is accepted when `mem_valid && mem_ready`. There are no byte
strobes, bursts, outstanding transactions, or memory error responses.

## Address Map

| Address range | Behavior |
| --- | --- |
| `0x000`-`0x0ff` | Forwarded to `tinynpu_apb_wrapper` using `paddr[7:0]` |
| `0x100`-`0x11f` | Handled by descriptor registers in this wrapper |

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
| `0x114` | `DMA_CONFIG` | reserved configuration register |

Invalid descriptor reads return `0`. Invalid descriptor writes are ignored.
`pslverr` remains `0`.

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

`DMA_CTRL.clear_done` clears sticky done. `DMA_CTRL.clear_error` clears error.
The current wrapper does not raise error internally.

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

## Future Path

- Replace the abstract memory port with a real SoC memory bus master.
- Add interrupt/status/error handling.
- Add burst transfers, byte strobes, memory error responses, and richer
  backpressure tests.
