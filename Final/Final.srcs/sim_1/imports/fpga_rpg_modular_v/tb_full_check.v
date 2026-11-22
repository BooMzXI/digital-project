`timescale 1ns / 1ps
// ============================================================================
//  7-Scene Visual Verification Testbench (Modular Architecture)
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
    wire         back, mirror, moving, adv;
    wire         is_attacking, player_hit_pulse;
    wire [13:0]  p_dmg;
    wire [8:0]   player_hp, player_max_hp;

    wire [3:0]   item_active;
    wire [2:0]   current_form;
    wire [39:0]  flat_item_x, flat_item_y;
    wire         item_picked;
    wire [8:0]   next_max_hp;

    wire [159:0] flat_minion_x, flat_minion_y;
    wire [207:0] flat_minion_hp;
    wire [1:0]   minion_state;
    wire [15:0]  minion_active_atk;
    wire [3:0]   barrier_active;
    wire [15:0]  flat_minion_dying;
    wire         minion_dmg_to_player;

    wire [9:0]   boss_x, boss_y;
    wire [1:0]   boss_state;
    wire [16:0]  boss_hp;
    wire         boss_dying;
    wire         game_won;
    wire         boss_dmg_to_player;

    wire [3:0]   VGA_R, VGA_G, VGA_B;
    wire         VGA_HS, VGA_VS;

    player u_player (
        .clk(clk), .rst(rst), .tick(tick), .btn(btn),
        .btn_attack(btn_attack), .sw0(sw0),
        .current_form(current_form),
        .flat_item_x(flat_item_x), .flat_item_y(flat_item_y),
        .barrier_active(barrier_active),
        .item_picked(item_picked), .next_max_hp(next_max_hp),
        .boss_dmg_to_player(boss_dmg_to_player),
        .minion_dmg_to_player(minion_dmg_to_player),
        .game_won(game_won),
        .px(px), .py(py), .cam_x(cam_x), .cam_y(cam_y),
        .back(back), .mirror(mirror), .moving(moving), .adv(adv),
        .is_attacking(is_attacking), .player_hit_pulse(player_hit_pulse),
        .p_dmg(p_dmg),
        .player_hp(player_hp), .player_max_hp(player_max_hp)
    );

    item_ctrl u_item (
        .clk(clk), .rst(rst), .tick(tick),
        .game_won(game_won), .px(px), .py(py),
        .barrier_active(barrier_active),
        .item_active(item_active), .current_form(current_form),
        .flat_item_x(flat_item_x), .flat_item_y(flat_item_y),
        .item_picked(item_picked), .next_max_hp(next_max_hp)
    );

    minion_ctrl u_minion (
        .clk(clk), .rst(rst), .tick(tick),
        .game_won(game_won), .px(px), .py(py), .player_hp(player_hp),
        .current_form(current_form),
        .flat_item_x(flat_item_x), .flat_item_y(flat_item_y),
        .player_hit_pulse(player_hit_pulse), .p_dmg(p_dmg),
        .flat_minion_x(flat_minion_x), .flat_minion_y(flat_minion_y),
        .flat_minion_hp(flat_minion_hp), .minion_state(minion_state),
        .minion_active_atk(minion_active_atk),
        .barrier_active(barrier_active),
        .flat_minion_dying(flat_minion_dying),
        .minion_dmg_to_player(minion_dmg_to_player)
    );

    boss_ctrl u_boss (
        .clk(clk), .rst(rst), .tick(tick),
        .px(px), .py(py), .player_hp(player_hp),
        .player_hit_pulse(player_hit_pulse), .p_dmg(p_dmg),
        .boss_x(boss_x), .boss_y(boss_y),
        .boss_state(boss_state), .boss_hp(boss_hp),
        .boss_dying(boss_dying), .game_won(game_won),
        .boss_dmg_to_player(boss_dmg_to_player)
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
        .minion_active_atk(minion_active_atk),
        .barrier_active(barrier_active),
        .boss_dying(boss_dying), .flat_minion_dying(flat_minion_dying), .game_won(game_won),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS)
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
        $display("   STARTING 7-SCENE MODULAR VERIFICATION SIMULATION      ");
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
        u_player.px       = boss_x + 10'd65;
        u_player.py       = boss_y;
        u_boss.boss_state = 2'd2;
        u_boss.boss_timer = 8'd1;
        step_ticks(1);
        save_frame_ppm("2_boss_attack.ppm");

        // 3. Left Wall Collision & Bottom-Left Minions
        $display("\n[3/7] Capturing Left Wall Collision & Bottom-Left Minions...");
        @(negedge clk);
        u_boss.boss_state = 2'd0;
        u_player.px       = 10'd76;
        u_player.py       = 10'd490;
        btn               = 4'b0010;
        repeat (3) @(posedge clk);
        step_ticks(20);
        @(negedge clk);
        btn               = 4'b0000;
        step_ticks(1);
        save_frame_ppm("3_left_edge_minions.ppm");

        // 4. Minion Patrol Movement
        $display("\n[4/7] Capturing Minion Patrol Movement...");
        step_ticks(80);
        save_frame_ppm("4_minions_moved.ppm");

        // 5. Minion Attack at Exact Top Red-Border Edge (py = m_y[8] - 20)
        $display("\n[5/7] Capturing Minion Attack at Exact Top Red-Border Edge...");
        @(negedge clk);
        u_player.px                = u_minion.m_x[8];
        u_player.py                = u_minion.m_y[8] - 10'd20;
        u_minion.minion_state      = 2'd2;
        u_minion.minion_timer      = 8'd1;
        u_minion.minion_active_atk = 16'd1 << 8;
        step_ticks(1);
        save_frame_ppm("5_minion_attack.ppm");

        // 6. Death Screen
        $display("\n[6/7] Capturing Death Screen...");
        @(negedge clk);
        u_minion.minion_state      = 2'd0;
        u_minion.minion_active_atk = 16'd0;
        u_player.px                = boss_x;
        u_player.py                = boss_y;
        u_player.player_hp         = 9'd20;
        u_boss.boss_state          = 2'd2;
        u_boss.boss_timer          = 8'd1;
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
        u_item.current_form = 3'd4;
        u_boss.boss_hp      = 17'd0;
        u_boss.boss_dt      = 6'd2;
        step_ticks(2);
        save_frame_ppm("7_win.ppm");

        $finish;
    end

endmodule
