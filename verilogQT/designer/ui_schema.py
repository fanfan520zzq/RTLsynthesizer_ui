"""
UI Schema Definition
定义所有支持的控件类型和属性
"""

from dataclasses import dataclass, field, asdict
from typing import List, Dict, Any, Optional
from enum import Enum


class WidgetType(Enum):
    """控件类型"""
    PANEL = "panel"
    TEXT = "text"
    BAR = "bar"
    SPECTRUM = "spectrum"
    WAVEFORM = "waveform"
    ENVELOPE = "envelope"
    KNOB = "knob"
    KEYBOARD = "keyboard"
    LINE = "line"
    ICON = "icon"


class AnimationType(Enum):
    """动画类型"""
    NONE = "none"
    EASE = "ease"
    LINEAR = "linear"


@dataclass
class Color:
    """颜色定义 (RGB888)"""
    r: int = 255
    g: int = 255
    b: int = 255

    def to_hex(self) -> int:
        return (self.r << 16) | (self.g << 8) | self.b

    @classmethod
    def from_hex(cls, hex_val: int):
        return cls(
            r=(hex_val >> 16) & 0xFF,
            g=(hex_val >> 8) & 0xFF,
            b=hex_val & 0xFF
        )

    def to_dict(self) -> Dict[str, int]:
        return {"r": self.r, "g": self.g, "b": self.b}

    @classmethod
    def from_dict(cls, data: Dict[str, int]):
        return cls(r=data["r"], g=data["g"], b=data["b"])

# 别名兼容
ColorRGB = Color


@dataclass
class Widget:
    """控件基类"""
    type: str = "widget"
    x: int = 0
    y: int = 0
    width: int = 100
    height: int = 100
    visible: bool = True
    layer: int = 0
    name: str = ""
    # Empty = shared by every page; nonempty = a stable PC page ID.
    page: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class PanelWidget(Widget):
    """面板控件"""
    type: str = "panel"
    bg_color: Color = field(default_factory=lambda: Color(10, 13, 18))
    border_color: Color = field(default_factory=lambda: Color(30, 40, 60))
    border_width: int = 1
    corner_radius: int = 8


@dataclass
class TextWidget(Widget):
    """文本控件"""
    type: str = "text"
    text: str = "TEXT"
    source: str = ""  # empty=static text, filename=status slots 17..31
    font_size: int = 16
    color: Color = field(default_factory=lambda: Color(220, 220, 240))
    align: str = "left"  # left, center, right


@dataclass
class BarWidget(Widget):
    """进度条控件"""
    type: str = "bar"
    source: str = "value"  # 数据源寄存器名
    max_value: int = 100
    fg_color: Color = field(default_factory=lambda: Color(56, 189, 248))
    bg_color: Color = field(default_factory=lambda: Color(30, 40, 60))
    corner_radius: int = 999  # 圆角半径


@dataclass
class SpectrumWidget(Widget):
    """频谱控件"""
    type: str = "spectrum"
    bars: int = 64
    source: str = "fft_bins"
    attack: int = 4  # 上升速度
    decay: int = 1   # 下降速度
    peak_hold: int = 20  # 峰值保持帧数
    bar_color: Color = field(default_factory=lambda: Color(56, 189, 248))
    peak_color: Color = field(default_factory=lambda: Color(233, 165, 104))
    bg_color: Color = field(default_factory=lambda: Color(15, 19, 28))


@dataclass
class WaveformWidget(Widget):
    """波形控件"""
    type: str = "waveform"
    samples: int = 1024
    source: str = "pcm_buffer"
    line_color: Color = field(default_factory=lambda: Color(110, 231, 183))
    bg_color: Color = field(default_factory=lambda: Color(15, 19, 28))
    line_width: int = 2


@dataclass
class EnvelopeWidget(Widget):
    """包络线控件"""
    type: str = "envelope"
    source: str = "envelope_params"  # L1,L2,L3,L4,R1,R2,R3,R4
    line_color: Color = field(default_factory=lambda: Color(233, 165, 104))
    fill_color: Color = field(default_factory=lambda: Color(100, 70, 45))  # 半透明效果用更深的颜色
    bg_color: Color = field(default_factory=lambda: Color(15, 19, 28))


@dataclass
class KnobWidget(Widget):
    """旋钮控件"""
    type: str = "knob"
    source: str = "knob_value"
    min_value: int = 0
    max_value: int = 127
    min_angle: int = -135  # 度数
    max_angle: int = 135
    fg_color: Color = field(default_factory=lambda: Color(56, 189, 248))
    bg_color: Color = field(default_factory=lambda: Color(30, 40, 60))
    pointer_color: Color = field(default_factory=lambda: Color(220, 220, 240))


@dataclass
class KeyboardWidget(Widget):
    """钢琴键盘控件"""
    type: str = "keyboard"
    start_note: int = 48  # C3
    keys: int = 25  # visible window only; MIDI transport remains 0..127
    source: str = "key_states"
    white_key_color: Color = field(default_factory=lambda: Color(240, 240, 245))
    black_key_color: Color = field(default_factory=lambda: Color(20, 25, 35))
    pressed_color: Color = field(default_factory=lambda: Color(56, 189, 248))


@dataclass
class LineWidget(Widget):
    """直线控件"""
    type: str = "line"
    x2: int = 100
    y2: int = 100
    color: Color = field(default_factory=lambda: Color(100, 120, 160))
    line_width: int = 1


@dataclass
class IconWidget(Widget):
    """图标控件"""
    type: str = "icon"
    icon_name: str = "note"
    color: Color = field(default_factory=lambda: Color(220, 220, 240))


@dataclass
class UIScene:
    """完整的 UI 场景"""
    name: str = "default_scene"
    width: int = 800
    height: int = 480
    bg_color: Color = field(default_factory=lambda: Color(5, 7, 12))
    widgets: List[Widget] = field(default_factory=list)
    # Interaction rules are JSON-compatible dictionaries.  Keeping the rule
    # shape data-driven lets the PC preview and RTL generator consume exactly
    # the same behavior definition.
    interactions: List[Dict[str, Any]] = field(default_factory=list)
    # PC hardware bindings are separate from local/RTL interaction rules.
    # Keys are stable widget names; layout edits do not change UART commands.
    pc_bindings: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    pages: List[Dict[str, str]] = field(default_factory=list)
    initial_page: str = ""
    # Local navigation never generates UART commands or FPGA feedback.
    local_actions: Dict[str, Dict[str, str]] = field(default_factory=dict)

    def visible_widgets(self, page=None):
        page = self.initial_page if page is None else page
        return [w for w in self.widgets if w.visible and (not w.page or w.page == page)]

    def validate_navigation(self):
        import re
        if not isinstance(self.pages, list):
            raise ValueError('pages 必须是页面列表')
        ids = []
        for page in self.pages:
            if not isinstance(page, dict) or not isinstance(page.get('title'), str):
                raise ValueError('页面需要 id 和 title')
            page_id = page.get('id')
            if not isinstance(page_id, str) or not re.fullmatch(r'[A-Za-z0-9_-]+', page_id):
                raise ValueError('页面ID只能包含字母、数字、下划线和短横线')
            if page_id in ids:
                raise ValueError('页面ID不能重复')
            ids.append(page_id)
        if (ids and self.initial_page not in ids) or (not ids and self.initial_page):
            raise ValueError('默认页必须对应已有页面')
        for widget in self.widgets:
            if not isinstance(widget.page, str) or (widget.page and widget.page not in ids):
                raise ValueError(f'控件所属页面不存在：{widget.name}')
        if not isinstance(self.local_actions, dict):
            raise ValueError('local_actions 必须是控件名到本地动作的字典')
        for name, action in self.local_actions.items():
            matches = [w for w in self.widgets if w.name == name]
            if len(matches) != 1 or matches[0].type not in ('panel', 'text'):
                raise ValueError(f'切页按钮需要唯一的 panel/text 名称：{name}')
            if (not isinstance(action, dict) or action.get('action') != 'switch_page' or
                    action.get('target') not in ids):
                raise ValueError(f'无效切页目标：{name}')
            if name in self.pc_bindings:
                raise ValueError(f'控件不能同时绑定切页和串口操作：{name}')

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "width": self.width,
            "height": self.height,
            "bg_color": self.bg_color.to_dict(),
            "widgets": [self._widget_to_dict(w) for w in self.widgets],
            "interactions": self.interactions,
            "pc_bindings": self.pc_bindings,
            "pages": self.pages,
            "initial_page": self.initial_page,
            "local_actions": self.local_actions,
        }

    def _widget_to_dict(self, widget: Widget) -> Dict[str, Any]:
        """Convert widget to dict with proper Color serialization"""
        d = asdict(widget)
        # Convert Color objects to dicts
        for key, value in d.items():
            if isinstance(value, Color):
                d[key] = value.to_dict()
        return d

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'UIScene':
        """Create UIScene from dictionary"""
        if not isinstance(data, dict):
            raise TypeError("scene data must be a dictionary")

        bg_data = data.get("bg_color", {})
        bg_color = Color(
            r=bg_data.get("r", 5),
            g=bg_data.get("g", 7),
            b=bg_data.get("b", 12),
        )
        widgets = []

        for raw_widget in data.get("widgets", []):
            if not isinstance(raw_widget, dict):
                raise TypeError("each widget must be a dictionary")

            # Do not mutate the caller's decoded JSON while converting colors.
            w_data = dict(raw_widget)
            widget_type = w_data["type"]

            # Convert color dicts back to Color objects
            for key in list(w_data.keys()):
                if "color" in key.lower() and isinstance(w_data[key], dict):
                    w_data[key] = Color.from_dict(w_data[key])

            # Create appropriate widget type
            if widget_type == "panel":
                widgets.append(PanelWidget(**w_data))
            elif widget_type == "text":
                widgets.append(TextWidget(**w_data))
            elif widget_type == "bar":
                widgets.append(BarWidget(**w_data))
            elif widget_type == "spectrum":
                widgets.append(SpectrumWidget(**w_data))
            elif widget_type == "waveform":
                widgets.append(WaveformWidget(**w_data))
            elif widget_type == "envelope":
                widgets.append(EnvelopeWidget(**w_data))
            elif widget_type == "knob":
                widgets.append(KnobWidget(**w_data))
            elif widget_type == "keyboard":
                widgets.append(KeyboardWidget(**w_data))
            elif widget_type == "line":
                widgets.append(LineWidget(**w_data))
            elif widget_type == "icon":
                widgets.append(IconWidget(**w_data))
            else:
                # Preserve unknown widgets as a generic object so the PC
                # designer can still open an older scene, but generation is
                # expected to reject visible unsupported types explicitly.
                base_fields = Widget.__dataclass_fields__
                widgets.append(Widget(**{
                    key: value for key, value in w_data.items()
                    if key in base_fields
                }))

        scene = cls(
            name=data.get("name", "default_scene"),
            width=data.get("width", 800),
            height=data.get("height", 480),
            bg_color=bg_color,
            widgets=widgets,
            interactions=list(data.get("interactions", [])),
            pc_bindings=data.get("pc_bindings", {}),
            pages=data.get('pages', []),
            initial_page=data.get('initial_page', ''),
            local_actions=data.get('local_actions', {}),
        )
        scene.validate_navigation()
        return scene

    @classmethod
    def from_json(cls, filepath: str) -> 'UIScene':
        """Load UIScene from JSON file"""
        import json
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return cls.from_dict(data)
