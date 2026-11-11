`timescale 1ns/1ps
`ifndef DUT
`define DUT mm_accel
`endif
module mm_accel_tb;
    parameter N = 4;
    parameter K = 4;
    parameter MAXT = 256;

    reg clk = 0;
    reg rst = 1;
    reg start = 0;
    reg wr_en = 0;
    reg wr_b = 0;
    reg [7:0] wr_addr = 0;
    reg [7:0] wr_data = 0;
    wire busy, done;
    wire [N*N*32-1:0] c_flat;

    reg [7:0] av [0:MAXT*N*K-1];
    reg [7:0] bv [0:MAXT*K*N-1];
    reg [31:0] cv [0:MAXT*N*N-1];
    reg [31:0] cnt [0:0];
    integer tc, x, errors = 0, cycles = 0, first = 0;

    `DUT #(.N(N), .K(K)) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .wr_en(wr_en),
        .wr_b(wr_b),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .busy(busy),
        .done(done),
        .c_flat(c_flat)
    );

    always #5 clk = ~clk;

    task write(input sel, input [7:0] addr, input [7:0] data);
        begin
            wr_en = 1;
            wr_b = sel;
            wr_addr = addr;
            wr_data = data;
            @(posedge clk);
            #1 wr_en = 0;
        end
    endtask

    initial begin
        $readmemh("data/a.hex", av);
        $readmemh("data/b.hex", bv);
        $readmemh("data/c.hex", cv);
        $readmemh("data/count.hex", cnt);
        if (cnt[0] === 32'bx || cnt[0] == 0 || cnt[0] > MAXT) begin
            $display("FAIL missing or invalid test vectors, run scripts/gen_vectors.py first");
            $finish;
        end
        if ($test$plusargs("wave")) begin
            $dumpfile("sim/mm_accel_tb.vcd");
            $dumpvars(0, mm_accel_tb);
        end
        repeat (2) @(posedge clk);
        #1 rst = 0;

        for (tc = 0; tc < cnt[0]; tc = tc + 1) begin
            for (x = 0; x < N*K; x = x + 1)
                write(0, x, av[tc*N*K + x]);
            for (x = 0; x < K*N; x = x + 1)
                write(1, x, bv[tc*K*N + x]);

            start = 1;
            @(posedge clk);
            #1 start = 0;
            cycles = 1;
            while (!done) begin
                @(posedge clk);
                #1 cycles = cycles + 1;
            end
            if (tc == 0)
                first = cycles;

            for (x = 0; x < N*N; x = x + 1) begin
                if (c_flat[x*32 +: 32] !== cv[tc*N*N + x]) begin
                    if (errors < 10)
                        $display("FAIL case %0d C[%0d][%0d]=%0d want %0d", tc, x / N, x % N,
                                 $signed(c_flat[x*32 +: 32]), $signed(cv[tc*N*N + x]));
                    errors = errors + 1;
                end
            end
        end

        $display("RESULT N=%0d K=%0d cases=%0d errors=%0d cycles=%0d", N, K, cnt[0], errors, first);
        if (errors == 0)
            $display("ALL %0d MATRIX TESTS PASSED", cnt[0]);
        $finish;
    end
endmodule
