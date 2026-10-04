"""Existing Dimension ASCII protocol, based on dimension_uart RTL."""
import re

DEFAULTS = {'R': 0x47, 'D': 0x40, 'W': 0xCC, 'M': 0x4D}
FX_QUERY = re.compile(r'^FX R([0-9A-F]{2}) D([0-9A-F]{2}) W([0-9A-F]{2}) M([0-9A-F]{2}) E(0[01])$')


def command(text):
    text = text.upper()
    if text in ('M', 'A', 'P', 'S', 'Q', '!Q', '@L') or text in tuple(str(i) for i in range(7)):
        return text.encode('ascii')
    if re.fullmatch(r'@S0[0-9A-F]', text):
        return text.encode('ascii')
    if re.fullmatch(r'![RDWM][0-9A-F]{2}', text) or text in ('!E00', '!E01'):
        return text.encode('ascii')
    raise ValueError('Unsupported Dimension command')


def effect_snapshot(line):
    match = FX_QUERY.fullmatch(line)
    if not match:
        return None
    return dict(zip(('R', 'D', 'W', 'M', 'E'), (int(x,16) for x in match.groups())))


class LineParser:
    def __init__(self):
        self.buffer = bytearray()
        self.discarding = False
        self.errors = 0

    def feed(self, data):
        lines=[]
        for byte in data:
            if byte == 10:
                if not self.discarding:
                    try:
                        text=self.buffer.rstrip(b'\r').decode('ascii')
                        if text: lines.append(text)
                    except UnicodeDecodeError:
                        self.errors += 1
                self.buffer.clear()
                self.discarding=False
            elif not self.discarding:
                self.buffer.append(byte)
                if len(self.buffer)>128:
                    self.errors+=1
                    self.buffer.clear()
                    self.discarding=True
        return lines
