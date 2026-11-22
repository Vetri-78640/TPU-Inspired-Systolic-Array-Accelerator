# Roadmap

## Phase I (due 16 Nov 2026) - done

- [x] Processing element and parameterized N x N systolic array
- [x] Hardware skew, controller FSM and top level with buffers
- [x] NumPy reference model, unit testbenches and 106-case accelerator test
- [x] Sequential single-MAC baseline and cycle comparison
- [x] Yosys resource results and iCE40 post-route timing
- [x] Block, PE, wavefront and waveform diagrams
- [x] Phase I IEEE report
- [x] Continuous integration on every push
- [x] Demo video (link in README)

## Phase II

| Goal | Area | Status |
|---|---|---|
| Streaming back-to-back matrices | timing and control, array core | done: 106 matrices of 4x4x4 in 430 cycles (4.06 per matrix, was 12), 98.6% utilization |
| Pipelined MAC | array core | done: iCE40 fmax 55.14 to 73.04 MHz at 4x4, one extra cycle of latency |
| Wider limits | timing and control | done: widths from `$clog2`, tested up to N = 4, K = 256 and N = 16 |
| Tiling | timing and control | done: `mm_tiled`, for example 8x8x8 on the 4x4 array in 41 cycles (single MAC: 513) |
| Neural network demo | verification | done: 64-32-10 digit classifier, both layers on the accelerator, exact match with NumPy, 96.67% accuracy |
| Gate-level check | verification | done: synthesized iCE40 netlists pass all 106 cases |
| Xilinx timing | performance | open: Vivado does not run on macOS; iCE40 post-route timing and Yosys Xilinx resource counts are used instead |
| Weight-stationary comparison | array core | done: `mm_ws`, same tests as tiling, digit classifier exact on both; 3% slower than OS at 360x64x32 but 90x fewer weight reads |
| Final report | documentation | Results and Discussion and Conclusion sections |
| Interview preparation | everyone | each member can explain their own part and the overall design |
