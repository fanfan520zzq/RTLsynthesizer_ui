set root [file dirname [info script]]
cd $root
open_project tang_mega_60k_hdmi.gprj
set_option -top_module top_tmds_60k
set_option -output_base_name fpga_ui_60k_ec11
set_option -verilog_std sysv2017
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1

run all
exit
