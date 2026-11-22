`timescale 1ns / 1ps
// ============================================================================
//  Game Logic Subsystem Wrapper (Player + Item + Minion + Boss + Walk FSM)
// ============================================================================
module game_logic (
    input  wire         clk, rst, tick,
    input  wire [3:0]   btn,
    input  wire         btn_attack, sw0,

    output wire [9:0]   px, py, cam_x, cam_y,
    output wire [4:0]   sprite_frame,
    output wire         mirror,
    output wire [3:0]   item_active,
    output wire [2:0]   current_form,
    output wire [39:0]  flat_item_x, flat_item_y,
    output wire [9:0]   boss_x, boss_y,
    output wire [1:0]   boss_state,
    output wire [16:0]  boss_hp,
    output wire [8:0]   player_hp, player_max_hp,
    output wire [159:0] flat_minion_x, flat_minion_y,
    output wire [207:0] flat_minion_hp,
    output wire [1:0]   minion_state,
    output wire [15:0]  minion_active_atk,
    output wire [3:0]   barrier_active,
    output wire         boss_dying,
    output wire [15:0]  flat_minion_dying,
    output wire         game_won,
    output wire [1:0]   walk_state
);
    // Internal Logic Signals
    wire        back, moving, adv;
    wire        is_attacking, player_hit_pulse;
    wire [13:0] p_dmg;
    wire        item_picked;
    wire [8:0]  next_max_hp;
    wire        minion_dmg_to_player;
    wire        boss_dmg_to_player;

    // 1. Player Movement, Camera & HP Controller
    player u_player (
        .clk(clk), .rst(rst), .tick(tick),
        .btn(btn), .btn_attack(btn_attack), .sw0(sw0),
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

    // 2. Collectible Items & Form Evolution Controller
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

    // 3. 16 Minions Patrol & Selective AI Controller
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

    // 4. Boss AI & Victory Controller
    boss_ctrl u_boss (
        .clk(clk), .rst(rst), .tick(tick),
        .px(px), .py(py), .player_hp(player_hp),
        .player_hit_pulse(player_hit_pulse), .p_dmg(p_dmg),
        .boss_x(boss_x), .boss_y(boss_y),
        .boss_state(boss_state), .boss_hp(boss_hp),
        .boss_dying(boss_dying), .game_won(game_won),
        .boss_dmg_to_player(boss_dmg_to_player)
    );

    // 5. Walking Animation FSM & Sprite Frame Multiplexer
    wire [1:0] step;
    walk_fsm u_walk (
        .clk(clk), .clear_n(~rst), .adv(adv), .m(moving),
        .step(step), .state(walk_state)
    );

    wire [4:0] base_frame        = current_form * 5'd4;
    wire [4:0] walk_sprite_frame = base_frame + {3'd0, step};
    assign     sprite_frame      = is_attacking ? (base_frame + 5'd3) : walk_sprite_frame;

endmodule
