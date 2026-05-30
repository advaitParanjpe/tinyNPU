# tinyNPU Synthesis Notes

## Flow Overview

`make synth` runs a basic Yosys synthesis flow for `tinynpu_top` using the
default `row4` MAC variant. `make synth-serial`, `make synth-row4-pipe`, `make
synth-row4-pipe2`, and `make synth-full16` run the same flow for the other MAC
variants. `make synth-apb` synthesizes the optional APB wrapper around the
default `row4` core.

`make synth-dma-desc` synthesizes the optional DMA descriptor wrapper around the
APB core wrapper. This includes synthesizable descriptor registers, a DMA FSM,
and a simple abstract external memory port. It is not AXI and has no burst or
outstanding transaction support.

`make synth-axi-lite` synthesizes the optional AXI4-Lite control wrapper around
the DMA descriptor wrapper. This adds AXI-Lite control-plane handshaking only;
the external memory interface remains the same abstract ready/valid port and is
not a full AXI memory master. v26 adds descriptor done/error IRQ registers and
an `irq` output to the descriptor and AXI-Lite wrappers. v27 adds timeout
counters, `DMA_ERROR_CODE`, and timeout/error control logic.

`make synth-axi-read-dma` synthesizes the optional AXI read-DMA wrapper. This
top has AXI4-Lite control, a single-beat AXI4 read master for loading A/B, an
abstract write port for C results, and the wrapped tinyNPU core. It has no AXI
write master, no burst support, and no multiple outstanding reads.

`make synth-axi-dma` synthesizes the optional full single-beat AXI DMA wrapper.
This top has AXI4-Lite control, AXI4 reads for A/B loads, AXI4 writes for C
stores, and the wrapped tinyNPU core. It still has no bursts, IDs, or multiple
outstanding transactions.

v22 added memory-port backpressure verification without changing this RTL. v23
adds `tinynpu_mem_port_assertions` for simulation only; it is not read by the
Yosys synthesis scripts.

The flow reads the SystemVerilog RTL, sets `tinynpu_top` as the top module, runs
generic synthesis cleanup and optimization passes, writes a synthesized Verilog
netlist, and emits a simple area-style statistics report.

The current flow includes the behavioral A/B int8 scratchpad modules and C int32
result-buffer module. This is still generic register-based synthesis, not SRAM
macro mapping.

Variant-specific outputs are written under `build/synth/<variant>/`:

- `yosys.log`
- `stat.txt`
- `tinynpu_top_synth.v` for core MAC variants, including `build/synth/row4/`,
  `build/synth/row4_pipe/`, `build/synth/row4_pipe2/`,
  `build/synth/serial/`, and `build/synth/full16/`
- `tinynpu_apb_wrapper_synth.v` for `build/synth/apb/`
- `tinynpu_dma_descriptor_wrapper_synth.v` for `build/synth/dma_desc/`
- `tinynpu_axi_lite_wrapper_synth.v` for `build/synth/axi_lite/`
- `tinynpu_axi_read_dma_wrapper_synth.v` for `build/synth/axi_read_dma/`
- `tinynpu_axi_dma_wrapper_synth.v` for `build/synth/axi_dma/`
- `synth_summary.json`

## Current Limitations

- Generic Yosys synthesis only
- No real standard-cell library mapping yet
- No timing constraints yet
- No clock uncertainty or IO delay modeling
- AXI DMA support is single-beat only
- No bursts, byte strobes, outstanding transactions, or memory error responses
  beyond timeout detection and AXI read/write response error handling
- No OpenROAD floorplan, placement, routing, or parasitics
- No technology-specific area, power, or timing claims

## Future Steps

- Compare serial, row-MAC, and full-parallel area/latency tradeoffs
- Add Sky130 or ASAP7 mapping
- Add clock constraints and timing estimates
- Add optional OpenROAD place-and-route flow
- Track synthesis report deltas in CI-style regressions
