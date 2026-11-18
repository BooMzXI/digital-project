`timescale 1ns / 1ps
module player (
    input  wire       clk, rst, tick,              
    input  wire [3:0] btn,               
    input  wire       btn_attack, sw0,               
    // [อัปเดต] ย้ายจุดเกิดผู้เล่นไปตรงกลางล่างของแมพ 800x512
    output reg  [9:0] px = 10'd400, py = 10'd450, 
    output reg  [8:0] cam_x = 0,
    output reg  [9:0] cam_y = 0,
    output reg        back = 0, mirror = 0,        
    output wire       moving, adv,                
    
    output reg  [3:0] item_active, 
    output reg  [2:0] current_form, 
    output wire [39:0] flat_item_x, flat_item_y,
    
    output reg        is_attacking = 0,
    output reg  [8:0] player_hp = 9'd100, player_max_hp = 9'd100, 
    // [อัปเดต] ย้ายบอสไปตรงกลางของแมพ
    output reg  [9:0] boss_x = 10'd400, boss_y = 10'd256, 
    output reg  [1:0] boss_state = 0,   
    output reg  [16:0] boss_hp = 17'd100000, 
    
    output wire [159:0] flat_minion_x, flat_minion_y,
    output wire [207:0] flat_minion_hp,      
    output reg  [1:0]   minion_state = 0,
    output wire [3:0]   barrier_active,
    
    output wire         boss_dying,
    output wire [15:0]  flat_minion_dying,
    output reg          game_won = 0
);
    wire [2:0] step_size = sw0 ? 3'd5 : 3'd2;
    reg [3:0] btn_s = 0, b = 0;          
    reg [2:0] frames = 0;                

    wire up = b[3], down = b[2], left = b[1], right = b[0];
    assign moving = up | down | left | right;
    assign adv    = tick && (!moving || frames == 3'd7);

    reg [9:0]  item_x [0:3], item_y [0:3], m_x [0:15], m_y [0:15];
    reg [12:0] m_hp [0:15]; 
    
    reg [5:0] m_dt [0:15];
    reg [5:0] boss_dt = 0;
    
    assign flat_item_x = {item_x[3], item_x[2], item_x[1], item_x[0]}; 
    assign flat_item_y = {item_y[3], item_y[2], item_y[1], item_y[0]};
    assign boss_dying = (boss_dt > 0);
    
    genvar g;
    generate
        for (g=0; g<16; g=g+1) begin : pack_m
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
    
    wire [9:0] target_x = item_x[current_form];
    wire [9:0] target_y = item_y[current_form];
    wire [9:0] dx_b = (px > boss_x) ? (px - boss_x) : (boss_x - px);
    wire [9:0] dy_b = (py > boss_y) ? (py - boss_y) : (boss_y - py);
    integer dx_m, dy_m, dmg_hit, i;
    
    wire [13:0] p_dmg = (current_form == 3'd0) ? 14'd1 :
                        (current_form == 3'd1) ? 14'd10 :
                        (current_form == 3'd2) ? 14'd100 :
                        (current_form == 3'd3) ? 14'd1000 : 14'd10000;

    reg [4:0] attack_timer = 0; reg [7:0] boss_timer = 0, minion_timer = 0;

    reg [1:0] rand_shift = 0;
    always @(posedge clk) rand_shift <= rand_shift + 1'b1;

    // [อัปเดต] จัดระเบียบการสุ่ม 4 มุมให้ปลอดภัย (X:150,650) และ (Y:120,392) เพื่อไม่ให้ลูกน้องกระเด็นติดขอบจอ
    wire [9:0] ix0 = (rand_shift==0)?10'd150 : (rand_shift==1)?10'd650 : (rand_shift==2)?10'd650 : 10'd150;
    wire [9:0] iy0 = (rand_shift==0)?10'd120 : (rand_shift==1)?10'd120 : (rand_shift==2)?10'd392 : 10'd392;

    wire [9:0] ix1 = (rand_shift==0)?10'd650 : (rand_shift==1)?10'd650 : (rand_shift==2)?10'd150 : 10'd150;
    wire [9:0] iy1 = (rand_shift==0)?10'd120 : (rand_shift==1)?10'd392 : (rand_shift==2)?10'd392 : 10'd120;

    wire [9:0] ix2 = (rand_shift==0)?10'd650 : (rand_shift==1)?10'd150 : (rand_shift==2)?10'd150 : 10'd650;
    wire [9:0] iy2 = (rand_shift==0)?10'd392 : (rand_shift==1)?10'd392 : (rand_shift==2)?10'd120 : 10'd120;

    wire [9:0] ix3 = (rand_shift==0)?10'd150 : (rand_shift==1)?10'd150 : (rand_shift==2)?10'd650 : 10'd650;
    wire [9:0] iy3 = (rand_shift==0)?10'd392 : (rand_shift==1)?10'd120 : (rand_shift==2)?10'd120 : 10'd392;

    wire [9:0] nx_l = px - step_size, nx_r = px + step_size, ny_u = py - step_size, ny_d = py + step_size;
    reg hit_l, hit_r, hit_u, hit_d;
    integer c_i;
    always @(*) begin
        hit_l = 0; hit_r = 0; hit_u = 0; hit_d = 0;
        for (c_i = 0; c_i < 4; c_i = c_i + 1) begin
            if (barrier_active[c_i]) begin
                if (nx_l >= item_x[c_i] - 60 && nx_l <= item_x[c_i] + 60 && py >= item_y[c_i] - 60 && py <= item_y[c_i] + 60) hit_l = 1;
                if (nx_r >= item_x[c_i] - 60 && nx_r <= item_x[c_i] + 60 && py >= item_y[c_i] - 60 && py <= item_y[c_i] + 60) hit_r = 1;
                if (px >= item_x[c_i] - 60 && px <= item_x[c_i] + 60 && ny_u >= item_y[c_i] - 60 && ny_u <= item_y[c_i] + 60) hit_u = 1;
                if (px >= item_x[c_i] - 60 && px <= item_x[c_i] + 60 && ny_d >= item_y[c_i] - 60 && ny_d <= item_y[c_i] + 60) hit_d = 1;
            end
        end
    end
    wire hit_b_l = hit_l;
    wire hit_b_r = hit_r;
    wire hit_b_u = hit_u;
    wire hit_b_d = hit_d;

    always @(posedge clk) begin
        btn_s <= btn; b <= btn_s;
        if (rst) begin
            px <= 10'd400; py <= 10'd450; 
            back <= 1'b0; mirror <= 1'b0; frames <= 3'd0;
            item_active <= 4'b1111; current_form <= 3'd0;
            
            item_x[0] <= ix0; item_y[0] <= iy0;
            item_x[1] <= ix1; item_y[1] <= iy1;
            item_x[2] <= ix2; item_y[2] <= iy2;
            item_x[3] <= ix3; item_y[3] <= iy3;
            
            for (i=0; i<16; i=i+1) begin 
                if (i < 4) m_hp[i] <= 13'd5;        
                else if (i < 8) m_hp[i] <= 13'd50;  
                else if (i < 12) m_hp[i] <= 13'd500; 
                else m_hp[i] <= 13'd5000;           
                m_dt[i] <= 0; 
            end
            
            m_x[0] <= ix0;      m_y[0] <= iy0 - 75; 
            m_x[1] <= ix0 + 75; m_y[1] <= iy0;
            m_x[2] <= ix0;      m_y[2] <= iy0 + 75;
            m_x[3] <= ix0 - 75; m_y[3] <= iy0;
            
            m_x[4] <= ix1;      m_y[4] <= iy1 - 75; 
            m_x[5] <= ix1 + 75; m_y[5] <= iy1;
            m_x[6] <= ix1;      m_y[6] <= iy1 + 75;
            m_x[7] <= ix1 - 75; m_y[7] <= iy1;
            
            m_x[8] <= ix2;      m_y[8] <= iy2 - 75; 
            m_x[9] <= ix2 + 75; m_y[9] <= iy2;
            m_x[10]<= ix2;      m_y[10]<= iy2 + 75;
            m_x[11]<= ix2 - 75; m_y[11]<= iy2;
            
            m_x[12]<= ix3;      m_y[12]<= iy3 - 75; 
            m_x[13]<= ix3 + 75; m_y[13]<= iy3;
            m_x[14]<= ix3;      m_y[14]<= iy3 + 75;
            m_x[15]<= ix3 - 75; m_y[15]<= iy3;

            player_max_hp <= 9'd100; player_hp <= 9'd100; game_won <= 1'b0;
            boss_hp <= 17'd100000; boss_state <= 2'd0; boss_timer <= 8'd0; boss_dt <= 0;
            is_attacking <= 1'b0; attack_timer <= 5'd0;
            minion_state <= 2'd0; minion_timer <= 8'd0;
            
        end else if (tick) begin
            
            if (boss_dt > 0) begin
                boss_dt <= boss_dt - 1;
                if (boss_dt == 1) game_won <= 1'b1; 
            end
            for (i=0; i<16; i=i+1) if (m_dt[i] > 0) m_dt[i] <= m_dt[i] - 1;

            if (!game_won) begin
                if (player_hp > 0) begin 
                    // [อัปเดต] ขอบเขตการเดินสำหรับแมพขนาด 800 x 512
                    if (left  && px > 32  && !hit_b_l) begin px <= px - step_size; mirror <= 1'b0; end
                    if (right && px < 768 && !hit_b_r) begin px <= px + step_size; mirror <= 1'b1; end // ขวาสุด 800
                    if (up    && py > 64  && !hit_b_u) begin py <= py - step_size; back   <= 1'b1; end
                    if (down  && py < 480 && !hit_b_d) begin py <= py + step_size; back   <= 1'b0; end // ล่างสุด 512
                    frames <= moving ? frames + 1'b1 : 3'd0;
                end
                
                // [อัปเดต] ขอบเขตกล้องสำหรับแมพขนาด 800 x 512 (กล้องกว้าง 320, สูง 240)
                cam_x <= (px < 160) ? 9'd0  : (px > 640) ? 9'd480  : px - 10'd160; 
                cam_y <= (py < 120) ? 10'd0 : (py > 392) ? 10'd272 : py - 10'd120;

                if (is_attacking) begin 
                    attack_timer <= attack_timer + 1'b1;
                    if (attack_timer == 5'd1) begin
                        if (boss_hp > 0 && dx_b <= 10'd60 && dy_b <= 10'd60) begin 
                            if (boss_hp > p_dmg) boss_hp <= boss_hp - p_dmg; 
                            else begin boss_hp <= 0; boss_dt <= 6'd60; end 
                        end
                        for (i = 0; i < 16; i = i + 1) begin
                            if (m_hp[i] > 0) begin
                                dx_m = (px > m_x[i]) ? (px - m_x[i]) : (m_x[i] - px);
                                dy_m = (py > m_y[i]) ? (py - m_y[i]) : (m_y[i] - py);
                                if (dx_m <= 48 && dy_m <= 48) begin
                                    if (m_hp[i] > p_dmg) m_hp[i] <= m_hp[i] - p_dmg; 
                                    else begin m_hp[i] <= 0; m_dt[i] <= 6'd60; end 
                                end
                            end
                        end
                    end
                    if (attack_timer >= 5'd5) begin is_attacking <= 1'b0; attack_timer <= 5'd0; end
                end else if (btn_attack && player_hp > 0) begin
                    is_attacking <= 1'b1; attack_timer <= 5'd0;
                end

                if (boss_hp > 0) begin
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
                            if (boss_timer == 8'd1 && dx_b <= 10'd60 && dy_b <= 10'd60 && player_hp > 0) begin
                                if (player_hp > 9'd50) player_hp <= player_hp - 9'd50; else player_hp <= 9'd0;
                            end
                            if (boss_timer >= 8'd15) begin boss_state <= 2'd0; boss_timer <= 8'd0; end
                        end
                    endcase
                end

                case (minion_state)
                    2'd0: begin
                        minion_timer <= minion_timer + 1'b1;
                        if (minion_timer >= 8'd100) begin minion_state <= 2'd1; minion_timer <= 8'd0; end
                    end
                    2'd1: begin
                        minion_timer <= minion_timer + 1'b1;
                        if (minion_timer >= 8'd50) begin minion_state <= 2'd2; minion_timer <= 8'd0; end
                    end
                    2'd2: begin
                        minion_timer <= minion_timer + 1'b1;
                        if (minion_timer == 8'd1 && player_hp > 0) begin
                            dmg_hit = 0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (m_hp[i] > 0) begin
                                    dx_m = (px > m_x[i]) ? (px - m_x[i]) : (m_x[i] - px);
                                    dy_m = (py > m_y[i]) ? (py - m_y[i]) : (m_y[i] - py);
                                    if (dx_m <= 40 && dy_m <= 40) dmg_hit = 1;
                                end
                            end
                            if (dmg_hit) begin if (player_hp > 9'd20) player_hp <= player_hp - 9'd20; else player_hp <= 9'd0; end
                        end
                        if (minion_timer >= 8'd15) begin minion_state <= 2'd0; minion_timer <= 8'd0; end
                    end
                endcase

                if (current_form < 4 && !barrier_active[current_form]) begin
                    if (item_active[current_form] && 
                        (px + 25 > target_x) && (px - 25 < target_x) && 
                        (py + 25 > target_y) && (py - 25 < target_y)) begin
                        item_active[current_form] <= 1'b0;          
                        current_form <= current_form + 1'b1; 
                        
                        if (current_form == 0) begin player_max_hp <= 9'd150; player_hp <= 9'd150; end
                        else if (current_form == 1) begin player_max_hp <= 9'd200; player_hp <= 9'd200; end
                        else if (current_form == 2) begin player_max_hp <= 9'd250; player_hp <= 9'd250; end
                        else if (current_form == 3) begin player_max_hp <= 9'd300; player_hp <= 9'd300; end
                    end
                end
            end
        end
    end
endmodule