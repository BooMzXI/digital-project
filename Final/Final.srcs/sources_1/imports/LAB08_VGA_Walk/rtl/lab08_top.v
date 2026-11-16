`timescale 1ns / 1ps
// ============================================================================
//  CPE222 LAB08 : VGA RPG Demo on the Nexys A7-100T
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
    // ---  7-Segment ---
    output wire       CA, CB, CC, CD, CE, CF, CG, DP,
    output wire [7:0] AN
);
    // ---------------- Clock and Reset ----------------
    wire clk, locked;
    clk_gen u_clk (.clk100(CLK100MHZ), .clk25(clk), .locked(locked));

    reg rst_1 = 1'b1, rst = 1'b1;                 
    always @(posedge clk) {rst, rst_1} <= {rst_1, ~(locked & CPU_RESETN)};

    // ---------------- Part A : VGA Timing ----------------
    wire [9:0] x, y;
    wire       hsync, vsync, video_on;
    vga_sync u_sync (.clk(clk), .rst(rst), .x(x), .y(y),
                     .hsync(hsync), .vsync(vsync), .video_on(video_on));

    wire tick = (x == 10'd0) && (y == 10'd480); // End of frame

    // ---------------- Player and Camera ----------------
    wire [3:0]  item_active;
    wire [2:0]  current_form; 
    wire [39:0] flat_item_x, flat_item_y;
    wire [9:0]  px, py, cam_y;
    wire [8:0]  cam_x;
    wire        back, mirror, moving, adv;
    wire        is_attacking;

    // --- Boss and Combat (Expanded Bit-widths for 100k HP) ---
    wire [9:0]  boss_x, boss_y;
    wire [1:0]  boss_state;
    wire [16:0] boss_hp;           // 17-bit for 100,000 HP
    wire [8:0]  player_hp;         // 9-bit for 300 HP
    wire [8:0]  player_max_hp;     
    
    // --- Minions and Barrier (Expanded to 208 bits for 13-bit HP array) ---
    wire [159:0] flat_minion_x, flat_minion_y;
    wire [207:0] flat_minion_hp;   // 16 * 13 bits
    wire [1:0]   minion_state;
    wire [3:0]   barrier_active;

    // --- Death and Game Over Signals ---
    wire         boss_dying;
    wire [15:0]  flat_minion_dying;
    wire         game_won;

    player u_player (
        .clk(clk), .rst(rst), .tick(tick), .btn({BTNU, BTND, BTNL, BTNR}),
        .btn_attack(BTNC), .sw0(SW[0]),
        .px(px), .py(py), .cam_x(cam_x), .cam_y(cam_y),
        .back(back), .mirror(mirror), .moving(moving), .adv(adv),
        .item_active(item_active), .current_form(current_form),
        .flat_item_x(flat_item_x), .flat_item_y(flat_item_y),
        .is_attacking(is_attacking),
        .boss_x(boss_x), .boss_y(boss_y), .boss_state(boss_state),
        .boss_hp(boss_hp), .player_hp(player_hp), .player_max_hp(player_max_hp),
        .flat_minion_x(flat_minion_x), .flat_minion_y(flat_minion_y),
        .flat_minion_hp(flat_minion_hp), .minion_state(minion_state),
        .barrier_active(barrier_active),
        .boss_dying(boss_dying), .flat_minion_dying(flat_minion_dying), .game_won(game_won)
    );

    // ---------------- Part C : Walking Picture ----------------
    wire [1:0] step, walk_state;
    walk_fsm u_walk (.clk(clk), .clear_n(~rst), .adv(adv), .m(moving),
                     .step(step), .state(walk_state));

    wire [4:0] base_frame = current_form * 5'd4;  
    wire [4:0] walk_sprite_frame = base_frame + {3'd0, step};
    wire [4:0] sprite_frame = is_attacking ? (base_frame + 5'd3) : walk_sprite_frame;
    assign LED = walk_state;

    // ---------------- Picture Render ----------------
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
        .barrier_active(barrier_active),
        .boss_dying(boss_dying), .flat_minion_dying(flat_minion_dying), .game_won(game_won),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS)
    );

    // ---------------- Timer (MM:SS) ----------------
    wire tick_1sec, tick_fast;
    tick_gen #(.DIV(25_000_000)) u_tick_1sec (.clk(clk), .reset_n(~rst), .tick(tick_1sec));
    tick_gen #(.DIV(25_000)) u_tick_fast (.clk(clk), .reset_n(~rst), .tick(tick_fast));

    reg [3:0] sec_0=0, sec_1=0, min_0=0, min_1=0;
    always @(posedge clk) begin
        if (rst) begin
            sec_0 <= 0; sec_1 <= 0; min_0 <= 0; min_1 <= 0;
        end else if (tick_1sec && !game_won && player_hp > 0) begin // Stop timer on win/loss
            if (sec_0 == 9) begin
                sec_0 <= 0;
                if (sec_1 == 5) begin
                    sec_1 <= 0;
                    if (min_0 == 9) begin
                        min_0 <= 0;
                        if (min_1 < 9) min_1 <= min_1 + 1;
                    end else min_0 <= min_0 + 1;
                end else sec_1 <= sec_1 + 1;
            end else sec_0 <= sec_0 + 1;
        end
    end

    // 3-bit scan selector (8 digits)
    reg [2:0] scan_sel = 0;
    always @(posedge clk) begin
        if (tick_fast) scan_sel <= scan_sel + 1'b1;
    end

    reg [3:0] current_digit;
    reg [7:0] an_temp;
    always @(*) begin
        case (scan_sel)
            3'd0: begin current_digit = sec_0; an_temp = 8'b1111_1110; end 
            3'd1: begin current_digit = sec_1; an_temp = 8'b1111_1101; end 
            3'd2: begin current_digit = min_0; an_temp = 8'b1111_1011; end 
            3'd3: begin current_digit = min_1; an_temp = 8'b1111_0111; end 
            3'd7: begin current_digit = {1'b0, current_form}; an_temp = 8'b0111_1111; end 
            default: begin current_digit = 4'd0; an_temp = 8'b1111_1111; end 
        endcase
    end

    wire [6:0] seg_n;
    seg7_dec u_seg7 (.digit(current_digit), .seg_n(seg_n));
    assign {CG, CF, CE, CD, CC, CB, CA} = seg_n;
    assign DP = (scan_sel == 3'd2) ? 1'b0 : 1'b1; // DP on Min ones
    assign AN = an_temp;
endmodule