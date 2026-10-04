`timescale 1ns / 1ps

// Tang Mega 60K direct-TMDS standalone display top.
// TMDS structure: Tang Mega 138K color-bar example.
// PLL/device/pins: matching GW5AT-LV60PG484AC1/I0 example.
module top_tmds_60k (
    input  wire       clk,
    input  wire       rst,
    output wire       tmds_clk_n_0,
    output wire       tmds_clk_p_0,
    output wire [2:0] tmds_d_n_0,
    output wire [2:0] tmds_d_p_0,
    output wire       hpd_en,
    output wire       led
);
    wire clk_pixel;
    wire clk_tmds_5x;
    wire pll_lock;

    TMDS_PLL u_tmds_pll (
        .clkin   (clk),
        .clkout0 (clk_tmds_5x),
        .clkout1 (clk_pixel),
        .lock    (pll_lock)
    );

    wire video_resetn;
    reset_sync_tmds u_video_reset (
        .clk       (clk_pixel),
        .ext_resetn(rst & pll_lock),
        .resetn    (video_resetn)
    );

    wire [13:0] pixel_x_wide;
    wire [13:0] pixel_y_wide;
    wire video_vsync;
    wire video_hsync;
    wire video_de;

    video_timing_ctrl #(
        // Match rv_test's 800x480 panel timing (positive syncs).
        .video_hlength   (1056),
        .video_vlength   (525),
        .video_hsync_pol (1),
        .video_hsync_len (20),
        .video_hbp_len   (26),
        .video_h_visible (800),
        .video_vsync_pol (1),
        .video_vsync_len (3),
        .video_vbp_len   (23),
        .video_v_visible (480)
    ) u_video_timing (
        .pixel_clock      (clk_pixel),
        .reset            (~video_resetn),
        .ext_sync         (1'b0),
        .timing_h_pos     (),
        .timing_v_pos     (),
        .pixel_x          (pixel_x_wide),
        .pixel_y          (pixel_y_wide),
        .video_vsync      (video_vsync),
        .video_hsync      (video_hsync),
        .video_den        (video_de),
        .video_line_start ()
    );

    wire frame_start = video_de && (pixel_x_wide == 0) &&
                       (pixel_y_wide == 0);

    // Synthetic status is used only for this standalone display smoke test.
    reg [31:0] frame_counter;
    reg [511:0] ui_status_flat;
    reg [127:0] note_active;
    always @(posedge clk_pixel or negedge video_resetn) begin
        if (!video_resetn) begin
            frame_counter  <= 0;
            ui_status_flat <= 0;
            note_active    <= 0;
            // Filename bytes occupy status slots 17..31, little-endian.
            ui_status_flat[17*16 + 0*8 +: 8] <= "A";
            ui_status_flat[17*16 + 1*8 +: 8] <= "U";
            ui_status_flat[17*16 + 2*8 +: 8] <= "T";
            ui_status_flat[17*16 + 3*8 +: 8] <= "O";
            ui_status_flat[17*16 + 4*8 +: 8] <= "P";
            ui_status_flat[17*16 + 5*8 +: 8] <= "L";
            ui_status_flat[17*16 + 6*8 +: 8] <= "A";
            ui_status_flat[17*16 + 7*8 +: 8] <= "Y";
            ui_status_flat[17*16 + 8*8 +: 8] <= ".";
            ui_status_flat[17*16 + 9*8 +: 8] <= "F";
            ui_status_flat[17*16 +10*8 +: 8] <= "S";
            ui_status_flat[17*16 +11*8 +: 8] <= "E";
            ui_status_flat[17*16 +12*8 +: 8] <= "1";
        end else if (frame_start) begin
            frame_counter <= frame_counter + 1'b1;
            ui_status_flat[0*16 +: 16] <= frame_counter[15:0];
            ui_status_flat[1*16 +: 16] <= frame_counter[31:16];
            ui_status_flat[2*16 +: 16] <= 16'd3600;
            ui_status_flat[3*16 +: 16] <= 16'd0;
            ui_status_flat[4*16 +: 16] <= 16'h0003;
            ui_status_flat[5*16 +: 16] <= 16'd1;
            ui_status_flat[6*16 +: 16] <= {6'd0, frame_counter[9:0]};
            ui_status_flat[7*16 +: 16] <= {11'd0, frame_counter[4:0]};
            ui_status_flat[8*16 +: 16] <= 16'd0;
            ui_status_flat[9*16 +: 16] <= 16'd0;
            ui_status_flat[10*16 +: 16] <= 16'd0;
            ui_status_flat[11*16 +: 16] <= {6'd0, frame_counter[9:0]};
            ui_status_flat[12*16 +: 16] <= {6'd0, frame_counter[10:1]};
            ui_status_flat[13*16 +: 16] <= {6'd0, frame_counter[11:2]};
            ui_status_flat[14*16 +: 16] <= {6'd0, frame_counter[12:3]};
            ui_status_flat[15*16 +: 16] <= {6'd0, frame_counter[13:4]};
            ui_status_flat[16*16 +: 16] <= {6'd0, frame_counter[14:5]};
            note_active <= 128'd1 << frame_counter[6:0];
        end
    end

    // Keep this boundary visible in Gowin reports.  The scene module may be
    // flattened, but its 24-bit result must remain on the TMDS pixel path.
    wire [23:0] scene_rgb /* synthesis syn_keep = 1 */;
    ui_generated_scene u_scene (
        .clk            (clk_pixel),
        .rst_n          (video_resetn),
        .pixel_x        (pixel_x_wide[10:0]),
        .pixel_y        (pixel_y_wide[9:0]),
        .ui_status_flat (ui_status_flat),
        .note_active    (note_active),
        .pixel_rgb      (scene_rgb)
    );

    // One stable pipeline boundary separates generated UI combinational logic
    // from the TMDS 8b/10b encoder.  Sync/de are delayed by the same cycle so
    // every generated scene can be replaced without changing video alignment.
    reg [23:0] scene_rgb_q;
    reg        video_de_d1;
    reg        video_de_q;
    reg        video_hsync_d1;
    reg        video_hsync_q;
    reg        video_vsync_d1;
    reg        video_vsync_q;
    always @(posedge clk_pixel or negedge video_resetn) begin
        if (!video_resetn) begin
            scene_rgb_q   <= 24'h000000;
            video_de_d1   <= 1'b0;
            video_de_q    <= 1'b0;
            video_hsync_d1 <= 1'b0;
            video_hsync_q <= 1'b0;
            video_vsync_d1 <= 1'b0;
            video_vsync_q <= 1'b0;
        end else begin
            scene_rgb_q   <= video_de_d1 ? scene_rgb : 24'h000000;
            video_de_d1   <= video_de;
            video_de_q    <= video_de_d1;
            video_hsync_d1 <= video_hsync;
            video_hsync_q <= video_hsync_d1;
            video_vsync_d1 <= video_vsync;
            video_vsync_q <= video_vsync_d1;
        end
    end

    // Device-specific 60K DVI transmitter IP from the official cam_dvi
    // example.  This keeps the direct-TMDS architecture while avoiding the
    // reset recovery violations of the 138K example's handwritten PHY.
    DVI_TX_Top u_dvi_tx (
        .I_rst_n       (video_resetn),
        .I_serial_clk  (clk_tmds_5x),
        .I_rgb_clk     (clk_pixel),
        .I_rgb_vs      (video_vsync_q),
        .I_rgb_hs      (video_hsync_q),
        .I_rgb_de      (video_de_q),
        .I_rgb_r       (scene_rgb_q[23:16]),
        .I_rgb_g       (scene_rgb_q[15:8]),
        .I_rgb_b       (scene_rgb_q[7:0]),
        .O_tmds_clk_p  (tmds_clk_p_0),
        .O_tmds_clk_n  (tmds_clk_n_0),
        .O_tmds_data_p (tmds_d_p_0),
        .O_tmds_data_n (tmds_d_n_0)
    );

    assign hpd_en = 1'b1;
    assign led = ~pll_lock;
endmodule

module reset_sync_tmds (
    input  wire clk,
    input  wire ext_resetn,
    output wire resetn
);
    reg [3:0] reset_count;
    always @(posedge clk or negedge ext_resetn) begin
        if (!ext_resetn)
            reset_count <= 4'b0000;
        else if (!resetn)
            reset_count <= reset_count + 1'b1;
    end
    assign resetn = &reset_count;
endmodule
