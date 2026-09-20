"""Read-only scene inventory for aligning Storm Wolf with the piggy fixtures."""
from pathlib import Path
import bpy,json,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
for relative in ('skins/stormwolf/stormwolf.blend','pig/pig_parts.blend','pig/pig_stormwolf_bolts.blend'):
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/relative))
    rows=[]
    for ob in bpy.context.scene.objects:
        if ob.type!='MESH':continue
        points=[ob.matrix_world@v.co for v in ob.data.vertices]
        bm=bmesh.new();bm.from_mesh(ob.data)
        rows.append(dict(name=ob.name,vertices=len(points),triangles=sum(len(p.vertices)-2 for p in ob.data.polygons),
            bounds={k:[round(fn(p[i] for p in points),5) for i in range(3)] for k,fn in [('min',min),('max',max)]},
            nonManifold=sum(not e.is_manifold for e in bm.edges),uv=[u.name for u in ob.data.uv_layers],
            location=list(ob.location),scale=list(ob.scale),materials=[m.name for m in ob.data.materials if m],
            images=[n.image.filepath for m in ob.data.materials if m and m.node_tree for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]))
        bm.free()
        if relative.startswith('skins/'):
            bm=bmesh.new();bm.from_mesh(ob.data);bm.transform(ob.matrix_world)
            tree=BVHTree.FromBMesh(bm)
            for direction in ((0,1,0),(0,0,1),(0,0,-1),(1,0,0),(-1,0,0),(0,.94854,-.31667)):
                d=Vector(direction).normalized();hit=tree.ray_cast(Vector((0,0,0)),d)
                print('SURFACE_RAY',direction,tuple(hit[0]) if hit[0] else None)
            print('BOUNDARY_EDGES',[(tuple(e.verts[0].co),tuple(e.verts[1].co),len(e.link_faces)) for e in bm.edges if not e.is_manifold])
            pending=set(bm.verts);components=[]
            while pending:
                queue=[pending.pop()];component=[]
                while queue:
                    v=queue.pop();component.append(v)
                    for e in v.link_edges:
                        w=e.other_vert(v)
                        if w in pending:pending.remove(w);queue.append(w)
                components.append(len(component))
            print('COMPONENT_SIZES',sorted(components,reverse=True));bm.free()
    print('SCENE_INVENTORY',relative,json.dumps(rows),flush=True)
