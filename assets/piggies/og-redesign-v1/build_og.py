"""Build the 15 OG redesigns without altering live Config or shared pig meshes.

blender -b --python assets/piggies/og-redesign-v1/build_og.py -- --skin marble
Each skin owns a procedural source, packed animated review, FBXs, maps and renders.
"""
from pathlib import Path
import argparse, colorsys, hashlib, json, math, random, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SPECS = json.loads((HERE/'design-specs.json').read_text())['skins']
argv = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument('--skin', required=True)
parser.add_argument('--quick', action='store_true')
ARGS = parser.parse_args(argv)
SPEC = next(s for s in SPECS if s['key']==ARGS.skin)
KEY, TIER = SPEC['key'], SPEC['tier']
HOME = ROOT/'assets/piggies'/TIER/KEY
for room in ('source','generate','sheets','preview','package'):(HOME/room).mkdir(parents=True,exist_ok=True)
CORE = ('Body','Snout','Ears','Legs','Tail','EyePreview')
SOURCE = ROOT/'assets/piggies/common/cow/source/cow_closed.blend'
random.seed(20260923 + sum(map(ord,KEY)))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene;scene.name = SPEC['name']+' - OG v1'
scene.render.fps=24;scene.frame_start=1;scene.frame_end=145
asset=bpy.data.collections.new('ASSET - mesh and coat');scene.collection.children.link(asset)
fxcol=bpy.data.collections.new('FX - animated geometry');scene.collection.children.link(fxcol)
auracol=bpy.data.collections.new('AURA - preview only; use Roblox emitter');scene.collection.children.link(auracol)
stage=bpy.data.collections.new('REVIEW - cameras and lights');scene.collection.children.link(stage)
with bpy.data.libraries.load(str(SOURCE),link=False) as (a,b):b.objects=list(CORE)
parts=dict(zip(CORE,b.objects));assert all(parts.values())
for name,ob in parts.items():
    asset.objects.link(ob);ob.name=name;ob.hide_render=False;ob.hide_viewport=False;ob.hide_select=False;ob.hide_set(False)
    for modifier in list(ob.modifiers):ob.modifiers.remove(modifier)
    for face in ob.data.polygons:face.use_smooth=True
def signature(ob):
    return hashlib.sha256(json.dumps(([list(v.co) for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons],[[list(v.uv) for v in uv.data] for uv in ob.data.uv_layers])).encode()).hexdigest()
signatures={n:signature(o) for n,o in parts.items()}
def lin(rgb):return tuple(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb)
def assign(ob,mat):
    ob.data.materials.clear();ob.data.materials.append(mat)
    for p in ob.data.polygons:p.material_index=0
def move(ob,col):
    for c in list(ob.users_collection):c.objects.unlink(ob)
    col.objects.link(ob)
def flat(name,rgb,emission=0,metal=0,rough=.6):
    m=bpy.data.materials.new(KEY+'_'+name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*lin(rgb),1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    p.inputs['Specular IOR Level'].default_value=.3
    p.inputs['Emission Color'].default_value=(*lin(rgb),1);p.inputs['Emission Strength'].default_value=emission
    m.diffuse_color=(*lin(rgb),1)
    return m

class Paint:
    def __init__(self,name,base):
        self.mat=flat(name,base);self.nt=self.mat.node_tree;self.n=self.nt.nodes;self.l=self.nt.links
        self.bs=self.n.get('Principled BSDF')
        self.tex=self.n.new('ShaderNodeTexCoord').outputs['Object']
        n=self.n.new('ShaderNodeSeparateXYZ');self.l.new(self.tex,n.inputs[0])
        self.x,self.y,self.z=(n.outputs[k] for k in 'XYZ')
        self.color=self.rgb(base);self.glow=0;self.metal=0;self.rough=.65
    def rgb(self,v):
        n=self.n.new('ShaderNodeRGB');n.outputs[0].default_value=(*lin(v),1);return n.outputs[0]
    def wire(self,v,s):
        if isinstance(v,(int,float)):s.default_value=(v,v,v,1) if s.type=='RGBA' else v
        else:self.l.new(v,s)
    def op(self,kind,a,b=0):
        n=self.n.new('ShaderNodeMath');n.operation=kind;self.wire(a,n.inputs[0]);self.wire(b,n.inputs[1]);return n.outputs[0]
    def vec(self,x,y,z):
        n=self.n.new('ShaderNodeCombineXYZ')
        for v,s in zip((x,y,z),n.inputs):self.wire(v,s)
        return n.outputs[0]
    def noise(self,scale,detail=2,vec=None):
        n=self.n.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=scale;n.inputs['Detail'].default_value=detail;n.inputs['Roughness'].default_value=.55
        self.l.new(vec or self.tex,n.inputs['Vector']);return n.outputs['Fac']
    def vor(self,scale,feature='DISTANCE_TO_EDGE',vec=None):
        n=self.n.new('ShaderNodeTexVoronoi');n.feature=feature;n.inputs['Scale'].default_value=scale
        self.l.new(vec or self.tex,n.inputs['Vector']);return n
    def mix(self,a,b,f):
        n=self.n.new('ShaderNodeMixRGB');self.wire(f,n.inputs[0])
        for v,s in zip((a,b),n.inputs[1:3]):
            if isinstance(v,(list,tuple)):s.default_value=(*lin(v),1)
            else:self.l.new(v,s)
        return n.outputs[0]
    def ramp(self,f,colors,interpolation='LINEAR'):
        n=self.n.new('ShaderNodeValToRGB');n.color_ramp.interpolation=interpolation
        for i,c in enumerate(colors):
            e=n.color_ramp.elements[i] if i<2 else n.color_ramp.elements.new(i/(len(colors)-1))
            e.position=i/(len(colors)-1);e.color=(*lin(c),1)
        self.l.new(f,n.inputs[0]);return n.outputs['Color']
    def ellipse(self,axes,center,radii):
        d=0
        for a,c,r in zip(axes,center,radii):
            q=self.op('DIVIDE',self.op('SUBTRACT',a,c),r);d=self.op('ADD',d,self.op('MULTIPLY',q,q))
        return self.op('LESS_THAN',d,1)
    def stripe(self,phase,width):
        return self.op('LESS_THAN',self.op('ABSOLUTE',self.op('SINE',phase)),width)
    def finish(self):
        self.l.new(self.color,self.bs.inputs['Base Color']);self.l.new(self.color,self.bs.inputs['Emission Color'])
        self.wire(self.glow,self.bs.inputs['Emission Strength']);self.wire(self.metal,self.bs.inputs['Metallic']);self.wire(self.rough,self.bs.inputs['Roughness'])
        for label,value in [('BAKE_COLOR',self.color),('BAKE_EMISSIVE',self.glow),('BAKE_METAL',self.metal),('BAKE_ROUGH',self.rough)]:
            node=self.n.new('ShaderNodeEmission');node.label=label;node.name=label
            self.wire(value,node.inputs['Color'])
        return self.mat

P=SPEC['palette'];paints={}
def paint(name,mode):
    p=Paint(name,P[0]);o=p.op;x,y,z=p.x,p.y,p.z
    n=p.noise(2.5);noise=p.noise(8)
    warp=p.vec(o('ADD',x,o('MULTIPLY',n,.35)),o('ADD',y,o('MULTIPLY',noise,.2)),z)
    if KEY=='marble':
        phase=o('ADD',o('ADD',o('MULTIPLY',x,2.6),o('MULTIPLY',z,3.6)),o('MULTIPLY',p.noise(1.65,2),6))
        vein=p.stripe(phase,o('ADD',.10,o('MULTIPLY',noise,.24)));halo=p.stripe(phase,.38)
        p.color=p.mix(P[0],P[1],o('MULTIPLY',halo,.65));p.color=p.mix(p.color,P[2],vein)
        gold=p.stripe(o('ADD',phase,.36),.025);p.color=p.mix(p.color,[188,157,104],gold)
        p.rough=.25
    elif KEY in ('rockslide','quartz','charcoal','stormcaller'):
        vor=p.vor(3.8 if KEY=='rockslide' else 4.5,'DISTANCE_TO_EDGE',warp)
        edge=vor.outputs['Distance'];cracks=o('LESS_THAN',edge,.034 if KEY=='rockslide' else .022)
        cell=p.vor(4.5,'F1',warp).outputs['Color']
        p.color=p.mix(P[0],P[1],cell)
        p.color=p.mix(p.color,P[1] if KEY=='rockslide' else P[2],cracks)
        if KEY=='stormcaller':
            cracks=o('MULTIPLY',cracks,o('GREATER_THAN',p.noise(1.4),.51))
            cracks=o('MULTIPLY',cracks,o('GREATER_THAN',y,-.6))
            p.color=p.mix(P[0],P[1],o('MULTIPLY',n,.35));p.color=p.mix(p.color,P[2],cracks)
        if KEY=='quartz':
            u=o('MULTIPLY',y,5);v=o('MULTIPLY',z,5);row=o('FLOOR',v);u=o('ADD',u,o('MULTIPLY',row,.5))
            diagonal=o('GREATER_THAN',o('ADD',o('FRACT',u),o('FRACT',v)),1)
            index=o('FRACT',o('MULTIPLY',o('ADD',o('ADD',o('FLOOR',u),o('MULTIPLY',row,3)),diagonal),.173))
            p.color=p.ramp(index,[[217,149,183],[239,188,207],[225,161,191],[247,215,225]],'CONSTANT')
            p.color=p.mix(p.color,P[1],o('MULTIPLY',cracks,.6));p.rough=.22
        if KEY in ('charcoal','stormcaller'):
            p.glow=o('MULTIPLY',cracks,1.5 if KEY=='charcoal' else 1.8)
        if KEY=='rockslide':p.rough=.91
    elif KEY=='banker':
        pin=p.stripe(o('ADD',o('MULTIPLY',y,27),o('MULTIPLY',x,.6)),.085)
        p.color=p.mix(P[0],P[1],o('MULTIPLY',pin,.7))
        front=o('LESS_THAN',y,-.62)
        face=o('MULTIPLY',o('LESS_THAN',y,-.48),o('GREATER_THAN',z,-.32))
        p.color=p.mix(p.color,[223,167,173],face)
        bib=o('MULTIPLY',front,o('MULTIPLY',o('LESS_THAN',z,-.25),o('LESS_THAN',o('ABSOLUTE',x),o('ADD',.45,o('MULTIPLY',z,.23)))))
        p.color=p.mix(p.color,P[1],bib)
        tie=o('MULTIPLY',bib,p.ellipse((x,z),(0,-.57),(.115,.29)))
        p.color=p.mix(p.color,P[2],tie)
        p.rough=.75
    elif KEY=='tiedye':
        angle=o('ARCTAN2',o('SUBTRACT',z,.15),o('SUBTRACT',y,.15))
        radius=o('SQRT',o('ADD',o('MULTIPLY',y,y),o('MULTIPLY',z,z)))
        phase=o('ADD',o('ADD',o('MULTIPLY',angle,2),o('MULTIPLY',radius,11)),o('MULTIPLY',noise,1.4))
        value=o('MULTIPLY',o('ADD',o('SINE',phase),1),.5)
        p.color=p.ramp(value,[P[2],P[3],P[0],P[1],P[4]])
        p.color=p.mix(p.color,P[4],p.stripe(o('MULTIPLY',phase,2),.065));p.rough=.78
    elif KEY=='verdigris':
        patina=o('GREATER_THAN',o('ADD',n,o('MULTIPLY',z,.11)),.49)
        copper=p.mix(P[0],[213,137,80],noise);green=p.mix(P[1],P[2],p.noise(7))
        p.color=p.mix(copper,green,patina);p.metal=o('MULTIPLY',o('SUBTRACT',1,patina),.8);p.rough=o('ADD',.3,o('MULTIPLY',patina,.5))
    elif KEY=='ghost':
        flow=o('ADD',o('MULTIPLY',z,8),o('MULTIPLY',n,5))
        wave=p.stripe(flow,.21);lower=o('LESS_THAN',z,.02)
        pattern=o('MULTIPLY',wave,lower);rim=o('MULTIPLY',p.stripe(o('ADD',flow,.22),.055),lower)
        # Spiral ghost curls rise from the lower coat on both flanks.
        for cy,cz in [(-.27,-.18),(.33,.10),(.75,-.2)]:
            dy=o('SUBTRACT',y,cy);dz=o('SUBTRACT',z,cz)
            r=o('SQRT',o('ADD',o('MULTIPLY',dy,dy),o('MULTIPLY',dz,dz)))
            spiral=o('ADD',o('ARCTAN2',dz,dy),o('MULTIPLY',r,19))
            area=o('LESS_THAN',r,.30)
            pattern=o('MAXIMUM',pattern,o('MULTIPLY',p.stripe(spiral,.58),area))
            rim=o('MAXIMUM',rim,o('MULTIPLY',p.stripe(o('ADD',spiral,.59),.09),area))
        p.color=p.mix(P[0],P[1],o('MULTIPLY',pattern,.85))
        p.color=p.mix(p.color,P[2],rim);p.glow=o('MULTIPLY',rim,.9);p.rough=.27
    elif KEY in ('starlight','nightlight'):
        p.color=p.mix(P[0],[54,67,109] if KEY=='nightlight' else P[1],o('MULTIPLY',n,.4));marks=0
        rng=random.Random(451)
        if KEY=='starlight':
            stars=[]
            for i in range(15):
                cy=rng.uniform(-.58,.9);cz=rng.uniform(-.4,.8);r=rng.uniform(.035,.095)
                stars.append((cy,cz))
                a=o('DIVIDE',o('ABSOLUTE',o('SUBTRACT',y,cy)),r)
                b=o('DIVIDE',o('ABSOLUTE',o('SUBTRACT',z,cz)),r)
                star=o('LESS_THAN',o('ADD',o('SQRT',a),o('SQRT',b)),1.2)
                marks=o('MAXIMUM',marks,star)
                if i%3!=0:
                    ay,az=stars[-2];vy,vz=cy-ay,cz-az
                    dy=o('SUBTRACT',y,ay);dz=o('SUBTRACT',z,az)
                    dot=o('ADD',o('MULTIPLY',dy,vy),o('MULTIPLY',dz,vz))
                    t=o('MINIMUM',1,o('MAXIMUM',0,o('DIVIDE',dot,vy*vy+vz*vz)))
                    ry=o('SUBTRACT',dy,o('MULTIPLY',t,vy));rz=o('SUBTRACT',dz,o('MULTIPLY',t,vz))
                    line=o('LESS_THAN',o('ADD',o('MULTIPLY',ry,ry),o('MULTIPLY',rz,rz)),.000014)
                    marks=o('MAXIMUM',marks,o('MULTIPLY',line,.65))
            dots=o('LESS_THAN',p.vor(22,'F1').outputs['Distance'],.10);marks=o('MAXIMUM',marks,dots)
        else:
            for cy,cz in [(.2,.3),(.69,-.2),(-.3,-.18)]:
                disc=p.ellipse((y,z),(cy,cz),(.21,.24));cut=p.ellipse((y,z),(cy+.085,cz+.04),(.19,.22))
                marks=o('MAXIMUM',marks,o('MULTIPLY',disc,o('SUBTRACT',1,cut)))
            for cy,cz in [(-.35,.48),(.7,.55),(.5,-.48),(-.03,-.5)]:
                dy=o('DIVIDE',o('ABSOLUTE',o('SUBTRACT',y,cy)),.07);dz=o('DIVIDE',o('ABSOLUTE',o('SUBTRACT',z,cz)),.07)
                star=o('LESS_THAN',o('ADD',o('SQRT',dy),o('SQRT',dz)),1.2)
                marks=o('MAXIMUM',marks,star)
        clear=o('GREATER_THAN',y,-.62);marks=o('MULTIPLY',marks,clear)
        p.color=p.mix(p.color,P[2],marks);p.glow=o('MULTIPLY',marks,1.35);p.rough=.38
    elif KEY=='sugarrush':
        phase=o('ADD',o('ADD',o('MULTIPLY',y,9),o('MULTIPLY',z,7)),o('MULTIPLY',n,.9))
        value=o('MULTIPLY',o('ADD',o('SINE',phase),1),.5)
        p.color=p.ramp(value,[P[0],P[0],P[2],P[1],P[1]],'CONSTANT')
        sprinkles=o('LESS_THAN',p.vor(18,'F1',p.vec(x,y,o('MULTIPLY',z,.48))).outputs['Distance'],.16)
        p.color=p.mix(p.color,[255,240,218],sprinkles)
        p.glow=o('MULTIPLY',p.stripe(phase,.12),.6);p.rough=.4
    elif KEY=='hologram':
        scan=p.stripe(o('MULTIPLY',z,72),.15)
        grid=o('MAXIMUM',p.stripe(o('MULTIPLY',y,16),.075),p.stripe(o('MULTIPLY',z,16),.075))
        marks=o('MAXIMUM',o('MULTIPLY',scan,.38),grid)
        p.color=p.mix(P[0],P[1],marks)
        bar=o('MULTIPLY',p.stripe(o('MULTIPLY',z,11),.13),o('GREATER_THAN',p.noise(5),.63))
        p.color=p.mix(p.color,P[2],bar);p.glow=o('MULTIPLY',marks,1.2);p.rough=.34
    elif KEY=='supernova':
        phase=o('ADD',o('ADD',o('MULTIPLY',y,4),o('MULTIPLY',z,5)),o('MULTIPLY',p.noise(1.7,2),6))
        channels=p.stripe(phase,.22);edges=p.stripe(phase,.4)
        p.color=p.mix(P[0],P[1],edges);p.color=p.mix(p.color,P[2],channels);p.glow=o('MULTIPLY',channels,1.9);p.rough=.43
    elif KEY=='prismatic':
        # Triangular cells in the side plane, offset in alternate rows.
        u=o('ADD',o('MULTIPLY',y,3.6),o('MULTIPLY',x,.7));v=o('MULTIPLY',z,3.6)
        row=o('FLOOR',v);u=o('ADD',u,o('MULTIPLY',row,.5))
        diagonal=o('GREATER_THAN',o('ADD',o('FRACT',u),o('FRACT',v)),1)
        seed=o('ADD',o('ADD',o('MULTIPLY',o('FLOOR',u),12.9898),o('MULTIPLY',row,78.233)),o('MULTIPLY',diagonal,37.7))
        index=o('FRACT',o('MULTIPLY',o('SINE',seed),43758.5453))
        jewels=[[30,36,85],[47,52,133],[90,76,172],[61,118,188],[69,191,207],[107,93,191],[63,54,132],[186,111,177],[70,70,154]]
        p.color=p.ramp(index,jewels,'CONSTANT');p.metal=.24;p.rough=.28
        seam=o('MINIMUM',o('FRACT',u),o('FRACT',v));p.glow=o('MULTIPLY',o('LESS_THAN',seam,.018),.7)
    # Keep faces readable and define the separate trim pieces intentionally.
    if mode=='snout':
        tones={'banker':[223,157,169],'tiedye':[235,143,172],'ghost':[178,211,212],'nightlight':[173,115,61],'sugarrush':[229,102,155],'prismatic':[149,137,188],'supernova':[103,43,44]}
        p.color=p.mix(p.color,tones.get(KEY,P[0] if KEY in ('marble','quartz') else P[1]),.45 if KEY=='marble' else .85);p.glow=0
        if KEY in ('banker','ghost','tiedye','starlight','nightlight','sugarrush','hologram','supernova','prismatic','stormcaller','charcoal'):
            p.color=p.rgb(tones.get(KEY,P[1]))
    elif mode=='legs':
        toe=o('LESS_THAN',z,-.87);p.color=p.mix(p.color,P[1],o('MULTIPLY',toe,.6))
        if KEY=='marble':p.color=p.mix(p.color,P[2],.65)
    elif mode=='ear':
        p.color=p.mix(p.color,P[1],.7);p.glow=0
    if KEY=='banker':
        if name.startswith('Ears') or mode=='tail':p.color=p.rgb([231,164,179] if mode!='ear' else [199,122,151])
        if mode=='legs':p.color=p.mix(P[0],P[1],o('MULTIPLY',o('GREATER_THAN',z,-.91),o('LESS_THAN',z,-.85)))
    if KEY=='tiedye':
        if name.startswith('Ears') or mode=='tail':p.color=p.rgb([235,143,172] if mode!='ear' else [205,99,143])
        if mode=='legs':p.color=p.rgb(P[3])
    if KEY=='verdigris':
        if mode in ('snout','ear','tail'):
            p.color=p.rgb(P[0]);p.metal=.8;p.rough=.32
        if mode=='legs':
            toe=o('LESS_THAN',z,-.81);p.color=p.mix(p.color,P[0],toe);p.metal=o('MAXIMUM',p.metal,o('MULTIPLY',toe,.8))
    paints[name]=p
    return p.finish()

assign(parts['Body'],paint('Body_coat','body'))
assign(parts['Snout'],paint('Snout_coat','snout'))
assign(parts['Legs'],paint('Legs_coat','legs'))
assign(parts['Tail'],paint('Tail_coat','tail'))
ears=parts['Ears']
for i in range(len(ears.data.materials)):ears.data.materials[i]=paint('Ears_'+str(i),'body' if i==0 else 'ear')
eye_rgb=P[1] if KEY=='hologram' else P[2] if KEY=='prismatic' else P[-1]
lit_eyes=TIER!='rare' and KEY not in ('nightlight','sugarrush')
eyes=flat('Eyes',eye_rgb if lit_eyes else (27,27,32),.22 if lit_eyes else 0,rough=.24)
assign(parts['EyePreview'],eyes)

extras=[];aura=[]
def mesh(name,verts,faces,material,col=fxcol):
    data=bpy.data.meshes.new(KEY+'_'+name);data.from_pydata(verts,[],faces);data.update()
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    ob=bpy.data.objects.new(name,data);col.objects.link(ob);assign(ob,material)
    (aura if col==auracol else extras).append(ob);return ob
def crystal(name,base,direction,radius,material,sides=6):
    base=Vector(base);d=Vector(direction);axis=d.normalized();ref=Vector((0,1,0))
    if abs(ref.dot(axis))>.9:ref=Vector((1,0,0))
    u=axis.cross(ref).normalized();v=axis.cross(u).normalized();verts=[]
    if name.startswith('OrbitPrism'):
        for i in range(4):
            a=math.tau*i/4;verts.append(base+d*.5+radius*(math.cos(a)*u+math.sin(a)*v))
        verts.extend([base,base+d]);faces=[]
        for i in range(4):faces.extend([(4,(i+1)%4,i),(5,i,(i+1)%4)])
        return mesh(name,verts,faces,material)
    for t,r in [(0,.8),(.65,1)]:
        for i in range(sides):
            a=math.tau*i/sides;verts.append(base+d*t+radius*r*(math.cos(a)*u+math.sin(a)*v))
    verts.extend([base-axis*.03,base+d]);faces=[]
    for i in range(sides):
        j=(i+1)%sides;faces.extend([(i,j,j+sides,i+sides),(2*sides,j,i),(2*sides+1,i+sides,j+sides)])
    return mesh(name,verts,faces,material)
def tube(name,points,radii,material,col=fxcol,sides=7):
    points=list(map(Vector,points));verts=[]
    for i,p in enumerate(points):
        d=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
        ref=Vector((0,0,1)) if abs(d.z)<.9 else Vector((0,1,0))
        u=d.cross(ref).normalized();v=d.cross(u).normalized()
        for j in range(sides):
            a=j*math.tau/sides;verts.append(p+radii[i]*(math.cos(a)*u+math.sin(a)*v))
    faces=[]
    for i in range(len(points)-1):
        for j in range(sides):
            k=i*sides+j;l=i*sides+(j+1)%sides;faces.append((k,l,l+sides,k+sides))
    faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))])
    return mesh(name,verts,faces,material,col)
def loop_bob(ob,height=.05,phase=0):
    start=ob.location.copy()
    for f in (1,37,73,109,145):
        ob.location=start+Vector((0,0,height*math.sin((f-1)/144*math.tau+phase)))
        ob.keyframe_insert(data_path='location',frame=f)
    ob['motion']='bob';ob['bobSourceUnits']=height
def loop_spin(ob):
    ob.rotation_euler.z=0;ob.keyframe_insert(data_path='rotation_euler',frame=1)
    ob.rotation_euler.z=math.tau;ob.keyframe_insert(data_path='rotation_euler',frame=145)
    ob['motion']='orbit';ob['periodSeconds']=6
    if ob.animation_data:
        action=ob.animation_data.action
        for slot in action.slots:
            for layer in action.layers:
                for strip in layer.strips:
                    bag=strip.channelbag(slot)
                    if bag:
                        for curve in bag.fcurves:
                            for point in curve.keyframe_points:point.interpolation='LINEAR'

def loop_sway(ob,phase=0):
    # Keep the moving halo in the rear hemisphere for its entire loop.
    # A full revolution would pass straight through the face and snout.
    for frame in (1,37,73,109,145):
        ob.rotation_euler.z=.07*math.sin((frame-1)/144*math.tau+phase)
        ob.keyframe_insert(data_path='rotation_euler',frame=frame)
    ob['motion']='orbital sway';ob['periodSeconds']=6

if KEY in ('rockslide','quartz'):
    for side in (-1,1):
        for j in range(3):
            direction=Vector((side*.8,.18+j*.21,.48-j*.09)).normalized()
            hit,point,normal,_=parts['Body'].ray_cast(direction*4,-direction);assert hit
            material=flat('Accent_'+str(side)+'_'+str(j),P[1 if j%2 else 2],rough=.83 if KEY=='rockslide' else .24)
            direction=normal*.20+Vector((0,.04,.07)) if KEY=='rockslide' else normal*.12+Vector((0,.03,.33+j*.07))
            crystal(('RockPlate' if KEY=='rockslide' else 'QuartzPoint')+f'_{side}_{j}',point-normal*.09,direction,.22 if KEY=='rockslide' else .10,material,5 if KEY=='rockslide' else 6)
if KEY=='supernova':
    # Buried flame roots keep the sculpted corona attached through the bob.
    # Only the small cinders float; large disconnected arcs read as bananas.
    for j,a in enumerate((.20,.65,1.05,2.09,2.50,2.94)):
        direction=Vector((math.cos(a),math.sin(a),.23)).normalized()
        hit,point,normal,_=parts['Body'].ray_cast(direction*4,-direction);assert hit
        base=point-normal*.11
        along=Vector((normal.x*.19,normal.y*.19,.63+.10*(j%2)))
        bend=Vector((-normal.x*.24,-normal.y*.24,.06))
        u=Vector((-math.sin(a),math.cos(a),0));v=direction
        vertices=[];profile=((0,.38),(.20,1),(.43,.85),(.67,.54),(.87,.23),(.99,.012))
        for t,width in profile:
            center=base+along*t+bend*(t*t)
            for k in range(8):
                angle=k*math.tau/8;vertices.append(center+u*(math.cos(angle)*.19*width)+v*(math.sin(angle)*.05*width))
        faces=[]
        for i in range(len(profile)-1):
            for k in range(8):
                n=i*8+k;m=i*8+(k+1)%8;faces.append((n,m,m+8,n+8))
        faces.extend([tuple(reversed(range(8))),tuple((len(profile)-1)*8+k for k in range(8))])
        ob=mesh('SolarFlame_'+str(j),vertices,faces,flat('SolarFlameMat'+str(j),[255,150,30] if j%2 else [240,85,22],.75))
        loop_bob(ob,.025,j*.5)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.058,location=(1.29*math.cos(a),1.29*math.sin(a),.30+.24*(j%2)))
        cinder=bpy.context.object;cinder.name='SolarCinder_'+str(j);move(cinder,fxcol);assign(cinder,flat(cinder.name,[255,146,28],1.2));extras.append(cinder);loop_bob(cinder,.10,j*.5)
if KEY=='prismatic':
    for j in range(6):
        a=.08+j*(math.pi-.16)/5;rgb=tuple(int(v*230) for v in colorsys.hsv_to_rgb(j/6,.68,1))
        ob=crystal('OrbitPrism_'+str(j),(1.5*math.cos(a),1.5*math.sin(a)+.15,.02+.25*math.sin(a)),(.12*math.cos(a),.12*math.sin(a),.52),.19,flat('Prism'+str(j),rgb,.08,metal=.3,rough=.2))
        loop_sway(ob)
    points=[(1.5*math.cos(a),1.5*math.sin(a)+.15,.11+.25*math.sin(a)) for a in np.linspace(.08,math.pi-.08,45)]
    ob=tube('PrismaticOrbitArc',points,[.015]*len(points),flat('OrbitLight',(128,150,248),1));loop_sway(ob)
if KEY=='stormcaller':
    for side in (-1,1):
        cloud=[]
        for j,(dx,dy,dz,size) in enumerate([(0,0,0,.27),(.18,.08,.02,.24),(-.15,.06,.06,.23),(.03,-.12,.12,.25)]):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=size,location=(side*(1.14+dx),.40+dy,.22+dz))
            ob=bpy.context.object;ob.name=f'StormCloud_{side}_{j}';move(ob,fxcol);assign(ob,flat(ob.name,P[1] if j%2 else P[0],rough=.88));extras.append(ob);loop_bob(ob,.055,side)
        bolt=[(side*1.2,.39,.07),(side*1.10,.40,-.13),(side*1.26,.39,-.12),(side*1.14,.40,-.43)]
        ob=tube('LightningFork_'+str(side),bolt,[.045,.045,.037,.005],flat('Lightning'+str(side),P[2],2),sides=4);loop_bob(ob,.055,side)

# These small animated meshes are a Blender visual proxy for existing Roblox
# ParticleEmitters. They are deliberately excluded from every mesh export.
if TIER!='rare':
    for j in range(14):
        a=random.uniform(0,math.tau);r=random.uniform(1.14,1.47);pos=Vector((math.cos(a)*r,math.sin(a)*r,random.uniform(-.22,1.03)))
        if pos.y<-.65:pos.y=.3+abs(pos.y)*.4
        rgb=P[1] if KEY=='hologram' else P[-1]
        if KEY=='sugarrush':rgb=P[j%len(P)]
        if KEY=='ghost':
            points=[pos+Vector((.06*math.sin(t*math.pi),0,t*.22)) for t in np.linspace(0,1,8)]
            ob=tube('AuraWisp_'+str(j),points,[.003+.012*math.sin(t*math.pi) for t in np.linspace(0,1,8)],flat('Wisp'+str(j),rgb,1),auracol)
        else:
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=random.uniform(.010,.027),location=pos)
            ob=bpy.context.object;ob.name='AuraMote_'+str(j);move(ob,auracol);assign(ob,flat(ob.name,rgb,2));aura.append(ob)
        loop_bob(ob,.15,j*.6)

assert signatures=={n:signature(o) for n,o in parts.items()}
scene['skinKey']=KEY;scene['revision']='og-redesign-v1';scene['tier']=TIER;scene['aura']=SPEC['aura'] or ''
scene['design']=SPEC['design'];scene['runtimeStatus']='Local authoring complete; Roblox upload/integration pending'
scene.frame_set(1)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HOME/'source'/f'{KEY}-og-v1-procedural.blend'))

# Bake each material's actual 3D field to the original UVs. No UV painting.
scene.render.engine='CYCLES';scene.cycles.samples=1;scene.cycles.device='CPU'
scene.render.bake.margin=12;scene.render.bake.use_selected_to_active=False
maps={};size=1024
groups={'body':[parts['Body']],'trim':[parts[n] for n in ('Snout','Ears','Legs','Tail')]}
channels=['color']+(['emissive'] if TIER!='rare' else [])+(['metal','rough'] if KEY=='verdigris' else [])
for group,objects in groups.items():
    materials={m for ob in objects for m in ob.data.materials};saved={}
    for mat in materials:
        output=next(n for n in mat.node_tree.nodes if n.type=='OUTPUT_MATERIAL')
        saved[mat]=output.inputs['Surface'].links[0].from_socket
    for channel in channels:
        image=bpy.data.images.new(KEY+'_'+group+'_'+channel,size*2,size*2,alpha=True)
        if channel!='color':image.colorspace_settings.name='Non-Color'
        for mat in materials:
            nt=mat.node_tree;output=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL')
            nt.links.new(nt.nodes['BAKE_'+channel.upper()].outputs[0],output.inputs['Surface'])
            tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image;nt.nodes.active=tex
        bpy.ops.object.select_all(action='DESELECT')
        for ob in objects:ob.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.bake(type='EMIT')
        image.scale(size,size)
        pixels=np.empty(size*size*4,dtype=np.float32);image.pixels.foreach_get(pixels);pixels[3::4]=1;image.pixels.foreach_set(pixels)
        path=HOME/'sheets'/f'{KEY}_og_v1_{group}_{channel}.png';image.filepath_raw=str(path);image.file_format='PNG';image.save();image.pack()
        maps[group,channel]=(image,path)
        print('BAKED',KEY,group,channel,flush=True)
    for mat in materials:
        nt=mat.node_tree;output=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');nt.links.new(saved[mat],output.inputs['Surface'])
    # The review/export uses the baked maps, not the original node field.
    mat=flat(group+'_Baked',P[0],rough=.65);nt=mat.node_tree;p=nt.nodes['Principled BSDF']
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=maps[group,'color'][0];nt.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    if TIER!='rare':
        glow=nt.nodes.new('ShaderNodeTexImage');glow.image=maps[group,'emissive'][0]
        nt.links.new(tex.outputs['Color'],p.inputs['Emission Color'])
        mul=nt.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';nt.links.new(glow.outputs['Color'],mul.inputs[0])
        for frame,strength in [(1,.65),(37,1.35),(73,.65),(109,1.35),(145,.65)]:
            mul.inputs[1].default_value=strength;mul.inputs[1].keyframe_insert(data_path='default_value',frame=frame)
        nt.links.new(mul.outputs[0],p.inputs['Emission Strength'])
    if KEY=='verdigris':
        for channel,socket in [('metal','Metallic'),('rough','Roughness')]:
            tex2=nt.nodes.new('ShaderNodeTexImage');tex2.image=maps[group,channel][0];nt.links.new(tex2.outputs['Color'],p.inputs[socket])
    elif KEY in ('marble','quartz','ghost','prismatic','hologram'):p.inputs['Roughness'].default_value=.28
    elif KEY in ('rockslide','charcoal'):p.inputs['Roughness'].default_value=.88
    for ob in objects:assign(ob,mat)

scene.frame_set(1)
motion_checks={}
if TIER!='rare':
    original={ob.name:ob.matrix_world.copy() for ob in extras+aura}
    scene.frame_set(145);bpy.context.view_layer.update()
    closure=max((max(abs(ob.matrix_world[i][j]-original[ob.name][i][j]) for i in range(4) for j in range(4)) for ob in extras+aura),default=0)
    assert closure<1e-5,('animation seam',KEY,closure)
    motion_checks['loopClosureError']=closure
    if TIER=='legendary':
        for frame in (1,19,37,55,73,91,109,127,145):
            scene.frame_set(frame);bpy.context.view_layer.update()
            for ob in extras:
                for vertex in ob.data.vertices:
                    v=ob.matrix_world@vertex.co
                    assert not (abs(v.x)<.64 and v.y<-.72 and -.60<v.z<.70),('FX in face clearance',KEY,ob.name,frame)
        motion_checks['faceClearanceSampledFrames']=9
    scene.frame_set(1)
exported=[]
for label,objects in [('complete',list(parts.values())+extras),('accessories',extras)]:
    if not objects:continue
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    path=HOME/'package'/f'{KEY}-og-v1-{label}.fbx'
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=6.0,apply_unit_scale=False,bake_space_transform=True,axis_forward='-Z',axis_up='Y',use_mesh_modifiers=False,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
    before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(path),use_anim=False)
    imported=[ob for ob in bpy.data.objects if ob not in before];import_mesh=[ob for ob in imported if ob.type=='MESH']
    expected=sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in objects)
    assert len(import_mesh)==len(objects),(KEY,label,'FBX mesh count',len(import_mesh),len(objects),[o.name for o in import_mesh])
    assert sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in import_mesh)==expected,(KEY,label,'FBX triangle count')
    def bounds(obs,factor=1):
        pts=[(ob.matrix_world@v.co)*factor for ob in obs for v in ob.data.vertices]
        return [min(p[i] for p in pts) for i in range(3)]+[max(p[i] for p in pts) for i in range(3)]
    bounds_error=max(abs(a-b) for a,b in zip(bounds(objects,6),bounds(import_mesh)))
    assert bounds_error<.001,(KEY,label,'FBX bounds',bounds_error)
    for ob in imported:bpy.data.objects.remove(ob,do_unlink=True)
    exported.append({'file':path.name,'meshCount':len(objects),'triangles':expected,'roundTripChecked':True,'roundTripBoundsError':bounds_error})

world=bpy.data.worlds.new(KEY+'_World');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(*lin((181,193,211)),1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5
def light(name,pos,power,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);stage.objects.link(ob);ob.location=pos;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
light('Key',(-3,-4,6),370,5);light('Fill',(4,-1,3),190,4);light('Rim',(1,4,5),390,3)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-1.025));ground=bpy.context.object;ground.name='ReviewGround';move(ground,stage);assign(ground,flat('Ground',(185,187,189),rough=.95))
data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',data);stage.objects.link(camera);scene.camera=camera;data.type='ORTHO';data.ortho_scale=4.0 if TIER=='legendary' else 3.45
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.image_settings.file_format='PNG'
shots=[('hero',(-4,-6,2.8),(0,0,.08)),('back',(-4,6,2.8),(0,0,.08))]
for name,pos,target in shots:
    camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(HOME/'preview'/f'{KEY}-og-v1-{name}.png');bpy.ops.render.render(write_still=True)
camera.location=shots[0][1];camera.rotation_euler=(Vector(shots[0][2])-camera.location).to_track_quat('-Z','Y').to_euler()
if TIER!='rare':
    # A real second animation state catches static/disconnected FX accidentally shipped as motion.
    scene.frame_set(37);scene.render.filepath=str(HOME/'preview'/f'{KEY}-og-v1-motion.png');bpy.ops.render.render(write_still=True);scene.frame_set(1)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False;area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=parts['Body']
bpy.ops.wm.save_as_mainfile(filepath=str(HOME/'package'/f'{KEY}-og-v1.blend'))
checks=[]
for ob in list(parts.values())+extras:
    bm=bmesh.new();bm.from_mesh(ob.data);nonmanifold=sum(not e.is_manifold for e in bm.edges);bm.free()
    tris=sum(len(p.vertices)-2 for p in ob.data.polygons)
    assert tris<20000 and nonmanifold==0,(KEY,ob.name,tris,nonmanifold)
    pts=[ob.matrix_world@v.co for v in ob.data.vertices];lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
    checks.append({'name':ob.name,'role':'base' if ob in parts.values() else 'accessory','triangles':tris,'nonManifoldEdges':nonmanifold,'motion':ob.get('motion'),
        'offsetRobloxStuds':[(lo[0]+hi[0])*3,(lo[2]+hi[2])*3+6.62,-(lo[1]+hi[1])*3],
        'sizeRobloxStuds':[(hi[i]-lo[i])*6 for i in (0,2,1)]})
assert signatures=={n:signature(ob) for n,ob in parts.items()}
report={'skin':KEY,'name':SPEC['name'],'tier':TIER,'revision':'og-redesign-v1','status':'Built locally; Roblox upload and installation pending','design':SPEC['design'],
    'baseGeometryAndUVPreserved':True,'sourceGeometrySignatures':signatures,'parts':checks,'exports':exported,'aura':SPEC['aura'],
    'auraPreviewObjects':len(aura),'auraExcludedFromMeshExports':True,'animation':{'frames':[1,145],'fps':24,'loopSeconds':6,'animatedGeometry':sum(bool(o.animation_data) for o in extras),'materialPulse':TIER!='rare',**motion_checks},
    'tierChecks':{'authoredCoat':True,'glowAndAura':TIER!='rare','substantialAnimatedGeometry':TIER=='legendary' and len(extras)>=6},
    'textures':[{'role':g+'_'+ch,'file':str(path.relative_to(HOME)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[1024,1024]} for (g,ch),(im,path) in maps.items()],
    'generator':'assets/piggies/og-redesign-v1/build_og.py','runtimeNotes':'Use supplied maps on shared body/trim; replace old procedural pattern. Preserve rarity. Use existing aura key; preview motes are not export meshes. New accessories replace, not stack with, old shard/FX geometry. Full Blender animation is retained in packed blend; FBX is a static import pose.'}
(HOME/'package/og-v1-asset-report.json').write_text(json.dumps(report,indent=2)+'\n')
(HOME/'generate/og-v1-spec.json').write_text(json.dumps(SPEC,indent=2)+'\n')
print('OG_COMPLETE',KEY,json.dumps({'extraTriangles':sum(p['triangles'] for p in checks if p['role']=='accessory'),'maps':len(maps),'basePreserved':True}),flush=True)
