"""Deterministic low-poly meadow kit and connected valley shell. Background Blender.
Canonical coordinates are Roblox studs (X, up Y, Z); export conversion is explicit.
"""
import bpy, bmesh, math, json, random, hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/environment/piggy-meadows/build-v1'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
COLORS = [(137,139,135),(120,125,124),(155,156,145),(94,132,53),(117,157,62),
          (55,113,46),(72,135,52),(89,151,59),(32,89,51),(239,235,211),
          (244,190,33),(123,73,204),(222,74,126),(94,64,42),(165,116,69),
          (65,112,97),(106,139,120),(123,148,137),(82,114,60),(39,74,46),
          (194,51,52),(210,183,133),(80,102,102),(55,63,65)]
im=bpy.data.images.new('MeadowPalette',width=len(COLORS)*8,height=8)
im.pixels=[v for _y in range(8) for c in COLORS for _x in range(8) for v in (*[q/255 for q in c],1)]
im.filepath_raw=str(OUT/'palette.png'); im.file_format='PNG'; im.save(); im.pack()
mat=bpy.data.materials.new('MeadowPalette'); mat.use_nodes=True
node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;node.interpolation='Closest'
bs=mat.node_tree.nodes.get('Principled BSDF');mat.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
bs.inputs['Roughness'].default_value=.9
records={}; objects={}

class Mesh:
    def __init__(self): self.v=[];self.f=[];self.c=[]
    def add(self,verts,faces,color):
        start=len(self.v);self.v.extend(verts)
        self.f.extend([tuple(start+i for i in f) for f in faces]);self.c.extend([color]*len(faces))
    def hull(self,center,size,color,seed=0):
        rng=random.Random(seed);verts=[]
        for y,r in [(0,.78),(.48,1),(1,.52)]:
            for i in range(6):
                a=math.tau*i/6;rr=r*rng.uniform(.88,1.1)
                verts.append((center[0]+math.cos(a)*size[0]*rr/2,center[1]+y*size[1],center[2]+math.sin(a)*size[2]*rr/2))
        bm=bmesh.new()
        for v in verts:bm.verts.new(v)
        bm.verts.ensure_lookup_table();bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
        used=set(v for f in bm.faces for v in f.verts);arr=list(used);idx={v:i for i,v in enumerate(arr)}
        self.add([tuple(v.co) for v in arr],[tuple(idx[v] for v in f.verts) for f in bm.faces],color);bm.free()
    def cone(self,a,b,r0,r1,color,n=6):
        a,b=Vector(a),Vector(b);d=(b-a).normalized();u=d.cross(Vector((0,0,1)))
        if u.length<.01:u=d.cross(Vector((1,0,0)))
        u.normalize();v=d.cross(u)
        verts=[tuple(p+r*(math.cos(i*math.tau/n)*u+math.sin(i*math.tau/n)*v)) for p,r in [(a,r0),(b,r1)] for i in range(n)]
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        self.add(verts,faces,color)
    def leaf(self,at,tip,width,color):
        a,b=Vector(at),Vector(tip);side=(b-a).cross(Vector((0,1,0))).normalized()*width
        mid=a.lerp(b,.48);ridge=mid+Vector((0,width*.25,0))
        self.add([tuple(v) for v in [a,mid+side,b,mid-side,ridge]],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(0,3,2,1)],color)
    def object(self,name,category='meadow'):
        mesh=bpy.data.meshes.new(name);mesh.from_pydata([(x,-z,y) for x,y,z in self.v],[],self.f);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(mat)
        uv=mesh.uv_layers.new(name='PaletteUV')
        for poly,col in zip(mesh.polygons,self.c):
            for li in poly.loop_indices:uv.data[li].uv=((col+.5)/len(COLORS),.5)
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        mesh.calc_loop_triangles()
        lo=[min(p[i] for p in self.v) for i in range(3)];hi=[max(p[i] for p in self.v) for i in range(3)]
        records[name]={'category':category,'size':[hi[i]-lo[i] for i in range(3)],'center':[(hi[i]+lo[i])/2 for i in range(3)],'triangles':len(mesh.loop_triangles)}
        assert len(mesh.loop_triangles)<20000,name
        objects[name]=obj
        return obj

def foliage(m,x,y,z,s=1,seed=0,color=6):m.hull((x,y,z),(s*2,s*1.4,s*1.7),color,seed)
def bloom(m,at,col,kind=0,scale=1):
    x,y,z=at
    if kind==1: # six-sided hanging/open bell
        m.cone((x,y+.25*scale,z),(x,y-.22*scale,z),.14*scale,.37*scale,col)
    elif kind==3:
        for k in range(3):m.hull((x,y+k*.28*scale,z),(.4*scale,.44*scale,.4*scale),10,k)
    else:
        for i in range(5):
            a=i*math.tau/5
            m.leaf((x,y,z),(x+math.cos(a)*.52*scale,y+(.2 if kind==2 else .02)*scale,z+math.sin(a)*.52*scale),.18*scale,col)
        m.cone((x,y-.02,z),(x,y+.12*scale,z),.18*scale,.18*scale,10,8)

# Six rocks, intentionally broad flat facets.
for i,name in enumerate(['RockRounded','RockSplit','RockSlab','RockWedge','RockCluster','Pebbles']):
    m=Mesh()
    sizes=[(5,3.7,4),(4,5,3.4),(6,1.2,4),(3.5,4,3),(5,3,4),(1,.55,.8)]
    if i in (1,4,5):
        for j in range(2 if i==1 else 3 if i==4 else 5):
            s=1-j*.17 if i!=5 else .7+j*.15
            m.hull(((j-.7)*(1.9 if i<5 else 1.1),0,math.sin(j)*.65),tuple(v*s for v in sizes[i]),j%3,33+i*4+j)
    else:m.hull((0,0,0),sizes[i],i%3,24+i)
    # A simple colored top facet, not a mass of additional moss geometry.
    for fi,f in enumerate(m.f):
        if all(m.v[v][1]>sizes[i][1]*.78 for v in f) and fi%2==0:m.c[fi]=3
    m.object(name)

for kind,name in enumerate(['Daisies','Bellflowers','PinkCups','GoldenSpikes']):
    m=Mesh()
    for j in range(4):
        a=j*2.3;x=math.cos(a)*.62;z=math.sin(a)*.55;h=1.25+(j%3)*.35
        m.cone((x,0,z),(x,h,z),.055,.045,8,5)
        for s in (-1,1):m.leaf((x,.25,z),(x+s*.65,.7,z+.3),.22,5+j%3)
        bloom(m,(x,h,z),[9,11,12,10][kind],kind,.8)
    m.object(name)

for kind,name in enumerate(['BushLow','BushTall','BushFlowers','Fern']):
    m=Mesh()
    if kind==3:
        for j in range(7):
            a=j*math.tau/7
            for k in range(1,4):
                t=k/4;at=(math.cos(a)*t,math.sin(t*2)*1.5,math.sin(a)*t)
                for s in (-1,1):m.leaf(at,(math.cos(a+s*.4)*(t+.65),at[1]+.1,math.sin(a+s*.4)*(t+.65)),.18,5+j%3)
    else:
        for j in range(5):
            a=j*math.tau/5;x=math.cos(a)*1.05;z=math.sin(a)*.85;h=1.35 if kind==1 and j%2==0 else 0
            if h:m.cone((0,0,0),(x,h+.3,z),.17,.1,13)
            foliage(m,x,h,z,1 if kind!=0 else .8,40+j,5+j%3)
        if kind==2:
            for j in range(5):bloom(m,(math.cos(j*1.3)*1.2,1.35,math.sin(j*1.3)),12,0,.6)
    m.object(name)

m=Mesh()
for j in range(4):
    x=(j-1.5)*.45;z=math.sin(j)*.35;h=1.8+j*.3
    m.cone((x,0,z),(x,h,z),.04,.03,8,5);m.cone((x,h-.2,z),(x,h+.35,z),.12,.1,13,6)
    m.leaf((x,0,z),(x+.5,h*.8,z+.2),.12,6)
m.object('Reeds')
m=Mesh();m.cone((0,0,0),(0,.08,0),.9,.9,6,8);bloom(m,(.2,.12,0),9,0,.8);m.object('Lily')
m=Mesh();m.cone((-3,.85,0),(3,.85,0),.85,.72,13,8)
m.cone((3,.85,0),(3.03,.85,0),.63,.63,14,8);m.cone((3.04,.85,0),(3.06,.85,0),.35,.35,13,8)
m.cone((0,.8,0),(1,2.1,.45),.32,.18,13,6);m.hull((-.5,1.35,-.3),(2,.2,.9),3,90);m.object('Log')
m=Mesh()
for j in range(3):
    x=(j-1)*.65;h=.65+j*.25
    m.cone((x,0,0),(x,h,0),.1,.1,21,6);m.cone((x,h,0),(x,h+.5,0),.5,.1,20 if j<2 else 21,7)
    if j<2:m.hull((x+.15,h+.22,.15),(.16,.05,.16),9,j)
m.object('Mushrooms')
m=Mesh();m.hull((0,0,0),(10,5,6),1,22);m.hull((3,0,1),(6,2.2,4),0,24);m.object('CascadeLedge')

# A shared perimeter, with chamfered corners and vertices at the tunnel arch.
points=[]
outline=[(216,270),(-216,270),(-252,234),(-252,-234),(-216,-270),(216,-270),(252,-234),(252,234)]
for k,a in enumerate(outline):
    b=outline[(k+1)%len(outline)];length=math.dist(a,b);count=math.ceil(length/24)
    ts=[i/count for i in range(count)]
    if a[0]==b[0]:
        ts += [(z-a[1])/(b[1]-a[1]) for z in [-28,-11,-7,0,7,11,28] if 0<(z-a[1])/(b[1]-a[1])<1]
    for t in sorted(set(ts)):points.append((a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t))
n=len(points)
loops=[]
for ring in range(8):
    row=[]
    for i,(x,z) in enumerate(points):
        a=math.atan2(z/270,x/252);h=32+5*math.sin(a*3+.4)+3*math.sin(a*7)
        offsets=[0,2,7,45,150,280,470,800];off=offsets[ring]
        # Rounded rectangle expansion: same vertex identity across every layer.
        sx=x*(1+off/252);sz=z*(1+off/270)
        ys=[-9,h*.52,h,h+3+math.sin(a*5)*3,12+5*math.sin(a*4),75+30*math.sin(a*5+.8)**2,24+12*math.sin(a*4),-35]
        y=ys[ring]
        if ring==0 and abs(x)==252 and abs(z)<=11:y=10+(11-abs(z)) if abs(z)>=7 else 14
        row.append((sx,y,sz))
    loops.append(row)
border=Mesh()
for i in range(n):
    j=(i+1)%n
    for ring in range(7):
        col=(i%3 if ring<2 else [3,18,18,16,17][ring-2])
        border.add([loops[ring][i],loops[ring][j],loops[ring+1][j],loops[ring+1][i]],[(0,1,2),(0,2,3)],col)
# Split into spatial strips so each imported MeshPart stays within Roblox size limits.
for chunk in range(12):
    m=Mesh();start=math.floor(chunk*n/12);end=math.floor((chunk+1)*n/12)
    for i in range(start,end):
        for ring in range(7):
            fi=(i*7+ring)*2
            for face,col in zip(border.f[fi:fi+2],border.c[fi:fi+2]):m.add([border.v[v] for v in face],[(0,1,2)],col)
    m.object(f'Border_{chunk+1:02}','border')

catalog={'version':1,'authoring':{'tunnelX':252,'edgeZ':270,'groundY':-.5},'parts':records,
         'boundary':[{'x':x,'z':z,'height':loops[2][i][1]} for i,(x,z) in enumerate(points)]}
for category in ['meadow','border']:
    bpy.ops.object.select_all(action='DESELECT')
    for name,obj in objects.items():obj.select_set(records[name]['category']==category)
    path=OUT/(category+'.fbx')
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=.01,
        apply_unit_scale=True,axis_forward='-Z',axis_up='Y',path_mode='COPY',embed_textures=True,
        use_mesh_modifiers=True,bake_anim=False)
    catalog[category]={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(OUT/'catalog.json').write_text(json.dumps(catalog,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'meadows-and-border.blend'))

# Honest mesh preview: arrange copies of the kit on a neutral plane.
for obj in objects.values():obj.hide_render=True
for i,(name,obj) in enumerate((p for p in objects.items() if records[p[0]]['category']=='meadow')):
    cp=obj.copy();cp.data=obj.data;cp.hide_render=False;bpy.context.collection.objects.link(cp)
    cp.location=(i%5*10,-(i//5)*9,0)
bpy.ops.mesh.primitive_plane_add(size=200,location=(20,-13,-.08));plane=bpy.context.object
base=bpy.data.materials.new('PreviewGround');base.diffuse_color=(.55,.58,.48,1);plane.data.materials.append(base)
bpy.ops.object.light_add(type='AREA',location=(15,-10,35));bpy.context.object.data.energy=9000;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=25
bpy.ops.object.camera_add(location=(47,-59,48));cam=bpy.context.object;cam.rotation_euler=(Vector((20,-13,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=58
scene=bpy.context.scene;scene.camera=cam;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.world.color=(.5,.5,.5);scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.render.filepath=str(OUT/'kit-preview.png');bpy.ops.render.render(write_still=True)
print('MEADOW_BUILD_OK',len(records),'meshes',sum(p['triangles'] for p in records.values()),'triangles')
