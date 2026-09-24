"""Render the final packaged honey tail and export it separately for import."""
from pathlib import Path
import hashlib
import json
import bpy
from mathutils import Vector

root = Path(__file__).resolve().parents[1]
out = root / 'package'
bpy.ops.wm.open_mainfile(filepath=str(out / 'honeycomb-complete.blend'))
tail = bpy.data.objects['Tail']
bpy.ops.object.select_all(action='DESELECT')
tail_parts = [tail] + [bpy.data.objects[name] for name in ('HoneyDrop','HoneyDropHighlight') if name in bpy.data.objects]
for obj in tail_parts: obj.select_set(True)
bpy.context.view_layer.objects.active = tail
target = out / 'honeycomb-tail.fbx'
bpy.ops.export_scene.fbx(filepath=str(target), use_selection=True, object_types={'MESH'},
                        global_scale=1, apply_unit_scale=False, bake_space_transform=True,
                        axis_forward='-Z', axis_up='Y', use_mesh_modifiers=False,
                        mesh_smooth_type='FACE', bake_anim=False, path_mode='COPY', embed_textures=True)
known = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(target), use_anim=False)
added = [o for o in bpy.data.objects if o not in known]
meshes = [o for o in added if o.type == 'MESH']
assert len(meshes) == len(tail_parts) and all(o.data.uv_layers for o in meshes)
assert sum(len(o.data.polygons) for o in meshes) == sum(len(o.data.polygons) for o in tail_parts)
for obj in added: bpy.data.objects.remove(obj, do_unlink=True)
report_path = out / 'honeycomb-asset-report.json'
report = json.loads(report_path.read_text())
report['tailRevision'] = {'style': 'Orange curl, lighter translucent honey droplet, curved reflective streak',
                        'file': target.name, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                        'needsSkinSpecificTailMesh': True, 'roundTripPassed': True,
                        'parts': [o.name for o in tail_parts], 'materialNote': 'Preserve separate droplet and highlight materials. Blender uses transmission 0.78, alpha 0.78, IOR 1.47; configure transparency in Roblox after import.'}
report_path.write_text(json.dumps(report, indent=2) + '\n')
scene = bpy.context.scene
scene.camera.location = (15, 26, 10)
focus = Vector((.4, 7.8, 2.8))
scene.camera.rotation_euler = (focus - scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.ortho_scale = 7.5
scene.render.resolution_x = scene.render.resolution_y = 640
scene.render.filepath = str(out / 'honeycomb-tail-detail.png')
bpy.ops.render.render(write_still=True)
