`timescale 1ns / 1ps
// ============================================================================
//  7-Scene Visual Verification Testbench (Hierarchical Subsystems)
// ============================================================================
module tb_full_check;

    // Pixel Clock 25 MHz
    reg clk  = 0;
    reg rst  = 1;
    reg tick = 0;
    always #20 clk = ~clk;

    reg [3:0] btn        = 4'b0000;
    reg       btn_attack = 1'b0;
    reg       sw0        = 1'b0;

    reg  [9:0] x = 0, y = 0;
    reg        video_on = 0;
    wire       hsync = 1'b1, vsync = 1'b1;

    wire [9:0]   px, py, cam_x, cam_y;
    wire [4:0]   sprite_frame;
    wire         mirror;
    wire [3:0]   item_active;
    wire [2:0]   current_form;
    wire [39:0]  flat_item_x, flat_item_y;
    wire [9:0]   boss_x, boss_y;
    wire [1:0]   boss_state;
    wire [16:0]  boss_hp;
    wire [8:0]   player_hp, player_max_hp;
    wire [159:0] flat_minion_x, flat_minion_y;
    wire [207:0] flat_minion_hp;
    wire [1:0]   minion_state;
    wire [15:0]  minion_active_atk;
    wire [3:0]   barrier_active;
    wire         boss_dying;
    wire [15:0]  flat_minion_dying;
    wire         game_won;
    wire [1:0]   walk_state;

    wire [3:0]   VGA_R, VGA_G, VGA_B;
    wire         VGA_HS, VGA_VS;

    game_logic u_logic (
        .clk(clk), .rst(rst), .tick(tick),
        .btn(btn), .btn_attack(btn_attack), .sw0(sw0),
        .px(px), .py(py), .cam_x(cam_x), .cam_y(cam_y),
        .sprite_frame(sprite_frame), .mirror(mirror),
        .item_active(item_active), .current_form(current_form),
        .flat_item_x(flat_item_x), .flat_item_y(flat_item_y),
        .boss_x(boss_x), .boss_y(boss_y), .boss_state(boss_state),
        .boss_hp(boss_hp), .player_hp(player_hp), .player_max_hp(player_max_hp),
        .flat_minion_x(flat_minion_x), .flat_minion_y(flat_minion_y),
        .flat_minion_hp(flat_minion_hp), .minion_state(minion_state),
        .minion_active_atk(minion_active_atk),
        .barrier_active(barrier_active),
        .boss_dying(boss_dying), .flat_minion_dying(flat_minion_dying),
        .game_won(game_won),
        .walk_state(walk_state)
    );

    game_graphics u_gfx (
        .clk(clk), .x(x), .y(y), .hsync(hsync), .vsync(vsync), .video_on(video_on),
        .px(px), .py(py), .cam_x(cam_x), .cam_y(cam_y),
        .sprite_frame(sprite_frame), .mirror(mirror),
        .item_active(item_active), .current_form(current_form),
        .flat_item_x(flat_item_x), .flat_item_y(flat_item_y),
        .boss_x(boss_x), .boss_y(boss_y), .boss_state(boss_state),
        .boss_hp(boss_hp), .player_hp(player_hp), .player_max_hp(player_max_hp),
        .flat_minion_x(flat_minion_x), .flat_minion_y(flat_minion_y),
        .flat_minion_hp(flat_minion_hp), .minion_state(minion_state),
        .minion_active_atk(minion_active_atk),
        .barrier_active(barrier_active),
        .boss_dying(boss_dying), .flat_minion_dying(flat_minion_dying),
        .game_won(game_won),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS)
    );

    task step_ticks;
        input integer count;
        integer k;
        begin
            for (k = 0; k < count; k = k + 1) begin
                @(negedge clk);
                tick = 1'b1;
                @(posedge clk);
                @(negedge clk);
                tick = 1'b0;
                @(posedge clk);
            end
        end
    endtask

    task save_frame_ppm;
        input [8*26:1] filename;
        integer fd, r, c;
        begin
            fd = $fopen(filename, "w");
            $fwrite(fd, "P3\n640 480\n15\n");

            for (r = 0; r < 480; r = r + 1) begin
                @(negedge clk);
                y        = r[9:0];
                x        = 10'd0;
                video_on = 1'b1;

                for (c = 0; c < 643; c = c + 1) begin
                    @(posedge clk);
                    if (c >= 3) begin
                        $fwrite(fd, "%0d %0d %0d ", VGA_R, VGA_G, VGA_B);
                    end
                    @(negedge clk);
                    if (c < 639) x = x + 10'd1;
                    else         video_on = 1'b0;
                end
                $fwrite(fd, "\n");
            end

            $fclose(fd);
            $display("[SAVED] %0s | px=%0d, py=%0d | HP=%0d | cam=(%0d,%0d)", filename, px, py, player_hp, cam_x, cam_y);
        end
    endtask

    initial begin
        $display("=========================================================");
        $display("   STARTING 7-SCENE HIERARCHICAL VERIFICATION            ");
        $display("=========================================================");

        rst = 1'b1;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        // 1. Spawn Point
        $display("\n[1/7] Capturing Spawn Screen...");
        step_ticks(2);
        save_frame_ppm("1_spawn.ppm");

        // 2. Boss Attack at Exact Red-Border Edge (px = boss_x + 65)
        $display("\n[2/7] Capturing Boss Attack at Exact Red-Border Edge...");
        @(negedge clk);
        u_logic.u_player.px     = boss_x + 10'd65;
        u_logic.u_player.py     = boss_y;
        u_logic.u_boss.boss_state = 2'd2;
        u_logic.u_boss.boss_timer = 8'd1;
        step_ticks(1);
        save_frame_ppm("2_boss_attack.ppm");

        // 3. Left Wall Collision & Bottom-Left Minions
        $display("\n[3/7] Capturing Left Wall Collision & Bottom-Left Minions...");
        @(negedge clk);
        u_logic.u_boss.boss_state = 2'd0;
        u_logic.u_player.px       = 10'd76;
        u_logic.u_player.py       = 10'd490;
        btn                       = 4'b0010;
        repeat (3) @(posedge clk);
        step_ticks(20);
        @(negedge clk);
        btn                       = 4'b0000;
        step_ticks(1);
        save_frame_ppm("3_left_edge_minions.ppm");

        // 4. Minion Patrol Movement
        $display("\n[4/7] Capturing Minion Patrol Movement...");
        step_ticks(80);
        save_frame_ppm("4_minions_moved.ppm");

        // 5. Minion Attack at Exact Top Red-Border Edge (py = m_y[8] - 20)
        $display("\n[5/7] Capturing Minion Attack at Exact Top Red-Border Edge...");
        @(negedge clk);
        u_logic.u_player.px                = u_logic.u_minion.m_x[8];
        u_logic.u_player.py                = u_logic.u_minion.m_y[8] - 10'd20;
        u_logic.u_minion.minion_state      = 2'd2;
        u_logic.u_minion.minion_timer      = 8'd1;
        u_logic.u_minion.minion_active_atk = 16'd1 << 8;
        step_ticks(1);
        save_frame_ppm("5_minion_attack.ppm");

        // 6. Death Screen
        $display("\n[6/7] Capturing Death Screen...");
        @(negedge clk);
        u_logic.u_minion.minion_state      = 2'd0;
        u_logic.u_minion.minion_active_atk = 16'd0;
        u_logic.u_player.px                = boss_x;
        u_logic.u_player.py                = boss_y;
        u_logic.u_player.player_hp         = 9'd20;
        u_logic.u_boss.boss_state          = 2'd2;
        u_logic.u_boss.boss_timer          = 8'd1;
        step_ticks(1);
        save_frame_ppm("6_die.ppm");

        // 7. Victory Screen
        $display("\n[7/7] Capturing Victory Screen...");
        @(negedge clk);
        rst = 1'b1;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        @(negedge clk);
        u_logic.u_item.current_form = 3'd4;
        u_logic.u_boss.boss_hp      = 17'd0;
        u_logic.u_boss.boss_dt      = 6'd2;
        step_ticks(2);
        save_frame_ppm("7_win.ppm");

        $finish;
    end

endmodule
