"""Build the large forest obstacle kit in Blender; coordinates are Roblox studs.

Authoring (x,y,z) -> Blender (x,-z,y). One palette-mapped visual mesh per
asset, separate primitive collision records, and no changes to the live game.
"""
from pathlib import Path
import math
import random
import json
import struct
import zlib
import sys
import bpy
import bmesh
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
ROOT.mkdir(parents=True,exist_ok=True)
COLORS = [(137,139,135),(120,125,124),(155,156,145),(94,132,53),
          (117,157,62),(55,113,46),(72,135,52),(89,151,59),
          (32,89,51),(94,64,42),(117,82,57),(165,116,69),
          (210,183,133),(185,143,92),(65,43,30),(239,235,211)]
NAMES = ['stone','stone-dark','stone-light','moss','moss-light','leaf-dark',
         'leaf','leaf-light','pine','bark','bark-light','wood-dark','wood',
         'wood-ring','interior','cream']
CATALOG = {}

def make_palette():
    def chunk(kind,data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    width,height = 512,32
    row = b''.join(bytes((*rgb,255))*32 for rgb in COLORS)
    data = b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))
    data += chunk(b'IDAT',zlib.compress((b'\x00'+row)*height))+chunk(b'IEND',b'')
    (ROOT/'forest-palette.png').write_bytes(data)

def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    image=bpy.data.images.load(str(ROOT/'forest-palette.png'))
    image.pack()
    mat=bpy.data.materials.new('ForestPalette')
    mat.diffuse_color=(1,1,1,1)
    mat.use_nodes=True
    node=mat.node_tree.nodes.new('ShaderNodeTexImage')
    node.image=image;node.interpolation='Closest'
    bs=mat.node_tree.nodes.get('Principled BSDF')
    mat.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value=.92
    return mat

def cv(p):return (p[0],-p[2],p[1])

class Mesh:
    def __init__(self):self.v=[];self.f=[];self.c=[]
    def add(self,v,f,c):
        off=len(self.v);self.v.extend(v)
        self.f.extend(tuple(off+i for i in face) for face in f)
        self.c.extend(c if isinstance(c,list) else [c]*len(f))
    def hull(self,base,size,seed=0,color=0,moss=False):
        rng=random.Random(seed);points=[]
        for y,ratio,shift in [(0,.74,0),(.33,1,.12),(.74,.88,-.10),(1,.54,.08)]:
            for i in range(9):
                a=i*math.tau/9
                r=ratio*rng.uniform(.91,1.07)
                points.append((base[0]+math.cos(a)*size[0]*r/2+shift*size[0],
                    base[1]+y*size[1],base[2]+math.sin(a)*size[2]*r/2))
        bm=bmesh.new()
        for p in points:bm.verts.new(p)
        bm.verts.ensure_lookup_table()
        bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
        used=list({v for face in bm.faces for v in face.verts});index={v:i for i,v in enumerate(used)}
        verts=[tuple(v.co) for v in used];faces=[];colors=[]
        for i,face in enumerate(bm.faces):
            faces.append(tuple(index[v] for v in face.verts))
            mean=sum(v.co.y for v in face.verts)/len(face.verts)
            colors.append((3 if i%4 else 4) if moss and mean>base[1]+size[1]*.78 else color)
        self.add(verts,faces,colors);bm.free()
    def tube(self,points,radii,color=9,sides=10,cap=True):
        pts=[Vector(p) for p in points];verts=[]
        for i,p in enumerate(pts):
            tangent=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
            guide=Vector((0,0,1))
            if abs(guide.dot(tangent))>.95:guide=Vector((1,0,0))
            u=(guide-tangent*guide.dot(tangent)).normalized();v=tangent.cross(u)
            r=radii[i] if isinstance(radii,list) else radii
            verts.extend(tuple(p+r*(math.cos(j*math.tau/sides)*u+math.sin(j*math.tau/sides)*v)) for j in range(sides))
        faces=[];colors=[]
        for k in range(len(pts)-1):
            for j in range(sides):
                faces.append((k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j))
                colors.append(color if j%4 else min(color+1,15))
        if cap:
            faces.extend([tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+j for j in range(sides))])
            colors.extend([color,11 if color in (9,10) else color])
        self.add(verts,faces,colors)
    def stump(self,x,z,r,h,seed=0):
        n=14;rng=random.Random(seed)
        perturb=[rng.uniform(.95,1.05) for _ in range(n)]
        profiles=[(0,r*1.1),(.15,r*1.06),(h-.12,r),(h,r*.92),
                  (h,r*.82),(h,r*.66),(h,r*.62),(h,r*.40),(h,r*.36),(h,r*.08)]
        verts=[]
        for k,(y,rad) in enumerate(profiles):
            verts.extend((x+rad*math.cos(i*math.tau/n)*(perturb[i] if k<4 else 1),y,
                          z+rad*math.sin(i*math.tau/n)*(perturb[i] if k<4 else 1)) for i in range(n))
        faces=[tuple(reversed(range(n)))];colors=[9]
        for k in range(len(profiles)-1):
            col=9 if k<2 else [11,12,12,13,12,13,12][k-2]
            for i in range(n):
                faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
                colors.append(10 if k<2 and i%4==0 else col)
        faces.append(tuple((len(profiles)-1)*n+i for i in range(n)));colors.append(12)
        self.add(verts,faces,colors)
    def foliage(self,center,size,seed,color=6):
        bm=bmesh.new();bmesh.ops.create_icosphere(bm,subdivisions=2,radius=1)
        rng=random.Random(seed)
        for v in bm.verts:
            q=rng.uniform(.95,1.04)
            v.co=Vector((center[0]+v.co.x*size[0]*q/2,center[1]+v.co.y*size[1]*q/2,
                         center[2]+v.co.z*size[2]*q/2))
        bm.verts.ensure_lookup_table();idx={v:i for i,v in enumerate(bm.verts)}
        verts=[tuple(v.co) for v in bm.verts]
        faces=[tuple(idx[v] for v in f.verts) for f in bm.faces]
        colors=[color if sum(verts[i][1] for i in f)/len(f)<center[1]+size[1]*.24 else min(color+1,7) for f in faces]
        self.add(verts,faces,colors);bm.free()
    def object(self,name,material):
        mesh=bpy.data.meshes.new(name+'Geometry')
        mesh.from_pydata([cv(v) for v in self.v],[],self.f);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
        mesh.materials.append(material)
        uv=mesh.uv_layers.new(name='PaletteUV')
        for poly,color in zip(mesh.polygons,self.c):
            for li in poly.loop_indices:uv.data[li].uv=((color+.5)/16,.5)
        bm=bmesh.new();bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        for poly in mesh.polygons:poly.use_smooth=False
        return obj

def box(name,center,size,rotation=(0,0,0)):
    return {'name':name,'center':list(center),'size':list(size),'rotation_degrees':list(rotation)}

def beam_box(name,a,b,width):
    # All root segments lie in local XY; a rotation about Z aligns local Y.
    a,b=Vector(a),Vector(b);d=b-a
    return box(name,(a+b)/2,(width,d.length+.12,width),(0,0,math.degrees(math.atan2(-d.x,d.y))))

def passage(axis,length,width,height):
    return {'axis':axis,'length':length,'clear_width':width,'clear_height':height,
            'floor_y':0,'center':[0,0,0],
            'reference_avatar':{'width':3.5,'height':5.8},
            'note':'Straight clearance envelope, checked against render triangles and supplied collision boxes.'}

def moss_boulder():
    m=Mesh();m.hull((0,-.2,0),(14,10.5,11),21,0,True)
    m.hull((-5,-.2,2.6),(6,4.3,6),32,1,True)
    m.hull((4.7,-.2,-2.5),(4.5,3.6,5),23,2,True)
    return m,[box('BoulderCore',(0,4,0),(8,8,7)),box('LowShoulder',(-4,1.6,2),(4.2,3.2,4)),
              box('SideRock',(4.4,1.3,-2),(2.5,2.6,3))],None

def split_rock():
    m=Mesh()
    m.hull((-8,0,0),(7.2,14,9),60,1,True)
    m.hull((8,0,.3),(7.5,12,10),63,0,True)
    m.hull((-10,0,3),(5,5,6),12,2,True)
    m.hull((10,0,-3),(5,4,5),16,2,True)
    col=[box('WestPillar',(-8,5.5,0),(5.5,11,6)),box('EastPillar',(8,4.8,0),(5.5,9.6,7)),
         box('WestFoot',(-10,1.8,3),(3.5,3.6,4)),box('EastFoot',(10,1.5,-3),(3.5,3,3.5))]
    return m,col,passage('Z',18,7,10)

def hollow_log():
    m=Mesh();n=28
    # A circular fallen trunk with a flattened interior walking surface.
    inner=[(5*math.cos(i*math.tau/n),max(.65,4.5+5*math.sin(i*math.tau/n))) for i in range(n)]
    outer=[(6.15*math.cos(i*math.tau/n),max(-.6,4.5+6.15*math.sin(i*math.tau/n))) for i in range(n)]
    count=len(inner);verts=[];rng=random.Random(71)
    lengths=[-11,-6,0,6,11]
    for shell,ring in enumerate([outer,inner]):
        for k,x in enumerate(lengths):
            for j,(z,y) in enumerate(ring):
                # End silhouettes vary slightly; inner and outer ends share X.
                wave=.16*math.sin(j*2.7) if k in (0,4) else 0
                bulge=1+.025*math.sin(k*1.5+j*.6) if shell==0 and y>0 else 1
                verts.append((x+wave,4.5+(y-4.5)*bulge,z*bulge))
    faces=[];colors=[];layer=count*len(lengths)
    for shell in (0,1):
        off=shell*layer
        for k in range(4):
            for j in range(count):
                faces.append((off+k*count+j,off+k*count+(j+1)%count,
                              off+(k+1)*count+(j+1)%count,off+(k+1)*count+j))
                colors.append((9 if j%4 else 10) if shell==0 else (11 if inner[j][1]<=.65 else 14))
    for k in (0,4):
        for j in range(count):
            faces.append((k*count+j,k*count+(j+1)%count,layer+k*count+(j+1)%count,layer+k*count+j))
            colors.append(12)
    m.add(verts,faces,colors)
    # Small branch and moss live outside the tunnel clearance.
    m.tube([(-2,8.8,3.5),(-1,11,4.8),(.4,12.1,5.5)],[1.1,.83,.70],9)
    m.hull((-4,10.1,-.6),(5.2,.9,3.0),24,3)
    m.hull((5,10.0,1.0),(4,.85,3),35,4)
    col=[box('TunnelFloor',(0,.15,0),(22,1.0,6.4))]
    for i in range(n):
        a=(i+.5)*math.tau/n
        col.append(box('ShellSegment%02d'%i,(0,4.5+5.575*math.sin(a),5.575*math.cos(a)),
                       (22,1.00,2*5.575*math.sin(math.pi/n)+.04),
                       (90-math.degrees(a),0,0)))
    # Gentle low thresholds give the flattened interior a ground-level approach.
    for sign in (-1,1):
        x0,x1=sign*10.95,sign*12.6
        m.add([(x0,.65,-3.2),(x0,.65,3.2),(x1,.02,-3.2),(x1,.02,3.2),
               (x0,-.25,-3.2),(x0,-.25,3.2),(x1,-.25,-3.2),(x1,-.25,3.2)],
              [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],11)
        col.append(box('EntryRamp'+str(sign),(sign*11.77,.20,0),(1.85,.25,6.4),
                       (0,0,-sign*20.9)))
    route=passage('X',27,6,7.4);route['floor_y']=.65
    return m,col,route

def giant_oak():
    m=Mesh()
    m.tube([(0,-.15,0),(.3,3,0),(-.3,10,.3),(.4,17,0),(.9,23,.3)],[3.7,3,2.45,1.85,.95],9,12)
    for i in range(6):
        a=i*math.tau/6+.1
        m.tube([(math.cos(a)*1.5,3,math.sin(a)*1.5),
                (math.cos(a)*4,1.1,math.sin(a)*4),(math.cos(a)*7,.1,math.sin(a)*7)],
               [1.45,1.05,.24],9,8)
    branches=[((-1,11,0),(-7,21,1)),((1,14,0),(7,24,-1)),((0,17,.2),(0,27,5)),
              ((0,15,0),(-1,24,-6))]
    for a,b in branches:m.tube([a,Vector(a).lerp(Vector(b),.6),b],[1.6,1,.55],9,9)
    leaves=[((-7,22,1),(13,11,13),6),((7,24,-1),(14,12,13),6),
            ((0,29,0),(15,13,15),7),((0,26,6),(14,11,12),6),
            ((-1,25,-6),(15,12,13),5),((-7,27,-4),(11,10,11),6),
            ((7,28,5),(11,10,11),7)]
    for i,(p,s,c) in enumerate(leaves):m.foliage(p,s,100+i,c)
    col=[box('Trunk',(0,8,0),(4.4,16,4.4))]
    for i in range(6):
        a=i*math.tau/6+.1
        col.append(box('Root%02d'%i,(math.cos(a)*3.9,.65,math.sin(a)*3.9),
                       (4.5,1.3,1.5),(0,-math.degrees(a),0)))
    return m,col,None

def giant_pine():
    m=Mesh();m.tube([(0,-.15,0),(0,6,0),(.35,18,0),(.3,33,0)],[2.2,1.8,1.1,.24],9,10)
    for i,(base,r,height) in enumerate([(7,9,13),(14,7.8,12),(21,6.2,11),(28,4.3,10)]):
        n=12;verts=[]
        profiles=[(base,r*.50),(base+.65,r),(base+height*.30,r*.79),(base+height,.14)]
        for k,(y,rad) in enumerate(profiles):
            for j in range(n):
                a=math.tau*j/n+i*.17
                verts.append((math.cos(a)*rad,y+(.55 if k==1 and j%2 else 0),math.sin(a)*rad))
        faces=[tuple(reversed(range(n)))];colors=[8]
        for k in range(3):
            for j in range(n):
                faces.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
                colors.append(8 if k==0 else 5 if j%3 else 6)
        faces.append(tuple(3*n+j for j in range(n)));colors.append(6)
        m.add(verts,faces,colors)
    for i in range(5):
        a=i*math.tau/5
        m.tube([(0,1.5,0),(math.cos(a)*4.5,.05,math.sin(a)*4.5)],[1.0,.17],9,7)
    return m,[box('Trunk',(0,11,0),(2.9,22,2.9))],None

def root_arch():
    m=Mesh();m.stump(-9,0,3.6,10.8,51)
    points=[]
    a,b,c,d=map(Vector,[(-8,0,0),(-8,13,0),(8,13,0),(8,0,0)])
    for i in range(23):
        t=i/22
        points.append(a*(1-t)**3+b*(3*(1-t)**2*t)+c*(3*(1-t)*t*t)+d*t**3)
    m.tube(points,[1.75-.25*math.sin(i*math.pi/22) for i in range(23)],9,10)
    m.tube([(-9,6,0),(-12,10,-1),(-14,11,-2)],[1.05,.7,.55],9,9)
    m.hull((-1,10.7,0),(5,.65,2.8),82,3)
    m.hull((8,0,1),(4,1.4,4),14,3)
    col=[box('Stump',(-9,5.3,0),(5.5,10.6,5.5))]
    for i,(a,b) in enumerate(zip(points,points[1:])):
        col.append(beam_box('RootSegment%02d'%i,a,b,2.75))
    return m,col,passage('Z',10,6,6.8)

def stone_arch():
    m=Mesh();n=16;verts=[]
    # Continuous natural stone arch: rectangular feet and a broad curved crown.
    inner=[(6,0)]+[(6*math.cos(i*math.pi/n),3+6*math.sin(i*math.pi/n)) for i in range(n+1)]+[(-6,0)]
    outer=[(10,0)]+[((10+.20*math.sin(i*2.8))*math.cos(i*math.pi/n),
                     3+(10+.25*math.sin(i*2.1))*math.sin(i*math.pi/n)) for i in range(n+1)]+[(-10,0)]
    count=len(inner)
    for z in (-2.5,2.5):
        for ring in [outer,inner]:verts.extend((x,y,z) for x,y in ring)
    faces=[];colors=[]
    for side in range(2):
        off=side*count*2
        for i in range(count-1):
            faces.append((off+i,off+(i+1)%count,off+count+(i+1)%count,off+count+i))
            colors.append(0 if (i+side)%4 else 2)
    for ring in range(2):
        off=ring*count
        for i in range(count-1):
            faces.append((off+i,off+(i+1)%count,off+count*2+(i+1)%count,off+count*2+i))
            colors.append(3 if ring==0 and 4<i<13 else 1)
    # Cap each foot separately; no zero-area strip or hidden slab spans the opening.
    for i in (0,count-1):
        faces.append((i,count+i,3*count+i,2*count+i));colors.append(1)
    m.add(verts,faces,colors)
    m.hull((-9,0,1),(5,4,6),74,1,True);m.hull((9,0,-1),(5,3.5,6),73,2,True)
    col=[box('WestFoot',(-8,1.5,0),(3.7,3,4.7)),box('EastFoot',(8,1.5,0),(3.7,3,4.7))]
    for i in range(n):
        a=(i+.5)*math.pi/n
        col.append(box('Arch%02d'%i,(8*math.cos(a),3+8*math.sin(a),0),
            (2*8*math.sin(math.pi/n/2)+.05,3.8,4.7),(0,0,math.degrees(a)-90)))
    return m,col,passage('Z',12,7,7.1)

def stepping_stumps():
    m=Mesh();col=[]
    for i,(x,z,r,h) in enumerate([(-7,-1,2.5,1.5),(-2,0,2.4,3.0),(3,1,2.45,4.5),(8,1.7,2.3,3.0)]):
        m.stump(x,z,r,h,120+i)
        col.append(box('Step%02d'%i,(x,h/2-.03,z),(r*1.30,h-.06,r*1.30)))
        if i in (0,2):
            m.tube([(x,h*.4,z),(x+.3,h*.75,z+r+1)],[.55,.34],9,8)
        if i in (1,3):m.hull((x+r*.65,0,z-.8),(1.8,.45,1.5),i,3)
    return m,col,None

BUILDERS={'moss-boulder':moss_boulder,'split-rock-passage':split_rock,
          'hollow-log':hollow_log,'giant-oak':giant_oak,'giant-pine':giant_pine,
          'root-arch':root_arch,'stone-arch':stone_arch,'stepping-stumps':stepping_stumps}
DISPLAY={'moss-boulder':'Mossback Boulder','split-rock-passage':'Split Rock Passage',
         'hollow-log':'Hollow Fallen Giant','giant-oak':'Giant Oak','giant-pine':'Tall Forest Pine',
         'root-arch':'Ancient Root Arch','stone-arch':'Mossy Stone Arch','stepping-stumps':'Stepping Stumps'}

def select(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objs:obj.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]

def stage(obj,key):
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
    scene.render.resolution_x=scene.render.resolution_y=900
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    scene.render.film_transparent=True;scene.view_settings.view_transform='Standard'
    scene.world=bpy.data.worlds.new('ForestPreviewWorld');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.8,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.4
    for name,pos,power,size in [('Key',(-20,-30,45),23000,30),('Fill',(25,-10,28),13000,25),('Rim',(4,25,40),22000,22)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        light=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(light);light.location=pos
        light.rotation_euler=(Vector((0,0,7))-light.location).to_track_quat('-Z','Y').to_euler()
    points=[v.co for v in obj.data.vertices]
    lo=Vector([min(p[k] for p in points) for k in range(3)]);hi=Vector([max(p[k] for p in points) for k in range(3)])
    target=(lo+hi)/2
    view=Vector((.8,-1.5,.9))
    if key=='hollow-log':view=Vector((1.5,-1.0,.7))
    if key in ('giant-oak','giant-pine'):view=Vector((.8,-1.8,.4))
    bpy.ops.object.camera_add(location=target+view*45)
    cam=bpy.context.object;cam.name='PreviewCamera';cam.data.type='ORTHO'
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    inv=cam.rotation_euler.to_matrix().transposed()
    projected=[inv@(p-target) for p in points]
    width=max(p.x for p in projected)-min(p.x for p in projected)
    height=max(p.y for p in projected)-min(p.y for p in projected)
    cam.data.ortho_scale=max(width,height)*1.18
    scene.camera=cam
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.shading.type='MATERIAL'
    return cam,target

def build(key):
    material=setup();m,colliders,walk=BUILDERS[key]()
    name=''.join(w.title() for w in key.split('-'))
    obj=m.object(name,material)
    obj.data.calc_loop_triangles()
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges),key
    assert bm.calc_volume(signed=True)>0,key
    bm.free()
    tri=len(obj.data.loop_triangles);assert tri<6000,(key,tri)
    out=ROOT/key;out.mkdir(exist_ok=True)
    (out/'preview').mkdir(exist_ok=True)
    low=[min(v[k] for v in m.v) for k in range(3)];high=[max(v[k] for v in m.v) for k in range(3)]
    report={'key':key,'name':DISPLAY[key],'mesh_name':name,'triangles':tri,
        'parts':1,'texture':'../forest-palette.png','flat_shaded':True,'closed_manifold':True,
        'dimensions_studs':[high[k]-low[k] for k in range(3)],
        'bounds_studs':{'min':low,'max':high},'pivot':'ground anchor at (0,0,0)',
        'authoring_to_blender':'(x,y,z) -> (x,-z,y)',
        'fbx_global_scale':.01,'collision':colliders,'passage':walk,
        'status':'local source art; not uploaded or placed in the live map'}
    (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    select([obj])
    bpy.ops.export_scene.fbx(filepath=str(out/(key+'.fbx')),use_selection=True,object_types={'MESH'},
        global_scale=.01,axis_forward='-Z',axis_up='Y',apply_unit_scale=True,
        bake_space_transform=True,mesh_smooth_type='FACE',path_mode='RELATIVE',bake_anim=False)
    cam,target=stage(obj,key)
    select([obj]);bpy.ops.wm.save_as_mainfile(filepath=str(out/(key+'.blend')))
    scene=bpy.context.scene;scene.render.filepath=str(out/'preview'/(key+'.png'))
    bpy.ops.render.render(write_still=True)
    if walk:
        # Show the opening straight-on; this view is also checked by ray casts.
        cam.location=Vector((45,0,3.5)) if walk['axis']=='X' else Vector((0,-45,3.5))
        at=Vector((0,0,3.5));cam.rotation_euler=(at-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=18 if key!='split-rock-passage' else 28
        scene.render.filepath=str(out/'preview'/(key+'-opening.png'))
        bpy.ops.render.render(write_still=True)
    CATALOG[key]=report
    print('FOREST_ASSET_COMPLETE',key,tri,flush=True)

if __name__=='__main__':
    make_palette()
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(BUILDERS)
    for key in chosen:build(key)
    # Retain records of previously built assets when rebuilding a subset.
    all_records={}
    for key in BUILDERS:
        path=ROOT/key/'manifest.json'
        if path.exists():all_records[key]=json.loads(path.read_text())
    (ROOT/'catalog.json').write_text(json.dumps({'assets':all_records,
        'palette':dict(zip(NAMES,COLORS)),'status':'local; not uploaded or integrated'},indent=2)+'\n')
    print('FOREST_BUILD_COMPLETE',len(all_records),flush=True)
