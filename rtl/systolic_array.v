`timescale 1ns/1ps
module systolic_array #(parameter N = 4, parameter PIPE = 0) (
    input clk,
    input rst,
    input clr,
    input [N-1:0] last_left,
    input [N*8-1:0] a_left,
    input [N*8-1:0] b_top,
    output [N*N*32-1:0] c_flat,
    output [N*N*32-1:0] r_flat,
    output [N*N-1:0] v_flat
);
    wire [N*(N+1)*8-1:0] ah;
    wire [N*(N+1)-1:0] lh;
    wire [(N+1)*N*8-1:0] bv;

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : edge_in
            assign ah[(i*(N+1))*8 +: 8] = a_left[i*8 +: 8];
            assign lh[i*(N+1)] = last_left[i];
            assign bv[i*8 +: 8] = b_top[i*8 +: 8];
        end
        for (i = 0; i < N; i = i + 1) begin : row
            for (j = 0; j < N; j = j + 1) begin : col
                pe #(.PIPE(PIPE)) u_pe (
                    .clk(clk),
                    .rst(rst),
                    .clr(clr),
                    .last_in(lh[i*(N+1)+j]),
                    .a_in(ah[(i*(N+1)+j)*8 +: 8]),
                    .b_in(bv[(i*N+j)*8 +: 8]),
                    .a_out(ah[(i*(N+1)+j+1)*8 +: 8]),
                    .b_out(bv[((i+1)*N+j)*8 +: 8]),
                    .last_out(lh[i*(N+1)+j+1]),
                    .acc(c_flat[(i*N+j)*32 +: 32]),
                    .res(r_flat[(i*N+j)*32 +: 32]),
                    .valid(v_flat[i*N+j])
                );
            end
        end
    endgenerate
endmodule
