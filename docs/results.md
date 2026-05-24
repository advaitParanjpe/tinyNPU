# tinyNPU Results

These results come from local simulation and generic Yosys synthesis. They are
useful for tracking relative RTL changes, but they are not technology-mapped
area, timing, or power numbers.

| version | variant | datapath | max latency cycles | total cells | relative latency | relative cells | coverage-style status | notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| v17 | row4 | 4-lane row MAC | 26 | 14514 | 1.00x | 1.00x | scenario summary generated | Default datapath; generic gates only |
| v17 | serial | serial MAC baseline | 66 | 10347 | 2.54x | 0.71x | scenario summary generated | Lower cell count, higher latency; generic gates only |
| v17 | full16 | 16-lane full parallel MAC | 8 | 34149 | 0.31x | 2.35x | scenario summary generated | Lowest latency, highest generic cell count |

APB wrapper synthesis is tracked separately because it changes the integration
top, not the MAC datapath comparison.

| version | top | wrapped core | total cells | notes |
| --- | --- | --- | ---: | --- |
| v17 | `tinynpu_apb_wrapper` | row4 | 14560 | Generic Yosys only; APB wrapper around default core |

The descriptor-driven DMA-style APB testbench is simulation-only and does not
add synthesizable descriptor or DMA RTL, so it has no synthesis row.

Relative values use the default `row4` variant as the baseline. Synthesis is
generic Yosys only, not technology-mapped PPA.

Coverage-style status means the simulation flow emitted
`build/sim/<variant>/coverage_summary.json` from observed passing scenario tests
and enabled checker status. It is scenario coverage, not full UVM-style
functional coverage.
