`timescale 1ns/1ps
module pe_tb;
    reg clk = 0;
    reg rst = 1;
    reg clr = 0;
    reg signed [7:0] a = 0, b = 0;
    wire signed [7:0] a_out, b_out;
    wire signed [31:0] acc;
    integer errors = 0;

    pe dut (.clk(clk), .rst(rst), .clr(clr), .a_in(a), .b_in(b), .a_out(a_out), .b_out(b_out), .acc(acc));

    always #5 clk = ~clk;

    task step(input signed [7:0] x, input signed [7:0] y);
        begin
            a = x;
            b = y;
            @(posedge clk);
            #1;
        end
    endtask

    task check(input signed [31:0] want, input [8*24-1:0] name);
        begin
            if (acc !== want) begin
                $display("FAIL %0s: acc=%0d want=%0d", name, acc, want);
                errors = errors + 1;
            end else
                $display("PASS %0s: acc=%0d", name, acc);
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
        check(-5, "mac sequence");
        if (a_out !== 7 || b_out !== -1) begin
            $display("FAIL pass-through: a_out=%0d b_out=%0d", a_out, b_out);
            errors = errors + 1;
        end else
            $display("PASS pass-through: a_out=%0d b_out=%0d", a_out, b_out);

        clr = 1;
        step(0, 0);
        clr = 0;
        check(0, "clear");

        step(-128, -128);
        check(16384, "largest product");
        step(127, -128);
        check(16384 - 16256, "mixed signs");

        if (errors == 0)
            $display("ALL PE TESTS PASSED");
        else
            $display("PE TESTS FAILED: %0d", errors);
        $finish;
    end
endmodule
