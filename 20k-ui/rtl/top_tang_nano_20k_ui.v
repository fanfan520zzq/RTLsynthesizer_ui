`timescale 1ns / 1ps
// Standalone Nano 20K UI demo top level.
//
// Inputs ec11_a/ec11_b/ec11_key_n must be 3.3 V FPGA-safe signals.  A common
// EC11 board marked "5V GND A B KEY" must either be powered from 3.3 V (when
// its circuit permits it) or have A/B/KEY level-shifted before this top.
// The HDMI pin pair locations belong in the board-specific .cst file.
module top_tang_nano_20k_ui (
    input  wire       clk_27m,
    input  wire       btn_rst_n,
    input  wire       ec11_a,
    input  wire       ec11_b,
    input  wire       ec11_key_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n
);
    wire clk_pixel;
    wire clk_serial;
    wire pll_locked;

    pll_800x480_template pll (
        .clk_in    (clk_27m),
        .clk_pixel (clk_pixel),
        .clk_serial(clk_serial),
        .locked    (pll_locked)
    );

    // Pin 88 is MODE0_KEY1 and is pulled low by the 3921 board, so it cannot
    // be used as an active-low reset input. Release reset after the PLL locks.
    reg [7:0] reset_count;
    reg       core_rst_n;
    always @(posedge clk_pixel or negedge pll_locked) begin
        if (!pll_locked) begin
            reset_count <= 8'd0;
            core_rst_n  <= 1'b0;
        end else if (reset_count != 8'hFF) begin
            reset_count <= reset_count + 8'd1;
            core_rst_n  <= 1'b0;
        end else begin
            core_rst_n  <= 1'b1;
        end
    end

    // Raster timing: GitHub UI mode, H=1056 and V=525, positive sync.
    wire [10:0] px;
    wire [9:0]  py;
    wire        de_raw;
    wire        hs_raw;
    wire        vs_raw;
    wire        frame_start;

    video_timing_800x480 vt (
        .clk        (clk_pixel),
        .rst_n      (core_rst_n),
        .x          (px),
        .y          (py),
        .de         (de_raw),
        .hsync      (hs_raw),
        .vsync      (vs_raw),
        .frame_start(frame_start)
    );

    // EC11 events are synchronous one-cycle pulses.
    wire rot_inc, rot_dec, short_press, long_press, key_down;
    ec11_input #(
        .DEBOUNCE_CYCLES  (500000),
        .LONG_PRESS_CYCLES(33000000)
    ) ec11 (
        .clk        (clk_pixel),
        .rst_n      (core_rst_n),
        .enc_a      (ec11_a),
        .enc_b      (ec11_b),
        .key_n      (ec11_key_n),
        .rot_inc    (rot_inc),
        .rot_dec    (rot_dec),
        .short_press(short_press),
        .long_press (long_press),
        .key_down   (key_down)
    );

    wire [1:0] page;
    wire [2:0] focus;
    wire       editing;
    wire [7:0] tempo, cutoff, resonance, drive, mix;
    wire [7:0] main_mode, fx_depth;

    ui_state state (
        .clk        (clk_pixel),
        .rst_n      (core_rst_n),
        .rot_inc    (rot_inc),
        .rot_dec    (rot_dec),
        .short_press(short_press),
        .long_press (long_press),
        .page       (page),
        .focus      (focus),
        .editing    (editing),
        .tempo      (tempo),
        .cutoff     (cutoff),
        .resonance  (resonance),
        .drive      (drive),
        .mix        (mix),
        .main_mode  (main_mode),
        .fx_depth   (fx_depth)
    );

    // Internal deterministic test source. This creates a 48 kHz sample pulse
    // from the ~33.3 MHz pixel clock and is not an audio input interface.
    wire sample_tick;
    wire signed [7:0] sample;
    wire [15:0] sample_phase;
    test_wave_48k #(
        .CLK_HZ   (33300000),
        .SAMPLE_HZ(48000),
        .FREQ_HZ  (440)
    ) wave (
        .clk        (clk_pixel),
        .rst_n      (core_rst_n),
        .sample_tick(sample_tick),
        .sample     (sample),
        .phase      (sample_phase)
    );

    wire [7:0] spec0, spec1, spec2, spec3;
    wire [7:0] spec4, spec5, spec6, spec7;
    wire       spectrum_frame_valid;
    wire       spectrum_busy;

    spectrum_goertzel128 spectrum (
        .clk        (clk_pixel),
        .rst_n      (core_rst_n),
        .sample_tick(sample_tick),
        .sample_in  (sample),
        .bar0       (spec0), .bar1(spec1), .bar2(spec2), .bar3(spec3),
        .bar4       (spec4), .bar5(spec5), .bar6(spec6), .bar7(spec7),
        .frame_valid(spectrum_frame_valid),
        .busy       (spectrum_busy)
    );

    wire [7:0] red, green, blue;
    ui_renderer_800x480 renderer (
        .clk        (clk_pixel),
        .rst_n      (core_rst_n),
        .px         (px),
        .py         (py),
        .frame_start(frame_start),
        .page       (page),
        .focus      (focus),
        .editing    (editing),
        .tempo      (tempo),
        .cutoff     (cutoff),
        .resonance  (resonance),
        .drive      (drive),
        .mix        (mix),
        .spec0      (spec0), .spec1(spec1), .spec2(spec2), .spec3(spec3),
        .spec4      (spec4), .spec5(spec5), .spec6(spec6), .spec7(spec7),
        .main_mode  (main_mode),
        .fx_depth   (fx_depth),
        .r_out      (red),
        .g_out      (green),
        .b_out      (blue)
    );

    // The renderer adds one pixel-clock of RGB latency. Match DE/sync to it
    // before the registered TMDS encoder samples both on the same edge.
    reg de_d, hs_d, vs_d;
    always @(posedge clk_pixel or negedge core_rst_n) begin
        if (!core_rst_n) begin
            de_d <= 1'b0;
            hs_d <= 1'b0;
            vs_d <= 1'b0;
        end else begin
            de_d <= de_raw;
            hs_d <= hs_raw;
            vs_d <= vs_raw;
        end
    end

    hdmi_tx tx (
        .pclk      (clk_pixel),
        .fclk      (clk_serial),
        .rst_n     (core_rst_n),
        .red       (red),
        .green     (green),
        .blue      (blue),
        .de        (de_d),
        .hsync     (hs_d),
        .vsync     (vs_d),
        .tmds_d_p  (tmds_d_p),
        .tmds_d_n  (tmds_d_n),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n)
    );
endmodule
