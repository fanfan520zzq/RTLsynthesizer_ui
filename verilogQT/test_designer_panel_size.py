"""Panel viewport stays pixel-exact while the editor window is resized."""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
import unittest
from pathlib import Path
from PySide6.QtCore import QPointF, Qt
from PySide6.QtWidgets import QApplication
from designer.ui_designer import MainWindow
from designer.ui_schema import UIScene

APP = QApplication.instance() or QApplication([])
ROOT = Path(__file__).resolve().parent


class PanelViewportTests(unittest.TestCase):
    def setUp(self):
        self.editor = MainWindow()
        self.editor.show()
        APP.processEvents()

    def tearDown(self):
        self.editor.is_modified = False
        self.editor.close()

    def assert_viewport(self, width, height):
        APP.processEvents()
        canvas = self.editor.canvas
        self.assertEqual((canvas.viewport().width(), canvas.viewport().height()),
                         (width, height))
        self.assertTrue(canvas.transform().isIdentity())
        delta = canvas.mapFromScene(QPointF(100, 100)) - canvas.mapFromScene(QPointF(0, 0))
        self.assertEqual((delta.x(), delta.y()), (100, 100))
        self.assertEqual(canvas.horizontalScrollBarPolicy(), Qt.ScrollBarAlwaysOff)
        self.assertIn(f'{width} × {height}', self.editor.panel_size_label.text())

    def test_default_and_window_resize(self):
        self.assert_viewport(800, 480)
        self.editor.resize(1600, 900)
        self.assert_viewport(800, 480)

    def test_load_pc_scene_and_legacy_dimensions(self):
        self.editor.canvas.load_scene(UIScene.from_json(ROOT/'examples/dimension_autoplay_pc.json'))
        self.assert_viewport(800, 480)
        self.editor.canvas.load_scene(UIScene(width=640, height=360))
        self.assert_viewport(640, 360)
        self.editor.is_modified = False
        self.editor.on_new()
        self.assert_viewport(800, 480)


if __name__ == '__main__':
    unittest.main()
