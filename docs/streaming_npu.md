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
- one compute engine, selected as `tinynpu_mac_row4_pipe2` by default or
  `tinynpu_mac_systolic4x4` with `TINYNPU_MAC_SYSTOLIC4X4`;
- two C result buffers;
- independent load, compute, and output FSMs.

The load FSM fills an available A/B buffer. The compute FSM claims a full A/B
buffer and a free C buffer, runs the selected MAC, writes the C buffer, and
releases the input buffer. The output FSM streams any full C buffer and
releases it after the final accepted output beat. The A/B and C ping-pong
buffers, packet format, and stream ports are identical for both compute
engines.

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

The self-checking simulation reports the following metrics for the
double-buffered AXI4-Stream prototype:

| Compute engine | Single-tile latency | Steady-state cycles/tile | Maximum input acceptance | Overlap |
| --- | ---: | ---: | ---: | --- |
| `row4_pipe2` (default) | 156 cycles | 64 | 63 cycles/tile | Yes |
| `systolic4x4` | 115 cycles | 64 | 63 cycles/tile | Yes |

The measured input acceptance rate includes the simple one-beat-at-a-time
testbench driver overhead. The systolic engine reduces isolated-tile latency,
while the current 32-beat input frame and 16-beat output schedule leave both
variants at the same measured 64-cycle steady-state interval. The design still
has one compute engine, so this is an overlapped tile pipeline rather than a
multi-tile array.

The intended overlap looks like this for consecutive tiles:

```text
Time/cycles  --->

Tile 0       LOAD A/B  | COMPUTE | OUTPUT C
Tile 1                 LOAD A/B  | COMPUTE | OUTPUT C
Tile 2                           LOAD A/B  | COMPUTE | OUTPUT C
Tile 3                                     LOAD A/B  | COMPUTE | OUTPUT C

Stages      input buffer fill overlaps previous compute/output when an input
            buffer is free; compute overlaps previous output when a C buffer is
            free; output can stall independently through m_axis_tready.
```

For a 4x4 matrix multiply, each output tile represents 64 signed int8 MACs
(`4 x 4 x 4`). Using the measured steady-state result:

```text
tiles/s = f_clk / steady_state_cycles_per_tile
MAC/s   = tiles/s * 64
```

Frequency-dependent estimates:

| Clock | Steady-state cycles/tile | Estimated tiles/s | Estimated MAC/s |
| ---: | ---: | ---: | ---: |
| 90 MHz | 64 | 1.40625 M tiles/s | 90.0 M MAC/s |
| 100 MHz | 64 | 1.5625 M tiles/s | 100.0 M MAC/s |

These are arithmetic estimates from simulation-cycle counts. They are not an
ASIC timing-closure claim; this streaming NPU path has not yet been optimized
for ASIC timing or added to the OpenLane implementation targets.

## Verification

`make sim-axis-stream-npu` runs the default row4_pipe2 engine and
`make sim-axis-stream-npu-systolic4x4` runs the same self-checking testbench
with the systolic engine. The testbench covers:

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
- Single-clock RTL only; there is no CDC or multi-clock integration yet.
- One selected MAC engine, so compute is not multi-tile parallel.
- Only two input buffers and two output buffers.
- No packet IDs or metadata, so outputs are emitted in compute/output buffer
  order for this local pipeline.
- No AXI4 sidebands beyond `tvalid`, `tready`, `tdata`, and `tlast`.
- This module has simulation coverage only and is not part of the OpenLane ASIC
  targets.
- Not a production NPU and not yet fully optimized for ASIC timing.

## Future Work

- Add deeper queues or configurable buffer counts.
- Use a continuous-valid stream driver to measure peak input bandwidth more
  precisely.
- Add optional metadata sidebands for tile IDs if out-of-order or multi-engine
  execution is introduced.
- Explore multiple systolic engines or a continuous line-buffered dataflow for
  higher throughput.
- Add synthesis and ASIC-flow experiments only after the streaming RTL and
  verification plan stabilize.
