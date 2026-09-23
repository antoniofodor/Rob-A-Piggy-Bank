"""Render 16 frames of the real idle loop for a four-second preview GIF."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parent
while not (root/'paths.py').exists() and not (root/'blender'/'pig'/'paths.py').exists():
    if root.parent==root: raise RuntimeError('cannot find blender/pig/paths.py above %s'%__file__)
    root=root.parent
if not (root/'paths.py').exists(): root=root/'blender'/'pig'
sys.path.insert(0,str(root))
import bpy,paths
bpy.ops.wm.open_mainfile(filepath=paths.skin_blend('phoenix'))
scene=bpy.context.scene;scene.camera=bpy.data.objects['Hero']
scene.render.resolution_x=600;scene.render.resolution_y=600;scene.cycles.samples=4
out=Path(paths.RENDERS)/'phoenix_idle_frames';out.mkdir(exist_ok=True)
for i in range(16):
    scene.frame_set(1+round(i*120/16));scene.render.filepath=str(out/('%02d.png'%i));bpy.ops.render.render(write_still=True)
print('PHOENIX_PREVIEW_FRAMES',out)
