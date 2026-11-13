"""Diagnostic contact sheets of real native captures. Run with uv --with pillow."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
for size in ['1440x900', '1920x1080', '1024x768', '390x844']:
    sheet = Image.new('RGB', (1440, 1120), '#d9dce3')
    draw = ImageDraw.Draw(sheet)
    for i, state in enumerate(['ai-home', 'active-chat', 'manual', 'editor', 'collapsed', 'dark']):
        picture = Image.open(root / f'{state}-{size}.png')
        expected = tuple(int(n) * 2 for n in size.split('x'))
        assert picture.size == expected, (state, size, picture.size)
        picture.thumbnail((470, 510))
        x, y = (i % 3) * 480, (i // 3) * 560
        draw.text((x + 10, y + 8), f'{state} {size}', fill='black')
        sheet.paste(picture, (x + (480 - picture.width) // 2, y + 30))
    sheet.save(root / f'contact-{size}.jpg')
