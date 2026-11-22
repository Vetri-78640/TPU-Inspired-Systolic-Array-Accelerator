#!/bin/bash
mkdir -p sim/mut results
D=sim/mut
CORE="rtl/pe.v rtl/systolic_array.v rtl/skew.v"
out=results/mutation.txt
caught=0
total=0

check() {
    total=$((total + 1))
    if [ "$2" = 0 ]; then
        echo "MISSED  $1" >> $out
    else
        caught=$((caught + 1))
        echo "caught  $1 ($2 errors)" >> $out
    fi
}

errs() {
    grep -o "errors=[0-9]*" | head -1 | cut -d= -f2
}

accel() {
    python3 scripts/gen_vectors.py --n 4 --k 4 --count 20 > /dev/null
    iverilog -o $D/x "$@" tb/mm_accel_tb.v && vvp -n $D/x | errs
}

stream() {
    python3 scripts/gen_vectors.py --n 4 --k 4 --count 20 > /dev/null
    iverilog -o $D/x "$@" tb/stream_tb.v && vvp -n $D/x | errs
}

tiled() {
    python3 scripts/gen_vectors.py --n 4 --m 8 --k 8 --p 12 --count 20 > /dev/null
    iverilog -P tiled_tb.M=8 -P tiled_tb.K=8 -P tiled_tb.P=12 -o $D/x "$@" tb/tiled_tb.v && vvp -n $D/x | errs
}

ws() {
    python3 scripts/gen_vectors.py --n 4 --m 6 --k 8 --p 8 --count 20 > /dev/null
    iverilog -DWS -P tiled_tb.M=6 -P tiled_tb.K=8 -P tiled_tb.P=8 -o $D/x rtl/skew.v rtl/pe_ws.v rtl/ws_array.v "$@" tb/tiled_tb.v && vvp -n $D/x | errs
}

echo "Mutation tests: each line is one deliberate bug and whether the testbench caught it" > $out

sed 's/2\*N + K - 3 + PIPE/2*N + K - 4 + PIPE/' rtl/controller.v > $D/ctl.v
check "controller finishes one cycle early" "$(accel $CORE $D/ctl.v rtl/mm_accel.v)"
sed 's/sr\[i\*W-1 -: W\]/din[i*W +: W]/' rtl/skew.v > $D/skew.v
check "skew removed" "$(accel rtl/pe.v rtl/systolic_array.v $D/skew.v rtl/controller.v rtl/mm_accel.v)"
sed 's/wire signed \[15:0\] p = a_in \* b_in;/wire signed [15:0] p = $unsigned(a_in) * $unsigned(b_in);/' rtl/pe.v > $D/pe_u.v
check "unsigned multiply" "$(accel $D/pe_u.v rtl/systolic_array.v rtl/skew.v rtl/controller.v rtl/mm_accel.v)"

sed 's/res <= acc + m;/res <= acc;/' rtl/pe.v > $D/pe1.v
check "PE drops the last product" "$(stream $D/pe1.v rtl/systolic_array.v rtl/skew.v rtl/mm_stream.v)"
sed 's/^                acc <= 0;$/                acc <= acc;/' rtl/pe.v > $D/pe2.v
check "PE keeps its sum after last" "$(stream $D/pe2.v rtl/systolic_array.v rtl/skew.v rtl/mm_stream.v)"
sed 's/\.last_left(l_skew)/.last_left({N{in_last}})/' rtl/mm_stream.v > $D/st1.v
check "last flag not skewed" "$(stream $CORE $D/st1.v)"
sed 's/\.last_out(lh\[i\*(N+1)+j+1\])/.last_out()/' rtl/systolic_array.v > $D/sa1.v
check "last flag not passed right" "$(stream rtl/pe.v $D/sa1.v rtl/skew.v rtl/mm_stream.v)"

sed 's/if (oj\[p\] == TP - 1) begin/if (oj[p] == TM - 1) begin/' rtl/mm_tiled.v > $D/t1.v
check "tiled: column wrap uses the row count" "$(tiled $CORE rtl/mm_stream.v $D/t1.v)"
sed 's/bmem\[k\*P + tj\*N + g\]/bmem[k*P + ti*N + g]/' rtl/mm_tiled.v > $D/t2.v
check "tiled: B feeder uses the tile row" "$(tiled $CORE rtl/mm_stream.v $D/t2.v)"
sed 's/if (run \&\& fin == T) begin/if (run \&\& fin == T - 1) begin/' rtl/mm_tiled.v > $D/t3.v
check "tiled: done one tile early" "$(tiled $CORE rtl/mm_stream.v $D/t3.v)"

sed 's/(tk\*N + N - 1 - t)\*P/(tk*N + t)*P/' rtl/mm_ws.v > $D/w1.v
check "ws: weights loaded in the wrong order" "$(ws $D/w1.v)"
sed 's/\.din(s_rev), \.dout(s_al)/.din(s_bot), .dout(s_al)/' rtl/mm_ws.v > $D/w2.v
check "ws: output deskew reversed" "$(ws $D/w2.v)"
sed 's/(tk == 0 ? 32.d0 : cmem\[r\*P + tj\*N + j\])/32'"'"'d0/' rtl/mm_ws.v > $D/w3.v
check "ws: no accumulation over K tiles" "$(ws $D/w3.v)"
sed 's/localparam LAST = M + 2\*N - 2;/localparam LAST = M + 2*N - 3;/' rtl/mm_ws.v > $D/w4.v
check "ws: drain one cycle short" "$(ws $D/w4.v)"
sed 's/(t >= 2\*N - 1)/(t >= 2*N - 2)/; s/wire \[TW-1:0\] r = t - (2\*N - 1);/wire [TW-1:0] r = t - (2*N - 2);/' rtl/mm_ws.v > $D/w5.v
check "ws: results captured one cycle early" "$(ws $D/w5.v)"

echo "caught $caught of $total" >> $out
cat $out
