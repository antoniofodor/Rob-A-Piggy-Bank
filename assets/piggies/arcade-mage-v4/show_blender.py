import bpy
from pathlib import Path
path=Path(r'C:/Users/anton/robloxGame/assets/piggies/legendary/finalboss/package/mage-v4/finalboss-mage-v4.blend')
before=set(bpy.data.scenes);original_file=bpy.data.filepath
with bpy.data.libraries.load(str(path),link=False) as (a,b):b.scenes=list(a.scenes)
added=[s for s in b.scenes if s];bpy.context.window.scene=added[0]
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False;area.spaces.active.region_3d.view_perspective='CAMERA'
assert before.issubset(set(bpy.data.scenes)) and original_file==bpy.data.filepath
print({'scene':bpy.context.scene.name,'preservedScenes':len(before)})
