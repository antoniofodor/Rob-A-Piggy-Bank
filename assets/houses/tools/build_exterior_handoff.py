"""Assemble measured exterior-only handoffs after build and FBX checks."""
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug
ROOT=Path(__file__).resolve().parents[3]
MODELS=ROOT/'assets/houses'
names={'crystal':'Crystal Spire','galleon':'The Beached Galleon'}
cards=[]
for slug,name in names.items():
    out=MODELS/f'{house_slug(slug)}-v1'
    report=json.loads((out/'geometry-report.json').read_text())
    imp=json.loads((out/'roblox-import-report.json').read_text())
    w,d,h=report['boundsBlender']['size']
    reference='../design/mvp-exteriors/'+house_slug(slug)+'-concept.png'
    readme=f'''# {name} — Blender exterior v1

September 17, 2026. **Actual Blender asset, exterior only. Studio integration pending.**

Built from `{report['reference']}`. Interiors were explicitly deferred by the user. The door is closed decorative geometry; this model has no furnished rooms, entry behavior, display mounts or gameplay scripts.

## Files

- `{house_slug(slug)}.blend`: editable source scene with named geometry groups, materials and review cameras/lights.
- `{house_slug(slug)}-roblox.fbx`: recommended Roblox import file, split to one flat colour per mesh.
- `{house_slug(slug)}-visual.fbx`, `{house_slug(slug)}-visual.obj`, `{house_slug(slug)}-visual.mtl`: grouped art exchange exports.
- `exterior.png`, `front.png`, `road.png`: actual Blender renders, not generated concept images. The low-angle road study is orthographic; it is not the required live Studio pavement photograph.
- `geometry-report.json`: actual vertex bounds, topology, palette and scope.
- `roblox-import-report.json`: per-mesh colours, triangle counts and FBX round-trip verification.
- `animation-handoff.json`: named decorative groups and timing. Runtime animation is not installed.
- `{house_slug(slug)}-collision-mounts.rbxmx`: generic export companion containing **only one invisible origin root**. No collision boxes or display attachments. It is not a collision solution and is optional.

## Measured geometry

Complete exported geometry: **{w:.2f} wide × {d:.2f} deep × {h:.2f} high** in Blender units intended as studs. Frontward projection is {-report['boundsBlender']['min'][1]:.2f}; rear extent is {report['boundsBlender']['max'][1]:.2f}. Static bounds include the approach, plinth, all ropes and decorative geometry. Both width ≤60 and total depth ≤57 pass offline.

FBX: **{imp['meshCount']} single-material meshes, {imp['triangles']:,} triangles**. With optional origin companion: {imp['basePartsWithCompanion']} BaseParts, before any runtime collision. Source had {report['authoredObjectsBeforeMerge']} authored objects merged into {report['visualMeshes']} sections for editing/export. Exported source topology has no non-manifold edges. FBX round-trip max bounds error: {imp['fbxRoundTripMaxBoundsError']:.9f} units.

Zero route samples were run, because there is no interior or traversable route contract. A report of zero blocked rays is **not** an avatar clearance test.

## Import and placement

Blender uses X across, Y rearward, Z up, with the main front wall at Y=0 and the source origin at ground level. The export pipeline maps `(x,y,z)` to Roblox `(-x,z,y)`; front is Roblox -Z. The broad side of the Galleon is its house frontage. Check scale/orientation in Studio before front-pinning with `HOUSE_FRONT_LINE`.

Use the FBX manifest to assign exact flat RGB and SmoothPlastic. Materials have no image textures; preview lighting/emission are not baked into the export. The exporter strips emission, and coloured FX must be reapplied by integration. Do not import the review floor, camera or lights. No upload IDs, publishing, runtime source edits or ownership changes were made.

The importer must decide Anchored, collision fidelity and collision proxies. Do not assume the mesh importer's default collision will match the hull/crystal outline. Check real plot/kennel/lawn clearance, shadows, lighting, viewport framing and mobile performance. Ground-level windows are warm; upper panes are dark and have no light emission.

## Decorative motion

Use the named section groups in `animation-handoff.json` and the material manifest. Crystal has three independent colour-pulse accents (9-second cycle, thirds of a phase); its rock/crystal structure remains fixed. Galleon's masthead glow pulses over 7 seconds. Optional sail sway is ±2 degrees over 11 seconds about the recorded hinge; hull, mast, deck, rigging and gangplank stay fixed. Group both sail material meshes under the same pivot if enabling sway. Final motion bounds and rigging intersections still require Studio inspection; MVP may use the static sail.

## Rebuild

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 8 --python-exit-code 1 --python assets/houses/tools/build_{slug}.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python-exit-code 1 --python assets/houses/tools/export_house_roblox.py -- {slug} 1
python assets/houses/tools/build_exterior_handoff.py
```

The repo ignores generated FBX files, so rebuild them after checking out on another machine. The `.blend`, OBJ/MTL and build scripts preserve the asset. Blender's optional OS thumbnail cache failed under sandbox permissions; source saves and exports completed successfully.
'''
    (out/'README.md').write_text(readme,encoding='utf-8')
    html=f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{name} · Blender exterior</title><style>body{{margin:0;background:#fff7e8;color:#29201b;font:16px/1.5 system-ui,sans-serif}}main{{max-width:1180px;margin:auto;padding:28px 20px}}h1{{font-size:38px;margin:8px 0}}.grid{{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}}img{{width:100%;display:block;border-radius:12px}}figure{{margin:0}}figcaption{{font-size:13px;margin:8px 0 20px}}a{{color:inherit}}.note{{padding:14px;background:#f5e1c6;border-radius:10px}}@media(max-width:700px){{.grid{{grid-template-columns:1fr}}h1{{font-size:29px}}}}</style><main><a href="../mvp-exteriors.html">← Exterior batch</a><h1>{name}</h1><p>Blender exterior v1 · {w:.2f} × {d:.2f} × {h:.2f} studs · {imp['meshCount']} meshes · {imp['triangles']:,} triangles</p><p class="note">Actual model renders below. Exterior only; Studio import, collision and gameplay checks remain pending.</p><div class="grid"><figure><img src="exterior.png" alt="Actual Blender exterior render"><figcaption>Actual Blender model</figcaption></figure><figure><img src="{reference}" alt="Saved concept reference"><figcaption>Saved reference concept</figcaption></figure><figure><img src="front.png" alt="Actual front render"><figcaption>Front view</figcaption></figure><figure><img src="road.png" alt="Low-angle Blender render"><figcaption>Low-angle study · not a live Studio photograph</figcaption></figure></div><p><a href="{house_slug(slug)}.blend">Editable Blender file</a> · <a href="{house_slug(slug)}-roblox.fbx">Roblox FBX</a> · <a href="README.md">Import handoff</a> · <a href="roblox-import-report.json">Verification</a></p></main></html>'''
    (out/'index.html').write_text(html,encoding='utf-8')
    cards.append(f'<article><a href="{house_slug(slug)}-v1/index.html"><img src="{house_slug(slug)}-v1/exterior.png" alt="{name} actual Blender model"></a><h2>{name}</h2><p>{w:.2f} × {d:.2f} × {h:.2f} studs<br>{imp["meshCount"]} meshes · {imp["triangles"]:,} triangles</p><p><a href="{house_slug(slug)}-v1/index.html">Reference comparison and files →</a></p></article>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MVP house exteriors · Blender models</title><style>body{margin:0;background:#fff7e8;color:#29201b;font:16px/1.5 system-ui,sans-serif}main{max-width:1180px;margin:auto;padding:30px 22px}h1{font-size:clamp(30px,5vw,48px);line-height:1.1;margin:12px 0 20px}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px}img{width:100%;border-radius:15px;display:block}article{padding:16px;background:#f5e1c6;border-radius:18px}h2{margin:12px 0 6px}a{color:inherit}@media(max-width:700px){.grid{grid-template-columns:1fr}main{padding:24px 14px}}</style><main><small>ROB A PIGGY BANK · BLENDER EXTERIORS · SEPTEMBER 17</small><h1>Two concepts, now actual models.</h1><p>Crystal Spire and Beached Galleon. Editable Blender scenes, material-split Roblox FBX exports, and renders from the built geometry. Interiors remain deferred.</p><div class="grid">'''+''.join(cards)+'''</div><p>Offline topology, static bounds and FBX round-trip checks passed. Studio scale, collision, lighting, motion clearance and mobile performance still need validation. No runtime installation or publishing was performed.</p></main></html>'''
(MODELS/'mvp-exteriors.html').write_text(page,encoding='utf-8')
print('Wrote exterior review gallery and two measured import handoffs.')
