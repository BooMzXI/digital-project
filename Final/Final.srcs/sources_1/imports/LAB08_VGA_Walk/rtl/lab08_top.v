`timescale 1ns / 1ps
// ============================================================================
//  CPE222 LAB08 : VGA walk demo on the Nexys A7-100T   (given - do not modify)
//
//  BTNU/BTND/BTNL/BTNR : walk          CPU RESET : restart
//  LED1 LED0           : state of walk_fsm (y2 y1)
//  VGA                 : 640 x 480 @ 60 Hz, game picture 320 x 240 shown 2x
//
//  Everything runs on one 25 MHz clock:
//    clk_gen -> vga_sync (Part A) -> vga_render -> VGA pins
//               player -> walk_fsm (Part C) -> sprite picture
// ============================================================================
module lab08_top (
    input  wire       CLK100MHZ,
    input  wire       CPU_RESETN,
    input  wire       BTNU, BTND, BTNL, BTNR,
    output wire [3:0] VGA_R, VGA_G, VGA_B,
    output wire       VGA_HS, VGA_VS,
    output wire [1:0] LED,
    // ---  7-Segment ---
    output wire       CA, CB, CC, CD, CE, CF, CG, DP,
    output wire [7:0] AN
);
    // ---------------- clock and reset ----------------
    wire clk, locked;
    clk_gen u_clk (.clk100(CLK100MHZ), .clk25(clk), .locked(locked));

    reg rst_1 = 1'b1, rst = 1'b1;                 // reset, moved to the 25 MHz clock
    always @(posedge clk) {rst, rst_1} <= {rst_1, ~(locked & CPU_RESETN)};

    // ---------------- Part A : VGA timing ----------------
    wire [9:0] x, y;
    wire       hsync, vsync, video_on;
    vga_sync u_sync (.clk(clk), .rst(rst), .x(x), .y(y),
                     .hsync(hsync), .vsync(vsync), .video_on(video_on));

    // one pulse per frame, at the start of the blank lines (the picture is not being drawn)
    wire tick = (x == 10'd0) && (y == 10'd480);

    // ---------------- player and camera ----------------
    wire [9:0] px, py, cam_y;
    wire [8:0] cam_x;
    wire       back, mirror, moving, adv;
    player u_player (.clk(clk), .rst(rst), .tick(tick), .btn({BTNU, BTND, BTNL, BTNR}),
                     .px(px), .py(py), .cam_x(cam_x), .cam_y(cam_y),
                     .back(back), .mirror(mirror), .moving(moving), .adv(adv));

    // ---------------- Part C : walking picture ----------------
    wire [1:0] step, walk_state;
    walk_fsm u_walk (.clk(clk), .clear_n(~rst), .adv(adv), .m(moving),
                     .step(step), .state(walk_state));

    // sprite pictures: 0 stand, 1 step, 2 other step (to the front); 3-5 the same to the back
    wire [2:0] sprite_frame = (back ? 3'd3 : 3'd0) + {1'b0, step};
    assign LED = walk_state;

    // ---------------- picture ----------------
    vga_render u_render (.clk(clk), .x(x), .y(y), .hsync(hsync), .vsync(vsync), .video_on(video_on),
                         .px(px), .py(py), .cam_x(cam_x), .cam_y(cam_y),
                         .sprite_frame(sprite_frame), .mirror(mirror),
                         .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS));
                         
   wire tick_1sec, tick_fast;
   
   
// ---------------- timer ----------------
tick_gen #(.DIV(25_000_000)) u_tick_1sec (
    .clk(clk), .reset_n(~rst), .tick(tick_1sec)
);

tick_gen #(.DIV(25_000)) u_tick_fast ( // 25MHz / 25,000 = 1,000 Hz
    .clk(clk), .reset_n(~rst), .tick(tick_fast)
);

// 2. Cascade 4-digit Counter
wire [3:0] d0, d1, d2, d3;

// Counting conditions for each digit
wire en_d1 = tick_1sec & (d0 == 4'd9);
wire en_d2 = en_d1     & (d1 == 4'd9);
wire en_d3 = en_d2     & (d2 == 4'd9);

mod10_jk cnt0 (.clk(clk), .clear_n(~rst), .en(tick_1sec), .count(d0)); // Ones digit
mod10_jk cnt1 (.clk(clk), .clear_n(~rst), .en(en_d1),     .count(d1)); // Tens digit
mod10_jk cnt2 (.clk(clk), .clear_n(~rst), .en(en_d2),     .count(d2)); // Hundreds digit
mod10_jk cnt3 (.clk(clk), .clear_n(~rst), .en(en_d3),     .count(d3)); // Thousands digit

// 3. Screen switching circuit (Multiplexer)
reg [1:0] scan_sel = 0;
always @(posedge clk) begin
    if (tick_fast) scan_sel <= scan_sel + 1'b1;
end

reg [3:0] current_digit;
reg [7:0] an_temp;

always @(*) begin
    case (scan_sel)
        2'd0: begin current_digit = d0; an_temp = 8'b1111_1110; end // open AN[0]
        2'd1: begin current_digit = d1; an_temp = 8'b1111_1101; end // open AN[1]
        2'd2: begin current_digit = d2; an_temp = 8'b1111_1011; end // open AN[2]
        2'd3: begin current_digit = d3; an_temp = 8'b1111_0111; end // open AN[3]
    endcase
end

// 4. Decode the selected digit for 7-Segment display
wire [6:0] seg_n;
seg7_dec u_seg7 (.digit(current_digit), .seg_n(seg_n));

assign {CG, CF, CE, CD, CC, CB, CA} = seg_n;
assign DP = 1'b1;           // Turn off decimal point
assign AN = an_temp;
endmodule
