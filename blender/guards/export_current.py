"""Export edited guard actions without rebuilding or overwriting the source scene.

Blender assets/guards/terrier/terrier.blend -b --python blender/guards/export_current.py
GUARD_EXPORT_DIR overrides the default sibling edited-exports directory.
"""
import os
import sys
from pathlib import Path
deps=Path(os.environ.get('GUARD_PYTHON_DEPS','/tmp/guard-blender-python'))
if deps.exists():sys.path.insert(0,str(deps))
import bpy

rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE' and 'creature' in o]
if len(rigs)!=1:raise RuntimeError('Open an individual guard .blend with exactly one guard rig.')
rig=rigs[0];key=rig['creature']
objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==rig]
out=Path(os.environ.get('GUARD_EXPORT_DIR',str(Path(bpy.data.filepath).parent/'edited-exports')))
out.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
saved=(rig.animation_data.action,scene.frame_start,scene.frame_end,scene.frame_current)
try:
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
    bpy.context.view_layer.objects.active=rig
    for o in objects:o.select_set(True)
    settings=dict(use_selection=True,object_types={'ARMATURE','MESH'},add_leaf_bones=False,
        apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',
        use_armature_deform_only=False,use_custom_props=True,mesh_smooth_type='FACE',
        bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,
        bake_anim_simplify_factor=0,bake_anim_force_startend_keying=True)
    actions=[a for a in bpy.data.actions if a.name.startswith(key+'_') and a.get('clip')]
    for a in actions:
        rig.animation_data.action=a
        # Use actual edited key ranges, not the original duration metadata.
        start,end=a.frame_range;scene.frame_start=int(start);scene.frame_end=int(end)
        scene.frame_set(scene.frame_start)
        bpy.ops.export_scene.fbx(filepath=str(out/(key+'_'+a['clip']+'.fbx')),bake_anim=True,**settings)
    print('EDITED_GUARD_CLIPS_EXPORTED',str(out),flush=True)
finally:
    rig.animation_data.action=saved[0];scene.frame_start=saved[1];scene.frame_end=saved[2];scene.frame_set(saved[3])
