from pathlib import Path
import bpy,json
p=Path(__file__).resolve().parents[1]/'pig/pig_parts.blend'
bpy.ops.wm.open_mainfile(filepath=str(p))
out={}
for name in ['Body','Snout','Legs','EyePreview']:
    ob=bpy.data.objects[name];verts=ob.data.vertices
    groups=[];remaining=set(range(len(verts)));neighbors={v.index:set() for v in verts}
    for e in ob.data.edges:
        x,y=e.vertices;neighbors[x].add(y);neighbors[y].add(x)
    while remaining:
        todo=[remaining.pop()];part=[]
        while todo:
            v=todo.pop();part.append(v)
            for n in neighbors[v]:
                if n in remaining:remaining.remove(n);todo.append(n)
        pts=[ob.matrix_world@verts[i].co for i in part]
        groups.append(dict(vertices=len(part),min=[min(v[a] for v in pts) for a in range(3)],max=[max(v[a] for v in pts) for a in range(3)]))
    out[name]=groups
print('BASE_BOUNDS',json.dumps(out))
