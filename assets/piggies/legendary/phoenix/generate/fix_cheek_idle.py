"""Keep the current Ice Phoenix cheek ruffs seated without rebuilding its art.

Run with Blender --background --python <this file>. Only the two cheek
rotation tracks change; geometry, weights, materials and other tracks persist.
"""
from pathlib import Path
import hashlib
import json
import bpy

PACKAGE = Path(__file__).resolve().parents[1] / 'package'
CHEEKS = ('Ruff_L', 'Ruff_R')
bpy.ops.wm.open_mainfile(filepath=str(PACKAGE / 'phoenix-complete.blend'))
scene = bpy.context.scene
rig = bpy.data.objects['Phoenix_Rig']
action = rig.animation_data.action
curves = [curve for layer in action.layers for strip in layer.strips
          for bag in strip.channelbags for curve in bag.fcurves]
paths = {f'pose.bones["{bone}"].rotation_quaternion' for bone in CHEEKS}
changed = 0
for curve in curves:
    if curve.data_path not in paths:
        continue
    value = 1.0 if curve.array_index == 0 else 0.0
    for key in curve.keyframe_points:
        key.co.y = key.handle_left.y = key.handle_right.y = value
    curve.update()
    changed += 1
assert changed == 8, changed

# Validate every frame using evaluated vertices, including the weighted tips.
baseline = {}
maximum = 0.0
for frame in range(1, 122):
    scene.frame_set(frame)
    graph = bpy.context.evaluated_depsgraph_get()
    for bone in CHEEKS:
        ob = bpy.data.objects[f'Phoenix_{bone}_Feathers'].evaluated_get(graph)
        mesh = ob.to_mesh()
        coords = [rig.matrix_world.inverted() @ ob.matrix_world @ v.co for v in mesh.vertices]
        ob.to_mesh_clear()
        if bone not in baseline:
            baseline[bone] = coords
        maximum = max(maximum, max((a-b).length for a,b in zip(baseline[bone], coords)))
assert maximum < 1e-6, maximum
scene.frame_set(1)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(PACKAGE / 'phoenix-complete.blend'))
bpy.ops.object.select_all(action='DESELECT')
for ob in scene.objects:
    if ob == rig or (ob.type == 'MESH' and 'bone' in ob):
        ob.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(
    filepath=str(PACKAGE / 'phoenix-idle.fbx'), use_selection=True,
    object_types={'MESH', 'ARMATURE'}, axis_forward='-Z', axis_up='Y',
    add_leaf_bones=False, armature_nodetype='NULL', path_mode='COPY',
    embed_textures=True, use_triangles=True, bake_anim=True,
    bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
    bake_anim_simplify_factor=0)
note = ('Cheek ruffs remain in their rest pose relative to Root. Crest, mantle '
        'and tail retain their idle motion; frost shimmer is unchanged.')
for filename in ('phoenix-asset-report.json', 'animation-handoff.json'):
    path = PACKAGE / filename
    report = json.loads(path.read_text(encoding='utf-8'))
    animation = report['animation'] if 'animation' in report else report
    animation['notes'] = note
    animation['stationaryBones'] = ['Root', *CHEEKS]
    path.write_text(json.dumps(report, indent=2), encoding='utf-8')
(PACKAGE / 'cheek-idle-checks.json').write_text(json.dumps({
    'framesChecked': 121, 'cheekVertexMaximumMotion': maximum,
    'sceneSHA256': hashlib.sha256((PACKAGE / 'phoenix-complete.blend').read_bytes()).hexdigest(),
    'notes': note}, indent=2), encoding='utf-8')
print('PHOENIX_CHEEKS_FIXED', maximum, flush=True)
