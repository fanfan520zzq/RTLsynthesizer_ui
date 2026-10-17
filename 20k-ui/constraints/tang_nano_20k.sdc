# 27 MHz reference input
create_clock -name clk_27m -period 37.037 [get_ports {clk_27m}]

# The final generated PLL wrapper may use different hierarchical net names.
# Update these two get_nets after adding the Gowin-generated IP.
create_clock -name clk_serial -period 6.006 [get_nets {pll/clk_serial}]
create_generated_clock -name clk_pixel -source [get_nets {pll/clk_serial}] -divide_by 5 [get_nets {pll/clk_pixel}]
set_clock_groups -asynchronous -group [get_clocks {clk_pixel}] -group [get_clocks {clk_serial}]

set_false_path -from [get_ports {btn_rst_n}]
set_false_path -from [get_ports {ec11_a}]
set_false_path -from [get_ports {ec11_b}]
set_false_path -from [get_ports {ec11_key_n}]
