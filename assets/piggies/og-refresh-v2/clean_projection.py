"""Suppress internal shell intersections when viewing the translucent pigs."""
from pathlib import Path
import bpy,sys,argparse,json
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
p=argparse.ArgumentParser();p.add_argument('--skin',required=True);p.add_argument('--draft',action='store_true');args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
key=args.skin;home=ROOT/'assets/piggies/epic'/key/'revisions/og-v2';path=home/'package'/f'{key}-og-v2.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));scene=bpy.context.scene
materials={m for name in ('Body','Snout','Ears','Legs','Tail') for m in bpy.data.objects[name].data.materials}
for m in materials:
    if m.node_tree.nodes.get('Outer visible surface only'):continue
    nt=m.node_tree;bs=nt.nodes['Principled BSDF'];old=bs.inputs['Alpha'].links[0].from_socket
    ray=nt.nodes.new('ShaderNodeLightPath');limit=nt.nodes.new('ShaderNodeMath');limit.operation='LESS_THAN';limit.inputs[1].default_value=.5
    nt.links.new(ray.outputs['Transparent Depth'],limit.inputs[0])
    mul=nt.nodes.new('ShaderNodeMath');mul.name='Outer visible surface only';mul.operation='MULTIPLY'
    nt.links.new(old,mul.inputs[0]);nt.links.new(limit.outputs[0],mul.inputs[1]);nt.links.new(mul.outputs[0],bs.inputs['Alpha'])
scene.frame_set(1)
if args.draft:
    scene.render.resolution_x=480;scene.render.resolution_y=480;scene.cycles.samples=6
    scene.render.filepath=str(HERE/f'{key}-projection-draft.png');bpy.ops.render.render(write_still=True)
else:
    scene['translucency']='Outer visible surface only; hidden internal pig shells suppressed'
    scene.cycles.samples=16
    shots=[('hero',(-4,-6,2.8)),('back',(-4,6,2.8)),('top',(-3,-4,6))]
    for label,pos in shots:
        scene.camera.location=pos;scene.camera.rotation_euler=(Vector((0,0,.08))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(home/'preview'/f'{key}-og-v2-{label}.png');bpy.ops.render.render(write_still=True)
    scene.camera.location=shots[0][1];scene.camera.rotation_euler=(Vector((0,0,.08))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    scene.frame_set(37);scene.render.filepath=str(home/'preview'/f'{key}-og-v2-motion.png');bpy.ops.render.render(write_still=True);scene.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(path))
    report_path=home/'package/og-v2-asset-report.json';report=json.loads(report_path.read_text());report['translucency']='Outer visible surface with suppressed internal intersections; Blender shader effect'
    report_path.write_text(json.dumps(report,indent=2)+'\n')
print('PROJECTION_CLEANED',key,args.draft,flush=True)
