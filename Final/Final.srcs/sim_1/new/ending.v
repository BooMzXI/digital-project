`timescale 1ns / 1ps

module tb_end_screens;

    // สร้างสัญญาณ Pixel Clock 25 MHz โดยตรง (รันจบใน ~1-2 วินาที)
    reg clk = 0;
    reg rst = 1;
    reg tick = 0;
    always #20 clk = ~clk;

    reg  [9:0] x = 0, y = 0;
    reg        video_on = 0;
    wire       hsync = 1'b1, vsync = 1'b1;

    wire [3:0]   item_active;
    wire [2:0]   current_form;
    wire [39:0]  flat_item_x, flat_item_y;
    wire [9:0]   px, py, cam_y;
    wire [8:0]   cam_x;
    wire         back, mirror, moving, adv;
    wire         is_attacking;

    wire [9:0]   boss_x, boss_y;
    wire [1:0]   boss_state;
    wire [16:0]  boss_hp;
    wire [8:0]   player_hp, player_max_hp;

    wire [159:0] flat_minion_x, flat_minion_y;
    wire [207:0] flat_minion_hp;
    wire [1:0]   minion_state;
    wire [3:0]   barrier_active;

    wire         boss_dying;
    wire [15:0]  flat_minion_dying;
    wire         game_won;

    wire [3:0]   VGA_R, VGA_G, VGA_B;
    wire         VGA_HS, VGA_VS;

    player u_player (
        .clk(clk), .rst(rst), .tick(tick), .btn(4'b0000),
        .btn_attack(1'b0), .sw0(1'b0),
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

    wire [1:0] step, walk_state;
    walk_fsm u_walk (
        .clk(clk), .clear_n(~rst), .adv(adv), .m(moving),
        .step(step), .state(walk_state)
    );

    wire [4:0] base_frame        = current_form * 5'd4;
    wire [4:0] walk_sprite_frame = base_frame + {3'd0, step};
    wire [4:0] sprite_frame      = is_attacking ? (base_frame + 5'd3) : walk_sprite_frame;

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

    reg [11:0] px_die_text, px_die_rst;
    reg [11:0] px_win_text, px_win_rst;
    integer    win_qb_nonzero, win_rgb_nonzero;
    reg [7:0]  win_sample_qb;

    task pulse_tick;
        begin
            @(negedge clk);
            tick = 1'b1;
            @(posedge clk);
            @(negedge clk);
            tick = 1'b0;
            @(posedge clk);
        end
    endtask

    task render_and_save_ppm;
        input [8*20:1] filename;
        input          is_win_screen;
        integer fd, r, c, out_c;
        begin
            if (is_win_screen) begin
                win_qb_nonzero  = 0;
                win_rgb_nonzero = 0;
                win_sample_qb   = 8'd0;
            end

            fd = $fopen(filename, "w");
            $fwrite(fd, "P3\n640 480\n15\n");

            for (r = 0; r < 480; r = r + 1) begin
                @(negedge clk);
                y        = r[9:0];
                x        = 10'd0;
                video_on = 1'b1;

                for (c = 0; c < 642; c = c + 1) begin
                    @(posedge clk);
                    // เช็กข้อมูลพิกเซลจาก ROM ในกรอบรูปชนะเกม (Stage 1)
                    if (is_win_screen && c >= 1 && c <= 640 && u_render.on_boss_1) begin
                        if (u_render.q_b !== 8'd0) begin
                            win_qb_nonzero = win_qb_nonzero + 1;
                            if (win_sample_qb == 8'd0) win_sample_qb = u_render.q_b;
                        end
                    end

                    if (c >= 2) begin
                        out_c = c - 2;
                        $fwrite(fd, "%0d %0d %0d ", VGA_R, VGA_G, VGA_B);

                        if (is_win_screen && out_c >= 256 && out_c < 384 && r >= 196 && r < 324) begin
                            if ({VGA_R, VGA_G, VGA_B} != 12'h000)
                                win_rgb_nonzero = win_rgb_nonzero + 1;
                        end

                        if (!is_win_screen && out_c == 96 && r == 180)
                            px_die_text = {VGA_R, VGA_G, VGA_B};
                        if (is_win_screen && out_c == 160 && r == 110)
                            px_win_text = {VGA_R, VGA_G, VGA_B};
                        if (out_c == 56 && r == 376) begin
                            if (is_win_screen) px_win_rst = {VGA_R, VGA_G, VGA_B};
                            else               px_die_rst = {VGA_R, VGA_G, VGA_B};
                        end
                    end
                    @(negedge clk);
                    if (c < 639) x = x + 10'd1;
                    else         video_on = 1'b0;
                end
                $fwrite(fd, "\n");
            end

            $fclose(fd);
            $display("[INFO] Saved VGA frame to %0s", filename);
        end
    endtask

    initial begin
        $display("==================================================");
        $display("   STARTING END-SCREEN SIMULATION (DIE & WIN)     ");
        $display("==================================================");

        rst = 1'b1;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        // --------------------------------------------------
        // TEST 1 : จำลองฉากผู้เล่นตาย (YOU DIE)
        // --------------------------------------------------
        $display("\n--- [TEST 1] Simulating Player Death ---");
        @(negedge clk);
        u_player.px         = 10'd400;
        u_player.py         = 10'd260;
        u_player.player_hp  = 9'd20;
        u_player.boss_state = 2'd2;
        u_player.boss_timer = 8'd1; // ตั้งเป็น 1 เพื่อให้บอสฟาดโดนทันทีใน tick ถัดไป

        pulse_tick();
        $display("Player HP after boss hit = %0d (Expected: 0)", player_hp);

        render_and_save_ppm("screen_die.ppm", 1'b0);

        if (px_die_text == 12'hF00 && px_die_rst == 12'hFFF)
            $display("[PASS] YOU DIE (Red: %h) & PRESS RESET (White: %h)", px_die_text, px_die_rst);
        else
            $display("[FAIL] Unexpected color on Death screen: top=%h, rst=%h", px_die_text, px_die_rst);

        // --------------------------------------------------
        // TEST 2 : กด Reset แล้วจำลองฉากชนะบอส (YOU RECIVE)
        // --------------------------------------------------
        $display("\n--- [TEST 2] Pressing Reset & Simulating Boss Victory ---");
        @(negedge clk);
        rst = 1'b1;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        @(negedge clk);
        u_player.current_form = 3'd4;
        u_player.boss_hp      = 17'd0;
        u_player.boss_dt      = 6'd2;

        pulse_tick();
        pulse_tick();
        $display("Game Won Flag = %0b (Expected: 1)", game_won);

        render_and_save_ppm("screen_win.ppm", 1'b1);
        $display("[DIAG] Frame 27 non-zero sprite indices = %0d (sample q_b = 0x%h), visible RGB pixels = %0d",
                 win_qb_nonzero, win_sample_qb, win_rgb_nonzero);

        if (px_win_text == 12'h0F0 && px_win_rst == 12'hFFF)
            $display("[PASS] YOU RECIVE (Green: %h) & PRESS RESET (White: %h)", px_win_text, px_win_rst);
        else
            $display("[FAIL] Unexpected color on Victory screen: top=%h, rst=%h", px_win_text, px_win_rst);

        $display("\n==================================================");
        $display("   SIMULATION COMPLETED SUCCESSFULLY!             ");
        $display("==================================================");
        $finish;
    end

endmodule