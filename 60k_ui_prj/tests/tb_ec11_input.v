`timescale 1ns/1ps
// Raw A/B/SW -> real debouncer -> UI controller, no event injection.
module tb_ec11_input;
    reg clk=0, rst_n=0, a=1,b=1,sw=1;
    always #5 clk=~clk;
    wire rv,cw,sv,pressed;
    wire signed [15:0] position;
    wire [1:0] page;
    wire [3:0] focus;
    wire editing;
    wire [7:0] rate;
    ec11_decoder #(.CLK_HZ(10000),.SAMPLE_HZ(1000)) decoder (
        .clk(clk),.rst_n(rst_n),.ec11_a(a),.ec11_b(b),.ec11_sw_n(sw),
        .rotate_valid(rv),.rotate_cw(cw),.position(position),
        .switch_valid(sv),.switch_pressed(pressed)
    );
    ui_ec11_controller #(.CLK_HZ(10000),.LONG_PRESS_MS(800)) controller (
        .clk(clk),.rst_n(rst_n),.rotate_valid(rv),.rotate_cw(cw),
        .switch_valid(sv),.switch_pressed(pressed),
        .page(page),.focus(focus),.editing(editing),.rate(rate),
        .depth(),.width_value(),.mix(),.preset(),.fx_enable(),
        .selected_item(),.last_action(),.action_count()
    );
    task ab;
        input [1:0] val;
        begin @(negedge clk); {a,b}=val; repeat(50) @(negedge clk); end
    endtask
    task detent;
        input direction;
        begin
            if(direction) begin ab(2'b10); ab(2'b00); ab(2'b01); ab(2'b11); end
            else begin ab(2'b01); ab(2'b00); ab(2'b10); ab(2'b11); end
        end
    endtask
    task click;
        begin
            @(negedge clk); sw=0; repeat(60) @(negedge clk);
            sw=1; repeat(60) @(negedge clk);
        end
    endtask
    integer i;
    initial begin
        repeat(5) @(negedge clk); rst_n=1;
        // Pulses shorter than the stable sampling interval must be ignored.
        repeat(6) begin
            @(negedge clk); a=0; sw=0;
            @(negedge clk); a=1; sw=1;
        end
        repeat(60) @(negedge clk);
        if(position!==0 || focus!==0 || pressed!==0) $fatal(1,"bounce escaped");
        detent(1); if(position!==1 || focus!==1) $fatal(1,"CW raw input");
        click(); if(page!==1) $fatal(1,"raw switch click");
        for(i=0;i<9;i=i+1) detent(1);
        if(focus!==10) $fatal(1,"raw focus");
        click(); if(!editing) $fatal(1,"raw enter edit");
        detent(1); if(rate!==65) $fatal(1,"raw parameter step");
        @(negedge clk); sw=0;
        repeat(8200) @(negedge clk);
        sw=1; repeat(60) @(negedge clk);
        if(editing || focus!==1 || rate!==64 || page!==1) $fatal(1,"raw long press");
        detent(0); if(focus!==0) $fatal(1,"CCW raw input");
        click(); if(page!==0) $fatal(1,"raw return page");
        $display("PASS tb_ec11_input raw quadrature/bounce/click/long-press to controller");
        $finish;
    end
    initial begin #200000; $fatal(1,"input watchdog"); end
endmodule
