"""Original cartographic illustration for the explicitly labeled Aster sample fixture."""
from PIL import Image, ImageDraw
import math
from pathlib import Path
w,h=900,420
im=Image.new('RGB',(w,h),'#223642'); d=ImageDraw.Draw(im)
for row in range(18):
    points=[]
    for x in range(-30,w+30,5):
        y=230+row*13+math.sin(x/100+row*.08)*19+math.sin(x/42)*5
        points.append((x,y))
    d.line(points,fill=(63+row,87+row,100+row),width=1)
for j in range(10):
    p=[]
    for i in range(140):
        a=i/139*math.pi*2
        r=90+j*11+math.sin(a*3)*11+math.cos(a*7)*5
        p.append((w*.7+math.cos(a)*r*1.5,h*.31+math.sin(a)*r*.55))
    d.line(p,fill=(98+j*4,120+j*4,126+j*3),width=2)
d.line([(115,300),(280,235),(420,249),(600,135)],fill='#C3B890',width=2)
for x,y in [(115,300),(280,235),(420,249),(600,135)]:
    d.ellipse((x-4,y-4,x+4,y+4),fill='#D8CBA6')
d.line([(60,54),(60,92)],fill='#9EB5BF',width=2);d.line([(41,73),(79,73)],fill='#9EB5BF',width=2)
path=Path(__file__).resolve().parent.parent/'Sources/SynthesisUI/Assets/aster-coast.png'
im.save(path)
