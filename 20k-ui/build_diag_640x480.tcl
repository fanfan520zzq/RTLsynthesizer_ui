set_device GW2AR-LV18QN88C8/I7 -name GW2AR-18C
add_file rtl/top_tang_nano_20k_diag.v
add_file rtl/video_timing_640x480.v
add_file rtl/colorbars_640x480.v
add_file rtl/hdmi_tx.v
add_file rtl/tmds_encoder.v
add_file rtl/tmds_serializer.v
add_file rtl/pll_640x480.v
add_file constraints/tang_nano_20k_diag.cst
add_file constraints/tang_nano_20k_diag.sdc
set_option -top_module top_tang_nano_20k_diag
set_option -verilog_std v2001
set_option -print_all_synthesis_warning 1
set_option -output_base_name diag_640x480
run all
exit
