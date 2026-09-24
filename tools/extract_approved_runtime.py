"""Read approved Blender poses and materials in the existing Roblox import frame."""
import bpy,json,sys
from pathlib import Path
from mathutils import Matrix,Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from approved_skin_batch import HERE,SPECS,report
A=Matrix(((-6,0,0,0),(0,0,6,0),(0,6,0,0),(0,0,0,1)))
def srgb(v):return round(255*(12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055))
output={}
for spec in SPECS:
    bpy.ops.wm.open_mainfile(filepath=str(spec['blend']))
    scene=bpy.context.scene;scene.frame_set(1);bpy.context.view_layer.update()
    parts={};coats={}
    for name in ('Body','Snout'):
        bs=bpy.data.objects[name].data.materials[0].node_tree.nodes.get('Principled BSDF')
        coats['body' if name=='Body' else 'trim']={'emission':bs.inputs['Emission Strength'].default_value}
    for row in report(spec)['parts']:
        if row['role']!='accessory':continue
        ob=bpy.data.objects[row['name']];initial=ob.matrix_world.copy()
        points=[A@initial@v.co for v in ob.data.vertices]
        center=Vector([(min(v[i] for v in points)+max(v[i] for v in points))/2 for i in range(3)])
        size=[max(v[i] for v in points)-min(v[i] for v in points) for i in range(3)]
        mat=ob.data.materials[0];bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        images=[Path(bpy.path.abspath(n.image.filepath)).name for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
        part={'center':list(center),'size':size,'color':[srgb(c) for c in bs.inputs['Base Color'].default_value[:3]],'metallic':bs.inputs['Metallic'].default_value,'roughness':bs.inputs['Roughness'].default_value,'emission':bs.inputs['Emission Strength'].default_value,'images':images,'samples':[]}
        for frame in range(1,146,2):
            scene.frame_set(frame);bpy.context.view_layer.update()
            pose=A@ob.matrix_world@initial.inverted()@A.inverted()@Matrix.Translation(center)
            pos,quat,scale=pose.decompose();rot=quat.to_matrix()
            part['samples'].append([*pos,*[rot[i][j] for i in range(3) for j in range(3)],*scale])
        scene.frame_set(1);bpy.context.view_layer.update()
        if max(abs(x-y) for sample in part['samples'] for x,y in zip(sample,part['samples'][0]))<.00001:part['samples']=[]
        parts[row['name']]=part
    output[spec['key']]={'parts':parts,'coats':coats}
(HERE/'runtime-source.json').write_text(json.dumps(output,separators=(',',':')))
print('Extracted approved parts:',{key:len(v['parts']) for key,v in output.items()})
