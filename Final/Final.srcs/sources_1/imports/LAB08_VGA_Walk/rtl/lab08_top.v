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
    output wire [1:0] LED
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
endmodule
