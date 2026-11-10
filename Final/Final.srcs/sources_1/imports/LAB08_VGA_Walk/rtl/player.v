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
    output reg  [9:0] px = 10'd210,
    output reg  [9:0] py = 10'd655,
    output reg  [8:0] cam_x = 0,
    output reg  [9:0] cam_y = 0,
    output reg        back = 0,          // 1 = walking away from the screen
    output reg        mirror = 0,        // the sprites face left; mirror them to face right
    output wire       moving,            // a direction button is held
    output wire       adv                // walk_fsm may change state now
);
    localparam STEP = 2;

    reg [3:0] btn_s = 0, b = 0;          // buttons, moved to this clock
    reg [2:0] frames = 0;                // frames since the last adv while walking

    wire up = b[3], down = b[2], left = b[1], right = b[0];
    assign moving = up | down | left | right;
    assign adv    = tick && (!moving || frames == 3'd7);

    always @(posedge clk) begin
        btn_s <= btn;
        b     <= btn_s;
        if (rst) begin
            px <= 10'd210;  py <= 10'd655;  back <= 1'b0;  mirror <= 1'b0;  frames <= 3'd0;
        end else if (tick) begin
            if (left  && px > 16)  begin px <= px - STEP;  mirror <= 1'b0; end
            if (right && px < 494) begin px <= px + STEP;  mirror <= 1'b1; end
            if (up    && py > 48)  begin py <= py - STEP;  back   <= 1'b1; end
            if (down  && py < 766) begin py <= py + STEP;  back   <= 1'b0; end
            frames <= moving ? frames + 1'b1 : 3'd0;

            // the camera keeps the player in the middle, but stays on the map
            cam_x <= (px < 160) ? 9'd0  : (px > 352) ? 9'd192  : px - 10'd160;
            cam_y <= (py < 120) ? 10'd0 : (py > 648) ? 10'd528 : py - 10'd120;
        end
    end
endmodule
