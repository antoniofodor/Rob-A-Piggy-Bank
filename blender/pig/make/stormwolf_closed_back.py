"""Blend the old tail attachment into the intact, opposite rear haunch."""
import math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

def repair(body):
    mesh=body.data;mesh.calc_loop_triangles()
    vertices=[v.co.copy() for v in mesh.vertices]
    triangles=list(mesh.loop_triangles)
    uv=mesh.uv_layers.active
    original_uv=[x.uv.copy() for x in uv.data]
    tree=BVHTree.FromPolygons(vertices,[tuple(t.vertices) for t in triangles],all_triangles=True)
    def sample(co):
        hit=tree.ray_cast(Vector((-abs(co.x),3,co.z)),Vector((0,-1,0)),3)
        assert hit[0] is not None,tuple(co)
        t=triangles[hit[2]]
        mapped=barycentric_transform(hit[0],*(vertices[i] for i in t.vertices),
            *(Vector((*original_uv[i],0)) for i in t.loops))
        return hit[0].y,Vector((mapped.x,mapped.y))
    moved=set()
    for v in mesh.vertices:
        if v.co.y<.65:continue
        r=math.sqrt(((v.co.x-.17)/.25)**2+((v.co.z+.412)/.19)**2)
        if r>=1:continue
        # Full restoration at the former root; eased into surrounding hide.
        t=max(0,min(1,(1-r)/.4));weight=t*t*(3-2*t)
        y,_=sample(v.co)
        v.co.y+=(y-v.co.y)*weight
        moved.add(v.index)
    faces=set()
    for p in mesh.polygons:
        if p.material_index==2 or any(i in moved for i in p.vertices):
            for li in p.loop_indices:
                _,mapped=sample(mesh.vertices[mesh.loops[li].vertex_index].co)
                uv.data[li].uv=mapped
            p.material_index=0;p.use_smooth=True;faces.add(p.index)
    mesh.update()
    return faces
