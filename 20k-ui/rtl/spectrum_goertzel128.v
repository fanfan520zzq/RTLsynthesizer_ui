// Eight-bin, 128-sample Goertzel analyser for the internal test source.
//
// It deliberately reuses one multiplier over time.  The result is an
// 8-bit visual level per bin, suitable for a small spectrum display and well
// below the Nano 20K LUT budget.  It is not an audio-quality FFT: bins are
// coarse and the magnitude is an abs(s1)+abs(s2) approximation.  Replace this
// block with a streamed FFT when a real audio path is added.
module spectrum_goertzel128 #(
    parameter integer SAMPLE_COUNT = 128
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       sample_tick,
    input  wire signed [7:0] sample_in,
    output reg [7:0] bar0,
    output reg [7:0] bar1,
    output reg [7:0] bar2,
    output reg [7:0] bar3,
    output reg [7:0] bar4,
    output reg [7:0] bar5,
    output reg [7:0] bar6,
    output reg [7:0] bar7,
    output reg       frame_valid,
    output reg       busy
);
    reg signed [7:0] sample_mem [0:SAMPLE_COUNT-1];
    reg [6:0] capture_index;
    reg [6:0] sample_index;
    reg [2:0] bin_index;
    reg [2:0] state;

    localparam ST_CAPTURE = 3'd0;
    localparam ST_INIT    = 3'd1;
    localparam ST_PROCESS = 3'd2;
    localparam ST_MAG     = 3'd3;
    localparam ST_WAIT    = 3'd4;

    reg signed [23:0] s1;
    reg signed [23:0] s2;

    // 2*cos(2*pi*k/128), represented in signed Q8.8.  The selected bins
    // cover the useful low/mid range for a 440 Hz test tone at 48 kHz.
    function signed [15:0] goertzel_coeff;
        input [2:0] b;
        begin
            case (b)
                3'd0: goertzel_coeff = 16'sd511; // k=1
                3'd1: goertzel_coeff = 16'sd509; // k=2
                3'd2: goertzel_coeff = 16'sd506; // k=3
                3'd3: goertzel_coeff = 16'sd503; // k=4
                3'd4: goertzel_coeff = 16'sd497; // k=5
                3'd5: goertzel_coeff = 16'sd490; // k=6
                3'd6: goertzel_coeff = 16'sd473; // k=8
                default: goertzel_coeff = 16'sd451; // k=10
            endcase
        end
    endfunction

    wire signed [15:0] coeff_now = goertzel_coeff(bin_index);
    // Keep the full product until after the Q8.8 shift; truncating first
    // would discard the high-order energy for a near-resonant bin.
    wire signed [39:0] coeff_product_full = coeff_now * s1;
    wire signed [31:0] coeff_scaled = coeff_product_full >>> 8;
    // A part-select is unsigned in Verilog even when its source is signed.
    // Re-declare the truncated value as signed before adding it to s1/sample.
    wire signed [23:0] coeff_scaled_24 = coeff_scaled[23:0];
    wire signed [23:0] sample_ext = {{16{sample_mem[sample_index][7]}}, sample_mem[sample_index]};
    wire signed [23:0] s0_calc = sample_ext + coeff_scaled_24 - s2;

    function [7:0] level_from_state;
        input signed [23:0] v1;
        input signed [23:0] v2;
        reg [23:0] abs1;
        reg [23:0] abs2;
        reg [24:0] total;
        begin
            if (v1 < 0) abs1 = -v1; else abs1 = v1;
            if (v2 < 0) abs2 = -v2; else abs2 = v2;
            total = abs1 + abs2;
            // The shift is an intentionally conservative visual gain.  It
            // prevents a full-scale test tone from wrapping the 8-bit bar.
            if (total[24:7] > 8'hff)
                level_from_state = 8'hff;
            else
                level_from_state = total[14:7];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            capture_index <= 7'd0;
            sample_index  <= 7'd0;
            bin_index     <= 3'd0;
            state         <= ST_CAPTURE;
            s1            <= 24'sd0;
            s2            <= 24'sd0;
            bar0          <= 8'd0;
            bar1          <= 8'd0;
            bar2          <= 8'd0;
            bar3          <= 8'd0;
            bar4          <= 8'd0;
            bar5          <= 8'd0;
            bar6          <= 8'd0;
            bar7          <= 8'd0;
            frame_valid   <= 1'b0;
            busy          <= 1'b0;
        end else begin
            frame_valid <= 1'b0;
            case (state)
                ST_CAPTURE: begin
                    busy <= 1'b0;
                    if (sample_tick) begin
                        sample_mem[capture_index] <= sample_in;
                        if (capture_index == SAMPLE_COUNT-1) begin
                            capture_index <= 7'd0;
                            bin_index     <= 3'd0;
                            sample_index  <= 7'd0;
                            busy          <= 1'b1;
                            state         <= ST_INIT;
                        end else begin
                            capture_index <= capture_index + 7'd1;
                        end
                    end
                end

                ST_INIT: begin
                    s1           <= 24'sd0;
                    s2           <= 24'sd0;
                    sample_index <= 7'd0;
                    state        <= ST_PROCESS;
                end

                ST_PROCESS: begin
                    s2 <= s1;
                    s1 <= s0_calc;
                    if (sample_index == SAMPLE_COUNT-1) begin
                        state <= ST_MAG;
                    end else begin
                        sample_index <= sample_index + 7'd1;
                    end
                end

                ST_MAG: begin
                    case (bin_index)
                        3'd0: bar0 <= level_from_state(s1, s2);
                        3'd1: bar1 <= level_from_state(s1, s2);
                        3'd2: bar2 <= level_from_state(s1, s2);
                        3'd3: bar3 <= level_from_state(s1, s2);
                        3'd4: bar4 <= level_from_state(s1, s2);
                        3'd5: bar5 <= level_from_state(s1, s2);
                        3'd6: bar6 <= level_from_state(s1, s2);
                        default: bar7 <= level_from_state(s1, s2);
                    endcase
                    if (bin_index == 3'd7) begin
                        state       <= ST_WAIT;
                        frame_valid <= 1'b1;
                    end else begin
                        bin_index <= bin_index + 3'd1;
                        state     <= ST_INIT;
                    end
                end

                default: begin // ST_WAIT
                    // The next sample tick starts a new 128-point frame.
                    // The capture RAM is not overwritten while bins are read.
                    busy  <= 1'b0;
                    state <= ST_CAPTURE;
                end
            endcase
        end
    end
endmodule
