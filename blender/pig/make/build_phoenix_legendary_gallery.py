"""Package the verified Ice Phoenix without replacing other legendary art."""
from pathlib import Path
from html.parser import HTMLParser
import hashlib, json, os, re
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
PACKAGE = ROOT.parents[1]/'assets/skins/animal/legendary/phoenix'
OUT = REPO / 'assets/skins/animal/legendary'
OUT.mkdir(parents=True, exist_ok=True)
def relative(path, base): return os.path.relpath(path, base).replace('\\', '/')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
r = json.loads((PACKAGE / 'phoenix-asset-report.json').read_text())
a = json.loads((PACKAGE / 'animation-checks.json').read_text())
vault = json.loads((PACKAGE / 'vault-fit-checks.json').read_text())
assert vault['sceneSHA256'] == sha(PACKAGE / 'phoenix-complete.blend')
assert len(vault['fit']) == 4 and all(t['maxBareGap']==0 for t in vault['fit'])
assert all(sha(PACKAGE / f)==digest for f,digest in vault['previews'].items())
assert a['sceneSHA256'] == sha(PACKAGE / 'phoenix-complete.blend')
assert not r['addedGeometryVaultBlocked'] and not r['addedGeometryCoinBlocked']
assert not a['animatedVaultBlocked'] and not a['animatedCoinBlocked']
assert r['fbxRoundTripBoundsError'] < .001 and a['fbxBoneLoopError'] < 1e-4
assert a['boneLoopError'] < 1e-5 and len(a['movementMatrixDeltas']) == 9
assert all(m['nonManifoldEdges'] == 0 and m['triangles'] < 20000 for m in r['meshes'])
assert all(sha(Path(p)) == digest for p, digest in r['inputHashes'].items())
assert all(sha(PACKAGE / m['file']) == m['sha256'] for m in r['maps'])
assert r['featherCount'] >= 400
assert r['featherAttachment']['maximumSignedRootGap'] < 0
assert a['pinnedRootMaxMotion'] < 1e-5
assert r['crystalCrown']['legFeathers'] == 120
assert r['crystalCrown']['crownFeathers'] == 7
assert r['crystalCrown']['atlas']['size'] == [2048,2048]
assert 0 < r['crystalCrown']['atlas']['maskCoverage']['Face'] < .08
assert r['crystalCrown']['atlas']['maskCoverage']['Eye'] == 0
images = []
for f in a['frames']:
    with Image.open(PACKAGE / 'motion' / f'frame-{f:03d}.png') as im:
        images.append(im.convert('RGB'))
images[0].save(PACKAGE / 'phoenix-idle.gif', save_all=True, append_images=images[1:], duration=100, loop=0)
with Image.open(PACKAGE / 'phoenix-idle.gif') as gif:
    assert gif.n_frames == 40 and gif.info['duration'] == 100
phases = '{\n' + ''.join(f'    ["{g["part"]}"] = {g["phase"]},\n' for g in r['animation']['glowGroups']) + '}'
template = Path(__file__).with_name('phoenix_frost.template.luau').read_text()
assert template.count('__PHASES__') == 1
(PACKAGE / 'PhoenixFrost.luau').write_text(template.replace('__PHASES__', phases), encoding='utf-8')

readme = f'''# Ice Phoenix — legendary piggy

An ivory piggy with {r['featherCount']} closed, curved feathers in ice blue and indigo,
a seven-feather crown and a seven-feather tail fan. 120 smaller feathers
continue down all four legs, leaving a narrow pale hoof rim. Thin luminous
frost veins run along the feathers; mirrored branching frost markings frame
the face, with a six-ray forehead motif and a narrow upper snout flourish.
Body feathers now follow the skin's curvature, with their roots buried and
pinned to Root while their tips flex. Close-set coverts fill the back and
both sides of the snout. Only the functional coin slot and rear vault plate
clearance are reserved. Stronger cyan-white tips pulse from a material gain
of roughly 1.1 to 5.5; the vein and face masks stay restrained.
Veins and cyan-white feather tips shimmer in staggered groups while the
mantle, cheeks, crown and tail move gently in a four-second loop.
The vein pattern and color gradient are fixed; brightness
changes over time. Original pig body, snout, eyes, feet, ears and curled tail
are retained, with the tail above the flush rear vault opening. The crown
coin slot stays clear. This revision follows the user's selected and refined
Crystal Crown concept in `../../../../../blender/pig/skins/phoenix/concepts-v2/crystal-crown-refined.png`.

## Files

- `phoenix-complete.blend`: editable scene, packed maps, nine-bone rig,
  material animation, review cameras and lighting.
- `phoenix-complete.fbx`: main rigged model in its neutral pose.
- `phoenix-idle.fbx`: matching four-second bone animation; import onto the
  main rig, not as another display model.
- `phoenix_color.png`: opaque 2048 × 2048 atlas for every mesh, with 16 tiles.
- `phoenix_emissive.png`: matching mask for frost veins, tips and face markings.
- `PhoenixFrost.luau`: optional client companion for masked emission.
- `phoenix-idle.gif`: actual 40-frame animation preview at 10 fps.
- Four full model views, a crystal detail view, `index.html`, asset report,
  animation handoff and checks.

## Studio import

Import the main model with its rig intact. Body is 12 studs across; scale the
entire model uniformly if Studio adds an importer multiplier. Blender uses
X across, -Y forward, Z up; FBX declares -Z forward, Y up. Preserve all nine
bones and exact mesh names. Accessories are grouped by their controlling bone.

All exported meshes use the new `PhoenixPalette` UV map and the two supplied
atlases, including the eyes, snout and original body parts. Feather UVs now
vary across their width as well as their length; the face is projected into
its own tile. Reimport the complete model with these new UVs and atlases.
Do not apply the
old Phoenix textures or old pig UV maps. Assign the color atlas and assign
the grayscale mask as SurfaceAppearance EmissiveMaskContent, with white
EmissiveTint. Only after assigning the mask, add boolean attribute
`PhoenixFrostGlow = true` to the prepared SurfaceAppearances. Black areas
of the mask remain non-emissive. Do not use the mask as transparency.

Import the idle FBX through Animation Editor on the main rig, publish under
the experience owner, and play it looping through an Animator. FBX carries
bone motion, not the Blender material animation. Install `PhoenixFrost.luau`
as a ModuleScript and call `local stop = require(module).start(phoenixModel)`
from the client cosmetic controller when starting the idle. The helper uses
the same four-second frost brightness curve and per-mesh phases as Blender.
An optional second argument offsets playback time in seconds. Call `stop()`
on skin changes; model destruction also cleans up and restores material values.
Preserve mesh names for phase lookup and preserve the blended Root/tip weights
so the feather bases remain attached. Tune glow strength in the game's lighting.
The older `assets/phoenix/PhoenixEffects.luau` targets a different rig and
must not be used with this package.

Keep game-owned deposit effects, collision behavior and the rear vault plate.
Use the verified runtime dial seat recorded in `vault-fit-checks.json`:
Blender coordinates (0, 6.471867, -0.280617) studs, with normal
(0, 0.948537, -0.316667), at the package's 12-stud body width. Preserve the
existing 0.9-stud plate thickness and tier radii 1.55, 1.68, 1.82 and 1.95.
The smaller feathers intentionally tuck beneath the plate; keep them in the
model. They follow the body surface and are not a protruding mounting collar.
The bore and plate front remain unobstructed. Do not position the plate using
the body origin alone: its axis originates 1.88 studs above that origin.
Review held/shop views, daylight materials and mobile performance after import.

## Verification and status

{r['meshCount']} meshes / {r['triangles']:,} triangles; largest mesh
{max(m['triangles'] for m in r['meshes']):,} triangles. All meshes are manifold.
Static FBX reimport preserves mesh and triangle counts, weights, UV presence
and bounds (maximum error {r['fbxRoundTripBoundsError']:.9f} studs). Animation
reimport preserves nine bones, actual accessory movement, a stationary Root,
and a closed loop. Added geometry clears the vault plate and coin slot;
moving geometry was checked at 40 animation states. Source/master and atlas
hashes are verified. The previous Phoenix files remain unchanged.

The fitted Iron and Gold previews reconstruct the runtime vault geometry in
Blender. All four tiers passed 128 radial samples with zero bare gap at the
plate edge. The latest clearance checks use the runtime's actual axis origin.

**Art approved with vault fit verified. Studio integration, uploads and in-game material
calibration remain pending.** No runtime, economy or crate catalogue edits.
The logical `phoenix` asset key is retained; the display name is Ice Phoenix.

## Rebuild

Run `blender/pig/make/build_phoenix_legendary.py` in Blender, then
`render_phoenix_legendary.py` in Blender and
`build_phoenix_legendary_gallery.py` in Python with Pillow.
Before the gallery, run `check_phoenix_vault_fit.py` in Blender to regenerate
the fitted previews and seam checks. `phoenix_vault_geometry.py` reads the
runtime dial constants directly to keep construction and clearance aligned.
`phoenix_crystal_atlas.py` authors the feather veins and facial frost markings
procedurally, without editing the approved concept raster. The builder's
`--draft` option lowers still-render quality. Outputs stay in this separate
package; original source scenes are never saved over.
'''
(PACKAGE / 'README.md').write_text(readme, encoding='utf-8')
css = '*{box-sizing:border-box}body{margin:0;background:#122434;color:#e9f3f8;font:16px/1.5 system-ui}main{max-width:1150px;margin:auto;padding:30px 24px}h1{font-size:44px}a{color:#99eaff}nav{display:flex;gap:18px;flex-wrap:wrap}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}figure{margin:0}img{display:block;width:100%;border-radius:14px}figcaption,.small{font-size:13px}.note{padding:18px;border-left:4px solid #a7f3ff;background:#213c51}@media(max-width:650px){.grid{grid-template-columns:1fr}}'
views = ''.join(f'<figure><img src="phoenix-{key}.png" alt="Ice Phoenix: {label}" loading="lazy"><figcaption>{label}</figcaption></figure>' for key, label in [('hero','Layered blue feathers and glowing frost tips'),('front','Ivory face and curved cheek fans'),('crown','Three-feather crest and clear coin slot'),('rear','Tail fan and original curl above the flush vault opening')])
page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Ice Phoenix legendary piggy</title><style>{css}</style></head><body><main><a href="{relative(OUT / 'index.html', PACKAGE)}">← Legendary skins</a><p class="small">ANIMAL LEGENDARY · ICE PHOENIX</p><h1>Ice Phoenix</h1><p class="note">An ivory face, 60 curved blue feathers, and cyan-white tips. A soft frost shimmer follows a gentle feather-and-tail idle.</p><nav><a href="phoenix-complete.blend">Blender scene</a><a href="phoenix-complete.fbx">Model FBX</a><a href="phoenix-idle.fbx">Idle animation FBX</a><a href="PhoenixFrost.luau">Frost helper</a><a href="README.md">Import notes</a></nav><h2>Actual animation</h2><img style="max-width:620px" src="phoenix-idle.gif" alt="Four-second feather movement and staggered frost glow"><p class="small">{r['meshCount']} meshes · {r['triangles']:,} triangles · Studio integration pending</p><h2>Model views</h2><div class="grid">{views}</div></main></body></html>'''
page = page.replace('60 curved blue feathers', f"{r['featherCount']} closely layered blue feathers")
page = page.replace('An ivory face,', 'Feathers seated into the skin, a seven-feather crown, frost face markings,')
page = page.replace('A soft frost shimmer follows a gentle feather-and-tail idle.', 'The coat fills the back and snout sides, with rooted feather movement and a stronger cyan glow at the tips.')
page = page.replace('Three-feather crest and clear coin slot', 'Seven-feather crown and clear coin slot')
page = page.replace('Ivory face and curved cheek fans', 'Branching frost face markings and feathered legs')
page = page.replace('</div></main>', '<figure><img src="phoenix-detail.png" alt="Close-up of crystal feather veins and frost face markings"><figcaption>Crystal feather veins and facial frost detail</figcaption></figure></div></main>')
page = page.replace('<h2>Actual animation</h2>', '<h2>Vault fit — complete</h2><p>The feathers meet the vault edge with no bare gap across all four sizes. Smallest and largest plates shown.</p><div class="grid"><figure><img src="phoenix-vault-iron.png" alt="Iron vault fitted flush into the feather coat"><figcaption>Iron — smallest vault plate</figcaption></figure><figure><img src="phoenix-vault-gold.png" alt="Gold vault fitted flush into the feather coat"><figcaption>Gold — largest vault plate</figcaption></figure></div><h2>Actual animation</h2>')
if (ROOT / 'skins/phoenix/concepts-v2/index.html').exists():
    page = page.replace('<h2>Actual animation</h2>', '<p class="note"><a href="../../../../../blender/pig/skins/phoenix/concepts-v2/index.html#refined">Selected Crystal Crown concept →</a><br>The model below implements the crown, frost-vein glow, facial markings and feathered legs.</p><h2>Actual animation</h2>')
(PACKAGE / 'index.html').write_text(page, encoding='utf-8')
# Only replace this package's marked card; preserve the other artist's cards.
index = OUT / 'index.html'
old = index.read_text(encoding='utf-8') if index.exists() else '<!doctype html><html><body><main><h1>Legendary piggies</h1></main></body></html>'
old = re.sub(r'<!-- ICE PHOENIX START -->.*?<!-- ICE PHOENIX END -->', '', old, flags=re.S)
link = relative(PACKAGE, OUT)
card = f'<!-- ICE PHOENIX START --><article style="margin-top:24px"><a href="{link}/index.html"><img src="{link}/phoenix-hero.png" alt="Ice Phoenix legendary piggy"></a><h2>Ice Phoenix</h2><p>Layered ice-blue feathers, glowing cyan tips and a gentle frost shimmer.</p><nav><a href="{link}/index.html">Model and animation</a><a href="{link}/README.md">Import handoff</a></nav></article><!-- ICE PHOENIX END -->'
assert '</main>' in old
index.write_text(old.replace('</main>', card + '</main>'), encoding='utf-8')
manifest = OUT / 'manifest.json'
data = json.loads(manifest.read_text()) if manifest.exists() else dict(models=[])
data['models'] = [m for m in data['models'] if m['skin'] != 'phoenix'] + [dict(skin='phoenix', displayName='Ice Phoenix', package=relative(PACKAGE, REPO), meshCount=r['meshCount'], triangles=r['triangles'], status='Art approved with vault fit verified; Studio integration pending')]
data['count'] = len(data['models'])
manifest.write_text(json.dumps(data, indent=2))
class Links(HTMLParser):
    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in ('href', 'src'):
                assert (self.folder / value.split('#',1)[0]).exists(), value
for path in (PACKAGE / 'index.html', OUT / 'index.html', ROOT / 'skins/phoenix/concepts-v2/index.html'):
    parser = Links(); parser.folder = path.parent
    parser.feed(path.read_text(encoding='utf-8'))
print('ICE_PHOENIX_GALLERY_VERIFIED', r['meshCount'], 'meshes,', r['triangles'], 'triangles; geometry, animation, maps, sources and links passed')
