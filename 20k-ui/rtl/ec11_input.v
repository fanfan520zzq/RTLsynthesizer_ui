// Debounced EC11 quadrature decoder.
//
// The module expects the encoder board to be powered from 3.3 V.  If the
// board is powered from 5 V, level-shift A/B/KEY before they reach the FPGA.
// KEY is active low (the usual push-pull EC11 module wiring).
module ec11_input #(
    parameter integer DEBOUNCE_CYCLES  = 500000,   // about 15 ms at 33 MHz
    parameter integer LONG_PRESS_CYCLES = 33000000  // about 1 second at 33 MHz
) (
    input  wire clk,
    input  wire rst_n,
    input  wire enc_a,
    input  wire enc_b,
    input  wire key_n,
    output reg  rot_inc,
    output reg  rot_dec,
    output reg  short_press,
    output reg  long_press,
    output reg  key_down
);
    // Two-flop synchronizers keep asynchronous panel signals out of the
    // state machine.  The attributes are understood by Gowin tools and are
    // harmless in other Verilog tools.
    (* syn_preserve = 1 *) reg a_meta, a_sync;
    (* syn_preserve = 1 *) reg b_meta, b_sync;
    (* syn_preserve = 1 *) reg k_meta, k_sync;

    reg [1:0] ab_prev;
    reg signed [3:0] quarter_acc;

    reg [31:0] db_count;
    reg        key_sampled;
    reg [31:0] press_count;
    reg        long_sent;

    wire [1:0] ab_now = {a_sync, b_sync};

    // +1 is one direction and -1 is the other.  Swap A/B at the connector
    // (or swap these cases) if the desired clockwise direction is reversed.
    function signed [1:0] quad_delta;
        input [1:0] old_ab;
        input [1:0] new_ab;
        begin
            case ({old_ab, new_ab})
                4'b0001, 4'b0111, 4'b1110, 4'b1000: quad_delta =  2'sd1;
                4'b0010, 4'b1011, 4'b1101, 4'b0100: quad_delta = -2'sd1;
                default:                               quad_delta =  2'sd0;
            endcase
        end
    endfunction

    wire signed [1:0] q_delta = quad_delta(ab_prev, ab_now);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_meta      <= 1'b0;
            a_sync      <= 1'b0;
            b_meta      <= 1'b0;
            b_sync      <= 1'b0;
            k_meta      <= 1'b1;
            k_sync      <= 1'b1;
            ab_prev     <= 2'b00;
            quarter_acc <= 4'sd0;
            db_count    <= 32'd0;
            key_sampled <= 1'b1;
            press_count <= 32'd0;
            long_sent   <= 1'b0;
            key_down    <= 1'b0;
            rot_inc     <= 1'b0;
            rot_dec     <= 1'b0;
            short_press <= 1'b0;
            long_press  <= 1'b0;
        end else begin
            a_meta <= enc_a;
            a_sync <= a_meta;
            b_meta <= enc_b;
            b_sync <= b_meta;
            k_meta <= key_n;
            k_sync <= k_meta;

            rot_inc     <= 1'b0;
            rot_dec     <= 1'b0;
            short_press <= 1'b0;
            long_press  <= 1'b0;

            // Quadrature transition accumulator.  A complete detent is four
            // legal Gray-code transitions; illegal/bouncy jumps contribute 0.
            if (ab_now != ab_prev) begin
                ab_prev <= ab_now;
                if (q_delta == 2'sd1) begin
                    if (quarter_acc == 4'sd3) begin
                        rot_inc    <= 1'b1;
                        quarter_acc <= 4'sd0;
                    end else begin
                        quarter_acc <= quarter_acc + 4'sd1;
                    end
                end else if (q_delta == -2'sd1) begin
                    if (quarter_acc == -4'sd3) begin
                        rot_dec    <= 1'b1;
                        quarter_acc <= 4'sd0;
                    end else begin
                        quarter_acc <= quarter_acc - 4'sd1;
                    end
                end
            end

            // Key debounce.  key_sampled is the debounced electrical level;
            // key_down is a convenient active-high state for the UI.
            if (k_sync != key_sampled) begin
                if (db_count >= DEBOUNCE_CYCLES-1) begin
                    db_count    <= 32'd0;
                    key_sampled <= k_sync;
                    if (!k_sync) begin
                        key_down    <= 1'b1;
                        press_count <= 32'd0;
                        long_sent   <= 1'b0;
                    end else begin
                        key_down <= 1'b0;
                        if (!long_sent && press_count < LONG_PRESS_CYCLES)
                            short_press <= 1'b1;
                    end
                end else begin
                    db_count <= db_count + 32'd1;
                end
            end else begin
                db_count <= 32'd0;
            end

            if (!key_sampled && press_count < LONG_PRESS_CYCLES) begin
                press_count <= press_count + 32'd1;
                if (press_count == LONG_PRESS_CYCLES-1) begin
                    long_press <= 1'b1;
                    long_sent  <= 1'b1;
                end
            end
        end
    end
endmodule
