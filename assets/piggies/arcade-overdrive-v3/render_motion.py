from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];HOME=ROOT/'assets/piggies/legendary/finalboss'
bpy.ops.wm.open_mainfile(filepath=str(HOME/'package/overdrive-v3/finalboss-overdrive-v3.blend'))
s=bpy.context.scene;s.render.resolution_x=480;s.render.resolution_y=480;s.cycles.samples=8
s.view_layers[0].cycles.use_denoising=True
out=HOME/'preview/overdrive-v3/frames';out.mkdir(exist_ok=True)
for label,pos in [('motion',(-4,-6,2.8)),('reactor',(-4,6,2.8))]:
 s.camera.location=pos;s.camera.rotation_euler=(Vector((0,0,.1))-s.camera.location).to_track_quat('-Z','Y').to_euler()
 for j,f in enumerate(range(1,145,6)):
  s.frame_set(f);s.render.filepath=str(out/f'{label}-{j:02d}.png');bpy.ops.render.render(write_still=True)
print('MOTION_RENDER_COMPLETE',flush=True)
