// Standalone 50 MHz UART register loopback; no PLL/audio/SD dependencies.
module top_pcui_lp #(
    parameter integer CLK_HZ = 50000000,
    parameter integer BAUD = 115200,
    parameter integer TIMEOUT_CYCLES = CLK_HZ / 50
) (
    input wire clk,
    input wire rst,
    input wire uart_rx,
    output wire uart_tx,
    output wire led
);
    // Reset asserts asynchronously and releases through two flip-flops.
    reg [1:0] reset_pipe;
    always @(posedge clk or negedge rst)
        if (!rst) reset_pipe <= 0;
        else reset_pipe <= {reset_pipe[0],1'b1};
    wire rst_n = reset_pipe[1];
    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_error;
    wire [7:0] tx_data;
    wire tx_valid;
    wire tx_ready;
    wire button_state;
    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx_pin(uart_rx),
        .byte_data(rx_data),
        .byte_valid(rx_valid),
        .framing_error(rx_error)
    );
    pcui_protocol #(.TIMEOUT_CYCLES(TIMEOUT_CYCLES)) u_protocol (
        .clk(clk),
        .rst_n(rst_n),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_error(rx_error),
        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),
        .button_state(button_state)
    );
    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),
        .tx_pin(uart_tx)
    );
    assign led = ~button_state;
endmodule
