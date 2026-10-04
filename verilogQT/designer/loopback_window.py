"""Hardware-backed first UI: requested values and confirmed values are distinct."""
from PySide6.QtCore import Qt, QTimer
from PySide6.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QComboBox, QSlider, QSpinBox, QPlainTextEdit)
from PySide6.QtSerialPort import QSerialPortInfo
from communication.serial_client import SerialClient
from communication.protocol import SET, QUERY, TOGGLE, PING
from .interactive_state import InteractiveState
from .pixel_renderer import PixelRenderer
from .ui_schema import UIScene
from PySide6.QtGui import QImage, QPixmap, QFont, QFontDatabase
from pathlib import Path
import json


class LoopbackWindow(QMainWindow):
    def __init__(self, parent=None):
        super().__init__(parent)
        # Offscreen Qt on Windows may have no system-font inventory.
        font_path = Path('C:/Windows/Fonts/msyh.ttc')
        if not QFontDatabase.families() and font_path.exists():
            QFontDatabase.addApplicationFont(str(font_path))
        self.setFont(QFont('Microsoft YaHei', 10))
        self.setWindowTitle("FPGA PC UI 串口回环 · 115200 8N1")
        self.resize(850, 560)
        self.client = SerialClient(self)
        self.ok_count = 0
        self.error_count = 0
        self.dirty = False
        self.state = InteractiveState()
        self.known_slots = set()
        scene_path = Path(__file__).resolve().parents[1] / 'examples' / 'pcui_loopback.json'
        self.scene = UIScene.from_dict(json.loads(scene_path.read_text(encoding='utf-8')))
        self.renderer = PixelRenderer(self.scene.width, self.scene.height)
        root = QWidget()
        layout = QVBoxLayout(root)
        self.setCentralWidget(root)
        ports = QHBoxLayout()
        self.port_box = QComboBox()
        self.port_box.setEditable(True)
        refresh = QPushButton("刷新串口")
        refresh.clicked.connect(self.refresh_ports)
        self.connect_btn = QPushButton("连接")
        self.connect_btn.clicked.connect(self.toggle_connection)
        for widget in (self.port_box, refresh, self.connect_btn): ports.addWidget(widget)
        layout.addLayout(ports)
        self.connection = QLabel("未连接；回读值须由 FPGA 回复确认")
        layout.addWidget(self.connection)
        self.scene_view = QLabel()
        layout.addWidget(self.scene_view)
        self.scene_status = QLabel("场景尚无已确认数据；空条不表示 FPGA 值为 0")
        layout.addWidget(self.scene_status)
        self.register = QComboBox()
        self.register.addItems([f"寄存器 {i}" for i in range(8)])
        self.register.currentIndexChanged.connect(self.change_register)
        layout.addWidget(self.register)
        self.slider = QSlider(Qt.Orientation.Horizontal)
        self.slider.setRange(0, 65535)
        self.target = QSpinBox()
        self.target.setRange(0, 65535)
        self.slider.valueChanged.connect(self.target.setValue)
        self.target.valueChanged.connect(self.slider.setValue)
        self.target.valueChanged.connect(self.schedule_write)
        layout.addWidget(QLabel("目标值：拖动后 120 ms 合并发送；回读值只由有效回复更新"))
        layout.addWidget(self.slider)
        layout.addWidget(self.target)
        self.confirmed_value = QLabel("FPGA 回读：未确认")
        self.button_value = QLabel("FPGA 按钮：未确认")
        self.counts = QLabel("成功 0 · 错误 0")
        for widget in (self.confirmed_value, self.button_value, self.counts): layout.addWidget(widget)
        actions = QHBoxLayout()
        self.query = QPushButton("查询选定寄存器")
        self.query.clicked.connect(lambda: self.client.send(QUERY, self.register.currentIndex()))
        self.toggle = QPushButton("切换 FPGA 按钮 / LED")
        self.toggle.clicked.connect(lambda: self.client.send(TOGGLE))
        self.ping = QPushButton("Ping")
        self.ping.clicked.connect(lambda: self.client.send(PING))
        for widget in (self.query, self.toggle, self.ping): actions.addWidget(widget)
        layout.addLayout(actions)
        self.log = QPlainTextEdit()
        self.log.setReadOnly(True)
        self.log.setMaximumBlockCount(300)
        layout.addWidget(self.log)
        self.debounce = QTimer(self)
        self.debounce.setSingleShot(True)
        self.debounce.timeout.connect(self.flush_write)
        self.client.trace.connect(self.log.appendPlainText)
        self.client.confirmed.connect(self.accept_reply)
        self.client.failed.connect(self.show_error)
        self.client.connected.connect(self.link_changed)
        self.client.busy_changed.connect(self.busy_changed)
        self.refresh_ports()
        self.link_changed(False)

    def render_confirmed_scene(self):
        frame = self.renderer.render_scene(self.scene, self.state.to_dict())
        h, w, _ = frame.shape
        image = QImage(frame.data, w, h, w*3, QImage.Format.Format_RGB888)
        self.scene_view.setPixmap(QPixmap.fromImage(image))
        slots = ', '.join(str(i) for i in sorted(self.known_slots)) or '无'
        self.scene_status.setText(f"已确认寄存器：{slots}；其余柱条尚未读取")

    def refresh_ports(self):
        current = self.port_box.currentText()
        self.port_box.clear()
        self.port_box.addItems([p.portName() for p in QSerialPortInfo.availablePorts()])
        if current: self.port_box.setCurrentText(current)

    def toggle_connection(self):
        if self.client.port.isOpen(): self.client.close()
        else: self.client.open(self.port_box.currentText())

    def link_changed(self, connected):
        self.dirty = False
        self.known_slots.clear()
        self.state = InteractiveState()
        self.render_confirmed_scene()
        self.debounce.stop()
        self.connect_btn.setText("断开" if connected else "连接")
        self.connection.setText("串口已打开，等待 FPGA 确认" if connected else "串口未连接")
        self.confirmed_value.setText("FPGA 回读：未确认")
        self.button_value.setText("FPGA 按钮：未确认")
        self.port_box.setEnabled(not connected)
        self.slider.setEnabled(connected)
        self.target.setEnabled(connected)
        self.busy_changed(False)

    def busy_changed(self, busy):
        enabled = self.client.port.isOpen() and not busy
        for widget in (self.register, self.query, self.toggle, self.ping): widget.setEnabled(enabled)
        if not busy and self.dirty: self.debounce.start(120)

    def schedule_write(self, value):
        if self.client.port.isOpen():
            self.dirty = True
            self.debounce.start(120)

    def flush_write(self):
        if self.client.send(SET, self.register.currentIndex(), self.target.value()): self.dirty = False

    def change_register(self, index):
        # Cancel a not-yet-sent edit so it cannot accidentally target a new slot.
        self.dirty = False
        self.debounce.stop()
        self.confirmed_value.setText("FPGA 回读：未确认")
        self.client.send(QUERY, index)

    def accept_reply(self, reply):
        self.ok_count += 1
        self.state.set_knob_value(reply.index, reply.value)
        self.known_slots.add(reply.index)
        self.render_confirmed_scene()
        self.connection.setText(f"FPGA 已确认 · seq={reply.sequence}")
        if reply.index == self.register.currentIndex():
            self.confirmed_value.setText(f"FPGA 回读：{reply.value} · 寄存器 {reply.index}")
        self.button_value.setText(f"FPGA 按钮：{'开启' if reply.button else '关闭'}")
        self.update_counts()

    def show_error(self, message):
        self.error_count += 1
        self.connection.setText(message)
        self.log.appendPlainText("ERROR " + message)
        self.update_counts()

    def update_counts(self):
        self.counts.setText(f"成功 {self.ok_count} · 错误 {self.error_count} · 坏帧 {self.client.parser.errors}")

    def closeEvent(self, event):
        self.client.close()
        super().closeEvent(event)
