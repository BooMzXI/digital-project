`timescale 1ns / 1ps
// ============================================================================
//  8x8 Bitmap Character ROM for Victory and Death End Screens
// ============================================================================
module font_8x8 (
    input  wire [7:0] char_code,
    input  wire [2:0] row,
    input  wire [2:0] col,
    output wire       pixel_on
);
    reg [7:0] row_bits;
    always @(*) begin
        case (char_code)
            "A": case (row)
                3'd0: row_bits = 8'b00111000;
                3'd1: row_bits = 8'b01000100;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b10000010;
                3'd4: row_bits = 8'b11111110;
                3'd5: row_bits = 8'b10000010;
                3'd6: row_bits = 8'b10000010;
                default: row_bits = 8'b00000000;
            endcase
            "C": case (row)
                3'd0: row_bits = 8'b01111100;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000000;
                3'd3: row_bits = 8'b10000000;
                3'd4: row_bits = 8'b10000000;
                3'd5: row_bits = 8'b10000010;
                3'd6: row_bits = 8'b01111100;
                default: row_bits = 8'b00000000;
            endcase
            "D": case (row)
                3'd0: row_bits = 8'b11111000;
                3'd1: row_bits = 8'b10000100;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b10000010;
                3'd4: row_bits = 8'b10000010;
                3'd5: row_bits = 8'b10000100;
                3'd6: row_bits = 8'b11111000;
                default: row_bits = 8'b00000000;
            endcase
            "E": case (row)
                3'd0: row_bits = 8'b11111110;
                3'd1: row_bits = 8'b10000000;
                3'd2: row_bits = 8'b10000000;
                3'd3: row_bits = 8'b11111100;
                3'd4: row_bits = 8'b10000000;
                3'd5: row_bits = 8'b10000000;
                3'd6: row_bits = 8'b11111110;
                default: row_bits = 8'b00000000;
            endcase
            "I": case (row)
                3'd0: row_bits = 8'b01111100;
                3'd1: row_bits = 8'b00010000;
                3'd2: row_bits = 8'b00010000;
                3'd3: row_bits = 8'b00010000;
                3'd4: row_bits = 8'b00010000;
                3'd5: row_bits = 8'b00010000;
                3'd6: row_bits = 8'b01111100;
                default: row_bits = 8'b00000000;
            endcase
            "O": case (row)
                3'd0: row_bits = 8'b01111100;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b10000010;
                3'd4: row_bits = 8'b10000010;
                3'd5: row_bits = 8'b10000010;
                3'd6: row_bits = 8'b01111100;
                default: row_bits = 8'b00000000;
            endcase
            "P": case (row)
                3'd0: row_bits = 8'b11111100;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b11111100;
                3'd4: row_bits = 8'b10000000;
                3'd5: row_bits = 8'b10000000;
                3'd6: row_bits = 8'b10000000;
                default: row_bits = 8'b00000000;
            endcase
            "R": case (row)
                3'd0: row_bits = 8'b11111100;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b11111100;
                3'd4: row_bits = 8'b10001000;
                3'd5: row_bits = 8'b10000100;
                3'd6: row_bits = 8'b10000010;
                default: row_bits = 8'b00000000;
            endcase
            "S": case (row)
                3'd0: row_bits = 8'b01111100;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000000;
                3'd3: row_bits = 8'b01111100;
                3'd4: row_bits = 8'b00000010;
                3'd5: row_bits = 8'b10000010;
                3'd6: row_bits = 8'b01111100;
                default: row_bits = 8'b00000000;
            endcase
            "T": case (row)
                3'd0: row_bits = 8'b11111110;
                3'd1: row_bits = 8'b00010000;
                3'd2: row_bits = 8'b00010000;
                3'd3: row_bits = 8'b00010000;
                3'd4: row_bits = 8'b00010000;
                3'd5: row_bits = 8'b00010000;
                3'd6: row_bits = 8'b00010000;
                default: row_bits = 8'b00000000;
            endcase
            "U": case (row)
                3'd0: row_bits = 8'b10000010;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b10000010;
                3'd4: row_bits = 8'b10000010;
                3'd5: row_bits = 8'b10000010;
                3'd6: row_bits = 8'b01111100;
                default: row_bits = 8'b00000000;
            endcase
            "V": case (row)
                3'd0: row_bits = 8'b10000010;
                3'd1: row_bits = 8'b10000010;
                3'd2: row_bits = 8'b10000010;
                3'd3: row_bits = 8'b10000010;
                3'd4: row_bits = 8'b01000100;
                3'd5: row_bits = 8'b00101000;
                3'd6: row_bits = 8'b00010000;
                default: row_bits = 8'b00000000;
            endcase
            "Y": case (row)
                3'd0: row_bits = 8'b10000010;
                3'd1: row_bits = 8'b01000100;
                3'd2: row_bits = 8'b00101000;
                3'd3: row_bits = 8'b00010000;
                3'd4: row_bits = 8'b00010000;
                3'd5: row_bits = 8'b00010000;
                3'd6: row_bits = 8'b00010000;
                default: row_bits = 8'b00000000;
            endcase
            default: row_bits = 8'b00000000;
        endcase
    end
    assign pixel_on = row_bits[3'd7 - col];
endmodule
