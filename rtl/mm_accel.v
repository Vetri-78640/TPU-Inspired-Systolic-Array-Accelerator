`timescale 1ns/1ps
module mm_accel #(parameter N = 4, parameter K = 4) (
    input clk,
    input rst,
    input start,
    input wr_en,
    input wr_b,
    input [7:0] wr_addr,
    input [7:0] wr_data,
    output busy,
    output done,
    output [N*N*32-1:0] c_flat
);
    reg [7:0] amem [0:N*K-1];
    reg [7:0] bmem [0:K*N-1];

    always @(posedge clk) begin
        if (wr_en) begin
            if (wr_b)
                bmem[wr_addr] <= wr_data;
            else
                amem[wr_addr] <= wr_data;
        end
    end

    wire clr, run;
    wire [7:0] t;

    controller #(.N(N), .K(K)) u_ctrl (
        .clk(clk),
        .rst(rst),
        .start(start),
        .clr(clr),
        .run(run),
        .busy(busy),
        .done(done),
        .t(t)
    );

    wire feed = run && (t < K);
    wire [N*8-1:0] a_col, b_row, a_skew, b_skew;

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : feeder
            assign a_col[i*8 +: 8] = feed ? amem[i*K + t] : 8'd0;
            assign b_row[i*8 +: 8] = feed ? bmem[t*N + i] : 8'd0;
        end
    endgenerate

    skew #(.N(N)) u_skew_a (.clk(clk), .rst(rst), .din(a_col), .dout(a_skew));
    skew #(.N(N)) u_skew_b (.clk(clk), .rst(rst), .din(b_row), .dout(b_skew));

    systolic_array #(.N(N)) u_array (
        .clk(clk),
        .rst(rst),
        .clr(clr),
        .a_left(a_skew),
        .b_top(b_skew),
        .c_flat(c_flat)
    );
endmodule
