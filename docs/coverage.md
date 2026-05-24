# tinyNPU Coverage-Style Reporting

tinyNPU uses lightweight scenario coverage reporting. This is not full
functional coverage with covergroups or a UVM environment. The simulator wrapper
parses observed passing test names and checker status, then writes a structured
JSON summary.

## Generated Artifacts

Run one variant:

```sh
make sim
```

Run all variants:

```sh
make compare
```

Coverage summaries are written to:

- `build/sim/row4/coverage_summary.json`
- `build/sim/serial/coverage_summary.json`
- `build/sim/full16/coverage_summary.json`

The selected variant's `sim_summary.json` also records the coverage summary
path, number of passed coverage categories, and known gap count.

## Covered Now

- Functional scenarios: identity, all zeros, all ones, mixed signed values.
- Arithmetic edge cases: max positive, min negative times positive,
  alternating extremes, sparse single nonzero.
- Control/status scenarios: back-to-back operations, start while busy, sticky
  done and clear, new start after done, reset mid-operation.
- Bus behavior: invalid reads return zero and invalid writes are ignored.
- Random testing: deterministic golden-model vectors, 50 tests by default.
- Checker suite: busy/done mutex, start ignored while busy, bounded done after
  start, reset clears status, C stable while done is sticky.
- Variant regression: `serial`, `row4`, and `full16` through `make compare`.

## Known Gaps

- No AXI/APB protocol coverage yet.
- No SRAM macro or memory timing coverage yet.
- No formal proof yet.
- Only fixed 4x4 matrix size currently tested.
