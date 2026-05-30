# AXI4-Stream Tile Core

`tinynpu_axis_stream_tile_core` is the first streaming-interface milestone for
tinyNPU. It is a separate RTL module and does not change the existing
register-controlled `tinynpu_top`, APB/AXI-Lite/DMA wrappers, or documented
ASIC-flow targets.

## Interface

The module uses a small AXI4-Stream-style subset:

| Port | Direction | Description |
| --- | --- | --- |
| `s_axis_tvalid` | input | Input beat is valid |
| `s_axis_tready` | output | Core can accept an input beat |
| `s_axis_tdata[7:0]` | input | One signed int8 matrix element |
| `s_axis_tlast` | input | End of input tile frame |
| `m_axis_tvalid` | output | Output beat is valid |
| `m_axis_tready` | input | Downstream can accept an output beat |
| `m_axis_tdata[31:0]` | output | One signed int32 C result |
| `m_axis_tlast` | output | End of output tile frame |
| `busy` | output | Core is computing or draining output |
| `done` | output | One-cycle pulse after the final output beat is accepted |
| `frame_error` | output | Sticky framing error flag, cleared when a new input frame starts |

The first milestone intentionally omits `tkeep`, `tstrb`, and `tuser`. Every
input beat carries exactly one int8 element and every output beat carries exactly
one int32 result, so byte-lane qualification is not needed yet.

## Packet Format

All matrices use row-major order.

Input frame:

1. 16 signed int8 `A` elements on `s_axis_tdata`.
2. 16 signed int8 `B` elements on `s_axis_tdata`.
3. `s_axis_tlast` must be asserted only on the final `B[15]` beat.

Output frame:

1. 16 signed int32 `C` elements on `m_axis_tdata`.
2. `m_axis_tlast` is asserted only on the final `C[15]` beat.

The result is `C = A x B`, using signed int8 operands and signed int32
accumulation.

## FSM

The stream core is a simple tile-at-a-time controller:

| State | Purpose |
| --- | --- |
| `S_LOAD_A` | Accept 16 A elements while `s_axis_tready` is high |
| `S_LOAD_B` | Accept 16 B elements and require `s_axis_tlast` on final B |
| `S_START_MAC` | Pulse start into the internal row4_pipe2 MAC |
| `S_WAIT_MAC` | Wait for the internal MAC to finish |
| `S_OUTPUT` | Emit 16 C elements with valid/ready backpressure |

Input backpressure is handled through `s_axis_tready`. The core deasserts input
ready while computing and while output data is pending, so Milestone 1 does not
accept a new tile while busy. Output backpressure is handled by holding
`m_axis_tvalid`, `m_axis_tdata`, and `m_axis_tlast` stable until
`m_axis_tready` accepts the beat.

## Framing Errors

`frame_error` is set if `s_axis_tlast` arrives before `B[15]`, or if `B[15]` is
accepted without `s_axis_tlast`. The bad frame is discarded and no output frame
is emitted. The flag remains asserted until the first beat of the next input
frame is accepted.

## Current Limitations

- Tile size is fixed at 4x4.
- Input and output streams are not overlapped.
- Only one tile can be in flight.
- The internal compute engine is the timing-oriented row4_pipe2 MAC, not a
  fully streaming systolic or line-buffered datapath.
- There is no packet metadata, byte enable, ID, destination, or user sideband.
- This streaming module has simulation coverage only; it has not been added to
  the ASIC-flow targets.

## Future Work

- Add a streaming wrapper that can queue or double-buffer tiles.
- Overlap input load, MAC execution, and output drain.
- Consider wider stream data widths for packed rows or columns.
- Add optional sideband metadata if integration needs tile IDs or shape fields.
- Evaluate whether a dedicated streaming datapath is preferable to reusing the
  tile MAC for higher-throughput designs.
