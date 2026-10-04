# Tang Mega 60K 三页 UI / EC11 独立测试

当前工程是 **800×480 五寸屏显示 + EC11 操作**，目标器件仍为
`GW5AT-LV60PG484AC1/I0`。三页来自 PC 的 `dimension_autoplay_pc.json`：
SD 曲目页、音色/效果页、状态/播放页。

本版没有连接 SD 控制器、Dimension 合成器或 UART。曲目是明确标注的
`DEMO 0..5`；SCAN、LOAD、AUTO、PLAY、STOP、QUERY 仅记录本地请求，
不会模拟 FPGA 加载成功、开始播放、播放完成或硬件 ACK。

## 上板入口与接线

使用本仓库 `60k_ui_prj/`。当前为三页 EC11 UI，旧单页显示源码仅作参考。

- Gowin 工程：`tang_mega_60k_hdmi.gprj`
- 当前顶层源：`rtl/top_ec11_ui_60k.v`，模块名 `top_tmds_60k`
- 新测试位流：`impl/pnr/fpga_ui_60k_ec11.fs`
- 复位按键：Y12，低有效；板载 LED：T18，PLL 锁定后灭。

| EC11 信号 | FPGA 管脚 | 电气设置 |
|---|---|---|
| A | A15 | 3.3 V 输入，内部上拉 |
| B | B20 | 3.3 V 输入，内部上拉 |
| SW | B21 | 3.3 V 输入，按下接地 |
| 编码器 C / 开关公共端 | GND | 与 FPGA 共地 |

这些引脚来自当前已跑通的 `60k_ec11_uart_test/src/ec11_uart_test.cst`，
不是该例程旧 README 中的 F13/F16/D20。原 EC11 工程未修改。
不要给输入管脚接 5 V；若实际旋转方向相反，可交换 A/B。
HDMI 约束不变：时钟 G15/G16，数据 J14/H14、J15/H15、K17/J17，HPD K13。

## EC11 怎样操作

1. 旋转：移动青色焦点框，支持首尾循环。默认焦点为 SD 页签。
2. 短按后松开：确认。焦点在顶部三个页签时切页，在按钮时执行本地操作。
3. 效果页选中 R/D/W/M 条形控件后短按：进入编辑，边框变黄。
   旋转每个完整编码周期增减 1，范围 0..255，不溢出；屏幕用 `00..FF` 十六进制显示。
   再短按确认，退出编辑。
4. 长按约 0.8 秒：取消未确认的参数修改，返回当前页签焦点。
   非编辑状态只返回当前页签；长按松开不会再次触发短按。
5. 换页保留选择与本地参数，复位恢复默认值。

SD 页的 PREV/NEXT 在 6 个演示项之间循环。音色页可选择 PATCH 0..6、
开关本地 FX，并编辑四个参数。初值 R=64、D=128、W=128、M=64、FX=1，
仅是 UI 测试值，不是播放器的已读回状态。

状态页 `LAST LOCAL REQUEST` 使用十六进制编码：

| 代码 | 本地操作 |
|---|---|
| 00 | 复位后尚无请求 |
| 01 / 02 / 03 / 04 | SCAN / PREV / NEXT / LOAD |
| 05 / 06 / 07 / 08 | AUTO / PLAY / STOP / QUERY |
| 10..16 | PATCH 0..6 |
| 20..23 | 确认 R / D / W / M 参数 |
| 30 / 31 | FX ON / FX BYPASS |

## 布局迁移与后续修改

`scenes/dimension_autoplay_pc.json` 是 PC 三页布局快照，保留坐标、页面和颜色。
FPGA 本版采用正常比例的原生 8×16 ASCII 字格：正文 1×，大字横纵同时 2×，即 16×32。
不再使用 5×7 字模的单独纵向拉伸。字号映射为：PC 字号不大于 16 对应 8×16，
大于 16 对应 16×32；大字文本框自动加高到至少 32 像素，生成器检查文本越界及重叠。
这仍不是 PC 任意字号的像素级复刻；
圆形旋钮转换成同位置的条形数值控件。焦点、选中项、编辑和页切换均实时生成，
不是整屏静态图片，也不需要帧缓冲。

本地交互生成入口为 `tools/generate_ec11_ui.py`，不是 PC 中通用的 `Generate RTL`
（后者会拒绝多页/PC 绑定）。生成器检查固定页面 ID、控件名字、边界及切页目标，
并只输出一个可替换源 `rtl/ui_ec11_scene.v`；修改坐标和颜色后无需再改顶层。
改变控制语义、增加/删除交互控件时仍需修改控制器和对应测试。

三页共用一个同步字体 ROM，先选择当前页和文字，再读取对应字模。
背景、文字颜色、列号及焦点框与 ROM 同步延迟，外部 1 拍渲染契约保持不变。
字体快照为 `scenes/font_8x16.mem`（可打印 ASCII 32..126，8×16 字格）；
从本机 Consolas Bold 原生栅格化，不进行横向/纵向重采样，也不随工程分发 TTF。
ROM 数据已经内嵌到生成的单个 Verilog 中，综合不需要额外 `.mem` 或 Windows 字体。
如需重新烘焙字模，可用已配置的 Python 环境运行 `tools/build_font_8x16.py`；
日常修改布局只需重跑 `tools/generate_ec11_ui.py`，不需要重新烘焙字体。

```powershell
# 在本工程目录执行；使用已经配置好的上位机 Python 环境。
& ..\verilogQT\.venv\Scripts\python.exe tools\generate_ec11_ui.py
# 也可 --scene 指向在 PC 设计器中编辑并保存的同名三页 JSON。
& tools\test_ec11.ps1
& tools\render_ec11.ps1
& 'D:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe' build_tmds.tcl
```

`--pc-root D:\verilogQT` 可切换使用独立上位机目录的场景 schema；字体渲染由本工程生成器实现。
本 FPGA 示例没有 UART、音乐合成、SD 播放和音频效果器。PC 串口接口见仓库根目录 `UART_COMMANDS.md`。

## 显示链路与验证边界

采用此前已显示成功的五寸屏链路：H=1056/20/26/800，V=525/3/23/480，
HS/VS 正极性；60K PLLA 输出像素 33.333333 MHz、串行 166.666667 MHz。
每帧在消隐区统一锁存 UI 状态；渲染 1 拍 + 输出 1 拍，DE/HS/VS 同步延迟 2 拍。
EC11 解码器保持原始源码不变，改用像素时钟参数，消抖仍是 3 次 1 ms 采样。

当前仿真、综合、布局布线和位流证据见 `BUILD_VALIDATION.md`。
**本次 EC11+显示的组合还需要用户上板验证，不能用单独显示/单独编码器的通过替代。**

原 `release/v0.1.0-board-verified/` 的 720p 上板基线位流没有修改。
旧 `rtl/top_tmds_60k.v` / `rtl/ui_generated_scene.v` 保留为参考但不在当前 GPRJ 文件列表中；
不要选择旧 `fpga_ui_60k_tmds.fs` 测试本次 EC11 功能。
