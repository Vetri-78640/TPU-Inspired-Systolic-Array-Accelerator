`timescale 1ns/1ps
module array_tb;
    localparam N = 2;
    reg clk = 0;
    reg rst = 1;
    reg clr = 0;
    reg [N*8-1:0] a_left = 0, b_top = 0;
    wire [N*N*32-1:0] c_flat;
    reg signed [7:0] A [0:N-1][0:N-1];
    reg signed [7:0] B [0:N-1][0:N-1];
    reg signed [31:0] C [0:N-1][0:N-1];
    integer t, i, j, errors = 0;

    systolic_array #(.N(N)) dut (.clk(clk), .rst(rst), .clr(clr), .a_left(a_left), .b_top(b_top), .c_flat(c_flat));

    always #5 clk = ~clk;

    task run_case(input [8*16-1:0] name);
        begin
            clr = 1;
            @(posedge clk);
            #1 clr = 0;
            for (t = 0; t < 3*N - 2; t = t + 1) begin
                for (i = 0; i < N; i = i + 1) begin
                    a_left[i*8 +: 8] = (t - i >= 0 && t - i < N) ? A[i][t-i] : 8'd0;
                    b_top[i*8 +: 8] = (t - i >= 0 && t - i < N) ? B[t-i][i] : 8'd0;
                end
                @(posedge clk);
                #1;
            end
            a_left = 0;
            b_top = 0;
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1)
                    if ($signed(c_flat[(i*N+j)*32 +: 32]) !== C[i][j]) begin
                        $display("FAIL %0s C[%0d][%0d]=%0d want %0d", name, i, j, $signed(c_flat[(i*N+j)*32 +: 32]), C[i][j]);
                        errors = errors + 1;
                    end
            $display("checked %0s after %0d cycles", name, 3*N - 2);
        end
    endtask

    initial begin
        $dumpfile("sim/array_tb.vcd");
        $dumpvars(0, array_tb);
        @(posedge clk);
        #1 rst = 0;

        A[0][0] = 1; A[0][1] = 2; A[1][0] = 3; A[1][1] = 4;
        B[0][0] = 5; B[0][1] = 6; B[1][0] = 7; B[1][1] = 8;
        C[0][0] = 19; C[0][1] = 22; C[1][0] = 43; C[1][1] = 50;
        run_case("2x2 positive");

        A[0][0] = -128; A[0][1] = 127; A[1][0] = -1; A[1][1] = 0;
        B[0][0] = -128; B[0][1] = 3; B[1][0] = 127; B[1][1] = -128;
        C[0][0] = 32513; C[0][1] = -16640; C[1][0] = 128; C[1][1] = -3;
        run_case("2x2 signed");

        if (errors == 0)
            $display("ALL ARRAY TESTS PASSED");
        else
            $display("ARRAY TESTS FAILED: %0d", errors);
        $finish;
    end
endmodule
