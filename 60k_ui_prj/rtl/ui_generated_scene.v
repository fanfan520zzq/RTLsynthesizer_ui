`timescale 1ns / 1ps

// AUTO-GENERATED. Replace this file only; do not edit other RTL.
// ui_status_flat slots (16-bit each):
// 0..1 playback_frame, 2..3 duration_frames, 4 flags, 5 file_index,
// 6 progress(0..1023), 7 active_voices, 8 decoder_error,
// 9 sd_error, 10 player_error, 11..16 operator levels(0..1023),
// 17..31 filename ASCII (30 bytes, little-endian byte order).
// note_active[n] means MIDI note number n; displayed key count is per-widget.
module ui_generated_scene (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [10:0]  pixel_x,
    input  wire [9:0]   pixel_y,
    input  wire [511:0] ui_status_flat,
    input  wire [127:0] note_active,
    output wire [23:0]  pixel_rgb
);

    function [4:0] font5x7;
        input [7:0] ch;
        input [2:0] row;
        begin
            case ({ch, row})
                {8'd48, 3'd0}: font5x7 = 5'b01110;
                {8'd48, 3'd1}: font5x7 = 5'b10001;
                {8'd48, 3'd2}: font5x7 = 5'b10011;
                {8'd48, 3'd3}: font5x7 = 5'b10101;
                {8'd48, 3'd4}: font5x7 = 5'b11001;
                {8'd48, 3'd5}: font5x7 = 5'b10001;
                {8'd48, 3'd6}: font5x7 = 5'b01110;
                {8'd49, 3'd0}: font5x7 = 5'b00100;
                {8'd49, 3'd1}: font5x7 = 5'b01100;
                {8'd49, 3'd2}: font5x7 = 5'b00100;
                {8'd49, 3'd3}: font5x7 = 5'b00100;
                {8'd49, 3'd4}: font5x7 = 5'b00100;
                {8'd49, 3'd5}: font5x7 = 5'b00100;
                {8'd49, 3'd6}: font5x7 = 5'b01110;
                {8'd50, 3'd0}: font5x7 = 5'b01110;
                {8'd50, 3'd1}: font5x7 = 5'b10001;
                {8'd50, 3'd2}: font5x7 = 5'b00001;
                {8'd50, 3'd3}: font5x7 = 5'b00010;
                {8'd50, 3'd4}: font5x7 = 5'b00100;
                {8'd50, 3'd5}: font5x7 = 5'b01000;
                {8'd50, 3'd6}: font5x7 = 5'b11111;
                {8'd51, 3'd0}: font5x7 = 5'b11110;
                {8'd51, 3'd1}: font5x7 = 5'b00001;
                {8'd51, 3'd2}: font5x7 = 5'b00001;
                {8'd51, 3'd3}: font5x7 = 5'b01110;
                {8'd51, 3'd4}: font5x7 = 5'b00001;
                {8'd51, 3'd5}: font5x7 = 5'b00001;
                {8'd51, 3'd6}: font5x7 = 5'b11110;
                {8'd52, 3'd0}: font5x7 = 5'b00010;
                {8'd52, 3'd1}: font5x7 = 5'b00110;
                {8'd52, 3'd2}: font5x7 = 5'b01010;
                {8'd52, 3'd3}: font5x7 = 5'b10010;
                {8'd52, 3'd4}: font5x7 = 5'b11111;
                {8'd52, 3'd5}: font5x7 = 5'b00010;
                {8'd52, 3'd6}: font5x7 = 5'b00010;
                {8'd53, 3'd0}: font5x7 = 5'b11111;
                {8'd53, 3'd1}: font5x7 = 5'b10000;
                {8'd53, 3'd2}: font5x7 = 5'b10000;
                {8'd53, 3'd3}: font5x7 = 5'b11110;
                {8'd53, 3'd4}: font5x7 = 5'b00001;
                {8'd53, 3'd5}: font5x7 = 5'b00001;
                {8'd53, 3'd6}: font5x7 = 5'b11110;
                {8'd54, 3'd0}: font5x7 = 5'b01110;
                {8'd54, 3'd1}: font5x7 = 5'b10000;
                {8'd54, 3'd2}: font5x7 = 5'b10000;
                {8'd54, 3'd3}: font5x7 = 5'b11110;
                {8'd54, 3'd4}: font5x7 = 5'b10001;
                {8'd54, 3'd5}: font5x7 = 5'b10001;
                {8'd54, 3'd6}: font5x7 = 5'b01110;
                {8'd56, 3'd0}: font5x7 = 5'b01110;
                {8'd56, 3'd1}: font5x7 = 5'b10001;
                {8'd56, 3'd2}: font5x7 = 5'b10001;
                {8'd56, 3'd3}: font5x7 = 5'b01110;
                {8'd56, 3'd4}: font5x7 = 5'b10001;
                {8'd56, 3'd5}: font5x7 = 5'b10001;
                {8'd56, 3'd6}: font5x7 = 5'b01110;
                {8'd65, 3'd0}: font5x7 = 5'b01110;
                {8'd65, 3'd1}: font5x7 = 5'b10001;
                {8'd65, 3'd2}: font5x7 = 5'b10001;
                {8'd65, 3'd3}: font5x7 = 5'b11111;
                {8'd65, 3'd4}: font5x7 = 5'b10001;
                {8'd65, 3'd5}: font5x7 = 5'b10001;
                {8'd65, 3'd6}: font5x7 = 5'b10001;
                {8'd66, 3'd0}: font5x7 = 5'b11110;
                {8'd66, 3'd1}: font5x7 = 5'b10001;
                {8'd66, 3'd2}: font5x7 = 5'b10001;
                {8'd66, 3'd3}: font5x7 = 5'b11110;
                {8'd66, 3'd4}: font5x7 = 5'b10001;
                {8'd66, 3'd5}: font5x7 = 5'b10001;
                {8'd66, 3'd6}: font5x7 = 5'b11110;
                {8'd67, 3'd0}: font5x7 = 5'b01111;
                {8'd67, 3'd1}: font5x7 = 5'b10000;
                {8'd67, 3'd2}: font5x7 = 5'b10000;
                {8'd67, 3'd3}: font5x7 = 5'b10000;
                {8'd67, 3'd4}: font5x7 = 5'b10000;
                {8'd67, 3'd5}: font5x7 = 5'b10000;
                {8'd67, 3'd6}: font5x7 = 5'b01111;
                {8'd68, 3'd0}: font5x7 = 5'b11110;
                {8'd68, 3'd1}: font5x7 = 5'b10001;
                {8'd68, 3'd2}: font5x7 = 5'b10001;
                {8'd68, 3'd3}: font5x7 = 5'b10001;
                {8'd68, 3'd4}: font5x7 = 5'b10001;
                {8'd68, 3'd5}: font5x7 = 5'b10001;
                {8'd68, 3'd6}: font5x7 = 5'b11110;
                {8'd69, 3'd0}: font5x7 = 5'b11111;
                {8'd69, 3'd1}: font5x7 = 5'b10000;
                {8'd69, 3'd2}: font5x7 = 5'b10000;
                {8'd69, 3'd3}: font5x7 = 5'b11110;
                {8'd69, 3'd4}: font5x7 = 5'b10000;
                {8'd69, 3'd5}: font5x7 = 5'b10000;
                {8'd69, 3'd6}: font5x7 = 5'b11111;
                {8'd70, 3'd0}: font5x7 = 5'b11111;
                {8'd70, 3'd1}: font5x7 = 5'b10000;
                {8'd70, 3'd2}: font5x7 = 5'b10000;
                {8'd70, 3'd3}: font5x7 = 5'b11110;
                {8'd70, 3'd4}: font5x7 = 5'b10000;
                {8'd70, 3'd5}: font5x7 = 5'b10000;
                {8'd70, 3'd6}: font5x7 = 5'b10000;
                {8'd71, 3'd0}: font5x7 = 5'b01111;
                {8'd71, 3'd1}: font5x7 = 5'b10000;
                {8'd71, 3'd2}: font5x7 = 5'b10000;
                {8'd71, 3'd3}: font5x7 = 5'b10111;
                {8'd71, 3'd4}: font5x7 = 5'b10001;
                {8'd71, 3'd5}: font5x7 = 5'b10001;
                {8'd71, 3'd6}: font5x7 = 5'b01111;
                {8'd72, 3'd0}: font5x7 = 5'b10001;
                {8'd72, 3'd1}: font5x7 = 5'b10001;
                {8'd72, 3'd2}: font5x7 = 5'b10001;
                {8'd72, 3'd3}: font5x7 = 5'b11111;
                {8'd72, 3'd4}: font5x7 = 5'b10001;
                {8'd72, 3'd5}: font5x7 = 5'b10001;
                {8'd72, 3'd6}: font5x7 = 5'b10001;
                {8'd73, 3'd0}: font5x7 = 5'b01110;
                {8'd73, 3'd1}: font5x7 = 5'b00100;
                {8'd73, 3'd2}: font5x7 = 5'b00100;
                {8'd73, 3'd3}: font5x7 = 5'b00100;
                {8'd73, 3'd4}: font5x7 = 5'b00100;
                {8'd73, 3'd5}: font5x7 = 5'b00100;
                {8'd73, 3'd6}: font5x7 = 5'b01110;
                {8'd75, 3'd0}: font5x7 = 5'b10001;
                {8'd75, 3'd1}: font5x7 = 5'b10010;
                {8'd75, 3'd2}: font5x7 = 5'b10100;
                {8'd75, 3'd3}: font5x7 = 5'b11000;
                {8'd75, 3'd4}: font5x7 = 5'b10100;
                {8'd75, 3'd5}: font5x7 = 5'b10010;
                {8'd75, 3'd6}: font5x7 = 5'b10001;
                {8'd76, 3'd0}: font5x7 = 5'b10000;
                {8'd76, 3'd1}: font5x7 = 5'b10000;
                {8'd76, 3'd2}: font5x7 = 5'b10000;
                {8'd76, 3'd3}: font5x7 = 5'b10000;
                {8'd76, 3'd4}: font5x7 = 5'b10000;
                {8'd76, 3'd5}: font5x7 = 5'b10000;
                {8'd76, 3'd6}: font5x7 = 5'b11111;
                {8'd78, 3'd0}: font5x7 = 5'b10001;
                {8'd78, 3'd1}: font5x7 = 5'b11001;
                {8'd78, 3'd2}: font5x7 = 5'b10101;
                {8'd78, 3'd3}: font5x7 = 5'b10011;
                {8'd78, 3'd4}: font5x7 = 5'b10001;
                {8'd78, 3'd5}: font5x7 = 5'b10001;
                {8'd78, 3'd6}: font5x7 = 5'b10001;
                {8'd79, 3'd0}: font5x7 = 5'b01110;
                {8'd79, 3'd1}: font5x7 = 5'b10001;
                {8'd79, 3'd2}: font5x7 = 5'b10001;
                {8'd79, 3'd3}: font5x7 = 5'b10001;
                {8'd79, 3'd4}: font5x7 = 5'b10001;
                {8'd79, 3'd5}: font5x7 = 5'b10001;
                {8'd79, 3'd6}: font5x7 = 5'b01110;
                {8'd80, 3'd0}: font5x7 = 5'b11110;
                {8'd80, 3'd1}: font5x7 = 5'b10001;
                {8'd80, 3'd2}: font5x7 = 5'b10001;
                {8'd80, 3'd3}: font5x7 = 5'b11110;
                {8'd80, 3'd4}: font5x7 = 5'b10000;
                {8'd80, 3'd5}: font5x7 = 5'b10000;
                {8'd80, 3'd6}: font5x7 = 5'b10000;
                {8'd82, 3'd0}: font5x7 = 5'b11110;
                {8'd82, 3'd1}: font5x7 = 5'b10001;
                {8'd82, 3'd2}: font5x7 = 5'b10001;
                {8'd82, 3'd3}: font5x7 = 5'b11110;
                {8'd82, 3'd4}: font5x7 = 5'b10100;
                {8'd82, 3'd5}: font5x7 = 5'b10010;
                {8'd82, 3'd6}: font5x7 = 5'b10001;
                {8'd83, 3'd0}: font5x7 = 5'b01111;
                {8'd83, 3'd1}: font5x7 = 5'b10000;
                {8'd83, 3'd2}: font5x7 = 5'b10000;
                {8'd83, 3'd3}: font5x7 = 5'b01110;
                {8'd83, 3'd4}: font5x7 = 5'b00001;
                {8'd83, 3'd5}: font5x7 = 5'b00001;
                {8'd83, 3'd6}: font5x7 = 5'b11110;
                {8'd84, 3'd0}: font5x7 = 5'b11111;
                {8'd84, 3'd1}: font5x7 = 5'b00100;
                {8'd84, 3'd2}: font5x7 = 5'b00100;
                {8'd84, 3'd3}: font5x7 = 5'b00100;
                {8'd84, 3'd4}: font5x7 = 5'b00100;
                {8'd84, 3'd5}: font5x7 = 5'b00100;
                {8'd84, 3'd6}: font5x7 = 5'b00100;
                {8'd85, 3'd0}: font5x7 = 5'b10001;
                {8'd85, 3'd1}: font5x7 = 5'b10001;
                {8'd85, 3'd2}: font5x7 = 5'b10001;
                {8'd85, 3'd3}: font5x7 = 5'b10001;
                {8'd85, 3'd4}: font5x7 = 5'b10001;
                {8'd85, 3'd5}: font5x7 = 5'b10001;
                {8'd85, 3'd6}: font5x7 = 5'b01110;
                {8'd86, 3'd0}: font5x7 = 5'b10001;
                {8'd86, 3'd1}: font5x7 = 5'b10001;
                {8'd86, 3'd2}: font5x7 = 5'b10001;
                {8'd86, 3'd3}: font5x7 = 5'b10001;
                {8'd86, 3'd4}: font5x7 = 5'b10001;
                {8'd86, 3'd5}: font5x7 = 5'b01010;
                {8'd86, 3'd6}: font5x7 = 5'b00100;
                {8'd88, 3'd0}: font5x7 = 5'b10001;
                {8'd88, 3'd1}: font5x7 = 5'b10001;
                {8'd88, 3'd2}: font5x7 = 5'b01010;
                {8'd88, 3'd3}: font5x7 = 5'b00100;
                {8'd88, 3'd4}: font5x7 = 5'b01010;
                {8'd88, 3'd5}: font5x7 = 5'b10001;
                {8'd88, 3'd6}: font5x7 = 5'b10001;
                {8'd89, 3'd0}: font5x7 = 5'b10001;
                {8'd89, 3'd1}: font5x7 = 5'b10001;
                {8'd89, 3'd2}: font5x7 = 5'b01010;
                {8'd89, 3'd3}: font5x7 = 5'b00100;
                {8'd89, 3'd4}: font5x7 = 5'b00100;
                {8'd89, 3'd5}: font5x7 = 5'b00100;
                {8'd89, 3'd6}: font5x7 = 5'b00100;
                {8'd90, 3'd0}: font5x7 = 5'b11111;
                {8'd90, 3'd1}: font5x7 = 5'b00001;
                {8'd90, 3'd2}: font5x7 = 5'b00010;
                {8'd90, 3'd3}: font5x7 = 5'b00100;
                {8'd90, 3'd4}: font5x7 = 5'b01000;
                {8'd90, 3'd5}: font5x7 = 5'b10000;
                {8'd90, 3'd6}: font5x7 = 5'b11111;
                default: font5x7 = 5'b00000;
            endcase
        end
    endfunction

    wire [15:0] bar_0_value = ui_status_flat[96 +: 16];
    wire [25:0] bar_0_product = bar_0_value[9:0] * 16'd536;
    wire [15:0] bar_0_fill = bar_0_product >> 10;
    wire [15:0] bar_1_value = ui_status_flat[176 +: 16];
    wire [25:0] bar_1_product = bar_1_value[9:0] * 16'd384;
    wire [15:0] bar_1_fill = bar_1_product >> 10;
    wire [15:0] bar_2_value = ui_status_flat[192 +: 16];
    wire [25:0] bar_2_product = bar_2_value[9:0] * 16'd384;
    wire [15:0] bar_2_fill = bar_2_product >> 10;
    wire [15:0] bar_3_value = ui_status_flat[208 +: 16];
    wire [25:0] bar_3_product = bar_3_value[9:0] * 16'd384;
    wire [15:0] bar_3_fill = bar_3_product >> 10;
    wire [15:0] bar_4_value = ui_status_flat[224 +: 16];
    wire [25:0] bar_4_product = bar_4_value[9:0] * 16'd384;
    wire [15:0] bar_4_fill = bar_4_product >> 10;
    wire [15:0] bar_5_value = ui_status_flat[240 +: 16];
    wire [25:0] bar_5_product = bar_5_value[9:0] * 16'd384;
    wire [15:0] bar_5_fill = bar_5_product >> 10;
    wire [15:0] bar_6_value = ui_status_flat[256 +: 16];
    wire [25:0] bar_6_product = bar_6_value[9:0] * 16'd384;
    wire [15:0] bar_6_fill = bar_6_product >> 10;
    wire [15:0] bar_7_value = ui_status_flat[112 +: 16];
    wire [25:0] bar_7_product = bar_7_value[9:0] * 16'd248;
    wire [15:0] bar_7_fill = bar_7_product >> 10;
    wire [15:0] bar_8_value = ui_status_flat[128 +: 16];
    wire [25:0] bar_8_product = bar_8_value[9:0] * 16'd72;
    wire [15:0] bar_8_fill = bar_8_product >> 10;
    wire [15:0] bar_9_value = ui_status_flat[144 +: 16];
    wire [25:0] bar_9_product = bar_9_value[9:0] * 16'd72;
    wire [15:0] bar_9_fill = bar_9_product >> 10;
    wire [15:0] bar_10_value = ui_status_flat[160 +: 16];
    wire [25:0] bar_10_product = bar_10_value[9:0] * 16'd72;
    wire [15:0] bar_10_fill = bar_10_product >> 10;

    wire [10:0] text_0_lx = pixel_x - 11'd16;
    wire [9:0] text_0_ly = pixel_y - 10'd16;
    wire [7:0] text_0_index = text_0_lx / 16;
    reg [7:0] text_0_char;
    always @(*) begin
        case (text_0_index)
            8'd0: text_0_char = 8'd70;
            8'd1: text_0_char = 8'd80;
            8'd2: text_0_char = 8'd71;
            8'd3: text_0_char = 8'd65;
            8'd4: text_0_char = 8'd32;
            8'd5: text_0_char = 8'd83;
            8'd6: text_0_char = 8'd89;
            8'd7: text_0_char = 8'd78;
            8'd8: text_0_char = 8'd84;
            8'd9: text_0_char = 8'd72;
            8'd10: text_0_char = 8'd32;
            8'd11: text_0_char = 8'd65;
            8'd12: text_0_char = 8'd85;
            8'd13: text_0_char = 8'd84;
            8'd14: text_0_char = 8'd79;
            8'd15: text_0_char = 8'd32;
            8'd16: text_0_char = 8'd80;
            8'd17: text_0_char = 8'd76;
            8'd18: text_0_char = 8'd65;
            8'd19: text_0_char = 8'd89;
            8'd20: text_0_char = 8'd69;
            8'd21: text_0_char = 8'd82;
            default: text_0_char = 8'd32;
        endcase
    end
    wire [2:0] text_0_row = text_0_ly / 2;
    wire [2:0] text_0_col = (text_0_lx % 16) / 2;
    wire [4:0] text_0_glyph = font5x7(text_0_char, text_0_row);
    wire text_0_pixel = (text_0_lx < 430) &&
        (text_0_ly < 14) && (text_0_col < 5) &&
        text_0_glyph[4-text_0_col];

    wire [10:0] text_1_lx = pixel_x - 11'd560;
    wire [9:0] text_1_ly = pixel_y - 10'd16;
    wire [7:0] text_1_index = text_1_lx / 16;
    reg [7:0] text_1_char;
    always @(*) begin
        case (text_1_index)
            8'd0: text_1_char = 8'd56;
            8'd1: text_1_char = 8'd48;
            8'd2: text_1_char = 8'd48;
            8'd3: text_1_char = 8'd88;
            8'd4: text_1_char = 8'd52;
            8'd5: text_1_char = 8'd56;
            8'd6: text_1_char = 8'd48;
            8'd7: text_1_char = 8'd32;
            8'd8: text_1_char = 8'd54;
            8'd9: text_1_char = 8'd48;
            8'd10: text_1_char = 8'd72;
            8'd11: text_1_char = 8'd90;
            default: text_1_char = 8'd32;
        endcase
    end
    wire [2:0] text_1_row = text_1_ly / 2;
    wire [2:0] text_1_col = (text_1_lx % 16) / 2;
    wire [4:0] text_1_glyph = font5x7(text_1_char, text_1_row);
    wire text_1_pixel = (text_1_lx < 224) &&
        (text_1_ly < 14) && (text_1_col < 5) &&
        text_1_glyph[4-text_1_col];

    wire [10:0] text_2_lx = pixel_x - 11'd32;
    wire [9:0] text_2_ly = pixel_y - 10'd80;
    wire [7:0] text_2_index = text_2_lx / 16;
    reg [7:0] text_2_char;
    always @(*) begin
        case (text_2_index)
            8'd0: text_2_char = 8'd70;
            8'd1: text_2_char = 8'd73;
            8'd2: text_2_char = 8'd76;
            8'd3: text_2_char = 8'd69;
            default: text_2_char = 8'd32;
        endcase
    end
    wire [2:0] text_2_row = text_2_ly / 2;
    wire [2:0] text_2_col = (text_2_lx % 16) / 2;
    wire [4:0] text_2_glyph = font5x7(text_2_char, text_2_row);
    wire text_2_pixel = (text_2_lx < 64) &&
        (text_2_ly < 14) && (text_2_col < 5) &&
        text_2_glyph[4-text_2_col];

    wire [10:0] text_3_lx = pixel_x - 11'd112;
    wire [9:0] text_3_ly = pixel_y - 10'd80;
    wire [7:0] text_3_index = text_3_lx / 16;
    reg [7:0] text_3_char;
    always @(*) begin
        case (text_3_index)
            8'd0: text_3_char = ui_status_flat[272 +: 8];
            8'd1: text_3_char = ui_status_flat[280 +: 8];
            8'd2: text_3_char = ui_status_flat[288 +: 8];
            8'd3: text_3_char = ui_status_flat[296 +: 8];
            8'd4: text_3_char = ui_status_flat[304 +: 8];
            8'd5: text_3_char = ui_status_flat[312 +: 8];
            8'd6: text_3_char = ui_status_flat[320 +: 8];
            8'd7: text_3_char = ui_status_flat[328 +: 8];
            8'd8: text_3_char = ui_status_flat[336 +: 8];
            8'd9: text_3_char = ui_status_flat[344 +: 8];
            8'd10: text_3_char = ui_status_flat[352 +: 8];
            8'd11: text_3_char = ui_status_flat[360 +: 8];
            8'd12: text_3_char = ui_status_flat[368 +: 8];
            8'd13: text_3_char = ui_status_flat[376 +: 8];
            8'd14: text_3_char = ui_status_flat[384 +: 8];
            8'd15: text_3_char = ui_status_flat[392 +: 8];
            8'd16: text_3_char = ui_status_flat[400 +: 8];
            8'd17: text_3_char = ui_status_flat[408 +: 8];
            8'd18: text_3_char = ui_status_flat[416 +: 8];
            8'd19: text_3_char = ui_status_flat[424 +: 8];
            8'd20: text_3_char = ui_status_flat[432 +: 8];
            8'd21: text_3_char = ui_status_flat[440 +: 8];
            8'd22: text_3_char = ui_status_flat[448 +: 8];
            8'd23: text_3_char = ui_status_flat[456 +: 8];
            8'd24: text_3_char = ui_status_flat[464 +: 8];
            8'd25: text_3_char = ui_status_flat[472 +: 8];
            8'd26: text_3_char = ui_status_flat[480 +: 8];
            8'd27: text_3_char = ui_status_flat[488 +: 8];
            8'd28: text_3_char = ui_status_flat[496 +: 8];
            8'd29: text_3_char = ui_status_flat[504 +: 8];
            default: text_3_char = 8'd32;
        endcase
    end
    wire [2:0] text_3_row = text_3_ly / 2;
    wire [2:0] text_3_col = (text_3_lx % 16) / 2;
    wire [4:0] text_3_glyph = font5x7(text_3_char, text_3_row);
    wire text_3_pixel = (text_3_lx < 648) &&
        (text_3_ly < 14) && (text_3_col < 5) &&
        text_3_glyph[4-text_3_col];

    wire [10:0] text_4_lx = pixel_x - 11'd32;
    wire [9:0] text_4_ly = pixel_y - 10'd124;
    wire [7:0] text_4_index = text_4_lx / 8;
    reg [7:0] text_4_char;
    always @(*) begin
        case (text_4_index)
            8'd0: text_4_char = 8'd80;
            8'd1: text_4_char = 8'd76;
            8'd2: text_4_char = 8'd65;
            8'd3: text_4_char = 8'd89;
            8'd4: text_4_char = 8'd66;
            8'd5: text_4_char = 8'd65;
            8'd6: text_4_char = 8'd67;
            8'd7: text_4_char = 8'd75;
            8'd8: text_4_char = 8'd32;
            8'd9: text_4_char = 8'd80;
            8'd10: text_4_char = 8'd82;
            8'd11: text_4_char = 8'd79;
            8'd12: text_4_char = 8'd71;
            8'd13: text_4_char = 8'd82;
            8'd14: text_4_char = 8'd69;
            8'd15: text_4_char = 8'd83;
            8'd16: text_4_char = 8'd83;
            default: text_4_char = 8'd32;
        endcase
    end
    wire [2:0] text_4_row = text_4_ly / 1;
    wire [2:0] text_4_col = (text_4_lx % 8) / 1;
    wire [4:0] text_4_glyph = font5x7(text_4_char, text_4_row);
    wire text_4_pixel = (text_4_lx < 176) &&
        (text_4_ly < 7) && (text_4_col < 5) &&
        text_4_glyph[4-text_4_col];

    wire [10:0] text_5_lx = pixel_x - 11'd32;
    wire [9:0] text_5_ly = pixel_y - 10'd198;
    wire [7:0] text_5_index = text_5_lx / 16;
    reg [7:0] text_5_char;
    always @(*) begin
        case (text_5_index)
            8'd0: text_5_char = 8'd79;
            8'd1: text_5_char = 8'd80;
            8'd2: text_5_char = 8'd69;
            8'd3: text_5_char = 8'd82;
            8'd4: text_5_char = 8'd65;
            8'd5: text_5_char = 8'd84;
            8'd6: text_5_char = 8'd79;
            8'd7: text_5_char = 8'd82;
            8'd8: text_5_char = 8'd32;
            8'd9: text_5_char = 8'd76;
            8'd10: text_5_char = 8'd69;
            8'd11: text_5_char = 8'd86;
            8'd12: text_5_char = 8'd69;
            8'd13: text_5_char = 8'd76;
            8'd14: text_5_char = 8'd83;
            default: text_5_char = 8'd32;
        endcase
    end
    wire [2:0] text_5_row = text_5_ly / 2;
    wire [2:0] text_5_col = (text_5_lx % 16) / 2;
    wire [4:0] text_5_glyph = font5x7(text_5_char, text_5_row);
    wire text_5_pixel = (text_5_lx < 280) &&
        (text_5_ly < 14) && (text_5_col < 5) &&
        text_5_glyph[4-text_5_col];

    wire [10:0] text_6_lx = pixel_x - 11'd32;
    wire [9:0] text_6_ly = pixel_y - 10'd232;
    wire [7:0] text_6_index = text_6_lx / 8;
    reg [7:0] text_6_char;
    always @(*) begin
        case (text_6_index)
            8'd0: text_6_char = 8'd79;
            8'd1: text_6_char = 8'd80;
            8'd2: text_6_char = 8'd49;
            default: text_6_char = 8'd32;
        endcase
    end
    wire [2:0] text_6_row = text_6_ly / 1;
    wire [2:0] text_6_col = (text_6_lx % 8) / 1;
    wire [4:0] text_6_glyph = font5x7(text_6_char, text_6_row);
    wire text_6_pixel = (text_6_lx < 48) &&
        (text_6_ly < 7) && (text_6_col < 5) &&
        text_6_glyph[4-text_6_col];

    wire [10:0] text_7_lx = pixel_x - 11'd32;
    wire [9:0] text_7_ly = pixel_y - 10'd254;
    wire [7:0] text_7_index = text_7_lx / 8;
    reg [7:0] text_7_char;
    always @(*) begin
        case (text_7_index)
            8'd0: text_7_char = 8'd79;
            8'd1: text_7_char = 8'd80;
            8'd2: text_7_char = 8'd50;
            default: text_7_char = 8'd32;
        endcase
    end
    wire [2:0] text_7_row = text_7_ly / 1;
    wire [2:0] text_7_col = (text_7_lx % 8) / 1;
    wire [4:0] text_7_glyph = font5x7(text_7_char, text_7_row);
    wire text_7_pixel = (text_7_lx < 48) &&
        (text_7_ly < 7) && (text_7_col < 5) &&
        text_7_glyph[4-text_7_col];

    wire [10:0] text_8_lx = pixel_x - 11'd32;
    wire [9:0] text_8_ly = pixel_y - 10'd276;
    wire [7:0] text_8_index = text_8_lx / 8;
    reg [7:0] text_8_char;
    always @(*) begin
        case (text_8_index)
            8'd0: text_8_char = 8'd79;
            8'd1: text_8_char = 8'd80;
            8'd2: text_8_char = 8'd51;
            default: text_8_char = 8'd32;
        endcase
    end
    wire [2:0] text_8_row = text_8_ly / 1;
    wire [2:0] text_8_col = (text_8_lx % 8) / 1;
    wire [4:0] text_8_glyph = font5x7(text_8_char, text_8_row);
    wire text_8_pixel = (text_8_lx < 48) &&
        (text_8_ly < 7) && (text_8_col < 5) &&
        text_8_glyph[4-text_8_col];

    wire [10:0] text_9_lx = pixel_x - 11'd32;
    wire [9:0] text_9_ly = pixel_y - 10'd298;
    wire [7:0] text_9_index = text_9_lx / 8;
    reg [7:0] text_9_char;
    always @(*) begin
        case (text_9_index)
            8'd0: text_9_char = 8'd79;
            8'd1: text_9_char = 8'd80;
            8'd2: text_9_char = 8'd52;
            default: text_9_char = 8'd32;
        endcase
    end
    wire [2:0] text_9_row = text_9_ly / 1;
    wire [2:0] text_9_col = (text_9_lx % 8) / 1;
    wire [4:0] text_9_glyph = font5x7(text_9_char, text_9_row);
    wire text_9_pixel = (text_9_lx < 48) &&
        (text_9_ly < 7) && (text_9_col < 5) &&
        text_9_glyph[4-text_9_col];

    wire [10:0] text_10_lx = pixel_x - 11'd32;
    wire [9:0] text_10_ly = pixel_y - 10'd320;
    wire [7:0] text_10_index = text_10_lx / 8;
    reg [7:0] text_10_char;
    always @(*) begin
        case (text_10_index)
            8'd0: text_10_char = 8'd79;
            8'd1: text_10_char = 8'd80;
            8'd2: text_10_char = 8'd53;
            default: text_10_char = 8'd32;
        endcase
    end
    wire [2:0] text_10_row = text_10_ly / 1;
    wire [2:0] text_10_col = (text_10_lx % 8) / 1;
    wire [4:0] text_10_glyph = font5x7(text_10_char, text_10_row);
    wire text_10_pixel = (text_10_lx < 48) &&
        (text_10_ly < 7) && (text_10_col < 5) &&
        text_10_glyph[4-text_10_col];

    wire [10:0] text_11_lx = pixel_x - 11'd32;
    wire [9:0] text_11_ly = pixel_y - 10'd342;
    wire [7:0] text_11_index = text_11_lx / 8;
    reg [7:0] text_11_char;
    always @(*) begin
        case (text_11_index)
            8'd0: text_11_char = 8'd79;
            8'd1: text_11_char = 8'd80;
            8'd2: text_11_char = 8'd54;
            default: text_11_char = 8'd32;
        endcase
    end
    wire [2:0] text_11_row = text_11_ly / 1;
    wire [2:0] text_11_col = (text_11_lx % 8) / 1;
    wire [4:0] text_11_glyph = font5x7(text_11_char, text_11_row);
    wire text_11_pixel = (text_11_lx < 48) &&
        (text_11_ly < 7) && (text_11_col < 5) &&
        text_11_glyph[4-text_11_col];

    wire [10:0] text_12_lx = pixel_x - 11'd520;
    wire [9:0] text_12_ly = pixel_y - 10'd198;
    wire [7:0] text_12_index = text_12_lx / 16;
    reg [7:0] text_12_char;
    always @(*) begin
        case (text_12_index)
            8'd0: text_12_char = 8'd65;
            8'd1: text_12_char = 8'd85;
            8'd2: text_12_char = 8'd84;
            8'd3: text_12_char = 8'd79;
            8'd4: text_12_char = 8'd32;
            8'd5: text_12_char = 8'd83;
            8'd6: text_12_char = 8'd84;
            8'd7: text_12_char = 8'd65;
            8'd8: text_12_char = 8'd84;
            8'd9: text_12_char = 8'd85;
            8'd10: text_12_char = 8'd83;
            default: text_12_char = 8'd32;
        endcase
    end
    wire [2:0] text_12_row = text_12_ly / 2;
    wire [2:0] text_12_col = (text_12_lx % 16) / 2;
    wire [4:0] text_12_glyph = font5x7(text_12_char, text_12_row);
    wire text_12_pixel = (text_12_lx < 248) &&
        (text_12_ly < 14) && (text_12_col < 5) &&
        text_12_glyph[4-text_12_col];

    wire [10:0] text_13_lx = pixel_x - 11'd520;
    wire [9:0] text_13_ly = pixel_y - 10'd234;
    wire [7:0] text_13_index = text_13_lx / 8;
    reg [7:0] text_13_char;
    always @(*) begin
        case (text_13_index)
            8'd0: text_13_char = 8'd65;
            8'd1: text_13_char = 8'd67;
            8'd2: text_13_char = 8'd84;
            8'd3: text_13_char = 8'd73;
            8'd4: text_13_char = 8'd86;
            8'd5: text_13_char = 8'd69;
            8'd6: text_13_char = 8'd32;
            8'd7: text_13_char = 8'd86;
            8'd8: text_13_char = 8'd79;
            8'd9: text_13_char = 8'd73;
            8'd10: text_13_char = 8'd67;
            8'd11: text_13_char = 8'd69;
            8'd12: text_13_char = 8'd83;
            default: text_13_char = 8'd32;
        endcase
    end
    wire [2:0] text_13_row = text_13_ly / 1;
    wire [2:0] text_13_col = (text_13_lx % 8) / 1;
    wire [4:0] text_13_glyph = font5x7(text_13_char, text_13_row);
    wire text_13_pixel = (text_13_lx < 248) &&
        (text_13_ly < 7) && (text_13_col < 5) &&
        text_13_glyph[4-text_13_col];

    wire [10:0] text_14_lx = pixel_x - 11'd520;
    wire [9:0] text_14_ly = pixel_y - 10'd296;
    wire [7:0] text_14_index = text_14_lx / 8;
    reg [7:0] text_14_char;
    always @(*) begin
        case (text_14_index)
            8'd0: text_14_char = 8'd68;
            8'd1: text_14_char = 8'd69;
            8'd2: text_14_char = 8'd67;
            8'd3: text_14_char = 8'd79;
            8'd4: text_14_char = 8'd68;
            8'd5: text_14_char = 8'd69;
            8'd6: text_14_char = 8'd82;
            8'd7: text_14_char = 8'd32;
            8'd8: text_14_char = 8'd83;
            8'd9: text_14_char = 8'd68;
            8'd10: text_14_char = 8'd32;
            8'd11: text_14_char = 8'd80;
            8'd12: text_14_char = 8'd76;
            8'd13: text_14_char = 8'd65;
            8'd14: text_14_char = 8'd89;
            8'd15: text_14_char = 8'd69;
            8'd16: text_14_char = 8'd82;
            8'd17: text_14_char = 8'd32;
            8'd18: text_14_char = 8'd69;
            8'd19: text_14_char = 8'd82;
            8'd20: text_14_char = 8'd82;
            8'd21: text_14_char = 8'd79;
            8'd22: text_14_char = 8'd82;
            8'd23: text_14_char = 8'd83;
            default: text_14_char = 8'd32;
        endcase
    end
    wire [2:0] text_14_row = text_14_ly / 1;
    wire [2:0] text_14_col = (text_14_lx % 8) / 1;
    wire [4:0] text_14_glyph = font5x7(text_14_char, text_14_row);
    wire text_14_pixel = (text_14_lx < 248) &&
        (text_14_ly < 7) && (text_14_col < 5) &&
        text_14_glyph[4-text_14_col];

    wire [24:0] component_0 = ((pixel_x >= 0) && (pixel_x < 800) && (pixel_y >= 0) && (pixel_y < 480)) ? {1'b1, 24'h05070C} : 25'd0;
    wire [24:0] component_1 = ((pixel_x >= 0) && (pixel_x < 800) && (pixel_y >= 0) && (pixel_y < 48)) ? {1'b1, ((pixel_x < 1) || (pixel_x >= 799) || (pixel_y < 1) || (pixel_y >= 47)) ? 24'h1E293B : 24'h0F172A} : 25'd0;
    wire [24:0] component_2 = ((pixel_x >= 16) && (pixel_x < 784) && (pixel_y >= 64) && (pixel_y < 168)) ? {1'b1, ((pixel_x < 18) || (pixel_x >= 782) || (pixel_y < 66) || (pixel_y >= 166)) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] component_3 = ((pixel_x >= 16) && (pixel_x < 488) && (pixel_y >= 184) && (pixel_y < 376)) ? {1'b1, ((pixel_x < 18) || (pixel_x >= 486) || (pixel_y < 186) || (pixel_y >= 374)) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] component_4 = ((pixel_x >= 504) && (pixel_x < 784) && (pixel_y >= 184) && (pixel_y < 376)) ? {1'b1, ((pixel_x < 506) || (pixel_x >= 782) || (pixel_y < 186) || (pixel_y >= 374)) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] component_5 = ((pixel_x >= 16) && (pixel_x < 784) && (pixel_y >= 392) && (pixel_y < 464)) ? {1'b1, ((pixel_x < 18) || (pixel_x >= 782) || (pixel_y < 394) || (pixel_y >= 462)) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] component_6 = text_0_pixel ? {1'b1, 24'hE2E8F0} : 25'd0;
    wire [24:0] component_7 = text_1_pixel ? {1'b1, 24'h38BDF8} : 25'd0;
    wire [24:0] component_8 = text_2_pixel ? {1'b1, 24'h94A3B8} : 25'd0;
    wire [24:0] component_9 = text_3_pixel ? {1'b1, 24'hF1F5F9} : 25'd0;
    wire [24:0] component_10 = text_4_pixel ? {1'b1, 24'h94A3B8} : 25'd0;
    wire [24:0] component_11 = ((pixel_x >= 224) && (pixel_x < 760) && (pixel_y >= 122) && (pixel_y < 146)) ? {1'b1, ((pixel_x - 224) < bar_0_fill) ? 24'h38BDF8 : 24'h1E293B} : 25'd0;
    wire [24:0] component_12 = text_5_pixel ? {1'b1, 24'hE2E8F0} : 25'd0;
    wire [24:0] component_13 = text_6_pixel ? {1'b1, 24'h94A3B8} : 25'd0;
    wire [24:0] component_14 = ((pixel_x >= 88) && (pixel_x < 472) && (pixel_y >= 232) && (pixel_y < 246)) ? {1'b1, ((pixel_x - 88) < bar_1_fill) ? 24'h22C55E : 24'h1E293B} : 25'd0;
    wire [24:0] component_15 = text_7_pixel ? {1'b1, 24'h94A3B8} : 25'd0;
    wire [24:0] component_16 = ((pixel_x >= 88) && (pixel_x < 472) && (pixel_y >= 254) && (pixel_y < 268)) ? {1'b1, ((pixel_x - 88) < bar_2_fill) ? 24'h84CC16 : 24'h1E293B} : 25'd0;
    wire [24:0] component_17 = text_8_pixel ? {1'b1, 24'h94A3B8} : 25'd0;
    wire [24:0] component_18 = ((pixel_x >= 88) && (pixel_x < 472) && (pixel_y >= 276) && (pixel_y < 290)) ? {1'b1, ((pixel_x - 88) < bar_3_fill) ? 24'hEAB308 : 24'h1E293B} : 25'd0;
    wire [24:0] component_19 = text_9_pixel ? {1'b1, 24'h94A3B8} : 25'd0;
    wire [24:0] component_20 = ((pixel_x >= 88) && (pixel_x < 472) && (pixel_y >= 298) && (pixel_y < 312)) ? {1'b1, ((pixel_x - 88) < bar_4_fill) ? 24'hF97316 : 24'h1E293B} : 25'd0;
    wire [24:0] component_21 = text_10_pixel ? {1'b1, 24'h94A3B8} : 25'd0;
    wire [24:0] component_22 = ((pixel_x >= 88) && (pixel_x < 472) && (pixel_y >= 320) && (pixel_y < 334)) ? {1'b1, ((pixel_x - 88) < bar_5_fill) ? 24'hA855F7 : 24'h1E293B} : 25'd0;
    wire [24:0] component_23 = text_11_pixel ? {1'b1, 24'h94A3B8} : 25'd0;
    wire [24:0] component_24 = ((pixel_x >= 88) && (pixel_x < 472) && (pixel_y >= 342) && (pixel_y < 356)) ? {1'b1, ((pixel_x - 88) < bar_6_fill) ? 24'hEC4899 : 24'h1E293B} : 25'd0;
    wire [24:0] component_25 = text_12_pixel ? {1'b1, 24'hE2E8F0} : 25'd0;
    wire [24:0] component_26 = text_13_pixel ? {1'b1, 24'h94A3B8} : 25'd0;
    wire [24:0] component_27 = ((pixel_x >= 520) && (pixel_x < 768) && (pixel_y >= 260) && (pixel_y < 274)) ? {1'b1, ((pixel_x - 520) < bar_7_fill) ? 24'h14B8A6 : 24'h1E293B} : 25'd0;
    wire [24:0] component_28 = text_14_pixel ? {1'b1, 24'h94A3B8} : 25'd0;
    wire [24:0] component_29 = ((pixel_x >= 520) && (pixel_x < 592) && (pixel_y >= 340) && (pixel_y < 354)) ? {1'b1, ((pixel_x - 520) < bar_8_fill) ? 24'hEF4444 : 24'h1E293B} : 25'd0;
    wire [24:0] component_30 = ((pixel_x >= 608) && (pixel_x < 680) && (pixel_y >= 340) && (pixel_y < 354)) ? {1'b1, ((pixel_x - 608) < bar_9_fill) ? 24'hEF4444 : 24'h1E293B} : 25'd0;
    wire [24:0] component_31 = ((pixel_x >= 696) && (pixel_x < 768) && (pixel_y >= 340) && (pixel_y < 354)) ? {1'b1, ((pixel_x - 696) < bar_10_fill) ? 24'hEF4444 : 24'h1E293B} : 25'd0;
    wire [24:0] component_32 = ((pixel_x >= 32) && (pixel_x < 62) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 32) ? 24'h202632 : (note_active[48] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_33 = ((pixel_x >= 62) && (pixel_x < 93) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 62) ? 24'h202632 : (note_active[49] ? 24'h38BDF8 : 24'h111827)} : 25'd0;
    wire [24:0] component_34 = ((pixel_x >= 93) && (pixel_x < 124) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 93) ? 24'h202632 : (note_active[50] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_35 = ((pixel_x >= 124) && (pixel_x < 154) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 124) ? 24'h202632 : (note_active[51] ? 24'h38BDF8 : 24'h111827)} : 25'd0;
    wire [24:0] component_36 = ((pixel_x >= 154) && (pixel_x < 185) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 154) ? 24'h202632 : (note_active[52] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_37 = ((pixel_x >= 185) && (pixel_x < 216) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 185) ? 24'h202632 : (note_active[53] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_38 = ((pixel_x >= 216) && (pixel_x < 246) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 216) ? 24'h202632 : (note_active[54] ? 24'h38BDF8 : 24'h111827)} : 25'd0;
    wire [24:0] component_39 = ((pixel_x >= 246) && (pixel_x < 277) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 246) ? 24'h202632 : (note_active[55] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_40 = ((pixel_x >= 277) && (pixel_x < 308) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 277) ? 24'h202632 : (note_active[56] ? 24'h38BDF8 : 24'h111827)} : 25'd0;
    wire [24:0] component_41 = ((pixel_x >= 308) && (pixel_x < 338) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 308) ? 24'h202632 : (note_active[57] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_42 = ((pixel_x >= 338) && (pixel_x < 369) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 338) ? 24'h202632 : (note_active[58] ? 24'h38BDF8 : 24'h111827)} : 25'd0;
    wire [24:0] component_43 = ((pixel_x >= 369) && (pixel_x < 400) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 369) ? 24'h202632 : (note_active[59] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_44 = ((pixel_x >= 400) && (pixel_x < 430) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 400) ? 24'h202632 : (note_active[60] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_45 = ((pixel_x >= 430) && (pixel_x < 461) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 430) ? 24'h202632 : (note_active[61] ? 24'h38BDF8 : 24'h111827)} : 25'd0;
    wire [24:0] component_46 = ((pixel_x >= 461) && (pixel_x < 492) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 461) ? 24'h202632 : (note_active[62] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_47 = ((pixel_x >= 492) && (pixel_x < 522) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 492) ? 24'h202632 : (note_active[63] ? 24'h38BDF8 : 24'h111827)} : 25'd0;
    wire [24:0] component_48 = ((pixel_x >= 522) && (pixel_x < 553) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 522) ? 24'h202632 : (note_active[64] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_49 = ((pixel_x >= 553) && (pixel_x < 584) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 553) ? 24'h202632 : (note_active[65] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_50 = ((pixel_x >= 584) && (pixel_x < 614) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 584) ? 24'h202632 : (note_active[66] ? 24'h38BDF8 : 24'h111827)} : 25'd0;
    wire [24:0] component_51 = ((pixel_x >= 614) && (pixel_x < 645) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 614) ? 24'h202632 : (note_active[67] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_52 = ((pixel_x >= 645) && (pixel_x < 676) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 645) ? 24'h202632 : (note_active[68] ? 24'h38BDF8 : 24'h111827)} : 25'd0;
    wire [24:0] component_53 = ((pixel_x >= 676) && (pixel_x < 706) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 676) ? 24'h202632 : (note_active[69] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;
    wire [24:0] component_54 = ((pixel_x >= 706) && (pixel_x < 737) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 706) ? 24'h202632 : (note_active[70] ? 24'h38BDF8 : 24'h111827)} : 25'd0;
    wire [24:0] component_55 = ((pixel_x >= 737) && (pixel_x < 768) && (pixel_y >= 404) && (pixel_y < 452)) ? {1'b1, (pixel_x == 737) ? 24'h202632 : (note_active[71] ? 24'h38BDF8 : 24'hF1F5F9)} : 25'd0;

    wire [24:0] compose_l0_0 = component_1[24] ? component_1 : component_0;
    wire [24:0] compose_l0_1 = component_3[24] ? component_3 : component_2;
    wire [24:0] compose_l0_2 = component_5[24] ? component_5 : component_4;
    wire [24:0] compose_l0_3 = component_7[24] ? component_7 : component_6;
    wire [24:0] compose_l0_4 = component_9[24] ? component_9 : component_8;
    wire [24:0] compose_l0_5 = component_11[24] ? component_11 : component_10;
    wire [24:0] compose_l0_6 = component_13[24] ? component_13 : component_12;
    wire [24:0] compose_l0_7 = component_15[24] ? component_15 : component_14;
    wire [24:0] compose_l0_8 = component_17[24] ? component_17 : component_16;
    wire [24:0] compose_l0_9 = component_19[24] ? component_19 : component_18;
    wire [24:0] compose_l0_10 = component_21[24] ? component_21 : component_20;
    wire [24:0] compose_l0_11 = component_23[24] ? component_23 : component_22;
    wire [24:0] compose_l0_12 = component_25[24] ? component_25 : component_24;
    wire [24:0] compose_l0_13 = component_27[24] ? component_27 : component_26;
    wire [24:0] compose_l0_14 = component_29[24] ? component_29 : component_28;
    wire [24:0] compose_l0_15 = component_31[24] ? component_31 : component_30;
    wire [24:0] compose_l0_16 = component_33[24] ? component_33 : component_32;
    wire [24:0] compose_l0_17 = component_35[24] ? component_35 : component_34;
    wire [24:0] compose_l0_18 = component_37[24] ? component_37 : component_36;
    wire [24:0] compose_l0_19 = component_39[24] ? component_39 : component_38;
    wire [24:0] compose_l0_20 = component_41[24] ? component_41 : component_40;
    wire [24:0] compose_l0_21 = component_43[24] ? component_43 : component_42;
    wire [24:0] compose_l0_22 = component_45[24] ? component_45 : component_44;
    wire [24:0] compose_l0_23 = component_47[24] ? component_47 : component_46;
    wire [24:0] compose_l0_24 = component_49[24] ? component_49 : component_48;
    wire [24:0] compose_l0_25 = component_51[24] ? component_51 : component_50;
    wire [24:0] compose_l0_26 = component_53[24] ? component_53 : component_52;
    wire [24:0] compose_l0_27 = component_55[24] ? component_55 : component_54;
    reg [24:0] compose_pipe_0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_0 <= 25'd0;
        else compose_pipe_0 <= compose_l0_0;
    end
    reg [24:0] compose_pipe_1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_1 <= 25'd0;
        else compose_pipe_1 <= compose_l0_1;
    end
    reg [24:0] compose_pipe_2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_2 <= 25'd0;
        else compose_pipe_2 <= compose_l0_2;
    end
    reg [24:0] compose_pipe_3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_3 <= 25'd0;
        else compose_pipe_3 <= compose_l0_3;
    end
    reg [24:0] compose_pipe_4;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_4 <= 25'd0;
        else compose_pipe_4 <= compose_l0_4;
    end
    reg [24:0] compose_pipe_5;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_5 <= 25'd0;
        else compose_pipe_5 <= compose_l0_5;
    end
    reg [24:0] compose_pipe_6;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_6 <= 25'd0;
        else compose_pipe_6 <= compose_l0_6;
    end
    reg [24:0] compose_pipe_7;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_7 <= 25'd0;
        else compose_pipe_7 <= compose_l0_7;
    end
    reg [24:0] compose_pipe_8;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_8 <= 25'd0;
        else compose_pipe_8 <= compose_l0_8;
    end
    reg [24:0] compose_pipe_9;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_9 <= 25'd0;
        else compose_pipe_9 <= compose_l0_9;
    end
    reg [24:0] compose_pipe_10;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_10 <= 25'd0;
        else compose_pipe_10 <= compose_l0_10;
    end
    reg [24:0] compose_pipe_11;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_11 <= 25'd0;
        else compose_pipe_11 <= compose_l0_11;
    end
    reg [24:0] compose_pipe_12;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_12 <= 25'd0;
        else compose_pipe_12 <= compose_l0_12;
    end
    reg [24:0] compose_pipe_13;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_13 <= 25'd0;
        else compose_pipe_13 <= compose_l0_13;
    end
    reg [24:0] compose_pipe_14;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_14 <= 25'd0;
        else compose_pipe_14 <= compose_l0_14;
    end
    reg [24:0] compose_pipe_15;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_15 <= 25'd0;
        else compose_pipe_15 <= compose_l0_15;
    end
    reg [24:0] compose_pipe_16;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_16 <= 25'd0;
        else compose_pipe_16 <= compose_l0_16;
    end
    reg [24:0] compose_pipe_17;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_17 <= 25'd0;
        else compose_pipe_17 <= compose_l0_17;
    end
    reg [24:0] compose_pipe_18;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_18 <= 25'd0;
        else compose_pipe_18 <= compose_l0_18;
    end
    reg [24:0] compose_pipe_19;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_19 <= 25'd0;
        else compose_pipe_19 <= compose_l0_19;
    end
    reg [24:0] compose_pipe_20;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_20 <= 25'd0;
        else compose_pipe_20 <= compose_l0_20;
    end
    reg [24:0] compose_pipe_21;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_21 <= 25'd0;
        else compose_pipe_21 <= compose_l0_21;
    end
    reg [24:0] compose_pipe_22;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_22 <= 25'd0;
        else compose_pipe_22 <= compose_l0_22;
    end
    reg [24:0] compose_pipe_23;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_23 <= 25'd0;
        else compose_pipe_23 <= compose_l0_23;
    end
    reg [24:0] compose_pipe_24;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_24 <= 25'd0;
        else compose_pipe_24 <= compose_l0_24;
    end
    reg [24:0] compose_pipe_25;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_25 <= 25'd0;
        else compose_pipe_25 <= compose_l0_25;
    end
    reg [24:0] compose_pipe_26;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_26 <= 25'd0;
        else compose_pipe_26 <= compose_l0_26;
    end
    reg [24:0] compose_pipe_27;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) compose_pipe_27 <= 25'd0;
        else compose_pipe_27 <= compose_l0_27;
    end
    wire [24:0] compose_l1_0 = compose_pipe_1[24] ? compose_pipe_1 : compose_pipe_0;
    wire [24:0] compose_l1_1 = compose_pipe_3[24] ? compose_pipe_3 : compose_pipe_2;
    wire [24:0] compose_l1_2 = compose_pipe_5[24] ? compose_pipe_5 : compose_pipe_4;
    wire [24:0] compose_l1_3 = compose_pipe_7[24] ? compose_pipe_7 : compose_pipe_6;
    wire [24:0] compose_l1_4 = compose_pipe_9[24] ? compose_pipe_9 : compose_pipe_8;
    wire [24:0] compose_l1_5 = compose_pipe_11[24] ? compose_pipe_11 : compose_pipe_10;
    wire [24:0] compose_l1_6 = compose_pipe_13[24] ? compose_pipe_13 : compose_pipe_12;
    wire [24:0] compose_l1_7 = compose_pipe_15[24] ? compose_pipe_15 : compose_pipe_14;
    wire [24:0] compose_l1_8 = compose_pipe_17[24] ? compose_pipe_17 : compose_pipe_16;
    wire [24:0] compose_l1_9 = compose_pipe_19[24] ? compose_pipe_19 : compose_pipe_18;
    wire [24:0] compose_l1_10 = compose_pipe_21[24] ? compose_pipe_21 : compose_pipe_20;
    wire [24:0] compose_l1_11 = compose_pipe_23[24] ? compose_pipe_23 : compose_pipe_22;
    wire [24:0] compose_l1_12 = compose_pipe_25[24] ? compose_pipe_25 : compose_pipe_24;
    wire [24:0] compose_l1_13 = compose_pipe_27[24] ? compose_pipe_27 : compose_pipe_26;
    wire [24:0] compose_l2_0 = compose_l1_1[24] ? compose_l1_1 : compose_l1_0;
    wire [24:0] compose_l2_1 = compose_l1_3[24] ? compose_l1_3 : compose_l1_2;
    wire [24:0] compose_l2_2 = compose_l1_5[24] ? compose_l1_5 : compose_l1_4;
    wire [24:0] compose_l2_3 = compose_l1_7[24] ? compose_l1_7 : compose_l1_6;
    wire [24:0] compose_l2_4 = compose_l1_9[24] ? compose_l1_9 : compose_l1_8;
    wire [24:0] compose_l2_5 = compose_l1_11[24] ? compose_l1_11 : compose_l1_10;
    wire [24:0] compose_l2_6 = compose_l1_13[24] ? compose_l1_13 : compose_l1_12;
    wire [24:0] compose_l3_0 = compose_l2_1[24] ? compose_l2_1 : compose_l2_0;
    wire [24:0] compose_l3_1 = compose_l2_3[24] ? compose_l2_3 : compose_l2_2;
    wire [24:0] compose_l3_2 = compose_l2_5[24] ? compose_l2_5 : compose_l2_4;
    wire [24:0] compose_l4_0 = compose_l3_1[24] ? compose_l3_1 : compose_l3_0;
    wire [24:0] compose_l4_1 = compose_l2_6[24] ? compose_l2_6 : compose_l3_2;
    wire [24:0] compose_l5_0 = compose_l4_1[24] ? compose_l4_1 : compose_l4_0;
    assign pixel_rgb = compose_l5_0[24] ? compose_l5_0[23:0] : 24'h05070C;

    wire unused_contract_inputs = clk ^ rst_n;
endmodule
