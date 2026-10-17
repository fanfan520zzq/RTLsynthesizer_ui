`timescale 1ns / 1ps
//
// 10:1 serializer for one TMDS channel.
//
// Synthesis path uses Gowin's OSER10 hard primitive (DDR, 5x pixel clock).
// Simulation path uses a behavioural shift register so the testbench can run
// without the vendor library -- define SIMULATION to select it.
//
// TMDS transmits LSB first, so symbol[0] must leave the pin first.
//
// Clocking: fclk = 5 x pclk. OSER10 internally does DDR, giving 10 bits per
// pixel period. Both clocks must come from the same PLL with a known phase
// relationship; feed fclk from CLKOUT and pclk from CLKOUTD (/5).
//
module tmds_serializer (
    input  wire       pclk,     // pixel clock
    input  wire       fclk,     // 5 x pclk
    input  wire       rst,      // active high
    input  wire [9:0] symbol,
    output wire       sdata
);

`ifdef SIMULATION

    // ---- behavioural model: shift out on fclk edges, DDR-style ----
    reg [9:0] shreg;
    reg [3:0] phase;

    always @(posedge fclk or posedge rst) begin
        if (rst) begin
            shreg <= 10'd0;
            phase <= 4'd0;
        end else if (phase >= 4'd8) begin
            shreg <= symbol;          // reload at end of the 5-fclk window
            phase <= 4'd0;
        end else begin
            shreg <= {2'b00, shreg[9:2]};
            phase <= phase + 4'd2;
        end
    end

    assign sdata = shreg[0];

`else

    OSER10 oser_inst (
        .Q      (sdata),
        .D0     (symbol[0]),   // shifted out first
        .D1     (symbol[1]),
        .D2     (symbol[2]),
        .D3     (symbol[3]),
        .D4     (symbol[4]),
        .D5     (symbol[5]),
        .D6     (symbol[6]),
        .D7     (symbol[7]),
        .D8     (symbol[8]),
        .D9     (symbol[9]),
        .PCLK   (pclk),
        .FCLK   (fclk),
        .RESET  (rst)
    );

    defparam oser_inst.GSREN = "false";
    defparam oser_inst.LSREN = "true";

`endif

endmodule
