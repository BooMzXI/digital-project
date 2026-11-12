`timescale 1ns / 1ps
// Moves the player once per frame and keeps the camera around it.  (given - do not modify)
// (px, py) is the point between the feet, in map pixels.  The map is 512 x 768.
//
// It also makes the "adv" pulse for walk_fsm: while a button is held, adv comes
// every 8 frames (7.5 times a second); when no button is held, adv comes on the next
// frame so that the player stands still at once.
module player (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,              // one pulse per frame
    input  wire [3:0] btn,               // {up, down, left, right}
input  wire       btn_attack,
    output reg  [9:0] px = 10'd210,
    output reg  [9:0] py = 10'd655,
    output reg  [8:0] cam_x = 0,
    output reg  [9:0] cam_y = 0,
    output reg        back = 0,          // 1 = walking away from the screen
    output reg        mirror = 0,        // the sprites face left; mirror them to face right
    output wire       moving,            // a direction button is held
    output wire       adv,                // walk_fsm may change state now
    // ---  Output for item and form ---
    output reg  [2:0] item_active, // 3 item
    output reg  [2:0] current_form, // 3 form 0 normal 3 bit
    output wire [29:0] flat_item_x, // position X 3 item (10 bit each)
    output wire [29:0] flat_item_y ,
//attack check
output reg        is_attacking = 0 ,
output reg  [6:0] player_hp = 7'd64, // player health (Max 64)
//boss
output reg  [9:0] boss_x = 10'd250, // position
    output reg  [9:0] boss_y = 10'd200, 
    output reg  [1:0] boss_state = 0,   // 0=rest, 1=wait, 2=dmg, 3=die
    output reg  [7:0] boss_hp = 8'd128 // boss health (Max 128)
);
//walk
    localparam STEP = 2;

    reg [3:0] btn_s = 0, b = 0;          // buttons, moved to this clock
    reg [2:0] frames = 0;                // frames since the last adv while walking

    wire up = b[3], down = b[2], left = b[1], right = b[0];
    assign moving = up | down | left | right;
    assign adv    = tick && (!moving || frames == 3'd7);

//item
parameter NUM_ITEMS = 3;
    reg [9:0] item_x [0:NUM_ITEMS-1];
    reg [9:0] item_y [0:NUM_ITEMS-1];
    reg [2:0] form_grant [0:NUM_ITEMS-1];
//pack array to output
assign flat_item_x = {item_x[2], item_x[1], item_x[0]}; //for 3 item add more item[x]
    assign flat_item_y = {item_y[2], item_y[1], item_y[0]};
integer i;
//random for item
//X (0 ... 511)
reg [8:0] rand_x = 9'd0;
    // Y (0 ... 767)
    reg [9:0] rand_y = 10'd0;

reg [4:0] attack_timer = 0; //atk time

// --- player boss length ---
    wire [9:0] dx_b = (px > boss_x) ? (px - boss_x) : (boss_x - px);
    wire [9:0] dy_b = (py > boss_y) ? (py - boss_y) : (boss_y - py);
    
    // --- change dmg each form ---
    wire [7:0] p_dmg = (current_form == 3'd0) ? 8'd5 :
                       (current_form == 3'd1) ? 8'd10 :
                       (current_form == 3'd2) ? 8'd15 : 8'd20;

    reg [7:0] boss_timer = 0;

    always @(posedge clk) begin
        rand_x <= rand_x + 9'd73;
        rand_y <= rand_y + 10'd103;

        // scope in mape (Map 512 x 768) not to close to side
        if (rand_x > 9'd480) rand_x <= 9'd32; 
        if (rand_y > 10'd720) rand_y <= 10'd48;
    end

    always @(posedge clk) begin
        btn_s <= btn;
        b     <= btn_s;
        if (rst) begin
            px <= 10'd210;  py <= 10'd655;  back <= 1'b0;  mirror <= 1'b0;  frames <= 3'd0;
//item initial set
item_active <= 3'b111;
            current_form <= 3'd0;
//item position
           item_x[0] <= {1'b0, rand_x}; 
            item_y[0] <= rand_y; 
            form_grant[0] <= 3'd1;
            item_x[1] <= {1'b0, ~rand_x}; 
            item_y[1] <= {~rand_y[4:0], rand_y[9:5]}; 
            form_grant[1] <= 3'd2;
            item_x[2] <= {1'b0, rand_x[4:0], rand_x[8:5]};  
            item_y[2] <= ~rand_y; 
            form_grant[2] <= 3'd3;
//reset attacking
boss_hp <= 8'd128;
            player_hp <= 7'd64;
            boss_state <= 2'd0;
            boss_timer <= 8'd0;
            is_attacking <= 1'b0;
            attack_timer <= 5'd0;
        end else if (tick) begin
            if (player_hp > 0) begin // ถ้าตายเดินไม่ได้
                if (left  && px > 16)  begin px <= px - STEP;  mirror <= 1'b0; end
                if (right && px < 494) begin px <= px + STEP;  mirror <= 1'b1; end
                if (up    && py > 48)  begin py <= py - STEP;  back   <= 1'b1; end
                if (down  && py < 766) begin py <= py + STEP;  back   <= 1'b0; end
                frames <= moving ? frames + 1'b1 : 3'd0;
            end

            // the camera keeps the player in the middle, but stays on the map
            cam_x <= (px < 160) ? 9'd0  : (px > 352) ? 9'd192  : px - 10'd160;
            cam_y <= (py < 120) ? 10'd0 : (py > 648) ? 10'd528 : py - 10'd120;
// atk part
if (is_attacking) begin //15 frame per attack 
                attack_timer <= attack_timer + 1'b1;

	if (attack_timer == 5'd1) begin
                    if (boss_state != 2'd3 && dx_b <= 10'd20 && dy_b <= 10'd20) begin
                        if (boss_hp > p_dmg) boss_hp <= boss_hp - p_dmg;
                        else boss_hp <= 8'd0; // boss death
                    end
                end

                if (attack_timer >= 5'd15) begin //decrease time here
                    is_attacking <= 1'b0; 
                    attack_timer <= 5'd0;
                end
            end else if (btn_attack) begin
                // if click btn = atk
                is_attacking <= 1'b1;
                attack_timer <= 5'd0;
            end
//boss animation and machanic
if (boss_hp == 0) begin
                boss_state <= 2'd3; // 3 = บอสตาย
            end else begin
                case (boss_state)
                    2'd0: begin // Rest 2s
                        boss_timer <= boss_timer + 1'b1;
                        if (boss_timer >= 8'd120) begin 
                            boss_state <= 2'd1;
                            boss_timer <= 8'd0;
                        end
                    end
                    2'd1: begin // show red zone 1s
                        boss_timer <= boss_timer + 1'b1;
                        if (boss_timer >= 8'd60) begin 
                            boss_state <= 2'd2;
                            boss_timer <= 8'd0;
                        end
                    end
                    2'd2: begin // Damage & Delay 0.25s
                        boss_timer <= boss_timer + 1'b1;
                        if (boss_timer == 8'd1) begin
                            if (dx_b <= 10'd25 && dy_b <= 10'd25 && player_hp > 0) begin
                                if (player_hp > 7'd10) player_hp <= player_hp - 7'd10; // boss dmg 10
                                else player_hp <= 7'd0;
                            end
                        end
                        if (boss_timer >= 8'd15) begin 
                            boss_state <= 2'd0;
                            boss_timer <= 8'd0;
                        end
                    end
                endcase
            end

//item collition check
for (i = 0; i < NUM_ITEMS; i = i + 1) begin
                if (item_active[i] && (current_form == i) && 
                    (px + 16 > item_x[i]) && (px - 16 < item_x[i]) && 
                    (py + 16 > item_y[i]) && (py - 16 < item_y[i])) begin
                    
                    item_active[i] <= 1'b0;          // pickup
                    current_form <= form_grant[i];   // update form
                end
            end
        end

    end
endmodule
