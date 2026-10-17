`timescale 1ns / 1ps
// Standard 640x480 VGA/DVI raster timing.
//
// Totals are 800 x 525 and the expected pixel clock is 25.2 MHz.  HSYNC and
// VSYNC are active low, as required by the 640x480@60 timing convention.
// Coordinates and timing signals are registered together; consumers that add
// one RGB pipeline stage should delay DE/HSYNC/VSYNC by the same one cycle.
module video_timing_640x480 (
    input  wire       clk,
    input  wire       rst_n,
    output reg [9:0]  x,
    output reg [9:0]  y,
    output reg        de,
    output reg        hsync,
    output reg        vsync,
    output reg        frame_start
);
    localparam integer H_ACTIVE = 640;
    localparam integer H_FP     = 16;
    localparam integer H_SYNC   = 96;
    localparam integer H_BP     = 48;
    localparam integer H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;

    localparam integer V_ACTIVE = 480;
    localparam integer V_FP     = 10;
    localparam integer V_SYNC   = 2;
    localparam integer V_BP     = 33;
    localparam integer V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;

    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count     <= 10'd0;
            v_count     <= 10'd0;
            x           <= 10'd0;
            y           <= 10'd0;
            de          <= 1'b0;
            hsync       <= 1'b1;
            vsync       <= 1'b1;
            frame_start <= 1'b0;
        end else begin
            frame_start <= 1'b0;

            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1) begin
                    v_count     <= 10'd0;
                    frame_start <= 1'b1;
                end else begin
                    v_count <= v_count + 10'd1;
                end
            end else begin
                h_count <= h_count + 10'd1;
            end

            if ((h_count < H_ACTIVE) && (v_count < V_ACTIVE)) begin
                x  <= h_count;
                y  <= v_count;
                de <= 1'b1;
            end else begin
                x  <= 10'd0;
                y  <= 10'd0;
                de <= 1'b0;
            end

            // VGA sync pulses are active low.
            if ((h_count >= H_ACTIVE + H_FP) &&
                (h_count <  H_ACTIVE + H_FP + H_SYNC))
                hsync <= 1'b0;
            else
                hsync <= 1'b1;

            if ((v_count >= V_ACTIVE + V_FP) &&
                (v_count <  V_ACTIVE + V_FP + V_SYNC))
                vsync <= 1'b0;
            else
                vsync <= 1'b1;
        end
    end
endmodule
