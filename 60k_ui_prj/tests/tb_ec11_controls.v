`timescale 1ns/1ps
module tb_ec11_controls;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    reg rv=0, cw=0, sv=0, pressed=0;
    wire [1:0] page;
    wire [3:0] focus;
    wire editing;
    wire [7:0] rate,depth,width_value,mix,last_action;
    wire [2:0] preset,selected_item;
    wire fx_enable;
    wire [15:0] action_count;
    ui_ec11_controller #(.CLK_HZ(1000), .LONG_PRESS_MS(20)) dut (
        .clk(clk), .rst_n(rst_n), .rotate_valid(rv), .rotate_cw(cw),
        .switch_valid(sv), .switch_pressed(pressed),
        .page(page), .focus(focus), .editing(editing), .rate(rate),
        .depth(depth), .width_value(width_value), .mix(mix),
        .preset(preset), .fx_enable(fx_enable), .selected_item(selected_item),
        .last_action(last_action), .action_count(action_count)
    );
    task rotate;
        input direction;
        begin
            @(negedge clk); rv=1; cw=direction;
            @(negedge clk); rv=0;
        end
    endtask
    task click;
        begin
            @(negedge clk); sv=1; pressed=1;
            @(negedge clk); sv=0;
            repeat(2) @(negedge clk);
            sv=1; pressed=0;
            @(negedge clk); sv=0;
        end
    endtask
    task hold;
        begin
            @(negedge clk); sv=1; pressed=1;
            @(negedge clk); sv=0;
            repeat(30) @(negedge clk);
            sv=1; pressed=0;
            @(negedge clk); sv=0;
        end
    endtask
    task go_focus;
        input integer target;
        integer guard_count;
        begin
            guard_count=0;
            while (focus!=target && guard_count<17) begin rotate(1); guard_count=guard_count+1; end
            if (focus!=target) $fatal(1,"focus navigation failed");
        end
    endtask
    integer i,k;
    reg [15:0] before_count;
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        if (page!==0 || focus!==0 || rate!==64) $fatal(1,"reset state");
        rotate(0); if(focus!==6) $fatal(1,"CCW wrap");
        rotate(1); if(focus!==0) $fatal(1,"CW wrap");
        go_focus(3); click(); if(last_action!==1) $fatal(1,"scan request");
        go_focus(4); click(); if(selected_item!==5) $fatal(1,"previous item wrap");
        go_focus(5); click(); if(selected_item!==0) $fatal(1,"next item wrap");
        go_focus(6); click(); if(last_action!==4) $fatal(1,"load request");
        go_focus(1); click(); if(page!==1) $fatal(1,"effects page");
        for(i=0;i<7;i=i+1) begin
            go_focus(i+3); click();
            if(preset!==i || last_action!==8'h10+i) $fatal(1,"preset %0d",i);
        end
        for(i=0;i<4;i=i+1) begin
            go_focus(10+i); click();
            if(!editing) $fatal(1,"enter edit");
            for(k=0;k<260;k=k+1) rotate(1);
            if(dut.edit_value!==255) $fatal(1,"upper limit");
            for(k=0;k<260;k=k+1) rotate(0);
            if(dut.edit_value!==0) $fatal(1,"lower limit");
            repeat(42) rotate(1);
            click();
            if(editing || dut.edit_value!==42 || last_action!==8'h20+i)
                $fatal(1,"commit parameter %0d",i);
        end
        go_focus(10); click(); rotate(1);
        before_count=action_count;
        hold();
        if(editing || rate!==42 || focus!==1 || action_count!==before_count)
            $fatal(1,"long press cancel/release must not click");
        go_focus(15); click(); if(fx_enable!==0 || last_action!==8'h31) $fatal(1,"bypass");
        go_focus(14); click(); if(fx_enable!==1) $fatal(1,"FX on");
        go_focus(2); click(); if(page!==2) $fatal(1,"play page");
        for(i=0;i<4;i=i+1) begin
            go_focus(3+i); click();
            if(last_action!==5+i) $fatal(1,"play request %0d",i);
        end
        hold(); if(focus!==2) $fatal(1,"hold current tab");
        go_focus(0); click(); go_focus(1); click();
        if(rate!==42 || depth!==42 || width_value!==42 || mix!==42 || preset!==6)
            $fatal(1,"state must persist across pages");
        // Rotation while a button is held is intentionally ignored.
        @(negedge clk); sv=1; pressed=1;
        @(negedge clk); sv=0;
        rotate(1); if(focus!==1) $fatal(1,"rotate while pressed");
        repeat(30) @(negedge clk);
        sv=1; pressed=0;
        @(negedge clk); sv=0;
        if(page!==1 || focus!==1) $fatal(1,"long press released as short press");
        $display("PASS tb_ec11_controls navigation/edit/limits/cancel/persistence/actions");
        $finish;
    end
    initial begin #1000000; $fatal(1,"controls watchdog"); end
endmodule
