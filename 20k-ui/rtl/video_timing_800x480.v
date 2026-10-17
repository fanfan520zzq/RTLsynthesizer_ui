// Generic 800x480 raster timing for the Nano 20K UI prototype.
//
// The pixel clock is intentionally an input.  Instantiate a board-specific
// Gowin PLL in the top level (the official Nano 20K HDMI examples do this)
// and feed the resulting clock here.  The defaults below match the
// RTLsynthesizer_ui GitHub scene: H=1056 (800+210+20+26), V=525
// (480+19+3+23), positive sync and approximately 33.333 MHz pixel clock.
module video_timing_800x480 #(
    parameter integer H_ACTIVE = 800,
    parameter integer H_FP     = 210,
    parameter integer H_SYNC   = 20,
    parameter integer H_BP     = 26,
    parameter integer V_ACTIVE = 480,
    parameter integer V_FP     = 19,
    parameter integer V_SYNC   = 3,
    parameter integer V_BP     = 23,
    parameter         HS_POL   = 1'b1,
    parameter         VS_POL   = 1'b1
) (
    input  wire        clk,
    input  wire        rst_n,
    output reg [10:0]  x,
    output reg [9:0]   y,
    output reg         de,
    output reg         hsync,
    output reg         vsync,
    output reg         frame_start
);
    localparam integer H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam integer V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;

    reg [10:0] h_count;
    reg [9:0]  v_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count    <= 11'd0;
            v_count    <= 10'd0;
            x          <= 11'd0;
            y          <= 10'd0;
            de         <= 1'b0;
            hsync      <= ~HS_POL;
            vsync      <= ~VS_POL;
            frame_start <= 1'b0;
        end else begin
            frame_start <= 1'b0;

            if (h_count == H_TOTAL-1) begin
                h_count <= 11'd0;
                if (v_count == V_TOTAL-1) begin
                    v_count    <= 10'd0;
                    frame_start <= 1'b1;
                end else begin
                    v_count <= v_count + 10'd1;
                end
            end else begin
                h_count <= h_count + 11'd1;
            end

            // Registered coordinates are valid for the pixel being emitted
            // in the current cycle.  The one-cycle pipeline is intentional:
            // the renderer can use x/y/de synchronously with this module.
            if (h_count < H_ACTIVE && v_count < V_ACTIVE) begin
                x  <= h_count;
                y  <= v_count;
                de <= 1'b1;
            end else begin
                x  <= 11'd0;
                y  <= 10'd0;
                de <= 1'b0;
            end

            if (h_count >= H_ACTIVE + H_FP &&
                h_count <  H_ACTIVE + H_FP + H_SYNC)
                hsync <= HS_POL;
            else
                hsync <= ~HS_POL;

            if (v_count >= V_ACTIVE + V_FP &&
                v_count <  V_ACTIVE + V_FP + V_SYNC)
                vsync <= VS_POL;
            else
                vsync <= ~VS_POL;
        end
    end
endmodule
