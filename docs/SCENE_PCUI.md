# 场景与 PC 交互

`verilogQT/examples/dimension_autoplay_pc.json` 是 800×480 三页 UI 示例。控件布局、页面、颜色、字号和 `pc_bindings` 保存在 JSON 中，不包含音乐 ROM 或音频算法。

菜单 2 打开设计器；可拖动控件、改所属页面、编辑本地切页动作、颜色和字号，保存后重新载入。
菜单 1 或设计器中的 Scene FPGA Control 运行场景。绑定到外部串口的按钮和旋钮等待真实回复；不会自动连接 COM，也不会把未知状态显示成已确认值。
F11 隐藏调试区，Esc 返回；切换视图不发送命令。

串口绑定分为 command、effect、feedback、scan/load/previous/next。命令表见 [UART_COMMANDS](../UART_COMMANDS.md)。
旋钮拖动时显示目标草稿，松手只发送一次；收到设置确认后查询真实值。断开、超时或失焦时取消未提交动作。
连接外部后端需要用户另外提供兼容位流。本仓库不包含该位流或音乐后端 RTL。

## 三页 FPGA 示例

`60k_ui_prj/scenes/dimension_autoplay_pc.json` 是专用 FPGA UI 布局快照。
`tools/generate_ec11_ui.py` 校验固定页面和控件名，并输出三页 `ui_ec11_scene.v`。
EC11 旋转、确认、参数草稿和取消由 `ui_ec11_controller.v` 实现。SCAN/LOAD/PLAY 等只记录 LOCAL REQUEST，曲目是 DEMO 项。
改变布局不必改顶层；增删交互控件、改变操作语义时需同步控制器和测试。

通用 Generate RTL 拒绝多页/PC UART 绑定，不能把 PC 客户端直接导出成带业务后端的 FPGA 系统。
操作与接线见 [FPGA UI README](../60k_ui_prj/README.md)，验证分层见 [发布记录](UI_ONLY_RELEASE.md)。
