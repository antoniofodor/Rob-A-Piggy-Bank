"""Publish the verified Rainbow Tiger package without replacing Storm Wolf art."""
from pathlib import Path
from html.parser import HTMLParser
import json,hashlib,os,re
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];REPO=ROOT.parents[1]
import sys as _sys;_sys.path.insert(0,str(ROOT));import paths
PACKAGE=Path(paths.skin_study('rainbowtiger','legendary-v1'));OUT=Path(paths.tier_gallery('legendary'))
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
    images[0].save(PACKAGE/'rainbowtiger-idle.gif',save_all=True,append_images=images[1:],duration=100,loop=0)
    readme=f'''# Rainbow Tiger — legendary model revision 1

Built from concept v2 with the latest requested **black/charcoal coat**, determined
brows, and a **swept silver tiger cheek-and-neck ruff instead of a mohawk**.
The original round pig body, large snout, eyes, short feet, coin opening and rear
vault bore remain. Seven mirrored rainbow markings use individually authored
outlines projected onto the body and continuing around the rear, with shallow
raised geometry. The foot cuffs use sculpted dark outer fur overlapping a short
silver under-fringe, matching the reference silhouette. Curved fur locks
also fill the ears, all four foot cuffs and original curled tail. Paired tapered
forehead markings sit between the eyes. The tail plume has a continuous silver-to-
rainbow UV gradient on the fur, with no separate colored tip solids.
Both eyes glow and smoothly cycle through RGB colors. This is a new art revision
for review, not a claim that the user has approved the latest model.

[Review gallery](index.html) · [Actual idle preview](rainbowtiger-idle.gif)

## Files

- `rainbowtiger-complete.blend`: editable full scene in stud units, rig, lights,
  four-second tail/ruff motion, stripe pulse and synchronized RGB eye glow.
  Press Play to preview.
- **`rainbowtiger-complete.fbx`**: import this as the main model, keeping its rig.
- `rainbowtiger-idle.fbx`: matching bone animation for Roblox's Animation Editor;
  this is not a second display model.
- `rainbowtiger-idle.gif`: actual Blender animation, 40 frames over four seconds.
- `rainbowtiger-asset-report.json`: per-part colors, bones, triangle counts and
  original-source hashes. `animation-handoff.json`: exact pulse groups and timing.
- `animation-checks.json`: animation FBX and moving rear-clearance checks.

## Import / Fable handoff

The source package is already at **12 studs across Body**, using +Z up and -Y
forward in Blender. FBX declares Y up and -Z forward. Normalize the entire
import uniformly if Studio applies an importer multiplier; never scale individual
parts. Align the body center, snout and rear vault axis with the existing bank.
Visual parts are non-colliding; the game continues to own interaction/collision.

Preserve `Root`, `Tail`, `Ruff_L` and `Ruff_R` bones and their weights. Import the
idle FBX into the Animation Editor on the imported rig, then publish its animation
under the experience owner and play it through an Animator. The root stays still;
tail sway is 3 degrees and ruff motion is 1.2 degrees. The loop lasts four seconds.

The color pulse is **Blender material animation**, so it does not become a Roblox
animation through FBX. Recreate the slow pulse only on the seven `PrismStripe_*`
groups and `FaceStripe_*` / `RearStripe_*` accents listed in `alsoParts`, using
`animation-handoff.json`; leave
the black body, snout and silver ruff colors fixed. The intended pulse is brightness/glow
moving across existing hues, not rapid hue cycling or flashing. No particle aura.

The `Eyes` mesh has a separate synchronized four-second RGB loop specified under
`eyes` in the same handoff. Keep both eyes at steady glow brightness while their
color changes smoothly. Restore the glow in Studio; FBX does not carry material
color/emission keyframes. Do not apply the eye color animation to the pig's body.

The `TailPlume` mesh uses **`rainbowtiger-tail-gradient.png`**, embedded in both
FBX files and also included separately. Preserve its UVs and apply the image as
its color map/SurfaceAppearance if the importer does not carry it over. Keep this
mesh's tint white so the silver-to-rainbow transition stays intact. It uses one
continuous textured fur surface; do not replace it with colored tip parts.

Flat material colors for the other parts are recorded per mesh. If Studio does not preserve FBX
materials, reapply those RGB colors with SmoothPlastic. Ears also have a second
`RainbowTiger_EarInner` material colored RGB 67,62,77. Do not attach the old
Rainbow Tiger color maps: this model uses its new flat palette and actual stripe
geometry. Do not add duplicate game-built eyes or another fur mesh.

Keep the game's coin pile, deposit effects and rear vault plate. The opening is
flush; no protruding collar is added. The crown intentionally has no mane so its
original coin slot remains accessible. Confirm plate seating at every lock tier,
daylight glow, shop-card/held-pig appearance and mobile cost in Studio.

## Verified / pending

{report['meshCount']} meshes, {report['triangles']:,} triangles, largest mesh
{max(m['triangles'] for m in report['meshes']):,}. All meshes are manifold; static FBX
round-trip bounds error is {report['fbxRoundTripBoundsError']:.9f} studs. The idle
FBX retains four bones, weights, a closed four-second loop and a stationary root.
Animated accessories clear the rear plate probe throughout 40 sampled states.
Original master, old Rainbow Tiger scene and old textures retain their hashes.

**Not uploaded or installed in Studio.** No crate/economy/runtime files changed.
This is the art and animation handoff for integration, with live checks pending.

## Rebuild

Run `blender/pig/make/build_rainbowtiger_legendary.py` in background Blender,
then `render_rainbowtiger_preview.py` in Blender, then `build_rainbowtiger_gallery.py`
in regular Python. `--draft` on the builder uses lower-resolution review renders.
'''
    (PACKAGE/'README.md').write_text(readme,encoding='utf-8')
    css='body{margin:0;background:#f4eddc;color:#342d29;font:16px/1.5 system-ui}main{max-width:1150px;margin:auto;padding:28px}img{width:100%;border-radius:14px}nav{display:flex;gap:18px;flex-wrap:wrap}a{color:#77464c}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}figure{margin:0}h1{font-size:40px}.note{background:#fff9ed;padding:18px;border-radius:12px}@media(max-width:650px){.grid{grid-template-columns:1fr}}'
    views=''.join(f'<figure><img src="rainbowtiger-{key}.png" alt="Rainbow Tiger {label}"><figcaption>{label}</figcaption></figure>' for key,label in [('hero','Black coat and broad raised rainbow markings'),('front','Swept silver tiger ruff, determined brows and RGB eyes'),('side','Individually shaped tapered flank stripes'),('crown','No mohawk; original deposit opening retained'),('rear','Original curled tail above the flush vault bore')])
    page=f'<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Rainbow Tiger legendary</title><style>{css}</style><main><a href="{relative(OUT/"index.html",PACKAGE)}">Legendary animals</a><h1>Rainbow Tiger</h1><p class="note">Original piggy shape, black coat, silver tiger ruff and raised rainbow stripes. Actual model renders and a four-second idle/pulse preview. Studio integration pending.</p><nav><a href="rainbowtiger-complete.blend">Blender scene</a><a href="rainbowtiger-complete.fbx">Model FBX</a><a href="rainbowtiger-idle.fbx">Idle animation FBX</a><a href="README.md">Import and Fable handoff</a></nav><h2>Actual animation preview</h2><img style="max-width:620px" src="rainbowtiger-idle.gif" alt="Four-second tail sway and rainbow stripe pulse"><h2>Model views</h2><div class="grid">{views}</div></main></html>'
    (PACKAGE/'index.html').write_text(page,encoding='utf-8')
    OUT.mkdir(parents=True,exist_ok=True)
    # Only our marked card is replaced; another artist can update Storm Wolf.
    index=OUT/'index.html'
    if index.exists():
        old=index.read_text(encoding='utf-8');old=re.sub(r'<!-- RAINBOW TIGER START -->.*?<!-- RAINBOW TIGER END -->','',old,flags=re.S)
        old=old.replace('One revised review package. Other legendary designs have not been rebuilt in this pass.','Storm Wolf and Rainbow Tiger review packages. Studio integration remains pending.')
        link=relative(PACKAGE,OUT)
        card=f'<!-- RAINBOW TIGER START --><article style="margin-top:24px"><a href="{link}/index.html"><img src="{link}/rainbowtiger-hero.png" alt="Rainbow Tiger piggy bank"></a><h2>Rainbow Tiger</h2><p>Black coat, swept silver tiger ruff, raised prism stripes and four-second animation.</p><nav><a href="{link}/index.html">Model and motion review</a><a href="{link}/README.md">Import handoff</a></nav></article><!-- RAINBOW TIGER END -->'
        index.write_text(old.replace('</main>',card+'</main>'),encoding='utf-8')
    manifest=OUT/'manifest.json'
    data=json.loads(manifest.read_text()) if manifest.exists() else {'models':[]}
    data['models']=[m for m in data['models'] if m['skin']!='rainbowtiger']+[{'skin':'rainbowtiger','package':relative(PACKAGE,REPO),'meshCount':report['meshCount'],'triangles':report['triangles'],'status':'Black tiger art revision for review; Studio integration pending'}]
    data['count']=len(data['models']);manifest.write_text(json.dumps(data,indent=2))
    class Links(HTMLParser):
        def handle_starttag(self,tag,attrs):
            for key,value in attrs:
                if key in ('src','href'):assert (PACKAGE/value).exists(),value
    Links().feed(page)
    print('RAINBOW_TIGER_GALLERY_VERIFIED',report['meshCount'],'meshes,',report['triangles'],'triangles; static/animated exports and source preservation passed')
if __name__=='__main__':publish()
