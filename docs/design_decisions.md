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
