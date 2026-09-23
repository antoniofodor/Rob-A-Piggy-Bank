"""Render the current ear geometry close up without modifying the saved model."""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
import sys as _sys;_sys.path.insert(0,str(ROOT));import paths
package=Path(paths.animal_package('rainbowtiger'))
bpy.ops.wm.open_mainfile(filepath=str(package/'rainbowtiger-complete.blend'))
scene=bpy.context.scene
scene.frame_set(1)
camera=scene.camera
camera.location=(0,-30,10)
camera.rotation_euler=(Vector((0,-2,5.4))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=11
scene.render.resolution_x=960
scene.render.resolution_y=640
scene.cycles.samples=24
scene.render.filepath=str(package/'rainbowtiger-ear-detail.png')
bpy.ops.render.render(write_still=True)
