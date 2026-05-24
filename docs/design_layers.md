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

The descriptor start behavior is status-only in v19: start asserts busy for a
few cycles, then sets done. No real DMA data mover exists yet.

Status: synthesizable.

Targets:

- Test: `make sim-dma-desc`
- Synthesize: `make synth-dma-desc`

## Layer 4: DMA-Style Simulation Model

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

- Real DMA data mover RTL.
- AXI/AHB memory master.
- Burst transfers.
- Descriptor-driven hardware memory movement.
- Interrupt output.
- SRAM macro integration.
- Technology-mapped timing/PPA.
