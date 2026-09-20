"""Generate the complete exterior library from measured build/import reports."""
import json,os
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug
from html.parser import HTMLParser
ROOT=Path(__file__).resolve().parents[3]
MODELS=ROOT/'assets/houses'
NAMES={'crystal':'Crystal Spire','galleon':'The Beached Galleon','portal':'Portal House','thundercloud':'Thundercloud Fortress','void':'The Void','villa':'Fairy Lantern Cottage','modern':'Fishbowl House','palace':'Ice Palace','goldenpig':'The Golden Piggy','candy':'Gingerbread Manor (seasonal)'}
NOTES={
 'crystal':'Jagged violet spire with three independent slow pulse accents. Rock and crystal geometry stay fixed.',
 'galleon':'Broadside is the house front. Masthead pulse is separate; optional sail sway rotates both sail materials together around the recorded hinge. Keep rigging, hull, mast and gangplank fixed.',
 'portal':'Follows the saved image’s side-by-side facade split and Y/Z ring plane. This resolves the earlier front/back prose ambiguity in favor of the reference image. Open ring geometry around a closed exterior shell; no portal or teleport behavior.',
 'thundercloud':'Storm grey-blue, never black. Slow lightning sweep and fading rain groups. Fade rain before ground contact; keep stairs and cloud foundation fixed.',
 'void':'Near-black structure with violet edges. Main silhouette ring stays fixed; planets and comet have model-local orbit centers. Check swept ornaments against the plot and building before enabling movement.',
 'villa':'Round green door, toadstool window hoods, ivy and five independently named lantern bulbs. Use slow, staggered pulses.',
 'modern':'Apply material-overrides.json after import: RGB alone makes the dome opaque. Transparent dome and bubble meshes should be non-colliding. Closed pod and decorative entrance sleeve; no swimming or interior mechanics.',
 'palace':'Opaque pale-blue walls and deep-blue icicle accents. Frozen fountain sits beside the stair. Structural ice stays fixed; only accent intensity changes.',
 'goldenpig':'Earned completion-house art, never a coin purchase. Reference is the far-right piggy in the saved lineup; obsolete neighboring Dragon/Sky Islands concepts are not used.',
 'candy':'SEASONAL ASSET ONLY. This file does not approve the unresolved permanent 8M candy registry entry. Sale/availability rules were not changed.'}
CSS='body{margin:0;background:#fff7e8;color:#29201b;font:16px/1.5 system-ui,sans-serif}main{max-width:1180px;margin:auto;padding:30px 22px}h1{font-size:clamp(30px,5vw,46px);line-height:1.1}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}img{width:100%;border-radius:14px;display:block}article{padding:16px;background:#f5e1c6;border-radius:17px}figure{margin:0}figcaption{font-size:13px;margin:8px 0 20px}h2{margin:12px 0 6px}a{color:inherit}.note{padding:14px;background:#f5e1c6;border-radius:10px}.tag{font-size:12px;font-weight:800}@media(max-width:700px){.grid{grid-template-columns:1fr}main{padding:24px 14px}}'
def page(title,body):return f'<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title><style>{CSS}</style><main>{body}</main></html>'
rows=[];cards=[];pages=[]
for slug,name in NAMES.items():
    out=MODELS/f'{house_slug(slug)}-v1'
    r=json.loads((out/'geometry-report.json').read_text());imp=json.loads((out/'roblox-import-report.json').read_text())
    assert r['triangles']==imp['triangles'],slug+' stale import report'
    assert imp['singleMaterialPerMesh'] and imp['fbxRoundTripMaxBoundsError'] < .001,slug+' import check failed'
    assert all(m['nonManifoldEdges']==0 and m['triangles']<20000 for m in r['meshes']),slug+' topology check failed'
    assert r['boundsBlender']['size'][0]<=60 and r['boundsBlender']['size'][1]<=57,slug+' static footprint too large'
    assert (out/f'{house_slug(slug)}-roblox.fbx').stat().st_mtime >= (out/f'{house_slug(slug)}.blend').stat().st_mtime,slug+' stale FBX'
    w,d,h=r['boundsBlender']['size'];note=NOTES[slug]
    reference=os.path.relpath(ROOT/r['reference'],out).replace('\\','/')
    command=f'--python assets/houses/tools/build_{slug}.py' if slug in ('crystal','galleon') else f'--python assets/houses/tools/build_fantasy_batch.py -- {slug}'
    text=f'''# {name} — Blender exterior v1

September 17, 2026. **Actual Blender asset; Studio integration pending. Interiors deferred.**

{note}

Source reference: `{r['reference']}`. Doorways are closed decorative geometry, with no furnished rooms, display mounts, entry logic or gameplay scripts.

## Deliverables

- `{house_slug(slug)}.blend`: editable geometry, named sections, materials and review cameras/lights.
- `{house_slug(slug)}-roblox.fbx`: recommended single-material-per-mesh import.
- `{house_slug(slug)}-visual.fbx`, `{house_slug(slug)}-visual.obj`, `{house_slug(slug)}-visual.mtl`: grouped art exchange exports.
- `exterior.png`, `front.png`, `road.png`: actual Blender renders. Road view is an orthographic low-angle study, not a live Studio pavement photograph.
- `geometry-report.json`, `roblox-import-report.json`: source topology, vertex bounds, per-mesh RGB/triangles and FBX round-trip results.
- `animation-handoff.json`: named decorative effects and periods; runtime animation is not installed.
- `{house_slug(slug)}-collision-mounts.rbxmx`: optional generic companion with only an invisible origin root. **No collision boxes or display attachments.**

## Measured output

Static bounds: **{w:.2f} W × {d:.2f} D × {h:.2f} H** in units intended as studs. Frontward projection {-r['boundsBlender']['min'][1]:.2f}; rear extent {r['boundsBlender']['max'][1]:.2f}. All static ornament, approaches and bases are counted. Width ≤60 and total depth ≤57 pass offline.

**{imp['meshCount']} FBX meshes, {imp['triangles']:,} triangles**. Optional origin root adds one BasePart. Source: {r['authoredObjectsBeforeMerge']} primitives merged into {r['visualMeshes']} editing sections. All exported source meshes have zero non-manifold edges. FBX round-trip maximum bounds error: {imp['fbxRoundTripMaxBoundsError']:.9f} units.

Zero route samples were run: these are exterior models, so zero blocked rays is not evidence of avatar clearance. Full coplanar, continuous motion, physics and Studio visual checks remain pending.

## Integration

Blender X is across, Y rearward, Z up. The structural front-wall reference is Y=0; silhouette-specific doors may project forward. Origin is ground level. The export mapping is `(x,y,z)` → Roblox `(-x,z,y)`, front -Z. Confirm scale and orientation before front-pinning with HOUSE_FRONT_LINE. Do not use a whole-model bounding-box center inflated by decorative FX.

Use flat RGB from the material manifest and SmoothPlastic; no texture images are needed. Fishbowl additionally requires its material-overrides.json. Preview emission is stripped on export; restore only named accent effects in integration. Review ground/lights/cameras are excluded. Choose Anchored/collision fidelity and simple collision proxies explicitly; automatic mesh collision is not certified.

Actual plot/fence/lawn/kennel fit, camera, shadows, bloom, native shop framing, motion sweep and mobile performance need Studio verification. Warm accents are assigned explicitly in the Blender source. Game runtime, ownership and economy files were not changed by this batch, and nothing was uploaded or published.

## Rebuild

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 6 --python-exit-code 1 {command}
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python-exit-code 1 --python assets/houses/tools/export_house_roblox.py -- {slug} 1
python assets/houses/tools/build_fantasy_handoff.py
```

Generated FBX files are git-ignored; rebuild after checkout. Source .blend, OBJ/MTL and scripts preserve the asset. Blender's optional OS thumbnail cache was unavailable under sandbox permissions, but sources and exports saved successfully.
'''
    (out/'README.md').write_text(text,encoding='utf-8')
    tag='SEASONAL MODEL' if slug=='candy' else 'EARNED HOUSE' if slug=='goldenpig' else 'EXTERIOR MODEL'
    figures=''.join(f'<figure><img src="{src}" alt="{caption}"><figcaption>{caption}</figcaption></figure>' for src,caption in [('exterior.png','Actual Blender model'),(reference,'Saved concept reference'),('front.png','Front view'),('road.png','Low-angle study · not a live Studio photograph')])
    body=f'<a href="../mvp-exteriors.html">← All exterior models</a><p class="tag">{tag}</p><h1>{name}</h1><p>{w:.2f} × {d:.2f} × {h:.2f} studs · {imp["meshCount"]} meshes · {imp["triangles"]:,} triangles</p><p class="note">{note}</p><div class="grid">{figures}</div><p><a href="{house_slug(slug)}.blend">Editable Blender file</a> · <a href="{house_slug(slug)}-roblox.fbx">Roblox FBX</a> · <a href="README.md">Import handoff</a> · <a href="roblox-import-report.json">Verification</a></p><p>Studio import, collision, lighting, effects and mobile performance remain pending.</p>'
    (out/'index.html').write_text(page(name,body),encoding='utf-8');pages.append(out/'index.html')
    cards.append(f'<article><a href="{house_slug(slug)}-v1/index.html"><img loading="lazy" src="{house_slug(slug)}-v1/exterior.png" alt="{name} Blender model"></a><h2>{name}</h2><span class="tag">{tag}</span><p>{w:.2f} × {d:.2f} × {h:.2f} studs<br>{imp["meshCount"]} meshes · {imp["triangles"]:,} triangles</p><a href="{house_slug(slug)}-v1/index.html">Reference comparison and files →</a></article>')
    rows.append({'id':slug,'name':name,'boundsWDH':[w,d,h],'meshes':imp['meshCount'],'triangles':imp['triangles'],'availability':tag})
body=f'<small>ROB A PIGGY BANK · BLENDER EXTERIORS</small><h1>The fantasy exterior library.</h1><p>{len(rows)} built exterior models in this continuation. Every card is a render of actual Blender geometry. Editable scenes, material-split FBX files and measured handoffs are included. Interiors remain deferred.</p><div class="grid">'+''.join(cards)+'</div><p>Existing Mushroom, Treehouse and Gloop assets remain in their original folders. Existing code-built houses are unchanged. Gingerbread stays seasonal; Golden Piggy stays earned.</p><p>Offline topology, static bounds and FBX checks passed. Studio validation and runtime integration remain pending.</p><a href="MVP-EXTERIORS.md">Batch handoff</a>'
(MODELS/'mvp-exteriors.html').write_text(page('Blender exterior library',body),encoding='utf-8');pages.append(MODELS/'mvp-exteriors.html')
(MODELS/'mvp-exterior-manifest.json').write_text(json.dumps({'status':'Exterior model drafts; Studio integration pending','models':rows},indent=2))
table='\n'.join(f'| {r["name"]} | [{house_slug(r["id"])}.blend]({house_slug(r["id"])}-v1/{house_slug(r["id"])}.blend) | {r["meshes"]} | {r["triangles"]:,} | '+ ' × '.join(f'{v:.2f}' for v in r['boundsWDH'])+' |' for r in rows)
(MODELS/'MVP-EXTERIORS.md').write_text(f'''# MVP exterior modelling — September 17

The remaining eight fantasy exteriors are built from the saved concepts, alongside the previously completed Crystal Spire and Beached Galleon. Interiors remain deferred beyond MVP.

[Open the model gallery](mvp-exteriors.html) for actual Blender renders, reference comparisons and per-house import instructions.

| House | Editable source | FBX meshes | Triangles | Width × depth × height |
| --- | --- | ---: | ---: | --- |
{table}

Each folder includes a Blender scene, material-split Roblox FBX, grouped OBJ/MTL, three renders, source geometry report, FBX round-trip report and decorative animation handoff. Dimensions use Blender units intended as studs. Static bounds include bases, stairs and ornaments.

Gingerbread Manor remains **seasonal only**. Golden Piggy remains **earned**, using the piggy in the saved fantasy lineup. Existing Mushroom, Treehouse and Gloop Blender assets and code-built houses were preserved. This batch did not edit game runtime, prices, ownership or availability.

Offline vertex bounds, manifold topology, per-mesh triangle limits, single-material splitting and FBX bounds round trips pass. Studio import, collision, avatar routes, motion sweep, lighting and mobile performance are pending. Generic collision/mount companions contain only an invisible origin root; no collision boxes or display mounts are supplied. Zero route samples is not an avatar clearance test. Fishbowl's transparent dome requires its material-overrides.json after import.

Rebuild the original two with build_crystal.py / build_galleon.py. Rebuild the eight new sources with assets/houses/tools/build_fantasy_batch.py -- <house-id>, export using export_house_roblox.py -- <house-id> 1, then regenerate the complete gallery with build_fantasy_handoff.py. Exact commands are in each README. FBX files are git-ignored and rebuildable; .blend, OBJ/MTL and scripts preserve the sources.

These are first visual review models. Decorative FX are named meshes and timing specifications; runtime animation has not been installed. Next refinement should use user art feedback or actual Studio evidence.
''',encoding='utf-8')
links=[]
class Checker(HTMLParser):
    def handle_starttag(self,tag,attrs):
        for key,value in attrs:
            if key in ('src','href'):links.append(self.path.parent/value)
parser=Checker()
for path in pages:parser.path=path;parser.feed(path.read_text(encoding='utf-8'))
assert all(p.exists() for p in links),[str(p) for p in links if not p.exists()]
print(f'Built {len(rows)} model handoffs, {len(pages)} pages; {len(links)} local references verified.')
