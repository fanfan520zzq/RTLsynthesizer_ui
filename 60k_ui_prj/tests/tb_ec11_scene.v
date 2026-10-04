`timescale 1ns/1ps
module tb_ec11_scene;
    reg clk=0,rst_n=0,frame_start=0;
    always #5 clk=~clk;
    reg [10:0] x=0;
    reg [9:0] y=0;
    reg [1:0] page=0;
    reg [3:0] focus=0;
    reg editing=0;
    reg [7:0] rate=64,depth=128,width_value=128,mix=64;
    reg [2:0] preset=0,selected_item=0;
    reg fx_enable=1;
    reg [7:0] last_action=0;
    wire [23:0] rgb;
    reg [7:0] expected_font [0:1519];
    ui_ec11_scene dut (
        .clk(clk),.rst_n(rst_n),.frame_start(frame_start),.pixel_x(x),.pixel_y(y),
        .page(page),.focus(focus),.editing(editing),.rate(rate),.depth(depth),
        .width_value(width_value),.mix(mix),.preset(preset),.fx_enable(fx_enable),
        .selected_item(selected_item),.last_action(last_action),.action_count(16'd0),
        .pixel_rgb(rgb)
    );
    task snapshot;
        begin
            @(negedge clk); frame_start=1;
            @(negedge clk); frame_start=0;
        end
    endtask
    task probe;
        input integer px,py;
        input [23:0] expected;
        begin
            @(negedge clk); x=px; y=py;
            @(posedge clk); #1;
            if(rgb!==expected) $fatal(1,"pixel %0d,%0d got %h expected %h",px,py,rgb,expected);
        end
    endtask
    // Compare complete native/scaled cells with the baked font snapshot.
    // This detects bit order, single-axis stretch, clipping and ROM latency.
    task probe_glyph;
        input integer px,py,code,scale;
        input [23:0] fg,bg;
        integer gx,gy;
        reg [7:0] bits;
        begin
            for(gy=0;gy<16*scale;gy=gy+1) begin
                bits=expected_font[(code-32)*16+gy/scale];
                for(gx=0;gx<8*scale;gx=gx+1)
                    probe(px+gx,py+gy,bits[7-gx/scale] ? fg : bg);
            end
        end
    endtask
    initial begin
        $readmemh("../scenes/font_8x16.mem",expected_font);
        repeat(3) @(negedge clk); rst_n=1;
        probe(799,479,24'h05070c);
        probe_glyph(16,8,69,2,24'he2e8f0,24'h05070c); // large E, true 2x in BOTH axes
        probe_glyph(32,154,83,1,24'he2e8f0,24'h0f172a); // native small S
        probe(16,44,24'h38bdf8); // focused tab
        probe(24,191,24'h34d399); // selected demo row, clear of text glyphs
        @(negedge clk); page=1; focus=10;
        probe(24,191,24'h34d399); // no mid-frame page switch
        snapshot();
        probe(32,194,24'h0f172a); // no longer the SD selected-row outline
        probe(32,189,24'h34d399); // selected patch 0 bottom border
        probe(84,264,24'h38bdf8); // focused rate bar
        probe(90,280,24'h38bdf8); // rate64 fill covers 20 of 80 pixels
        probe(110,280,24'h1e293b);
        // HEX: 40, rendered through the same shared ROM as every other label.
        probe_glyph(136,352,52,1,24'he2e8f0,24'h0f172a);
        probe_glyph(144,352,48,1,24'he2e8f0,24'h0f172a);
        @(negedge clk); editing=1; rate=255;
        probe(84,264,24'h38bdf8); // editing also waits for a frame snapshot
        snapshot();
        probe(84,264,24'hfbbf24);
        probe(162,280,24'hfbbf24); // focus border at final 2 columns
        probe(161,280,24'h38bdf8); // max value fill
        probe_glyph(136,352,70,1,24'he2e8f0,24'h0f172a);
        probe_glyph(144,352,70,1,24'he2e8f0,24'h0f172a);
        @(negedge clk); page=2; focus=4; editing=0;
        snapshot();
        probe(288,254,24'h38bdf8); // PLAY focus
        probe(400,330,24'h0f172a); // playback panel, not previous effects
        probe(799,479,24'h05070c);
        $display("PASS tb_ec11_scene pages/snapshot/focus/edit/bar/native font/2x aspect/hex pixels");
        $finish;
    end
    initial begin #40000; $fatal(1,"scene watchdog"); end
endmodule
