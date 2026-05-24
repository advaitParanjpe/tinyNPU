# tinyNPU DMA-Style Simulation Model

`tb/tb_tinynpu_apb_dma_model.sv` models the system-level movement pattern around
tinyNPU using testbench tasks and a simulated external memory array. It is not
synthesizable DMA RTL.

The model instantiates `tinynpu_apb_wrapper` and moves data through APB
transactions:

1. Load A from external memory into the tinyNPU A scratchpad.
2. Load B from external memory into the tinyNPU B scratchpad.
3. Start the accelerator through CTRL.
4. Poll STATUS.done.
5. Read C through APB and store it back into external memory.

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

- `dma_identity`
- `dma_mixed_signed`
- `dma_back_to_back`
- `dma_external_memory_unchanged`

## Limitations

- No real DMA controller RTL.
- No AXI master.
- No burst transactions.
- No descriptor registers.
- No bus arbitration.
- No memory latency model yet.

## Future Path

- Add descriptor registers for source/destination addresses and control.
- Add a real DMA controller.
- Add AXI-lite control and an AXI memory master.
- Add memory latency, backpressure, and arbitration tests.
