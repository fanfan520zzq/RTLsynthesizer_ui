# PCUI v1

仅用于 `fpga_pcui_lp`，115200 8N1。所有 uint16 小端。

请求固定 10 字节：`A5 5A 01 seq_lo seq_hi op index value_lo value_hi CRC`。
回复固定 11 字节：`5A A5 01 seq_lo seq_hi status index value_lo value_hi button CRC`。
CRC-8/ATM：poly=07，init=00，xorout=00，不反射，覆盖版本至载荷末字节，排除两字节帧头。

| op | 功能 | 参数/响应 |
|---|---|---|
| 01 | SET | index=0..7，value=0..65535；写入并回读 |
| 02 | QUERY | index=0..7，value忽略；返回当前值 |
| 03 | TOGGLE | index=0,value=0；翻转按钮，value返回寄存器0 |
| 04 | PING | index=0,value=0；value返回寄存器0 |

每个有效回复均包含按钮状态 0/1。status：0成功、1 CRC错误、2版本错误、3索引越界、4命令/参数错误。
错误请求不修改寄存器或按钮。CRC错误帧中的序号不可信，PC仍须匹配在途序号；匹配不到将超时。
半包超过 20 ms 无字节、UART framing error 均丢弃，无回复；新帧从 A5 5A 恢复。
FPGA 发送响应期间收到的完整请求丢弃。PC必须等到上一回复完成再发送，最多一个请求在途。
PC 1秒超时断开连接，不自动重发 TOGGLE；重连后通过 QUERY/PING 恢复已确认状态。
本版无事件去重，手动重复 TOGGLE 会再次翻转。序号 uint16 循环，连接不重置 PC 计数。
寄存器与按钮默认0，复位清零，断开串口不清零。

Python 编解码：`verilogQT/communication/protocol.py`；RTL：`fpga_pcui_lp/rtl/pcui_protocol.v`。
