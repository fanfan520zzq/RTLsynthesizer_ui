`timescale 1ns/1ps
module tb_pcui_lp;
    reg clk=0;
    always #500 clk=~clk;
    reg rst=0, rx=1;
    wire tx,led;
    top_pcui_lp #(.CLK_HZ(1000000),.BAUD(100000),.TIMEOUT_CYCLES(2000)) dut (
        .clk(clk), .rst(rst), .uart_rx(rx), .uart_tx(tx), .led(led)
    );
    reg [7:0] captured [0:255];
    integer count=0;
    integer tests=0;
    reg [7:0] sample;
    integer bitno;
    // Independent pin-level decoder; does not reuse the DUT uart_rx.
    initial forever begin
        @(negedge tx);
        repeat(15) @(posedge clk);
        for(bitno=0;bitno<8;bitno=bitno+1) begin
            sample[bitno]=tx;
            repeat(10) @(posedge clk);
        end
        if(tx!==1'b1) $fatal(1,"TX stop bit invalid");
        captured[count]=sample;
        count=count+1;
    end
    function [7:0] crc_byte(input [7:0] old,input [7:0] data);
        reg [7:0] c; integer k;
        begin c=old^data; for(k=0;k<8;k=k+1) c=c[7]?(c<<1)^8'h07:c<<1; crc_byte=c; end
    endfunction
    task send_byte(input [7:0] b);
        integer j;
        begin
            @(negedge clk); rx=0; repeat(10) @(negedge clk);
            for(j=0;j<8;j=j+1) begin rx=b[j];repeat(10) @(negedge clk);end
            rx=1; repeat(10) @(negedge clk);
        end
    endtask
    task command(input [15:0] seq,input [7:0] op,input [7:0] idx,
                 input [15:0] value,input [7:0] ver,input bit bad_crc);
        reg [7:0] c; reg [55:0] b; integer j;
        begin
            b={value,idx,op,seq,ver};c=0;
            send_byte(8'ha5);send_byte(8'h5a);
            for(j=0;j<7;j=j+1) begin send_byte(b[j*8+:8]);c=crc_byte(c,b[j*8+:8]);end
            send_byte(c ^ (bad_crc?8'h01:8'h00));
        end
    endtask
    task check(input [15:0] seq,input [7:0] status,input [7:0] idx,
               input [15:0] value,input bit button);
        integer j,t; reg [79:0] expected; reg [7:0] c;
        begin
            t=0;
            while(count<11&&t<3000) begin @(negedge clk);t=t+1;end
            if(count!=11) $fatal(1,"reply length %0d",count);
            expected={{7'd0,button},value,idx,status,seq,8'd1,8'ha5,8'h5a};
            c=0;
            for(j=0;j<10;j=j+1) begin
                if(captured[j]!==expected[j*8+:8]) $fatal(1,"reply %0d byte%0d actual %h expected %h",seq,j,captured[j],expected[j*8+:8]);
                if(j>=2)c=crc_byte(c,captured[j]);
            end
            if(captured[10]!==c) $fatal(1,"reply CRC");
            count=0; tests=tests+1;
            repeat(20) @(negedge clk);
        end
    endtask
    integer i;
    initial begin
        repeat(10) @(negedge clk);rst=1;repeat(10) @(negedge clk);
        command(1,4,0,0,1,0);check(1,0,0,0,0);
        for(i=0;i<8;i=i+1) begin
            command(i+2,1,i,16'h1234+i,1,0);check(i+2,0,i,16'h1234+i,0);
        end
        for(i=0;i<8;i=i+1) begin
            command(i+20,2,i,0,1,0);check(i+20,0,i,16'h1234+i,0);
        end
        command(40,1,7,65535,1,0);check(40,0,7,65535,0);
        command(41,3,0,0,1,0);check(41,0,0,16'h1234,1);
        if(led!==0)$fatal(1,"LED not active");
        command(42,3,0,0,1,0);check(42,0,0,16'h1234,0);
        command(43,1,0,999,1,1);check(43,1,0,0,0);
        command(44,2,0,0,1,0);check(44,0,0,16'h1234,0);
        command(45,1,8,999,1,0);check(45,3,8,0,0);
        command(46,1,0,999,2,0);check(46,2,0,0,0);
        command(47,99,0,0,1,0);check(47,4,0,0,0);
        command(48,3,1,0,1,0);check(48,4,1,0,0);
        send_byte(8'ha5);send_byte(8'h5a);send_byte(1);
        repeat(2200) @(negedge clk);
        if(count!=0)$fatal(1,"partial frame generated response");
        send_byte(8'hff);send_byte(8'ha5);send_byte(8'h00);
        command(65535,2,0,0,1,0);check(65535,0,0,16'h1234,0);
        command(0,1,0,0,1,0);check(0,0,0,0,0);
        // Force invalid stop bit, wait for parser reset, then recover.
        @(negedge clk);rx=0;repeat(110) @(negedge clk);rx=1;repeat(100) @(negedge clk);
        command(50,4,0,0,1,0);check(50,0,0,0,0);
        rst=0;repeat(10) @(negedge clk);rst=1;repeat(10) @(negedge clk);
        command(51,2,7,0,1,0);check(51,0,7,0,0);
        $display("PCUI_UART_PASS cases=%0d",tests);
        $finish;
    end
    initial begin #100000000; $fatal(1,"watchdog");end
endmodule
