"""Assert sidebar contrast on native captures. Run with: uv run --with pillow python ... <dir>."""
from pathlib import Path
import re
import sys
from PIL import Image, ImageStat

root = Path(sys.argv[1])
checked = 0
for path in sorted(root.glob('*.png')):
    match = re.match(r'(.+)-(\d+)x(\d+)\.png$', path.name)
    if not match or '-panel-' in path.name:
        continue
    state, width, height = match[1], int(match[2]), int(match[3])
    if width < 760:
        continue
    image = Image.open(path).convert('RGB')
    scale = image.width / width
    # Narrow gutter avoids text, icons, hover surfaces, scrollbars and the world artwork.
    samples = []
    for y in (100, 300, min(600, height - 80)):
        box = tuple(round(v * scale) for v in (5, y, 9, y + 4))
        rgb = ImageStat.Stat(image.crop(box)).mean
        samples.append(sum(c * w for c, w in zip(rgb, (0.2126, 0.7152, 0.0722))))
    light = state.startswith('light')
    assert all(v > 180 if light else v < 90 for v in samples), (path.name, samples)
    print(f'PASS {path.name}: {"light" if light else "dark"} sidebar luminance {samples}')
    checked += 1
assert checked, 'No desktop captures checked'
