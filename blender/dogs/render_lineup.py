"""Render the three authored meshes at their actual relative sizes."""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector, Matrix

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from build_dogs import OUT, material, lighting, BREEDS

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
camera=lighting(scene)
scene.render.resolution_x=1600;scene.render.resolution_y=960
scene.cycles.samples=16
camera.location=(0,-23,10)
camera.rotation_euler=(Vector((0,0,1.8))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=17.0
for name,pos,energy,size in [('Key softbox',(-6,-8,12),2500,9),('Fill softbox',(8,-4,8),1900,8),('Rim softbox',(1,7,11),2200,8)]:
    o=bpy.data.objects[name];o.location=pos;o.data.energy=energy;o.data.size=size
    o.rotation_euler=(Vector((0,0,1.5))-o.location).to_track_quat('-Z','Y').to_euler()
ink=material('Preview labels',(38,49,61))
muted=material('Preview label secondary',(82,98,109))

def text_obj(text,loc,size,mat):
    curve=bpy.data.curves.new(text,'FONT');curve.body=text;curve.size=size;curve.align_x='CENTER'
    obj=bpy.data.objects.new(text,curve);scene.collection.objects.link(obj)
    obj.location=loc;obj.rotation_euler=camera.rotation_euler;curve.materials.append(mat)

all_meshes=[]
for breed,x in [('terrier',-5.0),('shepherd',0),('mastiff',5.0)]:
    info=json.loads((OUT/breed/(breed+'-report.json')).read_text())
    names=set(info['parts'])
    with bpy.data.libraries.load(str(OUT/breed/(breed+'.blend')),link=False) as (src,dst):
        dst.objects=[name for name in src.objects if name in names]
    transform=Matrix.Translation((x,0,0))@Matrix.Rotation(math.radians(-27),4,'Z')
    for obj in dst.objects:
        scene.collection.objects.link(obj)
    # Appended objects need evaluation before reading their world matrices.
    bpy.context.view_layer.update()
    for obj in dst.objects:
        obj.matrix_world=transform@obj.matrix_world
        all_meshes.append(obj)
    text_obj(BREEDS[breed]['label'].upper(),(x,-3.8,.48),.46,ink)
    text_obj(breed.upper(),(x,-3.8,.10),.20,muted)
text_obj('GUARD DOGS',(0,2.1,5.0),.53,ink)
text_obj('SCRUFFY  /  REX  /  TITAN',(0,2.1,4.57),.19,muted)
scene.render.filepath=str(OUT/'dogs-lineup.png')
bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in all_meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=all_meshes[0]
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dogs-lineup.blend'))
print('DOG_LINEUP_READY',flush=True)
