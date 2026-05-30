# tinyNPU ASIC Flow Plan

This plan starts the ASIC-flow pivot after the full single-beat AXI DMA
milestone. The first implementation target is the existing default row4
`tinynpu_top` core, not the AXI DMA wrapper.

## Scope

The goal is an ASIC-style RTL-to-GDS flow scaffold for local iteration and
report tracking. This is not a tapeout claim unless the design is eventually
submitted to a shuttle or fab.

No new RTL features are part of this pivot. Bursts, outstanding transactions,
AXI IDs, larger matrices, SRAM macros, and accelerator feature changes remain
out of scope.

## Implementation Target

Top module:

- `tinynpu_top`

Clock and reset:

- `clk`: primary clock input
- `rst_n`: active-low asynchronous reset input

Public core bus:

- `bus_valid`
- `bus_we`
- `bus_addr[7:0]`
- `bus_wdata[31:0]`
- `bus_rdata[31:0]`
- `bus_ready`

Default MAC configuration:

- `row4`
- No synthesis define is required.
- Do not pass `TINYNPU_MAC_SERIAL`.
- Do not pass `TINYNPU_MAC_FULL16`.
- Do not pass `TINYNPU_SIM_ASSERT` for ASIC implementation.

## Source List

The row4 implementation source list is:

1. `rtl/tinynpu_mac_row4.sv`
2. `rtl/tinynpu_mac_array.sv`
3. `rtl/tinynpu_scratchpad_i8.sv`
4. `rtl/tinynpu_result_buffer_i32.sv`
5. `rtl/tinynpu_top.sv`

These files include `rtl/tinynpu_defs.svh` for shared matrix and bus widths. The
compatibility package `rtl/tinynpu_pkg.sv` is intentionally not in the OpenLane
source list because the first Dockerized OpenLane 2 run used Yosys header
generation with the Verilog-2005 frontend and failed on file-scope
SystemVerilog package import syntax:

```text
rtl/tinynpu_mac_serial.sv:3: ERROR: syntax error, unexpected TOK_ID
```

Line 3 was `import tinynpu_pkg::*;`. OpenLane 2 documents `USE_SYNLIG` as a
SystemVerilog-capable frontend option, but enabling it is not required for this
row4 ASIC-style RTL-to-GDS bring-up. The less invasive fix is to avoid
package/import syntax in the implementation source path and keep the constants
behavior-equivalent through the shared include file.

Simulation-only files are intentionally excluded:

- `rtl/tinynpu_assertions.sv`
- `rtl/tinynpu_mem_port_assertions.sv`
- `tb/*`
- `sim/*`

Integration wrappers are also excluded from the first ASIC target:

- `tinynpu_apb_wrapper`
- `tinynpu_dma_descriptor_wrapper`
- `tinynpu_axi_lite_wrapper`
- `tinynpu_axi_read_dma_wrapper`
- `tinynpu_axi_dma_wrapper`

## Constraints

Initial constraints live in `constraints/tinynpu_top.sdc`.

The starting point is intentionally conservative and simple:

- 100 MHz clock target: `create_clock -period 10.000`
- 2 ns input delay relative to `clk`
- 2 ns output delay relative to `clk`

These constraints are placeholders for flow bring-up. They are not final timing
signoff constraints.

## OpenLane Scaffold

The initial OpenLane-style config lives at:

- `openlane/tinynpu_top/config.json`

Assumptions:

- OpenLane is installed locally.
- A Sky130A PDK installation is available.
- The config uses `sky130_fd_sc_hd` as the starting standard-cell library.
- The first floorplan uses an absolute 800 um by 800 um die area and 45 percent
  placement target density.

These values are intended for a smoke flow. They should be revisited after the
first clean OpenLane/OpenROAD run reports utilization, timing, and routing
quality.

## Bring-Up Commands

Existing checks:

```sh
make check
make synth
```

ASIC-flow scaffold check:

```sh
python3 scripts/check_asic_flow.py
```

Possible OpenLane invocation depends on the installed OpenLane version. Common
forms are:

```sh
openlane --dockerized openlane/tinynpu_top/config.json
```

Use the command required by the local OpenLane installation.

## Current Audit Results

Already passing in this workspace:

- `make check`
- `make synth`
- `make asic-check`
- `openlane --dockerized openlane/tinynpu_top/config.json`

`make synth` confirms that the row4 `tinynpu_top` elaborates and synthesizes
with the generic Yosys flow. Latest generic Yosys summary:

- top: `tinynpu_top`
- MAC variant: `row4`
- cells: 14,514
- wires: 4,104
- wire bits: 49,766

Dockerized OpenLane run history:

- `RUN_2026-05-30_00-23-50` reached Yosys JSON header generation and failed on
  the file-scope `import tinynpu_pkg::*;` construct.
- `RUN_2026-05-30_00-28-25` parsed and synthesized after the shared include
  refactor, then failed post-PnR STA because the SDC used
  `remove_from_collection`, which this OpenSTA path did not accept.
- `RUN_2026-05-30_00-36-33` completed the Dockerized OpenLane flow after the
  SDC was rewritten with an explicit input port collection and the same SDC was
  wired as both `PNR_SDC_FILE` and `SIGNOFF_SDC_FILE`.

Final metrics from `RUN_2026-05-30_00-36-33`:

- Flow status: complete.
- Routed DRC: 0 final detailed-route errors after repair iterations.
- Magic DRC: 0.
- KLayout DRC: 0.
- LVS device differences: 0.
- Power-grid violations: 0.
- Antenna: 2 violating pins on 2 nets.
- Worst setup slack across reported corners: -5.831 ns, with 319 setup
  violations.
- Hold WNS/TNS: 0 / 0.
- Max slew violations: 3,003.
- Max capacitance violations: 29.

## Current Blockers

- The Dockerized OpenLane smoke flow completes, but physical closure is not
  clean: antenna, setup, max slew, and max capacitance violations remain.
- The SDC is a bring-up constraint file, not a final timing contract.
- The flow still uses register-based scratchpads and result storage; no SRAM
  macro mapping has been introduced.
- No pin order, PDN customization, macro placement, or IO timing budget has been
  finalized.
- The config still carries some deprecated OpenLane variable names that should
  be cleaned up after the bring-up path stabilizes.

## Next Steps

1. Fix the remaining antenna violations without changing RTL behavior.
2. Decide whether the 100 MHz placeholder clock target is the right first
   physical target, then tune clock period, die area, density, buffering, and IO
   constraints against that target.
3. Clean up deprecated OpenLane config variables.
4. Capture stable report summaries under `build/asic/` or a similarly ignored
   output tree once the flow settings stop changing.
5. Revisit SRAM macro mapping, pin order, PDN customization, and IO budgets
   before treating this as more than an ASIC-style RTL-to-GDS flow scaffold.
