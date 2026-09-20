"""Inventory all 18 permanent Blender house models; keep seasonal art separate.

Only writes per-house handoffs for the six legacy replacements built here.
Earlier model packages retain their own reports, import history and scope.
"""
import json,os
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug
from html.parser import HTMLParser
ROOT=Path(__file__).resolve().parents[3]
MODELS=ROOT/'assets/houses'
if (MODELS/'walk-in-manifest.json').exists():
    # The old exterior inventory is retained as history. The current entry
    # point must keep selecting the verified walk-in revisions.
    from build_walkin_handoff import main
    main()
    raise SystemExit(0)
HOUSES=[
 ('shack','Cardboard Fort',1),('cottage','Beehive Cottage',1),('townhouse','Wonky Townhouse',1),
 ('mushroom','Toadstool Cottage',1),('villa','Fairy Lantern Cottage',1),('treehouse','The Treehouse',2),
 ('manor','Haunted Manor',1),('slime','Gloop House',2),('modern','Fishbowl House',1),
 ('neontower','Neon Tower',1),('crystal','Crystal Spire',1),('palace','Ice Palace',1),
 ('skycastle','Sky Castle',1),('galleon','The Beached Galleon',1),('portal','Portal House',1),
 ('thundercloud','Thundercloud Fortress',1),('void','The Void',1),('goldenpig','The Golden Piggy',1)]
NEW={
 'shack':'Starter Shack re-theme: a taped cardboard fort with folded flaps, corrugated edge marks and a crayon door. Humble single-storey shell. No animation.',
 'cottage':'Cosy Cottage re-theme: a ribbed beehive with hexagonal windows, projecting wax entrance, honey drips and a chimney. No bees or other actors. No animation.',
 'townhouse':'Brick Townhouse re-theme: three connected storeys lean in alternating directions. Windows and trim follow their storey transforms. The entrance and approach remain fixed. No animation.',
 'manor':'Stone Manor re-theme: crooked chimneys, asymmetrical gables, an attic lookout and slow porch lantern pulses. Haunted architecture without a ghost actor; the existing no-creatures direction is retained.',
 'neontower':'Rebuild of the existing six-storey Neon Tower: curtain walls, full-height columns, floor bands, corner risers, entrance canopy and crown beacon/halo. Blue-grey structure keeps The Void as the only all-black house. Named effects are timing specifications, not installed animation.',
 'skycastle':'Rebuild of the existing four-turret Sky Castle: stone keep, stepped violet caps, battlements, closed portcullis, rose banner, runes and floating shards. Shards have constrained bob timing; full orbits require a swept-fit check. No gameplay gate or interior.'}
CSS='*{box-sizing:border-box}body{margin:0;background:#f5efdf;color:#28362f;font:16px/1.5 system-ui,sans-serif}main{max-width:1240px;margin:auto;padding:34px 24px}h1{font-size:clamp(30px,5vw,48px);line-height:1.12}h2{font-size:21px;margin:12px 0 5px}a{color:#284e45}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px}.views{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}article{padding:14px;background:#fffaf0;border:1px solid #d7d6c5;border-radius:16px}img{display:block;width:100%;border-radius:10px}figure{margin:0}figcaption,.small{font-size:13px}.tag{font-size:11px;font-weight:800;letter-spacing:.8px}.notice{background:#e5e5d2;border-left:4px solid #6e8261;padding:16px}nav{display:flex;gap:14px;flex-wrap:wrap}a:focus-visible{outline:3px solid #9a6725;outline-offset:4px}@media(max-width:960px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){.grid,.views{grid-template-columns:1fr}main{padding:22px 14px}}'
def page(title,body):return f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title><style>{CSS}</style></head><body><main>{body}</main></body></html>'
cards=[];rows=[];pages=[]
for slug,name,rev in HOUSES:
    folder=f'{house_slug(slug)}-v{rev}';out=MODELS/folder
    geo=json.loads((out/'geometry-report.json').read_text())
    report='roblox-import-report.json' if (out/'roblox-import-report.json').exists() else 'package-report.json'
    imp=json.loads((out/report).read_text())
    count=imp.get('meshCount',imp.get('visualMeshes'));tris=imp['triangles'];w,d,h=geo['boundsBlender']['size']
    fbx=f'{house_slug(slug)}-roblox.fbx' if (out/f'{house_slug(slug)}-roblox.fbx').exists() else f'{house_slug(slug)}-visual.fbx'
    assert (out/f'{house_slug(slug)}.blend').exists() and (out/fbx).exists(),slug+' missing source/export'
    new=slug in NEW
    stage='NEW REBUILD' if new else 'EARLIER MODEL'
    if slug=='goldenpig':stage='EARNED HOUSE'
    if new:
        assert geo['triangles']==tris,slug+' triangle mismatch'
        assert imp['singleMaterialPerMesh'] and imp['fbxRoundTripMaxBoundsError']<.001,slug+' import failure'
        assert all(m['nonManifoldEdges']==0 and m['triangles']<20000 for m in geo['meshes']),slug+' topology failure'
        assert w<=60 and d<=57,slug+' footprint failure'
        assert (out/fbx).stat().st_mtime>=(out/f'{house_slug(slug)}.blend').stat().st_mtime,slug+' stale export'
        reference=geo['reference'];refpath=os.path.relpath(ROOT/reference,out).replace('\\','/')
        note=NEW[slug]
        (out/'README.md').write_text(f'''# {name} — Blender exterior v1

**Stable house ID: `{slug}`. New editable exterior model; Studio integration pending.**

{note}

Design source: [{reference}]({refpath}). No dedicated bitmap concept was found for this house. The first four replacements follow HOUSE-TIER-BRIEF section 4; Neon Tower and Sky Castle follow their existing rebuilt House.luau architecture. Display names here describe the proposed art; runtime names, ownership, prices and saved IDs were not changed.

## Files and measured output

- `{house_slug(slug)}.blend`: editable section meshes, flat-colour materials and presentation cameras.
- `{fbx}`: recommended single-material-per-mesh Roblox export.
- `{house_slug(slug)}-visual.fbx`, `{house_slug(slug)}-visual.obj`, `{house_slug(slug)}-visual.mtl`: grouped exchange geometry.
- `exterior.png`, `front.png`, `road.png`: actual Blender renders. Road is an orthographic low-angle study, not a live Studio photograph.
- `geometry-report.json`, `{report}`: source and reimported FBX measurements, per-mesh RGB and triangle counts.
- `animation-handoff.json`: named decorative mesh groups and timing; animation is not installed.
- `{house_slug(slug)}-collision-mounts.rbxmx`: generic invisible origin root only, with no collision boxes or display mounts.

Static envelope: **{w:.2f} W × {d:.2f} D × {h:.2f} H** in Blender units intended as studs. **{count} material-split meshes, {tris:,} triangles.** All source mesh edges are manifold. Width ≤60 and depth ≤57 checks pass; bounds include ornaments and approach geometry. FBX reimport maximum bounds error: {imp['fbxRoundTripMaxBoundsError']:.9f} units. These are static offline checks, not Studio clearance or performance certification.

## Import and scope

Blender X runs across, Y rearward and Z upward. Export mapping is Blender `(x,y,z)` → Roblox `(-x,z,y)`, front -Z. Origin is at ground level; the front facade reference is approximately Y=0. Decorative porches and stairs project forward. Confirm scale/orientation and align the structural facade before front-pinning; never align using an ornament-inflated bounding-box centre.

Use per-mesh RGB from the import report and SmoothPlastic. No texture uploads are needed. Preview emission is stripped on export; restore named accents only. REVIEW ground, lights and cameras are excluded from exports. Anchor the structure and choose collision proxies explicitly. There are no avatar route samples: zero blocked rays does not demonstrate clearance.

Closed decorative door/shell, no furnished interior, trophy mounts, entry mechanics or gameplay scripts. Interiors remain deferred. Check actual plot/fence/lawn fit, animation sweep, native camera, shadows/bloom and mobile performance in Studio. Nothing was uploaded or published by this batch.

## Rebuild

From repository root:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python-exit-code 1 --python assets/houses/tools/build_legacy_exteriors.py -- {slug}
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python-exit-code 1 --python assets/houses/tools/export_house_roblox.py -- {slug} 1
python assets/houses/tools/build_permanent_handoff.py
```

FBX is git-ignored and rebuildable; .blend, OBJ/MTL and build scripts preserve the source. Blender's optional OS thumbnail-cache failure does not affect these saved files.
''',encoding='utf-8')
        figures=''.join(f'<figure><img src="{file}" alt="{name}: {caption}"><figcaption>{caption}</figcaption></figure>' for file,caption in [('exterior.png','Actual Blender model'),('front.png','Front view'),('road.png','Low-angle study; not a live Studio photograph')])
        body=f'<a href="../mvp-exteriors.html">← All 18 permanent houses</a><p class="tag">{slug} · NEW BLENDER REBUILD</p><h1>{name}</h1><p>{w:.2f} × {d:.2f} × {h:.2f} studs · {count} meshes · {tris:,} triangles</p><p class="notice">{note}</p><nav><a href="{house_slug(slug)}.blend">Blender source</a><a href="{fbx}">Roblox FBX</a><a href="README.md">Import handoff</a><a href="{refpath}">Written design source</a></nav><p class="small">Offline geometry and FBX checks passed. Studio integration, collision and live visual checks remain pending. Interiors deferred.</p><div class="views">{figures}</div>'
        (out/'index.html').write_text(page(name,body),encoding='utf-8');pages.append(out/'index.html')
    review='index.html' if (out/'index.html').exists() else 'README.md'
    cards.append(f'<article><a href="{folder}/{review}"><img loading="lazy" src="{folder}/exterior.png" alt="{name} Blender model"></a><p class="tag">{stage} · {slug}</p><h2>{name}</h2><p class="small">{w:.2f} × {d:.2f} × {h:.2f} studs<br>{count} meshes · {tris:,} triangles</p><nav><a href="{folder}/{review}">Review</a><a href="{folder}/{house_slug(slug)}.blend">Blender</a><a href="{folder}/{fbx}">FBX</a></nav></article>')
    rows.append({'id':slug,'name':name,'revision':rev,'folder':folder,'blend':f'{folder}/{house_slug(slug)}.blend','fbx':f'{folder}/{fbx}','boundsWDH':[w,d,h],'meshes':count,'triangles':tris,'batch':'new legacy rebuild' if new else 'earlier model','report':f'{folder}/{report}','integration':'See per-house handoff; model existence is not live deployment'})
assert len(rows)==18 and len({r['id'] for r in rows})==18 and not any(r['id']=='candy' for r in rows)
body='<small>ROB A PIGGY BANK · PERMANENT HOUSE LIBRARY</small><h1>18 houses. All modelled in Blender.</h1><p>Six new rebuilds complete the permanent art roster. Each card shows actual model geometry and links to its editable source and export.</p><p class="notice">18 permanent house models, including the free starter and earned Golden Piggy. Seasonal Gingerbread is excluded. Blender asset coverage is complete; integration and live checks are tracked separately. Interiors remain deferred.</p><div class="grid">'+''.join(cards)+'</div><p>The latest six are new exterior drafts. Earlier Mushroom, Treehouse and Gloop packages are preserved with their original validation and import history. Runtime names and the catalogue were not changed here.</p><a href="MVP-EXTERIORS.md">Full count and handoff</a>'
(MODELS/'mvp-exteriors.html').write_text(page('18 permanent Blender houses',body),encoding='utf-8');pages.append(MODELS/'mvp-exteriors.html')
# The library entry point always shows the complete, current roster.
(MODELS/'index.html').write_text(page('18 permanent Blender houses',body),encoding='utf-8')
pages.append(MODELS/'index.html')
(MODELS/'mvp-exterior-manifest.json').write_text(json.dumps({'permanentModelCount':18,'seasonalExcluded':['candy'],'status':'Blender coverage complete; see per-house integration status','models':rows},indent=2),encoding='utf-8')
table='\n'.join(f'| `{r["id"]}` | {r["name"]} | [source]({r["blend"]}) | {r["meshes"]} | {r["triangles"]:,} | {r["batch"]} |' for r in rows)
(MODELS/'MVP-EXTERIORS.md').write_text(f'''# Permanent Blender house inventory — September 17

**18/18 permanent houses have distinct Blender models. Seasonal Gingerbread is excluded.**

[Open the complete model gallery](mvp-exteriors.html).

Count reconciliation: 3 earlier models (Mushroom, Treehouse, Gloop) + 9 earlier permanent exteriors + 6 legacy rebuilds = 18. The nine include earned Golden Piggy; the free starter is among the six rebuilds. The earlier ten-model batch included one seasonal Gingerbread, which does not count toward 18.

| Stable ID | Model design | Blender | Meshes | Triangles | Batch |
| --- | --- | --- | ---: | ---: | --- |
{table}

The six newly completed assets are Cardboard Fort (shack), Beehive Cottage (cottage), Wonky Townhouse (townhouse), Haunted Manor (manor), Neon Tower and Sky Castle. These replace the remaining original models as art deliverables, while the original runtime builders remain in place until integration. The first four follow the written optional directions that the user has now authorised building; tower/castle preserve the existing design vocabulary. No dedicated concept bitmaps were found for these six.

Each new folder contains .blend, material-split FBX, grouped OBJ/MTL, three renders, topology and FBX round-trip reports, plus named decorative effect specifications. All six pass offline manifold, per-mesh triangle-limit, static 60×57 footprint and FBX bounds checks. They have closed decorative shells; no interiors, gameplay logic, collision proxies or avatar route tests. Their companion RBXMX contains an invisible origin root only.

Older packages keep their own validation and integration history. Mushroom uses its original visual FBX/package report; Treehouse v2 and Gloop v2 use their existing material-split FBXs. This inventory does not claim that all 18 are installed or approved in Studio. Verify plot fit, scale, collision, camera, motion, lighting and mobile performance during integration.

Runtime IDs, names, economy and ownership were not edited. The registry still carries the seasonal candy slot, so its entry count and completion grant need separate reconciliation; do not infer live catalogue changes from this art inventory. Interiors remain deferred. Seasonal files were not rebuilt or modified.

Rebuild the new six with `assets/houses/tools/build_legacy_exteriors.py -- <id>` in Blender; then `export_house_roblox.py -- <id> 1`. Regenerate this complete inventory using **build_permanent_handoff.py**. Older gallery generators cover partial historical batches. FBXs are git-ignored and rebuildable; .blend/OBJ/MTL and scripts preserve the assets.
''',encoding='utf-8')
links=[]
class Checker(HTMLParser):
    def handle_starttag(self,tag,attrs):
        for key,value in attrs:
            if key in ('src','href'):links.append(self.path.parent/value)
parser=Checker()
for p in pages:parser.path=p;parser.feed(p.read_text(encoding='utf-8'))
assert all(p.exists() for p in links),[str(p) for p in links if not p.exists()]
print(f'18 permanent sources/exports accounted for; six new handoffs and {len(links)} local links verified.')
