"""Existing ASCII protocol regression, using an in-memory serial port."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
import sys
import unittest
from pathlib import Path
from PySide6.QtWidgets import QApplication
from communication.dimension_protocol import command,effect_snapshot,LineParser
from communication.dimension_client import DimensionClient

APP=QApplication.instance() or QApplication([])
SNAP=b'FX R47 D40 WCC M4D E00\n'


class FakePort:
    def __init__(self): self.opened=False;self.sent=[]
    def setPortName(self,*a):pass
    def setBaudRate(self,*a):pass
    def setDataBits(self,*a):pass
    def setParity(self,*a):pass
    def setStopBits(self,*a):pass
    def setFlowControl(self,*a):pass
    def open(self,*a):self.opened=True;return True
    def clear(self):pass
    def close(self):self.opened=False
    def isOpen(self):return self.opened
    def write(self,data):self.sent.append(data);return len(data)


class DimensionTests(unittest.TestCase):
    def setUp(self):
        self.client=DimensionClient()
        self.real=self.client.port
        self.fake=FakePort();self.client.port=self.fake
        self.results=[];self.errors=[];self.snapshots=[];self.notices=[]
        self.client.result.connect(lambda cmd,line:self.results.append((cmd,line)))
        self.client.failed.connect(self.errors.append)
        self.client.snapshot.connect(self.snapshots.append)
        self.client.notice.connect(self.notices.append)
        self.fake.open()

    def tearDown(self):
        self.client.close();self.client.port=self.real

    def test_encoding_and_rejection(self):
        for c in ('M','A','P','S','Q','0','1','2','3','4','5','6','!Q','!E00','!E01','!R00','!DFF','!WCC','!M4D'):
            self.assertEqual(command(c),c.encode())
        self.assertEqual(command('!rff'),b'!RFF')
        for c in ('7','!E02','!R100','!DZZ','!Z00','M\n'):
            with self.assertRaises(ValueError):command(c)

    def test_split_lines_and_corruption(self):
        parser=LineParser()
        self.assertEqual(parser.feed(b'P5 '),[])
        self.assertEqual(parser.feed(b'A\r\n'+SNAP),['P5 A',SNAP.decode().strip()])
        self.assertEqual(parser.feed(b'x'*129+b'\nP5 M\n'),['P5 M'])
        self.assertEqual(parser.feed(b'\xff\nP5 S\n'),['P5 S'])
        self.assertEqual(parser.errors,2)
        self.assertIsNone(effect_snapshot('FX R47 D40 WCC M4D E02'))

    def test_connection_queries_only(self):
        self.client.open('FAKE')
        self.assertEqual(self.fake.sent,[b'Q'])
        self.client.feed(b'P5 A\n')
        self.assertEqual(self.fake.sent,[b'Q',b'!Q'])
        self.client.feed(SNAP)
        self.assertIsNone(self.client.pending)
        self.assertEqual(self.snapshots[0]['W'],0xCC)

    def test_ack_requires_readback(self):
        self.client.send('!RFF')
        self.assertFalse(self.client.send('P'))
        self.client.feed(b'P5 R\nFX O')
        self.assertEqual(self.results,[])
        self.client.feed(b'K\n')
        self.assertEqual(self.fake.sent,[b'!RFF',b'!Q'])
        self.assertEqual(self.results,[])
        self.client.feed(b'FX RFF D40 WCC M4D E00\n')
        self.assertEqual(self.results[0][0],'!RFF')
        self.assertFalse(self.errors)
        self.assertIsNone(self.client.pending)

    def test_readback_mismatch(self):
        self.client.send('!E01');self.client.feed(b'FX OK\n'+SNAP)
        self.assertEqual(len(self.errors),1)
        self.assertEqual(self.snapshots[0]['E'],0)
        self.assertEqual(self.results,[])  # mismatch must never count as confirmed success

    def test_base_responses_notices_and_rejections(self):
        for cmd in ('M','A','P','S','0','1','2','3','4','5','6'):
            self.client.send(cmd)
            self.client.feed(b'P5 R\nP5 E\n')
            self.assertEqual(self.client.pending,cmd)
            self.client.feed(('P5 '+cmd+'\n').encode())
            self.assertIsNone(self.client.pending)
        for line in ('P5 N','P5 B','P5 C'):
            self.client.send('P');self.client.feed((line+'\n').encode())
            self.assertIsNone(self.client.pending)
        self.assertEqual(len(self.errors),3)

    def test_timeout_no_replay(self):
        self.client.send('P');self.client._timeout()
        self.assertEqual(self.fake.sent,[b'P'])
        self.assertFalse(self.fake.isOpen())
        self.assertIsNone(self.client.pending)

    def test_sd_list_split_and_load_ack(self):
        catalogs=[]
        self.client.files.connect(catalogs.append)
        self.assertFalse(self.client.send('@S00'))
        self.assertTrue(self.client.send('@L'))
        self.client.feed(b'P5 S\nSD BE')
        self.client.feed(b'GIN\nSD F00 FIRST   .BIN\nSD F01 SECOND  .BIN\nSD END 02\n')
        self.assertEqual(catalogs,[[(0,'FIRST.BIN'),(1,'SECOND.BIN')]])
        self.assertIsNone(self.client.pending)
        self.client.send('@S01')
        self.client.feed(b'P5 S\nP5 R\n')
        self.assertEqual(self.client.pending,'@S01')
        self.client.feed(b'SD READY 01\n')
        self.assertEqual(self.results[-1],('@S01','SD READY 01'))
        self.assertNotIn(b'P',self.fake.sent)  # load never sends PLAY

    def test_sd_bad_catalog_and_load_error(self):
        self.client.send('@L')
        self.client.feed(b'SD BEGIN\nSD F01 FIRST   .BIN\n')
        self.assertFalse(self.fake.isOpen())
        self.fake.open()
        self.client.send('@L');self.client.feed(b'SD BEGIN\nSD END 00\n')
        self.assertEqual(self.client.catalog,[])
        self.client.send('@L');self.client.feed(b'SD ERR F2\n')
        self.assertIsNone(self.client.pending)
        self.client.catalog=[(0,'FIRST.BIN')]
        self.client.send('@S00');self.client.feed(b'SD ERR 0A\n')
        self.assertIsNone(self.client.pending)
        self.assertFalse(any(cmd=='@S00' for cmd,line in self.results))

    def test_sd_count_cap_and_encoding(self):
        self.assertEqual(command('@s0f'),b'@S0F')
        for c in ('@S10','@SFF','@S0','@X','@L\n'):
            with self.assertRaises(ValueError):command(c)
        self.client.send('@L')
        self.client.feed(b'SD BEGIN\nSD END 01\n')
        self.assertFalse(self.fake.isOpen())

    def test_sd_gui_load_gate(self):
        from designer.dimension_window import DimensionWindow
        w=DimensionWindow();self.addCleanup(w.close)
        real=w.client.port;fake=FakePort();fake.open();w.client.port=fake
        w.scan_files()
        self.assertFalse(w.play_btn.isEnabled())
        w.client.feed(b'P5 S\nSD BEGIN\nSD F00 FIRST   .BIN\nSD END 01\n')
        self.assertEqual(w.song_list.count(),1)
        w.load_song();w.client.feed(b'P5 R\n')
        self.assertFalse(w.play_btn.isEnabled())
        w.client.feed(b'SD READY 00\n')
        self.assertTrue(w.play_btn.isEnabled())
        w.client.close();w.client.port=real

    def test_gui_target_confirmation_and_disconnect(self):
        from designer.dimension_window import DimensionWindow
        w=DimensionWindow()
        self.addCleanup(w.close)
        w.targets['R'].setValue(200)
        self.assertIn('未确认',w.readbacks['R'].text())
        w.accept_snapshot(effect_snapshot(SNAP.decode().strip()))
        self.assertIn('71',w.readbacks['R'].text())
        self.assertEqual(w.targets['R'].value(),200)
        w.accept_result('P','P5 N')
        self.assertIn('未知',w.playback.text())
        w.accept_result('P','P5 P')
        self.assertIn('请求已接受',w.playback.text())
        w.notice('P5 E')
        self.assertIn('错误',w.playback.text())
        w.link_changed(False)
        self.assertIn('未确认',w.readbacks['R'].text())
        w.show();APP.processEvents()
        output_dir=Path(__file__).resolve().parent/'test_output'
        output_dir.mkdir(exist_ok=True)
        self.assertTrue(w.grab().save(str(output_dir/'dimension_preview.png')))
        sys.path.insert(0,os.path.join(os.path.dirname(__file__),'designer'))
        from ui_designer import MainWindow
        editor=MainWindow();editor.on_dimension_control()
        self.assertIsInstance(editor._dimension_window,DimensionWindow)
        editor._dimension_window.close();editor.close()


if __name__=='__main__':unittest.main()
