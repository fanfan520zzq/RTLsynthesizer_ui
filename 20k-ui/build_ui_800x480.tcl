# Explicit-output build for the normal 800x480 UI bitstream.
# This script deliberately uses a different basename from the diagnostic build.
set_device GW2AR-LV18QN88C8/I7 -name GW2AR-18C
add_file rtl/top_tang_nano_20k_ui.v
add_file rtl/ui_state.v
add_file rtl/ec11_input.v
add_file rtl/test_wave_48k.v
add_file rtl/spectrum_goertzel128.v
add_file rtl/ui_renderer_800x480.v
add_file rtl/video_timing_800x480.v
add_file rtl/font_rom.v
add_file rtl/hdmi_tx.v
add_file rtl/tmds_encoder.v
add_file rtl/tmds_serializer.v
add_file rtl/pll_800x480_template.v
add_file constraints/tang_nano_20k.cst
add_file constraints/tang_nano_20k.sdc
set_option -top_module top_tang_nano_20k_ui
set_option -verilog_std v2001
set_option -print_all_synthesis_warning 1
set_option -output_base_name ui_800x480
run all
exit
