"""Publish the verified Rainbow Tiger package without replacing Storm Wolf art."""
from pathlib import Path
from html.parser import HTMLParser
import json,hashlib,os,re
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];REPO=ROOT.parents[1]
PACKAGE=ROOT.parents[1]/'assets/skins/animal/legendary/rainbowtiger';OUT=REPO/'assets/skins/animal/legendary'
def relative(path,base):return os.path.relpath(path,base).replace('\\','/')
def publish():
    report=json.loads((PACKAGE/'rainbowtiger-asset-report.json').read_text())
    animation=json.loads((PACKAGE/'animation-checks.json').read_text())
    assert animation['sceneSHA256']==hashlib.sha256((PACKAGE/'rainbowtiger-complete.blend').read_bytes()).hexdigest(),'Render the current model animation before publishing'
    assert not report['addedGeometryVaultBlocked'] and not animation['animatedVaultBlocked']
    assert report['fbxRoundTripBoundsError']<.001 and animation['fbxBoneLoopError']<1e-4
    assert all(m['nonManifoldEdges']==0 and m['triangles']<20000 for m in report['meshes'])
    assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==sha for p,sha in report['inputHashes'].items())
    images=[]
    for f in animation['frames']:
        with Image.open(PACKAGE/'motion'/f'frame-{f:03d}.png') as im:images.append(im.convert('RGB'))
    images[0].save(PACKAGE/'rainbowtiger-idle.gif',save_all=True,append_images=images[1:],duration=round(1000/animation['previewFPS']),loop=0)
    readme=f'''# Rainbow Tiger — option C, swept charcoal

Built from the approved [option C concept](../../../../../assets/skins/animal/legendary/rainbow-tiger-concept/concept-v5-c-swept-charcoal.png), with the latest adjustments:

- Upper cheek strands rebuilt to follow the face downward in curved layers.
- Inner-ear locks share roots at the actual medial corner nearest the forehead,
  then fan upward/outward while resting against the inner-ear surface.
  Ear tuft roots are fuller, with a gradual taper along each strand to a fine tip.
  Four broad overlapping tufts now span each inner ear from the upper tip to
  the lower outer corner, following the reference's full fan of hair.
- The approved isolated beard study is fitted onto both cheeks and the chin.
  Dense overlapping banana-shaped locks retain the reviewed smooth curves and
  fullness, with short upper tufts flowing into long lower locks.
- Fine curved strokes follow the fur through UV color and normal maps.
  The complete beard sides follow the existing Ruff_L/R bones.
- Two extra overlapping locks fill the inner cheek on each side and follow
  the snout rim. Their roots remain on the cheek; their flowing tips may rest
  alongside the snout. Three fuller chin locks root beneath the snout itself.
  Root positions and attachment surfaces are verified in `beard-root-checks.json`.
- Soft small eyebrow arches; fully visible RGB eyes.
- One inner and one outer face stripe per eye, spaced clear of the eyes.
- Clean painted stripe bands with broad centers and sharp tapered ends,
  continuing around the back. Raised stripe shells have been removed.
- Bare pig feet, original body/snout/bank openings, compact rainbow tail plume.

[Model gallery](index.html) · [Actual animation](rainbowtiger-idle.gif) · [Ear close-up](rainbowtiger-ear-detail.png)

## Import files

**`rainbowtiger-complete.fbx` is the main model.** `rainbowtiger-idle.fbx`
contains its matching four-second bone animation. The editable source is
`rainbowtiger-complete.blend`; all review images show this actual model.

Body is 12 studs wide. Preserve uniform scale and align the original body center,
snout and rear vault axis. Visual parts should be non-colliding in the game.
The previous `legendary-v1` and `clean-review-v2` packages remain preserved.
The full model before this beard replacement is saved in `../before-approved-beard/`.

## Textures

The color images are embedded in the FBX and included separately:

- `rainbowtiger-coat.png`: Body, with a dedicated seam-wrapped coat UV layout.
- `rainbowtiger-stripe-emission.png`: Body stripe-only glow mask, supplied separately
  for runtime setup; black pixels leave the coat dark.
- `rainbowtiger-charcoal-fur.png`: EarFur.
- `beard-flow-color.png`: CheekFur_-1, CheekFur_1, CheekFill_-1, CheekFill_1
  and BeardFur. These are the cheek layers, inner fills and under-snout locks.
- `beard-flow-normal.png`: the same beard meshes; assign as SurfaceAppearance
  NormalMap to retain the curved hair strokes. Keep the color map on ColorMap.
- `rainbowtiger-tail-gradient.png`: TailPlume.

Preserve their UVs. If the importer drops a color image, reapply it as the mesh's
color map/SurfaceAppearance and keep the part tint white. The ear texture supplies dark roots and lighter tips. Beard color and normal
maps supply its fine curved strokes; flat color alone would lose that detail.
Body must also retain a white part tint so its coat image supplies the color.
Other parts use RGB colors recorded in `rainbowtiger-asset-report.json`.
Ears retain a second inner material RGB 67,62,77. Do not apply the old painted
Rainbow Tiger textures or add duplicate eyes/fur meshes.

## Animation / Fable handoff

The rig retains Root, Tail, Ruff_L and Ruff_R. Root is stationary; Tail sways
3 degrees and each cheek side, including its inner fill, sways 1.2 degrees
with Ruff_L/R. The under-snout BeardFur stays with Root.
Import and publish the
idle FBX on the model's rig. Source action is frames 1–121 at 30 fps; FBX import
may shift it to 2–122 while preserving the four-second period.

**FBX does not transfer Blender's material animation.** Recreate the gentle
brightness pulse through the Body material using `rainbowtiger-stripe-emission.png`
and the timing in `animation-handoff.json`. Only painted stripes emit; do not
apply a uniform glow to the black body. The Eyes mesh has its own synchronized smooth
four-second RGB cycle. Keep the underlying coat and fur color maps fixed. Tail uses a continuous
color texture and bone movement. No particle aura is intended.

Keep the original coin slot, coin-deposit effects and flush rear vault plate.
Confirm lock-tier seating, daylight glow, held/shop appearances and mobile
performance after Studio integration. No runtime/economy files were changed.

## Verification

{report['meshCount']} meshes / {report['triangles']:,} triangles; largest mesh
{max(m['triangles'] for m in report['meshes']):,} triangles. All meshes are closed
and manifold. FBX reimport preserves count, triangles, weights and bounds within
{report['fbxRoundTripBoundsError']:.9f} studs; fur/tail UVs and textures survive.
The imported idle loop is closed, the root stays still, and animated accessories
clear the rear-plate probe in 40 sampled states. The original master and old
painted Rainbow Tiger source and maps retain their hashes.

**Art built; Studio integration and live checks pending.** The approved concept
is the target; the new physical model is ready for visual review.

## Rebuild

Run `build_rainbowtiger_swept.py` in background Blender; then
`render_rainbowtiger_preview.py -- --swept` in Blender; then
`build_rainbowtiger_swept_gallery.py` in Python. `--draft` changes only render
resolution/samples, not the geometry or exports.
'''
    (PACKAGE/'README.md').write_text(readme,encoding='utf-8')
    css='body{margin:0;background:#f4eddc;color:#342d29;font:16px/1.5 system-ui}main{max-width:1150px;margin:auto;padding:28px}img{width:100%;border-radius:14px}nav{display:flex;gap:18px;flex-wrap:wrap}a{color:#77464c}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}figure{margin:0}h1{font-size:40px}.note{background:#fff9ed;padding:18px;border-radius:12px}@media(max-width:650px){.grid{grid-template-columns:1fr}}'
    views=''.join(f'<figure><img src="rainbowtiger-{key}.png" alt="Rainbow Tiger {label}"><figcaption>{label}</figcaption></figure>' for key,label in [('hero','Black coat and broad clean painted rainbow markings'),('front','Full textured beard, relaxed brows and RGB eyes'),('side','Individually shaped tapered flank stripes'),('crown','No mohawk; original deposit opening retained'),('rear','Original curled tail above the flush vault bore')])
    page=f'<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Rainbow Tiger legendary</title><style>{css}</style><main><a href="{relative(OUT/"index.html",PACKAGE)}">Legendary animals</a><h1>Rainbow Tiger</h1><p class="note">Approved option C build: black piggy, full layered textured beard, softer brows and clean wraparound rainbow stripes. Actual model renders and a four-second idle/pulse preview. Studio integration pending.</p><nav><a href="rainbowtiger-complete.blend">Blender scene</a><a href="rainbowtiger-complete.fbx">Model FBX</a><a href="rainbowtiger-idle.fbx">Idle animation FBX</a><a href="README.md">Import and Fable handoff</a></nav><h2>Actual animation preview</h2><img style="max-width:620px" src="rainbowtiger-idle.gif" alt="Four-second tail sway and rainbow stripe pulse"><h2>Model views</h2><div class="grid">{views}</div></main></html>'
    (PACKAGE/'index.html').write_text(page,encoding='utf-8')
    OUT.mkdir(parents=True,exist_ok=True)
    # Only our marked card is replaced; another artist can update Storm Wolf.
    index=OUT/'index.html'
    if index.exists():
        old=index.read_text(encoding='utf-8');old=re.sub(r'<!-- RAINBOW TIGER START -->.*?<!-- RAINBOW TIGER END -->','',old,flags=re.S)
        old=old.replace('One revised review package. Other legendary designs have not been rebuilt in this pass.','Storm Wolf and Rainbow Tiger review packages. Studio integration remains pending.')
        link=relative(PACKAGE,OUT)
        card=f'<!-- RAINBOW TIGER START --><article style="margin-top:24px"><a href="{link}/index.html"><img src="{link}/rainbowtiger-hero.png" alt="Rainbow Tiger piggy bank"></a><h2>Rainbow Tiger</h2><p>Option C: full layered textured beard, relaxed brows, wraparound rainbow stripes and four-second animation.</p><nav><a href="{link}/index.html">Model and motion review</a><a href="{link}/README.md">Import handoff</a></nav></article><!-- RAINBOW TIGER END -->'
        index.write_text(old.replace('</main>',card+'</main>'),encoding='utf-8')
    manifest=OUT/'manifest.json'
    data=json.loads(manifest.read_text()) if manifest.exists() else {'models':[]}
    data['models']=[m for m in data['models'] if m['skin']!='rainbowtiger']+[{'skin':'rainbowtiger','package':relative(PACKAGE,REPO),'meshCount':report['meshCount'],'triangles':report['triangles'],'status':'Option C built with requested refinements; Studio integration pending'}]
    data['count']=len(data['models']);manifest.write_text(json.dumps(data,indent=2))
    class Links(HTMLParser):
        def handle_starttag(self,tag,attrs):
            for key,value in attrs:
                if key in ('src','href'):assert (PACKAGE/value).exists(),value
    Links().feed(page)
    print('RAINBOW_TIGER_GALLERY_VERIFIED',report['meshCount'],'meshes,',report['triangles'],'triangles; static/animated exports and source preservation passed')
if __name__=='__main__':publish()
