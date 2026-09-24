"""Compose renders into a labeled review sheet; make true 64px card previews."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'preview'
OUT.mkdir(exist_ok=True)
font_path = 'C:/Windows/Fonts/segoeui.ttf'
bold_path = 'C:/Windows/Fonts/segoeuib.ttf'
font = lambda size,bold=False: ImageFont.truetype(bold_path if bold else font_path,size)
canvas = Image.new('RGB',(1600,1110),(19,25,38))
d = ImageDraw.Draw(canvas)
d.text((48,30),'LASSO ASSET KIT',font=font(34,True),fill=(243,238,225))
d.text((48,79),'Four tier textures. One shared coil. Matching capture and break effects.',font=font(20),fill=(171,183,202))

def put(path,box):
    im = Image.open(path).convert('RGBA')
    im.thumbnail((box[2]-box[0],box[3]-box[1]),Image.Resampling.LANCZOS)
    pos = (box[0]+(box[2]-box[0]-im.width)//2,box[1]+(box[3]-box[1]-im.height)//2)
    canvas.paste(im,pos,im)

for i,(key,label,detail,accent) in enumerate([
    ('rope','Rope','Tan rope / leather grip',(218,181,126)),
    ('braided','Braided','Woven pattern / dark grip',(186,124,72)),
    ('golden','Golden','Gold rope / copper-brown grip',(245,186,49)),
    ('elite','Elite','Purple rope / gold + blue emblem',(149,105,234))]):
    x = 32+i*392
    d.rounded_rectangle((x,129,x+372,629),radius=18,fill=(28,36,52))
    d.rounded_rectangle((x+18,150,x+22,182),radius=2,fill=accent)
    d.text((x+34,150),label,font=font(25,True),fill=(243,238,225))
    put(ROOT/'tiers'/'preview'/f'{key}.png',(x+8,185,x+364,552))
    d.text((x+20,571),detail,font=font(17),fill=(192,200,213))
    thumb = Image.open(ROOT/'tiers'/'preview'/f'{key}.png').convert('RGBA').resize((64,64),Image.Resampling.LANCZOS)
    thumb.save(OUT/f'{key}-64.png')

d.text((48,661),'REUSABLE EFFECT MESHES',font=font(22,True),fill=(243,238,225))
for i,(key,label,detail,path) in enumerate([
    ('loop','Capture loop','1,276 triangles / all four textures',ROOT/'loop'/'preview'/'loop-rope.png'),
    ('snapped-end','Snapped end','454 triangles / clone twice',ROOT/'snapped-end'/'preview'/'snapped-end-rope.png'),
    ('daze-star','Daze star','276 triangles / instance and orbit',ROOT/'daze-star'/'preview'/'daze-star-hero.png')]):
    x = 32+i*522
    d.rounded_rectangle((x,704,x+504,1036),radius=18,fill=(28,36,52))
    d.text((x+20,721),label,font=font(23,True),fill=(243,238,225))
    put(path,(x+14,755,x+490,982))
    d.text((x+20,996),detail,font=font(17),fill=(192,200,213))
d.text((48,1061),'Blender sources + FBX + 1024 / 512 px PNG atlases  |  Coil: 4,964 triangles  |  Local assets; not uploaded',
       font=font(17),fill=(158,172,194))
canvas.save(OUT/'lasso-kit.png')

# Inspection grid: previews at their actual target resolution, never upscaled.
small = Image.new('RGB',(520,160),(28,36,52))
sd = ImageDraw.Draw(small)
for i,key in enumerate(['rope','braided','golden','elite']):
    im = Image.open(OUT/f'{key}-64.png')
    small.paste(im,(28+i*128,25),im)
    sd.text((24+i*128,105),key.title(),font=font(16),fill=(243,238,225))
small.save(OUT/'thumbnail-check.png')
print('Review sheet and 64px thumbnails saved.')
