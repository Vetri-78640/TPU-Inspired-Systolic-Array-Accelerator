`timescale 1ns/1ps
module pe_tb;
    reg clk = 0;
    reg rst = 1;
    reg clr = 0;
    reg signed [7:0] a = 0, b = 0;
    wire signed [7:0] a_out, b_out, a_out1, b_out1;
    wire signed [31:0] acc, acc1;
    integer errors = 0;

    pe #(.PIPE(0)) dut (.clk(clk), .rst(rst), .clr(clr), .a_in(a), .b_in(b), .a_out(a_out), .b_out(b_out), .acc(acc));
    pe #(.PIPE(1)) dp (.clk(clk), .rst(rst), .clr(clr), .a_in(a), .b_in(b), .a_out(a_out1), .b_out(b_out1), .acc(acc1));

    always #5 clk = ~clk;

    task step(input signed [7:0] x, input signed [7:0] y);
        begin
            a = x;
            b = y;
            @(posedge clk);
            #1;
        end
    endtask

    task check(input signed [31:0] got, input signed [31:0] want, input [8*28-1:0] name);
        begin
            if (got !== want) begin
                $display("FAIL %0s: got=%0d want=%0d", name, got, want);
                errors = errors + 1;
            end else
                $display("PASS %0s: %0d", name, got);
        end
    endtask

    initial begin
        $dumpfile("sim/pe_tb.vcd");
        $dumpvars(0, pe_tb);
        @(posedge clk);
        #1 rst = 0;

        step(3, 4);
        step(-2, 5);
        step(7, -1);
        check(acc, -5, "mac sequence");
        check(a_out, 7, "pass-through a");
        check(b_out, -1, "pass-through b");
        step(0, 0);
        check(acc1, -5, "pipelined mac, 1 cycle later");

        clr = 1;
        step(0, 0);
        clr = 0;
        check(acc, 0, "clear");
        check(acc1, 0, "pipelined clear");

        step(-128, -128);
        check(acc, 16384, "largest product");
        step(127, -128);
        check(acc, 128, "mixed signs");
        check(acc1, 16384, "pipelined largest product");

        if (errors == 0)
            $display("ALL PE TESTS PASSED");
        else
            $display("PE TESTS FAILED: %0d", errors);
        $finish;
    end
endmodule
