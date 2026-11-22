# Architecture specification

Design specification for the output-stationary systolic array accelerator. All numbers below are produced by the code in this repository (`make test`, `make perf`, `make synth`, `make fmax`, `make nn`).

## Module hierarchy

```
fpga_top              board wrapper: 32-bit result read port (synthesis and timing only)
└── mm_accel          one matrix at a time: buffers, feeders, skew, controller, array
    ├── controller    FSM: IDLE -> CLEAR -> RUN -> DONE, cycle counter t
    ├── skew (x2)     delay row i / column j by i / j cycles
    └── systolic_array
        └── pe (N x N)  one signed MAC with pass-through registers

mm_tiled              matrices larger than the array: buffers, tile feeder, result buffer
└── mm_stream         back-to-back matrices, no clear between them
    ├── skew (x3)     A, B and the 1-bit "last" flag
    └── systolic_array

mm_ws                 weight-stationary variant, same interface as mm_tiled
├── skew (x2)         A in, and output deskew (32-bit lanes)
└── ws_array
    └── pe_ws (N x N) holds one weight; A moves right, partial sums move down

seq_mac               baseline: one MAC unit, same interface as mm_accel
```

## Parameters

| Parameter | Meaning | Default | Tested |
|---|---|---|---|
| `N` | array is N x N | 4 | 2, 3, 4, 8, 16 |
| `K` | inner dimension | 4 | 1 to 256 |
| `M`, `P` | `mm_tiled` only: A is M x K, B is K x P; M and P are multiples of N | 8 | M up to 360, P up to 32 |
| `PIPE` | 1 adds a register between the multiplier and the adder | 0 | 0, 1 |

Address and counter widths are derived from the parameters with `$clog2`, so there is no fixed size limit. The accumulator is 32 bits, which bounds K at 131,071.

## Interfaces

### `pe`

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | clock, synchronous reset |
| `clr` | in | 1 | zero the accumulator on the next edge |
| `last_in` | in | 1 | this is the last k of the current matrix |
| `a_in`, `b_in` | in | 8 signed | operands from the left and from above |
| `a_out`, `b_out`, `last_out` | out | 8, 8, 1 | operands and flag passed on, 1 cycle later |
| `acc` | out | 32 signed | running sum of `a_in * b_in` |
| `res` | out | 32 signed | finished result, written when `last_in` is set |
| `valid` | out | 1 | one-cycle pulse when `res` is written |

On `last_in` the PE writes `res <= acc + a*b` and restarts `acc` at 0, so the next matrix starts in the following cycle without a clear. With `PIPE = 1` the product and the flag are registered first, and every result appears one cycle later.

### `systolic_array`

| Port | Dir | Width | Description |
|---|---|---|---|
| `last_left` | in | N | `last_left[i]` enters row i and moves right with A |
| `a_left` | in | 8N | `a_left[i*8 +: 8]` enters row i |
| `b_top` | in | 8N | `b_top[j*8 +: 8]` enters column j |
| `c_flat` | out | 32N² | running sums, C[i][j] at `c_flat[(i*N + j)*32 +: 32]` |
| `r_flat`, `v_flat` | out | 32N², N² | finished results and valid pulses, same layout |

### `mm_accel` and `seq_mac`

| Port | Dir | Width | Description |
|---|---|---|---|
| `start` | in | 1 | begin a multiplication |
| `wr_en`, `wr_b` | in | 1 | write enable; 0 selects buffer A, 1 selects B |
| `wr_addr`, `wr_data` | in | log2(NK), 8 | A[i][k] at address i*K + k; B[k][j] at k*N + j |
| `busy`, `done` | out | 1 | `done` stays high with stable results until the next `start` |
| `c_flat` | out | 32N² | results, same layout as `systolic_array` |

### `mm_stream`

| Port | Dir | Width | Description |
|---|---|---|---|
| `a_col`, `b_row` | in | 8N each | column k of A and row k of B, one k per cycle, matrices back to back |
| `in_last` | in | 1 | set with k = K - 1 of each matrix |
| `r_flat`, `v_flat` | out | 32N², N² | each PE's result and valid pulse |

K is not a parameter here: the host ends each matrix with `in_last`, so K can change from one matrix to the next.

### `mm_tiled`

| Port | Dir | Width | Description |
|---|---|---|---|
| `start`, `busy`, `done` | | 1 | same handshake as `mm_accel` |
| `wr_en`, `wr_b`, `wr_addr`, `wr_data` | in | | A[r][k] at r*K + k; B[k][c] at k*P + c |
| `rd_addr`, `rd_data` | in, out | log2(MP), 32 | C[r][c] at address r*P + c, registered read |

The feeder walks the output tiles row by row. For tile (ti, tj) it streams rows ti*N .. ti*N+N-1 of A and columns tj*N .. tj*N+N-1 of B for K cycles, then moves to the next tile with no gap. Each PE has its own tile counter, so it writes every result to the right place in the result buffer. `done` rises when the bottom-right PE, the last to finish, has written its result for the final tile.

### `mm_ws`

Same ports as `mm_tiled`, with K and P multiples of N (M can be any size). PE(k,j) holds B[k][j]. For each weight tile it spends N cycles shifting the weights down the columns, then streams the M rows of A through the array, one row per cycle. Partial sums flow down each column and leave at the bottom, where a deskew lines them up into one output row per cycle. Results for K > N are added across weight tiles in the result buffer.

### `fpga_top`

Adds `sel` and `c_out` (32 bits, registered): `c_out` shows C entry `sel` one cycle later. This keeps the pin count low instead of 512+ output bits.

## Timing

`mm_accel`, counting from the clock edge that samples `start`:

| Cycle | State | Action |
|---|---|---|
| 1 | CLEAR | `clr` = 1, all accumulators zeroed |
| 2 .. 2N + K - 1 + PIPE | RUN | t = 0 .. 2N + K - 3 + PIPE; feeders drive A column t and B row t while t < K, zeros after |
| 2N + K + PIPE | DONE | `done` = 1, results valid |

| Design | Cycles |
|---|---|
| `mm_accel` | 2N + K + PIPE, start to done |
| `mm_stream`, B matrices back to back | B·K + 2N - 2 + PIPE, first input to last result; K per matrix in steady state |
| `mm_tiled` | T·K + 2N + 1 + PIPE, start to done, with T = (M/N)(P/N) tiles |
| `mm_ws` | (K/N)(P/N)·(M + 3N - 1) + 1, start to done |
| `seq_mac` | N·N·K + 1 |

PE(i,j) performs the MAC for index k = t - i - j, so one matrix takes M + N + K - 2 compute cycles.

## Number format

- Operands: signed 8-bit (-128 to 127). Products: up to 16384 (16 bits).
- Accumulators: signed 32-bit, safe for K up to 131,071.

## Implementation results

| Design | Tool | Result |
|---|---|---|
| `mm_accel` 4x4 | Yosys `synth_xilinx` (7-series) | 16 DSP48E1, 70 LUTs, 172 FFs, 16 RAM32M |
| `mm_accel` 4x4, PIPE = 1 | Yosys `synth_xilinx` | same; the product register becomes the DSP48E1's internal MREG |
| `mm_stream` 4x4 | Yosys `synth_xilinx` | 16 DSP48E1, 7 LUTs, 679 FFs |
| `mm_tiled` 4x4, 8x8x8 | Yosys `synth_xilinx` | 16 DSP48E1, 6000 LUTs, 2839 FFs, 24 RAM64M |
| `mm_ws` 4x4, 8x8x8 | Yosys `synth_xilinx` | 16 DSP48E1, 2601 LUTs, 2395 FFs, 24 RAM64M |
| `fpga_top` 4x4 | nextpnr-ice40, HX8K | PIPE = 0: 6942 logic cells (90%), 55.14 MHz; PIPE = 1: 4679 (60%), 73.04 MHz |
| `fpga_top` 2x2 | nextpnr-ice40, HX8K | PIPE = 0: 1688 logic cells (21%), 62.08 MHz; PIPE = 1: 1142 (14%), 89.34 MHz |

- On the iCE40, which has no DSP blocks, the pipeline register also saves area. Without it, Yosys fuses the multiplier and the 32-bit adder into one `$macc` cell that maps poorly to LUTs; with it, the adder uses the iCE40 carry chain.
- The tiled design's cost is the result buffer: 16 PEs can write in the same cycle, so it is built from flip-flops with 16 write ports.
- Output-stationary against weight-stationary (`results/os_vs_ws.csv`): for one layer of the digit classifier (360x64 by 64x32), OS takes 46,089 cycles and WS 47,489 (3% more), but WS reads each weight once (2048 reads) while OS reads B again for every row of tiles (184,320 reads). WS loses on small matrices because each weight tile costs N cycles to load and 2N - 1 to drain.
- `make gate` simulates the synthesized iCE40 netlists (PIPE 0 and 1) against the same 106 test cases.
