`timescale 1ns/1ps
module skew #(parameter N = 4, parameter W = 8) (
    input clk,
    input rst,
    input [N*W-1:0] din,
    output [N*W-1:0] dout
);
    assign dout[W-1:0] = din[W-1:0];

    genvar i;
    generate
        for (i = 1; i < N; i = i + 1) begin : lane
            reg [i*W-1:0] sr;
            always @(posedge clk) begin
                if (rst)
                    sr <= 0;
                else
                    sr <= (sr << W) | din[i*W +: W];
            end
            assign dout[i*W +: W] = sr[i*W-1 -: W];
        end
    endgenerate
endmodule
