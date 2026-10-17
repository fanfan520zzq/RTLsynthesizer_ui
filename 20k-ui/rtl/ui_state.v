// Small UI state machine used by the standalone Nano 20K demo.
//
// KEY short press enters/leaves edit mode. A long press cancels an active edit
// and returns to MAIN. When idle, rotating past the last focus item advances to
// the next page and rotating backwards from the first item goes to the prior
// page.  This is intentionally independent of the renderer, so a generated
// UI.verilog scene can replace ui_renderer without changing input handling.
module ui_state (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rot_inc,
    input  wire       rot_dec,
    input  wire       short_press,
    input  wire       long_press,
    output reg [1:0]  page,
    output reg [2:0]  focus,
    output reg        editing,
    output reg [7:0]  tempo,
    output reg [7:0]  cutoff,
    output reg [7:0]  resonance,
    output reg [7:0]  drive,
    output reg [7:0]  mix,
    output reg [7:0]  main_mode,
    output reg [7:0]  fx_depth
);
    localparam PAGE_MAIN  = 2'd0;
    localparam PAGE_PATCH = 2'd1;
    localparam PAGE_FX    = 2'd2;

    reg [7:0] edit_backup;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            page      <= PAGE_MAIN;
            focus     <= 3'd0;
            editing   <= 1'b0;
            tempo     <= 8'd120;
            cutoff    <= 8'd96;
            resonance <= 8'd48;
            drive     <= 8'd24;
            mix       <= 8'd64;
            main_mode <= 8'd1;
            fx_depth  <= 8'd80;
            edit_backup <= 8'd0;
        end else begin
            if (long_press) begin
                if (editing) begin
                    case (page)
                        PAGE_MAIN: begin
                            if (focus == 3'd0) tempo <= edit_backup;
                            if (focus == 3'd1) cutoff <= edit_backup;
                            if (focus == 3'd2) main_mode <= edit_backup;
                        end
                        PAGE_PATCH: begin
                            if (focus == 3'd0) cutoff <= edit_backup;
                            if (focus == 3'd1) resonance <= edit_backup;
                            if (focus == 3'd2) drive <= edit_backup;
                        end
                        default: begin
                            if (focus == 3'd0) drive <= edit_backup;
                            if (focus == 3'd1) mix <= edit_backup;
                            if (focus == 3'd2) fx_depth <= edit_backup;
                        end
                    endcase
                end
                page    <= PAGE_MAIN;
                focus   <= 3'd0;
                editing <= 1'b0;
            end else begin
                if (short_press) begin
                    editing <= ~editing;
                    if (!editing) begin
                        case (page)
                            PAGE_MAIN: begin
                                if (focus == 3'd0) edit_backup <= tempo;
                                if (focus == 3'd1) edit_backup <= cutoff;
                                if (focus == 3'd2) edit_backup <= main_mode;
                            end
                            PAGE_PATCH: begin
                                if (focus == 3'd0) edit_backup <= cutoff;
                                if (focus == 3'd1) edit_backup <= resonance;
                                if (focus == 3'd2) edit_backup <= drive;
                            end
                            default: begin
                                if (focus == 3'd0) edit_backup <= drive;
                                if (focus == 3'd1) edit_backup <= mix;
                                if (focus == 3'd2) edit_backup <= fx_depth;
                            end
                        endcase
                    end
                end

                // A debounced key edge and an encoder edge can arrive on the
                // same clock. The key action owns that cycle so a click
                // cannot also move the focus or change the value.
                if (!short_press && (rot_inc || rot_dec)) begin
                    if (editing) begin
                        case (page)
                            PAGE_MAIN: begin
                                if (focus == 3'd0 && rot_inc && tempo < 8'd240) tempo <= tempo + 8'd1;
                                if (focus == 3'd0 && rot_dec && tempo > 8'd30)  tempo <= tempo - 8'd1;
                                if (focus == 3'd1 && rot_inc && cutoff < 8'd127) cutoff <= cutoff + 8'd1;
                                if (focus == 3'd1 && rot_dec && cutoff > 8'd1)   cutoff <= cutoff - 8'd1;
                                if (focus == 3'd2 && rot_inc && main_mode < 8'd3) main_mode <= main_mode + 8'd1;
                                if (focus == 3'd2 && rot_dec && main_mode > 8'd0) main_mode <= main_mode - 8'd1;
                            end
                            PAGE_PATCH: begin
                                if (focus == 3'd0 && rot_inc && cutoff < 8'd127) cutoff <= cutoff + 8'd1;
                                if (focus == 3'd0 && rot_dec && cutoff > 8'd1)   cutoff <= cutoff - 8'd1;
                                if (focus == 3'd1 && rot_inc && resonance < 8'd127) resonance <= resonance + 8'd1;
                                if (focus == 3'd1 && rot_dec && resonance > 8'd1)   resonance <= resonance - 8'd1;
                                if (focus == 3'd2 && rot_inc && drive < 8'd127) drive <= drive + 8'd1;
                                if (focus == 3'd2 && rot_dec && drive > 8'd1)   drive <= drive - 8'd1;
                            end
                            default: begin
                                if (focus == 3'd0 && rot_inc && drive < 8'd127) drive <= drive + 8'd1;
                                if (focus == 3'd0 && rot_dec && drive > 8'd1)   drive <= drive - 8'd1;
                                if (focus == 3'd1 && rot_inc && mix < 8'd127) mix <= mix + 8'd1;
                                if (focus == 3'd1 && rot_dec && mix > 8'd1)   mix <= mix - 8'd1;
                                if (focus == 3'd2 && rot_inc && fx_depth < 8'd127) fx_depth <= fx_depth + 8'd1;
                                if (focus == 3'd2 && rot_dec && fx_depth > 8'd0)   fx_depth <= fx_depth - 8'd1;
                            end
                        endcase
                    end else begin
                        if (rot_inc) begin
                            if (focus == 3'd2) begin
                                focus <= 3'd0;
                                if (page == PAGE_FX)
                                    page <= PAGE_MAIN;
                                else
                                    page <= page + 2'd1;
                            end else begin
                                focus <= focus + 3'd1;
                            end
                        end else if (rot_dec) begin
                            if (focus == 3'd0) begin
                                focus <= 3'd2;
                                if (page == PAGE_MAIN)
                                    page <= PAGE_FX;
                                else
                                    page <= page - 2'd1;
                            end else begin
                                focus <= focus - 3'd1;
                            end
                        end
                    end
                end
            end
        end
    end
endmodule
