`timescale 1ns / 1ps
// ============================================================================
//  CPE222 LAB08 : VGA RPG Demo on the Nexys A7-100T (Modular Top-Level)
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
    // ---------------- Clock and Reset ----------------
    wire clk, locked;
    clk_gen u_clk (.clk100(CLK100MHZ), .clk25(clk), .locked(locked));

    reg rst_1 = 1'b1, rst = 1'b1;
    always @(posedge clk) {rst, rst_1} <= {rst_1, ~(locked & CPU_RESETN)};

    // ---------------- VGA Timing ----------------
    wire [9:0] x, y;
    wire       hsync, vsync, video_on;
    vga_sync u_sync (
        .clk(clk), .rst(rst), .x(x), .y(y),
        .hsync(hsync), .vsync(vsync), .video_on(video_on)
    );

    wire tick = (x == 10'd0) && (y == 10'd480); // 60 Hz frame tick

    // ---------------- Inter-Module Wires ----------------
    wire [9:0]   px, py, cam_x, cam_y;
    wire         back, mirror, moving, adv;
    wire         is_attacking, player_hit_pulse;
    wire [13:0]  p_dmg;
    wire [8:0]   player_hp, player_max_hp;

    wire [3:0]   item_active;
    wire [2:0]   current_form;
    wire [39:0]  flat_item_x, flat_item_y;
    wire         item_picked;
    wire [8:0]   next_max_hp;

    wire [159:0] flat_minion_x, flat_minion_y;
    wire [207:0] flat_minion_hp;
    wire [1:0]   minion_state;
    wire [15:0]  minion_active_atk;
    wire [3:0]   barrier_active;
    wire [15:0]  flat_minion_dying;
    wire         minion_dmg_to_player;

    wire [9:0]   boss_x, boss_y;
    wire [1:0]   boss_state;
    wire [16:0]  boss_hp;
    wire         boss_dying;
    wire         game_won;
    wire         boss_dmg_to_player;

    // ---------------- Player Controller ----------------
    player u_player (
        .clk(clk), .rst(rst), .tick(tick),
        .btn({BTNU, BTND, BTNL, BTNR}),
        .btn_attack(BTNC), .sw0(SW[0]),
        .current_form(current_form),
        .flat_item_x(flat_item_x), .flat_item_y(flat_item_y),
        .barrier_active(barrier_active),
        .item_picked(item_picked), .next_max_hp(next_max_hp),
        .boss_dmg_to_player(boss_dmg_to_player),
        .minion_dmg_to_player(minion_dmg_to_player),
        .game_won(game_won),
        .px(px), .py(py), .cam_x(cam_x), .cam_y(cam_y),
        .back(back), .mirror(mirror), .moving(moving), .adv(adv),
        .is_attacking(is_attacking), .player_hit_pulse(player_hit_pulse),
        .p_dmg(p_dmg),
        .player_hp(player_hp), .player_max_hp(player_max_hp)
    );

    // ---------------- Item & Evolution Controller ----------------
    item_ctrl u_item (
        .clk(clk), .rst(rst), .tick(tick),
        .game_won(game_won),
        .px(px), .py(py),
        .barrier_active(barrier_active),
        .item_active(item_active),
        .current_form(current_form),
        .flat_item_x(flat_item_x), .flat_item_y(flat_item_y),
        .item_picked(item_picked),
        .next_max_hp(next_max_hp)
    );

    // ---------------- Minion AI & Patrol Controller ----------------
    minion_ctrl u_minion (
        .clk(clk), .rst(rst), .tick(tick),
        .game_won(game_won),
        .px(px), .py(py), .player_hp(player_hp),
        .current_form(current_form),
        .flat_item_x(flat_item_x), .flat_item_y(flat_item_y),
        .player_hit_pulse(player_hit_pulse), .p_dmg(p_dmg),
        .flat_minion_x(flat_minion_x), .flat_minion_y(flat_minion_y),
        .flat_minion_hp(flat_minion_hp),
        .minion_state(minion_state),
        .minion_active_atk(minion_active_atk),
        .barrier_active(barrier_active),
        .flat_minion_dying(flat_minion_dying),
        .minion_dmg_to_player(minion_dmg_to_player)
    );

    // ---------------- Boss AI Controller ----------------
    boss_ctrl u_boss (
        .clk(clk), .rst(rst), .tick(tick),
        .px(px), .py(py), .player_hp(player_hp),
        .player_hit_pulse(player_hit_pulse), .p_dmg(p_dmg),
        .boss_x(boss_x), .boss_y(boss_y),
        .boss_state(boss_state), .boss_hp(boss_hp),
        .boss_dying(boss_dying), .game_won(game_won),
        .boss_dmg_to_player(boss_dmg_to_player)
    );

    // ---------------- Walking Animation FSM ----------------
    wire [1:0] step, walk_state;
    walk_fsm u_walk (
        .clk(clk), .clear_n(~rst), .adv(adv), .m(moving),
        .step(step), .state(walk_state)
    );

    wire [4:0] base_frame        = current_form * 5'd4;
    wire [4:0] walk_sprite_frame = base_frame + {3'd0, step};
    wire [4:0] sprite_frame      = is_attacking ? (base_frame + 5'd3) : walk_sprite_frame;
    assign LED = walk_state;

    // ---------------- VGA Picture Renderer ----------------
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
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS)
    );

    // ---------------- 7-Segment Timer & Form Display ----------------
    game_timer u_timer (
        .clk(clk), .rst(rst),
        .game_won(game_won), .player_hp(player_hp),
        .current_form(current_form),
        .CA(CA), .CB(CB), .CC(CC), .CD(CD),
        .CE(CE), .CF(CF), .CG(CG), .DP(DP),
        .AN(AN)
    );

endmodule
