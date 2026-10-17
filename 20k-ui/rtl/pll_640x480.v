`timescale 1ns / 1ps
// Gowin GW2AR clock wrapper for 640x480@60 DVI.
// 27 MHz * 28 / 6 = 126 MHz serial clock; CLKDIV /5 gives the 25.2 MHz
// pixel clock required by OSER10. This matches the Nano 20K HDMI example.
module pll_640x480 (
    input  wire clk_in,
    output wire clk_pixel,
    output wire clk_serial,
    output wire locked
);
`ifdef SIMULATION
    // The simulation path intentionally does not model PLL frequency.
    assign clk_serial = clk_in;
    assign clk_pixel  = clk_in;
    assign locked     = 1'b1;
`else
    wire pll_lock;
    assign locked = pll_lock;

    rPLL #(
        .FCLKIN("27"),
        .IDIV_SEL(5),       // /6
        .FBDIV_SEL(27),     // x28 -> 126 MHz
        .ODIV_SEL(4),       // VCO = 504 MHz
        .DEVICE("GW2AR-18C")
    ) pll_inst (
        .CLKOUT   (clk_serial),
        .CLKOUTD  (),
        .LOCK     (pll_lock),
        .CLKIN    (clk_in),
        .CLKFB    (1'b0),
        .RESET    (1'b0),
        .RESET_P  (1'b0),
        .FBDSEL   (6'b0),
        .IDSEL    (6'b0),
        .ODSEL    (6'b0),
        .PSDA     (4'b0),
        .DUTYDA   (4'b0),
        .FDLY      (4'b0),
        .CLKOUTP  (),
        .CLKOUTD3 ()
    );

    CLKDIV #(
        .DIV_MODE("5"),
        .GSREN("false")
    ) clkdiv_inst (
        .CLKOUT (clk_pixel),
        .HCLKIN (clk_serial),
        .RESETN (pll_lock),
        .CALIB  (1'b1)
    );
`endif
endmodule
