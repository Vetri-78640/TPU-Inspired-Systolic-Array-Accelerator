`timescale 1ns/1ps
module seq_mac #(parameter N = 4, parameter K = 4) (
    input clk,
    input rst,
    input start,
    input wr_en,
    input wr_b,
    input [7:0] wr_addr,
    input [7:0] wr_data,
    output busy,
    output reg done,
    output reg [N*N*32-1:0] c_flat
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

    reg run;
    reg [7:0] i, j, k;
    reg signed [31:0] acc;

    wire signed [7:0] a = amem[i*K + k];
    wire signed [7:0] b = bmem[k*N + j];
    wire signed [31:0] sum = acc + a * b;

    assign busy = run;

    always @(posedge clk) begin
        if (rst) begin
            run <= 0;
            done <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            acc <= 0;
        end else if (start) begin
            run <= 1;
            done <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            acc <= 0;
        end else if (run) begin
            if (k == K - 1) begin
                c_flat[(i*N + j)*32 +: 32] <= sum;
                acc <= 0;
                k <= 0;
                if (j == N - 1) begin
                    j <= 0;
                    if (i == N - 1) begin
                        run <= 0;
                        done <= 1;
                    end else
                        i <= i + 1;
                end else
                    j <= j + 1;
            end else begin
                acc <= sum;
                k <= k + 1;
            end
        end
    end
endmodule
