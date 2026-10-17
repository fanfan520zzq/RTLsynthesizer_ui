`timescale 1ns / 1ps
//
// HDMI / DVI transmitter: 3 TMDS data channels + clock channel.
//
// This is DVI-mode video only -- no audio, no AVI infoframe. Every display
// I am aware of accepts that over an HDMI connector, and it keeps the design
// small. Adding data islands would mean a packet scheduler and CTS/N clock
// regeneration, which is a meaningful chunk of extra logic.
//
// Channel map (HDMI 1.4 table 5-1):
//   ch0 = Blue,  carries {vsync, hsync} during blanking
//   ch1 = Green, control 00 during blanking
//   ch2 = Red,   control 00 during blanking
//
module hdmi_tx (
    input  wire       pclk,      // pixel clock
    input  wire       fclk,      // 5 x pclk
    input  wire       rst_n,

    input  wire [7:0] red,
    input  wire [7:0] green,
    input  wire [7:0] blue,
    input  wire       de,
    input  wire       hsync,
    input  wire       vsync,

    // ELVDS differential pairs
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n
);

    wire rst = ~rst_n;

    // ---------------- encode ----------------
    wire [9:0] sym_b, sym_g, sym_r;

    tmds_encoder enc_b (
        .clk(pclk), .rst_n(rst_n),
        .din(blue),  .ctrl({vsync, hsync}), .de(de),
        .dout(sym_b)
    );

    tmds_encoder enc_g (
        .clk(pclk), .rst_n(rst_n),
        .din(green), .ctrl(2'b00), .de(de),
        .dout(sym_g)
    );

    tmds_encoder enc_r (
        .clk(pclk), .rst_n(rst_n),
        .din(red),   .ctrl(2'b00), .de(de),
        .dout(sym_r)
    );

    // ---------------- serialize ----------------
    wire ser_b, ser_g, ser_r;

    tmds_serializer ser_ch0 (
        .pclk(pclk), .fclk(fclk), .rst(rst),
        .symbol(sym_b), .sdata(ser_b)
    );

    tmds_serializer ser_ch1 (
        .pclk(pclk), .fclk(fclk), .rst(rst),
        .symbol(sym_g), .sdata(ser_g)
    );

    tmds_serializer ser_ch2 (
        .pclk(pclk), .fclk(fclk), .rst(rst),
        .symbol(sym_r), .sdata(ser_r)
    );

    // TMDS clock channel is just the pixel clock as a 5-low/5-high pattern
    wire ser_clk;

    tmds_serializer ser_chc (
        .pclk(pclk), .fclk(fclk), .rst(rst),
        .symbol(10'b1111100000), .sdata(ser_clk)
    );

    // ---------------- differential output buffers ----------------
`ifdef SIMULATION

    assign tmds_d_p   = {ser_r, ser_g, ser_b};
    assign tmds_d_n   = ~{ser_r, ser_g, ser_b};
    assign tmds_clk_p = ser_clk;
    assign tmds_clk_n = ~ser_clk;

`else

    ELVDS_OBUF obuf_b   (.I(ser_b),   .O(tmds_d_p[0]), .OB(tmds_d_n[0]));
    ELVDS_OBUF obuf_g   (.I(ser_g),   .O(tmds_d_p[1]), .OB(tmds_d_n[1]));
    ELVDS_OBUF obuf_r   (.I(ser_r),   .O(tmds_d_p[2]), .OB(tmds_d_n[2]));
    ELVDS_OBUF obuf_clk (.I(ser_clk), .O(tmds_clk_p),  .OB(tmds_clk_n));

`endif

endmodule
