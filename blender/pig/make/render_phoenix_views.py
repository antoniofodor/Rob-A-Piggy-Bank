"""Refresh wide crown/rear review views without changing the exported scene."""
from pathlib import Path
import bpy,hashlib
from mathutils import Vector
out=Path(__file__).resolve().parents[1].parents[1]/'assets/skins/animal/legendary/phoenix'
source=out/'phoenix-complete.blend';digest=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source));scene=bpy.context.scene;cam=scene.camera
scene.frame_set(55);cam.data.ortho_scale=26
for name,pos,target in [('crown',(-8,-21,34),(0,0,2)),('rear',(0,35,13),(0,1,1))]:
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/f'phoenix-{name}.png');bpy.ops.render.render(write_still=True)
assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
