`timescale 1ns / 1ps
// Finds the colour of every screen pixel and sends it to the VGA pins.  (given - do not modify)
//
// The game picture is 320 x 240 and every game pixel is 2 x 2 screen pixels.
// For screen pixel (x, y) the map point is (cam_x + x/2, cam_y + y/2).
// The ROMs need time, so the colour is ready 3 clocks after (x, y):
//   clock 1 : map ROM and sprite ROM give colour numbers
//   clock 2 : the two palettes turn them into 12-bit colours
//   clock 3 : choose sprite or map, and drive the pins
// hsync, vsync and video_on are delayed by the same 3 clocks so that they stay in line.
module vga_render (
    input  wire        clk,
    input  wire [9:0]  x, y,
    input  wire        hsync, vsync, video_on,
    input  wire [9:0]  px, py,
    input  wire [8:0]  cam_x,
    input  wire [9:0]  cam_y,
    input  wire [2:0]  sprite_frame,
    input  wire        mirror,
    output reg  [3:0]  VGA_R = 0, VGA_G = 0, VGA_B = 0,
    output reg         VGA_HS = 1, VGA_VS = 1
);
    // ---- where is this pixel on the map? ----
    wire [8:0]  gx = x[9:1];
    wire [8:0]  gy = y[9:1];
    wire [9:0]  wx = cam_x + gx;
    wire [9:0]  wy = cam_y + gy;

    // ---- map colour ----
    wire [6:0]  map_index;
    wire [11:0] map_color;
    rom_1p  #(.DW(7), .AW(19), .DEPTH(512*768), .FILE("map.mem")) u_map (
        .clk(clk), .addr({wy, wx[8:0]}), .q(map_index));
    rom_lut #(.DW(12), .AW(7), .FILE("map_pal.mem")) u_map_pal (
        .clk(clk), .addr(map_index), .q(map_color));

    // ---- sprite colour: 32 x 48 picture with the feet at (px, py) ----
    wire signed [11:0] sx = $signed({2'b0, wx}) - $signed({2'b0, px}) + 12'sd16;
    wire signed [11:0] sy = $signed({2'b0, wy}) - $signed({2'b0, py}) + 12'sd47;
    wire        on_sprite = sx >= 0 && sx < 32 && sy >= 0 && sy < 48;
    wire [4:0]  col = mirror ? 5'd31 - sx[4:0] : sx[4:0];
    wire [13:0] sprite_addr = sprite_frame * 14'd1536 + {sy[5:0], 5'd0} + col;

    wire [7:0]  sprite_index;
    wire [11:0] sprite_color;
    rom_1p  #(.DW(8), .AW(14), .DEPTH(9216), .FILE("sprite.mem")) u_sprite (
        .clk(clk), .addr(sprite_addr), .q(sprite_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_sprite_pal (
        .clk(clk), .addr(sprite_index), .q(sprite_color));

    // ---- pipeline ----
    reg on_1 = 0, see_2 = 0;
    reg vid_1 = 0, vid_2 = 0;
    reg hs_1 = 1, hs_2 = 1, vs_1 = 1, vs_2 = 1;

    always @(posedge clk) begin
        // clock 1
        on_1  <= on_sprite;
        vid_1 <= video_on;  hs_1 <= hsync;  vs_1 <= vsync;
        // clock 2 : colour 0 of the sprite is transparent
        see_2 <= on_1 && sprite_index != 8'd0;
        vid_2 <= vid_1;     hs_2 <= hs_1;   vs_2 <= vs_1;
        // clock 3 : the screen must be black outside the picture
        {VGA_R, VGA_G, VGA_B} <= !vid_2 ? 12'h000 : see_2 ? sprite_color : map_color;
        VGA_HS <= hs_2;
        VGA_VS <= vs_2;
    end
endmodule
