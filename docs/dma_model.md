# tinyNPU DMA-Style Simulation Model

`tb/tb_tinynpu_apb_dma_model.sv` models the system-level movement pattern around
tinyNPU using testbench tasks and a simulated external memory array. It is not
synthesizable DMA RTL.

The model instantiates `tinynpu_apb_wrapper` and moves data through APB
transactions. Tests program simulation-only descriptor registers first,
then the descriptor model performs the movement sequence:

1. Software writes A/B/C external-memory base addresses.
2. Software writes `DMA_CTRL.start`.
3. The testbench descriptor model loads A into the tinyNPU A scratchpad.
4. The model loads B into the tinyNPU B scratchpad.
5. The model starts the accelerator through CTRL.
6. The model polls STATUS.done.
7. The model reads C through APB and stores it back into external memory.
8. The descriptor model sets `DMA_STATUS.done`.

These descriptor registers are testbench-side model state only. v18 also has an
optional synthesizable descriptor-register wrapper, documented in
`docs/dma_descriptor_wrapper.md`, but that wrapper does not move memory.

## Descriptor Register Map

| Address | Name | Description |
| --- | --- | --- |
| `0x100` | `DMA_CTRL` | bit 0: start; bit 1: clear done/error |
| `0x104` | `DMA_STATUS` | bit 0: busy; bit 1: done; bit 2: error |
| `0x108` | `DMA_A_EXT_BASE` | external memory word address for A |
| `0x10c` | `DMA_B_EXT_BASE` | external memory word address for B |
| `0x110` | `DMA_C_EXT_BASE` | external memory word address for C |
| `0x114` | `DMA_CONFIG` | reserved model register |

Invalid descriptor reads return `0`. Invalid descriptor writes are ignored.
Writing start while the descriptor model is busy is ignored and does not set
error.

## External Memory Layout

The testbench uses word-addressed external memory:

| Word range | Purpose |
| --- | --- |
| `0`-`15` | A matrix for the first operation |
| `16`-`31` | B matrix for the first operation |
| `32`-`47` | C result for the first operation |
| `64`-`79` | A matrix for the second operation |
| `80`-`95` | B matrix for the second operation |
| `96`-`111` | C result for the second operation |

Each A/B word carries one signed int8 value in bits `[7:0]`. C words store
signed int32 results.

## Run

```sh
make sim-apb-dma
```

Outputs are written under `build/sim/apb_dma/`, including:

- `tinynpu_apb_dma_model.vcd`
- `sim_summary.json`

## Current Tests

- `dma_desc_identity`
- `dma_desc_mixed_signed`
- `dma_desc_back_to_back`
- `dma_desc_start_while_busy`
- `dma_desc_invalid_access`
- `dma_desc_external_memory_unchanged`

## Limitations

- No real DMA controller RTL.
- No real DMA data mover RTL.
- No AXI master.
- No burst transactions.
- No bus arbitration.
- No interrupts.
- No memory latency model yet.

## Future Path

- Connect the synthesizable descriptor wrapper to a real DMA controller.
- Add AXI-lite or APB control and an AXI/AHB memory master.
- Add memory latency, backpressure, and arbitration tests.
