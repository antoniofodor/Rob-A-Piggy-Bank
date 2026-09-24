"""Append the review scenes without resetting the user's open Blender file."""
from pathlib import Path
import bpy,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
specs=json.loads((HERE/'design-specs.json').read_text())['skins']
before=set(bpy.data.scenes);original_file=bpy.data.filepath;added=[]
for row in specs:
    if row['key'] not in ('ghost','hologram'):continue
    path=ROOT/'assets/piggies'/row['tier']/row['key']/'revisions/og-v2/package'/f"{row['key']}-og-v2.blend"
    with bpy.data.libraries.load(str(path),link=False) as (a,b):b.scenes=list(a.scenes)
    for scene in b.scenes:
        if scene:scene.name=row['name']+' - approved layered';added.append(scene)
bpy.context.window.scene=next(s for s in added if s.get('skinKey')=='ghost')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False
            area.spaces.active.region_3d.view_perspective='CAMERA'
assert before.issubset(set(bpy.data.scenes)) and original_file==bpy.data.filepath
print({'scenesAdded':[s.name for s in added],'preservedScenes':len(before),'active':bpy.context.scene.name})
