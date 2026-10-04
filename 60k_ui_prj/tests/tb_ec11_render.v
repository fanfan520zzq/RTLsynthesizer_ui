`timescale 1ns/1ps
// Export the ACTUAL generated RTL pixel output, not a Qt approximation.
module tb_ec11_render;
    reg clk=0,rst_n=0,frame_start=0;
    always #5 clk=~clk;
    reg [10:0] x=0;
    reg [9:0] y=0;
    reg [1:0] page=0;
    reg [3:0] focus=3;
    reg editing=0;
    wire [23:0] rgb;
    ui_ec11_scene dut (
        .clk(clk),.rst_n(rst_n),.frame_start(frame_start),.pixel_x(x),.pixel_y(y),
        .page(page),.focus(focus),.editing(editing),.rate(8'd64),.depth(8'd128),
        .width_value(8'd128),.mix(8'd64),.preset(3'd2),.fx_enable(1'b1),
        .selected_item(3'd1),.last_action(8'h06),.action_count(16'd1),.pixel_rgb(rgb)
    );
    integer p,px,py,fd;
    reg [255:0] name;
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        for(p=0;p<3;p=p+1) begin
            @(negedge clk); page=p; focus=(p==1)?10:(p==2)?4:3;
            editing=(p==1); frame_start=1;
            @(negedge clk); frame_start=0;
            $sformat(name,"ec11_page_%0d.ppm",p);
            fd=$fopen(name,"w");
            if(!fd) $fatal(1,"Cannot open preview");
            $fdisplay(fd,"P3\n800 480\n255");
            for(py=0;py<480;py=py+1) begin
                for(px=0;px<800;px=px+1) begin
                    @(negedge clk); x=px; y=py;
                    @(posedge clk); #1;
                    if((^rgb)===1'bx) $fatal(1,"Unknown rendered pixel");
                    $fdisplay(fd,"%0d %0d %0d",rgb[23:16],rgb[15:8],rgb[7:0]);
                end
            end
            $fclose(fd);
        end
        $display("PASS tb_ec11_render pages=3 actual RTL output");
        $finish;
    end
    initial begin #12000000; $fatal(1,"render watchdog"); end
endmodule
