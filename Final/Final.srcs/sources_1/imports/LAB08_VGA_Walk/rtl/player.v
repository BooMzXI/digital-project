`timescale 1ns / 1ps
module player (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,              
    input  wire [3:0] btn,               
    input  wire       btn_attack,
    input  wire       sw0,               // SW0 for speed boost
    output reg  [9:0] px = 10'd210,
    output reg  [9:0] py = 10'd655,
    output reg  [8:0] cam_x = 0,
    output reg  [9:0] cam_y = 0,
    output reg        back = 0,          
    output reg        mirror = 0,        
    output wire       moving,            
    output wire       adv,                
    
    // --- 4 Items & 5 Forms ---
    output reg  [3:0] item_active, 
    output reg  [2:0] current_form, 
    output wire [39:0] flat_item_x, 
    output wire [39:0] flat_item_y,
    
    // --- Combat & Boss ---
    output reg        is_attacking = 0,
    output reg  [7:0] player_hp = 8'd64,
    output reg  [7:0] player_max_hp = 8'd64,
    output reg  [9:0] boss_x = 10'd250, 
    output reg  [9:0] boss_y = 10'd200, 
    output reg  [1:0] boss_state = 0,   
    output reg  [7:0] boss_hp = 8'd128, 
    
    // --- 16 Minions & Barrier ---
    output wire [159:0] flat_minion_x, 
    output wire [159:0] flat_minion_y,
    output wire [95:0]  flat_minion_hp,
    output reg  [1:0]   minion_state = 0,
    output wire [3:0]   barrier_active
);
    // Dynamic Speed
    wire [2:0] step_size = sw0 ? 3'd5 : 3'd2;

    reg [3:0] btn_s = 0, b = 0;          
    reg [2:0] frames = 0;                

    wire up = b[3], down = b[2], left = b[1], right = b[0];
    assign moving = up | down | left | right;
    assign adv    = tick && (!moving || frames == 3'd7);

    // Arrays
    reg [9:0] item_x [0:3];
    reg [9:0] item_y [0:3];
    reg [9:0] m_x [0:15];
    reg [9:0] m_y [0:15];
    reg [5:0] m_hp [0:15];

    assign flat_item_x = {item_x[3], item_x[2], item_x[1], item_x[0]}; 
    assign flat_item_y = {item_y[3], item_y[2], item_y[1], item_y[0]};
    
    // Pack 16 minions automatically using genvar
    genvar g;
    generate
        for (g=0; g<16; g=g+1) begin : pack_m
            assign flat_minion_x[g*10 +: 10] = m_x[g];
            assign flat_minion_y[g*10 +: 10] = m_y[g];
            assign flat_minion_hp[g*6 +: 6]  = m_hp[g];
        end
    endgenerate

    // Base Index for current form's minions (current_form * 4)
    wire [3:0] base_idx = {current_form[1:0], 2'b00};
    
    // Barrier is active if any of the 4 minions guarding the current item is alive
    assign barrier_active[0] = (current_form == 3'd0 && (m_hp[0]>0 || m_hp[1]>0 || m_hp[2]>0 || m_hp[3]>0));
    assign barrier_active[1] = (current_form < 3'd1) || (current_form == 3'd1 && (m_hp[4]>0 || m_hp[5]>0 || m_hp[6]>0 || m_hp[7]>0));
    assign barrier_active[2] = (current_form < 3'd2) || (current_form == 3'd2 && (m_hp[8]>0 || m_hp[9]>0 || m_hp[10]>0 || m_hp[11]>0));
    assign barrier_active[3] = (current_form < 3'd3) || (current_form == 3'd3 && (m_hp[12]>0 || m_hp[13]>0 || m_hp[14]>0 || m_hp[15]>0));
    
    wire [9:0] target_x = item_x[current_form];
    wire [9:0] target_y = item_y[current_form];

    // Distance logic variables
    wire [9:0] dx_b = (px > boss_x) ? (px - boss_x) : (boss_x - px);
    wire [9:0] dy_b = (py > boss_y) ? (py - boss_y) : (boss_y - py);
    integer dx_m, dy_m, dmg_hit;
    
    // Damage scales with forms (Form 0=5, 1=10, 2=15, 3=20, 4=25)
    wire [7:0] p_dmg = 8'd5 + (current_form * 8'd5);

    reg [8:0] rand_x = 9'd0;
    reg [9:0] rand_y = 10'd0;
    reg [4:0] attack_timer = 0; 
    reg [7:0] boss_timer = 0;
    reg [7:0] minion_timer = 0;
    integer i;

    // --- Safe Random Logic ---
    // Make sure Item is between X: 50-450, Y: 50-700 so minions (+/-40) don't fall off map
    wire [9:0] rx0 = rand_x; 
    wire [9:0] ry0 = rand_y;
    wire [9:0] rx1 = {1'b0, ~rand_x[8:0]}; 
    wire [9:0] ry1 = {~rand_y[4:0], rand_y[9:5]};
    wire [9:0] rx2 = {1'b0, rand_x[4:0], rand_x[8:5]}; 
    wire [9:0] ry2 = ~rand_y;
    wire [9:0] rx3 = {1'b0, ~rand_x[8:5], rand_x[4:0]}; 
    wire [9:0] ry3 = {rand_y[4:0], ~rand_y[9:5]};

    wire [9:0] sx0 = (rx0 < 50) ? 10'd50 : ((rx0 > 450) ? 10'd450 : rx0);
    wire [9:0] sy0 = (ry0 < 50) ? 10'd50 : ((ry0 > 700) ? 10'd700 : ry0);
    wire [9:0] sx1 = (rx1 < 50) ? 10'd50 : ((rx1 > 450) ? 10'd450 : rx1);
    wire [9:0] sy1 = (ry1 < 50) ? 10'd50 : ((ry1 > 700) ? 10'd700 : ry1);
    wire [9:0] sx2 = (rx2 < 50) ? 10'd50 : ((rx2 > 450) ? 10'd450 : rx2);
    wire [9:0] sy2 = (ry2 < 50) ? 10'd50 : ((ry2 > 700) ? 10'd700 : ry2);
    wire [9:0] sx3 = (rx3 < 50) ? 10'd50 : ((rx3 > 450) ? 10'd450 : rx3);
    wire [9:0] sy3 = (ry3 < 50) ? 10'd50 : ((ry3 > 700) ? 10'd700 : ry3);

    always @(posedge clk) begin
        rand_x <= rand_x + 9'd73;
        rand_y <= rand_y + 10'd103;
    end

    // Movement collision with barrier
    wire [9:0] next_px_l = px - step_size;
    wire [9:0] next_px_r = px + step_size;
    wire [9:0] next_py_u = py - step_size;
    wire [9:0] next_py_d = py + step_size;
    
    wire hit_b_l = barrier_active && (next_px_l >= target_x - 36 && next_px_l <= target_x + 36 && py >= target_y - 36 && py <= target_y + 36);
    wire hit_b_r = barrier_active && (next_px_r >= target_x - 36 && next_px_r <= target_x + 36 && py >= target_y - 36 && py <= target_y + 36);
    wire hit_b_u = barrier_active && (px >= target_x - 36 && px <= target_x + 36 && next_py_u >= target_y - 36 && next_py_u <= target_y + 36);
    wire hit_b_d = barrier_active && (px >= target_x - 36 && px <= target_x + 36 && next_py_d >= target_y - 36 && next_py_d <= target_y + 36);

    always @(posedge clk) begin
        btn_s <= btn; b <= btn_s;
        
        if (rst) begin
            px <= 10'd210; py <= 10'd655; back <= 1'b0; mirror <= 1'b0; frames <= 3'd0;
            item_active <= 4'b1111; current_form <= 3'd0;
            
            // Assign clamped random positions to items
            item_x[0] <= sx0; item_y[0] <= sy0;
            item_x[1] <= sx1; item_y[1] <= sy1;
            item_x[2] <= sx2; item_y[2] <= sy2;
            item_x[3] <= sx3; item_y[3] <= sy3;
            
            // Spawn 16 Minions (4 per item: N, S, E, W outside the 36px box)
            m_x[0] <= sx0;      m_y[0] <= sy0 - 40;  // Item 0 North
            m_x[1] <= sx0;      m_y[1] <= sy0 + 40;  // Item 0 South
            m_x[2] <= sx0 + 40; m_y[2] <= sy0;       // Item 0 East
            m_x[3] <= sx0 - 40; m_y[3] <= sy0;       // Item 0 West
            
            m_x[4] <= sx1;      m_y[4] <= sy1 - 40;  // Item 1
            m_x[5] <= sx1;      m_y[5] <= sy1 + 40;
            m_x[6] <= sx1 + 40; m_y[6] <= sy1;
            m_x[7] <= sx1 - 40; m_y[7] <= sy1;
            
            m_x[8] <= sx2;      m_y[8] <= sy2 - 40;  // Item 2
            m_x[9] <= sx2;      m_y[9] <= sy2 + 40;
            m_x[10]<= sx2 + 40; m_y[10]<= sy2;
            m_x[11]<= sx2 - 40; m_y[11]<= sy2;
            
            m_x[12]<= sx3;      m_y[12]<= sy3 - 40;  // Item 3
            m_x[13]<= sx3;      m_y[13]<= sy3 + 40;
            m_x[14]<= sx3 + 40; m_y[14]<= sy3;
            m_x[15]<= sx3 - 40; m_y[15]<= sy3;
            
            for (i=0; i<16; i=i+1) m_hp[i] <= 6'd30;
            
            player_max_hp <= 8'd64; player_hp <= 8'd64;
            boss_hp <= 8'd128; boss_state <= 2'd0; boss_timer <= 8'd0;
            is_attacking <= 1'b0; attack_timer <= 5'd0;
            minion_state <= 2'd0; minion_timer <= 8'd0;
            
        end else if (tick) begin
            if (player_hp > 0) begin 
                if (left  && px > 16  && !hit_b_l) begin px <= px - step_size; mirror <= 1'b0; end
                if (right && px < 494 && !hit_b_r) begin px <= px + step_size; mirror <= 1'b1; end
                if (up    && py > 48  && !hit_b_u) begin py <= py - step_size; back   <= 1'b1; end
                if (down  && py < 766 && !hit_b_d) begin py <= py + step_size; back   <= 1'b0; end
                frames <= moving ? frames + 1'b1 : 3'd0;
            end
            
            cam_x <= (px < 160) ? 9'd0  : (px > 352) ? 9'd192  : px - 10'd160;
            cam_y <= (py < 120) ? 10'd0 : (py > 648) ? 10'd528 : py - 10'd120;

            // --- Player Attack ---
            if (is_attacking) begin 
                attack_timer <= attack_timer + 1'b1;
                
                if (attack_timer == 5'd1) begin
                    // Hit Boss
                    if (boss_state != 2'd3 && dx_b <= 10'd30 && dy_b <= 10'd30) begin
                        if (boss_hp > p_dmg) boss_hp <= boss_hp - p_dmg; else boss_hp <= 8'd0; 
                    end
                    // Hit all 16 Minions
                    for (i = 0; i < 16; i = i + 1) begin
                        if (m_hp[i] > 0) begin
                            dx_m = (px > m_x[i]) ? (px - m_x[i]) : (m_x[i] - px);
                            dy_m = (py > m_y[i]) ? (py - m_y[i]) : (m_y[i] - py);
                            if (dx_m <= 25 && dy_m <= 25) begin
                                if (m_hp[i] > p_dmg) m_hp[i] <= m_hp[i] - p_dmg; else m_hp[i] <= 0;
                            end
                        end
                    end
                end

                if (attack_timer >= 5'd15) begin 
                    is_attacking <= 1'b0; attack_timer <= 5'd0;
                end
            end else if (btn_attack && player_hp > 0) begin
                is_attacking <= 1'b1; attack_timer <= 5'd0;
            end

            // --- Boss FSM ---
            if (boss_hp == 0) boss_state <= 2'd3; 
            else begin
                case (boss_state)
                    2'd0: begin
                        boss_timer <= boss_timer + 1'b1;
                        if (boss_timer >= 8'd100) begin boss_state <= 2'd1; boss_timer <= 8'd0; end
                    end
                    2'd1: begin
                        boss_timer <= boss_timer + 1'b1;
                        if (boss_timer >= 8'd50) begin boss_state <= 2'd2; boss_timer <= 8'd0; end
                    end
                    2'd2: begin
                        boss_timer <= boss_timer + 1'b1;
                        if (boss_timer == 8'd1 && dx_b <= 10'd40 && dy_b <= 10'd40 && player_hp > 0) begin
                            if (player_hp > 8'd15) player_hp <= player_hp - 8'd15; else player_hp <= 8'd0;
                        end
                        if (boss_timer >= 8'd15) begin boss_state <= 2'd0; boss_timer <= 8'd0; end
                    end
                endcase
            end

            // --- Minion Global FSM (Shares Boss Attack States) ---
            case (minion_state)
                2'd0: begin
                    minion_timer <= minion_timer + 1'b1;
                    if (minion_timer >= 8'd120) begin minion_state <= 2'd1; minion_timer <= 8'd0; end
                end
                2'd1: begin
                    minion_timer <= minion_timer + 1'b1;
                    if (minion_timer >= 8'd60) begin minion_state <= 2'd2; minion_timer <= 8'd0; end
                end
                2'd2: begin
                    minion_timer <= minion_timer + 1'b1;
                    if (minion_timer == 8'd1 && player_hp > 0) begin
                        // Check if player took damage from ANY alive minion on the map
                        dmg_hit = 0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (m_hp[i] > 0) begin
                                dx_m = (px > m_x[i]) ? (px - m_x[i]) : (m_x[i] - px);
                                dy_m = (py > m_y[i]) ? (py - m_y[i]) : (m_y[i] - py);
                                if (dx_m <= 25 && dy_m <= 25) dmg_hit = 1;
                            end
                        end
                        if (dmg_hit) begin
                            if (player_hp > 8'd5) player_hp <= player_hp - 8'd5; else player_hp <= 8'd0;
                        end
                    end
                    if (minion_timer >= 8'd15) begin minion_state <= 2'd0; minion_timer <= 8'd0; end
                end
            endcase

            // --- Item Collection & Form Update ---
            if (current_form < 4 && !barrier_active) begin
                if (item_active[current_form] && 
                    (px + 16 > target_x) && (px - 16 < target_x) && 
                    (py + 16 > target_y) && (py - 16 < target_y)) begin
                    
                    item_active[current_form] <= 1'b0;          
                    current_form <= current_form + 1'b1; // Upgrade form
                    
                    player_max_hp <= player_max_hp + 8'd16; 
                    player_hp <= player_max_hp + 8'd16; // Restore fully + buff
                end
            end
        end
    end
endmodule