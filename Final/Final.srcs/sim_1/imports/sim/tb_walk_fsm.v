`timescale 1ns / 1ps
//=============================================================================
// CPE222 LAB08 - Part C testbench : walk_fsm
//   1) reset                       4) adv = 0 must hold the state
//   2) walking: 10 adv pulses       5) 300 random clocks
//   3) stop walking                 6) asynchronous clear
// A failure names the row of the state table that is wrong.
// Clock period = 10 ns.  adv and m change 2 ns after each rising edge.
//=============================================================================
module tb_walk_fsm;

    reg  clk = 1'b0, clear_n = 1'b0, adv = 1'b0, m = 1'b0;
    wire [1:0] step, state;

    always #5 clk = ~clk;

    walk_fsm dut (.clk(clk), .clear_n(clear_n), .adv(adv), .m(m), .step(step), .state(state));

    integer errors = 0, grp_err = 0, checking = 0, i, k;
    reg     reported [0:15];             // one message per row {adv, state, m}
    reg     step_rep [0:3];              // one message per state for step

    // ---------------- golden model ----------------
    function [1:0] gnext;                    // S0 -> S1 -> S2 -> S3 -> S0 while m = 1
        input [1:0] s;
        input       mm;
        gnext = mm ? s + 2'd1 : 2'd0;
    endfunction
    function [1:0] gstep;                    // S1 -> 1, S3 -> 2, S0/S2 -> 0
        input [1:0] s;
        gstep = (s == 2'd1) ? 2'd1 : (s == 2'd3) ? 2'd2 : 2'd0;
    endfunction

    // ---------------- automatic checker ----------------
    reg [1:0] ps, es;
    reg       pm, pa;
    always @(posedge clk) begin
        if (checking) begin
            ps = state;  pm = m;  pa = adv;
            #1;
            es = pa ? gnext(ps, pm) : ps;
            if (state !== es) begin
                errors = errors + 1;
                if (!reported[{pa, ps, pm}]) begin
                    reported[{pa, ps, pm}] = 1'b1;
                    if (pa) $display("FAIL : state S%0d (%b), m=%b, adv=1 -> expected S%0d (%b), got %b",
                                     ps, ps, pm, es, es, state);
                    else    $display("FAIL : state S%0d (%b), adv=0 -> the state must not change, got %b",
                                     ps, ps, state);
                end
            end
            else if (step !== gstep(state)) begin
                errors = errors + 1;
                if (!step_rep[state]) begin
                    step_rep[state] = 1'b1;
                    $display("FAIL : in state S%0d (%b) step should be %0d, got %b",
                             state, state, gstep(state), step);
                end
            end
        end
    end

    task drive;                              // values for the next clock cycle
        input a, mm;
        begin
            @(posedge clk); #2 adv = a; m = mm;
        end
    endtask

    task group_result;
        input [8*44:1] msg;
        begin
            if (errors == grp_err) $display("ok   : %0s", msg);
            else                   $display("FAIL : %0s  (%0d error(s))", msg, errors - grp_err);
            grp_err = errors;
        end
    endtask

    integer seed = 8;

    initial begin
        for (i = 0; i < 16; i = i + 1) reported[i] = 1'b0;
        for (i = 0; i < 4; i = i + 1)  step_rep[i] = 1'b0;
        $display("==================================================");
        $display(" LAB08 Part C : walk_fsm");
        $display("==================================================");

        // ---------- 1) reset ----------
        clear_n = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        if (state !== 2'b00 || step !== 2'd0) begin
            errors = errors + 1;
            $display("FAIL : reset  state=%b step=%b (should be 00, 00)", state, step);
        end
        @(negedge clk) clear_n = 1'b1;
        group_result("reset -> S0 (00), step = 0");

        // ---------- 2) walking ----------
        checking = 1;
        $display("       adv  m | state y2y1 | step");
        for (k = 0; k < 10; k = k + 1) begin
            drive(1'b1, 1'b1);
            drive(1'b0, 1'b1);               // one clock with adv = 0 between pulses
            @(negedge clk);
            $display("       #%-3d 1 |     %b     |  %0d", k + 1, state, step);
        end
        group_result("walking: S0 S1 S2 S3 S0 ...");

        // ---------- 3) stop walking from every state ----------
        for (k = 0; k < 4; k = k + 1) begin
            for (i = 0; i <= k; i = i + 1) begin drive(1'b1, 1'b1); drive(1'b0, 1'b1); end
            drive(1'b1, 1'b0);               // m = 0 -> S0
            drive(1'b0, 1'b0);
            drive(1'b0, 1'b0);
        end
        group_result("m = 0 -> back to S0 from every state");

        // ---------- 4) adv = 0 holds ----------
        drive(1'b1, 1'b1); drive(1'b1, 1'b1);
        for (i = 0; i < 8; i = i + 1) drive(1'b0, i[0]);
        group_result("adv = 0 -> the state is held");

        // ---------- 5) random ----------
        for (i = 0; i < 300; i = i + 1) drive($random(seed), $random(seed));
        @(posedge clk); #3;
        group_result("300 random clocks");

        // ---------- 6) asynchronous clear ----------
        checking = 0;
        drive(1'b1, 1'b1); drive(1'b1, 1'b1); drive(1'b1, 1'b1);   // go to some state away from S0
        @(posedge clk); #3;
        clear_n = 1'b0;
        #1;                                   // no clock edge yet
        if (state !== 2'b00) begin
            errors = errors + 1;
            $display("FAIL : asynchronous clear did not force state 00");
        end
        @(negedge clk) clear_n = 1'b1;
        group_result("asynchronous clear (no clock needed)");

        $display("==================================================");
        if (errors == 0) $display(" RESULT : PASS");
        else             $display(" RESULT : FAIL  (%0d error(s))", errors);
        $display("==================================================");
        $finish;
    end

endmodule
