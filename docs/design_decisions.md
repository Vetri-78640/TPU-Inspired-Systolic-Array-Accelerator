# Design decisions

Each decision records what we chose, why, and what it costs. New decisions are added at the end; old ones are marked superseded rather than edited.

## D1 - Systolic array (Project 12)

- **Choice:** a matrix multiplication accelerator built from a grid of processing elements.
- **Why:** matrix multiplication is the core operation of neural networks, and a systolic array (the structure behind Google's TPU) reuses every operand across a whole row or column of PEs instead of fetching it again from memory.

## D2 - Output-stationary dataflow

- **Choice:** each PE keeps its own output C[i][j]; A moves right, B moves down.
- **Why:** no weight-loading phase, no partial sums moving between PEs, and no adders outside the array. This keeps the control simple and each PE self-contained.
- **Cost:** results must be read out of every PE, and utilization is low for small K (33% at 4x4x4). Weight-stationary designs such as TPU v1 can be faster in practice.

## D3 - Signed 8-bit operands, 32-bit accumulators

- **Why:** the same widths as the TPU and as integer-only neural network inference (int8 weights and activations, int32 sums). The largest product is -128 x -128 = 16384, so 32 bits cannot overflow for K up to 131,071.

## D4 - Plain Verilog-2001

- **Why:** the course specifies Verilog, and plain Verilog-2001 works unchanged in Icarus Verilog, Yosys and nextpnr. Multi-dimensional ports are avoided by using packed buses.

## D5 - Hardware skew instead of pre-skewed inputs

- **Choice:** row i and column j are delayed inside the accelerator by shift registers.
- **Why:** the accelerator accepts plain row-major matrices, so the host needs no knowledge of the array timing. The bare array is still tested separately with testbench-generated skew to keep array bugs and skew bugs apart.

## D6 - NumPy as the reference model

- **Choice:** Python generates test matrices and expected results as hex files; the Verilog testbench compares every output.
- **Why:** exact integer reference (int64), easy random and edge-case generation, and the same vectors drive both the systolic array and the sequential baseline.

## D7 - Sequential single-MAC baseline with the same interface

- **Why:** the brief asks for a comparison with sequential multiplication. Sharing the buffers and ports means one testbench and identical inputs measure both designs.

## D8 - Simulation and open-source synthesis

- **Choice:** Icarus Verilog for simulation, Yosys for resource counts, nextpnr-ice40 for post-route timing.
- **Why:** no FPGA board is available and Vivado does not run on macOS. The tools are free and scripted, so every number in the report can be reproduced with one `make` command.
- **Open:** Xilinx timing with Vivado on a lab PC in Phase II.

## D9 - A "last" flag instead of a global clear (Phase II)

- **Choice:** a 1-bit flag travels with A along each row. When a PE sees it, it stores its result and restarts its accumulator in the same cycle.
- **Why:** a global clear stops the whole array between matrices, so a 4x4x4 product took 12 cycles for 4 cycles of useful work. With the flag, each PE moves to the next matrix on its own and the array stays busy (98.6% utilization over 106 back-to-back matrices).
- **Cost:** a 32-bit result register and a valid bit per PE. Results leave the array on a diagonal wavefront, so the consumer captures each one on its valid pulse instead of reading all of them at once.

## D10 - Optional pipelined MAC (Phase II)

- **Choice:** a parameter `PIPE` adds a register between the multiplier and the adder.
- **Why:** it shortens the critical path. On the iCE40 the 4x4 design goes from 55.14 to 73.04 MHz for one extra cycle of latency.
- **Cost:** one cycle of latency; no extra area on Xilinx, where the register becomes the DSP48E1's MREG.

## D11 - Tiling in hardware with per-PE tile counters (Phase II)

- **Choice:** `mm_tiled` streams one output tile after another through `mm_stream`, and each PE counts its own tiles to know where its result goes.
- **Why:** PEs finish a tile at different times (the wavefront), so one shared tile index would be wrong for some PEs. Counting per PE keeps the write address correct without a delay line.
- **Cost:** the result buffer needs up to N² writes in one cycle, so it is built from flip-flops (2839 FFs for 8x8x8 on a 4x4 array). A drain network or output FIFO would be cheaper.

## D12 - Widths derived from parameters (Phase II)

- **Choice:** buffer addresses and the cycle counter use `$clog2` of the sizes they index.
- **Why:** the fixed 8-bit widths of Phase I limited N·K to 256. Now N = 4, K = 256 (1024 entries) and N = 16 work with no edits.

## D13 - Neural network demo with host-side activation (Phase II)

- **Choice:** the accelerator runs both matrix multiplications of a 64-32-10 digit classifier; bias, ReLU and int8 rescaling run in Python between layers.
- **Why:** this is the same split as the TPU, where matrix multiplication runs in the array and activations run in a separate unit. It shows the accelerator on real data with an exact NumPy check.

## D14 - Weight-stationary variant for comparison (Phase II)

- **Choice:** `mm_ws` keeps one weight in each PE and moves partial sums down the columns, as in TPU v1. It has the same ports as `mm_tiled`, so one testbench checks both.
- **Why:** to measure the trade-off instead of assuming it. WS reads each weight from the buffer once; OS reads B again for every row of output tiles (90 times for the 360-row digit layer). Throughput is close for tall matrices, and WS needs only N result writes per cycle instead of N², so it uses fewer LUTs.
- **Cost:** without double-buffered weights, each weight tile adds N load cycles and 2N - 1 drain cycles, so WS is slower on small matrices (16 against 13 cycles at 4x4x4).
