#!/bin/bash
set -e
mkdir -p results
CORE="rtl/pe.v rtl/systolic_array.v rtl/skew.v"
RTL="$CORE rtl/controller.v rtl/mm_accel.v"
xc7() {
    yosys -q -p "read_verilog $1; chparam $2 $3; synth_xilinx -family xc7 -flatten -top $3; tee -o results/$4.txt stat"
}
for n in 2 4 8; do
    xc7 "$RTL" "-set N $n -set K $n" mm_accel synth_n$n
done
xc7 "$RTL" "-set N 4 -set K 4 -set PIPE 1" mm_accel synth_n4_pipe
xc7 "rtl/seq_mac.v" "-set N 4 -set K 4" seq_mac synth_seq_n4
xc7 "$CORE rtl/mm_stream.v" "-set N 4" mm_stream synth_stream_n4
xc7 "$CORE rtl/mm_stream.v rtl/mm_tiled.v" "-set N 4 -set M 8 -set K 8 -set P 8" mm_tiled synth_tiled_n4_8x8
echo "synthesis reports written to results/"
