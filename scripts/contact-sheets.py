"""Contact sheets from native captures.

usage: contact-sheets.py <capture-dir> [--prune]

Finds every `<state>-<width>x<height>.png`, checks that the bitmap matches the logical size at an
integer backing scale, and writes one `contact-<size>.jpg` per window size plus `contact-panels.jpg`
for captured sheets. Names are matched exactly so `light` never picks up `light-library`.
`--prune` removes the source PNGs afterwards to keep the repository small.
"""
from pathlib import Path
import math
import re
import sys
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
prune = '--prune' in sys.argv
pattern = re.compile(r'^(?P<state>.+?)(?P<panel>-panel)?-(?P<w>\d+)x(?P<h>\d+)\.png$')
frames, panels = {}, []
for path in sorted(root.glob('*.png')):
    match = pattern.match(path.name)
    if not match:
        continue
    size = f"{match['w']}x{match['h']}"
    if match['panel']:
        panels.append((f"{match['state']} {size}", path))
    else:
        frames.setdefault(size, []).append((match['state'], path))

def sheet(items, out, cell_w, columns):
    pictures = []
    for label, path in items:
        picture = Image.open(path).convert('RGB')
        picture.thumbnail((cell_w, cell_w * 2), Image.LANCZOS)
        pictures.append((label, picture))
    cell_h = max(p.height for _, p in pictures) + 30
    rows = math.ceil(len(pictures) / columns)
    canvas = Image.new('RGB', (columns * (cell_w + 12) + 12, rows * (cell_h + 12) + 12), '#5a6068')
    draw = ImageDraw.Draw(canvas)
    for i, (label, picture) in enumerate(pictures):
        x = 12 + (i % columns) * (cell_w + 12)
        y = 12 + (i // columns) * (cell_h + 12)
        draw.text((x, y + 4), label, fill='white')
        canvas.paste(picture, (x, y + 24))
    canvas.save(out, quality=86)
    print(f'{out.name}: {len(pictures)} captures')

for size, items in frames.items():
    w, h = map(int, size.split('x'))
    for state, path in items:
        picture = Image.open(path)
        scale = picture.width / w
        assert scale in (1, 2) and picture.height == h * scale, (state, size, picture.size)
    order = {name: i for i, (name, _) in enumerate(items)}
    sheet([(f'{s} {size}', p) for s, p in sorted(items, key=lambda v: order[v[0]])],
          root / f'contact-{size}.jpg', min(w, 960), 3)
if panels:
    sheet(panels, root / 'contact-panels.jpg', 640, 3)
steps = [(p.stem.replace('selftest-', ''), p) for p in sorted(root.glob('selftest-*.png'))]
if steps:
    sheet(steps, root / 'contact-selftest.jpg', 960, 3)
if prune:
    for path in root.glob('*.png'):
        path.unlink()
