`timescale 1ns/1ps
// Uses Gowin's GW5A PLLA simulation model, not a clock stub.
module tb_panel_pll;
    reg clk=0;
    always #10 clk=~clk;
    wire lock, serial_clk, pixel_clk;
    TMDS_PLL dut (
        .clkin(clk),
        .lock(lock),
        .clkout0(serial_clk),
        .clkout1(pixel_clk)
    );
    realtime t0, pixel_period, serial_period;
    initial begin
        wait(lock===1'b1);
        repeat(20) @(posedge pixel_clk);
        t0=$realtime;
        repeat(100) @(posedge pixel_clk);
        pixel_period=($realtime-t0)/100.0;
        @(posedge serial_clk); t0=$realtime;
        repeat(500) @(posedge serial_clk);
        serial_period=($realtime-t0)/500.0;
        if (pixel_period<29.99 || pixel_period>30.01 ||
            serial_period<5.99 || serial_period>6.01)
            $fatal(1,"PLL mismatch pixel=%f ns serial=%f ns",pixel_period,serial_period);
        $display("PASS tb_panel_pll pixel_period=%f ns serial_period=%f ns",pixel_period,serial_period);
        $finish;
    end
    initial begin #500000; $fatal(1,"PLL lock/clock watchdog"); end
endmodule
