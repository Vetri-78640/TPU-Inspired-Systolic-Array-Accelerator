#!/bin/bash
set -e
mkdir -p sim results
RTL="rtl/pe.v rtl/systolic_array.v rtl/skew.v rtl/controller.v rtl/mm_accel.v rtl/fpga_top.v"
out=results/fmax_ice40.txt
echo "Place-and-route timing, Lattice iCE40 HX8K (ct256), nextpnr-ice40" > $out
for cfg in "2 0" "2 1" "4 0" "4 1"; do
    set -- $cfg
    n=$1
    p=$2
    yosys -q -p "read_verilog $RTL; chparam -set N $n -set K $n -set PIPE $p fpga_top; synth_ice40 -top fpga_top -json sim/fpga_n${n}_p$p.json"
    nextpnr-ice40 --hx8k --package ct256 --json sim/fpga_n${n}_p$p.json --freq 12 --seed 1 2> sim/fpga_n${n}_p$p.log
    echo "N=$n K=$n PIPE=$p" >> $out
    grep -m1 -E "ICESTORM_LC:" sim/fpga_n${n}_p$p.log | sed 's/^Info: *[[:space:]]*/  logic cells /' >> $out
    grep -E "Max frequency for clock" sim/fpga_n${n}_p$p.log | tail -1 | sed 's/^Info: */  post-route /' >> $out
done
cat $out
