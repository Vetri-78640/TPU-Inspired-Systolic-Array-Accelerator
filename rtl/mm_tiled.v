`timescale 1ns/1ps
module mm_tiled #(
    parameter N = 4,
    parameter M = 8,
    parameter K = 8,
    parameter P = 8,
    parameter PIPE = 0,
    parameter AW = $clog2(M*K > K*P ? M*K : K*P),
    parameter CW = (M*P > 1) ? $clog2(M*P) : 1
) (
    input clk,
    input rst,
    input start,
    input wr_en,
    input wr_b,
    input [AW-1:0] wr_addr,
    input [7:0] wr_data,
    input [CW-1:0] rd_addr,
    output reg [31:0] rd_data,
    output busy,
    output reg done
);
    localparam TM = M / N, TP = P / N, T = TM * TP;
    localparam IW = $clog2(T + 1), KW = $clog2(K + 1);

    reg [7:0] amem [0:M*K-1];
    reg [7:0] bmem [0:K*P-1];
    reg [31:0] cmem [0:M*P-1];

    always @(posedge clk) begin
        if (wr_en) begin
            if (wr_b)
                bmem[wr_addr] <= wr_data;
            else
                amem[wr_addr] <= wr_data;
        end
        rd_data <= cmem[rd_addr];
    end

    reg run, feed;
    reg [IW-1:0] ti, tj, fin;
    reg [KW-1:0] k;

    always @(posedge clk) begin
        if (rst) begin
            run <= 0;
            feed <= 0;
            done <= 0;
            ti <= 0;
            tj <= 0;
            k <= 0;
        end else if (start && !run) begin
            run <= 1;
            feed <= 1;
            done <= 0;
            ti <= 0;
            tj <= 0;
            k <= 0;
        end else begin
            if (feed) begin
                if (k == K - 1) begin
                    k <= 0;
                    if (tj == TP - 1) begin
                        tj <= 0;
                        if (ti == TM - 1)
                            feed <= 0;
                        else
                            ti <= ti + 1;
                    end else
                        tj <= tj + 1;
                end else
                    k <= k + 1;
            end
            if (run && fin == T) begin
                run <= 0;
                done <= 1;
            end
        end
    end

    assign busy = run;

    wire [N*8-1:0] a_col, b_row;
    wire [N*N*32-1:0] r_flat;
    wire [N*N-1:0] v_flat;

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : feeder
            assign a_col[g*8 +: 8] = feed ? amem[(ti*N + g)*K + k] : 8'd0;
            assign b_row[g*8 +: 8] = feed ? bmem[k*P + tj*N + g] : 8'd0;
        end
    endgenerate

    mm_stream #(.N(N), .PIPE(PIPE)) u_stream (
        .clk(clk),
        .rst(rst),
        .in_last(feed && k == K - 1),
        .a_col(a_col),
        .b_row(b_row),
        .r_flat(r_flat),
        .v_flat(v_flat)
    );

    reg [IW-1:0] oi [0:N*N-1];
    reg [IW-1:0] oj [0:N*N-1];
    integer p;

    always @(posedge clk) begin
        if (rst || (start && !run)) begin
            fin <= 0;
            for (p = 0; p < N*N; p = p + 1) begin
                oi[p] <= 0;
                oj[p] <= 0;
            end
        end else begin
            for (p = 0; p < N*N; p = p + 1) begin
                if (v_flat[p]) begin
                    cmem[(oi[p]*N + p/N)*P + oj[p]*N + p%N] <= r_flat[p*32 +: 32];
                    if (oj[p] == TP - 1) begin
                        oj[p] <= 0;
                        oi[p] <= oi[p] + 1;
                    end else
                        oj[p] <= oj[p] + 1;
                end
            end
            if (v_flat[N*N-1])
                fin <= fin + 1;
        end
    end
endmodule
