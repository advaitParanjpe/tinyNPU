# tinyNPU APB-Lite Wrapper

`rtl/tinynpu_apb_wrapper.sv` is an optional APB-lite-style slave wrapper around
the existing `tinynpu_top` simple-bus core. It does not replace the simple bus.

## Signals

- `pclk`: APB clock, connected to core `clk`
- `presetn`: active-low reset, connected to core `rst_n`
- `psel`: slave select
- `penable`: APB access phase indicator
- `pwrite`: write when `1`, read when `0`
- `paddr[7:0]`: byte address, passed to core `bus_addr`
- `pwdata[31:0]`: write data, passed to core `bus_wdata`
- `prdata[31:0]`: read data
- `pready`: transfer completion
- `pslverr`: always `0` in the current wrapper

## Timing

An APB transfer completes during the access phase when
`psel && penable && pready`.

Writes complete in one access cycle. The wrapper asserts the core simple-bus
write transaction during that APB access cycle.

Reads use one wait state because `tinynpu_top` has registered read data. On the
first read access cycle, `pready` is `0` and the wrapper issues the core read.
On the following cycle, `pready` is `1` and `prdata` contains the returned core
read data.

`pready` is `1` outside active transfers.

## Error Behavior

`pslverr` is always `0`. Invalid and unaligned accesses use the existing
`tinynpu_top` behavior:

- invalid reads return `0`
- unaligned reads return `0`
- invalid and unaligned writes are ignored
- writes to C result storage are ignored

## Current Limitations

- Focused APB wrapper testbench only; not full APB protocol coverage.
- A DMA-style APB system testbench exists, but it is a testbench model only,
  not synthesizable DMA RTL.
- No APB error signaling yet.
- No APB protection, strobe, or byte-lane support.
- No AXI, real DMA, SRAM macro, or SoC interconnect integration.
