// PC UI loopback register bank. One request outstanding; CRC-8/ATM.
// Byte input/output boundary can be reused with the Dimension UART frontend.
module pcui_protocol #(
    parameter integer TIMEOUT_CYCLES = 1000000
) (
    input wire clk,
    input wire rst_n,
    input wire [7:0] rx_data,
    input wire rx_valid,
    input wire rx_error,
    output wire [7:0] tx_data,
    output wire tx_valid,
    input wire tx_ready,
    output reg button_state
);
    reg [15:0] values [0:7]; // 8 independently readable 16-bit values.
    reg [3:0] rx_pos;
    reg [55:0] body;
    reg [7:0] crc;
    reg [31:0] age;
    reg [87:0] reply;
    reg [3:0] tx_pos;
    reg sending;
    reg [7:0] status;
    reg [15:0] result_value;
    reg next_button;
    reg [7:0] reply_crc;
    integer i;
    function [7:0] crc_byte;
        input [7:0] old_crc;
        input [7:0] data;
        reg [7:0] c;
        integer k;
        begin
            c = old_crc ^ data;
            for (k=0; k<8; k=k+1)
                c = c[7] ? (c << 1) ^ 8'h07 : c << 1;
            crc_byte = c;
        end
    endfunction
    wire [7:0] version = body[7:0];
    wire [15:0] sequence_id = body[23:8];
    wire [7:0] opcode = body[31:24];
    wire [7:0] index = body[39:32];
    wire [15:0] requested = body[55:40];
    assign tx_data = reply[tx_pos*8 +: 8];
    assign tx_valid = sending;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_pos <= 0; body <= 0; crc <= 0; age <= 0;
            reply <= 0; tx_pos <= 0; sending <= 0; button_state <= 0;
            for (i=0; i<8; i=i+1) values[i] <= 0;
        end else begin
            if (sending && tx_ready) begin
                if (tx_pos == 10) begin sending <= 0; tx_pos <= 0; end
                else tx_pos <= tx_pos + 1'b1;
            end
            if (rx_pos != 0) begin
                if (age >= TIMEOUT_CYCLES-1) begin rx_pos <= 0; age <= 0; end
                else age <= age + 1'b1;
            end
            if (rx_error) begin rx_pos <= 0; age <= 0; end
            else if (rx_valid) begin
                age <= 0;
                if (rx_pos == 0) begin
                    if (rx_data == 8'ha5) rx_pos <= 1;
                end else if (rx_pos == 1) begin
                    if (rx_data == 8'h5a) begin rx_pos <= 2; crc <= 0; end
                    else rx_pos <= rx_data == 8'ha5 ? 1 : 0;
                end else if (rx_pos < 9) begin
                    body[(rx_pos-2)*8 +: 8] <= rx_data;
                    crc <= crc_byte(crc, rx_data);
                    rx_pos <= rx_pos + 1'b1;
                end else begin
                    rx_pos <= 0;
                    // PC waits for response; overlapping requests are discarded.
                    if (!sending) begin
                        status = 0; result_value = 0; next_button = button_state;
                        if (crc != rx_data) status = 1;
                        else if (version != 1) status = 2;
                        else if (opcode == 1 || opcode == 2) begin
                            if (index >= 8) status = 3;
                            else if (opcode == 1) begin
                                values[index[2:0]] <= requested;
                                result_value = requested;
                            end else result_value = values[index[2:0]];
                        end else if ((opcode == 3 || opcode == 4) && index == 0 && requested == 0) begin
                            if (opcode == 3) begin
                                next_button = ~button_state;
                                button_state <= next_button;
                            end
                            result_value = values[0];
                        end else status = 4;
                        reply[15:0] = 16'ha55a;
                        reply[23:16] = 1;
                        reply[39:24] = sequence_id;
                        reply[47:40] = status;
                        reply[55:48] = index;
                        reply[71:56] = result_value;
                        reply[79:72] = {7'd0,next_button};
                        reply_crc = 0;
                        for (i=2; i<10; i=i+1) reply_crc = crc_byte(reply_crc, reply[i*8 +: 8]);
                        reply[87:80] = reply_crc;
                        tx_pos <= 0; sending <= 1;
                    end
                end
            end
        end
    end
endmodule
