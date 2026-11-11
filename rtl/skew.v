`timescale 1ns/1ps
module skew #(parameter N = 4) (
    input clk,
    input rst,
    input [N*8-1:0] din,
    output [N*8-1:0] dout
);
    assign dout[7:0] = din[7:0];

    genvar i;
    generate
        for (i = 1; i < N; i = i + 1) begin : lane
            reg [i*8-1:0] sr;
            always @(posedge clk) begin
                if (rst)
                    sr <= 0;
                else
                    sr <= (sr << 8) | din[i*8 +: 8];
            end
            assign dout[i*8 +: 8] = sr[i*8-1 -: 8];
        end
    endgenerate
endmodule
