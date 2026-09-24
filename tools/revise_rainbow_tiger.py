"""Remove facial beard and seat the existing plume on the actual tail end cap."""
import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/piggies/legendary/rainbowtiger/revisions/tail-tip-v2'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/piggies/legendary/rainbowtiger/package/rainbowtiger-complete.blend'))
scene=bpy.context.scene;scene.frame_set(1)
removed=['BeardFur','CheekFill_-1','CheekFill_1','CheekFur_-1','CheekFur_1']
for name in removed:
 bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
tail=bpy.data.objects['Tail'];plume=bpy.data.objects['TailPlume']
# This vertex is the 16-sided end-cap centre, verified against its neighbour ring.
tip=tail.matrix_world@tail.data.vertices[672].co
old_root=Vector((0,1.32*6,.58*6))
# Slightly overlap the cap so the five roots never appear detached.
new_root=tip-Vector((0,.04,.06))
delta=new_root-old_root
plume.location+=delta
parts=[o for o in scene.objects if o.type=='MESH' and 'bone' in o]
rig=bpy.data.objects['RainbowTiger_Rig']
bpy.ops.object.select_all(action='DESELECT')
for o in parts+[rig]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
common=dict(use_selection=True,object_types={'MESH','ARMATURE'},axis_forward='-Z',axis_up='Y',add_leaf_bones=False,armature_nodetype='NULL',path_mode='COPY',embed_textures=True,use_triangles=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False)
for suffix,anim in [('complete',False),('idle',True)]:
 bpy.ops.export_scene.fbx(filepath=str(OUT/f'rainbowtiger-{suffix}.fbx'),bake_anim=anim,**common)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rainbowtiger-complete.blend'))
report=dict(removed=removed,tailTipBlender=list(tip),plumeRootBlender=list(new_root),deltaBlender=list(delta),deltaSeat=[delta.x,delta.z,-delta.y],existingMeshIdsReused=True)
(OUT/'revision.json').write_text(json.dumps(report,indent=2))
scene.render.resolution_x=700;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.cycles.samples=24
scene.render.filepath=str(OUT/'rainbowtiger-hero.png');bpy.ops.render.render(write_still=True)
scene.camera.location=(16,21,12)
scene.camera.rotation_euler=(Vector((0,1,1))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'rainbowtiger-rear.png');bpy.ops.render.render(write_still=True)
