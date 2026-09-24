"""Update the current honeycomb scenes, retaining geometry and UVs."""
from pathlib import Path
import hashlib
import json
import runpy
import sys
import bpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
repo = ROOT
while not (repo / 'blender/pig/paths.py').exists(): repo = repo.parent
sys.path.insert(0, str(repo / 'blender/pig'))
from rare_coats import SPECS
paint = runpy.run_path(str(HERE / 'honeycomb_pattern.py'))['paint']
core = ('Body', 'Snout', 'Ears', 'Legs', 'Tail')

def signature():
    payload = {name: {'verts': [list(v.co) for v in bpy.data.objects[name].data.vertices],
                      'faces': [list(p.vertices) for p in bpy.data.objects[name].data.polygons],
                      'uv': [[list(v.uv) for v in uv.data] for uv in bpy.data.objects[name].data.uv_layers]}
               for name in core}
    return hashlib.sha256(json.dumps(payload).encode()).hexdigest()

proof = {}
for filename in ('honeycomb.blend', 'honeycomb_closed.blend'):
    path = ROOT / 'source' / filename
    bpy.ops.wm.open_mainfile(filepath=str(path))
    before = signature()
    materials = {m for name in core for m in bpy.data.objects[name].data.materials if m}
    changed = 0
    for material in materials:
        nt = material.node_tree
        bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        if bsdf.inputs['Base Color'].is_linked:
            paint(nt, bsdf, SPECS['honeycomb']); changed += 1
    assert changed, 'No patterned materials found'
    assert signature() == before, 'Geometry or UVs changed'
    runpy.run_path(str(HERE / 'honey_tail.py'))['apply'](bpy.data.objects['Tail'])
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    proof[filename] = {'coatPreservesGeometryAndUVs': True, 'geometryUVHashBeforeTail': before, 'patternedMaterials': changed,
                       'tailStyle': 'solid honey-orange curl with a separate translucent amber droplet and curved reflective streak'}

specpath = ROOT / 'source/coat-spec.json'
spec = json.loads(specpath.read_text())
spec['pattern'] = 'Spherical honeycomb: hexagonal amber cells and golden wax walls; twelve pentagonal junctions close the surface without pole stretching'
spec['patternGenerator'] = 'generate/honeycomb_pattern.py'
spec['glow'] = 'None. No dots, emissive channel, animation, or extra geometry.'
spec['geometryValidation'] = proof
specpath.write_text(json.dumps(spec, indent=2) + '\n', encoding='utf-8')
print('HONEYCOMB_UPDATED', json.dumps(proof))
