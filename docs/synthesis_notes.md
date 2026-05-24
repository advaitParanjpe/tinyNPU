# tinyNPU Synthesis Notes

## Flow Overview

`make synth` runs a basic Yosys synthesis flow for `tinynpu_top` using the
default `row4` MAC variant. `make synth-serial` and `make synth-full16` run the
same flow for the other MAC variants. `make synth-apb` synthesizes the optional
APB wrapper around the default `row4` core.

`make synth-dma-desc` synthesizes the optional DMA descriptor wrapper around the
APB core wrapper. This includes synthesizable descriptor registers and a
DMA-control FSM skeleton, but no real DMA data mover.

The flow reads the SystemVerilog RTL, sets `tinynpu_top` as the top module, runs
generic synthesis cleanup and optimization passes, writes a synthesized Verilog
netlist, and emits a simple area-style statistics report.

The current flow includes the behavioral A/B int8 scratchpad modules and C int32
result-buffer module. This is still generic register-based synthesis, not SRAM
macro mapping.

Variant-specific outputs are written under `build/synth/<variant>/`:

- `yosys.log`
- `stat.txt`
- `tinynpu_top_synth.v`
- `tinynpu_apb_wrapper_synth.v` for `build/synth/apb/`
- `tinynpu_dma_descriptor_wrapper_synth.v` for `build/synth/dma_desc/`
- `synth_summary.json`

## Current Limitations

- Generic Yosys synthesis only
- No real standard-cell library mapping yet
- No timing constraints yet
- No clock uncertainty or IO delay modeling
- No real DMA data mover or memory bus master yet
- No OpenROAD floorplan, placement, routing, or parasitics
- No technology-specific area, power, or timing claims

## Future Steps

- Compare serial, row-MAC, and full-parallel area/latency tradeoffs
- Add Sky130 or ASAP7 mapping
- Add clock constraints and timing estimates
- Add optional OpenROAD place-and-route flow
- Track synthesis report deltas in CI-style regressions
