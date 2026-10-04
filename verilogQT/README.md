# VerilogQT 上位机

PySide6 UI 设计器、交互预览、JSON 场景和显示 RTL 生成工具。当前默认画布为 800×480。
本目录为源码维护入口；独立运行副本需要手动同步，虚拟环境应各自创建。
配套显示/EC11 工程在 `../60k_ui_prj/`，串口回环在 `../fpga_pcui_lp/`。音乐后端源码和位流不随本仓库提供。

## 安装和启动

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\启动.bat
```

统一入口只有 `启动.bat`：

- 1：运行 800×480 场景 UI；串口控件需要用户另外提供兼容的外部后端。
- 2：打开 UI 设计器。
- 3：外部 Dimension ASCII 串口调试。
- 4：高级工具，包含独立回环测试、单页显示 RTL 导出和打开目录。
- 0：退出。

菜单不自动连接串口、安装依赖或烧录。旧 BAT 保存在 `tools/legacy_launchers/`，作为兼容入口。
串口使用 PySide6 QtSerialPort，不需要 pyserial。

## 编辑和预览

打开 `examples/dimension_autoplay_pc.json` 可编辑三页场景。拖动控件可改变坐标，属性面板可改尺寸、文字、所属页面和颜色；支持 HEX/RGB 选色，保存 JSON 后保留。
可新增/重命名页面、设置默认页、配置本地切页动作。删除仍被控件或导航引用的页面会被阻止；公共控件在每页显示。
Text 字号范围 8–72 px，设计画布、Preview 和 PC 运行 UI 共用可缩放 ASCII 字形，文字裁剪到控件边界。
PC 预览支持旋钮、鼠标/电脑键盘事件和本地交互规则。串口绑定场景的预览进入硬件运行窗口，不自动连接；未确认数据不冒充真实后端状态。
F11 显示纯场景，Esc 返回调试界面。屏幕保持场景像素尺寸，不因扩大窗口而自动放大。

## 目录

- `designer/`：设计器、场景模型、PC 渲染、交互预览和运行窗口。
- `communication/`：回环协议与外部 Dimension 客户端，不包含 FPGA 业务后端。
- `generator/`：显示 RTL 生成器。
- `examples/`：单页显示、三页交互、串口回环等 JSON 示例；不是音乐 ROM。
- `rtl/`、`testbench/`：旧 UI 渲染/事件模板和相关测试，不含音乐合成核心。
- `tools/`：统一启动器及兼容入口。

## RTL 导出边界

通用 `Generate RTL` 每次生成一个 `ui_generated_scene.v`，拒绝多页和 PC UART 绑定。导出结果不直接替换当前三页 EC11 顶层。
三页 FPGA UI 请用 `../60k_ui_prj/tools/generate_ec11_ui.py`，详细步骤见 [FPGA UI](../60k_ui_prj/README.md)。
PC 任意字号与 FPGA 的两档原生字格不同，不能把 PC 外观当作 FPGA 像素效果保证。

## 串口

回环需要烧录独立 `fpga_pcui_lp` 工程，见 [协议](../docs/PCUI_PROTOCOL.md)。
外部业务客户端的命令和使用边界见 [命令表](../UART_COMMANDS.md)、[Dimension 客户端](../docs/DIMENSION_PCUI.md) 和 [场景控制](../docs/SCENE_PCUI.md)。
页面和串口客户端仍可在 PC 上测试；本仓库不提供音乐后端位流，独立 UI 位流也不接收 Dimension ASCII 命令。

## 主要回归

```powershell
.\.venv\Scripts\python.exe -m unittest test_scene_runtime test_dimension test_pcui_protocol test_designer_drag test_designer_colors test_designer_font_size test_designer_panel_size test_pages -v
.\.venv\Scripts\python.exe test_pcui_gui.py
```

测试使用离屏窗口及模拟串口；不等于实板通信验收。菜单/BAT 回归另见 `test_launcher.py`。
