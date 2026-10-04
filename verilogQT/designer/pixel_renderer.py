#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RTL Pixel Renderer
像素级渲染器 - Python 参考实现
完整支持所有控件类型
"""

import numpy as np
from dataclasses import replace
from functools import lru_cache
import re
from pathlib import Path
from typing import Tuple, Optional, Dict, Any, List

try:
    # Works when imported as ``designer.pixel_renderer``.
    from .ui_schema import *
except ImportError:
    # Also keep direct execution (``python designer/pixel_renderer.py``) working.
    from ui_schema import *


class PixelRenderer:
    """像素渲染器 - 模拟 FPGA 行为"""

    def __init__(self, width: int = 1280, height: int = 720):
        self.width = width
        self.height = height
        self.framebuffer = np.zeros((height, width, 3), dtype=np.uint8)

    def render_scene(self, scene: UIScene, ui_state: Dict[str, Any], page=None):
        """渲染整个场景"""
        if scene.width <= 0 or scene.height <= 0:
            raise ValueError("scene width and height must be positive")

        # A renderer can be reused for scenes with different resolutions.
        if self.width != scene.width or self.height != scene.height:
            self.width = scene.width
            self.height = scene.height
            self.framebuffer = np.zeros((self.height, self.width, 3), dtype=np.uint8)

        # 清空背景
        bg = scene.bg_color
        self.framebuffer[:, :] = [bg.r, bg.g, bg.b]

        # 按 layer 排序渲染
        widgets = sorted(scene.visible_widgets(page), key=lambda w: w.layer)

        for widget in widgets:
            if not widget.visible:
                continue

            if widget.type == "panel":
                active_page = scene.initial_page if page is None else page
                action = scene.local_actions.get(widget.name)
                if action and action['target'] == active_page:
                    self._render_panel(replace(widget, border_width=max(3, widget.border_width)))
                else:
                    self._render_panel(widget)
            elif widget.type == "text":
                self._render_text(widget)
            elif widget.type == "bar":
                # 从 ui_state 数组中获取值
                value = self._get_value_from_state(widget.source, ui_state)
                self._render_bar(widget, value)
            elif widget.type == "spectrum":
                fft_data = ui_state.get(widget.source, [])
                self._render_spectrum(widget, fft_data)
            elif widget.type == "waveform":
                pcm_data = ui_state.get(widget.source, [])
                self._render_waveform(widget, pcm_data)
            elif widget.type == "knob":
                value = self._get_value_from_state(widget.source, ui_state)
                self._render_knob(widget, value)
            elif widget.type == "keyboard":
                key_states = ui_state.get(widget.source, [])
                self._render_keyboard(widget, key_states)

        return self.framebuffer

    def _get_value_from_state(self, source: str, ui_state: Dict[str, Any]) -> int:
        """从 ui_state 中解析值"""
        # 支持紧凑和带空格的格式: "ui_state[0]" / "ui_state [ 0 ]"。
        # This is the same grammar used by the preview and RTL generator.
        if isinstance(source, str):
            match = re.fullmatch(r"\s*ui_state\s*\[\s*(\d+)\s*\]\s*", source)
            if match:
                try:
                    idx = int(match.group(1))
                    state_array = ui_state.get("ui_state", [])
                    if 0 <= idx < len(state_array):
                        return state_array[idx]
                except (TypeError, ValueError, IndexError):
                    pass
        if isinstance(source, str):
            direct = ui_state.get(source)
            if direct is not None and not isinstance(direct, (list, tuple, dict)):
                return int(direct)
            # DX7 scene names map to the same 16-bit flattened words used by
            # the generator (op1_level -> ui_state[0], etc.).
            if source.lower().startswith("op") and source.lower().endswith("_level"):
                try:
                    index = int(source[2:-6]) - 1
                    values = ui_state.get("ui_state", [])
                    if 0 <= index < len(values):
                        return int(values[index])
                except (TypeError, ValueError):
                    pass
        return 0

    def _render_panel(self, widget: PanelWidget):
        """渲染面板"""
        x1, y1 = widget.x, widget.y
        x2, y2 = x1 + widget.width, y1 + widget.height

        # 裁剪
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(self.width, x2), min(self.height, y2)

        if x1 >= x2 or y1 >= y2:
            return

        # 填充背景
        bg = widget.bg_color
        self.framebuffer[y1:y2, x1:x2] = [bg.r, bg.g, bg.b]

        # 绘制边框
        if widget.border_width > 0:
            border = widget.border_color
            bw = widget.border_width
            # 上下边框
            if y1 + bw <= y2:
                self.framebuffer[y1:y1+bw, x1:x2] = [border.r, border.g, border.b]
                self.framebuffer[max(y1, y2-bw):y2, x1:x2] = [border.r, border.g, border.b]
            # 左右边框
            if x1 + bw <= x2:
                self.framebuffer[y1:y2, x1:x1+bw] = [border.r, border.g, border.b]
                self.framebuffer[y1:y2, max(x1, x2-bw):x2] = [border.r, border.g, border.b]

    def _render_text(self, widget: TextWidget):
        """PC字号按像素缩放；裁剪到文字控件及屏幕内，不覆盖邻居。"""
        pixels = self.text_pixels(widget)
        x1, y1 = max(0, widget.x), max(0, widget.y)
        x2 = min(self.width, widget.x + widget.width)
        y2 = min(self.height, widget.y + widget.height)
        if x1 >= x2 or y1 >= y2:
            return
        source = pixels[y1-widget.y:y2-widget.y, x1-widget.x:x2-widget.x]
        target = self.framebuffer[y1:y2, x1:x2]
        mask = source[:, :, 3] != 0
        target[mask] = source[:, :, :3][mask]

    @classmethod
    def text_pixels(cls, widget: TextWidget):
        """Transparent RGBA used by both the designer and PC runtime.

        The existing 8x16 ASCII font is kept; 16px remains pixel-identical.
        Arbitrary PC sizes use nearest-neighbor scaling, not the FPGA
        generator's separate two-step 5x7 font implementation.
        """
        return cls._scaled_text(widget.text, int(widget.font_size),
                                max(0, int(widget.width)), max(0, int(widget.height)),
                                widget.align, widget.color.r, widget.color.g, widget.color.b)

    @staticmethod
    @lru_cache(maxsize=64)
    def _scaled_text(text, font_size, width, height, align, red, green, blue):
        pixels = np.zeros((height, width, 4), dtype=np.uint8)
        # Guard manually authored JSON; designer offers the useful 8–72 range.
        size = max(1, min(256, font_size))
        cell_width = max(1, (size + 1) // 2)
        try:
            text.encode('ascii')
        except UnicodeEncodeError:
            return pixels
        text_width = len(text) * cell_width
        if align == 'center':
            x_start = max(0, width - text_width) // 2
        elif align == 'right':
            x_start = max(0, width - text_width)
        else:
            x_start = 0
        glyphs = PixelRenderer._font_glyphs()
        rows = np.arange(min(size, height)) * 16 // size
        cols = np.arange(cell_width) * 8 // cell_width
        for char_index, char in enumerate(text):
            x = x_start + char_index * cell_width
            if x >= width:
                break
            bitmap = glyphs.get(ord(char), glyphs.get(32, [0] * 16))
            bits = np.asarray(bitmap, dtype=np.uint8)[rows]
            count = min(cell_width, width - x)
            mask = ((bits[:, None] >> (7 - cols[:count])) & 1) != 0
            pixels[:len(rows), x:x+count][mask] = (red, green, blue, 255)
        pixels.setflags(write=False)
        return pixels

    @staticmethod
    @lru_cache(maxsize=1)
    def _font_glyphs():
        """Return a compact deterministic 8x16 ASCII font used by RTL."""
        # Parse the exact .mem file shipped with the generated RTL first.  It
        # keeps the PC reference renderer pixel-compatible for all printable
        # ASCII characters instead of silently blanking uncommon labels.
        mem_path = Path(__file__).parent.parent / "assets" / "fonts" / "font_8x16_full.mem"
        try:
            rows = []
            for raw_line in mem_path.read_text(encoding="utf-8").splitlines():
                line = raw_line.split("//", 1)[0].strip()
                if re.fullmatch(r"[0-9A-Fa-f]{2}", line):
                    rows.append(int(line, 16))
            if len(rows) >= 95 * 16:
                return {
                    0x20 + index: rows[index * 16:(index + 1) * 16]
                    for index in range(95)
                }
        except (OSError, ValueError):
            pass

        # Keep the reference implementation dependency-free.  The ROM remains
        # the source of truth for arbitrary glyphs; these common UI glyphs are
        # enough for the shipped scenes and keep preview/RTL geometry aligned.
        rows = {
            "A": [0x00,0x00,0x18,0x24,0x42,0x42,0x7E,0x42,0x42,0x42,0x00,0x00,0x00,0x00,0x00,0x00],
            "B": [0x00,0x00,0x7C,0x42,0x42,0x7C,0x42,0x42,0x42,0x7C,0x00,0x00,0x00,0x00,0x00,0x00],
            "C": [0x00,0x00,0x3C,0x42,0x40,0x40,0x40,0x40,0x42,0x3C,0x00,0x00,0x00,0x00,0x00,0x00],
            "D": [0x00,0x00,0x78,0x44,0x42,0x42,0x42,0x42,0x44,0x78,0x00,0x00,0x00,0x00,0x00,0x00],
            "E": [0x00,0x00,0x7E,0x40,0x40,0x7C,0x40,0x40,0x40,0x7E,0x00,0x00,0x00,0x00,0x00,0x00],
            "F": [0x00,0x00,0x7E,0x40,0x40,0x7C,0x40,0x40,0x40,0x40,0x00,0x00,0x00,0x00,0x00,0x00],
            "G": [0x00,0x00,0x3C,0x42,0x40,0x40,0x4E,0x42,0x42,0x3C,0x00,0x00,0x00,0x00,0x00,0x00],
            "I": [0x00,0x00,0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x7E,0x00,0x00,0x00,0x00,0x00,0x00],
            "N": [0x00,0x00,0x42,0x62,0x52,0x4A,0x46,0x42,0x42,0x42,0x00,0x00,0x00,0x00,0x00,0x00],
            "O": [0x00,0x00,0x3C,0x42,0x42,0x42,0x42,0x42,0x42,0x3C,0x00,0x00,0x00,0x00,0x00,0x00],
            "P": [0x00,0x00,0x7C,0x42,0x42,0x7C,0x40,0x40,0x40,0x40,0x00,0x00,0x00,0x00,0x00,0x00],
            "R": [0x00,0x00,0x7C,0x42,0x42,0x7C,0x48,0x44,0x42,0x42,0x00,0x00,0x00,0x00,0x00,0x00],
            "S": [0x00,0x00,0x3C,0x42,0x40,0x3C,0x02,0x42,0x42,0x3C,0x00,0x00,0x00,0x00,0x00,0x00],
            "T": [0x00,0x00,0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00],
            "V": [0x00,0x00,0x42,0x42,0x42,0x42,0x42,0x42,0x24,0x18,0x00,0x00,0x00,0x00,0x00,0x00],
            "W": [0x00,0x00,0x42,0x42,0x42,0x42,0x5A,0x5A,0x66,0x42,0x00,0x00,0x00,0x00,0x00,0x00],
            "Y": [0x00,0x00,0x42,0x42,0x24,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00],
            "0": [0x00,0x00,0x3C,0x42,0x46,0x4A,0x52,0x62,0x42,0x3C,0x00,0x00,0x00,0x00,0x00,0x00],
            "1": [0x00,0x00,0x18,0x38,0x18,0x18,0x18,0x18,0x18,0x7E,0x00,0x00,0x00,0x00,0x00,0x00],
            "2": [0x00,0x00,0x3C,0x42,0x02,0x04,0x18,0x20,0x40,0x7E,0x00,0x00,0x00,0x00,0x00,0x00],
            "4": [0x00,0x00,0x0C,0x14,0x24,0x44,0x7E,0x04,0x04,0x04,0x00,0x00,0x00,0x00,0x00,0x00],
            "7": [0x00,0x00,0x7E,0x02,0x04,0x08,0x10,0x20,0x20,0x20,0x00,0x00,0x00,0x00,0x00,0x00],
            " ": [0] * 16,
            ".": [0] * 14 + [0x18, 0x18],
            ":": [0,0,0x18,0x18,0,0,0,0,0x18,0x18,0,0,0,0,0,0],
            "-": [0] * 7 + [0x7E] + [0] * 8,
        }
        return {ord(key): value for key, value in rows.items()}

    def _render_bar(self, widget: BarWidget, value: int):
        """渲染进度条"""
        x1, y1 = widget.x, widget.y
        x2, y2 = x1 + widget.width, y1 + widget.height

        # 裁剪
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(self.width, x2), min(self.height, y2)

        if x1 >= x2 or y1 >= y2:
            return

        # 计算填充宽度（根据 max_value 缩放）
        # 如果 max_value 存在则使用它，否则假设 0-65535
        max_val = getattr(widget, 'max_value', 65535)
        filled_width = (value * widget.width) // max(1, max_val)
        filled_width = max(0, min(widget.width, filled_width))

        # 背景
        bg = widget.bg_color
        self.framebuffer[y1:y2, x1:x2] = [bg.r, bg.g, bg.b]

        # 前景
        if filled_width > 0:
            fg = widget.fg_color
            x_fill = min(x1 + filled_width, x2)
            self.framebuffer[y1:y2, x1:x_fill] = [fg.r, fg.g, fg.b]

    def _render_spectrum(self, widget: SpectrumWidget, fft_bins: List[int]):
        """渲染频谱分析器"""
        x1, y1 = widget.x, widget.y
        x2, y2 = x1 + widget.width, y1 + widget.height

        # 裁剪
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(self.width, x2), min(self.height, y2)

        if x1 >= x2 or y1 >= y2:
            return

        # 背景
        bg = widget.bg_color
        self.framebuffer[y1:y2, x1:x2] = [bg.r, bg.g, bg.b]

        if not fft_bins:
            return

        # 计算柱宽
        num_bars = min(widget.bars, len(fft_bins))
        if num_bars <= 0:
            return
        bar_width = widget.width // num_bars
        if bar_width < 1:
            return

        gap = max(1, bar_width // 8)  # 间隙
        actual_bar_width = bar_width - gap

        # 绘制每个柱子
        bar_color = widget.bar_color
        for i in range(num_bars):
            if i >= len(fft_bins):
                break

            # 计算柱子高度 (8位值 0-255)
            bin_value = min(255, max(0, fft_bins[i]))
            bar_height = (bin_value * widget.height) // 256
            bar_height = max(0, min(widget.height, bar_height))

            # 计算柱子位置
            bar_x = x1 + i * bar_width
            bar_y = y2 - bar_height

            # 绘制柱子
            if bar_height > 0 and bar_x + actual_bar_width <= x2:
                self.framebuffer[bar_y:y2, bar_x:bar_x+actual_bar_width] = [
                    bar_color.r, bar_color.g, bar_color.b
                ]

    def _render_waveform(self, widget: WaveformWidget, pcm_data: List[int]):
        """渲染波形"""
        x1, y1 = widget.x, widget.y
        x2, y2 = x1 + widget.width, y1 + widget.height

        # 裁剪
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(self.width, x2), min(self.height, y2)

        if x1 >= x2 or y1 >= y2:
            return

        # 背景
        bg = widget.bg_color
        self.framebuffer[y1:y2, x1:x2] = [bg.r, bg.g, bg.b]

        if not pcm_data or len(pcm_data) < 2:
            return

        # 绘制波形线
        line_color = widget.line_color
        center_y = (y1 + y2) // 2
        half_height = widget.height // 2

        num_samples = min(len(pcm_data), widget.width)

        for i in range(num_samples - 1):
            # 从 PCM 数据获取样本 (假设 -32768 到 32767)
            sample1 = pcm_data[i * len(pcm_data) // num_samples]
            sample2 = pcm_data[(i + 1) * len(pcm_data) // num_samples]

            # 转换为屏幕坐标
            y_sample1 = center_y - (sample1 * half_height) // 32768
            y_sample2 = center_y - (sample2 * half_height) // 32768

            # 裁剪
            y_sample1 = max(y1, min(y2 - 1, y_sample1))
            y_sample2 = max(y1, min(y2 - 1, y_sample2))

            x_pos1 = x1 + i
            x_pos2 = x1 + i + 1

            if x_pos2 >= x2:
                break

            # 绘制线段 (Bresenham 算法简化版)
            self._draw_line(
                x_pos1, y_sample1, x_pos2, y_sample2,
                line_color, widget.line_width
            )

    def _draw_line(self, x0: int, y0: int, x1: int, y1: int,
                   color: ColorRGB, width: int = 1):
        """绘制线段"""
        dx = abs(x1 - x0)
        dy = abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy

        while True:
            # 绘制点（考虑线宽）
            for w in range(width):
                py = y0 + w - width // 2
                if 0 <= py < self.height and 0 <= x0 < self.width:
                    self.framebuffer[py, x0] = [color.r, color.g, color.b]

            if x0 == x1 and y0 == y1:
                break

            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x0 += sx
            if e2 < dx:
                err += dx
                y0 += sy

    def _render_knob(self, widget: KnobWidget, value: int):
        """渲染旋钮"""
        cx = widget.x + widget.width // 2
        cy = widget.y + widget.height // 2
        radius = min(widget.width, widget.height) // 2

        # 绘制圆形背景
        bg = widget.bg_color
        for y in range(max(0, widget.y), min(self.height, widget.y + widget.height)):
            for x in range(max(0, widget.x), min(self.width, widget.x + widget.width)):
                dx = x - cx
                dy = y - cy
                if dx * dx + dy * dy <= radius * radius:
                    self.framebuffer[y, x] = [bg.r, bg.g, bg.b]

        # 绘制边框圆
        fg = widget.fg_color
        for y in range(max(0, widget.y), min(self.height, widget.y + widget.height)):
            for x in range(max(0, widget.x), min(self.width, widget.x + widget.width)):
                dx = x - cx
                dy = y - cy
                dist_sq = dx * dx + dy * dy
                if (radius - 2) ** 2 <= dist_sq <= radius ** 2:
                    self.framebuffer[y, x] = [fg.r, fg.g, fg.b]

        # 绘制指示线（从中心到边缘）
        # 将值映射到控件声明的角度范围，并限制到有效值域。
        value_range = widget.max_value - widget.min_value
        if value_range <= 0:
            normalized = 0.0
        else:
            normalized = (value - widget.min_value) / value_range
            normalized = max(0.0, min(1.0, normalized))
        angle = widget.min_angle + normalized * (widget.max_angle - widget.min_angle)

        # 转换为弧度
        # RTL uses 0 degrees at the top and positive angles clockwise;
        # convert that convention to the screen's standard x-right/y-down
        # trigonometric coordinates.
        rad = np.deg2rad(angle - 90)

        # 计算指示线终点
        indicator_length = int(radius * 0.8)
        end_x = int(cx + indicator_length * np.cos(rad))
        end_y = int(cy + indicator_length * np.sin(rad))

        # 绘制指示线
        self._draw_line(cx, cy, end_x, end_y, widget.pointer_color, 3)

    def _render_keyboard(self, widget: KeyboardWidget, key_states: List[bool]):
        """渲染键盘"""
        x1, y1 = widget.x, widget.y
        x2, y2 = x1 + widget.width, y1 + widget.height

        # 裁剪
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(self.width, x2), min(self.height, y2)

        if x1 >= x2 or y1 >= y2:
            return

        # 背景
        self.framebuffer[y1:y2, x1:x2] = [0, 0, 0]

        # 首先绘制所有白键
        white_key_color = widget.white_key_color
        black_key_color = widget.black_key_color
        pressed_color = widget.pressed_color

        # 键盘音符模式（C, C#, D, D#, E, F, F#, G, G#, A, A#, B）
        # True = 黑键, False = 白键
        is_black = [False, True, False, True, False, False, True, False, True, False, True, False]

        if widget.keys <= 0 or widget.width <= 0:
            return
        num_white_keys = sum(
            not is_black[(widget.start_note + i) % 12]
            for i in range(widget.keys)
        )
        if num_white_keys <= 0:
            return
        white_key_width = widget.width / num_white_keys

        if white_key_width < 2:
            return  # 太小无法绘制

        white_key_idx = 0
        for i in range(widget.keys):
            note = (widget.start_note + i) % 12

            if not is_black[note]:  # 白键
                key_x1 = int(x1 + white_key_idx * white_key_width)
                key_x2 = int(x1 + (white_key_idx + 1) * white_key_width)

                # 检查是否按下
                is_pressed = i < len(key_states) and key_states[i]
                color = pressed_color if is_pressed else white_key_color

                # 绘制白键
                self.framebuffer[y1:y2, key_x1:key_x2] = [color.r, color.g, color.b]

                # 绘制边框
                if key_x1 >= x1 and key_x1 < x2:
                    self.framebuffer[y1:y2, key_x1:key_x1+1] = [30, 30, 30]

                white_key_idx += 1

        # 然后绘制黑键（覆盖在白键上方）
        black_key_height = int(widget.height * 0.6)
        black_key_width_px = int(white_key_width * 0.6)

        white_key_idx = 0
        for i in range(widget.keys):
            note = (widget.start_note + i) % 12

            if is_black[note]:  # 黑键
                # 黑键位于两个白键之间
                key_center = int(x1 + white_key_idx * white_key_width)
                key_x1 = key_center - black_key_width_px // 2
                key_x2 = key_center + black_key_width_px // 2

                # 裁剪
                key_x1 = max(x1, key_x1)
                key_x2 = min(x2, key_x2)

                if key_x1 < key_x2:
                    # 检查是否按下
                    is_pressed = i < len(key_states) and key_states[i]
                    color = pressed_color if is_pressed else black_key_color

                    # 绘制黑键
                    self.framebuffer[y1:y1+black_key_height, key_x1:key_x2] = [
                        color.r, color.g, color.b
                    ]
            else:
                white_key_idx += 1

    def save_frame(self, filename: str):
        """保存帧到文件"""
        from PIL import Image
        img = Image.fromarray(self.framebuffer, 'RGB')
        img.save(filename)
        print(f"Saved frame to {filename}")


def test_render():
    """测试渲染器"""
    # 创建测试场景
    scene = UIScene(
        name="test",
        width=1280,
        height=720,
        bg_color=ColorRGB(5, 7, 12)
    )

    # 添加测试控件
    scene.widgets.append(PanelWidget(
        type="panel", name="bg",
        x=0, y=0, width=1280, height=720,
        bg_color=ColorRGB(10, 13, 18),
        border_width=0
    ))

    scene.widgets.append(SpectrumWidget(
        type="spectrum", name="spectrum",
        x=50, y=100, width=600, height=200,
        bars=64,
        bar_color=ColorRGB(56, 189, 248),
        bg_color=ColorRGB(10, 13, 18)
    ))

    scene.widgets.append(BarWidget(
        type="bar", name="bar1",
        x=100, y=350, width=300, height=20,
        source="ui_state[0]",
        fg_color=ColorRGB(56, 189, 248),
        bg_color=ColorRGB(30, 40, 60)
    ))

    scene.widgets.append(KeyboardWidget(
        type="keyboard", name="kbd",
        x=50, y=500, width=700, height=100,
        start_note=48,
        keys=25
    ))

    scene.widgets.append(KnobWidget(
        type="knob", name="knob1",
        x=800, y=100, width=80, height=80,
        source="ui_state[1]",
        min_value=0,
        max_value=127
    ))

    # 模拟状态
    ui_state = {
        "fft_bins": [int(128 + 100 * np.sin(i * 0.1)) for i in range(128)],
        "ui_state": [40000, 50000] + [32768] * 30,
        "key_states": [True, False, True, False] + [False] * 21,
    }

    # 渲染
    renderer = PixelRenderer()
    frame = renderer.render_scene(scene, ui_state)

    # 保存
    renderer.save_frame("test_render.png")


if __name__ == "__main__":
    test_render()
