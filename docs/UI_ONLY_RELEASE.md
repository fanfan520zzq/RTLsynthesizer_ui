# UI、显示与交互发布记录

日期：2026-10-04。

## 上传范围

本次更新基于远程 main 的 `20cfc30e715387da521b22baeccc3ec9b5bacd2c`，不继承本地之后的十个提交。
只整理 VerilogQT、独立三页 HDMI/EC11 UI、UART 回环、测试和说明。
不包含 Union、音乐合成 RTL、音色/正弦 ROM、Dimension 音频效果器、SD 播放器或这些系统的位流。
PC 对外部业务的串口客户端与控件绑定保留，实际音乐后端由用户另行提供。

原工作区工程和未提交修改保留。发布副本中的脚本使用仓库内部相对路径。
旧 BAT 入口移到 `tools/legacy_launchers/`；800×480 单页导出参考与当前 PC 生成器对齐，三页活动顶层仍为 `top_ec11_ui_60k.v`。
原 720p 纯显示实板基线保留。`impl/`、虚拟环境和构建缓存不上传。

## 本次重新验证

| 层次 | 结果 |
|---|---|
| PC 离屏交互/模拟串口 | 73 项 unittest 通过：场景、参数回读、拖动、颜色、字号、画布、页面、生成边界和启动器 |
| PC 回环 GUI | `PCUI_GUI_PASS`；本地目标编辑与确认状态隔离、断开清理、设计器入口 |
| 三页生成 | 默认相对路径可运行；生成 RTL 与迁入前三页版本 SHA-256 一致 |
| UI RTL 仿真 | 6 项通过，编译/运行 0 Error / 0 Warning；PLL、完整时序、控制、真实 EC11 输入、字体和场景像素 |
| 完整 RTL 渲染 | 三页各 800×480；输出位于 `60k_ui_prj/preview/`，已目视检查 |
| UART 回环 RTL | `PCUI_UART_PASS cases=30`，0 Error / 0 Warning |
| Gowin 构建 | 综合、布局布线、位流生成完成；Logic 2689、Register 338、DSP 2、BSRAM 1；无 Latch；Setup/Hold 违例 0/0 |
| 本次实板 | 未新增实板烧录或验收；上述结果不等于上板结果 |

Gowin 版本：V1.9.11.03 Education；ModelSim：10.3c。
显示约束、加密 DVI IP 和器件保持独立 UI 工程的配置，未引入音乐后端。

生成的当前 UI 位流位于本地 `60k_ui_prj/impl/pnr/fpga_ui_60k_ec11.fs`（构建输出，不纳入本次上传）：

```text
SHA256 6DBAD2883EA43D1C45C055C073E00EC04FC86C8B39CD5957A27BF7668EDB957A
```

三页生成源 `rtl/ui_ec11_scene.v` 的 SHA-256：

```text
45F87B86B25773F0DCF6D756CE0C1243B376D83AB93A9CA170904AB9F43F5AE1
```

保留历史构建中的 DVI 通用时钟路由等提示；时序通过只覆盖现有约束，不代替 HDMI 电气或实板操作验证。
UART 命令本身没有新增或修改。根目录 `UART_COMMANDS.md` 明确区分本仓库回环 RTL与 PC 外部业务客户端；工作区全工程总表仍按实际本地工程适用范围维护。
