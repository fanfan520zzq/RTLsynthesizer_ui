// Internal 48 kHz triangle-wave source for the standalone UI demo.
// This is a deterministic test source, not an audio ADC interface.
module test_wave_48k #(
    parameter integer CLK_HZ    = 33333333,
    parameter integer SAMPLE_HZ = 48000,
    parameter integer FREQ_HZ   = 440
) (
    input  wire       clk,
    input  wire       rst_n,
    output reg        sample_tick,
    output reg signed [7:0] sample,
    output reg [15:0] phase
);
    // A fractional accumulator keeps the long-term sample rate at exactly
    // SAMPLE_HZ (within the integer clock-frequency quantization).
    reg [31:0] rate_acc;
    localparam integer PHASE_INC = (FREQ_HZ * 65536) / SAMPLE_HZ;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rate_acc    <= 32'd0;
            phase       <= 16'd0;
            sample      <= 8'sd0;
            sample_tick <= 1'b0;
        end else begin
            sample_tick <= 1'b0;
            if (rate_acc + SAMPLE_HZ >= CLK_HZ) begin
                rate_acc    <= rate_acc + SAMPLE_HZ - CLK_HZ;
                phase       <= phase + PHASE_INC[15:0];
                sample_tick <= 1'b1;

                // Four linear segments make a signed, full-scale triangle.
                case (phase[15:14])
                    2'b00: sample <=  $signed({1'b0, phase[13:7]});
                    2'b01: sample <=  $signed(8'd127 - {1'b0, phase[13:7]});
                    2'b10: sample <= -$signed({1'b0, phase[13:7]});
                    default: sample <= -$signed(8'd127 - {1'b0, phase[13:7]});
                endcase
            end else begin
                rate_acc <= rate_acc + SAMPLE_HZ;
            end
        end
    end
endmodule
