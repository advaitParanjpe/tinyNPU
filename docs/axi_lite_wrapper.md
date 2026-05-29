# tinyNPU AXI4-Lite Control Wrapper

`rtl/tinynpu_axi_lite_wrapper.sv` is an optional control-plane wrapper around
`tinynpu_dma_descriptor_wrapper`. It lets AXI4-Lite software program the same
core and DMA descriptor registers that are already available through the
descriptor wrapper's APB-lite-style interface.

This is only a control wrapper. The DMA data path still uses the existing
abstract ready/valid external memory port. There is no full AXI memory master.
The wrapper also passes through the descriptor wrapper's `irq` output.

v28 adds `tinynpu_axi_read_dma_wrapper` as a separate optional block for AXI
read-master A/B loads. This AXI-Lite wrapper remains the control-only path and
is unchanged.
v29 adds `tinynpu_axi_dma_wrapper` as a separate optional block for single-beat
AXI read/write DMA. This AXI-Lite wrapper still remains the control-only path.

## Layering

```text
AXI4-Lite control access
        |
tinynpu_axi_lite_wrapper
        |
tinynpu_dma_descriptor_wrapper
        |
tinynpu_apb_wrapper
        |
tinynpu_top
```

The AXI-Lite wrapper does not change `tinynpu_top`, `tinynpu_apb_wrapper`, the
MAC variants, or the abstract memory-port protocol.

## AXI4-Lite Subset

Supported:

- 12-bit AXI4-Lite slave address
- single outstanding write transaction
- single outstanding read transaction
- independent write address, write data, write response, read address, and read
  data channels
- OKAY responses only: `BRESP = 2'b00`, `RRESP = 2'b00`
- no IDs
- no bursts
- no multiple outstanding transactions

Invalid reads inherit the descriptor-wrapper behavior and return `0` where the
underlying address map is unmapped. Invalid writes are ignored. The wrapper
returns OKAY for both valid and invalid addresses.

## WSTRB Behavior

v25 uses full-word-only writes. A write is forwarded to the descriptor wrapper
only when `s_axi_wstrb == 4'b1111`.

Partial writes with any other `WSTRB` value are ignored and still receive an
OKAY write response. This keeps the bridge simple and avoids hidden
read-modify-write behavior across the forwarded core and descriptor regions.

## Address Map

The AXI-Lite address map matches `tinynpu_dma_descriptor_wrapper`.

| Address range | Behavior |
| --- | --- |
| `0x000`-`0x0ff` | forwarded core region through the APB wrapper |
| `0x100`-`0x120` | DMA descriptor/status/IRQ register region |

Descriptor registers:

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

## Interrupt Output

v26 adds an `irq` output to `tinynpu_axi_lite_wrapper`. It is the descriptor
wrapper IRQ passed through unchanged:

- `DMA_IRQ_ENABLE[0]` enables done IRQs.
- `DMA_IRQ_ENABLE[1]` enables error IRQs.
- `DMA_IRQ_STATUS[0]` is sticky done pending.
- `DMA_IRQ_STATUS[1]` is sticky error pending.
- `DMA_CTRL.clear_done` clears done status and done IRQ pending.
- `DMA_CTRL.clear_error` clears error status and error IRQ pending.
- `DMA_ERROR_CODE` reports `0` for no error, `1` for memory timeout, and `2`
  for core timeout.
- `DMA_IRQ_STATUS` reads do not clear pending bits; writes are ignored.

Polling `DMA_STATUS` remains supported.

`DMA_CONFIG[15:0]` configures memory timeout cycles, and
`DMA_CONFIG[31:16]` configures core timeout cycles. Zero fields select the
descriptor wrapper defaults.

## External Memory Port

These signals pass through from `tinynpu_dma_descriptor_wrapper` unchanged:

| Signal | Direction | Description |
| --- | --- | --- |
| `mem_valid` | output | memory transaction request |
| `mem_we` | output | `0` read, `1` write |
| `mem_addr[31:0]` | output | external memory word address |
| `mem_wdata[31:0]` | output | write data for stores |
| `mem_rdata[31:0]` | input | read data for loads |
| `mem_ready` | input | transaction accepted/data valid |

The port remains a simple single-beat ready/valid interface. It is not AXI and
does not support bursts, byte strobes, outstanding transactions, or memory error
responses.

## Verification

Run:

```sh
make sim-axi-lite
```

The testbench checks descriptor register read/write, forwarded core operation,
descriptor-programmed DMA identity and mixed-signed matrix multiplies, AXI-Lite
channel stalls, invalid/unaligned accesses, and the full-word-only `WSTRB`
policy. v26 also checks done IRQ assertion, pending status, clear behavior, and
disabled-IRQ behavior. v27 adds AXI-Lite-level memory-timeout error IRQ and
`DMA_ERROR_CODE` checks.

## Synthesis

Run:

```sh
make synth-axi-lite
```

The synthesis top is `tinynpu_axi_lite_wrapper` with the default `row4` MAC
variant through the wrapped tinyNPU core.

## Not Implemented

- full AXI/AXI4 memory master
- burst transfers
- multiple outstanding transactions
- AXI IDs
- interconnect integration
- full AXI interrupt-controller integration
- memory error responses
