create_clock -name clk -period 20.000 -waveform {0 10.000} [get_ports {clk}]
# 50 MHz input -> 166.666667 MHz serial / 33.333333 MHz pixel (PLLA M=20).
create_generated_clock -name clk_tmds_5x -source [get_ports {clk}] -master_clock clk -divide_by 3 -multiply_by 10 [get_pins {u_tmds_pll/PLLA_inst/CLKOUT0}]
create_generated_clock -name clk_pixel -source [get_ports {clk}] -master_clock clk -divide_by 3 -multiply_by 2 [get_pins {u_tmds_pll/PLLA_inst/CLKOUT1}]

# The official Tang Mega 60K cam_dvi project treats the DVI serializer fast
# clock and RGB pixel clock as separate timing groups.  Their relationship is
# handled inside the device-specific DVI_TX IP/OSER10 block.
set_clock_groups -asynchronous -group [get_clocks {clk_tmds_5x}] -group [get_clocks {clk_pixel}]
