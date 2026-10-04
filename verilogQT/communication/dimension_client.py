"""Sequential legacy transactions; unsolicited P5 R/E cannot acknowledge a command."""
from PySide6.QtCore import QObject, QIODevice, QTimer, Signal
from PySide6.QtSerialPort import QSerialPort
from .dimension_protocol import command, effect_snapshot, LineParser
import re


class DimensionClient(QObject):
    result = Signal(str, str)
    snapshot = Signal(object)
    notice = Signal(str)
    failed = Signal(str)
    connected = Signal(bool)
    busy_changed = Signal(bool)
    trace = Signal(str)
    files = Signal(object)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.port=QSerialPort(self)
        self.port.readyRead.connect(self._read)
        self.port.errorOccurred.connect(self._error)
        self.timer=QTimer(self)
        self.timer.setSingleShot(True)
        self.timer.timeout.connect(self._timeout)
        self.parser=LineParser()
        self.pending=None
        self.readback=None
        self.initializing=False
        self.catalog=[]
        self.list_started=False
        self.list_rows=[]

    def open(self, name):
        self.close()
        self.port.setPortName(name)
        self.port.setBaudRate(115200)
        self.port.setDataBits(QSerialPort.DataBits.Data8)
        self.port.setParity(QSerialPort.Parity.NoParity)
        self.port.setStopBits(QSerialPort.StopBits.OneStop)
        self.port.setFlowControl(QSerialPort.FlowControl.NoFlowControl)
        if not self.port.open(QIODevice.OpenModeFlag.ReadWrite):
            self.failed.emit(self.port.errorString())
            return False
        self.port.clear()
        self.parser=LineParser()
        self.connected.emit(True)
        self.initializing=True
        return self.send('Q')

    def close(self):
        self.timer.stop()
        self.pending=None
        self.readback=None
        self.initializing=False
        self.catalog=[]
        self.list_started=False
        self.list_rows=[]
        self.port.close()
        self.busy_changed.emit(False)
        self.connected.emit(False)

    def send(self, text):
        packet=command(text)
        if not self.port.isOpen() or self.pending is not None:
            return False
        if text.upper().startswith('@S') and int(text[2:],16)>=len(self.catalog):
            self.failed.emit('请先扫描文件列表，并选择有效编号')
            return False
        if text.upper()=='@L':
            self.catalog=[]
            self.list_rows=[]
            self.list_started=False
        self.pending=packet.decode('ascii')
        self.busy_changed.emit(True)
        return self._write(packet)

    def _write(self, packet):
        self.trace.emit('TX '+packet.decode('ascii'))
        if self.port.write(packet)!=len(packet):
            self._fatal('串口写入失败，结果未确认')
            return False
        self.timer.start(35000 if packet.startswith(b'@') else 3000)
        return True

    def _read(self):
        self.feed(bytes(self.port.readAll()))

    def feed(self, data):
        for line in self.parser.feed(data):
            self.trace.emit('RX '+line)
            if line in ('P5 R','P5 E'):
                self.notice.emit(line)
                continue
            current=self.pending
            if current is None:
                self.notice.emit(line)
                continue
            if current.startswith('@'):
                self._sd_line(current,line)
                continue
            if current.startswith('!'):
                if current=='!Q':
                    snapshot=effect_snapshot(line)
                    if snapshot is not None:
                        self.snapshot.emit(snapshot)
                        if self.readback:
                            original=self.readback
                            self.readback=None
                            if snapshot[original[1]]!=int(original[2:],16):
                                self._finish(original,line,'效果器回读与目标值不一致')
                            else: self._finish(original,line)
                        else: self._finish(current,line)
                    elif line=='FX ERR': self._finish(current,line,'效果器查询失败')
                    continue
                if line=='FX OK':
                    # ACK lacks parameter/value: query and verify authoritative values.
                    self.readback=current
                    self.pending='!Q'
                    self._write(b'!Q')
                elif line=='FX ERR': self._finish(current,line,'效果器参数被拒绝')
                continue
            expected={'Q':('M','A')}.get(current,(current,))
            if line in tuple('P5 '+ch for ch in expected):
                self._finish(current,line)
            elif line in ('P5 N','P5 B','P5 C'):
                reason={'P5 N':'未就绪或当前模式不允许','P5 B':'已在播放','P5 C':'无效命令'}[line]
                self._finish(current,line,reason)
            else:
                self.notice.emit(line)

    def _sd_line(self,current,line):
        if line=='FX ERR':
            self._finish(current,line,'文件命令格式或半包错误；请重新扫描')
            return
        if re.fullmatch(r'SD ERR [0-9A-F]{2}',line):
            codes={'F0':'SD 操作超时，请重新扫描','F1':'文件编号无效，请重新扫描',
                   'F2':'不支持的文件系统（需要 FAT16/FAT32、512 字节扇区）'}
            code=line[-2:]
            self._finish(current,line,codes.get(code,f'歌曲校验/加载失败，错误码 {code}；未播放'))
            return
        if current=='@L':
            if line=='SD BEGIN' and not self.list_started:
                self.list_started=True
                return
            match=re.fullmatch(r'SD F([0-9A-F]{2}) ([ -~]{12})',line)
            if match and self.list_started:
                index=int(match[1],16)
                name=match[2]
                if index!=len(self.list_rows) or index>=16 or name[8:].upper()!='.BIN':
                    self._fatal('文件列表协议错误；请重连重新扫描')
                    return
                self.list_rows.append((index,name[:8].rstrip()+name[8:]))
                return
            match=re.fullmatch(r'SD END ([0-9A-F]{2})',line)
            if match:
                if not self.list_started or int(match[1],16)!=len(self.list_rows):
                    self._fatal('文件列表数量不一致；请重连重新扫描')
                    return
                self.catalog=list(self.list_rows)
                self.files.emit(self.catalog)
                self._finish(current,line)
                return
        elif line=='SD READY '+current[2:]:
            self._finish(current,line)
            return
        self.notice.emit(line)

    def _finish(self, text, line, error=None):
        self.timer.stop()
        self.pending=None
        self.readback=None
        if error: self.failed.emit(error)
        else: self.result.emit(text,line)
        if self.initializing and text=='Q' and not error:
            self.initializing=False
            self.send('!Q')
        else:
            self.initializing=False
            self.busy_changed.emit(False)

    def _timeout(self):
        text=self.readback or self.pending or '?'
        self._fatal(f'{text} 超时，结果未知；请重连查询。未自动重发。')

    def _fatal(self, message):
        self.close()
        self.failed.emit(message)

    def _error(self, error):
        if error==QSerialPort.SerialPortError.ResourceError:
            self._fatal('设备断开：'+self.port.errorString())
