"""Blender background: render the rear view and prepare the packed review scene."""
from pathlib import Path
import bpy
from mathutils import Vector

HOME = Path(__file__).resolve().parents[1]
file = HOME / 'package/muddy-complete.blend'
bpy.ops.wm.open_mainfile(filepath=str(file))
scene = bpy.context.scene
scene.name = 'MUDDY - finished splash coat'
camera = scene.camera
original_position = camera.location.copy()
original_rotation = camera.rotation_euler.copy()
camera.location = (-23,31,16)
camera.rotation_euler = (Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath = str(HOME / 'preview/muddy-back.png')
bpy.ops.render.render(write_still=True)
camera.location = original_position
camera.rotation_euler = original_rotation
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.overlay.show_overlays = False
            space.region_3d.view_perspective = 'CAMERA'
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = bpy.data.objects['Body']
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(file))
