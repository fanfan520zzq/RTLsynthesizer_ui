create_clock -name clk -period 20.000 [get_ports {clk}]
# Asynchronous board inputs; internal synchronizers are retained.
set_false_path -from [get_ports {rst}]
set_false_path -from [get_ports {uart_rx}]
