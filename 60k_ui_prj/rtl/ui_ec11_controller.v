`timescale 1ns / 1ps
// Local UI test only: no SD, UART or synthesizer is connected here.
// All events/state live in clk_pixel; the copied EC11 decoder synchronizes pins.
module ui_ec11_controller #(
    parameter integer CLK_HZ = 33333333,
    parameter integer LONG_PRESS_MS = 800
)(
    input wire clk,
    input wire rst_n,
    input wire rotate_valid,
    input wire rotate_cw,
    input wire switch_valid,
    input wire switch_pressed,
    output reg [1:0] page,
    output reg [3:0] focus,
    output reg editing,
    output reg [7:0] rate,
    output reg [7:0] depth,
    output reg [7:0] width_value,
    output reg [7:0] mix,
    output reg [2:0] preset,
    output reg fx_enable,
    output reg [2:0] selected_item,
    output reg [7:0] last_action,
    output reg [15:0] action_count
);
    localparam integer HOLD_CYCLES = (CLK_HZ / 1000) * LONG_PRESS_MS;
    localparam integer HOLD_W = (HOLD_CYCLES < 2) ? 1 : $clog2(HOLD_CYCLES);
    reg [HOLD_W-1:0] hold_count;
    reg long_fired;
    reg [7:0] edit_original;
    wire [3:0] last_focus = (page == 1) ? 4'd15 : 4'd6;
    reg [7:0] edit_value;
    always @* begin
        case (focus)
            10: edit_value = rate;
            11: edit_value = depth;
            12: edit_value = width_value;
            default: edit_value = mix;
        endcase
    end
    wire [7:0] edit_next = rotate_cw ?
        ((edit_value == 255) ? 8'd255 : edit_value + 8'd1) :
        ((edit_value == 0) ? 8'd0 : edit_value - 8'd1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            page <= 0;
            focus <= 0;
            editing <= 0;
            rate <= 64;
            depth <= 128;
            width_value <= 128;
            mix <= 64;
            preset <= 0;
            fx_enable <= 1;
            selected_item <= 0;
            last_action <= 0;
            action_count <= 0;
            hold_count <= 0;
            long_fired <= 0;
            edit_original <= 0;
        end else begin
            // Suppress rotation while holding the switch: long-press cannot
            // accidentally navigate or edit a different value.
            if (rotate_valid && !switch_pressed) begin
                if (editing) begin
                    case (focus)
                        10: rate <= edit_next;
                        11: depth <= edit_next;
                        12: width_value <= edit_next;
                        13: mix <= edit_next;
                        default: editing <= 0;
                    endcase
                end else if (rotate_cw) begin
                    focus <= (focus == last_focus) ? 4'd0 : focus + 4'd1;
                end else begin
                    focus <= (focus == 0) ? last_focus : focus - 4'd1;
                end
            end

            if (switch_valid && switch_pressed) begin
                hold_count <= 0;
                long_fired <= 0;
            end else if (switch_pressed && !long_fired) begin
                if (hold_count == HOLD_CYCLES - 1) begin
                    long_fired <= 1;
                    // Long press cancels an uncommitted edit, then returns
                    // focus to the current page tab. It does not switch page.
                    if (editing) begin
                        case (focus)
                            10: rate <= edit_original;
                            11: depth <= edit_original;
                            12: width_value <= edit_original;
                            13: mix <= edit_original;
                        endcase
                    end
                    editing <= 0;
                    focus <= {2'b00, page};
                end else hold_count <= hold_count + 1'b1;
            end else if (switch_valid && !switch_pressed && !long_fired) begin
                // Activate on release so a long press never also clicks.
                if (focus < 3) begin
                    page <= focus[1:0];
                end else if (editing) begin
                    editing <= 0;
                    last_action <= 8'h20 + (focus - 4'd10);
                    action_count <= action_count + 1'b1;
                end else if (page == 1 && focus >= 10 && focus <= 13) begin
                    editing <= 1;
                    edit_original <= edit_value;
                end else begin
                    action_count <= action_count + 1'b1;
                    case (page)
                        0: case (focus)
                            3: last_action <= 8'h01; // SCAN request only
                            4: begin
                                selected_item <= (selected_item == 0) ? 3'd5 : selected_item - 1'b1;
                                last_action <= 8'h02;
                            end
                            5: begin
                                selected_item <= (selected_item == 5) ? 3'd0 : selected_item + 1'b1;
                                last_action <= 8'h03;
                            end
                            6: last_action <= 8'h04; // LOAD request only
                        endcase
                        1: begin
                            if (focus <= 9) begin
                                preset <= focus - 4'd3;
                                last_action <= 8'h10 + (focus - 4'd3);
                            end else begin
                                fx_enable <= (focus == 14);
                                last_action <= (focus == 14) ? 8'h30 : 8'h31;
                            end
                        end
                        2: last_action <= 8'h05 + (focus - 4'd3);
                    endcase
                end
            end
        end
    end
endmodule
