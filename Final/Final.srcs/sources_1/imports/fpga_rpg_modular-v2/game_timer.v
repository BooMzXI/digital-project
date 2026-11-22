`timescale 1ns / 1ps
// ============================================================================
//  7-Segment Game Timer (MM:SS) & Current Form Display Multiplexer
// ============================================================================
module game_timer (
    input  wire       clk, rst,
    input  wire       game_won,
    input  wire [8:0] player_hp,
    input  wire [2:0] current_form,
    output wire       CA, CB, CC, CD, CE, CF, CG, DP,
    output wire [7:0] AN
);
    wire tick_1sec, tick_fast;
    tick_gen #(.DIV(25_000_000)) u_tick_1sec (.clk(clk), .reset_n(~rst), .tick(tick_1sec));
    tick_gen #(.DIV(25_000))     u_tick_fast (.clk(clk), .reset_n(~rst), .tick(tick_fast));

    reg [3:0] sec_0 = 4'd0, sec_1 = 4'd0, min_0 = 4'd0, min_1 = 4'd0;
    always @(posedge clk) begin
        if (rst) begin
            sec_0 <= 4'd0; sec_1 <= 4'd0; min_0 <= 4'd0; min_1 <= 4'd0;
        end else if (tick_1sec && !game_won && player_hp > 0) begin
            if (sec_0 == 4'd9) begin
                sec_0 <= 4'd0;
                if (sec_1 == 4'd5) begin
                    sec_1 <= 4'd0;
                    if (min_0 == 4'd9) begin
                        min_0 <= 4'd0;
                        if (min_1 < 4'd9) min_1 <= min_1 + 1'b1;
                    end else min_0 <= min_0 + 1'b1;
                end else sec_1 <= sec_1 + 1'b1;
            end else sec_0 <= sec_0 + 1'b1;
        end
    end

    reg [2:0] scan_sel = 3'd0;
    always @(posedge clk) begin
        if (tick_fast) scan_sel <= scan_sel + 1'b1;
    end

    reg [3:0] current_digit;
    reg [7:0] an_temp;
    always @(*) begin
        case (scan_sel)
            3'd0:    begin current_digit = sec_0;                an_temp = 8'b1111_1110; end
            3'd1:    begin current_digit = sec_1;                an_temp = 8'b1111_1101; end
            3'd2:    begin current_digit = min_0;                an_temp = 8'b1111_1011; end
            3'd3:    begin current_digit = min_1;                an_temp = 8'b1111_0111; end
            3'd7:    begin current_digit = {1'b0, current_form}; an_temp = 8'b0111_1111; end
            default: begin current_digit = 4'd0;                 an_temp = 8'b1111_1111; end
        endcase
    end

    wire [6:0] seg_n;
    seg7_dec u_seg7 (.digit(current_digit), .seg_n(seg_n));
    assign {CG, CF, CE, CD, CC, CB, CA} = seg_n;
    assign DP = (scan_sel == 3'd2) ? 1'b0 : 1'b1;
    assign AN = an_temp;

endmodule
