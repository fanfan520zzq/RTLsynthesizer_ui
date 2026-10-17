`timescale 1ns / 1ps
// Small behavioral check for the 640x480 diagnostic raster and color bars.
module tb_diag_640x480;
    reg clk;
    reg rst_n;
    wire [9:0] x;
    wire [9:0] y;
    wire de;
    wire hsync;
    wire vsync;
    wire frame_start;
    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;

    video_timing_640x480 timing (
        .clk(clk), .rst_n(rst_n), .x(x), .y(y), .de(de),
        .hsync(hsync), .vsync(vsync), .frame_start(frame_start)
    );
    colorbars_640x480 bars (
        .de(de), .x(x), .y(y), .red(red), .green(green), .blue(blue)
    );

    always #1 clk = ~clk;

    task check_bar;
        input [9:0] sample_x;
        input [23:0] expected;
        begin
            while (!(de && (x == sample_x) && (y == 10'd10)))
                @(posedge clk);
            #0;
            if ({red, green, blue} !== expected) begin
                $display("FAIL bar x=%0d got=%h expected=%h", sample_x,
                         {red, green, blue}, expected);
                $finish;
            end
        end
    endtask

    integer line_cycles;
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        check_bar(10'd0,   24'hffffff);
        check_bar(10'd80,  24'hffff00);
        check_bar(10'd160, 24'h00ffff);
        check_bar(10'd240, 24'h00ff00);
        check_bar(10'd320, 24'hff00ff);
        check_bar(10'd400, 24'hff0000);
        check_bar(10'd480, 24'h0000ff);
        check_bar(10'd560, 24'h000000);

        // Start at a known frame origin, then measure one full 800x525 frame.
        while (!(de && (x == 10'd0) && (y == 10'd0)))
            @(posedge clk);
        line_cycles = 0;
        while (!frame_start) begin
            @(posedge clk);
            line_cycles = line_cycles + 1;
        end
        if (line_cycles < 419000 || line_cycles > 421000) begin
            $display("FAIL frame length=%0d, expected 420000 clocks", line_cycles);
            $finish;
        end
        $display("PASS 640x480 timing and color bars");
        $finish;
    end
endmodule
