// Nano 20K 800x480 HDMI clock template.
//
// The GitHub UI timing is 1056 x 525 and nominally 33.333 MHz pixel clock.
// With a 27 MHz crystal, the integer GW2AR rPLL settings below generate
// 166.5 MHz serial clock (27 * 37 / 6), then CLKDIV /5 generates the
// 33.3 MHz pixel clock. This matches the Nano 20K HDMI example.
// This is within the normal monitor tolerance, but it is deliberately not
// described as an exact 33.333 MHz solution.  Regenerate/check this IP in
// Gowin IP Core Generator for the installed tool version before hardware use.
//
// rPLL parameter convention on GW2AR is N = *_SEL + 1 for IDIV/FBDIV;
// ODIV_SEL is the VCO output divider.  ODIV=4 puts the VCO near 666 MHz,
// inside the usual GW2AR VCO range.  CLKDIV("5") is the same dedicated
// divider arrangement used by the official Nano 20K HDMI examples.
module pll_800x480_template (
    input  wire clk_in,
    output wire clk_pixel,
    output wire clk_serial,
    output wire locked
);
`ifdef SIMULATION
    // Behavioral fallback: frequency is not modeled; the relationship is
    // sufficient for RTL tests that only need a pixel/serial clock pair.
    assign clk_serial = clk_in;
    assign clk_pixel  = clk_in;
    assign locked     = 1'b1;
`else
    wire pll_lock;
    assign locked = pll_lock;

    rPLL #(
        .FCLKIN("27"),
        .IDIV_SEL(5),       // /6
        .FBDIV_SEL(36),     // x37 -> 166.5 MHz
        .ODIV_SEL(4),       // VCO = 666 MHz
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
