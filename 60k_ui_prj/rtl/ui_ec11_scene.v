// Layout SHA256: a5822872b8aa39503b1e7a382e2d5b8d71a31ed9aa6d6fb7dbc2974afecdf51e
// Font SHA256: 092d4d0395970dd3f0d6b8eaeedf2e114265ee4bcbb28e1c06095181593003f2
`timescale 1ns / 1ps
// Fixed UI-only contract; generated geometry follows the named PC widgets.
module ui_ec11_scene (
    input wire clk,
    input wire rst_n,
    input wire frame_start,
    input wire [10:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire [1:0] page,
    input wire [3:0] focus,
    input wire editing,
    input wire [7:0] rate,
    input wire [7:0] depth,
    input wire [7:0] width_value,
    input wire [7:0] mix,
    input wire [2:0] preset,
    input wire fx_enable,
    input wire [2:0] selected_item,
    input wire [7:0] last_action,
    input wire [15:0] action_count,
    output wire [23:0] pixel_rgb
);
    // Freeze all displayed state for an entire frame: no torn page/focus.
    reg [1:0] page_s;
    reg [3:0] focus_s;
    reg editing_s;
    reg [7:0] rate_s, depth_s, width_s, mix_s;
    reg [2:0] preset_s, selected_s;
    reg fx_s;
    reg [7:0] action_s;
    reg [15:0] count_s;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            page_s<=0; focus_s<=0; editing_s<=0;
            rate_s<=64; depth_s<=128; width_s<=128; mix_s<=64;
            preset_s<=0; selected_s<=0; fx_s<=1; action_s<=0; count_s<=0;
        end else if (frame_start) begin
            page_s<=page; focus_s<=focus; editing_s<=editing;
            rate_s<=rate; depth_s<=depth; width_s<=width_value; mix_s<=mix;
            preset_s<=preset; selected_s<=selected_item; fx_s<=fx_enable;
            action_s<=last_action; count_s<=action_count;
        end
    end
    reg [511:0] status;
    always @* begin
        status=0;
        status[0*16+:16]={8'd0,width_s};
        status[1*16+:16]={8'd0,mix_s};
        status[4*16+:16]={15'd0,fx_s};
        status[5*16+:16]={13'd0,selected_s};
        status[7*16+:16]={13'd0,preset_s};
        status[8*16+:16]={8'd0,action_s};
        status[9*16+:16]=count_s;
        // Bit replication maps 0..255 exactly onto 0..1023 without division.
        status[11*16+:16]={6'd0,rate_s,rate_s[7:6]};
        status[12*16+:16]={6'd0,depth_s,depth_s[7:6]};
        status[13*16+:16]={6'd0,width_s,width_s[7:6]};
        status[14*16+:16]={6'd0,mix_s,mix_s[7:6]};
        status[15*16+:16]={8'd0,rate_s};
        status[16*16+:16]={8'd0,depth_s};
    end
    wire [23:0] bg0, bg1, bg2;
    wire [38:0] text0, text1, text2;
    ui_ec11_page_0 u_sd (
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .ui_status_flat(status),
        .background_rgb(bg0),
        .text_descriptor(text0)
    );
    ui_ec11_page_1 u_fx (
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .ui_status_flat(status),
        .background_rgb(bg1),
        .text_descriptor(text1)
    );
    ui_ec11_page_2 u_play (
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .ui_status_flat(status),
        .background_rgb(bg2),
        .text_descriptor(text2)
    );
    // Pick a page/text descriptor BEFORE the shared synchronous font ROM.
    wire [38:0] text_now = (page_s==0) ? text0 : (page_s==1) ? text1 : text2;
    wire [23:0] bg_now = (page_s==0) ? bg0 : (page_s==1) ? bg1 : bg2;
    wire [7:0] glyph_row;
    ui_ec11_font_rom u_font (
        .clk(clk),
        .char_code(text_now[13:7]),
        .row(text_now[6:3]),
        .pixels(glyph_row)
    );
    reg [10:0] fx, fw, sx, sw;
    reg [9:0] fy, fh, sy, sh;
    always @* begin
        fx=0; fy=0; fw=0; fh=0;
        if (focus_s < 3) begin
            case (focus_s)
            4'd0: begin fx=16; fy=44; fw=248; fh=40; end
            4'd1: begin fx=276; fy=44; fw=248; fh=40; end
            4'd2: begin fx=536; fy=44; fw=248; fh=40; end
            endcase
        end else begin
            case (page_s)
            2'd0: case (focus_s)
                4'd3: begin fx=32; fy=348; fw=144; fh=48; end
                4'd4: begin fx=192; fy=348; fw=104; fh=48; end
                4'd5: begin fx=312; fy=348; fw=104; fh=48; end
                4'd6: begin fx=432; fy=348; fw=336; fh=48; end
            endcase
            2'd1: case (focus_s)
                4'd3: begin fx=32; fy=146; fw=96; fh=44; end
                4'd4: begin fx=136; fy=146; fw=96; fh=44; end
                4'd5: begin fx=240; fy=146; fw=96; fh=44; end
                4'd6: begin fx=344; fy=146; fw=96; fh=44; end
                4'd7: begin fx=448; fy=146; fw=96; fh=44; end
                4'd8: begin fx=552; fy=146; fw=96; fh=44; end
                4'd9: begin fx=656; fy=146; fw=96; fh=44; end
                4'd10: begin fx=84; fy=264; fw=80; fh=80; end
                4'd11: begin fx=268; fy=264; fw=80; fh=80; end
                4'd12: begin fx=452; fy=264; fw=80; fh=80; end
                4'd13: begin fx=636; fy=264; fw=80; fh=80; end
                4'd14: begin fx=32; fy=380; fw=136; fh=32; end
                4'd15: begin fx=184; fy=380; fw=160; fh=32; end
            endcase
            2'd2: case (focus_s)
                4'd3: begin fx=32; fy=254; fw=224; fh=54; end
                4'd4: begin fx=288; fy=254; fw=224; fh=54; end
                4'd5: begin fx=544; fy=254; fw=224; fh=54; end
                4'd6: begin fx=32; fy=336; fw=736; fh=44; end
            endcase
            endcase
        end
        sx=0; sy=0; sw=0; sh=0;
        case (page_s)
            2'd0: case (selected_s)
                3'd0: begin sx=24; sy=191; sw=752; sh=23; end
                3'd1: begin sx=24; sy=213; sw=752; sh=23; end
                3'd2: begin sx=24; sy=235; sw=752; sh=23; end
                3'd3: begin sx=24; sy=257; sw=752; sh=23; end
                3'd4: begin sx=24; sy=279; sw=752; sh=23; end
                3'd5: begin sx=24; sy=301; sw=752; sh=23; end
            endcase
            2'd1: case (preset_s)
                3'd0: begin sx=32; sy=146; sw=96; sh=44; end
                3'd1: begin sx=136; sy=146; sw=96; sh=44; end
                3'd2: begin sx=240; sy=146; sw=96; sh=44; end
                3'd3: begin sx=344; sy=146; sw=96; sh=44; end
                3'd4: begin sx=448; sy=146; sw=96; sh=44; end
                3'd5: begin sx=552; sy=146; sw=96; sh=44; end
                3'd6: begin sx=656; sy=146; sw=96; sh=44; end
            endcase
        endcase
    end
    wire focus_hit = (fw != 0) && pixel_x>=fx && pixel_x<fx+fw &&
        pixel_y>=fy && pixel_y<fy+fh &&
        (pixel_x<fx+2 || pixel_x>=fx+fw-2 || pixel_y<fy+2 || pixel_y>=fy+fh-2);
    wire selected_hit = (sw != 0) && pixel_x>=sx && pixel_x<sx+sw &&
        pixel_y>=sy && pixel_y<sy+sh &&
        (pixel_x==sx || pixel_x==sx+sw-1 || pixel_y==sy || pixel_y==sy+sh-1);
    reg focus_q, selected_q, editing_q;
    reg text_valid_q;
    reg [23:0] text_color_q, bg_q;
    reg [2:0] text_col_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            focus_q<=0; selected_q<=0; editing_q<=0;
            text_valid_q<=0; text_color_q<=0; text_col_q<=0; bg_q<=24'h05070C;
        end else begin
            focus_q<=focus_hit;
            selected_q<=selected_hit; editing_q<=editing_s;
            text_valid_q<=text_now[38]; text_color_q<=text_now[37:14];
            text_col_q<=text_now[2:0]; bg_q<=bg_now;
        end
    end
    wire [23:0] page_rgb = (text_valid_q && glyph_row[7-text_col_q]) ? text_color_q : bg_q;
    // ROM, RGB, column and outlines all share the same one-cycle pipeline.
    assign pixel_rgb = focus_q ? (editing_q ? 24'hFBBF24 : 24'h38BDF8) :
                       selected_q ? 24'h34D399 : page_rgb;
endmodule

module ui_ec11_page_0 (
    input wire [10:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire [511:0] ui_status_flat,
    output wire [23:0] background_rgb,
    output wire [38:0] text_descriptor
);
    function [6:0] hexchar;
        input [3:0] nibble;
        begin hexchar=(nibble<10)?7'd48+nibble:7'd55+nibble; end
    endfunction
    wire [24:0] background_0 = (pixel_x>=16 && pixel_x<784 && pixel_y>=100 && pixel_y<410) ? {1'b1, (pixel_x<17 || pixel_x>=783 || pixel_y<101 || pixel_y>=409) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_1 = (pixel_x>=32 && pixel_x<176 && pixel_y>=348 && pixel_y<396) ? {1'b1, (pixel_x<33 || pixel_x>=175 || pixel_y<349 || pixel_y>=395) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_2 = (pixel_x>=192 && pixel_x<296 && pixel_y>=348 && pixel_y<396) ? {1'b1, (pixel_x<193 || pixel_x>=295 || pixel_y<349 || pixel_y>=395) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_3 = (pixel_x>=312 && pixel_x<416 && pixel_y>=348 && pixel_y<396) ? {1'b1, (pixel_x<313 || pixel_x>=415 || pixel_y<349 || pixel_y>=395) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_4 = (pixel_x>=432 && pixel_x<768 && pixel_y>=348 && pixel_y<396) ? {1'b1, (pixel_x<433 || pixel_x>=767 || pixel_y<349 || pixel_y>=395) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_5 = (pixel_x>=16 && pixel_x<264 && pixel_y>=44 && pixel_y<84) ? {1'b1, (pixel_x<17 || pixel_x>=263 || pixel_y<45 || pixel_y>=83) ? 24'h38BDF8 : 24'h0F172A} : 25'd0;
    wire [24:0] background_6 = (pixel_x>=276 && pixel_x<524 && pixel_y>=44 && pixel_y<84) ? {1'b1, (pixel_x<277 || pixel_x>=523 || pixel_y<45 || pixel_y>=83) ? 24'h38BDF8 : 24'h0F172A} : 25'd0;
    wire [24:0] background_7 = (pixel_x>=536 && pixel_x<784 && pixel_y>=44 && pixel_y<84) ? {1'b1, (pixel_x<537 || pixel_x>=783 || pixel_y<45 || pixel_y>=83) ? 24'h38BDF8 : 24'h0F172A} : 25'd0;
    wire [24:0] bg_compose_0_0 = background_1[24] ? background_1 : background_0;
    wire [24:0] bg_compose_0_1 = background_3[24] ? background_3 : background_2;
    wire [24:0] bg_compose_0_2 = background_5[24] ? background_5 : background_4;
    wire [24:0] bg_compose_0_3 = background_7[24] ? background_7 : background_6;
    wire [24:0] bg_compose_1_0 = bg_compose_0_1[24] ? bg_compose_0_1 : bg_compose_0_0;
    wire [24:0] bg_compose_1_1 = bg_compose_0_3[24] ? bg_compose_0_3 : bg_compose_0_2;
    wire [24:0] bg_compose_2_0 = bg_compose_1_1[24] ? bg_compose_1_1 : bg_compose_1_0;
    assign background_rgb=bg_compose_2_0[24] ? bg_compose_2_0[23:0] : 24'h05070C;
    wire [10:0] text_0_lx=pixel_x-11'd16;
    wire [9:0] text_0_ly=pixel_y-10'd8;
    wire [7:0] text_0_index=text_0_lx/16;
    wire [3:0] text_0_row=text_0_ly/2;
    wire [2:0] text_0_col=(text_0_lx%16)/2;
    reg [6:0] text_0_char;
    always @* begin
        case (text_0_index)
            8'd0: text_0_char=7'd69;
            8'd1: text_0_char=7'd67;
            8'd2: text_0_char=7'd49;
            8'd3: text_0_char=7'd49;
            8'd4: text_0_char=7'd32;
            8'd5: text_0_char=7'd47;
            8'd6: text_0_char=7'd32;
            8'd7: text_0_char=7'd84;
            8'd8: text_0_char=7'd72;
            8'd9: text_0_char=7'd82;
            8'd10: text_0_char=7'd69;
            8'd11: text_0_char=7'd69;
            8'd12: text_0_char=7'd32;
            8'd13: text_0_char=7'd80;
            8'd14: text_0_char=7'd65;
            8'd15: text_0_char=7'd71;
            8'd16: text_0_char=7'd69;
            8'd17: text_0_char=7'd32;
            8'd18: text_0_char=7'd85;
            8'd19: text_0_char=7'd73;
            default: text_0_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_0=(text_0_lx<320 && text_0_ly<32) ? {1'b1,24'hE2E8F0,text_0_char,text_0_row,text_0_col} : 39'd0;
    wire [10:0] text_1_lx=pixel_x-11'd492;
    wire [9:0] text_1_ly=pixel_y-10'd12;
    wire [7:0] text_1_index=text_1_lx/8;
    wire [3:0] text_1_row=text_1_ly/1;
    wire [2:0] text_1_col=(text_1_lx%8)/1;
    reg [6:0] text_1_char;
    always @* begin
        case (text_1_index)
            8'd0: text_1_char=7'd76;
            8'd1: text_1_char=7'd79;
            8'd2: text_1_char=7'd67;
            8'd3: text_1_char=7'd65;
            8'd4: text_1_char=7'd76;
            8'd5: text_1_char=7'd32;
            8'd6: text_1_char=7'd84;
            8'd7: text_1_char=7'd69;
            8'd8: text_1_char=7'd83;
            8'd9: text_1_char=7'd84;
            8'd10: text_1_char=7'd32;
            8'd11: text_1_char=7'd45;
            8'd12: text_1_char=7'd32;
            8'd13: text_1_char=7'd78;
            8'd14: text_1_char=7'd79;
            8'd15: text_1_char=7'd32;
            8'd16: text_1_char=7'd83;
            8'd17: text_1_char=7'd68;
            8'd18: text_1_char=7'd47;
            8'd19: text_1_char=7'd65;
            8'd20: text_1_char=7'd85;
            8'd21: text_1_char=7'd68;
            8'd22: text_1_char=7'd73;
            8'd23: text_1_char=7'd79;
            default: text_1_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_1=(text_1_lx<192 && text_1_ly<16) ? {1'b1,24'hE2E8F0,text_1_char,text_1_row,text_1_col} : 39'd0;
    wire [10:0] text_2_lx=pixel_x-11'd16;
    wire [9:0] text_2_ly=pixel_y-10'd464;
    wire [7:0] text_2_index=text_2_lx/8;
    wire [3:0] text_2_row=text_2_ly/1;
    wire [2:0] text_2_col=(text_2_lx%8)/1;
    reg [6:0] text_2_char;
    always @* begin
        case (text_2_index)
            8'd0: text_2_char=7'd82;
            8'd1: text_2_char=7'd79;
            8'd2: text_2_char=7'd84;
            8'd3: text_2_char=7'd65;
            8'd4: text_2_char=7'd84;
            8'd5: text_2_char=7'd69;
            8'd6: text_2_char=7'd58;
            8'd7: text_2_char=7'd32;
            8'd8: text_2_char=7'd70;
            8'd9: text_2_char=7'd79;
            8'd10: text_2_char=7'd67;
            8'd11: text_2_char=7'd85;
            8'd12: text_2_char=7'd83;
            8'd13: text_2_char=7'd32;
            8'd14: text_2_char=7'd45;
            8'd15: text_2_char=7'd32;
            8'd16: text_2_char=7'd67;
            8'd17: text_2_char=7'd76;
            8'd18: text_2_char=7'd73;
            8'd19: text_2_char=7'd67;
            8'd20: text_2_char=7'd75;
            8'd21: text_2_char=7'd58;
            8'd22: text_2_char=7'd32;
            8'd23: text_2_char=7'd69;
            8'd24: text_2_char=7'd78;
            8'd25: text_2_char=7'd84;
            8'd26: text_2_char=7'd69;
            8'd27: text_2_char=7'd82;
            8'd28: text_2_char=7'd47;
            8'd29: text_2_char=7'd79;
            8'd30: text_2_char=7'd75;
            8'd31: text_2_char=7'd32;
            8'd32: text_2_char=7'd45;
            8'd33: text_2_char=7'd32;
            8'd34: text_2_char=7'd72;
            8'd35: text_2_char=7'd79;
            8'd36: text_2_char=7'd76;
            8'd37: text_2_char=7'd68;
            8'd38: text_2_char=7'd32;
            8'd39: text_2_char=7'd48;
            8'd40: text_2_char=7'd46;
            8'd41: text_2_char=7'd56;
            8'd42: text_2_char=7'd83;
            8'd43: text_2_char=7'd58;
            8'd44: text_2_char=7'd32;
            8'd45: text_2_char=7'd67;
            8'd46: text_2_char=7'd65;
            8'd47: text_2_char=7'd78;
            8'd48: text_2_char=7'd67;
            8'd49: text_2_char=7'd69;
            8'd50: text_2_char=7'd76;
            8'd51: text_2_char=7'd47;
            8'd52: text_2_char=7'd66;
            8'd53: text_2_char=7'd65;
            8'd54: text_2_char=7'd67;
            8'd55: text_2_char=7'd75;
            default: text_2_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_2=(text_2_lx<448 && text_2_ly<16) ? {1'b1,24'hE2E8F0,text_2_char,text_2_row,text_2_col} : 39'd0;
    wire [10:0] text_3_lx=pixel_x-11'd32;
    wire [9:0] text_3_ly=pixel_y-10'd116;
    wire [7:0] text_3_index=text_3_lx/16;
    wire [3:0] text_3_row=text_3_ly/2;
    wire [2:0] text_3_col=(text_3_lx%16)/2;
    reg [6:0] text_3_char;
    always @* begin
        case (text_3_index)
            8'd0: text_3_char=7'd68;
            8'd1: text_3_char=7'd69;
            8'd2: text_3_char=7'd77;
            8'd3: text_3_char=7'd79;
            8'd4: text_3_char=7'd32;
            8'd5: text_3_char=7'd73;
            8'd6: text_3_char=7'd84;
            8'd7: text_3_char=7'd69;
            8'd8: text_3_char=7'd77;
            8'd9: text_3_char=7'd58;
            8'd10: text_3_char=7'd32;
            8'd11: text_3_char=hexchar(ui_status_flat[80+:4]);
            default: text_3_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_3=(text_3_lx<192 && text_3_ly<32) ? {1'b1,24'hE2E8F0,text_3_char,text_3_row,text_3_col} : 39'd0;
    wire [10:0] text_4_lx=pixel_x-11'd32;
    wire [9:0] text_4_ly=pixel_y-10'd154;
    wire [7:0] text_4_index=text_4_lx/8;
    wire [3:0] text_4_row=text_4_ly/1;
    wire [2:0] text_4_col=(text_4_lx%8)/1;
    reg [6:0] text_4_char;
    always @* begin
        case (text_4_index)
            8'd0: text_4_char=7'd83;
            8'd1: text_4_char=7'd68;
            8'd2: text_4_char=7'd32;
            8'd3: text_4_char=7'd66;
            8'd4: text_4_char=7'd65;
            8'd5: text_4_char=7'd67;
            8'd6: text_4_char=7'd75;
            8'd7: text_4_char=7'd69;
            8'd8: text_4_char=7'd78;
            8'd9: text_4_char=7'd68;
            8'd10: text_4_char=7'd32;
            8'd11: text_4_char=7'd78;
            8'd12: text_4_char=7'd79;
            8'd13: text_4_char=7'd84;
            8'd14: text_4_char=7'd32;
            8'd15: text_4_char=7'd67;
            8'd16: text_4_char=7'd79;
            8'd17: text_4_char=7'd78;
            8'd18: text_4_char=7'd78;
            8'd19: text_4_char=7'd69;
            8'd20: text_4_char=7'd67;
            8'd21: text_4_char=7'd84;
            8'd22: text_4_char=7'd69;
            8'd23: text_4_char=7'd68;
            8'd24: text_4_char=7'd32;
            8'd25: text_4_char=7'd45;
            8'd26: text_4_char=7'd32;
            8'd27: text_4_char=7'd68;
            8'd28: text_4_char=7'd69;
            8'd29: text_4_char=7'd77;
            8'd30: text_4_char=7'd79;
            8'd31: text_4_char=7'd32;
            8'd32: text_4_char=7'd73;
            8'd33: text_4_char=7'd84;
            8'd34: text_4_char=7'd69;
            8'd35: text_4_char=7'd77;
            8'd36: text_4_char=7'd83;
            8'd37: text_4_char=7'd32;
            8'd38: text_4_char=7'd79;
            8'd39: text_4_char=7'd78;
            8'd40: text_4_char=7'd76;
            8'd41: text_4_char=7'd89;
            default: text_4_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_4=(text_4_lx<336 && text_4_ly<16) ? {1'b1,24'hE2E8F0,text_4_char,text_4_row,text_4_col} : 39'd0;
    wire [10:0] text_5_lx=pixel_x-11'd32;
    wire [9:0] text_5_ly=pixel_y-10'd194;
    wire [7:0] text_5_index=text_5_lx/8;
    wire [3:0] text_5_row=text_5_ly/1;
    wire [2:0] text_5_col=(text_5_lx%8)/1;
    reg [6:0] text_5_char;
    always @* begin
        case (text_5_index)
            8'd0: text_5_char=7'd68;
            8'd1: text_5_char=7'd69;
            8'd2: text_5_char=7'd77;
            8'd3: text_5_char=7'd79;
            8'd4: text_5_char=7'd32;
            8'd5: text_5_char=7'd48;
            8'd6: text_5_char=7'd32;
            8'd7: text_5_char=7'd45;
            8'd8: text_5_char=7'd32;
            8'd9: text_5_char=7'd85;
            8'd10: text_5_char=7'd73;
            8'd11: text_5_char=7'd32;
            8'd12: text_5_char=7'd73;
            8'd13: text_5_char=7'd84;
            8'd14: text_5_char=7'd69;
            8'd15: text_5_char=7'd77;
            8'd16: text_5_char=7'd32;
            8'd17: text_5_char=7'd79;
            8'd18: text_5_char=7'd78;
            8'd19: text_5_char=7'd76;
            8'd20: text_5_char=7'd89;
            default: text_5_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_5=(text_5_lx<168 && text_5_ly<16) ? {1'b1,24'hE2E8F0,text_5_char,text_5_row,text_5_col} : 39'd0;
    wire [10:0] text_6_lx=pixel_x-11'd32;
    wire [9:0] text_6_ly=pixel_y-10'd216;
    wire [7:0] text_6_index=text_6_lx/8;
    wire [3:0] text_6_row=text_6_ly/1;
    wire [2:0] text_6_col=(text_6_lx%8)/1;
    reg [6:0] text_6_char;
    always @* begin
        case (text_6_index)
            8'd0: text_6_char=7'd68;
            8'd1: text_6_char=7'd69;
            8'd2: text_6_char=7'd77;
            8'd3: text_6_char=7'd79;
            8'd4: text_6_char=7'd32;
            8'd5: text_6_char=7'd49;
            8'd6: text_6_char=7'd32;
            8'd7: text_6_char=7'd45;
            8'd8: text_6_char=7'd32;
            8'd9: text_6_char=7'd85;
            8'd10: text_6_char=7'd73;
            8'd11: text_6_char=7'd32;
            8'd12: text_6_char=7'd73;
            8'd13: text_6_char=7'd84;
            8'd14: text_6_char=7'd69;
            8'd15: text_6_char=7'd77;
            8'd16: text_6_char=7'd32;
            8'd17: text_6_char=7'd79;
            8'd18: text_6_char=7'd78;
            8'd19: text_6_char=7'd76;
            8'd20: text_6_char=7'd89;
            default: text_6_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_6=(text_6_lx<168 && text_6_ly<16) ? {1'b1,24'hE2E8F0,text_6_char,text_6_row,text_6_col} : 39'd0;
    wire [10:0] text_7_lx=pixel_x-11'd32;
    wire [9:0] text_7_ly=pixel_y-10'd238;
    wire [7:0] text_7_index=text_7_lx/8;
    wire [3:0] text_7_row=text_7_ly/1;
    wire [2:0] text_7_col=(text_7_lx%8)/1;
    reg [6:0] text_7_char;
    always @* begin
        case (text_7_index)
            8'd0: text_7_char=7'd68;
            8'd1: text_7_char=7'd69;
            8'd2: text_7_char=7'd77;
            8'd3: text_7_char=7'd79;
            8'd4: text_7_char=7'd32;
            8'd5: text_7_char=7'd50;
            8'd6: text_7_char=7'd32;
            8'd7: text_7_char=7'd45;
            8'd8: text_7_char=7'd32;
            8'd9: text_7_char=7'd85;
            8'd10: text_7_char=7'd73;
            8'd11: text_7_char=7'd32;
            8'd12: text_7_char=7'd73;
            8'd13: text_7_char=7'd84;
            8'd14: text_7_char=7'd69;
            8'd15: text_7_char=7'd77;
            8'd16: text_7_char=7'd32;
            8'd17: text_7_char=7'd79;
            8'd18: text_7_char=7'd78;
            8'd19: text_7_char=7'd76;
            8'd20: text_7_char=7'd89;
            default: text_7_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_7=(text_7_lx<168 && text_7_ly<16) ? {1'b1,24'hE2E8F0,text_7_char,text_7_row,text_7_col} : 39'd0;
    wire [10:0] text_8_lx=pixel_x-11'd32;
    wire [9:0] text_8_ly=pixel_y-10'd260;
    wire [7:0] text_8_index=text_8_lx/8;
    wire [3:0] text_8_row=text_8_ly/1;
    wire [2:0] text_8_col=(text_8_lx%8)/1;
    reg [6:0] text_8_char;
    always @* begin
        case (text_8_index)
            8'd0: text_8_char=7'd68;
            8'd1: text_8_char=7'd69;
            8'd2: text_8_char=7'd77;
            8'd3: text_8_char=7'd79;
            8'd4: text_8_char=7'd32;
            8'd5: text_8_char=7'd51;
            8'd6: text_8_char=7'd32;
            8'd7: text_8_char=7'd45;
            8'd8: text_8_char=7'd32;
            8'd9: text_8_char=7'd85;
            8'd10: text_8_char=7'd73;
            8'd11: text_8_char=7'd32;
            8'd12: text_8_char=7'd73;
            8'd13: text_8_char=7'd84;
            8'd14: text_8_char=7'd69;
            8'd15: text_8_char=7'd77;
            8'd16: text_8_char=7'd32;
            8'd17: text_8_char=7'd79;
            8'd18: text_8_char=7'd78;
            8'd19: text_8_char=7'd76;
            8'd20: text_8_char=7'd89;
            default: text_8_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_8=(text_8_lx<168 && text_8_ly<16) ? {1'b1,24'hE2E8F0,text_8_char,text_8_row,text_8_col} : 39'd0;
    wire [10:0] text_9_lx=pixel_x-11'd32;
    wire [9:0] text_9_ly=pixel_y-10'd282;
    wire [7:0] text_9_index=text_9_lx/8;
    wire [3:0] text_9_row=text_9_ly/1;
    wire [2:0] text_9_col=(text_9_lx%8)/1;
    reg [6:0] text_9_char;
    always @* begin
        case (text_9_index)
            8'd0: text_9_char=7'd68;
            8'd1: text_9_char=7'd69;
            8'd2: text_9_char=7'd77;
            8'd3: text_9_char=7'd79;
            8'd4: text_9_char=7'd32;
            8'd5: text_9_char=7'd52;
            8'd6: text_9_char=7'd32;
            8'd7: text_9_char=7'd45;
            8'd8: text_9_char=7'd32;
            8'd9: text_9_char=7'd85;
            8'd10: text_9_char=7'd73;
            8'd11: text_9_char=7'd32;
            8'd12: text_9_char=7'd73;
            8'd13: text_9_char=7'd84;
            8'd14: text_9_char=7'd69;
            8'd15: text_9_char=7'd77;
            8'd16: text_9_char=7'd32;
            8'd17: text_9_char=7'd79;
            8'd18: text_9_char=7'd78;
            8'd19: text_9_char=7'd76;
            8'd20: text_9_char=7'd89;
            default: text_9_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_9=(text_9_lx<168 && text_9_ly<16) ? {1'b1,24'hE2E8F0,text_9_char,text_9_row,text_9_col} : 39'd0;
    wire [10:0] text_10_lx=pixel_x-11'd32;
    wire [9:0] text_10_ly=pixel_y-10'd304;
    wire [7:0] text_10_index=text_10_lx/8;
    wire [3:0] text_10_row=text_10_ly/1;
    wire [2:0] text_10_col=(text_10_lx%8)/1;
    reg [6:0] text_10_char;
    always @* begin
        case (text_10_index)
            8'd0: text_10_char=7'd68;
            8'd1: text_10_char=7'd69;
            8'd2: text_10_char=7'd77;
            8'd3: text_10_char=7'd79;
            8'd4: text_10_char=7'd32;
            8'd5: text_10_char=7'd53;
            8'd6: text_10_char=7'd32;
            8'd7: text_10_char=7'd45;
            8'd8: text_10_char=7'd32;
            8'd9: text_10_char=7'd85;
            8'd10: text_10_char=7'd73;
            8'd11: text_10_char=7'd32;
            8'd12: text_10_char=7'd73;
            8'd13: text_10_char=7'd84;
            8'd14: text_10_char=7'd69;
            8'd15: text_10_char=7'd77;
            8'd16: text_10_char=7'd32;
            8'd17: text_10_char=7'd79;
            8'd18: text_10_char=7'd78;
            8'd19: text_10_char=7'd76;
            8'd20: text_10_char=7'd89;
            default: text_10_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_10=(text_10_lx<168 && text_10_ly<16) ? {1'b1,24'hE2E8F0,text_10_char,text_10_row,text_10_col} : 39'd0;
    wire [10:0] text_11_lx=pixel_x-11'd48;
    wire [9:0] text_11_ly=pixel_y-10'd360;
    wire [7:0] text_11_index=text_11_lx/16;
    wire [3:0] text_11_row=text_11_ly/2;
    wire [2:0] text_11_col=(text_11_lx%16)/2;
    reg [6:0] text_11_char;
    always @* begin
        case (text_11_index)
            8'd0: text_11_char=7'd83;
            8'd1: text_11_char=7'd67;
            8'd2: text_11_char=7'd65;
            8'd3: text_11_char=7'd78;
            8'd4: text_11_char=7'd32;
            8'd5: text_11_char=7'd83;
            8'd6: text_11_char=7'd68;
            default: text_11_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_11=(text_11_lx<112 && text_11_ly<32) ? {1'b1,24'h7DD3FC,text_11_char,text_11_row,text_11_col} : 39'd0;
    wire [10:0] text_12_lx=pixel_x-11'd212;
    wire [9:0] text_12_ly=pixel_y-10'd360;
    wire [7:0] text_12_index=text_12_lx/16;
    wire [3:0] text_12_row=text_12_ly/2;
    wire [2:0] text_12_col=(text_12_lx%16)/2;
    reg [6:0] text_12_char;
    always @* begin
        case (text_12_index)
            8'd0: text_12_char=7'd80;
            8'd1: text_12_char=7'd82;
            8'd2: text_12_char=7'd69;
            8'd3: text_12_char=7'd86;
            default: text_12_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_12=(text_12_lx<64 && text_12_ly<32) ? {1'b1,24'h7DD3FC,text_12_char,text_12_row,text_12_col} : 39'd0;
    wire [10:0] text_13_lx=pixel_x-11'd332;
    wire [9:0] text_13_ly=pixel_y-10'd360;
    wire [7:0] text_13_index=text_13_lx/16;
    wire [3:0] text_13_row=text_13_ly/2;
    wire [2:0] text_13_col=(text_13_lx%16)/2;
    reg [6:0] text_13_char;
    always @* begin
        case (text_13_index)
            8'd0: text_13_char=7'd78;
            8'd1: text_13_char=7'd69;
            8'd2: text_13_char=7'd88;
            8'd3: text_13_char=7'd84;
            default: text_13_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_13=(text_13_lx<64 && text_13_ly<32) ? {1'b1,24'h7DD3FC,text_13_char,text_13_row,text_13_col} : 39'd0;
    wire [10:0] text_14_lx=pixel_x-11'd456;
    wire [9:0] text_14_ly=pixel_y-10'd360;
    wire [7:0] text_14_index=text_14_lx/16;
    wire [3:0] text_14_row=text_14_ly/2;
    wire [2:0] text_14_col=(text_14_lx%16)/2;
    reg [6:0] text_14_char;
    always @* begin
        case (text_14_index)
            8'd0: text_14_char=7'd76;
            8'd1: text_14_char=7'd79;
            8'd2: text_14_char=7'd65;
            8'd3: text_14_char=7'd68;
            8'd4: text_14_char=7'd32;
            8'd5: text_14_char=7'd83;
            8'd6: text_14_char=7'd69;
            8'd7: text_14_char=7'd76;
            8'd8: text_14_char=7'd69;
            8'd9: text_14_char=7'd67;
            8'd10: text_14_char=7'd84;
            8'd11: text_14_char=7'd69;
            8'd12: text_14_char=7'd68;
            8'd13: text_14_char=7'd32;
            8'd14: text_14_char=7'd70;
            8'd15: text_14_char=7'd73;
            8'd16: text_14_char=7'd76;
            8'd17: text_14_char=7'd69;
            default: text_14_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_14=(text_14_lx<288 && text_14_ly<32) ? {1'b1,24'h7DD3FC,text_14_char,text_14_row,text_14_col} : 39'd0;
    wire [10:0] text_15_lx=pixel_x-11'd24;
    wire [9:0] text_15_ly=pixel_y-10'd424;
    wire [7:0] text_15_index=text_15_lx/8;
    wire [3:0] text_15_row=text_15_ly/1;
    wire [2:0] text_15_col=(text_15_lx%8)/1;
    reg [6:0] text_15_char;
    always @* begin
        case (text_15_index)
            8'd0: text_15_char=7'd83;
            8'd1: text_15_char=7'd67;
            8'd2: text_15_char=7'd65;
            8'd3: text_15_char=7'd78;
            8'd4: text_15_char=7'd32;
            8'd5: text_15_char=7'd65;
            8'd6: text_15_char=7'd78;
            8'd7: text_15_char=7'd68;
            8'd8: text_15_char=7'd32;
            8'd9: text_15_char=7'd76;
            8'd10: text_15_char=7'd79;
            8'd11: text_15_char=7'd65;
            8'd12: text_15_char=7'd68;
            8'd13: text_15_char=7'd32;
            8'd14: text_15_char=7'd82;
            8'd15: text_15_char=7'd69;
            8'd16: text_15_char=7'd67;
            8'd17: text_15_char=7'd79;
            8'd18: text_15_char=7'd82;
            8'd19: text_15_char=7'd68;
            8'd20: text_15_char=7'd32;
            8'd21: text_15_char=7'd76;
            8'd22: text_15_char=7'd79;
            8'd23: text_15_char=7'd67;
            8'd24: text_15_char=7'd65;
            8'd25: text_15_char=7'd76;
            8'd26: text_15_char=7'd32;
            8'd27: text_15_char=7'd82;
            8'd28: text_15_char=7'd69;
            8'd29: text_15_char=7'd81;
            8'd30: text_15_char=7'd85;
            8'd31: text_15_char=7'd69;
            8'd32: text_15_char=7'd83;
            8'd33: text_15_char=7'd84;
            8'd34: text_15_char=7'd83;
            8'd35: text_15_char=7'd32;
            8'd36: text_15_char=7'd79;
            8'd37: text_15_char=7'd78;
            8'd38: text_15_char=7'd76;
            8'd39: text_15_char=7'd89;
            default: text_15_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_15=(text_15_lx<320 && text_15_ly<16) ? {1'b1,24'hE2E8F0,text_15_char,text_15_row,text_15_col} : 39'd0;
    wire [10:0] text_16_lx=pixel_x-11'd24;
    wire [9:0] text_16_ly=pixel_y-10'd446;
    wire [7:0] text_16_index=text_16_lx/8;
    wire [3:0] text_16_row=text_16_ly/1;
    wire [2:0] text_16_col=(text_16_lx%8)/1;
    reg [6:0] text_16_char;
    always @* begin
        case (text_16_index)
            8'd0: text_16_char=7'd78;
            8'd1: text_16_char=7'd79;
            8'd2: text_16_char=7'd32;
            8'd3: text_16_char=7'd82;
            8'd4: text_16_char=7'd69;
            8'd5: text_16_char=7'd65;
            8'd6: text_16_char=7'd76;
            8'd7: text_16_char=7'd32;
            8'd8: text_16_char=7'd70;
            8'd9: text_16_char=7'd73;
            8'd10: text_16_char=7'd76;
            8'd11: text_16_char=7'd69;
            8'd12: text_16_char=7'd32;
            8'd13: text_16_char=7'd83;
            8'd14: text_16_char=7'd67;
            8'd15: text_16_char=7'd65;
            8'd16: text_16_char=7'd78;
            8'd17: text_16_char=7'd32;
            8'd18: text_16_char=7'd79;
            8'd19: text_16_char=7'd82;
            8'd20: text_16_char=7'd32;
            8'd21: text_16_char=7'd76;
            8'd22: text_16_char=7'd79;
            8'd23: text_16_char=7'd65;
            8'd24: text_16_char=7'd68;
            8'd25: text_16_char=7'd32;
            8'd26: text_16_char=7'd73;
            8'd27: text_16_char=7'd78;
            8'd28: text_16_char=7'd32;
            8'd29: text_16_char=7'd84;
            8'd30: text_16_char=7'd72;
            8'd31: text_16_char=7'd73;
            8'd32: text_16_char=7'd83;
            8'd33: text_16_char=7'd32;
            8'd34: text_16_char=7'd83;
            8'd35: text_16_char=7'd84;
            8'd36: text_16_char=7'd65;
            8'd37: text_16_char=7'd78;
            8'd38: text_16_char=7'd68;
            8'd39: text_16_char=7'd65;
            8'd40: text_16_char=7'd76;
            8'd41: text_16_char=7'd79;
            8'd42: text_16_char=7'd78;
            8'd43: text_16_char=7'd69;
            8'd44: text_16_char=7'd32;
            8'd45: text_16_char=7'd84;
            8'd46: text_16_char=7'd69;
            8'd47: text_16_char=7'd83;
            8'd48: text_16_char=7'd84;
            default: text_16_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_16=(text_16_lx<392 && text_16_ly<16) ? {1'b1,24'hE2E8F0,text_16_char,text_16_row,text_16_col} : 39'd0;
    wire [10:0] text_17_lx=pixel_x-11'd108;
    wire [9:0] text_17_ly=pixel_y-10'd56;
    wire [7:0] text_17_index=text_17_lx/8;
    wire [3:0] text_17_row=text_17_ly/1;
    wire [2:0] text_17_col=(text_17_lx%8)/1;
    reg [6:0] text_17_char;
    always @* begin
        case (text_17_index)
            8'd0: text_17_char=7'd83;
            8'd1: text_17_char=7'd68;
            8'd2: text_17_char=7'd32;
            8'd3: text_17_char=7'd83;
            8'd4: text_17_char=7'd79;
            8'd5: text_17_char=7'd78;
            8'd6: text_17_char=7'd71;
            8'd7: text_17_char=7'd83;
            default: text_17_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_17=(text_17_lx<64 && text_17_ly<16) ? {1'b1,24'h7DD3FC,text_17_char,text_17_row,text_17_col} : 39'd0;
    wire [10:0] text_18_lx=pixel_x-11'd340;
    wire [9:0] text_18_ly=pixel_y-10'd56;
    wire [7:0] text_18_index=text_18_lx/8;
    wire [3:0] text_18_row=text_18_ly/1;
    wire [2:0] text_18_col=(text_18_lx%8)/1;
    reg [6:0] text_18_char;
    always @* begin
        case (text_18_index)
            8'd0: text_18_char=7'd80;
            8'd1: text_18_char=7'd65;
            8'd2: text_18_char=7'd84;
            8'd3: text_18_char=7'd67;
            8'd4: text_18_char=7'd72;
            8'd5: text_18_char=7'd32;
            8'd6: text_18_char=7'd47;
            8'd7: text_18_char=7'd32;
            8'd8: text_18_char=7'd69;
            8'd9: text_18_char=7'd70;
            8'd10: text_18_char=7'd70;
            8'd11: text_18_char=7'd69;
            8'd12: text_18_char=7'd67;
            8'd13: text_18_char=7'd84;
            8'd14: text_18_char=7'd83;
            default: text_18_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_18=(text_18_lx<120 && text_18_ly<16) ? {1'b1,24'h7DD3FC,text_18_char,text_18_row,text_18_col} : 39'd0;
    wire [10:0] text_19_lx=pixel_x-11'd608;
    wire [9:0] text_19_ly=pixel_y-10'd56;
    wire [7:0] text_19_index=text_19_lx/8;
    wire [3:0] text_19_row=text_19_ly/1;
    wire [2:0] text_19_col=(text_19_lx%8)/1;
    reg [6:0] text_19_char;
    always @* begin
        case (text_19_index)
            8'd0: text_19_char=7'd83;
            8'd1: text_19_char=7'd84;
            8'd2: text_19_char=7'd65;
            8'd3: text_19_char=7'd84;
            8'd4: text_19_char=7'd85;
            8'd5: text_19_char=7'd83;
            8'd6: text_19_char=7'd32;
            8'd7: text_19_char=7'd47;
            8'd8: text_19_char=7'd32;
            8'd9: text_19_char=7'd80;
            8'd10: text_19_char=7'd76;
            8'd11: text_19_char=7'd65;
            8'd12: text_19_char=7'd89;
            default: text_19_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_19=(text_19_lx<104 && text_19_ly<16) ? {1'b1,24'h7DD3FC,text_19_char,text_19_row,text_19_col} : 39'd0;
    wire [38:0] text_compose_0_0 = descriptor_1[38] ? descriptor_1 : descriptor_0;
    wire [38:0] text_compose_0_1 = descriptor_3[38] ? descriptor_3 : descriptor_2;
    wire [38:0] text_compose_0_2 = descriptor_5[38] ? descriptor_5 : descriptor_4;
    wire [38:0] text_compose_0_3 = descriptor_7[38] ? descriptor_7 : descriptor_6;
    wire [38:0] text_compose_0_4 = descriptor_9[38] ? descriptor_9 : descriptor_8;
    wire [38:0] text_compose_0_5 = descriptor_11[38] ? descriptor_11 : descriptor_10;
    wire [38:0] text_compose_0_6 = descriptor_13[38] ? descriptor_13 : descriptor_12;
    wire [38:0] text_compose_0_7 = descriptor_15[38] ? descriptor_15 : descriptor_14;
    wire [38:0] text_compose_0_8 = descriptor_17[38] ? descriptor_17 : descriptor_16;
    wire [38:0] text_compose_0_9 = descriptor_19[38] ? descriptor_19 : descriptor_18;
    wire [38:0] text_compose_1_0 = text_compose_0_1[38] ? text_compose_0_1 : text_compose_0_0;
    wire [38:0] text_compose_1_1 = text_compose_0_3[38] ? text_compose_0_3 : text_compose_0_2;
    wire [38:0] text_compose_1_2 = text_compose_0_5[38] ? text_compose_0_5 : text_compose_0_4;
    wire [38:0] text_compose_1_3 = text_compose_0_7[38] ? text_compose_0_7 : text_compose_0_6;
    wire [38:0] text_compose_1_4 = text_compose_0_9[38] ? text_compose_0_9 : text_compose_0_8;
    wire [38:0] text_compose_2_0 = text_compose_1_1[38] ? text_compose_1_1 : text_compose_1_0;
    wire [38:0] text_compose_2_1 = text_compose_1_3[38] ? text_compose_1_3 : text_compose_1_2;
    wire [38:0] text_compose_3_0 = text_compose_2_1[38] ? text_compose_2_1 : text_compose_2_0;
    wire [38:0] text_compose_4_0 = text_compose_1_4[38] ? text_compose_1_4 : text_compose_3_0;
    assign text_descriptor=text_compose_4_0;
endmodule

module ui_ec11_page_1 (
    input wire [10:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire [511:0] ui_status_flat,
    output wire [23:0] background_rgb,
    output wire [38:0] text_descriptor
);
    function [6:0] hexchar;
        input [3:0] nibble;
        begin hexchar=(nibble<10)?7'd48+nibble:7'd55+nibble; end
    endfunction
    wire [24:0] background_0 = (pixel_x>=16 && pixel_x<784 && pixel_y>=100 && pixel_y<202) ? {1'b1, (pixel_x<17 || pixel_x>=783 || pixel_y<101 || pixel_y>=201) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_1 = (pixel_x>=32 && pixel_x<128 && pixel_y>=146 && pixel_y<190) ? {1'b1, (pixel_x<33 || pixel_x>=127 || pixel_y<147 || pixel_y>=189) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_2 = (pixel_x>=136 && pixel_x<232 && pixel_y>=146 && pixel_y<190) ? {1'b1, (pixel_x<137 || pixel_x>=231 || pixel_y<147 || pixel_y>=189) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_3 = (pixel_x>=240 && pixel_x<336 && pixel_y>=146 && pixel_y<190) ? {1'b1, (pixel_x<241 || pixel_x>=335 || pixel_y<147 || pixel_y>=189) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_4 = (pixel_x>=344 && pixel_x<440 && pixel_y>=146 && pixel_y<190) ? {1'b1, (pixel_x<345 || pixel_x>=439 || pixel_y<147 || pixel_y>=189) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_5 = (pixel_x>=448 && pixel_x<544 && pixel_y>=146 && pixel_y<190) ? {1'b1, (pixel_x<449 || pixel_x>=543 || pixel_y<147 || pixel_y>=189) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_6 = (pixel_x>=552 && pixel_x<648 && pixel_y>=146 && pixel_y<190) ? {1'b1, (pixel_x<553 || pixel_x>=647 || pixel_y<147 || pixel_y>=189) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_7 = (pixel_x>=656 && pixel_x<752 && pixel_y>=146 && pixel_y<190) ? {1'b1, (pixel_x<657 || pixel_x>=751 || pixel_y<147 || pixel_y>=189) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_8 = (pixel_x>=16 && pixel_x<784 && pixel_y>=212 && pixel_y<420) ? {1'b1, (pixel_x<17 || pixel_x>=783 || pixel_y<213 || pixel_y>=419) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_9 = (pixel_x>=32 && pixel_x<168 && pixel_y>=380 && pixel_y<412) ? {1'b1, (pixel_x<33 || pixel_x>=167 || pixel_y<381 || pixel_y>=411) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_10 = (pixel_x>=184 && pixel_x<344 && pixel_y>=380 && pixel_y<412) ? {1'b1, (pixel_x<185 || pixel_x>=343 || pixel_y<381 || pixel_y>=411) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [9:0] bar_11_value=ui_status_flat[176+:10];
    wire [25:0] bar_11_product=bar_11_value*16'd80;
    wire [15:0] bar_11_fill=bar_11_product>>10;
    wire [24:0] background_11 = (pixel_x>=84 && pixel_x<164 && pixel_y>=264 && pixel_y<344) ? {1'b1, ((pixel_x-84)<bar_11_fill) ? 24'h38BDF8 : 24'h1E293B} : 25'd0;
    wire [9:0] bar_12_value=ui_status_flat[192+:10];
    wire [25:0] bar_12_product=bar_12_value*16'd80;
    wire [15:0] bar_12_fill=bar_12_product>>10;
    wire [24:0] background_12 = (pixel_x>=268 && pixel_x<348 && pixel_y>=264 && pixel_y<344) ? {1'b1, ((pixel_x-268)<bar_12_fill) ? 24'h38BDF8 : 24'h1E293B} : 25'd0;
    wire [9:0] bar_13_value=ui_status_flat[208+:10];
    wire [25:0] bar_13_product=bar_13_value*16'd80;
    wire [15:0] bar_13_fill=bar_13_product>>10;
    wire [24:0] background_13 = (pixel_x>=452 && pixel_x<532 && pixel_y>=264 && pixel_y<344) ? {1'b1, ((pixel_x-452)<bar_13_fill) ? 24'h38BDF8 : 24'h1E293B} : 25'd0;
    wire [9:0] bar_14_value=ui_status_flat[224+:10];
    wire [25:0] bar_14_product=bar_14_value*16'd80;
    wire [15:0] bar_14_fill=bar_14_product>>10;
    wire [24:0] background_14 = (pixel_x>=636 && pixel_x<716 && pixel_y>=264 && pixel_y<344) ? {1'b1, ((pixel_x-636)<bar_14_fill) ? 24'h38BDF8 : 24'h1E293B} : 25'd0;
    wire [24:0] background_15 = (pixel_x>=16 && pixel_x<264 && pixel_y>=44 && pixel_y<84) ? {1'b1, (pixel_x<17 || pixel_x>=263 || pixel_y<45 || pixel_y>=83) ? 24'h38BDF8 : 24'h0F172A} : 25'd0;
    wire [24:0] background_16 = (pixel_x>=276 && pixel_x<524 && pixel_y>=44 && pixel_y<84) ? {1'b1, (pixel_x<277 || pixel_x>=523 || pixel_y<45 || pixel_y>=83) ? 24'h38BDF8 : 24'h0F172A} : 25'd0;
    wire [24:0] background_17 = (pixel_x>=536 && pixel_x<784 && pixel_y>=44 && pixel_y<84) ? {1'b1, (pixel_x<537 || pixel_x>=783 || pixel_y<45 || pixel_y>=83) ? 24'h38BDF8 : 24'h0F172A} : 25'd0;
    wire [24:0] bg_compose_0_0 = background_1[24] ? background_1 : background_0;
    wire [24:0] bg_compose_0_1 = background_3[24] ? background_3 : background_2;
    wire [24:0] bg_compose_0_2 = background_5[24] ? background_5 : background_4;
    wire [24:0] bg_compose_0_3 = background_7[24] ? background_7 : background_6;
    wire [24:0] bg_compose_0_4 = background_9[24] ? background_9 : background_8;
    wire [24:0] bg_compose_0_5 = background_11[24] ? background_11 : background_10;
    wire [24:0] bg_compose_0_6 = background_13[24] ? background_13 : background_12;
    wire [24:0] bg_compose_0_7 = background_15[24] ? background_15 : background_14;
    wire [24:0] bg_compose_0_8 = background_17[24] ? background_17 : background_16;
    wire [24:0] bg_compose_1_0 = bg_compose_0_1[24] ? bg_compose_0_1 : bg_compose_0_0;
    wire [24:0] bg_compose_1_1 = bg_compose_0_3[24] ? bg_compose_0_3 : bg_compose_0_2;
    wire [24:0] bg_compose_1_2 = bg_compose_0_5[24] ? bg_compose_0_5 : bg_compose_0_4;
    wire [24:0] bg_compose_1_3 = bg_compose_0_7[24] ? bg_compose_0_7 : bg_compose_0_6;
    wire [24:0] bg_compose_2_0 = bg_compose_1_1[24] ? bg_compose_1_1 : bg_compose_1_0;
    wire [24:0] bg_compose_2_1 = bg_compose_1_3[24] ? bg_compose_1_3 : bg_compose_1_2;
    wire [24:0] bg_compose_3_0 = bg_compose_2_1[24] ? bg_compose_2_1 : bg_compose_2_0;
    wire [24:0] bg_compose_4_0 = bg_compose_0_8[24] ? bg_compose_0_8 : bg_compose_3_0;
    assign background_rgb=bg_compose_4_0[24] ? bg_compose_4_0[23:0] : 24'h05070C;
    wire [10:0] text_0_lx=pixel_x-11'd16;
    wire [9:0] text_0_ly=pixel_y-10'd8;
    wire [7:0] text_0_index=text_0_lx/16;
    wire [3:0] text_0_row=text_0_ly/2;
    wire [2:0] text_0_col=(text_0_lx%16)/2;
    reg [6:0] text_0_char;
    always @* begin
        case (text_0_index)
            8'd0: text_0_char=7'd69;
            8'd1: text_0_char=7'd67;
            8'd2: text_0_char=7'd49;
            8'd3: text_0_char=7'd49;
            8'd4: text_0_char=7'd32;
            8'd5: text_0_char=7'd47;
            8'd6: text_0_char=7'd32;
            8'd7: text_0_char=7'd84;
            8'd8: text_0_char=7'd72;
            8'd9: text_0_char=7'd82;
            8'd10: text_0_char=7'd69;
            8'd11: text_0_char=7'd69;
            8'd12: text_0_char=7'd32;
            8'd13: text_0_char=7'd80;
            8'd14: text_0_char=7'd65;
            8'd15: text_0_char=7'd71;
            8'd16: text_0_char=7'd69;
            8'd17: text_0_char=7'd32;
            8'd18: text_0_char=7'd85;
            8'd19: text_0_char=7'd73;
            default: text_0_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_0=(text_0_lx<320 && text_0_ly<32) ? {1'b1,24'hE2E8F0,text_0_char,text_0_row,text_0_col} : 39'd0;
    wire [10:0] text_1_lx=pixel_x-11'd492;
    wire [9:0] text_1_ly=pixel_y-10'd12;
    wire [7:0] text_1_index=text_1_lx/8;
    wire [3:0] text_1_row=text_1_ly/1;
    wire [2:0] text_1_col=(text_1_lx%8)/1;
    reg [6:0] text_1_char;
    always @* begin
        case (text_1_index)
            8'd0: text_1_char=7'd76;
            8'd1: text_1_char=7'd79;
            8'd2: text_1_char=7'd67;
            8'd3: text_1_char=7'd65;
            8'd4: text_1_char=7'd76;
            8'd5: text_1_char=7'd32;
            8'd6: text_1_char=7'd84;
            8'd7: text_1_char=7'd69;
            8'd8: text_1_char=7'd83;
            8'd9: text_1_char=7'd84;
            8'd10: text_1_char=7'd32;
            8'd11: text_1_char=7'd45;
            8'd12: text_1_char=7'd32;
            8'd13: text_1_char=7'd78;
            8'd14: text_1_char=7'd79;
            8'd15: text_1_char=7'd32;
            8'd16: text_1_char=7'd83;
            8'd17: text_1_char=7'd68;
            8'd18: text_1_char=7'd47;
            8'd19: text_1_char=7'd65;
            8'd20: text_1_char=7'd85;
            8'd21: text_1_char=7'd68;
            8'd22: text_1_char=7'd73;
            8'd23: text_1_char=7'd79;
            default: text_1_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_1=(text_1_lx<192 && text_1_ly<16) ? {1'b1,24'hE2E8F0,text_1_char,text_1_row,text_1_col} : 39'd0;
    wire [10:0] text_2_lx=pixel_x-11'd16;
    wire [9:0] text_2_ly=pixel_y-10'd464;
    wire [7:0] text_2_index=text_2_lx/8;
    wire [3:0] text_2_row=text_2_ly/1;
    wire [2:0] text_2_col=(text_2_lx%8)/1;
    reg [6:0] text_2_char;
    always @* begin
        case (text_2_index)
            8'd0: text_2_char=7'd82;
            8'd1: text_2_char=7'd79;
            8'd2: text_2_char=7'd84;
            8'd3: text_2_char=7'd65;
            8'd4: text_2_char=7'd84;
            8'd5: text_2_char=7'd69;
            8'd6: text_2_char=7'd58;
            8'd7: text_2_char=7'd32;
            8'd8: text_2_char=7'd70;
            8'd9: text_2_char=7'd79;
            8'd10: text_2_char=7'd67;
            8'd11: text_2_char=7'd85;
            8'd12: text_2_char=7'd83;
            8'd13: text_2_char=7'd32;
            8'd14: text_2_char=7'd45;
            8'd15: text_2_char=7'd32;
            8'd16: text_2_char=7'd67;
            8'd17: text_2_char=7'd76;
            8'd18: text_2_char=7'd73;
            8'd19: text_2_char=7'd67;
            8'd20: text_2_char=7'd75;
            8'd21: text_2_char=7'd58;
            8'd22: text_2_char=7'd32;
            8'd23: text_2_char=7'd69;
            8'd24: text_2_char=7'd78;
            8'd25: text_2_char=7'd84;
            8'd26: text_2_char=7'd69;
            8'd27: text_2_char=7'd82;
            8'd28: text_2_char=7'd47;
            8'd29: text_2_char=7'd79;
            8'd30: text_2_char=7'd75;
            8'd31: text_2_char=7'd32;
            8'd32: text_2_char=7'd45;
            8'd33: text_2_char=7'd32;
            8'd34: text_2_char=7'd72;
            8'd35: text_2_char=7'd79;
            8'd36: text_2_char=7'd76;
            8'd37: text_2_char=7'd68;
            8'd38: text_2_char=7'd32;
            8'd39: text_2_char=7'd48;
            8'd40: text_2_char=7'd46;
            8'd41: text_2_char=7'd56;
            8'd42: text_2_char=7'd83;
            8'd43: text_2_char=7'd58;
            8'd44: text_2_char=7'd32;
            8'd45: text_2_char=7'd67;
            8'd46: text_2_char=7'd65;
            8'd47: text_2_char=7'd78;
            8'd48: text_2_char=7'd67;
            8'd49: text_2_char=7'd69;
            8'd50: text_2_char=7'd76;
            8'd51: text_2_char=7'd47;
            8'd52: text_2_char=7'd66;
            8'd53: text_2_char=7'd65;
            8'd54: text_2_char=7'd67;
            8'd55: text_2_char=7'd75;
            default: text_2_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_2=(text_2_lx<448 && text_2_ly<16) ? {1'b1,24'hE2E8F0,text_2_char,text_2_row,text_2_col} : 39'd0;
    wire [10:0] text_3_lx=pixel_x-11'd32;
    wire [9:0] text_3_ly=pixel_y-10'd112;
    wire [7:0] text_3_index=text_3_lx/8;
    wire [3:0] text_3_row=text_3_ly/1;
    wire [2:0] text_3_col=(text_3_lx%8)/1;
    reg [6:0] text_3_char;
    always @* begin
        case (text_3_index)
            8'd0: text_3_char=7'd76;
            8'd1: text_3_char=7'd79;
            8'd2: text_3_char=7'd67;
            8'd3: text_3_char=7'd65;
            8'd4: text_3_char=7'd76;
            8'd5: text_3_char=7'd32;
            8'd6: text_3_char=7'd80;
            8'd7: text_3_char=7'd65;
            8'd8: text_3_char=7'd84;
            8'd9: text_3_char=7'd67;
            8'd10: text_3_char=7'd72;
            8'd11: text_3_char=7'd58;
            8'd12: text_3_char=7'd32;
            8'd13: text_3_char=hexchar(ui_status_flat[112+:4]);
            default: text_3_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_3=(text_3_lx<112 && text_3_ly<16) ? {1'b1,24'hE2E8F0,text_3_char,text_3_row,text_3_col} : 39'd0;
    wire [10:0] text_4_lx=pixel_x-11'd92;
    wire [9:0] text_4_ly=pixel_y-10'd228;
    wire [7:0] text_4_index=text_4_lx/16;
    wire [3:0] text_4_row=text_4_ly/2;
    wire [2:0] text_4_col=(text_4_lx%16)/2;
    reg [6:0] text_4_char;
    always @* begin
        case (text_4_index)
            8'd0: text_4_char=7'd82;
            8'd1: text_4_char=7'd65;
            8'd2: text_4_char=7'd84;
            8'd3: text_4_char=7'd69;
            default: text_4_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_4=(text_4_lx<64 && text_4_ly<32) ? {1'b1,24'hE2E8F0,text_4_char,text_4_row,text_4_col} : 39'd0;
    wire [10:0] text_5_lx=pixel_x-11'd96;
    wire [9:0] text_5_ly=pixel_y-10'd352;
    wire [7:0] text_5_index=text_5_lx/8;
    wire [3:0] text_5_row=text_5_ly/1;
    wire [2:0] text_5_col=(text_5_lx%8)/1;
    reg [6:0] text_5_char;
    always @* begin
        case (text_5_index)
            8'd0: text_5_char=7'd72;
            8'd1: text_5_char=7'd69;
            8'd2: text_5_char=7'd88;
            8'd3: text_5_char=7'd58;
            8'd4: text_5_char=7'd32;
            8'd5: text_5_char=hexchar(ui_status_flat[244+:4]);
            8'd6: text_5_char=hexchar(ui_status_flat[240+:4]);
            default: text_5_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_5=(text_5_lx<56 && text_5_ly<16) ? {1'b1,24'hE2E8F0,text_5_char,text_5_row,text_5_col} : 39'd0;
    wire [10:0] text_6_lx=pixel_x-11'd268;
    wire [9:0] text_6_ly=pixel_y-10'd228;
    wire [7:0] text_6_index=text_6_lx/16;
    wire [3:0] text_6_row=text_6_ly/2;
    wire [2:0] text_6_col=(text_6_lx%16)/2;
    reg [6:0] text_6_char;
    always @* begin
        case (text_6_index)
            8'd0: text_6_char=7'd68;
            8'd1: text_6_char=7'd69;
            8'd2: text_6_char=7'd80;
            8'd3: text_6_char=7'd84;
            8'd4: text_6_char=7'd72;
            default: text_6_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_6=(text_6_lx<80 && text_6_ly<32) ? {1'b1,24'hE2E8F0,text_6_char,text_6_row,text_6_col} : 39'd0;
    wire [10:0] text_7_lx=pixel_x-11'd280;
    wire [9:0] text_7_ly=pixel_y-10'd352;
    wire [7:0] text_7_index=text_7_lx/8;
    wire [3:0] text_7_row=text_7_ly/1;
    wire [2:0] text_7_col=(text_7_lx%8)/1;
    reg [6:0] text_7_char;
    always @* begin
        case (text_7_index)
            8'd0: text_7_char=7'd72;
            8'd1: text_7_char=7'd69;
            8'd2: text_7_char=7'd88;
            8'd3: text_7_char=7'd58;
            8'd4: text_7_char=7'd32;
            8'd5: text_7_char=hexchar(ui_status_flat[260+:4]);
            8'd6: text_7_char=hexchar(ui_status_flat[256+:4]);
            default: text_7_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_7=(text_7_lx<56 && text_7_ly<16) ? {1'b1,24'hE2E8F0,text_7_char,text_7_row,text_7_col} : 39'd0;
    wire [10:0] text_8_lx=pixel_x-11'd452;
    wire [9:0] text_8_ly=pixel_y-10'd228;
    wire [7:0] text_8_index=text_8_lx/16;
    wire [3:0] text_8_row=text_8_ly/2;
    wire [2:0] text_8_col=(text_8_lx%16)/2;
    reg [6:0] text_8_char;
    always @* begin
        case (text_8_index)
            8'd0: text_8_char=7'd87;
            8'd1: text_8_char=7'd73;
            8'd2: text_8_char=7'd68;
            8'd3: text_8_char=7'd84;
            8'd4: text_8_char=7'd72;
            default: text_8_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_8=(text_8_lx<80 && text_8_ly<32) ? {1'b1,24'hE2E8F0,text_8_char,text_8_row,text_8_col} : 39'd0;
    wire [10:0] text_9_lx=pixel_x-11'd464;
    wire [9:0] text_9_ly=pixel_y-10'd352;
    wire [7:0] text_9_index=text_9_lx/8;
    wire [3:0] text_9_row=text_9_ly/1;
    wire [2:0] text_9_col=(text_9_lx%8)/1;
    reg [6:0] text_9_char;
    always @* begin
        case (text_9_index)
            8'd0: text_9_char=7'd72;
            8'd1: text_9_char=7'd69;
            8'd2: text_9_char=7'd88;
            8'd3: text_9_char=7'd58;
            8'd4: text_9_char=7'd32;
            8'd5: text_9_char=hexchar(ui_status_flat[4+:4]);
            8'd6: text_9_char=hexchar(ui_status_flat[0+:4]);
            default: text_9_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_9=(text_9_lx<56 && text_9_ly<16) ? {1'b1,24'hE2E8F0,text_9_char,text_9_row,text_9_col} : 39'd0;
    wire [10:0] text_10_lx=pixel_x-11'd652;
    wire [9:0] text_10_ly=pixel_y-10'd228;
    wire [7:0] text_10_index=text_10_lx/16;
    wire [3:0] text_10_row=text_10_ly/2;
    wire [2:0] text_10_col=(text_10_lx%16)/2;
    reg [6:0] text_10_char;
    always @* begin
        case (text_10_index)
            8'd0: text_10_char=7'd77;
            8'd1: text_10_char=7'd73;
            8'd2: text_10_char=7'd88;
            default: text_10_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_10=(text_10_lx<48 && text_10_ly<32) ? {1'b1,24'hE2E8F0,text_10_char,text_10_row,text_10_col} : 39'd0;
    wire [10:0] text_11_lx=pixel_x-11'd648;
    wire [9:0] text_11_ly=pixel_y-10'd352;
    wire [7:0] text_11_index=text_11_lx/8;
    wire [3:0] text_11_row=text_11_ly/1;
    wire [2:0] text_11_col=(text_11_lx%8)/1;
    reg [6:0] text_11_char;
    always @* begin
        case (text_11_index)
            8'd0: text_11_char=7'd72;
            8'd1: text_11_char=7'd69;
            8'd2: text_11_char=7'd88;
            8'd3: text_11_char=7'd58;
            8'd4: text_11_char=7'd32;
            8'd5: text_11_char=hexchar(ui_status_flat[20+:4]);
            8'd6: text_11_char=hexchar(ui_status_flat[16+:4]);
            default: text_11_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_11=(text_11_lx<56 && text_11_ly<16) ? {1'b1,24'hE2E8F0,text_11_char,text_11_row,text_11_col} : 39'd0;
    wire [10:0] text_12_lx=pixel_x-11'd376;
    wire [9:0] text_12_ly=pixel_y-10'd390;
    wire [7:0] text_12_index=text_12_lx/8;
    wire [3:0] text_12_row=text_12_ly/1;
    wire [2:0] text_12_col=(text_12_lx%8)/1;
    reg [6:0] text_12_char;
    always @* begin
        case (text_12_index)
            8'd0: text_12_char=7'd76;
            8'd1: text_12_char=7'd79;
            8'd2: text_12_char=7'd67;
            8'd3: text_12_char=7'd65;
            8'd4: text_12_char=7'd76;
            8'd5: text_12_char=7'd32;
            8'd6: text_12_char=7'd70;
            8'd7: text_12_char=7'd88;
            8'd8: text_12_char=7'd32;
            8'd9: text_12_char=7'd69;
            8'd10: text_12_char=7'd78;
            8'd11: text_12_char=7'd65;
            8'd12: text_12_char=7'd66;
            8'd13: text_12_char=7'd76;
            8'd14: text_12_char=7'd69;
            8'd15: text_12_char=7'd58;
            8'd16: text_12_char=7'd32;
            8'd17: text_12_char=hexchar(ui_status_flat[64+:4]);
            default: text_12_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_12=(text_12_lx<144 && text_12_ly<16) ? {1'b1,24'hE2E8F0,text_12_char,text_12_row,text_12_col} : 39'd0;
    wire [10:0] text_13_lx=pixel_x-11'd52;
    wire [9:0] text_13_ly=pixel_y-10'd158;
    wire [7:0] text_13_index=text_13_lx/8;
    wire [3:0] text_13_row=text_13_ly/1;
    wire [2:0] text_13_col=(text_13_lx%8)/1;
    reg [6:0] text_13_char;
    always @* begin
        case (text_13_index)
            8'd0: text_13_char=7'd80;
            8'd1: text_13_char=7'd65;
            8'd2: text_13_char=7'd84;
            8'd3: text_13_char=7'd67;
            8'd4: text_13_char=7'd72;
            8'd5: text_13_char=7'd32;
            8'd6: text_13_char=7'd48;
            default: text_13_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_13=(text_13_lx<56 && text_13_ly<16) ? {1'b1,24'h7DD3FC,text_13_char,text_13_row,text_13_col} : 39'd0;
    wire [10:0] text_14_lx=pixel_x-11'd156;
    wire [9:0] text_14_ly=pixel_y-10'd158;
    wire [7:0] text_14_index=text_14_lx/8;
    wire [3:0] text_14_row=text_14_ly/1;
    wire [2:0] text_14_col=(text_14_lx%8)/1;
    reg [6:0] text_14_char;
    always @* begin
        case (text_14_index)
            8'd0: text_14_char=7'd80;
            8'd1: text_14_char=7'd65;
            8'd2: text_14_char=7'd84;
            8'd3: text_14_char=7'd67;
            8'd4: text_14_char=7'd72;
            8'd5: text_14_char=7'd32;
            8'd6: text_14_char=7'd49;
            default: text_14_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_14=(text_14_lx<56 && text_14_ly<16) ? {1'b1,24'h7DD3FC,text_14_char,text_14_row,text_14_col} : 39'd0;
    wire [10:0] text_15_lx=pixel_x-11'd260;
    wire [9:0] text_15_ly=pixel_y-10'd158;
    wire [7:0] text_15_index=text_15_lx/8;
    wire [3:0] text_15_row=text_15_ly/1;
    wire [2:0] text_15_col=(text_15_lx%8)/1;
    reg [6:0] text_15_char;
    always @* begin
        case (text_15_index)
            8'd0: text_15_char=7'd80;
            8'd1: text_15_char=7'd65;
            8'd2: text_15_char=7'd84;
            8'd3: text_15_char=7'd67;
            8'd4: text_15_char=7'd72;
            8'd5: text_15_char=7'd32;
            8'd6: text_15_char=7'd50;
            default: text_15_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_15=(text_15_lx<56 && text_15_ly<16) ? {1'b1,24'h7DD3FC,text_15_char,text_15_row,text_15_col} : 39'd0;
    wire [10:0] text_16_lx=pixel_x-11'd364;
    wire [9:0] text_16_ly=pixel_y-10'd158;
    wire [7:0] text_16_index=text_16_lx/8;
    wire [3:0] text_16_row=text_16_ly/1;
    wire [2:0] text_16_col=(text_16_lx%8)/1;
    reg [6:0] text_16_char;
    always @* begin
        case (text_16_index)
            8'd0: text_16_char=7'd80;
            8'd1: text_16_char=7'd65;
            8'd2: text_16_char=7'd84;
            8'd3: text_16_char=7'd67;
            8'd4: text_16_char=7'd72;
            8'd5: text_16_char=7'd32;
            8'd6: text_16_char=7'd51;
            default: text_16_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_16=(text_16_lx<56 && text_16_ly<16) ? {1'b1,24'h7DD3FC,text_16_char,text_16_row,text_16_col} : 39'd0;
    wire [10:0] text_17_lx=pixel_x-11'd468;
    wire [9:0] text_17_ly=pixel_y-10'd158;
    wire [7:0] text_17_index=text_17_lx/8;
    wire [3:0] text_17_row=text_17_ly/1;
    wire [2:0] text_17_col=(text_17_lx%8)/1;
    reg [6:0] text_17_char;
    always @* begin
        case (text_17_index)
            8'd0: text_17_char=7'd80;
            8'd1: text_17_char=7'd65;
            8'd2: text_17_char=7'd84;
            8'd3: text_17_char=7'd67;
            8'd4: text_17_char=7'd72;
            8'd5: text_17_char=7'd32;
            8'd6: text_17_char=7'd52;
            default: text_17_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_17=(text_17_lx<56 && text_17_ly<16) ? {1'b1,24'h7DD3FC,text_17_char,text_17_row,text_17_col} : 39'd0;
    wire [10:0] text_18_lx=pixel_x-11'd572;
    wire [9:0] text_18_ly=pixel_y-10'd158;
    wire [7:0] text_18_index=text_18_lx/8;
    wire [3:0] text_18_row=text_18_ly/1;
    wire [2:0] text_18_col=(text_18_lx%8)/1;
    reg [6:0] text_18_char;
    always @* begin
        case (text_18_index)
            8'd0: text_18_char=7'd80;
            8'd1: text_18_char=7'd65;
            8'd2: text_18_char=7'd84;
            8'd3: text_18_char=7'd67;
            8'd4: text_18_char=7'd72;
            8'd5: text_18_char=7'd32;
            8'd6: text_18_char=7'd53;
            default: text_18_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_18=(text_18_lx<56 && text_18_ly<16) ? {1'b1,24'h7DD3FC,text_18_char,text_18_row,text_18_col} : 39'd0;
    wire [10:0] text_19_lx=pixel_x-11'd676;
    wire [9:0] text_19_ly=pixel_y-10'd158;
    wire [7:0] text_19_index=text_19_lx/8;
    wire [3:0] text_19_row=text_19_ly/1;
    wire [2:0] text_19_col=(text_19_lx%8)/1;
    reg [6:0] text_19_char;
    always @* begin
        case (text_19_index)
            8'd0: text_19_char=7'd80;
            8'd1: text_19_char=7'd65;
            8'd2: text_19_char=7'd84;
            8'd3: text_19_char=7'd67;
            8'd4: text_19_char=7'd72;
            8'd5: text_19_char=7'd32;
            8'd6: text_19_char=7'd54;
            default: text_19_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_19=(text_19_lx<56 && text_19_ly<16) ? {1'b1,24'h7DD3FC,text_19_char,text_19_row,text_19_col} : 39'd0;
    wire [10:0] text_20_lx=pixel_x-11'd80;
    wire [9:0] text_20_ly=pixel_y-10'd392;
    wire [7:0] text_20_index=text_20_lx/8;
    wire [3:0] text_20_row=text_20_ly/1;
    wire [2:0] text_20_col=(text_20_lx%8)/1;
    reg [6:0] text_20_char;
    always @* begin
        case (text_20_index)
            8'd0: text_20_char=7'd70;
            8'd1: text_20_char=7'd88;
            8'd2: text_20_char=7'd32;
            8'd3: text_20_char=7'd79;
            8'd4: text_20_char=7'd78;
            default: text_20_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_20=(text_20_lx<40 && text_20_ly<16) ? {1'b1,24'h7DD3FC,text_20_char,text_20_row,text_20_col} : 39'd0;
    wire [10:0] text_21_lx=pixel_x-11'd228;
    wire [9:0] text_21_ly=pixel_y-10'd392;
    wire [7:0] text_21_index=text_21_lx/8;
    wire [3:0] text_21_row=text_21_ly/1;
    wire [2:0] text_21_col=(text_21_lx%8)/1;
    reg [6:0] text_21_char;
    always @* begin
        case (text_21_index)
            8'd0: text_21_char=7'd70;
            8'd1: text_21_char=7'd88;
            8'd2: text_21_char=7'd32;
            8'd3: text_21_char=7'd66;
            8'd4: text_21_char=7'd89;
            8'd5: text_21_char=7'd80;
            8'd6: text_21_char=7'd65;
            8'd7: text_21_char=7'd83;
            8'd8: text_21_char=7'd83;
            default: text_21_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_21=(text_21_lx<72 && text_21_ly<16) ? {1'b1,24'h7DD3FC,text_21_char,text_21_row,text_21_col} : 39'd0;
    wire [10:0] text_22_lx=pixel_x-11'd24;
    wire [9:0] text_22_ly=pixel_y-10'd434;
    wire [7:0] text_22_index=text_22_lx/8;
    wire [3:0] text_22_row=text_22_ly/1;
    wire [2:0] text_22_col=(text_22_lx%8)/1;
    reg [6:0] text_22_char;
    always @* begin
        case (text_22_index)
            8'd0: text_22_char=7'd76;
            8'd1: text_22_char=7'd79;
            8'd2: text_22_char=7'd67;
            8'd3: text_22_char=7'd65;
            8'd4: text_22_char=7'd76;
            8'd5: text_22_char=7'd32;
            8'd6: text_22_char=7'd86;
            8'd7: text_22_char=7'd65;
            8'd8: text_22_char=7'd76;
            8'd9: text_22_char=7'd85;
            8'd10: text_22_char=7'd69;
            8'd11: text_22_char=7'd83;
            8'd12: text_22_char=7'd32;
            8'd13: text_22_char=7'd79;
            8'd14: text_22_char=7'd78;
            8'd15: text_22_char=7'd76;
            8'd16: text_22_char=7'd89;
            8'd17: text_22_char=7'd32;
            8'd18: text_22_char=7'd45;
            8'd19: text_22_char=7'd32;
            8'd20: text_22_char=7'd67;
            8'd21: text_22_char=7'd76;
            8'd22: text_22_char=7'd73;
            8'd23: text_22_char=7'd67;
            8'd24: text_22_char=7'd75;
            8'd25: text_22_char=7'd32;
            8'd26: text_22_char=7'd65;
            8'd27: text_22_char=7'd32;
            8'd28: text_22_char=7'd86;
            8'd29: text_22_char=7'd65;
            8'd30: text_22_char=7'd76;
            8'd31: text_22_char=7'd85;
            8'd32: text_22_char=7'd69;
            8'd33: text_22_char=7'd32;
            8'd34: text_22_char=7'd84;
            8'd35: text_22_char=7'd79;
            8'd36: text_22_char=7'd32;
            8'd37: text_22_char=7'd69;
            8'd38: text_22_char=7'd68;
            8'd39: text_22_char=7'd73;
            8'd40: text_22_char=7'd84;
            8'd41: text_22_char=7'd32;
            8'd42: text_22_char=7'd45;
            8'd43: text_22_char=7'd32;
            8'd44: text_22_char=7'd82;
            8'd45: text_22_char=7'd65;
            8'd46: text_22_char=7'd78;
            8'd47: text_22_char=7'd71;
            8'd48: text_22_char=7'd69;
            8'd49: text_22_char=7'd32;
            8'd50: text_22_char=7'd48;
            8'd51: text_22_char=7'd48;
            8'd52: text_22_char=7'd32;
            8'd53: text_22_char=7'd84;
            8'd54: text_22_char=7'd79;
            8'd55: text_22_char=7'd32;
            8'd56: text_22_char=7'd70;
            8'd57: text_22_char=7'd70;
            8'd58: text_22_char=7'd32;
            8'd59: text_22_char=7'd72;
            8'd60: text_22_char=7'd69;
            8'd61: text_22_char=7'd88;
            default: text_22_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_22=(text_22_lx<496 && text_22_ly<16) ? {1'b1,24'hE2E8F0,text_22_char,text_22_row,text_22_col} : 39'd0;
    wire [10:0] text_23_lx=pixel_x-11'd108;
    wire [9:0] text_23_ly=pixel_y-10'd56;
    wire [7:0] text_23_index=text_23_lx/8;
    wire [3:0] text_23_row=text_23_ly/1;
    wire [2:0] text_23_col=(text_23_lx%8)/1;
    reg [6:0] text_23_char;
    always @* begin
        case (text_23_index)
            8'd0: text_23_char=7'd83;
            8'd1: text_23_char=7'd68;
            8'd2: text_23_char=7'd32;
            8'd3: text_23_char=7'd83;
            8'd4: text_23_char=7'd79;
            8'd5: text_23_char=7'd78;
            8'd6: text_23_char=7'd71;
            8'd7: text_23_char=7'd83;
            default: text_23_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_23=(text_23_lx<64 && text_23_ly<16) ? {1'b1,24'h7DD3FC,text_23_char,text_23_row,text_23_col} : 39'd0;
    wire [10:0] text_24_lx=pixel_x-11'd340;
    wire [9:0] text_24_ly=pixel_y-10'd56;
    wire [7:0] text_24_index=text_24_lx/8;
    wire [3:0] text_24_row=text_24_ly/1;
    wire [2:0] text_24_col=(text_24_lx%8)/1;
    reg [6:0] text_24_char;
    always @* begin
        case (text_24_index)
            8'd0: text_24_char=7'd80;
            8'd1: text_24_char=7'd65;
            8'd2: text_24_char=7'd84;
            8'd3: text_24_char=7'd67;
            8'd4: text_24_char=7'd72;
            8'd5: text_24_char=7'd32;
            8'd6: text_24_char=7'd47;
            8'd7: text_24_char=7'd32;
            8'd8: text_24_char=7'd69;
            8'd9: text_24_char=7'd70;
            8'd10: text_24_char=7'd70;
            8'd11: text_24_char=7'd69;
            8'd12: text_24_char=7'd67;
            8'd13: text_24_char=7'd84;
            8'd14: text_24_char=7'd83;
            default: text_24_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_24=(text_24_lx<120 && text_24_ly<16) ? {1'b1,24'h7DD3FC,text_24_char,text_24_row,text_24_col} : 39'd0;
    wire [10:0] text_25_lx=pixel_x-11'd608;
    wire [9:0] text_25_ly=pixel_y-10'd56;
    wire [7:0] text_25_index=text_25_lx/8;
    wire [3:0] text_25_row=text_25_ly/1;
    wire [2:0] text_25_col=(text_25_lx%8)/1;
    reg [6:0] text_25_char;
    always @* begin
        case (text_25_index)
            8'd0: text_25_char=7'd83;
            8'd1: text_25_char=7'd84;
            8'd2: text_25_char=7'd65;
            8'd3: text_25_char=7'd84;
            8'd4: text_25_char=7'd85;
            8'd5: text_25_char=7'd83;
            8'd6: text_25_char=7'd32;
            8'd7: text_25_char=7'd47;
            8'd8: text_25_char=7'd32;
            8'd9: text_25_char=7'd80;
            8'd10: text_25_char=7'd76;
            8'd11: text_25_char=7'd65;
            8'd12: text_25_char=7'd89;
            default: text_25_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_25=(text_25_lx<104 && text_25_ly<16) ? {1'b1,24'h7DD3FC,text_25_char,text_25_row,text_25_col} : 39'd0;
    wire [38:0] text_compose_0_0 = descriptor_1[38] ? descriptor_1 : descriptor_0;
    wire [38:0] text_compose_0_1 = descriptor_3[38] ? descriptor_3 : descriptor_2;
    wire [38:0] text_compose_0_2 = descriptor_5[38] ? descriptor_5 : descriptor_4;
    wire [38:0] text_compose_0_3 = descriptor_7[38] ? descriptor_7 : descriptor_6;
    wire [38:0] text_compose_0_4 = descriptor_9[38] ? descriptor_9 : descriptor_8;
    wire [38:0] text_compose_0_5 = descriptor_11[38] ? descriptor_11 : descriptor_10;
    wire [38:0] text_compose_0_6 = descriptor_13[38] ? descriptor_13 : descriptor_12;
    wire [38:0] text_compose_0_7 = descriptor_15[38] ? descriptor_15 : descriptor_14;
    wire [38:0] text_compose_0_8 = descriptor_17[38] ? descriptor_17 : descriptor_16;
    wire [38:0] text_compose_0_9 = descriptor_19[38] ? descriptor_19 : descriptor_18;
    wire [38:0] text_compose_0_10 = descriptor_21[38] ? descriptor_21 : descriptor_20;
    wire [38:0] text_compose_0_11 = descriptor_23[38] ? descriptor_23 : descriptor_22;
    wire [38:0] text_compose_0_12 = descriptor_25[38] ? descriptor_25 : descriptor_24;
    wire [38:0] text_compose_1_0 = text_compose_0_1[38] ? text_compose_0_1 : text_compose_0_0;
    wire [38:0] text_compose_1_1 = text_compose_0_3[38] ? text_compose_0_3 : text_compose_0_2;
    wire [38:0] text_compose_1_2 = text_compose_0_5[38] ? text_compose_0_5 : text_compose_0_4;
    wire [38:0] text_compose_1_3 = text_compose_0_7[38] ? text_compose_0_7 : text_compose_0_6;
    wire [38:0] text_compose_1_4 = text_compose_0_9[38] ? text_compose_0_9 : text_compose_0_8;
    wire [38:0] text_compose_1_5 = text_compose_0_11[38] ? text_compose_0_11 : text_compose_0_10;
    wire [38:0] text_compose_2_0 = text_compose_1_1[38] ? text_compose_1_1 : text_compose_1_0;
    wire [38:0] text_compose_2_1 = text_compose_1_3[38] ? text_compose_1_3 : text_compose_1_2;
    wire [38:0] text_compose_2_2 = text_compose_1_5[38] ? text_compose_1_5 : text_compose_1_4;
    wire [38:0] text_compose_3_0 = text_compose_2_1[38] ? text_compose_2_1 : text_compose_2_0;
    wire [38:0] text_compose_3_1 = text_compose_0_12[38] ? text_compose_0_12 : text_compose_2_2;
    wire [38:0] text_compose_4_0 = text_compose_3_1[38] ? text_compose_3_1 : text_compose_3_0;
    assign text_descriptor=text_compose_4_0;
endmodule

module ui_ec11_page_2 (
    input wire [10:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire [511:0] ui_status_flat,
    output wire [23:0] background_rgb,
    output wire [38:0] text_descriptor
);
    function [6:0] hexchar;
        input [3:0] nibble;
        begin hexchar=(nibble<10)?7'd48+nibble:7'd55+nibble; end
    endfunction
    wire [24:0] background_0 = (pixel_x>=16 && pixel_x<784 && pixel_y>=100 && pixel_y<398) ? {1'b1, (pixel_x<17 || pixel_x>=783 || pixel_y<101 || pixel_y>=397) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_1 = (pixel_x>=32 && pixel_x<256 && pixel_y>=254 && pixel_y<308) ? {1'b1, (pixel_x<33 || pixel_x>=255 || pixel_y<255 || pixel_y>=307) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_2 = (pixel_x>=288 && pixel_x<512 && pixel_y>=254 && pixel_y<308) ? {1'b1, (pixel_x<289 || pixel_x>=511 || pixel_y<255 || pixel_y>=307) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_3 = (pixel_x>=544 && pixel_x<768 && pixel_y>=254 && pixel_y<308) ? {1'b1, (pixel_x<545 || pixel_x>=767 || pixel_y<255 || pixel_y>=307) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_4 = (pixel_x>=32 && pixel_x<768 && pixel_y>=336 && pixel_y<380) ? {1'b1, (pixel_x<33 || pixel_x>=767 || pixel_y<337 || pixel_y>=379) ? 24'h334155 : 24'h0F172A} : 25'd0;
    wire [24:0] background_5 = (pixel_x>=16 && pixel_x<264 && pixel_y>=44 && pixel_y<84) ? {1'b1, (pixel_x<17 || pixel_x>=263 || pixel_y<45 || pixel_y>=83) ? 24'h38BDF8 : 24'h0F172A} : 25'd0;
    wire [24:0] background_6 = (pixel_x>=276 && pixel_x<524 && pixel_y>=44 && pixel_y<84) ? {1'b1, (pixel_x<277 || pixel_x>=523 || pixel_y<45 || pixel_y>=83) ? 24'h38BDF8 : 24'h0F172A} : 25'd0;
    wire [24:0] background_7 = (pixel_x>=536 && pixel_x<784 && pixel_y>=44 && pixel_y<84) ? {1'b1, (pixel_x<537 || pixel_x>=783 || pixel_y<45 || pixel_y>=83) ? 24'h38BDF8 : 24'h0F172A} : 25'd0;
    wire [24:0] bg_compose_0_0 = background_1[24] ? background_1 : background_0;
    wire [24:0] bg_compose_0_1 = background_3[24] ? background_3 : background_2;
    wire [24:0] bg_compose_0_2 = background_5[24] ? background_5 : background_4;
    wire [24:0] bg_compose_0_3 = background_7[24] ? background_7 : background_6;
    wire [24:0] bg_compose_1_0 = bg_compose_0_1[24] ? bg_compose_0_1 : bg_compose_0_0;
    wire [24:0] bg_compose_1_1 = bg_compose_0_3[24] ? bg_compose_0_3 : bg_compose_0_2;
    wire [24:0] bg_compose_2_0 = bg_compose_1_1[24] ? bg_compose_1_1 : bg_compose_1_0;
    assign background_rgb=bg_compose_2_0[24] ? bg_compose_2_0[23:0] : 24'h05070C;
    wire [10:0] text_0_lx=pixel_x-11'd16;
    wire [9:0] text_0_ly=pixel_y-10'd8;
    wire [7:0] text_0_index=text_0_lx/16;
    wire [3:0] text_0_row=text_0_ly/2;
    wire [2:0] text_0_col=(text_0_lx%16)/2;
    reg [6:0] text_0_char;
    always @* begin
        case (text_0_index)
            8'd0: text_0_char=7'd69;
            8'd1: text_0_char=7'd67;
            8'd2: text_0_char=7'd49;
            8'd3: text_0_char=7'd49;
            8'd4: text_0_char=7'd32;
            8'd5: text_0_char=7'd47;
            8'd6: text_0_char=7'd32;
            8'd7: text_0_char=7'd84;
            8'd8: text_0_char=7'd72;
            8'd9: text_0_char=7'd82;
            8'd10: text_0_char=7'd69;
            8'd11: text_0_char=7'd69;
            8'd12: text_0_char=7'd32;
            8'd13: text_0_char=7'd80;
            8'd14: text_0_char=7'd65;
            8'd15: text_0_char=7'd71;
            8'd16: text_0_char=7'd69;
            8'd17: text_0_char=7'd32;
            8'd18: text_0_char=7'd85;
            8'd19: text_0_char=7'd73;
            default: text_0_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_0=(text_0_lx<320 && text_0_ly<32) ? {1'b1,24'hE2E8F0,text_0_char,text_0_row,text_0_col} : 39'd0;
    wire [10:0] text_1_lx=pixel_x-11'd492;
    wire [9:0] text_1_ly=pixel_y-10'd12;
    wire [7:0] text_1_index=text_1_lx/8;
    wire [3:0] text_1_row=text_1_ly/1;
    wire [2:0] text_1_col=(text_1_lx%8)/1;
    reg [6:0] text_1_char;
    always @* begin
        case (text_1_index)
            8'd0: text_1_char=7'd76;
            8'd1: text_1_char=7'd79;
            8'd2: text_1_char=7'd67;
            8'd3: text_1_char=7'd65;
            8'd4: text_1_char=7'd76;
            8'd5: text_1_char=7'd32;
            8'd6: text_1_char=7'd84;
            8'd7: text_1_char=7'd69;
            8'd8: text_1_char=7'd83;
            8'd9: text_1_char=7'd84;
            8'd10: text_1_char=7'd32;
            8'd11: text_1_char=7'd45;
            8'd12: text_1_char=7'd32;
            8'd13: text_1_char=7'd78;
            8'd14: text_1_char=7'd79;
            8'd15: text_1_char=7'd32;
            8'd16: text_1_char=7'd83;
            8'd17: text_1_char=7'd68;
            8'd18: text_1_char=7'd47;
            8'd19: text_1_char=7'd65;
            8'd20: text_1_char=7'd85;
            8'd21: text_1_char=7'd68;
            8'd22: text_1_char=7'd73;
            8'd23: text_1_char=7'd79;
            default: text_1_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_1=(text_1_lx<192 && text_1_ly<16) ? {1'b1,24'hE2E8F0,text_1_char,text_1_row,text_1_col} : 39'd0;
    wire [10:0] text_2_lx=pixel_x-11'd16;
    wire [9:0] text_2_ly=pixel_y-10'd464;
    wire [7:0] text_2_index=text_2_lx/8;
    wire [3:0] text_2_row=text_2_ly/1;
    wire [2:0] text_2_col=(text_2_lx%8)/1;
    reg [6:0] text_2_char;
    always @* begin
        case (text_2_index)
            8'd0: text_2_char=7'd82;
            8'd1: text_2_char=7'd79;
            8'd2: text_2_char=7'd84;
            8'd3: text_2_char=7'd65;
            8'd4: text_2_char=7'd84;
            8'd5: text_2_char=7'd69;
            8'd6: text_2_char=7'd58;
            8'd7: text_2_char=7'd32;
            8'd8: text_2_char=7'd70;
            8'd9: text_2_char=7'd79;
            8'd10: text_2_char=7'd67;
            8'd11: text_2_char=7'd85;
            8'd12: text_2_char=7'd83;
            8'd13: text_2_char=7'd32;
            8'd14: text_2_char=7'd45;
            8'd15: text_2_char=7'd32;
            8'd16: text_2_char=7'd67;
            8'd17: text_2_char=7'd76;
            8'd18: text_2_char=7'd73;
            8'd19: text_2_char=7'd67;
            8'd20: text_2_char=7'd75;
            8'd21: text_2_char=7'd58;
            8'd22: text_2_char=7'd32;
            8'd23: text_2_char=7'd69;
            8'd24: text_2_char=7'd78;
            8'd25: text_2_char=7'd84;
            8'd26: text_2_char=7'd69;
            8'd27: text_2_char=7'd82;
            8'd28: text_2_char=7'd47;
            8'd29: text_2_char=7'd79;
            8'd30: text_2_char=7'd75;
            8'd31: text_2_char=7'd32;
            8'd32: text_2_char=7'd45;
            8'd33: text_2_char=7'd32;
            8'd34: text_2_char=7'd72;
            8'd35: text_2_char=7'd79;
            8'd36: text_2_char=7'd76;
            8'd37: text_2_char=7'd68;
            8'd38: text_2_char=7'd32;
            8'd39: text_2_char=7'd48;
            8'd40: text_2_char=7'd46;
            8'd41: text_2_char=7'd56;
            8'd42: text_2_char=7'd83;
            8'd43: text_2_char=7'd58;
            8'd44: text_2_char=7'd32;
            8'd45: text_2_char=7'd67;
            8'd46: text_2_char=7'd65;
            8'd47: text_2_char=7'd78;
            8'd48: text_2_char=7'd67;
            8'd49: text_2_char=7'd69;
            8'd50: text_2_char=7'd76;
            8'd51: text_2_char=7'd47;
            8'd52: text_2_char=7'd66;
            8'd53: text_2_char=7'd65;
            8'd54: text_2_char=7'd67;
            8'd55: text_2_char=7'd75;
            default: text_2_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_2=(text_2_lx<448 && text_2_ly<16) ? {1'b1,24'hE2E8F0,text_2_char,text_2_row,text_2_col} : 39'd0;
    wire [10:0] text_3_lx=pixel_x-11'd32;
    wire [9:0] text_3_ly=pixel_y-10'd160;
    wire [7:0] text_3_index=text_3_lx/16;
    wire [3:0] text_3_row=text_3_ly/2;
    wire [2:0] text_3_col=(text_3_lx%16)/2;
    reg [6:0] text_3_char;
    always @* begin
        case (text_3_index)
            8'd0: text_3_char=7'd76;
            8'd1: text_3_char=7'd79;
            8'd2: text_3_char=7'd67;
            8'd3: text_3_char=7'd65;
            8'd4: text_3_char=7'd76;
            8'd5: text_3_char=7'd32;
            8'd6: text_3_char=7'd82;
            8'd7: text_3_char=7'd69;
            8'd8: text_3_char=7'd81;
            8'd9: text_3_char=7'd85;
            8'd10: text_3_char=7'd69;
            8'd11: text_3_char=7'd83;
            8'd12: text_3_char=7'd84;
            8'd13: text_3_char=7'd32;
            8'd14: text_3_char=7'd79;
            8'd15: text_3_char=7'd78;
            8'd16: text_3_char=7'd76;
            8'd17: text_3_char=7'd89;
            8'd18: text_3_char=7'd32;
            8'd19: text_3_char=7'd45;
            8'd20: text_3_char=7'd32;
            8'd21: text_3_char=7'd78;
            8'd22: text_3_char=7'd79;
            8'd23: text_3_char=7'd32;
            8'd24: text_3_char=7'd77;
            8'd25: text_3_char=7'd85;
            8'd26: text_3_char=7'd83;
            8'd27: text_3_char=7'd73;
            8'd28: text_3_char=7'd67;
            8'd29: text_3_char=7'd32;
            8'd30: text_3_char=7'd80;
            8'd31: text_3_char=7'd76;
            8'd32: text_3_char=7'd65;
            8'd33: text_3_char=7'd89;
            8'd34: text_3_char=7'd66;
            8'd35: text_3_char=7'd65;
            8'd36: text_3_char=7'd67;
            8'd37: text_3_char=7'd75;
            default: text_3_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_3=(text_3_lx<608 && text_3_ly<32) ? {1'b1,24'hE2E8F0,text_3_char,text_3_row,text_3_col} : 39'd0;
    wire [10:0] text_4_lx=pixel_x-11'd32;
    wire [9:0] text_4_ly=pixel_y-10'd198;
    wire [7:0] text_4_index=text_4_lx/8;
    wire [3:0] text_4_row=text_4_ly/1;
    wire [2:0] text_4_col=(text_4_lx%8)/1;
    reg [6:0] text_4_char;
    always @* begin
        case (text_4_index)
            8'd0: text_4_char=7'd76;
            8'd1: text_4_char=7'd65;
            8'd2: text_4_char=7'd83;
            8'd3: text_4_char=7'd84;
            8'd4: text_4_char=7'd32;
            8'd5: text_4_char=7'd76;
            8'd6: text_4_char=7'd79;
            8'd7: text_4_char=7'd67;
            8'd8: text_4_char=7'd65;
            8'd9: text_4_char=7'd76;
            8'd10: text_4_char=7'd32;
            8'd11: text_4_char=7'd82;
            8'd12: text_4_char=7'd69;
            8'd13: text_4_char=7'd81;
            8'd14: text_4_char=7'd85;
            8'd15: text_4_char=7'd69;
            8'd16: text_4_char=7'd83;
            8'd17: text_4_char=7'd84;
            8'd18: text_4_char=7'd58;
            8'd19: text_4_char=7'd32;
            8'd20: text_4_char=hexchar(ui_status_flat[132+:4]);
            8'd21: text_4_char=hexchar(ui_status_flat[128+:4]);
            default: text_4_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_4=(text_4_lx<176 && text_4_ly<16) ? {1'b1,24'hE2E8F0,text_4_char,text_4_row,text_4_col} : 39'd0;
    wire [10:0] text_5_lx=pixel_x-11'd32;
    wire [9:0] text_5_ly=pixel_y-10'd118;
    wire [7:0] text_5_index=text_5_lx/8;
    wire [3:0] text_5_row=text_5_ly/1;
    wire [2:0] text_5_col=(text_5_lx%8)/1;
    reg [6:0] text_5_char;
    always @* begin
        case (text_5_index)
            8'd0: text_5_char=7'd83;
            8'd1: text_5_char=7'd68;
            8'd2: text_5_char=7'd32;
            8'd3: text_5_char=7'd47;
            8'd4: text_5_char=7'd32;
            8'd5: text_5_char=7'd83;
            8'd6: text_5_char=7'd89;
            8'd7: text_5_char=7'd78;
            8'd8: text_5_char=7'd84;
            8'd9: text_5_char=7'd72;
            8'd10: text_5_char=7'd32;
            8'd11: text_5_char=7'd66;
            8'd12: text_5_char=7'd65;
            8'd13: text_5_char=7'd67;
            8'd14: text_5_char=7'd75;
            8'd15: text_5_char=7'd69;
            8'd16: text_5_char=7'd78;
            8'd17: text_5_char=7'd68;
            8'd18: text_5_char=7'd58;
            8'd19: text_5_char=7'd32;
            8'd20: text_5_char=7'd78;
            8'd21: text_5_char=7'd79;
            8'd22: text_5_char=7'd84;
            8'd23: text_5_char=7'd32;
            8'd24: text_5_char=7'd67;
            8'd25: text_5_char=7'd79;
            8'd26: text_5_char=7'd78;
            8'd27: text_5_char=7'd78;
            8'd28: text_5_char=7'd69;
            8'd29: text_5_char=7'd67;
            8'd30: text_5_char=7'd84;
            8'd31: text_5_char=7'd69;
            8'd32: text_5_char=7'd68;
            default: text_5_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_5=(text_5_lx<264 && text_5_ly<16) ? {1'b1,24'hE2E8F0,text_5_char,text_5_row,text_5_col} : 39'd0;
    wire [10:0] text_6_lx=pixel_x-11'd72;
    wire [9:0] text_6_ly=pixel_y-10'd266;
    wire [7:0] text_6_index=text_6_lx/16;
    wire [3:0] text_6_row=text_6_ly/2;
    wire [2:0] text_6_col=(text_6_lx%16)/2;
    reg [6:0] text_6_char;
    always @* begin
        case (text_6_index)
            8'd0: text_6_char=7'd65;
            8'd1: text_6_char=7'd85;
            8'd2: text_6_char=7'd84;
            8'd3: text_6_char=7'd79;
            8'd4: text_6_char=7'd32;
            8'd5: text_6_char=7'd77;
            8'd6: text_6_char=7'd79;
            8'd7: text_6_char=7'd68;
            8'd8: text_6_char=7'd69;
            default: text_6_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_6=(text_6_lx<144 && text_6_ly<32) ? {1'b1,24'h7DD3FC,text_6_char,text_6_row,text_6_col} : 39'd0;
    wire [10:0] text_7_lx=pixel_x-11'd368;
    wire [9:0] text_7_ly=pixel_y-10'd266;
    wire [7:0] text_7_index=text_7_lx/16;
    wire [3:0] text_7_row=text_7_ly/2;
    wire [2:0] text_7_col=(text_7_lx%16)/2;
    reg [6:0] text_7_char;
    always @* begin
        case (text_7_index)
            8'd0: text_7_char=7'd80;
            8'd1: text_7_char=7'd76;
            8'd2: text_7_char=7'd65;
            8'd3: text_7_char=7'd89;
            default: text_7_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_7=(text_7_lx<64 && text_7_ly<32) ? {1'b1,24'h7DD3FC,text_7_char,text_7_row,text_7_col} : 39'd0;
    wire [10:0] text_8_lx=pixel_x-11'd624;
    wire [9:0] text_8_ly=pixel_y-10'd266;
    wire [7:0] text_8_index=text_8_lx/16;
    wire [3:0] text_8_row=text_8_ly/2;
    wire [2:0] text_8_col=(text_8_lx%16)/2;
    reg [6:0] text_8_char;
    always @* begin
        case (text_8_index)
            8'd0: text_8_char=7'd83;
            8'd1: text_8_char=7'd84;
            8'd2: text_8_char=7'd79;
            8'd3: text_8_char=7'd80;
            default: text_8_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_8=(text_8_lx<64 && text_8_ly<32) ? {1'b1,24'h7DD3FC,text_8_char,text_8_row,text_8_col} : 39'd0;
    wire [10:0] text_9_lx=pixel_x-11'd280;
    wire [9:0] text_9_ly=pixel_y-10'd348;
    wire [7:0] text_9_index=text_9_lx/16;
    wire [3:0] text_9_row=text_9_ly/2;
    wire [2:0] text_9_col=(text_9_lx%16)/2;
    reg [6:0] text_9_char;
    always @* begin
        case (text_9_index)
            8'd0: text_9_char=7'd81;
            8'd1: text_9_char=7'd85;
            8'd2: text_9_char=7'd69;
            8'd3: text_9_char=7'd82;
            8'd4: text_9_char=7'd89;
            8'd5: text_9_char=7'd32;
            8'd6: text_9_char=7'd70;
            8'd7: text_9_char=7'd80;
            8'd8: text_9_char=7'd71;
            8'd9: text_9_char=7'd65;
            8'd10: text_9_char=7'd32;
            8'd11: text_9_char=7'd77;
            8'd12: text_9_char=7'd79;
            8'd13: text_9_char=7'd68;
            8'd14: text_9_char=7'd69;
            default: text_9_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_9=(text_9_lx<240 && text_9_ly<32) ? {1'b1,24'h7DD3FC,text_9_char,text_9_row,text_9_col} : 39'd0;
    wire [10:0] text_10_lx=pixel_x-11'd24;
    wire [9:0] text_10_ly=pixel_y-10'd412;
    wire [7:0] text_10_index=text_10_lx/8;
    wire [3:0] text_10_row=text_10_ly/1;
    wire [2:0] text_10_col=(text_10_lx%8)/1;
    reg [6:0] text_10_char;
    always @* begin
        case (text_10_index)
            8'd0: text_10_char=7'd82;
            8'd1: text_10_char=7'd69;
            8'd2: text_10_char=7'd81;
            8'd3: text_10_char=7'd85;
            8'd4: text_10_char=7'd69;
            8'd5: text_10_char=7'd83;
            8'd6: text_10_char=7'd84;
            8'd7: text_10_char=7'd32;
            8'd8: text_10_char=7'd67;
            8'd9: text_10_char=7'd79;
            8'd10: text_10_char=7'd68;
            8'd11: text_10_char=7'd69;
            8'd12: text_10_char=7'd83;
            8'd13: text_10_char=7'd58;
            8'd14: text_10_char=7'd32;
            8'd15: text_10_char=7'd48;
            8'd16: text_10_char=7'd49;
            8'd17: text_10_char=7'd32;
            8'd18: text_10_char=7'd83;
            8'd19: text_10_char=7'd67;
            8'd20: text_10_char=7'd65;
            8'd21: text_10_char=7'd78;
            8'd22: text_10_char=7'd32;
            8'd23: text_10_char=7'd48;
            8'd24: text_10_char=7'd50;
            8'd25: text_10_char=7'd32;
            8'd26: text_10_char=7'd80;
            8'd27: text_10_char=7'd82;
            8'd28: text_10_char=7'd69;
            8'd29: text_10_char=7'd86;
            8'd30: text_10_char=7'd32;
            8'd31: text_10_char=7'd48;
            8'd32: text_10_char=7'd51;
            8'd33: text_10_char=7'd32;
            8'd34: text_10_char=7'd78;
            8'd35: text_10_char=7'd69;
            8'd36: text_10_char=7'd88;
            8'd37: text_10_char=7'd84;
            8'd38: text_10_char=7'd32;
            8'd39: text_10_char=7'd48;
            8'd40: text_10_char=7'd52;
            8'd41: text_10_char=7'd32;
            8'd42: text_10_char=7'd76;
            8'd43: text_10_char=7'd79;
            8'd44: text_10_char=7'd65;
            8'd45: text_10_char=7'd68;
            default: text_10_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_10=(text_10_lx<368 && text_10_ly<16) ? {1'b1,24'hE2E8F0,text_10_char,text_10_row,text_10_col} : 39'd0;
    wire [10:0] text_11_lx=pixel_x-11'd24;
    wire [9:0] text_11_ly=pixel_y-10'd438;
    wire [7:0] text_11_index=text_11_lx/8;
    wire [3:0] text_11_row=text_11_ly/1;
    wire [2:0] text_11_col=(text_11_lx%8)/1;
    reg [6:0] text_11_char;
    always @* begin
        case (text_11_index)
            8'd0: text_11_char=7'd48;
            8'd1: text_11_char=7'd53;
            8'd2: text_11_char=7'd32;
            8'd3: text_11_char=7'd65;
            8'd4: text_11_char=7'd85;
            8'd5: text_11_char=7'd84;
            8'd6: text_11_char=7'd79;
            8'd7: text_11_char=7'd32;
            8'd8: text_11_char=7'd48;
            8'd9: text_11_char=7'd54;
            8'd10: text_11_char=7'd32;
            8'd11: text_11_char=7'd80;
            8'd12: text_11_char=7'd76;
            8'd13: text_11_char=7'd65;
            8'd14: text_11_char=7'd89;
            8'd15: text_11_char=7'd32;
            8'd16: text_11_char=7'd48;
            8'd17: text_11_char=7'd55;
            8'd18: text_11_char=7'd32;
            8'd19: text_11_char=7'd83;
            8'd20: text_11_char=7'd84;
            8'd21: text_11_char=7'd79;
            8'd22: text_11_char=7'd80;
            8'd23: text_11_char=7'd32;
            8'd24: text_11_char=7'd48;
            8'd25: text_11_char=7'd56;
            8'd26: text_11_char=7'd32;
            8'd27: text_11_char=7'd81;
            8'd28: text_11_char=7'd85;
            8'd29: text_11_char=7'd69;
            8'd30: text_11_char=7'd82;
            8'd31: text_11_char=7'd89;
            8'd32: text_11_char=7'd32;
            8'd33: text_11_char=7'd45;
            8'd34: text_11_char=7'd32;
            8'd35: text_11_char=7'd78;
            8'd36: text_11_char=7'd79;
            8'd37: text_11_char=7'd32;
            8'd38: text_11_char=7'd66;
            8'd39: text_11_char=7'd65;
            8'd40: text_11_char=7'd67;
            8'd41: text_11_char=7'd75;
            8'd42: text_11_char=7'd69;
            8'd43: text_11_char=7'd78;
            8'd44: text_11_char=7'd68;
            8'd45: text_11_char=7'd32;
            8'd46: text_11_char=7'd65;
            8'd47: text_11_char=7'd67;
            8'd48: text_11_char=7'd75;
            default: text_11_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_11=(text_11_lx<392 && text_11_ly<16) ? {1'b1,24'hE2E8F0,text_11_char,text_11_row,text_11_col} : 39'd0;
    wire [10:0] text_12_lx=pixel_x-11'd108;
    wire [9:0] text_12_ly=pixel_y-10'd56;
    wire [7:0] text_12_index=text_12_lx/8;
    wire [3:0] text_12_row=text_12_ly/1;
    wire [2:0] text_12_col=(text_12_lx%8)/1;
    reg [6:0] text_12_char;
    always @* begin
        case (text_12_index)
            8'd0: text_12_char=7'd83;
            8'd1: text_12_char=7'd68;
            8'd2: text_12_char=7'd32;
            8'd3: text_12_char=7'd83;
            8'd4: text_12_char=7'd79;
            8'd5: text_12_char=7'd78;
            8'd6: text_12_char=7'd71;
            8'd7: text_12_char=7'd83;
            default: text_12_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_12=(text_12_lx<64 && text_12_ly<16) ? {1'b1,24'h7DD3FC,text_12_char,text_12_row,text_12_col} : 39'd0;
    wire [10:0] text_13_lx=pixel_x-11'd340;
    wire [9:0] text_13_ly=pixel_y-10'd56;
    wire [7:0] text_13_index=text_13_lx/8;
    wire [3:0] text_13_row=text_13_ly/1;
    wire [2:0] text_13_col=(text_13_lx%8)/1;
    reg [6:0] text_13_char;
    always @* begin
        case (text_13_index)
            8'd0: text_13_char=7'd80;
            8'd1: text_13_char=7'd65;
            8'd2: text_13_char=7'd84;
            8'd3: text_13_char=7'd67;
            8'd4: text_13_char=7'd72;
            8'd5: text_13_char=7'd32;
            8'd6: text_13_char=7'd47;
            8'd7: text_13_char=7'd32;
            8'd8: text_13_char=7'd69;
            8'd9: text_13_char=7'd70;
            8'd10: text_13_char=7'd70;
            8'd11: text_13_char=7'd69;
            8'd12: text_13_char=7'd67;
            8'd13: text_13_char=7'd84;
            8'd14: text_13_char=7'd83;
            default: text_13_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_13=(text_13_lx<120 && text_13_ly<16) ? {1'b1,24'h7DD3FC,text_13_char,text_13_row,text_13_col} : 39'd0;
    wire [10:0] text_14_lx=pixel_x-11'd608;
    wire [9:0] text_14_ly=pixel_y-10'd56;
    wire [7:0] text_14_index=text_14_lx/8;
    wire [3:0] text_14_row=text_14_ly/1;
    wire [2:0] text_14_col=(text_14_lx%8)/1;
    reg [6:0] text_14_char;
    always @* begin
        case (text_14_index)
            8'd0: text_14_char=7'd83;
            8'd1: text_14_char=7'd84;
            8'd2: text_14_char=7'd65;
            8'd3: text_14_char=7'd84;
            8'd4: text_14_char=7'd85;
            8'd5: text_14_char=7'd83;
            8'd6: text_14_char=7'd32;
            8'd7: text_14_char=7'd47;
            8'd8: text_14_char=7'd32;
            8'd9: text_14_char=7'd80;
            8'd10: text_14_char=7'd76;
            8'd11: text_14_char=7'd65;
            8'd12: text_14_char=7'd89;
            default: text_14_char=7'd32;
        endcase
    end
    wire [38:0] descriptor_14=(text_14_lx<104 && text_14_ly<16) ? {1'b1,24'h7DD3FC,text_14_char,text_14_row,text_14_col} : 39'd0;
    wire [38:0] text_compose_0_0 = descriptor_1[38] ? descriptor_1 : descriptor_0;
    wire [38:0] text_compose_0_1 = descriptor_3[38] ? descriptor_3 : descriptor_2;
    wire [38:0] text_compose_0_2 = descriptor_5[38] ? descriptor_5 : descriptor_4;
    wire [38:0] text_compose_0_3 = descriptor_7[38] ? descriptor_7 : descriptor_6;
    wire [38:0] text_compose_0_4 = descriptor_9[38] ? descriptor_9 : descriptor_8;
    wire [38:0] text_compose_0_5 = descriptor_11[38] ? descriptor_11 : descriptor_10;
    wire [38:0] text_compose_0_6 = descriptor_13[38] ? descriptor_13 : descriptor_12;
    wire [38:0] text_compose_1_0 = text_compose_0_1[38] ? text_compose_0_1 : text_compose_0_0;
    wire [38:0] text_compose_1_1 = text_compose_0_3[38] ? text_compose_0_3 : text_compose_0_2;
    wire [38:0] text_compose_1_2 = text_compose_0_5[38] ? text_compose_0_5 : text_compose_0_4;
    wire [38:0] text_compose_1_3 = descriptor_14[38] ? descriptor_14 : text_compose_0_6;
    wire [38:0] text_compose_2_0 = text_compose_1_1[38] ? text_compose_1_1 : text_compose_1_0;
    wire [38:0] text_compose_2_1 = text_compose_1_3[38] ? text_compose_1_3 : text_compose_1_2;
    wire [38:0] text_compose_3_0 = text_compose_2_1[38] ? text_compose_2_1 : text_compose_2_0;
    assign text_descriptor=text_compose_3_0;
endmodule
// One 2048x8 synchronous ROM shared by ALL pages/labels.
// MSB is the leftmost pixel. Unsupported ASCII is blank.
module ui_ec11_font_rom (
    input wire clk,
    input wire [6:0] char_code,
    input wire [3:0] row,
    output reg [7:0] pixels
);
    reg [7:0] font_rows [0:2047];
    integer i;
    initial begin
        for (i=0; i<1024; i=i+1) begin
            font_rows[i] = 8'd0;
            font_rows[i+1024] = 8'd0;
        end
        font_rows[530] = 8'h18;
        font_rows[531] = 8'h18;
        font_rows[532] = 8'h18;
        font_rows[533] = 8'h18;
        font_rows[534] = 8'h18;
        font_rows[535] = 8'h18;
        font_rows[536] = 8'h18;
        font_rows[538] = 8'h18;
        font_rows[539] = 8'h18;
        font_rows[546] = 8'h6C;
        font_rows[547] = 8'h2C;
        font_rows[548] = 8'h2C;
        font_rows[563] = 8'h34;
        font_rows[564] = 8'h24;
        font_rows[565] = 8'h7F;
        font_rows[566] = 8'h24;
        font_rows[567] = 8'h2C;
        font_rows[568] = 8'h2C;
        font_rows[569] = 8'hFE;
        font_rows[570] = 8'h6C;
        font_rows[571] = 8'h6C;
        font_rows[578] = 8'h08;
        font_rows[579] = 8'h3E;
        font_rows[580] = 8'h78;
        font_rows[581] = 8'h78;
        font_rows[582] = 8'h78;
        font_rows[583] = 8'h3C;
        font_rows[584] = 8'h1E;
        font_rows[585] = 8'h16;
        font_rows[586] = 8'h16;
        font_rows[587] = 8'hFC;
        font_rows[588] = 8'h30;
        font_rows[589] = 8'h30;
        font_rows[594] = 8'h73;
        font_rows[595] = 8'hF6;
        font_rows[596] = 8'hF4;
        font_rows[597] = 8'h6C;
        font_rows[598] = 8'h18;
        font_rows[599] = 8'h10;
        font_rows[600] = 8'h3E;
        font_rows[601] = 8'h6B;
        font_rows[602] = 8'h4B;
        font_rows[603] = 8'hCE;
        font_rows[610] = 8'h38;
        font_rows[611] = 8'h6C;
        font_rows[612] = 8'h6C;
        font_rows[613] = 8'h7C;
        font_rows[614] = 8'h78;
        font_rows[615] = 8'h7E;
        font_rows[616] = 8'hDE;
        font_rows[617] = 8'hCE;
        font_rows[618] = 8'hCE;
        font_rows[619] = 8'h7F;
        font_rows[626] = 8'h18;
        font_rows[627] = 8'h18;
        font_rows[628] = 8'h18;
        font_rows[642] = 8'h04;
        font_rows[643] = 8'h0C;
        font_rows[644] = 8'h18;
        font_rows[645] = 8'h30;
        font_rows[646] = 8'h30;
        font_rows[647] = 8'h30;
        font_rows[648] = 8'h30;
        font_rows[649] = 8'h30;
        font_rows[650] = 8'h30;
        font_rows[651] = 8'h30;
        font_rows[652] = 8'h18;
        font_rows[653] = 8'h0C;
        font_rows[654] = 8'h04;
        font_rows[658] = 8'h20;
        font_rows[659] = 8'h30;
        font_rows[660] = 8'h18;
        font_rows[661] = 8'h18;
        font_rows[662] = 8'h0C;
        font_rows[663] = 8'h0C;
        font_rows[664] = 8'h0C;
        font_rows[665] = 8'h0C;
        font_rows[666] = 8'h0C;
        font_rows[667] = 8'h18;
        font_rows[668] = 8'h18;
        font_rows[669] = 8'h30;
        font_rows[670] = 8'h20;
        font_rows[674] = 8'h18;
        font_rows[675] = 8'h7E;
        font_rows[676] = 8'h7C;
        font_rows[677] = 8'h7C;
        font_rows[678] = 8'h7E;
        font_rows[679] = 8'h18;
        font_rows[693] = 8'h18;
        font_rows[694] = 8'h18;
        font_rows[695] = 8'h18;
        font_rows[696] = 8'hFE;
        font_rows[697] = 8'h18;
        font_rows[698] = 8'h18;
        font_rows[699] = 8'h18;
        font_rows[713] = 8'h18;
        font_rows[714] = 8'h18;
        font_rows[715] = 8'h18;
        font_rows[716] = 8'h18;
        font_rows[717] = 8'h70;
        font_rows[728] = 8'h3C;
        font_rows[745] = 8'h18;
        font_rows[746] = 8'h38;
        font_rows[747] = 8'h18;
        font_rows[754] = 8'h06;
        font_rows[755] = 8'h0C;
        font_rows[756] = 8'h0C;
        font_rows[757] = 8'h08;
        font_rows[758] = 8'h18;
        font_rows[759] = 8'h18;
        font_rows[760] = 8'h30;
        font_rows[761] = 8'h30;
        font_rows[762] = 8'h60;
        font_rows[763] = 8'h60;
        font_rows[764] = 8'h40;
        font_rows[771] = 8'h3C;
        font_rows[772] = 8'h66;
        font_rows[773] = 8'h46;
        font_rows[774] = 8'hCE;
        font_rows[775] = 8'hDE;
        font_rows[776] = 8'hE6;
        font_rows[777] = 8'hE6;
        font_rows[778] = 8'h66;
        font_rows[779] = 8'h3C;
        font_rows[787] = 8'h18;
        font_rows[788] = 8'h78;
        font_rows[789] = 8'h58;
        font_rows[790] = 8'h18;
        font_rows[791] = 8'h18;
        font_rows[792] = 8'h18;
        font_rows[793] = 8'h18;
        font_rows[794] = 8'h18;
        font_rows[795] = 8'h7E;
        font_rows[803] = 8'h3C;
        font_rows[804] = 8'h6C;
        font_rows[805] = 8'h06;
        font_rows[806] = 8'h06;
        font_rows[807] = 8'h0C;
        font_rows[808] = 8'h18;
        font_rows[809] = 8'h30;
        font_rows[810] = 8'h70;
        font_rows[811] = 8'h7E;
        font_rows[819] = 8'h7C;
        font_rows[820] = 8'h0C;
        font_rows[821] = 8'h06;
        font_rows[822] = 8'h0C;
        font_rows[823] = 8'h3C;
        font_rows[824] = 8'h06;
        font_rows[825] = 8'h06;
        font_rows[826] = 8'h0E;
        font_rows[827] = 8'h7C;
        font_rows[835] = 8'h1C;
        font_rows[836] = 8'h1C;
        font_rows[837] = 8'h3C;
        font_rows[838] = 8'h2C;
        font_rows[839] = 8'h6C;
        font_rows[840] = 8'hCC;
        font_rows[841] = 8'hFF;
        font_rows[842] = 8'h0C;
        font_rows[843] = 8'h0C;
        font_rows[851] = 8'h7E;
        font_rows[852] = 8'h60;
        font_rows[853] = 8'h60;
        font_rows[854] = 8'h7C;
        font_rows[855] = 8'h0E;
        font_rows[856] = 8'h06;
        font_rows[857] = 8'h06;
        font_rows[858] = 8'h0C;
        font_rows[859] = 8'h78;
        font_rows[867] = 8'h1E;
        font_rows[868] = 8'h70;
        font_rows[869] = 8'h60;
        font_rows[870] = 8'h7C;
        font_rows[871] = 8'h66;
        font_rows[872] = 8'h66;
        font_rows[873] = 8'h66;
        font_rows[874] = 8'h66;
        font_rows[875] = 8'h3C;
        font_rows[883] = 8'h7E;
        font_rows[884] = 8'h06;
        font_rows[885] = 8'h0C;
        font_rows[886] = 8'h0C;
        font_rows[887] = 8'h18;
        font_rows[888] = 8'h18;
        font_rows[889] = 8'h38;
        font_rows[890] = 8'h30;
        font_rows[891] = 8'h30;
        font_rows[899] = 8'h3C;
        font_rows[900] = 8'h66;
        font_rows[901] = 8'h66;
        font_rows[902] = 8'h7C;
        font_rows[903] = 8'h3C;
        font_rows[904] = 8'h6E;
        font_rows[905] = 8'h66;
        font_rows[906] = 8'h66;
        font_rows[907] = 8'h3C;
        font_rows[915] = 8'h3C;
        font_rows[916] = 8'h6E;
        font_rows[917] = 8'hC6;
        font_rows[918] = 8'hC6;
        font_rows[919] = 8'h66;
        font_rows[920] = 8'h7E;
        font_rows[921] = 8'h06;
        font_rows[922] = 8'h0C;
        font_rows[923] = 8'h78;
        font_rows[933] = 8'h18;
        font_rows[934] = 8'h18;
        font_rows[938] = 8'h18;
        font_rows[939] = 8'h18;
        font_rows[949] = 8'h18;
        font_rows[950] = 8'h18;
        font_rows[953] = 8'h18;
        font_rows[954] = 8'h18;
        font_rows[955] = 8'h18;
        font_rows[956] = 8'h18;
        font_rows[957] = 8'h70;
        font_rows[964] = 8'h04;
        font_rows[965] = 8'h1C;
        font_rows[966] = 8'h38;
        font_rows[967] = 8'h70;
        font_rows[968] = 8'h70;
        font_rows[969] = 8'h38;
        font_rows[970] = 8'h1C;
        font_rows[971] = 8'h04;
        font_rows[983] = 8'h7E;
        font_rows[985] = 8'h7E;
        font_rows[996] = 8'h20;
        font_rows[997] = 8'h30;
        font_rows[998] = 8'h18;
        font_rows[999] = 8'h0E;
        font_rows[1000] = 8'h0E;
        font_rows[1001] = 8'h18;
        font_rows[1002] = 8'h30;
        font_rows[1003] = 8'h20;
        font_rows[1010] = 8'h38;
        font_rows[1011] = 8'h0C;
        font_rows[1012] = 8'h06;
        font_rows[1013] = 8'h0E;
        font_rows[1014] = 8'h3C;
        font_rows[1015] = 8'h30;
        font_rows[1016] = 8'h30;
        font_rows[1018] = 8'h30;
        font_rows[1019] = 8'h30;
        font_rows[1026] = 8'h1C;
        font_rows[1027] = 8'h36;
        font_rows[1028] = 8'h62;
        font_rows[1029] = 8'h5F;
        font_rows[1030] = 8'hFF;
        font_rows[1031] = 8'hFF;
        font_rows[1032] = 8'hEF;
        font_rows[1033] = 8'hEF;
        font_rows[1034] = 8'hFE;
        font_rows[1035] = 8'hFE;
        font_rows[1036] = 8'hC0;
        font_rows[1037] = 8'h64;
        font_rows[1038] = 8'h3C;
        font_rows[1043] = 8'h38;
        font_rows[1044] = 8'h3C;
        font_rows[1045] = 8'h3C;
        font_rows[1046] = 8'h2C;
        font_rows[1047] = 8'h6C;
        font_rows[1048] = 8'h66;
        font_rows[1049] = 8'h7E;
        font_rows[1050] = 8'hC6;
        font_rows[1051] = 8'hC3;
        font_rows[1059] = 8'h7C;
        font_rows[1060] = 8'h66;
        font_rows[1061] = 8'h66;
        font_rows[1062] = 8'h66;
        font_rows[1063] = 8'h7C;
        font_rows[1064] = 8'h66;
        font_rows[1065] = 8'h66;
        font_rows[1066] = 8'h66;
        font_rows[1067] = 8'h7C;
        font_rows[1075] = 8'h3C;
        font_rows[1076] = 8'h72;
        font_rows[1077] = 8'h60;
        font_rows[1078] = 8'h60;
        font_rows[1079] = 8'hE0;
        font_rows[1080] = 8'h60;
        font_rows[1081] = 8'h60;
        font_rows[1082] = 8'h72;
        font_rows[1083] = 8'h3C;
        font_rows[1091] = 8'hFC;
        font_rows[1092] = 8'hCE;
        font_rows[1093] = 8'hC6;
        font_rows[1094] = 8'hC6;
        font_rows[1095] = 8'hC6;
        font_rows[1096] = 8'hC6;
        font_rows[1097] = 8'hC6;
        font_rows[1098] = 8'hCE;
        font_rows[1099] = 8'hF8;
        font_rows[1107] = 8'h7E;
        font_rows[1108] = 8'h60;
        font_rows[1109] = 8'h60;
        font_rows[1110] = 8'h60;
        font_rows[1111] = 8'h7E;
        font_rows[1112] = 8'h60;
        font_rows[1113] = 8'h60;
        font_rows[1114] = 8'h60;
        font_rows[1115] = 8'h7E;
        font_rows[1123] = 8'h7E;
        font_rows[1124] = 8'h60;
        font_rows[1125] = 8'h60;
        font_rows[1126] = 8'h60;
        font_rows[1127] = 8'h7C;
        font_rows[1128] = 8'h60;
        font_rows[1129] = 8'h60;
        font_rows[1130] = 8'h60;
        font_rows[1131] = 8'h60;
        font_rows[1139] = 8'h3C;
        font_rows[1140] = 8'h62;
        font_rows[1141] = 8'h60;
        font_rows[1142] = 8'hC0;
        font_rows[1143] = 8'hCE;
        font_rows[1144] = 8'hC6;
        font_rows[1145] = 8'h66;
        font_rows[1146] = 8'h66;
        font_rows[1147] = 8'h3E;
        font_rows[1155] = 8'h46;
        font_rows[1156] = 8'h46;
        font_rows[1157] = 8'h46;
        font_rows[1158] = 8'h46;
        font_rows[1159] = 8'h7E;
        font_rows[1160] = 8'h46;
        font_rows[1161] = 8'h46;
        font_rows[1162] = 8'h46;
        font_rows[1163] = 8'h46;
        font_rows[1171] = 8'h7E;
        font_rows[1172] = 8'h18;
        font_rows[1173] = 8'h18;
        font_rows[1174] = 8'h18;
        font_rows[1175] = 8'h18;
        font_rows[1176] = 8'h18;
        font_rows[1177] = 8'h18;
        font_rows[1178] = 8'h18;
        font_rows[1179] = 8'h7E;
        font_rows[1187] = 8'h7C;
        font_rows[1188] = 8'h0C;
        font_rows[1189] = 8'h0C;
        font_rows[1190] = 8'h0C;
        font_rows[1191] = 8'h0C;
        font_rows[1192] = 8'h0C;
        font_rows[1193] = 8'h0C;
        font_rows[1194] = 8'h4C;
        font_rows[1195] = 8'h38;
        font_rows[1203] = 8'h66;
        font_rows[1204] = 8'h6C;
        font_rows[1205] = 8'h6C;
        font_rows[1206] = 8'h78;
        font_rows[1207] = 8'h78;
        font_rows[1208] = 8'h78;
        font_rows[1209] = 8'h6C;
        font_rows[1210] = 8'h6E;
        font_rows[1211] = 8'h66;
        font_rows[1219] = 8'h60;
        font_rows[1220] = 8'h60;
        font_rows[1221] = 8'h60;
        font_rows[1222] = 8'h60;
        font_rows[1223] = 8'h60;
        font_rows[1224] = 8'h60;
        font_rows[1225] = 8'h60;
        font_rows[1226] = 8'h60;
        font_rows[1227] = 8'h7E;
        font_rows[1235] = 8'h66;
        font_rows[1236] = 8'h6E;
        font_rows[1237] = 8'h6E;
        font_rows[1238] = 8'hFA;
        font_rows[1239] = 8'hDA;
        font_rows[1240] = 8'hDA;
        font_rows[1241] = 8'hC2;
        font_rows[1242] = 8'hC2;
        font_rows[1243] = 8'hC2;
        font_rows[1251] = 8'h66;
        font_rows[1252] = 8'h76;
        font_rows[1253] = 8'h76;
        font_rows[1254] = 8'h76;
        font_rows[1255] = 8'h5E;
        font_rows[1256] = 8'h5E;
        font_rows[1257] = 8'h4E;
        font_rows[1258] = 8'h4E;
        font_rows[1259] = 8'h46;
        font_rows[1267] = 8'h3C;
        font_rows[1268] = 8'h66;
        font_rows[1269] = 8'hC6;
        font_rows[1270] = 8'hC6;
        font_rows[1271] = 8'hC3;
        font_rows[1272] = 8'hC6;
        font_rows[1273] = 8'hC6;
        font_rows[1274] = 8'h66;
        font_rows[1275] = 8'h3C;
        font_rows[1283] = 8'h7C;
        font_rows[1284] = 8'h66;
        font_rows[1285] = 8'h66;
        font_rows[1286] = 8'h66;
        font_rows[1287] = 8'h66;
        font_rows[1288] = 8'h7C;
        font_rows[1289] = 8'h60;
        font_rows[1290] = 8'h60;
        font_rows[1291] = 8'h60;
        font_rows[1299] = 8'h3C;
        font_rows[1300] = 8'h66;
        font_rows[1301] = 8'hC6;
        font_rows[1302] = 8'hC6;
        font_rows[1303] = 8'hC3;
        font_rows[1304] = 8'hC6;
        font_rows[1305] = 8'hC6;
        font_rows[1306] = 8'h66;
        font_rows[1307] = 8'h3C;
        font_rows[1308] = 8'h18;
        font_rows[1309] = 8'h18;
        font_rows[1310] = 8'h0E;
        font_rows[1315] = 8'h7C;
        font_rows[1316] = 8'h6E;
        font_rows[1317] = 8'h66;
        font_rows[1318] = 8'h6E;
        font_rows[1319] = 8'h7C;
        font_rows[1320] = 8'h6C;
        font_rows[1321] = 8'h6C;
        font_rows[1322] = 8'h66;
        font_rows[1323] = 8'h66;
        font_rows[1331] = 8'h3C;
        font_rows[1332] = 8'h64;
        font_rows[1333] = 8'h60;
        font_rows[1334] = 8'h70;
        font_rows[1335] = 8'h3C;
        font_rows[1336] = 8'h0E;
        font_rows[1337] = 8'h06;
        font_rows[1338] = 8'h46;
        font_rows[1339] = 8'h7C;
        font_rows[1347] = 8'hFE;
        font_rows[1348] = 8'h18;
        font_rows[1349] = 8'h18;
        font_rows[1350] = 8'h18;
        font_rows[1351] = 8'h18;
        font_rows[1352] = 8'h18;
        font_rows[1353] = 8'h18;
        font_rows[1354] = 8'h18;
        font_rows[1355] = 8'h18;
        font_rows[1363] = 8'hC6;
        font_rows[1364] = 8'hC6;
        font_rows[1365] = 8'hC6;
        font_rows[1366] = 8'hC6;
        font_rows[1367] = 8'hC6;
        font_rows[1368] = 8'hC6;
        font_rows[1369] = 8'h46;
        font_rows[1370] = 8'h66;
        font_rows[1371] = 8'h3C;
        font_rows[1379] = 8'hC3;
        font_rows[1380] = 8'hC6;
        font_rows[1381] = 8'h66;
        font_rows[1382] = 8'h66;
        font_rows[1383] = 8'h64;
        font_rows[1384] = 8'h3C;
        font_rows[1385] = 8'h3C;
        font_rows[1386] = 8'h3C;
        font_rows[1387] = 8'h38;
        font_rows[1395] = 8'hC3;
        font_rows[1396] = 8'hC3;
        font_rows[1397] = 8'hC2;
        font_rows[1398] = 8'hDA;
        font_rows[1399] = 8'hDA;
        font_rows[1400] = 8'hDA;
        font_rows[1401] = 8'hEE;
        font_rows[1402] = 8'h6E;
        font_rows[1403] = 8'h66;
        font_rows[1411] = 8'hE6;
        font_rows[1412] = 8'h6E;
        font_rows[1413] = 8'h3C;
        font_rows[1414] = 8'h38;
        font_rows[1415] = 8'h18;
        font_rows[1416] = 8'h3C;
        font_rows[1417] = 8'h6C;
        font_rows[1418] = 8'h66;
        font_rows[1419] = 8'hC6;
        font_rows[1427] = 8'hC6;
        font_rows[1428] = 8'h66;
        font_rows[1429] = 8'h6C;
        font_rows[1430] = 8'h3C;
        font_rows[1431] = 8'h38;
        font_rows[1432] = 8'h18;
        font_rows[1433] = 8'h18;
        font_rows[1434] = 8'h18;
        font_rows[1435] = 8'h18;
        font_rows[1443] = 8'h7E;
        font_rows[1444] = 8'h0C;
        font_rows[1445] = 8'h0C;
        font_rows[1446] = 8'h18;
        font_rows[1447] = 8'h18;
        font_rows[1448] = 8'h30;
        font_rows[1449] = 8'h30;
        font_rows[1450] = 8'h60;
        font_rows[1451] = 8'h7E;
        font_rows[1458] = 8'h3C;
        font_rows[1459] = 8'h30;
        font_rows[1460] = 8'h30;
        font_rows[1461] = 8'h30;
        font_rows[1462] = 8'h30;
        font_rows[1463] = 8'h30;
        font_rows[1464] = 8'h30;
        font_rows[1465] = 8'h30;
        font_rows[1466] = 8'h30;
        font_rows[1467] = 8'h30;
        font_rows[1468] = 8'h30;
        font_rows[1469] = 8'h30;
        font_rows[1470] = 8'h3C;
        font_rows[1474] = 8'h60;
        font_rows[1475] = 8'h60;
        font_rows[1476] = 8'h30;
        font_rows[1477] = 8'h30;
        font_rows[1478] = 8'h18;
        font_rows[1479] = 8'h18;
        font_rows[1480] = 8'h08;
        font_rows[1481] = 8'h0C;
        font_rows[1482] = 8'h0C;
        font_rows[1483] = 8'h06;
        font_rows[1484] = 8'h06;
        font_rows[1490] = 8'h3C;
        font_rows[1491] = 8'h0C;
        font_rows[1492] = 8'h0C;
        font_rows[1493] = 8'h0C;
        font_rows[1494] = 8'h0C;
        font_rows[1495] = 8'h0C;
        font_rows[1496] = 8'h0C;
        font_rows[1497] = 8'h0C;
        font_rows[1498] = 8'h0C;
        font_rows[1499] = 8'h0C;
        font_rows[1500] = 8'h0C;
        font_rows[1501] = 8'h0C;
        font_rows[1502] = 8'h3C;
        font_rows[1507] = 8'h18;
        font_rows[1508] = 8'h3C;
        font_rows[1509] = 8'h64;
        font_rows[1510] = 8'h46;
        font_rows[1534] = 8'hFF;
        font_rows[1537] = 8'h60;
        font_rows[1538] = 8'h30;
        font_rows[1539] = 8'h30;
        font_rows[1557] = 8'h3C;
        font_rows[1558] = 8'h46;
        font_rows[1559] = 8'h06;
        font_rows[1560] = 8'h3E;
        font_rows[1561] = 8'h66;
        font_rows[1562] = 8'h6E;
        font_rows[1563] = 8'h7E;
        font_rows[1570] = 8'h60;
        font_rows[1571] = 8'h60;
        font_rows[1572] = 8'h60;
        font_rows[1573] = 8'h7C;
        font_rows[1574] = 8'h76;
        font_rows[1575] = 8'h66;
        font_rows[1576] = 8'h66;
        font_rows[1577] = 8'h66;
        font_rows[1578] = 8'h66;
        font_rows[1579] = 8'h7C;
        font_rows[1589] = 8'h3E;
        font_rows[1590] = 8'h70;
        font_rows[1591] = 8'h60;
        font_rows[1592] = 8'h60;
        font_rows[1593] = 8'h60;
        font_rows[1594] = 8'h70;
        font_rows[1595] = 8'h3E;
        font_rows[1602] = 8'h06;
        font_rows[1603] = 8'h06;
        font_rows[1604] = 8'h06;
        font_rows[1605] = 8'h3E;
        font_rows[1606] = 8'h66;
        font_rows[1607] = 8'h66;
        font_rows[1608] = 8'hC6;
        font_rows[1609] = 8'hC6;
        font_rows[1610] = 8'h6E;
        font_rows[1611] = 8'h3E;
        font_rows[1621] = 8'h3C;
        font_rows[1622] = 8'h66;
        font_rows[1623] = 8'h66;
        font_rows[1624] = 8'h7E;
        font_rows[1625] = 8'h60;
        font_rows[1626] = 8'h60;
        font_rows[1627] = 8'h3E;
        font_rows[1634] = 8'h0E;
        font_rows[1635] = 8'h18;
        font_rows[1636] = 8'h30;
        font_rows[1637] = 8'h30;
        font_rows[1638] = 8'hFE;
        font_rows[1639] = 8'h30;
        font_rows[1640] = 8'h30;
        font_rows[1641] = 8'h30;
        font_rows[1642] = 8'h30;
        font_rows[1643] = 8'h30;
        font_rows[1653] = 8'h3E;
        font_rows[1654] = 8'h6C;
        font_rows[1655] = 8'h66;
        font_rows[1656] = 8'h6C;
        font_rows[1657] = 8'h7C;
        font_rows[1658] = 8'h60;
        font_rows[1659] = 8'h7E;
        font_rows[1660] = 8'h66;
        font_rows[1661] = 8'hE6;
        font_rows[1662] = 8'h7C;
        font_rows[1666] = 8'h60;
        font_rows[1667] = 8'h60;
        font_rows[1668] = 8'h60;
        font_rows[1669] = 8'h7C;
        font_rows[1670] = 8'h66;
        font_rows[1671] = 8'h66;
        font_rows[1672] = 8'h66;
        font_rows[1673] = 8'h66;
        font_rows[1674] = 8'h66;
        font_rows[1675] = 8'h66;
        font_rows[1682] = 8'h18;
        font_rows[1683] = 8'h18;
        font_rows[1685] = 8'h78;
        font_rows[1686] = 8'h18;
        font_rows[1687] = 8'h18;
        font_rows[1688] = 8'h18;
        font_rows[1689] = 8'h18;
        font_rows[1690] = 8'h18;
        font_rows[1691] = 8'h7E;
        font_rows[1698] = 8'h0C;
        font_rows[1699] = 8'h0C;
        font_rows[1701] = 8'h7C;
        font_rows[1702] = 8'h0C;
        font_rows[1703] = 8'h0C;
        font_rows[1704] = 8'h0C;
        font_rows[1705] = 8'h0C;
        font_rows[1706] = 8'h0C;
        font_rows[1707] = 8'h0C;
        font_rows[1708] = 8'h0C;
        font_rows[1709] = 8'h4C;
        font_rows[1710] = 8'h78;
        font_rows[1714] = 8'h60;
        font_rows[1715] = 8'h60;
        font_rows[1716] = 8'h60;
        font_rows[1717] = 8'h66;
        font_rows[1718] = 8'h6C;
        font_rows[1719] = 8'h78;
        font_rows[1720] = 8'h78;
        font_rows[1721] = 8'h7C;
        font_rows[1722] = 8'h6C;
        font_rows[1723] = 8'h66;
        font_rows[1730] = 8'h78;
        font_rows[1731] = 8'h18;
        font_rows[1732] = 8'h18;
        font_rows[1733] = 8'h18;
        font_rows[1734] = 8'h18;
        font_rows[1735] = 8'h18;
        font_rows[1736] = 8'h18;
        font_rows[1737] = 8'h18;
        font_rows[1738] = 8'h18;
        font_rows[1739] = 8'h7E;
        font_rows[1749] = 8'hFE;
        font_rows[1750] = 8'hDA;
        font_rows[1751] = 8'hDA;
        font_rows[1752] = 8'hDA;
        font_rows[1753] = 8'hDA;
        font_rows[1754] = 8'hDA;
        font_rows[1755] = 8'hDA;
        font_rows[1765] = 8'h7C;
        font_rows[1766] = 8'h66;
        font_rows[1767] = 8'h66;
        font_rows[1768] = 8'h66;
        font_rows[1769] = 8'h66;
        font_rows[1770] = 8'h66;
        font_rows[1771] = 8'h66;
        font_rows[1781] = 8'h3C;
        font_rows[1782] = 8'h66;
        font_rows[1783] = 8'h46;
        font_rows[1784] = 8'hC6;
        font_rows[1785] = 8'h46;
        font_rows[1786] = 8'h66;
        font_rows[1787] = 8'h3C;
        font_rows[1797] = 8'h7C;
        font_rows[1798] = 8'h76;
        font_rows[1799] = 8'h66;
        font_rows[1800] = 8'h66;
        font_rows[1801] = 8'h66;
        font_rows[1802] = 8'h66;
        font_rows[1803] = 8'h7C;
        font_rows[1804] = 8'h60;
        font_rows[1805] = 8'h60;
        font_rows[1806] = 8'h60;
        font_rows[1813] = 8'h3E;
        font_rows[1814] = 8'h66;
        font_rows[1815] = 8'h66;
        font_rows[1816] = 8'hC6;
        font_rows[1817] = 8'hC6;
        font_rows[1818] = 8'h6E;
        font_rows[1819] = 8'h3E;
        font_rows[1820] = 8'h06;
        font_rows[1821] = 8'h06;
        font_rows[1822] = 8'h06;
        font_rows[1829] = 8'h6C;
        font_rows[1830] = 8'h76;
        font_rows[1831] = 8'h66;
        font_rows[1832] = 8'h60;
        font_rows[1833] = 8'h60;
        font_rows[1834] = 8'h60;
        font_rows[1835] = 8'h60;
        font_rows[1845] = 8'h3C;
        font_rows[1846] = 8'h60;
        font_rows[1847] = 8'h70;
        font_rows[1848] = 8'h3C;
        font_rows[1849] = 8'h0E;
        font_rows[1850] = 8'h0E;
        font_rows[1851] = 8'h7C;
        font_rows[1859] = 8'h30;
        font_rows[1860] = 8'h30;
        font_rows[1861] = 8'hFE;
        font_rows[1862] = 8'h30;
        font_rows[1863] = 8'h30;
        font_rows[1864] = 8'h30;
        font_rows[1865] = 8'h30;
        font_rows[1866] = 8'h30;
        font_rows[1867] = 8'h1E;
        font_rows[1877] = 8'h66;
        font_rows[1878] = 8'h66;
        font_rows[1879] = 8'h66;
        font_rows[1880] = 8'h66;
        font_rows[1881] = 8'h66;
        font_rows[1882] = 8'h6E;
        font_rows[1883] = 8'h3E;
        font_rows[1893] = 8'hC6;
        font_rows[1894] = 8'h66;
        font_rows[1895] = 8'h66;
        font_rows[1896] = 8'h64;
        font_rows[1897] = 8'h3C;
        font_rows[1898] = 8'h3C;
        font_rows[1899] = 8'h18;
        font_rows[1909] = 8'hC3;
        font_rows[1910] = 8'hC3;
        font_rows[1911] = 8'hDA;
        font_rows[1912] = 8'hDA;
        font_rows[1913] = 8'h7E;
        font_rows[1914] = 8'h6E;
        font_rows[1915] = 8'h66;
        font_rows[1925] = 8'h66;
        font_rows[1926] = 8'h6C;
        font_rows[1927] = 8'h3C;
        font_rows[1928] = 8'h18;
        font_rows[1929] = 8'h3C;
        font_rows[1930] = 8'h6E;
        font_rows[1931] = 8'hE6;
        font_rows[1941] = 8'hC6;
        font_rows[1942] = 8'h66;
        font_rows[1943] = 8'h66;
        font_rows[1944] = 8'h6C;
        font_rows[1945] = 8'h3C;
        font_rows[1946] = 8'h38;
        font_rows[1947] = 8'h18;
        font_rows[1948] = 8'h10;
        font_rows[1949] = 8'h30;
        font_rows[1950] = 8'hE0;
        font_rows[1957] = 8'h7E;
        font_rows[1958] = 8'h0C;
        font_rows[1959] = 8'h18;
        font_rows[1960] = 8'h18;
        font_rows[1961] = 8'h30;
        font_rows[1962] = 8'h30;
        font_rows[1963] = 8'h7E;
        font_rows[1970] = 8'h0C;
        font_rows[1971] = 8'h18;
        font_rows[1972] = 8'h18;
        font_rows[1973] = 8'h10;
        font_rows[1974] = 8'h10;
        font_rows[1975] = 8'h30;
        font_rows[1976] = 8'h70;
        font_rows[1977] = 8'h30;
        font_rows[1978] = 8'h10;
        font_rows[1979] = 8'h10;
        font_rows[1980] = 8'h10;
        font_rows[1981] = 8'h18;
        font_rows[1982] = 8'h0C;
        font_rows[1985] = 8'h18;
        font_rows[1986] = 8'h18;
        font_rows[1987] = 8'h18;
        font_rows[1988] = 8'h18;
        font_rows[1989] = 8'h18;
        font_rows[1990] = 8'h18;
        font_rows[1991] = 8'h18;
        font_rows[1992] = 8'h18;
        font_rows[1993] = 8'h18;
        font_rows[1994] = 8'h18;
        font_rows[1995] = 8'h18;
        font_rows[1996] = 8'h18;
        font_rows[1997] = 8'h18;
        font_rows[1998] = 8'h18;
        font_rows[2002] = 8'h70;
        font_rows[2003] = 8'h18;
        font_rows[2004] = 8'h18;
        font_rows[2005] = 8'h18;
        font_rows[2006] = 8'h18;
        font_rows[2007] = 8'h18;
        font_rows[2008] = 8'h0E;
        font_rows[2009] = 8'h18;
        font_rows[2010] = 8'h18;
        font_rows[2011] = 8'h18;
        font_rows[2012] = 8'h18;
        font_rows[2013] = 8'h18;
        font_rows[2014] = 8'h70;
        font_rows[2023] = 8'h72;
        font_rows[2024] = 8'hDA;
        font_rows[2025] = 8'hCE;
    end
    always @(posedge clk) pixels <= font_rows[{char_code,row}];
endmodule
