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

1. `rtl/tinynpu_pkg.sv`
2. `rtl/tinynpu_mac_serial.sv`
3. `rtl/tinynpu_mac_row4.sv`
4. `rtl/tinynpu_mac_full16.sv`
5. `rtl/tinynpu_mac_array.sv`
6. `rtl/tinynpu_scratchpad_i8.sv`
7. `rtl/tinynpu_result_buffer_i32.sv`
8. `rtl/tinynpu_top.sv`

`tinynpu_mac_serial.sv` and `tinynpu_mac_full16.sv` remain in the source list so
the compile-time variant wrapper can elaborate cleanly, but the default branch
instantiates `tinynpu_mac_row4`.

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
openlane openlane/tinynpu_top/config.json
```

or:

```sh
flow.tcl -design openlane/tinynpu_top
```

Use the command required by the local OpenLane installation.

## Current Audit Results

Already passing in this workspace:

- `make check`
- `make synth`
- `python3 scripts/check_asic_flow.py`

`make synth` confirms that the row4 `tinynpu_top` elaborates and synthesizes
with the generic Yosys flow. Latest generic Yosys summary:

- top: `tinynpu_top`
- MAC variant: `row4`
- cells: 14,514
- wires: 4,104
- wire bits: 49,766

## Current Blockers

- OpenLane/OpenROAD is not available on the current PATH, so an RTL-to-GDS smoke
  run has not been executed in this workspace.
- The SDC is a bring-up constraint file, not a final timing contract.
- The flow still uses register-based scratchpads and result storage; no SRAM
  macro mapping has been introduced.
- No pin order, PDN customization, macro placement, or IO timing budget has been
  finalized.
- No technology-mapped timing, area, power, DRC, or LVS result exists yet.

## Next Steps

1. Install or activate OpenLane/OpenROAD plus a Sky130A PDK.
2. Run the `tinynpu_top` OpenLane smoke flow.
3. Capture key reports under `build/asic/` or a similarly ignored output tree.
4. Record first-pass utilization, worst slack, routed status, DRC/LVS status,
   and any unsupported RTL/tool issues.
5. Tune die area, density, clock period, and IO constraints only after the first
   report set exists.

