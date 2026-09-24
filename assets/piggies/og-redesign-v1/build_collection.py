"""Assemble the completed assets into one Blender file with 15 individual scenes."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
spec=json.loads((HERE/'design-specs.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
gallery=bpy.context.scene;gallery.name='OG COLLECTION - 15 redesigns'
gallery.render.fps=24;gallery.frame_start=1;gallery.frame_end=145
tiers=('rare','epic','legendary')
labels=[]
for row,tier in enumerate(tiers):
    skins=[s for s in spec['skins'] if s['tier']==tier]
    for i,s in enumerate(skins):
        path=ROOT/'assets/piggies'/tier/s['key']/'package'/f"{s['key']}-og-v1.blend"
        with bpy.data.libraries.load(str(path),link=False) as (a,b):b.scenes=list(a.scenes)
        source=b.scenes[0];source.frame_set(1)
        offset=Vector(((i-(len(skins)-1)/2)*3.55,0,(2-row)*3.5))
        for collection in source.collection.children:
            if collection.name.startswith(('ASSET','FX','AURA')):
                ob=bpy.data.objects.new(s['key']+' / '+collection.name,None)
                gallery.collection.objects.link(ob);ob.instance_type='COLLECTION';ob.instance_collection=collection
                ob.location=offset;ob.rotation_euler.z=-.38
        labels.append((s['name'],tier,offset+Vector((0,-.30,-1.40))))

def lin(rgb):return tuple(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb)
world=bpy.data.worlds.new('CollectionWorld');world.use_nodes=True;gallery.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(*lin((44,48,64)),1)
world.node_tree.nodes['Background'].inputs[1].default_value=.7
for name,pos,energy,size in [('Key',(-9,-12,16),7000,12),('Fill',(12,-6,8),4200,13),('Rim',(0,5,12),6200,10)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);gallery.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,0,3))-ob.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('CollectionCamera');camera=bpy.data.objects.new('CollectionCamera',data);gallery.collection.objects.link(camera)
camera.location=(0,-32,12);camera.rotation_euler=(Vector((0,0,3.4))-camera.location).to_track_quat('-Z','Y').to_euler()
data.type='ORTHO';data.ortho_scale=22;gallery.camera=camera
for name,tier,pos in labels:
    curve=bpy.data.curves.new(name,'FONT');curve.body=name;curve.align_x='CENTER';curve.align_y='CENTER';curve.size=.23
    ob=bpy.data.objects.new(name+' label',curve);gallery.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=camera.rotation_euler
    mat=bpy.data.materials.new(tier+' label');mat.use_nodes=True
    color={'rare':(163,198,236),'epic':(206,167,235),'legendary':(237,199,126)}[tier]
    p=mat.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*lin(color),1);p.inputs['Emission Color'].default_value=(*lin(color),1);p.inputs['Emission Strength'].default_value=.8
    curve.materials.append(mat)
gallery.render.engine='CYCLES';gallery.cycles.samples=24;gallery.cycles.use_denoising=True
gallery.render.resolution_x=2100;gallery.render.resolution_y=1200;gallery.render.resolution_percentage=100
gallery.view_settings.view_transform='Standard';gallery.view_settings.look='None'
gallery.render.image_settings.file_format='PNG';gallery.render.film_transparent=False
bpy.context.window.scene=gallery
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False;area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'og-collection-v1.blend'))
gallery.render.filepath=str(HERE/'og-collection-v1.png');bpy.ops.render.render(write_still=True)
print('OG COLLECTION SAVED: 15 assets, 15 individual scenes plus overview',flush=True)
