"""Make QA contact sheets from the actual Blender renders, without editing them."""
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw
from walkin_catalogue import SPECS, folder

BASE = Path(__file__).resolve().parents[1]
OUT = BASE / 'walk-in-review'
OUT.mkdir(exist_ok=True)
for view in ('exterior', 'interior', 'entry'):
    sheet = Image.new('RGB', (960, 2160), '#f6efdf')
    draw = ImageDraw.Draw(sheet)
    for i, (slug, (revision, _, _)) in enumerate(SPECS.items()):
        name = folder(slug, revision + 1)
        with Image.open(BASE / name / (view + '.png')) as source:
            preview = ImageOps.contain(source.convert('RGB'), (312, 320))
        x, y = i % 3 * 320 + 4, i // 3 * 360 + 28
        sheet.paste(preview, (x, y))
        draw.text((x, y - 20), name, fill='#302b25')
    sheet.save(OUT / (view + '-contact.png'))
print('Wrote three contact sheets from all 18 house render sets.')
