`timescale 1ns/1ps
module systolic_array #(parameter N = 4) (
    input clk,
    input rst,
    input clr,
    input [N*8-1:0] a_left,
    input [N*8-1:0] b_top,
    output [N*N*32-1:0] c_flat
);
    wire [N*(N+1)*8-1:0] ah;
    wire [(N+1)*N*8-1:0] bv;

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : edge_in
            assign ah[(i*(N+1))*8 +: 8] = a_left[i*8 +: 8];
            assign bv[i*8 +: 8] = b_top[i*8 +: 8];
        end
        for (i = 0; i < N; i = i + 1) begin : row
            for (j = 0; j < N; j = j + 1) begin : col
                pe u_pe (
                    .clk(clk),
                    .rst(rst),
                    .clr(clr),
                    .a_in(ah[(i*(N+1)+j)*8 +: 8]),
                    .b_in(bv[(i*N+j)*8 +: 8]),
                    .a_out(ah[(i*(N+1)+j+1)*8 +: 8]),
                    .b_out(bv[((i+1)*N+j)*8 +: 8]),
                    .acc(c_flat[(i*N+j)*32 +: 32])
                );
            end
        end
    endgenerate
endmodule
