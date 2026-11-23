# Contributing

How the team works on this repository: who owns what, how to test a change, and the style every file follows.

## Quick start

```bash
git clone https://github.com/Vetri-78640/TPU-Inspired-Systolic-Array-Accelerator.git
cd TPU-Inspired-Systolic-Array-Accelerator
pip install numpy matplotlib scikit-learn
make test
```

`make test` runs 8 suites and should print 8 lines containing `PASSED` and none containing `FAIL`.

| Tool | Needed for |
|---|---|
| Icarus Verilog 11+ | all simulation (`make test`, `seq`, `stream`, `tiled`, `ws`) |
| Python 3.9+ with NumPy and Matplotlib | test vectors, `make model`, `make perf` |
| scikit-learn | `make nn` |
| Yosys | `make synth`, `make gate` |
| nextpnr-ice40 | `make fmax` |
| A XeTeX engine, such as tectonic | building `report/main.pdf` |

## Ownership

| Area | Owner | Files |
|---|---|---|
| Array core | Vetriselvan R | `rtl/pe.v`, `rtl/systolic_array.v`, `rtl/pe_ws.v`, `rtl/ws_array.v`, `rtl/mm_ws.v`, `tb/pe_tb.v` |
| Input timing and control | Hrishi Dongre | `rtl/skew.v`, `rtl/controller.v`, `rtl/mm_accel.v`, `rtl/mm_stream.v`, `rtl/mm_tiled.v`, `tb/skew_tb.v`, `tb/controller_tb.v` |
| Verification | Ishan Goyal | `scripts/gen_vectors.py`, `scripts/plot_wave.py`, `scripts/nn_demo.py`, `scripts/gatesim.sh`, `scripts/mutation.sh`, `tb/array_tb.v`, `tb/mm_accel_tb.v`, `tb/stream_tb.v`, `tb/tiled_tb.v`, `tb/net_wrap.v` |
| Baseline and performance | Pampana Sree Adithya | `rtl/seq_mac.v`, `rtl/fpga_top.v`, `scripts/os_model.py`, `scripts/perf.py`, `scripts/synth.sh`, `scripts/fmax.sh`, `results/` |
| Report, diagrams and video | Vedant Madne | `scripts/diagrams.py`, `docs/diagrams/`, `report/`, `README.md` |

A change to another member's files goes through that member: ask first, or open an issue and assign it to them.

## Workflow

1. Work from an issue in the current milestone. Open one if the change has none.
2. Make the change and run the checks for it (next section).
3. Commit with a message in the format below. Put `(#n)` at the end of the subject, and `Closes #n` in the body of the commit that finishes the issue.
4. Push. GitHub Actions runs the suites with `PIPE=0` and `PIPE=1`, the baseline, the timing model and the neural network demo, and marks the commit red if any of them fails.

## Checks before pushing

| You changed | Run |
|---|---|
| Anything in `rtl/` | `make test` and `make test PIPE=1` |
| `rtl/controller.v`, `rtl/mm_accel.v` or `rtl/seq_mac.v` | also `make seq` and `make gate` |
| A different array size or `K` | `make accel N=8 K=8`, or the size you changed |
| A testbench | `make mutation`, which must still report `caught 15 of 15` |
| A number in the report or README | the script that produces it (`make perf`, `make synth`, `make fmax` or `make nn`), then copy the value from `results/` |

## Verilog style

- Plain Verilog-2001. The first line of every file is `` `timescale 1ns/1ps ``.
- One module per file, and the file is named after the module.
- 4-space indentation, no tabs. Signals and modules use short `snake_case` names, and parameters use capitals (`N`, `K`, `PIPE`, `W`).
- One port per line in an ANSI header. Mark arithmetic signals `signed` explicitly.
- Synchronous, active-high `rst`. Use non-blocking assignments (`<=`) in clocked blocks and `assign` for combinational logic.
- Size everything from parameters: derive counter and address widths with `$clog2`, and select lanes with `+:`. Never hard-code a width that depends on `N` or `K`.
- Name every generate block (`begin : lane`).
- No `initial` blocks or `$display` in `rtl/`. Those belong in testbenches.
- The code must compile with `iverilog -Wall` without warnings.

```verilog
`timescale 1ns/1ps
module skew #(parameter N = 4, parameter W = 8) (
    input clk,
    input rst,
    input [N*W-1:0] din,
    output [N*W-1:0] dout
);
```

## Testbench style

- Name the testbench `<module>_tb` and save it as `tb/<module>_tb.v`.
- Check every result against an expected value. Expected values come from hand calculation or from the NumPy files written by `scripts/gen_vectors.py`, never from the design itself.
- Print one `FAIL ...` line for each mismatch, giving where it happened, the value received and the value expected. Count mismatches in `errors`.
- Print `ALL ... TESTS PASSED` once, and only when `errors` is 0. CI counts these lines, so a suite must never print a pass without checking.
- Matrix testbenches also print a `RESULT ... errors=<e> cycles=<c>` line. `scripts/perf.py` and `scripts/nn_demo.py` read the cycle counts from it, so keep that format.
- Write waveforms to `sim/` only.

## Python and shell style

- Scripts run from the repository root and write only to `sim/`, `data/` or `results/`.
- Python: standard library imports first, then third-party ones. Constants in capitals at the top of the file. Use `matplotlib.use("Agg")` so plots work without a display.
- Shell: start with `#!/bin/bash` and keep file lists in variables at the top. Use `set -e`, except in scripts like `mutation.sh` that expect some runs to fail.

## Commit messages

Use `type(area): summary`. The area is optional. Start the summary in lower case and leave off the full stop.

```
feat(rtl): add mm_tiled for matrices larger than the array (#5)
test(tb): streaming testbench with per-PE result checks
perf: compare output- and weight-stationary cycles, weight reads and area (#8)
docs(report): describe the Phase II designs and add Results and Discussion
ci: run simulation tests on every push
```

| Type | Use for |
|---|---|
| `feat` | new or changed hardware behaviour |
| `fix` | a bug fix |
| `test` | testbenches, vectors, mutation tests |
| `perf` | measurements, sweeps, synthesis and timing results |
| `docs` | README, report, diagrams, `docs/` |
| `build` | Makefile and tool scripts |
| `ci` | GitHub Actions |
| `chore` | anything else |

Keep each commit to one change, and never commit generated files. `sim/`, `data/`, waveform dumps and LaTeX build files are already ignored. `report/main.pdf` is committed, so rebuild it whenever `report/main.tex` changes.

## Adding a module

1. Write the module in `rtl/`, following the Verilog style above.
2. Add a self-checking testbench in `tb/`, following the testbench style.
3. Add a make target. If the module is part of the core flow, add it to `test`, and CI will expect one more `PASSED` line automatically.
4. If the module is synthesizable, add it to `scripts/synth.sh` and save its report in `results/`.
5. Document its ports and timing in `docs/architecture.md`, and record any design choice in `docs/design_decisions.md`.
