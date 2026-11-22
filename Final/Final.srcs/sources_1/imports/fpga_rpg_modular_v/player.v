`timescale 1ns / 1ps
// ============================================================================
//  Player Movement, Camera Viewport, Attack Timer, and Player HP Controller
// ============================================================================
module player (
    input  wire        clk, rst, tick,
    input  wire [3:0]  btn,
    input  wire        btn_attack, sw0,
    input  wire [2:0]  current_form,
    input  wire [39:0] flat_item_x, flat_item_y,
    input  wire [3:0]  barrier_active,
    input  wire        item_picked,
    input  wire [8:0]  next_max_hp,
    input  wire        boss_dmg_to_player,
    input  wire        minion_dmg_to_player,
    input  wire        game_won,

    output reg  [9:0]  px = 10'd480, py = 10'd540,
    output reg  [9:0]  cam_x = 10'd0, cam_y = 10'd0,
    output reg         back = 1'b0, mirror = 1'b0,
    output wire        moving, adv,
    output reg         is_attacking = 1'b0,
    output wire        player_hit_pulse,
    output wire [13:0] p_dmg,
    output reg  [8:0]  player_hp = 9'd100, player_max_hp = 9'd100
);
    wire [2:0] step_size = sw0 ? 3'd5 : 3'd2;
    reg  [3:0] btn_s = 4'd0, b = 4'd0;
    reg  [2:0] frames = 3'd0;
    reg  [4:0] attack_timer = 5'd0;

    wire up = b[3], down = b[2], left = b[1], right = b[0];
    assign moving = up | down | left | right;
    assign adv    = tick && (!moving || frames == 3'd7);

    assign p_dmg = (current_form == 3'd0) ? 14'd1 :
                   (current_form == 3'd1) ? 14'd10 :
                   (current_form == 3'd2) ? 14'd100 :
                   (current_form == 3'd3) ? 14'd1000 : 14'd10000;

    assign player_hit_pulse = !game_won && is_attacking && (attack_timer == 5'd1);

    wire [8:0] total_incoming_dmg = (boss_dmg_to_player   ? 9'd50 : 9'd0) +
                                    (minion_dmg_to_player ? 9'd20 : 9'd0);

    // Unpack Item Coordinates for Barrier Collision
    wire [9:0] item_x [0:3], item_y [0:3];
    assign {item_x[3], item_x[2], item_x[1], item_x[0]} = flat_item_x;
    assign {item_y[3], item_y[2], item_y[1], item_y[0]} = flat_item_y;

    wire [9:0] nx_l = px - step_size, nx_r = px + step_size;
    wire [9:0] ny_u = py - step_size, ny_d = py + step_size;
    reg hit_l, hit_r, hit_u, hit_d;
    integer c_i;
    always @(*) begin
        hit_l = 1'b0; hit_r = 1'b0; hit_u = 1'b0; hit_d = 1'b0;
        for (c_i = 0; c_i < 4; c_i = c_i + 1) begin
            if (barrier_active[c_i]) begin
                if (nx_l >= item_x[c_i] - 60 && nx_l <= item_x[c_i] + 60 && py >= item_y[c_i] - 60 && py <= item_y[c_i] + 60) hit_l = 1'b1;
                if (nx_r >= item_x[c_i] - 60 && nx_r <= item_x[c_i] + 60 && py >= item_y[c_i] - 60 && py <= item_y[c_i] + 60) hit_r = 1'b1;
                if (px >= item_x[c_i] - 60 && px <= item_x[c_i] + 60 && ny_u >= item_y[c_i] - 60 && ny_u <= item_y[c_i] + 60) hit_u = 1'b1;
                if (px >= item_x[c_i] - 60 && px <= item_x[c_i] + 60 && ny_d >= item_y[c_i] - 60 && ny_d <= item_y[c_i] + 60) hit_d = 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        btn_s <= btn;
        b     <= btn_s;

        if (rst) begin
            px            <= 10'd480;
            py            <= 10'd540;
            cam_x         <= 10'd0;
            cam_y         <= 10'd0;
            back          <= 1'b0;
            mirror        <= 1'b0;
            frames        <= 3'd0;
            player_max_hp <= 9'd100;
            player_hp     <= 9'd100;
            is_attacking  <= 1'b0;
            attack_timer  <= 5'd0;
        end else if (tick) begin
            if (!game_won) begin
                // Player Movement within 960x640 Map (52px margin)
                if (player_hp > 0) begin
                    if (left  && px > 52  && !hit_l) begin px <= px - step_size; mirror <= 1'b0; end
                    if (right && px < 908 && !hit_r) begin px <= px + step_size; mirror <= 1'b1; end
                    if (up    && py > 52  && !hit_u) begin py <= py - step_size; back   <= 1'b1; end
                    if (down  && py < 588 && !hit_d) begin py <= py + step_size; back   <= 1'b0; end
                    frames <= moving ? frames + 1'b1 : 3'd0;
                end

                // Camera Viewport Clamp (320x240 Window inside 960x640 Map)
                cam_x <= (px < 160) ? 10'd0 : (px > 10'd800) ? 10'd640 : px - 10'd160;
                cam_y <= (py < 120) ? 10'd0 : (py > 10'd520) ? 10'd400 : py - 10'd120;

                // Player Attack Timer
                if (is_attacking) begin
                    attack_timer <= attack_timer + 1'b1;
                    if (attack_timer >= 5'd20) begin
                        is_attacking <= 1'b0;
                        attack_timer <= 5'd0;
                    end
                end else if (btn_attack && player_hp > 0) begin
                    is_attacking <= 1'b1;
                    attack_timer <= 5'd0;
                end

                // Player HP Update (Evolution Heal or Enemy Damage)
                if (item_picked) begin
                    player_max_hp <= next_max_hp;
                    player_hp     <= next_max_hp;
                end else if (total_incoming_dmg > 0) begin
                    if (player_hp > total_incoming_dmg)
                        player_hp <= player_hp - total_incoming_dmg;
                    else
                        player_hp <= 9'd0;
                end
            end
        end
    end

endmodule
