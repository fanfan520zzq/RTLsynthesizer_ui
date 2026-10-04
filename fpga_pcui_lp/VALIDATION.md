# 验证记录 2026-09-30

- UART复用来源：`60k_phase6_dimension/src/manual/uart_rx.v` 和 `uart_tx.v`，未修改。
- ModelSim 10.3c 引脚级回环：`PCUI_UART_PASS cases=30`，编译/仿真0错误0警告。
- 覆盖8寄存器读写、最大值、按钮/LED、CRC错、版本错、越界、命令错、半包超时、噪声恢复、序号回绕、错误stop bit、复位清零。
- PC协议测试5项通过：已知CRC向量、半包/粘包/噪声、损坏恢复、参数范围、请求匹配和超时关闭。
- Gowin V1.9.11.03 Education：综合、布局布线、位流生成通过。
- Logic=523/59904，Register=355/60780；目标50MHz，Fmax=106.467MHz；Setup/Hold违例=0/0。
- 位流SHA256：`694FD3BD90BBFB0CAC3E1D5742F3E6483DE58C1E7B10CFC464A828766EC2E46C`。
- Gowin提示 `clk_d` 使用通用时钟路由；最终约束内时序通过。
- 新上位机虚拟环境安装完成，pip check无依赖错误；GUI离屏实例化/渲染通过。
- GUI回归通过：本地目标值不伪造回读、回读驱动JSON场景、断开清除确认状态、设计器工具栏启动串口窗口；中文字体渲染已检查。
- 2026-09-30用户反馈“成功”，确认第一版PC UI串口回环实板测试通过；具体仿真覆盖范围仍以上述测试为准。

复现：在 `sim/` 用 ModelSim `vsim -c -do run.do`；在 `verilogQT/` 用 `.venv/Scripts/python.exe -m unittest test_pcui_protocol -v` 和 `.venv/Scripts/python.exe test_pcui_gui.py`。
