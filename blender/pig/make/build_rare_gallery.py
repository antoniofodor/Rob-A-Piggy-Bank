"""Verify and publish the local rare-coat review gallery; no runtime edits."""
from pathlib import Path
import sys,json,hashlib,os
from html import escape
from html.parser import HTMLParser
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import paths
from rare_coats import SPECS
REPO=ROOT.parents[1];OUT=REPO/'assets/skins/animal/rare';OUT.mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def rel(p,base):return os.path.relpath(p,base).replace('\\','/')
CSS='*{box-sizing:border-box}body{margin:0;background:#f5f0f8;color:#32273d;font:16px/1.5 system-ui,sans-serif}main{max-width:1200px;margin:auto;padding:32px 24px}h1{font-size:clamp(32px,5vw,48px);line-height:1.1}h2{margin:10px 0}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}article,figure{margin:0;background:#fffafc;border:1px solid #dbcde2;border-radius:18px;padding:16px}img{display:block;width:100%;border-radius:12px}a{color:#62417e}nav{display:flex;flex-wrap:wrap;gap:15px}.note{background:#e9ddf0;padding:16px;border-left:4px solid #9167ac}.small,figcaption{font-size:13px}@media(max-width:640px){.grid{grid-template-columns:1fr}main{padding:22px 14px}}'
def page(title,body):return f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{escape(title)}</title><style>{CSS}</style></head><body><main>{body}</main></body></html>'
cards=[];models=[];pages=[]
for key,spec in SPECS.items():
    folder=Path(paths.skin_dir(key));package=Path(paths.animal_package(key));report_path=package/f'{key}-asset-report.json'
    r=json.loads(report_path.read_text());art=json.loads((folder/'coat-spec.json').read_text())
    assert r['meshCount']==6 and r['triangles']==20670 and r['fbxRoundTripMaxBoundsError']<.001,key
    assert (package/f'{key}-complete.blend').stat().st_mtime>=report_path.stat().st_mtime,key+' incomplete'
    assert all(sha(p)==digest for p,digest in r['inputHashes'].items()),key+' source drift'
    assert sha(art['parentScene'])==art['parentSceneSha256'],key+' parent drift'
    assert all(p['uvPreservedBeforeTriangulation'] and p['maxSourceVertexError']<1e-6 and p['sourceNonManifoldEdges']==0 for p in r['parts']),key
    assert all(sha(package/t['file'])==t['sha256'] for t in r['textures']+r['emissiveTextures']),key
    name=escape(spec['name']);shots=[('hero','Three-quarter'),('front','Front'),('crown','Crown and ear inspection'),('spine','Back and tail inspection'),('glow','Dim lighting — static glow details')]
    figures=''.join(f'<figure><img src="{key}-{shot}.png" alt="{name}: {caption}" loading="lazy"><figcaption>{caption}</figcaption></figure>' for shot,caption in shots)
    nav=f'<nav><a href="{key}-complete.blend">Blender</a><a href="{key}-complete.fbx">FBX</a><a href="README.md">Import notes</a><a href="{key}-asset-report.json">Checks</a></nav>'
    body=f'<a href="{rel(OUT/"index.html",package)}">← Rare skins</a><p class="small">RARE · FIRST ART PASS</p><h1>{name}</h1><p class="note">{spec["parent"].title()} pattern, reworked in a new palette with small static glow accents. Shared pig shape and UVs retained.</p>{nav}<p class="small">Six meshes · 20,670 triangles · body width 12 studs · Blender previews</p><div class="grid">{figures}</div>'
    (package/'index.html').write_text(page(spec['name'],body),encoding='utf-8');pages.append(package/'index.html')
    (package/'README.md').write_text(f'''# {spec['name']} — rare skin, first art pass

Asset ID proposal: `{key}`. Based on the approved `{spec['parent']}` procedural coat.
Palette: {', '.join(f"{k} #{''.join(f'{c:02X}' for c in v)}" for k,v in spec.items() if isinstance(v,tuple))}.

## Files

- `{key}-complete.blend`: assembled pig with packed colour and emissive masks, review lighting and camera.
- `{key}-complete.fbx`: six separated static meshes with embedded colour textures. Assign the supplied emissive masks explicitly in Studio; do not assume the FBX importer recreates Blender's emission graph.
- `{key}_body_color.png`, `{key}_trim_color.png`: opaque 1024×1024 colour sheets.
- `{key}_body_emissive.png`, `{key}_trim_emissive.png`: 1024×1024 grayscale glow masks; white marks the sparse highlights.
- Five review renders, including dim lighting, and `{key}-asset-report.json`.
- `blender/pig/skins/{key}/coat-spec.json`: palette, parent scene hash and preview glow strength.

## Import

Use Body's colour/mask pair on Body. Snout, Ears, Legs and Tail share the trim pair and UV atlas. Eyes are an optional separate mesh; omit them when the game creates its own eyes. Keep the existing coin-slot/vault frame and game-built functional parts.

The body is 12 studs wide. Full envelope is 12 × 17.076 × 13.974 studs; origin is the body centre. Blender faces -Y with Z up; FBX declares -Z forward with Y up. Total 20,670 triangles, largest mesh 7,152. FBX reimport kept mesh count, UV presence, triangles and bounds (error {r['fbxRoundTripMaxBoundsError']:.9f}).

Assign emissive masks in Studio using SurfaceAppearance.EmissiveMaskContent. Start with white EmissiveTint and tune EmissiveStrength in the actual game lighting; Blender's {art['emissiveStrength']} strength is a preview value, not a cross-renderer guarantee. Set strength to zero for a painted-only version. This is a static detail, with no pulsing, animated colour or added geometry.

Roblox's current [emissive-mask documentation](https://create.roblox.com/docs/art/modeling/surface-appearance) supersedes the older repository note that SurfaceAppearance lacks an emissive channel. Mask assignment is an editor/import step.

Prefer the shared game meshes over uploading another duplicate pig. The crate catalogue, rarity weights and economy were not modified. These seven art proposals are not a decision to put all seven into the live crate. No uploads or Studio installation were performed; Studio material, scale and mobile review remain pending.

## Rebuild

In Blender, run `blender/pig/make/build_rare_coat.py -- --skin {key}`, then `make/bake_skin.py -- --skin {key}`, then `make/package_animal.py -- --skin {key} --name "{spec['name']}"`. The durable palette definitions are in `blender/pig/rare_coats.py`; the builder reuses the parent graph without saving the parent. Run `build_rare_gallery.py` after rebuilding packages.
''',encoding='utf-8')
    link=rel(package,OUT)
    cards.append(f'<article><a href="{link}/index.html"><img src="{link}/{key}-hero.png" alt="{name}" loading="lazy"></a><h2>{name}</h2><nav><a href="{link}/index.html">Inspect five views</a><a href="{link}/{key}-complete.blend">Blender</a><a href="{link}/{key}-complete.fbx">FBX</a></nav></article>')
    models.append(dict(skin=key,name=spec['name'],rarity='rare',parent=spec['parent'],package=rel(package,REPO),triangles=r['triangles'],emissiveTextures=r['emissiveTextures'],status='First art pass; Studio integration pending'))
body='<a href="../common/index.html">← Common animal skins</a><p class="small">ROB A PIGGY BANK · RARE SKINS</p><h1>Seven rare piggies.</h1><p class="note">Sweets, fruit and ice palettes with small static glow details. Complete Blender/FBX assets for review; the live crate is unchanged.</p><div class="grid">'+''.join(cards)+'</div><p>Each package includes opaque colour sheets, separate emissive masks and five inspection views. These are Blender previews; Studio lighting and mobile checks remain pending.</p>'
if (OUT.parent/'legendary/index.html').exists():body='<p><a href="../legendary/index.html">Legendary skins: Storm Wolf revision</a></p>'+body
(OUT/'index.html').write_text(page('Rare piggy skins',body),encoding='utf-8');pages.append(OUT/'index.html')
(OUT/'manifest.json').write_text(json.dumps(dict(count=len(models),models=models),indent=2),encoding='utf-8')
(OUT/'README.md').write_text('''# Rare animal skins — first art pass

[Review all seven](index.html): Strawberry Cow, Cookies & Cream, Watermelon, Peppermint, Glacier, Bubblegum Leopard, Honeycomb.

Each package contains a six-mesh Blender scene, FBX, two opaque 1024px colour sheets, two separate emissive masks, five renders and an import handoff. All use the existing pig geometry/UVs; total 20,670 triangles, with a 12-stud-wide body. The common skins and shared master remain untouched.

The new coats follow the sweets/fruit/weather list in docs/animal-crate-plan.md. The newer MASTER-PLAN.md Art 10 brief adds a small glow detail to rare skins, implemented here as sparse static highlights with separate masks. No animated colour, fur or extra geometry is added. Turn emission strength off for a painted-only presentation.

Roblox now supports emissive masks on SurfaceAppearance, contrary to the older repository notes. See [official PBR documentation](https://create.roblox.com/docs/art/modeling/surface-appearance). Set up masks in the editor/import pipeline; tune strength in Studio, since the Blender preview is not a brightness guarantee.

The seven designs are review assets, not a change to the crate pool. The older proposed ladder only called for four rares; final selection, runtime IDs, uploads, Studio material/scale checks and mobile review remain pending. No rarity weights, economy or ownership data were changed.

Durable sources: blender/pig/rare_coats.py and blender/pig/make/build_rare_coat.py. Each skin folder also has a make_<id>_blend.py entry point. Regenerate colour maps with bake_skin.py, packages with package_animal.py --skin <id> --name <name>, and this gallery with build_rare_gallery.py.
''',encoding='utf-8')
class Links(HTMLParser):
    def handle_starttag(self,tag,attrs):
        for k,v in attrs:
            if k in ('href','src') and not v.startswith('https:'):assert (self.folder/v).exists(),v
parser=Links()
for p in pages:parser.folder=p.parent;parser.feed(p.read_text(encoding='utf-8'))
print('RARE_GALLERY_VERIFIED',len(models),'complete packages; sources, exports and local links checked')
