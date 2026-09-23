"""Publish the locally verified Storm Wolf layout revision for review."""
from pathlib import Path
import json,hashlib,os
from html.parser import HTMLParser
ROOT=Path(__file__).resolve().parents[1];REPO=ROOT.parents[1]
import sys as _sys;_sys.path.insert(0,str(ROOT));import paths
PACKAGE=Path(paths.animal_package('stormwolf'));OUT=Path(paths.tier_gallery('legendary'))
report_path=PACKAGE/'stormwolf-layout-checks.json';r=json.loads(report_path.read_text())
assert not r['vaultBlocked'] and not r['plateBlocked']
assert all(m['nonManifoldEdges']==0 and m['triangles']<21000 for m in r['meshes'])
assert all(u['maxUVError']<1e-5 for u in r['uv'])
assert r['fbxRoundTripBoundsError']<1e-4
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==digest for p,digest in r['inputHashes'].items())
assert (PACKAGE/'stormwolf-complete.blend').stat().st_mtime>=report_path.stat().st_mtime
animation=json.loads((PACKAGE/'lightning-preview-checks.json').read_text())
assert animation['fps']==30 and animation['longestFlashFrames']<=2 and animation['offFrames']
assert animation['bodyGlow']['maskPacked'] and animation['bodyGlow']['framesVerified']==60
assert (PACKAGE/'stormwolf-lightning.mp4').stat().st_mtime>=(PACKAGE/'stormwolf-complete.blend').stat().st_mtime
assert r['lightning']['mainBolts']==8 and r['lightning']['forks']==8
glow=r['bodyGlow']
assert hashlib.sha256((PACKAGE/'stormwolf_body_emissive.png').read_bytes()).hexdigest()==glow['sha256']
assert .001<glow['coverageAboveTenPercent']<.15
def relative(p,base):return os.path.relpath(p,base).replace('\\','/')
CSS='*{box-sizing:border-box}body{margin:0;background:#17202b;color:#eaf3fa;font:16px/1.5 system-ui,sans-serif}main{max-width:1150px;margin:auto;padding:30px 24px}h1{font-size:clamp(32px,5vw,48px);line-height:1.1}a{color:#92dafa}nav{display:flex;gap:18px;flex-wrap:wrap}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}figure,article{margin:0;padding:14px;border:1px solid #45576c;border-radius:16px;background:#222f3d}img{display:block;width:100%;border-radius:9px}figcaption,.small{font-size:13px}.note{padding:16px;background:#263c4c;border-left:4px solid #8bd7f3}@media(max-width:650px){.grid{grid-template-columns:1fr}main{padding:20px 14px}}'
CSS+='video{display:block;width:100%;max-height:680px;background:#101823;border-radius:12px;margin:20px 0}'
def page(title,body):return f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title><style>{CSS}</style></head><body><main>{body}</main></body></html>'
shots=[('hero','Three-quarter, during a full strike'),('rear','Flush vault opening and low centered tail'),('side','Tail projects outward just above the opening'),('crown','Continuous mane, with the coin location concealed'),('front','Original face and coat'),('vault','View along the vault axis')]
figures=''.join(f'<figure><img src="stormwolf-{key}.png" alt="Storm Wolf: {title}" loading="lazy"><figcaption>{title}</figcaption></figure>' for key,title in shots)
nav='<nav><a href="stormwolf-complete.blend">Complete Blender scene</a><a href="stormwolf-complete.fbx">FBX</a><a href="stormwolf-layout.blend">Native editable model</a><a href="stormwolf_body_emissive.png">Body glow mask</a><a href="StormWolfLightning.luau">Studio playback helper</a><a href="README.md">Import notes</a><a href="stormwolf-layout-checks.json">Checks</a></nav>'
video='<h2>Lightning in motion</h2><p>Chunky, jagged branches flash in short, uneven bursts. The lightning painted on the body glows softly between strikes and brightens in sync with the bolts.</p><video controls autoplay muted loop playsinline poster="stormwolf-lightning-on.png" src="stormwolf-lightning.mp4"></video><p class="small">33–67 ms flashes · staggered double strikes · animated body glow · 30 fps Blender preview</p>'
body=f'<a href="{relative(OUT/"index.html",PACKAGE)}">← Legendary skins</a><p class="small">STORM WOLF · LAYOUT AND LIGHTNING REVISION</p><h1>Storm Wolf</h1><p class="note">A flush opening into the hollow body, with the original tail projecting outward just above it. The mane covers the coin deposit location. Original painted coat and crystal details retained, with chunky branching lightning and synchronized body glow.</p>{nav}{video}<p class="small">{r["meshCount"]} meshes · {r["totalTriangles"]:,} triangles · Studio integration pending</p><div class="grid">{figures}</div>'
(PACKAGE/'index.html').write_text(page('Storm Wolf layout revision',body),encoding='utf-8')
link=relative(PACKAGE,OUT)
body=f'<nav><a href="../common/index.html">Common animals</a><a href="../rare/index.html">Rare skins</a></nav><p class="small">ROB A PIGGY BANK · LEGENDARY SKINS</p><h1>Legendary piggies.</h1><p class="note">Storm Wolf: a flush vault opening, a low centered tail, continuous mane, and chunky branching lightning and glowing body markings that pulse with each strike.</p><article><video controls autoplay muted loop playsinline poster="{link}/stormwolf-lightning-on.png" src="{link}/stormwolf-lightning.mp4"></video><h2>Storm Wolf</h2><nav><a href="{link}/index.html">Animation and six views</a><a href="{link}/stormwolf-complete.blend">Blender</a><a href="{link}/stormwolf-complete.fbx">FBX</a></nav></article><p class="small">One revised review package. Other legendary designs have not been rebuilt in this pass.</p>'
(OUT/'index.html').write_text(page('Legendary piggy skins',body),encoding='utf-8')
(OUT/'manifest.json').write_text(json.dumps(dict(count=1,models=[dict(skin='stormwolf',package=relative(PACKAGE,REPO),meshCount=r['meshCount'],triangles=r['totalTriangles'],status='Layout revision for review; Studio integration pending')]),indent=2))
(PACKAGE/'README.md').write_text(f'''# Storm Wolf — layout revision

The existing Storm Wolf has a hollow chamber and a flush rear vault opening. Its original tail is separated at the root and projects outward just above the opening, with a low 5-degree lift. There is no protruding collar. The mane stays continuous over the coin deposit position, with no visible slot or rim, following the user's review. All six old blue bolt meshes are removed and replaced with eight long, chunky, jagged strikes and eight substantial tapered forks. The largest roots are 0.60 studs across. Painted cyan lightning has a separate emission mask and pulses in sync; the texture pattern stays fixed.

The painted coat and original sources remain unchanged. The retained exterior UV loops were checked against their source values with maximum error {max(u['maxUVError'] for u in r['uv']):.9f}. A tiny original mesh pinhole was closed. The rear opening and the largest reference dial plate both passed clearance sampling. Body and Tail are closed manifold meshes.

## Files

- `stormwolf-complete.blend`: packed coat and glow mask, review stage, and a 60-frame lightning preview with stepped visibility and emission, including animated body glow. Meshes are scaled to studs.
- `stormwolf-complete.fbx`: {r['meshCount']} separate static meshes with embedded coat; {r['totalTriangles']:,} triangles total. Largest mesh is {max(m['triangles'] for m in r['meshes']):,} triangles.
- `stormwolf-layout.blend`: native editable geometry, before review staging and the 6× stud scale.
- `stormwolf_body_color.png`: the original coat, unchanged. Body and Tail share this sheet; interior and closed root faces use flat materials.
- `stormwolf_body_emissive.png`: grayscale 1024px mask selecting cyan markings on the original UVs. `body-glow-checks.json` records its hash and coverage. The dark coat and grey mane stay non-emissive.
- Six review renders, `index.html` and `stormwolf-layout-checks.json`.
- `stormwolf-lightning.mp4`: a 30 fps motion preview showing two cycles. `lightning-preview-checks.json` records timing; flashes last one or two frames (33–67 ms), with staggered double strikes and fully dark gaps.
- `StormWolfLightning.luau`: client-side Studio playback helper, with the same timing as `lightning-animation.json`.

## Integration

This legendary uses its own Body mesh and separated Tail, plus six new lightning groups and the existing glowing eyes. Do not substitute the common pig's body or UVs. The Blender scene retains `VaultMount` and `CoinSlotMount` reference empties; these are not functional game parts and are omitted from the FBX.

Native axes are X across, -Y toward the face, Z up. FBX declares -Z forward and Y up. The complete export is 6× the native scene. Reimport preserved mesh count, triangles, body/tail UV presence and bounds (maximum error {r['fbxRoundTripBoundsError']:.9f}). The vault bore radius is 1.43 studs on the shared rear dial axis. The wolf's body surface differs from the common mesh: fit the runtime vault plate to the flush rim during Studio integration instead of adding a visible neck to bridge the gap. Check the plate at all lock tiers. The coin anchor remains under the mane; no visible slot is intended.

Assign the existing coat to Body and Tail; use the flat material colors for the cavity and sealed tail root. Use the six separate Lightning_p0–p5 groups for glow and flicker, and Bolts_eyes for the eyes. FBX geometry is static; the Blender timeline is retained in the blend file. To reproduce the flicker in Studio, import the six lightning meshes with their exact names, install the supplied helper as a ModuleScript, and call `local stop = require(module).start(stormWolfModel)` from a client cosmetic controller. Call `stop()` when changing skins; destruction also cleans up. The helper drives Neon color and transparency in hard steps, with no fading tween. Tune the game's existing bloom/lighting during Studio review. Do not duplicate the eyes with game-built eyes.

For the painted lightning, assign `stormwolf_body_emissive.png` to the Body and Tail SurfaceAppearances' EmissiveMaskContent in Studio, alongside the original color map. Add the boolean attribute `StormWolfBodyGlow = true` to each prepared SurfaceAppearance. The helper then animates EmissiveStrength from 0.35 between strikes to 5.0 at the strongest strike, with white EmissiveTint. Only mark surfaces after assigning the mask, to keep the whole body from glowing. This changes brightness, not the painted pattern's position. Mask assignment is an editor/import step; the helper changes only runtime strength and tint and restores their previous values on cleanup. Reference: https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance

No runtime, economy, crate catalogue, uploads or publishing changes were made. Studio vault seating, material/glow, animation and mobile review remain pending.

## Rebuild

Run `blender/pig/make/build_stormwolf_layout.py` in background Blender, then `render_stormwolf_lightning.py` in Blender, then `build_legendary_gallery.py` in Python. `--draft` on the model builder creates only the native scene and three quick renders, not a complete package. Lightning geometry, schedules, and the generated Studio helper are authored by `stormwolf_lightning.py` and its Luau template; `stormwolf_body_glow.py` bakes the mask and keys body emission. The builder asserts that the original Storm Wolf source, coat, bolt source and common master retain their hashes.
''',encoding='utf-8')
class Links(HTMLParser):
    def handle_starttag(self,tag,attrs):
        for key,value in attrs:
            if key in ('href','src'):assert (self.folder/value).exists(),value
parser=Links()
for p in (OUT/'index.html',PACKAGE/'index.html'):
    parser.folder=p.parent;parser.feed(p.read_text(encoding='utf-8'))
print('LEGENDARY_GALLERY_VERIFIED',r['meshCount'],'meshes,',r['totalTriangles'],'triangles; source hashes, UVs, clearance and local links passed')

# Preserve additional verified legendary packages when refreshing Storm Wolf.
if (Path(paths.animal_package('rainbowtiger'))/'animation-checks.json').exists():
    from build_rainbowtiger_swept_gallery import publish
    publish()
elif (Path(paths.skin_study('rainbowtiger','legendary-v1'))/'animation-checks.json').exists():
    from build_rainbowtiger_gallery import publish
    publish()
