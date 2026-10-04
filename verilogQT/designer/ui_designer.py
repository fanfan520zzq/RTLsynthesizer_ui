#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FPGA UI Designer - Main Application
基于 PySide6 的可视化 UI 设计器 - 完整版
"""

import sys
import json
import numpy as np
from pathlib import Path

# Prefer UTF-8 on Windows without replacing/closing the process streams when
# this module is imported by a test or another application.
if sys.platform == 'win32':
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QSplitter, QListWidget, QGraphicsView, QGraphicsScene,
    QPushButton, QLabel, QSpinBox, QLineEdit, QComboBox,
    QGroupBox, QFormLayout, QColorDialog, QFileDialog, QMessageBox,
    QGraphicsRectItem, QGraphicsTextItem, QDialog, QCheckBox,
    QPlainTextEdit, QDialogButtonBox, QScrollArea, QLayout, QInputDialog
)
from PySide6.QtCore import Qt, QRectF, QPointF, Signal, QTimer
from PySide6.QtGui import QColor, QPen, QBrush, QPainter, QImage, QPixmap

try:
    # Package imports (for example ``python -m designer.ui_designer``).
    from .ui_schema import *
    from .pixel_renderer import PixelRenderer
    from .color_editor import ColorEditor
except ImportError:
    # Keep the existing direct/script entry points working.
    from ui_schema import *
    from pixel_renderer import PixelRenderer
    from color_editor import ColorEditor


class DesignCanvas(QGraphicsView):
    """设计画布"""

    widget_selected = Signal(object)
    widget_moved = Signal(object)
    scene_changed = Signal()
    panel_size_changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.scene = QGraphicsScene()
        self.setScene(self.scene)

        self.setBackgroundBrush(QBrush(QColor(5, 7, 12)))
        # 编辑器窗口可以变大，但屏幕区域始终保持场景的原始像素尺寸。
        self.setStyleSheet('QGraphicsView { border: 1px solid #38bdf8; }')
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setAlignment(Qt.AlignLeft | Qt.AlignTop)

        # 抗锯齿
        self.setRenderHint(QPainter.Antialiasing)

        self.ui_scene = UIScene()
        self.ui_scene.name = "new_scene"
        self.ui_scene.width = 800
        self.ui_scene.height = 480
        self.ui_scene.bg_color = ColorRGB(5, 7, 12)
        self.current_page = ''
        # 800x480 画布
        self.scene.setSceneRect(0, 0, self.ui_scene.width, self.ui_scene.height)
        self._sync_panel_size()

        self.selected_widget = None
        self.widget_graphics_map = {}  # widget -> graphics item 映射
        self._drag = None

    def _sync_panel_size(self):
        """固定可见屏幕大小，不缩放控件，不改变 JSON 的逻辑坐标。"""
        self.ensurePolished()
        border = 2 * self.frameWidth()
        self.setFixedSize(self.ui_scene.width + border,
                          self.ui_scene.height + border)
        self.panel_size_changed.emit()

    def add_widget(self, widget_type: str):
        """添加控件"""
        # 默认位置和大小
        x, y = 100, 100
        w, h = 200, 100

        if widget_type == "panel":
            widget = PanelWidget(
                type="panel", name=f"panel_{len(self.ui_scene.widgets)}",
                x=x, y=y, width=w, height=h,
                bg_color=ColorRGB(15, 19, 28),
                border_color=ColorRGB(50, 70, 100),
                border_width=2
            )
        elif widget_type == "text":
            widget = TextWidget(
                type="text", name=f"text_{len(self.ui_scene.widgets)}",
                x=x, y=y, width=w, height=30,
                text="Text Label",
                font_size=16,
                color=ColorRGB(200, 210, 230)
            )
        elif widget_type == "bar":
            widget = BarWidget(
                type="bar", name=f"bar_{len(self.ui_scene.widgets)}",
                x=x, y=y, width=w, height=20,
                source="ui_state[0]",
                max_value=100,
                fg_color=ColorRGB(56, 189, 248),
                bg_color=ColorRGB(30, 40, 60)
            )
        elif widget_type == "spectrum":
            widget = SpectrumWidget(
                type="spectrum", name=f"spectrum_{len(self.ui_scene.widgets)}",
                x=x, y=y, width=600, height=240,
                bars=64,
                source="fft_bins",
                bar_color=ColorRGB(56, 189, 248),
                bg_color=ColorRGB(10, 13, 18)
            )
        elif widget_type == "waveform":
            widget = WaveformWidget(
                type="waveform", name=f"waveform_{len(self.ui_scene.widgets)}",
                x=x, y=y, width=600, height=200,
                samples=1024,
                source="pcm_buffer",
                line_color=ColorRGB(110, 231, 183),
                bg_color=ColorRGB(10, 13, 18),
                line_width=2
            )
        elif widget_type == "keyboard":
            widget = KeyboardWidget(
                type="keyboard", name=f"keyboard_{len(self.ui_scene.widgets)}",
                x=x, y=y, width=700, height=120,
                start_note=48,
                keys=25,
                source="key_states",
                white_key_color=ColorRGB(240, 240, 245),
                black_key_color=ColorRGB(20, 25, 35),
                pressed_color=ColorRGB(56, 189, 248)
            )
        elif widget_type == "knob":
            widget = KnobWidget(
                type="knob", name=f"knob_{len(self.ui_scene.widgets)}",
                x=x, y=y, width=80, height=80,
                source="ui_state[0]",
                min_value=0,
                max_value=127,
                fg_color=ColorRGB(56, 189, 248),
                bg_color=ColorRGB(30, 40, 60)
            )
        else:
            return

        widget.page = self.current_page
        self.ui_scene.widgets.append(widget)
        self.redraw()
        self.scene_changed.emit()

    def load_scene(self, scene: UIScene):
        """加载场景"""
        self.ui_scene = scene
        self.current_page = scene.initial_page
        self.selected_widget = None
        self.redraw()
        self.scene_changed.emit()

    def set_page(self, page_id):
        if page_id not in {'', *(p['id'] for p in self.ui_scene.pages)}:
            raise ValueError('页面不存在')
        self.current_page = page_id
        self.selected_widget = None
        self.redraw()
        self.widget_selected.emit(None)

    def redraw(self):
        """重绘画布"""
        # Properties/load/delete may rebuild the graphics items. Never keep
        # a drag reference to an item deleted by scene.clear().
        self._drag = None
        self.scene.clear()
        self.widget_graphics_map.clear()
        if self.current_page not in {'', *(p['id'] for p in self.ui_scene.pages)}:
            self.current_page = self.ui_scene.initial_page

        self.scene.setSceneRect(
            0, 0, self.ui_scene.width, self.ui_scene.height
        )
        self._sync_panel_size()

        # 更新背景色
        bg = self.ui_scene.bg_color
        self.setBackgroundBrush(QBrush(QColor(bg.r, bg.g, bg.b)))

        # Match the reference renderer: hidden widgets are skipped and
        # visible widgets are painted from low to high layer.
        for widget in sorted(self.ui_scene.visible_widgets(self.current_page), key=lambda item: item.layer):
            if not widget.visible:
                continue

            if widget.type == "panel":
                item = self._draw_panel(widget)
            elif widget.type == "text":
                item = self._draw_text(widget)
            elif widget.type == "bar":
                item = self._draw_bar(widget)
            elif widget.type == "spectrum":
                item = self._draw_spectrum(widget)
            elif widget.type == "waveform":
                item = self._draw_waveform(widget)
            elif widget.type == "keyboard":
                item = self._draw_keyboard(widget)
            elif widget.type == "knob":
                item = self._draw_knob(widget)
            else:
                continue

            if item:
                # Dataclass widgets are mutable and therefore unhashable.
                self.widget_graphics_map[id(widget)] = item
                item.setSelected(widget is self.selected_widget)

    def _draw_panel(self, widget: PanelWidget):
        """绘制面板"""
        bg = widget.bg_color
        border = widget.border_color
        action = self.ui_scene.local_actions.get(widget.name)
        border_width = max(3, widget.border_width) if action and action['target'] == self.current_page else widget.border_width

        rect = self.scene.addRect(
            widget.x, widget.y, widget.width, widget.height,
            QPen(QColor(border.r, border.g, border.b), border_width),
            QBrush(QColor(bg.r, bg.g, bg.b))
        )
        rect.setData(0, widget)
        rect.setFlag(QGraphicsRectItem.ItemIsSelectable)
        return rect

    def _draw_text(self, widget: TextWidget):
        """与PC运行/预览共用字号、颜色和裁剪，透明区域也可选中拖动。"""
        root = self.scene.addRect(widget.x, widget.y, widget.width, widget.height,
                                  QPen(Qt.NoPen), QBrush(Qt.NoBrush))
        root.setData(0, widget)
        root.setFlag(QGraphicsRectItem.ItemIsSelectable)
        pixels = PixelRenderer.text_pixels(widget)
        if widget.width > 0 and widget.height > 0:
            image = QImage(pixels.data, widget.width, widget.height,
                           widget.width * 4, QImage.Format_RGBA8888)
            text = self.scene.addPixmap(QPixmap.fromImage(image))
            text.setPos(widget.x, widget.y)
            text.setParentItem(root)
        return root

    def _draw_bar(self, widget: BarWidget):
        """绘制进度条"""
        # 背景
        bg_rect = self.scene.addRect(
            widget.x, widget.y, widget.width, widget.height,
            QPen(Qt.NoPen),
            QBrush(QColor(widget.bg_color.r, widget.bg_color.g, widget.bg_color.b))
        )
        bg_rect.setData(0, widget)
        bg_rect.setFlag(QGraphicsRectItem.ItemIsSelectable)

        # 前景 (50% 示例)
        fg_width = widget.width // 2
        fg_rect = self.scene.addRect(
            widget.x, widget.y, fg_width, widget.height,
            QPen(Qt.NoPen),
            QBrush(QColor(widget.fg_color.r, widget.fg_color.g, widget.fg_color.b))
        )
        fg_rect.setParentItem(bg_rect)

        return bg_rect

    def _draw_spectrum(self, widget: SpectrumWidget):
        """绘制频谱占位"""
        rect = self.scene.addRect(
            widget.x, widget.y, widget.width, widget.height,
            QPen(QColor(widget.bar_color.r, widget.bar_color.g, widget.bar_color.b), 2),
            QBrush(QColor(widget.bg_color.r, widget.bg_color.g, widget.bg_color.b))
        )
        rect.setData(0, widget)
        rect.setFlag(QGraphicsRectItem.ItemIsSelectable)

        label = self.scene.addText(f"SPECTRUM\n{widget.bars} bars")
        label.setPos(widget.x + 10, widget.y + 10)
        label.setDefaultTextColor(QColor(widget.bar_color.r, widget.bar_color.g, widget.bar_color.b))
        label.setParentItem(rect)

        return rect

    def _draw_waveform(self, widget: WaveformWidget):
        """绘制波形占位"""
        rect = self.scene.addRect(
            widget.x, widget.y, widget.width, widget.height,
            QPen(QColor(widget.line_color.r, widget.line_color.g, widget.line_color.b), 2),
            QBrush(QColor(widget.bg_color.r, widget.bg_color.g, widget.bg_color.b))
        )
        rect.setData(0, widget)
        rect.setFlag(QGraphicsRectItem.ItemIsSelectable)

        label = self.scene.addText(f"WAVEFORM\n{widget.samples} samples")
        label.setPos(widget.x + 10, widget.y + 10)
        label.setDefaultTextColor(QColor(widget.line_color.r, widget.line_color.g, widget.line_color.b))
        label.setParentItem(rect)

        return rect

    def _draw_keyboard(self, widget: KeyboardWidget):
        """绘制键盘占位"""
        rect = self.scene.addRect(
            widget.x, widget.y, widget.width, widget.height,
            QPen(QColor(widget.black_key_color.r, widget.black_key_color.g, widget.black_key_color.b), 2),
            QBrush(QColor(widget.white_key_color.r, widget.white_key_color.g, widget.white_key_color.b))
        )
        rect.setData(0, widget)
        rect.setFlag(QGraphicsRectItem.ItemIsSelectable)

        label = self.scene.addText(f"KEYBOARD\n{widget.keys} keys from note {widget.start_note}")
        label.setPos(widget.x + 10, widget.y + 10)
        label.setDefaultTextColor(QColor(widget.pressed_color.r, widget.pressed_color.g, widget.pressed_color.b))
        label.setParentItem(rect)

        return rect

    def _draw_knob(self, widget: KnobWidget):
        """绘制旋钮占位"""
        ellipse = self.scene.addEllipse(
            widget.x, widget.y, widget.width, widget.height,
            QPen(QColor(widget.fg_color.r, widget.fg_color.g, widget.fg_color.b), 2),
            QBrush(QColor(widget.bg_color.r, widget.bg_color.g, widget.bg_color.b))
        )
        ellipse.setData(0, widget)
        ellipse.setFlag(QGraphicsRectItem.ItemIsSelectable)
        pointer = self.scene.addLine(
            widget.x + widget.width // 2, widget.y + widget.height // 2,
            widget.x + widget.width // 2, widget.y + 4,
            QPen(QColor(widget.pointer_color.r, widget.pointer_color.g, widget.pointer_color.b), 3)
        )
        pointer.setParentItem(ellipse)

        return ellipse

    def mousePressEvent(self, event):
        """选择最上层控件；坐标拖动由视图统一管理，复合图元一起移动。"""
        if event.button() != Qt.LeftButton:
            super().mousePressEvent(event)
            return
        self.setFocus()
        position = event.position().toPoint()
        item = self.itemAt(position)
        # A bar's foreground or a placeholder label belongs to its parent,
        # not a second independently selectable/draggable widget.
        while item is not None and item.data(0) is None:
            item = item.parentItem()
        widget = item.data(0) if item is not None else None
        self.scene.clearSelection()
        self.selected_widget = widget
        self._drag = None
        if widget is not None:
            item.setSelected(True)
            self._drag = (widget, item, self.mapToScene(position),
                          QPointF(widget.x, widget.y), QPointF(item.pos()))
        self.widget_selected.emit(widget)
        event.accept()

    def _move_drag(self, position):
        if self._drag is None:
            return
        widget, item, start_mouse, start_model, start_item = self._drag
        delta = self.mapToScene(position) - start_mouse
        x = max(0, min(max(0, self.ui_scene.width-widget.width), round(start_model.x()+delta.x())))
        y = max(0, min(max(0, self.ui_scene.height-widget.height), round(start_model.y()+delta.y())))
        if (widget.x, widget.y) == (x, y):
            return
        widget.x, widget.y = x, y
        # Rect/ellipse geometry uses scene coordinates while text starts at
        # item.pos(). Apply a delta to the original position for both cases.
        item.setPos(start_item + QPointF(x, y) - start_model)
        self.widget_moved.emit(widget)
        self.scene_changed.emit()

    def mouseMoveEvent(self, event):
        if self._drag is not None:
            self._move_drag(event.position().toPoint())
            event.accept()
        else:
            super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.LeftButton and self._drag is not None:
            self._move_drag(event.position().toPoint())
            self._drag = None
            event.accept()
        else:
            super().mouseReleaseEvent(event)

    def focusOutEvent(self, event):
        # Already displayed moves stay committed; a later mouse move must not
        # continue a gesture after the user switches away from this canvas.
        self._drag = None
        super().focusOutEvent(event)

    def delete_selected(self):
        """删除选中的控件"""
        if self.selected_widget and self.selected_widget in self.ui_scene.widgets:
            self.ui_scene.pc_bindings.pop(self.selected_widget.name, None)
            self.ui_scene.local_actions.pop(self.selected_widget.name, None)
            self.ui_scene.widgets.remove(self.selected_widget)
            self.selected_widget = None
            self.redraw()
            self.scene_changed.emit()


class PropertyPanel(QWidget):
    """属性面板"""

    property_changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.current_widget = None
        self.canvas = None
        self.init_ui()

    def set_canvas(self, canvas):
        """设置画布引用"""
        self.canvas = canvas
        self.canvas.panel_size_changed.connect(self.sync_scene_color)
        self.sync_scene_color()

    def sync_scene_color(self):
        if self.canvas:
            self.scene_color_editor.set_color(self.canvas.ui_scene.bg_color)

    def on_scene_color_changed(self, color):
        if self.canvas:
            self.canvas.ui_scene.bg_color = color
            self.canvas.redraw()
            self.property_changed.emit()

    def clear_widget(self):
        """清除已删除或已卸载控件的属性引用。"""
        self.current_widget = None
        self.color_editors.clear()
        self.blockSignals(True)
        try:
            self.name_edit.clear()
            self.x_spin.setValue(0)
            self.y_spin.setValue(0)
            self.width_spin.setValue(1)
            self.height_spin.setValue(1)
            self.visible_check.setChecked(False)
            while self.special_layout.rowCount() > 0:
                self.special_layout.removeRow(0)
        finally:
            self.blockSignals(False)

    def init_ui(self):
        layout = QVBoxLayout()

        layout.setSizeConstraint(QLayout.SetMinimumSize)

        self.title_label = QLabel("Properties")
        self.title_label.setStyleSheet("font-weight: bold; font-size: 14px;")
        layout.addWidget(self.title_label)

        scene_group = QGroupBox('画布颜色')
        scene_layout = QFormLayout(scene_group)
        self.scene_color_editor = ColorEditor(ColorRGB(5, 7, 12))
        self.scene_color_editor.color_changed.connect(self.on_scene_color_changed)
        scene_layout.addRow('背景色:', self.scene_color_editor)
        layout.addWidget(scene_group)
        self.color_editors = {}

        # 基本属性组
        basic_group = QGroupBox("Basic")
        basic_layout = QFormLayout()

        self.name_edit = QLineEdit()
        self.name_edit.textChanged.connect(self.on_property_changed)

        self.x_spin = QSpinBox()
        self.x_spin.setRange(0, 800)
        self.x_spin.valueChanged.connect(self.on_property_changed)

        self.y_spin = QSpinBox()
        self.y_spin.setRange(0, 480)
        self.y_spin.valueChanged.connect(self.on_property_changed)

        self.width_spin = QSpinBox()
        self.width_spin.setRange(1, 800)
        self.width_spin.valueChanged.connect(self.on_property_changed)

        self.height_spin = QSpinBox()
        self.height_spin.setRange(1, 480)
        self.height_spin.valueChanged.connect(self.on_property_changed)

        self.visible_check = QCheckBox()
        self.visible_check.setChecked(True)
        self.visible_check.stateChanged.connect(self.on_property_changed)

        basic_layout.addRow("Name:", self.name_edit)
        basic_layout.addRow("X:", self.x_spin)
        basic_layout.addRow("Y:", self.y_spin)
        basic_layout.addRow("Width:", self.width_spin)
        basic_layout.addRow("Height:", self.height_spin)
        basic_layout.addRow("Visible:", self.visible_check)

        basic_group.setLayout(basic_layout)
        layout.addWidget(basic_group)

        # 特殊属性组
        self.special_group = QGroupBox("Widget Properties")
        self.special_layout = QFormLayout()
        self.special_layout.setSizeConstraint(QLayout.SetMinimumSize)
        self.special_group.setLayout(self.special_layout)
        layout.addWidget(self.special_group)

        layout.addStretch()
        self.setLayout(layout)

    def on_property_changed(self):
        """属性修改"""
        if self.current_widget:
            # 更新基本属性
            old_name = self.current_widget.name
            self.current_widget.name = self.name_edit.text()
            if self.canvas and old_name != self.current_widget.name:
                for mapping in (self.canvas.ui_scene.pc_bindings, self.canvas.ui_scene.local_actions):
                    if old_name in mapping:
                        mapping[self.current_widget.name] = mapping.pop(old_name)
            self.current_widget.x = self.x_spin.value()
            self.current_widget.y = self.y_spin.value()
            self.current_widget.width = self.width_spin.value()
            self.current_widget.height = self.height_spin.value()
            self.current_widget.visible = self.visible_check.isChecked()

            # 重绘画布
            if self.canvas:
                self.canvas.redraw()

            self.property_changed.emit()

    def load_widget(self, widget: Widget):
        """加载控件属性"""
        # Ignore value-change signals while replacing the editor contents.
        # QSignalBlocker on the panel itself does not block child widgets.
        self.current_widget = None

        self.color_editors.clear()

        # 阻止信号触发
        self.blockSignals(True)

        scene_width = self.canvas.ui_scene.width if self.canvas else 800
        scene_height = self.canvas.ui_scene.height if self.canvas else 480
        self.x_spin.setRange(0, max(0, scene_width))
        self.y_spin.setRange(0, max(0, scene_height))
        self.width_spin.setRange(1, max(1, scene_width))
        self.height_spin.setRange(1, max(1, scene_height))
        self.name_edit.setText(widget.name)
        self.x_spin.setValue(widget.x)
        self.y_spin.setValue(widget.y)
        self.width_spin.setValue(widget.width)
        self.height_spin.setValue(widget.height)
        self.visible_check.setChecked(widget.visible)

        self.page_combo = QComboBox()
        self.page_combo.addItem('公共（所有页）', '')
        for page in self.canvas.ui_scene.pages if self.canvas else []:
            self.page_combo.addItem(page['title'], page['id'])
        self.page_combo.setCurrentIndex(max(0, self.page_combo.findData(widget.page)))

        # 清空特殊属性
        while self.special_layout.rowCount() > 0:
            self.special_layout.removeRow(0)
        self.special_layout.addRow('所属页面:', self.page_combo)
        self.page_combo.currentIndexChanged.connect(self.on_widget_page_changed)

        if widget.type in ('panel', 'text') and self.canvas:
            self.navigation_combo = QComboBox()
            self.navigation_combo.addItem('无（保留串口绑定）', '')
            for page in self.canvas.ui_scene.pages:
                self.navigation_combo.addItem('切换到：' + page['title'], page['id'])
            action = self.canvas.ui_scene.local_actions.get(widget.name, {})
            self.navigation_combo.setCurrentIndex(max(0, self.navigation_combo.findData(action.get('target', ''))))
            self.special_layout.addRow('点击动作:', self.navigation_combo)
            self.navigation_combo.currentIndexChanged.connect(self.on_navigation_changed)

        # 根据类型添加特殊属性
        if widget.type == "text":
            text_edit = QLineEdit(widget.text)
            text_edit.textChanged.connect(lambda: setattr(widget, 'text', text_edit.text()))
            text_edit.textChanged.connect(self.on_property_changed)
            self.special_layout.addRow("Text:", text_edit)

            source_edit = QLineEdit(getattr(widget, 'source', ''))
            source_edit.setPlaceholderText("empty=static, filename=FPGA status")
            source_edit.textChanged.connect(lambda: setattr(widget, 'source', source_edit.text()))
            source_edit.textChanged.connect(self.on_property_changed)
            self.special_layout.addRow("Source:", source_edit)

            font_spin = QSpinBox()
            self.font_size_spin = font_spin
            font_spin.setObjectName('textFontSize')
            font_spin.setRange(8, 72)
            font_spin.setSuffix(' px')
            font_spin.setToolTip('PC字号按像素调整；放大后请同时检查文字控件的宽、高。FPGA字号仍按生成器规则。')
            font_spin.setValue(widget.font_size)
            font_spin.valueChanged.connect(lambda v: setattr(widget, 'font_size', v))
            font_spin.valueChanged.connect(self.on_property_changed)
            self.special_layout.addRow("字号:", font_spin)

        elif widget.type == "bar":
            source_edit = QLineEdit(widget.source)
            source_edit.textChanged.connect(lambda: setattr(widget, 'source', source_edit.text()))
            source_edit.textChanged.connect(self.on_property_changed)
            self.special_layout.addRow("Source:", source_edit)

            max_spin = QSpinBox()
            max_spin.setRange(1, 65535)
            max_spin.setValue(widget.max_value)
            max_spin.valueChanged.connect(lambda v: setattr(widget, 'max_value', v))
            max_spin.valueChanged.connect(self.on_property_changed)
            self.special_layout.addRow("Max Value:", max_spin)

        elif widget.type == "spectrum":
            bars_spin = QSpinBox()
            # The flattened RTL interface exposes 128 FFT bins.
            bars_spin.setRange(1, 128)
            bars_spin.setValue(widget.bars)
            bars_spin.valueChanged.connect(lambda v: setattr(widget, 'bars', v))
            bars_spin.valueChanged.connect(self.on_property_changed)
            self.special_layout.addRow("Bars:", bars_spin)

            source_edit = QLineEdit(widget.source)
            source_edit.textChanged.connect(lambda: setattr(widget, 'source', source_edit.text()))
            source_edit.textChanged.connect(self.on_property_changed)
            self.special_layout.addRow("Source:", source_edit)

        elif widget.type == "waveform":
            samples_spin = QSpinBox()
            # The current RTL bus contains 1024 PCM samples.
            samples_spin.setRange(1, 1024)
            samples_spin.setValue(widget.samples)
            samples_spin.valueChanged.connect(lambda v: setattr(widget, 'samples', v))
            samples_spin.valueChanged.connect(self.on_property_changed)
            self.special_layout.addRow("Samples:", samples_spin)

            source_edit = QLineEdit(widget.source)
            source_edit.textChanged.connect(lambda: setattr(widget, 'source', source_edit.text()))
            source_edit.textChanged.connect(self.on_property_changed)
            self.special_layout.addRow("Source:", source_edit)

        elif widget.type == "knob":
            source_edit = QLineEdit(widget.source)
            source_edit.textChanged.connect(lambda: setattr(widget, 'source', source_edit.text()))
            source_edit.textChanged.connect(self.on_property_changed)
            self.special_layout.addRow("Source:", source_edit)
            for field, label in (("min_value", "Min Value:"), ("max_value", "Max Value:")):
                spin = QSpinBox()
                spin.setRange(0, 65535)
                spin.setValue(getattr(widget, field))
                spin.valueChanged.connect(lambda value, key=field: setattr(widget, key, value))
                spin.valueChanged.connect(self.on_property_changed)
                self.special_layout.addRow(label, spin)

        elif widget.type == "keyboard":
            start_spin = QSpinBox()
            start_spin.setRange(0, 127)
            start_spin.setValue(widget.start_note)
            start_spin.valueChanged.connect(lambda v: setattr(widget, 'start_note', v))
            start_spin.valueChanged.connect(self.on_property_changed)
            self.special_layout.addRow("Start Note:", start_spin)

            keys_spin = QSpinBox()
            keys_spin.setRange(1, max(1, 128 - widget.start_note))
            keys_spin.setValue(widget.keys)
            keys_spin.valueChanged.connect(lambda v: setattr(widget, 'keys', v))
            keys_spin.valueChanged.connect(self.on_property_changed)
            start_spin.valueChanged.connect(
                lambda v: keys_spin.setMaximum(max(1, 128 - v))
            )
            self.special_layout.addRow("Keys:", keys_spin)

        # 只展示现有渲染路径实际使用的颜色，避免无效果的属性入口。
        color_fields = {
            'panel': [('bg_color', '背景色'), ('border_color', '边框色')],
            'text': [('color', '文字色')],
            'bar': [('fg_color', '前景色'), ('bg_color', '背景色')],
            'spectrum': [('bar_color', '柱状色'), ('bg_color', '背景色')],
            'waveform': [('line_color', '线条色'), ('bg_color', '背景色')],
            'knob': [('fg_color', '轮廓色'), ('bg_color', '背景色'), ('pointer_color', '指针色')],
            'keyboard': [('white_key_color', '白键色'), ('black_key_color', '黑键色'), ('pressed_color', '按下色')],
        }
        for field, label in color_fields.get(widget.type, []):
            editor = ColorEditor(getattr(widget, field))
            editor.color_changed.connect(
                lambda color, target=widget, key=field: self.on_widget_color_changed(target, key, color)
            )
            self.color_editors[field] = editor
            self.special_layout.addRow(label + ':', editor)

        # 恢复信号
        self.blockSignals(False)
        self.current_widget = widget

    def on_widget_color_changed(self, widget, field, color):
        if self.current_widget is widget:
            setattr(widget, field, color)
            if self.canvas:
                self.canvas.redraw()
            self.property_changed.emit()

    def on_widget_page_changed(self, *_):
        if not self.current_widget or not self.canvas:
            return
        self.current_widget.page = self.page_combo.currentData()
        self.canvas.redraw()
        self.property_changed.emit()

    def on_navigation_changed(self, *_):
        widget = self.current_widget
        if not widget or not self.canvas:
            return
        target = self.navigation_combo.currentData()
        if target and widget.name in self.canvas.ui_scene.pc_bindings:
            self.navigation_combo.blockSignals(True)
            self.navigation_combo.setCurrentIndex(0)
            self.navigation_combo.blockSignals(False)
            QMessageBox.warning(self, '绑定冲突', '该控件已有串口绑定。请先在PC Bindings中解除，或新建导航按钮。')
            return
        if target:
            self.canvas.ui_scene.local_actions[widget.name] = {'action': 'switch_page', 'target': target}
        else:
            self.canvas.ui_scene.local_actions.pop(widget.name, None)
        self.canvas.redraw()
        self.property_changed.emit()


class PreviewDialog(QDialog):
    """预览对话框"""

    def __init__(self, image: QImage, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Preview - Rendered Frame")
        self.setGeometry(100, 100, 1300, 750)

        layout = QVBoxLayout()

        label = QLabel()
        pixmap = QPixmap.fromImage(image)
        label.setPixmap(pixmap)
        label.setScaledContents(False)

        layout.addWidget(label)
        self.setLayout(layout)


class InteractionEditorDialog(QDialog):
    """Edit scene interaction rules as readable JSON."""

    def __init__(self, scene: UIScene, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Edit Interactions")
        self.resize(720, 520)
        self.scene = scene
        layout = QVBoxLayout(self)
        layout.addWidget(QLabel(
            'Rules use trigger/source/actions. Example: '
            '{"trigger":"click","source":"button_0",'
            '"actions":[{"action":"set","target":"ui_state[0]","value":65535}]}'
        ))
        self.editor = QPlainTextEdit()
        self.editor.setPlainText(json.dumps(scene.interactions, indent=2, ensure_ascii=True))
        layout.addWidget(self.editor)
        buttons = QDialogButtonBox(QDialogButtonBox.Save | QDialogButtonBox.Cancel)
        buttons.accepted.connect(self._save)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def _save(self):
        try:
            rules = json.loads(self.editor.toPlainText() or "[]")
            if not isinstance(rules, list) or any(not isinstance(item, dict) for item in rules):
                raise ValueError("interactions must be a JSON array of objects")
            # Use the same rule validator as RTL generation so a preview cannot
            # accept a JSON rule that will later crash or generate differently.
            from generator.rtl_generator import RTLGenerator
            candidate = UIScene(
                name=self.scene.name,
                width=self.scene.width,
                height=self.scene.height,
                bg_color=self.scene.bg_color,
                widgets=self.scene.widgets,
                interactions=rules,
            )
            RTLGenerator.validate_interaction_rules(candidate)
            self.scene.interactions = rules
            self.accept()
        except (json.JSONDecodeError, ValueError, TypeError, ImportError) as exc:
            QMessageBox.warning(self, "Invalid interactions", str(exc))


class PCBindingEditorDialog(InteractionEditorDialog):
    """Keep hardware mappings editable without mixing them with local actions."""

    def __init__(self, scene, parent=None):
        super().__init__(scene, parent)
        self.setWindowTitle("PC Bindings - Dimension")
        self.layout().itemAt(0).widget().setText(
            '控件名 -> 绑定；例：{"play":{"kind":"command","command":"P"},\n'
            '"rate":{"kind":"effect","parameter":"R"}, '
            '"read":{"kind":"feedback","field":"R"}}\n'
            '文件按钮 kind: scan / load / previous / next；仅 PC 场景控制使用。'
        )
        self.editor.setPlainText(json.dumps(scene.pc_bindings, indent=2, ensure_ascii=False))

    def _save(self):
        try:
            from designer.scene_runtime import validate_bindings
            candidate = UIScene.from_dict(self.scene.to_dict())
            candidate.pc_bindings = json.loads(self.editor.toPlainText() or '{}')
            validate_bindings(candidate)
            self.scene.pc_bindings = candidate.pc_bindings
            self.accept()
        except (ValueError, TypeError) as exc:
            QMessageBox.warning(self, "Invalid PC bindings", str(exc))


class MainWindow(QMainWindow):
    """主窗口"""

    def __init__(self):
        super().__init__()
        self.setWindowTitle("FPGA UI Designer - Tang Mega 60K")
        self.setGeometry(100, 100, 1240, 660)

        self.current_file = None
        self.is_modified = False

        self.init_ui()

    def init_ui(self):
        # 中心部件
        central = QWidget()
        self.setCentralWidget(central)

        layout = QHBoxLayout()

        # 左侧：控件列表
        left_panel = QWidget()
        left_layout = QVBoxLayout()

        title = QLabel("Widgets")
        title.setStyleSheet("font-weight: bold; font-size: 14px;")
        left_layout.addWidget(title)

        self.widget_list = QListWidget()
        widgets = ["Panel", "Text", "Bar", "Spectrum", "Waveform",
                   "Knob", "Keyboard"]
        self.widget_list.addItems(widgets)
        self.widget_list.itemDoubleClicked.connect(self.on_add_widget)
        left_layout.addWidget(self.widget_list)

        add_btn = QPushButton("Add Widget")
        add_btn.clicked.connect(self.on_add_widget)
        left_layout.addWidget(add_btn)

        del_btn = QPushButton("Delete Selected")
        del_btn.clicked.connect(self.on_delete_widget)
        left_layout.addWidget(del_btn)

        left_panel.setLayout(left_layout)
        left_panel.setMaximumWidth(200)

        # 中间：画布
        self.canvas = DesignCanvas()
        self.canvas.widget_selected.connect(self.on_widget_selected)
        self.canvas.widget_moved.connect(self.on_widget_selected)
        self.canvas.scene_changed.connect(self.on_scene_changed)

        # 将屏幕与编辑器空白明确分开，不再把整块工作区画成黑屏。
        self.canvas_workspace = QWidget()
        self.canvas_workspace.setObjectName('canvasWorkspace')
        self.canvas_workspace.setStyleSheet(
            'QWidget#canvasWorkspace { background: #d9dde3; }'
        )
        canvas_layout = QVBoxLayout(self.canvas_workspace)
        page_row = QHBoxLayout()
        self.page_selector = QComboBox()
        self.page_selector.currentIndexChanged.connect(self.on_page_selected)
        page_row.addWidget(self.page_selector, 1)
        for text, handler in (('新增页', self.on_add_page), ('改页名', self.on_rename_page),
                              ('删除页', self.on_delete_page), ('设为默认页', self.on_default_page)):
            button = QPushButton(text)
            button.clicked.connect(handler)
            page_row.addWidget(button)
        canvas_layout.addLayout(page_row)
        self.panel_size_label = QLabel()
        self.panel_size_label.setAlignment(Qt.AlignCenter)
        canvas_layout.addWidget(self.panel_size_label)
        canvas_layout.addWidget(self.canvas, 1, Qt.AlignCenter)
        self.canvas.panel_size_changed.connect(self.update_panel_label)
        self.canvas.panel_size_changed.connect(self.refresh_pages)
        self.refresh_pages()
        self.update_panel_label()

        # 右侧：属性面板
        self.property_panel = PropertyPanel()
        self.property_panel.set_canvas(self.canvas)
        self.property_panel.property_changed.connect(self.on_scene_changed)
        self.property_scroll = QScrollArea()
        self.property_scroll.setWidgetResizable(True)
        self.property_scroll.setWidget(self.property_panel)
        self.property_scroll.setMinimumWidth(310)
        self.property_scroll.setMaximumWidth(350)

        # 分割器
        splitter = QSplitter()
        splitter.addWidget(left_panel)
        splitter.addWidget(self.canvas_workspace)
        splitter.addWidget(self.property_scroll)
        splitter.setStretchFactor(1, 3)

        layout.addWidget(splitter)
        central.setLayout(layout)

        # 工具栏
        self.create_toolbar()

        # 状态栏
        self.statusBar().showMessage("Ready")

    def update_panel_label(self):
        scene = self.canvas.ui_scene
        panel = '（5寸屏）' if (scene.width, scene.height) == (800, 480) else ''
        self.panel_size_label.setText(
            f'屏幕画布{panel}：{scene.width} × {scene.height} · 1:1 像素'
        )

    def refresh_pages(self):
        self.page_selector.blockSignals(True)
        self.page_selector.clear()
        self.page_selector.addItem('公共控件', '')
        for page in self.canvas.ui_scene.pages:
            label = page['title'] + (' [默认]' if page['id'] == self.canvas.ui_scene.initial_page else '')
            self.page_selector.addItem(label, page['id'])
        self.page_selector.setCurrentIndex(max(0, self.page_selector.findData(self.canvas.current_page)))
        self.page_selector.blockSignals(False)

    def on_page_selected(self, *_):
        page_id = self.page_selector.currentData()
        if page_id is not None:
            self.canvas.set_page(page_id)

    def add_page(self, title):
        scene = self.canvas.ui_scene
        number = 1
        while f'page_{number}' in {p['id'] for p in scene.pages}:
            number += 1
        page_id = f'page_{number}'
        scene.pages.append({'id': page_id, 'title': title})
        if len(scene.pages) == 1:
            scene.initial_page = page_id
        self.canvas.set_page(page_id)
        self.on_scene_changed()
        return page_id

    def on_add_page(self):
        title, accepted = QInputDialog.getText(self, '新增页面', '页面名称:')
        if accepted and title.strip():
            self.add_page(title.strip())

    def on_rename_page(self):
        page = next((p for p in self.canvas.ui_scene.pages if p['id'] == self.canvas.current_page), None)
        if page:
            title, accepted = QInputDialog.getText(self, '修改页面名称', '页面名称:', text=page['title'])
            if accepted and title.strip():
                page['title'] = title.strip()
                self.refresh_pages()
                self.on_scene_changed()

    def on_default_page(self):
        if self.canvas.current_page:
            self.canvas.ui_scene.initial_page = self.canvas.current_page
            self.refresh_pages()
            self.on_scene_changed()

    def on_delete_page(self):
        page_id = self.canvas.current_page
        if not page_id:
            return
        scene = self.canvas.ui_scene
        if any(w.page == page_id for w in scene.widgets) or any(a['target'] == page_id for a in scene.local_actions.values()):
            QMessageBox.warning(self, '页面仍被使用', '请先移动/删除本页控件，并解除指向本页的导航动作，再删除页面。')
            return
        scene.pages = [p for p in scene.pages if p['id'] != page_id]
        if scene.initial_page == page_id:
            scene.initial_page = scene.pages[0]['id'] if scene.pages else ''
        self.canvas.set_page(scene.initial_page)
        self.on_scene_changed()

    def create_toolbar(self):
        """创建工具栏"""
        toolbar = self.addToolBar("Main")
        serial_action = toolbar.addAction("FPGA Serial Loopback")
        serial_action.triggered.connect(self.on_serial_loopback)
        dimension_action = toolbar.addAction("Dimension Control")
        dimension_action.triggered.connect(self.on_dimension_control)
        scene_action = toolbar.addAction("Scene FPGA Control")
        scene_action.triggered.connect(self.on_scene_control)
        binding_action = toolbar.addAction("PC Bindings")
        binding_action.triggered.connect(self.on_pc_bindings)

        new_action = toolbar.addAction("New")
        new_action.triggered.connect(self.on_new)

        open_action = toolbar.addAction("Open")
        open_action.triggered.connect(self.on_open)

        save_action = toolbar.addAction("Save")
        save_action.triggered.connect(self.on_save)

        save_as_action = toolbar.addAction("Save As")
        save_as_action.triggered.connect(self.on_save_as)

        toolbar.addSeparator()

        preview_action = toolbar.addAction("Preview")
        preview_action.triggered.connect(self.on_preview)

        interaction_action = toolbar.addAction("Interactions")
        interaction_action.triggered.connect(self.on_edit_interactions)

        generate_action = toolbar.addAction("Generate RTL")
        generate_action.triggered.connect(self.on_generate_rtl)

    def on_serial_loopback(self):
        from designer.loopback_window import LoopbackWindow
        if not hasattr(self, '_serial_window'):
            self._serial_window = LoopbackWindow(self)
        self._serial_window.show()
        self._serial_window.raise_()

    def on_dimension_control(self):
        from designer.dimension_window import DimensionWindow
        if not hasattr(self, '_dimension_window'):
            self._dimension_window = DimensionWindow(self)
        self._dimension_window.show()
        self._dimension_window.raise_()

    def on_edit_interactions(self):
        """Open the scene-level interaction rule editor."""
        dialog = InteractionEditorDialog(self.canvas.ui_scene, self)
        if dialog.exec():
            self.on_scene_changed()

    def on_scene_control(self):
        from designer.scene_runtime import SceneRuntimeWindow
        try:
            # Snapshot current edits. Do not mutate the scene while it runs.
            window = SceneRuntimeWindow(self.canvas.ui_scene, self)
            window.setAttribute(Qt.WA_DeleteOnClose)
            window.show()
        except (ValueError, TypeError) as exc:
            QMessageBox.warning(self, "Scene FPGA Control", str(exc))

    def on_pc_bindings(self):
        dialog = PCBindingEditorDialog(self.canvas.ui_scene, self)
        if dialog.exec():
            self.on_scene_changed()

    def on_add_widget(self):
        """添加控件"""
        current = self.widget_list.currentItem()
        if current:
            widget_type = current.text().lower()
            self.canvas.add_widget(widget_type)

    def on_delete_widget(self):
        """删除控件"""
        self.canvas.delete_selected()
        self.property_panel.clear_widget()

    def on_widget_selected(self, widget):
        """控件被选中"""
        if widget is None:
            self.property_panel.clear_widget()
            self.statusBar().showMessage("No widget selected")
            return
        self.property_panel.load_widget(widget)
        self.statusBar().showMessage(f"Selected: {widget.name} ({widget.type}) X={widget.x} Y={widget.y}")

    def on_scene_changed(self):
        """场景修改"""
        self.is_modified = True
        self.update_title()

    def update_title(self):
        """更新标题"""
        title = "FPGA UI Designer - Tang Mega 60K"
        if self.current_file:
            title += f" - {Path(self.current_file).name}"
        if self.is_modified:
            title += " *"
        self.setWindowTitle(title)

    def on_new(self):
        """新建项目"""
        if not self._confirm_save_if_needed():
            return

        self.canvas.ui_scene = UIScene()
        self.canvas.ui_scene.name = "new_scene"
        self.canvas.ui_scene.width = 800
        self.canvas.ui_scene.height = 480
        self.canvas.ui_scene.bg_color = ColorRGB(5, 7, 12)
        self.canvas.selected_widget = None
        self.property_panel.clear_widget()
        self.canvas.redraw()

        self.current_file = None
        self.is_modified = False
        self.update_title()
        self.statusBar().showMessage("New scene created")

    def on_open(self):
        """打开项目"""
        filename, _ = QFileDialog.getOpenFileName(
            self, "Open UI Scene", "", "JSON Files (*.json)"
        )
        if filename and self._confirm_save_if_needed():
            try:
                scene = UIScene.from_json(filename)
                self.canvas.load_scene(scene)
                self.property_panel.clear_widget()
                self.current_file = filename
                self.is_modified = False
                self.update_title()
                self.statusBar().showMessage(f"Loaded: {filename}")
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to load file:\n{e}")

    def on_save(self):
        """保存项目"""
        if self.current_file:
            return self._save_to_file(self.current_file)
        return self.on_save_as()

    def on_save_as(self):
        """另存为"""
        filename, _ = QFileDialog.getSaveFileName(
            self, "Save UI Scene", "", "JSON Files (*.json)"
        )
        if filename:
            return self._save_to_file(filename)
        return False

    def _save_to_file(self, filename):
        """保存到文件"""
        try:
            self.canvas.ui_scene.validate_navigation()
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(self.canvas.ui_scene.to_dict(), f, indent=2)
            self.current_file = filename
            self.is_modified = False
            self.update_title()
            self.statusBar().showMessage(f"Saved: {filename}")
            return True
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to save file:\n{e}")
            return False

    def _confirm_save_if_needed(self):
        """Return False when the user cancels or saving fails."""
        if not self.is_modified:
            return True

        reply = QMessageBox.question(
            self, "Unsaved Changes",
            "Do you want to save changes?",
            QMessageBox.Save | QMessageBox.Discard | QMessageBox.Cancel
        )
        if reply == QMessageBox.Save:
            return self.on_save()
        return reply == QMessageBox.Discard

    def on_preview(self):
        """预览渲染 - 使用交互式预览"""
        if self.canvas.ui_scene.pc_bindings:
            self.on_scene_control()
            return
        try:
            # 尝试加载交互式预览
            try:
                try:
                    from .interactive_preview import InteractivePreviewDialog
                except ImportError:
                    from interactive_preview import InteractivePreviewDialog

                # 显示交互式预览
                dialog = InteractivePreviewDialog(self.canvas.ui_scene, self)
                dialog.exec()

                self.statusBar().showMessage("Interactive preview closed")
            except ImportError as ie:
                # 降级到静态预览
                QMessageBox.warning(
                    self, "Interactive Preview Unavailable",
                    f"Interactive preview module not found: {ie}\nUsing static preview instead."
                )
                self._static_preview()
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Preview failed:\n{e}")

    def _static_preview(self):
        """静态预览（原方法）"""
        renderer = PixelRenderer()

        # 模拟 UI 状态 - 生成动态测试数据
        fft_bins = [int(128 + 100 * np.sin(i * 0.1)) for i in range(128)]
        ui_state = [32768] * 32  # 50% 默认值
        ui_state[0] = 40000  # OP1
        ui_state[1] = 50000  # OP2
        ui_state[2] = 30000  # OP3
        ui_state[3] = 45000  # OP4
        ui_state[4] = 35000  # OP5
        ui_state[5] = 55000  # OP6

        # 生成 PCM 波形数据（正弦波）
        pcm_buffer = [int(20000 * np.sin(i * 2 * np.pi / 256)) for i in range(1024)]

        # 生成键盘状态（模拟按下 C、E、G 和弦）
        key_states = [0] * 128
        key_states[0] = 1   # C
        key_states[4] = 1   # E
        key_states[7] = 1   # G

        state_dict = {
            "fft_bins": fft_bins,
            "ui_state": ui_state,
            "pcm_buffer": pcm_buffer,
            "key_states": key_states,
        }

        frame = renderer.render_scene(self.canvas.ui_scene, state_dict)

        # 转换为 QImage
        height, width, channels = frame.shape
        bytes_per_line = channels * width
        qimage = QImage(frame.data, width, height, bytes_per_line, QImage.Format_RGB888)

        # 显示预览对话框
        dialog = PreviewDialog(qimage, self)
        dialog.exec()

        self.statusBar().showMessage("Static preview generated")

    def on_generate_rtl(self):
        """生成 RTL"""
        output_dir = QFileDialog.getExistingDirectory(
            self, "Select Output Directory"
        )
        if output_dir:
            try:
                try:
                    from generator.rtl_generator import RTLGenerator
                except ModuleNotFoundError:
                    from rtl_generator import RTLGenerator
                generator = RTLGenerator()
                generator.generate(self.canvas.ui_scene, Path(output_dir))
                QMessageBox.information(
                    self, "Success",
                    "Generated exactly one replaceable Verilog file:\n"
                    f"{Path(output_dir) / 'ui_generated_scene.v'}"
                )
                self.statusBar().showMessage(f"RTL generated: {output_dir}")
            except Exception as e:
                QMessageBox.critical(self, "Error", f"RTL generation failed:\n{e}")

    def closeEvent(self, event):
        """窗口关闭"""
        if self._confirm_save_if_needed():
            event.accept()
        else:
            event.ignore()


def main():
    app = QApplication(sys.argv)

    # 设置样式
    app.setStyle("Fusion")

    window = MainWindow()
    window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
