# tinyNPU Source Manifest

## Synthesizable RTL

- `rtl/tinynpu_defs.svh`: shared matrix width constants for synthesizable RTL.
- `rtl/tinynpu_pkg.sv`: compatibility package aliasing the shared constants and
  typedefs for flows that still read the package.
- `rtl/tinynpu_mac_array.sv`: compile-time MAC variant wrapper.
- `rtl/tinynpu_mac_serial.sv`: serial one-MAC-per-cycle datapath.
- `rtl/tinynpu_mac_row4.sv`: default four-lane row MAC datapath.
- `rtl/tinynpu_mac_row4_pipe.sv`: timing-oriented four-lane row MAC datapath
  with a product register stage before accumulator update.
- `rtl/tinynpu_mac_row4_pipe2.sv`: second timing-oriented four-lane row MAC
  datapath with operand-select, product, and accumulator pipeline stages.
- `rtl/tinynpu_mac_systolic4x4.sv`: output-stationary 4x4 PE array with
  wavefront operand movement and pipelined partial-product multiplication.
- `rtl/tinynpu_mac_full16.sv`: full-parallel 16-output datapath.
- `rtl/tinynpu_scratchpad_i8.sv`: 16-entry int8 scratchpad for A/B storage.
- `rtl/tinynpu_result_buffer_i32.sv`: 16-entry int32 C result buffer.
- `rtl/tinynpu_top.sv`: core accelerator with simple register bus and an
  asynchronous-assert, synchronous-deassert reset synchronizer.
- `rtl/tinynpu_apb_wrapper.sv`: APB-lite-style wrapper around the core.
- `rtl/tinynpu_dma_descriptor_wrapper.sv`: APB-lite-style descriptor wrapper
  with DMA FSM, abstract external memory port, timeout/error handling, IRQ
  output, and APB core wrapper.
- `rtl/tinynpu_axi_lite_wrapper.sv`: AXI4-Lite control wrapper around the DMA
  descriptor wrapper; memory port remains the abstract ready/valid interface
  and descriptor IRQ is passed through.
- `rtl/tinynpu_axi_read_dma_wrapper.sv`: AXI4-Lite controlled wrapper with an
  AXI4 read master for A/B loads and an abstract C write port.
- `rtl/tinynpu_axi_dma_wrapper.sv`: AXI4-Lite controlled wrapper with AXI4 read
  master loads for A/B and AXI4 write master stores for C.
- `rtl/tinynpu_axis_stream_tile_core.sv`: tile-at-a-time AXI4-Stream-style
  interface for one 4x4 A/B input tile and one C output tile.
- `rtl/tinynpu_axis_stream_npu.sv`: double-buffered AXI4-Stream prototype with
  ping-pong A/B input buffers, a selectable row4_pipe2 or systolic4x4 compute
  engine, ping-pong C output buffers, and overlapped load/compute/output FSMs.

## Simulation-Only RTL/Checkers

- `rtl/tinynpu_assertions.sv`: simulation checker logic enabled by
  `TINYNPU_SIM_ASSERT`.
- `rtl/tinynpu_mem_port_assertions.sv`: reusable simulation-only checker for the
  abstract DMA memory port, enabled by `TINYNPU_SIM_ASSERT`.

## Testbenches

- `tb/tb_tinynpu_top.sv`: simple-bus self-checking regression.
- `tb/tb_tinynpu_apb_wrapper.sv`: focused APB wrapper regression.
- `tb/tb_tinynpu_apb_dma_model.sv`: testbench-only DMA-style external-memory
  model.
- `tb/tb_tinynpu_dma_descriptor_wrapper.sv`: synthesizable descriptor-wrapper
  regression.
- `tb/tb_tinynpu_axi_lite_wrapper.sv`: AXI4-Lite control-wrapper regression.
- `tb/tb_tinynpu_axi_read_dma_wrapper.sv`: AXI read-DMA wrapper regression.
- `tb/tb_tinynpu_axi_dma_wrapper.sv`: full single-beat AXI DMA wrapper
  regression.
- `tb/tb_tinynpu_axis_stream_tile_core.sv`: AXI4-Stream tile-core regression.
- `tb/tb_tinynpu_axis_stream_npu.sv`: double-buffered streaming NPU regression.

## Models And Simulation Runners

- `model/golden_matmul.py`: Python golden model and vector generator.
- `sim/run_sim.py`: core simulation runner for MAC variants.
- `sim/run_apb_sim.py`: APB wrapper simulation runner.
- `sim/run_apb_dma_sim.py`: DMA-style testbench model runner.
- `sim/run_dma_descriptor_wrapper_sim.py`: DMA descriptor-wrapper simulation
  runner.
- `sim/run_axi_lite_sim.py`: AXI4-Lite control-wrapper simulation runner.
- `sim/run_axi_read_dma_sim.py`: AXI read-DMA wrapper simulation runner.
- `sim/run_axi_dma_sim.py`: full single-beat AXI DMA wrapper simulation runner.
- `sim/run_axis_stream_sim.py`: AXI4-Stream tile-core simulation runner.
- `sim/run_axis_stream_npu_sim.py`: double-buffered streaming NPU simulation
  runner.

## Scripts

- `scripts/check_repo.py`: repository static checks.
- `scripts/check_asic_flow.py`: ASIC-flow scaffold checks for the row4,
  row4_pipe, row4_pipe2, row4_pipe2_dupa, row4_pipe3, systolic4x4, and selected
  lower-clock row4_pipe2 `tinynpu_top` OpenLane setups.
- `scripts/synth_yosys.sh`: Yosys synthesis entry point.
- `scripts/synth_yosys.ys`: Yosys synthesis script template.
- `scripts/parse_yosys_stats.py`: synthesis report parser.
- `scripts/save_result_snapshot.py`: result summary snapshot writer.

## ASIC Flow Scaffold

- `constraints/tinynpu_top.sdc`: initial ASIC-style clock and IO timing
  constraints for the row4 `tinynpu_top` implementation target.
- `openlane/tinynpu_top/config.json`: initial OpenLane-style configuration for
  the row4 `tinynpu_top` implementation target.
- `openlane/tinynpu_top_row4_pipe/config.json`: separate OpenLane
  configuration for the timing-oriented row4_pipe target.
- `openlane/tinynpu_top_row4_pipe2/config.json`: separate OpenLane
  configuration for the second timing-oriented row4_pipe2 target.
- `openlane/tinynpu_top_row4_pipe2_dupa/config.json`: separate OpenLane
  configuration for the row4_pipe2 lane-local selected-A experiment.
- `openlane/tinynpu_top_row4_pipe3/config.json`: separate OpenLane
  configuration for the deeper product-generation pipeline experiment.
- `openlane/tinynpu_top_systolic4x4/config.json`: 10 ns / 100 MHz OpenLane
  configuration for the 4x4 systolic-array experiment.
- `openlane/tinynpu_top_row4_pipe2_95mhz/config.json`: selected row4_pipe2
  10.5 ns / 95.2 MHz target.
- `openlane/tinynpu_top_row4_pipe2_93mhz/config.json`: selected row4_pipe2
  10.75 ns / 93.0 MHz sweep target.
- `openlane/tinynpu_top_row4_pipe2_91mhz/config.json`: selected row4_pipe2
  11.0 ns / 90.9 MHz sweep target.

## Test Vectors

- `tests/test_vectors/generated_matmul_tests.json`: deterministic generated
  golden vectors.
- `tests/test_vectors/generated_matmul_tests.svh`: SystemVerilog include
  generated from the same vectors.

## Documentation

- `docs/*.md`: design, verification, synthesis, bus, wrapper, and development
  notes.
- `docs/asic_flow_plan.md`: ASIC-flow pivot plan, source list, constraints,
  OpenLane assumptions, and current blockers.
- `docs/asic_flow_results.md`: captured ASIC-style OpenLane/SKY130 flow,
  timing/PPA exploration, and limitations.
- `docs/performance.md`: simulation performance reporting notes.
- `docs/streaming_core.md`: tile-at-a-time AXI4-Stream interface notes.
- `docs/streaming_npu.md`: double-buffered streaming NPU architecture,
  verification, metrics, and limitations.

## Generated/Ignored Outputs

- `build/`: simulation outputs, waveforms, synthesis reports, netlists, and
  structured summaries. This directory is ignored and regenerated by make
  targets.
