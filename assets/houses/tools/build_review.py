"""Build the local review gallery and asset handoffs from measured reports."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug
import json
from html import escape

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'assets/houses'
DESIGNS = [
    ('mushroom', 'Toadstool Cottage', 'Rare · 250K', 'Spotted mushroom cap, round doorway and a compact trophy nook.'),
    ('treehouse', 'The Treehouse', 'Rare · 750K', 'Raised oak cabin, switchback stairs, guarded deck, side bridge and trophy shelves.'),
    ('slime', 'Gloop House', 'Epic · 2.5M', 'Green walls inside and out, thick slime drips, a purple door and a larger display room.'),
]
cards = []
for slug, name, tier, description in DESIGNS:
    folder = OUT / f'{house_slug(slug)}-v1'
    report = json.loads((folder / 'package-report.json').read_text())
    checks = json.loads((folder / 'asset-checks.json').read_text())
    bounds = report.get('objBoundsRoblox', report.get('objBoundsRobloxAxes'))
    width, height, depth = bounds['size']
    meshes, triangles, collisions = report['visualMeshes'], report['triangles'], report['collisionParts']
    parts = meshes + collisions + 1
    samples = checks.get('routeSamples', checks.get('doorwayStandingLaneSamples'))
    assert not checks.get('blockedClearanceSamples', checks.get('blockedSamples'))
    assert not checks.get('unsupportedElevatedSamples')
    assert checks['fbxRoundTripMeshCount'] == meshes
    assert checks.get('fbxRoundTripMaxBoundsError',0) < .001
    if slug != 'mushroom':
        geometry = json.loads((folder / 'geometry-report.json').read_text())
        (folder / 'README.md').write_text(f'''# {name} — Blender prototype

{description}

**Status: offline asset prototype, not imported or integrated into Studio.**
This is actual mesh geometry with walk-in space inside the shell. The interior
render temporarily hides the front wall and roof; gameplay uses the full shell.

## Contents

- `{house_slug(slug)}.blend`: editable source, named meshes, trophy marker empties.
- `{house_slug(slug)}-visual.fbx`: static visual export, without review lights/camera/ground.
- `{house_slug(slug)}-visual.obj` and `.mtl`: alternate export and material colours.
- `{house_slug(slug)}-collision-mounts.rbxmx`: anchored invisible collision guides, Root,
  and nine semantic trophy attachments. Visual MeshParts should not collide.
- Exterior, front and interior PNGs: actual Blender renders.
- Geometry, package and asset-check reports: measured build outputs.

FBX exports follow the repository's existing ignore rule. On another machine,
rebuild from the checked-in Blender scripts/source or use the OBJ export.

## Measured build

- {meshes} visual mesh objects; {triangles:,} triangles total.
- {collisions} collision parts plus Root; **{parts} BaseParts** before trophies
  if each exported mesh becomes one MeshPart. Importer splitting can add parts.
- Complete visual bounds: **{width:.3f} W × {depth:.3f} D × {height:.3f} H**.
  Includes open door, roof, foliage and exterior decorations.
- Front projection: local Roblox Z={bounds['min'][2]:.3f}; rear Z={bounds['max'][2]:.3f}.
- Floor at Y={geometry['floorHeight']}; doorway {geometry['doorWidth']} wide.
- {samples} route centreline samples passed the offline clearance/support check.
  Each sample uses five upward rays and horizontal cross-rays at three body
  heights across a 1.7-unit footprint against visible geometry and collision
  guides; steps below .65 are allowed. This is not a
  swept avatar test and does not prove the entire floor is navigable.
- FBX round trip preserved all {meshes} mesh objects and matched authored
  bounds within .001 design unit.
- Individual meshes have no non-manifold edges and stay below 20,000 triangles.
  Trim intersections and intentional overlaps are not a zero-coplanar audit.

## Import contract for Fable

1. Authoring is Blender X across, Y inward, Z up. Export and companion use
   Roblox **(-x, z, y)**. Front faces -Z; Root is at ground level on the
   structural front-wall plane. Numeric units are intended as studs.
2. Verify Studio's FBX import scale against the bounds above. Keep all imported
   objects in their original relative positions. Align the companion using
   the same origin; do not separately centre files by their bounding boxes.
3. Set visual parts anchored, CanCollide=false, SmoothPlastic. Match material
   names to the sRGB palette in `geometry-report.json` and approved Theme
   colours. No texture uploads or wood/metal materials are required.
4. Place Root using HOUSE_FRONT_LINE. Validate the entire footprint, including
   negative-Z stairs/open door, against live plots and lawn/robbery areas.
5. Keep the collision guides static. Validate walking, jumping, stairs, rail
   corners, camera comfort and pursuit with actual desktop/mobile avatars.
   These boxes are drafts and may need adjustment after those tests.
6. Trophy attachment names are Featured, Shelf_1..4, Wall, Record,
   Plaque_Legacy and Door_Exit. They mark placement; actual awarded displays
   are not baked in. Full Decor models need purpose-sized variants or
   selected display pieces, not blind scaling. Wall/plaque orientation and
   actual trophy clearance must be set during integration.

Animation: {geometry['animation']}
All Legendary house animation specifications remain in
`assets/houses/design/fantasy-v3/ANIMATION-HANDOFF.md`.

## Rebuild

From the repository root:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python assets/houses/tools/build_{'slime' if slug == 'slime' else 'treehouse'}.py
python assets/houses/tools/package_assets.py {slug}
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python assets/houses/tools/verify_assets.py -- {slug}
python assets/houses/tools/build_review.py
```

The source does not modify runtime scripts or upload meshes. Studio scale,
camera, mobile navigation, full collision and performance checks remain pending.
''', encoding='utf-8')
    path = f'{house_slug(slug)}-v1'
    cards.append(f'''<article data-folder="{path}">
<header><p class="tier">{tier}</p><h2>{escape(name)}</h2><p>{escape(description)}</p></header>
<a class="preview" href="{path}/exterior.png"><img src="{path}/exterior.png" alt="{escape(name)} exterior, actual Blender render" width="1200" height="1000"></a>
<div class="views" role="group" aria-label="{escape(name)} render view">
<button aria-pressed="true" data-view="exterior">Exterior</button><button aria-pressed="false" data-view="front">Front</button><button aria-pressed="false" data-view="interior">Interior cutaway</button></div>
<dl><div><dt>Visual meshes</dt><dd>{meshes}</dd></div><div><dt>Triangles</dt><dd>{triangles:,}</dd></div><div><dt>BaseParts incl. guides</dt><dd>{parts}</dd></div><div><dt>Width × depth</dt><dd>{width:.1f} × {depth:.1f}</dd></div></dl>
<p class="checks">Offline clearance: {samples} samples passed · FBX round trip passed</p>
<nav aria-label="{escape(name)} files"><a href="{path}/{house_slug(slug)}.blend">Blender source</a><a href="{path}/{house_slug(slug)}-visual.obj">OBJ export</a><a href="{path}/{house_slug(slug)}-collision-mounts.rbxmx">Collision + mounts</a><a href="{path}/README.md">Import handoff</a></nav>
</article>''')

page = '''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>House models · Physical prototypes</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f3efdf;color:#27362c;font:16px/1.55 system-ui,sans-serif}.wrap{max-width:1440px;margin:auto;padding:42px 28px 64px}h1{font-size:clamp(30px,4vw,52px);line-height:1.05;margin:10px 0 18px;letter-spacing:-1.5px}h2{margin:4px 0 10px;font-size:26px}.eyebrow,.tier{text-transform:uppercase;font-size:12px;letter-spacing:2px;font-weight:800;color:#547349}.intro{max-width:780px}.notice{border-left:4px solid #b57e34;background:#ede4ca;padding:16px 20px;margin:24px 0 32px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px}article{min-width:0;background:#fffcf0;border:1px solid #d4d7c4;border-radius:18px;overflow:hidden}article header{padding:22px 22px 4px;min-height:185px}article header p{margin:0 0 10px}.preview{display:block;background:#ccc}.preview img{display:block;width:100%;height:auto}.views{display:flex;flex-wrap:wrap;gap:6px;padding:16px 16px 0}button{font:inherit;font-size:13px;border:1px solid #c3cbb8;border-radius:20px;padding:8px 12px;background:transparent;color:#354c37;cursor:pointer}button[aria-pressed=true]{background:#304c38;color:#fff;border-color:#304c38}button:focus-visible,a:focus-visible{outline:3px solid #cf8a28;outline-offset:3px}dl{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin:20px}dt{font-size:11px;color:#62725e}dd{margin:2px 0 0;font-weight:750;font-size:20px}.checks{font-size:12px;padding:0 20px;color:#4e6949}nav{display:flex;flex-wrap:wrap;gap:10px 18px;padding:16px 20px 24px}a{color:#365b42}nav a{font-size:13px;font-weight:650}footer{margin-top:34px;max-width:850px;color:#64725e;font-size:14px}@media(max-width:1050px){.grid{grid-template-columns:1fr 1fr}}@media(max-width:650px){.wrap{padding:24px 14px 40px}.grid{grid-template-columns:1fr}article header{min-height:0;padding-bottom:14px}}
</style></head><body><main class="wrap"><p class="eyebrow">Rob a Piggy Bank / House art</p><h1>Walk right into the fantasy.</h1><p class="intro">Three physical prototypes with real interior space, trophy placement markers and separate collision guides. These previews are rendered from the exported Blender models.</p><p class="notice"><strong>Ready for Studio import review.</strong> Offline geometry and sampled routes checked. Live scale, camera, avatar collision, trophy fit and mobile playtests are still pending. These houses are not installed in the game yet.</p><section class="grid">''' + ''.join(cards) + '''</section><footer>Dimensions are design units intended as studs. Counts exclude actual trophy instances and any importer splitting. The Toadstool uses the earlier nine-sample doorway check; the newer houses use a five-ray route check against mesh surfaces and collision guides. Legendary motion is specified separately; this batch contains Rare and Epic houses.</footer></main><script>
document.querySelectorAll('article').forEach(card=>card.querySelectorAll('button[data-view]').forEach(button=>button.addEventListener('click',()=>{const view=button.dataset.view;const image=card.querySelector('img');image.src=card.dataset.folder+'/'+view+'.png';image.alt=card.querySelector('h2').textContent+' '+view+', actual Blender render';card.querySelector('.preview').href=image.src;card.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));})));
</script></body></html>'''
if (OUT / 'treehouse-v2/index.html').exists():
    page=page.replace('<section class="grid">','<p class="notice"><strong>New Treehouse art revision:</strong> <a href="treehouse-v2/index.html">Compare the rebuilt Blender model with its original reference.</a> The cards below preserve the first prototype batch.</p><section class="grid">')
(OUT / 'index.html').write_text(page, encoding='utf-8')
print('Generated model gallery and current Treehouse/Gloop import handoffs.')
