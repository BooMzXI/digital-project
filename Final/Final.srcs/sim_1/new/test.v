`timescale 1ns / 1ps

module tb_vga_snapshot();
    // 1. ประกาศตัวแปรจำลอง Input/Output
    reg CLK100MHZ = 0;
    reg CPU_RESETN = 0;
    reg BTNU = 0, BTND = 0, BTNL = 0, BTNR = 0, BTNC = 0;
    reg [0:0] SW = 0; // สวิตช์ความเร็วที่เพิ่งเพิ่มเข้ามา
    
    wire [3:0] VGA_R, VGA_G, VGA_B;
    wire VGA_HS, VGA_VS;
    wire [1:0] LED;
    wire CA, CB, CC, CD, CE, CF, CG, DP;
    wire [7:0] AN;

    // 2. เรียกใช้งานโมดูล Top ล่าสุด
    lab08_top uut (
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .BTNU(BTNU), .BTND(BTND), .BTNL(BTNL), .BTNR(BTNR), .BTNC(BTNC),
        .SW(SW), // <--- โยงสายไฟสวิตช์
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS),
        .LED(LED), .CA(CA), .CB(CB), .CC(CC), .CD(CD), .CE(CE), .CF(CF), .CG(CG), .DP(DP), .AN(AN)
    );

    // 3. สร้าง Clock 100MHz
    always #5 CLK100MHZ = ~CLK100MHZ;

    integer file;
    integer frame_count = 0;

    initial begin
        // สร้างไฟล์รูปภาพนามสกุล .ppm (เปิดด้วยโปรแกรมดูรูป หรือ Photopea.com)
        file = $fopen("game_screen.ppm", "w");
        $fwrite(file, "P3\n640 480\n15\n");

        // จังหวะเริ่มเกม
        CPU_RESETN = 0; 
        #100;
        CPU_RESETN = 1; 
        
        // เปิดสวิตช์วิ่งเร็ว
        SW[0] = 1;
        
        // รอเวลาให้จอภาพเริ่มวาดเฟรมแรก แล้วกดปุ่มตี (เพื่อถ่ายรูปท่าถือดาบ)
        #15000000; 
        BTNC = 1;
    end

    // 4. ดักจับการขึ้นเฟรมใหม่ (อิงจาก VSYNC)
    always @(negedge VGA_VS) begin
        frame_count = frame_count + 1;
        // 1. แก้เป็นเลข 3 เพื่อให้ระบบทำงานจบเฟรมที่ 2 ก่อนหยุด
        if (frame_count == 3) begin
            $fclose(file);
            $display("========================================");
            $display(" SUCCESS: Image saved as game_screen.ppm");
            $display("========================================");
            $finish;
        end
    end

    // 5. บันทึกค่าสี 12-bit ลงไฟล์เฉพาะช่วงที่วาดภาพในเฟรมที่ 1
    always @(posedge uut.clk) begin
        // 2. แก้เป็นเลข 2 เพื่อถ่ายรูปในเฟรมที่ 2 แทนเฟรมแรก
        if (frame_count == 2 && uut.video_on) begin
            $fwrite(file, "%d %d %d\n", VGA_R, VGA_G, VGA_B);
        end
    end
endmodule