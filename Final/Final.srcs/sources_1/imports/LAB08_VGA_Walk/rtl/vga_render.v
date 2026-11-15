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
    input  wire [7:0]  boss_hp, player_hp, player_max_hp,
    input  wire [159:0] flat_minion_x, flat_minion_y,
    input  wire [95:0]  flat_minion_hp,
    input  wire [1:0]   minion_state,
    input  wire         barrier_active,
    
    input  wire         boss_dying,
    input  wire [15:0]  flat_minion_dying,
    input  wire         game_won,
    
    output reg  [3:0]  VGA_R = 0, VGA_G = 0, VGA_B = 0,
    output reg         VGA_HS = 1, VGA_VS = 1
);
    wire [9:0] item_x [0:3], item_y [0:3], m_x [0:15], m_y [0:15];
    wire [5:0] m_hp [0:15]; wire m_dying [0:15];
    
    assign {item_x[3], item_x[2], item_x[1], item_x[0]} = flat_item_x;
    assign {item_y[3], item_y[2], item_y[1], item_y[0]} = flat_item_y;

    genvar g;
    generate
        for (g=0; g<16; g=g+1) begin : unpack_m
            assign m_x[g] = flat_minion_x[g*10 +: 10];
            assign m_y[g] = flat_minion_y[g*10 +: 10];
            assign m_hp[g] = flat_minion_hp[g*6 +: 6];
            assign m_dying[g] = flat_minion_dying[g];
        end
    endgenerate

    wire [8:0] gx = x[9:1], gy = y[9:1];
    wire [9:0] wx = cam_x + gx, wy = cam_y + gy;

    wire [6:0] map_index; wire [11:0] map_color;
    rom_1p #(.DW(7), .AW(19), .DEPTH(512*768), .FILE("map.mem")) u_map (.clk(clk), .addr({wy, wx[8:0]}), .q(map_index));
    rom_lut #(.DW(12), .AW(7), .FILE("map_pal.mem")) u_map_pal (.clk(clk), .addr(map_index), .q(map_color));

    wire signed [11:0] sx = $signed({2'b0, wx}) - $signed({2'b0, px}) + 12'sd32;
    wire signed [11:0] sy = $signed({2'b0, wy}) - $signed({2'b0, py}) + 12'sd63;
    wire        on_sprite = sx >= 0 && sx < 64 && sy >= 0 && sy < 64;
    wire [5:0]  col = mirror ? 6'd63 - sx[5:0] : sx[5:0];
    wire [16:0] sprite_addr = sprite_frame * 17'd4096 + {sy[5:0], 6'd0} + {1'b0, col};
    wire [7:0]  sprite_index; wire [11:0] sprite_color;
    rom_1p #(.DW(8), .AW(17), .DEPTH(110592), .FILE("sprite.mem")) u_sprite (.clk(clk), .addr(sprite_addr), .q(sprite_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_sprite_pal (.clk(clk), .addr(sprite_index), .q(sprite_color));

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
    wire [7:0] item_index; wire [11:0] item_color;
    rom_1p #(.DW(8), .AW(17), .DEPTH(110592), .FILE("sprite.mem")) u_item_rom (.clk(clk), .addr(item_addr), .q(item_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_item_pal (.clk(clk), .addr(item_index), .q(item_color));

    reg on_minion = 0; reg [5:0] mx_col = 0; reg [5:0] my_row = 0; reg minion_is_dying = 0;
    always @(*) begin
        on_minion = 0; mx_col = 0; my_row = 0; minion_is_dying = 0;
        for (i = 0; i < 16; i = i + 1) begin
            if ((m_hp[i] > 0 || m_dying[i]) && (wx >= (m_x[i] - 32)) && (wx < (m_x[i] + 32)) && (wy >= (m_y[i] - 63)) && (wy <= m_y[i])) begin
                on_minion = 1'b1; mx_col = wx - (m_x[i] - 32); my_row = wy - (m_y[i] - 63);
                minion_is_dying = m_dying[i];
            end
        end
    end
    wire [4:0] minion_frame = minion_is_dying ? 5'd26 : (5'd24 + {3'b000, minion_state});
    wire [16:0] minion_addr = minion_frame * 17'd4096 + {my_row, 6'd0} + {1'b0, mx_col};
    wire [7:0] minion_index; wire [11:0] minion_color;
    rom_1p #(.DW(8), .AW(17), .DEPTH(110592), .FILE("sprite.mem")) u_minion_rom (.clk(clk), .addr(minion_addr), .q(minion_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_minion_pal (.clk(clk), .addr(minion_index), .q(minion_color));

    wire signed [11:0] end_sx = $signed({2'b0, x}) - 12'sd256; 
    wire signed [11:0] end_sy = $signed({2'b0, y}) - 12'sd176; 
    wire on_end_sprite = game_won && (end_sx >= 0 && end_sx < 128 && end_sy >= 0 && end_sy < 128);
    wire [5:0] esx = end_sx[6:1], esy = end_sy[6:1];

    wire signed [11:0] bsx_2x = $signed({2'b0, wx}) - $signed({2'b0, boss_x}) + 12'sd64;
    wire signed [11:0] bsy_2x = $signed({2'b0, wy}) - $signed({2'b0, boss_y}) + 12'sd127;
    wire on_boss = (boss_hp > 0 || boss_dying) && (bsx_2x >= 0 && bsx_2x < 128 && bsy_2x >= 0 && bsy_2x < 128);
    wire on_boss_eval = game_won ? on_end_sprite : on_boss;
    
    wire [5:0] bsx = bsx_2x[6:1], bsy = bsy_2x[6:1]; 
    wire [4:0] boss_frame = boss_dying ? 5'd26 : (5'd24 + {3'b000, boss_state});
    wire [16:0] boss_addr = game_won ? (5'd26 * 17'd4096 + {esy, 6'd0} + {1'b0, esx}) : (boss_frame * 17'd4096 + {bsy, 6'd0} + {1'b0, bsx});
    
    wire [7:0] boss_index; wire [11:0] boss_color;
    rom_1p #(.DW(8), .AW(17), .DEPTH(110592), .FILE("sprite.mem")) u_boss_rom (.clk(clk), .addr(boss_addr), .q(boss_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_boss_pal (.clk(clk), .addr(boss_index), .q(boss_color));

    // --- Expanded Red Barrier Box ---
    wire [9:0] tgt_x = (current_form < 4) ? item_x[current_form] : 10'd0;
    wire [9:0] tgt_y = (current_form < 4) ? item_y[current_form] : 10'd0;
    wire on_barrier = barrier_active && ((wx >= tgt_x - 45 && wx <= tgt_x + 45 && (wy == tgt_y - 45 || wy == tgt_y + 45 || wy == tgt_y - 44 || wy == tgt_y + 44)) ||
                                         (wy >= tgt_y - 45 && wy <= tgt_y + 45 && (wx == tgt_x - 45 || wx == tgt_x + 45 || wx == tgt_x - 44 || wx == tgt_x + 44)));

    // --- Health Bars (Moved up above all heads) ---
    wire [6:0] max_w = player_max_hp[7:1]; wire [6:0] php_w = player_hp[7:1]; 
    wire on_php_bg = (wx >= px - 16 && wx < (px - 16 + max_w)) && (wy >= py - 72 && wy <= py - 70);
    wire on_php_fg = on_php_bg && (wx < (px - 16 + php_w));
    
    wire on_bhp_bg = (wx >= boss_x - 32 && wx <= boss_x + 31) && (wy >= boss_y - 140 && wy <= boss_y - 137); 
    wire [6:0] bhp_w = boss_hp[7:1]; 
    wire on_bhp_fg = on_bhp_bg && (wx < (boss_x - 32 + bhp_w));
    
    // --- Added Minion Health Bars ---
    reg on_mhp_bg_c = 0; reg on_mhp_fg_c = 0;
    always @(*) begin
        on_mhp_bg_c = 0; on_mhp_fg_c = 0;
        for (i = 0; i < 16; i = i + 1) begin
            if (m_hp[i] > 0) begin
                if (wx >= m_x[i] - 15 && wx < m_x[i] + 15 && wy >= m_y[i] - 72 && wy <= m_y[i] - 70) begin
                    on_mhp_bg_c = 1'b1;
                    if (wx < m_x[i] - 15 + m_hp[i]) on_mhp_fg_c = 1'b1; // Bar width 30px (Minion max HP is 30)
                end
            end
        end
    end
    wire on_mhp_bg = on_mhp_bg_c;
    wire on_mhp_fg = on_mhp_fg_c;

    // --- Expanded Warning Rings ---
    wire on_boss_warn = (boss_state == 2'd1) && (boss_hp > 0) && (
        (wx >= boss_x - 70 && wx <= boss_x + 70 && (wy == boss_y - 130 || wy == boss_y + 10 || wy == boss_y - 129 || wy == boss_y + 9)) ||
        (wy >= boss_y - 130 && wy <= boss_y + 10 && (wx == boss_x - 70 || wx == boss_x + 70 || wx == boss_x - 69 || wx == boss_x + 69))
    );
    
    reg on_minion_warn = 0;
    always @(*) begin
        on_minion_warn = 0;
        if (minion_state == 2'd1) begin
            for (i = 0; i < 16; i = i + 1) begin
                if (m_hp[i] > 0) begin
                    if ((wx >= m_x[i] - 35 && wx <= m_x[i] + 35 && (wy == m_y[i] - 65 || wy == m_y[i] + 5 || wy == m_y[i] - 64 || wy == m_y[i] + 4)) ||
                        (wy >= m_y[i] - 65 && wy <= m_y[i] + 5 && (wx == m_x[i] - 35 || wx == m_x[i] + 35 || wx == m_x[i] - 34 || wx == m_x[i] + 34))) begin
                        on_minion_warn = 1'b1;
                    end
                end
            end
        end
    end
    
    reg on_1=0, see_2=0, on_item_1=0, see_item_2=0;
    reg on_minion_1=0, see_minion_2=0, on_boss_1=0, see_boss_2=0;
    reg on_bar_1=0, on_bar_2=0, on_warn_1=0, on_warn_2=0;
    reg on_php_bg_1=0, on_php_fg_1=0, on_bhp_bg_1=0, on_bhp_fg_1=0;
    reg on_mhp_bg_1=0, on_mhp_fg_1=0, on_mhp_bg_2=0, on_mhp_fg_2=0; // Minion health bar wires
    reg on_php_bg_2=0, on_php_fg_2=0, on_bhp_bg_2=0, on_bhp_fg_2=0;
    reg boss_dying_1=0, boss_dying_2=0, minion_dying_1=0, minion_dying_2=0;
    reg game_won_1=0, game_won_2=0;
    reg vid_1=0, vid_2=0, hs_1=1, hs_2=1, vs_1=1, vs_2=1;

    always @(posedge clk) begin
        // clock 1
        on_1 <= game_won ? 0 : on_sprite; on_item_1 <= on_item; on_boss_1 <= on_boss_eval; on_minion_1 <= on_minion;
        on_bar_1 <= on_barrier; on_warn_1 <= on_boss_warn | on_minion_warn;
        on_php_bg_1 <= on_php_bg; on_php_fg_1 <= on_php_fg; on_bhp_bg_1 <= on_bhp_bg; on_bhp_fg_1 <= on_bhp_fg;
        on_mhp_bg_1 <= on_mhp_bg; on_mhp_fg_1 <= on_mhp_fg;
        boss_dying_1 <= boss_dying; minion_dying_1 <= minion_is_dying; game_won_1 <= game_won;
        vid_1 <= video_on; hs_1 <= hsync; vs_1 <= vsync;
        
        // clock 2
        see_2        <= on_1 && (sprite_index != 8'd0);
        see_item_2   <= on_item_1 && (item_index != 8'd0);	
        see_boss_2   <= on_boss_1 && (boss_index != 8'd0);
        see_minion_2 <= on_minion_1 && (minion_index != 8'd0);
        on_bar_2 <= on_bar_1; on_warn_2 <= on_warn_1;
        on_php_bg_2 <= on_php_bg_1; on_php_fg_2 <= on_php_fg_1;
        on_bhp_bg_2 <= on_bhp_bg_1; on_bhp_fg_2 <= on_bhp_fg_1;
        on_mhp_bg_2 <= on_mhp_bg_1; on_mhp_fg_2 <= on_mhp_fg_1;
        boss_dying_2 <= boss_dying_1; minion_dying_2 <= minion_dying_1; game_won_2 <= game_won_1;
        vid_2 <= vid_1; hs_2 <= hs_1; vs_2 <= vs_1;
        
        // clock 3
        {VGA_R, VGA_G, VGA_B} <= !vid_2 ? 12'h000 : 
                                 game_won_2  ? (see_boss_2 ? boss_color : 12'h000) : 
                                 on_php_fg_2 ? 12'h0F0 : on_php_bg_2 ? 12'h800 :
                                 on_bhp_fg_2 ? 12'h0F0 : on_bhp_bg_2 ? 12'h800 : 
                                 on_mhp_fg_2 ? 12'h0F0 : on_mhp_bg_2 ? 12'h800 : // Insert Minion health bar colors here
                                 on_bar_2    ? 12'hF00 : 
                                 on_warn_2   ? 12'hF00 : 
                                 see_2       ? sprite_color : 
                                 see_boss_2  ? (boss_dying_2 ? {4'hF, boss_color[7:0]} : boss_color) : 
                                 see_minion_2? (minion_dying_2 ? {4'hF, minion_color[7:0]} : minion_color) :
                                 see_item_2  ? item_color : 
                                 map_color;
        VGA_HS <= hs_2; VGA_VS <= vs_2;
    end
endmodule