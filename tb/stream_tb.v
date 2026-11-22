`timescale 1ns/1ps
module stream_tb;
    parameter N = 4;
    parameter K = 4;
    parameter GAP = 0;
    parameter MAXT = 256;

    reg clk = 0;
    reg rst = 1;
    reg in_last = 0;
    reg [N*8-1:0] a_col = 0, b_row = 0;
    wire [N*N*32-1:0] r_flat;
    wire [N*N-1:0] v_flat;

    reg [7:0] av [0:MAXT*N*K-1];
    reg [7:0] bv [0:MAXT*K*N-1];
    reg [31:0] cv [0:MAXT*N*N-1];
    reg [31:0] cnt [0:0];
    integer got [0:N*N-1];
    integer tc, k, i, p, errors = 0, cyc = 0, t0 = 0, tend = 0, missing = 0;

    mm_stream #(.N(N)
`ifdef PIPE
        , .PIPE(1)
`endif
    ) dut (
        .clk(clk),
        .rst(rst),
        .in_last(in_last),
        .a_col(a_col),
        .b_row(b_row),
        .r_flat(r_flat),
        .v_flat(v_flat)
    );

    always #5 clk = ~clk;

    always @(posedge clk)
        cyc <= cyc + 1;

    always @(negedge clk) begin
        if (!rst) begin
            for (p = 0; p < N*N; p = p + 1) begin
                if (v_flat[p]) begin
                    if (got[p] >= cnt[0] || r_flat[p*32 +: 32] !== cv[got[p]*N*N + p]) begin
                        if (errors < 10)
                            $display("FAIL case %0d C[%0d][%0d]=%0d want %0d", got[p], p / N, p % N,
                                     $signed(r_flat[p*32 +: 32]), $signed(cv[got[p]*N*N + p]));
                        errors = errors + 1;
                    end
                    got[p] = got[p] + 1;
                    tend = cyc;
                end
            end
        end
    end

    initial begin
        $readmemh("data/count.hex", cnt);
        if (cnt[0] === 32'bx || cnt[0] == 0 || cnt[0] > MAXT) begin
            $display("FAIL missing or invalid test vectors, run scripts/gen_vectors.py first");
            $finish;
        end
        $readmemh("data/a.hex", av, 0, cnt[0]*N*K - 1);
        $readmemh("data/b.hex", bv, 0, cnt[0]*K*N - 1);
        $readmemh("data/c.hex", cv, 0, cnt[0]*N*N - 1);
        for (p = 0; p < N*N; p = p + 1)
            got[p] = 0;
        if ($test$plusargs("wave")) begin
            $dumpfile("sim/stream_tb.vcd");
            $dumpvars(0, stream_tb);
        end
        repeat (2) @(posedge clk);
        #1 rst = 0;
        t0 = cyc;

        for (tc = 0; tc < cnt[0]; tc = tc + 1) begin
            for (k = 0; k < K; k = k + 1) begin
                for (i = 0; i < N; i = i + 1) begin
                    a_col[i*8 +: 8] = av[tc*N*K + i*K + k];
                    b_row[i*8 +: 8] = bv[tc*K*N + k*N + i];
                end
                in_last = (k == K - 1);
                @(posedge clk);
                #1;
            end
            if (GAP > 0 && tc % 10 == 9) begin
                a_col = 0;
                b_row = 0;
                in_last = 0;
                repeat (GAP) @(posedge clk);
                #1;
            end
        end
        a_col = 0;
        b_row = 0;
        in_last = 0;
        repeat (2*N + 4) @(posedge clk);

        for (p = 0; p < N*N; p = p + 1)
            if (got[p] != cnt[0])
                missing = missing + 1;
        if (missing > 0) begin
            $display("FAIL %0d PEs produced the wrong number of results", missing);
            errors = errors + missing;
        end

        $display("RESULT stream N=%0d K=%0d cases=%0d errors=%0d cycles=%0d per_matrix=%0.2f",
                 N, K, cnt[0], errors, tend - t0, (tend - t0) * 1.0 / cnt[0]);
        if (errors == 0)
            $display("ALL %0d STREAM TESTS PASSED", cnt[0]);
        $finish;
    end
endmodule
