"""Verify the authored files and write the local review gallery/handoff."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
EPIC = ROOT / "assets/piggies/epic"
KEYS = ("hedgehog", "lion", "stormstone", "peacock")
NAMES = dict(zip(KEYS, ("Hedgehog", "Lion", "Storm Stone", "Peacock")))
cards, rows = [], []
for key in KEYS:
    base = EPIC / key
    package = base / "package/epic-v2"
    report_file = package / "asset-report.json"
    report = json.loads(report_file.read_text())
    assert report["baseGeometryUnchanged"] and report["baseUVsPreserved"], key
    for export in report["exports"]:
        file = package / export["file"]
        assert hashlib.sha256(file.read_bytes()).hexdigest() == export["sha256"], file
        assert export["roundTripBoundsError"] < .001, file
    for part in report["parts"]:
        assert part["triangles"] < 20000, part["name"]
        if part["role"] == "accessory": assert part["nonManifoldEdges"] == 0, part["name"]
    for view in ("hero", "front", "back", "crown"):
        assert (base / "preview" / f"{key}-epic-v2-{view}.png").stat().st_size > 10000
    for sheet in ("body", "trim", "palette"):
        assert (base / "sheets" / f"{key}-epic-v2-{sheet}.png").is_file()
    assert (base / "source" / f"{key}-epic-v2.blend").stat().st_size > 10000
    report["concept"] = "assets/piggies/epic/_concepts-v2/epic-concepts.png"
    report_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    accessory_triangles = sum(p["triangles"] for p in report["parts"] if p["role"] == "accessory")
    rows.append({"key": key, "triangles": report["totalTriangles"], "accessoryTriangles": accessory_triangles,
                 "accessoryMeshes": sum(p["role"] == "accessory" for p in report["parts"]), "checks": "passed"})
    (package / "README.md").write_text(f"""# {NAMES[key]} — epic v2

Built from the approved [concept](../../../_concepts-v2/epic-concepts.png).
Open the [Blender source](../../source/{key}-epic-v2.blend) or
[rendered preview](../../preview/{key}-epic-v2-hero.png).

Import `{key}-epic-v2-accessories.fbx` to use the existing shared pig body.
`{key}-epic-v2-complete.fbx` contains the complete static pig for inspection.
Both embed their textures. The body is 12 studs wide in the FBX; the editable
source retains the original 2-unit width. `asset-report.json` gives measured
per-mesh sizes/offsets, palette/Neon roles, and successful FBX round-trip checks.

{report['totalTriangles']:,} triangles total; {accessory_triangles:,} in new accessories.
Every mesh is below 20,000 triangles and every accessory has zero nonmanifold
edges. Base vertices, topology and UVs are unchanged.

Status: authored and validated locally. Not uploaded or installed in Roblox.
See the [shared handoff](../../../_concepts-v2/README.md) for the integration steps.
""", encoding="utf-8")
    buttons = "".join(f'<button data-view="{view}">{view.title()}</button>' for view in ("hero", "front", "back", "crown"))
    cards.append(f'''<article data-key="{key}"><div class="title"><h2>{NAMES[key]}</h2><span>EPIC</span></div>
<a class="preview" href="../{key}/preview/{key}-epic-v2-hero.png"><img src="../{key}/preview/{key}-epic-v2-hero.png" alt="{NAMES[key]} actual Blender model"></a>
<nav>{buttons}</nav><p>{accessory_triangles:,} accessory triangles · {rows[-1]['accessoryMeshes']} accessory meshes</p>
<footer><a href="../{key}/source/{key}-epic-v2.blend">Blender source</a><a href="../{key}/package/epic-v2/{key}-epic-v2-accessories.fbx">Accessories FBX</a><a href="../{key}/package/epic-v2/{key}-epic-v2-complete.fbx">Complete FBX</a></footer></article>''')

page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Animal epics · Blender v2</title><style>
*{box-sizing:border-box}body{margin:0;background:#f3f1e9;color:#292d31;font:16px system-ui,sans-serif}main{max-width:1320px;margin:48px auto;padding:0 24px}h1{font-size:clamp(30px,4vw,54px);margin:10px 0}header p{color:#636866;max-width:740px;line-height:1.6}.eyebrow{letter-spacing:.2em;font-size:12px;font-weight:750;color:#915b22}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px;margin-top:32px}article{background:#fff;border-radius:18px;overflow:hidden;border:1px solid #deddd4}.title{display:flex;align-items:center;justify-content:space-between;padding:18px 22px}h2{margin:0;font-size:24px}.title span{font-size:11px;letter-spacing:.15em;background:#efe5f8;color:#7c438e;padding:7px 12px;border-radius:18px}img{width:100%;display:block}nav{display:flex;gap:8px;padding:18px 22px 0}button{background:#f3f1e9;border:0;border-radius:20px;padding:9px 17px;cursor:pointer;color:#4c5551}button.selected{background:#273e36;color:white}article p{padding:0 22px;font-size:13px;color:#72756e}footer{display:flex;flex-wrap:wrap;gap:14px;padding:6px 22px 22px}a{color:#386754;font-size:14px}details{margin-top:30px}summary{cursor:pointer;font-size:18px;padding:14px 0}.status{padding:14px 18px;background:#e7eadf;border-radius:10px;font-size:14px;display:inline-block}@media(max-width:700px){.grid{grid-template-columns:1fr}main{margin-top:26px}}
</style><main><header><div class="eyebrow">ANIMAL PACK / ASSET REVIEW</div><h1>Four epics, made in Blender.</h1><p>The approved concept translated into editable meshes, baked coats and checked FBX exports. Choose a view below to inspect each actual model.</p><div class="status">Authored and validated locally · Roblox import pending</div></header><section class="grid">'''
page += "".join(cards)
page += '''</section><details><summary>Approved concept sheet</summary><img src="epic-concepts.png" alt="Approved four-pig concept sheet"></details><p><a href="README.md">Asset handoff and rebuild instructions</a></p></main><script>
document.querySelectorAll('article').forEach(card=>{card.querySelector('button').classList.add('selected');card.querySelectorAll('button').forEach(button=>button.onclick=()=>{const key=card.dataset.key;const url=`../${key}/preview/${key}-epic-v2-${button.dataset.view}.png`;card.querySelector('img').src=url;card.querySelector('.preview').href=url;card.querySelectorAll('button').forEach(b=>b.classList.toggle('selected',b===button));});});
</script></html>'''
(EPIC / "_concepts-v2/index.html").write_text(page, encoding="utf-8")
(EPIC / "_concepts-v2/validation.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
print(json.dumps(rows, indent=2))
