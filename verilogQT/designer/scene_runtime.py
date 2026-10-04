"""Editable scene -> tested Dimension ASCII client; never simulate board feedback."""
from copy import deepcopy
from pathlib import Path

from PySide6.QtCore import Qt, Signal, QEvent
from PySide6.QtGui import QImage, QPixmap, QPainter, QColor, QFont, QFontDatabase, QShortcut, QKeySequence
from PySide6.QtWidgets import (QMainWindow, QWidget, QLabel, QVBoxLayout,
                              QHBoxLayout, QComboBox, QPushButton, QPlainTextEdit,
                              QScrollArea, QFrame)
from PySide6.QtSerialPort import QSerialPortInfo
from communication.dimension_client import DimensionClient
from .ui_schema import UIScene
from .pixel_renderer import PixelRenderer


EXAMPLE = Path(__file__).resolve().parents[1] / 'examples' / 'dimension_autoplay_pc.json'
COMMANDS = {'M', 'A', 'P', 'S', 'Q', '!Q', '!E00', '!E01', *map(str, range(7))}
FEEDBACK = {'mode', 'playback', 'selected', 'loaded', 'status', 'preset',
            'R', 'D', 'W', 'M', 'E', *(f'file_{i}' for i in range(6))}


def validate_bindings(scene):
    """Reject typos/ambiguous names before opening any serial port."""
    scene.validate_navigation()
    bindings = scene.pc_bindings
    if not isinstance(bindings, dict) or not bindings:
        raise ValueError('场景需要非空 pc_bindings；请先打开 dimension_autoplay_pc.json')
    if any(not isinstance(name, str) or not isinstance(binding, dict) for name, binding in bindings.items()):
        raise ValueError('pc_bindings 必须为 控件名 -> 绑定对象')
    if not (1 <= scene.width <= 2048 and 1 <= scene.height <= 1024):
        raise ValueError('PC 场景大小必须在 2048x1024 以内')
    if scene.interactions:
        raise ValueError('硬件运行不执行本地 interactions；请使用独立 pc_bindings 场景')
    for w in scene.widgets:
        if w.visible and (w.type not in ('panel', 'text', 'knob') or w.width <= 0 or w.height <= 0):
            raise ValueError(f'硬件场景暂只支持 panel/text/knob：{w.name}')
        if w.visible and w.type == 'knob' and bindings.get(w.name, {}).get('kind') != 'effect':
            raise ValueError(f'旋钮需要明确的 effect 绑定：{w.name}')
    for name, binding in bindings.items():
        matches = [w for w in scene.widgets if w.name == name]
        if not name or len(matches) != 1 or not isinstance(binding, dict):
            raise ValueError(f'绑定必须对应唯一控件名：{name}')
        widget = matches[0]
        kind = binding.get('kind')
        if kind == 'command':
            if binding.get('command') not in COMMANDS or widget.type not in ('panel', 'text'):
                raise ValueError(f'无效按钮命令：{name}')
        elif kind == 'effect':
            if (binding.get('parameter') not in ('R', 'D', 'W', 'M') or
                    widget.type != 'knob' or widget.min_value != 0 or widget.max_value != 255):
                raise ValueError(f'效果器需要 0..255 旋钮：{name}')
        elif kind == 'feedback':
            if widget.type != 'text' or binding.get('field') not in FEEDBACK:
                raise ValueError(f'无效回读文本：{name}')
        elif kind in ('scan', 'load', 'previous', 'next'):
            if widget.type not in ('panel', 'text'):
                raise ValueError(f'文件操作需要 panel/text：{name}')
        else:
            raise ValueError(f'未知绑定类型：{name} / {kind}')


class SceneCanvas(QLabel):
    """Native-sized scene. Mouse targets are separate from confirmed board values."""
    activated = Signal(str)
    edited = Signal(str, int)
    target_changed = Signal(str, int)

    def __init__(self, scene, parent=None):
        super().__init__(parent)
        self.scene = scene
        self.current_page = scene.initial_page
        self.renderer = PixelRenderer(scene.width, scene.height)
        self.setFixedSize(scene.width, scene.height)
        self.setAlignment(Qt.AlignLeft | Qt.AlignTop)
        self.enabled_names = set()
        self.confirmed = {}
        self.labels = {}
        self.drag = None
        self.pressed = None
        self.installEventFilter(self)

    def hit(self, point):
        # Include decorative widgets in z ordering: a foreground overlay must
        # not allow accidental clicks through to a covered command button.
        ordered = sorted(self.scene.visible_widgets(self.current_page), key=lambda w: w.layer)
        for w in reversed(ordered):
            if (w.visible and w.x <= point.x() < w.x + w.width and
                    w.y <= point.y() < w.y + w.height):
                return w if w.name in self.enabled_names or w.name in self.scene.local_actions else None
        return None

    def cancel_input(self):
        # Lost focus / disconnect never commits a half-finished gesture.
        self.drag = self.pressed = None
        self.render()

    def eventFilter(self, obj, event):
        if event.type() == QEvent.WindowDeactivate:
            self.cancel_input()
        return super().eventFilter(obj, event)

    def mousePressEvent(self, event):
        if event.button() != Qt.LeftButton:
            return
        w = self.hit(event.position().toPoint())
        self.pressed = w
        if w is not None and w.type == 'knob':
            binding = self.scene.pc_bindings[w.name]
            value = self.confirmed.get(binding['parameter'])
            if value is not None:
                self.drag = (w, event.position().y(), value, value)

    def mouseMoveEvent(self, event):
        if self.drag:
            w, start_y, start_value, _ = self.drag
            target = max(0, min(255, start_value + round((start_y-event.position().y())*255/160)))
            self.drag = (w, start_y, start_value, target)
            self.target_changed.emit(w.name, target)
            self.render()

    def mouseReleaseEvent(self, event):
        if event.button() != Qt.LeftButton:
            return
        drag, pressed = self.drag, self.pressed
        self.drag = self.pressed = None
        if drag:
            w, _, initial, target = drag
            if w.name in self.enabled_names and initial != target:
                # One transaction on release, never a command per mouse move.
                self.edited.emit(w.name, target)
        elif pressed is not None and self.hit(event.position().toPoint()) is pressed:
            self.activated.emit(pressed.name)
        self.render()

    def render(self):
        # Runtime substitutions do not alter the designer scene or saved JSON.
        view = deepcopy(self.scene)
        values = {}
        for w in view.widgets:
            binding = view.pc_bindings.get(w.name, {})
            if binding.get('kind') == 'feedback':
                w.text = self.labels.get(binding['field'], 'UNKNOWN')
            elif binding.get('kind') == 'effect':
                value = self.confirmed.get(binding['parameter'], 0)
                if self.drag and self.drag[0].name == w.name:
                    value = self.drag[3]
                # Use runtime-only names so duplicate/legacy ui_state sources
                # cannot accidentally couple two different effect parameters.
                w.source = 'pc_effect_' + w.name
                values[w.source] = value
        frame = self.renderer.render_scene(view, values, self.current_page)
        pixmap = QPixmap.fromImage(QImage(frame.data, view.width, view.height,
                                         view.width*3, QImage.Format_RGB888))
        painter = QPainter(pixmap)
        painter.setFont(QFont('Consolas', 9))
        for w in view.visible_widgets(self.current_page):
            binding = view.pc_bindings.get(w.name, {})
            if not w.visible or not binding or binding.get('kind') == 'feedback':
                continue
            if w.name not in self.enabled_names:
                painter.fillRect(w.x, w.y, w.width, w.height, QColor(5, 7, 12, 145))
            if binding.get('kind') == 'effect' and binding['parameter'] not in self.confirmed:
                painter.setPen(QColor('#fbbf24'))
                painter.drawText(w.x, w.y, w.width, w.height, Qt.AlignCenter, '?')
        painter.end()
        self.setPixmap(pixmap)


class SceneRuntimeWindow(QMainWindow):
    def __init__(self, scene=None, parent=None):
        super().__init__(parent)
        font_path = Path('C:/Windows/Fonts/msyh.ttc')
        if not QFontDatabase.families() and font_path.exists():
            QFontDatabase.addApplicationFont(str(font_path))
        self.setFont(QFont('Microsoft YaHei', 10))
        self.scene = UIScene.from_dict(deepcopy(scene.to_dict())) if scene is not None else UIScene.from_json(str(EXAMPLE))
        validate_bindings(self.scene)
        self.setWindowTitle('Dimension 场景 UI · 自动演奏 · 115200 8N1')
        self.resize(min(1150, self.scene.width + 50), min(900, self.scene.height + 260))
        self.client = DimensionClient(self)
        self.confirmed = {}
        self.labels = {}
        self.selected = 0
        self.loaded_index = None
        self.mode = None
        self.operation = None
        self.synchronized = False
        self.scene_error = False
        root = QWidget(self)
        layout = QVBoxLayout(root)
        self.root_layout = layout
        self.panel_view = False
        self.setCentralWidget(root)
        self.port_controls = QWidget(root)
        row = QHBoxLayout(self.port_controls)
        row.setContentsMargins(0, 0, 0, 0)
        self.port_box = QComboBox()
        self.port_box.setEditable(True)
        refresh = QPushButton('刷新串口')
        refresh.clicked.connect(self.refresh_ports)
        self.connect_btn = QPushButton('连接')
        self.connect_btn.clicked.connect(self.toggle_connection)
        screen_btn = QPushButton('屏幕预览 F11')
        screen_btn.clicked.connect(lambda: self.set_panel_view(True))
        for item in (self.port_box, refresh, self.connect_btn, screen_btn):
            row.addWidget(item)
        layout.addWidget(self.port_controls)
        self.instructions = QLabel('点按钮操作；上下拖旋钮，松手发送；F11 预览屏幕，Esc 返回调试。')
        layout.addWidget(self.instructions)
        self.canvas = SceneCanvas(self.scene)
        self.scroll = QScrollArea()
        self.scroll.setWidget(self.canvas)
        self.scroll.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.scroll, 1)
        self.status = QLabel()
        self.status.setWordWrap(True)
        layout.addWidget(self.status)
        self.log = QPlainTextEdit()
        self.log.setReadOnly(True)
        self.log.setMaximumBlockCount(300)
        self.log.setMaximumHeight(115)
        layout.addWidget(self.log)
        self.screen_shortcut = QShortcut(QKeySequence('F11'), self)
        self.screen_shortcut.activated.connect(lambda: self.set_panel_view(not self.panel_view))
        self.debug_shortcut = QShortcut(QKeySequence('Esc'), self)
        self.debug_shortcut.activated.connect(lambda: self.set_panel_view(False))
        self.canvas.activated.connect(self.activate)
        self.canvas.edited.connect(self.edit_effect)
        self.canvas.target_changed.connect(self.show_target)
        self.client.connected.connect(self.link_changed)
        self.client.busy_changed.connect(self.refresh_view)
        self.client.result.connect(self.accept_result)
        self.client.snapshot.connect(self.accept_snapshot)
        self.client.files.connect(self.accept_files)
        self.client.notice.connect(self.notice)
        self.client.failed.connect(self.failure)
        self.client.trace.connect(self.log.appendPlainText)
        self.refresh_ports()
        self.link_changed(False)

    def set_panel_view(self, enabled):
        """Pixel-exact panel view, not a change to FPGA HDMI timing.

        The 800x480 canvas stays at native pixels. On a larger PC screen it is
        centered; a smaller desktop may clip it instead of silently scaling
        coordinates. UART transactions/confirmed state remain untouched.
        """
        enabled = bool(enabled)
        if enabled == self.panel_view:
            return
        self.canvas.cancel_input()
        self.panel_view = enabled
        for widget in (self.port_controls, self.instructions, self.status, self.log):
            widget.setVisible(not enabled)
        if enabled:
            self._debug_geometry = self.saveGeometry()
            self.root_layout.setContentsMargins(0, 0, 0, 0)
            self.root_layout.setSpacing(0)
            self.scroll.setFrameShape(QFrame.NoFrame)
            self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            self.scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            self.scroll.setStyleSheet('QScrollArea { background: #05070c; }')
            self.showFullScreen()
        else:
            self.root_layout.setContentsMargins(9, 9, 9, 9)
            self.root_layout.setSpacing(6)
            self.scroll.setFrameShape(QFrame.StyledPanel)
            self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAsNeeded)
            self.scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
            self.scroll.setStyleSheet('')
            self.showNormal()
            self.restoreGeometry(self._debug_geometry)

    def refresh_ports(self):
        current = self.port_box.currentText()
        self.port_box.clear()
        self.port_box.addItems([p.portName() for p in QSerialPortInfo.availablePorts()])
        if current:
            self.port_box.setCurrentText(current)

    def toggle_connection(self):
        if self.client.port.isOpen():
            self.client.close()
        else:
            self.client.open(self.port_box.currentText())

    def link_changed(self, connected):
        self.canvas.cancel_input()
        self.confirmed.clear()
        self.mode = self.loaded_index = self.operation = None
        self.synchronized = False
        self.scene_error = False
        self.selected = 0
        self.labels = {'mode': 'MODE: UNKNOWN', 'playback': 'PLAY: UNKNOWN',
                       'loaded': 'LOADED: UNKNOWN', 'preset': 'PRESET: UNKNOWN'}
        self.connect_btn.setText('断开' if connected else '连接')
        self.port_box.setEnabled(not connected)
        self.set_status('等待 Q / !Q 回读' if connected else '未连接；所有板卡状态未知')
        self.refresh_view()

    def set_status(self, text):
        self.status.setText(text)
        # ASCII framebuffer uses the original FPGA font; Chinese detail stays
        # in the native Qt status/log outside the scene.

    def allowed(self, binding):
        if not (self.client.port.isOpen() and self.client.pending is None and self.synchronized):
            return False
        kind = binding['kind']
        if kind == 'feedback':
            return False
        if kind in ('load', 'previous', 'next'):
            return bool(self.client.catalog)
        if kind == 'effect':
            return binding['parameter'] in self.confirmed
        if kind == 'command':
            if binding['command'] == 'A':
                return self.loaded_index is not None
            if binding['command'] == 'P':
                return self.loaded_index is not None and self.mode == 'A'
        return True

    def refresh_view(self, *_):
        catalog = self.client.catalog
        start = (self.selected // 6) * 6
        for row in range(6):
            index = start + row
            self.labels[f'file_{row}'] = (
                f'{">" if index == self.selected else " "} {catalog[index][0]:02X}: {catalog[index][1]}'
                if index < len(catalog) else 'SCAN SD FIRST' if not catalog and row == 0 else ''
            )
        self.labels['selected'] = (f'SELECT {catalog[self.selected][0]:02X}: {catalog[self.selected][1]}'
                                   if catalog and self.selected < len(catalog) else 'SELECT: SCAN SD FIRST')
        self.labels['status'] = ('LINK: DISCONNECTED' if not self.client.port.isOpen() else
                                'LINK: BUSY ' + str(self.client.pending) if self.client.pending else
                                'LINK: ERROR - ESC FOR DETAILS' if self.scene_error else
                                'LINK: READY' if self.synchronized else 'LINK: SYNCING')
        for key in ('R', 'D', 'W', 'M', 'E'):
            self.labels[key] = f'{key} READ: ' + (str(self.confirmed[key]) if key in self.confirmed else '?')
        self.canvas.confirmed = dict(self.confirmed)
        self.canvas.labels = dict(self.labels)
        self.canvas.enabled_names = {name for name, binding in self.scene.pc_bindings.items() if self.allowed(binding)}
        if (self.canvas.pressed and self.canvas.pressed.name not in self.canvas.enabled_names and
                self.canvas.pressed.name not in self.scene.local_actions):
            self.canvas.cancel_input()
        self.canvas.render()

    def activate(self, name):
        action = self.scene.local_actions.get(name)
        if action:
            self.switch_page(action['target'])
            return
        binding = self.scene.pc_bindings[name]
        if not self.allowed(binding):
            return
        kind = binding['kind']
        if kind in ('previous', 'next'):
            self.selected = (self.selected + (1 if kind == 'next' else -1)) % len(self.client.catalog)
            self.refresh_view()
        elif kind == 'scan':
            self.loaded_index = None
            self.selected = 0
            self.labels['loaded'] = 'LOADED: SCANNING / INVALIDATED'
            self.labels['playback'] = 'PLAY: STOPPING / SCANNING'
            self.send('@L')
        elif kind == 'load':
            index = self.client.catalog[self.selected][0]
            self.loaded_index = None
            self.labels['loaded'] = 'LOADED: WAIT SD READY'
            self.labels['playback'] = 'PLAY: STOPPING / LOADING'
            self.send(f'@S{index:02X}')
        elif kind == 'command':
            self.send(binding['command'])

    def switch_page(self, page_id):
        if page_id not in {p['id'] for p in self.scene.pages}:
            raise ValueError('页面不存在')
        # A page switch cancels an unfinished gesture but never sends it.
        self.canvas.drag = self.canvas.pressed = None
        self.canvas.current_page = page_id
        self.canvas.render()

    def send(self, command):
        self.scene_error = False
        self.operation = command
        if self.client.send(command):
            self.set_status(f'等待 FPGA 确认：{command}；不会自动重发')
        else:
            self.operation = None
        self.refresh_view()

    def show_target(self, name, value):
        parameter = self.scene.pc_bindings[name]['parameter']
        self.set_status(f'{parameter} 目标 {value}；回读 {self.confirmed.get(parameter, "未知")}；松手后发送')

    def edit_effect(self, name, value):
        binding = self.scene.pc_bindings[name]
        if self.allowed(binding) and 0 <= value <= 255:
            self.send(f'!{binding["parameter"]}{value:02X}')

    def accept_snapshot(self, snapshot):
        self.confirmed = dict(snapshot)
        self.synchronized = self.mode is not None
        self.refresh_view()

    def accept_files(self, rows):
        self.selected = 0
        self.refresh_view()

    def accept_result(self, command, line):
        if command == 'Q' or command in ('A', 'M'):
            previous_mode = self.mode
            self.mode = line[-1]
            self.labels['mode'] = 'MODE: ' + ('AUTO' if self.mode == 'A' else 'MANUAL')
            self.synchronized = bool(self.confirmed)
            if command in ('A', 'M') and previous_mode != self.mode:
                self.labels['playback'] = 'PLAY: MODE CHANGED / STOPPED'
        elif command == 'P':
            self.labels['playback'] = 'PLAY: START ACCEPTED (NO END QUERY)'
        elif command == 'S':
            self.labels['playback'] = 'PLAY: STOP CONFIRMED'
        elif command in tuple(map(str, range(7))):
            self.labels['preset'] = 'PRESET: ' + command + ' (LAST ACK)'
            # An unchanged preset has an immediate ACK; a changed one stops
            # the player. Without a preset query, don't infer which occurred.
            self.labels['playback'] = 'PLAY: UNKNOWN AFTER PATCH COMMAND'
        elif command == '@L':
            self.labels['playback'] = 'PLAY: STOPPED / SCAN DONE'
            self.labels['loaded'] = 'LOADED: NONE - SELECT THEN LOAD'
        elif command.startswith('@S'):
            self.loaded_index = int(command[2:], 16)
            name = dict(self.client.catalog).get(self.loaded_index, '?')
            self.labels['loaded'] = 'LOADED: ' + name
            self.labels['playback'] = 'PLAY: READY - NOT STARTED'
        self.operation = None
        self.set_status(f'FPGA 已确认：{command} → {line}')
        self.refresh_view()

    def notice(self, line):
        if line == 'P5 E':
            self.scene_error = True
            self.loaded_index = None
            self.labels['loaded'] = 'LOADED: INVALID / ERROR'
            self.labels['playback'] = 'PLAY: ERROR / CLEANUP'
            self.set_status('FPGA 自动演奏错误；请重新扫描和加载')
        # P5 R has no file identity and cannot satisfy a selected-file load.
        self.refresh_view()

    def failure(self, message):
        self.scene_error = True
        if self.operation and self.operation.startswith('@'):
            self.loaded_index = None
            self.labels['loaded'] = 'LOADED: ERROR / NOT CONFIRMED'
            self.labels['playback'] = 'PLAY: UNKNOWN / OPERATION FAILED'
        self.operation = None
        self.set_status(message)
        self.log.appendPlainText('ERROR ' + message)
        self.refresh_view()

    def changeEvent(self, event):
        if event.type() == QEvent.WindowDeactivate and hasattr(self, 'canvas'):
            self.canvas.cancel_input()
        super().changeEvent(event)

    def closeEvent(self, event):
        self.canvas.cancel_input()
        self.client.close()
        super().closeEvent(event)
