# Changelog

## v14

- Refactored A/B matrix storage into reusable int8 scratchpad modules.
- Refactored C result storage into a reusable int32 result-buffer module.
- Preserved the public bus interface, address map, and MAC variant behavior.

## v13

- Added `scripts/check_repo.py` for lightweight repository quality checks.
- Added `make check`, `make precommit`, and development workflow docs.

## v12

- Documented the simple register bus protocol.
- Added bus protocol tests for always-ready behavior, A/B readback, C read-only
  storage, ignored CTRL bits, and unaligned accesses.

## v11

- Added coverage-style scenario reporting from simulation output.
- Added per-variant `coverage_summary.json` artifacts and coverage documentation.

## v10

- Cleanup, reproducibility, and commit-readiness pass.
- Confirmed clean rebuild through `make clean`, `make golden`, and `make compare`.

## v9

- Added `full16`, a 16-output full-parallel MAC variant.
- Extended simulation, synthesis, and result flows to compare `serial`, `row4`, and `full16`.

## v8

- Added architecture variant framework.
- Added `serial` MAC baseline while keeping `row4` as the default.

## v7

- Added structured simulation, synthesis, and result summaries.
- Added result snapshot tooling and architecture variant documentation.

## v6

- Added generic Yosys synthesis flow and synthesis report parsing.

## v5

- Replaced the serial-style default datapath with the four-lane `row4` MAC.

## v4

- Added lightweight simulation checkers and latency measurement.

## v3

- Added control/status, reset, invalid access, and signed arithmetic edge-case tests.

## v2

- Added deterministic random golden-model test vector generation.

## v1

- Added simple register bus, CTRL/STATUS, and A/B/C storage around the MAC array.

## v0

- Created fixed 4x4 signed int8 matrix multiply RTL, Python golden model, and self-checking simulation.
