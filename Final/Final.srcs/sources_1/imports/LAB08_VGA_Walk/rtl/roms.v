`timescale 1ns / 1ps
// ROMs loaded from .mem files

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
// Banked Dual-Port ROM for Sprite (No RAMB36E1 Cascade)
// ==========================================
module rom_2p #(
    parameter DW = 8, AW = 17, DEPTH = 114688,
    parameter FILE = ""
) (
    input  wire          clk,
    input  wire [AW-1:0] addr_a,
    output reg  [DW-1:0] q_a,
    input  wire [AW-1:0] addr_b,
    output reg  [DW-1:0] q_b
);
    // Split 114,688 words into 3x32K + 1x16K banks (max 32K per bank prevents cascading)
    (* rom_style = "block" *) reg [DW-1:0] mem0 [0:32767];
    (* rom_style = "block" *) reg [DW-1:0] mem1 [0:32767];
    (* rom_style = "block" *) reg [DW-1:0] mem2 [0:32767];
    (* rom_style = "block" *) reg [DW-1:0] mem3 [0:16383];

    initial begin : init_spr
        reg [DW-1:0] init_mem [0:114687];
        integer idx;
        for (idx = 0; idx < 114688; idx = idx + 1) begin
            init_mem[idx] = {DW{1'b0}};
        end
        $readmemh(FILE, init_mem);
        for (idx = 0; idx < 114688; idx = idx + 1) begin
            if (idx < 32768)
                mem0[idx] = init_mem[idx];
            else if (idx < 65536)
                mem1[idx - 32768] = init_mem[idx];
            else if (idx < 98304)
                mem2[idx - 65536] = init_mem[idx];
            else
                mem3[idx - 98304] = init_mem[idx];
        end
    end

    always @(posedge clk) begin
        case (addr_a[16:15])
            2'b00: q_a <= mem0[addr_a[14:0]];
            2'b01: q_a <= mem1[addr_a[14:0]];
            2'b10: q_a <= mem2[addr_a[14:0]];
            2'b11: q_a <= mem3[addr_a[13:0]];
        endcase

        case (addr_b[16:15])
            2'b00: q_b <= mem0[addr_b[14:0]];
            2'b01: q_b <= mem1[addr_b[14:0]];
            2'b10: q_b <= mem2[addr_b[14:0]];
            2'b11: q_b <= mem3[addr_b[13:0]];
        endcase
    end
endmodule

// ==========================================
// Banked ROM for 800x512 Map (Saves 49 BRAMs)
// ==========================================
module rom_map_800x512 #(
    parameter DW = 7,
    parameter FILE = ""
) (
    input  wire          clk,
    input  wire [18:0]   addr,
    output reg  [DW-1:0] q
);
    // Split 409,600 words into 3 power-of-2 banks: 262144 + 131072 + 16384 = 409600
    (* rom_style = "block" *) reg [DW-1:0] mem0 [0:262143];
    (* rom_style = "block" *) reg [DW-1:0] mem1 [0:131071];
    (* rom_style = "block" *) reg [DW-1:0] mem2 [0:16383];

    initial begin : init_blk
        reg [DW-1:0] init_mem [0:409599];
        integer idx;
        for (idx = 0; idx < 409600; idx = idx + 1) begin
            init_mem[idx] = {DW{1'b0}};
        end
        $readmemh(FILE, init_mem);
        for (idx = 0; idx < 409600; idx = idx + 1) begin
            if (idx < 262144)
                mem0[idx] = init_mem[idx];
            else if (idx < 393216)
                mem1[idx - 262144] = init_mem[idx];
            else
                mem2[idx - 393216] = init_mem[idx];
        end
    end

    always @(posedge clk) begin
        if (!addr[18])
            q <= mem0[addr[17:0]];
        else if (!addr[17])
            q <= mem1[addr[16:0]];
        else
            q <= mem2[addr[13:0]];
    end
endmodule