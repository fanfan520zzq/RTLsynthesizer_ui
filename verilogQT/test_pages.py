"""Page isolation, GUI configuration, local navigation and UART continuity."""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
import unittest
import tempfile
from copy import deepcopy
from pathlib import Path
from unittest.mock import patch
import numpy as np
from PySide6.QtCore import Qt, QPoint, QPointF
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication
from designer.ui_schema import UIScene, PanelWidget, TextWidget, ColorRGB
from designer.ui_designer import MainWindow
from designer.scene_runtime import SceneRuntimeWindow, EXAMPLE, validate_bindings
from designer.interactive_preview import InteractivePreviewDialog
from designer.pixel_renderer import PixelRenderer
from generator.compact_rtl_generator import CompactRTLGenerator
from generator.rtl_generator import RTLGenerator
from test_dimension import FakePort, SNAP

APP = QApplication.instance() or QApplication([])


def local_scene():
    return UIScene(pages=[{'id':'a','title':'第一页'}, {'id':'b','title':'第二页'}], initial_page='a',
                   widgets=[PanelWidget(name='nav', x=5, y=5, width=90, height=30, layer=10),
                            PanelWidget(name='a', x=40, y=80, width=120, height=80, page='a', bg_color=ColorRGB(255,0,0)),
                            PanelWidget(name='b', x=40, y=80, width=120, height=80, page='b', bg_color=ColorRGB(0,255,0))],
                   local_actions={'nav':{'action':'switch_page','target':'b'}})


class PageTests(unittest.TestCase):
    def test_legacy_and_roundtrip_validation(self):
        old = UIScene.from_dict({'widgets':[{'type':'panel','name':'old'}]})
        self.assertEqual(old.visible_widgets(), old.widgets)
        scene = local_scene()
        self.assertEqual(UIScene.from_dict(scene.to_dict()).to_dict(), scene.to_dict())
        for kind in ('duplicate_page', 'bad_default', 'bad_widget_page', 'bad_target', 'missing_source', 'binding_conflict'):
            bad = deepcopy(scene)
            if kind == 'duplicate_page': bad.pages.append(bad.pages[0])
            if kind == 'bad_default': bad.initial_page = 'missing'
            if kind == 'bad_widget_page': bad.widgets[1].page = 'missing'
            if kind == 'bad_target': bad.local_actions['nav']['target'] = 'missing'
            if kind == 'missing_source': bad.local_actions['missing'] = bad.local_actions['nav']
            if kind == 'binding_conflict': bad.pc_bindings['nav'] = {'kind':'command','command':'P'}
            with self.subTest(kind=kind), self.assertRaises(ValueError): bad.validate_navigation()

    def test_renderer_page_isolation_and_rtl_rejection(self):
        scene = local_scene()
        renderer = PixelRenderer()
        source = scene.to_dict()
        self.assertEqual(renderer.render_scene(scene, {}, 'a')[100,80].tolist(), [255,0,0])
        self.assertEqual(renderer.render_scene(scene, {}, 'b')[100,80].tolist(), [0,255,0])
        self.assertEqual(scene.to_dict(), source)
        with tempfile.TemporaryDirectory() as folder:
            for generator in (CompactRTLGenerator(), RTLGenerator()):
                with self.assertRaises(ValueError): generator.generate(scene, Path(folder))
            self.assertFalse(list(Path(folder).glob('*.v')))

    def test_designer_create_move_configure_default_save(self):
        editor = MainWindow()
        try:
            a = editor.add_page('曲目')
            editor.canvas.add_widget('panel')
            widget = editor.canvas.ui_scene.widgets[0]
            self.assertEqual(widget.page, a)
            b = editor.add_page('播放')
            self.assertNotIn(id(widget), editor.canvas.widget_graphics_map)
            editor.canvas.set_page(a)
            editor.canvas.selected_widget = widget
            editor.on_widget_selected(widget)
            panel = editor.property_panel
            panel.navigation_combo.setCurrentIndex(panel.navigation_combo.findData(b))
            self.assertEqual(editor.canvas.ui_scene.local_actions[widget.name]['target'], b)
            panel.page_combo.setCurrentIndex(0)
            self.assertEqual(widget.page, '')
            editor.canvas.set_page(b)
            self.assertIn(id(widget), editor.canvas.widget_graphics_map)
            editor.on_default_page()
            self.assertEqual(editor.canvas.ui_scene.initial_page, b)
            with tempfile.TemporaryDirectory() as folder:
                target = Path(folder)/'pages.json'
                self.assertTrue(editor._save_to_file(str(target)))
                scene = UIScene.from_json(target)
                self.assertEqual(scene.to_dict(), editor.canvas.ui_scene.to_dict())
            editor.canvas.selected_widget = widget
            editor.on_delete_widget()
            self.assertNotIn(widget.name, editor.canvas.ui_scene.local_actions)
            editor.on_delete_page()
            self.assertEqual(len(editor.canvas.ui_scene.pages), 1)
        finally:
            editor.is_modified = False
            editor.close()

    def test_local_preview_click_changes_page(self):
        scene = local_scene()
        preview = InteractivePreviewDialog(scene)
        try:
            QTest.mouseClick(preview.canvas, Qt.LeftButton, pos=QPoint(30,20))
            self.assertEqual(preview.current_page, 'b')
            self.assertEqual(preview._hit_test(QPoint(80,100)).name, 'b')
            self.assertEqual(preview.state.ui_values, [0]*32)
        finally:
            preview.close()


class RuntimePages(unittest.TestCase):
    def setUp(self):
        self.window = SceneRuntimeWindow()
        self.real = self.window.client.port
        self.fake = FakePort()
        self.window.client.port = self.fake

    def tearDown(self):
        self.window.close()
        self.window.client.port = self.real

    def click(self, name):
        w = next(w for w in self.window.scene.widgets if w.name == name)
        QTest.mouseClick(self.window.canvas, Qt.LeftButton, pos=QPoint(w.x+w.width//2,w.y+w.height//2))

    def connect(self):
        self.window.client.open('FAKE')
        self.window.client.feed(b'P5 A\n'+SNAP)

    def test_example_three_pages_and_all_widgets_fit(self):
        scene = self.window.scene
        self.assertEqual([p['id'] for p in scene.pages], ['sd_songs','sound_fx','status_play'])
        self.assertEqual(scene.initial_page, 'sd_songs')
        for w in scene.widgets:
            self.assertLessEqual(w.x+w.width,800)
            self.assertLessEqual(w.y+w.height,480)
        for page in scene.pages:
            self.window.switch_page(page['id'])
            names = {w.name for w in scene.visible_widgets(page['id'])}
            self.assertIn('nav_sd_songs', names)
            self.assertNotIn('play' if page['id']=='sd_songs' else 'scan', names)

    def test_navigation_disconnected_busy_and_no_uart(self):
        before = self.window.scene.to_dict()
        self.click('nav_sound_fx')
        self.assertEqual(self.window.canvas.current_page, 'sound_fx')
        self.assertEqual(self.fake.sent, [])
        self.window.client.open('FAKE')
        pending = self.window.client.pending
        self.click('nav_status_play')
        self.assertEqual(self.window.canvas.current_page, 'status_play')
        self.assertEqual(self.window.client.pending, pending)
        self.assertEqual(self.fake.sent, [b'Q'])
        self.assertEqual(self.window.scene.to_dict(), before)
        self.window.client.close()
        self.click('nav_sd_songs_bg')
        self.assertEqual(self.window.canvas.current_page, 'sd_songs')
        self.assertEqual(self.fake.sent, [b'Q'])

    def test_hidden_page_cannot_trigger_command(self):
        self.connect()
        self.click('play')  # coordinates on another page, not a legal button here
        self.assertNotIn(b'P', self.fake.sent)
        self.assertEqual(self.window.canvas.current_page, 'sd_songs')
        self.window.switch_page('sound_fx')
        self.click('fx_on')
        self.assertEqual(self.fake.sent[-1], b'!E01')

    def test_catalog_paging_load_play_and_state_continuity(self):
        self.connect()
        self.click('scan')
        self.window.client.feed(b'P5 S\nSD BEGIN\n'+b''.join(f'SD F{i:02X} SONG{i:04}.BIN\n'.encode() for i in range(8))+b'SD END 08\n')
        for _ in range(6): self.click('next')
        self.assertTrue(self.window.labels['file_0'].startswith('> 06:'))
        self.assertIn('07:', self.window.labels['file_1'])
        self.click('load')
        self.assertEqual(self.fake.sent[-1], b'@S06')
        self.window.client.feed(b'SD READY 06\n')
        state = (dict(self.window.confirmed), self.window.selected, self.window.loaded_index, list(self.window.client.catalog))
        sent = list(self.fake.sent)
        self.click('nav_sound_fx'); self.click('nav_status_play')
        self.assertEqual(self.fake.sent, sent)
        self.assertEqual((self.window.confirmed,self.window.selected,self.window.loaded_index,self.window.client.catalog),state)
        self.click('auto'); self.window.client.feed(b'P5 A\n')
        self.click('play')
        self.assertEqual(self.fake.sent[-1], b'P')

    def test_page_switch_cancels_drag_without_commit(self):
        self.connect()
        self.click('nav_sound_fx')
        w = next(w for w in self.window.scene.widgets if w.name=='fx_R')
        start = QPoint(w.x+w.width//2, w.y+w.height//2)
        QTest.mousePress(self.window.canvas, Qt.LeftButton, pos=start)
        QTest.mouseMove(self.window.canvas, start-QPoint(0,40))
        self.window.switch_page('status_play')
        QTest.mouseRelease(self.window.canvas, Qt.LeftButton, pos=start)
        self.assertEqual(self.fake.sent, [b'Q',b'!Q'])
        self.assertEqual(self.window.confirmed['R'],71)


if __name__ == '__main__':
    unittest.main()
