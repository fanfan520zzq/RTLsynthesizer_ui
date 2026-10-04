// Fractional-timing 8N1 UART receiver.  The start bit is re-checked at its
// centre; byte_valid and framing_error are one-clock pulses.
module uart_rx #(
    parameter integer CLK_HZ = 24000000,
    parameter integer BAUD = 115200
) (
    input wire clk,
    input wire rst_n,
    input wire rx_pin,
    output reg [7:0] byte_data,
    output reg byte_valid,
    output reg framing_error
);
    localparam integer PHASE_W = $clog2(CLK_HZ + BAUD + 1);
    localparam [PHASE_W:0] CLK_HZ_CONST = CLK_HZ;
    reg [1:0] rx_sync;
    reg rx_d;
    reg busy;
    reg [3:0] bit_index;
    reg [7:0] shift;
    reg [PHASE_W-1:0] phase;
    wire start_edge = rx_d && !rx_sync[1];
    wire [PHASE_W:0] phase_advanced = {1'b0,phase} + BAUD;
    wire [PHASE_W:0] phase_remainder = phase_advanced - CLK_HZ_CONST;
    wire sample_tick = phase_advanced >= CLK_HZ_CONST;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rx_sync<=2'b11; rx_d<=1'b1; busy<=1'b0; bit_index<=0;
            shift<=0; phase<=0; byte_data<=0; byte_valid<=1'b0;
            framing_error<=1'b0;
        end else begin
            rx_sync <= {rx_sync[0],rx_pin};
            rx_d <= rx_sync[1];
            byte_valid <= 1'b0;
            framing_error <= 1'b0;
            if(!busy) begin
                if(start_edge) begin
                    busy <= 1'b1;
                    bit_index <= 0;
                    phase <= CLK_HZ/2;
                end
            end else if(sample_tick) begin
                phase <= phase_remainder[PHASE_W-1:0];
                if(bit_index==0) begin
                    if(rx_sync[1]) begin
                        busy <= 1'b0;
                        framing_error <= 1'b1;
                    end else bit_index <= 1;
                end else if(bit_index<=8) begin
                    shift[bit_index-1] <= rx_sync[1];
                    bit_index <= bit_index + 1'b1;
                end else begin
                    busy <= 1'b0;
                    if(rx_sync[1]) begin
                        byte_data <= shift;
                        byte_valid <= 1'b1;
                    end else framing_error <= 1'b1;
                end
            end else phase <= phase_advanced[PHASE_W-1:0];
        end
    end
endmodule
