# tinyNPU Simple Register Bus Protocol

tinyNPU uses a minimal testbench-friendly register bus. It is intentionally not
AXI, APB, or any other standard SoC bus.

An optional APB-lite-style wrapper is documented separately in
`docs/apb_wrapper.md`. The wrapper translates APB transfers into this simple bus
without changing `tinynpu_top`.

## Signals

- `bus_ready` is always `1` in the current implementation.
- A transaction occurs on a rising clock edge when `bus_valid && bus_ready`.
- `bus_we = 1` selects a write transaction.
- `bus_we = 0` selects a read transaction.
- `bus_addr` is byte-addressed.
- Valid register and storage addresses are 32-bit word-aligned.
- Unaligned addresses are invalid.

## Timing

Writes are accepted on the transaction clock edge.

Reads use a registered response. When a read transaction is accepted on a rising
clock edge, `bus_rdata` is updated after that edge and remains stable until a
later read transaction or reset changes it. The testbench samples `bus_rdata`
after the accepted read edge.

## Address Behavior

- Invalid reads return `0`.
- Invalid writes are ignored.
- Unaligned reads return `0`.
- Unaligned writes are ignored.
- Writes to C result storage are ignored.

## Data Behavior

- A and B storage are written with `bus_wdata[7:0]`.
- A and B storage hold signed int8 values.
- Reads from A and B return the stored int8 value sign-extended to 32 bits.
- Reads from C return signed int32 result values.

## Control and Status

`CTRL` is at `0x00`:

- bit 0: `start`
- bit 1: `clear_done`
- other bits are ignored

`CTRL.start` is accepted only when the accelerator is idle. A start write while
busy is ignored and does not restart or corrupt the active operation.

`CTRL.clear_done` clears sticky `STATUS.done`. If `start` and `clear_done` are
written together while idle, the operation starts and `done` is cleared.

`STATUS` is at `0x04`:

- bit 0: `busy`
- bit 1: sticky `done`
- other bits read as `0`

`STATUS.done` remains asserted after an operation completes until software writes
`CTRL.clear_done` or starts a new operation.
