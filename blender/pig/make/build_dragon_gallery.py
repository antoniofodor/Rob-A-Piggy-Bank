"""Publish verified Dragon art while preserving other legendary review cards."""
from pathlib import Path
from html.parser import HTMLParser
import hashlib,json,os,re,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];REPO=ROOT.parents[1]
import sys as _sys;_sys.path.insert(0,str(ROOT));import paths
PACKAGE=Path(paths.animal_package('dragon'));OUT=Path(paths.tier_gallery('legendary'))
def relative(path,base):return os.path.relpath(path,base).replace('\\','/')
r=json.loads((PACKAGE/'dragon-asset-report.json').read_text());a=json.loads((PACKAGE/'animation-checks.json').read_text())
assert a['sceneSHA256']==hashlib.sha256((PACKAGE/'dragon-complete.blend').read_bytes()).hexdigest()
assert not r['addedGeometryVaultBlocked'] and not r['addedGeometryCoinBlocked'] and not a['animatedVaultBlocked'] and not a['animatedCoinBlocked']
assert r['fbxRoundTripBoundsError']<.001 and a['fbxBoneLoopError']<1e-4
assert all(m['nonManifoldEdges']==0 and m['triangles']<20000 for m in r['meshes'])
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==sha for p,sha in r['inputHashes'].items())
assert all(hashlib.sha256((PACKAGE/m['file']).read_bytes()).hexdigest()==m['sha256'] for m in r['maps'])
assert r['raisedScales']['totalPlates']>350
assert all(.003<m['maskCoverageAboveTenPercent']<.30 for m in r['raisedScales']['seamMasks'])
images=[]
for f in a['frames']:
    with Image.open(PACKAGE/'motion'/f'frame-{f:03d}.png') as im:images.append(im.convert('RGB'))
images[0].save(PACKAGE/'dragon-idle.gif',save_all=True,append_images=images[1:],duration=100,loop=0)
with Image.open(PACKAGE/'dragon-idle.gif') as gif:assert gif.n_frames==40 and gif.info['duration']==100
shutil.copy2(Path(__file__).with_name('dragon_glow.luau'),PACKAGE/'DragonGlow.luau')
readme=f'''# Dragon — raised-scale legendary revision

An ember dragon built on the existing round piggy layout: {r['raisedScales']['totalPlates']}
actual green scale plates, curved ivory horns, compact scalloped wings and a
fin on the original curled tail. The scales have shallow beveled edges and
rise 0.12–0.168 studs above the skin. They cover the body, outer ears, legs and
tail, including the forehead, crown and belly. The old gold belly and horizontal
glow bands are removed. Narrow warm seams follow the new scales across the
coat and brighten together in a breathing cycle. The smooth snout, inner ears,
opening seats and cavity remain non-emissive. Original pig body, ears, feet,
snout silhouette, flush rear vault opening and crown coin slot are retained.
The snout uses one green color, including its recessed nostrils.

The four-second idle lifts the wings by five degrees and sways the tail by
three degrees. Warm seams and wing/tail accents brighten in a slow breathing
cycle; the green plates retain their colors. The base body never moves.

## Files

- `dragon-complete.blend`: editable scene in studs, packed maps, four-bone
  rig, review lighting, bone motion and animated material emission.
- `dragon-complete.fbx`: the main rigged model in its neutral pose.
- `dragon-idle.fbx`: matching four-second bone animation. Import onto the
  main model's rig, not as a second display model.
- `dragon-idle.gif`: actual model animation, 40 frames at 10 fps.
- `dragon_body_color.png` / `dragon_trim_color.png`: opaque 1024px green
  undercoat and warm seam maps. Trim covers Snout, Ears, Legs and Tail.
- `dragon_body_emissive.png` / `dragon_trim_emissive.png`: grayscale masks
  projected from the actual raised scale borders, selecting only their warm
  seams. Do not assign these as transparency maps or use the old banded maps.
- `DragonGlow.luau`: optional client material playback companion.
- `dragon-asset-report.json`, `animation-handoff.json`, `animation-checks.json`:
  exact colors, bones, timing, file hashes, geometry and export checks.
- Four model views, a scale close-up and `index.html` for review.

## Studio import

Import the main FBX with its rig intact. Body is **12 studs across**; normalize
the entire imported model uniformly if Studio adds an importer multiplier.
Blender is X across, -Y forward, Z up; FBX declares -Z forward and Y up.
Preserve Root, Tail, Wing_L and Wing_R bones and weights. Accessories share
meshes by material and bone. Flat colors are recorded per mesh in the report.
Keep all `Dragon_Root_Scale*` and `Dragon_Tail_Scale*` meshes: these are the
real beveled plates. Apply their recorded flat green materials, not the body
texture. Tail scales share the Tail bone so they move with its original mesh.

Apply the body maps to Body and the trim maps to Snout, Ears, Legs and Tail,
using each object's preserved UVs. Use the emissive maps as each prepared
SurfaceAppearance's EmissiveMaskContent, with white EmissiveTint. Add boolean
attribute `DragonGlow = true` to those prepared SurfaceAppearances only.
Black areas of each mask stay non-emissive. The small Eyes use flat dark brown
(RGB 36, 24, 16).

Import the idle FBX into Roblox's Animation Editor on this rig, publish under
the experience owner and play the animation through an Animator, looping.
The Blender material animation does not transfer through FBX. Install
`DragonGlow.luau` as a ModuleScript and call
`local stop = require(module).start(dragonModel)` from the client cosmetic
controller when starting the idle animation. Call `stop()` when changing skins;
model destruction also cleans up. An optional phase offset in seconds lets the
controller match an already-playing idle. The helper pulses prepared masked
SurfaceAppearances from 0.35 to 2.2 and applies a warm Neon pulse to the three
named `Dragon_*_Ember` meshes. Tune bloom/strength in the game's lighting.

Keep game-owned deposit effects, coins, collisions and the rear vault plate.
Seat the plate against the existing flush opening and check every lock tier.
Do not add another collar, duplicate eyes or replace the shared pig master.
Validate held/shop views, daylight glow and mobile performance after import.

## Verification and status

{r['meshCount']} meshes / {r['triangles']:,} triangles; largest mesh
{max(m['triangles'] for m in r['meshes']):,} triangles. All meshes are manifold.
Static FBX preserves mesh count, triangle count, weights and bounds
(maximum error {r['fbxRoundTripBoundsError']:.9f} studs). Animated FBX preserves
four bones, actual wing/tail movement, stationary Root and a closed loop.
The moving accessories clear the coin slot and largest rear dial plate over
40 sampled animation states. Source scene, original maps and shared master
hashes are unchanged. All four delivered maps have verified hashes.

**Raised-scale art revision for review; not installed or uploaded to Roblox.**
No runtime, crate catalogue or economy files changed. Live integration and
in-game material calibration remain pending.

## Rebuild

Run `blender/pig/make/build_dragon_legendary.py` in Blender, followed by
`render_dragon_preview.py` in Blender and `build_dragon_gallery.py` in Python
with Pillow. The model builder's `--draft` flag lowers still-render quality.
It always rebuilds a separate package and never saves into original sources.
`dragon_raised_scales.py` partitions the original surface into closed beveled
plates, then projects their borders to matching seam maps. Temporary baking
ribbons are removed before export. Colors vary per plate without belly bands.
'''
(PACKAGE/'README.md').write_text(readme,encoding='utf-8')
css='*{box-sizing:border-box}body{margin:0;background:#14251e;color:#edf0dd;font:16px/1.5 system-ui}main{max-width:1150px;margin:auto;padding:30px 24px}h1{font-size:44px}a{color:#f2c77e}nav{display:flex;gap:18px;flex-wrap:wrap}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}figure{margin:0}img{display:block;width:100%;border-radius:14px}figcaption,.small{font-size:13px}.note{padding:18px;border-left:4px solid #ffad46;background:#223b2e}@media(max-width:650px){.grid{grid-template-columns:1fr}}'
views=''.join(f'<figure><img src="dragon-{key}.png" alt="Dragon: {label}" loading="lazy"><figcaption>{label}</figcaption></figure>' for key,label in [('hero','Beveled green scales and continuous ember seams'),('front','Glowing scale seams across the forehead and legs'),('crown','Raised scales across the back, with a clear coin slot'),('rear','Original curled tail above the flush vault opening'),('scales','Close-up: real raised plates and shallow bevels, at low glow')])
page=f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dragon legendary piggy</title><style>{css}</style></head><body><main><a href="{relative(OUT/"index.html",PACKAGE)}">← Legendary skins</a><p class="small">ANIMAL LEGENDARY · RAISED-SCALE REVISION</p><h1>Dragon</h1><p class="note">{r["raisedScales"]["totalPlates"]} real beveled scales sit slightly above the skin. Continuous ember seams breathe across the coat, with a gentle wing-and-tail idle.</p><nav><a href="dragon-complete.blend">Blender scene</a><a href="dragon-complete.fbx">Model FBX</a><a href="dragon-idle.fbx">Idle animation FBX</a><a href="DragonGlow.luau">Glow helper</a><a href="README.md">Import notes</a></nav><h2>Actual animation</h2><img style="max-width:620px" src="dragon-idle.gif" alt="Four-second wing lift, tail sway and whole-coat ember pulse"><p class="small">{r["meshCount"]} meshes · {r["triangles"]:,} triangles · Studio integration pending</p><h2>Model views</h2><div class="grid">{views}</div></main></body></html>'
(PACKAGE/'index.html').write_text(page,encoding='utf-8')
# Update only Dragon's marked card and manifest entry; leave other art intact.
index=OUT/'index.html';old=index.read_text(encoding='utf-8') if index.exists() else '<!doctype html><html><body><main><h1>Legendary piggies</h1></main></body></html>'
old=re.sub(r'<!-- DRAGON START -->.*?<!-- DRAGON END -->','',old,flags=re.S)
link=relative(PACKAGE,OUT)
card=f'<!-- DRAGON START --><article style="margin-top:24px"><a href="{link}/index.html"><img src="{link}/dragon-hero.png" alt="Dragon legendary piggy"></a><h2>Dragon</h2><p>Raised scales, scalloped wings and breathing ember seams across the coat.</p><nav><a href="{link}/index.html">Model and animation</a><a href="{link}/README.md">Import handoff</a></nav></article><!-- DRAGON END -->'
old=old.replace('One revised review package. Other legendary designs have not been rebuilt in this pass.','Legendary model packages for review. Studio integration remains pending.')
index.write_text(old.replace('</main>',card+'</main>'),encoding='utf-8')
manifest=OUT/'manifest.json';data=json.loads(manifest.read_text()) if manifest.exists() else dict(models=[])
data['models']=[m for m in data['models'] if m['skin']!='dragon']+[dict(skin='dragon',package=relative(PACKAGE,REPO),meshCount=r['meshCount'],triangles=r['triangles'],status='Raised-scale revision with continuous breathing glow; Studio integration pending')]
data['count']=len(data['models']);manifest.write_text(json.dumps(data,indent=2))
class Links(HTMLParser):
    def handle_starttag(self,tag,attrs):
        for key,value in attrs:
            if key in ('href','src'):assert (self.folder/value).exists(),value
for path in (PACKAGE/'index.html',OUT/'index.html'):
    parser=Links();parser.folder=path.parent;parser.feed(path.read_text(encoding='utf-8'))
print('DRAGON_GALLERY_VERIFIED',r['meshCount'],'meshes,',r['triangles'],'triangles; geometry, animation, maps, sources and links passed')
