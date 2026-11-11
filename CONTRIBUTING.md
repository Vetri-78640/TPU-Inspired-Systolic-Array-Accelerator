# Contributing

How the team works on this repository.

## Setup

1. Install Icarus Verilog 11+ and Python 3.9+ with NumPy and Matplotlib. Yosys and nextpnr-ice40 are only needed for `make synth` and `make fmax`.
2. Clone the repository and run `make test`. You should see 5 lines ending in `PASSED`.

## Ownership

| Area | Owner | Files |
|---|---|---|
| Array core | Vetriselvan R | `rtl/pe.v`, `rtl/systolic_array.v`, `tb/pe_tb.v` |
| Input timing and control | Hrishi Dongre | `rtl/skew.v`, `rtl/controller.v`, `rtl/mm_accel.v`, `tb/skew_tb.v`, `tb/controller_tb.v` |
| Verification | Ishan Goyal | `scripts/gen_vectors.py`, `scripts/plot_wave.py`, `tb/array_tb.v`, `tb/mm_accel_tb.v` |
| Baseline and performance | Pampana Sree Adithya | `rtl/seq_mac.v`, `rtl/fpga_top.v`, `scripts/os_model.py`, `scripts/perf.py`, `scripts/synth.sh`, `scripts/fmax.sh`, `results/` |
| Report, diagrams and video | Vedant Madne | `scripts/diagrams.py`, `docs/diagrams/`, `report/`, `README.md` |

Changes to another member's files go through that member.

## Rules

- Run `make test` before every push. GitHub Actions runs it again on every push and marks the commit red if any test fails.
- A testbench must print `PASSED` or `FAIL`. Never print a pass without checking a result.
- Every number in the report or README must come from `results/` or a test log.
- Do not commit generated files: `sim/`, `data/` and waveform dumps are ignored.
- Keep commits small, one change each.

## Commit messages

Use a type and an area:

```
feat(rtl): add tiling support to the controller
test(tb): add back-to-back run test
docs(report): add results section
build: add fmax target
ci: cache Python packages
```

Types: `feat`, `fix`, `test`, `docs`, `build`, `ci`, `chore`.

## Adding a module

1. Write the module in `rtl/` with a `timescale` line, plain Verilog-2001.
2. Add a self-checking testbench in `tb/` that prints `PASSED` or `FAIL`.
3. Add a make target and, if it is part of the core flow, add it to `test`.
4. Update `docs/architecture.md` with its ports and timing.
