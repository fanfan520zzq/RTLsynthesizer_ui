# UI 仓库串口接口

本仓库的 FPGA 串口实现只有 `fpga_pcui_lp`。`60k_ui_prj` 没有 UART；EC11 的 LOCAL REQUEST 编码不是串口命令。
外部 Dimension 命令仅由 PC 客户端发送，音乐后端源码/位流不在本仓库。下面两种协议不能混用。

## FPGA PCUI 二进制回环

适用 `fpga_pcui_lp`；115200 8N1，请求固定 10 字节，回复固定 11 字节。
请求：`A5 5A 01 seq16 op index value16 CRC8`；回复：`5A A5 01 seq16 status index value16 button CRC8`。
多字节小端，CRC-8/ATM：poly07/init00/xorout00/不反射，覆盖版本至载荷，排除帧头。

| op | 操作 | 参数 |
|---|---|---|
| 01 | SET 写入回读 | index=0..7，value=0..65535 |
| 02 | QUERY | index=0..7，value 忽略 |
| 03 | TOGGLE | index=0，value=0；翻转按钮 |
| 04 | PING | index=0，value=0；返回寄存器0 |

寄存器和按钮复位为0。status：0成功、1CRC错误、2版本错误、3索引越界、4命令/参数错误。
半包20ms超时或UART帧错误丢弃；FPGA响应期间完整新请求丢弃。PC最多一个在途请求，1秒超时断开，不自动重发。
详见 [协议](docs/PCUI_PROTOCOL.md)，RTL 为 `fpga_pcui_lp/rtl/pcui_protocol.v`。

## PC 外部业务客户端

适用用户另行提供的兼容 Dimension 设备；115200 8N1 ASCII。本仓库不实现以下命令的 FPGA 后端。

| 请求 | 语义/回复 |
|---|---|
| M/A | 手动/自动；P5 M/A |
| P/S | 播放/停止；P5 P/S；P5 N/B/C 表示拒绝 |
| Q | 查询模式；P5 M/A |
| 0..6 | 选择音色；P5 数字 |
| !E00/!E01 | 外部效果关闭/开启；FX OK/FX ERR |
| !RHH/!DHH/!WHH/!MHH | 外部效果参数，HH=00..FF；FX OK/FX ERR |
| !Q | FX RHH DHH WHH MHH E00/01 |
| @L | 仅多文件扩展设备；SD BEGIN、SD FHH 文件名、SD END CC |
| @SHH | 仅多文件扩展设备；HH=00..0F；SD READY HH 或 SD ERR EE |

`!M` 是外部 Dimension Mix，不是主音量。既有外部默认 R47/D40/WCC/M4D/E00；PC未知值保持未知，不把默认值当作回读。
PC设置确认后自动查询；普通请求3秒、SD请求35秒超时断开，不重发。扩展加载不会自动播放。异步 P5 R/E 不能代替 SD READY。
这些定义来自现有 RTL 核对记录和 PC 编解码实现；后端不在本仓库，不承诺所有设备都支持全部扩展。
