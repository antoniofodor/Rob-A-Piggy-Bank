"""Apply the runtime wind tuning to the current Ice Phoenix, preserving its art."""
from pathlib import Path
import hashlib
import json
import math
import sys
import bpy

REPO = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(REPO/'blender/pig/make'))
from phoenix_wind import animate, angle

PACKAGE = Path(__file__).resolve().parents[1]/'package'
bpy.ops.wm.open_mainfile(filepath=str(PACKAGE/'phoenix-complete.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['Phoenix_Rig']
parts = [o for o in scene.objects if o.type == 'MESH' and 'bone' in o]
def geometry_hash():
    return hashlib.sha256(repr([
        (o.name, [tuple(v.co) for v in o.data.vertices],
         [tuple(p.vertices) for p in o.data.polygons],
         [[tuple(uv.uv) for uv in layer.data] for layer in o.data.uv_layers])
        for o in parts]).encode()).hexdigest()
before = geometry_hash()
tuning = animate(rig, scene)
assert geometry_hash() == before
checks = {}
for name, profile in tuning.items():
    samples = [angle(math.tau*f/120,profile) for f in range(121)]
    assert abs(samples[0]-samples[-1]) < 1e-8
    assert max(map(abs,samples)) < math.radians(5)
    checks[name] = {'minimumDegrees': math.degrees(min(samples)),
                    'maximumDegrees': math.degrees(max(samples)),
                    'loopError': abs(samples[0]-samples[-1])}
# Verify cheek geometry itself remains still, not just its rotation channels.
baseline = {}
cheek_motion = 0
for frame in range(1,122):
    scene.frame_set(frame)
    graph = bpy.context.evaluated_depsgraph_get()
    for name in ('Ruff_L','Ruff_R'):
        ob = bpy.data.objects[f'Phoenix_{name}_Feathers'].evaluated_get(graph)
        mesh = ob.to_mesh()
        coords = [ob.matrix_world@v.co for v in mesh.vertices]
        ob.to_mesh_clear()
        baseline.setdefault(name, coords)
        cheek_motion = max(cheek_motion, max((a-b).length for a,b in zip(baseline[name],coords)))
assert cheek_motion < 1e-6
scene.frame_set(1)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(PACKAGE/'phoenix-complete.blend'))
bpy.ops.object.select_all(action='DESELECT')
for ob in parts+[rig]: ob.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(filepath=str(PACKAGE/'phoenix-idle.fbx'),
    use_selection=True, object_types={'MESH','ARMATURE'}, axis_forward='-Z', axis_up='Y',
    add_leaf_bones=False, armature_nodetype='NULL', path_mode='COPY', embed_textures=True,
    use_triangles=True, bake_anim=True, bake_anim_use_all_actions=False,
    bake_anim_use_nla_strips=False, bake_anim_simplify_factor=0)
note = ('A delayed icy gust passes from crest through mantle to tail, with faster '
        'tip flutter during the gust. Cheek ruffs stay seated against the face.')
for filename in ('phoenix-asset-report.json','animation-handoff.json'):
    p = PACKAGE/filename
    report = json.loads(p.read_text(encoding='utf-8'))
    animation = report.get('animation',report)
    animation.update(notes=note, windProfiles=tuning, stationaryBones=['Root','Ruff_L','Ruff_R'])
    p.write_text(json.dumps(report,indent=2),encoding='utf-8')
report = {'sceneSHA256': hashlib.sha256((PACKAGE/'phoenix-complete.blend').read_bytes()).hexdigest(),
          'geometryUnchanged': True, 'framesChecked': 121,
          'cheekVertexMaximumMotion': cheek_motion, 'windTracks': checks, 'notes': note}
for filename in ('icy-wind-checks.json','cheek-idle-checks.json'):
    (PACKAGE/filename).write_text(json.dumps(report,indent=2),encoding='utf-8')
print('ICY_WIND_APPLIED',json.dumps(report),flush=True)
