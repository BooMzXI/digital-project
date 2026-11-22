`timescale 1ns / 1ps
// ============================================================================
//  16 Minions Patrol, Selective Attack AI FSM, and Barrier Unlock Controller
// ============================================================================
module minion_ctrl (
    input  wire         clk, rst, tick,
    input  wire         game_won,
    input  wire [9:0]   px, py,
    input  wire [8:0]   player_hp,
    input  wire [2:0]   current_form,
    input  wire [39:0]  flat_item_x, flat_item_y,
    input  wire         player_hit_pulse,
    input  wire [13:0]  p_dmg,

    output wire [159:0] flat_minion_x, flat_minion_y,
    output wire [207:0] flat_minion_hp,
    output reg  [1:0]   minion_state = 2'd0,
    output reg  [15:0]  minion_active_atk = 16'd0,
    output wire [3:0]   barrier_active,
    output wire [15:0]  flat_minion_dying,
    output reg          minion_dmg_to_player
);
    wire [9:0] item_x [0:3], item_y [0:3];
    assign {item_x[3], item_x[2], item_x[1], item_x[0]} = flat_item_x;
    assign {item_y[3], item_y[2], item_y[1], item_y[0]} = flat_item_y;

    reg [9:0]  m_x [0:15], m_y [0:15];
    reg [12:0] m_hp [0:15];
    reg [5:0]  m_dt [0:15];
    reg [7:0]  minion_timer = 8'd0;
    reg        m_move_tick  = 1'b0;

    genvar g;
    generate
        for (g = 0; g < 16; g = g + 1) begin : pack_m
            assign flat_minion_x[g*10 +: 10] = m_x[g];
            assign flat_minion_y[g*10 +: 10] = m_y[g];
            assign flat_minion_hp[g*13 +: 13]  = m_hp[g];
            assign flat_minion_dying[g]      = (m_dt[g] > 0);
        end
    endgenerate

    assign barrier_active[0] = (current_form == 3'd0 && (m_hp[0]>0 || m_hp[1]>0 || m_hp[2]>0 || m_hp[3]>0));
    assign barrier_active[1] = (current_form < 3'd1) || (current_form == 3'd1 && (m_hp[4]>0 || m_hp[5]>0 || m_hp[6]>0 || m_hp[7]>0));
    assign barrier_active[2] = (current_form < 3'd2) || (current_form == 3'd2 && (m_hp[8]>0 || m_hp[9]>0 || m_hp[10]>0 || m_hp[11]>0));
    assign barrier_active[3] = (current_form < 3'd3) || (current_form == 3'd3 && (m_hp[12]>0 || m_hp[13]>0 || m_hp[14]>0 || m_hp[15]>0));

    integer i, dx_m, dy_m;
    reg [15:0] next_atk_mask;

    // Combinational Damage Pulse to Player (exact tick when minion_state == 2 && minion_timer == 1)
    always @(*) begin
        minion_dmg_to_player = 1'b0;
        if (!game_won && (minion_state == 2'd2) && (minion_timer == 8'd1) && (player_hp > 0)) begin
            for (i = 0; i < 16; i = i + 1) begin
                if (m_hp[i] > 0 && minion_active_atk[i]) begin
                    dx_m = (px > m_x[i]) ? (px - m_x[i]) : (m_x[i] - px);
                    dy_m = (py > m_y[i]) ? (py - m_y[i]) : (m_y[i] - py);
                    if (dx_m <= 20 && dy_m <= 20)
                        minion_dmg_to_player = 1'b1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                if (i < 4)       m_hp[i] <= 13'd5;
                else if (i < 8)  m_hp[i] <= 13'd50;
                else if (i < 12) m_hp[i] <= 13'd500;
                else             m_hp[i] <= 13'd5000;
                m_dt[i] <= 6'd0;
            end

            m_x[0]  <= item_x[0];      m_y[0]  <= item_y[0] - 75;
            m_x[1]  <= item_x[0] + 75; m_y[1]  <= item_y[0];
            m_x[2]  <= item_x[0];      m_y[2]  <= item_y[0] + 75;
            m_x[3]  <= item_x[0] - 75; m_y[3]  <= item_y[0];

            m_x[4]  <= item_x[1];      m_y[4]  <= item_y[1] - 75;
            m_x[5]  <= item_x[1] + 75; m_y[5]  <= item_y[1];
            m_x[6]  <= item_x[1];      m_y[6]  <= item_y[1] + 75;
            m_x[7]  <= item_x[1] - 75; m_y[7]  <= item_y[1];

            m_x[8]  <= item_x[2];      m_y[8]  <= item_y[2] - 75;
            m_x[9]  <= item_x[2] + 75; m_y[9]  <= item_y[2];
            m_x[10] <= item_x[2];      m_y[10] <= item_y[2] + 75;
            m_x[11] <= item_x[2] - 75; m_y[11] <= item_y[2];

            m_x[12] <= item_x[3];      m_y[12] <= item_y[3] - 75;
            m_x[13] <= item_x[3] + 75; m_y[13] <= item_y[3];
            m_x[14] <= item_x[3];      m_y[14] <= item_y[3] + 75;
            m_x[15] <= item_x[3] - 75; m_y[15] <= item_y[3];

            minion_state      <= 2'd0;
            minion_timer      <= 8'd0;
            minion_active_atk <= 16'd0;
            m_move_tick       <= 1'b0;
        end else if (tick) begin
            for (i = 0; i < 16; i = i + 1)
                if (m_dt[i] > 0) m_dt[i] <= m_dt[i] - 1'b1;

            if (!game_won) begin
                // Clockwise Patrol (all minions pause together when minion_state != 0)
                m_move_tick <= ~m_move_tick;
                if (m_move_tick && minion_state == 2'd0) begin
                    for (i = 0; i < 16; i = i + 1) begin
                        if (m_hp[i] > 0) begin
                            if (m_y[i] == item_y[i >> 2] - 10'd75 && m_x[i] < item_x[i >> 2] + 10'd75)
                                m_x[i] <= m_x[i] + 10'd1;
                            else if (m_x[i] == item_x[i >> 2] + 10'd75 && m_y[i] < item_y[i >> 2] + 10'd75)
                                m_y[i] <= m_y[i] + 10'd1;
                            else if (m_y[i] == item_y[i >> 2] + 10'd75 && m_x[i] > item_x[i >> 2] - 10'd75)
                                m_x[i] <= m_x[i] - 10'd1;
                            else if (m_x[i] == item_x[i >> 2] - 10'd75 && m_y[i] > item_y[i >> 2] - 10'd75)
                                m_y[i] <= m_y[i] - 10'd1;
                        end
                    end
                end

                // Take Damage from Player Attack
                if (player_hit_pulse) begin
                    for (i = 0; i < 16; i = i + 1) begin
                        if (m_hp[i] > 0) begin
                            dx_m = (px > m_x[i]) ? (px - m_x[i]) : (m_x[i] - px);
                            dy_m = (py > m_y[i]) ? (py - m_y[i]) : (m_y[i] - py);
                            if (dx_m <= 48 && dy_m <= 48) begin
                                if (m_hp[i] > p_dmg)
                                    m_hp[i] <= m_hp[i] - p_dmg;
                                else begin
                                    m_hp[i] <= 13'd0;
                                    m_dt[i] <= 6'd60;
                                end
                            end
                        end
                    end
                end

                // Minion AI FSM (Locks animation & red border only on nearby minions)
                case (minion_state)
                    2'd0: begin
                        minion_active_atk <= 16'd0;
                        if (minion_timer < 8'd30) begin
                            minion_timer <= minion_timer + 1'b1;
                        end else if (player_hp > 0) begin
                            next_atk_mask = 16'd0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (m_hp[i] > 0) begin
                                    dx_m = (px > m_x[i]) ? (px - m_x[i]) : (m_x[i] - px);
                                    dy_m = (py > m_y[i]) ? (py - m_y[i]) : (m_y[i] - py);
                                    if (dx_m <= 24 && dy_m <= 24)
                                        next_atk_mask[i] = 1'b1;
                                end
                            end
                            if (|next_atk_mask) begin
                                minion_state      <= 2'd1;
                                minion_timer      <= 8'd0;
                                minion_active_atk <= next_atk_mask;
                            end
                        end
                    end
                    2'd1: begin
                        minion_timer <= minion_timer + 1'b1;
                        if (minion_timer >= 8'd50) begin
                            minion_state <= 2'd2;
                            minion_timer <= 8'd0;
                        end
                    end
                    2'd2: begin
                        minion_timer <= minion_timer + 1'b1;
                        if (minion_timer >= 8'd15) begin
                            minion_state      <= 2'd0;
                            minion_timer      <= 8'd0;
                            minion_active_atk <= 16'd0;
                        end
                    end
                endcase
            end
        end
    end

endmodule
