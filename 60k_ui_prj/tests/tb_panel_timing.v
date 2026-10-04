`timescale 1ns/1ps
// Verify two complete rasters and reset; no TMDS electrical simulation.
module tb_panel_timing;
    reg clk = 0;
    reg reset = 1;
    always #5 clk = ~clk;
    wire [13:0] h, v, x, y;
    wire hs, vs, de, line_start;
    video_timing_ctrl dut (
        .pixel_clock(clk),
        .reset(reset),
        .ext_sync(1'b0),
        .timing_h_pos(h),
        .timing_v_pos(v),
        .pixel_x(x),
        .pixel_y(y),
        .video_hsync(hs),
        .video_vsync(vs),
        .video_den(de),
        .video_line_start(line_start)
    );
    integer frame, n, eh, ev, active, lines, firsts, lasts;
    reg expected_de;
    initial begin
        repeat (4) @(negedge clk);
        reset = 0;
        for (frame=0; frame<2; frame=frame+1) begin
            active=0; lines=0; firsts=0; lasts=0;
            for (n=0; n<1056*525; n=n+1) begin
                eh=n%1056; ev=n/1056;
                expected_de=(eh>=46 && eh<846 && ev>=26 && ev<506);
                if (h !== eh || v !== ev || hs !== (eh<20) ||
                    vs !== (ev<3) || de !== expected_de)
                    $fatal(1,"TIMING mismatch n=%0d h=%0d v=%0d", n,h,v);
                if (de) begin
                    active=active+1;
                    if (x !== (eh-46) || y !== (ev-26))
                        $fatal(1,"COORD mismatch");
                    if (x==0 && y==0) firsts=firsts+1;
                    if (x==799 && y==479) lasts=lasts+1;
                end
                if (line_start) lines=lines+1;
                @(negedge clk);
            end
            if (active!=800*480 || lines!=480 || firsts!=1 || lasts!=1)
                $fatal(1,"FRAME mismatch active=%0d lines=%0d",active,lines);
        end
        reset=1;
        @(negedge clk);
        if (h!==0 || v!==0 || de!==0) $fatal(1,"RESET mismatch");
        $display("PASS tb_panel_timing frames=2 active=384000 total=554400");
        $finish;
    end
    initial begin #12000000; $fatal(1,"TIMING watchdog"); end
endmodule
