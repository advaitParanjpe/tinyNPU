# tinyNPU Development

## Local Workflow

Run quick repository checks before starting or committing:

```sh
make check
```

Run the default simulation while editing RTL or tests:

```sh
make sim
```

Run the APB wrapper, DMA descriptor wrapper, and DMA-style model smoke
regressions when touching integration logic:

```sh
make sim-apb
make sim-apb-dma
make sim-dma-desc
make synth-apb
make synth-dma-desc
```

Run the full variant comparison before commit:

```sh
make compare
```

Check the working tree before committing:

```sh
git status
```

## Precommit

Use the longer precommit target when a change is ready:

```sh
make precommit
```

This runs `make check`, `make golden`, `make compare`, `make sim-apb`,
`make sim-apb-dma`, `make sim-dma-desc`, `make synth-apb`, and
`make synth-dma-desc`.

## Tools

Required for the full flow:

- Python 3
- Icarus Verilog (`iverilog` and `vvp`) for simulation
- Yosys for generic synthesis
- `make`

`make check` reports missing `iverilog` or `yosys` as skipped tool checks, not
repository failures, so documentation and static checks can still run in lighter
environments.

## Generated Outputs

`build/` is ignored. Simulation, synthesis, coverage, and result summaries are
regenerated there by the make targets.
