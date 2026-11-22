`timescale 1ns / 1ps
// ============================================================================
//  Collectible Items, Random Corner Spawning, and Form Evolution Controller
// ============================================================================
module item_ctrl (
    input  wire        clk, rst, tick,
    input  wire        game_won,
    input  wire [9:0]  px, py,
    input  wire [3:0]  barrier_active,

    output reg  [3:0]  item_active = 4'b1111,
    output reg  [2:0]  current_form = 3'd0,
    output wire [39:0] flat_item_x, flat_item_y,
    output wire        item_picked,
    output wire [8:0]  next_max_hp
);
    reg [9:0] item_x [0:3], item_y [0:3];
    assign flat_item_x = {item_x[3], item_x[2], item_x[1], item_x[0]};
    assign flat_item_y = {item_y[3], item_y[2], item_y[1], item_y[0]};

    reg [1:0] rand_shift = 2'd0;
    always @(posedge clk) rand_shift <= rand_shift + 1'b1;

    // 4 Corner Positions for 960x640 Map (Left=160, Right=800, Top=150, Bottom=490)
    wire [9:0] ix0 = (rand_shift==0)?10'd160 : (rand_shift==1)?10'd800 : (rand_shift==2)?10'd800 : 10'd160;
    wire [9:0] iy0 = (rand_shift==0)?10'd150 : (rand_shift==1)?10'd150 : (rand_shift==2)?10'd490 : 10'd490;

    wire [9:0] ix1 = (rand_shift==0)?10'd800 : (rand_shift==1)?10'd800 : (rand_shift==2)?10'd160 : 10'd160;
    wire [9:0] iy1 = (rand_shift==0)?10'd150 : (rand_shift==1)?10'd490 : (rand_shift==2)?10'd490 : 10'd150;

    wire [9:0] ix2 = (rand_shift==0)?10'd800 : (rand_shift==1)?10'd160 : (rand_shift==2)?10'd160 : 10'd800;
    wire [9:0] iy2 = (rand_shift==0)?10'd490 : (rand_shift==1)?10'd490 : (rand_shift==2)?10'd150 : 10'd150;

    wire [9:0] ix3 = (rand_shift==0)?10'd160 : (rand_shift==1)?10'd160 : (rand_shift==2)?10'd800 : 10'd800;
    wire [9:0] iy3 = (rand_shift==0)?10'd490 : (rand_shift==1)?10'd150 : (rand_shift==2)?10'd150 : 10'd490;

    wire [9:0] target_x = item_x[current_form[1:0]];
    wire [9:0] target_y = item_y[current_form[1:0]];

    assign item_picked = !game_won && (current_form < 3'd4) && !barrier_active[current_form[1:0]] &&
                         item_active[current_form[1:0]] &&
                         (px + 10'd25 > target_x) && (px - 10'd25 < target_x) &&
                         (py + 10'd25 > target_y) && (py - 10'd25 < target_y);

    assign next_max_hp = (current_form == 3'd0) ? 9'd150 :
                         (current_form == 3'd1) ? 9'd200 :
                         (current_form == 3'd2) ? 9'd250 : 9'd300;

    always @(posedge clk) begin
        if (rst) begin
            item_active  <= 4'b1111;
            current_form <= 3'd0;
            item_x[0] <= ix0; item_y[0] <= iy0;
            item_x[1] <= ix1; item_y[1] <= iy1;
            item_x[2] <= ix2; item_y[2] <= iy2;
            item_x[3] <= ix3; item_y[3] <= iy3;
        end else if (tick) begin
            if (item_picked) begin
                item_active[current_form[1:0]] <= 1'b0;
                current_form                   <= current_form + 1'b1;
            end
        end
    end

endmodule
