"""Font changes affect designer, preview and PC runtime without RTL changes."""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
from pathlib import Path
import tempfile
import unittest
import numpy as np
from PySide6.QtCore import Qt, QPointF
from PySide6.QtGui import QImage
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication
from designer.ui_designer import MainWindow
from designer.ui_schema import UIScene, TextWidget, ColorRGB
from designer.pixel_renderer import PixelRenderer
from designer.scene_runtime import SceneRuntimeWindow
from designer.interactive_preview import InteractivePreviewDialog

APP = QApplication.instance() or QApplication([])


def rgba(pixmap):
    image = pixmap.toImage().convertToFormat(QImage.Format_RGBA8888)
    return np.frombuffer(image.bits(), dtype=np.uint8).reshape(image.height(), image.bytesPerLine())[:, :image.width()*4].reshape(image.height(), image.width(), 4).copy()


class FontTests(unittest.TestCase):
    def setUp(self):
        self.editor = MainWindow()
        self.text = TextWidget(name='label', text='SIZE 0123', x=30, y=30,
                               width=360, height=90, font_size=16)
        self.editor.canvas.load_scene(UIScene(widgets=[self.text]))
        self.editor.canvas.selected_widget = self.text
        self.editor.on_widget_selected(self.text)
        self.editor.is_modified = False
        self.editor.show()
        APP.processEvents()

    def tearDown(self):
        self.editor.is_modified = False
        self.editor.close()

    def test_actual_spin_updates_pixels_and_preserves_layout(self):
        old = PixelRenderer.text_pixels(self.text).copy()
        spin = self.editor.property_panel.font_size_spin
        spin.setFocus()
        spin.selectAll()
        QTest.keyClicks(spin, '32')
        QTest.keyClick(spin, Qt.Key_Return)
        self.assertEqual(self.text.font_size, 32)
        self.assertTrue(self.editor.is_modified)
        self.assertEqual((self.text.x, self.text.y, self.text.width, self.text.height), (30, 30, 360, 90))
        pixels = PixelRenderer.text_pixels(self.text)
        self.assertFalse(np.array_equal(old, pixels))
        root = self.editor.canvas.widget_graphics_map[id(self.text)]
        self.assertTrue(root.isSelected())
        self.assertTrue(np.array_equal(rgba(root.childItems()[0].pixmap()), pixels))
        start = self.editor.canvas.mapFromScene(QPointF(45, 45))
        end = self.editor.canvas.mapFromScene(QPointF(65, 55))
        QTest.mousePress(self.editor.canvas.viewport(), Qt.LeftButton, pos=start)
        QTest.mouseMove(self.editor.canvas.viewport(), end)
        QTest.mouseRelease(self.editor.canvas.viewport(), Qt.LeftButton, pos=end)
        self.assertEqual((self.text.x, self.text.y), (50, 40))
        self.assertEqual(self.text.font_size, 32)

    def test_sizes_8_16_24_32_48_72_and_native_rom(self):
        text = TextWidget(text='A', x=0, y=0, width=100, height=90)
        for size in (8, 16, 24, 32, 48, 72):
            text.font_size = size
            pixels = PixelRenderer.text_pixels(text)
            mask = pixels[:, :, 3] != 0
            self.assertTrue(mask.any())
            self.assertFalse(mask[size:, :].any())
            self.assertFalse(mask[:, (size+1)//2:].any())
        text.font_size = 16
        native = PixelRenderer.text_pixels(text)[:16, :8, 3] != 0
        glyph = PixelRenderer._font_glyphs()[ord('A')]
        expected = np.array([[(bits >> (7-col)) & 1 for col in range(8)] for bits in glyph], dtype=bool)
        self.assertTrue(np.array_equal(native, expected))

    def test_save_reload_preview_runtime_share_pixels(self):
        self.editor.property_panel.font_size_spin.setValue(24)
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder)/'font.json'
            self.assertTrue(self.editor._save_to_file(str(target)))
            scene = UIScene.from_json(target)
            self.assertEqual(scene.widgets[0].font_size, 24)
            scene.pc_bindings = {'label': {'kind': 'feedback', 'field': 'mode'}}
            preview = InteractivePreviewDialog(scene)
            runtime = SceneRuntimeWindow(scene)
            try:
                # Supply an in-memory label, never open a serial port.
                runtime.canvas.labels['mode'] = scene.widgets[0].text
                runtime.canvas.render()
                expected = PixelRenderer().render_scene(scene, {})
                self.assertTrue(np.array_equal(rgba(runtime.canvas.pixmap())[:, :, :3], expected))
                # Both preview and runtime invoke the same renderer.
                self.assertTrue(np.array_equal(preview.renderer.render_scene(scene, {}), expected))
            finally:
                preview.close()
                runtime.close()

    def test_alignment_clipping_color_and_negative_origin(self):
        text = TextWidget(text='AB', width=80, height=40, font_size=24,
                          color=ColorRGB(1, 2, 3))
        masks = {}
        for align in ('left', 'center', 'right'):
            text.align = align
            masks[align] = PixelRenderer.text_pixels(text)[:, :, 3] != 0
        self.assertTrue(np.array_equal(masks['left'][:, :24], masks['center'][:, 28:52]))
        self.assertTrue(np.array_equal(masks['left'][:, :24], masks['right'][:, 56:80]))
        text.x, text.y, text.width, text.height = -5, -5, 15, 15
        text.align = 'left'
        scene = UIScene(width=60, height=60, widgets=[text])
        frame = PixelRenderer().render_scene(scene, {})
        bg = [scene.bg_color.r, scene.bg_color.g, scene.bg_color.b]
        self.assertTrue((frame[10:, :] == bg).all())
        self.assertTrue((frame[:, 10:] == bg).all())
        self.assertTrue(((frame[:10, :10] == [1, 2, 3]).all(axis=2)).any())


if __name__ == '__main__':
    unittest.main()
