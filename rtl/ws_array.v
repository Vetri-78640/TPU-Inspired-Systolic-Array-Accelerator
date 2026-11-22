`timescale 1ns/1ps
module ws_array #(parameter N = 4) (
    input clk,
    input rst,
    input load,
    input [N*8-1:0] w_top,
    input [N*8-1:0] a_left,
    output [N*32-1:0] s_bot
);
    wire [N*(N+1)*8-1:0] ah;
    wire [(N+1)*N*8-1:0] wv;
    wire [(N+1)*N*32-1:0] sv;

    genvar k, j;
    generate
        for (k = 0; k < N; k = k + 1) begin : edge_in
            assign ah[(k*(N+1))*8 +: 8] = a_left[k*8 +: 8];
            assign wv[k*8 +: 8] = w_top[k*8 +: 8];
            assign sv[k*32 +: 32] = 0;
            assign s_bot[k*32 +: 32] = sv[(N*N + k)*32 +: 32];
        end
        for (k = 0; k < N; k = k + 1) begin : row
            for (j = 0; j < N; j = j + 1) begin : col
                pe_ws u_pe (
                    .clk(clk),
                    .rst(rst),
                    .load(load),
                    .w_in(wv[(k*N+j)*8 +: 8]),
                    .a_in(ah[(k*(N+1)+j)*8 +: 8]),
                    .s_in(sv[(k*N+j)*32 +: 32]),
                    .w(wv[((k+1)*N+j)*8 +: 8]),
                    .a_out(ah[(k*(N+1)+j+1)*8 +: 8]),
                    .s_out(sv[((k+1)*N+j)*32 +: 32])
                );
            end
        end
    endgenerate
endmodule
