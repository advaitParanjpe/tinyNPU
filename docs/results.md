# tinyNPU Results

These results come from local simulation and generic Yosys synthesis. They are
useful for tracking relative RTL changes, but they are not technology-mapped
area, timing, or power numbers.

| version | variant | datapath | max latency cycles | total cells | relative latency | relative cells | coverage-style status | notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| v12 | row4 | 4-lane row MAC | 26 | 14321 | 1.00x | 1.00x | scenario summary generated | Default datapath; generic gates only |
| v12 | serial | serial MAC baseline | 66 | 10154 | 2.54x | 0.71x | scenario summary generated | Lower cell count, higher latency; generic gates only |
| v12 | full16 | 16-lane full parallel MAC | 8 | 33956 | 0.31x | 2.37x | scenario summary generated | Lowest latency, highest generic cell count |

Relative values use the default `row4` variant as the baseline. Synthesis is
generic Yosys only, not technology-mapped PPA.

Coverage-style status means the simulation flow emitted
`build/sim/<variant>/coverage_summary.json` from observed passing scenario tests
and enabled checker status. It is scenario coverage, not full UVM-style
functional coverage.
