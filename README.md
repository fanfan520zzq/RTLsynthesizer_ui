# RTLsynthesizer UI

Tang Mega 60K 的 **UI、HDMI 显示和交互工具**。包含 VerilogQT 电脑设计器、800×480 三页 FPGA UI / EC11 工程，以及独立 UART 回环示例。

本仓库不包含音乐合成核心、音色 ROM、Dimension 音频效果器、SD 音乐播放器、Union 联合工程或它们的位流。PC 控件的名称和外部串口客户端可涉及音色/播放，但实际业务后端由用户另外提供。

## 目录

| 路径 | 内容 |
|---|---|
| `verilogQT/` | PySide6 设计器、交互预览、页面/颜色/字号编辑、JSON 场景、RTL 生成器、PC 串口客户端及测试 |
| `60k_ui_prj/` | GW5AT-LV60PG484AC1/I0，800×480 HDMI、三页 UI、EC11 焦点/确认/参数编辑、字体、生成工具和 RTL 测试 |
| `fpga_pcui_lp/` | 8 个寄存器和 1 个按钮的 UART 回环示例；不含 HDMI 和音乐 |
| `docs/` | UI 使用、生成边界、串口协议和本次上传验证 |
| `UART_COMMANDS.md` | 本仓库回环协议及 PC 对外部后端使用的命令 |

## 电脑端入口

```powershell
cd verilogQT
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\启动.bat
```

统一菜单：1 运行场景 UI，2 编辑 UI，3 外部 Dimension 串口调试，4 高级工具。
菜单 1/3 不自带音乐后端，不自动连接 COM；纯电脑演示可在设计器中预览无串口绑定的场景。页面编辑、导航、颜色和字号变化在 PC 上实时显示。
源码以仓库内 `verilogQT/` 为维护源；独立运行副本需要主动同步，不是自动双向同步。

## FPGA 显示和交互

打开 `60k_ui_prj/tang_mega_60k_hdmi.gprj`。当前顶层源是 `rtl/top_ec11_ui_60k.v`（模块 `top_tmds_60k`），构建输出 `impl/pnr/fpga_ui_60k_ec11.fs`。

三页分别是曲目、音色/参数、状态/播放。曲目使用明确标记的 DEMO 项；SCAN/LOAD/PLAY 等按钮只记录本地请求，不加载文件、不合成声音、不伪造硬件 ACK。旋转 EC11 移动焦点，短按确认，长按取消/返回；参数草稿确认后更新本地 UI 状态。

在 `60k_ui_prj/` 执行：

```powershell
& ..\verilogQT\.venv\Scripts\python.exe tools\generate_ec11_ui.py
& tools\test_ec11.ps1
& tools\render_ec11.ps1
& 'D:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe' build_tmds.tcl
```

接线、操作和三页生成要求见 [FPGA UI README](60k_ui_prj/README.md)。

## 三种生成/集成边界

- PC 通用 `Generate RTL` 导出单页固定接口的 `ui_generated_scene.v`；不支持直接导出多页或 PC UART 绑定。
- 本仓库三页 EC11 UI 使用专用 `60k_ui_prj/tools/generate_ec11_ui.py`，生成 `ui_ec11_scene.v`。修改坐标、颜色、文字后重新生成；增删交互控件或改变语义需要同步控制器和测试。
- 联合业务系统需另行接入真实后端；本仓库只提供 UI 示例及接口，不包含该集成源码。

## 验证与历史基线

三页 EC11 UI 的历史构建记录见 [BUILD_VALIDATION](60k_ui_prj/BUILD_VALIDATION.md)，本次上传验证见 [UI_ONLY_RELEASE](docs/UI_ONLY_RELEASE.md)。PC 离屏测试、RTL 仿真、综合/P&R 和实板验收分别记录，不能互相替代。
原 720p 用户已验收的纯显示版本保留在 `60k_ui_prj/release/v0.1.0-board-verified/`；它不是当前三页版本的实板验收证明。
`verilogQT/docs/` 中的旧实现说明和旧板级模板作为历史参考，当前使用入口以本 README 和各工程 README 为准。
