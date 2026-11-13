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
    input  wire [4:0]  sprite_frame,
    input  wire        mirror,
//for item
input  wire [2:0]  item_active,
    input  wire [29:0] flat_item_x,
    input  wire [29:0] flat_item_y,
// boss & health bar
input  wire [9:0]  boss_x, boss_y,
    input  wire [1:0]  boss_state,
    input  wire [7:0]  boss_hp,
    input  wire [6:0]  player_hp,
//-----------------------------------------
    output reg  [3:0]  VGA_R = 0, VGA_G = 0, VGA_B = 0,
    output reg         VGA_HS = 1, VGA_VS = 1
);
//divide item wire
wire [9:0] item_x [0:2];
    wire [9:0] item_y [0:2];
    assign {item_x[2], item_x[1], item_x[0]} = flat_item_x;
    assign {item_y[2], item_y[1], item_y[0]} = flat_item_y;

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
    wire [14:0] sprite_addr = sprite_frame * 15'd1536 + {sy[5:0], 5'd0} + col;

    wire [7:0]  sprite_index;
    wire [11:0] sprite_color;
    rom_1p  #(.DW(8), .AW(15), .DEPTH(32768), .FILE("sprite.mem")) u_sprite (
        .clk(clk), .addr(sprite_addr), .q(sprite_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_sprite_pal (
        .clk(clk), .addr(sprite_index), .q(sprite_color));

//--------------------item color-----
reg on_item = 0;
    reg [1:0] active_item_id = 0; 
    reg [4:0] item_col = 0;
    reg [5:0] item_row = 0;

integer i;
    // find that have pixle in the same spot?
    always @(*) begin
        on_item = 1'b0;
        active_item_id = 2'd0;
        item_col = 5'd0;
        item_row = 6'd0;
        
        for (i = 0; i < 3; i = i + 1) begin
            // --- sprite colour: 32 x 48 picture with the feet at (px, py) ----
            if (item_active[i] && 
                (wx >= (item_x[i] - 16)) && (wx < (item_x[i] + 16)) &&
                (wy >= (item_y[i] - 16)) && (wy < (item_y[i] + 16))) begin
                
                on_item = 1'b1;
                active_item_id = i[1:0];
                item_col = wx - (item_x[i] - 16);
                item_row = wy - (item_y[i] - 16);
            end
        end
    end
// find Address (example 12, 13, 14 after char sprite)
    // +12 คือ skip all form (ร่างละ 4 ท่า = 12 ท่า)
wire [4:0] item_frame = 5'd12 + {3'b000, active_item_id};
    wire [14:0] item_addr = item_frame * 15'd1536 + {item_row, 5'd0} + item_col;

    // find color (share sprite.mem and spr_pal.mem )
    wire [7:0] item_index;
    wire [11:0] item_color;
    rom_1p  #(.DW(8), .AW(15), .DEPTH(32768), .FILE("sprite.mem")) u_item_rom (
        .clk(clk), .addr(item_addr), .q(item_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_item_pal (
        .clk(clk), .addr(item_index), .q(item_color));

// ---- Boss Sprite (e.g.start at frame16, 17, 18, 19) ----
    wire signed [11:0] bsx = $signed({2'b0, wx}) - $signed({2'b0, boss_x}) + 12'sd16;
    wire signed [11:0] bsy = $signed({2'b0, wy}) - $signed({2'b0, boss_y}) + 12'sd47;
    wire on_boss = bsx >= 0 && bsx < 32 && bsy >= 0 && bsy < 48;
    wire [4:0] boss_frame = 5'd16 + {3'b000, boss_state};
    wire [14:0] boss_addr = boss_frame * 15'd1536 + {bsy[5:0], 5'd0} + bsx[4:0];
    
    wire [7:0] boss_index;
    wire [11:0] boss_color;
    rom_1p  #(.DW(8), .AW(15), .DEPTH(32768), .FILE("sprite.mem")) u_boss_rom (
        .clk(clk), .addr(boss_addr), .q(boss_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_boss_pal (
        .clk(clk), .addr(boss_index), .q(boss_color));

// ---- Health Bars  ----
    // player
    wire on_php_bg = (wx >= px - 16 && wx <= px + 15) && (wy >= py - 52 && wy <= py - 50);
    wire [4:0] php_w = player_hp[6:1]; // หาร 2 เพื่อสเกลความยาว
    wire on_php_fg = on_php_bg && (wx < (px - 16 + {5'b0, php_w}));

    // boss
    wire on_bhp_bg = (wx >= boss_x - 32 && wx <= boss_x + 31) && (wy >= boss_y - 52 && wy <= boss_y - 50);
    wire [5:0] bhp_w = boss_hp[7:1]; 
    wire on_bhp_fg = on_bhp_bg && (wx < (boss_x - 32 + {4'b0, bhp_w}));

    // ---- boss attack zone ----
    wire on_red_square = (boss_state == 2'd1) && (
        (wx >= boss_x - 25 && wx <= boss_x + 25 && (wy == boss_y - 25 || wy == boss_y + 25 || wy == boss_y - 24 || wy == boss_y + 24)) ||
        (wy >= boss_y - 25 && wy <= boss_y + 25 && (wx == boss_x - 25 || wx == boss_x + 25 || wx == boss_x - 24 || wx == boss_x + 24))
    );

    // ---- pipeline ----
    reg on_1 = 0, see_2 = 0;
    reg on_item_1 = 0, see_item_2 = 0;
    reg on_boss_1 = 0, see_boss_2 = 0;
    reg on_php_bg_1=0, on_php_fg_1=0, on_bhp_bg_1=0, on_bhp_fg_1=0, on_rs_1=0;
    reg on_php_bg_2=0, on_php_fg_2=0, on_bhp_bg_2=0, on_bhp_fg_2=0, on_rs_2=0;
    reg vid_1 = 0, vid_2 = 0;
    reg hs_1 = 1, hs_2 = 1, vs_1 = 1, vs_2 = 1;


    always @(posedge clk) begin
        // clock 1
        on_1        <= on_sprite;
        on_item_1   <= on_item;
        on_boss_1   <= on_boss;
        on_php_bg_1 <= on_php_bg; on_php_fg_1 <= on_php_fg;
        on_bhp_bg_1 <= on_bhp_bg; on_bhp_fg_1 <= on_bhp_fg;
        on_rs_1     <= on_red_square;
        vid_1 <= video_on;  hs_1 <= hsync;  vs_1 <= vsync;
        // clock 2 : colour 0 of the sprite is transparent
        see_2       <= on_1 && (sprite_index != 8'd0);
        see_item_2  <= on_item_1 && (item_index != 8'd0);	
        see_boss_2  <= on_boss_1 && (boss_index != 8'd0);
        on_php_bg_2 <= on_php_bg_1; on_php_fg_2 <= on_php_fg_1;
        on_bhp_bg_2 <= on_bhp_bg_1; on_bhp_fg_2 <= on_bhp_fg_1;
        on_rs_2     <= on_rs_1;
        vid_2 <= vid_1;     hs_2 <= hs_1;   vs_2 <= vs_1;
        // clock 3 : the screen must be black outside the picture
       {VGA_R, VGA_G, VGA_B} <= !vid_2      ? 12'h000 : 
                                 on_php_fg_2 ? 12'h0F0 : // player green
                                 on_php_bg_2 ? 12'h800 : //player bg health bar red
                                 on_bhp_fg_2 ? 12'h0F0 : //  boss green
                                 on_bhp_bg_2 ? 12'h800 : // boss bg health bar red
                                 on_rs_2     ? 12'hF00 : // attack zone red
                                 see_2       ? sprite_color : 
                                 see_item_2  ? item_color : 
                                 see_boss_2  ? boss_color :
                                 map_color;
        VGA_HS <= hs_2;
        VGA_VS <= vs_2;
    end
endmodule
