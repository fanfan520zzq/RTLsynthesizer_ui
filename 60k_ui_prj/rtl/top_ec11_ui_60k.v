`timescale 1ns / 1ps
// Standalone HDMI + EC11 UI interaction test. No SD/audio/UART backend.
module top_tmds_60k (
    input wire clk,
    input wire rst,
    input wire ec11_a,
    input wire ec11_b,
    input wire ec11_sw_n,
    output wire tmds_clk_n_0,
    output wire tmds_clk_p_0,
    output wire [2:0] tmds_d_n_0,
    output wire [2:0] tmds_d_p_0,
    output wire hpd_en,
    output wire led
);
    wire clk_pixel;
    wire clk_tmds_5x;
    wire pll_lock;
    TMDS_PLL u_tmds_pll (
        .clkin(clk),
        .clkout0(clk_tmds_5x),
        .clkout1(clk_pixel),
        .lock(pll_lock)
    );
    wire video_resetn;
    reset_sync_tmds u_video_reset (
        .clk(clk_pixel),
        .ext_resetn(rst & pll_lock),
        .resetn(video_resetn)
    );

    wire [13:0] h_pos;
    wire [13:0] v_pos;
    wire [13:0] pixel_x_wide;
    wire [13:0] pixel_y_wide;
    wire video_vsync;
    wire video_hsync;
    wire video_de;
    // Already board-accepted 5-inch panel format, matching rv_test geometry.
    video_timing_ctrl #(
        .video_hlength(1056),
        .video_vlength(525),
        .video_hsync_pol(1),
        .video_hsync_len(20),
        .video_hbp_len(26),
        .video_h_visible(800),
        .video_vsync_pol(1),
        .video_vsync_len(3),
        .video_vbp_len(23),
        .video_v_visible(480)
    ) u_video_timing (
        .pixel_clock(clk_pixel),
        .reset(~video_resetn),
        .ext_sync(1'b0),
        .timing_h_pos(h_pos),
        .timing_v_pos(v_pos),
        .pixel_x(pixel_x_wide),
        .pixel_y(pixel_y_wide),
        .video_vsync(video_vsync),
        .video_hsync(video_hsync),
        .video_den(video_de),
        .video_line_start()
    );
    // Snapshot in vertical blanking, before the first visible pixel.
    wire frame_start = (h_pos == 0) && (v_pos == 0);

    wire rotate_valid;
    wire rotate_cw;
    wire switch_valid;
    wire switch_pressed;
    // Same verified decoder, adjusted only to the 33.333 MHz pixel domain.
    // Debounce remains three 1 ms samples; no multi-bit clock crossing needed.
    ec11_decoder #(
        .CLK_HZ(33333333),
        .SAMPLE_HZ(1000),
        .DEBOUNCE_SAMPLES(3)
    ) u_ec11 (
        .clk(clk_pixel),
        .rst_n(video_resetn),
        .ec11_a(ec11_a),
        .ec11_b(ec11_b),
        .ec11_sw_n(ec11_sw_n),
        .rotate_valid(rotate_valid),
        .rotate_cw(rotate_cw),
        .position(),
        .switch_valid(switch_valid),
        .switch_pressed(switch_pressed)
    );
    wire [1:0] page;
    wire [3:0] focus;
    wire editing;
    wire [7:0] rate;
    wire [7:0] depth;
    wire [7:0] width_value;
    wire [7:0] mix;
    wire [2:0] preset;
    wire fx_enable;
    wire [2:0] selected_item;
    wire [7:0] last_action;
    wire [15:0] action_count;
    ui_ec11_controller u_controls (
        .clk(clk_pixel),
        .rst_n(video_resetn),
        .rotate_valid(rotate_valid),
        .rotate_cw(rotate_cw),
        .switch_valid(switch_valid),
        .switch_pressed(switch_pressed),
        .page(page),
        .focus(focus),
        .editing(editing),
        .rate(rate),
        .depth(depth),
        .width_value(width_value),
        .mix(mix),
        .preset(preset),
        .fx_enable(fx_enable),
        .selected_item(selected_item),
        .last_action(last_action),
        .action_count(action_count)
    );
    wire [23:0] scene_rgb;
    ui_ec11_scene u_scene (
        .clk(clk_pixel),
        .rst_n(video_resetn),
        .frame_start(frame_start),
        .pixel_x(pixel_x_wide[10:0]),
        .pixel_y(pixel_y_wide[9:0]),
        .page(page),
        .focus(focus),
        .editing(editing),
        .rate(rate),
        .depth(depth),
        .width_value(width_value),
        .mix(mix),
        .preset(preset),
        .fx_enable(fx_enable),
        .selected_item(selected_item),
        .last_action(last_action),
        .action_count(action_count),
        .pixel_rgb(scene_rgb)
    );

    // Renderer one clock + RGB boundary one clock. Delay sync/DE by two.
    reg [23:0] scene_rgb_q;
    reg [1:0] de_pipe;
    reg [1:0] hs_pipe;
    reg [1:0] vs_pipe;
    always @(posedge clk_pixel or negedge video_resetn) begin
        if (!video_resetn) begin
            scene_rgb_q <= 0;
            de_pipe <= 0;
            hs_pipe <= 0;
            vs_pipe <= 0;
        end else begin
            scene_rgb_q <= de_pipe[0] ? scene_rgb : 24'd0;
            de_pipe <= {de_pipe[0], video_de};
            hs_pipe <= {hs_pipe[0], video_hsync};
            vs_pipe <= {vs_pipe[0], video_vsync};
        end
    end
    DVI_TX_Top u_dvi_tx (
        .I_rst_n(video_resetn),
        .I_serial_clk(clk_tmds_5x),
        .I_rgb_clk(clk_pixel),
        .I_rgb_vs(vs_pipe[1]),
        .I_rgb_hs(hs_pipe[1]),
        .I_rgb_de(de_pipe[1]),
        .I_rgb_r(scene_rgb_q[23:16]),
        .I_rgb_g(scene_rgb_q[15:8]),
        .I_rgb_b(scene_rgb_q[7:0]),
        .O_tmds_clk_p(tmds_clk_p_0),
        .O_tmds_clk_n(tmds_clk_n_0),
        .O_tmds_data_p(tmds_d_p_0),
        .O_tmds_data_n(tmds_d_n_0)
    );
    assign hpd_en = 1'b1;
    assign led = ~pll_lock;
endmodule

module reset_sync_tmds (
    input wire clk,
    input wire ext_resetn,
    output wire resetn
);
    reg [3:0] reset_count;
    always @(posedge clk or negedge ext_resetn) begin
        if (!ext_resetn) reset_count <= 0;
        else if (!resetn) reset_count <= reset_count + 1'b1;
    end
    assign resetn = &reset_count;
endmodule
