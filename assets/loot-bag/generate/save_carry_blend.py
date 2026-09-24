"""Package the validated carry FBX in an editable Blender scene.

Run with: blender --background --python assets/loot-bag/generate/save_carry_blend.py
The shop icon source and the game export are left untouched.
"""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


OUT = Path(__file__).resolve().parents[1]
ROOT = OUT.parents[1]
manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
bpy.ops.wm.open_mainfile(filepath=str(ROOT / manifest["source"]))
materials = {row["part"]: bpy.data.materials[row["material"]]
             for row in manifest["segments"]}
for obj in list(bpy.data.objects):
    if obj.type not in {"CAMERA", "LIGHT"}:
        bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.import_scene.fbx(filepath=str(OUT / "loot-bag.fbx"))
meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
assert {obj.name for obj in meshes} == set(materials)
assert sum(len(poly.vertices) - 2 for obj in meshes for poly in obj.data.polygons) == manifest["whole"]["triangles"]
for obj in meshes:
    obj.data.materials.clear()
    obj.data.materials.append(materials[obj.name])
    for poly in obj.data.polygons:
        poly.material_index = 0

scene = bpy.context.scene
camera = bpy.data.objects["IconCamera"]
scene.camera = camera
target = Vector((0, 0, manifest["targetHeightStuds"] * 0.45))
yaw, pitch = math.radians(22), math.radians(14)
camera.location = target + 11 * Vector((math.cos(pitch) * math.sin(yaw),
                                       -math.cos(pitch) * math.cos(yaw),
                                       math.sin(pitch)))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
scene.render.resolution_x = scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
if scene.render.engine == "CYCLES":
    scene.cycles.samples = 48
scene.render.filepath = str(OUT / "preview" / "loot-bag-carry.png")
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_perspective = "CAMERA"
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "loot-bag-carry.blend"))
bpy.ops.render.render(write_still=True)
print("Carry scene saved: rounded bottom, no rectangular base or side coins, central coin retained.")
