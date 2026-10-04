#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
交互式预览窗口
支持旋钮拖动、琴键点击、键盘输入和实时动画
"""

from PySide6.QtWidgets import QDialog, QVBoxLayout, QLabel, QWidget
from PySide6.QtCore import QTimer, Qt, QPoint, QEvent
from PySide6.QtGui import QImage, QPixmap, QMouseEvent, QKeyEvent
import numpy as np
import re

try:
    from .pixel_renderer import PixelRenderer
    from .interactive_state import InteractiveState
    from .ui_schema import UIScene, KnobWidget, KeyboardWidget, BarWidget
except ImportError:
    from pixel_renderer import PixelRenderer
    from interactive_state import InteractiveState
    from ui_schema import UIScene, KnobWidget, KeyboardWidget, BarWidget


class InteractiveCanvas(QLabel):
    """可交互的画布"""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMouseTracking(True)
        self.setFocusPolicy(Qt.StrongFocus)  # 接受键盘焦点


class InteractivePreviewDialog(QDialog):
    """交互式预览对话框

    功能：
    - 鼠标拖动旋钮改变值
    - 鼠标点击琴键
    - 键盘按键映射到琴键（AWSEDFTGYH 对应白键）
    - 实时动画（频谱、波形）
    - 60 FPS 刷新
    """

    def __init__(self, scene: UIScene, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Interactive Preview - Drag knobs, click keys, use keyboard (ASDFGHJ)")
        self.resize(scene.width + 40, scene.height + 80)

        self.scene = scene
        scene.validate_navigation()
        self.current_page = scene.initial_page
        # Validate the same interaction contract used by RTL generation before
        # the window starts accepting input. This keeps a hand-edited scene
        # from failing later inside an event callback.
        try:
            from generator.rtl_generator import RTLGenerator
        except ImportError:
            from rtl_generator import RTLGenerator
        RTLGenerator.validate_interaction_rules(scene)
        self.renderer = PixelRenderer(scene.width, scene.height)
        self.state = InteractiveState()
        # Keep the owning keyboard with each mouse-pressed key. A key index
        # alone is ambiguous when a scene contains more than one keyboard.
        self._pressed_mouse_keys = []
        self._pressed_keyboard_keys = set()
        self._pressed_widget = None
        self._key_map = {
            Qt.Key_A: 0, Qt.Key_W: 1, Qt.Key_S: 2, Qt.Key_E: 3,
            Qt.Key_D: 4, Qt.Key_F: 5, Qt.Key_T: 6, Qt.Key_G: 7,
            Qt.Key_Y: 8, Qt.Key_H: 9, Qt.Key_U: 10, Qt.Key_J: 11,
            Qt.Key_K: 12,
        }
        self._bind_scene_sources()

        # 交互状态
        self.dragging_knob = None  # 当前拖动的旋钮
        self.drag_start_pos = None
        self.drag_start_value = 0
        self._knob_moved = False

        # UI
        layout = QVBoxLayout()

        # 提示标签
        self.info_label = QLabel("Drag knobs to adjust • Click piano keys • Keyboard: A W S E D F T G Y H U J")
        self.info_label.setStyleSheet("padding: 5px; background: #1a1d24; color: #a0aec0; font-size: 11px;")
        self.info_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.info_label)

        # 画布
        self.canvas = InteractiveCanvas()
        self.canvas.installEventFilter(self)  # 安装事件过滤器
        self.canvas.setFocus()
        layout.addWidget(self.canvas)

        # 状态栏
        self.status_label = QLabel("Ready")
        self.status_label.setStyleSheet("padding: 3px; background: #0f1419; color: #6b7280; font-size: 10px;")
        layout.addWidget(self.status_label)

        self.setLayout(layout)

        # 动画定时器（60 FPS）
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_frame)
        self.timer.start(16)  # ~60 FPS

        # 首次渲染
        self.update_frame()

    def update_frame(self):
        """更新一帧"""
        # 更新动画
        self.state.update_animation()

        # 渲染
        frame = self.renderer.render_scene(self.scene, self.state.to_dict(), self.current_page)

        # 转换为 QImage
        height, width, channels = frame.shape
        bytes_per_line = channels * width
        qimage = QImage(frame.data, width, height, bytes_per_line, QImage.Format_RGB888)

        # 显示
        pixmap = QPixmap.fromImage(qimage)
        self.canvas.setPixmap(pixmap)

        # 更新状态栏
        if self.dragging_knob:
            idx = self._get_knob_index(self.dragging_knob)
            if idx is not None:
                value = self.state.get_knob_value(idx)
                value_range = max(1, self.dragging_knob.max_value - self.dragging_knob.min_value)
                percent = int((value - self.dragging_knob.min_value) * 100 / value_range)
                self.status_label.setText(f"Knob {self.dragging_knob.name}: {percent}%")

    def eventFilter(self, obj, event):
        """事件过滤器"""
        if obj == self.canvas:
            if event.type() == QEvent.MouseButtonPress:
                self.mousePressEvent(event)
                return True
            elif event.type() == QEvent.MouseMove:
                self.mouseMoveEvent(event)
                return True
            elif event.type() == QEvent.MouseButtonRelease:
                self.mouseReleaseEvent(event)
                return True
            elif event.type() == QEvent.KeyPress:
                self.keyPressEvent(event)
                return True
            elif event.type() == QEvent.KeyRelease:
                self.keyReleaseEvent(event)
                return True
        return super().eventFilter(obj, event)

    def mousePressEvent(self, event: QMouseEvent):
        """鼠标按下"""
        if event.button() != Qt.LeftButton:
            return
        self.canvas.setFocus()
        pos = event.pos()

        # Hit testing must mirror the renderer: highest layer, then latest
        # scene entry, is the topmost visible widget.
        widget = self._hit_test(pos)
        if widget is None:
            return

        self._pressed_widget = widget
        if isinstance(widget, KnobWidget):
            self.dragging_knob = widget
            self.drag_start_pos = pos
            self._knob_moved = False
            idx = self._get_knob_index(widget)
            self.drag_start_value = (
                self.state.get_knob_value(idx)
                if idx is not None else self._default_knob_value(widget)
            )
            self._dispatch_interactions("press", widget)
            return

        if isinstance(widget, KeyboardWidget):
            key_idx = self._get_key_at_pos(widget, pos)
            if key_idx is not None:
                self.state.set_key_down(key_idx, True)
                self._pressed_mouse_keys.append((widget, key_idx))
                self._dispatch_interactions("key_down", widget, key_idx)
                self.status_label.setText(f"Key {key_idx} pressed")
            else:
                self._pressed_widget = None
            return

        self._dispatch_interactions("press", widget)

    def mouseMoveEvent(self, event: QMouseEvent):
        """鼠标移动"""
        if self.dragging_knob and self.drag_start_pos:
            # 垂直拖动改变旋钮值（向上增加，向下减少）
            delta_y = self.drag_start_pos.y() - event.pos().y()
            sensitivity = max(1.0, (self.dragging_knob.max_value - self.dragging_knob.min_value) / 160.0)

            new_value = self.drag_start_value + int(delta_y * sensitivity)
            new_value = max(self.dragging_knob.min_value,
                            min(self.dragging_knob.max_value, new_value))

            # 更新状态
            idx = self._get_knob_index(self.dragging_knob)
            if idx is not None and new_value != self.state.get_knob_value(idx):
                self._knob_moved = True
                self.state.set_knob_value(idx, new_value)
                self._dispatch_interactions("change", self.dragging_knob, new_value)

    def mouseReleaseEvent(self, event: QMouseEvent):
        """鼠标释放"""
        if event.button() != Qt.LeftButton:
            return
        # 释放旋钮
        if self.dragging_knob:
            widget = self.dragging_knob
            self._dispatch_interactions("release", widget)
            if not self._knob_moved and self._hit_test(event.pos()) is widget:
                self._dispatch_interactions("click", widget)
            self.dragging_knob = None
            self.drag_start_pos = None
            self._knob_moved = False
            self._pressed_widget = None
            self.status_label.setText("Ready")
            return

        # Release each mouse key exactly once, using the keyboard that owned
        # the press. Do not infer another key from the release position.
        if self._pressed_mouse_keys:
            pressed_mouse_keys = self._pressed_mouse_keys
            self._pressed_mouse_keys = []
            for widget, key_idx in pressed_mouse_keys:
                self.state.set_key_down(key_idx, False)
                self._dispatch_interactions("key_up", widget, key_idx)
            self._pressed_widget = None
            self.status_label.setText("Ready")
            return

        # A regular widget always receives release; click additionally
        # requires the pointer to still be over that same widget.
        if self._pressed_widget is not None:
            widget = self._pressed_widget
            self._pressed_widget = None
            self._dispatch_interactions("release", widget)
            if self._hit_test(event.pos()) is widget:
                self._dispatch_interactions("click", widget)
            self.status_label.setText("Ready")
            return

        self.status_label.setText("Ready")

    def _release_active_inputs(self):
        """Clear held inputs when the preview loses activation or closes."""
        if self.dragging_knob is not None:
            knob = self.dragging_knob
            self._dispatch_interactions("release", knob)
            if self._pressed_widget is knob:
                self._pressed_widget = None
        self.dragging_knob = None
        self.drag_start_pos = None
        self._knob_moved = False

        for widget, key_idx in self._pressed_mouse_keys:
            self.state.set_key_down(key_idx, False)
            self._dispatch_interactions("key_up", widget, key_idx)
        self._pressed_mouse_keys.clear()
        if self._pressed_widget is not None and isinstance(self._pressed_widget, KeyboardWidget):
            self._pressed_widget = None

        for key_idx in tuple(self._pressed_keyboard_keys):
            self.state.set_key_down(key_idx, False)
            for widget in self.scene.visible_widgets(self.current_page):
                if isinstance(widget, KeyboardWidget) and widget.visible:
                    self._dispatch_interactions("key_up", widget, key_idx)
        self._pressed_keyboard_keys.clear()
        if self._pressed_widget is not None:
            self._dispatch_interactions("release", self._pressed_widget)
        self._pressed_widget = None

    def keyPressEvent(self, event: QKeyEvent):
        """键盘按下 - 映射到琴键"""
        if event.isAutoRepeat():
            return

        if event.key() in self._key_map:
            key_idx = self._key_map[event.key()]
            if key_idx in self._pressed_keyboard_keys:
                return
            self._pressed_keyboard_keys.add(key_idx)
            self.state.set_key_down(key_idx, True)
            for widget in self.scene.visible_widgets(self.current_page):
                if isinstance(widget, KeyboardWidget) and widget.visible:
                    self._dispatch_interactions("key_down", widget, key_idx)
            self.status_label.setText(f"Key {key_idx} pressed (keyboard)")

    def keyReleaseEvent(self, event: QKeyEvent):
        """键盘释放"""
        if event.isAutoRepeat():
            return

        if event.key() in self._key_map:
            key_idx = self._key_map[event.key()]
            if key_idx not in self._pressed_keyboard_keys:
                return
            self._pressed_keyboard_keys.remove(key_idx)
            self.state.set_key_down(key_idx, False)
            for widget in self.scene.visible_widgets(self.current_page):
                if isinstance(widget, KeyboardWidget) and widget.visible:
                    self._dispatch_interactions("key_up", widget, key_idx)
            self.status_label.setText("Ready")

    def _dispatch_interactions(self, event_name: str, widget, event_value: int = 0):
        """Run JSON-defined actions for one preview event."""
        source = getattr(widget, "name", "")
        action = self.scene.local_actions.get(source)
        if event_name == 'click' and action:
            self.switch_page(action['target'])
            return
        for rule in self.scene.interactions:
            if not isinstance(rule, dict):
                continue
            trigger = str(rule.get("trigger", rule.get("event", ""))).lower()
            if trigger != event_name:
                continue
            rule_source = rule.get("source", rule.get("widget", ""))
            if rule_source and rule_source != source:
                continue
            key_filter = rule.get("key_index")
            if key_filter is not None:
                try:
                    if int(key_filter) != int(event_value):
                        continue
                except (TypeError, ValueError):
                    self.status_label.setText(f"Interaction error: invalid key_index {key_filter!r}")
                    continue
            actions = rule.get("actions", [rule])
            if isinstance(actions, dict):
                actions = [actions]
            for action in actions:
                if isinstance(action, dict):
                    try:
                        self.state.apply_action(action, event_value)
                    except (TypeError, ValueError, KeyError) as exc:
                        self.status_label.setText(f"Interaction error: {exc}")

    def _hit_test(self, pos: QPoint):
        """Return the topmost visible widget containing ``pos``."""
        ordered = sorted(
            self.scene.visible_widgets(self.current_page),
            key=lambda widget: widget.layer,
        )
        for widget in reversed(ordered):
            if self._point_in_widget(pos, widget):
                return widget
        return None

    def switch_page(self, page_id):
        if page_id not in {p['id'] for p in self.scene.pages}:
            raise ValueError('页面不存在')
        self._release_active_inputs()
        self.current_page = page_id
        self.update_frame()

    def _point_in_widget(self, pos: QPoint, widget) -> bool:
        """检查点是否在控件内"""
        return (widget.x <= pos.x() < widget.x + widget.width and
                widget.y <= pos.y() < widget.y + widget.height)

    def _get_knob_index(self, knob: KnobWidget) -> int:
        """从旋钮的 source 属性解析索引"""
        return self._get_source_index(knob.source)

    def _get_key_at_pos(self, keyboard: KeyboardWidget, pos: QPoint) -> int:
        """Map a point using the same white/black key geometry as rendering."""
        local_x = pos.x() - keyboard.x
        local_y = pos.y() - keyboard.y
        if (not (0 <= local_x < keyboard.width) or
                not (0 <= local_y < keyboard.height) or keyboard.keys <= 0):
            return None
        black_notes = {1, 3, 6, 8, 10}
        white_count = sum((keyboard.start_note + i) % 12 not in black_notes
                          for i in range(keyboard.keys))
        if white_count <= 0:
            return None
        white_width = keyboard.width / white_count
        black_width = white_width * 0.6
        white_before = 0
        for index in range(keyboard.keys):
            note = (keyboard.start_note + index) % 12
            if note in black_notes:
                center = white_before * white_width
                if (local_y < keyboard.height * 0.6 and
                        center - black_width / 2 <= local_x < center + black_width / 2):
                    return index
            else:
                white_before += 1
        white_index = min(white_count - 1, int(local_x / white_width))
        white_before = 0
        for index in range(keyboard.keys):
            if (keyboard.start_note + index) % 12 not in black_notes:
                if white_before == white_index:
                    return index
                white_before += 1
        return None

    def _default_knob_value(self, knob: KnobWidget) -> int:
        return knob.min_value + (knob.max_value - knob.min_value) // 2

    def _bind_scene_sources(self):
        next_index = 0
        for widget in self.scene.widgets:
            if isinstance(widget, (KnobWidget, BarWidget)) and widget.visible:
                if not isinstance(widget.source, str) or not widget.source.strip():
                    raise ValueError(
                        f"{widget.type} {widget.name or '<unnamed>'} source must be a non-empty string"
                    )
                index = self._get_source_index(widget.source)
                if index is None:
                    index = next_index
                next_index = max(next_index, index + 1)
                if index >= len(self.state.ui_values):
                    raise ValueError(
                        f"too many UI state sources; '{widget.source}' needs ui_state[{index}]"
                    )
                self.state.bind_source(widget.source, index)

    def _get_source_index(self, source):
        if isinstance(source, str):
            match = re.fullmatch(r"\s*ui_state\s*\[\s*(\d+)\s*\]\s*", source)
            if match:
                index = int(match.group(1))
                if index >= len(self.state.ui_values):
                    raise ValueError(f"source index out of range: {source}")
                return index
            if source.strip().lower().startswith("ui_state"):
                raise ValueError(f"invalid UI state source: {source}")
            match = re.fullmatch(r"\s*op(\d+)_level\s*", source, re.IGNORECASE)
            if match:
                index = int(match.group(1)) - 1
                if not 0 <= index < len(self.state.ui_values):
                    raise ValueError(f"source index out of range: {source}")
                return index
        return self.state.source_indices.get(source) if isinstance(source, str) else None

    def closeEvent(self, event):
        """关闭事件"""
        self._release_active_inputs()
        self.timer.stop()
        super().closeEvent(event)

    def changeEvent(self, event):
        if event.type() == QEvent.WindowDeactivate:
            self._release_active_inputs()
        super().changeEvent(event)
