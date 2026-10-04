#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Low-resource, fixed-contract UI-to-Verilog generator.

Each generation writes exactly one replaceable Verilog source:
``ui_generated_scene.v``.  Board clocks, timing, TMDS PHY and application RTL
stay outside this file, so changing a layout never requires editing them.
"""

import json
from pathlib import Path

try:
    from designer.ui_schema import PanelWidget, TextWidget, BarWidget, KeyboardWidget
except ImportError:
    from ui_schema import PanelWidget, TextWidget, BarWidget, KeyboardWidget


STATUS_SLOTS = {
    "playback_frame_lo": 0,
    "playback_frame_hi": 1,
    "duration_frames_lo": 2,
    "duration_frames_hi": 3,
    "playback_flags": 4,
    "file_index": 5,
    "playback_progress": 6,
    "progress": 6,
    "active_voices": 7,
    "decoder_error": 8,
    "sd_error": 9,
    "player_error": 10,
    "op1_level": 11,
    "op2_level": 12,
    "op3_level": 13,
    "op4_level": 14,
    "op5_level": 15,
    "op6_level": 16,
}

# Five pixels wide, seven rows high.  Only glyphs used by the scene are
# emitted, which keeps static labels inexpensive.
FONT_5X7 = {
    " ": ("00000",)*7,
    "-": ("00000","00000","00000","11111","00000","00000","00000"),
    ".": ("00000","00000","00000","00000","00000","01100","01100"),
    ":": ("00000","01100","01100","00000","01100","01100","00000"),
    "/": ("00001","00010","00100","01000","10000","00000","00000"),
    "#": ("01010","11111","01010","01010","11111","01010","00000"),
    "0": ("01110","10001","10011","10101","11001","10001","01110"),
    "1": ("00100","01100","00100","00100","00100","00100","01110"),
    "2": ("01110","10001","00001","00010","00100","01000","11111"),
    "3": ("11110","00001","00001","01110","00001","00001","11110"),
    "4": ("00010","00110","01010","10010","11111","00010","00010"),
    "5": ("11111","10000","10000","11110","00001","00001","11110"),
    "6": ("01110","10000","10000","11110","10001","10001","01110"),
    "7": ("11111","00001","00010","00100","01000","01000","01000"),
    "8": ("01110","10001","10001","01110","10001","10001","01110"),
    "9": ("01110","10001","10001","01111","00001","00001","01110"),
    "A": ("01110","10001","10001","11111","10001","10001","10001"),
    "B": ("11110","10001","10001","11110","10001","10001","11110"),
    "C": ("01111","10000","10000","10000","10000","10000","01111"),
    "D": ("11110","10001","10001","10001","10001","10001","11110"),
    "E": ("11111","10000","10000","11110","10000","10000","11111"),
    "F": ("11111","10000","10000","11110","10000","10000","10000"),
    "G": ("01111","10000","10000","10111","10001","10001","01111"),
    "H": ("10001","10001","10001","11111","10001","10001","10001"),
    "I": ("01110","00100","00100","00100","00100","00100","01110"),
    "J": ("00001","00001","00001","00001","10001","10001","01110"),
    "K": ("10001","10010","10100","11000","10100","10010","10001"),
    "L": ("10000","10000","10000","10000","10000","10000","11111"),
    "M": ("10001","11011","10101","10101","10001","10001","10001"),
    "N": ("10001","11001","10101","10011","10001","10001","10001"),
    "O": ("01110","10001","10001","10001","10001","10001","01110"),
    "P": ("11110","10001","10001","11110","10000","10000","10000"),
    "Q": ("01110","10001","10001","10001","10101","10010","01101"),
    "R": ("11110","10001","10001","11110","10100","10010","10001"),
    "S": ("01111","10000","10000","01110","00001","00001","11110"),
    "T": ("11111","00100","00100","00100","00100","00100","00100"),
    "U": ("10001","10001","10001","10001","10001","10001","01110"),
    "V": ("10001","10001","10001","10001","10001","01010","00100"),
    "W": ("10001","10001","10001","10101","10101","10101","01010"),
    "X": ("10001","10001","01010","00100","01010","10001","10001"),
    "Y": ("10001","10001","01010","00100","00100","00100","00100"),
    "Z": ("11111","00001","00010","00100","01000","10000","11111"),
}


class CompactRTLGenerator:
    OUTPUT_NAME = "ui_generated_scene.v"
    SUPPORTED = (PanelWidget, TextWidget, BarWidget, KeyboardWidget)

    def generate(self, scene, output_dir: Path):
        self.validate(scene)
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        # Clean only files claimed by a previous generator manifest.  This
        # makes a dedicated generated_rtl directory contain exactly one .v,
        # without risking unrelated RTL when users export directly into a
        # board project's rtl directory.
        old_manifest_path = output_dir / "generated_manifest.json"
        if old_manifest_path.exists():
            try:
                old_manifest = json.loads(old_manifest_path.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                old_manifest = {}
            old_names = set(old_manifest.get("generated_files", []))
            old_names.update(old_manifest.get("generated_verilog", []))
            if output_dir.name.lower() == "generated_rtl":
                old_names.update({
                    "ui_top.v", "pixel_renderer.v", "ui_interaction.v",
                    "text_renderer.v", "font_8x16_full.v",
                    "panel_renderer.v", "bar_renderer.v",
                    "spectrum_renderer.v", "waveform_renderer.v",
                    "keyboard_renderer.v", "knob_renderer.v",
                })
            for name in old_names:
                candidate = output_dir / Path(str(name)).name
                if candidate.suffix.lower() == ".v" and candidate.name != self.OUTPUT_NAME:
                    candidate.unlink(missing_ok=True)
        output_path = output_dir / self.OUTPUT_NAME
        output_path.write_text(self._emit(scene), encoding="utf-8")

        manifest = {
            "scene": scene.name,
            "generated_verilog_count": 1,
            "generated_verilog": [self.OUTPUT_NAME],
            "replace_target": "rtl/ui_generated_scene.v",
            "status_slots": STATUS_SLOTS,
            "filename_ascii": {"first_slot": 17, "bytes": 30},
            "note_active_bits": 128,
            "note_active_meaning": "MIDI note number bitmap; not physical key count",
        }
        (output_dir / "generated_manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"[OK] Generated exactly 1 Verilog file: {output_path}")

    @classmethod
    def validate(cls, scene):
        if getattr(scene, 'pc_bindings', {}):
            raise ValueError('PC UART bindings cannot be exported as HDMI RTL; use Scene FPGA Control')
        if scene.pages or scene.local_actions or any(w.page for w in scene.widgets):
            raise ValueError('PC多页导航不能导出为HDMI RTL；请使用PC运行UI')
        if not (1 <= scene.width <= 2048 and 1 <= scene.height <= 1024):
            raise ValueError("scene resolution exceeds pixel_x[10:0]/pixel_y[9:0]")
        unsupported = [w for w in scene.widgets if w.visible and not isinstance(w, cls.SUPPORTED)]
        if unsupported:
            names = ", ".join(f"{w.name}:{w.type}" for w in unsupported)
            raise ValueError(
                "compact FPGA mode supports panel/text/bar/keyboard only; "
                f"remove or hide high-cost widgets: {names}"
            )
        for w in scene.widgets:
            if not w.visible:
                continue
            if w.width <= 0 or w.height <= 0:
                raise ValueError(f"widget {w.name or w.type} has non-positive size")
            if isinstance(w, BarWidget):
                cls._status_slot(w.source)
            if isinstance(w, KeyboardWidget):
                if not (1 <= w.keys <= 128):
                    raise ValueError("displayed keyboard key count must be 1..128")
                if not (0 <= w.start_note <= 127) or w.start_note + w.keys > 128:
                    raise ValueError("keyboard display window must stay inside MIDI notes 0..127")
            if isinstance(w, TextWidget):
                source = getattr(w, "source", "")
                if source not in ("", "filename"):
                    raise ValueError("compact text source must be empty or 'filename'")
                if not source:
                    try:
                        w.text.upper().encode("ascii")
                    except UnicodeEncodeError as exc:
                        raise ValueError("compact FPGA text currently supports ASCII only") from exc

    @staticmethod
    def _status_slot(source):
        key = str(source).strip().lower()
        if key in STATUS_SLOTS:
            return STATUS_SLOTS[key]
        for prefix in ("status[", "ui_status["):
            if key.startswith(prefix) and key.endswith("]"):
                index = int(key[len(prefix):-1])
                if 0 <= index <= 31:
                    return index
        raise ValueError(
            f"unknown status source '{source}'; use a documented name or status[0..31]"
        )

    @staticmethod
    def _hex(color):
        return f"24'h{color.to_hex():06X}"

    def _emit(self, scene):
        widgets = [(order, w) for order, w in enumerate(scene.widgets) if w.visible]
        widgets.sort(key=lambda item: (item[1].layer, item[0]))
        texts = [w for _, w in widgets if isinstance(w, TextWidget)]
        bars = [w for _, w in widgets if isinstance(w, BarWidget)]

        used_chars = {" "}
        for w in texts:
            if not getattr(w, "source", ""):
                used_chars.update(w.text.upper())

        out = [
            "`timescale 1ns / 1ps",
            "",
            "// AUTO-GENERATED. Replace this file only; do not edit other RTL.",
            "// ui_status_flat slots (16-bit each):",
            "// 0..1 playback_frame, 2..3 duration_frames, 4 flags, 5 file_index,",
            "// 6 progress(0..1023), 7 active_voices, 8 decoder_error,",
            "// 9 sd_error, 10 player_error, 11..16 operator levels(0..1023),",
            "// 17..31 filename ASCII (30 bytes, little-endian byte order).",
            "// note_active[n] means MIDI note number n; displayed key count is per-widget.",
            "module ui_generated_scene (",
            "    input  wire         clk,",
            "    input  wire         rst_n,",
            "    input  wire [10:0]  pixel_x,",
            "    input  wire [9:0]   pixel_y,",
            "    input  wire [511:0] ui_status_flat,",
            "    input  wire [127:0] note_active,",
            "    output wire [23:0]  pixel_rgb",
            ");",
            "",
            "    function [4:0] font5x7;",
            "        input [7:0] ch;",
            "        input [2:0] row;",
            "        begin",
            "            case ({ch, row})",
        ]
        for ch in sorted(used_chars):
            glyph = FONT_5X7.get(ch, FONT_5X7[" "])
            for row, bits in enumerate(glyph):
                if "1" in bits:
                    out.append(f"                {{8'd{ord(ch)}, 3'd{row}}}: font5x7 = 5'b{bits};")
        out += [
            "                default: font5x7 = 5'b00000;",
            "            endcase",
            "        end",
            "    endfunction",
            "",
        ]

        for i, w in enumerate(bars):
            slot = self._status_slot(w.source)
            out.append(f"    wire [15:0] bar_{i}_value = ui_status_flat[{slot * 16} +: 16];")
            # Keep the full 10-bit value x 16-bit width product BEFORE the
            # right shift. A 16-bit intermediate wrapped ordinary wide bars.
            out.append(f"    wire [25:0] bar_{i}_product = bar_{i}_value[9:0] * 16'd{w.width};")
            out.append(f"    wire [15:0] bar_{i}_fill = bar_{i}_product >> 10;")
        if bars:
            out.append("")

        for i, w in enumerate(texts):
            scale = 2 if w.font_size >= 14 else 1
            cell_w = 8 * scale
            glyph_h = 7 * scale
            max_chars = max(1, w.width // cell_w)
            out += [
                f"    wire [10:0] text_{i}_lx = pixel_x - 11'd{w.x};",
                f"    wire [9:0] text_{i}_ly = pixel_y - 10'd{w.y};",
                f"    wire [7:0] text_{i}_index = text_{i}_lx / {cell_w};",
                f"    reg [7:0] text_{i}_char;",
                f"    always @(*) begin",
                f"        case (text_{i}_index)",
            ]
            if getattr(w, "source", "") == "filename":
                for index in range(min(30, max_chars)):
                    bit = 17 * 16 + index * 8
                    out.append(f"            8'd{index}: text_{i}_char = ui_status_flat[{bit} +: 8];")
            else:
                for index, ch in enumerate(w.text.upper()[:max_chars]):
                    out.append(f"            8'd{index}: text_{i}_char = 8'd{ord(ch)};")
            out += [
                f"            default: text_{i}_char = 8'd32;",
                "        endcase",
                "    end",
                f"    wire [2:0] text_{i}_row = text_{i}_ly / {scale};",
                f"    wire [2:0] text_{i}_col = (text_{i}_lx % {cell_w}) / {scale};",
                f"    wire [4:0] text_{i}_glyph = font5x7(text_{i}_char, text_{i}_row);",
                f"    wire text_{i}_pixel = (text_{i}_lx < {w.width}) &&",
                f"        (text_{i}_ly < {glyph_h}) && (text_{i}_col < 5) &&",
                f"        text_{i}_glyph[4-text_{i}_col];",
                "",
            ]

        # Emit every visual as an independent {active,rgb} candidate.  A
        # balanced priority tree below selects the last active candidate.
        # This is materially shallower than a long procedural if-chain and is
        # what lets a non-trivial 720p scene meet the 74.25 MHz pixel clock.
        leaves = []
        panel_index = bar_index = text_index = keyboard_index = 0
        for _, w in widgets:
            inside = (f"(pixel_x >= {w.x}) && (pixel_x < {w.x + w.width}) && "
                      f"(pixel_y >= {w.y}) && (pixel_y < {w.y + w.height})")
            if isinstance(w, PanelWidget):
                color_expr = self._hex(w.bg_color)
                bw = max(0, int(w.border_width))
                if bw:
                    edge = (f"(pixel_x < {w.x + bw}) || (pixel_x >= {w.x + w.width - bw}) || "
                            f"(pixel_y < {w.y + bw}) || (pixel_y >= {w.y + w.height - bw})")
                    color_expr = f"({edge}) ? {self._hex(w.border_color)} : {color_expr}"
                name = f"component_{len(leaves)}"
                out.append(f"    wire [24:0] {name} = ({inside}) ? {{1'b1, {color_expr}}} : 25'd0;")
                leaves.append(name)
                panel_index += 1
            elif isinstance(w, BarWidget):
                color_expr = (f"((pixel_x - {w.x}) < bar_{bar_index}_fill) ? "
                              f"{self._hex(w.fg_color)} : {self._hex(w.bg_color)}")
                name = f"component_{len(leaves)}"
                out.append(f"    wire [24:0] {name} = ({inside}) ? {{1'b1, {color_expr}}} : 25'd0;")
                leaves.append(name)
                bar_index += 1
            elif isinstance(w, TextWidget):
                name = f"component_{len(leaves)}"
                out.append(
                    f"    wire [24:0] {name} = text_{text_index}_pixel ? "
                    f"{{1'b1, {self._hex(w.color)}}} : 25'd0;"
                )
                leaves.append(name)
                text_index += 1
            elif isinstance(w, KeyboardWidget):
                for key in range(w.keys):
                    x0 = w.x + (key * w.width) // w.keys
                    x1 = w.x + ((key + 1) * w.width) // w.keys
                    note = w.start_note + key
                    black = (note % 12) in (1, 3, 6, 8, 10)
                    base = w.black_key_color if black else w.white_key_color
                    key_inside = (f"(pixel_x >= {x0}) && (pixel_x < {x1}) && "
                                  f"(pixel_y >= {w.y}) && (pixel_y < {w.y + w.height})")
                    key_color = (f"(pixel_x == {x0}) ? 24'h202632 : "
                                 f"(note_active[{note}] ? {self._hex(w.pressed_color)} : {self._hex(base)})")
                    name = f"component_{len(leaves)}"
                    out.append(f"    wire [24:0] {name} = ({key_inside}) ? {{1'b1, {key_color}}} : 25'd0;")
                    leaves.append(name)
                keyboard_index += 1
        out.append("")
        level = 0
        nodes = leaves
        while len(nodes) > 1:
            next_nodes = []
            for pair in range(0, len(nodes), 2):
                if pair + 1 == len(nodes):
                    next_nodes.append(nodes[pair])
                    continue
                left = nodes[pair]
                right = nodes[pair + 1]
                name = f"compose_l{level}_{pair // 2}"
                out.append(f"    wire [24:0] {name} = {right}[24] ? {right} : {left};")
                next_nodes.append(name)
            # Fixed one-cycle pipeline after the first balanced merge level.
            # The stable board top delays DE/HS/VS by the matching extra cycle.
            if level == 0 and len(next_nodes) > 1:
                piped_nodes = []
                for index, source in enumerate(next_nodes):
                    name = f"compose_pipe_{index}"
                    out.append(f"    reg [24:0] {name};")
                    out.append("    always @(posedge clk or negedge rst_n) begin")
                    out.append(f"        if (!rst_n) {name} <= 25'd0;")
                    out.append(f"        else {name} <= {source};")
                    out.append("    end")
                    piped_nodes.append(name)
                next_nodes = piped_nodes
            nodes = next_nodes
            level += 1
        if nodes:
            out.append(
                f"    assign pixel_rgb = {nodes[0]}[24] ? {nodes[0]}[23:0] : {self._hex(scene.bg_color)};"
            )
        else:
            out.append(f"    assign pixel_rgb = {self._hex(scene.bg_color)};")
        out += ["", "    wire unused_contract_inputs = clk ^ rst_n;", "endmodule", ""]
        return "\n".join(out)
