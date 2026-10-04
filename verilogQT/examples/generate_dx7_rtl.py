#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Example: Load and Generate RTL from JSON
"""

import sys
import json
from pathlib import Path

# Force UTF-8 encoding on Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# Import both modules through their package-qualified names so the scene
# objects and generator share the exact same ``designer.ui_schema`` classes.
# Importing one side as plain ``ui_schema`` creates a second module instance
# and makes isinstance-based renderer selection unreliable.
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from designer.ui_schema import *
from generator.rtl_generator import RTLGenerator


def load_scene_from_json(json_path: Path) -> UIScene:
    """从 JSON 加载 UI Scene"""
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    scene = UIScene(
        name=data.get("name", "scene"),
        width=data.get("width", 800),
        height=data.get("height", 480),
        interactions=list(data.get("interactions", [])),
    )

    # 加载背景色
    if "bg_color" in data:
        bg = data["bg_color"]
        scene.bg_color = Color(bg.get("r", 5), bg.get("g", 7), bg.get("b", 12))

    # 加载控件
    for w_data in data.get("widgets", []):
        widget_type = w_data.get("type")

        if widget_type == "panel":
            widget = PanelWidget(
                type="panel",
                x=w_data.get("x", 0),
                y=w_data.get("y", 0),
                width=w_data.get("width", 100),
                height=w_data.get("height", 100),
                name=w_data.get("name", ""),
                visible=w_data.get("visible", True),
                layer=w_data.get("layer", 0)
            )
            if "bg_color" in w_data:
                c = w_data["bg_color"]
                widget.bg_color = Color(c["r"], c["g"], c["b"])
            if "border_color" in w_data:
                c = w_data["border_color"]
                widget.border_color = Color(c["r"], c["g"], c["b"])
            widget.border_width = w_data.get("border_width", 1)

        elif widget_type == "text":
            widget = TextWidget(
                type="text",
                x=w_data.get("x", 0),
                y=w_data.get("y", 0),
                width=w_data.get("width", 100),
                height=w_data.get("height", 30),
                text=w_data.get("text", ""),
                font_size=w_data.get("font_size", 16),
                align=w_data.get("align", "left"),
                name=w_data.get("name", ""),
                visible=w_data.get("visible", True),
                layer=w_data.get("layer", 0)
            )
            if "color" in w_data:
                c = w_data["color"]
                widget.color = Color(c["r"], c["g"], c["b"])

        elif widget_type == "bar":
            widget = BarWidget(
                type="bar",
                x=w_data.get("x", 0),
                y=w_data.get("y", 0),
                width=w_data.get("width", 100),
                height=w_data.get("height", 20),
                source=w_data.get("source", "value"),
                max_value=w_data.get("max_value", 100),
                corner_radius=w_data.get("corner_radius", 999),
                name=w_data.get("name", ""),
                visible=w_data.get("visible", True),
                layer=w_data.get("layer", 0)
            )
            if "fg_color" in w_data:
                c = w_data["fg_color"]
                widget.fg_color = Color(c["r"], c["g"], c["b"])
            if "bg_color" in w_data:
                c = w_data["bg_color"]
                widget.bg_color = Color(c["r"], c["g"], c["b"])

        elif widget_type == "spectrum":
            widget = SpectrumWidget(
                type="spectrum",
                x=w_data.get("x", 0),
                y=w_data.get("y", 0),
                width=w_data.get("width", 600),
                height=w_data.get("height", 240),
                bars=w_data.get("bars", 64),
                source=w_data.get("source", "fft_bins"),
                attack=w_data.get("attack", 4),
                decay=w_data.get("decay", 1),
                peak_hold=w_data.get("peak_hold", 20),
                name=w_data.get("name", ""),
                visible=w_data.get("visible", True),
                layer=w_data.get("layer", 0)
            )
            if "bar_color" in w_data:
                c = w_data["bar_color"]
                widget.bar_color = Color(c["r"], c["g"], c["b"])
            if "bg_color" in w_data:
                c = w_data["bg_color"]
                widget.bg_color = Color(c["r"], c["g"], c["b"])

        elif widget_type == "waveform":
            widget = WaveformWidget(
                type="waveform",
                x=w_data.get("x", 0),
                y=w_data.get("y", 0),
                width=w_data.get("width", 600),
                height=w_data.get("height", 200),
                samples=w_data.get("samples", 1024),
                source=w_data.get("source", "pcm_buffer"),
                line_width=w_data.get("line_width", 2),
                name=w_data.get("name", ""),
                visible=w_data.get("visible", True),
                layer=w_data.get("layer", 0)
            )
            if "line_color" in w_data:
                c = w_data["line_color"]
                widget.line_color = Color(c["r"], c["g"], c["b"])
            if "bg_color" in w_data:
                c = w_data["bg_color"]
                widget.bg_color = Color(c["r"], c["g"], c["b"])

        elif widget_type == "keyboard":
            widget = KeyboardWidget(
                type="keyboard",
                x=w_data.get("x", 0),
                y=w_data.get("y", 0),
                width=w_data.get("width", 700),
                height=w_data.get("height", 120),
                start_note=w_data.get("start_note", 48),
                keys=w_data.get("keys", 25),
                source=w_data.get("source", "key_states"),
                name=w_data.get("name", ""),
                visible=w_data.get("visible", True),
                layer=w_data.get("layer", 0)
            )
            if "white_key_color" in w_data:
                c = w_data["white_key_color"]
                widget.white_key_color = Color(c["r"], c["g"], c["b"])
            if "black_key_color" in w_data:
                c = w_data["black_key_color"]
                widget.black_key_color = Color(c["r"], c["g"], c["b"])
            if "pressed_color" in w_data:
                c = w_data["pressed_color"]
                widget.pressed_color = Color(c["r"], c["g"], c["b"])

        elif widget_type == "knob":
            widget = KnobWidget(
                type="knob",
                x=w_data.get("x", 0),
                y=w_data.get("y", 0),
                width=w_data.get("width", 80),
                height=w_data.get("height", 80),
                source=w_data.get("source", "knob_value"),
                min_value=w_data.get("min_value", 0),
                max_value=w_data.get("max_value", 127),
                min_angle=w_data.get("min_angle", -135),
                max_angle=w_data.get("max_angle", 135),
                name=w_data.get("name", ""),
                visible=w_data.get("visible", True),
                layer=w_data.get("layer", 0)
            )
            if "fg_color" in w_data:
                c = w_data["fg_color"]
                widget.fg_color = Color(c["r"], c["g"], c["b"])
            if "bg_color" in w_data:
                c = w_data["bg_color"]
                widget.bg_color = Color(c["r"], c["g"], c["b"])

        else:
            continue  # 未知类型跳过

        scene.widgets.append(widget)

    return scene


def main():
    # 自动演奏低资源示例：不携带 FFT/PCM 大总线。
    json_path = Path(__file__).parent / "autoplay_status.json"
    print(f"Loading UI from {json_path}...")

    scene = UIScene.from_json(json_path)
    print(f"[OK] Loaded scene '{scene.name}' with {len(scene.widgets)} widgets")

    # 生成到单独的示例输出目录，避免覆盖手写 RTL
    output_dir = Path(__file__).parent / "generated_rtl"
    output_dir.mkdir(exist_ok=True)
    print(f"\nGenerating RTL to {output_dir}...")
    # Keep the CLI output ASCII-only so it works with the Windows cp1252
    # console when Python is not started in UTF-8 mode.
    print("[NOTE] This is example output, not the main project RTL")

    generator = RTLGenerator()
    generator.generate(scene, output_dir)

    print(f"\n[OK] RTL generation complete!")
    print(f"\nGenerated Verilog files (fixed count = 1):")
    print(f"  - ui_generated_scene.v")
    print(f"\nNext steps:")
    print(f"  1. Copy ui_generated_scene.v over the FPGA project's file of the same name")
    print(f"  2. Rebuild the existing Gowin project; no other Verilog file changes")


if __name__ == "__main__":
    main()
