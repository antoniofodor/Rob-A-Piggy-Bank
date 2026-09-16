"""Reimport FBX deliverables and check geometry, skinning and motion independently."""
import os
import sys
from pathlib import Path
deps=Path(os.environ.get('GUARD_PYTHON_DEPS','/tmp/guard-blender-python'))
if deps.exists():sys.path.insert(0,str(deps))
import bpy
import json
import math
import struct
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/guards'

def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps=30
    bpy.ops.import_scene.fbx(filepath=str(path),use_anim=True,anim_offset=0)
    bpy.context.view_layer.update()
    rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
    assert len(rigs)==1,(path,'armature count',len(rigs))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    return rigs[0],meshes

def points(meshes):
    deps=bpy.context.evaluated_depsgraph_get();result=[]
    for o in meshes:
        e=o.evaluated_get(deps);m=e.to_mesh()
        result.extend(tuple(e.matrix_world@v.co) for v in m.vertices)
        e.to_mesh_clear()
    return result

def run():
    results=[]
    requested=os.environ.get('GUARD_ONLY')
    reports=sorted(OUT.glob('*/*-report.json'))
    active_keys={p.parent.name for p in reports}
    if requested:reports=[p for p in reports if p.parent.name in requested.split(',')]
    for path in reports:
        report=json.loads(path.read_text());key=report['creature'];folder=path.parent
        rig,meshes=load(folder/(key+'.fbx'))
        assert set(report['bones'])==set(rig.data.bones.keys()),(key,'bone mismatch')
        if key=='cerberus':
            assert report['tier']==5
            for suffix in ('','_Left','_Right'):
                assert rig.data.bones['Jaw'+suffix].parent.name=='Head'+suffix
        assert len(meshes)==len(report['parts']),(key,'mesh count',len(meshes),len(report['parts']))
        assert not rig.animation_data or not rig.animation_data.action,(key,'base has animation')
        total=0
        for o in meshes:
            assert all(math.isfinite(c) for v in o.data.vertices for c in v.co)
            assert any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers),(key,o.name,'unskinned')
            for v in o.data.vertices:
                weights=[g for g in v.groups if g.weight>1e-7]
                assert len(weights)==1 and abs(sum(g.weight for g in weights)-1)<1e-5,(key,o.name,'weights')
                assert o.vertex_groups[weights[0].group].name!='Root'
            o.data.calc_loop_triangles();total+=len(o.data.loop_triangles)
            for t in o.data.loop_triangles:
                a,b,c=[o.data.vertices[i].co for i in t.vertices]
                assert (b-a).cross(c-a).length>1e-10,(key,o.name,'degenerate triangle')
        assert total==report['triangles'],(key,'triangles',total,report['triangles'])
        pts=points(meshes);height=max(p[2] for p in pts)-min(p[2] for p in pts)
        assert abs(height-report['height'])<.015,(key,'roundtrip scale',height,report['height'])
        assert abs(min(p[2] for p in pts))<.015,(key,'ground origin')
        clips={}
        for clip,meta in report['clips'].items():
            rig,meshes=load(folder/(key+'_'+clip+'.fbx'))
            assert rig.animation_data and rig.animation_data.action,(key,clip,'missing animation')
            assert len(bpy.data.actions)==1,(key,clip,'multiple exported clips')
            bpy.context.scene.frame_set(1);start=points(meshes)
            jaw_start={n:rig.pose.bones[n].matrix_basis.to_quaternion() for n in ('Jaw','Jaw_Left','Jaw_Right') if n in rig.pose.bones}
            bpy.context.scene.frame_set(8 if clip=='Chase' else 16 if clip=='Idle' else 13);mid=points(meshes)
            if key=='cerberus' and clip!='Idle':
                for name,q in jaw_start.items():
                    assert q.rotation_difference(rig.pose.bones[name].matrix_basis.to_quaternion()).angle>.005,(key,clip,name,'jaw does not move')
            displacement=max((Vector(a)-Vector(b)).length for a,b in zip(start,mid))
            assert displacement>.005,(key,clip,'no skinned movement')
            bpy.context.scene.frame_set(meta['end']);end=points(meshes)
            if meta['loop']:
                error=max((Vector(a)-Vector(b)).length for a,b in zip(start,end))
                assert error<.001,(key,clip,'loop discontinuity',error)
            clips[clip]={'motionDisplacement':round(displacement,5),'singleClip':True}
        raw=(folder/(key+'.glb')).read_bytes()
        magic,version,length=struct.unpack_from('<4sII',raw)
        assert magic==b'glTF' and version==2 and length==len(raw)
        size,kind=struct.unpack_from('<I4s',raw,12);assert kind==b'JSON'
        doc=json.loads(raw[20:20+size])
        assert doc.get('skins'),(key,'missing GLB skin')
        for mesh in doc['meshes']:
            for primitive in mesh['primitives']:
                assert 'JOINTS_0' in primitive['attributes'] and 'WEIGHTS_0' in primitive['attributes']
        results.append({'creature':key,'triangles':total,'bones':len(report['bones']),'height':round(height,3),'clips':clips,'passed':True})
        print('GUARD_VALIDATED',key,total,'triangles',flush=True)
    assert results,'No deliverables found'
    if requested and (OUT/'validation.json').exists():
        changed={r['creature'] for r in results}
        previous=json.loads((OUT/'validation.json').read_text())
        results.extend(r for r in previous if r['creature'] in active_keys and r['creature'] not in changed)
    results.sort(key=lambda r:r['creature'])
    (OUT/'validation.json').write_text(json.dumps(results,indent=2)+'\n')
    print('ALL_GUARDS_VALIDATED',len(results),flush=True)

if __name__=='__main__':run()
