"""Refresh the vault close-up from the complete, stud-scaled review scene."""
from pathlib import Path
import bpy,math,sys
from mathutils import Vector
root=Path(__file__).resolve().parents[1];out=root.parents[1]/'assets/skins/animal/legendary/stormwolf'
bpy.ops.wm.open_mainfile(filepath=str(out/'stormwolf-complete.blend'))
scene=bpy.context.scene;camera=scene.camera
n=Vector((0,math.sqrt(36-1.9**2),-1.9)).normalized()
hatch=n*(1/math.sqrt((n.y/1.08)**2+(n.z/.96)**2))
bpy.data.objects['REVIEW_Ground'].hide_render=True
camera.location=(hatch+n*1.7)*6
camera.rotation_euler=(hatch*6-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=1.35*6
view='vault'
if '--side' in sys.argv:
    view='side';bpy.data.objects['REVIEW_Ground'].hide_render=False
    camera.location=Vector((4,3,1.7))*6
    camera.rotation_euler=(Vector((0,.3,0))*6-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=4.5*6
scene.render.filepath=str(out/f'stormwolf-{view}.png')
bpy.ops.render.render(write_still=True)
