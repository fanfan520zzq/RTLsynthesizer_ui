onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
vlib work
vlog -sv ../rtl/uart_rx.v ../rtl/uart_tx.v ../rtl/pcui_protocol.v ../rtl/top_pcui_lp.v tb_pcui_lp.sv
vsim -c work.tb_pcui_lp
run -all
quit -code 0 -force
