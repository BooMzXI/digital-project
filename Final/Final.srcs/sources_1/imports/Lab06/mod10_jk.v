`timescale 1ns / 1ps
//==============================================================================
// MOD-10 counter (0-9) built from JK flip-flops
// Board : Digilent Nexys A7-100T      Tool : Vivado 2024.2
//
// CPU_RESETN : reset, active LOW      SW[0]    : 1 = count, 0 = hold
// LED[3:0]   : Q3..Q0                 7-seg    : digit on AN[0]
// Signals ending in _n are active LOW.
//
// STUDENT FILE : complete module mod10_jk from the circuit diagram (Part 2)
//==============================================================================

//------------------------------------------------------------------------------
// Top level
//------------------------------------------------------------------------------
module mod10_top #(
    parameter integer DIV = 100_000_000          // count rate = 100 MHz / DIV
)(
    input  wire       CLK100MHZ,
    input  wire       CPU_RESETN,
    input  wire [0:0] SW,
    output wire [3:0] LED,
    output wire       CA, CB, CC, CD, CE, CF, CG, DP,
    output wire [7:0] AN
);
    wire       tick_1hz;
    wire       count_en = tick_1hz & SW[0];
    wire [3:0] count;
    wire [6:0] seg_n;                            // {g,f,e,d,c,b,a}

    tick_gen #(.DIV(DIV)) u_tick_gen (
        .clk     (CLK100MHZ),
        .reset_n (CPU_RESETN),
        .tick    (tick_1hz)
    );

    mod10_jk u_counter (
        .clk     (CLK100MHZ),
        .clear_n (CPU_RESETN),
        .en      (count_en),
        .count   (count)
    );

    seg7_dec u_seg7 (
        .digit   (count),
        .seg_n   (seg_n)
    );

    assign LED                         = count;
    assign {CG, CF, CE, CD, CC, CB, CA} = seg_n;
    assign DP                          = 1'b1;          // off
    assign AN                          = 8'b1111_1110;  // AN[0] only
endmodule

//------------------------------------------------------------------------------
// MOD-10 counter: 4 JK flip-flops on a shared clock
// en = 0 forces J = K = 0 (hold), so the count changes only when en = 1.
//------------------------------------------------------------------------------
module mod10_jk (
    input  wire       clk,
    input  wire       clear_n,
    input  wire       en,
    output wire [3:0] count                      // count[3] = Q3 (MSB)
);
    wire Q0 = count[0];
    wire Q1 = count[1];
    wire Q2 = count[2];
    wire Q3 = count[3];

    //========== Part 2 : WRITE YOUR CODE FROM THE CIRCUIT DIAGRAM ==========
    // FF0 is done for you as an example. Write FF1, FF2 and FF3 the same way.

    // (a) J/K logic : one line for each J and K input
    wire J0 = 1'b1;           wire K0 = 1'b1;
    wire J1 = Q0&(~Q3);       wire K1 = Q0;
    wire J2 = Q0&Q1;          wire K2 = J2;
    wire J3 = (Q0&Q1)&Q2;       wire K3 = Q0;
    // TODO : J1, K1, J2, K2, J3, K3


    // (b) Flip-flops : one jkff instance per flip-flop, named FF0 .. FF3
    jkff FF0 (.J(J0 & en), .K(K0 & en),
              .Clock(clk), .Clearn(clear_n), .Q(count[0]));
    jkff FF1 (.J(J1 & en), .K(K1 & en),
              .Clock(clk), .Clearn(clear_n), .Q(count[1]));
    jkff FF2 (.J(J2 & en), .K(K2 & en),
              .Clock(clk), .Clearn(clear_n), .Q(count[2]));
    jkff FF3 (.J(J3 & en), .K(K3 & en),
              .Clock(clk), .Clearn(clear_n), .Q(count[3]));
    // TODO : FF1, FF2, FF3


    //=======================================================================
endmodule

//------------------------------------------------------------------------------
// JK flip-flop from a D flip-flop: Q(next) = J·Q' + K'·Q
//------------------------------------------------------------------------------
module jkff (
    input  wire J,
    input  wire K,
    input  wire Clock,
    input  wire Clearn,
    output wire Q
);
    wire D = (J & ~Q) | (~K & Q);

    dff_aclr ff0 (.D(D), .Clock(Clock), .Clearn(Clearn), .Q(Q));
endmodule

//------------------------------------------------------------------------------
// D flip-flop, rising edge, asynchronous active-LOW clear
//------------------------------------------------------------------------------
module dff_aclr (
    input  wire D,
    input  wire Clock,
    input  wire Clearn,
    output reg  Q
);
    always @(posedge Clock or negedge Clearn)
        if (!Clearn) Q <= 1'b0;
        else         Q <= D;
endmodule

//------------------------------------------------------------------------------
// Tick generator: 1-clock-wide pulse every DIV clocks
//------------------------------------------------------------------------------
module tick_gen #(
    parameter integer DIV = 100_000_000
)(
    input  wire clk,
    input  wire reset_n,
    output reg  tick
);
    reg [31:0] clk_count;

    always @(posedge clk or negedge reset_n)
        if (!reset_n) begin
            clk_count <= 32'd0;
            tick      <= 1'b0;
        end else if (clk_count == DIV - 1) begin
            clk_count <= 32'd0;
            tick      <= 1'b1;
        end else begin
            clk_count <= clk_count + 1'b1;
            tick      <= 1'b0;
        end
endmodule

//------------------------------------------------------------------------------
// 7-segment decoder, active LOW: seg_n = {g,f,e,d,c,b,a}
//------------------------------------------------------------------------------
module seg7_dec (//
    input  wire [3:0] digit,
    output reg  [6:0] seg_n
);
    always @(*)
        case (digit)
            4'd0:    seg_n = 7'b100_0000;
            4'd1:    seg_n = 7'b111_1001;
            4'd2:    seg_n = 7'b010_0100;
            4'd3:    seg_n = 7'b011_0000;
            4'd4:    seg_n = 7'b001_1001;
            4'd5:    seg_n = 7'b001_0010;
            4'd6:    seg_n = 7'b000_0010;
            4'd7:    seg_n = 7'b111_1000;
            4'd8:    seg_n = 7'b000_0000;
            4'd9:    seg_n = 7'b001_0000;
            default: seg_n = 7'b011_1111;        // "-"
        endcase
endmodule
