"""Deterministic UV-aligned cartoon base-color atlases; run with normal Python.

Patterns are deliberately broad and unlit. No photographic fibres, noise,
ambient occlusion, or baked highlights. All tiers share the same UV layout.
"""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'textures'
OUT.mkdir(exist_ok=True)
SIZE = 1024
PALETTES = {
    'rope': {'rope':(218,181,126), 'grip':(91,51,30)},
    'braided': {'rope':(171,113,64), 'grip':(65,40,29)},
    'golden': {'rope':(245,186,49), 'grip':(115,52,31)},
    'elite': {'rope':(124,62,217), 'grip':(239,180,48)},
}

def uv_rect(u0,v0,u1,v1):
    return (round(u0*SIZE),round((1-v1)*SIZE),round(u1*SIZE),round((1-v0)*SIZE))

for tier, colors in PALETTES.items():
    im = Image.new('RGB',(SIZE,SIZE),colors['rope'])
    pix = im.load()
    # U tiles along the rope. V traverses the circumference without a seam.
    if tier == 'braided':
        for y in range(round(.38*SIZE),SIZE):
            v = ((1-y/SIZE)-.03)/.57
            for x in range(SIZE):
                u = x/SIZE
                a = (u+v)%1
                b = (u-v)%1
                first = min(a,1-a) < .095
                second = min(b,1-b) < .095
                if first and (not second or math.floor((u+v)*2)%2 == 0):
                    pix[x,y] = (203,146,91)
                elif second:
                    pix[x,y] = (144,87,47)
    # A padded material block for the grip. Front and side islands are separate.
    draw = ImageDraw.Draw(im)
    draw.rectangle(uv_rect(0,.64,1,1),fill=colors['grip'])
    if tier in ('braided','golden','elite'):
        edge = {'braided':(158,100,56),'golden':(245,186,49),'elite':(142,81,19)}[tier]
        for v in (.682,.938):
            draw.rectangle(uv_rect(0,v,1,v+.014),fill=edge)
    if tier == 'elite':
        # An emblem printed on the grip, not a new raised mesh. Its atlas
        # ellipse becomes circular after the grip's tall planar UV mapping.
        cx, cy = .25*SIZE, (1-.81)*SIZE
        rx, ry = .161*SIZE, .060*SIZE
        draw.ellipse((cx-rx*1.14,cy-ry*1.14,cx+rx*1.14,cy+ry*1.14),fill=(132,78,21))
        draw.ellipse((cx-rx*1.035,cy-ry*1.035,cx+rx*1.035,cy+ry*1.035),fill=(255,215,89))
        ring = [(cx+rx*math.cos(i*math.pi/4),cy+ry*math.sin(i*math.pi/4)) for i in range(8)]
        draw.polygon(ring,fill=(51,181,235))
        inside = [(cx+rx*.65*math.cos(i*math.pi/4),cy+ry*.65*math.sin(i*math.pi/4)) for i in range(8)]
        for i in range(8):
            draw.polygon([ring[i],ring[(i+1)%8],inside[(i+1)%8],inside[i]],
                         fill=[(90,206,246),(46,169,224)][i%2])
        draw.polygon(inside,fill=(112,220,251))
    im.save(OUT/f'{tier}.png',optimize=True)
    im.resize((512,512),Image.Resampling.LANCZOS).save(OUT/f'{tier}-512.png',optimize=True)

manifest = {'type':'sRGB base-color atlases', 'size':[SIZE,SIZE], 'alpha':False,
    'tiers':PALETTES, 'uv_layout':{
        'rope':{'u':'unbounded; repeat every 0.60 authoring units','v':[.03,.60]},
        'grip_front':{'u':[.03,.47],'v':[.66,.96]},
        'grip_back_and_edges':{'u':[.53,.97],'v':[.66,.96]}},
    'roblox':{'mesh_color':[255,255,255],'maps':'one ColorMap/TextureID per tier; shared by both coil parts',
              'normal_map':None,'roughness_map':None,'metalness_map':None},
    'elite':'same coil geometry; purple rope and gold grip with blue printed emblem',
    'authoring':'generated from exact UV coordinates, no lighting baked into base colors'}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Painted four 1024px atlases and four 512px versions.')
