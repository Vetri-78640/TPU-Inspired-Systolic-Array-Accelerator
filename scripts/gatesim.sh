#!/bin/bash
set -e
mkdir -p sim
RTL="rtl/pe.v rtl/systolic_array.v rtl/skew.v rtl/controller.v rtl/mm_accel.v"
CELLS=$(yosys-config --datdir)/ice40/cells_sim.v
python3 scripts/gen_vectors.py --n 4 --k 4 --count 100
for p in 0 1; do
    yosys -q -p "read_verilog $RTL; chparam -set N 4 -set K 4 -set PIPE $p mm_accel; synth_ice40 -top mm_accel; rename mm_accel mm_net; write_verilog -noattr sim/net_p$p.v"
    iverilog -g2012 -DNO_ICE40_DEFAULT_ASSIGNMENTS -DDUT=net_wrap -o sim/gate_p$p sim/net_p$p.v tb/net_wrap.v $CELLS tb/mm_accel_tb.v
    echo "iCE40 netlist PIPE=$p"
    vvp -n sim/gate_p$p | grep -E "RESULT|PASSED|FAIL"
done
