`timescale 1ns/1ps
module net_wrap #(parameter N = 4, parameter K = 4) (
    input clk,
    input rst,
    input start,
    input wr_en,
    input wr_b,
    input [3:0] wr_addr,
    input [7:0] wr_data,
    output busy,
    output done,
    output [N*N*32-1:0] c_flat
);
    mm_net u_net (
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
endmodule
