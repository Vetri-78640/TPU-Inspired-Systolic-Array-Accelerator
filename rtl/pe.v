`timescale 1ns/1ps
module pe (
    input clk,
    input rst,
    input signed [7:0] a_in,
    input signed [7:0] b_in,
    output reg signed [7:0] a_out,
    output reg signed [7:0] b_out,
    output reg signed [31:0] acc
);
    always @(posedge clk) begin
        if (rst) begin
            a_out <= 0;
            b_out <= 0;
            acc <= 0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            acc <= acc + a_in * b_in;
        end
    end
endmodule
