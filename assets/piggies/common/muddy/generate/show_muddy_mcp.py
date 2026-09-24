"""Append the saved review scene through Blender MCP, retaining the user's open work."""
from pathlib import Path
import bpy

file = Path(__file__).resolve().parents[1] / 'package/muddy-complete.blend'
previous_scene = bpy.context.scene.name
previous_file = bpy.data.filepath
existing = set(bpy.data.scenes)
with bpy.data.libraries.load(str(file),link=False) as (source,target):
    target.scenes = ['MUDDY - finished splash coat']
scene = target.scenes[0]
assert scene is not None
bpy.context.window.scene = scene
scene['savedReviewFile'] = str(file)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.overlay.show_overlays = False
            space.region_3d.view_perspective = 'CAMERA'
assert existing.issubset(set(bpy.data.scenes))
assert bpy.data.filepath == previous_file
print({'reviewScene':scene.name,'previousScenePreserved':previous_scene,
       'sourceFileUnchanged':True,'reviewMeshes':sum(o.type=='MESH' for o in scene.objects)})
