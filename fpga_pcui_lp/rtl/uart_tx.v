// Ready/valid byte input; 8N1, LSB first. The fractional divider avoids
// accumulating error when 50 MHz is not an integer multiple of 115200 baud.
module uart_tx #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD = 115200
)(
    input wire clk,
    input wire rst_n,
    input wire [7:0] tx_data,
    input wire tx_valid,
    output wire tx_ready,
    output wire tx_pin
);
    localparam integer PHASE_W = $clog2(CLK_HZ + BAUD);
    reg [PHASE_W-1:0] phase;
    localparam [PHASE_W-1:0] BAUD_STEP = BAUD;
    localparam [PHASE_W-1:0] TICK_THRESHOLD = CLK_HZ - BAUD;
    wire [PHASE_W:0] advanced_phase = {1'b0, phase} + {1'b0, BAUD_STEP};
    reg [9:0] frame;
    reg [3:0] bit_index;
    reg busy;
    assign tx_ready = !busy;
    assign tx_pin = busy ? frame[0] : 1'b1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 0;
            frame <= 10'h3ff;
            bit_index <= 0;
            busy <= 1'b0;
        end else if (!busy) begin
            if (tx_valid) begin
                frame <= {1'b1, tx_data, 1'b0};
                bit_index <= 0;
                phase <= 0;
                busy <= 1'b1;
            end
        end else if (phase >= TICK_THRESHOLD) begin
            phase <= phase - TICK_THRESHOLD;
            frame <= {1'b1, frame[9:1]};
            if (bit_index == 9) busy <= 1'b0;
            else bit_index <= bit_index + 1'b1;
        end else phase <= advanced_phase[PHASE_W-1:0];
    end
endmodule
