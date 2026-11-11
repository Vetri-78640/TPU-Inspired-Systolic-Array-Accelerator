`timescale 1ns/1ps
module fpga_top #(parameter N = 4, parameter K = 4) (
    input clk,
    input rst,
    input start,
    input wr_en,
    input wr_b,
    input [7:0] wr_addr,
    input [7:0] wr_data,
    input [7:0] sel,
    output busy,
    output done,
    output reg [31:0] c_out
);
    wire [N*N*32-1:0] c_flat;

    mm_accel #(.N(N), .K(K)) u_accel (
        .clk(clk),
        .rst(rst),
        .start(start),
        .wr_en(wr_en),
        .wr_b(wr_b),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .busy(busy),
        .done(done),
        .c_flat(c_flat)
    );

    always @(posedge clk)
        c_out <= c_flat[sel*32 +: 32];
endmodule
