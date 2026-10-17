`timescale 1ns/1ps
module tb_ui20k;
 reg clk=0, rst_n=0, a=0, b=0, key_n=1;
 wire [2:0] dp,dn; wire cp,cn;
 top_tang_nano_20k_ui dut(.clk_27m(clk),.btn_rst_n(rst_n),.ec11_a(a),.ec11_b(b),.ec11_key_n(key_n),.tmds_d_p(dp),.tmds_d_n(dn),.tmds_clk_p(cp),.tmds_clk_n(cn));
 always #5 clk=~clk;
 initial begin
   $dumpfile("tb_ui20k.vcd"); $dumpvars(0,tb_ui20k);
   #100 rst_n=1;
   #1000000;
   if (^dp === 1'bx || ^cp === 1'bx) $fatal(1,"TMDS outputs contain X");
   $display("PASS: simulation outputs are driven");
   $finish;
 end
endmodule
