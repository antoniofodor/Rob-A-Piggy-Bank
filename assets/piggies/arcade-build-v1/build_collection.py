"""Tier rows plus individual review scenes; does not touch open Blender work."""
from pathlib import Path
import bpy,json
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
spec=json.loads((HERE/'design-specs.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.name='ARCADE - expanded collection (10)'
scene.render.fps=24;scene.frame_start=1;scene.frame_end=145
labels=[]
for i,s in enumerate(spec['skins']):
    path=HERE.parent/s['tier']/s['key']/'package'/f"{s['key']}-arcade-v1.blend"
    with bpy.data.libraries.load(str(path),link=False) as (a,b):b.scenes=list(a.scenes)
    source=b.scenes[0];source.frame_set(1)
    tier_skins=[v for v in spec['skins'] if v['tier']==s['tier']]
    index=tier_skins.index(s);row=('rare','epic','legendary').index(s['tier'])
    offset=Vector(((index-(len(tier_skins)-1)/2)*3.5,0,(2-row)*3.7))
    for col in source.collection.children:
        if col.name.startswith(('ASSET','FX','AURA')):
            ob=bpy.data.objects.new(s['key']+' / '+col.name,None);scene.collection.objects.link(ob)
            ob.instance_type='COLLECTION';ob.instance_collection=col;ob.location=offset;ob.rotation_euler.z=-.40
    labels.append((s['name']+' / '+s['tier'].upper(),offset+Vector((0,-.30,-1.36))))
def lin(rgb):return tuple(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb)
world=bpy.data.worlds.new('Arcade overview world');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(*lin((36,28,47)),1);world.node_tree.nodes['Background'].inputs[1].default_value=.65
for name,pos,power,size in [('Key',(-9,-12,16),3700,12),('Fill',(10,-6,8),2300,12),('Rim',(0,5,12),3500,10)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,0,3.5))-ob.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Arcade camera');cam=bpy.data.objects.new('Arcade camera',data);scene.collection.objects.link(cam)
cam.location=(0,-32,12);cam.rotation_euler=(Vector((0,0,3.8))-cam.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=14.9;scene.camera=cam
for label,pos in labels:
    curve=bpy.data.curves.new(label,'FONT');curve.body=label;curve.align_x='CENTER';curve.align_y='CENTER';curve.size=.19
    ob=bpy.data.objects.new(label,curve);scene.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=cam.rotation_euler
    mat=bpy.data.materials.new(label);mat.use_nodes=True;p=mat.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*lin((239,219,188)),1);p.inputs['Emission Color'].default_value=(*lin((239,219,188)),1);p.inputs['Emission Strength'].default_value=.8;curve.materials.append(mat)
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1900;scene.render.resolution_y=1500;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.render.image_settings.file_format='PNG'
bpy.context.window.scene=scene
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False;area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'arcade-collection-v2.blend'))
scene.render.filepath=str(HERE/'arcade-collection-v2.png');bpy.ops.render.render(write_still=True)
print('ARCADE COLLECTION SAVED:',len(spec['skins']),'assets')
