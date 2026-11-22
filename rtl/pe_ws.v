`timescale 1ns/1ps
module pe_ws (
    input clk,
    input rst,
    input load,
    input signed [7:0] w_in,
    input signed [7:0] a_in,
    input signed [31:0] s_in,
    output reg signed [7:0] w,
    output reg signed [7:0] a_out,
    output reg signed [31:0] s_out
);
    always @(posedge clk) begin
        if (rst) begin
            w <= 0;
            a_out <= 0;
            s_out <= 0;
        end else begin
            if (load)
                w <= w_in;
            a_out <= a_in;
            s_out <= s_in + a_in * w;
        end
    end
endmodule
