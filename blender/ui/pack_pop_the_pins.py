"""Pop the Pins: crop the twelve kit sprites to their display rects and pack
them into three atlases for Roblox.

    python blender/ui/pack_pop_the_pins.py

WHY ATLASES. Every image is an upload under the developer's own account, and
this project has already had an account actioned over generated uploads, so
twelve become three. WHY CROP FIRST. Roblox downscales anything over 1024 on
a side, which would silently invalidate the kit's pixel `displayRectPixels`;
cropping and packing here means the rects in `atlas.json` are measured
against the exact texture that ships.

Writes assets/ui/pop-the-pins-v1/roblox/{housing,parts,buttons}.png and
atlas.json ({sheet: {sprite: [x, y, w, h]}} plus each sheet's size).
"""
import json
from pathlib import Path
from PIL import Image

KIT = Path(__file__).resolve().parents[2] / 'assets/ui/pop-the-pins-v1'
OUT = KIT / 'roblox'
OUT.mkdir(exist_ok=True)
manifest = json.loads((KIT / 'manifest.json').read_text())['assets']
PAD = 4

def crop(name, scale):
    spec = manifest[name]
    x, y, w, h = spec['displayRectPixels']
    im = Image.open(KIT / spec['file']).convert('RGBA').crop((x, y, x + w, y + h))
    return im.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)

# (sheet, [(rows of (sprite, scale))])
SHEETS = {
    'housing': [[('lock-housing', 1024 / 1470)]],
    'parts': [
        [('pin-idle', 0.6), ('pin-active', 0.6), ('pin-set', 0.6), ('spring', 0.24)],
        [('top-cap', 0.235), ('target-notch', 0.395), ('success-check', 0.185)],
    ],
    'buttons': [
        [('button-primary', 0.34), ('button-primary-pressed', 0.34)],
        [('button-secondary', 0.34), ('button-secondary-pressed', 0.34)],
    ],
}

atlas = {}
for sheet, rows in SHEETS.items():
    placed, y, width = {}, 0, 0
    for row in rows:
        x, tallest = 0, 0
        for name, scale in row:
            im = crop(name, scale)
            placed[name] = (im, x, y)
            x += im.width + PAD
            tallest = max(tallest, im.height)
        width = max(width, x - PAD)
        y += tallest + PAD
    height = y - PAD
    assert width <= 1024 and height <= 1024, (sheet, width, height)
    canvas = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    rects = {}
    for name, (im, x, y) in placed.items():
        canvas.paste(im, (x, y))
        rects[name] = [x, y, im.width, im.height]
    canvas.save(OUT / (sheet + '.png'), optimize=True)
    atlas[sheet] = {'size': [width, height], 'sprites': rects}
    print(sheet, width, height, {k: v for k, v in rects.items()})

(OUT / 'atlas.json').write_text(json.dumps(atlas, indent=1))
