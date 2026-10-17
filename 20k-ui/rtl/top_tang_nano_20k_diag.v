`timescale 1ns / 1ps
// Standalone 640x480 color-bar diagnostic top level.
// Port names and pin assignments intentionally match the UI top level.
module top_tang_nano_20k_diag (
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
    // Keep the inputs in the top-level interface so the diagnostic bitstream
    // uses exactly the same connector wiring as the UI bitstream.
    wire unused_inputs = ec11_a ^ ec11_b ^ ec11_key_n;

    wire clk_pixel;
    wire clk_serial;
    wire pll_locked;

    pll_640x480 pll (
        .clk_in    (clk_27m),
        .clk_pixel (clk_pixel),
        .clk_serial(clk_serial),
        .locked    (pll_locked)
    );

    reg [7:0] reset_count;
    reg       core_rst_n;
    // Pin 88 is MODE0_KEY1 and is hard-pulled low on the 3921 board.
    // Do not use it as a reset input: the board resistor would hold the
    // entire video pipeline in reset. Keep the port for cable compatibility,
    // but release reset from PLL lock alone.
    always @(posedge clk_pixel) begin
        if (!pll_locked) begin
            reset_count <= 8'd0;
            core_rst_n  <= 1'b0;
        end else if (reset_count != 8'hff) begin
            reset_count <= reset_count + 8'd1;
            core_rst_n  <= 1'b0;
        end else begin
            core_rst_n  <= 1'b1;
        end
    end

    // Keep the legacy input from being optimized into an accidental reset
    // path while documenting that it is intentionally ignored.
    wire unused_reset_input = btn_rst_n;

    wire [9:0] px;
    wire [9:0] py;
    wire       de_raw;
    wire       hs_raw;
    wire       vs_raw;
    wire       frame_start;

    video_timing_640x480 timing (
        .clk        (clk_pixel),
        .rst_n      (core_rst_n),
        .x          (px),
        .y          (py),
        .de         (de_raw),
        .hsync      (hs_raw),
        .vsync      (vs_raw),
        .frame_start(frame_start)
    );

    wire [7:0] red_raw;
    wire [7:0] green_raw;
    wire [7:0] blue_raw;
    colorbars_640x480 bars (
        .de   (de_raw),
        .x    (px),
        .y    (py),
        .red  (red_raw),
        .green(green_raw),
        .blue (blue_raw)
    );

    // Color bars are combinational from the registered timing coordinates.
    // Delay all video metadata equally before the two-stage TMDS encoder.
    reg [7:0] red_d, green_d, blue_d;
    reg       de_d, hs_d, vs_d;
    always @(posedge clk_pixel or negedge core_rst_n) begin
        if (!core_rst_n) begin
            red_d   <= 8'd0;
            green_d <= 8'd0;
            blue_d  <= 8'd0;
            de_d    <= 1'b0;
            hs_d    <= 1'b1;
            vs_d    <= 1'b1;
        end else begin
            red_d   <= red_raw;
            green_d <= green_raw;
            blue_d  <= blue_raw;
            de_d    <= de_raw;
            hs_d    <= hs_raw;
            vs_d    <= vs_raw;
        end
    end

    // 640x480 uses active-low syncs, and hdmi_tx forwards the physical
    // sync polarity into the DVI control symbols. Do not invert here.
    hdmi_tx tx (
        .pclk      (clk_pixel),
        .fclk      (clk_serial),
        .rst_n     (core_rst_n),
        .red       (red_d),
        .green     (green_d),
        .blue      (blue_d),
        .de        (de_d),
        .hsync     (hs_d),
        .vsync     (vs_d),
        .tmds_d_p  (tmds_d_p),
        .tmds_d_n  (tmds_d_n),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n)
    );
endmodule
