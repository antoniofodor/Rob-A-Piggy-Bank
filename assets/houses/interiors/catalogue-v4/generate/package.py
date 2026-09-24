"""Validate, build Studio previews, make a review gallery and bundle all 18 interiors."""
import html
import json
import math
import re
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET
import zipfile
from PIL import Image, ImageDraw, ImageFont
from tier_sizes import tier_order, dimensions

ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[3]
rows=json.loads((ROOT/'manifest.json').read_text())
mapping=json.loads((REPO/'default.project.json').read_text())['tree']['ServerStorage']
assert [r['id'] for r in rows]==tier_order()
checks=[]
total=0
for row in rows:
    slug=row['slug']; folder=ROOT/slug
    assert all(row[k]==v for k,v in dimensions(row['id']).items())
    assert (REPO/mapping[row['kit']]['$path']).resolve()==(folder/(slug+'-interior-kit.rbxmx')).resolve()
    spec=json.loads((folder/'geometry.json').read_text())
    test=json.loads((folder/'studio-checks.json').read_text(encoding='utf-8-sig'))
    assert test['passed'],slug
    total+=test['count']
    room=spec['templates']['RoomShell']; pedestal=spec['templates']['Pedestal']
    slots=[v for k,v in room['mounts'].items() if k.startswith('Slot_')]
    assert len(slots)==6
    assert row['length']==40
    assert sorted(round(-v['position'][2],5) for v in slots)==[8,8,20,20,32,32]
    assert room['mounts']['Exit']['position']==[0,0,-row['length']]
    assert pedestal['mounts']['Piggy']['position']==[0,1.69,0]
    assert all(abs(abs(v['position'][0])-(row['width']/2-12))<.001 for v in slots)
    for template in spec['templates'].values():
        for part in template['parts']:
            assert all(math.isfinite(v) and v>0 for v in part['size'])
            r=part['rotation']
            for i in range(3):
                for j in range(3):
                    assert abs(sum(r[k*3+i]*r[k*3+j] for k in range(3))-(i==j))<1e-5
    for f in folder.glob('*.rbxmx'): ET.parse(f)
    subprocess.run(['rojo','build',str(folder/'preview.project.json'),'-o',str(folder/(slug+'-interior-preview.rbxlx'))],check=True)
    ET.parse(folder/(slug+'-interior-preview.rbxlx'))
    for f in [folder/'preview/hall.png',folder/(slug+'-interior.blend')]+[folder/'exports'/(t+'.fbx') for t in spec['templates']]:
        assert f.stat().st_size>1000,f
    description=f'''# {row['title']} interior — tier {row['tier']}

{row['description']}

Room dimensions: **{row['width']} wide × {row['length']} long × {row['height']} high**, in studs. Six separate pedestal slots. The pedestal, cash plate and interaction mounts retain their usable size. Rooms connect through `Root.Entry` and `Root.Exit`; the Builder supports adding rooms and removing individual pedestals.

Open `{slug}-interior-preview.rbxlx` in Studio for a two-room walkthrough. The static review's first gate is open and terminal gate is closed. Reference block avatars disappear locally when Play starts. The default follow camera has an 11-stud zoom cap.

`{slug}-interior-kit.rbxmx` supplies `{row['kit']}` for ServerStorage. Its four templates are `RoomShell`, `Pedestal`, `RebirthGate` and `AchievementVestibule`. Collection buttons are separate `Collect.CollectionPlate` and `Collect.CollectionInset` parts, and may be replaced with your own. `Root.Collect` marks the interaction position. `Root.Piggy` marks the display top. The entrance alcove is reserved for future achievements.

`{slug}-interior.blend` contains the assembled review and reusable template scenes. `exports/` contains four FBX modules; static material groups are merged there, so use the native kit for individual part edits. `preview/hall.png` renders the delivered geometry; lighting differs from the game.

**{test['count']} Studio geometry checks passed.** The catalogue also verifies these kits through the game's ThemedInterior wrapper. See [catalogue instructions](../README.md) for build commands, integration and the tier-size rule.
'''
    (folder/'README.md').write_text(description,encoding='utf-8')
    checks.append(dict(theme=slug,passed=True,count=test['count']))

integration=json.loads((ROOT/'integration-checks.json').read_text(encoding='utf-8-sig'))
assert len(integration)==6 and all(t['passed'] for t in integration)
total+=sum(t['count'] for t in integration)
(ROOT/'package-checks.json').write_text(json.dumps(dict(passed=True,themes=checks,engineChecks=total),indent=2))

# A contact sheet is a document layout of actual renders, not concept art.
columns=3; cardw,cardh=576,410
sheet=Image.new('RGB',(columns*cardw,math.ceil(len(rows)/columns)*cardh),(242,239,230))
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',22)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',17)
for i,row in enumerate(rows):
    x,y=(i%columns)*cardw,(i//columns)*cardh
    preview=Image.open(ROOT/row['slug']/'preview/hall.png').convert('RGB')
    preview.thumbnail((cardw-16,350),Image.Resampling.LANCZOS)
    sheet.paste(preview,(x+8,y+8))
    draw.text((x+12,y+363),f"{row['tier']:02}  {row['title']}",font=font,fill=(40,44,51))
    draw.text((x+12,y+389),f"{row['width']} wide · {row['length']} long · {row['height']} high",font=small,fill=(85,90,96))
sheet.save(ROOT/'catalogue-contact-sheet.jpg',quality=93)
# Compact six-theme pages are refreshed with the same renders and dimensions.
for start in range(0,len(rows),6):
    page=Image.new('RGB',(1536,740),(242,239,230))
    labels=ImageDraw.Draw(page)
    for index,row in enumerate(rows[start:start+6]):
        x,y=(index%3)*512,(index//3)*370
        preview=Image.open(ROOT/row['slug']/'preview/hall.png').convert('RGB')
        preview.thumbnail((500,313),Image.Resampling.LANCZOS)
        page.paste(preview,(x+6,y+6))
        labels.text((x+10,y+323),f"{row['tier']:02}  {row['title']}",font=font,fill=(40,44,51))
        labels.text((x+10,y+348),f"{row['width']} wide · {row['length']} long · {row['height']} high",font=small,fill=(85,90,96))
    page.save(ROOT/f'review-tiers-{start+1}-{min(start+6,len(rows))}.jpg',quality=93)
cards=[]
for row in rows:
    slug=row['slug']; title=html.escape(row['title'])
    cards.append(f'''<article><a href="{slug}/preview/hall.png"><img src="{slug}/preview/hall.png" alt="{title} interior"></a><h2>{row['tier']:02} · {title}</h2><p>{row['width']} wide × {row['length']} long × {row['height']} high</p><p>{html.escape(row['description'])}</p><nav><a href="{slug}/{slug}-interior-preview.rbxlx">Studio preview</a><a href="{slug}/{slug}-interior-kit.rbxmx">Editable kit</a><a href="{slug}/README.md">Instructions</a></nav></article>''')
    row.pop('palette',None)
(ROOT/'gallery.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>House interiors</title><style>body{margin:0;background:#efeee7;color:#26323e;font:16px system-ui}header,main{max-width:1500px;margin:auto;padding:28px}h1{font-size:38px;margin:0}header p{max-width:800px;line-height:1.6}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:22px}article{background:#fff;border-radius:14px;overflow:hidden;padding-bottom:20px}img{width:100%;display:block}h2,p,nav{margin:15px 20px}h2{font-size:21px}p{line-height:1.5}nav{display:flex;gap:16px;flex-wrap:wrap}a{color:#276578}</style><header><h1>A bigger home at every tier</h1><p>All 18 permanent interiors. Each tier adds 2 studs of width and 1 of ceiling height. Every room stays 40 studs long, with pedestal rows at 8, 20 and 32 studs. Six separate display stations per room, with clear paths around them. These are renders of the editable game models.</p></header><main class="grid">'''+''.join(cards)+'</main></html>',encoding='utf-8')
dest=ROOT/'complete-house-interiors-v4.zip'
with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for path in sorted(ROOT.rglob('*')):
        if not path.is_file() or path.suffix in ('.zip','.pyc','.log') or '__pycache__' in path.parts or re.search(r'\.blend\d+$',path.name): continue
        archive.write(path,path.relative_to(ROOT))
with zipfile.ZipFile(dest) as archive:
    assert archive.testzip() is None
    print(json.dumps(dict(files=len(archive.namelist()),bytes=dest.stat().st_size,engineChecks=total)))
