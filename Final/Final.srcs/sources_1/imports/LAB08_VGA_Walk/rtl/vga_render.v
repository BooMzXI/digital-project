`timescale 1ns / 1ps
module vga_render (
    input  wire        clk,
    input  wire [9:0]  x, y,
    input  wire        hsync, vsync, video_on,
    input  wire [9:0]  px, py,
    input  wire [8:0]  cam_x,
    input  wire [9:0]  cam_y,
    input  wire [4:0]  sprite_frame,
    input  wire        mirror,
    input  wire [3:0]  item_active,
    input  wire [2:0]  current_form,
    input  wire [39:0] flat_item_x, flat_item_y,
    input  wire [9:0]  boss_x, boss_y,
    input  wire [1:0]  boss_state,
    
    input  wire [16:0] boss_hp, 
    input  wire [8:0]  player_hp, player_max_hp,
    input  wire [159:0] flat_minion_x, flat_minion_y,
    input  wire [207:0] flat_minion_hp,
    
    input  wire [1:0]   minion_state,
    input  wire [3:0]   barrier_active,
    input  wire         boss_dying,
    input  wire [15:0]  flat_minion_dying,
    input  wire         game_won,
    
    output reg  [3:0]  VGA_R = 0, VGA_G = 0, VGA_B = 0,
    output reg         VGA_HS = 1, VGA_VS = 1
);
    wire [9:0] item_x [0:3], item_y [0:3], m_x [0:15], m_y [0:15];
    wire [12:0] m_hp [0:15]; wire m_dying [0:15];
    
    assign {item_x[3], item_x[2], item_x[1], item_x[0]} = flat_item_x;
    assign {item_y[3], item_y[2], item_y[1], item_y[0]} = flat_item_y;

    genvar g;
    generate
        for (g=0; g<16; g=g+1) begin : unpack_m
            assign m_x[g] = flat_minion_x[g*10 +: 10];
            assign m_y[g] = flat_minion_y[g*10 +: 10];
            assign m_hp[g] = flat_minion_hp[g*13 +: 13];
            assign m_dying[g] = flat_minion_dying[g];
        end
    endgenerate

    wire [8:0] gx = x[9:1], gy = y[9:1];
    wire [9:0] wx = cam_x + gx, wy = cam_y + gy;

    // Banked ROM สำหรับ Map ขนาด 800 x 512
    wire [18:0] map_addr = (wy * 19'd800) + wx;
    wire [6:0] map_index; wire [11:0] map_color;
    
    rom_map_800x512 #(.DW(7), .FILE("map.mem")) u_map (
        .clk(clk), 
        .addr(map_addr), 
        .q(map_index)
    );
    rom_lut #(.DW(12), .AW(7), .FILE("map_pal.mem")) u_map_pal (.clk(clk), .addr(map_index), .q(map_color));

    wire signed [11:0] sx = $signed({2'b0, wx}) - $signed({2'b0, px}) + 12'sd32;
    wire signed [11:0] sy = $signed({2'b0, wy}) - $signed({2'b0, py}) + 12'sd63;
    wire        on_sprite = sx >= 0 && sx < 64 && sy >= 0 && sy < 64;
    wire [5:0]  col = mirror ? 6'd63 - sx[5:0] : sx[5:0];
    wire [16:0] sprite_addr = sprite_frame * 17'd4096 + {sy[5:0], 6'd0} + {1'b0, col};

    reg on_item = 0; reg [1:0] active_item_id = 0; reg [5:0] item_col = 0; reg [5:0] item_row = 0;
    integer i;
    always @(*) begin
        on_item = 0; active_item_id = 0; item_col = 0; item_row = 0;
        for (i = 0; i < 4; i = i + 1) begin
            if (item_active[i] && (wx >= (item_x[i] - 32)) && (wx < (item_x[i] + 32)) && (wy >= (item_y[i] - 32)) && (wy < (item_y[i] + 32))) begin
                on_item = 1'b1; active_item_id = i[1:0]; item_col = wx - (item_x[i] - 32); item_row = wy - (item_y[i] - 32);
            end
        end
    end
    wire [4:0] item_frame = 5'd20 + {3'b000, active_item_id}; 
    wire [16:0] item_addr = item_frame * 17'd4096 + {item_row, 6'd0} + {1'b0, item_col};

    reg on_minion = 0; reg [5:0] mx_col = 0; reg [5:0] my_row = 0; reg minion_is_dying = 0;
    always @(*) begin
        on_minion = 0; mx_col = 0; my_row = 0; minion_is_dying = 0;
        for (i = 0; i < 16; i = i + 1) begin
            if ((m_hp[i] > 0 || m_dying[i]) && (wx >= (m_x[i] - 16)) && (wx < (m_x[i] + 16)) && (wy >= (m_y[i] - 31)) && (wy <= m_y[i])) begin
                on_minion = 1'b1; 
                mx_col = (wx - (m_x[i] - 16)) * 2; 
                my_row = (wy - (m_y[i] - 31)) * 2;
                minion_is_dying = m_dying[i];
            end
        end
    end
    wire [4:0] minion_frame = minion_is_dying ? 5'd26 : (5'd24 + {3'b000, minion_state});
    wire [16:0] minion_addr = minion_frame * 17'd4096 + {my_row, 6'd0} + {1'b0, mx_col};

    // เลื่อนรูปฉากชนะ (Frame 27) ลงมาหน่อยจาก y=176 เป็น y=196 (128x128 px)
    wire signed [11:0] end_sx = $signed({2'b0, x}) - 12'sd256; 
    wire signed [11:0] end_sy = $signed({2'b0, y}) - 12'sd196; 
    wire on_end_sprite = game_won && (end_sx >= 0 && end_sx < 128 && end_sy >= 0 && end_sy < 128);
    wire [5:0] esx = end_sx[6:1], esy = end_sy[6:1];

    wire signed [11:0] bsx_1_5x = $signed({2'b0, wx}) - $signed({2'b0, boss_x}) + 12'sd48; 
    wire signed [11:0] bsy_1_5x = $signed({2'b0, wy}) - $signed({2'b0, boss_y}) + 12'sd95; 
    wire on_boss = (boss_hp > 0 || boss_dying) && (bsx_1_5x >= 0 && bsx_1_5x < 96 && bsy_1_5x >= 0 && bsy_1_5x < 96);
    wire on_boss_eval = game_won ? on_end_sprite : on_boss;
    
    wire [15:0] bsx_mul = bsx_1_5x[6:0] * 16'd171;
    wire [15:0] bsy_mul = bsy_1_5x[6:0] * 16'd171;
    wire [5:0] bsx = bsx_mul >> 8; 
    wire [5:0] bsy = bsy_mul >> 8; 
    
    wire [4:0] boss_frame = boss_dying ? 5'd26 : (5'd24 + {3'b000, boss_state});
    wire [16:0] boss_addr = game_won ? (5'd27 * 17'd4096 + {esy, 6'd0} + {1'b0, esx}) : (boss_frame * 17'd4096 + {bsy, 6'd0} + {1'b0, bsx});

    wire [16:0] addr_a = sprite_addr;
    wire [7:0]  q_a;
    
    wire [16:0] addr_b = on_boss_eval ? boss_addr   :
                         on_minion    ? minion_addr :
                         on_item      ? item_addr   : 17'd0;
    wire [7:0]  q_b;
    
    rom_2p #(.DW(8), .AW(17), .DEPTH(114688), .FILE("sprite.mem")) u_master_sprite (
        .clk(clk),
        .addr_a(addr_a), .q_a(q_a),
        .addr_b(addr_b), .q_b(q_b)
    );

    wire [11:0] color_a, color_b;
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_pal_a (.clk(clk), .addr(q_a), .q(color_a));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_pal_b (.clk(clk), .addr(q_b), .q(color_b));

    reg on_barrier_comb;
    always @(*) begin
        on_barrier_comb = 1'b0;
        for (i = 0; i < 4; i = i + 1) begin
            if (barrier_active[i]) begin
                if ((wx >= item_x[i] - 45 && wx <= item_x[i] + 45 && (wy == item_y[i] - 45 || wy == item_y[i] + 45 || wy == item_y[i] - 44 || wy == item_y[i] + 44)) ||
                    (wy >= item_y[i] - 45 && wy <= item_y[i] + 45 && (wx == item_x[i] - 45 || wx == item_x[i] + 45 || wx == item_x[i] - 44 || wx == item_x[i] + 44))) begin
                    on_barrier_comb = 1'b1;
                end
            end
        end
    end
    wire on_barrier = on_barrier_comb;

    wire [7:0] max_w = player_max_hp[8:1]; 
    wire [7:0] php_w = player_hp[8:1]; 
    wire [9:0] half_max_w = {2'b0, max_w[7:1]};
    wire [9:0] php_start = (px > half_max_w) ? (px - half_max_w) : 10'd0; 
    
    wire on_php_bg = (wx >= php_start && wx < (php_start + max_w)) && (wy >= py - 72 && wy <= py - 70);
    wire on_php_fg = on_php_bg && (wx < (php_start + php_w));
    
    wire on_bhp_bg = (wx >= boss_x - 48 && wx <= boss_x + 48) && (wy >= boss_y - 110 && wy <= boss_y - 107); 
    wire [6:0] bhp_w = boss_hp[16:10]; 
    wire on_bhp_fg = on_bhp_bg && (wx < (boss_x - 48 + bhp_w));
    
    reg on_mhp_bg_c = 0; reg on_mhp_fg_c = 0;
    reg [4:0] cur_mhp_w;
    always @(*) begin
        on_mhp_bg_c = 0; on_mhp_fg_c = 0;
        for (i = 0; i < 16; i = i + 1) begin
            if (m_hp[i] > 0) begin
                if (wx >= m_x[i] - 15 && wx < m_x[i] + 15 && wy >= m_y[i] - 40 && wy <= m_y[i] - 38) begin
                    on_mhp_bg_c = 1'b1;
                    if (i < 4) cur_mhp_w = m_hp[i] * 6;                     
                    else if (i < 8) cur_mhp_w = (m_hp[i] * 77) >> 7;        
                    else if (i < 12) cur_mhp_w = (m_hp[i] * 31) >> 9;       
                    else cur_mhp_w = (m_hp[i] * 25) >> 12;                  
                    if (wx < m_x[i] - 15 + cur_mhp_w) on_mhp_fg_c = 1'b1;
                end
            end
        end
    end
    wire on_mhp_bg = on_mhp_bg_c;
    wire on_mhp_fg = on_mhp_fg_c;

    wire on_boss_warn = (boss_state == 2'd1) && (boss_hp > 0) && (
        (wx >= boss_x - 55 && wx <= boss_x + 55 && (wy == boss_y - 100 || wy == boss_y + 10 || wy == boss_y - 99 || wy == boss_y + 9)) ||
        (wy >= boss_y - 100 && wy <= boss_y + 10 && (wx == boss_x - 55 || wx == boss_x + 55 || wx == boss_x - 54 || wx == boss_x + 54))
    );
    
    reg on_minion_warn = 0;
    always @(*) begin
        on_minion_warn = 0;
        if (minion_state == 2'd1) begin
            for (i = 0; i < 16; i = i + 1) begin
                if (m_hp[i] > 0) begin
                    if ((wx >= m_x[i] - 20 && wx <= m_x[i] + 20 && (wy == m_y[i] - 35 || wy == m_y[i] + 5 || wy == m_y[i] - 34 || wy == m_y[i] + 4)) ||
                        (wy >= m_y[i] - 35 && wy <= m_y[i] + 5 && (wx == m_x[i] - 20 || wx == m_x[i] + 20 || wx == m_x[i] - 19 || wx == m_x[i] + 19))) begin
                        on_minion_warn = 1'b1;
                    end
                end
            end
        end
    end

    // =========================================================================
    // ระบบแสดงข้อความพิกเซลสำหรับฉากจบ (YOU RECIVE / YOU DIE / PRESS RESET TO RESTART)
    // =========================================================================
    // 1) "YOU RECIVE" (10 ตัวอักษร, ขนาดตัวละ 32x32 px -> กว้าง 320 px, กึ่งกลางจอ x=160..479, y=110..141)
    wire in_win_box = (x >= 10'd160 && x < 10'd480) && (y >= 10'd110 && y < 10'd142);
    wire [9:0] win_dx = x - 10'd160;
    wire [9:0] win_dy = y - 10'd110;
    reg [7:0] win_char;
    always @(*) begin
        case (win_dx[8:5])
            4'd0: win_char = "Y";
            4'd1: win_char = "O";
            4'd2: win_char = "U";
            4'd3: win_char = " ";
            4'd4: win_char = "R";
            4'd5: win_char = "E";
            4'd6: win_char = "C";
            4'd7: win_char = "I";
            4'd8: win_char = "V";
            4'd9: win_char = "E";
            default: win_char = " ";
        endcase
    end
    wire win_px;
    font_8x8 u_font_win (.char_code(win_char), .row(win_dy[4:2]), .col(win_dx[4:2]), .pixel_on(win_px));
    wire on_win_text = in_win_box && win_px;

    // 2) "YOU DIE" (7 ตัวอักษร, ขนาดตัวละ 64x64 px -> กว้าง 448 px, กึ่งกลางจอ x=96..543, y=180..243)
    wire in_die_box = (x >= 10'd96 && x < 10'd544) && (y >= 10'd180 && y < 10'd244);
    wire [9:0] die_dx = x - 10'd96;
    wire [9:0] die_dy = y - 10'd180;
    reg [7:0] die_char;
    always @(*) begin
        case (die_dx[8:6])
            3'd0: die_char = "Y";
            3'd1: die_char = "O";
            3'd2: die_char = "U";
            3'd3: die_char = " ";
            3'd4: die_char = "D";
            3'd5: die_char = "I";
            3'd6: die_char = "E";
            default: die_char = " ";
        endcase
    end
    wire die_px;
    font_8x8 u_font_die (.char_code(die_char), .row(die_dy[5:3]), .col(die_dx[5:3]), .pixel_on(die_px));
    wire on_die_text = in_die_box && die_px;

    // 3) "PRESS RESET TO RESTART" (22 ตัวอักษร, ขนาดตัวละ 24x24 px -> กว้าง 528 px, กึ่งกลางจอ x=56..583, y=376..399)
    wire in_rst_box = (x >= 10'd56 && x < 10'd584) && (y >= 10'd376 && y < 10'd400);
    wire [9:0] rst_dx = x - 10'd56;
    wire [9:0] rst_dy = y - 10'd376;
    wire [20:0] rst_dx_mul = rst_dx * 12'd683;
    wire [7:0]  rst_dx_d3  = rst_dx_mul[18:11]; // หาร 3 แบบแม่นยำ (0..175)
    wire [12:0] rst_dy_mul = rst_dy * 8'd86;
    wire [2:0]  rst_row    = rst_dy_mul[10:8];  // หาร 3 แบบแม่นยำ (0..7)
    reg [7:0] rst_char;
    always @(*) begin
        case (rst_dx_d3[7:3])
            5'd0:  rst_char = "P";
            5'd1:  rst_char = "R";
            5'd2:  rst_char = "E";
            5'd3:  rst_char = "S";
            5'd4:  rst_char = "S";
            5'd5:  rst_char = " ";
            5'd6:  rst_char = "R";
            5'd7:  rst_char = "E";
            5'd8:  rst_char = "S";
            5'd9:  rst_char = "E";
            5'd10: rst_char = "T";
            5'd11: rst_char = " ";
            5'd12: rst_char = "T";
            5'd13: rst_char = "O";
            5'd14: rst_char = " ";
            5'd15: rst_char = "R";
            5'd16: rst_char = "E";
            5'd17: rst_char = "S";
            5'd18: rst_char = "T";
            5'd19: rst_char = "A";
            5'd20: rst_char = "R";
            5'd21: rst_char = "T";
            default: rst_char = " ";
        endcase
    end
    wire rst_px;
    font_8x8 u_font_rst (.char_code(rst_char), .row(rst_row), .col(rst_dx_d3[2:0]), .pixel_on(rst_px));
    wire on_restart_text = in_rst_box && rst_px;
    
    // =========================================================================
    // Pipeline 2 จังหวะ ให้ตรงกับ Latency ของ ROM
    // =========================================================================
    reg on_player_1=0, on_boss_1=0, on_minion_1=0, on_item_1=0;
    reg see_player_2=0, see_boss_2=0, see_minion_2=0, see_item_2=0;
    reg on_bar_1=0, on_bar_2=0, on_warn_1=0, on_warn_2=0;
    reg on_php_bg_1=0, on_php_fg_1=0, on_bhp_bg_1=0, on_bhp_fg_1=0;
    reg on_mhp_bg_1=0, on_mhp_fg_1=0, on_mhp_bg_2=0, on_mhp_fg_2=0; 
    reg on_php_bg_2=0, on_php_fg_2=0, on_bhp_bg_2=0, on_bhp_fg_2=0;
    reg boss_dying_1=0, boss_dying_2=0, minion_dying_1=0, minion_dying_2=0;
    reg game_won_1=0, game_won_2=0;
    reg is_dead_1=0, is_dead_2=0;
    reg on_win_text_1=0, on_win_text_2=0;
    reg on_die_text_1=0, on_die_text_2=0;
    reg on_rst_text_1=0, on_rst_text_2=0;
    reg vid_1=0, vid_2=0, hs_1=1, hs_2=1, vs_1=1, vs_2=1;

    always @(posedge clk) begin
        on_player_1   <= game_won ? 0 : on_sprite; 
        on_boss_1     <= on_boss_eval; 
        on_minion_1   <= on_minion;
        on_item_1     <= on_item;
        on_bar_1      <= on_barrier; on_warn_1 <= on_boss_warn | on_minion_warn;
        on_php_bg_1   <= on_php_bg; on_php_fg_1 <= on_php_fg; on_bhp_bg_1 <= on_bhp_bg; on_bhp_fg_1 <= on_bhp_fg;
        on_mhp_bg_1   <= on_mhp_bg; on_mhp_fg_1 <= on_mhp_fg;
        boss_dying_1  <= boss_dying; minion_dying_1 <= minion_is_dying; 
        game_won_1    <= game_won;
        is_dead_1     <= (player_hp == 9'd0) && !game_won;
        on_win_text_1 <= on_win_text;
        on_die_text_1 <= on_die_text;
        on_rst_text_1 <= on_restart_text;
        vid_1 <= video_on; hs_1 <= hsync; vs_1 <= vsync;
        
        see_player_2  <= on_player_1 && (q_a != 8'd0);
        see_boss_2    <= on_boss_1   && (q_b != 8'd0);
        see_minion_2  <= !on_boss_1 && on_minion_1 && (q_b != 8'd0);
        see_item_2    <= !on_boss_1 && !on_minion_1 && on_item_1 && (q_b != 8'd0);
        
        on_bar_2      <= on_bar_1; on_warn_2 <= on_warn_1;
        on_php_bg_2   <= on_php_bg_1; on_php_fg_2 <= on_php_fg_1;
        on_bhp_bg_2   <= on_bhp_bg_1; on_bhp_fg_2 <= on_bhp_fg_1;
        on_mhp_bg_2   <= on_mhp_bg_1; on_mhp_fg_2 <= on_mhp_fg_1;
        boss_dying_2  <= boss_dying_1; minion_dying_2 <= minion_dying_1; 
        game_won_2    <= game_won_1;
        is_dead_2     <= is_dead_1;
        on_win_text_2 <= on_win_text_1;
        on_die_text_2 <= on_die_text_1;
        on_rst_text_2 <= on_rst_text_1;
        vid_2 <= vid_1; hs_2 <= hs_1; vs_2 <= vs_1;
        
        {VGA_R, VGA_G, VGA_B} <= !vid_2 ? 12'h000 : 
                                 game_won_2   ? (on_win_text_2 ? 12'h0F0 : 
                                                 on_rst_text_2 ? 12'hFFF : 
                                                 see_boss_2    ? color_b : 12'h000) : 
                                 is_dead_2    ? (on_die_text_2 ? 12'hF00 : 
                                                 on_rst_text_2 ? 12'hFFF : 12'h000) : 
                                 on_php_fg_2  ? 12'h0F0 : on_php_bg_2 ? 12'h800 :
                                 on_bhp_fg_2  ? 12'h0F0 : on_bhp_bg_2 ? 12'h800 : 
                                 on_mhp_fg_2  ? 12'h0F0 : on_mhp_bg_2 ? 12'h800 :
                                 on_bar_2     ? 12'hF00 : 
                                 on_warn_2    ? 12'hF00 : 
                                 see_player_2 ? color_a : 
                                 see_boss_2   ? (boss_dying_2 ? {4'hF, color_b[7:0]} : color_b) : 
                                 see_minion_2 ? (minion_dying_2 ? {4'hF, color_b[7:0]} : color_b) :
                                 see_item_2   ? color_b : 
                                 map_color;
        VGA_HS <= hs_2; VGA_VS <= vs_2;
    end
endmodule

// ============================================================================
// ตารางฟอนต์ 8x8 แบบ Combinational (ไม่ใช้ BRAM)
// ============================================================================
module font_8x8 (
    input  wire [7:0] char_code,
    input  wire [2:0] row,
    input  wire [2:0] col,
    output wire       pixel_on
);
    reg [7:0] row_bits;
    always @(*) begin
        case (char_code)
            "A": case (row)
                3'd0: row_bits = 8'b00111000;
                3'd1: row_bits = 8'b01000100;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b10000010;
                3'd4: row_bits = 8'b11111110;
                3'd5: row_bits = 8'b10000010;
                3'd6: row_bits = 8'b10000010;
                default: row_bits = 8'b00000000;
            endcase
            "C": case (row)
                3'd0: row_bits = 8'b01111100;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000000;
                3'd3: row_bits = 8'b10000000;
                3'd4: row_bits = 8'b10000000;
                3'd5: row_bits = 8'b10000010;
                3'd6: row_bits = 8'b01111100;
                default: row_bits = 8'b00000000;
            endcase
            "D": case (row)
                3'd0: row_bits = 8'b11111000;
                3'd1: row_bits = 8'b10000100;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b10000010;
                3'd4: row_bits = 8'b10000010;
                3'd5: row_bits = 8'b10000100;
                3'd6: row_bits = 8'b11111000;
                default: row_bits = 8'b00000000;
            endcase
            "E": case (row)
                3'd0: row_bits = 8'b11111110;
                3'd1: row_bits = 8'b10000000;
                3'd2: row_bits = 8'b10000000;
                3'd3: row_bits = 8'b11111100;
                3'd4: row_bits = 8'b10000000;
                3'd5: row_bits = 8'b10000000;
                3'd6: row_bits = 8'b11111110;
                default: row_bits = 8'b00000000;
            endcase
            "I": case (row)
                3'd0: row_bits = 8'b01111100;
                3'd1: row_bits = 8'b00010000;
                3'd2: row_bits = 8'b00010000;
                3'd3: row_bits = 8'b00010000;
                3'd4: row_bits = 8'b00010000;
                3'd5: row_bits = 8'b00010000;
                3'd6: row_bits = 8'b01111100;
                default: row_bits = 8'b00000000;
            endcase
            "O": case (row)
                3'd0: row_bits = 8'b01111100;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b10000010;
                3'd4: row_bits = 8'b10000010;
                3'd5: row_bits = 8'b10000010;
                3'd6: row_bits = 8'b01111100;
                default: row_bits = 8'b00000000;
            endcase
            "P": case (row)
                3'd0: row_bits = 8'b11111100;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b11111100;
                3'd4: row_bits = 8'b10000000;
                3'd5: row_bits = 8'b10000000;
                3'd6: row_bits = 8'b10000000;
                default: row_bits = 8'b00000000;
            endcase
            "R": case (row)
                3'd0: row_bits = 8'b11111100;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b11111100;
                3'd4: row_bits = 8'b10001000;
                3'd5: row_bits = 8'b10000100;
                3'd6: row_bits = 8'b10000010;
                default: row_bits = 8'b00000000;
            endcase
            "S": case (row)
                3'd0: row_bits = 8'b01111100;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000000;
                3'd3: row_bits = 8'b01111100;
                3'd4: row_bits = 8'b00000010;
                3'd5: row_bits = 8'b10000010;
                3'd6: row_bits = 8'b01111100;
                default: row_bits = 8'b00000000;
            endcase
            "T": case (row)
                3'd0: row_bits = 8'b11111110;
                3'd1: row_bits = 8'b00010000;
                3'd2: row_bits = 8'b00010000;
                3'd3: row_bits = 8'b00010000;
                3'd4: row_bits = 8'b00010000;
                3'd5: row_bits = 8'b00010000;
                3'd6: row_bits = 8'b00010000;
                default: row_bits = 8'b00000000;
            endcase
            "U": case (row)
                3'd0: row_bits = 8'b10000010;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b10000010;
                3'd4: row_bits = 8'b10000010;
                3'd5: row_bits = 8'b10000010;
                3'd6: row_bits = 8'b01111100;
                default: row_bits = 8'b00000000;
            endcase
            "V": case (row)
                3'd0: row_bits = 8'b10000010;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b10000010;
                3'd4: row_bits = 8'b01000100;
                3'd5: row_bits = 8'b00101000;
                3'd6: row_bits = 8'b00010000;
                default: row_bits = 8'b00000000;
            endcase
            "Y": case (row)
                3'd0: row_bits = 8'b10000010;
                3'd1: row_bits = 8'b01000100;
                3'd2: row_bits = 8'b00101000;
                3'd3: row_bits = 8'b00010000;
                3'd4: row_bits = 8'b00010000;
                3'd5: row_bits = 8'b00010000;
                3'd6: row_bits = 8'b00010000;
                default: row_bits = 8'b00000000;
            endcase
            default: row_bits = 8'b00000000;
        endcase
    end
    assign pixel_on = row_bits[3'd7 - col];
endmodule