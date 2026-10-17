`timescale 1ns / 1ps
//
// TMDS 8b/10b encoder, DVI 1.0 / HDMI 1.4 section 5.4.
//
// Transition-minimising + DC-balancing encode for one channel.
// 2-stage pipeline: data in on cycle N, 10-bit symbol out on cycle N+2.
// All three channels must use the same latency, so the control/island path
// is padded to match.
//
// Channel assignment (HDMI): ch0 = Blue + HSYNC/VSYNC, ch1 = Green, ch2 = Red.
// Only ch0 carries control data during blanking; ch1/ch2 emit CTRL_00.
//
module tmds_encoder (
    input  wire       clk,
    input  wire       rst_n,

    input  wire [7:0] din,      // pixel byte for this channel
    input  wire [1:0] ctrl,     // {c1,c0}: ch0 uses {vsync,hsync}
    input  wire       de,       // 1 = active video, 0 = blanking

    output reg  [9:0] dout
);

    // ---------------- stage 1: transition minimisation ----------------
    // n1 = number of ones in din
    // Explicitly widen every operand so the popcount is not evaluated at 1-bit width.
    wire [3:0] n1_din = {3'b0, din[0]} + {3'b0, din[1]}
                      + {3'b0, din[2]} + {3'b0, din[3]}
                      + {3'b0, din[4]} + {3'b0, din[5]}
                      + {3'b0, din[6]} + {3'b0, din[7]};

    // XNOR when there are many ones (or exactly 4 starting with 0),
    // otherwise XOR. q_m[8] records which was used.
    wire use_xnor = (n1_din > 4'd4) || ((n1_din == 4'd4) && (din[0] == 1'b0));

    wire [8:0] q_m;
    assign q_m[0] = din[0];
    assign q_m[1] = use_xnor ? ~(q_m[0] ^ din[1]) : (q_m[0] ^ din[1]);
    assign q_m[2] = use_xnor ? ~(q_m[1] ^ din[2]) : (q_m[1] ^ din[2]);
    assign q_m[3] = use_xnor ? ~(q_m[2] ^ din[3]) : (q_m[2] ^ din[3]);
    assign q_m[4] = use_xnor ? ~(q_m[3] ^ din[4]) : (q_m[3] ^ din[4]);
    assign q_m[5] = use_xnor ? ~(q_m[4] ^ din[5]) : (q_m[4] ^ din[5]);
    assign q_m[6] = use_xnor ? ~(q_m[5] ^ din[6]) : (q_m[5] ^ din[6]);
    assign q_m[7] = use_xnor ? ~(q_m[6] ^ din[7]) : (q_m[6] ^ din[7]);
    assign q_m[8] = ~use_xnor;

    reg [8:0] q_m_r;
    reg [1:0] ctrl_r;
    reg       de_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_m_r  <= 9'd0;
            ctrl_r <= 2'd0;
            de_r   <= 1'b0;
        end else begin
            q_m_r  <= q_m;
            ctrl_r <= ctrl;
            de_r   <= de;
        end
    end

    // ---------------- stage 2: DC balancing ----------------
    // ones/zeros in the 8 data bits of q_m
    wire [3:0] n1_qm = {3'b0, q_m_r[0]} + {3'b0, q_m_r[1]}
                     + {3'b0, q_m_r[2]} + {3'b0, q_m_r[3]}
                     + {3'b0, q_m_r[4]} + {3'b0, q_m_r[5]}
                     + {3'b0, q_m_r[6]} + {3'b0, q_m_r[7]};
    wire [3:0] n0_qm = 4'd8 - n1_qm;

    // running disparity, signed, range roughly -16..+16
    reg signed [5:0] cnt;

    wire balanced   = (n1_qm == n0_qm);
    wire cnt_zero   = (cnt == 6'sd0);
    // invert when the current word would push disparity further from zero
    wire invert_now = (!cnt_zero && !balanced)
                    && (((cnt > 0) && (n1_qm > n0_qm))
                     || ((cnt < 0) && (n0_qm > n1_qm)));

    // disparity contribution of the data bits, as a signed delta
    wire signed [5:0] d_excess = $signed({2'b00, n1_qm}) - $signed({2'b00, n0_qm});

    // control-period symbols (DVI 1.0 table 3-5)
    localparam [9:0] CTRL_00 = 10'b1101010100;
    localparam [9:0] CTRL_01 = 10'b0010101011;
    localparam [9:0] CTRL_10 = 10'b0101010100;
    localparam [9:0] CTRL_11 = 10'b1010101011;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= CTRL_00;
            cnt  <= 6'sd0;
        end else if (!de_r) begin
            // blanking: emit control token, reset running disparity
            case (ctrl_r)
                2'b00: dout <= CTRL_00;
                2'b01: dout <= CTRL_01;
                2'b10: dout <= CTRL_10;
                2'b11: dout <= CTRL_11;
            endcase
            cnt <= 6'sd0;
        end else if (cnt_zero || balanced) begin
            // disparity is zero, or this word is self-balancing:
            // send uninverted, encode q_m[8] in bit 9 as its complement.
            dout[9]   <= ~q_m_r[8];
            dout[8]   <=  q_m_r[8];
            dout[7:0] <=  q_m_r[8] ? q_m_r[7:0] : ~q_m_r[7:0];

            cnt <= q_m_r[8] ? (cnt + d_excess)
                            : (cnt - d_excess);
        end else if (invert_now) begin
            // inverting brings the running disparity back toward zero
            dout[9]   <= 1'b1;
            dout[8]   <= q_m_r[8];
            dout[7:0] <= ~q_m_r[7:0];

            cnt <= cnt + {4'b0, q_m_r[8], 1'b0} - d_excess;
        end else begin
            dout[9]   <= 1'b0;
            dout[8]   <= q_m_r[8];
            dout[7:0] <= q_m_r[7:0];

            cnt <= cnt - {4'b0, ~q_m_r[8], 1'b0} + d_excess;
        end
    end

endmodule
