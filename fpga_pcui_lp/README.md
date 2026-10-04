# FPGA PC UI 串口回环

独立 Tang Mega 60K 工程：8 个 16 位寄存器及 1 个按钮状态。上电/复位均为 0。
复用 dimension 的 UART 源码，50 MHz 时钟 V22、低有效复位 Y12、TX U15、RX V14、LED T18。
连接使用 dimension 已验证的 USB 串口路径，115200 8N1，无流控。若使用外接 USB-UART，TX→V14、RX←U15、共地、3.3 V 电平。

## 使用

1. 在本目录运行 `gw_sh build.tcl`，位流位于 `impl/pnr/fpga_pcui_lp.fs`。
2. 烧录本位流，启动 `../verilogQT/启动.bat`，选4高级工具→1回环测试。
3. 选择正确 COM，连接；收到 Ping 回复才显示 FPGA 已确认。
4. 拖动滑块/数值框，比较目标值和 FPGA 回读值；切换寄存器后查询。
5. 点击按钮，检查返回按钮状态和 LED。关闭连接后重连查询，值应保留；按复位后查询，值应归零。

PC 合并滑块编辑，最多一个请求在途；1 秒未回复则断开并标为未确认，无自动重试。
此工程不包含自动演奏和 HDMI，后续可复用 `pcui_protocol.v` 的字节接口。

协议定义见 [协议](../docs/PCUI_PROTOCOL.md)。实板通信验收需用户烧录后完成。
