# tinyNPU AXI DMA Wrapper

`rtl/tinynpu_axi_dma_wrapper.sv` is the top-level full-DMA wrapper for the
current tinyNPU milestone. It is an optional, synthesizable, single-beat AXI DMA
integration wrapper around the existing tinyNPU core.

It combines:

- AXI4-Lite slave control and descriptor registers.
- AXI4 read master access for loading A and B from external memory.
- AXI4 write master access for storing C results to external memory.
- The existing tinyNPU core through `tinynpu_apb_wrapper`.
- Descriptor done/error IRQ behavior.

This is still intentionally small. v29 supports single-beat AXI transactions
only. It has no bursts, IDs, or multiple outstanding transactions.

## Interfaces

Control uses the same 12-bit AXI4-Lite descriptor map as the AXI-Lite and AXI
read-DMA wrappers. The AXI4-Lite slave accepts one read or write transaction at
a time and returns OKAY responses. Full-word writes use `WSTRB = 4'b1111`;
partial writes are ignored.

The AXI read master loads A/B:

- `ARLEN = 0`
- `ARSIZE = 3'b010`
- `ARBURST = 2'b01`
- `ARADDR = (descriptor_base + index) << 2`
- `RDATA[7:0]` is written into the tinyNPU A/B scratchpads

The AXI write master stores C:

- `AWLEN = 0`
- `AWSIZE = 3'b010`
- `AWBURST = 2'b01`
- `WSTRB = 4'b1111`
- `WLAST = 1`
- `AWADDR = (DMA_C_EXT_BASE + index) << 2`
- `WDATA = C[index]`

AW, W, and B are sequenced simply: address, data, then response. No outstanding
writes are issued.

## Descriptor Registers

| Address | Name | Description |
| --- | --- | --- |
| `0x100` | `DMA_CTRL` | write bit 0 to start, bit 1 to clear done, bit 2 to clear error |
| `0x104` | `DMA_STATUS` | bit 0 busy, bit 1 done, bit 2 error |
| `0x108` | `DMA_A_EXT_BASE` | word address base for A input reads |
| `0x10c` | `DMA_B_EXT_BASE` | word address base for B input reads |
| `0x110` | `DMA_C_EXT_BASE` | word address base for C result writes |
| `0x114` | `DMA_CONFIG` | `[15:0]` memory timeout, `[31:16]` core timeout; zero fields select defaults |
| `0x118` | `DMA_ERROR_CODE` | sticky error reason until `DMA_CTRL.clear_error` |
| `0x11c` | `DMA_IRQ_ENABLE` | bit 0 done IRQ enable, bit 1 error IRQ enable |
| `0x120` | `DMA_IRQ_STATUS` | bit 0 done pending, bit 1 error pending |

`DMA_CONFIG[15:0]` is the memory timeout limit for AXI read and write
handshakes. `DMA_CONFIG[31:16]` is the core timeout limit. A zero field selects
the default timeout.

Error codes:

- `0`: no error
- `1`: AXI read/write handshake timeout
- `2`: core completion timeout
- `3`: AXI read response error or missing `RLAST`
- `4`: AXI write response error

`DMA_CTRL.start` is accepted only when the wrapper is idle and no sticky error
is pending. `DMA_CTRL.clear_done` clears done pending state. `DMA_CTRL.clear_error`
clears the sticky error and error IRQ pending state so a new DMA can start.

## DMA Sequence

```text
IDLE
  -> LOAD_A_AXI
  -> LOAD_B_AXI
  -> START_CORE
  -> WAIT_CORE
  -> STORE_C_AXI
  -> DONE
```

`LOAD_A_AXI` and `LOAD_B_AXI` issue 16 single-beat AXI reads each. `START_CORE`
and `WAIT_CORE` drive the wrapped tinyNPU core through the internal APB path.
`STORE_C_AXI` reads each C word from the core and writes it through single-beat
AXI AW/W/B transactions.

## Transaction Sequence

For each A or B element:

1. Assert `m_axi_arvalid` with `(base + index) << 2`.
2. Wait for `m_axi_arready`.
3. Assert `m_axi_rready`.
4. Capture `m_axi_rdata[7:0]` when `m_axi_rvalid` is asserted.
5. Abort with error code `3` if `m_axi_rresp` is not OKAY or `m_axi_rlast` is
   not asserted.
6. Write the sign-extended int8 value into the wrapped core scratchpad.

For each C element:

1. Read the C word from the wrapped core.
2. Assert `m_axi_awvalid` with `(DMA_C_EXT_BASE + index) << 2`.
3. Wait for `m_axi_awready`.
4. Assert `m_axi_wvalid` with the C word, `WSTRB = 4'b1111`, and `WLAST = 1`.
5. Wait for `m_axi_wready`.
6. Assert `m_axi_bready` and wait for `m_axi_bvalid`.
7. Abort with error code `4` if `m_axi_bresp` is not OKAY.

The memory timeout counter covers AR, R, AW, W, and B waits. The core timeout
counter covers the internal wait for `STATUS.done`.

## Relationship To Other Wrappers

- `tinynpu_axi_lite_wrapper`: AXI4-Lite control only; data movement remains on
  the abstract ready/valid memory port.
- `tinynpu_axi_read_dma_wrapper`: AXI reads for A/B, abstract write port for C.
- `tinynpu_axi_dma_wrapper`: AXI reads for A/B and AXI writes for C.

## Run

```sh
make sim-axi-dma
make synth-axi-dma
```

The current regression covers these named tests:

| Test | Coverage |
| --- | --- |
| `axi_dma_identity` | AXI A/B loads, core compute, AXI C stores |
| `axi_dma_mixed_signed` | signed int8 inputs and signed int32 outputs |
| `axi_dma_ar_backpressure` | delayed AXI read-address acceptance |
| `axi_dma_rvalid_delay` | delayed AXI read data response |
| `axi_dma_aw_backpressure` | delayed AXI write-address acceptance |
| `axi_dma_w_backpressure` | delayed AXI write-data acceptance |
| `axi_dma_bvalid_delay` | delayed AXI write response |
| `axi_dma_rresp_error` | read response error, error code `3`, error IRQ |
| `axi_dma_read_timeout` | read-side timeout, error code `1` |
| `axi_dma_bresp_error` | write response error, error code `4`, error IRQ |
| `axi_dma_write_timeout` | write-side timeout, error code `1` |
| `axi_dma_irq_done` | done pending, done IRQ assertion, clear behavior |

Latest local generated results:

- `make sim-axi-dma`: passed 12/12 named tests.
- `make synth-axi-dma`: passed generic Yosys synthesis for
  `tinynpu_axi_dma_wrapper`.
- Generic Yosys size: 19,692 cells, 6,671 wires, and 56,226 wire bits.

## Current Limitations

- No bursts.
- No IDs.
- No multiple outstanding reads or writes.
- No AXI interconnect integration.
- No full AXI protocol compliance suite.
- Generic Yosys synthesis only; no technology-mapped PPA.
