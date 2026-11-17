"""Check theme/selection regressions in native sidebar screenshots.

Usage: uv run --with pillow python scripts/audit-sidebar-captures.py <capture-dir>
This samples settled surfaces, not text antialiasing; inspect contact sheets as well.
"""
from pathlib import Path
import re
import sys
from PIL import Image

root = Path(sys.argv[1])
checks = 0
for path in sorted(root.glob('*.png')):
    match = re.fullmatch(r'(graph|light-graph|sidebar-long|light-sidebar-long|sidebar-opaque|light-sidebar-opaque)-(\d+)x(\d+)\.png', path.name)
    if not match:
        continue
    state, width, height = match.groups()
    shot = Image.open(path).convert('RGB')
    scale = shot.width / int(width)
    assert scale in (1, 2) and shot.height == int(height) * scale, path.name
    def pixel(x, y):
        return shot.getpixel((int(x * scale), int(y * scale)))
    light = state.startswith('light-')
    surface = pixel(8, 300)
    assert (min(surface) > 200 if light else max(surface) < 60), (path.name, 'surface', surface)
    is_chat = state.endswith('long')
    selected = pixel(20, 210 if is_chat else 360)
    inactive = pixel(20, 360 if is_chat else 210)
    expected = (221, 226, 232) if light else (43, 48, 53)
    assert max(abs(a-b) for a, b in zip(selected, expected)) < 12, (path.name, 'selected', selected)
    assert max(abs(a-b) for a, b in zip(inactive, surface)) < 8, (path.name, 'inactive', inactive)
    print(f'PASS {path.name}: correct theme and selected destination')
    checks += 1
assert checks, 'No supported sidebar captures found'
print(f'{checks} native sidebar pixel checks passed')
