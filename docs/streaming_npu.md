# Double-Buffered AXI4-Stream NPU Prototype

`tinynpu_axis_stream_npu` is the first true streaming tinyNPU milestone. It is a
separate single-clock RTL path and does not replace `tinynpu_top` or the
tile-at-a-time `tinynpu_axis_stream_tile_core`.

This module is a double-buffered AXI4-Stream tinyNPU prototype: it can load one
tile while another tile is computing, and it can compute one tile while a prior
C tile is being streamed out, as long as the relevant ping-pong buffers are
available.

## Interface

The stream subset is intentionally small:

| Port | Direction | Description |
| --- | --- | --- |
| `s_axis_tvalid` | input | Input beat is valid |
| `s_axis_tready` | output | NPU can accept an input beat |
| `s_axis_tdata[7:0]` | input | One signed int8 A/B element |
| `s_axis_tlast` | input | End of input tile frame |
| `m_axis_tvalid` | output | Output beat is valid |
| `m_axis_tready` | input | Downstream can accept an output beat |
| `m_axis_tdata[31:0]` | output | One signed int32 C element |
| `m_axis_tlast` | output | End of output tile frame |
| `busy` | output | Any load, compute, queued output, or output stream is active |
| `frame_error` | output | Sticky malformed-frame flag, cleared on the next input frame start |

There is no `tkeep`, `tstrb`, `tid`, `tdest`, or `tuser` in this milestone.

## Packet Format

The format matches the tile-at-a-time stream core.

Input tile:

1. 16 signed int8 `A` elements in row-major order.
2. 16 signed int8 `B` elements in row-major order.
3. `s_axis_tlast` asserted only on final `B[15]`.

Output tile:

1. 16 signed int32 `C` elements in row-major order.
2. `m_axis_tlast` asserted only on final `C[15]`.

Malformed input frames are discarded. An early `s_axis_tlast` or a missing final
`s_axis_tlast` sets `frame_error` and releases the input buffer.

## Architecture

The prototype uses:

- two A/B input tile buffers;
- one reused `tinynpu_mac_row4_pipe2` compute engine;
- two C result buffers;
- independent load, compute, and output FSMs.

The load FSM fills an available A/B buffer. The compute FSM claims a full A/B
buffer and a free C buffer, runs the row4_pipe2 MAC, writes the C buffer, and
releases the input buffer. The output FSM streams any full C buffer and releases
it after the final accepted output beat.

## Buffer Ownership

Input buffers use these ownership states:

| State | Meaning |
| --- | --- |
| `IN_FREE` | Available for a new input tile |
| `IN_LOADING` | Owned by the input loader |
| `IN_FULL` | Complete tile waiting for compute |
| `IN_COMPUTE` | Owned by the compute FSM |

Output buffers use these ownership states:

| State | Meaning |
| --- | --- |
| `OUT_FREE` | Available for a new compute result |
| `OUT_COMPUTE` | Reserved by the active compute operation |
| `OUT_FULL` | Complete result tile waiting for output |
| `OUT_STREAM` | Owned by the output FSM |

`s_axis_tready` is asserted when the current input packet is in progress or at
least one input buffer is free. It deasserts when both input buffers are occupied
and the loader cannot claim another buffer. `m_axis_tdata` and `m_axis_tlast`
remain stable while `m_axis_tvalid` is high and `m_axis_tready` is low.

## Timing And Throughput

The current self-checking simulation reports:

| Metric | Value |
| --- | ---: |
| Single-tile latency | 156 cycles |
| Steady-state cycles per tile, back-to-back no output stalls | 64 cycles/tile |
| Maximum input acceptance rate in the current testbench | 63 cycles/tile |
| Load/compute/output overlap observed | Yes |

The measured input acceptance rate includes the simple one-beat-at-a-time
testbench driver overhead. The design has one compute engine, so steady-state
throughput is still compute-limited by the row4_pipe2 MAC plus output scheduling
overhead. This is an overlapped tile pipeline, not a fully parallel multi-MAC
streaming array.

## Verification

`make sim-axis-stream-npu` runs a self-checking testbench covering:

- single-tile identity;
- two back-to-back tiles;
- many back-to-back random tiles;
- input stalls;
- output backpressure;
- simultaneous input and output backpressure;
- output `tlast` correctness for every tile;
- no data mixing between ping-pong buffers;
- reset during load, compute, and output;
- signed edge values including `-128` and `127`;
- explicit input backpressure when buffers are full.

## Limitations

- Fixed 4x4 tile shape.
- One row4_pipe2 MAC engine, so compute is not multi-tile parallel.
- Only two input buffers and two output buffers.
- No packet IDs or metadata, so outputs are emitted in compute/output buffer
  order for this local pipeline.
- No AXI4 sidebands beyond `tvalid`, `tready`, `tdata`, and `tlast`.
- This module has simulation coverage only and is not part of the OpenLane ASIC
  targets.

## Future Work

- Add deeper queues or configurable buffer counts.
- Use a continuous-valid stream driver to measure peak input bandwidth more
  precisely.
- Add optional metadata sidebands for tile IDs if out-of-order or multi-engine
  execution is introduced.
- Explore multiple MAC engines or a systolic/line-buffered datapath for higher
  throughput.
- Add synthesis and ASIC-flow experiments only after the streaming RTL and
  verification plan stabilize.
