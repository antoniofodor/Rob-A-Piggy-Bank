"""Render the actual in-game acorn as transparent currency artwork.

blender --background --python blender/acorn/render_icon.py
Keeps the source blend, exported meshes and their palette unchanged.
"""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'assets/acorn/acorn.blend'))
scene = bpy.context.scene
bpy.data.objects['Backdrop'].hide_render = True
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.cycles.samples = 64
scene.cycles.use_denoising = True
camera = scene.camera
camera.location = (1.2, -3.0, 1.25)
camera.rotation_euler = (Vector((0, 0, .414)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = .91
out = ROOT / 'assets/acorn/ui'
out.mkdir(parents=True, exist_ok=True)
scene.render.filepath = str(out / 'acorn-model-icon.png')
bpy.ops.render.render(write_still=True)
