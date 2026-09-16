"""Render comparison scenes from the finished native rigged Blender files."""
import sys
import os
import json
import math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import bpy
from mathutils import Vector,Matrix
from build_guards import OUT,CONFIG,studio,material

GROUPS={'dogs':['terrier','shepherd','mastiff'],
        'wild':['direwolf','gorilla','raptor'],
        'elite':['triceratops','cerberus']}
for group,keys in GROUPS.items():
    if os.environ.get('GUARD_GROUP') and group not in os.environ['GUARD_GROUP'].split(','):continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.world=bpy.data.worlds.new('World')
    cam=studio();scene.render.resolution_x=1200;scene.render.resolution_y=720;scene.cycles.samples=4
    cam.location=(0,-24,10);cam.rotation_euler=(Vector((0,0,2.2))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=19 if group=='elite' else 18
    ink=material('Label',(62,55,53))
    def label(body,loc,size):
        d=bpy.data.curves.new(body,'FONT');d.body=body;d.align_x='CENTER';d.size=size
        o=bpy.data.objects.new(body,d);scene.collection.objects.link(o);o.location=loc
        o.rotation_euler=cam.rotation_euler;d.materials.append(ink)
    for key,x in zip(keys,(-4.0,4.0) if len(keys)==2 else (-5.5,0,5.5)):
        path=OUT/key/(key+'.blend')
        report=json.loads((OUT/key/(key+'-report.json')).read_text())
        names=set(report['parts'])|{key+'_Rig'}
        with bpy.data.libraries.load(str(path),link=False) as (src,dst):
            dst.objects=[n for n in src.objects if n in names]
        for o in dst.objects:scene.collection.objects.link(o)
        bpy.context.view_layer.update()
        rig=next(o for o in dst.objects if o.type=='ARMATURE')
        rig.matrix_world=Matrix.Translation((x,0,0))@Matrix.Rotation(math.radians(-22),4,'Z')
        label_y=-6.2 if group=='elite' else -4.7
        label(CONFIG[key]['label'].upper(),(x,label_y,.52),.43)
        label('TIER '+str(CONFIG[key]['tier']),(x,label_y,.10),.20)
    label(('DOG' if group=='dogs' else group.upper())+' GUARDS',(0,1.7,5.70),.48)
    label('BLENDER MODELS  /  RIGGED + EDITABLE',(0,1.7,5.28),.17)
    scene.frame_set(1);bpy.context.view_layer.update()
    scene.render.filepath=str(OUT/(group+'-lineup.png'))
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(group+'-lineup.blend')))
    print('GUARD_LINEUP_READY',group,flush=True)
