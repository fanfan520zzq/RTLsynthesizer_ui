// EC11 quadrature decoder with synchronizers and sampled digital debounce.
// A complete four-edge Gray-code cycle produces one detent event.
module ec11_decoder #(
    parameter integer CLK_HZ = 50000000,
    parameter integer SAMPLE_HZ = 1000,
    parameter integer DEBOUNCE_SAMPLES = 3
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              ec11_a,
    input  wire              ec11_b,
    input  wire              ec11_sw_n,
    output reg               rotate_valid,
    output reg               rotate_cw,
    output reg signed [15:0] position,
    output reg               switch_valid,
    output reg               switch_pressed
);
    localparam integer SAMPLE_DIV = CLK_HZ / SAMPLE_HZ;
    localparam integer SAMPLE_W = (SAMPLE_DIV < 2) ? 1 : $clog2(SAMPLE_DIV);

    reg [SAMPLE_W-1:0] sample_count;
    wire sample_tick = (sample_count == SAMPLE_DIV - 1);

    reg [1:0] a_sync;
    reg [1:0] b_sync;
    reg [1:0] sw_sync;

    reg [DEBOUNCE_SAMPLES-1:0] a_history;
    reg [DEBOUNCE_SAMPLES-1:0] b_history;
    reg [DEBOUNCE_SAMPLES-1:0] sw_history;
    wire [DEBOUNCE_SAMPLES-1:0] a_history_next = {a_history[DEBOUNCE_SAMPLES-2:0], a_sync[1]};
    wire [DEBOUNCE_SAMPLES-1:0] b_history_next = {b_history[DEBOUNCE_SAMPLES-2:0], b_sync[1]};
    wire [DEBOUNCE_SAMPLES-1:0] sw_history_next = {sw_history[DEBOUNCE_SAMPLES-2:0], sw_sync[1]};

    reg a_db;
    reg b_db;
    reg sw_db;
    reg [1:0] previous_ab;
    reg signed [3:0] quarter_count;
    reg signed [2:0] transition_delta;

    always @* begin
        case ({previous_ab, a_db, b_db})
            4'b0001, 4'b0111, 4'b1110, 4'b1000: transition_delta = 3'sd1;
            4'b0010, 4'b1011, 4'b1101, 4'b0100: transition_delta = -3'sd1;
            default: transition_delta = 3'sd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_count <= 0;
            a_sync <= 2'b11;
            b_sync <= 2'b11;
            sw_sync <= 2'b11;
            a_history <= {DEBOUNCE_SAMPLES{1'b1}};
            b_history <= {DEBOUNCE_SAMPLES{1'b1}};
            sw_history <= {DEBOUNCE_SAMPLES{1'b1}};
            a_db <= 1'b1;
            b_db <= 1'b1;
            sw_db <= 1'b1;
            previous_ab <= 2'b11;
            quarter_count <= 0;
            rotate_valid <= 1'b0;
            rotate_cw <= 1'b0;
            position <= 0;
            switch_valid <= 1'b0;
            switch_pressed <= 1'b0;
        end else begin
            a_sync <= {a_sync[0], ec11_a};
            b_sync <= {b_sync[0], ec11_b};
            sw_sync <= {sw_sync[0], ec11_sw_n};
            rotate_valid <= 1'b0;
            switch_valid <= 1'b0;

            if (sample_tick) begin
                sample_count <= 0;
                a_history <= a_history_next;
                b_history <= b_history_next;
                sw_history <= sw_history_next;

                if (&a_history_next)
                    a_db <= 1'b1;
                else if (~|a_history_next)
                    a_db <= 1'b0;

                if (&b_history_next)
                    b_db <= 1'b1;
                else if (~|b_history_next)
                    b_db <= 1'b0;

                if (&sw_history_next) begin
                    if (!sw_db) begin
                        sw_db <= 1'b1;
                        switch_valid <= 1'b1;
                        switch_pressed <= 1'b0;
                    end
                end else if (~|sw_history_next) begin
                    if (sw_db) begin
                        sw_db <= 1'b0;
                        switch_valid <= 1'b1;
                        switch_pressed <= 1'b1;
                    end
                end
            end else begin
                sample_count <= sample_count + 1'b1;
            end

            if ({a_db, b_db} != previous_ab) begin
                previous_ab <= {a_db, b_db};
                if (transition_delta == 3'sd1) begin
                    if (quarter_count == 4'sd3) begin
                        quarter_count <= 0;
                        rotate_valid <= 1'b1;
                        rotate_cw <= 1'b1;
                        if (position != 16'sh7fff)
                            position <= position + 16'sd1;
                    end else begin
                        quarter_count <= quarter_count + 4'sd1;
                    end
                end else if (transition_delta == -3'sd1) begin
                    if (quarter_count[3:0] == 4'hd) begin
                        quarter_count <= 0;
                        rotate_valid <= 1'b1;
                        rotate_cw <= 1'b0;
                        if (position[15:0] != 16'h8000)
                            position <= position - 16'sd1;
                    end else begin
                        quarter_count <= quarter_count - 4'sd1;
                    end
                end else begin
                    quarter_count <= 0;
                end
            end
        end
    end
endmodule
