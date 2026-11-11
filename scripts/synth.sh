#!/bin/bash
set -e
mkdir -p results
RTL="rtl/pe.v rtl/systolic_array.v rtl/skew.v rtl/controller.v rtl/mm_accel.v"
for n in 2 4 8; do
    yosys -q -p "read_verilog $RTL; chparam -set N $n -set K $n mm_accel; synth_xilinx -family xc7 -flatten -top mm_accel; tee -o results/synth_n$n.txt stat"
done
yosys -q -p "read_verilog rtl/seq_mac.v; chparam -set N 4 -set K 4 seq_mac; synth_xilinx -family xc7 -flatten -top seq_mac; tee -o results/synth_seq_n4.txt stat"
echo "synthesis reports written to results/"
