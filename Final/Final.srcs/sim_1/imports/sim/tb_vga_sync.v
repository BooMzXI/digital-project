`timescale 1ns / 1ps
//=============================================================================
// CPE222 LAB08 - Part A testbench : vga_sync
// Runs two whole frames (840,000 clocks = 33.6 ms) and checks x, y, hsync,
// vsync and video_on on every clock against the VGA 640x480 @ 60 Hz timing.
// It also measures the line and frame timing and prints it for the lab sheet.
// Clock = 25 MHz (40 ns).  Use Run All: this testbench runs for about 34 ms.
//=============================================================================
module tb_vga_sync;

    reg  clk = 1'b0;
    reg  rst = 1'b1;
    wire [9:0] x, y;
    wire hsync, vsync, video_on;

    always #20 clk = ~clk;

    vga_sync dut (.clk(clk), .rst(rst), .x(x), .y(y),
                  .hsync(hsync), .vsync(vsync), .video_on(video_on));

    // ---------------- golden model ----------------
    integer gx = 0, gy = 0;
    wire g_hs  = !(gx >= 656 && gx < 752);
    wire g_vs  = !(gy >= 490 && gy < 492);
    wire g_vid = (gx < 640) && (gy < 480);

    integer errors = 0, grp_err = 0, checking = 0;
    integer n_xy = 0, n_hs = 0, n_vs = 0, n_vid = 0;
    localparam SHOW = 3;                 // print at most 3 failures of each kind

    always @(negedge clk) begin
        if (checking) begin
            if (x !== gx[9:0] || y !== gy[9:0]) begin
                errors = errors + 1;  n_xy = n_xy + 1;
                if (n_xy <= SHOW)
                    $display("FAIL : counter  expected x=%0d y=%0d, got x=%0d y=%0d", gx, gy, x, y);
            end
            else begin
                // compare the outputs only where x and y are right, so the message is clear
                if (hsync !== g_hs) begin
                    errors = errors + 1;  n_hs = n_hs + 1;
                    if (n_hs <= SHOW) $display("FAIL : hsync    at x=%0d y=%0d should be %b, got %b", x, y, g_hs, hsync);
                end
                if (vsync !== g_vs) begin
                    errors = errors + 1;  n_vs = n_vs + 1;
                    if (n_vs <= SHOW) $display("FAIL : vsync    at x=%0d y=%0d should be %b, got %b", x, y, g_vs, vsync);
                end
                if (video_on !== g_vid) begin
                    errors = errors + 1;  n_vid = n_vid + 1;
                    if (n_vid <= SHOW) $display("FAIL : video_on at x=%0d y=%0d should be %b, got %b", x, y, g_vid, video_on);
                end
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            gx <= 0;  gy <= 0;
        end else begin
            gx <= (gx == 799) ? 0 : gx + 1;
            if (gx == 799) gy <= (gy == 524) ? 0 : gy + 1;
        end
    end

    // ---------------- measurements ----------------
    integer clk_n = 0;
    integer hs_fall1 = -1, hs_fall2 = -1, hs_rise = -1;
    integer vs_fall1 = -1, vs_fall2 = -1, vs_rise = -1;
    integer vid_line = 0, vid_line_max = 0, vid_lines = 0, frame_lines = -1;
    reg hs_d = 1'b1, vs_d = 1'b1, vid_d = 1'b0;

    always @(posedge clk) if (checking) begin
        clk_n = clk_n + 1;
        if (hs_d && !hsync) begin
            if (hs_fall1 < 0) hs_fall1 = clk_n; else if (hs_fall2 < 0) hs_fall2 = clk_n;
        end
        if (!hs_d && hsync && hs_fall1 >= 0 && hs_rise < 0) hs_rise = clk_n;
        if (vs_d && !vsync) begin
            if (frame_lines < 0) frame_lines = vid_lines;   // picture lines in the first frame
            if (vs_fall1 < 0) vs_fall1 = clk_n; else if (vs_fall2 < 0) vs_fall2 = clk_n;
        end
        if (!vs_d && vsync && vs_fall1 >= 0 && vs_rise < 0) vs_rise = clk_n;
        if (video_on) vid_line = vid_line + 1;
        if (vid_d && !video_on) begin
            vid_lines = vid_lines + 1;
            if (vid_line > vid_line_max) vid_line_max = vid_line;
            vid_line = 0;
        end
        hs_d = hsync;  vs_d = vsync;  vid_d = video_on;
    end

    task group_result;
        input [8*44:1] msg;
        begin
            if (errors == grp_err) $display("ok   : %0s", msg);
            else                   $display("FAIL : %0s  (%0d error(s))", msg, errors - grp_err);
            grp_err = errors;
        end
    endtask

    integer hs_period, hs_width, vs_period, vs_width;

    initial begin
        $display("==================================================");
        $display(" LAB08 Part A : vga_sync");
        $display("==================================================");

        // ---------- 1) reset ----------
        rst = 1'b1;
        repeat (3) @(posedge clk);
        #1;
        if (x !== 10'd0 || y !== 10'd0) begin
            errors = errors + 1;
            $display("FAIL : reset  x=%0d y=%0d (both should be 0)", x, y);
        end
        @(negedge clk) rst = 1'b0;
        group_result("reset -> x = 0, y = 0");

        // ---------- 2) two whole frames + 2 lines ----------
        checking = 1;
        repeat (2 * 800 * 525 + 1600) @(posedge clk);
        #1;
        if (n_xy == 0) begin
            $display("ok   : x counts 0..799 and y counts 0..524");
            if (n_hs == 0)  $display("ok   : hsync LOW for x = 656 .. 751");
            if (n_vs == 0)  $display("ok   : vsync LOW for y = 490 .. 491");
            if (n_vid == 0) $display("ok   : video_on HIGH for x < 640 and y < 480");
        end else
            $display("       fix x and y first: hsync, vsync and video_on are checked only where x and y are right");
        if (n_xy > SHOW || n_hs > SHOW || n_vs > SHOW || n_vid > SHOW)
            $display("       (only the first %0d failures of each kind are shown)", SHOW);
        grp_err = errors;

        // ---------- 3) measurements ----------
        hs_period = (hs_fall2 > 0) ? hs_fall2 - hs_fall1 : 0;
        hs_width  = (hs_rise  > 0) ? hs_rise  - hs_fall1 : 0;
        vs_period = (vs_fall2 > 0) ? vs_fall2 - vs_fall1 : 0;
        vs_width  = (vs_rise  > 0) ? vs_rise  - vs_fall1 : 0;
        $display("--------------------------------------------------");
        $display(" Measured (1 clock = 40 ns)");
        $display("INFO : hsync period   = %0d clocks  (should be 800)", hs_period);
        $display("INFO : hsync LOW      = %0d clocks  (should be 96)", hs_width);
        $display("INFO : vsync period   = %0d clocks  (should be 420000)", vs_period);
        $display("INFO : vsync LOW      = %0d clocks  (should be 1600)", vs_width);
        if (frame_lines < 0) frame_lines = 0;
        $display("INFO : video_on HIGH  = %0d clocks per line, %0d lines per frame  (should be 640, 480)",
                 vid_line_max, frame_lines);
        if (hs_period != 800 || hs_width != 96 || vs_period != 420000 || vs_width != 1600 ||
            vid_line_max != 640 || frame_lines != 480) begin
            errors = errors + 1;
            $display("FAIL : measured timing is not VGA 640x480 @ 60 Hz");
        end

        // ---------- 4) reset in the middle of a frame ----------
        checking = 0;
        grp_err  = errors;
        @(negedge clk) rst = 1'b1;
        @(posedge clk); #1;
        if (x !== 10'd0 || y !== 10'd0) begin
            errors = errors + 1;
            $display("FAIL : reset in the middle of a frame  x=%0d y=%0d", x, y);
        end
        @(negedge clk) rst = 1'b0;
        group_result("reset in the middle of a frame");

        $display("==================================================");
        if (errors == 0) $display(" RESULT : PASS");
        else             $display(" RESULT : FAIL  (%0d error(s))", errors);
        $display("==================================================");
        $finish;
    end

endmodule
