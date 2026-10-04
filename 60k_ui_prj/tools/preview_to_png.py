"""Convert ModelSim's real RGB output to viewable PNG artifacts."""
from pathlib import Path
from PySide6.QtGui import QImage

root = Path(__file__).resolve().parents[1]
output = root / 'preview'
output.mkdir(exist_ok=True)
for page in range(3):
    image = QImage(str(root / 'sim' / f'ec11_page_{page}.ppm'))
    if image.isNull() or image.width() != 800 or image.height() != 480:
        raise RuntimeError(f'Invalid RTL raster for page {page}')
    target = output / f'ec11_page_{page}.png'
    if not image.save(str(target)):
        raise RuntimeError(f'Cannot save {target}')
    print(f'RTL_PREVIEW_OK {target}')
