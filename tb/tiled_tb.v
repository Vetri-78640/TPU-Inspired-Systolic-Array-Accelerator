`timescale 1ns/1ps
module tiled_tb;
    parameter N = 4;
    parameter M = 8;
    parameter K = 8;
    parameter P = 8;
    parameter MAXT = 128;
    localparam AW = $clog2(M*K > K*P ? M*K : K*P);
    localparam CW = (M*P > 1) ? $clog2(M*P) : 1;

    reg clk = 0;
    reg rst = 1;
    reg start = 0;
    reg wr_en = 0;
    reg wr_b = 0;
    reg [AW-1:0] wr_addr = 0;
    reg [7:0] wr_data = 0;
    reg [CW-1:0] rd_addr = 0;
    wire [31:0] rd_data;
    wire busy, done;

    reg [7:0] av [0:MAXT*M*K-1];
    reg [7:0] bv [0:MAXT*K*P-1];
    reg [31:0] cv [0:MAXT*M*P-1];
    reg [31:0] cnt [0:0];
    integer tc, x, f, errors = 0, cycles = 0, first = 0;

    mm_tiled #(.N(N), .M(M), .K(K), .P(P)
`ifdef PIPE
        , .PIPE(1)
`endif
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .wr_en(wr_en),
        .wr_b(wr_b),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .busy(busy),
        .done(done)
    );

    always #5 clk = ~clk;

    always @(negedge clk)
        if (done && |dut.v_flat) begin
            $display("FAIL result arrived after done");
            errors = errors + 1;
        end

    task write(input sel, input [AW-1:0] addr, input [7:0] data);
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
        $readmemh("data/count.hex", cnt);
        if (cnt[0] === 32'bx || cnt[0] == 0 || cnt[0] > MAXT) begin
            $display("FAIL missing or invalid test vectors, run scripts/gen_vectors.py first");
            $finish;
        end
        $readmemh("data/a.hex", av, 0, cnt[0]*M*K - 1);
        $readmemh("data/b.hex", bv, 0, cnt[0]*K*P - 1);
        $readmemh("data/c.hex", cv, 0, cnt[0]*M*P - 1);
        f = $fopen("sim/tiled_out.hex", "w");
        repeat (2) @(posedge clk);
        #1 rst = 0;

        for (tc = 0; tc < cnt[0]; tc = tc + 1) begin
            for (x = 0; x < M*K; x = x + 1)
                write(0, x, av[tc*M*K + x]);
            for (x = 0; x < K*P; x = x + 1)
                write(1, x, bv[tc*K*P + x]);

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

            for (x = 0; x < M*P; x = x + 1) begin
                rd_addr = x;
                @(posedge clk);
                #1;
                $fdisplay(f, "%h", rd_data);
                if (rd_data !== cv[tc*M*P + x]) begin
                    if (errors < 10)
                        $display("FAIL case %0d C[%0d][%0d]=%0d want %0d", tc, x / P, x % P,
                                 $signed(rd_data), $signed(cv[tc*M*P + x]));
                    errors = errors + 1;
                end
            end
        end
        $fclose(f);

        $display("RESULT %0s N=%0d M=%0d K=%0d P=%0d tiles=%0d cases=%0d errors=%0d cycles=%0d",
                 "tiled", N, M, K, P, (M/N)*(P/N), cnt[0], errors, first);
        if (errors == 0)
            $display("ALL %0d %0s TESTS PASSED", cnt[0], "tiled");
        $finish;
    end
endmodule
