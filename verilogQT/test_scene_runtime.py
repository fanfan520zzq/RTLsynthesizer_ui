"""Offscreen real mouse events + in-memory UART. Not a board test."""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
import json
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from PySide6.QtCore import Qt, QPoint
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication, QDialog
from designer.scene_runtime import SceneRuntimeWindow, EXAMPLE, validate_bindings
from designer.ui_schema import UIScene, PanelWidget
from generator.compact_rtl_generator import CompactRTLGenerator
from test_dimension import FakePort, SNAP

APP = QApplication.instance() or QApplication([])
OUTPUT_DIR = Path(__file__).resolve().parent/'test_output'
OUTPUT_DIR.mkdir(exist_ok=True)


class SceneTests(unittest.TestCase):
    def setUp(self):
        self.window = SceneRuntimeWindow()
        self.real = self.window.client.port
        self.fake = FakePort()
        self.window.client.port = self.fake

    def tearDown(self):
        self.window.close()
        self.window.client.port = self.real

    def connect(self, mode='M'):
        self.window.port_box.setCurrentText('FAKE - OFFSCREEN TEST')
        self.window.client.open('FAKE')
        self.window.client.feed(('P5 '+mode+'\n').encode())
        self.window.client.feed(SNAP)

    def point(self, name):
        w = next(w for w in self.window.scene.widgets if w.name == name)
        if w.page and w.page != self.window.canvas.current_page:
            self.window.switch_page(w.page)
        return QPoint(w.x + w.width//2, w.y + w.height//2)

    def click(self, name):
        QTest.mouseClick(self.window.canvas, Qt.LeftButton, pos=self.point(name))

    def catalog(self):
        self.click('scan')
        self.window.client.feed(b'P5 S\nSD BEGIN\nSD F00 FIRST   .BIN\nSD F01 SECOND  .BIN\nSD END 02\n')

    def loaded(self):
        self.catalog()
        self.click('load')
        self.window.client.feed(b'SD READY 00\n')

    def test_schema_and_validation(self):
        source = json.loads(EXAMPLE.read_text(encoding='utf-8'))
        original = deepcopy(source)
        scene = UIScene.from_dict(source)
        self.assertEqual(source, original)
        self.assertEqual(UIScene.from_dict(scene.to_dict()).pc_bindings, scene.pc_bindings)
        for change in ('missing', 'duplicate', 'range', 'command', 'feedback', 'shape'):
            bad = UIScene.from_dict(scene.to_dict())
            if change == 'missing': bad.pc_bindings['missing'] = {'kind':'scan'}
            if change == 'duplicate': bad.widgets.append(PanelWidget(name='play'))
            if change == 'range': next(w for w in bad.widgets if w.name=='fx_R').max_value=127
            if change == 'command': bad.pc_bindings['play']['command']='@S10'
            if change == 'feedback': bad.pc_bindings['mode']['field']='invented_progress'
            if change == 'shape': bad.pc_bindings['fx_R'] = []
            with self.assertRaises(ValueError): validate_bindings(bad)

    def test_panel_resolution_bounds_and_fullscreen_state(self):
        self.assertEqual((self.window.scene.width,self.window.scene.height),(800,480))
        for widget in self.window.scene.widgets:
            with self.subTest(widget=widget.name):
                self.assertGreaterEqual(widget.x,0)
                self.assertGreaterEqual(widget.y,0)
                self.assertLessEqual(widget.x+widget.width,800)
                self.assertLessEqual(widget.y+widget.height,480)
        self.connect('A')
        self.loaded()
        state = (dict(self.window.confirmed),self.window.loaded_index,list(self.fake.sent))
        self.window.show(); APP.processEvents()
        QTest.keyClick(self.window,Qt.Key_F11); APP.processEvents()
        self.assertTrue(self.window.panel_view)
        self.assertTrue(self.window.isFullScreen())
        for widget in (self.window.port_controls,self.window.instructions,self.window.status,self.window.log):
            self.assertFalse(widget.isVisible())
        self.assertEqual(self.window.canvas.pixmap().width(),800)
        self.assertEqual(self.window.canvas.pixmap().height(),480)
        self.click('play')
        self.assertEqual(self.fake.sent[-1],b'P')
        self.window.client.feed(b'P5 P\n')
        QTest.keyClick(self.window,Qt.Key_Escape); APP.processEvents()
        self.assertFalse(self.window.panel_view)
        self.assertTrue(self.window.port_controls.isVisible())
        self.assertEqual(self.window.confirmed,state[0])
        self.assertEqual(self.window.loaded_index,state[1])
        self.assertEqual(self.fake.sent,state[2]+[b'P'])  # view toggle sends nothing
        output = OUTPUT_DIR/'scene_panel_800x480_preview.png'
        self.assertTrue(self.window.canvas.pixmap().save(str(output)))

    def test_connect_gates_until_queries_finish(self):
        self.click('scan')
        self.assertEqual(self.fake.sent, [])
        self.window.client.open('FAKE')
        self.click('scan')
        self.assertEqual(self.fake.sent, [b'Q'])
        self.window.client.feed(b'P5 M\n')
        self.click('scan')
        self.assertEqual(self.fake.sent, [b'Q', b'!Q'])
        self.window.client.feed(SNAP)
        self.assertIn('scan', self.window.canvas.enabled_names)
        self.assertNotIn('play', self.window.canvas.enabled_names)
        self.assertEqual(self.window.confirmed['R'], 71)

    def test_file_navigation_load_gate_and_play(self):
        self.connect()
        self.catalog()
        self.assertIsNone(self.window.loaded_index)
        self.click('next')
        self.assertEqual(self.window.selected, 1)
        self.click('load')
        self.assertEqual(self.fake.sent[-1], b'@S01')
        self.window.client.feed(b'P5 R\nP5 S\n')
        self.assertNotIn('play', self.window.canvas.enabled_names)
        self.window.client.feed(b'SD READY 01\n')
        self.assertEqual(self.window.loaded_index, 1)
        self.assertIn('SECOND.BIN', self.window.labels['loaded'])
        self.assertNotIn(b'P', self.fake.sent)
        self.click('prev')
        self.assertEqual(self.window.selected, 0)
        self.assertIn('SECOND.BIN', self.window.labels['loaded'])
        self.click('auto')
        self.window.client.feed(b'P5 A\n')
        self.click('play')
        self.assertEqual(self.fake.sent[-1], b'P')
        self.assertNotIn('START ACCEPTED', self.window.labels['playback'])
        self.window.client.feed(b'P5 P\n')
        self.assertIn('START ACCEPTED', self.window.labels['playback'])
        self.click('auto'); self.window.client.feed(b'P5 A\n')
        self.assertIn('START ACCEPTED', self.window.labels['playback'])  # no-op A is not STOP
        self.click('stop'); self.window.client.feed(b'P5 S\n')
        self.assertIn('STOP CONFIRMED', self.window.labels['playback'])

    def test_knob_drag_one_transaction_and_confirmed_readback(self):
        self.connect()
        before = self.window.scene.to_dict()
        start = self.point('fx_R')
        QTest.mousePress(self.window.canvas, Qt.LeftButton, pos=start)
        QTest.mouseMove(self.window.canvas, start-QPoint(0,40))
        self.assertEqual(self.fake.sent, [b'Q', b'!Q'])
        self.assertEqual(self.window.confirmed['R'], 71)
        self.assertEqual(self.window.labels['R'], 'R READ: 71')
        QTest.mouseRelease(self.window.canvas, Qt.LeftButton, pos=start-QPoint(0,40))
        self.assertEqual(self.fake.sent[-1], b'!R87')
        self.assertEqual(self.window.confirmed['R'], 71)
        self.click('fx_on')
        self.assertEqual(self.fake.sent[-1], b'!R87')  # busy: no second request
        self.window.client.feed(b'FX OK\n')
        self.assertEqual(self.window.confirmed['R'], 71)
        self.assertEqual(self.fake.sent[-1], b'!Q')
        self.window.client.feed(b'FX R87 D40 WCC M4D E00\n')
        self.assertEqual(self.window.confirmed['R'], 135)
        self.assertEqual(self.window.scene.to_dict(), before)

    def test_release_outside_cancel_focus_and_busy(self):
        self.connect()
        QTest.mousePress(self.window.canvas, Qt.LeftButton, pos=self.point('scan'))
        QTest.mouseRelease(self.window.canvas, Qt.LeftButton, pos=QPoint(0,0))
        self.assertEqual(self.fake.sent, [b'Q', b'!Q'])
        start = self.point('fx_D')
        QTest.mousePress(self.window.canvas, Qt.LeftButton, pos=start)
        QTest.mouseMove(self.window.canvas, start-QPoint(0,50))
        self.window.canvas.cancel_input()
        QTest.mouseRelease(self.window.canvas, Qt.LeftButton, pos=start)
        self.assertEqual(self.fake.sent, [b'Q', b'!Q'])

    def test_effect_mismatch_uses_real_snapshot(self):
        self.connect()
        self.window.edit_effect('fx_D', 255)
        self.window.client.feed(b'FX OK\n'+SNAP)
        self.assertEqual(self.window.confirmed['D'], 64)
        self.assertIn('不一致', self.window.status.text())
        self.assertIn('ERROR', self.window.labels['status'])

    def test_panel_error_visible_without_debug_log(self):
        self.connect('A')
        self.loaded()
        self.window.set_panel_view(True)
        self.window.client.feed(b'P5 E\n')
        self.assertFalse(self.window.log.isVisible())
        self.assertIn('ERROR', self.window.labels['status'])
        self.assertIn('ERROR', self.window.labels['playback'])
        self.assertNotIn('play', self.window.canvas.enabled_names)
        self.window.set_panel_view(False)

    def test_failure_disconnect_and_no_replay(self):
        self.connect('A')
        self.loaded()
        self.window.client.feed(b'P5 E\n')
        self.assertIsNone(self.window.loaded_index)
        self.assertNotIn('play', self.window.canvas.enabled_names)
        self.click('load'); self.window.client.feed(b'SD ERR 0A\n')
        self.assertNotIn('auto', self.window.canvas.enabled_names)
        self.click('scan')
        sent = list(self.fake.sent)
        self.window.client._timeout()
        self.assertEqual(self.fake.sent, sent)
        self.assertEqual(self.window.confirmed, {})
        self.assertEqual(self.window.canvas.enabled_names, set())
        self.assertIn('UNKNOWN', self.window.labels['mode'])
        self.window.client.open('FAKE')
        self.window.client.feed(b'P5 A\n'+SNAP)
        self.assertEqual(self.fake.sent[len(sent):], [b'Q', b'!Q'])
        self.assertNotIn('play', self.window.canvas.enabled_names)

    def test_all_presets_enable_and_query(self):
        self.connect()
        for i in range(7):
            self.click(f'preset_{i}')
            self.assertEqual(self.fake.sent[-1], str(i).encode())
            self.window.client.feed(f'P5 {i}\n'.encode())
            self.assertIn(f'{i} (LAST ACK)', self.window.labels['preset'])
        self.click('fx_on'); self.window.client.feed(b'FX OK\nFX R47 D40 WCC M4D E01\n')
        self.assertEqual(self.window.confirmed['E'], 1)
        self.click('fx_off'); self.window.client.feed(b'FX OK\n'+SNAP)
        self.assertEqual(self.window.confirmed['E'], 0)
        self.click('query'); self.window.client.feed(b'P5 A\n')
        self.assertEqual(self.window.mode, 'A')

    def test_export_boundary_and_old_scene(self):
        with self.assertRaisesRegex(ValueError, 'PC UART'):
            CompactRTLGenerator.validate(self.window.scene)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            CompactRTLGenerator().generate(UIScene(name='plain', widgets=[PanelWidget()]), path)
            self.assertEqual([p.name for p in path.glob('*.v')], ['ui_generated_scene.v'])

    def test_editor_save_binding_and_runtime_snapshot(self):
        from designer.ui_designer import MainWindow, PCBindingEditorDialog
        editor = MainWindow()
        try:
            editor.canvas.load_scene(UIScene.from_json(str(EXAMPLE)))
            dialog = PCBindingEditorDialog(editor.canvas.ui_scene, editor)
            dialog._save()
            self.assertEqual(dialog.result(), QDialog.DialogCode.Accepted)
            with tempfile.TemporaryDirectory() as folder:
                file = str(Path(folder)/'scene.json')
                self.assertTrue(editor._save_to_file(file))
                self.assertEqual(UIScene.from_json(file).pc_bindings, self.window.scene.pc_bindings)
            editor.on_scene_control()
            child = next(w for w in editor.findChildren(SceneRuntimeWindow))
            original_x = child.scene.widgets[0].x
            editor.canvas.ui_scene.widgets[0].x += 20
            self.assertEqual(child.scene.widgets[0].x, original_x)
            editor.canvas.ui_scene.pc_bindings['play']['command'] = 'S'
            self.assertEqual(child.scene.pc_bindings['play']['command'], 'P')
            child.close()
            self.connect('A'); self.loaded()
            self.window.show(); APP.processEvents()
            output = OUTPUT_DIR/'scene_runtime_preview.png'
            self.assertTrue(self.window.grab().save(str(output)))
        finally:
            editor.is_modified = False
            editor.close()


if __name__ == '__main__':
    unittest.main()
