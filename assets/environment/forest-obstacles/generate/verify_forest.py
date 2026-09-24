"""Geometry, palette, FBX-scale, and open-passage checks in Blender."""
from pathlib import Path
import json
import math
import bpy
import bmesh
from mathutils import Vector,Euler
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
catalog=json.loads((ROOT/'catalog.json').read_text())
results={};failures=[]

def measure(obj):
    verts=[obj.matrix_world@v.co for v in obj.data.vertices]
    return [[min(v[k] for v in verts) for k in range(3)],
            [max(v[k] for v in verts) for k in range(3)]]

def inspect(obj):
    obj.data.calc_loop_triangles()
    assert all(t.area>1e-9 for t in obj.data.loop_triangles),obj.name+' degenerate triangle'
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges),obj.name+' nonmanifold'
    assert bm.calc_volume(signed=True)>0,obj.name+' volume'
    bm.free()
    assert all(not p.use_smooth for p in obj.data.polygons)
    assert len(obj.data.materials)==1 and len(obj.data.uv_layers)==1
    images=[n.image for n in obj.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE']
    # FBX imports the RGBA atlas into color and alpha image nodes; both must
    # reference the same opaque palette, not an additional material map.
    assert images and all(tuple(im.size)==(512,32) for im in images)
    assert len({Path(bpy.path.abspath(im.filepath)).resolve() for im in images})==1
    return len(obj.data.loop_triangles)

def hits_box(start,end,spec):
    rot=Euler(tuple(math.radians(a) for a in spec['rotation_degrees']),'XYZ').to_matrix()
    start=rot.transposed()@(start-Vector(spec['center']))
    end=rot.transposed()@(end-Vector(spec['center']))
    delta=end-start;lo,hi=0.0,1.0
    for k in range(3):
        half=spec['size'][k]/2
        if abs(delta[k])<1e-10:
            if start[k]<-half or start[k]>half:return False
        else:
            a,b=sorted(((-half-start[k])/delta[k],(half-start[k])/delta[k]))
            lo=max(lo,a);hi=min(hi,b)
            if lo>hi:return False
    return True

for key,spec in catalog['assets'].items():
    out=ROOT/key
    bpy.ops.wm.open_mainfile(filepath=str(out/(key+'.blend')))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(objects)==1,key
    obj=objects[0];tri=inspect(obj);assert tri==spec['triangles'] and tri<6000
    original=measure(obj)
    report={'triangles':tri,'source':'passed','flat_shading':'passed',
            'closed_manifold':'passed','palette':'passed','collision_parts':len(spec['collision'])}
    if spec['passage']:
        p=spec['passage'];verts=[tuple(v.co) for v in obj.data.vertices]
        faces=[tuple(f.vertices) for f in obj.data.polygons]
        bvh=BVHTree.FromPolygons(verts,faces)
        nw=math.ceil(p['clear_width']/.25);nh=math.ceil(p['clear_height']/.25)
        total=0;visual=[];physics=[]
        for i in range(nw+1):
            across=-p['clear_width']/2+.06+(p['clear_width']-.12)*i/nw
            for j in range(nh+1):
                height=p['floor_y']+.07+(p['clear_height']-.14)*j/nh
                if p['axis']=='X':
                    a=Vector((-p['length']/2,height,across));b=Vector((p['length']/2,height,across))
                else:
                    a=Vector((across,height,-p['length']/2));b=Vector((across,height,p['length']/2))
                ab=Vector((a.x,-a.z,a.y));bb=Vector((b.x,-b.z,b.y));d=bb-ab
                hit=bvh.ray_cast(ab,d.normalized(),d.length)
                if hit[0] is not None:visual.append([across,height])
                for collider in spec['collision']:
                    if hits_box(a,b,collider):
                        physics.append([across,height,collider['name']]);break
                total+=1
        report['passage']={'rays':total,'visual_obstructions':visual[:10],
            'collision_obstructions':physics[:10],'visual_hits':len(visual),'collision_hits':len(physics),
            'width':p['clear_width'],'height':p['clear_height'],'floor_y':p['floor_y']}
        if visual or physics:failures.append(key)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(out/(key+'.fbx')))
    imported=list(bpy.context.scene.objects);assert len(imported)==1
    assert inspect(imported[0])==tri
    actual=measure(imported[0])
    for before,after in zip(sum(original,[]),sum(actual,[])):
        assert abs(before*.01-after)<.00002,(key,before,after)
    report['fbx_round_trip']='passed; world bounds match source x 0.01 export scale'
    results[key]=report
    print('CHECKED',key,flush=True)

results={'assets':results,'failures':failures,'total_triangles':sum(s['triangles'] for s in catalog['assets'].values()),
    'limitations':['Offline geometry and collision checks; not a live character playtest.',
                   'Default convex mesh collisions must be disabled; use supplied collision models.']}
(ROOT/'validation.json').write_text(json.dumps(results,indent=2)+'\n')
assert not failures,failures
print('FOREST_VALIDATION_PASSED',results['total_triangles'],flush=True)
