"""Render the source shader directly to distinguish pattern edges from bake seams."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root))
import bpy,bmesh,paths
from mathutils import Vector
key=sys.argv[sys.argv.index('--')+1]
bpy.ops.wm.open_mainfile(filepath=paths.skin_blend(key))
for ob in list(bpy.data.objects):
    if ob.name not in ('Body','Snout','Ears','Legs','Tail','EyePreview'):
        bpy.data.objects.remove(ob,do_unlink=True);continue
    for mod in list(ob.modifiers):ob.modifiers.remove(mod)
    bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
    for p in ob.data.polygons:p.use_smooth=True
    if '--smooth-pattern' in sys.argv:
        for edge in ob.data.edges:edge.use_edge_sharp=False
        if ob.data.has_custom_normals:ob.data.normals_split_custom_set([(0,0,0)]*len(ob.data.loops))
    ob.hide_render=False
    print(ob.name,'sharp edges',sum(e.use_edge_sharp for e in ob.data.edges),'custom normals',ob.data.has_custom_normals,flush=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.view_settings.exposure=0
world=bpy.data.worlds.new('Diagnostic');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.52,.56,.65,1);world.node_tree.nodes['Background'].inputs[1].default_value=.8;scene.world=world
for name,pos,energy,size in [('Key',(-20,-27,35),4500,22),('Fill',(25,-10,16),3000,20),('Rim',(3,22,28),5000,18)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy/36;data.shape='DISK';data.size=size/6
    ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);ob.location=Vector(pos)/6;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Diagnostic');cam=bpy.data.objects.new('Diagnostic',data);scene.collection.objects.link(cam);scene.camera=cam
data.type='ORTHO';data.ortho_scale=20/6;cam.location=Vector((2,24,30))/6;cam.rotation_euler=(Vector((0,1,2))/6-cam.location).to_track_quat('-Z','Y').to_euler()
suffix='_smooth' if '--smooth-pattern' in sys.argv else ''
scene.render.filepath=str(root/'renders'/f'animal_procedural_{key}_spine{suffix}.png');bpy.ops.render.render(write_still=True)
