# tinyNPU Results

These results come from local simulation and generic Yosys synthesis. They are
useful for tracking relative RTL changes, but they are not technology-mapped
area, timing, or power numbers.

| version | variant | datapath | max latency cycles | total cells | relative latency | relative cells | coverage-style status | notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| v24 | row4 | 4-lane row MAC | 26 | 14514 | 1.00x | 1.00x | scenario summary generated | Default datapath; generic gates only |
| v24 | serial | serial MAC baseline | 66 | 10347 | 2.54x | 0.71x | scenario summary generated | Lower cell count, higher latency; generic gates only |
| v24 | full16 | 16-lane full parallel MAC | 8 | 34149 | 0.31x | 2.35x | scenario summary generated | Lowest latency, highest generic cell count |

APB wrapper synthesis is tracked separately because it changes the integration
top, not the MAC datapath comparison.

| version | top | wrapped core | total cells | notes |
| --- | --- | --- | ---: | --- |
| v24 | `tinynpu_apb_wrapper` | row4 | 14560 | Generic Yosys only; APB wrapper around default core |
| v24 | `tinynpu_dma_descriptor_wrapper` | row4 | 17054 | Generic Yosys only; descriptor registers plus DMA FSM, abstract external memory port, and APB-wrapped core; no AXI |

The descriptor-driven APB DMA-style testbench still exists as a higher-level
simulation model. The synthesizable descriptor wrapper now has its own abstract
memory port and data-movement tests.
v24 adds simulation performance reporting for the descriptor wrapper. It does
not change synthesis, so RTL synthesis size is unchanged from v21-v23.

## DMA Descriptor Wrapper Performance

Measured by `make sim-dma-desc` over the abstract memory port:

| memory mode | tests | min total | max total | avg total | avg LOAD_A | avg LOAD_B | avg START_CORE | avg WAIT_CORE | avg STORE_C |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| always_ready | 6 | 168 | 177 | 175.5 | 29.5 | 32.0 | 1.0 | 31.0 | 80.0 |
| fixed_latency | 2 | 369 | 369 | 369.0 | 95.0 | 96.0 | 1.0 | 31.0 | 144.0 |
| random_backpressure | 3 | 367 | 369 | 367.7 | 94.3 | 96.7 | 1.0 | 31.0 | 142.7 |

These are simulation cycle counts, not AXI timing.

Relative values use the default `row4` variant as the baseline. Synthesis is
generic Yosys only, not technology-mapped PPA.

Coverage-style status means the simulation flow emitted
`build/sim/<variant>/coverage_summary.json` from observed passing scenario tests
and enabled checker status. It is scenario coverage, not full UVM-style
functional coverage.
