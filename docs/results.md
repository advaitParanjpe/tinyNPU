# tinyNPU Results

These results come from local simulation and generic Yosys synthesis. They are
useful for tracking relative RTL changes, but they are not technology-mapped
area, timing, or power numbers.

| version | variant | datapath | max latency cycles | total cells | relative latency | relative cells | notes |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| v10 | row4 | 4-lane row MAC | 26 | 14321 | 1.00x | 1.00x | Default datapath; generic gates only |
| v10 | serial | serial MAC baseline | 66 | 10154 | 2.54x | 0.71x | Lower cell count, higher latency; generic gates only |
| v10 | full16 | 16-lane full parallel MAC | 8 | 33956 | 0.31x | 2.37x | Lowest latency, highest generic cell count |

Relative values use the default `row4` variant as the baseline. Synthesis is
generic Yosys only, not technology-mapped PPA.
