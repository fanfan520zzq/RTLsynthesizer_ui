"""PC controls for the board-verified Dimension ASCII command set."""
from pathlib import Path
from PySide6.QtGui import QFont, QFontDatabase
from PySide6.QtCore import Qt
from PySide6.QtSerialPort import QSerialPortInfo
from PySide6.QtWidgets import (QMainWindow,QWidget,QVBoxLayout,QHBoxLayout,QGridLayout,
    QLabel,QPushButton,QComboBox,QSpinBox,QSlider,QPlainTextEdit,QGroupBox)
from communication.dimension_client import DimensionClient
from communication.dimension_protocol import DEFAULTS


class DimensionWindow(QMainWindow):
    def __init__(self,parent=None):
        super().__init__(parent)
        font=Path('C:/Windows/Fonts/msyh.ttc')
        if not QFontDatabase.families() and font.exists(): QFontDatabase.addApplicationFont(str(font))
        self.setFont(QFont('Microsoft YaHei',10))
        self.setWindowTitle('Dimension 自动演奏控制 · 现有 ASCII 协议')
        self.resize(900,700)
        self.client=DimensionClient(self)
        self.controls=[]
        self.targets={}
        self.readbacks={}
        self.ok_count=0
        self.multifile=False
        self.song_ready=False
        root=QWidget();self.setCentralWidget(root);layout=QVBoxLayout(root)
        row=QHBoxLayout()
        self.ports=QComboBox();self.ports.setEditable(True)
        refresh=QPushButton('刷新串口');refresh.clicked.connect(self.refresh_ports)
        self.connect_btn=QPushButton('连接 Dimension');self.connect_btn.clicked.connect(self.connect_port)
        for w in (self.ports,refresh,self.connect_btn):row.addWidget(w)
        layout.addLayout(row)
        self.status=QLabel('请选择 dimension 位流对应串口，115200 8N1')
        layout.addWidget(self.status)
        self.mode=QLabel('模式：未确认')
        self.playback=QLabel('播放：未知（现有协议不提供播放进度/连续状态）')
        self.preset_status=QLabel('音色：未知（仅设置成功时更新）')
        for w in (self.mode,self.playback,self.preset_status):layout.addWidget(w)
        group=QGroupBox('自动演奏');buttons=QHBoxLayout(group)
        for title,cmd in [('自动模式 A','A'),('播放 P','P'),('停止 S','S'),('查询模式 Q','Q'),('手动模式 M','M')]:
            btn=self.button(title,cmd);buttons.addWidget(btn)
            if cmd=='P':self.play_btn=btn
        layout.addWidget(group)
        songs=QGroupBox('SD 根目录选曲（需要 multifile 位流；最多 16 个 .BIN 候选，加载时校验）')
        songrow=QHBoxLayout(songs)
        self.scan_btn=QPushButton('扫描文件列表')
        self.scan_btn.clicked.connect(self.scan_files)
        self.song_list=QComboBox()
        self.load_btn=QPushButton('加载所选歌曲')
        self.load_btn.clicked.connect(self.load_song)
        self.song_status=QLabel('尚未扫描；加载不会自动播放')
        for w in (self.scan_btn,self.song_list,self.load_btn,self.song_status):songrow.addWidget(w)
        self.controls.extend([self.scan_btn,self.song_list,self.load_btn])
        layout.addWidget(songs)
        row=QHBoxLayout()
        self.preset=QComboBox();self.preset.addItems([f'音色 {i}' for i in range(7)])
        choose=QPushButton('应用音色');choose.clicked.connect(lambda:self.client.send(str(self.preset.currentIndex())))
        self.controls.extend([self.preset,choose]);row.addWidget(self.preset);row.addWidget(choose)
        layout.addLayout(row)
        fx=QGroupBox('Dimension 效果器：目标值与 FPGA 回读值分开显示')
        grid=QGridLayout(fx)
        for rowno,(key,title) in enumerate([('R','Rate 速度'),('D','Depth 深度'),('W','Width 宽度'),('M','Mix 比例')]):
            grid.addWidget(QLabel(title),rowno,0)
            slider=QSlider(Qt.Orientation.Horizontal);slider.setRange(0,255)
            spin=QSpinBox();spin.setRange(0,255);spin.setValue(DEFAULTS[key]);slider.setValue(DEFAULTS[key])
            slider.valueChanged.connect(spin.setValue);spin.valueChanged.connect(slider.setValue)
            btn=QPushButton('发送');btn.clicked.connect(lambda checked=False,k=key,s=spin:self.client.send(f'!{k}{s.value():02X}'))
            value=QLabel('回读：未确认')
            self.targets[key]=spin;self.readbacks[key]=value
            self.controls.extend([slider,spin,btn])
            for col,w in enumerate([slider,spin,btn,value],1):grid.addWidget(w,rowno,col)
        self.effect=QLabel('效果器开关：未确认')
        grid.addWidget(self.effect,4,0,1,3)
        grid.addWidget(self.button('开启 !E01','!E01'),4,3)
        grid.addWidget(self.button('关闭 !E00','!E00'),4,4)
        grid.addWidget(self.button('查询效果器 !Q','!Q'),5,0,1,5)
        layout.addWidget(fx)
        layout.addWidget(QLabel('设置收到 FX OK 后自动 !Q 回读核对；每次只发送一条命令，超时不重发。'))
        self.log=QPlainTextEdit();self.log.setReadOnly(True);self.log.setMaximumBlockCount(500)
        layout.addWidget(self.log)
        self.client.trace.connect(self.log.appendPlainText)
        self.client.connected.connect(self.link_changed)
        self.client.busy_changed.connect(self.set_busy)
        self.client.result.connect(self.accept_result)
        self.client.snapshot.connect(self.accept_snapshot)
        self.client.notice.connect(self.notice)
        self.client.failed.connect(self.failure)
        self.client.files.connect(self.accept_files)
        self.refresh_ports();self.link_changed(False)

    def button(self,title,cmd):
        btn=QPushButton(title)
        btn.clicked.connect(lambda checked=False:self.client.send(cmd))
        self.controls.append(btn)
        return btn

    def refresh_ports(self):
        old=self.ports.currentText();self.ports.clear()
        self.ports.addItems([p.portName() for p in QSerialPortInfo.availablePorts()])
        if old:self.ports.setCurrentText(old)

    def connect_port(self):
        if self.client.port.isOpen():self.client.close()
        else:self.client.open(self.ports.currentText())

    def link_changed(self,connected):
        self.connect_btn.setText('断开' if connected else '连接 Dimension')
        self.ports.setEnabled(not connected)
        self.status.setText('已打开串口，等待查询回复' if connected else '串口未连接')
        self.mode.setText('模式：未确认')
        self.playback.setText('播放：未知（现有协议不提供播放进度/连续状态）')
        self.preset_status.setText('音色：未确认')
        self.effect.setText('效果器开关：未确认')
        for label in self.readbacks.values():label.setText('回读：未确认')
        self.multifile=False;self.song_ready=False;self.song_list.clear()
        self.song_status.setText('尚未扫描；加载不会自动播放')
        self.set_busy(False)

    def set_busy(self,busy):
        for w in self.controls:w.setEnabled(self.client.port.isOpen() and not busy)
        self.load_btn.setEnabled(self.client.port.isOpen() and not busy and self.song_list.count()>0)
        if self.multifile:self.play_btn.setEnabled(self.client.port.isOpen() and not busy and self.song_ready)

    def scan_files(self):
        if self.client.send('@L'):
            self.multifile=True;self.song_ready=False;self.song_list.clear()
            self.song_status.setText('停止清理后扫描中…')
            self.set_busy(True)

    def accept_files(self,files):
        self.song_list.clear()
        for index,name in files:self.song_list.addItem(f'{index:02X} · {name}',index)
        self.song_status.setText(f'{len(files)} 个候选文件（上限 16）；请选择加载')

    def load_song(self):
        index=self.song_list.currentData()
        if index is not None and self.client.send(f'@S{index:02X}'):
            self.song_ready=False
            self.song_status.setText('停止清理后加载并校验中…')
            self.set_busy(True)

    def accept_result(self,cmd,line):
        if line in ('P5 N','P5 B','P5 C','FX ERR'):return
        self.ok_count+=1
        self.status.setText(f'FPGA 回复已确认：{cmd} → {line} · 累计 {self.ok_count}')
        if cmd in ('Q','M','A') and line in ('P5 M','P5 A'):
            self.mode.setText('模式：'+('自动' if line=='P5 A' else '手动'))
        if cmd=='P' and line=='P5 P':self.playback.setText('播放：启动请求已接受')
        if cmd=='S' and line=='P5 S':self.playback.setText('播放：已停止并清理音符')
        if cmd.startswith('@S') and line=='SD READY '+cmd[2:]:
            self.song_ready=True
            self.song_status.setText('加载完成；切换自动模式 A 后点击播放 P')
            self.playback.setText('播放：新歌曲已就绪，尚未播放')
        if cmd=='@L':self.playback.setText('播放：已停止并清理；等待选曲加载')
        if cmd in ('M','A') and line=='P5 '+cmd:self.playback.setText('播放：模式切换已完成，当前播放状态未查询')
        if cmd in tuple(str(i) for i in range(7)) and line=='P5 '+cmd:
            self.preset_status.setText('音色：'+cmd+'（设置已完成）')

    def accept_snapshot(self,snapshot):
        for key in self.readbacks:self.readbacks[key].setText(f'回读：{snapshot[key]} / {snapshot[key]:02X}')
        self.effect.setText('效果器开关：'+('开启' if snapshot['E'] else '关闭'))

    def notice(self,line):
        if line=='P5 R':
            self.status.setText('FPGA 就绪通知；等待 SD READY 确认选曲' if self.multifile
                                else 'FPGA 通知：歌曲加载完成')
        elif line=='P5 E':
            self.playback.setText('播放：FPGA 报告自动演奏错误并清理')
            if self.multifile:
                self.song_ready=False
                self.play_btn.setEnabled(False)
        else:self.log.appendPlainText('NOTICE '+line)

    def failure(self,message):
        self.status.setText(message);self.log.appendPlainText('ERROR '+message)
        if self.multifile:self.song_status.setText('操作失败；未确认加载，请检查日志/重新扫描')

    def closeEvent(self,event):
        self.client.close();super().closeEvent(event)
