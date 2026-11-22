`timescale 1ns / 1ps
// ============================================================================
//  CPE222 LAB08 : VGA RPG Demo on the Nexys A7-100T (Hierarchical Top-Level)
// ============================================================================
module lab08_top (
    input  wire       CLK100MHZ,
    input  wire       CPU_RESETN,
    input  wire       BTNU, BTND, BTNL, BTNR,
    input  wire       BTNC,         // Center = Attack button
    input  wire [0:0] SW,           // SW[0] = Speed boost
    output wire [3:0] VGA_R, VGA_G, VGA_B,
    output wire       VGA_HS, VGA_VS,
    output wire [1:0] LED,
    // --- 7-Segment ---
    output wire       CA, CB, CC, CD, CE, CF, CG, DP,
    output wire [7:0] AN
);
    // ---------------- 1. Clock and Reset ----------------
    wire clk, locked;
    clk_gen u_clk (.clk100(CLK100MHZ), .clk25(clk), .locked(locked));

    reg rst_1 = 1'b1, rst = 1'b1;
    always @(posedge clk) {rst, rst_1} <= {rst_1, ~(locked & CPU_RESETN)};

    // ---------------- 2. VGA Timing ----------------
    wire [9:0] x, y;
    wire       hsync, vsync, video_on;
    vga_sync u_sync (
        .clk(clk), .rst(rst), .x(x), .y(y),
        .hsync(hsync), .vsync(vsync), .video_on(video_on)
    );

    wire tick = (x == 10'd0) && (y == 10'd480); // 60 Hz frame tick

    // ---------------- Inter-Subsystem Buses ----------------
    wire [9:0]   px, py, cam_x, cam_y;
    wire [4:0]   sprite_frame;
    wire         mirror;
    wire [3:0]   item_active;
    wire [2:0]   current_form;
    wire [39:0]  flat_item_x, flat_item_y;
    wire [9:0]   boss_x, boss_y;
    wire [1:0]   boss_state;
    wire [16:0]  boss_hp;
    wire [8:0]   player_hp, player_max_hp;
    wire [159:0] flat_minion_x, flat_minion_y;
    wire [207:0] flat_minion_hp;
    wire [1:0]   minion_state;
    wire [15:0]  minion_active_atk;
    wire [3:0]   barrier_active;
    wire         boss_dying;
    wire [15:0]  flat_minion_dying;
    wire         game_won;
    wire [1:0]   walk_state;

    // ---------------- 3. Game Logic Subsystem ----------------
    game_logic u_logic (
        .clk(clk), .rst(rst), .tick(tick),
        .btn({BTNU, BTND, BTNL, BTNR}),
        .btn_attack(BTNC), .sw0(SW[0]),
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
        .boss_dying(boss_dying), .flat_minion_dying(flat_minion_dying),
        .game_won(game_won),
        .walk_state(walk_state)
    );
    assign LED = walk_state;

    // ---------------- 4. Graphics & Memory Subsystem ----------------
    game_graphics u_gfx (
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
        .boss_dying(boss_dying), .flat_minion_dying(flat_minion_dying),
        .game_won(game_won),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS)
    );

    // ---------------- 5. 7-Segment Timer & Form Display ----------------
    game_timer u_timer (
        .clk(clk), .rst(rst),
        .game_won(game_won), .player_hp(player_hp),
        .current_form(current_form),
        .CA(CA), .CB(CB), .CC(CC), .CD(CD),
        .CE(CE), .CF(CF), .CG(CG), .DP(DP),
        .AN(AN)
    );

endmodule
