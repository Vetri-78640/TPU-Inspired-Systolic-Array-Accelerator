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
- [ ] Demo video (link in README)

## Phase II

| Goal | Area | Done when |
|---|---|---|
| Streaming back-to-back matrices | timing and control, array core | a "first" flag travels with the data so each PE restarts on its own; one 4x4x4 result every 4 cycles instead of 12, utilization near 100% |
| Pipelined MAC | array core | register between multiply and add; fmax before and after on iCE40 (and Vivado) |
| Xilinx timing | performance | Vivado post-route fmax and utilization for the 4x4 array on a 7-series part |
| Tiling | timing and control | matrices larger than the array (for example 8x8 on a 4x4) multiply correctly, with cycle counts |
| Wider limits | timing and control | buffer address and counter widths derived from N and K, so N·K > 256 works |
| Neural network demo | verification | one quantized layer (int8 weights) runs on the accelerator and matches the NumPy result |
| Weight-stationary comparison (optional) | array core | WS variant with the same tests, cycle and resource comparison with OS |
| Final report | documentation | Results and Discussion and Conclusion sections added |
| Interview preparation | everyone | each member can explain their own part and the overall design |
