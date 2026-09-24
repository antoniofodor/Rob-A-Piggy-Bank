import bpy, json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(root/'assets/piggies/legendary/rainbowtiger/package/rainbowtiger-complete.blend'))
bpy.context.scene.frame_set(1)
for name in ('Tail','TailPlume'):
 o=bpy.data.objects[name]
 vs=[o.matrix_world@v.co for v in o.data.vertices]
 adjacency=[set() for v in vs]
 for e in o.data.edges:
  a,b=e.vertices;adjacency[a].add(b);adjacency[b].add(a)
 print(name,'bounds',[[f(v[i] for v in vs) for i in range(3)] for f in (min,max)])
 print('high degree',[(i,len(a),list(vs[i])) for i,a in enumerate(adjacency) if len(a)>10][:30])
 print('last vertices',[(i,list(vs[i])) for i in range(len(vs)-20,len(vs))])
 if name=='Tail':
  print('TIP neighbors',[(i,list(vs[i])) for i in adjacency[672]])
