"""Unified launcher; only opens a mode selected by the user, never a COM port."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MODES = ('scene-control', 'designer', 'dimension', 'loopback', 'generate', 'folder')


def command_for(mode, scene=None):
    if mode not in MODES:
        raise ValueError('unknown launch mode')
    python = str(ROOT/'.venv/Scripts/python.exe')
    if mode == 'folder':
        return ['explorer.exe', str(ROOT)]
    if mode == 'generate':
        return [python, str(ROOT/'examples/generate_dx7_rtl.py')]
    result = [python, str(ROOT/'run.py')]
    if mode != 'designer':
        result.append('--'+mode)
    if scene is not None:
        if mode != 'scene-control':
            raise ValueError('--scene is only valid for scene-control')
        result += ['--scene', str(Path(scene).resolve())]
    return result


def run_mode(mode, scene=None, dry_run=False):
    command = command_for(mode, scene)
    if dry_run:
        print('DRY_RUN '+subprocess.list2cmdline(command))
        return 0
    try:
        # Child runs in the app folder even when BAT is launched elsewhere.
        if mode == 'folder':
            subprocess.Popen(command, cwd=ROOT)
            return 0
        result = subprocess.run(command, cwd=ROOT)
        if result.returncode:
            print(f'启动失败，返回码 {result.returncode}。请检查上方错误及 README.md。')
        return result.returncode
    except OSError as error:
        print(f'无法启动：{error}')
        return 1


def menu(dry_run=False):
    while True:
        print('\nFPGA UI 上位机 — 800×480')
        print('1. 运行 UI（串口控制多文件音乐工程）')
        print('2. 编辑 UI（设计器）')
        print('3. 串口调试（Dimension）')
        print('4. 高级工具')
        print('0. 退出')
        try:
            choice = input('请选择 0–4：').strip()
            modes = {'1':'scene-control', '2':'designer', '3':'dimension'}
            if choice == '0':
                return 0
            if choice == '4':
                print('\n1. 二进制串口回环测试')
                print('2. 生成显示 RTL（输出到 examples/generated_rtl）')
                print('3. 打开项目目录')
                print('0. 返回')
                advanced = input('请选择 0–3：').strip()
                if advanced == '0':
                    continue
                modes = {'1':'loopback', '2':'generate', '3':'folder'}
                choice = advanced
            if choice not in modes:
                print('无效选择，请重新输入。')
                continue
            run_mode(modes[choice], dry_run=dry_run)
        except (EOFError, KeyboardInterrupt):
            print('\n已退出。')
            return 0


def main(argv=None):
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    parser = argparse.ArgumentParser(description='统一上位机启动入口')
    parser.add_argument('--mode', choices=MODES)
    parser.add_argument('--scene', help='运行自定义串口场景 JSON')
    parser.add_argument('--dry-run', action='store_true', help='仅检查启动命令，不打开窗口')
    args = parser.parse_args(argv)
    if args.scene and args.mode != 'scene-control':
        parser.error('--scene requires --mode scene-control')
    if args.mode:
        return run_mode(args.mode, args.scene, args.dry_run)
    return menu(args.dry_run)


if __name__ == '__main__':
    raise SystemExit(main())
