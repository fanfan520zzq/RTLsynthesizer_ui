"""RGB888 color editor shared by scene and widget properties."""
from PySide6.QtCore import Signal
from PySide6.QtGui import QColor
from PySide6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QLineEdit, QSpinBox, QColorDialog
try:
    from .ui_schema import ColorRGB
except ImportError:
    from ui_schema import ColorRGB


class ColorEditor(QWidget):
    color_changed = Signal(object)

    def __init__(self, color, parent=None):
        super().__init__(parent)
        self._updating = False
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(2)
        top = QHBoxLayout()
        self.pick_button = QPushButton('选色')
        self.pick_button.setToolTip('打开颜色选择器')
        self.hex_edit = QLineEdit()
        self.hex_edit.setPlaceholderText('#RRGGBB')
        self.hex_edit.setToolTip('HEX颜色，例如 #38BDF8；RGB范围0–255')
        top.addWidget(self.pick_button)
        top.addWidget(self.hex_edit, 1)
        layout.addLayout(top)
        rgb = QHBoxLayout()
        rgb.setSpacing(2)
        self.rgb_spins = []
        for channel in 'RGB':
            spin = QSpinBox()
            spin.setRange(0, 255)
            spin.setPrefix(channel + ':')
            spin.setToolTip(channel + '通道（0–255）')
            rgb.addWidget(spin)
            self.rgb_spins.append(spin)
            spin.valueChanged.connect(self._rgb_changed)
        layout.addLayout(rgb)
        self.pick_button.clicked.connect(self._choose_color)
        self.hex_edit.textChanged.connect(self._hex_changed)
        self.hex_edit.editingFinished.connect(self._finish_hex)
        self.set_color(color)
        # 不允许属性面板挤扁RGB输入行；空间不足时由外层滚动。
        self.setMinimumHeight(self.sizeHint().height())

    def set_color(self, color, emit=False):
        """Load without dirtying the scene; emit only genuine user changes."""
        changed = getattr(self, '_color', None) != color
        self._color = ColorRGB(color.r, color.g, color.b)
        self._updating = True
        try:
            value = f'#{color.to_hex():06X}'
            self.hex_edit.setText(value)
            self.hex_edit.setStyleSheet('')
            for spin, channel in zip(self.rgb_spins, (color.r, color.g, color.b)):
                spin.setValue(channel)
            ink = '#000000' if color.r * 299 + color.g * 587 + color.b * 114 > 128000 else '#ffffff'
            self.pick_button.setStyleSheet(f'background-color: {value}; color: {ink};')
        finally:
            self._updating = False
        if emit and changed:
            self.color_changed.emit(ColorRGB(color.r, color.g, color.b))

    def _rgb_changed(self):
        if not self._updating:
            self.set_color(ColorRGB(*(s.value() for s in self.rgb_spins)), emit=True)

    def _hex_changed(self, text):
        if self._updating:
            return
        # No names, alpha, shorthand or partial input: exactly RGB888.
        value = text.strip()
        valid = (len(value) == 7 and value.startswith('#') and
                 all(c in '0123456789abcdefABCDEF' for c in value[1:]))
        if valid:
            self.set_color(ColorRGB.from_hex(int(value[1:], 16)), emit=True)
        else:
            self.hex_edit.setStyleSheet('QLineEdit { border: 1px solid #dc2626; }')

    def _finish_hex(self):
        # Invalid input never modifies the scene and reverts on leaving field.
        self.set_color(self._color)

    def _choose_color(self):
        picked = QColorDialog.getColor(QColor(self._color.r, self._color.g, self._color.b),
                                        self, '选择颜色（RGB888）')
        if picked.isValid():
            self.set_color(ColorRGB(picked.red(), picked.green(), picked.blue()), emit=True)
