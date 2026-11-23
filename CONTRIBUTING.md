# Contributing

How the team works on this repository.

---

## Setup

1. Install Icarus Verilog 11+ and Python 3.9+ with NumPy and Matplotlib. Yosys and nextpnr-ice40 are only needed for `make synth` and `make fmax`.
2. Clone the repository and run:

   ```bash
   make test
   ```

   You should see 8 lines ending in `PASSED`. `make nn` also needs scikit-learn.

---

## Ownership

| Area | Owner | Files |
|:--|:--|:--|
| **Array core** | Vetriselvan R | `rtl/pe.v`<br>`rtl/systolic_array.v`<br>`rtl/pe_ws.v`<br>`rtl/ws_array.v`<br>`rtl/mm_ws.v`<br>`tb/pe_tb.v` |
| **Input timing and control** | Hrishi Dongre | `rtl/skew.v`<br>`rtl/controller.v`<br>`rtl/mm_accel.v`<br>`rtl/mm_stream.v`<br>`rtl/mm_tiled.v`<br>`tb/skew_tb.v`<br>`tb/controller_tb.v` |
| **Verification** | Ishan Goyal | `scripts/gen_vectors.py`<br>`scripts/plot_wave.py`<br>`scripts/nn_demo.py`<br>`scripts/gatesim.sh`<br>`scripts/mutation.sh`<br>`tb/array_tb.v`<br>`tb/mm_accel_tb.v`<br>`tb/stream_tb.v`<br>`tb/tiled_tb.v`<br>`tb/net_wrap.v` |
| **Baseline and performance** | Pampana Sree Adithya | `rtl/seq_mac.v`<br>`rtl/fpga_top.v`<br>`scripts/os_model.py`<br>`scripts/perf.py`<br>`scripts/synth.sh`<br>`scripts/fmax.sh`<br>`results/` |
| **Report, diagrams and video** | Vedant Madne | `scripts/diagrams.py`<br>`docs/diagrams/`<br>`report/`<br>`README.md` |

> Changes to another member's files go through that member.

---

## Rules

- Run `make test` before every push. GitHub Actions runs it again on every push and marks the commit red if any test fails.
- A testbench must print `PASSED` or `FAIL`. Never print a pass without checking a result.
- Every number in the report or README must come from `results/` or a test log.
- Do not commit generated files: `sim/`, `data/` and waveform dumps are ignored.
- Keep commits small, one change each.

---

## Commit messages

Use a type and an area:

```text
feat(rtl): add tiling support to the controller
test(tb): add back-to-back run test
docs(report): add results section
build: add fmax target
ci: cache Python packages
```

**Types:** `feat` · `fix` · `test` · `docs` · `build` · `ci` · `chore`

---

## Adding a module

1. Write the module in `rtl/` with a `timescale` line, plain Verilog-2001.
2. Add a self-checking testbench in `tb/` that prints `PASSED` or `FAIL`.
3. Add a make target and, if it is part of the core flow, add it to `test`.
4. Update `docs/architecture.md` with its ports and timing.
