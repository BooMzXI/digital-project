`timescale 1ns / 1ps
//=============================================================================
// CPE222 : Digital Electronics and Logic Design 1 / 2026
// LAB08  : VGA Walk Demo (FPGA)
// File   : lab08.v
//
//   vga_sync ....................... Part A, VGA timing counters   (you write)
//   dffe_aclr ...................... D flip-flop with enable       (given)
//   walk_fsm ....................... Part C, walking-picture FSM   (you write)
//=============================================================================


//=============================================================================
// PART A : VGA 640 x 480 @ 60 Hz timing generator
//   clk = 25 MHz pixel clock.  One clock = one pixel.
//   x counts 0 .. 799 along a line, y counts 0 .. 524 lines.
//   hsync and vsync are active LOW.  video_on = 1 inside the 640 x 480 picture.
//=============================================================================
module vga_sync (
    input  wire       clk,
    input  wire       rst,             // synchronous, active HIGH
    output reg  [9:0] x = 10'd0,       // 0 .. 799
    output reg  [9:0] y = 10'd0,       // 0 .. 524
    output wire       hsync,
    output wire       vsync,
    output wire       video_on
);
    localparam H_VISIBLE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48;
    localparam V_VISIBLE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33;
    localparam H_TOTAL = H_VISIBLE + H_FP + H_SYNC + H_BP;   // 800
    localparam V_TOTAL = V_VISIBLE + V_FP + V_SYNC + V_BP;   // 525

     //========== Part A : WRITE YOUR CODE HERE ==========================
    // Replace each value with an expression.  You may use the localparam
    // names above, e.g.  wire x_end = (x == H_TOTAL - 1);
    wire       x_end    = x == (H_TOTAL -1);     // x is at the last pixel of a line
    wire       y_end    = y == (V_TOTAL -1);     // y is at the last line of a frame
    wire [9:0] x_next   = x_end?10'd0:(x+10'd1);    // value of x after the next clock
    wire [9:0] y_next   = x_end?(y_end?10'd0:y+10'd1):y;    // value of y after the next clock

    assign hsync    = ~((x>=H_VISIBLE+H_FP)&&(x<H_VISIBLE+H_FP+H_SYNC));         // LOW during the horizontal sync pulse
    assign vsync    = ~((y>=V_VISIBLE+V_FP)&&(y<V_VISIBLE+V_FP+V_SYNC));         // LOW during the vertical sync pulse
    assign video_on = (x<H_VISIBLE) && (y<V_VISIBLE);      // HIGH inside the 640 x 480 picture
    //==================================================================


    always @(posedge clk) begin
        if (rst) begin
            x <= 10'd0;
            y <= 10'd0;
        end else begin
            x <= x_next;
            y <= y_next;
        end
    end
endmodule


//=============================================================================
// D flip-flop, rising edge, active-LOW asynchronous clear, clock enable
//   En = 0 : hold        En = 1 : Q <= D
//=============================================================================
module dffe_aclr (
    input  wire D,
    input  wire En,
    input  wire Clock,
    input  wire Clearn,
    output reg  Q
);
    always @(posedge Clock or negedge Clearn)
        if (!Clearn)  Q <= 1'b0;
        else if (En)  Q <= D;
endmodule


//=============================================================================
// PART C : walking-picture FSM (Moore)
//   The FSM changes state only when adv = 1 (one clock, from player).
//   Input m = 1 while a direction button is held.
//   States (y2y1) :  S0 = 00 stand     S1 = 01 left foot forward
//                    S2 = 10 stand     S3 = 11 right foot forward
//   step = 0 : stand picture   step = 1 : step picture A   step = 2 : step picture B
//=============================================================================
module walk_fsm (
    input  wire       clk,
    input  wire       clear_n,
    input  wire       adv,
    input  wire       m,
    output wire [1:0] step,
    output wire [1:0] state            // state[1] = y2, state[0] = y1
);
    wire y1 = state[0];
    wire y2 = state[1];

    //========== Part C : WRITE THE EQUATIONS FROM YOUR K-MAPS ==========
    wire D1 = m&~y1;                  // next value of y1
    wire D2 = m&y1;                  // next value of y2
    assign step[0] = y1;
    assign step[1] = y2;
    //==================================================================

    dffe_aclr FF1 (.D(D1), .En(adv), .Clock(clk), .Clearn(clear_n), .Q(state[0]));
    dffe_aclr FF2 (.D(D2), .En(adv), .Clock(clk), .Clearn(clear_n), .Q(state[1]));
endmodule
