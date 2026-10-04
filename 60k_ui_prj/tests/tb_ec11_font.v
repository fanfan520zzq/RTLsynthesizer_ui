`timescale 1ns/1ps
module tb_ec11_font;
    reg clk=0;
    always #5 clk=~clk;
    reg [6:0] char_code=0;
    reg [3:0] row=0;
    wire [7:0] pixels;
    reg [7:0] expected [0:1519];
    ui_ec11_font_rom dut (
        .clk(clk),.char_code(char_code),.row(row),.pixels(pixels)
    );
    integer ch,r;
    task sample;
        input integer code,line_index;
        input [7:0] value;
        begin
            @(negedge clk); char_code=code; row=line_index;
            @(posedge clk); #1;
            if(pixels!==value) $fatal(1,"ROM glyph %0d row %0d got %h expected %h",code,line_index,pixels,value);
        end
    endtask
    initial begin
        $readmemh("../scenes/font_8x16.mem",expected);
        for(ch=32;ch<=126;ch=ch+1)
            for(r=0;r<16;r=r+1) sample(ch,r,expected[(ch-32)*16+r]);
        for(r=0;r<16;r=r+1) begin sample(0,r,0); sample(127,r,0); end
        // Known byte examples make orientation and cell shape explicit.
        sample(65,3,8'h38);
        sample(70,3,8'h7E);
        $display("PASS tb_ec11_font printable ASCII rows=1520 synchronous ROM/blank/bit order");
        $finish;
    end
    initial begin #30000; $fatal(1,"font watchdog"); end
endmodule
