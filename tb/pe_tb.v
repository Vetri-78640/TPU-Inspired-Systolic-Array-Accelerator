`timescale 1ns/1ps
module pe_tb;
    reg clk = 0;
    reg rst = 1;
    reg clr = 0;
    reg last = 0;
    reg signed [7:0] a = 0, b = 0;
    wire signed [7:0] a_out, b_out, a_out1, b_out1;
    wire last_out, last_out1, valid, valid1;
    wire signed [31:0] acc, res, acc1, res1;
    integer errors = 0;

    pe #(.PIPE(0)) dut (.clk(clk), .rst(rst), .clr(clr), .last_in(last), .a_in(a), .b_in(b),
        .a_out(a_out), .b_out(b_out), .last_out(last_out), .acc(acc), .res(res), .valid(valid));
    pe #(.PIPE(1)) dp (.clk(clk), .rst(rst), .clr(clr), .last_in(last), .a_in(a), .b_in(b),
        .a_out(a_out1), .b_out(b_out1), .last_out(last_out1), .acc(acc1), .res(res1), .valid(valid1));

    always #5 clk = ~clk;

    task step(input signed [7:0] x, input signed [7:0] y, input l);
        begin
            a = x;
            b = y;
            last = l;
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

        step(3, 4, 0);
        step(-2, 5, 0);
        step(7, -1, 0);
        check(acc, -5, "mac sequence");
        check(a_out, 7, "pass-through a");
        check(b_out, -1, "pass-through b");
        step(0, 0, 0);
        check(acc1, -5, "pipelined mac, 1 cycle later");

        clr = 1;
        step(0, 0, 0);
        clr = 0;
        check(acc, 0, "clear");
        check(acc1, 0, "pipelined clear");

        step(-128, -128, 0);
        check(acc, 16384, "largest product");
        step(127, -128, 0);
        check(acc, 128, "mixed signs");
        check(acc1, 16384, "pipelined largest product");

        clr = 1;
        step(0, 0, 0);
        clr = 0;
        step(1, 5, 0);
        step(2, 7, 1);
        check(res, 19, "last: result 1");
        check(valid, 1, "last: valid pulse");
        check(acc, 0, "last: acc restarts");
        check(last_out, 1, "last: flag passed on");
        step(3, 6, 0);
        check(valid, 0, "last: valid one cycle");
        check(acc, 18, "last: next matrix starts");
        check(res1, 19, "pipelined last: result 1");
        check(valid1, 1, "pipelined last: valid pulse");
        step(4, 8, 1);
        check(res, 50, "last: result 2");
        check(res1, 19, "pipelined last: result held");
        step(0, 0, 0);
        check(res1, 50, "pipelined last: result 2");
        check(res, 50, "last: result held");

        if (errors == 0)
            $display("ALL PE TESTS PASSED");
        else
            $display("PE TESTS FAILED: %0d", errors);
        $finish;
    end
endmodule
