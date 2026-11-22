`timescale 1ns/1ps
module pe #(parameter PIPE = 0) (
    input clk,
    input rst,
    input clr,
    input last_in,
    input signed [7:0] a_in,
    input signed [7:0] b_in,
    output reg signed [7:0] a_out,
    output reg signed [7:0] b_out,
    output reg last_out,
    output reg signed [31:0] acc,
    output reg signed [31:0] res,
    output reg valid
);
    wire signed [15:0] p = a_in * b_in;
    wire signed [15:0] m;
    wire l;

    generate
        if (PIPE) begin : pipe
            reg signed [15:0] prod;
            reg lp;
            always @(posedge clk) begin
                if (rst || clr) begin
                    prod <= 0;
                    lp <= 0;
                end else begin
                    prod <= p;
                    lp <= last_in;
                end
            end
            assign m = prod;
            assign l = lp;
        end else begin : comb
            assign m = p;
            assign l = last_in;
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            a_out <= 0;
            b_out <= 0;
            last_out <= 0;
            acc <= 0;
            res <= 0;
            valid <= 0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            last_out <= last_in;
            valid <= l && !clr;
            if (clr)
                acc <= 0;
            else if (l) begin
                res <= acc + m;
                acc <= 0;
            end else
                acc <= acc + m;
        end
    end
endmodule
