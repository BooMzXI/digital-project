`timescale 1ns / 1ps
// ============================================================================
//  Graphics & Memory Subsystem Wrapper (vga_render + ROMs + Font ROM)
// ============================================================================
module game_graphics (
    input  wire         clk,
    input  wire [9:0]   x, y,
    input  wire         hsync, vsync, video_on,
    input  wire [9:0]   px, py,
    input  wire [9:0]   cam_x, cam_y,
    input  wire [4:0]   sprite_frame,
    input  wire         mirror,
    input  wire [3:0]   item_active,
    input  wire [2:0]   current_form,
    input  wire [39:0]  flat_item_x, flat_item_y,
    input  wire [9:0]   boss_x, boss_y,
    input  wire [1:0]   boss_state,
    input  wire [16:0]  boss_hp,
    input  wire [8:0]   player_hp, player_max_hp,
    input  wire [159:0] flat_minion_x, flat_minion_y,
    input  wire [207:0] flat_minion_hp,
    input  wire [1:0]   minion_state,
    input  wire [15:0]  minion_active_atk,
    input  wire [3:0]   barrier_active,
    input  wire         boss_dying,
    input  wire [15:0]  flat_minion_dying,
    input  wire         game_won,

    output wire [3:0]   VGA_R, VGA_G, VGA_B,
    output wire         VGA_HS, VGA_VS
);
    // Memory Address & Data Buses
    wire [19:0] map_addr;
    wire [4:0]  map_index;
    wire [11:0] map_color;

    wire [16:0] addr_a, addr_b;
    wire [7:0]  q_a, q_b;
    wire [11:0] color_a, color_b;

    // Font ROM Query & Pixel Buses
    wire [7:0]  win_char, die_char, rst_char;
    wire [2:0]  win_row, win_col, die_row, die_col, rst_row, rst_col;
    wire        win_px, die_px, rst_px;

    // 1. VGA Renderer & 3-Stage Overlay Pipeline
    vga_render u_render (
        .clk(clk), .x(x), .y(y), .hsync(hsync), .vsync(vsync), .video_on(video_on),
        .px(px), .py(py), .cam_x(cam_x), .cam_y(cam_y),
        .sprite_frame(sprite_frame), .mirror(mirror),
        .item_active(item_active), .current_form(current_form),
        .flat_item_x(flat_item_x), .flat_item_y(flat_item_y),
        .boss_x(boss_x), .boss_y(boss_y), .boss_state(boss_state),
        .boss_hp(boss_hp), .player_hp(player_hp), .player_max_hp(player_max_hp),
        .flat_minion_x(flat_minion_x), .flat_minion_y(flat_minion_y),
        .flat_minion_hp(flat_minion_hp), .minion_state(minion_state),
        .minion_active_atk(minion_active_atk),
        .barrier_active(barrier_active),
        .boss_dying(boss_dying), .flat_minion_dying(flat_minion_dying), .game_won(game_won),
        .map_addr(map_addr), .map_color(map_color),
        .addr_a(addr_a), .q_a(q_a), .color_a(color_a),
        .addr_b(addr_b), .q_b(q_b), .color_b(color_b),
        .win_char(win_char), .win_row(win_row), .win_col(win_col), .win_px(win_px),
        .die_char(die_char), .die_row(die_row), .die_col(die_col), .die_px(die_px),
        .rst_char(rst_char), .rst_row(rst_row), .rst_col(rst_col), .rst_px(rst_px),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS)
    );

    // 2. Map BRAM (960x640) & 32-Color Palette LUT
    rom_map_960x640 #(.DW(5), .FILE("map.mem")) u_map (
        .clk(clk), .addr(map_addr), .q(map_index)
    );
    rom_lut #(.DW(12), .AW(5), .FILE("map_pal.mem")) u_map_pal (
        .clk(clk), .addr(map_index), .q(map_color)
    );

    // 3. Dual-Port Sprite BRAM (28 Frames x 64x64) & 256-Color Palette LUTs
    rom_2p #(.DW(8), .AW(17), .DEPTH(114688), .FILE("sprite.mem")) u_master_sprite (
        .clk(clk), .addr_a(addr_a), .q_a(q_a), .addr_b(addr_b), .q_b(q_b)
    );
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_pal_a (
        .clk(clk), .addr(q_a), .q(color_a)
    );
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_pal_b (
        .clk(clk), .addr(q_b), .q(color_b)
    );

    // 4. 8x8 Bitmap Font ROMs for Victory & Death Screens
    font_8x8 u_font_win (.char_code(win_char), .row(win_row), .col(win_col), .pixel_on(win_px));
    font_8x8 u_font_die (.char_code(die_char), .row(die_row), .col(die_col), .pixel_on(die_px));
    font_8x8 u_font_rst (.char_code(rst_char), .row(rst_row), .col(rst_col), .pixel_on(rst_px));

endmodule
