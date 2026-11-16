`timescale 1ns / 1ps
module tb_lab08;

    // Inputs
    reg CLK100MHZ;
    reg CPU_RESETN;
    reg BTNU, BTND, BTNL, BTNR, BTNC;
    reg [0:0] SW;

    // Outputs
    wire [3:0] VGA_R, VGA_G, VGA_B;
    wire VGA_HS, VGA_VS;
    wire [1:0] LED;
    wire CA, CB, CC, CD, CE, CF, CG, DP;
    wire [7:0] AN;

    // Instantiate the Unit Under Test (UUT)
    lab08_top uut (
        .CLK100MHZ(CLK100MHZ), 
        .CPU_RESETN(CPU_RESETN), 
        .BTNU(BTNU), .BTND(BTND), .BTNL(BTNL), .BTNR(BTNR), .BTNC(BTNC), 
        .SW(SW), 
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), 
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), 
        .LED(LED), 
        .CA(CA), .CB(CB), .CC(CC), .CD(CD), .CE(CE), .CF(CF), .CG(CG), .DP(DP), 
        .AN(AN)
    );

    // 100 MHz Clock Generation (10ns period)
    always #5 CLK100MHZ = ~CLK100MHZ;

    // --- Image Capture Logic ---
    integer file;
    integer frame_count = 0;
    integer pixel_count = 0;
    
    initial begin
        // Open file to write the PPM image
        file = $fopen("frame.ppm", "w");
        // Write PPM Header: P3 format, 640x480 resolution, max color value 15
        $fwrite(file, "P3\n640 480\n15\n"); 
    end
    
    always @(negedge VGA_VS) begin
        frame_count = frame_count + 1;
    end
    
    // Capture pixels during the 3rd frame
    always @(posedge uut.clk) begin
        if (frame_count == 3) begin
            // Accessing internal video_on signal from vga_sync module
            if (uut.u_sync.video_on) begin
                $fwrite(file, "%d %d %d\n", VGA_R, VGA_G, VGA_B);
                pixel_count = pixel_count + 1;
                
                // End simulation when full frame is captured
                if (pixel_count == 640*480) begin
                    $fclose(file);
                    $display("=== FRAME CAPTURED to 'frame.ppm' ===");
                    $finish;
                end
            end
        end
    end

    // --- Control Logic ---
    initial begin
        CLK100MHZ = 0;
        CPU_RESETN = 0; // Active low reset
        BTNU = 0; BTND = 0; BTNL = 0; BTNR = 0; BTNC = 0;
        SW = 0;

        #100;
        CPU_RESETN = 1; // Release reset
        
        // The image capture logic above will automatically finish the simulation 
        // after capturing exactly one frame (around 50ms of simulation time).
    end
endmodule