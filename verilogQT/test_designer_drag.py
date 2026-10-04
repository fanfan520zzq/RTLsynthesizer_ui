"""Real Qt mouse gestures: layout drag, property sync and JSON persistence."""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
import tempfile
import unittest
from pathlib import Path
from PySide6.QtCore import Qt, QPoint, QPointF
from PySide6.QtTest import QTest
from PySide6.QtGui import QFontDatabase
from PySide6.QtWidgets import QApplication
from designer.ui_designer import MainWindow
from designer.ui_schema import (UIScene, PanelWidget, TextWidget, BarWidget,
                                SpectrumWidget, WaveformWidget, KeyboardWidget,
                                KnobWidget)

APP = QApplication.instance() or QApplication([])
font = Path('C:/Windows/Fonts/msyh.ttc')
if not QFontDatabase.families() and font.exists():
    QFontDatabase.addApplicationFont(str(font))


class DragTests(unittest.TestCase):
    def setUp(self):
        self.editor = MainWindow()
        self.canvas = self.editor.canvas
        self.editor.show()
        APP.processEvents()

    def tearDown(self):
        self.editor.is_modified = False
        self.editor.close()

    def load(self, widgets, bindings=None):
        self.canvas.load_scene(UIScene(name='drag_test', width=640, height=480,
                                      widgets=widgets, pc_bindings=bindings or {}))
        self.editor.is_modified = False
        self.editor.update_title()
        APP.processEvents()

    def point(self, x, y):
        return self.canvas.mapFromScene(QPointF(x, y))

    def gesture(self, widget, delta, local=QPoint(15,15)):
        start = self.point(widget.x+local.x(), widget.y+local.y())
        end = self.point(widget.x+local.x()+delta.x(), widget.y+local.y()+delta.y())
        QTest.mousePress(self.canvas.viewport(), Qt.LeftButton, pos=start)
        QTest.mouseMove(self.canvas.viewport(), end)
        # No release yet: model and property panel must already be in sync.
        self.assertEqual(self.editor.property_panel.x_spin.value(), widget.x)
        self.assertEqual(self.editor.property_panel.y_spin.value(), widget.y)
        QTest.mouseRelease(self.canvas.viewport(), Qt.LeftButton, pos=end)

    def test_drag_all_widget_types_and_composite_children(self):
        for kind in (PanelWidget, TextWidget, BarWidget, SpectrumWidget,
                     WaveformWidget, KeyboardWidget, KnobWidget):
            with self.subTest(kind=kind.__name__):
                w = kind(name='test', x=160, y=140, width=160, height=80)
                if isinstance(w, TextWidget): w.text='DRAG THIS TEXT'
                self.load([w])
                root = self.canvas.widget_graphics_map[id(w)]
                initial = root.sceneBoundingRect().topLeft()
                children = {child:child.scenePos() for child in root.childItems()}
                local = QPoint(80,40) if isinstance(w, KnobWidget) else QPoint(15,15)
                self.gesture(w, QPoint(45,30), local)
                self.assertEqual((w.x,w.y), (205,170))
                self.assertIs(self.canvas.selected_widget, w)
                self.assertTrue(root.isSelected())
                self.assertTrue(self.editor.is_modified)
                self.assertTrue(self.editor.windowTitle().endswith('*'))
                self.assertEqual(root.sceneBoundingRect().topLeft(), initial+QPointF(45,30))
                for child, pos in children.items():
                    self.assertEqual(child.scenePos(), pos+QPointF(45,30))

    def test_save_reload_and_binding_survives_drag(self):
        w = PanelWidget(name='play', x=140, y=120, width=90, height=40)
        bindings = {'play':{'kind':'command','command':'P'}}
        self.load([w],bindings)
        self.gesture(w, QPoint(24,17))
        with tempfile.TemporaryDirectory() as folder:
            filename = str(Path(folder)/'scene.json')
            self.assertTrue(self.editor._save_to_file(filename))
            restored = UIScene.from_json(filename)
            self.assertEqual((restored.widgets[0].x,restored.widgets[0].y),(164,137))
            self.assertEqual(restored.pc_bindings, bindings)
            self.canvas.load_scene(restored)
            self.assertIsNone(self.canvas._drag)
        self.gesture(restored.widgets[0], QPoint(16,13))
        self.assertEqual((restored.widgets[0].x,restored.widgets[0].y),(180,150))

    def test_boundaries_and_repeated_drag_after_property_edit(self):
        w = PanelWidget(name='panel', x=160, y=140, width=120, height=60)
        self.load([w])
        # Release can lie outside the scene/view; logical bounds still clamp.
        self.gesture(w, QPoint(-300,-300))
        self.assertEqual((w.x,w.y),(0,0))
        self.gesture(w, QPoint(1000,1000))
        self.assertEqual((w.x,w.y),(520,420))
        self.editor.property_panel.x_spin.setValue(200)
        self.editor.property_panel.y_spin.setValue(200)
        self.assertEqual((w.x,w.y),(200,200))
        self.assertTrue(self.canvas.widget_graphics_map[id(w)].isSelected())
        self.gesture(w, QPoint(20,10))
        self.assertEqual((w.x,w.y),(220,210))

    def test_click_without_move_and_empty_selection(self):
        w = PanelWidget(name='panel', x=160, y=140, width=120, height=60)
        self.load([w])
        QTest.mouseClick(self.canvas.viewport(), Qt.LeftButton, pos=self.point(180,160))
        self.assertIs(self.canvas.selected_widget,w)
        self.assertFalse(self.editor.is_modified)
        QTest.mouseClick(self.canvas.viewport(), Qt.LeftButton, pos=self.point(20,20))
        self.assertIsNone(self.canvas.selected_widget)
        self.assertIsNone(self.editor.property_panel.current_widget)
        self.assertFalse(self.editor.is_modified)

    def test_layer_and_focus_loss_stop_drag(self):
        back = PanelWidget(name='back', x=160, y=140, width=120, height=80, layer=0)
        front = PanelWidget(name='front', x=160, y=140, width=80, height=60, layer=5)
        self.load([front,back])
        self.gesture(front,QPoint(20,20))
        self.assertEqual((back.x,back.y),(160,140))
        start = self.point(front.x+15,front.y+15)
        QTest.mousePress(self.canvas.viewport(),Qt.LeftButton,pos=start)
        self.editor.property_panel.name_edit.setFocus()
        APP.processEvents()
        self.assertIsNone(self.canvas._drag)
        QTest.mouseMove(self.canvas.viewport(),start+QPoint(20,20))
        QTest.mouseRelease(self.canvas.viewport(),Qt.LeftButton,pos=start+QPoint(20,20))
        self.assertEqual((front.x,front.y),(180,160))

    def test_redraw_and_delete_cancel_stale_drag(self):
        w = PanelWidget(name='panel', x=160,y=140,width=120,height=60)
        self.load([w])
        start = self.point(180,160)
        QTest.mousePress(self.canvas.viewport(),Qt.LeftButton,pos=start)
        self.canvas.redraw()
        QTest.mouseMove(self.canvas.viewport(),start+QPoint(20,20))
        QTest.mouseRelease(self.canvas.viewport(),Qt.LeftButton,pos=start+QPoint(20,20))
        self.assertEqual((w.x,w.y),(160,140))
        self.editor.on_delete_widget()
        self.assertEqual(self.canvas.ui_scene.widgets,[])
        self.assertIsNone(self.canvas._drag)


if __name__ == '__main__': unittest.main()
