`timescale 1ns / 1ps
// ============================================================================
//  Boss AI FSM, HP Management, Death Animation Timer, and Victory Flag
// ============================================================================
module boss_ctrl (
    input  wire        clk, rst, tick,
    input  wire [9:0]  px, py,
    input  wire [8:0]  player_hp,
    input  wire        player_hit_pulse,
    input  wire [13:0] p_dmg,

    output reg  [9:0]  boss_x = 10'd480, boss_y = 10'd320,
    output reg  [1:0]  boss_state = 2'd0,
    output reg  [16:0] boss_hp = 17'd100000,
    output wire        boss_dying,
    output reg         game_won = 1'b0,
    output wire        boss_dmg_to_player
);
    reg [7:0] boss_timer = 8'd0;
    reg [5:0] boss_dt    = 6'd0;

    assign boss_dying = (boss_dt > 0);

    wire [9:0] dx_b = (px > boss_x) ? (px - boss_x) : (boss_x - px);
    wire [9:0] dy_b = (py > boss_y) ? (py - boss_y) : (boss_y - py);

    // Symmetric Hitbox Around Boss Center (±65 px matching red border)
    wire boss_trig_zone = (dx_b <= 10'd70) && (dy_b <= 10'd70);
    wire boss_hit_zone  = (dx_b <= 10'd65) && (dy_b <= 10'd65);

    assign boss_dmg_to_player = !game_won && (boss_hp > 0) &&
                                (boss_state == 2'd2) && (boss_timer == 8'd1) &&
                                boss_hit_zone && (player_hp > 0);

    always @(posedge clk) begin
        if (rst) begin
            boss_x     <= 10'd480;
            boss_y     <= 10'd320;
            boss_hp    <= 17'd100000;
            boss_state <= 2'd0;
            boss_timer <= 8'd0;
            boss_dt    <= 6'd0;
            game_won   <= 1'b0;
        end else if (tick) begin
            if (boss_dt > 0) begin
                boss_dt <= boss_dt - 1'b1;
                if (boss_dt == 6'd1)
                    game_won <= 1'b1;
            end

            if (!game_won) begin
                // Take Damage from Player Attack
                if (player_hit_pulse && boss_hp > 0 && dx_b <= 10'd65 && dy_b <= 10'd65) begin
                    if (boss_hp > p_dmg)
                        boss_hp <= boss_hp - p_dmg;
                    else begin
                        boss_hp <= 17'd0;
                        boss_dt <= 6'd60;
                    end
                end

                // Boss AI FSM
                if (boss_hp > 0) begin
                    case (boss_state)
                        2'd0: begin
                            if (boss_timer < 8'd30) begin
                                boss_timer <= boss_timer + 1'b1;
                            end else if (boss_trig_zone && player_hp > 0) begin
                                boss_state <= 2'd1;
                                boss_timer <= 8'd0;
                            end
                        end
                        2'd1: begin
                            boss_timer <= boss_timer + 1'b1;
                            if (boss_timer >= 8'd50) begin
                                boss_state <= 2'd2;
                                boss_timer <= 8'd0;
                            end
                        end
                        2'd2: begin
                            boss_timer <= boss_timer + 1'b1;
                            if (boss_timer >= 8'd15) begin
                                boss_state <= 2'd0;
                                boss_timer <= 8'd0;
                            end
                        end
                    endcase
                end
            end
        end
    end

endmodule
