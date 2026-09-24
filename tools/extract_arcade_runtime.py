"""Extract authored accessory colors and body-local motion from the approved Blender files."""
import bpy,json,sys
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[1]
HERE=ROOT/'assets/piggies/arcade-build-v1'
specs=json.loads((HERE/'manifest.json').read_text())['skins']
A=Matrix(((-6,0,0,0),(0,0,6,0),(0,6,0,0),(0,0,0,1)))
v2='--v2' in sys.argv
revised={'mechaplayer','finalboss','jackpot'} if v2 else set()
output={}
def srgb(v):return round(255*(12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055))
for s in specs:
    home=HERE.parent/s['tier']/s['key']
    report_path=home/('package/arcade-v2/asset-report.json' if s['key'] in revised else 'package/arcade-v1-asset-report.json')
    report=json.loads(report_path.read_text())
    rows=[p for p in report['parts'] if p['role']=='accessory']
    if not rows:continue
    blend_path=home/'package/arcade-v2'/f"{s['key']}-arcade-v2.blend" if s['key'] in revised else home/'package'/f"{s['key']}-arcade-v1.blend"
    bpy.ops.wm.open_mainfile(filepath=str(blend_path))
    scene=bpy.context.scene;scene.frame_set(1);bpy.context.view_layer.update()
    parts={}
    for row in rows:
        ob=bpy.data.objects[row['name']]
        initial=ob.matrix_world.copy()
        points=[A@initial@v.co for v in ob.data.vertices]
        center=Vector([(min(v[i] for v in points)+max(v[i] for v in points))/2 for i in range(3)])
        size=[max(v[i] for v in points)-min(v[i] for v in points) for i in range(3)]
        mat=ob.data.materials[0];bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        parts[row['name']]={'center':list(center),'size':size,'color':[srgb(c) for c in bs.inputs['Base Color'].default_value[:3]],'metallic':bs.inputs['Metallic'].default_value,'emission':bs.inputs['Emission Strength'].default_value,'samples':[]}
        # Incoming FBX vertices are baked in the mirrored body-local frame.
        # A delta about the original object's pivot also moves all parented armor together.
        for frame in range(1,146,2):
            scene.frame_set(frame);bpy.context.view_layer.update()
            pose=A@ob.matrix_world@initial.inverted()@A.inverted()@Matrix.Translation(center)
            pos,quat,scale=pose.decompose();rot=quat.to_matrix()
            parts[row['name']]['samples'].append([*pos,*[rot[i][j] for i in range(3) for j in range(3)],*scale])
        scene.frame_set(1);bpy.context.view_layer.update()
        samples=parts[row['name']]['samples']
        if max(abs(x-y) for row2 in samples for x,y in zip(row2,samples[0]))<.00001:parts[row['name']]['samples']=[]
    output[s['key']]=parts
(HERE/('runtime-source-v2.json' if v2 else 'runtime-source.json')).write_text(json.dumps(output,separators=(',',':')))
print('Extracted',sum(len(v) for v in output.values()),'parts with authored motion')
