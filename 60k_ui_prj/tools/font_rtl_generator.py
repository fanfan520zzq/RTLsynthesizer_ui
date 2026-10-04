"""Shared-font pixel descriptors: one synchronous ROM for all three pages.

Pages emit only background RGB and a selected text descriptor. The wrapper
selects one page before the font ROM, and delays every overlay by that same
one clock. No glyph decoder is replicated per label; no framebuffer is used.
"""
import re
from pathlib import Path


def load_glyphs(path):
    values = [int(line.split('//', 1)[0].strip(), 16)
              for line in Path(path).read_text(encoding='utf-8').splitlines()
              if re.fullmatch(r'[0-9A-Fa-f]{2}', line.split('//', 1)[0].strip())]
    if len(values) != 95*16:
        raise ValueError('Expected exactly 95 printable ASCII glyphs, 16 rows each')
    return {32+i: values[i*16:(i+1)*16] for i in range(95)}


def emit_font_rom(glyphs):
    out = [
        '// One 2048x8 synchronous ROM shared by ALL pages/labels.',
        '// MSB is the leftmost pixel. Unsupported ASCII is blank.',
        'module ui_ec11_font_rom (',
        '    input wire clk,',
        '    input wire [6:0] char_code,',
        '    input wire [3:0] row,',
        '    output reg [7:0] pixels',
        ');',
        '    reg [7:0] font_rows [0:2047];',
        '    integer i;',
        '    initial begin',
        "        for (i=0; i<1024; i=i+1) begin",
        "            font_rows[i] = 8'd0;",
        "            font_rows[i+1024] = 8'd0;",
        "        end",
    ]
    for ch, rows in sorted(glyphs.items()):
        for row, bits in enumerate(rows):
            if bits:
                out.append(f"        font_rows[{ch*16+row}] = 8'h{bits:02X};")
    out += ['    end', '    always @(posedge clk) pixels <= font_rows[{char_code,row}];',
            'endmodule', '']
    return '\n'.join(out)


def balanced(out, leaves, width, prefix):
    nodes = leaves
    level = 0
    while len(nodes) > 1:
        next_nodes = []
        for i in range(0, len(nodes), 2):
            if i+1 == len(nodes):
                next_nodes.append(nodes[i])
            else:
                name = f'{prefix}_{level}_{i//2}'
                out.append(f'    wire [{width-1}:0] {name} = {nodes[i+1]}[{width-1}] ? {nodes[i+1]} : {nodes[i]};')
                next_nodes.append(name)
        nodes = next_nodes
        level += 1
    return nodes[0] if nodes else f"{width}'d0"


def rect_overlap(a, b):
    return (a[0] < b[0]+b[2] and b[0] < a[0]+a[2] and
            a[1] < b[1]+b[3] and b[1] < a[1]+a[3])


def emit_page(scene, page_index, dynamic):
    widgets = [w for _,w in sorted(enumerate(scene.widgets), key=lambda p:(p[1].layer,p[0])) if w.visible]
    texts = [w for w in widgets if w.type == 'text']
    # A single font port may select one text rectangle per pixel. Explicitly
    # reject overlapping text or a higher-layer panel covering text, instead
    # of silently changing transparency/layer semantics.
    extents = []
    for w in texts:
        scale = 2 if w.font_size == 32 else 1
        extent = (w.x, w.y, len(w.text)*8*scale, 16*scale)
        for previous in extents:
            if rect_overlap(extent, previous):
                raise ValueError(f'Shared-font text rectangles overlap: {w.name}')
        for other in widgets:
            if other.type != 'text' and other.layer > w.layer and rect_overlap(
                    extent, (other.x,other.y,other.width,other.height)):
                raise ValueError(f'Higher-layer background covers text: {w.name}')
        extents.append(extent)

    hx = lambda color: f"24'h{color.to_hex():06X}"
    out = [f'module ui_ec11_page_{page_index} (',
           '    input wire [10:0] pixel_x,', '    input wire [9:0] pixel_y,',
           '    input wire [511:0] ui_status_flat,',
           '    output wire [23:0] background_rgb,',
           '    output wire [38:0] text_descriptor', ');',
           '    function [6:0] hexchar;', '        input [3:0] nibble;',
           "        begin hexchar=(nibble<10)?7'd48+nibble:7'd55+nibble; end",
           '    endfunction']
    background = []
    for w in widgets:
        if w.type == 'text':
            continue
        inside = f'(pixel_x>={w.x} && pixel_x<{w.x+w.width} && pixel_y>={w.y} && pixel_y<{w.y+w.height})'
        if w.type == 'panel':
            edge = f'(pixel_x<{w.x+w.border_width} || pixel_x>={w.x+w.width-w.border_width} || pixel_y<{w.y+w.border_width} || pixel_y>={w.y+w.height-w.border_width})'
            color = f'{edge} ? {hx(w.border_color)} : {hx(w.bg_color)}' if w.border_width else hx(w.bg_color)
        elif w.type == 'bar':
            slot = int(re.search(r'\[(\d+)\]', w.source)[1])
            i = len(background)
            out += [f'    wire [9:0] bar_{i}_value=ui_status_flat[{slot*16}+:10];',
                    f"    wire [25:0] bar_{i}_product=bar_{i}_value*16'd{w.width};",
                    f'    wire [15:0] bar_{i}_fill=bar_{i}_product>>10;']
            color = f'((pixel_x-{w.x})<bar_{i}_fill) ? {hx(w.fg_color)} : {hx(w.bg_color)}'
        else:
            raise ValueError(f'Unsupported background: {w.name}')
        name = f'background_{len(background)}'
        out.append(f"    wire [24:0] {name} = {inside} ? {{1'b1, {color}}} : 25'd0;")
        background.append(name)
    chosen_bg = balanced(out, background, 25, 'bg_compose')
    out.append(f'    assign background_rgb={chosen_bg}[24] ? {chosen_bg}[23:0] : {hx(scene.bg_color)};')

    descriptors = []
    for i,w in enumerate(texts):
        scale = 2 if w.font_size == 32 else 1
        cell = 8*scale
        out += [f"    wire [10:0] text_{i}_lx=pixel_x-11'd{w.x};",
                f"    wire [9:0] text_{i}_ly=pixel_y-10'd{w.y};",
                f'    wire [7:0] text_{i}_index=text_{i}_lx/{cell};',
                f'    wire [3:0] text_{i}_row=text_{i}_ly/{scale};',
                f'    wire [2:0] text_{i}_col=(text_{i}_lx%{cell})/{scale};',
                f'    reg [6:0] text_{i}_char;', '    always @* begin',
                f'        case (text_{i}_index)']
        dyn = dynamic.get(w.name)
        for ci,ch in enumerate(w.text):
            if not 32 <= ord(ch) <= 126:
                raise ValueError(f'Only printable ASCII supported: {w.name}')
            if dyn and ci >= len(w.text)-dyn[2]:
                di = ci-(len(w.text)-dyn[2])
                expr = f'hexchar(ui_status_flat[{dyn[1]*16+(dyn[2]-1-di)*4}+:4])'
            else:
                expr = f"7'd{ord(ch)}"
            out.append(f"            8'd{ci}: text_{i}_char={expr};")
        out += [f"            default: text_{i}_char=7'd32;", '        endcase', '    end']
        name = f'descriptor_{i}'
        inside = f'(text_{i}_lx<{len(w.text)*cell} && text_{i}_ly<{16*scale})'
        out.append(f"    wire [38:0] {name}={inside} ? {{1'b1,{hx(w.color)},text_{i}_char,text_{i}_row,text_{i}_col}} : 39'd0;")
        descriptors.append(name)
    out.append(f'    assign text_descriptor={balanced(out,descriptors,39,"text_compose")};')
    out += ['endmodule', '']
    return '\n'.join(out)
