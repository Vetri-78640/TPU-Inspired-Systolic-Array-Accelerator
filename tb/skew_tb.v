`timescale 1ns/1ps
module skew_tb;
    localparam N = 4;
    reg clk = 0;
    reg rst = 1;
    reg [N*8-1:0] din = 0;
    wire [N*8-1:0] dout;
    reg [7:0] hist [0:31];
    integer t, i, errors = 0;

    skew #(.N(N)) dut (.clk(clk), .rst(rst), .din(din), .dout(dout));

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/skew_tb.vcd");
        $dumpvars(0, skew_tb);
        @(posedge clk);
        #1 rst = 0;
        for (t = 0; t < 12; t = t + 1) begin
            hist[t] = t + 1;
            for (i = 0; i < N; i = i + 1)
                din[i*8 +: 8] = hist[t] + 16*i;
            #1;
            for (i = 0; i < N; i = i + 1) begin
                if (t >= i && dout[i*8 +: 8] !== hist[t-i] + 16*i) begin
                    $display("FAIL lane %0d cycle %0d: got %0d want %0d", i, t, dout[i*8 +: 8], hist[t-i] + 16*i);
                    errors = errors + 1;
                end
            end
            @(posedge clk);
            #1;
        end
        if (errors == 0)
            $display("ALL SKEW TESTS PASSED: lane i delayed by i cycles");
        else
            $display("SKEW TESTS FAILED: %0d", errors);
        $finish;
    end
endmodule
