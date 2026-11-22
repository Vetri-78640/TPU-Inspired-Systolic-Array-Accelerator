`timescale 1ns/1ps
module mm_stream #(parameter N = 4, parameter PIPE = 0) (
    input clk,
    input rst,
    input in_last,
    input [N*8-1:0] a_col,
    input [N*8-1:0] b_row,
    output [N*N*32-1:0] r_flat,
    output [N*N-1:0] v_flat
);
    wire [N*8-1:0] a_skew, b_skew;
    wire [N-1:0] l_skew;

    skew #(.N(N)) u_skew_a (.clk(clk), .rst(rst), .din(a_col), .dout(a_skew));
    skew #(.N(N)) u_skew_b (.clk(clk), .rst(rst), .din(b_row), .dout(b_skew));
    skew #(.N(N), .W(1)) u_skew_l (.clk(clk), .rst(rst), .din({N{in_last}}), .dout(l_skew));

    systolic_array #(.N(N), .PIPE(PIPE)) u_array (
        .clk(clk),
        .rst(rst),
        .clr(1'b0),
        .last_left(l_skew),
        .a_left(a_skew),
        .b_top(b_skew),
        .c_flat(),
        .r_flat(r_flat),
        .v_flat(v_flat)
    );
endmodule
