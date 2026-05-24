# tinyNPU DMA Descriptor Wrapper

`rtl/tinynpu_dma_descriptor_wrapper.sv` is an optional synthesizable APB-lite
wrapper that adds software-visible DMA descriptor registers around the existing
`tinynpu_apb_wrapper` core interface.

This is not a real DMA data mover yet. The wrapper stores descriptor registers
and runs a small DMA-control FSM skeleton that can launch the wrapped tinyNPU
core.

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

`LOAD_A`, `LOAD_B`, and `STORE_C` are placeholder timing states only. They do
not read or write external memory.

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
- The DMA descriptor wrapper still does not implement real DMA memory movement.

## Future Path

- Connect `DMA_CTRL.start` to a real DMA FSM.
- Add a memory bus master for A/B load and C store-back.
- Add interrupt/status/error handling.
- Add burst transfers and memory latency/backpressure tests.
