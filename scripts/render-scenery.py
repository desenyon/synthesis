"""Build-time ASCII landscape. No procedural text rendering in the app's frame loop."""
from PIL import Image, ImageDraw, ImageFont
import math, random
from pathlib import Path
rng=random.Random(1729)
w,h=1920,1120
im=Image.new('RGBA',(w,h),(0,0,0,0));d=ImageDraw.Draw(im)
font=ImageFont.truetype('/System/Library/Fonts/SFNSMono.ttf',8)
chars=' .,:;+=x%#@'
for row in range(125):
 for col in range(320):
  x,y=col*6,row*9
  nx=x/w;ny=y/h
  far=.48+.065*math.sin(nx*15)+.035*math.sin(nx*39)+.012*math.sin(nx*117)
  near=.70+.11*math.sin(nx*11+1)+.04*math.sin(nx*42)
  moon=((nx-.69)/.075)**2+((ny-.27)/.13)**2
  density=0;alpha=0
  if moon<1:
   density=.6+.3*math.sin(nx*95+ny*32)*math.cos(ny*87);alpha=85
  elif ny>near:
   density=.18+.38*(math.sin(nx*83+ny*72)**2);alpha=int(32*(1-(ny-near)*1.2))
  elif ny>far:
   density=.25+.37*math.sin(nx*63+ny*52)**2;alpha=48
  elif rng.random()<.007:
   density=.55;alpha=80
  else:continue
  char=chars[min(9,int(density*10))]
  fade=min(1,max(0,(1-nx)*3))*min(1,max(0,(1-ny)*3))
  d.text((x,y),char,font=font,fill=(112,155,165,int(alpha*fade)))
# sparse engraved constellation, deliberately no UI controls in the artwork
points=[(170,240),(280,170),(390,270),(480,210),(590,295)]
for a,b in zip(points,points[1:]): d.line((a,b),fill=(108,150,166,20),width=1)
for x,y in points:d.text((x-4,y-4),'+',font=font,fill=(147,179,189,120))
Path('Sources/SynthesisUI/Assets').mkdir(exist_ok=True)
im.save('Sources/SynthesisUI/Assets/landscape.png')
