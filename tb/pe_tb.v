`timescale 1ns/1ps
module pe_tb;
    reg clk = 0;
    reg rst = 1;
    reg signed [7:0] a = 0, b = 0;
    wire signed [7:0] a_out, b_out;
    wire signed [31:0] acc;

    pe dut (.clk(clk), .rst(rst), .a_in(a), .b_in(b), .a_out(a_out), .b_out(b_out), .acc(acc));

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/pe_tb.vcd");
        $dumpvars(0, pe_tb);
        @(posedge clk); #1 rst = 0;
        a = 3;  b = 4;  @(posedge clk); #1;
        a = -2; b = 5;  @(posedge clk); #1;
        a = 7;  b = -1; @(posedge clk); #1;
        if (acc == -5 && a_out == 7 && b_out == -1) $display("PASS acc=%0d", acc);
        else $display("FAIL acc=%0d a_out=%0d b_out=%0d", acc, a_out, b_out);
        $finish;
    end
endmodule
