"""Build the approved Arcade collection without altering live Config or shared pig meshes.

blender -b --python assets/piggies/arcade-build-v1/build_arcade.py -- --skin marble
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
scene = bpy.context.scene;scene.name = SPEC['name']+' - Arcade v1'
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
"""Spatial texture fields; executed within build_arcade.py's authoring context."""
def paint(name,mode):
    p=Paint(name,P[0]);o=p.op;x,y,z=p.x,p.y,p.z
    def mul(a,b):return o('MULTIPLY',a,b)
    def add(a,b):return o('ADD',a,b)
    def sub(a,b):return o('SUBTRACT',a,b)
    def absolute(a):return o('ABSOLUTE',a)
    def less(a,b):return o('LESS_THAN',a,b)
    def greater(a,b):return o('GREATER_THAN',a,b)
    def both(a,b):return mul(a,b)
    def quant(a,n=22):return o('DIVIDE',add(o('FLOOR',mul(a,n)),.5),n)
    def hashv(a,b):return o('FRACT',mul(o('SINE',add(mul(a,12.9898),mul(b,78.233))),43758.5453))
    def box(a,b,cx,cy,rx,ry):return both(less(absolute(sub(a,cx)),rx),less(absolute(sub(b,cy)),ry))
    if KEY=='playerone':
        # Fixed pixel clusters in object space, not a low-resolution screen filter.
        qx,qy,qz=(quant(a) for a in (x,y,z))
        shade=add(add(mul(qx,-.22),mul(qy,-.30)),add(mul(qz,.43),.48))
        checker=o('MODULO',add(o('FLOOR',mul(y,22)),o('FLOOR',mul(z,22))),2)
        shade=add(shade,mul(sub(checker,.5),.045))
        reds=[[88,24,46],[134,29,47],[178,32,48],[218,44,56],[246,74,77],[255,125,115]]
        creams=[[129,97,73],[171,139,98],[206,179,130],[235,216,169],[255,237,195],[255,249,221]]
        cream=mode in ('snout','legs','ear','tail')
        if cream and mode!='ear':
            # Snout/limb local coordinates are not centered like the body.
            shade=add(1.10 if mode=='legs' else .68,mul(qz,.40 if mode=='legs' else .30))
            shade=add(shade,mul(qy,-.12))
        p.color=p.ramp(shade,creams if cream else reds,'CONSTANT');p.rough=1
        p.bs.inputs['Specular IOR Level'].default_value=0
        if mode=='body' and name.startswith('Body'):
            # Seven-row 1P bitmap, mirrored onto the two side surfaces.
            side_y=mul(y,o('SIGN',x))
            u=o('FLOOR',o('DIVIDE',add(side_y,.30),.065));v=o('FLOOR',o('DIVIDE',sub(.35,z),.065))
            bitmap=['01001110','11001001','01001001','01001110','01001000','01001000','11101000']
            glyph=0
            for row,line in enumerate(bitmap):
                for col,c in enumerate(line):
                    if c=='1':glyph=o('MAXIMUM',glyph,both(less(absolute(sub(u,col)),.1),less(absolute(sub(v,row)),.1)))
            glyph=both(glyph,greater(absolute(x),.78));p.color=p.mix(p.color,P[1],glyph)
    elif KEY=='retrocarpet':
        # Spherical wrap avoids the stretched markings of planar side projection.
        angle=o('ARCTAN2',y,x);radius=o('SQRT',add(mul(x,x),mul(y,y)))
        latitude=o('ARCTAN2',z,radius)
        u=mul(angle,2.22);v=mul(latitude,3.2)
        iu=o('FLOOR',u);iv=o('FLOOR',v);a=sub(o('FRACT',u),.5);b=sub(o('FRACT',v),.5)
        seed=hashv(iu,iv);kind=o('FLOOR',mul(seed,4))
        a=sub(a,mul(sub(hashv(add(iu,7),iv),.5),.16))
        b=sub(b,mul(sub(hashv(iu,add(iv,5)),.5),.16))
        flip=greater(hashv(add(iu,11),iv),.5)
        a=mul(a,sub(1,mul(flip,2)))
        for k in range(4):
            select=less(absolute(sub(kind,k)),.1)
            if k==0:
                wave=mul(sub(mul(absolute(sub(o('FRACT',mul(add(a,.32),3.2)),.5)),2),.5),.55)
                mark=both(less(absolute(sub(b,wave)),.115),less(absolute(a),.32));rgb=P[1]
            elif k==1:
                wave=mul(o('SINE',mul(a,15)),.17)
                mark=both(less(absolute(sub(b,wave)),.105),less(absolute(a),.33));rgb=P[2]
            elif k==2:
                # Equilateral triangle contour, signed distance to three sides.
                d=o('MAXIMUM',mul(b,-1),add(mul(absolute(a),.866),mul(b,.5)))
                mark=both(less(d,.21),greater(d,.12));rgb=P[3]
            else:
                mark=less(add(mul(a,a),mul(b,b)),.050);rgb=P[4]
            p.color=p.mix(p.color,rgb,both(mark,select))
        if mode=='snout':p.color=p.rgb([103,67,149])
        if mode in ('legs','ear'):p.color=p.rgb(P[1])
        if mode=='tail':p.color=p.rgb([70,43,112])
        if name.startswith('Ears') and mode=='body':p.color=p.rgb(P[0])
        p.rough=.82
    elif KEY=='respawn':
        u=mul(y,9);v=mul(z,9);iu=o('FLOOR',u);iv=o('FLOOR',v)
        cell=hashv(iu,iv)
        level=add(add(z,mul(y,-.20)),mul(cell,.55))
        pattern=less(level,.40)
        pattern=o('MAXIMUM',pattern,both(greater(cell,.93),less(z,.52)))
        bright=both(pattern,greater(cell,.47))
        ink=p.ramp(cell,[P[0],P[2],P[1],P[3]],'CONSTANT')
        p.color=p.mix(P[0],ink,pattern)
        p.glow=mul(bright,.70)
        if mode=='body' and name.startswith('Body'):
            qy=quant(y,16);qz=quant(z,16)
            stem=box(qy,qz,.05,.30,.055,.17)
            arrow=both(less(absolute(sub(qy,.05)),sub(.58,qz)),both(greater(qz,.37),less(qz,.58)))
            arrow=both(o('MAXIMUM',stem,arrow),greater(absolute(x),.74))
            p.color=p.mix(p.color,P[1],arrow);p.glow=o('MAXIMUM',p.glow,mul(arrow,1.15))
        if mode=='snout':p.color=p.rgb([66,36,119]);p.glow=0
        if mode=='ear':p.color=p.rgb([60,30,109]);p.glow=0
        if mode=='tail':p.color=p.rgb(P[2]);p.glow=0
        p.rough=.65
    elif KEY=='jackpot':
        p.color=p.rgb(P[0]);p.rough=.42
        if mode=='body':
            u=mul(y,2.2);v=mul(z,2.2)
            a=sub(o('FRACT',u),.5);b=sub(o('FRACT',v),.5)
            seed=hashv(o('FLOOR',u),o('FLOOR',v))
            diamond=less(add(absolute(a),absolute(b)),.22)
            angle=o('ARCTAN2',b,a);r=o('SQRT',add(mul(a,a),mul(b,b)))
            star=less(r,add(.15,mul(o('COSINE',mul(angle,5)),.06)))
            marks=o('MAXIMUM',both(star,less(seed,.36)),both(diamond,greater(seed,.69)))
            p.color=p.mix(p.color,P[2],marks)
        if mode in ('snout','ear'):p.color=p.rgb(P[1])
        if mode in ('legs','tail'):p.color=p.rgb(P[2]);p.metal=.55
    elif KEY=='pixel':
        q=p.vec(quant(o('ARCTAN2',y,x),12),quant(z,9),0)
        noise=mul(sub(p.noise(3.2,0,q),.27),2.3)
        p.color=p.ramp(noise,[P[0],P[0],P[1],P[2],P[3],P[3]],'CONSTANT')
        if mode in ('snout','ear','tail') or name.startswith('Ears'):p.color=p.rgb(P[2])
        if mode=='legs':p.color=p.rgb(P[3])
        p.rough=.8
    elif KEY=='circuitboard':
        # Repeating printed right-angle traces and solder pads in a wrapping field.
        angle=o('ARCTAN2',y,x);u=mul(angle,1.3);v=mul(z,2.0)
        a=sub(o('FRACT',u),.5);b=sub(o('FRACT',v),.5)
        seed=hashv(o('FLOOR',u),o('FLOOR',v))
        a=mul(a,sub(1,mul(greater(seed,.5),2)))
        trace=both(less(absolute(add(a,.22)),.029),less(b,.20))
        trace=o('MAXIMUM',trace,both(less(absolute(sub(b,.20)),.029),greater(a,-.22)))
        trace=o('MAXIMUM',trace,both(less(absolute(sub(a,.18)),.022),greater(b,.20)))
        trace=o('MAXIMUM',trace,both(less(absolute(add(b,.18)),.022),greater(a,-.05)))
        pad=p.ellipse((a,b),(-.22,-.27),(.080,.080))
        pad=o('MAXIMUM',pad,p.ellipse((a,b),(.18,.34),(.065,.065)))
        chip=both(box(a,b,.20,-.15,.12,.11),greater(seed,.58))
        p.color=p.mix(P[0],P[2],mul(seed,.32));p.color=p.mix(p.color,P[1],o('MAXIMUM',trace,pad));p.color=p.mix(p.color,P[3],chip)
        if mode=='snout':p.color=p.rgb([24,60,46])
        if mode in ('ear','legs'):p.color=p.rgb(P[1])
        if mode=='tail' or (name.startswith('Ears') and mode=='body'):p.color=p.rgb(P[0])
        p.rough=.62
    elif KEY=='powerup':
        qy=quant(y,14);qz=quant(z,14)
        bands=both(less(o('FRACT',mul(add(qy,mul(qz,.6)),3)),.30),less(z,-.25))
        p.color=p.mix(P[0],P[2],bands)
        stem=box(qy,qz,0,.10,.095,.27)
        head=both(less(absolute(qy),sub(.68,qz)),both(greater(qz,.28),less(qz,.68)))
        arrow=both(o('MAXIMUM',stem,head),greater(absolute(x),.67))
        p.color=p.mix(p.color,P[1],arrow);p.glow=mul(arrow,1.05)
        bars=both(less(absolute(sub(z,-.39)),.045),both(less(absolute(y),.36),less(o('FRACT',mul(y,9)),.65)))
        bars=both(bars,greater(absolute(x),.64));p.color=p.mix(p.color,P[3],bars);p.glow=o('MAXIMUM',p.glow,mul(bars,.5))
        if mode=='snout':p.color=p.rgb([65,122,83]);p.glow=0
        if mode=='legs':p.color=p.rgb(P[2]);p.glow=0
        if mode=='ear':p.color=p.rgb(P[1]);p.glow=0
        if mode=='tail' or (name.startswith('Ears') and mode=='body'):p.color=p.rgb(P[0]);p.glow=0
    elif KEY=='synthwave':
        long=o('ARCTAN2',y,x)
        gridu=less(absolute(sub(o('FRACT',mul(long,3.5)),.5)),.035)
        gridv=less(absolute(sub(o('FRACT',mul(z,6)),.5)),.030)
        grid=both(o('MAXIMUM',gridu,gridv),less(z,-.12))
        p.color=p.mix(P[0],P[1],grid);p.glow=mul(grid,.75)
        disc=p.ellipse((y,z),(.14,.13),(.43,.43));disc=both(disc,greater(absolute(x),.66))
        stripes=greater(o('FRACT',mul(z,14)),.22)
        sun=both(disc,stripes);suncolor=p.ramp(add(mul(z,1.5),.4),[P[2],P[3]])
        p.color=p.mix(p.color,suncolor,sun);p.glow=o('MAXIMUM',p.glow,mul(sun,.65))
        if mode=='snout':p.color=p.rgb([72,42,115]);p.glow=0
        if mode=='legs':p.color=p.mix(P[0],P[2],grid);p.glow=mul(grid,.65)
        if mode=='ear':p.color=p.rgb(P[2]);p.glow=0
        if mode=='tail' or (name.startswith('Ears') and mode=='body'):p.color=p.rgb(P[0]);p.glow=0
    elif KEY in ('finalboss','mechaplayer'):
        u=mul(add(y,mul(z,.35)),2.7);v=mul(z,2.7)
        a=o('FRACT',u);b=o('FRACT',v)
        edge=o('MINIMUM',o('MINIMUM',a,sub(1,a)),o('MINIMUM',b,sub(1,b)))
        panel=hashv(o('FLOOR',u),o('FLOOR',v))
        line=both(less(edge,.018),greater(panel,.43));line=both(line,greater(y,-.62))
        p.color=p.mix(P[0],P[2],mul(panel,.6));p.color=p.mix(p.color,[24,27,40],less(edge,.035))
        p.color=p.mix(p.color,P[1],line);p.glow=mul(line,.85)
        if KEY=='finalboss':
            face=both(less(y,-.64),greater(z,-.25))
            p.color=p.mix(p.color,[225,143,172],face);p.glow=mul(p.glow,sub(1,face))
        if KEY=='mechaplayer':
            warning=both(less(absolute(add(z,.34)),.055),less(o('FRACT',mul(add(y,z),12)),.5))
            p.color=p.mix(p.color,P[3],warning)
        if mode=='snout':p.color=p.rgb([218,121,151] if KEY=='finalboss' else [87,120,147]);p.glow=0
        if mode=='legs':p.color=p.rgb([214,128,157] if KEY=='finalboss' else P[2]);p.glow=0
        if mode=='ear':p.color=p.rgb([201,104,144] if KEY=='finalboss' else P[1]);p.glow=0
        if mode=='tail' or (name.startswith('Ears') and mode=='body'):p.color=p.rgb([222,146,176] if KEY=='finalboss' else P[0]);p.glow=0
    paints[name]=p
    return p.finish()


assign(parts['Body'],paint('Body_coat','body'))
assign(parts['Snout'],paint('Snout_coat','snout'))
assign(parts['Legs'],paint('Legs_coat','legs'))
assign(parts['Tail'],paint('Tail_coat','tail'))
ears=parts['Ears']
for i in range(len(ears.data.materials)):ears.data.materials[i]=paint('Ears_'+str(i),'body' if i==0 else 'ear')
eye_rgb=P[1]
lit_eyes=TIER!='rare' and KEY in ('respawn','powerup','synthwave','finalboss','mechaplayer')
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

"""Arcade accessory geometry and closed six-second animation loops."""
def linear_keys(ob):
    if ob.animation_data:
        action=ob.animation_data.action
        for slot in action.slots:
            for layer in action.layers:
                for strip in layer.strips:
                    bag=strip.channelbag(slot)
                    if bag:
                        for curve in bag.fcurves:
                            for point in curve.keyframe_points:point.interpolation='LINEAR'

def box_mesh(name,center,dimensions,material,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center)
    ob=bpy.context.object;ob.name=name;ob.dimensions=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    move(ob,fxcol);assign(ob,material);extras.append(ob)
    if bevel:
        mod=ob.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob

if KEY=='respawn':
    # Small cubes are actual accessories; the body squares remain flat artwork.
    for j in range(7):
        side=-1 if j%2 else 1
        pos=Vector((side*(.72+.10*(j%3)),.63+.035*j,.25+.13*j))
        ob=box_mesh('RespawnPixel_'+str(j),pos,(.105,.105,.105),flat('Pixel'+str(j),P[1 if j%3 else 3],1.4))
        for frame in (1,19,37,55,73,91,109,127,145):
            t=((frame-1)/144+j/7)%1
            ob.location=pos+Vector((side*.12*math.sin(t*math.pi),.08*math.sin(t*math.pi),t*.38))
            # At wrap the cube has disappeared, avoiding a visible teleport.
            size=max(.015,math.sin(math.pi*t))
            ob.scale=(size,size,size)
            ob.keyframe_insert(data_path='location',frame=frame);ob.keyframe_insert(data_path='scale',frame=frame)
        ob['motion']='rise and dissolve';linear_keys(ob)

if KEY=='jackpot':
    brass=flat('Brass',[197,137,41],metal=.66,rough=.3)
    dark=flat('Housing enamel',[96,28,48],metal=.12,rough=.4)
    amber=flat('Amber bulbs',[255,176,40],1.7,rough=.3)
    cream=flat('Reel end caps',[222,199,144],metal=.1,rough=.55)
    # A curved saddle follows the actual body, burying its underside slightly.
    verts=[];nx,ny=10,8
    for layer in (0,1):
        for iy in range(ny+1):
            yy=-.09+.69*iy/ny
            for ix in range(nx+1):
                xx=-.56+1.12*ix/nx
                hit,co,normal,_=parts['Body'].ray_cast(Vector((xx,yy,3)),Vector((0,0,-1)));assert hit
                zz=co.z-.025 if layer==0 else co.z+.055
                verts.append((xx,yy,zz))
    faces=[];offset=(nx+1)*(ny+1)
    for layer in (0,1):
        for iy in range(ny):
            for ix in range(nx):
                k=layer*offset+iy*(nx+1)+ix
                face=(k,k+1,k+nx+2,k+nx+1);faces.append(face if layer else tuple(reversed(face)))
    boundary=list(range(nx+1))+[iy*(nx+1)+nx for iy in range(1,ny+1)]+[ny*(nx+1)+ix for ix in range(nx-1,-1,-1)]+[iy*(nx+1) for iy in range(ny-1,0,-1)]
    for i,k in enumerate(boundary):
        j=boundary[(i+1)%len(boundary)];faces.append((k,j,j+offset,k+offset))
    saddle=mesh('ReelSaddle',verts,faces,brass);saddle['attachment']='thin curved saddle follows Body with .025 source-unit embed'
    for xs in (-.50,.50):
        for ys in (-.025,.53):
            hit,co,normal,_=parts['Body'].ray_cast(Vector((xs,ys,3)),Vector((0,0,-1)));assert hit
            top=.94;bottom=co.z+.025
            box_mesh('SaddleSupport_'+str(xs)+'_'+str(ys),(xs,ys,(top+bottom)/2),(.08,.09,top-bottom),brass,.012)
    box_mesh('RearHousing',(0,.64,1.15),(1.18,.09,.55),dark,.035)
    box_mesh('FrontSill',(0,-.035,.925),(1.19,.10,.10),brass,.023)
    box_mesh('UpperRail',(0,.27,1.515),(1.19,.10,.065),brass,.018)
    for xside in (-.585,.585):
        box_mesh('ReelSide_'+str(xside),(xside,.29,1.19),(.075,.64,.59),brass,.055)

    def polygon_mask(xx,yy,points):
        inside=np.zeros(xx.shape,dtype=bool)
        for i in range(len(points)):
            x1,y1=points[i];x2,y2=points[i-1]
            inside^=((y1>yy)!=(y2>yy))&(xx<(x2-x1)*(yy-y1)/(y2-y1+1e-12)+x1)
        return inside

    def reel_material(j):
        w,h=256,1024;yy,xx=np.mgrid[0:h,0:w];u=xx/(w-1);v=yy/(h-1)
        pix=np.ones((h,w,4),dtype=np.float32);pix[:,:,:3]=lin((247,229,183))
        pix[(u<.035)|(u>.965),:3]=lin((181,130,48))
        for k in range(4):
            cy=(k+.5)/4;ax=(u-.5)/.40;ay=(cy-v)/.085
            symbol=(j+k)%3
            if symbol==0:
                pts=[((.93 if n%2==0 else .42)*math.cos(math.pi/2+n*math.pi/5),(.93 if n%2==0 else .42)*math.sin(math.pi/2+n*math.pi/5)) for n in range(10)]
                outer=polygon_mask(ax,ay,pts);inner=polygon_mask(ax*1.2,ay*1.2,pts)
                pix[outer,:3]=lin((154,86,18));pix[inner,:3]=lin((246,178,35))
            elif symbol==1:
                stem=(np.abs(ax+.14*ay)<.08)&(ay>.05)&(ay<.9)
                leaf=((ax-.3)/.38)**2+((ay-.72)/.16)**2<1
                fruit=((ax+.30)**2+(ay+.25)**2<.24)|((ax-.31)**2+(ay+.25)**2<.24)
                pix[stem|leaf,:3]=lin((48,110,48));pix[fruit,:3]=lin((205,35,56))
                shine=((ax+.40)**2+(ay+.09)**2<.014)|((ax-.21)**2+(ay+.09)**2<.014)
                pix[shine,:3]=lin((255,128,129))
            else:
                d=np.abs(ax)+np.abs(ay)*.78
                pix[d<.86,:3]=lin((134,26,49));pix[d<.66,:3]=lin((224,49,70))
                pix[(d<.66)&(ax<0),:3]=lin((249,105,109))
        im=bpy.data.images.new(f'ReelSymbols_{j}',w,h,alpha=True);im.pixels.foreach_set(pix.ravel())
        path=HOME/'sheets'/f'jackpot_arcade_v1_reel_{j}.png';im.filepath_raw=str(path);im.file_format='PNG';im.save();im.pack()
        mat=flat(f'ReelPrinted_{j}',(240,220,175),rough=.72)
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im
        mat.node_tree.links.new(node.outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
        return mat

    for j,xc in enumerate((-.36,0,.36)):
        # Cylinder axis X; local UVs wind around its circumference.
        count=48;radius=.28;width=.325;verts=[]
        for xend in (-width/2,width/2):
            for i in range(count):
                a=i*math.tau/count;verts.append((xend,radius*math.cos(a),radius*math.sin(a)))
        faces=[(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
        faces.extend([tuple(reversed(range(count))),tuple(range(count,count*2))])
        reel=mesh('SymbolReel_'+str(j),verts,faces,reel_material(j));reel.location=(xc,.29,1.205)
        reel.data.materials.append(cream)
        uv=reel.data.uv_layers.new(name='ReelUV')
        for poly in reel.data.polygons:
            if poly.index<count:
                i=poly.index
                for li,value in zip(poly.loop_indices,[(0,i/count),(0,(i+1)/count),(1,(i+1)/count),(1,i/count)]):uv.data[li].uv=value
                poly.use_smooth=True
            else:
                poly.material_index=1
        for frame,angle in [(1,math.pi/4),(145,math.pi/4+math.tau*(j+1))]:
            reel.rotation_euler.x=angle;reel.keyframe_insert(data_path='rotation_euler',frame=frame)
        reel['motion']='reel spin';reel['periodSeconds']=6/(j+1);linear_keys(reel)
    for side in (-1,1):
        for j in range(5):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=.038,location=(side*.63,-.042,.98+j*.115))
            ob=bpy.context.object;ob.name=f'Bulb_{side}_{j}';move(ob,fxcol);assign(ob,amber);extras.append(ob)
    tokenmat=flat('Token gold',[238,178,59],metal=.65,rough=.27)
    emblem=flat('Token emboss',[255,216,112],metal=.55,rough=.31)
    for j in range(6):
        side=-1 if j%2 else 1
        origin=Vector((side*(1.17+.09*(j%2)),.30+.18*(j//2),-.10+.23*(j//2)))
        bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.112,depth=.033,location=origin,rotation=(math.pi/2,0,.14*side))
        ob=bpy.context.object;ob.name='GoldToken_'+str(j);move(ob,fxcol);assign(ob,tokenmat);extras.append(ob)
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
        # Raised five-point motif joined to the coin; disconnected closed shells are valid.
        points=[]
        for depth in (-.026,-.019):
            for k in range(10):
                a=math.pi/2+k*math.pi/5;r=.063 if k%2==0 else .029
                points.append((r*math.cos(a),depth,r*math.sin(a)))
        faces=[tuple(reversed(range(10))),tuple(range(10,20))]+[(k,(k+1)%10,(k+1)%10+10,k+10) for k in range(10)]
        badge=mesh('TokenBadge_'+str(j),points,faces,emblem);badge.location=origin
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);badge.select_set(True);bpy.context.view_layer.objects.active=ob
        bpy.ops.object.join();extras.remove(badge)
        for frame in (1,19,37,55,73,91,109,127,145):
            a=(frame-1)/144*math.tau+j*math.tau/6
            ob.location=origin+Vector((side*.09*math.sin(a),.09*math.cos(a),.11*math.sin(a)))
            ob.rotation_euler.z=.24*math.sin(a)
            ob.keyframe_insert(data_path='location',frame=frame);ob.keyframe_insert(data_path='rotation_euler',frame=frame)
        ob['motion']='rear token orbit';ob['periodSeconds']=6

"""Six expansion piggies: simple epic motifs and visibly articulated legendary armor."""
def pivot_sway(ob,axis,amount,phase=0):
    start=ob.rotation_euler.copy()
    for f in (1,19,37,55,73,91,109,127,145):
        ob.rotation_euler=start.copy();ob.rotation_euler[axis]+=amount*math.sin((f-1)/144*math.tau+phase)
        ob.keyframe_insert(data_path='rotation_euler',frame=f)
    ob['motion']='hinged guard sway';ob['periodSeconds']=6

def shell_plate(name,side,cy,cz,half_y,half_z,material,thickness=.11):
    # Side armor is a closed convex polygon, buried at its central root.
    profile=[(-.82,-1),(.48,-1),(1,-.35),(.84,.76),(-.18,1),(-1,.35)]
    direction=Vector((side,cy,cz)).normalized()
    hit,point,normal,_=parts['Body'].ray_cast(direction*4,-direction);assert hit
    center=Vector((side*(abs(point.x)-.025),cy,cz))
    verts=[]
    for depth in (-.035,thickness):
        for u,v in profile:verts.append((side*depth,u*half_y,v*half_z))
    count=len(profile);faces=[tuple(reversed(range(count))),tuple(range(count,count*2))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    ob=mesh(name,verts,faces,material);ob.location=center;return ob

if KEY=='powerup':
    # The large arrows are paint; six restrained energy squares are the only extra geometry.
    for j in range(6):
        side=-1 if j%2 else 1
        ob=box_mesh('PowerSpark_'+str(j),(side*(1.02+.05*(j%3)),.48+.10*(j//2),.1+.22*(j//2)),(.055,.055,.055),flat('Spark'+str(j),P[1],1.2))
        loop_bob(ob,.12,j*.8)

if KEY=='finalboss':
    armor=flat('Boss armor',[88,43,105],metal=.22,rough=.4)
    gold=flat('Boss brass',[188,116,59],metal=.55,rough=.35)
    glow=flat('Boss energy',P[1],1.1)
    for side in (-1,1):
        for j,(cy,cz,hy,hz) in enumerate([(-.05,.25,.32,.32),(.43,.04,.33,.35)]):
            ob=shell_plate(f'BossGuard_{side}_{j}',side,cy,cz,hy,hz,gold)
            pivot_sway(ob,0,.045,j)
            # Insets and trim parent to the guard, so every layer moves together.
            inset=shell_plate(f'BossInset_{side}_{j}',side,cy,cz,hy*.84,hz*.84,armor,.10)
            inset.parent=ob;inset.location=(side*.045,0,0)
            jewel=crystal(f'OrbitPrism_Boss_{side}_{j}',(side*.15,0,.03),(side*.085,0,0),.12,glow,4)
            jewel.parent=ob;jewel.location=(0,0,0)
            bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.075,depth=.065,rotation=(0,math.pi/2,0))
            hinge=bpy.context.object;hinge.name=f'BossHinge_{side}_{j}';move(hinge,fxcol);assign(hinge,gold);extras.append(hinge)
            hinge.parent=ob;hinge.location=(side*.16,hy*.7,hz*.50)
        for j in range(3):
            cube=box_mesh(f'BossEnergy_{side}_{j}',(side*(1.22+.02*j),.48+.19*j,.10+.20*j),(.11,.11,.11),glow,.008)
            loop_bob(cube,.09,j+side)

if KEY=='mechaplayer':
    steel=flat('Mecha steel',[169,188,201],metal=.55,rough=.35)
    navy=flat('Mecha blue',[34,55,82],metal=.3,rough=.43)
    cyan=flat('Mecha vents',P[1],1.3)
    orange=flat('Warning orange',P[3],rough=.6)
    for side in (-1,1):
        for j,yy in enumerate((-.48,.54)):
            # Closed annular cuff sits around the original short leg.
            center=Vector((side*.5,yy,-.82));verts=[];n=12
            for zz,rr in [(-.19,.255),(.13,.255),(.13,.202),(-.19,.202)]:
                for i in range(n):
                    a=i*math.tau/n;verts.append((rr*math.cos(a),rr*math.sin(a),zz))
            faces=[]
            for ring in range(4):
                nxt=(ring+1)%4
                for i in range(n):faces.append((ring*n+i,ring*n+(i+1)%n,nxt*n+(i+1)%n,nxt*n+i))
            cuff=mesh(f'MechBoot_{side}_{j}',verts,faces,steel);cuff.location=center
            band=box_mesh(f'BootSignal_{side}_{j}',(side*.762,yy,-.79),(.027,.18,.045),cyan,.006)
        guard=shell_plate('MechGuard_'+str(side),side,.12,.06,.30,.27,navy,.13);pivot_sway(guard,1,.04,side)
        joint=box_mesh('MechGuardInset_'+str(side),(0,0,0),(.027,.20,.09),steel,.02);joint.parent=guard;joint.location=(side*.14,0,0)
        stripe=box_mesh('MechWarning_'+str(side),(0,0,0),(.03,.18,.026),orange,.005);stripe.parent=guard;stripe.location=(side*.16,0,.10)
        # Cylinder axis points rearward, firmly seated in a bracket at the rump.
        mount=box_mesh('ThrusterBracket_'+str(side),(side*.50,.78,.28),(.32,.33,.38),navy,.045)
        bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.20,depth=.40,location=(side*.50,1.0,.30),rotation=(math.pi/2,0,0))
        housing=bpy.context.object;housing.name='ThrusterHousing_'+str(side);move(housing,fxcol);assign(housing,steel);extras.append(housing)
        for j in range(3):
            vent=box_mesh(f'ThrusterVent_{side}_{j}',(side*.50,1.213,.20+j*.10),(.24,.025,.032),cyan,.005)
            loop_bob(vent,.012,j*.6)
        bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.13,radius2=.025,depth=.28,location=(side*.50,1.37,.30),rotation=(-math.pi/2,0,0))
        flame=bpy.context.object;flame.name='ThrusterPlume_'+str(side);move(flame,fxcol);assign(flame,cyan);extras.append(flame)
        for f in (1,37,73,109,145):
            flame.scale.z=.75+.25*math.cos((f-1)/144*math.tau)
            flame.keyframe_insert(data_path='scale',frame=f)
        flame['motion']='thruster pulse'


# Separate small visual proxies for proposed runtime emitters.
if TIER!='rare':
    for j in range(10):
        side=-1 if j%2 else 1;pos=(side*(.91+.04*(j%4)),.6+.04*(j%3),.10+.13*j)
        bpy.ops.mesh.primitive_cube_add(size=.022 if KEY=='respawn' else .014,location=pos)
        ob=bpy.context.object;ob.name='AuraPixel_'+str(j);move(ob,auracol)
        assign(ob,flat(ob.name,P[1] if KEY in ('respawn','powerup','synthwave','finalboss','mechaplayer') else P[-1],1.7));aura.append(ob);loop_bob(ob,.10,j*.6)


assert signatures=={n:signature(o) for n,o in parts.items()}
scene['skinKey']=KEY;scene['revision']='arcade-build-v1';scene['tier']=TIER;scene['aura']=SPEC['aura'] or ''
scene['design']=SPEC['design'];scene['runtimeStatus']='Local authoring complete; Roblox upload/integration pending'
scene.frame_set(1)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HOME/'source'/f'{KEY}-arcade-v1-procedural.blend'))

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
        path=HOME/'sheets'/f'{KEY}_arcade_v1_{group}_{channel}.png';image.filepath_raw=str(path);image.file_format='PNG';image.save();image.pack()
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
    elif KEY=='playerone':
        p.inputs['Roughness'].default_value=1
        p.inputs['Specular IOR Level'].default_value=0
        tex.interpolation='Closest'
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
    path=HOME/'package'/f'{KEY}-arcade-v1-{label}.fbx'
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
world.node_tree.nodes['Background'].inputs[1].default_value=.4
def light(name,pos,power,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);stage.objects.link(ob);ob.location=pos;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
light('Key',(-3,-4,6),310,5);light('Fill',(4,-1,3),145,4);light('Rim',(1,4,5),260,3)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-1.025));ground=bpy.context.object;ground.name='ReviewGround';move(ground,stage);assign(ground,flat('Ground',(53,47,66),rough=.95))
data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',data);stage.objects.link(camera);scene.camera=camera;data.type='ORTHO';data.ortho_scale=4.0 if TIER=='legendary' else 3.45
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.image_settings.file_format='PNG'
shots=[('hero',(-4,-6,2.8),(0,0,.08)),('back',(-4,6,2.8),(0,0,.08))]
for name,pos,target in shots:
    camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(HOME/'preview'/f'{KEY}-arcade-v1-{name}.png');bpy.ops.render.render(write_still=True)
camera.location=shots[0][1];camera.rotation_euler=(Vector(shots[0][2])-camera.location).to_track_quat('-Z','Y').to_euler()
if TIER!='rare':
    # A real second animation state catches static/disconnected FX accidentally shipped as motion.
    scene.frame_set(37);scene.render.filepath=str(HOME/'preview'/f'{KEY}-arcade-v1-motion.png');bpy.ops.render.render(write_still=True);scene.frame_set(1)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False;area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=parts['Body']
bpy.ops.wm.save_as_mainfile(filepath=str(HOME/'package'/f'{KEY}-arcade-v1.blend'))
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
report={'skin':KEY,'name':SPEC['name'],'tier':TIER,'revision':'arcade-build-v1','status':'Built locally; Roblox upload and installation pending','design':SPEC['design'],
    'baseGeometryAndUVPreserved':True,'sourceGeometrySignatures':signatures,'parts':checks,'exports':exported,'aura':SPEC['aura'],
    'auraPreviewObjects':len(aura),'auraExcludedFromMeshExports':True,'animation':{'frames':[1,145],'fps':24,'loopSeconds':6,'animatedGeometry':sum(bool(o.animation_data) for o in extras),'materialPulse':TIER!='rare',**motion_checks},
    'tierChecks':{'authoredCoat':True,'glowAndAura':TIER!='rare','substantialAnimatedGeometry':TIER=='legendary' and len(extras)>=6},
    'textures':[{'role':g+'_'+ch,'file':str(path.relative_to(HOME)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[1024,1024]} for (g,ch),(im,path) in maps.items()],
    'generator':'assets/piggies/arcade-build-v1/build_arcade.py','runtimeNotes':'Use supplied maps on shared body/trim; replace old procedural pattern. Player One is Rare for its authored pixel coat; these are new assets, not installed Config rows. Aura keys are proposed new emitters; preview motes are not export meshes. New accessories replace, not stack with, old shard/FX geometry. Full Blender animation is retained in packed blend; FBX is a static import pose.'}
if KEY=='jackpot':
    for index in range(3):
        path=HOME/'sheets'/f'jackpot_arcade_v1_reel_{index}.png'
        report['textures'].append({'role':f'reel_{index}','file':str(path.relative_to(HOME)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[256,1024]})
(HOME/'package/arcade-v1-asset-report.json').write_text(json.dumps(report,indent=2)+'\n')
(HOME/'generate/arcade-v1-spec.json').write_text(json.dumps(SPEC,indent=2)+'\n')
print('ARCADE_COMPLETE',KEY,json.dumps({'extraTriangles':sum(p['triangles'] for p in checks if p['role']=='accessory'),'maps':len(maps),'basePreserved':True}),flush=True)
