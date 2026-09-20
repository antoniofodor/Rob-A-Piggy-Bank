"""Read-only UV and modifier audit for an existing animal scene."""
from pathlib import Path
import sys,json
root=Path(__file__).resolve().parent
while not (root/'paths.py').exists():root=root.parent
sys.path.insert(0,str(root))
import paths,bpy
args=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=paths.skin_blend(args[0]))
for name in ('Body','Snout','Ears','Legs','Tail'):
    o=bpy.data.objects[name]
    layers=[]
    for layer in o.data.uv_layers:
        values=[d.uv for d in layer.data]
        layers.append({'name':layer.name,'active':layer==o.data.uv_layers.active,'render':layer.active_render,'bounds':[[min(v[i] for v in values),max(v[i] for v in values)] for i in (0,1)],'outside':sum(any(v[i]<0 or v[i]>1 for i in (0,1)) for v in values)})
    print(json.dumps({'object':name,'uvLayers':layers,'modifiers':[{'type':m.type,'viewport':getattr(m,'levels',None),'render':getattr(m,'render_levels',None),'uvSmooth':getattr(m,'uv_smooth',None)} for m in o.modifiers]}),flush=True)
    import numpy as np
    o.data.calc_loop_triangles();size=1024;coverage=np.zeros((size,size),dtype=np.int32)
    for tri in o.data.loop_triangles:
        a,b,c=np.array([o.data.uv_layers.active.data[i].uv[:] for i in tri.loops])*size
        lo=np.maximum(0,np.floor(np.minimum(np.minimum(a,b),c)).astype(int));hi=np.minimum(size-1,np.ceil(np.maximum(np.maximum(a,b),c)).astype(int))
        x,y=np.meshgrid(np.arange(lo[0],hi[0]+1)+.5,np.arange(lo[1],hi[1]+1)+.5)
        det=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(det)<1e-12:continue
        u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/det
        v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/det
        coverage[lo[1]:hi[1]+1,lo[0]:hi[0]+1]+=(u>1e-5)&(v>1e-5)&(u+v<1-1e-5)
    print('UV_INTERIOR_OVERLAP',name,int((coverage>1).sum()),'of',int((coverage>0).sum()),flush=True)
