"""Diagnostic contact sheets from real native captures, with backing-scale validation."""
from pathlib import Path
import math
import sys
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
connected = (root / 'conversation-home-1440x900.png').exists()
if connected:
    states = ['conversation-home', 'conversation', 'canvas', 'companion', 'manual', 'collapsed', 'light', 'graph', 'library']
    sizes = ['1440x900', '1920x1080', '1024x768']
else:
    states = ['canvas', 'conversation', 'power-system', 'detail', 'collapsed', 'light'] if (root / 'canvas-1440x900.png').exists() else ['ai-home', 'active-chat', 'manual', 'editor', 'collapsed', 'dark']
    sizes = ['1440x900', '1920x1080', '1024x768', '390x844']
for size in sizes:
    cell_w, cell_h = (600, 420) if connected else (480, 560)
    sheet = Image.new('RGB', (cell_w * 3, cell_h * math.ceil(len(states)/3)), '#d9dce3')
    draw = ImageDraw.Draw(sheet)
    for i, state in enumerate(states):
        picture = Image.open(root / f'{state}-{size}.png')
        w,h = map(int, size.split('x'))
        scale = picture.width/w
        assert scale in (1,2) and picture.height == h * scale, (state,size,picture.size)
        picture.thumbnail((cell_w-10, cell_h-40))
        x, y = (i%3)*cell_w, (i//3)*cell_h
        draw.text((x+10,y+8), f'{state} {size} ({int(scale)}x)', fill='black')
        sheet.paste(picture, (x+(cell_w-picture.width)//2,y+30))
    sheet.save(root / f'contact-{size}.jpg')
