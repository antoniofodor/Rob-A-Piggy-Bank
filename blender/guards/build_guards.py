"""Approved chunky guard roster, rigid skinned meshes and editable starter actions.

Blender -b --factory-startup -t 4 --python blender/guards/build_guards.py
GUARD_ONLY=terrier,gorilla,raptor limits the batch; GUARD_RENDER=0 skips previews.
GUARD_PYTHON_DEPS can point to a compatible isolated NumPy installation.
"""
import os
import sys
from pathlib import Path

deps = Path(os.environ.get('GUARD_PYTHON_DEPS', '/tmp/guard-blender-python'))
if deps.exists():
    sys.path.insert(0, str(deps))
import bpy
import bmesh
import json
import math
from mathutils import Vector, Quaternion, Matrix

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/guards'
PALE = (239, 219, 180)
CONFIG = {
    'terrier': dict(label='Scruffy', tier=1, family='canine', height=2.5,
        fur=(227,173,91), dark=(172,112,53), light=(247,207,142), collar=(210,54,42),
        hw=.61, hh=.59, hd=.48, hy=-.83, hz=1.65, body=(.51,.84,.43), bz=.94, leg=.70, ear=.65),
    'shepherd': dict(label='Rex', tier=2, family='canine', height=3.25,
        fur=(214,155,77), dark=(91,67,51), light=(231,179,106), collar=(41,137,216),
        hw=.59, hh=.63, hd=.48, hy=-.87, hz=1.88, body=(.49,.94,.48), bz=1.12, leg=.86, ear=.88),
    'mastiff': dict(label='Titan', tier=3, family='canine', height=4.05,
        fur=(78,73,82), dark=(49,46,54), light=(120,111,114), collar=(244,189,35),
        hw=.78, hh=.64, hd=.55, hy=-.83, hz=1.75, body=(.66,1.0,.52), bz=1.04, leg=.69, ear=.35),
    'direwolf': dict(label='Dire Wolf', tier=4, family='canine', height=4.3,
        fur=(119,134,154), dark=(73,91,119), light=(221,222,212), collar=None,
        hw=.64, hh=.59, hd=.50, hy=-1.0, hz=1.88, body=(.53,1.06,.49), bz=1.08, leg=.83, ear=.78),
    'gorilla': dict(label='Gorilla', tier=4, family='ape', height=4.3,
        fur=(91,83,79), dark=(62,58,57), light=(178,159,129), collar=None),
    'raptor': dict(label='Raptor', tier=4, family='dino', height=4.3,
        fur=(102,185,69), dark=(50,115,43), light=(226,214,149), collar=None),
    'triceratops': dict(label='Triceratops', tier=5, family='trike', height=4.7,
        fur=(55,177,184), dark=(35,122,139), light=(239,220,165), collar=None),
    'cerberus': dict(label='Cerberus', tier=5, family='cerberus', height=4.7,
        fur=(86,60,70), dark=(49,33,45), light=(151,113,119), collar=(235,169,46),
        hw=.55, hh=.54, hd=.43, hy=-1.06, hz=1.88, body=(.95,1.04,.57), bz=1.10, leg=.78, ear=.57),
}


def linear(v):
    v /= 255
    return v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4


def material(name, rgb):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*[linear(v) for v in rgb],1)
    m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=m.diffuse_color
    p.inputs['Roughness'].default_value=.85
    return m


def active(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True);bpy.context.view_layer.objects.active=o


class Guard:
    def __init__(self, key):
        self.key=key;self.cfg=CONFIG[key];self.objects=[];self.bones={};self.head_suffixes=['']
        self.mats={k:material(key+'_'+k,c) for k,c in {
            'fur':self.cfg['fur'],'dark':self.cfg['dark'],'light':self.cfg['light'],
            'collar':self.cfg['collar'] or (223,177,44),'eye':(18,18,20),
            'nose':(29,27,30),'mouth':(41,24,31),'teeth':(248,232,189),
            'inner':(201,126,112),'armor':(131,48,78),'accent':(238,122,64),
            'silver':(171,170,182),'brow':self.cfg['fur'],
            'mask':tuple(round(.6*a+.4*b) for a,b in zip(self.cfg['fur'],self.cfg['light']))}.items()}
        self.bone('Root',(0,0,0),None)
        self.bone('Body',(0,0,1),'Root')

    def bone(self,name,pivot,parent='Body'):
        self.bones[name]={'head':tuple(pivot),'parent':parent}

    def finish(self,o,name,tone,bone):
        o.name=name;o.data.materials.clear();o.data.materials.append(self.mats[tone])
        o['tone']=tone;o['bone']=bone
        active(o);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        for p in o.data.polygons:p.use_smooth=False
        self.objects.append(o)
        return o

    def box(self,name,center,half,tone='fur',bone='Body',bevel=.15,rot=None):
        bpy.ops.mesh.primitive_cube_add(size=2,location=center)
        o=bpy.context.object;o.scale=half
        if rot:o.rotation_euler=rot
        active(o);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        if bevel:
            mod=o.modifiers.new('One clean chamfer','BEVEL');mod.width=min(half)*bevel
            mod.segments=1;mod.affect='EDGES'
            bpy.ops.object.modifier_apply(modifier=mod.name)
        return self.finish(o,name,tone,bone)

    def mesh(self,name,verts,faces,tone='fur',bone='Body'):
        data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
        bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
        o=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(o)
        return self.finish(o,name,tone,bone)

    def oval(self,name,center,rx,rz,tone,bone):
        # A tiny eight-sided extruded disc, not a glossy eyeball.
        x,y,z=center;n=10
        verts=[(x+rx*math.cos(i*math.tau/n),y+d,z+rz*math.sin(i*math.tau/n)) for d in (-.014,.014) for i in range(n)]
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        return self.mesh(name,verts,faces,tone,bone)

    def taper(self,name,points,radii,tone='fur',bone='Body',sides=5):
        verts=[];faces=[];prev=None
        for j,p in enumerate(points):
            here=Vector(p);direction=(Vector(points[min(len(points)-1,j+1)])-Vector(points[max(0,j-1)])).normalized()
            if prev is None:
                u=direction.cross(Vector((1,0,0)) if abs(direction.x)<.9 else Vector((0,1,0))).normalized()
            else:u=(prev-direction*prev.dot(direction)).normalized()
            prev=u;v=direction.cross(u).normalized()
            for i in range(sides):
                a=i*math.tau/sides;verts.append(tuple(here+radii[j]*(math.cos(a)*u+math.sin(a)*v)))
        for j in range(len(points)-1):
            for i in range(sides):
                a=j*sides+i;b=j*sides+(i+1)%sides;faces.append((a,b,b+sides,a+sides))
        faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+i for i in range(sides))])
        return self.mesh(name,verts,faces,tone,bone)

    def ear(self,side,root,w,h,fold=False):
        x,y,z=root;name='Ear_L' if side<0 else 'Ear_R';self.bone(name,root,'Head')
        tip=(x+side*w*.16,y+.025,z+h)
        if fold:tip=(x+side*w*.95,y-.15,z+h*.48)
        a=(x-w/2,y,z);b=(x+w/2,y,z)
        verts=[a,b,tip,(a[0],y+.16,z),(b[0],y+.16,z),(tip[0],tip[1]+.12,tip[2])]
        self.mesh(name,verts,[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],'fur',name)
        if not fold:
            mid=Vector((x,y,z));ts=Vector(tip)
            iv=[(x-w*.27,y-.016,z+h*.13),(x+w*.27,y-.016,z+h*.13),tuple(mid+(ts-mid)*.78-Vector((0,.02,0)))]
            self.mesh(name+'_Inner',iv+[(a,b+.02,c) for a,b,c in iv],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],'inner',name)

    def face(self,hy,hz,hw,hd,mw,depth=.35,teeth=True,nose=True):
        front=hy-hd
        for side in (-1,1):
            suffix='L' if side<0 else 'R';x=side*hw*.48
            self.oval('Eye_'+suffix,(x,front-.023,hz+.10),hw*.105,hw*.17,'eye','Head')
            self.bone('Brow_'+suffix,(x,front-.04,hz+.31),'Head')
            self.box('Brow_'+suffix,(x,front-.05,hz+.32),(hw*.21,.027,.045),'brow','Brow_'+suffix,.10)
        cy=front-depth*.36;top=hz-.17
        # Closed muzzle halves conceal the simple fangs. They separate with Jaw.
        self.box('UpperMuzzle',(0,cy,top),(mw,depth,.16),'light','Head',.36)
        pivot=(0,front+.10,top-.14);self.bone('Jaw',pivot,'Head')
        self.box('LowerJaw',(0,cy+.015,top-.235),(mw*.96,depth*.96,.105),'light','Jaw',.26)
        self.box('MouthBack',(0,front-.018,top-.18),(mw*.83,.022,.14),'mouth','Head',0)
        self.box('LowerMouthInside',(0,cy,top-.125),(mw*.84,depth*.78,.018),'mouth','Jaw',0)
        if nose:self.box('Nose',(0,cy-depth-.017,top+.055),(mw*.36,.075,.092),'nose','Head',.40)
        # Small closed-mouth W mark follows the jaw.
        ys=cy-depth*.96-.008;zs=top-.225
        pts=[(-mw*.31,ys,zs+.025),(-mw*.13,ys,zs-.025),(0,ys,zs+.02),(mw*.15,ys,zs-.025),(mw*.3,ys,zs+.025)]
        for i in range(len(pts)-1):self.taper('Smile_'+str(i),pts[i:i+2],[.012,.012],'mouth','Jaw',4)
        if teeth:
            for side in (-1,1):
                x=side*mw*.66
                self.taper('Fang_'+str(side),[(x,cy-depth*.53,top-.13),(x,cy-depth*.53,top-.28)],[.078,.005],'teeth','Head',3)
                self.taper('LowerFang_'+str(side),[(x,cy-depth*.21,top-.15),(x,cy-depth*.21,top-.025)],[.06,.005],'teeth','Jaw',3)

    def leg(self,name,hip,knee,ankle,width,paw_depth,tone='fur'):
        self.bone(name,hip);self.bone(name+'_Lower',knee,name)
        for nm,a,b,w,bone in [(name,hip,knee,width,name),(name+'_Lower',knee,ankle,width*.83,name+'_Lower')]:
            mid=(Vector(a)+Vector(b))/2;length=(Vector(a)-Vector(b)).length
            q=(Vector(b)-Vector(a)).to_track_quat('Z','Y')
            self.box(nm,mid,(w,w,length*.5+w*.18),tone,bone,.22,q.to_euler())
        self.box(name+'_Foot',(ankle[0],ankle[1]-.07,width*.37),(width*1.11,paw_depth,width*.37),tone,name+'_Lower',.16)

    def surface_patch(self,name,source,predicate,tone):
        # A closed, almost flush color shell; keep the underlying body watertight.
        selected=[p for p in source.data.polygons if predicate(p.center)]
        indices=sorted({i for p in selected for i in p.vertices});mapping={v:i for i,v in enumerate(indices)}
        verts=[tuple(source.data.vertices[i].co) for i in indices]
        faces=[tuple(mapping[i] for i in p.vertices) for p in selected]
        obj=self.mesh(name,verts,faces,tone,'Body')
        # Preserve the source's outward normals for an open patch before thickening.
        for v in obj.data.vertices:v.co+=v.normal*.002
        active(obj);mod=obj.modifiers.new('Closed color shell','SOLIDIFY');mod.thickness=.008;mod.offset=-1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        return obj

    def canine(self):
        c=self.cfg;hy,hz,hw,hd=c['hy'],c['hz'],c['hw'],c['hd'];bx,by,bh=c['body']
        self.box('Body',(0,0,c['bz']),c['body'],'fur','Body',.45)
        self.bone('Head',(0,hy+.24,hz-.38))
        self.box('Neck',(0,hy+.18,hz-.47),(hw*.64,.38,.35),'fur','Body',.30)
        self.box('Head',(0,hy,hz),(hw,hd,c['hh']),'fur','Head',.42)
        for side in (-1,1):
            if self.key=='mastiff':
                root=(side*hw*.83,hy+.01,hz+.45);nm='Ear_L' if side<0 else 'Ear_R';self.bone(nm,root,'Head')
                self.box(nm,(side*(hw+.045),hy-.08,hz+.14),(.16,.26,.40),'fur',nm,.38,(0,side*.16,0))
            else:self.ear(side,(side*hw*.65,hy+.02,hz+c['hh']*.75),hw*.70,c['ear'],self.key=='terrier' and side>0)
        self.face(hy,hz,hw,hd,hw*.68,.27 if self.key in ('terrier','mastiff') else .36)
        if self.key in ('terrier','direwolf'):
            for side in (-1,1):
                x=side*hw*.85;z=hz-.16;y=hy-hd*.62
                self.mesh('Cheek_'+str(side),[(x,y-.12,z+.18),(x+side*.28,y,z-.04),(x,y-.10,z-.28),(x,y+.22,z)],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)],'light','Head')
        if c['collar']:
            self.box('Collar',(0,hy+.10,hz-.55),(hw*.82,.405,.12),'collar','Head',.35)
        for side in (-1,1):
            x=side*bx*.78
            self.leg('Front'+('L' if side<0 else 'R'),(x,-by*.64,c['leg']+.20),(x,-by*.65,c['leg']*.46),(x,-by*.69,.14),bx*.35,.24)
            self.leg('Back'+('L' if side<0 else 'R'),(x,by*.61,c['leg']+.24),(x,by*.82,c['leg']*.52),(x,by*.86,.14),bx*.38,.25)
        self.bone('Tail',(0,by*.80,c['bz']+.07))
        self.taper('Tail',[(0,by*.78,c['bz']+.10),(0,by+ .36,c['bz']+.37),(0,by+.64,c['bz']+.94)],[.20,.20,.027],'dark' if self.key=='shepherd' else 'fur','Tail',5)
        if self.key=='shepherd':
            body=next(o for o in self.objects if o.name=='Body')
            self.surface_patch('Saddle',body,lambda p:p.y>-.28 and p.z>c['bz']+.10,'dark')

    def cerberus(self):
        self.canine()
        c=self.cfg;center=Vector((0,c['hy'],c['hz']))
        names={'Head'}
        for name,info in self.bones.items():
            if info['parent'] in names:names.add(name)
        original_bones=[(n,dict(info)) for n,info in self.bones.items() if n in names]
        original_parts=[o for o in self.objects if o['bone'] in names]
        for side,suffix in [(-1,'_Left'),(1,'_Right')]:
            self.head_suffixes.append(suffix)
            destination=center+Vector((side*1.10,.08,-.22))
            transform=Matrix.Translation(destination)@Matrix.Rotation(math.radians(side*13),4,'Z')@Matrix.Scale(.91,4)@Matrix.Translation(-center)
            for name,info in original_bones:
                parent=info['parent']+suffix if info['parent'] in names else info['parent']
                self.bone(name+suffix,transform@Vector(info['head']),parent)
            for source in original_parts:
                obj=source.copy();obj.data=source.data.copy();obj.name=source.name+suffix
                obj.data.transform(transform);obj.data.update();obj['bone']=source['bone']+suffix
                bpy.context.scene.collection.objects.link(obj);self.objects.append(obj)
            self.box('Neck'+suffix,(side*.82,c['hy']+.29,c['hz']-.58),(.40,.40,.36),'fur','Body',.34)

    def ape_face(self):
        # A broad facial mask and flat nostril-bearing nose, not a canine snout.
        outline=[(-.45,2.37),(.45,2.37),(.53,2.18),(.46,1.82),(.33,1.57),(-.33,1.57),(-.46,1.82),(-.53,2.18)]
        verts=[(x,y,z) for y in (-.862,-.803) for x,z in outline]
        self.mesh('FaceMask',verts,[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)],'mask','Head')
        for side in (-1,1):
            suffix='L' if side<0 else 'R';x=side*.265
            self.oval('Eye_'+suffix,(x,-.886,2.16),.067,.087,'eye','Head')
            self.bone('Brow_'+suffix,(x,-.905,2.31),'Head')
            self.box('Brow_'+suffix,(x,-.912,2.31),(.21,.065,.062),'brow','Brow_'+suffix,.35)
        self.box('Nose',(0,-.955,1.99),(.267,.108,.108),'dark','Head',.50)
        for side in (-1,1):
            self.oval('Nostril_'+str(side),(side*.12,-1.069,1.98),.060,.036,'nose','Head')
        self.box('UpperMuzzle',(0,-.943,1.78),(.37,.155,.096),'mask','Head',.50)
        self.bone('Jaw',(0,-.735,1.70),'Head')
        self.box('LowerJaw',(0,-.923,1.625),(.35,.152,.076),'mask','Jaw',.44)
        self.box('MouthBack',(0,-.852,1.68),(.31,.018,.13),'mouth','Head',0)
        self.box('LowerMouthInside',(0,-.94,1.705),(.31,.13,.015),'mouth','Jaw',0)
        self.taper('MouthLine',[(-.22,-1.079,1.655),(0,-1.079,1.640),(.22,-1.079,1.655)],[.012,.012,.012],'mouth','Jaw',4)
        for side in (-1,1):
            x=side*.24
            self.taper('Fang_'+str(side),[(x,-1.015,1.70),(x,-1.015,1.56)],[.063,.004],'teeth','Head',3)
            self.taper('LowerFang_'+str(side),[(x,-.96,1.69),(x,-.96,1.78)],[.044,.004],'teeth','Jaw',3)

    def ape(self):
        w=.76
        self.box('Body',(0,.10,1.02),(w,.57,.83),'fur','Body',.54)
        self.box('Chest',(0,-.487,1.0),(w*.60,.035,.47),'light','Body',.34)
        self.bone('Head',(0,-.24,1.57))
        self.box('Head',(0,-.34,2.0),(.66,.49,.61),'fur','Head',.43)
        self.ape_face()
        for side in (-1,1):
            self.oval('Ear_'+str(side),(side*.67,-.34,2.03),.11,.16,'fur','Head')
            nm='Front'+('L' if side<0 else 'R')
            self.leg(nm,(side*w*.82,-.10,1.70),(side*(w+.20),-.24,.85),(side*(w+.36),-.61,.17),.27,.33)
            nm='Back'+('L' if side<0 else 'R')
            self.leg(nm,(side*.45,.38,.80),(side*.50,.44,.46),(side*.51,.37,.13),.22,.29)

    def dino(self):
        self.box('Body',(0,.08,1.18),(.51,.75,.60),'fur','Body',.50,(-.15,0,0))
        self.box('Belly',(0,-.69,1.21),(.36,.08,.40),'light','Body',.42,(-.15,0,0))
        self.bone('Head',(0,-.50,1.75))
        self.box('Neck',(0,-.49,1.83),(.34,.35,.49),'fur','Body',.35,(-.26,0,0))
        self.box('Head',(0,-.83,2.26),(.58,.68,.43),'fur','Head',.30)
        self.face(-.83,2.23,.58,.68,.49,.23,True,False)
        muzzle=next(o for o in self.objects if o.name=='UpperMuzzle')
        muzzle.data.materials[0]=self.mats['fur'];muzzle['tone']='fur'
        for side in (-1,1):
            self.oval('Nostril_'+str(side),(side*.26,-1.836,2.12),.035,.045,'dark','Head')
            nm='Back'+('L' if side<0 else 'R')
            self.leg(nm,(side*.42,.25,1.12),(side*.53,-.02,.58),(side*.52,.20,.16),.22,.39)
            for k in (-1,0,1):
                x=side*.52+k*.13
                self.taper(nm+'_Toe'+str(k),[(x,-.18,.10),(x,-.37,.05)],[.075,.005],'dark',nm+'_Lower',3)
            nm='Front'+('L' if side<0 else 'R');p=(side*.40,-.48,1.43);self.bone(nm,p)
            self.taper(nm,[p,(side*.55,-.78,1.21),(side*.52,-.99,1.31)],[.13,.10,.08],'fur',nm,4)
            for k in (-1,1):self.taper(nm+'_Claw'+str(k),[(side*.52+k*.055,-.98,1.30),(side*.52+k*.055,-1.08,1.20)],[.04,.004],'dark',nm,3)
        self.bone('Tail',(0,.61,1.32))
        self.taper('Tail',[(0,.61,1.32),(0,1.35,1.49),(0,2.10,1.70)],[.30,.22,.015],'fur','Tail',5)

    def trike(self):
        self.box('Body',(0,.20,.99),(.76,1.03,.58),'fur','Body',.48)
        self.bone('Head',(0,-.71,1.21))
        self.box('Head',(0,-1.06,1.40),(.65,.63,.53),'fur','Head',.42)
        # Thick octagonal fan, with a simple inner panel.
        for nm,rad,y,tone in [('Frill',1.02,-.70,'fur'),('FrillInset',.78,-.799,'dark')]:
            n=8;verts=[]
            for dy in (-.08,.08):
                for i in range(n):
                    a=i*math.tau/n;verts.append((rad*math.cos(a),y+dy,1.72+rad*math.sin(a)))
            faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
            self.mesh(nm,verts,faces,tone,'Head')
        # Put front facial block ahead of the frill.
        self.face(-1.06,1.40,.65,.63,.43,.26,False,False)
        for side in (-1,1):
            self.taper('BrowHorn_'+str(side),[(side*.42,-1.34,1.85),(side*.51,-1.62,2.20),(side*.56,-1.99,2.56)],[.17,.11,.008],'teeth','Head',5)
        self.taper('NoseHorn',[(0,-1.80,1.67),(0,-2.05,1.93)],[.14,.006],'teeth','Head',5)
        for side in (-1,1):
            for front in (True,False):
                nm=('Front' if front else 'Back')+('L' if side<0 else 'R');y=-.47 if front else .89
                self.leg(nm,(side*.57,y,.91),(side*.60,y,.47),(side*.61,y-.02,.13),.23,.28)
        self.bone('Tail',(0,1.10,1.06))
        self.taper('Tail',[(0,1.08,1.06),(0,1.64,1.13),(0,2.01,1.41)],[.23,.16,.01],'fur','Tail',5)

    def create(self):
        {'canine':self.canine,'ape':self.ape,'dino':self.dino,'trike':self.trike,'cerberus':self.cerberus}[self.cfg['family']]()
        bpy.context.view_layer.update()
        minz=min(v.co.z for o in self.objects for v in o.data.vertices)
        maxz=max(v.co.z for o in self.objects for v in o.data.vertices)
        self.scale=self.cfg['height']/(maxz-minz)
        for o in self.objects:
            for v in o.data.vertices:v.co=(v.co-Vector((0,0,minz)))*self.scale
        for name,info in self.bones.items():
            info['head']=tuple((Vector(info['head'])-Vector((0,0,minz)))*self.scale) if name!='Root' else (0,0,0)
        data=bpy.data.armatures.new(self.key+'_Skeleton');rig=bpy.data.objects.new(self.key+'_Rig',data)
        bpy.context.scene.collection.objects.link(rig);active(rig)
        bpy.ops.object.mode_set(mode='EDIT')
        for name,info in self.bones.items():
            b=data.edit_bones.new(name);b.head=info['head'];b.tail=b.head+Vector((0,0,.22*self.scale))
            if info['parent']:b.parent=data.edit_bones[info['parent']]
            b.use_deform=name!='Root'
        bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True;rig.data.display_type='STICK'
        for o in self.objects:
            vg=o.vertex_groups.new(name=o['bone']);vg.add(list(range(len(o.data.vertices))),1.0,'REPLACE')
            mod=o.modifiers.new('Rigid low-poly skin','ARMATURE');mod.object=rig
            o.parent=rig
        self.rig=rig
        rig['description']='Rigid weights; one bone per vertex. Root unweighted. Jaw opens around world X.'
        rig['tier']=self.cfg['tier'];rig['creature']=self.key
        self.actions={}
        self.make_actions()
        self.set_action('Idle');bpy.context.scene.frame_set(1)
        return self

    def reset_pose(self):
        for p in self.rig.pose.bones:
            p.rotation_mode='QUATERNION';p.rotation_quaternion=(1,0,0,0);p.location=(0,0,0);p.scale=(1,1,1)

    def rot(self,bone,axis,angle):
        if bone not in self.rig.pose.bones:return
        pb=self.rig.pose.bones[bone];q=pb.bone.matrix_local.to_quaternion()
        pb.rotation_quaternion=q.inverted()@Quaternion(Vector(axis),angle)@q

    def move(self,bone,world):
        pb=self.rig.pose.bones[bone];pb.location=pb.bone.matrix_local.to_3x3().inverted()@Vector(world)

    def pose(self,kind,t):
        self.reset_pose();s=math.sin(t*math.tau)
        if kind=='Idle':
            self.move('Body',(0,0,.018*self.scale*(1-math.cos(t*math.tau))))
            for i,suffix in enumerate(self.head_suffixes):
                amplitude=.045 if len(self.head_suffixes)>1 else .035
                self.rot('Head'+suffix,(0,0,1),amplitude*(math.sin(t*math.tau+i*.8)-math.sin(i*.8)))
            self.rot('Tail',(0,0,1),.15*s)
            return
        for i,suffix in enumerate(self.head_suffixes):
            self.rot('Head'+suffix,(1,0,0),.07)
            self.rot('Jaw'+suffix,(1,0,0),math.radians(22+6*math.sin(t*math.tau+i*.9)) if kind=='Chase' else math.radians((38-i*3)*math.sin(math.pi*t)**2))
            for side in (-1,1):
                ape=self.cfg['family']=='ape'
                nm=('Brow_L' if side<0 else 'Brow_R')+suffix;self.rot(nm,(0,1,0),-side*(.24 if ape else .32))
                self.move(nm,(0,-.018*self.scale,(-.035 if ape else -.09)*self.scale))
        if kind=='Chase':
            self.move('Body',(0,0,.09*self.scale*(1-math.cos(t*math.tau*2))))
            for nm,phase in [('FrontL',0),('BackR',0),('FrontR',math.pi),('BackL',math.pi)]:
                swing=math.sin(t*math.tau+phase)
                self.rot(nm,(1,0,0),.48*swing)
                self.rot(nm+'_Lower',(1,0,0),-.24*max(0,swing))
            self.rot('Tail',(0,0,1),.15*s)
        else:
            pulse=math.sin(math.pi*t)**2
            self.move('Body',(0,-.20*self.scale*pulse,.025*self.scale*pulse))
            for suffix in self.head_suffixes:self.rot('Head'+suffix,(1,0,0),-.12*pulse)

    def make_actions(self):
        rig=self.rig;rig.animation_data_create()
        for kind,end,step in [('Idle',61,5),('Chase',25,2),('Attack',25,2)]:
            a=bpy.data.actions.new(self.key+'_'+kind);a.use_fake_user=True;rig.animation_data.action=a
            for f in sorted(set(list(range(1,end+1,step))+[end])):
                self.pose(kind,(f-1)/(end-1))
                for p in rig.pose.bones:
                    p.keyframe_insert('rotation_quaternion',frame=f,group=p.name)
                    p.keyframe_insert('location',frame=f,group=p.name)
            a['clip']=kind;a['start']=1;a['end']=end;a['fps']=30;a['loop']=kind!='Attack'
            self.actions[kind]=a

    def set_action(self,kind):
        self.rig.animation_data.action=self.actions[kind]
        scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=int(self.actions[kind]['end'])

    def expression(self,hostile):
        colors={'eye':(245,23,32) if hostile else (18,18,20),'brow':self.cfg['dark'] if hostile else self.cfg['fur']}
        for name,rgb in colors.items():
            m=self.mats[name];m.diffuse_color=(*map(linear,rgb),1)
            p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=m.diffuse_color
            if name=='eye':
                p.inputs['Emission Color'].default_value=m.diffuse_color
                p.inputs['Emission Strength'].default_value=.12 if hostile else 0

    def export(self,folder):
        self.set_action('Idle');bpy.context.scene.frame_set(1);self.expression(False)
        bpy.context.view_layer.update();active(self.rig)
        for o in self.objects:o.select_set(True)
        common=dict(use_selection=True,object_types={'ARMATURE','MESH'},add_leaf_bones=False,
            apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',
            use_armature_deform_only=False,use_custom_props=True,mesh_smooth_type='FACE')
        bpy.ops.export_scene.fbx(filepath=str(folder/(self.key+'.fbx')),bake_anim=False,**common)
        # One clip per FBX, as required by the Roblox animation import workflow.
        for kind in self.actions:
            self.set_action(kind);bpy.context.scene.frame_set(1)
            bpy.ops.export_scene.fbx(filepath=str(folder/(self.key+'_'+kind+'.fbx')),
                bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,
                bake_anim_simplify_factor=0,bake_anim_force_startend_keying=True,**common)
        self.set_action('Idle');bpy.context.scene.frame_set(1)
        bpy.ops.export_scene.gltf(filepath=str(folder/(self.key+'.glb')),export_format='GLB',
            use_selection=True,export_animations=False,export_skins=True,export_extras=True)

    def report(self):
        parts={};allv=[]
        for o in self.objects:
            o.data.calc_loop_triangles();allv.extend(v.co.copy() for v in o.data.vertices)
            parts[o.name]={'triangles':len(o.data.loop_triangles),'tone':o['tone'],'bone':o['bone']}
            assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in o.data.vertices)
            assert o['bone']!='Root'
        bounds={'min':[min(v[i] for v in allv) for i in range(3)],'max':[max(v[i] for v in allv) for i in range(3)]}
        return {'creature':self.key,'label':self.cfg['label'],'tier':self.cfg['tier'],
            'triangles':sum(p['triangles'] for p in parts.values()),'parts':parts,'bones':self.bones,
            'height':bounds['max'][2]-bounds['min'][2],'boundsBlender':bounds,
            'clips':{k:{'start':1,'end':int(a['end']),'fps':30,'loop':k!='Attack'} for k,a in self.actions.items()},
            'animationStatus':'Editable starter motions, not final gameplay-tuned animations',
            'installedInGame':False,'units':'Blender Z up, -Y forward. Nominal authored units; verify FBX importer scale in Studio.',
            'palette':{k:list(v) if v is not None else None for k,v in self.cfg.items() if k in ('fur','dark','light','collar')}}


def studio():
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8
    scene.cycles.use_denoising=True;scene.render.resolution_x=720;scene.render.resolution_y=680
    scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=False
    scene.render.fps=30;scene.view_settings.view_transform='AgX'
    scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.76,.72,.65,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    for name,pos,power,size in [('Key',(-5,-8,11),1700,8),('Fill',(7,-4,7),1000,7),('Rim',(0,7,9),1400,6)]:
        bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.name='Studio_'+name
        o.data.energy=power;o.data.shape='DISK';o.data.size=size
        o.rotation_euler=(Vector((0,0,2))-o.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.035));floor=bpy.context.object
    floor.name='Studio_Floor';floor.data.materials.append(material('Studio_Ivory',(236,229,215)))
    bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='Studio_Camera';cam.data.type='ORTHO';scene.camera=cam
    return cam


def frame_camera(cam,guard):
    stats=guard.report();bounds=stats['boundsBlender'];h=guard.cfg['height']
    target=Vector((0,(bounds['min'][1]+bounds['max'][1])*.5,h*.49))
    cam.location=target+Vector((7,-12,6))*h/3
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    width=bounds['max'][0]-bounds['min'][0];length=bounds['max'][1]-bounds['min'][1]
    cam.data.ortho_scale=max(h*1.50,width*.88+length*.65)*1.07


def run():
    keys=os.environ.get('GUARD_ONLY',','.join(CONFIG)).split(',')
    for key in keys:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene=bpy.context.scene;scene.world=bpy.data.worlds.new('World');scene.render.fps=30
        g=Guard(key).create();folder=OUT/key;folder.mkdir(parents=True,exist_ok=True)
        report=g.report();(folder/(key+'-report.json')).write_text(json.dumps(report,indent=2)+'\n')
        g.export(folder)
        cam=studio();frame_camera(cam,g)
        if os.environ.get('GUARD_RENDER','1')!='0':
            for kind,frame in [('Idle',1),('Chase',4)]:
                if kind.lower() not in os.environ.get('GUARD_VIEWS','idle,chase').split(','):continue
                g.set_action(kind);scene.frame_set(frame);g.expression(kind=='Chase')
                scene.render.filepath=str(folder/(key+'-'+kind.lower()+'.png'))
                bpy.ops.render.render(write_still=True)
        g.set_action('Idle');scene.frame_set(1);g.expression(False)
        active(g.rig)
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type=='VIEW_3D':
                    area.spaces.active.shading.color_type='MATERIAL'
                    area.spaces.active.region_3d.view_distance=cam.data.ortho_scale*1.6
                    area.spaces.active.region_3d.view_location=(0,0,g.cfg['height']*.5)
        bpy.ops.wm.save_as_mainfile(filepath=str(folder/(key+'.blend')))
        print('GUARD_READY',key,report['triangles'],'triangles',len(g.bones),'bones',flush=True)


if __name__=='__main__':run()
