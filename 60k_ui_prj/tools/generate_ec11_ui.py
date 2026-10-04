"""Migrate the named PC three-page layout to the local EC11 test backend.

Writes exactly one replaceable RTL source. Never interprets PC UART bindings
as FPGA acknowledgements. Uses verilogQT schema and one native 8x16 font ROM.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from font_rtl_generator import emit_page, emit_font_rom, load_glyphs

ROOT = Path(__file__).resolve().parents[1]
PAGES = ('sd_songs', 'sound_fx', 'status_play')
FOCUS_NAMES = [
    ['scan_bg', 'prev_bg', 'next_bg', 'load_bg'],
    [f'preset_{i}_bg' for i in range(7)] +
    ['fx_R', 'fx_D', 'fx_W', 'fx_M', 'fx_on_bg', 'fx_off_bg'],
    ['auto_bg', 'play_bg', 'stop_bg', 'query_bg'],
]
NAV = ['nav_sd_songs_bg', 'nav_sound_fx_bg', 'nav_status_play_bg']
STATIC = {
    'title': 'EC11 / THREE PAGE UI',
    'link': 'LOCAL TEST - NO SD/AUDIO',
    'hint': 'ROTATE: FOCUS - CLICK: ENTER/OK - HOLD 0.8S: CANCEL/BACK',
    'loaded_file': 'SD BACKEND NOT CONNECTED - DEMO ITEMS ONLY',
    'prev': 'PREV', 'next': 'NEXT',
    'sd_help': 'SCAN AND LOAD RECORD LOCAL REQUESTS ONLY',
    'sd_format': 'NO REAL FILE SCAN OR LOAD IN THIS STANDALONE TEST',
    'fx_help': 'LOCAL VALUES ONLY - CLICK A VALUE TO EDIT - RANGE 00 TO FF HEX',
    'status_loaded': 'SD / SYNTH BACKEND: NOT CONNECTED',
    'mode': 'LOCAL REQUEST ONLY - NO MUSIC PLAYBACK',
    'play_help': 'REQUEST CODES: 01 SCAN 02 PREV 03 NEXT 04 LOAD',
    'play_ack_help': '05 AUTO 06 PLAY 07 STOP 08 QUERY - NO BACKEND ACK',
}
# (label with trailing placeholder, status slot, number of hexadecimal digits)
DYNAMIC = {
    'selected_file': ('DEMO ITEM: 0', 5, 1),
    'preset': ('LOCAL PATCH: 0', 7, 1),
    'read_R': ('HEX: 00', 15, 2),
    'read_D': ('HEX: 00', 16, 2),
    'read_W': ('HEX: 00', 0, 2),
    'read_M': ('HEX: 00', 1, 2),
    'fx_enable': ('LOCAL FX ENABLE: 0', 4, 1),
    'playback': ('LAST LOCAL REQUEST: 00', 8, 2),
}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--pc-root', type=Path,
                    default=ROOT.parent / 'verilogQT')
    ap.add_argument('--scene', type=Path, default=ROOT / 'scenes/dimension_autoplay_pc.json')
    args = ap.parse_args()
    sys.path.insert(0, str(args.pc_root))
    from designer.ui_schema import UIScene
    font_path = ROOT / 'scenes/font_8x16.mem'
    glyphs = load_glyphs(font_path)
    raw = json.loads(args.scene.read_text(encoding='utf-8'))
    UIScene.from_dict(raw).validate_navigation()
    if (raw['width'], raw['height']) != (800, 480):
        raise ValueError('This board test requires 800x480')
    if [p['id'] for p in raw['pages']] != list(PAGES) or raw['initial_page'] != PAGES[0]:
        raise ValueError('Page IDs/order/default must match the EC11 controller')
    by_name = {w['name']: w for w in raw['widgets']}
    if len(by_name) != len(raw['widgets']):
        raise ValueError('Duplicate widget names')
    for name in NAV + sum(FOCUS_NAMES, []) + list(STATIC) + list(DYNAMIC):
        if name not in by_name or not by_name[name].get('visible', True):
            raise ValueError(f'Required visible widget missing: {name}')
    for ni, name in enumerate(NAV):
        w = by_name[name]
        if w['type'] != 'panel' or w.get('page', ''):
            raise ValueError(f'Navigation focus must be a shared panel: {name}')
        if raw['local_actions'].get(name) != {'action': 'switch_page', 'target': PAGES[ni]}:
            raise ValueError(f'Navigation target must match the controller: {name}')
    for pi, names in enumerate(FOCUS_NAMES):
        for name in names:
            if by_name[name].get('page') != PAGES[pi]:
                raise ValueError(f'Control ownership must match the controller: {name}')
    codes = []
    for pi, page_id in enumerate(PAGES):
        converted = []
        for original in raw['widgets']:
            if original.get('page', '') not in ('', page_id):
                continue
            w = copy.deepcopy(original)
            w['page'] = ''
            x, y, width, height = (w[k] for k in ('x', 'y', 'width', 'height'))
            if min(x, y) < 0 or min(width, height) < 1 or x+width > 800 or y+height > 480:
                raise ValueError(f'Widget outside panel: {w["name"]}')
            if w['type'] == 'knob':
                i = 'RDWM'.index(w['name'][-1])
                # A low-cost level bar replaces the PC circular knob.
                w = {k: w[k] for k in ('name', 'x', 'y', 'width', 'height', 'layer', 'page')}
                w.update(type='bar', source=f'status[{11+i}]',
                         fg_color=original.get('fg_color', {'r':56,'g':189,'b':248}),
                         bg_color=original.get('bg_color', {'r':30,'g':41,'b':59}))
            elif w['type'] == 'text':
                name = w['name']
                if name in STATIC:
                    w['text'] = STATIC[name]
                elif name in DYNAMIC:
                    w['text'] = DYNAMIC[name][0]
                elif name.startswith('catalog_row_'):
                    w['text'] = f'DEMO {name[-1]} - UI ITEM ONLY'
                w['source'] = ''
                # Native 8x16 or a true 2x enlargement to 16x32. Both axes
                # always use the same integer scale; never stretch body text.
                w['font_size'] = 16 if w.get('font_size', 16) <= 16 else 32
                cell = w['font_size'] // 2
                w['height'] = max(w['height'], w['font_size'])
                if w['y']+w['height'] > 480:
                    raise ValueError(f'Font rectangle outside panel: {name}')
                if len(w['text']) * cell > w['width']:
                    raise ValueError(f'Text too wide in native font: {name}')
                if w.get('align') == 'center':
                    offset = (w['width'] - len(w['text']) * cell) // 2
                    w['x'] += offset
                    w['width'] -= offset
            elif w['type'] != 'panel':
                raise ValueError(f'Unsupported visible widget: {w["name"]}')
            converted.append(w)
        scene = UIScene.from_dict(dict(name=page_id, width=800, height=480,
                                       bg_color=raw['bg_color'], widgets=converted))
        codes.append(emit_page(scene, pi, DYNAMIC))

    wrapper = (ROOT / 'tools/ui_ec11_scene_wrapper.v.in').read_text(encoding='utf-8')
    focus_code = []
    for pi, names in enumerate(FOCUS_NAMES):
        focus_code.append(f"            2'd{pi}: case (focus_s)")
        for fi, name in enumerate(names, 3):
            w = by_name[name]
            focus_code.append(f"                4'd{fi}: begin fx={w['x']}; fy={w['y']}; fw={w['width']}; fh={w['height']}; end")
        focus_code.append('            endcase')
    nav_code = []
    for ni, name in enumerate(NAV):
        w = by_name[name]
        nav_code.append(f"            4'd{ni}: begin fx={w['x']}; fy={w['y']}; fw={w['width']}; fh={w['height']}; end")
    selected_code = []
    for pi, names, state in [(0, [f'catalog_row_{i}' for i in range(6)], 'selected_s'),
                              (1, [f'preset_{i}_bg' for i in range(7)], 'preset_s')]:
        selected_code.append(f"            2'd{pi}: case ({state})")
        for idx, name in enumerate(names):
            w = by_name[name]
            x,y,width,height = (w[k] for k in ('x','y','width','height'))
            if pi == 0:
                x -= 8; y -= 3; width += 16; height += 3
                if x < 0 or y < 0 or x+width > 800 or y+height > 480:
                    raise ValueError(f'Demo selection outline outside panel: {name}')
            selected_code.append(f"                3'd{idx}: begin sx={x}; sy={y}; sw={width}; sh={height}; end")
        selected_code.append('            endcase')
    wrapper = wrapper.replace('// @FOCUS_PAGE_CASES@', '\n'.join(focus_code))
    wrapper = wrapper.replace('// @FOCUS_NAV_CASES@', '\n'.join(nav_code))
    wrapper = wrapper.replace('// @SELECTED_CASES@', '\n'.join(selected_code))
    digest = hashlib.sha256(args.scene.read_bytes()).hexdigest()
    output = ROOT / 'rtl/ui_ec11_scene.v'
    font_digest = hashlib.sha256(font_path.read_bytes()).hexdigest()
    output.write_text(f'// Layout SHA256: {digest}\n// Font SHA256: {font_digest}\n' +
                      wrapper + '\n' + '\n'.join(codes) + emit_font_rom(glyphs), encoding='utf-8')
    print(f'EC11_UI_GENERATED pages=3 output={output} source_sha256={digest}')


if __name__ == '__main__':
    main()
