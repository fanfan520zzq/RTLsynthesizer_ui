# 收纳的旧启动入口

日常只使用根目录 `启动.bat`。此目录保留旧名字的兼容代理，统一转发到新入口：

- `start.bat`、`LEGACY_START.bat`、`START_ENV_V1.bat`：统一菜单。
- `start_scene_control.bat`：运行串口UI，支持 `--scene` 参数。
- `start_dimension.bat`：Dimension调试面板。
- `start_loopback.bat`：二进制回环测试。

每个代理以自身位置查找项目根目录，使用该目录自己的 `.venv`，不依赖启动时所在目录。
旧脚本的自动安装依赖功能不再保留；原内容可从已有Git历史恢复。
