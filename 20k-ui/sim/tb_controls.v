`timescale 1ns/1ps
module tb_controls;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg enc_a = 1'b0;
    reg enc_b = 1'b0;
    reg key_n = 1'b1;

    wire rot_inc, rot_dec, short_press, long_press, key_down;
    wire [1:0] page;
    wire [2:0] focus;
    wire editing;
    wire [7:0] tempo, cutoff, resonance, drive, mix;
    wire [7:0] main_mode, fx_depth;

    integer inc_count = 0;
    integer dec_count = 0;
    integer short_count = 0;
    integer long_count = 0;

    reg ui_inc = 1'b0;
    reg ui_dec = 1'b0;
    reg ui_short = 1'b0;
    reg ui_long = 1'b0;

    always #5 clk = ~clk;

    ec11_input #(
        .DEBOUNCE_CYCLES(3),
        .LONG_PRESS_CYCLES(20)
    ) encoder (
        .clk(clk), .rst_n(rst_n),
        .enc_a(enc_a), .enc_b(enc_b), .key_n(key_n),
        .rot_inc(rot_inc), .rot_dec(rot_dec),
        .short_press(short_press), .long_press(long_press),
        .key_down(key_down)
    );

    ui_state state (
        .clk(clk), .rst_n(rst_n),
        .rot_inc(ui_inc), .rot_dec(ui_dec),
        .short_press(ui_short), .long_press(ui_long),
        .page(page), .focus(focus), .editing(editing),
        .tempo(tempo), .cutoff(cutoff), .resonance(resonance),
        .drive(drive), .mix(mix),
        .main_mode(main_mode), .fx_depth(fx_depth)
    );

    always @(posedge clk) begin
        if (rot_inc) inc_count = inc_count + 1;
        if (rot_dec) dec_count = dec_count + 1;
        if (short_press) short_count = short_count + 1;
        if (long_press) long_count = long_count + 1;
    end

    task set_ab;
        input a;
        input b;
        begin
            @(negedge clk);
            enc_a = a;
            enc_b = b;
            repeat (4) @(posedge clk);
        end
    endtask

    task ui_pulse;
        input [1:0] which;
        begin
            @(negedge clk);
            case (which)
                2'd0: ui_inc = 1'b1;
                2'd1: ui_dec = 1'b1;
                2'd2: ui_short = 1'b1;
                default: ui_long = 1'b1;
            endcase
            @(negedge clk);
            ui_inc = 1'b0;
            ui_dec = 1'b0;
            ui_short = 1'b0;
            ui_long = 1'b0;
            #1;
        end
    endtask

    task ui_short_rot;
        input direction;
        begin
            @(negedge clk);
            ui_short = 1'b1;
            if (direction)
                ui_inc = 1'b1;
            else
                ui_dec = 1'b1;
            @(negedge clk);
            ui_short = 1'b0;
            ui_inc = 1'b0;
            ui_dec = 1'b0;
            #1;
        end
    endtask

    task press_key;
        input level;
        input integer cycles;
        begin
            @(negedge clk);
            key_n = level;
            repeat (cycles) @(posedge clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // One positive and one negative full quadrature detent.
        set_ab(1'b0, 1'b1);
        set_ab(1'b1, 1'b1);
        set_ab(1'b1, 1'b0);
        set_ab(1'b0, 1'b0);
        set_ab(1'b1, 1'b0);
        set_ab(1'b1, 1'b1);
        set_ab(1'b0, 1'b1);
        set_ab(1'b0, 1'b0);
        if (inc_count != 1 || dec_count != 1)
            $fatal(1, "EC11 quadrature decode failed: inc=%0d dec=%0d", inc_count, dec_count);

        // Debounced short press, then a long press that must not also short-fire.
        press_key(1'b0, 10);
        press_key(1'b1, 10);
        if (short_count != 1 || long_count != 0)
            $fatal(1, "EC11 short press failed: short=%0d long=%0d", short_count, long_count);
        press_key(1'b0, 32);
        press_key(1'b1, 10);
        if (short_count != 1 || long_count != 1)
            $fatal(1, "EC11 long press failed: short=%0d long=%0d", short_count, long_count);

        if (page != 0 || focus != 0 || editing || tempo != 120 || main_mode != 1 || fx_depth != 80)
            $fatal(1, "UI reset state incorrect");
        ui_pulse(2'd0);
        ui_pulse(2'd0);
        ui_pulse(2'd0);
        if (page != 1 || focus != 0)
            $fatal(1, "UI focus/page navigation failed");
        ui_pulse(2'd3);
        if (page != 0 || focus != 0)
            $fatal(1, "UI long-press return failed");
        ui_pulse(2'd2);
        ui_pulse(2'd0);
        if (!editing || tempo != 121)
            $fatal(1, "UI parameter edit failed");
        ui_pulse(2'd2);
        if (editing)
            $fatal(1, "UI edit-mode exit failed");

        // MAIN third item: MODE is an independent editable state value.
        ui_pulse(2'd0);
        ui_pulse(2'd0);
        ui_pulse(2'd2);
        ui_pulse(2'd0);
        if (!editing || main_mode != 2)
            $fatal(1, "MODE parameter edit failed: editing=%0d mode=%0d", editing, main_mode);

        // Return to MAIN, then rotate backwards into FX third item.
        ui_pulse(2'd3);
        ui_pulse(2'd1);
        ui_pulse(2'd2);
        ui_pulse(2'd1);
        if (!editing || page != 2 || focus != 2 || fx_depth != 79)
            $fatal(1, "DEPTH parameter edit failed: page=%0d focus=%0d editing=%0d depth=%0d",
                   page, focus, editing, fx_depth);
        ui_pulse(2'd3);
        if (editing || page != 0 || focus != 0 || fx_depth != 80)
            $fatal(1, "Long-press edit cancel failed: page=%0d focus=%0d editing=%0d depth=%0d",
                   page, focus, editing, fx_depth);

        // A same-cycle click and encoder edge must be owned by the click.
        ui_short_rot(1'b1);
        if (!editing || tempo != 121 || page != 0 || focus != 0)
            $fatal(1, "Short press plus rotation entered the wrong state");
        ui_short_rot(1'b1);
        if (editing || tempo != 121 || page != 0 || focus != 0)
            $fatal(1, "Short press plus rotation changed the value or focus");

        $display("PASS: EC11 rotation, short/long press, UI navigation, parameter edit and cancel");
        $finish;
    end
endmodule
