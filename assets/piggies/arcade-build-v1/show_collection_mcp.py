"""Append the finished review without replacing any open or unsaved scenes."""
import bpy
from pathlib import Path
path=Path(__file__).with_name('arcade-collection-v2.blend')
before=set(bpy.data.scenes);filepath=bpy.data.filepath
with bpy.data.libraries.load(str(path),link=False) as (a,b):b.scenes=list(a.scenes)
added=[s for s in b.scenes if s]
overview=next(s for s in added if s.name.startswith('ARCADE - expanded collection'))
bpy.context.window.scene=overview
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL'
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.region_3d.view_perspective='CAMERA'
assert before.issubset(set(bpy.data.scenes)) and filepath==bpy.data.filepath
print({'review':overview.name,'importedScenes':len(added),'preservedScenes':len(before),'originalFileUnchanged':True})
