import bpy
from pathlib import Path
root=Path(r'C:/Users/anton/robloxGame/assets/piggies/legendary');before=set(bpy.data.scenes);filepath=bpy.data.filepath;added=[]
for key in ('jackpot','finalboss','mechaplayer'):
 with bpy.data.libraries.load(str(root/key/'package/arcade-v2'/f'{key}-arcade-v2.blend'),link=False) as (a,b):b.scenes=list(a.scenes)
 added.extend(s for s in b.scenes if s)
bpy.context.window.scene=next(s for s in added if s.name.startswith('mechaplayer - Arcade legendary v2'))
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False;area.spaces.active.region_3d.view_perspective='CAMERA'
assert before.issubset(set(bpy.data.scenes)) and filepath==bpy.data.filepath
print({'appended':len(added),'preservedScenes':len(before),'scene':bpy.context.scene.name})
