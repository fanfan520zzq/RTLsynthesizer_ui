"""Bake native monospaced glyphs into 8x16 cells, with NO geometric resize.

The resulting .mem snapshot is embedded in the generated Verilog, so synthesis
does not depend on Windows fonts, Pillow, or any external memory file.
"""
import argparse
import hashlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path, default=Path('C:/Windows/Fonts/consolab.ttf'))
    args = parser.parse_args()
    font = ImageFont.truetype(str(args.font), 14)
    baseline = 12
    lines = [
        '// Native 8x16 cell, ASCII 32..126, 16 bytes per character.',
        '// Consolas Bold, rasterized at 14 px, baseline y=12, threshold=96.',
        '// No horizontal/vertical resampling or stretch. TTF not distributed.',
        f'// Source TTF SHA256: {hashlib.sha256(args.font.read_bytes()).hexdigest()}',
    ]
    for code in range(32, 127):
        ch = chr(code)
        left, top, right, bottom = font.getbbox(ch, anchor='ls')
        if left < 0 or right > 8 or top+baseline < 0 or bottom+baseline > 16:
            raise ValueError(f'Glyph does not fit native 8x16 cell: {ch!r}')
        if font.getlength(ch) != 8:
            raise ValueError(f'Font is not an 8-pixel monospaced raster: {ch!r}')
        im = Image.new('L', (8, 16), 0)
        ImageDraw.Draw(im).text((0, baseline), ch, font=font, anchor='ls', fill=255)
        lines.append(f'// ASCII {code}')
        for y in range(16):
            value = sum((1 << (7-x)) for x in range(8) if im.getpixel((x, y)) >= 96)
            lines.append(f'{value:02X}')
    output = ROOT / 'scenes/font_8x16.mem'
    output.write_text('\n'.join(lines)+'\n', encoding='utf-8')
    print(f'NATIVE_FONT_OK chars=95 cell=8x16 output={output}')


if __name__ == '__main__':
    main()
