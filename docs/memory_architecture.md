# tinyNPU Memory Architecture

tinyNPU v14 keeps the public register bus and address map unchanged, but moves
matrix storage out of `tinynpu_top` into small reusable modules.

## A/B Scratchpads

`rtl/tinynpu_scratchpad_i8.sv` stores one 4x4 matrix as 16 signed int8 values.
Two instances are used in `tinynpu_top`:

- A matrix storage
- B matrix storage

The scratchpad resets to zero, accepts one indexed write per cycle, provides an
indexed read for bus readback, and exports a flattened 16-entry vector for the
MAC variant wrapper.

## C Result Buffer

`rtl/tinynpu_result_buffer_i32.sv` stores the 16 signed int32 C result values.
It resets to zero and captures the full flattened MAC output when MAC done is
observed. Bus writes to the C address range are still ignored by `tinynpu_top`.

## Scope

These modules are behavioral/register-based storage. They are not SRAM macros,
do not add memory timing, and do not change the simple register bus protocol.
