set root [file dirname [info script]]
cd $root
open_project fpga_pcui_lp.gprj
set_option -top_module top_pcui_lp
set_option -output_base_name fpga_pcui_lp
set_option -verilog_std sysv2017
run all
exit
