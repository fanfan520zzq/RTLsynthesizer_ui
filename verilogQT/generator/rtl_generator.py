#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RTL Code Generator
从 UI Schema 生成 Verilog RTL 代码（flattened 接口）
"""

import json
import os
import re
import shutil
from pathlib import Path
from typing import List, Dict, Any
import sys

sys.path.insert(0, str(Path(__file__).parent.parent / "designer"))
try:
    from designer.ui_schema import *
except ImportError:
    from ui_schema import *

try:
    from generator.compact_rtl_generator import CompactRTLGenerator
except ImportError:
    from compact_rtl_generator import CompactRTLGenerator


class RTLGenerator:
    """RTL 代码生成器"""

    # These are the widgets for which the generated RTL has a concrete
    # implementation.  Keeping the list in one place prevents the old
    # behaviour where unsupported widgets were silently dropped from the
    # FPGA image while remaining visible in the PC preview.
    SUPPORTED_WIDGETS = (
        PanelWidget, TextWidget, BarWidget, SpectrumWidget,
        WaveformWidget, KeyboardWidget, KnobWidget,
    )
    MAX_INTERACTION_RULES = 32
    MAX_INTERACTION_ACTIONS = 64

    def __init__(self):
        self.indent_level = 0

    def indent(self, code: str = "") -> str:
        """添加缩进"""
        return "    " * self.indent_level + code

    def generate(self, scene: UIScene, output_dir: Path):
        """Generate the fixed, low-resource FPGA scene contract.

        The legacy multi-file methods remain below for compatibility with old
        tests and scene readers, but the supported export path deliberately
        writes only ``ui_generated_scene.v``.
        """
        if scene.pages or scene.local_actions or any(w.page for w in scene.widgets):
            raise ValueError('PC多页导航不能导出为RTL')
        return CompactRTLGenerator().generate(scene, output_dir)

        # Legacy generator retained as reference; unreachable by design.
        self._validate_scene_for_flattened_interfaces(scene)
        output_dir.mkdir(parents=True, exist_ok=True)

        # 生成各个模块
        self.generate_ui_top(scene, output_dir / "ui_top.v")
        self.generate_pixel_renderer(scene, output_dir / "pixel_renderer.v")
        self.generate_interaction_module(scene, output_dir / "ui_interaction.v")
        self._copy_renderer_dependencies(output_dir)

        # Text widgets use the checked-in 8x16 ASCII ROM.  Copy the ROM into
        # the generated directory so the output is self-contained and can be
        # added to a Gowin project without relying on a source-tree path.
        if any(isinstance(w, TextWidget) and w.visible for w in scene.widgets):
            font_src = Path(__file__).parent.parent / "assets" / "fonts" / "font_8x16_full.v"
            if not font_src.exists():
                raise FileNotFoundError(f"missing font ROM: {font_src}")
            shutil.copyfile(font_src, output_dir / "font_8x16_full.v")
            self.generate_text_renderers(scene, output_dir / "text_renderer.v")

        self.generate_build_script(output_dir / "build_generated.tcl")

        manifest = {
            "scene": scene.name,
            "resolution": {"width": scene.width, "height": scene.height},
            "generated_files": [p.name for p in sorted(output_dir.glob("*.v"))],
            "interface": {
                "fft_bins_flat_bits": 1024,
                "ui_state_flat_bits": 512,
                "pcm_buffer_flat_bits": 16384,
                "key_states_bits": 88,
                "event": {
                    "valid_bits": 1,
                    "type_bits": 4,
                    "id_bits": 8,
                    "value_bits": 16,
                    "types": {
                        "click": 1, "press": 2, "release": 3,
                        "change": 4, "key_down": 5, "key_up": 6,
                        "set_state": 8, "add_state": 9,
                        "toggle_state": 10, "set_key_down": 11,
                        "set_key_up": 12,
                    },
                },
            },
            "interaction_rules": len(scene.interactions),
            "widget_event_ids": {
                widget.name: index
                for index, widget in enumerate(scene.widgets)
                if widget.name
            },
            "unsupported_widgets": [],
            "warnings": [
                "Text widgets use the shared 8x16 ASCII ROM; font_size is preserved in JSON but not scaled in RTL."
            ] if any(isinstance(w, TextWidget) and w.visible and w.font_size != 16 for w in scene.widgets) else [],
            "integration": "Use build_generated.tcl from the project root; do not replace rtl/ by hand.",
        }
        (output_dir / "generated_manifest.json").write_text(
            json.dumps(manifest, indent=2, ensure_ascii=True) + "\n", encoding="utf-8"
        )

        print(f"[OK] Generated RTL in {output_dir}")

    @staticmethod
    def _copy_renderer_dependencies(output_dir: Path):
        """Copy the generic renderer modules required by pixel_renderer.v."""
        source_dir = Path(__file__).parent.parent / "rtl"
        dependencies = (
            "panel_renderer.v", "bar_renderer.v", "spectrum_renderer.v",
            "waveform_renderer.v", "keyboard_renderer.v", "knob_renderer.v",
        )
        missing = [name for name in dependencies if not (source_dir / name).exists()]
        if missing:
            raise FileNotFoundError(f"missing renderer dependencies: {', '.join(missing)}")
        for name in dependencies:
            shutil.copyfile(source_dir / name, output_dir / name)

    @staticmethod
    def generate_build_script(output_path: Path):
        """Emit a build entry point that actually consumes generated RTL.

        The board-specific device and constraints stay in ``board_config.tcl``;
        the generated script refuses to run until that file is confirmed.
        This makes a scene output reproducible without pretending that example
        pins or an unverified FPGA part are production settings.
        """
        output_dir = output_path.parent.resolve()
        project_root = Path(__file__).parent.parent.resolve()
        try:
            root_expr = os.path.relpath(project_root, output_dir).replace("\\", "/")
            project_root_line = (
                "set project_root [file join [file dirname [info script]] "
                f"{root_expr}]"
            )
        except ValueError:
            # Windows cannot express a relative path across drive letters.
            # Keep generation usable for system temporary directories while
            # preserving a relative, movable build script on the same drive.
            project_root_text = project_root.as_posix()
            if "}" in project_root_text:
                raise ValueError("project root contains an unsupported '}' character")
            project_root_line = f"set project_root {{{project_root_text}}}"
        lines = [
            "# Generated UI build entry point. Run from Gowin gw_sh.",
            # Do not call Tcl `file normalize` here.  On some Windows Tcl
            # builds, Desktop is a shell alias and normalization drops that
            # path component; the resulting project path does not exist.
            f"set generated_dir [file join [file dirname [info script]] .]",
            project_root_line,
            "source [file join $project_root board_config.tcl]",
            "require_board_config",
            "set_device -name $FPGA_DEVICE_NAME $FPGA_PART -device_version $FPGA_DEVICE_VERSION",
            "set root_rtl [file join $project_root rtl]",
            "add_file -type verilog [file join $root_rtl top_hdmi_tang_mega_60k.v]",
            "add_file -type verilog [file join $project_root $PLL_SOURCE_FILE]",
            "add_file -type verilog [file join $root_rtl hdmi_timing.v]",
            "add_file -type verilog [file join $root_rtl adv7513_controller.v]",
            "add_file -type verilog [file join $root_rtl ui_event_cdc.v]",
            "foreach f {panel_renderer.v bar_renderer.v spectrum_renderer.v waveform_renderer.v keyboard_renderer.v knob_renderer.v} {",
            "    add_file -type verilog [file join $generated_dir $f]",
            "}",
            "add_file -type verilog [file join $generated_dir ui_top.v]",
            "add_file -type verilog [file join $generated_dir pixel_renderer.v]",
            "add_file -type verilog [file join $generated_dir ui_interaction.v]",
            "if {[file exists [file join $generated_dir text_renderer.v]]} {",
            "    add_file -type verilog [file join $generated_dir text_renderer.v]",
            "    add_file -type verilog [file join $generated_dir font_8x16_full.v]",
            "}",
            "add_file -type cst [file join $project_root $HDMI_CONSTRAINT_FILE]",
            "set_option -top_module top_hdmi_tang_mega_60k",
            "set_option -output_base_name generated_ui",
            "set_option -output_path [file join $generated_dir impl]",
            "set_option -verilog_std sysv2017",
            "run syn",
            "run pnr",
            "run bit",
        ]
        output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"[OK] Generated {output_path.name}")

    @staticmethod
    def _validate_scene_for_flattened_interfaces(scene: UIScene):
        """Reject schema values that exceed the fixed flattened RTL buses."""
        unsupported = [
            w for w in scene.widgets
            if w.visible and not isinstance(w, RTLGenerator.SUPPORTED_WIDGETS)
        ]
        if unsupported:
            details = ", ".join(f"{w.name or '<unnamed>'}:{w.type}" for w in unsupported)
            raise ValueError(
                "Visible widget types are not implemented in generated RTL: "
                f"{details}. Hide/remove them or add a renderer before generating."
            )

        if not (1 <= scene.width <= 2048 and 1 <= scene.height <= 1024):
            raise ValueError("scene resolution must fit pixel_x[10:0]/pixel_y[9:0] (max 2048x1024)")

        for widget in scene.widgets:
            if not widget.visible:
                continue
            if widget.width <= 0 or widget.height <= 0:
                raise ValueError(f"widget {widget.name or '<unnamed>'} has non-positive dimensions")

            if isinstance(widget, TextWidget):
                if widget.font_size < 1:
                    raise ValueError(f"text widget {widget.name or '<unnamed>'} font_size must be positive")
                if widget.height < 16:
                    raise ValueError(
                        f"text widget {widget.name or '<unnamed>'} height must be at least 16 pixels"
                    )
                if widget.align not in ("left", "center", "right"):
                    raise ValueError(f"unsupported text alignment: {widget.align}")
                try:
                    widget.text.encode("ascii")
                except UnicodeEncodeError as exc:
                    raise ValueError(
                        f"text widget {widget.name or '<unnamed>'} contains non-ASCII characters"
                    ) from exc
                if len(widget.text) * 8 > widget.width:
                    raise ValueError(
                        f"text widget {widget.name or '<unnamed>'} is narrower than its text"
                    )

            if isinstance(widget, SpectrumWidget) and widget.visible:
                if widget.source not in ("fft_bins", "fft_bins_flat"):
                    raise ValueError(
                        f"spectrum {widget.name or '<unnamed>'} source must be fft_bins"
                    )
                if not 1 <= widget.bars <= 128:
                    raise ValueError("Spectrum bars must be between 1 and 128 for fft_bins_flat")
                if widget.width < widget.bars:
                    raise ValueError("Spectrum width must be at least the number of bars")
            elif isinstance(widget, WaveformWidget) and widget.visible:
                if widget.source not in ("pcm_buffer", "pcm_buffer_flat"):
                    raise ValueError(
                        f"waveform {widget.name or '<unnamed>'} source must be pcm_buffer"
                    )
                if not 1 <= widget.samples <= 1024:
                    raise ValueError("Waveform samples must be between 1 and 1024 for pcm_buffer_flat")
            elif isinstance(widget, KeyboardWidget) and widget.visible:
                if widget.source not in ("key_states", "key_states_flat"):
                    raise ValueError(
                        f"keyboard {widget.name or '<unnamed>'} source must be key_states"
                    )
                if not 1 <= widget.keys <= 128:
                    raise ValueError("Keyboard display count must be between 1 and 128")
                if not 0 <= widget.start_note <= 127 or widget.start_note + widget.keys > 128:
                    raise ValueError("Keyboard display window must stay within MIDI notes 0..127")
            elif isinstance(widget, BarWidget) and widget.visible:
                if not 1 <= widget.max_value <= 65535:
                    raise ValueError(
                        f"bar {widget.name or '<unnamed>'} max_value must be in 1..65535"
                    )
            elif isinstance(widget, KnobWidget) and widget.visible:
                if not (0 <= widget.min_value < widget.max_value <= 65535):
                    raise ValueError(
                        f"knob {widget.name or '<unnamed>'} range must satisfy 0 <= min < max <= 65535"
                    )

        RTLGenerator.validate_interaction_rules(scene)

    @staticmethod
    def validate_interaction_rules(scene: UIScene):
        """Validate names, event IDs, and the shared PC/RTL rule schema."""
        if not isinstance(scene.interactions, list):
            raise ValueError("scene interactions must be a list")
        if len(scene.widgets) > 256:
            raise ValueError("scene has more than 256 widgets; event IDs are limited to 8 bits")
        if len(scene.interactions) > RTLGenerator.MAX_INTERACTION_RULES:
            raise ValueError(
                f"scene has more than {RTLGenerator.MAX_INTERACTION_RULES} interaction rules"
            )

        widget_names = set()
        for widget_index, widget in enumerate(scene.widgets):
            if not isinstance(widget.name, str):
                raise ValueError(
                    f"widget at index {widget_index} name must be a string"
                )
            if widget.name:
                if widget.name in widget_names:
                    raise ValueError(f"duplicate widget name: {widget.name}")
                if widget_index > 255:
                    raise ValueError(
                        f"widget '{widget.name}' has event ID {widget_index}; maximum is 255"
                    )
                widget_names.add(widget.name)
            if (widget.visible and isinstance(widget, (KnobWidget, KeyboardWidget))
                    and not widget.name):
                raise ValueError(
                    f"visible interactive widget at index {widget_index} must have a unique name"
                )

        valid_triggers = {"click", "press", "release", "change", "key_down", "key_up"}
        valid_actions = {"set", "set_event_value", "set_event_key", "add", "toggle", "set_key"}

        # Normalize the action shape once. A rule may use the compact form
        # (the rule itself is the action) or provide one action object instead
        # of a list. Keeping the normalized list also makes the total-action
        # limit deterministic and avoids re-counting it inside the validator.
        normalized_actions = []
        action_total = 0
        for rule_index, rule in enumerate(scene.interactions):
            if not isinstance(rule, dict):
                raise ValueError(f"interaction {rule_index} must be an object")
            actions = rule.get("actions", [rule])
            if isinstance(actions, dict):
                actions = [actions]
            if not isinstance(actions, list) or not actions:
                raise ValueError(f"interaction {rule_index} must contain at least one action")
            normalized_actions.append(actions)
            action_total += len(actions)
        if action_total > RTLGenerator.MAX_INTERACTION_ACTIONS:
            raise ValueError(
                f"scene has more than {RTLGenerator.MAX_INTERACTION_ACTIONS} interaction actions"
            )

        for rule_index, rule in enumerate(scene.interactions):
            trigger = str(rule.get("trigger", rule.get("event", ""))).lower()
            if trigger not in valid_triggers:
                raise ValueError(f"interaction {rule_index} has unsupported trigger '{trigger}'")
            source = rule.get("source", rule.get("widget", ""))
            # Check the type before ``source not in widget_names``. Lists and
            # dictionaries are unhashable and otherwise leak a TypeError from
            # the set lookup instead of reporting an invalid rule.
            if not isinstance(source, str):
                raise ValueError(f"interaction {rule_index} source must be a widget name")
            if source and source not in widget_names:
                raise ValueError(f"interaction {rule_index} references unknown widget '{source}'")
            key_filter = rule.get("key_index")
            if key_filter is not None:
                if isinstance(key_filter, bool):
                    raise ValueError(f"interaction {rule_index} key_index must be an integer")
                try:
                    key_filter = int(key_filter)
                except (TypeError, ValueError) as exc:
                    raise ValueError(f"interaction {rule_index} key_index must be an integer") from exc
                if key_filter < 0 or key_filter >= 128:
                    raise ValueError(f"interaction {rule_index} key_index must be in 0..127")
            actions = normalized_actions[rule_index]
            for action in actions:
                if not isinstance(action, dict):
                    raise ValueError(f"interaction {rule_index} contains a non-object action")
                action_type = str(action.get("action", "set")).lower()
                if action_type not in valid_actions:
                    raise ValueError(f"interaction {rule_index} has unsupported action '{action_type}'")
                if action_type in ("set", "set_key", "add", "set_event_key"):
                    try:
                        action_value = int(action.get("value", 0))
                    except (TypeError, ValueError) as exc:
                        raise ValueError(
                            f"interaction {rule_index} action value must be an integer"
                        ) from exc
                    if action_type == "add" and not -(1 << 31) <= action_value <= (1 << 31) - 1:
                        raise ValueError(
                            f"interaction {rule_index} add value must fit signed 32-bit RTL arithmetic"
                        )
                target = action.get("target", "")
                if action_type == "set_event_key":
                    if str(target).strip() not in ("key_states[event]", "key_states[$event_value]"):
                        raise ValueError(
                            f"interaction {rule_index} set_event_key target must be key_states[event]"
                        )
                    continue
                match = re.fullmatch(r"\s*(ui_state|key_states)\s*\[\s*(\d+)\s*\]\s*", str(target))
                if not match:
                    raise ValueError(f"interaction {rule_index} has invalid target '{target}'")
                limit = 32 if match.group(1) == "ui_state" else 128
                if int(match.group(2)) >= limit:
                    raise ValueError(f"interaction {rule_index} target is out of range: {target}")

        # Validate all visible state-backed widgets here as well. The editor
        # calls this method directly when saving JSON, so invalid widget
        # sources must be rejected before generation is attempted.
        RTLGenerator._source_index_map(scene)

    @classmethod
    def _source_index_map(cls, scene: UIScene):
        """Resolve bar/knob sources exactly as the PC preview does."""
        result = {}
        next_index = 0
        for widget in scene.widgets:
            if not (widget.visible and isinstance(widget, (BarWidget, KnobWidget))):
                continue
            source = widget.source
            # ``source`` is used as a dictionary key below. Reject invalid
            # JSON values explicitly so a list/dict cannot escape as a raw
            # ``TypeError`` and so the PC preview and RTL accept the same
            # source schema.
            if not isinstance(source, str) or not source.strip():
                raise ValueError(
                    f"{widget.type} {widget.name or '<unnamed>'} source must be a non-empty string"
                )
            if source in result:
                index = result[source]
            else:
                explicit = cls._explicit_state_index(source)
                index = explicit if explicit is not None else next_index
                result[source] = index
            if index >= 32:
                raise ValueError(f"source '{source}' is outside ui_state[0..31]")
            next_index = max(next_index, index + 1)
        return result

    @staticmethod
    def _explicit_state_index(source):
        if source is None:
            return None
        if not isinstance(source, str):
            raise ValueError(f"source '{source}' must be a string")
        source_text = source
        match = re.fullmatch(r"\s*ui_state\s*\[\s*(\d+)\s*\]\s*", source_text)
        if match:
            index = int(match.group(1))
            if index >= 32:
                raise ValueError(f"source '{source}' is outside ui_state[0..31]")
            return index
        if source_text.strip().lower().startswith("ui_state"):
            raise ValueError(f"invalid UI state source: {source}")
        match = re.fullmatch(r"\s*op(\d+)_level\s*", source_text, re.IGNORECASE)
        if match:
            index = int(match.group(1)) - 1
            if not 0 <= index < 32:
                raise ValueError(f"source '{source}' is outside ui_state[0..31]")
            return index
        if source_text.strip() in ("", "value", "knob_value"):
            return None
        raise ValueError(
            f"RTL generator cannot map source '{source}' to ui_state_flat; "
            "use ui_state[N], opN_level, value, or knob_value"
        )

    @staticmethod
    def _interaction_event_type(trigger):
        return {"click": 1, "press": 2, "release": 3,
                "change": 4, "key_down": 5, "key_up": 6}[trigger]

    @staticmethod
    def _target_slice(target):
        match = re.fullmatch(r"\s*(ui_state|key_states)\s*\[\s*(\d+)\s*\]\s*", str(target))
        if not match:
            raise ValueError(f"invalid interaction target: {target}")
        return match.group(1), int(match.group(2))

    def generate_interaction_module(self, scene: UIScene, output_path: Path):
        """Generate deterministic sequential state updates for the event bus."""
        self.validate_interaction_rules(scene)
        widget_ids = {widget.name: index for index, widget in enumerate(scene.widgets) if widget.name}
        source_indices = self._source_index_map(scene)
        code = [
            "`timescale 1ns / 1ps",
            "// Generated interaction/state module.",
            "// All actions update next-state temporaries in source order.",
            "module ui_interaction (",
            "    input wire clk,",
            "    input wire rst_n,",
            "    input wire event_valid,",
            "    input wire [3:0] event_type,",
            "    input wire [7:0] event_id,",
            "    input wire [15:0] event_value,",
            "    output reg [511:0] ui_state_flat,",
            "    output reg [87:0] key_states",
            ");",
            "    localparam [3:0] EVENT_CHANGE = 4'd4;",
            "    localparam [3:0] EVENT_KEY_DOWN = 4'd5;",
            "    localparam [3:0] EVENT_KEY_UP = 4'd6;",
            "    reg [511:0] ui_next;",
            "    reg [87:0] key_next;",
            "",
            "    function [15:0] sat_add_u16;",
            "        input [15:0] current;",
            "        input signed [31:0] delta;",
            "        reg signed [32:0] total;",
            "        begin",
            "            total = $signed({1'b0, current}) + delta;",
            "            if (total < 0) sat_add_u16 = 16'd0;",
            "            else if (total > 65535) sat_add_u16 = 16'hFFFF;",
            "            else sat_add_u16 = total[15:0];",
            "        end",
            "    endfunction",
            "",
            "    function key_add_bool;",
            "        input current;",
            "        input signed [31:0] delta;",
            "        reg signed [32:0] total;",
            "        begin",
            "            total = $signed({1'b0, current}) + delta;",
            "            key_add_bool = (total != 0);",
            "        end",
            "    endfunction",
            "",
            "    function [87:0] set_key_index;",
            "        input [87:0] current;",
            "        input [7:0] index;",
            "        input value;",
            "        begin",
            "            set_key_index = current;",
            "            case (index)",
        ]
        for index in range(88):
            code.append(f"                8'd{index}: set_key_index[{index}] = value;")
        code.extend([
            "                default: begin end",
            "            endcase",
            "        end",
            "    endfunction",
            "",
            "    always @(posedge clk or negedge rst_n) begin",
            "        if (!rst_n) begin",
            "            ui_state_flat <= 512'd0;",
            "            key_states <= 88'd0;",
            "        end else begin",
            "            ui_next = ui_state_flat;",
            "            key_next = key_states;",
            "            if (event_valid) begin",
            "                // Direct operations use fixed case decoders rather than",
            "                // variable part-selects, keeping the generated logic bounded.",
            "                case (event_type)",
            "                    4'd8: begin",
            "                        case (event_id)",
        ])
        for index in range(32):
            code.append(f"                            8'd{index}: ui_next[{index * 16} +: 16] = event_value;")
        code.extend([
            "                            default: begin end",
            "                        endcase",
            "                    end",
            "                    4'd9: begin",
            "                        case (event_id)",
        ])
        for index in range(32):
            code.extend([
                f"                            8'd{index}: begin",
                f"                                if (ui_next[{index * 16} +: 16] > (16'hFFFF - event_value)) ui_next[{index * 16} +: 16] = 16'hFFFF;",
                f"                                else ui_next[{index * 16} +: 16] = ui_next[{index * 16} +: 16] + event_value;",
                "                            end",
            ])
        code.extend([
            "                            default: begin end",
            "                        endcase",
            "                    end",
            "                    4'd10: begin",
            "                        case (event_id)",
        ])
        for index in range(32):
            code.append(
                f"                            8'd{index}: ui_next[{index * 16} +: 16] = "
                f"(ui_next[{index * 16} +: 16] == 16'd0) ? 16'd1 : 16'd0;"
            )
        code.extend([
            "                            default: begin end",
            "                        endcase",
            "                    end",
            "                    4'd11: key_next = set_key_index(key_next, event_id, 1'b1);",
            "                    4'd12: key_next = set_key_index(key_next, event_id, 1'b0);",
            "                    default: begin end",
            "                endcase",
        ])

        # Match the PC preview's built-in state changes even when no explicit
        # interaction rule was authored for the widget.
        for widget_index, widget in enumerate(scene.widgets):
            if not (widget.visible and isinstance(widget, KnobWidget) and widget.name):
                continue
            source_index = source_indices[widget.source]
            code.extend([
                f"                if (event_type == EVENT_CHANGE && event_id == 8'd{widget_index}) begin",
                f"                    if (event_value < 16'd{widget.min_value}) ui_next[{source_index * 16} +: 16] = 16'd{widget.min_value};",
                f"                    else if (event_value > 16'd{widget.max_value}) ui_next[{source_index * 16} +: 16] = 16'd{widget.max_value};",
                f"                    else ui_next[{source_index * 16} +: 16] = event_value;",
                "                end",
            ])
        code.extend([
            "                if (event_type == EVENT_KEY_DOWN && event_value < 16'd88) key_next = set_key_index(key_next, event_value[7:0], 1'b1);",
            "                if (event_type == EVENT_KEY_UP && event_value < 16'd88) key_next = set_key_index(key_next, event_value[7:0], 1'b0);",
        ])

        for rule_index, rule in enumerate(scene.interactions):
            trigger = str(rule.get("trigger", rule.get("event", ""))).lower()
            event_type = self._interaction_event_type(trigger)
            source = rule.get("source", rule.get("widget", ""))
            source_condition = f"event_id == 8'd{widget_ids[source]}" if source else "1'b1"
            key_condition = ""
            if rule.get("key_index") is not None:
                key_condition = f" && event_value == 16'd{int(rule['key_index'])}"
            code.append(f"                // Scene interaction {rule_index}: {trigger} {source or '*'}")
            code.append(f"                if (event_type == 4'd{event_type} && {source_condition}{key_condition}) begin")
            actions = rule.get("actions", [rule])
            if isinstance(actions, dict):
                actions = [actions]
            for action in actions:
                action_type = action.get("action", "set").lower()
                if action_type == "set_event_key":
                    key_value = 1 if int(action.get("value", 1)) else 0
                    code.append(
                        f"                    if (event_value < 16'd88) key_next = set_key_index(key_next, event_value[7:0], 1'b{key_value});"
                    )
                    continue
                kind, index = self._target_slice(action["target"])
                target_ref = f"ui_next[{index * 16} +: 16]" if kind == "ui_state" else f"key_next[{index}]"
                if action_type == "set_event_value":
                    value_expr = "event_value" if kind == "ui_state" else "(event_value != 16'd0)"
                elif action_type == "add":
                    delta = int(action.get("value", 0))
                    delta_expr = f"-32'sd{abs(delta)}" if delta < 0 else f"32'sd{delta}"
                    value_expr = (
                        f"sat_add_u16({target_ref}, {delta_expr})"
                        if kind == "ui_state" else f"key_add_bool({target_ref}, {delta_expr})"
                    )
                elif action_type == "toggle":
                    value_expr = (
                        f"({target_ref} == 16'd0) ? 16'd1 : 16'd0"
                        if kind == "ui_state" else f"~{target_ref}"
                    )
                else:
                    raw_value = int(action.get("value", 0))
                    value_expr = (
                        f"16'd{max(0, min(65535, raw_value))}"
                        if kind == "ui_state" else f"1'b{1 if raw_value else 0}"
                    )
                code.append(f"                    {target_ref} = {value_expr};")
            code.append("                end")

        code.extend([
            "            end",
            "            ui_state_flat <= ui_next;",
            "            key_states <= key_next;",
            "        end",
            "    end",
            "endmodule",
            "",
        ])
        output_path.write_text("\n".join(code), encoding="utf-8")
        print(f"[OK] Generated {output_path.name}")

    @staticmethod
    def _state_index(source: str, default: int) -> int:
        """Resolve the flattened ui_state register used by a widget.

        The generated interface only exposes ``ui_state_flat``.  Keep the
        accepted mapping explicit instead of silently using a different
        register when a source name cannot be represented in RTL.
        """
        explicit = RTLGenerator._explicit_state_index(source)
        if explicit is not None:
            return explicit

        source_alias = source.strip() if isinstance(source, str) else source
        if source_alias not in (None, "", "value", "knob_value"):
            raise ValueError(
                f"RTL generator cannot map source '{source}' to ui_state_flat; "
                "use ui_state[N] or opN_level"
            )
        return default

    def generate_ui_top(self, scene: UIScene, output_path: Path):
        """生成顶层模块（flattened 接口）"""
        code = []
        code.append("`timescale 1ns / 1ps")
        code.append("//")
        code.append(f"// UI Top Module - Generated for {scene.name}")
        code.append("// Target: generic flattened RGB renderer; board integration is separate")
        code.append("//")
        code.append("")
        code.append("module ui_top (")
        code.append("    input wire clk,")
        code.append("    input wire rst_n,")
        code.append("    ")
        code.append("    // 时序信号")
        code.append("    input wire [10:0] pixel_x,")
        code.append("    input wire [9:0] pixel_y,")
        code.append("    ")
        code.append("    // 数据输入 - 扁平化接口")
        code.append("    input wire [1023:0] fft_bins_flat,    // 128 bins * 8 bits")
        code.append("    input wire [511:0] ui_state_flat,     // 32 registers * 16 bits")
        code.append("    input wire [16383:0] pcm_buffer_flat, // 1024 samples * 16 bits")
        code.append("    input wire [87:0] key_states,         // 88 keys max")
        code.append("    ")
        code.append("    // RGB 输出")
        code.append("    output wire [7:0] rgb_r,")
        code.append("    output wire [7:0] rgb_g,")
        code.append("    output wire [7:0] rgb_b")
        code.append(");")
        code.append("")
        code.append("    // 实例化像素渲染器")
        code.append("    pixel_renderer renderer (")
        code.append("        .clk(clk),")
        code.append("        .rst_n(rst_n),")
        code.append("        .pixel_x(pixel_x),")
        code.append("        .pixel_y(pixel_y),")
        code.append("        .fft_bins_flat(fft_bins_flat),")
        code.append("        .ui_state_flat(ui_state_flat),")
        code.append("        .pcm_buffer_flat(pcm_buffer_flat),")
        code.append("        .key_states(key_states),")
        code.append("        .rgb_r(rgb_r),")
        code.append("        .rgb_g(rgb_g),")
        code.append("        .rgb_b(rgb_b)")
        code.append("    );")
        code.append("")
        code.append("endmodule")

        output_path.write_text("\n".join(code), encoding="utf-8")
        print(f"[OK] Generated {output_path.name}")

    def generate_text_renderers(self, scene: UIScene, output_path: Path):
        """Generate one small, fixed-string renderer per visible text widget.

        Text strings are fixed at generation time.  Emit only the glyph rows
        used by each string as a small combinational ROM, so the result has no
        extra pixel-clock latency relative to the other renderers.  The full
        font ROM is still copied for projects that want to share it elsewhere.
        """
        text_widgets = [w for w in scene.widgets if isinstance(w, TextWidget) and w.visible]
        font_rows = self._load_font_rows()
        code = [
            "`timescale 1ns / 1ps",
            "// Generated fixed-string text renderers (8x16 ASCII font).",
            "",
        ]
        for index, widget in enumerate(text_widgets):
            text = widget.text
            text_len = len(text)
            extra = widget.width - text_len * 8
            if widget.align == "center":
                x_start = widget.x + extra // 2
            elif widget.align == "right":
                x_start = widget.x + extra
            else:
                x_start = widget.x
            module_name = f"text_renderer_{index}"
            code.extend([
                f"module {module_name} #(",
                f"    parameter X_START = {x_start},",
                f"    parameter Y_START = {widget.y},",
                f"    parameter TEXT_LEN = {text_len},",
                f"    parameter COLOR = 24'h{widget.color.to_hex():06X}",
                ") (",
                "    input wire clk,",
                "    input wire [10:0] pixel_x,",
                "    input wire [9:0] pixel_y,",
                "    output wire active,",
                "    output wire [23:0] color",
                ");",
                "    wire in_text_area = (pixel_x >= X_START) &&",
                "        (pixel_x < X_START + TEXT_LEN * 8) &&",
                "        (pixel_y >= Y_START) && (pixel_y < Y_START + 16);",
                "    wire [7:0] char_index = (pixel_x - X_START) >> 3;",
                "    wire [2:0] char_x = (pixel_x - X_START) & 7;",
                "    wire [3:0] char_y = pixel_y - Y_START;",
                "    reg [7:0] glyph_bits;",
                "    always @(*) begin",
                "        glyph_bits = 8'd0;",
                "        case (char_index)",
            ])
            for char_index, char in enumerate(text):
                rows = font_rows.get(ord(char), [0] * 16)
                code.extend([
                    f"            8'd{char_index}: begin",
                    "                case (char_y)",
                ])
                for row, bits in enumerate(rows):
                    code.append(f"                    4'd{row}: glyph_bits = 8'h{bits:02X};")
                code.extend([
                    "                    default: glyph_bits = 8'd0;",
                    "                endcase",
                    "            end",
                ])
            code.extend([
                "            default: glyph_bits = 8'd0;",
                "        endcase",
                "    end",
                "    assign active = in_text_area && glyph_bits[7 - char_x];",
                "    assign color = COLOR;",
                "endmodule",
                "",
            ])
        output_path.write_text("\n".join(code), encoding="utf-8")
        print(f"[OK] Generated {output_path.name}")

    @staticmethod
    def _load_font_rows():
        """Load the checked-in 95-character 8x16 ROM for code generation."""
        mem_path = Path(__file__).parent.parent / "assets" / "fonts" / "font_8x16_full.mem"
        try:
            values = []
            for raw_line in mem_path.read_text(encoding="utf-8").splitlines():
                value = raw_line.split("//", 1)[0].strip()
                if re.fullmatch(r"[0-9A-Fa-f]{2}", value):
                    values.append(int(value, 16))
            if len(values) >= 95 * 16:
                return {
                    0x20 + index: values[index * 16:(index + 1) * 16]
                    for index in range(95)
                }
        except (OSError, ValueError):
            pass
        return {}

    def generate_pixel_renderer(self, scene: UIScene, output_path: Path):
        """生成像素渲染器"""
        code = []
        code.append("`timescale 1ns / 1ps")
        code.append("//")
        code.append(f"// Pixel Renderer - Generated for {scene.name}")
        code.append("//")
        code.append("")
        code.append("module pixel_renderer (")
        code.append("    input wire clk,")
        code.append("    input wire rst_n,")
        code.append("    input wire [10:0] pixel_x,")
        code.append("    input wire [9:0] pixel_y,")
        code.append("")
        code.append("    // UI State - flattened arrays")
        code.append("    input wire [1023:0] fft_bins_flat,    // 128 * 8 bits")
        code.append("    input wire [511:0] ui_state_flat,     // 32 * 16 bits")
        code.append("    input wire [16383:0] pcm_buffer_flat, // 1024 * 16 bits")
        code.append("    input wire [87:0] key_states,")
        code.append("")
        code.append("    // RGB Output")
        code.append("    output reg [7:0] rgb_r,")
        code.append("    output reg [7:0] rgb_g,")
        code.append("    output reg [7:0] rgb_b")
        code.append(");")
        code.append("")

        # 按类型分组控件
        panels = [w for w in scene.widgets if isinstance(w, PanelWidget) and w.visible]
        texts = [w for w in scene.widgets if isinstance(w, TextWidget) and w.visible]
        bars = [w for w in scene.widgets if isinstance(w, BarWidget) and w.visible]
        spectrums = [w for w in scene.widgets if isinstance(w, SpectrumWidget) and w.visible]
        waveforms = [w for w in scene.widgets if isinstance(w, WaveformWidget) and w.visible]
        keyboards = [w for w in scene.widgets if isinstance(w, KeyboardWidget) and w.visible]
        knobs = [w for w in scene.widgets if isinstance(w, KnobWidget) and w.visible]
        source_indices = self._source_index_map(scene)

        supported_types = self.SUPPORTED_WIDGETS

        # 生成 Panel 实例
        for i, panel in enumerate(panels):
            code.append(f"    // Panel {i}: {panel.name}")
            code.append(f"    wire panel_{i}_active;")
            code.append(f"    wire [23:0] panel_{i}_color;")
            code.append(f"    panel_renderer #(")
            code.append(f"        .X_START({panel.x}),")
            code.append(f"        .Y_START({panel.y}),")
            code.append(f"        .WIDTH({panel.width}),")
            code.append(f"        .HEIGHT({panel.height}),")
            code.append(f"        .BG_COLOR(24'h{panel.bg_color.to_hex():06X})")
            code.append(f"    ) panel_{i} (")
            code.append(f"        .pixel_x(pixel_x),")
            code.append(f"        .pixel_y(pixel_y),")
            code.append(f"        .active(panel_{i}_active),")
            code.append(f"        .color(panel_{i}_color)")
            code.append(f"    );")
            code.append("")

        # 生成 Text 实例。  The per-widget modules are emitted into
        # text_renderer.v by generate_text_renderers().
        for i, text_widget in enumerate(texts):
            code.append(f"    // Text {i}: {text_widget.name}")
            code.append(f"    wire text_{i}_active;")
            code.append(f"    wire [23:0] text_{i}_color;")
            code.append(f"    text_renderer_{i} text_{i} (")
            code.append("        .clk(clk),")
            code.append("        .pixel_x(pixel_x),")
            code.append("        .pixel_y(pixel_y),")
            code.append(f"        .active(text_{i}_active),")
            code.append(f"        .color(text_{i}_color)")
            code.append("    );")
            code.append("")

        # 生成 Spectrum 实例
        for i, spectrum in enumerate(spectrums):
            code.append(f"    // Spectrum {i}: {spectrum.name}")
            code.append(f"    wire spectrum_{i}_active;")
            code.append(f"    wire [23:0] spectrum_{i}_color;")
            code.append(f"    spectrum_renderer #(")
            code.append(f"        .X_START({spectrum.x}),")
            code.append(f"        .Y_START({spectrum.y}),")
            code.append(f"        .WIDTH({spectrum.width}),")
            code.append(f"        .HEIGHT({spectrum.height}),")
            code.append(f"        .NUM_BARS({spectrum.bars}),")
            code.append(f"        .BAR_COLOR(24'h{spectrum.bar_color.to_hex():06X}),")
            code.append(f"        .BG_COLOR(24'h{spectrum.bg_color.to_hex():06X})")
            code.append(f"    ) spectrum_{i} (")
            code.append(f"        .clk(clk),")
            code.append(f"        .pixel_x(pixel_x),")
            code.append(f"        .pixel_y(pixel_y),")
            code.append(f"        .fft_bins_flat(fft_bins_flat),")
            code.append(f"        .active(spectrum_{i}_active),")
            code.append(f"        .color(spectrum_{i}_color)")
            code.append(f"    );")
            code.append("")

        # 生成 Bar 实例
        for i, bar in enumerate(bars):
            # 从 ui_state 中提取数据源索引
            source_idx = source_indices.get(bar.source, self._state_index(bar.source, i))
            code.append(f"    // Bar {i}: {bar.name}")
            code.append(f"    wire [15:0] bar_{i}_value;")
            code.append(f"    assign bar_{i}_value = ui_state_flat[{source_idx*16}+:16];")
            code.append(f"    wire bar_{i}_active;")
            code.append(f"    wire [23:0] bar_{i}_color;")
            code.append(f"    bar_renderer #(")
            code.append(f"        .X_START({bar.x}),")
            code.append(f"        .Y_START({bar.y}),")
            code.append(f"        .WIDTH({bar.width}),")
            code.append(f"        .HEIGHT({bar.height}),")
            code.append(f"        .MAX_VALUE({bar.max_value}),")
            code.append(f"        .FG_COLOR(24'h{bar.fg_color.to_hex():06X}),")
            code.append(f"        .BG_COLOR(24'h{bar.bg_color.to_hex():06X})")
            code.append(f"    ) bar_{i} (")
            code.append(f"        .pixel_x(pixel_x),")
            code.append(f"        .pixel_y(pixel_y),")
            code.append(f"        .value(bar_{i}_value),")
            code.append(f"        .active(bar_{i}_active),")
            code.append(f"        .color(bar_{i}_color)")
            code.append(f"    );")
            code.append("")

        # 生成 Waveform 实例
        for i, waveform in enumerate(waveforms):
            code.append(f"    // Waveform {i}: {waveform.name}")
            code.append(f"    wire waveform_{i}_active;")
            code.append(f"    wire [23:0] waveform_{i}_color;")
            code.append(f"    waveform_renderer #(")
            code.append(f"        .X_START({waveform.x}),")
            code.append(f"        .Y_START({waveform.y}),")
            code.append(f"        .WIDTH({waveform.width}),")
            code.append(f"        .HEIGHT({waveform.height}),")
            code.append(f"        .SAMPLES({waveform.samples}),")
            code.append(f"        .LINE_COLOR(24'h{waveform.line_color.to_hex():06X}),")
            code.append(f"        .BG_COLOR(24'h{waveform.bg_color.to_hex():06X})")
            code.append(f"    ) waveform_{i} (")
            code.append(f"        .clk(clk),")
            code.append(f"        .pixel_x(pixel_x),")
            code.append(f"        .pixel_y(pixel_y),")
            code.append(f"        .pcm_buffer_flat(pcm_buffer_flat),")
            code.append(f"        .active(waveform_{i}_active),")
            code.append(f"        .color(waveform_{i}_color)")
            code.append(f"    );")
            code.append("")

        # 生成 Keyboard 实例
        for i, keyboard in enumerate(keyboards):
            code.append(f"    // Keyboard {i}: {keyboard.name}")
            code.append(f"    wire keyboard_{i}_active;")
            code.append(f"    wire [23:0] keyboard_{i}_color;")
            code.append(f"    keyboard_renderer #(")
            code.append(f"        .X_START({keyboard.x}),")
            code.append(f"        .Y_START({keyboard.y}),")
            code.append(f"        .WIDTH({keyboard.width}),")
            code.append(f"        .HEIGHT({keyboard.height}),")
            code.append(f"        .START_NOTE({keyboard.start_note}),")
            code.append(f"        .NUM_KEYS({keyboard.keys}),")
            code.append(f"        .WHITE_KEY_COLOR(24'h{keyboard.white_key_color.to_hex():06X}),")
            code.append(f"        .BLACK_KEY_COLOR(24'h{keyboard.black_key_color.to_hex():06X}),")
            code.append(f"        .PRESSED_COLOR(24'h{keyboard.pressed_color.to_hex():06X})")
            code.append(f"    ) keyboard_{i} (")
            code.append(f"        .pixel_x(pixel_x),")
            code.append(f"        .pixel_y(pixel_y),")
            code.append(f"        .key_states(key_states[{keyboard.keys-1}:0]),")
            code.append(f"        .active(keyboard_{i}_active),")
            code.append(f"        .color(keyboard_{i}_color)")
            code.append(f"    );")
            code.append("")

        # 生成 Knob 实例
        for i, knob in enumerate(knobs):
            source_idx = source_indices.get(knob.source, self._state_index(knob.source, len(bars) + i))
            code.append(f"    // Knob {i}: {knob.name}")
            code.append(f"    wire [15:0] knob_{i}_value;")
            code.append(f"    assign knob_{i}_value = ui_state_flat[{source_idx*16}+:16];")
            code.append(f"    wire knob_{i}_active;")
            code.append(f"    wire [23:0] knob_{i}_color;")
            code.append(f"    knob_renderer #(")
            code.append(f"        .X_START({knob.x}),")
            code.append(f"        .Y_START({knob.y}),")
            code.append(f"        .SIZE({knob.width}),")
            code.append(f"        .MIN_VALUE({knob.min_value}),")
            code.append(f"        .MAX_VALUE({knob.max_value}),")
            code.append(f"        .MIN_ANGLE({knob.min_angle}),")
            code.append(f"        .MAX_ANGLE({knob.max_angle}),")
            code.append(f"        .FG_COLOR(24'h{knob.fg_color.to_hex():06X}),")
            code.append(f"        .BG_COLOR(24'h{knob.bg_color.to_hex():06X})")
            code.append(f"    ) knob_{i} (")
            code.append(f"        .pixel_x(pixel_x),")
            code.append(f"        .pixel_y(pixel_y),")
            code.append(f"        .value(knob_{i}_value),")
            code.append(f"        .active(knob_{i}_active),")
            code.append(f"        .color(knob_{i}_color)")
            code.append(f"    );")
            code.append("")

        # 合成逻辑
        code.append("    // 合成渲染 (layer 顺序)")
        code.append("    always @(posedge clk or negedge rst_n) begin")
        code.append("        if (!rst_n) begin")
        code.append("            rgb_r <= 8'd0;")
        code.append("            rgb_g <= 8'd0;")
        code.append("            rgb_b <= 8'd0;")
        code.append("        end else begin")
        code.append(f"            // 默认背景色")
        code.append(f"            rgb_r <= 8'd{scene.bg_color.r};")
        code.append(f"            rgb_g <= 8'd{scene.bg_color.g};")
        code.append(f"            rgb_b <= 8'd{scene.bg_color.b};")
        code.append("")

        # 按 layer 顺序渲染
        # Preserve scene order for widgets sharing a layer.  Building this
        # list by type (the old implementation) changed overlap order versus
        # the Python preview.
        widget_slots = {}
        for widget_type, widgets in (
                ('panel', panels), ('text', texts), ('spectrum', spectrums), ('bar', bars),
                ('waveform', waveforms), ('keyboard', keyboards), ('knob', knobs)):
            for idx, widget in enumerate(widgets):
                widget_slots[id(widget)] = (widget_type, idx)

        all_widgets = []
        for order, widget in enumerate(scene.widgets):
            slot = widget_slots.get(id(widget))
            if slot is not None:
                widget_type, idx = slot
                all_widgets.append((widget_type, idx, widget.layer, order))

        all_widgets.sort(key=lambda item: (item[2], item[3]))

        for widget_type, idx, layer, _order in all_widgets:
            code.append(f"            // Layer {layer}: {widget_type} {idx}")
            code.append(f"            if ({widget_type}_{idx}_active) begin")
            code.append(f"                rgb_r <= {widget_type}_{idx}_color[23:16];")
            code.append(f"                rgb_g <= {widget_type}_{idx}_color[15:8];")
            code.append(f"                rgb_b <= {widget_type}_{idx}_color[7:0];")
            code.append(f"            end")
            code.append("")

        code.append("        end")
        code.append("    end")
        code.append("")
        code.append("endmodule")

        output_path.write_text("\n".join(code), encoding="utf-8")
        print(f"[OK] Generated {output_path.name}")


if __name__ == "__main__":
    # 示例：从 JSON 生成 RTL
    import sys

    if len(sys.argv) < 2:
        print("Usage: python rtl_generator.py <input.json> [output_dir]")
        sys.exit(1)

    json_file = Path(sys.argv[1])
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("generated_rtl")

    # 加载 JSON
    scene = UIScene.from_json(json_file)

    # 生成 RTL
    generator = RTLGenerator()
    generator.generate(scene, output_dir)
