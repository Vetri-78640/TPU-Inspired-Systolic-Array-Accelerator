#!/bin/bash
set -e
mkdir -p sim results
RTL="rtl/pe.v rtl/systolic_array.v rtl/skew.v rtl/controller.v rtl/mm_accel.v rtl/fpga_top.v"
out=results/fmax_ice40.txt
echo "Place-and-route timing, Lattice iCE40 HX8K (ct256), nextpnr-ice40" > $out
for n in 2 4; do
    yosys -q -p "read_verilog $RTL; chparam -set N $n -set K $n fpga_top; synth_ice40 -top fpga_top -json sim/fpga_n$n.json"
    nextpnr-ice40 --hx8k --package ct256 --json sim/fpga_n$n.json --freq 12 --seed 1 --report sim/fpga_n$n.rpt.json 2> sim/fpga_n$n.log
    echo "N=$n K=$n" >> $out
    grep -m1 -E "ICESTORM_LC:" sim/fpga_n$n.log | sed 's/^Info: *[[:space:]]*/  logic cells /' >> $out
    grep -E "Max frequency for clock" sim/fpga_n$n.log | tail -1 | sed 's/^Info: */  post-route /' >> $out
done
cat $out
