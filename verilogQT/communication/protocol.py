"""PCUI v1, fixed-size little-endian messages, CRC-8/ATM (poly 0x07)."""
from dataclasses import dataclass
import struct

SET, QUERY, TOGGLE, PING = 1, 2, 3, 4
STATUS = {0: "OK", 1: "CRC错误", 2: "协议版本错误", 3: "寄存器越界", 4: "命令/参数错误"}


def crc8(data):
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = ((crc << 1) ^ (7 if crc & 128 else 0)) & 255
    return crc


def request(sequence, opcode, index=0, value=0):
    if not 0 <= sequence <= 65535 or not 0 <= value <= 65535:
        raise ValueError("sequence/value must be uint16")
    if opcode not in (SET, QUERY, TOGGLE, PING):
        raise ValueError("unknown opcode")
    if not 0 <= index < 8 or (opcode in (TOGGLE, PING) and (index or value)):
        raise ValueError("invalid index/value")
    body = struct.pack("<BHBBH", 1, sequence, opcode, index, value)
    return b"\xa5\x5a" + body + bytes([crc8(body)])


@dataclass(frozen=True)
class Reply:
    sequence: int
    status: int
    index: int
    value: int
    button: int


class ReplyParser:
    def __init__(self):
        self.buffer = bytearray()
        self.errors = 0

    def feed(self, data):
        self.buffer.extend(data)
        replies = []
        while True:
            start = self.buffer.find(b"\x5a\xa5")
            if start < 0:
                self.buffer[:] = self.buffer[-1:] if self.buffer[-1:] == b"\x5a" else b""
                break
            del self.buffer[:start]
            if len(self.buffer) < 11:
                break
            packet = bytes(self.buffer[:11])
            if packet[2] != 1 or crc8(packet[2:10]) != packet[10] or packet[9] > 1:
                self.errors += 1
                del self.buffer[0]
                continue
            _, seq, status, index, value, button = struct.unpack("<BHBBHB", packet[2:10])
            replies.append(Reply(seq, status, index, value, button))
            del self.buffer[:11]
        return replies
