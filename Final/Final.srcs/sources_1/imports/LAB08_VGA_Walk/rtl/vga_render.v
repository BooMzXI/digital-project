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
    input  wire [39:0] flat_item_x,
    input  wire [39:0] flat_item_y,
    
    // Boss & Player HP
    input  wire [9:0]  boss_x, boss_y,
    input  wire [1:0]  boss_state,
    input  wire [7:0]  boss_hp,
    input  wire [7:0]  player_hp,
    input  wire [7:0]  player_max_hp,
    
    // 16 Minions & Barrier
    input  wire [159:0] flat_minion_x,
    input  wire [159:0] flat_minion_y,
    input  wire [95:0]  flat_minion_hp,
    input  wire [1:0]   minion_state,
    input  wire         barrier_active,
    
    output reg  [3:0]  VGA_R = 0, VGA_G = 0, VGA_B = 0,
    output reg         VGA_HS = 1, VGA_VS = 1
);
    wire [9:0] item_x [0:3];
    wire [9:0] item_y [0:3];
    assign {item_x[3], item_x[2], item_x[1], item_x[0]} = flat_item_x;
    assign {item_y[3], item_y[2], item_y[1], item_y[0]} = flat_item_y;

    wire [9:0] m_x [0:15];
    wire [9:0] m_y [0:15];
    wire [5:0] m_hp [0:15];
    
    // Unpack 16 minions
    genvar g;
    generate
        for (g=0; g<16; g=g+1) begin : unpack_m
            assign m_x[g] = flat_minion_x[g*10 +: 10];
            assign m_y[g] = flat_minion_y[g*10 +: 10];
            assign m_hp[g] = flat_minion_hp[g*6 +: 6];
        end
    endgenerate

    wire [8:0]  gx = x[9:1];
    wire [8:0]  gy = y[9:1];
    wire [9:0]  wx = cam_x + gx;
    wire [9:0]  wy = cam_y + gy;

    // ---- map color ----
    wire [6:0]  map_index;
    wire [11:0] map_color;
    rom_1p  #(.DW(7), .AW(19), .DEPTH(512*768), .FILE("map.mem")) u_map (.clk(clk), .addr({wy, wx[8:0]}), .q(map_index));
    rom_lut #(.DW(12), .AW(7), .FILE("map_pal.mem")) u_map_pal (.clk(clk), .addr(map_index), .q(map_color));

    // ---- player sprite ----
    wire signed [11:0] sx = $signed({2'b0, wx}) - $signed({2'b0, px}) + 12'sd16;
    wire signed [11:0] sy = $signed({2'b0, wy}) - $signed({2'b0, py}) + 12'sd47;
    wire        on_sprite = sx >= 0 && sx < 32 && sy >= 0 && sy < 48;
    wire [4:0]  col = mirror ? 5'd31 - sx[4:0] : sx[4:0];
    wire [15:0] sprite_addr = sprite_frame * 16'd1536 + {sy[5:0], 5'd0} + col;
    wire [7:0]  sprite_index;
    wire [11:0] sprite_color;
    rom_1p  #(.DW(8), .AW(16), .DEPTH(65536), .FILE("sprite.mem")) u_sprite (.clk(clk), .addr(sprite_addr), .q(sprite_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_sprite_pal (.clk(clk), .addr(sprite_index), .q(sprite_color));

    // ---- items color ----
    reg on_item = 0; reg [1:0] active_item_id = 0; reg [4:0] item_col = 0; reg [5:0] item_row = 0;
    integer i;
    always @(*) begin
        on_item = 1'b0; active_item_id = 2'd0; item_col = 5'd0; item_row = 6'd0;
        for (i = 0; i < 4; i = i + 1) begin
            if (item_active[i] && (wx >= (item_x[i] - 16)) && (wx < (item_x[i] + 16)) &&
                (wy >= (item_y[i] - 16)) && (wy < (item_y[i] + 16))) begin
                on_item = 1'b1; active_item_id = i[1:0];
                item_col = wx - (item_x[i] - 16); item_row = wy - (item_y[i] - 16);
            end
        end
    end
    wire [4:0] item_frame = 5'd20 + {3'b000, active_item_id}; // Assume items are at frame 20,21,22,23
    wire [15:0] item_addr = item_frame * 16'd1536 + {item_row, 5'd0} + item_col;
    wire [7:0] item_index;
    wire [11:0] item_color;
    rom_1p  #(.DW(8), .AW(16), .DEPTH(65536), .FILE("sprite.mem")) u_item_rom (.clk(clk), .addr(item_addr), .q(item_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_item_pal (.clk(clk), .addr(item_index), .q(item_color));

    // ---- Minions 16x (Uses Boss Frames 16,17,18,19 but 1x size) ----
    reg on_minion = 0; reg [4:0] mx_col = 0; reg [5:0] my_row = 0;
    always @(*) begin
        on_minion = 1'b0; mx_col = 5'd0; my_row = 6'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (m_hp[i] > 0 && (wx >= (m_x[i] - 16)) && (wx < (m_x[i] + 16)) &&
                (wy >= (m_y[i] - 47)) && (wy <= m_y[i])) begin
                on_minion = 1'b1;
                mx_col = wx - (m_x[i] - 16); my_row = wy - (m_y[i] - 47);
            end
        end
    end
    wire [4:0] minion_frame = 5'd16 + {3'b000, minion_state};
    wire [15:0] minion_addr = minion_frame * 16'd1536 + {my_row, 5'd0} + mx_col;
    wire [7:0] minion_index;
    wire [11:0] minion_color;
    rom_1p  #(.DW(8), .AW(16), .DEPTH(65536), .FILE("sprite.mem")) u_minion_rom (.clk(clk), .addr(minion_addr), .q(minion_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_minion_pal (.clk(clk), .addr(minion_index), .q(minion_color));

    // ---- Boss Sprite (2x Scaling = 64x96 size) ----
    wire signed [11:0] bsx_2x = $signed({2'b0, wx}) - $signed({2'b0, boss_x}) + 12'sd32;
    wire signed [11:0] bsy_2x = $signed({2'b0, wy}) - $signed({2'b0, boss_y}) + 12'sd95;
    wire on_boss = (bsx_2x >= 0 && bsx_2x < 64 && bsy_2x >= 0 && bsy_2x < 96);
    
    wire [4:0] bsx = bsx_2x[5:1]; // divide by 2 for rendering
    wire [5:0] bsy = bsy_2x[6:1]; // divide by 2 for rendering
    wire [4:0] boss_frame = 5'd16 + {3'b000, boss_state};
    wire [15:0] boss_addr = boss_frame * 16'd1536 + {bsy, 5'd0} + bsx;
    
    wire [7:0] boss_index;
    wire [11:0] boss_color;
    rom_1p  #(.DW(8), .AW(16), .DEPTH(65536), .FILE("sprite.mem")) u_boss_rom (.clk(clk), .addr(boss_addr), .q(boss_index));
    rom_lut #(.DW(12), .AW(8), .FILE("spr_pal.mem")) u_boss_pal (.clk(clk), .addr(boss_index), .q(boss_color));

    // ---- Red Box Barrier around Item (72x72 box) ----
    wire [9:0] tgt_x = (current_form < 4) ? item_x[current_form] : 10'd0;
    wire [9:0] tgt_y = (current_form < 4) ? item_y[current_form] : 10'd0;
    wire on_barrier = barrier_active && (
        (wx >= tgt_x - 36 && wx <= tgt_x + 36 && (wy == tgt_y - 36 || wy == tgt_y + 36 || wy == tgt_y - 35 || wy == tgt_y + 35)) ||
        (wy >= tgt_y - 36 && wy <= tgt_y + 36 && (wx == tgt_x - 36 || wx == tgt_x + 36 || wx == tgt_x - 35 || wx == tgt_x + 35))
    );

    // ---- Health Bars ----
    wire [6:0] max_w = player_max_hp[7:1];
    wire [6:0] php_w = player_hp[7:1]; 
    wire on_php_bg = (wx >= px - 16 && wx < (px - 16 + max_w)) && (wy >= py - 52 && wy <= py - 50);
    wire on_php_fg = on_php_bg && (wx < (px - 16 + php_w));

    wire on_bhp_bg = (wx >= boss_x - 32 && wx <= boss_x + 31) && (wy >= boss_y - 100 && wy <= boss_y - 98);
    wire [6:0] bhp_w = boss_hp[7:1]; 
    wire on_bhp_fg = on_bhp_bg && (wx < (boss_x - 32 + bhp_w));

    // ---- Boss/Minion Attack Warning (Red Square) ----
    wire on_boss_warn = (boss_state == 2'd1) && (
        (wx >= boss_x - 40 && wx <= boss_x + 40 && (wy == boss_y - 40 || wy == boss_y + 40)) ||
        (wy >= boss_y - 40 && wy <= boss_y + 40 && (wx == boss_x - 40 || wx == boss_x + 40))
    );
    
    // ---- pipeline ----
    reg on_1=0, see_2=0, on_item_1=0, see_item_2=0;
    reg on_minion_1=0, see_minion_2=0, on_boss_1=0, see_boss_2=0;
    reg on_bar_1=0, on_bar_2=0, on_warn_1=0, on_warn_2=0;
    reg on_php_bg_1=0, on_php_fg_1=0, on_bhp_bg_1=0, on_bhp_fg_1=0;
    reg on_php_bg_2=0, on_php_fg_2=0, on_bhp_bg_2=0, on_bhp_fg_2=0;
    reg vid_1=0, vid_2=0, hs_1=1, hs_2=1, vs_1=1, vs_2=1;

    always @(posedge clk) begin
        // clock 1
        on_1 <= on_sprite; on_item_1 <= on_item; on_boss_1 <= on_boss; on_minion_1 <= on_minion;
        on_bar_1 <= on_barrier; on_warn_1 <= on_boss_warn;
        on_php_bg_1 <= on_php_bg; on_php_fg_1 <= on_php_fg; on_bhp_bg_1 <= on_bhp_bg; on_bhp_fg_1 <= on_bhp_fg;
        vid_1 <= video_on; hs_1 <= hsync; vs_1 <= vsync;
        
        // clock 2
        see_2        <= on_1 && (sprite_index != 8'd0);
        see_item_2   <= on_item_1 && (item_index != 8'd0);	
        see_boss_2   <= on_boss_1 && (boss_index != 8'd0);
        see_minion_2 <= on_minion_1 && (minion_index != 8'd0);
        on_bar_2 <= on_bar_1; on_warn_2 <= on_warn_1;
        on_php_bg_2 <= on_php_bg_1; on_php_fg_2 <= on_php_fg_1;
        on_bhp_bg_2 <= on_bhp_bg_1; on_bhp_fg_2 <= on_bhp_fg_1;
        vid_2 <= vid_1; hs_2 <= hs_1; vs_2 <= vs_1;
        
        // clock 3
       {VGA_R, VGA_G, VGA_B} <= !vid_2      ? 12'h000 : 
                                 on_php_fg_2 ? 12'h0F0 : on_php_bg_2 ? 12'h800 : // Player HP
                                 on_bhp_fg_2 ? 12'h0F0 : on_bhp_bg_2 ? 12'h800 : // Boss HP
                                 on_bar_2    ? 12'hF00 : // Red Barrier Box
                                 on_warn_2   ? 12'hF00 : // Attack Warning
                                 see_2       ? sprite_color : // Player
                                 see_boss_2  ? boss_color   : // Boss 2x
                                 see_minion_2? minion_color : // Minions
                                 see_item_2  ? item_color   : // Item
                                 map_color;
        VGA_HS <= hs_2; VGA_VS <= vs_2;
    end
endmodule