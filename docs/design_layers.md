# tinyNPU Design Layers

tinyNPU is organized as a small stack of synthesizable RTL layers plus
testbench-only system models.

## Layer 0: MAC Datapath Variants

Files:

- `rtl/tinynpu_mac_serial.sv`
- `rtl/tinynpu_mac_row4.sv`
- `rtl/tinynpu_mac_full16.sv`
- `rtl/tinynpu_mac_array.sv`

Purpose:

Fixed 4x4 signed int8 matrix multiply datapaths. `tinynpu_mac_array.sv` selects
one variant at compile time. The default is `row4`.

Status: synthesizable.

Targets:

- Test default: `make sim`
- Test all variants: `make compare`
- Synthesize default: `make synth`
- Synthesize other variants: `make synth-serial`, `make synth-full16`

## Layer 1: Core Accelerator

Files:

- `rtl/tinynpu_top.sv`
- `rtl/tinynpu_scratchpad_i8.sv`
- `rtl/tinynpu_result_buffer_i32.sv`

Purpose:

Core accelerator with the simple register bus, CTRL/STATUS, A/B int8
scratchpads, C int32 result buffer, and MAC wrapper.

Status: synthesizable.

Targets:

- Test: `make sim`
- Synthesize: `make synth`

## Layer 2: APB Wrapper

File:

- `rtl/tinynpu_apb_wrapper.sv`

Purpose:

APB-lite-style adapter around `tinynpu_top`. It preserves the core address map
and converts APB transfers to the simple core bus.

Status: synthesizable.

Targets:

- Test: `make sim-apb`
- Synthesize: `make synth-apb`

## Layer 3: DMA Descriptor Wrapper

File:

- `rtl/tinynpu_dma_descriptor_wrapper.sv`

Purpose:

Optional APB-lite-style wrapper with a 12-bit APB address space. It forwards
`0x000`-`0x0ff` to `tinynpu_apb_wrapper` and implements descriptor registers at
`0x100`-`0x11f`.

The descriptor start behavior runs a small DMA-control FSM:

```text
IDLE -> LOAD_A -> LOAD_B -> START_CORE -> WAIT_CORE -> STORE_C -> DONE
```

`LOAD_A` and `LOAD_B` read words from a simple abstract external memory port and
write A/B values into the wrapped core. `START_CORE` and `WAIT_CORE` drive the
wrapped tinyNPU core through the internal APB path. `STORE_C` reads C results
from the core and writes them back through the abstract memory port.

The memory port is word-addressed, single-beat, ready/valid, and not AXI. It has
no bursts, byte strobes, outstanding transactions, or error response.
The descriptor-wrapper testbench covers always-ready, fixed-latency, and
deterministic random-backpressure memory behavior. The reusable
`tinynpu_mem_port_assertions` checker verifies the abstract memory-port protocol
under `TINYNPU_SIM_ASSERT`.

Status: synthesizable.

Targets:

- Test: `make sim-dma-desc`
- Synthesize: `make synth-dma-desc`

## Layer 4: AXI4-Lite Control Wrapper

File:

- `rtl/tinynpu_axi_lite_wrapper.sv`

Purpose:

Optional AXI4-Lite slave adapter around `tinynpu_dma_descriptor_wrapper`. It
translates single-beat AXI4-Lite control reads and writes into the descriptor
wrapper's APB-style register interface. The abstract external memory port passes
through unchanged.

This is a control-plane wrapper only. It has no full AXI memory master, no
bursts, no IDs, and no multiple outstanding transactions. It returns OKAY
responses and accepts only full-word writes with `WSTRB == 4'b1111`; partial
writes are ignored.

Status: synthesizable.

Targets:

- Test: `make sim-axi-lite`
- Synthesize: `make synth-axi-lite`

See `docs/axi_lite_wrapper.md`.

## Layer 5: DMA-Style Simulation Model

File:

- `tb/tb_tinynpu_apb_dma_model.sv`

Purpose:

Testbench-only system model with simulated external memory and descriptor-driven
memory movement:

1. Load A from external memory into tinyNPU.
2. Load B from external memory into tinyNPU.
3. Start compute.
4. Poll done.
5. Store C back to external memory.

Status: testbench-only, not synthesizable DMA RTL.

Targets:

- Test: `make sim-apb-dma`

## Not Implemented Yet

- Full AXI/AHB memory master.
- Burst transfers.
- Byte strobes, memory error handling, and descriptor interrupts.
- Interrupt output.
- SRAM macro integration.
- Technology-mapped timing/PPA.
