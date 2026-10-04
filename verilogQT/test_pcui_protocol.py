"""Meaningful framing, corruption and transaction regressions; no hardware."""
import os
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
import struct
import unittest
from communication.protocol import *


def response(seq=1, value=123, index=0, status=0, button=1):
    body = struct.pack("<BHBBHB", 1, seq, status, index, value, button)
    return b"\x5a\xa5" + body + bytes([crc8(body)])


class ProtocolTests(unittest.TestCase):
    def test_crc_known_vector(self):
        self.assertEqual(crc8(b"123456789"), 0xF4)
        packet = request(0x1234, SET, 7, 65535)
        self.assertEqual(packet[:9], bytes.fromhex("a5 5a 01 34 12 01 07 ff ff"))
        self.assertEqual(len(packet), 10)

    def test_fragmentation_noise_and_coalescing(self):
        p = ReplyParser()
        packet = response(65535, 65535, 7)
        self.assertEqual(p.feed(b"noise\x5a"), [])
        self.assertEqual(p.feed(packet[1:5]), [])
        replies = p.feed(packet[5:] + response(0, 0))
        self.assertEqual([r.sequence for r in replies], [65535, 0])
        self.assertEqual(replies[0].value, 65535)
        self.assertFalse(p.buffer)

    def test_corrupt_frame_recovery(self):
        p = ReplyParser()
        packet = bytearray(response())
        packet[7] ^= 1
        replies = p.feed(packet + response(2))
        self.assertEqual(p.errors, 1)
        self.assertEqual(replies[0].sequence, 2)

    def test_invalid_arguments(self):
        for op, index, value in [(SET,8,0),(SET,0,-1),(TOGGLE,0,1),(PING,1,0)]:
            with self.assertRaises(ValueError): request(1,op,index,value)

    def test_client_matching_and_timeout(self):
        from PySide6.QtCore import QCoreApplication
        from communication.serial_client import SerialClient
        app = QCoreApplication.instance() or QCoreApplication([])
        class FakePort:
            def __init__(self): self.data=b"";self.open=True
            def readAll(self): data=self.data;self.data=b"";return data
            def isOpen(self): return self.open
            def close(self): self.open=False
        c = SerialClient()
        real_port = c.port
        c.port = FakePort()
        good=[];errors=[]
        c.confirmed.connect(good.append)
        c.failed.connect(errors.append)
        c.pending=(3,SET,0,999)
        c.port.data=response(2,999)
        c._read()
        self.assertEqual(good,[])
        self.assertIsNotNone(c.pending)
        c.port.data=response(3,999)
        c._read()
        self.assertEqual(good[0].value,999)
        self.assertIsNone(c.pending)
        c.pending=(4,TOGGLE,0,0)
        c._timeout()
        self.assertFalse(c.port.isOpen())
        self.assertEqual(len(errors),1)
        c.port=real_port


if __name__ == "__main__": unittest.main()
