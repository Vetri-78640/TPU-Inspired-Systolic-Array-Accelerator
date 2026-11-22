`timescale 1ns/1ps
module mm_ws #(
    parameter N = 4,
    parameter M = 8,
    parameter K = 8,
    parameter P = 8,
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
    localparam TK = K / N, TP = P / N;
    localparam LAST = M + 2*N - 2;
    localparam IDLE = 2'd0, LOAD = 2'd1, STREAM = 2'd2;
    localparam TW = $clog2(LAST + 1), IW = $clog2((TK > TP ? TK : TP) + 1);

    reg [7:0] amem [0:M*K-1];
    reg [7:0] bmem [0:K*P-1];
    reg [31:0] cmem [0:M*P-1];

    reg [1:0] s;
    reg [TW-1:0] t;
    reg [IW-1:0] tk, tj;

    always @(posedge clk) begin
        if (wr_en) begin
            if (wr_b)
                bmem[wr_addr] <= wr_data;
            else
                amem[wr_addr] <= wr_data;
        end
        rd_data <= cmem[rd_addr];
    end

    always @(posedge clk) begin
        if (rst) begin
            s <= IDLE;
            done <= 0;
            t <= 0;
            tk <= 0;
            tj <= 0;
        end else begin
            case (s)
                IDLE: if (start) begin
                    s <= LOAD;
                    done <= 0;
                    t <= 0;
                    tk <= 0;
                    tj <= 0;
                end
                LOAD: if (t == N - 1) begin
                    s <= STREAM;
                    t <= 0;
                end else
                    t <= t + 1;
                STREAM: if (t == LAST) begin
                    t <= 0;
                    if (tk == TK - 1) begin
                        tk <= 0;
                        if (tj == TP - 1) begin
                            s <= IDLE;
                            done <= 1;
                        end else begin
                            tj <= tj + 1;
                            s <= LOAD;
                        end
                    end else begin
                        tk <= tk + 1;
                        s <= LOAD;
                    end
                end else
                    t <= t + 1;
            endcase
        end
    end

    assign busy = (s != IDLE);

    wire load = (s == LOAD);
    wire feed = (s == STREAM) && (t < M);
    wire [N*8-1:0] w_top, a_col, a_skew;
    wire [N*32-1:0] s_bot, s_rev;

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : lanes
            assign w_top[g*8 +: 8] = load ? bmem[(tk*N + N - 1 - t)*P + tj*N + g] : 8'd0;
            assign a_col[g*8 +: 8] = feed ? amem[t*K + tk*N + g] : 8'd0;
            assign s_rev[(N-1-g)*32 +: 32] = s_bot[g*32 +: 32];
        end
    endgenerate

    skew #(.N(N)) u_skew_a (.clk(clk), .rst(rst), .din(a_col), .dout(a_skew));

    ws_array #(.N(N)) u_array (
        .clk(clk),
        .rst(rst),
        .load(load),
        .w_top(w_top),
        .a_left(a_skew),
        .s_bot(s_bot)
    );

    wire [N*32-1:0] s_al;
    skew #(.N(N), .W(32)) u_deskew (.clk(clk), .rst(rst), .din(s_rev), .dout(s_al));

    wire cap = (s == STREAM) && (t >= 2*N - 1);
    wire [TW-1:0] r = t - (2*N - 1);
    wire [N-1:0] v_flat = {N{cap}};
    integer j;

    always @(posedge clk) begin
        if (cap) begin
            for (j = 0; j < N; j = j + 1)
                cmem[r*P + tj*N + j] <= (tk == 0 ? 32'd0 : cmem[r*P + tj*N + j]) + s_al[(N-1-j)*32 +: 32];
        end
    end
endmodule
