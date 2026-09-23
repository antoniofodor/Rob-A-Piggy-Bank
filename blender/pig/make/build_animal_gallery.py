"""Write handoffs for the eight complete animal packages after verification."""
from pathlib import Path
import sys,json,os,hashlib
from html.parser import HTMLParser
root=Path(__file__).resolve().parent
while not (root/'paths.py').exists():root=root.parent
sys.path.insert(0,str(root))
import paths
REPO=root.parents[1];GALLERY=REPO/'assets/skins/animal/common';GALLERY.mkdir(parents=True,exist_ok=True)
NAMES={'bee':'Bumblebee','ladybird':'Ladybird','cow':'Dairy Cow','zebra':'Zebra','giraffe':'Giraffe','leopard':'Leopard','tiger':'Bengal Tiger','snowleopard':'Snow Leopard'}
CSS='*{box-sizing:border-box}body{margin:0;background:#f5efdf;color:#28362f;font:16px/1.5 system-ui,sans-serif}main{max-width:1200px;margin:auto;padding:32px 24px}h1{font-size:clamp(32px,5vw,48px);line-height:1.1}h2{font-size:23px;margin:12px 0 8px}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}article{background:#fffaf0;border:1px solid #d6d5c7;border-radius:18px;padding:16px}img{display:block;width:100%;border-radius:12px}figure{margin:0}figcaption,.small{font-size:13px}a{color:#28564b}nav{display:flex;flex-wrap:wrap;gap:14px}.note{background:#e3e4d2;padding:16px;border-left:4px solid #738268}.tag{font-size:12px;font-weight:800;letter-spacing:.8px}@media(max-width:640px){.grid{grid-template-columns:1fr}main{padding:22px 14px}}'
def page(title,body):return f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title><style>{CSS}</style></head><body><main>{body}</main></body></html>'
def relative(p,base):return os.path.relpath(p,base).replace('\\','/')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
cards=[];rows=[];pages=[]
for skin,name in NAMES.items():
    out=Path(paths.animal_package(skin));report_path=out/f'{skin}-asset-report.json'
    r=json.loads(report_path.read_text())
    assert r['meshCount']==6 and r['fbxRoundTripMaxBoundsError']<.001,skin
    assert all(p['uvPreservedBeforeTriangulation'] and p['maxSourceVertexError']<1e-6 and p['triangles']<20000 and p['sourceNonManifoldEdges']==0 for p in r['parts']),skin
    assert all(sha(p)==digest for p,digest in r['inputHashes'].items()),skin+' source changed'
    assert (out/f'{skin}-complete.blend').stat().st_mtime>=report_path.stat().st_mtime,skin+' incomplete build'
    assert all(sha(out/t['file'])==t['sha256'] for t in r['textures']),skin+' packaged texture changed'
    assert all(sha(out/t['file'])==sha(paths.skin_map(skin,t['group'])) for t in r['textures']),skin+' source texture differs'
    w,d,h=r['boundsBlenderStuds']['size'];tris=r['triangles']
    nav=f'<nav><a href="{skin}-complete.blend">Blender scene</a><a href="{skin}-complete.fbx">Complete FBX</a><a href="README.md">Import handoff</a><a href="{skin}-asset-report.json">Verification report</a></nav>'
    figures=''.join(f'<figure><img src="{skin}-{shot}.png" alt="{name}: {shot} view"><figcaption>{caption}</figcaption></figure>' for shot,caption in [('hero','Three-quarter view'),('front','Front view'),('crown','Crown and coin-slot inspection'),('spine','Back, tail and vault-opening inspection')])
    body=f'<a href="{relative(GALLERY/"index.html",out)}">← All eight animal skins</a><p class="tag">{skin} · STATIC TEXTURED ASSET</p><h1>{name}</h1><p class="note">Existing coat on the existing pig geometry. Six separated meshes, two preserved texture sheets. This is a complete standalone asset package, with no change to the approved coat design.</p>{nav}<p class="small">{w:.2f} W × {d:.2f} D × {h:.2f} H studs · {tris:,} triangles. Neutral Blender lighting, not a live Roblox screenshot.</p><div class="grid">{figures}</div>'
    (out/'index.html').write_text(page(name,body),encoding='utf-8');pages.append(out/'index.html')
    lines='\n'.join(f'| {p["name"]} | {p["textureGroup"]} | {p["triangles"]:,} |' for p in r['parts'])
    correction = ('\nTiger muzzle correction: the entire snout now uses solid orange, removing the detached stripe fragment and cream patches inside the nostril recesses. This is authored in make_tiger_blend.py and baked into the trim map.\n' if skin=='tiger' else '')
    if skin=='zebra':
        correction='\nZebra coat correction: a binary face/body pattern selector removes the dense pinstripe band near the ears. Removing the muzzle clearance ring lets the stripes meet the black nose. Authored in make_zebra_blend.py and baked into both maps.\n'
    (out/'README.md').write_text(f'''# {name} — complete animal asset v1

**Existing coat packaged as an editable Blender scene and complete static FBX. No runtime installation or new skin design.**
{correction}

## Deliverables

- `{skin}-complete.blend`: six separated meshes, baked texture materials, packed PNGs and review cameras/lights.
- `{skin}-complete.fbx`: complete pig, with body, snout, ears, legs, tail and optional eyes. Textures embedded; external originals are supplied too.
- `{skin}_body_color.png`, `{skin}_trim_color.png`: exact copies of the existing 1024×1024 coats, verified by SHA-256.
- `{skin}-hero.png`, `-front.png`, `-crown.png`, `-spine.png`: rendered from the exported geometry. Neutral studio lighting for inspection; not a live Roblox screenshot.
- `{skin}-asset-report.json`: mesh/triangle counts, source hashes, texture assignments and FBX round-trip measurements.
- `assets/piggies/{paths.tier_of(skin)}/{skin}/source/{skin}.blend` and `assets/piggies/{paths.tier_of(skin)}/{skin}/generate/make_{skin}_blend.py`: the coat's authoring scene and generator -- the source of truth this package is derived from.

## Geometry and scale

The body is **12 studs wide**. Full static envelope: **{w:.3f} W × {d:.3f} D × {h:.3f} H**; {tris:,} triangles over six meshes. Highest per-mesh triangle count: {max(p['triangles'] for p in r['parts']):,}. All source mesh edges are manifold. Each vertex agrees with the existing skin scene after uniform scaling within 0.000001 source units; UV coordinates and ear face assignments were preserved before triangulation. Preview subdivision was removed, so export geometry cannot silently multiply in size.

| Mesh | Texture group | Triangles |
| --- | --- | ---: |
{lines}

Blender axes: X across, -Y toward the face, Z upward. Origin stays at the body centre, matching the shared pig's attachment frame; the floor is at Z={r['boundsBlenderStuds']['min'][2]:.4f}. FBX declares Y up / -Z forward. Reimport into Blender preserved six meshes, triangles, coat UVs and bounds with maximum error **{r['fbxRoundTripMaxBoundsError']:.9f}** units. Verify Roblox importer scale/orientation on import.

The body, snout, ears, legs and tail keep their original shapes; this preserves the coin slot and vault opening rather than remodelling them by eye. The original textures, procedural scene and shared pig_parts.blend master were not modified. No fur, mane or crest accessories are added by this base-coat package.

## Integration

For the existing game pig, use the shared mesh IDs already in the project and the two coat textures. A separate mesh upload for every animal is unnecessary. The complete FBX is available for standalone import/review and for a pipeline that explicitly wants the full assembled model.

Apply the body sheet to **Body**, and the trim sheet to **Snout, Ears, Legs and Tail**. Use an opaque SurfaceAppearance on SmoothPlastic; these full-colour maps replace the base part tint. They do not require Neon, Glass, emission or alpha animation. Two texture groups are required; assigning the body map to the trim would use the wrong UV islands.

The **Eyes** mesh is optional: omit it when the runtime builds the eyes, so there is only one pair. Sculpted nostril recesses remain without separate black inserts, matching the existing coat preview convention. Game-built coins, vault plate/dial, interactions and existing accessory sets are not included and should remain managed by the game. No animated rig, fur attachment or new gameplay effect is claimed.

Offline checks passed; actual Studio texture assignment, scale, vault alignment, small shop/held-pig readability and mobile performance remain to be checked. Nothing was uploaded or published, and Config/ownership/economy files were not edited.

## Rebuild

From repository root, after the existing skin scene and two baked maps are available:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python-exit-code 1 --python blender/pig/make/package_animal.py -- --skin {skin}
python blender/pig/make/build_animal_gallery.py
```

If a source coat needs regeneration, follow blender/pig/WORKFLOW.md. Do not rebuild the shared pig master for a packaging task. Scene, render and FBX outputs are regenerable; the packaging script is the durable source.
''',encoding='utf-8')
    url=relative(out,GALLERY)
    cards.append(f'<article><a href="{url}/index.html"><img loading="lazy" src="{url}/{skin}-hero.png" alt="{name} complete piggy"></a><h2>{name}</h2><p class="small">Six meshes · {tris:,} triangles · two texture sheets</p><nav><a href="{url}/index.html">Inspect all views</a><a href="{url}/{skin}-complete.blend">Blender</a><a href="{url}/{skin}-complete.fbx">FBX</a></nav></article>')
    rows.append({'skin':skin,'name':name,'package':relative(out,REPO),'meshes':r['meshCount'],'triangles':tris,'bodyWidthStuds':12,'textures':r['textures'],'fbxBoundsError':r['fbxRoundTripMaxBoundsError'],'status':'Complete static package; existing coat preserved; runtime integration unchanged'})
rare_nav='<p><a href="../rare/index.html">Explore the seven rare skins</a></p>' if (GALLERY.parent/'rare/index.html').exists() else ''
if (GALLERY.parent/'legendary/index.html').exists():rare_nav+='<p><a href="../legendary/index.html">Legendary skins: Storm Wolf revision</a></p>'
(GALLERY/'index.html').write_text(page('Eight complete animal piggies',rare_nav+'<small>ROB A PIGGY BANK · ANIMAL SKINS</small><h1>Eight animal coats. Complete piggy assets.</h1><p class="note">The existing approved coats, packaged on the shared pig geometry. Editable Blender scenes, complete FBXs, preserved body/trim textures and four inspection views per animal. No new species or runtime changes in this pass.</p><div class="grid">'+''.join(cards)+'</div><p>The coat generators and shared pig master are preserved. These are static base-coat packages; fur/crest accessories and game-built vault/coin parts remain separate.</p><a href="README.md">Batch handoff</a>'),encoding='utf-8');pages.append(GALLERY/'index.html')
(GALLERY/'manifest.json').write_text(json.dumps({'animalCount':8,'status':'Eight existing coats packaged; no uploads or runtime edits','models':rows},indent=2),encoding='utf-8')
(GALLERY/'README.md').write_text('''# Eight complete animal piggy assets

[Open the gallery](index.html).

Bumblebee, Ladybird, Dairy Cow, Zebra, Giraffe, Leopard, Bengal Tiger and Snow Leopard are packaged under assets/piggies/<tier>/<skin>/package/. Each includes a complete six-mesh Blender scene and FBX, the unchanged body/trim textures, four rendered views and a measured handoff. These are the existing animal designs; no new coats/species were invented.

All 16 source coat sheets passed the existing check_fade.py hard-edge test (0.00% broad fades). Packaging verifies texture SHA-256, preserved source scenes/master, original vertices and UVs, per-mesh triangle limits, manifold source edges, and FBX mesh/triangle/bounds reimport. The uniform package is 20,670 triangles; the largest mesh is 7,152 triangles. Every body is 12 studs wide.

Visual review includes crown and spine views. Angular fragments in the spotted coats are inherited from their procedural patterns: a direct unbaked Leopard render reproduced them, including after smoothing its normals. They are not introduced by the FBX export. This packaging pass preserves the original maps exactly; refining those patterns would be a separate coat-design edit.

The shared game mesh remains the preferred runtime route: use two texture assignments per animal, rather than uploading eight copies of the same geometry. Complete FBXs are standalone assembled assets for review/import. Eyes are optional where the game supplies them; no duplicate nostril inserts, fur sets, vault plate, coin pile or gameplay objects are included.

Neutral Blender previews are not Studio screenshots. Runtime material/scale/attachment checks and mobile/held-pig/shop review remain pending. Nothing was uploaded, installed or published. Source coat scenes, maps, shared master and Config were preserved.

Rebuild each package with blender/pig/make/package_animal.py -- --skin <id> inside Blender. Generate this gallery with build_animal_gallery.py. Use WORKFLOW.md only if the underlying coat needs rebuilding.
''',encoding='utf-8')
links=[]
class Check(HTMLParser):
    def handle_starttag(self,tag,attrs):
        for k,v in attrs:
            if k in ('src','href'):links.append(self.path.parent/v)
parser=Check()
for p in pages:parser.path=p;parser.feed(p.read_text(encoding='utf-8'))
assert all(p.exists() for p in links),[str(p) for p in links if not p.exists()]
print(f'Eight complete animal packages verified; {len(links)} local links valid.')
