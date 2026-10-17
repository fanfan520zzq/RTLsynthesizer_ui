`timescale 1ns / 1ps
// Compact 800x480 UI renderer for Tang Nano 20K.
//
// The renderer is independent of the HDMI/TMDS transmitter.  It consumes
// raster coordinates and emits RGB888 one clock later.  Delay DE/HSYNC/VSYNC
// by one clock in the top level before passing them to the TMDS encoder.
// PAGE_MAIN/PAGE_PATCH/PAGE_FX are selected by the EC11 state machine.
module ui_renderer_800x480 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [10:0] px,
    input  wire [9:0]  py,
    input  wire        frame_start,
    input  wire [1:0]  page,
    input  wire [2:0]  focus,
    input  wire        editing,
    input  wire [7:0]  tempo,
    input  wire [7:0]  cutoff,
    input  wire [7:0]  resonance,
    input  wire [7:0]  drive,
    input  wire [7:0]  mix,
    input  wire [7:0]  spec0,
    input  wire [7:0]  spec1,
    input  wire [7:0]  spec2,
    input  wire [7:0]  spec3,
    input  wire [7:0]  spec4,
    input  wire [7:0]  spec5,
    input  wire [7:0]  spec6,
    input  wire [7:0]  spec7,
    input  wire [7:0]  main_mode,
    input  wire [7:0]  fx_depth,
    output reg [7:0]   r_out,
    output reg [7:0]   g_out,
    output reg [7:0]   b_out
);
    localparam [1:0] PAGE_MAIN  = 2'd0;
    localparam [1:0] PAGE_PATCH = 2'd1;
    localparam [1:0] PAGE_FX    = 2'd2;

    localparam [23:0] C_BG      = 24'h070A10;
    localparam [23:0] C_PANEL   = 24'h101722;
    localparam [23:0] C_BORDER  = 24'h263A52;
    localparam [23:0] C_TEXT    = 24'hC7D5E8;
    localparam [23:0] C_MUTED   = 24'h71849D;
    localparam [23:0] C_CYAN    = 24'h36C5F0;
    localparam [23:0] C_GREEN   = 24'h63D6A2;
    localparam [23:0] C_ORANGE  = 24'hF3A35C;
    localparam [23:0] C_BAR     = 24'h49BCEB;

    localparam [3:0] TL_HEADER = 4'd0;
    localparam [3:0] TL_MAIN   = 4'd1;
    localparam [3:0] TL_PATCH  = 4'd2;
    localparam [3:0] TL_FX     = 4'd3;
    localparam [3:0] TL_TITLE  = 4'd4;
    localparam [3:0] TL_LABEL0 = 4'd5;
    localparam [3:0] TL_LABEL1 = 4'd6;
    localparam [3:0] TL_LABEL2 = 4'd7;
    localparam [3:0] TL_VALUE0 = 4'd8;
    localparam [3:0] TL_VALUE1 = 4'd9;
    localparam [3:0] TL_VALUE2 = 4'd10;
    localparam [3:0] TL_STATUS = 4'd11;
    localparam [3:0] TL_FOOTER = 4'd12;

    reg [7:0] wave_phase;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wave_phase <= 8'd0;
        else if (frame_start)
            wave_phase <= wave_phase + 8'd3;
    end

    function [7:0] hex_char;
        input [3:0] n;
        begin
            if (n < 4'd10) hex_char = 8'd48 + n;
            else           hex_char = 8'd55 + n;
        end
    endfunction

    // Fixed text is deliberately short to keep the renderer compact. The
    // value lines use hexadecimal, avoiding dividers and large arithmetic.
    function [7:0] line_char;
        input [3:0] line;
        input [3:0] col;
        reg [7:0] v;
        begin
            line_char = " ";
            case (line)
                TL_HEADER: begin
                    case (col)
                        0: line_char="N"; 1: line_char="A"; 2: line_char="N";
                        3: line_char="O"; 5: line_char="2"; 6: line_char="0";
                        7: line_char="K"; 9: line_char="U"; 10: line_char="I";
                        default: line_char=" ";
                    endcase
                end
                TL_MAIN: begin
                    case (col)
                        0: line_char="M"; 1: line_char="A"; 2: line_char="I";
                        3: line_char="N"; default: line_char=" ";
                    endcase
                end
                TL_PATCH: begin
                    case (col)
                        0: line_char="P"; 1: line_char="A"; 2: line_char="T";
                        3: line_char="C"; 4: line_char="H";
                        default: line_char=" ";
                    endcase
                end
                TL_FX: begin
                    if (col == 0) line_char="F";
                    else if (col == 1) line_char="X";
                end
                TL_TITLE: begin
                    if (page == PAGE_MAIN) begin
                        case (col)
                            0: line_char="M"; 1: line_char="A"; 2: line_char="I";
                            3: line_char="N"; 5: line_char="P"; 6: line_char="E";
                            7: line_char="R"; 8: line_char="F"; 9: line_char="O";
                            10: line_char="R"; 11: line_char="M"; 12: line_char="A";
                            13: line_char="N"; 14: line_char="C"; 15: line_char="E";
                            default: line_char=" ";
                        endcase
                    end else if (page == PAGE_PATCH) begin
                        case (col)
                            0: line_char="P"; 1: line_char="A"; 2: line_char="T";
                            3: line_char="C"; 4: line_char="H"; 6: line_char="E";
                            7: line_char="D"; 8: line_char="I"; 9: line_char="T";
                            default: line_char=" ";
                        endcase
                    end else begin
                        case (col)
                            0: line_char="F"; 1: line_char="X"; 3: line_char="E";
                            4: line_char="F"; 5: line_char="F"; 6: line_char="E";
                            7: line_char="C"; 8: line_char="T"; 9: line_char="S";
                            default: line_char=" ";
                        endcase
                    end
                end
                TL_LABEL0: begin
                    if (page == PAGE_MAIN) begin
                        case (col) 0:line_char="T";1:line_char="E";2:line_char="M";3:line_char="P";4:line_char="O"; default:line_char=" "; endcase
                    end else if (page == PAGE_PATCH) begin
                        case (col) 0:line_char="C";1:line_char="U";2:line_char="T";3:line_char="O";4:line_char="F";5:line_char="F"; default:line_char=" "; endcase
                    end else begin
                        case (col) 0:line_char="D";1:line_char="R";2:line_char="I";3:line_char="V";4:line_char="E"; default:line_char=" "; endcase
                    end
                end
                TL_LABEL1: begin
                    if (page == PAGE_MAIN) begin
                        case (col) 0:line_char="C";1:line_char="U";2:line_char="T";3:line_char="O";4:line_char="F";5:line_char="F"; default:line_char=" "; endcase
                    end else if (page == PAGE_PATCH) begin
                        case (col) 0:line_char="R";1:line_char="E";2:line_char="S";3:line_char="O"; default:line_char=" "; endcase
                    end else begin
                        case (col) 0:line_char="M";1:line_char="I";2:line_char="X"; default:line_char=" "; endcase
                    end
                end
                TL_LABEL2: begin
                    if (page == PAGE_MAIN) begin
                        case (col) 0:line_char="M";1:line_char="O";2:line_char="D";3:line_char="E"; default:line_char=" "; endcase
                    end else if (page == PAGE_PATCH) begin
                        case (col) 0:line_char="D";1:line_char="R";2:line_char="I";3:line_char="V";4:line_char="E"; default:line_char=" "; endcase
                    end else begin
                        case (col) 0:line_char="D";1:line_char="E";2:line_char="P";3:line_char="T";4:line_char="H"; default:line_char=" "; endcase
                    end
                end
                TL_VALUE0: begin
                    if (page == PAGE_MAIN) v=tempo; else if (page == PAGE_PATCH) v=cutoff; else v=drive;
                    if (col==0) line_char="0"; else if (col==1) line_char="X";
                    else if (col==2) line_char=hex_char(v[7:4]);
                    else if (col==3) line_char=hex_char(v[3:0]);
                end
                TL_VALUE1: begin
                    if (page == PAGE_MAIN) v=cutoff; else if (page == PAGE_PATCH) v=resonance; else v=mix;
                    if (col==0) line_char="0"; else if (col==1) line_char="X";
                    else if (col==2) line_char=hex_char(v[7:4]);
                    else if (col==3) line_char=hex_char(v[3:0]);
                end
                TL_VALUE2: begin
                    if (page == PAGE_MAIN) v=main_mode; else if (page == PAGE_PATCH) v=drive; else v=fx_depth;
                    if (col==0) line_char="0"; else if (col==1) line_char="X";
                    else if (col==2) line_char=hex_char(v[7:4]);
                    else if (col==3) line_char=hex_char(v[3:0]);
                end
                TL_STATUS: begin
                    if (editing) begin
                        case (col) 0:line_char="E";1:line_char="D";2:line_char="I";3:line_char="T"; default:line_char=" "; endcase
                    end else begin
                        case (col) 0:line_char="R";1:line_char="U";2:line_char="N"; default:line_char=" "; endcase
                    end
                end
                TL_FOOTER: begin
                    case (col)
                        0:line_char="E";1:line_char="C";2:line_char="1";3:line_char="1";
                        5:line_char="R";6:line_char="O";7:line_char="T";8:line_char="A";9:line_char="T";10:line_char="E";
                        12:line_char="K";13:line_char="E";14:line_char="Y"; default:line_char=" ";
                    endcase
                end
                default: line_char=" ";
            endcase
        end
    endfunction

    reg        text_req;
    reg [3:0]  text_line, text_col, text_row;
    reg [2:0]  text_xbit;
    reg [10:0] text_x_local;
    reg [9:0]  text_y_local;
    reg [7:0]  font_char;
    reg [23:0] text_fg;
    wire [7:0] font_bits;

    // Text geometry and font request. All coordinates are in the 800x480
    // active area. Regions do not overlap, so a priority chain is sufficient.
    always @(*) begin
        text_req=1'b0; text_line=TL_HEADER; text_col=4'd0; text_xbit=3'd0; text_x_local=11'd0; text_y_local=10'd0; text_row=4'd0; text_fg=C_TEXT;
        if ((px>=11'd24)&&(px<11'd112)&&(py>=10'd16)&&(py<10'd32)) begin text_req=1'b1;text_line=TL_HEADER;text_x_local=px-11'd24;text_y_local=py-10'd16;text_fg=C_CYAN; end
        else if ((px>=11'd220)&&(px<11'd260)&&(py>=10'd16)&&(py<10'd32)) begin text_req=1'b1;text_line=TL_MAIN;text_x_local=px-11'd220;text_y_local=py-10'd16;text_fg=(page==PAGE_MAIN)?C_CYAN:C_MUTED; end
        else if ((px>=11'd300)&&(px<11'd348)&&(py>=10'd16)&&(py<10'd32)) begin text_req=1'b1;text_line=TL_PATCH;text_x_local=px-11'd300;text_y_local=py-10'd16;text_fg=(page==PAGE_PATCH)?C_GREEN:C_MUTED; end
        else if ((px>=11'd388)&&(px<11'd404)&&(py>=10'd16)&&(py<10'd32)) begin text_req=1'b1;text_line=TL_FX;text_x_local=px-11'd388;text_y_local=py-10'd16;text_fg=(page==PAGE_FX)?C_ORANGE:C_MUTED; end
        else if ((px>=11'd48)&&(px<11'd176)&&(py>=10'd56)&&(py<10'd72)) begin text_req=1'b1;text_line=TL_TITLE;text_x_local=px-11'd48;text_y_local=py-10'd56;text_fg=C_TEXT; end
        else if ((px>=11'd80)&&(px<11'd128)&&(py>=10'd282)&&(py<10'd298)) begin text_req=1'b1;text_line=TL_LABEL0;text_x_local=px-11'd80;text_y_local=py-10'd282;text_fg=(focus==0)?C_CYAN:C_TEXT; end
        else if ((px>=11'd300)&&(px<11'd348)&&(py>=10'd282)&&(py<10'd298)) begin text_req=1'b1;text_line=TL_LABEL1;text_x_local=px-11'd300;text_y_local=py-10'd282;text_fg=(focus==1)?C_CYAN:C_TEXT; end
        else if ((px>=11'd520)&&(px<11'd568)&&(py>=10'd282)&&(py<10'd298)) begin text_req=1'b1;text_line=TL_LABEL2;text_x_local=px-11'd520;text_y_local=py-10'd282;text_fg=(focus==2)?C_CYAN:C_TEXT; end
        else if ((px>=11'd80)&&(px<11'd112)&&(py>=10'd304)&&(py<10'd320)) begin text_req=1'b1;text_line=TL_VALUE0;text_x_local=px-11'd80;text_y_local=py-10'd304;text_fg=(focus==0)?C_CYAN:C_TEXT; end
        else if ((px>=11'd300)&&(px<11'd332)&&(py>=10'd304)&&(py<10'd320)) begin text_req=1'b1;text_line=TL_VALUE1;text_x_local=px-11'd300;text_y_local=py-10'd304;text_fg=(focus==1)?C_CYAN:C_TEXT; end
        else if ((px>=11'd520)&&(px<11'd552)&&(py>=10'd304)&&(py<10'd320)) begin text_req=1'b1;text_line=TL_VALUE2;text_x_local=px-11'd520;text_y_local=py-10'd304;text_fg=(focus==2)?C_CYAN:C_TEXT; end
        else if ((px>=11'd664)&&(px<11'd704)&&(py>=10'd282)&&(py<10'd298)) begin text_req=1'b1;text_line=TL_STATUS;text_x_local=px-11'd664;text_y_local=py-10'd282;text_fg=editing?C_ORANGE:C_GREEN; end
        else if ((px>=11'd24)&&(px<11'd144)&&(py>=10'd448)&&(py<10'd464)) begin text_req=1'b1;text_line=TL_FOOTER;text_x_local=px-11'd24;text_y_local=py-10'd448;text_fg=C_MUTED; end
        text_col=text_x_local[6:3];
        text_xbit=text_x_local[2:0];
        text_row=text_y_local[3:0];
        font_char=line_char(text_line,text_col);
    end

    font_rom font (.clk(clk),.char_code(font_char),.row(text_row),.bits(font_bits));

    reg [10:0] px_d;
    reg [9:0]  py_d;
    reg        text_req_d;
    reg [3:0]  text_col_d;
    reg [2:0]  text_xbit_d;
    reg [23:0] text_fg_d;
    reg [23:0] base_rgb;
    reg [7:0]  tri_phase, tri_y, bar_h, wave_y;

    always @(*) begin
        base_rgb=C_BG; tri_phase=8'd0; tri_y=8'd0; bar_h=8'd0; wave_y=8'd0;
        if ((px_d<800)&&(py_d<48)) base_rgb=24'h0D1420;
        if ((px_d>=24)&&(px_d<776)&&(py_d>=48)&&(py_d<438)) base_rgb=C_PANEL;
        if ((px_d>=24)&&(px_d<776)&&((py_d==48)||(py_d==49)||(py_d==268)||(py_d==269)||(py_d==270)||(py_d==271)||(py_d==436)||(py_d==437))) base_rgb=C_BORDER;
        if ((py_d>=48)&&(py_d<438)&&((px_d==24)||(px_d==25)||(px_d==774)||(px_d==775))) base_rgb=C_BORDER;

        // 8 spectrum bars, each 80 pixels wide plus 10-pixel gap.
        if ((px_d>=40)&&(px_d<760)&&(py_d>=86)&&(py_d<250)) begin
            if      (px_d<130) bar_h={1'b0,spec0[7:1]};
            else if (px_d<220) bar_h={1'b0,spec1[7:1]};
            else if (px_d<310) bar_h={1'b0,spec2[7:1]};
            else if (px_d<400) bar_h={1'b0,spec3[7:1]};
            else if (px_d<490) bar_h={1'b0,spec4[7:1]};
            else if (px_d<580) bar_h={1'b0,spec5[7:1]};
            else if (px_d<670) bar_h={1'b0,spec6[7:1]};
            else bar_h={1'b0,spec7[7:1]};
            if ((10'd250-py_d)<=bar_h) base_rgb=C_BAR;
        end

        // Dynamic triangle waveform, advanced once per frame.
        if ((px_d>=40)&&(px_d<760)&&(py_d>=330)&&(py_d<420)) begin
            // The waveform panel starts at y=330. Compare in panel-local
            // coordinates; comparing py_d[7:0] directly would wrap 330..419
            // to 74..163 and miss the 0..63 triangle range entirely.
            wave_y = py_d[7:0] - 8'd74;
            tri_phase=px_d[7:0]+wave_phase;
            if (tri_phase[7]) tri_y=8'd255-{tri_phase[6:0],1'b0};
            else tri_y={tri_phase[6:0],1'b0};
            if ((wave_y >= (tri_y>>2)) && (wave_y <= (tri_y>>2)+2)) base_rgb=C_GREEN;
        end

        if ((focus==0)&&(px_d>=72)&&(px_d<144)&&(py_d>=276)&&(py_d<326)&&((px_d==72)||(px_d==143)||(py_d==276)||(py_d==325))) base_rgb=editing?C_ORANGE:C_CYAN;
        if ((focus==1)&&(px_d>=292)&&(px_d<364)&&(py_d>=276)&&(py_d<326)&&((px_d==292)||(px_d==363)||(py_d==276)||(py_d==325))) base_rgb=editing?C_ORANGE:C_CYAN;
        if ((focus==2)&&(px_d>=512)&&(px_d<584)&&(py_d>=276)&&(py_d<326)&&((px_d==512)||(px_d==583)||(py_d==276)||(py_d==325))) base_rgb=editing?C_ORANGE:C_CYAN;
    end

    // At edge N font_rom updates bits for request N; this block consumes the
    // metadata and bits requested at N-1, hence the one-cycle RGB latency.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            px_d<=0; py_d<=0; text_req_d<=0; text_col_d<=0; text_xbit_d<=0; text_fg_d<=C_TEXT;
            r_out<=0; g_out<=0; b_out<=0;
        end else begin
            px_d<=px; py_d<=py; text_req_d<=text_req; text_col_d<=text_col; text_xbit_d<=text_xbit; text_fg_d<=text_fg;
            if (text_req_d && font_bits[7-text_xbit_d]) begin
                r_out<=text_fg_d[23:16]; g_out<=text_fg_d[15:8]; b_out<=text_fg_d[7:0];
            end else begin
                r_out<=base_rgb[23:16]; g_out<=base_rgb[15:8]; b_out<=base_rgb[7:0];
            end
        end
    end
endmodule
