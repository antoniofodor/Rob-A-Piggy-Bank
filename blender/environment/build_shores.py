"""Bake the measured basin banks into flat-shaded meshes instead of many wedges."""
import bpy, math, json, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/environment/piggy-meadows/build-v1'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
data=json.loads((OUT/'shore-layout.json').read_text());catalog=json.loads((OUT/'catalog.json').read_text())
catalog['parts']={name:p for name,p in catalog['parts'].items() if p['category']!='shore'}
im=bpy.data.images.load(str(OUT/'palette.png'));im.pack()
mat=bpy.data.materials.new('MeadowPalette');mat.use_nodes=True
node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;node.interpolation='Closest'
mat.node_tree.links.new(node.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
def mesh(name,quads):
    verts=[];faces=[];colors=[]
    for q,col in quads:
        # Canonical Y is up. A bank's visible side must face the sky, including
        # both mirrored stream banks; DoubleSided does not fix inverted lighting.
        a=[q[1][k]-q[0][k] for k in range(3)];b=[q[2][k]-q[0][k] for k in range(3)]
        if a[2]*b[0]-a[0]*b[2]<0:q=list(reversed(q))
        i=len(verts);verts.extend(q);faces.extend([(i,i+1,i+2),(i,i+2,i+3)]);colors.extend([col,col])
    assert all(math.isfinite(v) for p in verts for v in p)
    m=bpy.data.meshes.new(name);m.from_pydata([(x,-z,y) for x,y,z in verts],[],faces);m.materials.append(mat)
    uv=m.uv_layers.new(name='PaletteUV')
    for poly,col in zip(m.polygons,colors):
        for i in poly.loop_indices:uv.data[i].uv=((col+.5)/24,.5)
    obj=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(obj)
    lo=[min(p[i] for p in verts) for i in range(3)];hi=[max(p[i] for p in verts) for i in range(3)]
    catalog['parts'][name]={'category':'shore','size':[hi[i]-lo[i] for i in range(3)],'center':[(lo[i]+hi[i])/2 for i in range(3)],'triangles':len(faces)}
stream=data['stream']
for index,p in enumerate(data['ponds'],1):
    r=p['radius']*1.15+4;x0=math.floor((p['x']-r)/4)*4;x1=math.ceil((p['x']+r)/4)*4
    z0=math.floor((p['z']-r)/4)*4;z1=math.ceil((p['z']+r)/4)*4
    angles=[i*math.tau/24 for i in range(24)]+[math.atan2(z-p['z'],x-p['x'])%math.tau for x in [x0,x1] for z in [z0,z1]]
    angles=sorted(set(angles));rings=[[],[],[]];quads=[]
    for a in angles:
        dx,dz=math.cos(a),math.sin(a)
        tx=math.inf if abs(dx)<1e-7 else ((x1 if dx>0 else x0)-p['x'])/dx
        tz=math.inf if abs(dz)<1e-7 else ((z1 if dz>0 else z0)-p['z'])/dz
        t=min(tx,tz);rr=p['radius']*(1+.1*math.sin(a*3+p['side']))
        rings[0].append((p['x']+dx*t,-.47,p['z']+dz*t))
        rings[1].append((p['x']+dx*rr*1.10,-.52,p['z']+dz*rr*.86*1.10))
        rings[2].append((p['x']+dx*rr*.87,-2.5,p['z']+dz*rr*.86*.87))
    for i in range(len(angles)):
        j=(i+1)%len(angles);mid=[(rings[2][i][k]+rings[2][j][k])/2 for k in range(3)]
        outlet=p['side']==1 and mid[2]>p['z'] and abs(mid[0]-stream['x'])<stream['halfWidth']+2
        if not outlet:
            for ring,col in [(0,18),(1,3)]:quads.append(([rings[ring][i],rings[ring][j],rings[ring+1][j],rings[ring+1][i]],col))
    mesh(f'Shore_{index:02}',quads)
quads=[]
for side in [-1,1]:
    outer=math.floor((stream['x']-stream['halfWidth']-4)/4)*4 if side<0 else math.ceil((stream['x']+stream['halfWidth']+4)/4)*4
    inner=stream['x']+side*stream['halfWidth'];z0=stream['bankStart'];z1=stream['z1']
    quads.append(([(outer,-.47,z0),(outer,-.47,z1),(inner,-2.5,z1),(inner,-2.5,z0)],3))
mesh(f"Shore_{len(data['ponds'])+1:02}",quads)
bpy.ops.object.select_all(action='SELECT');path=OUT/'shore-wide-v2.fbx'
bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=.01,apply_unit_scale=True,axis_forward='-Z',axis_up='Y',path_mode='COPY',embed_textures=True,bake_anim=False)
catalog['shore']={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(OUT/'catalog.json').write_text(json.dumps(catalog,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'shorelines.blend'))
print('SHORES_OK',sum(p['triangles'] for p in catalog['parts'].values() if p['category']=='shore'),'triangles')
