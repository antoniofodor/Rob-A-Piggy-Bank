"""Append the review scenes while preserving the user's current Blender work."""
import bpy
from pathlib import Path

path = Path(__file__).with_name('og-collection-v1.blend')
before = set(bpy.data.scenes)
filepath = bpy.data.filepath
with bpy.data.libraries.load(str(path), link=False) as (available, target):
    target.scenes = list(available.scenes)
imported = [s for s in target.scenes if s]
overview = next(s for s in imported if s.name.startswith('OG COLLECTION'))
bpy.context.window.scene = overview
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.region_3d.view_perspective = 'CAMERA'
            space.overlay.show_overlays = False
            space.shading.type = 'MATERIAL'
assert before.issubset(set(bpy.data.scenes))
assert filepath == bpy.data.filepath
print({'review': overview.name, 'importedScenes': len(imported), 'preservedScenes': len(before), 'originalFileUnchanged': True})
