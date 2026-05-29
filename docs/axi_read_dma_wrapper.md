# tinyNPU AXI Read-DMA Wrapper

`rtl/tinynpu_axi_read_dma_wrapper.sv` is an optional integration wrapper that
starts the full AXI memory-master path without replacing the existing APB,
descriptor-wrapper, or AXI-Lite-control flows.

It combines:

- AXI4-Lite slave control and descriptor registers.
- AXI4 read master access for loading A and B from external memory.
- An abstract ready/valid write-only port for storing C results.
- The existing tinyNPU core through `tinynpu_apb_wrapper`.

This is not a full AXI DMA engine yet. v28 supports single-beat AXI reads only,
has no AXI write master, and has no bursts or outstanding transactions.
v29 adds `tinynpu_axi_dma_wrapper` as the next wrapper for AXI reads and AXI
writes. Keep this read-DMA wrapper for incremental read-side testing and the
abstract C write path.

## Interfaces

Control uses the same 12-bit AXI4-Lite register map as
`tinynpu_axi_lite_wrapper`.

The AXI4 read master issues one read per A/B matrix element:

| Signal | Behavior |
| --- | --- |
| `m_axi_araddr` | byte address, generated from descriptor word base plus index shifted left by 2 |
| `m_axi_arlen` | `0`, single beat |
| `m_axi_arsize` | `3'b010`, 4-byte word |
| `m_axi_arburst` | `2'b01`, INCR |
| `m_axi_arvalid/arready` | address handshake |
| `m_axi_rvalid/rready` | read-data handshake |
| `m_axi_rdata[7:0]` | int8 A/B payload loaded into the core scratchpads |
| `m_axi_rresp` | non-OKAY response sets `DMA_ERROR_CODE = 3` |
| `m_axi_rlast` | expected to be high for each single-beat response |

C results are stored through a simple abstract write port:

| Signal | Behavior |
| --- | --- |
| `c_mem_valid` | C write request |
| `c_mem_addr` | external memory word address |
| `c_mem_wdata` | signed int32 C result |
| `c_mem_ready` | write accepted |

## Descriptor Registers

The descriptor map matches the v27 descriptor wrapper:

| Address | Name |
| --- | --- |
| `0x100` | `DMA_CTRL` |
| `0x104` | `DMA_STATUS` |
| `0x108` | `DMA_A_EXT_BASE` |
| `0x10c` | `DMA_B_EXT_BASE` |
| `0x110` | `DMA_C_EXT_BASE` |
| `0x114` | `DMA_CONFIG` |
| `0x118` | `DMA_ERROR_CODE` |
| `0x11c` | `DMA_IRQ_ENABLE` |
| `0x120` | `DMA_IRQ_STATUS` |

`DMA_CONFIG[15:0]` is used as the AXI/read-memory timeout. `DMA_CONFIG[31:16]`
is used as the core-done timeout. Zero fields select default limits.

`DMA_ERROR_CODE` values:

- `0`: no error
- `1`: AXI read handshake timeout or C abstract write timeout
- `2`: core completion timeout
- `3`: AXI read response error or missing `RLAST`

## DMA Sequence

```text
IDLE
  -> LOAD_A_AXI
  -> LOAD_B_AXI
  -> START_CORE
  -> WAIT_CORE
  -> STORE_C_ABSTRACT
  -> DONE
```

`LOAD_A_AXI` and `LOAD_B_AXI` issue 16 single-beat AXI reads each and write
`RDATA[7:0]` into the wrapped core A/B storage. `START_CORE` writes the core
CTRL register. `WAIT_CORE` polls core STATUS. `STORE_C_ABSTRACT` reads the C
result words from the core and writes them through the abstract C write port.

Done and error IRQ behavior matches the descriptor wrapper: pending bits are
sticky, reads do not clear them, and `DMA_CTRL.clear_done` /
`DMA_CTRL.clear_error` clear the corresponding pending state.

## Verification

Run:

```sh
make sim-axi-read-dma
```

The regression covers identity and mixed-signed matrix multiplies, AXI AR
backpressure, delayed RVALID, RRESP error handling, timeout handling, and done
IRQ assertion/clear.

## Synthesis

Run:

```sh
make synth-axi-read-dma
```

The synthesis top is `tinynpu_axi_read_dma_wrapper` with the default `row4`
core. The report is generic Yosys synthesis only, not technology-mapped PPA.

## Current Limitations

- No AXI write master.
- No bursts.
- No IDs or multiple outstanding reads.
- No byte strobes for C stores.
- C result storage still uses the abstract write port.
- No full SoC interconnect integration.
