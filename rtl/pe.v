`timescale 1ns/1ps
module pe #(parameter PIPE = 0) (
    input clk,
    input rst,
    input clr,
    input signed [7:0] a_in,
    input signed [7:0] b_in,
    output reg signed [7:0] a_out,
    output reg signed [7:0] b_out,
    output reg signed [31:0] acc
);
    wire signed [15:0] p = a_in * b_in;
    wire signed [15:0] m;

    generate
        if (PIPE) begin : pipe
            reg signed [15:0] prod;
            always @(posedge clk) begin
                if (rst || clr)
                    prod <= 0;
                else
                    prod <= p;
            end
            assign m = prod;
        end else begin : comb
            assign m = p;
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            a_out <= 0;
            b_out <= 0;
            acc <= 0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            if (clr)
                acc <= 0;
            else
                acc <= acc + m;
        end
    end
endmodule
