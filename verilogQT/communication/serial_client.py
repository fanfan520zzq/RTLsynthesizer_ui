"""Nonblocking Qt serial client. One request in flight, no automatic retries."""
from PySide6.QtCore import QObject, QIODevice, QTimer, Signal
from PySide6.QtSerialPort import QSerialPort
from .protocol import ReplyParser, request, PING, SET, QUERY, STATUS


class SerialClient(QObject):
    confirmed = Signal(object)
    failed = Signal(str)
    connected = Signal(bool)
    busy_changed = Signal(bool)
    trace = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.port = QSerialPort(self)
        self.port.readyRead.connect(self._read)
        self.port.errorOccurred.connect(self._port_error)
        self.timer = QTimer(self)
        self.timer.setSingleShot(True)
        self.timer.timeout.connect(self._timeout)
        self.parser = ReplyParser()
        self.sequence = 0
        self.pending = None

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
        self.parser = ReplyParser()
        self.connected.emit(True)
        self.send(PING)
        return True

    def close(self):
        self.timer.stop()
        self.pending = None
        self.port.close()
        self.busy_changed.emit(False)
        self.connected.emit(False)

    def send(self, opcode, index=0, value=0):
        if not self.port.isOpen() or self.pending is not None:
            return False
        self.sequence = (self.sequence + 1) & 65535
        packet = request(self.sequence, opcode, index, value)
        self.pending = (self.sequence, opcode, index, value)
        self.busy_changed.emit(True)
        if self.port.write(packet) != len(packet):
            self._fatal("串口写入失败")
            return False
        self.trace.emit("TX " + packet.hex(" "))
        self.timer.start(1000)
        return True

    def _read(self):
        data = bytes(self.port.readAll())
        self.trace.emit("RX " + data.hex(" "))
        old_errors = self.parser.errors
        for reply in self.parser.feed(data):
            if self.pending is None or reply.sequence != self.pending[0]:
                self.trace.emit(f"忽略迟到/无请求响应 seq={reply.sequence}")
                continue
            seq, opcode, index, value = self.pending
            if reply.index != index or (reply.status == 0 and opcode == SET and reply.value != value):
                self._fatal("匹配请求的回读内容不一致")
                return
            self.timer.stop()
            self.pending = None
            self.busy_changed.emit(False)
            if reply.status:
                self.failed.emit(STATUS.get(reply.status, f"错误 {reply.status}"))
            else:
                self.confirmed.emit(reply)
        if self.parser.errors != old_errors:
            self.trace.emit(f"坏响应帧累计 {self.parser.errors}")

    def _timeout(self):
        self._fatal("请求超时：结果未确认。请重连后查询；不自动重发按钮命令。")

    def _fatal(self, message):
        self.close()
        self.failed.emit(message)

    def _port_error(self, error):
        if error == QSerialPort.SerialPortError.ResourceError:
            self._fatal("设备断开：" + self.port.errorString())
