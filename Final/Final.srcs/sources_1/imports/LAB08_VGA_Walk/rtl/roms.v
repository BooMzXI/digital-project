`timescale 1ns / 1ps
// ROMs loaded from .mem files (given - do not modify)

// single-port ROM, 1 clock read latency, Block RAM
module rom_1p #(
    parameter DW = 8, AW = 16, DEPTH = 1 << AW,
    parameter FILE = ""
) (
    input  wire          clk,
    input  wire [AW-1:0] addr,
    output reg  [DW-1:0] q
);
    (* rom_style = "block" *) reg [DW-1:0] mem [0:DEPTH-1];
    initial $readmemh(FILE, mem);
    always @(posedge clk) q <= mem[addr];
endmodule

// small palette / sprite ROM in LUTs, 1 clock read latency
module rom_lut #(
    parameter DW = 12, AW = 8,
    parameter FILE = ""
) (
    input  wire          clk,
    input  wire [AW-1:0] addr,
    output reg  [DW-1:0] q
);
    (* rom_style = "distributed" *) reg [DW-1:0] mem [0:(1<<AW)-1];
    initial $readmemh(FILE, mem);
    always @(posedge clk) q <= mem[addr];
endmodule

// ==========================================
// NEW: Dual-Port ROM for sharing BRAM
// ==========================================
// dual-port ROM, 1 clock read latency, Block RAM
module rom_2p #(
    parameter DW = 8, AW = 16, DEPTH = 1 << AW,
    parameter FILE = ""
) (
    input  wire          clk,
    input  wire [AW-1:0] addr_a,
    output reg  [DW-1:0] q_a,
    input  wire [AW-1:0] addr_b,
    output reg  [DW-1:0] q_b
);
    (* rom_style = "block" *) reg [DW-1:0] mem [0:DEPTH-1];
    initial $readmemh(FILE, mem);
    always @(posedge clk) begin
        q_a <= mem[addr_a];
        q_b <= mem[addr_b];
    end
endmodule