`timescale 1ns/1ps
module controller_tb;
    localparam N = 4;
    localparam K = 4;
    localparam RUNLEN = 2*N + K - 2;

    reg clk = 0;
    reg rst = 1;
    reg start = 0;
    wire clr, run, busy, done;
    wire [7:0] t;
    integer c, errors = 0;

    controller #(.N(N), .K(K)) dut (.clk(clk), .rst(rst), .start(start), .clr(clr), .run(run), .busy(busy), .done(done), .t(t));

    always #5 clk = ~clk;

    task expect(input e_clr, input e_run, input e_busy, input e_done, input [8*20-1:0] name);
        begin
            if (clr !== e_clr || run !== e_run || busy !== e_busy || done !== e_done) begin
                $display("FAIL %0s: clr=%b run=%b busy=%b done=%b", name, clr, run, busy, done);
                errors = errors + 1;
            end
        end
    endtask

    task one_run(input [8*20-1:0] name);
        begin
            start = 1;
            @(posedge clk);
            #1 start = 0;
            expect(1, 0, 1, 0, "clear");
            @(posedge clk);
            #1;
            for (c = 0; c < RUNLEN; c = c + 1) begin
                expect(0, 1, 1, 0, "run");
                if (t !== c) begin
                    $display("FAIL %0s: t=%0d want %0d", name, t, c);
                    errors = errors + 1;
                end
                if (c == 3) start = 1;
                @(posedge clk);
                #1 start = 0;
            end
            expect(0, 0, 0, 1, "done");
            repeat (3) @(posedge clk);
            #1 expect(0, 0, 0, 1, "done held");
            $display("checked %0s: clear 1 cycle, run %0d cycles, done held", name, RUNLEN);
        end
    endtask

    initial begin
        $dumpfile("sim/controller_tb.vcd");
        $dumpvars(0, controller_tb);
        @(posedge clk);
        #1 rst = 0;
        expect(0, 0, 0, 0, "idle");
        repeat (2) @(posedge clk);
        #1 expect(0, 0, 0, 0, "idle held");

        one_run("first run");
        one_run("back-to-back run");

        if (errors == 0)
            $display("ALL CONTROLLER TESTS PASSED");
        else
            $display("CONTROLLER TESTS FAILED: %0d", errors);
        $finish;
    end
endmodule
