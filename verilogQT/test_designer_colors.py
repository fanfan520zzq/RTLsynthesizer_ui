"""Actual Qt color controls, dirty-state, pixels and JSON persistence."""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from PySide6.QtCore import Qt, QPointF
from PySide6.QtGui import QColor
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication
from designer.color_editor import ColorEditor
from designer.ui_designer import MainWindow
from designer.ui_schema import (UIScene, ColorRGB, PanelWidget, TextWidget,
                                BarWidget, SpectrumWidget, WaveformWidget,
                                KnobWidget, KeyboardWidget)
from designer.pixel_renderer import PixelRenderer

APP = QApplication.instance() or QApplication([])


class ColorTests(unittest.TestCase):
    def setUp(self):
        self.editor = MainWindow()
        self.editor.show()
        APP.processEvents()
        self.panel = self.editor.property_panel

    def tearDown(self):
        self.editor.is_modified = False
        self.editor.close()

    def load(self, widgets):
        self.editor.canvas.load_scene(UIScene(widgets=widgets))
        self.editor.is_modified = False

    def select(self, widget):
        self.editor.canvas.selected_widget = widget
        self.editor.on_widget_selected(widget)
        APP.processEvents()

    def test_all_widget_colors_update_and_reload(self):
        kinds = (PanelWidget, TextWidget, BarWidget, SpectrumWidget,
                 WaveformWidget, KnobWidget, KeyboardWidget)
        widgets = [kind(name=kind.__name__, x=30, y=30, width=120, height=80)
                   for kind in kinds]
        self.load(widgets)
        for widget in widgets:
            self.select(widget)
            self.assertFalse(self.editor.is_modified)
            colors = list(self.panel.color_editors.items())
            self.assertTrue(colors)
            for index, (field, control) in enumerate(colors):
                with self.subTest(kind=widget.type, field=field):
                    value = ColorRGB(21 + index, 101 + index, 201 + index)
                    control.hex_edit.setText(f'#{value.to_hex():06X}')
                    self.assertEqual(getattr(widget, field), value)
                    self.assertTrue(self.editor.is_modified)
                    self.assertEqual((widget.x, widget.y), (30, 30))
                    self.assertIs(self.panel.current_widget, widget)
            self.editor.is_modified = False
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder)/'colors.json'
            self.assertTrue(self.editor._save_to_file(str(target)))
            restored = UIScene.from_json(target)
            self.assertEqual(restored.to_dict(), self.editor.canvas.ui_scene.to_dict())
            self.editor.canvas.load_scene(restored)
            self.select(restored.widgets[0])
            self.assertEqual(self.panel.color_editors['bg_color'].hex_edit.text(), '#1565C9')

    def test_background_rgb_hex_and_new_scene_sync(self):
        control = self.panel.scene_color_editor
        control.hex_edit.setText('#A1b2C3')
        self.assertEqual(self.editor.canvas.ui_scene.bg_color, ColorRGB(161, 178, 195))
        self.assertEqual(self.editor.canvas.backgroundBrush().color().name(), '#a1b2c3')
        self.assertTrue(self.editor.is_modified)
        control.rgb_spins[0].setValue(32)
        self.assertEqual(control.hex_edit.text(), '#20B2C3')
        frame = PixelRenderer(800, 480).render_scene(self.editor.canvas.ui_scene, {})
        self.assertEqual(frame[0, 0].tolist(), [32, 178, 195])
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder)/'background.json'
            self.editor._save_to_file(str(target))
            self.assertEqual(UIScene.from_json(target).bg_color, ColorRGB(32, 178, 195))
        self.editor.is_modified = False
        self.editor.on_new()
        self.assertEqual(control.hex_edit.text(), '#05070C')

    def test_real_hex_typing_cancel_and_invalid_are_safe(self):
        control = self.panel.scene_color_editor
        old = self.editor.canvas.ui_scene.bg_color
        for invalid in ('#XYZ123', '#11223', '#12345678', 'red', ''):
            control.hex_edit.setText(invalid)
            self.assertEqual(self.editor.canvas.ui_scene.bg_color, old)
            self.assertFalse(self.editor.is_modified)
            control._finish_hex()
            self.assertEqual(control.hex_edit.text(), '#05070C')
        with patch('designer.color_editor.QColorDialog.getColor', return_value=QColor()):
            QTest.mouseClick(control.pick_button, Qt.LeftButton)
        self.assertFalse(self.editor.is_modified)
        with patch('designer.color_editor.QColorDialog.getColor', return_value=QColor(1, 2, 3)):
            QTest.mouseClick(control.pick_button, Qt.LeftButton)
        self.assertEqual(self.editor.canvas.ui_scene.bg_color, ColorRGB(1, 2, 3))
        control.hex_edit.setFocus()
        control.hex_edit.selectAll()
        QTest.keyClicks(control.hex_edit, '#ABCDEF')
        QTest.keyClick(control.hex_edit, Qt.Key_Return)
        self.assertEqual(self.editor.canvas.ui_scene.bg_color, ColorRGB(171, 205, 239))
        control.rgb_spins[0].setValue(999)
        self.assertEqual(self.editor.canvas.ui_scene.bg_color.r, 255)

    def test_selection_clear_and_drag_after_color(self):
        widget = PanelWidget(name='play', x=30, y=30, width=120, height=80)
        self.load([widget])
        self.select(widget)
        self.panel.color_editors['bg_color'].hex_edit.setText('#FF0000')
        root = self.editor.canvas.widget_graphics_map[id(widget)]
        self.assertEqual(root.brush().color().name(), '#ff0000')
        self.assertTrue(root.isSelected())
        canvas = self.editor.canvas
        start = canvas.mapFromScene(QPointF(50, 50))
        end = canvas.mapFromScene(QPointF(80, 70))
        QTest.mousePress(canvas.viewport(), Qt.LeftButton, pos=start)
        QTest.mouseMove(canvas.viewport(), end)
        QTest.mouseRelease(canvas.viewport(), Qt.LeftButton, pos=end)
        self.assertEqual((widget.x, widget.y), (60, 50))
        self.assertEqual(widget.bg_color, ColorRGB(255, 0, 0))
        self.editor.on_delete_widget()
        self.assertEqual(self.panel.color_editors, {})
        self.panel.scene_color_editor.hex_edit.setText('#123456')
        self.assertEqual(canvas.ui_scene.bg_color, ColorRGB(18, 52, 86))

    def test_knob_pointer_and_outline_are_independent_pixels(self):
        knob = KnobWidget(x=10, y=10, width=80, height=80, min_angle=0, max_angle=0,
                          pointer_color=ColorRGB(255, 0, 0), fg_color=ColorRGB(0, 255, 0))
        frame = PixelRenderer(100, 100).render_scene(UIScene(width=100, height=100, widgets=[knob]), {})
        self.assertEqual(frame[30, 50].tolist(), [255, 0, 0])
        self.assertEqual(frame[50, 89].tolist(), [0, 255, 0])

    def test_color_rows_scroll_instead_of_compressing(self):
        widget = KnobWidget(x=30, y=30)
        self.load([widget])
        self.select(widget)
        self.editor.resize(1300, 550)
        APP.processEvents()
        controls = list(self.panel.color_editors.values())
        for previous, following in zip(controls, controls[1:]):
            self.assertLessEqual(previous.y() + previous.height(), following.y())
        for control in self.panel.color_editors.values():
            self.assertGreaterEqual(control.height(), control.sizeHint().height())
            for spin in control.rgb_spins:
                self.assertGreaterEqual(spin.height(), spin.sizeHint().height())
        self.assertGreater(self.editor.property_scroll.verticalScrollBar().maximum(), 0)


if __name__ == '__main__':
    unittest.main()
