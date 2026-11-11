# Architecture specification

Design specification for the output-stationary systolic array accelerator. All numbers below are produced by the code in this repository (`make test`, `make perf`, `make synth`, `make fmax`).

## Module hierarchy

```
fpga_top            board wrapper: 32-bit result read port (synthesis and timing only)
└── mm_accel        top level: buffers, feeders, skew, controller, array
    ├── controller  FSM: IDLE -> CLEAR -> RUN -> DONE, cycle counter t
    ├── skew (x2)   delay row i / column j by i / j cycles
    └── systolic_array
        └── pe (N x N)  one signed MAC with pass-through registers
seq_mac             baseline: one MAC unit, same interface as mm_accel
```

## Parameters

| Parameter | Meaning | Default | Tested |
|---|---|---|---|
| `N` | array is N x N; A is N x K, B is K x N | 4 | 2, 3, 4, 8 |
| `K` | inner dimension | 4 | 2, 3, 4, 8, 16, 32, 64 |

Limits of the current version: the buffer address and the cycle counter are 8 bits, so `N * K <= 256` and `2N + K - 3 <= 255`. For N = 4 this allows K up to 64.

## Interfaces

### `pe`

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | clock, synchronous reset |
| `clr` | in | 1 | zero the accumulator on the next edge |
| `a_in`, `b_in` | in | 8 signed | operands from the left and from above |
| `a_out`, `b_out` | out | 8 signed | operands passed right and down, 1 cycle later |
| `acc` | out | 32 signed | running sum of `a_in * b_in` |

### `systolic_array`

| Port | Dir | Width | Description |
|---|---|---|---|
| `a_left` | in | 8N | `a_left[i*8 +: 8]` enters row i |
| `b_top` | in | 8N | `b_top[j*8 +: 8]` enters column j |
| `c_flat` | out | 32N² | C[i][j] at `c_flat[(i*N + j)*32 +: 32]` |

### `mm_accel` and `seq_mac`

| Port | Dir | Width | Description |
|---|---|---|---|
| `start` | in | 1 | begin a multiplication |
| `wr_en`, `wr_b` | in | 1 | write enable; 0 selects buffer A, 1 selects B |
| `wr_addr`, `wr_data` | in | 8 | A[i][k] at address i*K + k; B[k][j] at k*N + j |
| `busy`, `done` | out | 1 | `done` stays high with stable results until the next `start` |
| `c_flat` | out | 32N² | results, same layout as `systolic_array` |

### `fpga_top`

Adds `sel` (8 bits) and `c_out` (32 bits, registered): `c_out` shows C entry `sel` one cycle later. This keeps the pin count at 63 instead of 512+ output bits.

## Timing

Counting from the clock edge that samples `start`:

| Cycle | State | Action |
|---|---|---|
| 1 | CLEAR | `clr` = 1, all accumulators zeroed |
| 2 .. 2N + K - 1 | RUN | t = 0 .. 2N + K - 3; feeders drive A column t and B row t while t < K, zeros after |
| 2N + K | DONE | `done` = 1, results valid |

- PE(i,j) performs the MAC for index k = t - i - j, so compute takes M + N + K - 2 cycles.
- Measured start-to-done latency: 2N + K cycles for the array, N·N·K + 1 for `seq_mac`.

## Number format

- Operands: signed 8-bit (-128 to 127). Products: up to 16384 (16 bits).
- Accumulators: signed 32-bit, safe for K up to 131,071.

## Implementation results

| Target | Tool | 4x4 result |
|---|---|---|
| Xilinx 7-series | Yosys `synth_xilinx` | 16 DSP48E1, 75 LUTs, 176 FFs |
| Lattice iCE40 HX8K | Yosys + nextpnr-ice40 | 6811 logic cells (88%), 53.48 MHz post-route |
