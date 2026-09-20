"""Smooth, reproducible shop icons and articulated tier crates. No image generation.
blender -b -t 6 --python-exit-code 1 --python blender/shop/build_icon_system.py
Optional -- --only coin,crate-common or --draft.
"""
from pathlib import Path
import bpy, bmesh, math, json, sys, hashlib
from mathutils import Vector,Matrix

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/shop-ui/icon-system-v1'
OUT.mkdir(parents=True,exist_ok=True)
MASTER=ROOT/'blender/pig/pig/pig_parts.blend'
MASTER_HASH=hashlib.sha256(MASTER.read_bytes()).hexdigest()
DRAFT='--draft' in sys.argv
SKIP_RENDER='--skip-render' in sys.argv # Topology/locator-only corrections after visual review.
ONLY=sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else None
RGB={'gold':(255,183,34),'goldlight':(255,224,112),'golddark':(176,88,15),
 'pink':(251,132,176),'snout':(238,95,150),'pinklight':(255,180,204),'ink':(40,30,48),
 'cream':(255,241,204),'white':(237,249,255),'silver':(172,214,237),
 'blue':(33,113,223),'deepblue':(24,53,113),'cyan':(67,229,244),
 'purple':(103,49,170),'darkpurple':(50,27,89),'violet':(180,111,255),
 'green':(61,186,104),'darkgreen':(25,108,78),'red':(241,76,99),
 'wood':(169,93,45),'woodlight':(213,140,68),'wooddark':(104,56,32),
 'tan':(231,164,83),'tanlight':(255,211,149),'brown':(117,69,44),'rubber':(192,32,45),'rubberdark':(139,26,36)}
M={};PARTS=[];GROUP='Body';KEY='';REPORT={}

def linear(rgb):return tuple(c/255/12.92 if c<=10.31475 else ((c/255+.055)/1.055)**2.4 for c in rgb)
def select(obs):
 bpy.ops.object.select_all(action='DESELECT')
 for ob in obs:ob.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
def reset(key):
 global M,PARTS,GROUP,KEY
 bpy.ops.wm.read_factory_settings(use_empty=True)
 KEY=key;PARTS=[];GROUP='Body';M={}
 for name,rgb in RGB.items():
  mat=bpy.data.materials.new(name);mat.diffuse_color=(*linear(rgb),1);mat.use_nodes=True
  p=mat.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=mat.diffuse_color
  p.inputs['Roughness'].default_value=.28 if name not in ('wood','woodlight','wooddark') else .43
  p.inputs['Metallic'].default_value=.22 if name in ('gold','goldlight','golddark','silver') else 0
  p.inputs['Coat Weight'].default_value=.25
  M[name]=mat
def finish(ob,name,tone,bevel=0):
 ob.name=name;ob['role']=GROUP
 ob.data.materials.clear();ob.data.materials.append(M[tone])
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=ob.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=3
  bpy.ops.object.modifier_apply(modifier=mod.name)
 for p in ob.data.polygons:p.use_smooth=True
 if bevel:
  mod=ob.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=40
  bpy.ops.object.modifier_apply(modifier=mod.name)
 PARTS.append(ob);return ob
def box(name,loc,size,tone,bevel=.09):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);ob=bpy.context.object;ob.dimensions=size
 return finish(ob,name,tone,min(bevel,min(size)*.42))
def ball(name,loc,size,tone):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=1,location=loc)
 ob=bpy.context.object;ob.scale=size;return finish(ob,name,tone)
def disc(name,loc,r,depth,tone,front=True,verts=48):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc)
 ob=finish(bpy.context.object,name,tone,min(.045,depth*.24))
 if front:ob.rotation_euler.x=math.pi/2
 return ob
def tube(name,points,r,tone):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=12;cu.bevel_depth=r;cu.bevel_resolution=3;cu.use_fill_caps=True
 sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
 for b,pt in zip(sp.bezier_points,points):b.co=pt;b.handle_left_type='AUTO';b.handle_right_type='AUTO'
 ob=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(ob);select([ob]);bpy.ops.object.convert(target='MESH')
 mesh=bpy.context.object.data;bm=bmesh.new();bm.from_mesh(mesh)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 return finish(bpy.context.object,name,tone)
def polygon(name,points,depth,y,tone,bevel=.03):
 verts=[(x,yy,z) for yy in (y-depth/2,y+depth/2) for x,z in points];n=len(points)
 faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);select([ob])
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 return finish(ob,name,tone,bevel)
def star(name,center,r,tone='goldlight',points=5):
 x,y,z=center
 return polygon(name,[(x+math.sin(i*math.pi/points)*r*(1 if i%2==0 else .47),z+math.cos(i*math.pi/points)*r*(1 if i%2==0 else .47)) for i in range(points*2)],.09,y,tone,.025)
def snout_seal(center,r,tone='goldlight',dark='golddark'):
 x,y,z=center
 nose=ball('PigSnout_Emboss',(x,y,z),(r,.15*r,r*.69),tone)
 # Real shallow cavities keep the same emblem usable on 3D crates and coin renders.
 for s in (-1,1):
  bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=1,location=(x+s*r*.37,y-.14*r,z))
  cutter=bpy.context.object;cutter.scale=(r*.15,r*.14,r*.28)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  select([nose]);mod=nose.modifiers.new('Recessed nostril','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
  bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
  ball('PigSnout_Nostril',(x+s*r*.37,y-.015*r,z),(r*.125,r*.018,r*.23),dark)
 nose.data.materials.clear();nose.data.materials.append(M[tone])
 for p in nose.data.polygons:p.material_index=0
 return nose
def coin(loc=(0,0,1),r=1):
 x,y,z=loc
 disc('Coin_RolledRim',(x,y,z),r,.22*r,'gold')
 disc('Coin_RecessedFace',(x,y-.118*r,z),r*.83,.035*r,'golddark')
 disc('Coin_SatinFace',(x,y-.144*r,z),r*.74,.025*r,'gold')
 return snout_seal((x,y-.20*r,z),r*.53)
def stack(x,y,count,r=.45):
 for i in range(count):disc('StackCoin',(x,y,.12+i*.16),r,.15,'gold',False)
def pig(loc=(0,0,0),scale=1):
 names=['Body','Snout','Ears','Legs','Tail'];parts=[]
 with bpy.data.libraries.load(str(MASTER),link=False) as (data,loaded):loaded.objects=[n for n in names if n in data.objects]
 for ob in loaded.objects:
  bpy.context.collection.objects.link(ob);ob.hide_render=False;ob.hide_set(False);ob.hide_viewport=False
  for mod in list(ob.modifiers):ob.modifiers.remove(mod)
  ear_inner={p.index for p in ob.data.polygons if p.material_index==1} if ob.name.startswith('Ears') else set()
  tone='ink' if ob.name.startswith('Eye') else ('snout' if ob.name.startswith('Snout') else 'pink')
  ob.data.materials.clear();ob.data.materials.append(M[tone]);ob.data.materials.append(M['snout'])
  for p in ob.data.polygons:p.material_index=1 if p.index in ear_inner else 0;p.use_smooth=True
  ob.matrix_world=Matrix.Translation(Vector(loc))@Matrix.Scale(scale,4)@ob.matrix_world
  ob.name='Pig_'+ob.name;ob['role']=GROUP;PARTS.append(ob);parts.append(ob)
 x,y,z=loc
 for side in (-1,1):
  parts.append(ball('Pig_Eye',(x+side*.318*scale,y-.889*scale,z+.364*scale),(.108*scale,.108*scale,.108*scale),'ink'))
  parts.append(ball('Pig_EyeGlint',(x+(side*.318-.025)*scale,y-.982*scale,z+.400*scale),(.025*scale,.018*scale,.026*scale),'white'))
 return parts
def arrow(x,y,z,s=1,tone='green'):
 pts=[(-.65,-.12),(.12,-.12),(.12,-.38),(.67,0),(.12,.38),(.12,.12),(-.65,.12)]
 return polygon('IncreaseArrow',[(x+a*s,z+b*s) for a,b in pts],.16*s,y,tone)
def clock(x,y,z,r=.72):
 disc('ClockCase',(x,y,z),r,.24,'gold');disc('ClockFace',(x,y-.14,z),r*.82,.045,'cream')
 for i in range(12):
  a=i*math.tau/12;ob=box('ClockTick',(x+math.sin(a)*r*.65,y-.18,z+math.cos(a)*r*.65),(.04,.045,.10),'brown',.015);ob.rotation_euler.y=a
 tube('ClockMinute',[(x,y-.23,z),(x+.04,y-.23,z+r*.46)],.05,'ink')
 tube('ClockHour',[(x,y-.24,z),(x+r*.3,y-.24,z-.07)],.055,'ink')
 ball('ClockPivot',(x,y-.24,z),(.085,.06,.085),'gold')
def income():
 pig_parts=pig((-.3,0,1.02),.83);clock(1.05,.08,1.9,.70)
 # Three positions along an incoming arc, ending with a coin partway inside the slot.
 # Turn each complete coin assembly to match the back-to-front slot as it approaches.
 for x,y,z,r,yaw in [(-1.20,.28,2.99,.30,24),(-.57,.25,2.57,.29,57),(-.30,.24,1.96,.29,90)]:
  first=len(PARTS);coin((x,y,z),r);bpy.context.view_layer.update()
  turn=Matrix.Translation(Vector((x,y,z)))@Matrix.Rotation(math.radians(yaw),4,'Z')@Matrix.Translation(Vector((-x,-y,-z)))
  for ob in PARTS[first:]:ob.matrix_world=turn@ob.matrix_world
 # Widen this illustration's slot to accommodate the embossed coin thickness.
 body=next(o for o in pig_parts if o.name.startswith('Pig_Body'))
 bpy.ops.mesh.primitive_cube_add(size=1,location=(-.30,.24,1.80));cutter=bpy.context.object;cutter.dimensions=(.15,.66,.42)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 select([body]);mod=body.modifiers.new('Icon deposit slot','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
 for i in range(2):
  x=-1.49-i*.16;z=3.08-i*.15
  tube('IncomingMotionTrail',[(x-.11,.29,z+.15),(x,.29,z+.02)],.021,'goldlight')
 polygon('SpeedBolt',[(1.52,1.8),(1.19,1.16),(1.52,1.16),(1.31,.65),(1.99,1.43),(1.60,1.43),(1.81,1.8)],.16,-.56,'goldlight')
def capacity():
 pig((-.95,-.25,.56),.47);pig((.72,.15,1.1),.95)
 arrow(-.57,-.04,1.9,.86)
def sack(loose_coins=True):
 # A continuous cloth neck, flared hollow mouth and tied cord distinguish a bag from a jar.
 ball('SackBody',(0,0,1.04),(.9,.67,1.04),'tan');box('SackBase',(0,0,.20),(1.40,.97,.28),'tan',.13)
 profile=[(1.81,.47),(1.94,.34),(2.06,.275),(2.17,.31),(2.32,.43),(2.47,.57),(2.55,.62)]
 n=64;verts=[];faces=[]
 for inner in (False,True):
  for row,(z,radius) in enumerate(profile):
   t=row/(len(profile)-1)
   for i in range(n):
    a=i*math.tau/n;fold=(.016+.050*t)*math.cos(7*a+.2)+.012*t*math.sin(4*a)
    r=radius+fold-(.045 if inner else 0)
    verts.append((r*math.cos(a),r*.72*math.sin(a),z+t*t*(.075*math.cos(3*a+.6)+.025*math.sin(5*a))))
 layer=n*len(profile)
 for side in (0,1):
  for row in range(len(profile)-1):
   for i in range(n):
    a=side*layer+row*n+i;b=side*layer+row*n+(i+1)%n
    face=(a,b,b+n,a+n);faces.append(tuple(reversed(face)) if side else face)
 for row in (0,len(profile)-1):
  for i in range(n):
   a=row*n+i;b=row*n+(i+1)%n;faces.append((a,a+layer,b+layer,b))
 mesh=bpy.data.meshes.new('GatheredCloth');mesh.from_pydata(verts,[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 ob=bpy.data.objects.new('FlaredFabricOpening',mesh);bpy.context.collection.objects.link(ob);select([ob]);finish(ob,'FlaredFabricOpening','tan')
 ob.data.materials.append(M['wood'])
 outside_faces=(len(profile)-1)*n
 for p in ob.data.polygons:
  if outside_faces<=p.index<outside_faces*2:p.material_index=1
 mod=ob.modifiers.new('Soft fabric folds','SUBSURF');mod.levels=2;mod.render_levels=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 for name in ('tan','wood'):
  M[name].node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.58
  M[name].node_tree.nodes['Principled BSDF'].inputs['Coat Weight'].default_value=.05
 tube('WrappedDrawstring',[(.32*math.cos(a),.235*math.sin(a),2.08) for a in [i*math.tau/16 for i in range(17)]],.043,'brown')
 tube('LeftBow',[(-.03,-.29,2.09),(-.30,-.34,2.21),(-.42,-.36,2.08),(-.26,-.36,2.01),(-.03,-.30,2.09)],.042,'brown')
 tube('RightBow',[(.03,-.29,2.09),(.30,-.34,2.22),(.43,-.35,2.10),(.27,-.36,2.01),(.03,-.30,2.09)],.042,'brown')
 ball('DrawstringKnot',(0,-.31,2.09),(.10,.07,.075),'brown')
 tube('LeftCordTail',[(-.025,-.34,2.07),(-.14,-.43,1.94),(-.19,-.53,1.73)],.034,'brown')
 tube('RightCordTail',[(.025,-.34,2.07),(.10,-.45,1.86),(.25,-.55,1.78)],.034,'brown')
 coin((0,-.66,1.03),.48)
 if loose_coins:stack(.86,-.35,3,.34)
def shield(x,y,z,s=1,tone='blue'):
 pts=[(-.56,.57),(0,.74),(.56,.57),(.51,-.14),(.30,-.49),(0,-.71),(-.30,-.49),(-.51,-.14)]
 polygon('ShieldRim',[(x+a*s,z+b*s) for a,b in pts],.20*s,y,'silver',.065*s)
 polygon('ShieldFace',[(x+a*s*.80,z+b*s*.80) for a,b in pts],.08*s,y-.135*s,tone,.04*s)
 tube('ShieldCheck',[(x-.24*s,y-.20*s,z),(x-.06*s,y-.20*s,z-.18*s),(x+.29*s,y-.20*s,z+.25*s)],.068*s,'white')

def vault_lock():
 # An oversized vault wheel, reinforced bolts, and a shield read as defence.
 box('VaultHousing',(0,.13,1.45),(2.05,.58,2.30),'deepblue',.25)
 box('VaultBezel',(0,-.22,1.45),(1.90,.25,2.14),'silver',.23)
 box('VaultDoor',(0,-.38,1.45),(1.62,.18,1.87),'blue',.20)
 for x in (-.86,.86):
  for z in (.91,1.91):box('LockingBolt',(x,-.1,z),(.60,.25,.18),'silver',.07)
 disc('WheelShadow',(0,-.51,1.47),.65,.12,'deepblue')
 tube('WheelRim',[(.56*math.sin(a),-.68,1.47+.56*math.cos(a)) for a in [i*math.tau/32 for i in range(33)]],.075,'silver')
 for i in range(5):
  a=i*math.tau/5
  tube('WheelSpoke',[(0,-.69,1.47),(.53*math.sin(a),-.69,1.47+.53*math.cos(a))],.080,'silver')
 disc('GoldWheelHub',(0,-.78,1.47),.22,.18,'gold')
 shield(.95,-.72,.55,.78,'green')

def fence_upgrade():
 box('LawnPlinth',(0,0,.12),(3.3,1.04,.25),'green',.12)
 for z in (.75,1.42):box('ReinforcedRail',(0,.12,z),(2.95,.23,.19),'silver',.07)
 for x in (-1.3,-.65,0,.65,1.3):
  polygon('Picket',[(x-.19,.25),(x+.19,.25),(x+.19,1.90),(x,2.13),(x-.19,1.90)],.22,-.08,'cream',.055)
  for z in (.77,1.43):ball('PicketRivet',(x,-.23,z),(.048,.035,.048),'gold')
 for x in (-1.63,1.63):
  box('FencePost',(x,.03,1.12),(.30,.42,2.15),'blue',.09)
  ball('PostCap',(x,.03,2.22),(.24,.25,.18),'silver')
 shield(.58,-.40,.79,.80,'blue')

def pick_tools():
 box('OpenPadlock',(0,.05,1.0),(1.58,.61,1.37),'purple',.22)
 box('LockFace',(0,-.285,1.0),(1.36,.09,1.12),'violet',.18)
 tube('OpenShackle',[(-.49,.06,1.62),(-.49,.06,2.18),(-.27,.06,2.52),(.23,.06,2.56),(.48,.06,2.28)],.15,'silver')
 disc('KeyholeDisc',(0,-.37,1.04),.19,.045,'darkpurple')
 polygon('KeyholeStem',[(-.08,1.04),(.08,1.04),(.15,.64),(-.15,.64)],.045,-.375,'darkpurple')
 # Recognisable hooked pick and bent tension wrench, not a normal door key.
 tube('HookPickShaft',[(-.80,-.60,.37),(-.27,-.58,.88),(.43,-.56,1.49),(.58,-.56,1.53),(.59,-.56,1.71)],.046,'silver')
 ob=box('HookPickGrip',(-1.00,-.62,.18),(.28,.23,.78),'blue',.11);ob.rotation_euler.y=.78
 tube('TensionWrench',[(.97,-.51,.27),(.51,-.53,.79),(-.44,-.54,1.73),(-.72,-.54,1.73)],.052,'silver')
 ob=box('WrenchGrip',(1.09,-.52,.12),(.27,.24,.65),'deepblue',.10);ob.rotation_euler.y=-.74
 star('UnlockGlint',(.98,.01,2.40),.24,'goldlight',4)

def loot_sack():
 sack()
 coin((-.91,-.39,.48),.41)
 arrow(-.69,-.14,2.59,.85,'green')

def shoe(tone='red',boot=False):
 # Continuous rounded sole and upper with a contrasting cuff and actual laces.
 ball('Sole',(-.14,0,.25),(1.24,.57,.24),'cream')
 ball('SoleStripe',(-.14,0,.34),(1.22,.56,.20),'silver' if tone=='purple' else 'gold')
 ball('ShoeUpper',(-.21,0,.56),(1.17,.53,.36),tone)
 box('Heel',(.65,.02,.71),(.67,.89,.72),tone,.24)
 box('Tongue',(.19,0,.89),(.83,.61,.21),'darkpurple' if tone=='purple' else 'brown',.10)
 if boot:
  box('HighAnkle',(.60,.02,1.15),(.80,.88,.91),tone,.24)
  box('AnkleCuff',(.60,.02,1.61),(.93,.98,.22),'cream',.10)
  box('CuffOpening',(.60,.02,1.72),(.59,.61,.04),'brown',.015)
 else:
  tube('SoftCollar',[(.68+.31*math.cos(a),.32*math.sin(a),.98) for a in [i*math.tau/20 for i in range(21)]],.095,'violet')
  ball('CollarOpening',(.68,0,.97),(.24,.23,.05),'darkpurple')
 for x in (-.14,.07,.28):
  tube('Lace',[(x,-.31,.87),(x+.09,0,.99),(x,.31,.87)],.042,'white')
 for x in (-.77,-.42,-.06,.31,.68):box('SoleTread',(x,-.515,.21),(.13,.045,.12),'silver',.035)

def speed_boots():
 shoe('red',True)
 polygon('SpeedBolt',[(-.02,1.15),(-.38,.67),(-.06,.67),(-.27,.34),(.42,.84),(.11,.84),(.33,1.15)],.10,-.56,'goldlight',.02)
 for i in range(3):
  tube('SpeedTrail',[(1.08,.15,.57+i*.38),(1.52,.15,.57+i*.38),(1.95-i*.12,.15,.57+i*.38)],.065,'goldlight')
 star('SpeedGlint',(-1.20,-.13,1.39),.18,'goldlight',4)

def sneak_thief():
 namespace=globals().copy()
 path=ROOT/"blender/shop/resident_sneak.py"
 exec(compile(path.read_text(),str(path),"exec"),namespace)
 namespace["build"]()

def house():
 box('IvoryWalls',(0,0,1.02),(2.15,1.63,1.95),'cream',.14)
 polygon('FrontGable',[(-1.12,1.72),(0,2.8),(1.12,1.72)],1.62,0,'cream',.06)
 for side in (-1,1):
  ob=box('GreenRoof',(side*.67,0,2.28),(1.8,2.10,.22),'green',.09);ob.rotation_euler.y=side*.70
 box('Door',(0,-.87,.64),(.57,.15,1.15),'wood',.14);ball('DoorKnob',(.15,-.99,.68),(.055,.055,.055),'gold')
 for x in (-.69,.69):
  box('WindowFrame',(x,-.90,1.10),(.57,.14,.63),'white',.08);box('BlueGlass',(x,-.98,1.1),(.42,.04,.47),'cyan',.04)
  box('WindowCross',(x,-1.01,1.1),(.045,.05,.48),'white',.015)
 box('Chimney',(.65,.38,2.47),(.42,.46,1.03),'wood',.06)
 box('GreenFooting',(0,0,.07),(2.55,2.02,.15),'darkgreen',.07)
def dog():
 ball('PuppyBust',(0,.10,.52),(.63,.50,.61),'tan');ball('PuppyHead',(0,0,1.39),(.84,.62,.82),'tanlight')
 for s in (-1,1):
  ob=ball('FloppyEar',(s*.74,.09,1.49),(.29,.30,.70),'brown');ob.rotation_euler.y=s*-.27
  ball('Eye',(s*.31,-.566,1.56),(.105,.07,.14),'ink');ball('EyeCatchlight',(s*.31-.02,-.626,1.61),(.027,.018,.033),'white')
  ball('Muzzle',(s*.18,-.59,1.16),(.29,.22,.23),'cream')
 ball('Nose',(0,-.80,1.27),(.20,.10,.14),'ink');ball('Tongue',(0,-.69,.94),(.12,.06,.18),'pink')
 box('Collar',(0,-.28,.66),(1.08,.53,.19),'blue',.08);coin((0,-.59,.57),.17)
def scooter():
 box('Deck',(0,0,.48),(2.13,.55,.20),'cyan',.09)
 for x in (-.86,.88):
  disc('RubberWheel',(x,0,.33),.32,.27,'ink');disc('Hub',(x,-.15,.33),.19,.035,'silver')
 tube('Stem',[(.78,0,.46),(.61,0,1.77),(.52,0,2.16)],.09,'silver')
 tube('Handlebar',[(.50,-.56,2.15),(.50,.56,2.15)],.095,'cyan')
 for y in (-.53,.53):ball('Grip',(.50,y,2.15),(.14,.19,.13),'ink')
 box('FootPad',(-.19,0,.60),(1.05,.38,.045),'deepblue',.02)
def potion():
 ball('Bottle',(0,0,.91),(.76,.55,.83),'red');ball('PotionHighlight',(-.35,-.46,1.20),(.14,.06,.24),'pinklight')
 disc('BottleNeck',(0,0,1.65),.32,.38,'white',False);disc('BottleRim',(0,0,1.81),.40,.16,'silver',False)
 disc('Cork',(0,0,1.99),.30,.26,'woodlight',False)
 disc('LabelSeal',(0,-.545,.92),.33,.08,'cream');star('LabelStar',(0,-.61,.92),.21,'gold')

def lathe(name,profile,tone):
 # A closed revolved wall, including its inner surface; axis points are shared poles.
 n=64;verts=[];rings=[];faces=[]
 for radius,z in profile:
  ring=[]
  for i in range(1 if radius==0 else n):
   a=i*math.tau/n;ring.append(len(verts));verts.append((radius*math.cos(a),radius*math.sin(a),z))
  rings.append(ring)
 for a,b in zip(rings,rings[1:]):
  for i in range(n):
   j=(i+1)%n
   if len(a)==1:faces.append((a[0],b[j],b[i]))
   elif len(b)==1:faces.append((a[i],a[j],b[0]))
   else:faces.append((a[i],a[j],b[j],b[i]))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);select([ob]);finish(ob,name,tone)
 mod=ob.modifiers.new('Rounded molded profile','SUBSURF');mod.levels=1;bpy.ops.object.modifier_apply(modifier=mod.name)
 return ob

def plunger():
 global GROUP
 GROUP='RubberCup'
 lathe('HollowRubberBell',[(0,.20),(.23,.20),(.28,.10),(.30,-.20),(.54,-.34),(.78,-.52),(.96,-.78),(1.02,-1.02),(1.10,-1.07),(1.10,-1.26),(1.04,-1.34),(.88,-1.34),(.83,-1.25),(.84,-1.11),(.78,-.95),(.60,-.70),(.34,-.47),(0,-.40)],'rubber')
 bpy.ops.mesh.primitive_torus_add(major_radius=1.04,minor_radius=.065,major_segments=64,minor_segments=12,location=(0,0,-1.20))
 finish(bpy.context.object,'ReinforcedRubberRim','rubberdark')
 GROUP='Handle'
 disc('WoodenShaft',(0,0,1.10),.15,2.16,'woodlight',False)
 disc('CupSocket',(0,0,.24),.235,.18,'wooddark',False)
 ball('RoundedGrip',(0,0,2.21),(.20,.20,.27),'woodlight')
 disc('GripCollar',(0,0,1.99),.185,.075,'wood',False)
 for name in ('rubber','rubberdark'):
  M[name].node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.44
  M[name].node_tree.nodes['Principled BSDF'].inputs['Coat Weight'].default_value=.10
 GROUP='Body'

def transform_new(first,loc,scale=1,angle=0):
 bpy.context.view_layer.update()
 matrix=Matrix.Translation(Vector(loc))@Matrix.Rotation(math.radians(angle),4,'Y')@Matrix.Scale(scale,4)
 for ob in PARTS[first:]:ob.matrix_world=matrix@ob.matrix_world

def gum():
 ball('BubblegumBomb',(0,0,0),(.47,.39,.43),'pink')
 for x,z,r in [(-.25,.09,.16),(.23,-.06,.17),(-.07,-.22,.16)]:ball('StickyGumBlob',(x,-.27,z),(r,r*.66,r),'pinklight')
 # Cartoon bomb silhouette: a fuse socket and short bent wick, without candy wrappers.
 disc('FuseSocket',(0,0,.405),.145,.16,'snout',False)
 disc('FuseSocketRim',(0,0,.49),.17,.055,'pinklight',False)
 tube('ShortFuse',[(0,0,.50),(.055,0,.66),(.20,-.015,.74),(.31,-.025,.69)],.042,'brown')
 ball('FuseEmber',(.31,-.025,.69),(.059,.050,.059),'gold')
 star('FuseSpark',(.34,-.055,.74),.125,'goldlight',4)

def golden_bone():
 ball('BoneShaft',(0,0,0),(.85,.19,.20),'gold')
 for s in (-1,1):
  for z in (-.19,.19):ball('BoneKnuckle',(s*.77,0,z),(.31,.23,.28),'gold')

def bubblegum_asset():
 gum()
 # Spark graphics belong to optional runtime particles, not the projectile mesh.
 for ob in PARTS[:]:
  if ob.name.startswith('FuseSpark'):PARTS.remove(ob);bpy.data.objects.remove(ob,do_unlink=True)
 for ob in PARTS:
  ob['role']='GumBody' if ob.name.startswith(('Bubblegum','StickyGum')) else 'Fuse'
 transform_new(0,(0,0,0),2)

def golden_bone_asset():
 golden_bone();bpy.context.view_layer.update()
 # Match BoneModel's horizontal long axis in Roblox Z, with knuckles across X.
 rotation=Matrix(((0,0,1,0),(1,0,0,0),(0,1,0,0),(0,0,0,1)))@Matrix.Scale(1.24,4)
 for ob in PARTS:ob.matrix_world=rotation@ob.matrix_world;ob['role']='GoldenBone'

def supplies():
 first=len(PARTS);plunger();transform_new(first,(-.57,.14,1.13),.64,-18)
 first=len(PARTS);golden_bone();transform_new(first,(.97,.04,1.66),.77,-48)
 # Sparse graphic glints, separate from the bone silhouette and the bomb's fuse.
 for x,y,z,r in [(1.91,-.12,2.25,.17),(.50,-.18,1.92,.115),(1.77,-.20,1.36,.095)]:
  star('GoldenBoneSparkleRim',(x,y,z),r,'goldlight',4)
  star('GoldenBoneSparkleCore',(x,y-.065,z),r*.64,'white',4)
 white=M['white'].node_tree.nodes['Principled BSDF']
 white.inputs['Emission Color'].default_value=(*linear(RGB['white']),1);white.inputs['Emission Strength'].default_value=.6
 first=len(PARTS);gum();transform_new(first,(.66,-.57,.54),.94,8)
def gem(name,x,y,z,r,tone='cyan'):
 return polygon(name,[(x,z+r),(x+r*.68,z+.14*r),(x+r*.60,z-.45*r),(x,z-r),(x-r*.60,z-.45*r),(x-r*.68,z+.14*r)],.24,y,tone,.055)

def crate(tier):
 global GROUP
 wood=tier=='common';rare=tier=='rare';body='wood' if wood else ('deepblue' if rare else 'darkpurple')
 trim='gold' if wood or not rare else 'silver';face='woodlight' if wood else ('blue' if rare else 'purple')
 width=3.2 if wood else (3.4 if rare else 3.65);depth=2.3;h=1.8 if wood else (1.85 if rare else 2.05)
 # Hollow tray and a separate bottom-centred model pivot. Lid hinge is at rear edge.
 GROUP='Body';box('Floor',(0,0,.17),(width,depth,.34),body,.14)
 for s in (-1,1):
  box('SideWall',(s*(width/2-.13),0,h/2),(.26,depth,h),body,.10)
  box('FrontBackWall',(0,s*(depth/2-.13),h/2),(width-.35,.26,h),body,.10)
  if wood:
   for row in range(3):box('TimberPlank',(0,s*(depth/2+.015),.45+row*.49),(width-.35,.14,.43),face,.05)
  else:
   box('InsetPanel',(0,s*(depth/2+.01),h*.53),(width-.72,.14,h-.57),face,.12)
  for x in (-1,1):box('CornerGuard',(x*(width/2-.10),s*(depth/2-.03),(h+.12)/2),(.27,.24,h+.12),trim,.10)
 box('BaseRim',(0,0,.18),(width+.17,depth+.16,.23),trim,.10)
 for s in (-1,1):
  # Side-mounted ring handles visibly distinguish the chest from a wooden cube.
  if not wood:tube('SideHandle',[(s*(width/2+.03),-.36,1.42),(s*(width/2+.30),-.32,1.08),(s*(width/2+.30),.32,1.08),(s*(width/2+.03),.36,1.42)],.10,trim)
 if wood:
  coin((0,-depth/2-.18,1.02),.39)
  for x in (-.93,.93):box('BrassStrap',(x,-depth/2-.12,.96),(.18,.13,1.63),trim,.05)
 else:
  box('ClaspBacking',(0,-depth/2-.15,1.22),(.75,.23,.94),trim,.13)
  snout_seal((0,-depth/2-.32,1.23),.35,'silver' if rare else 'goldlight','deepblue' if rare else 'darkpurple')
  if not rare:
   for s in (-1,1):
    polygon('GoldWing',[(s*.48,.81),(s*1.27,1.03),(s*1.47,1.54),(s*.84,1.22)],.14,-depth/2-.18,trim,.055)
 GROUP='Lid'
 box('LidLip',(0,0,h+.16),(width+.16,depth+.18,.27),trim,.12)
 if wood:
  box('WoodLid',(0,0,h+.35),(width,depth,.23),face,.10)
  for x in (-.93,.93):box('LidStrap',(x,0,h+.49),(.20,depth+.03,.075),trim,.025)
  # Visible timber separation, modeled as shallow recessed strips.
  for x in (-.42,.42):box('TimberSeam',(x,0,h+.472),(.035,depth-.22,.012),'wooddark',.004)
 else:
  box('DomedLid',(0,0,h+.43),(width-.15,depth-.06,.58),face,.27)
  for x in (-width*.33,width*.33):box('LidMetalBand',(x,0,h+.46),(.21,depth+.10,.58),trim,.09)
  if rare:
   gem('LidCrystal',0,-.27,h+.96,.38,'cyan')
  else:
   box('CrownBase',(0,0,h+.82),(1.6,.82,.23),'gold',.07)
   polygon('Crown',[(-.78,h+.81),(-.90,h+1.39),(-.39,h+1.09),(0,h+1.72),(.39,h+1.09),(.90,h+1.39),(.78,h+.81)],.30,-.06,'gold',.045)
   gem('CrownJewel',0,-.25,h+1.22,.24,'violet')
 GROUP='Body'
 return {'width':width,'depth':depth,'height':h,'hinge':[0,depth/2,h+.10],
  'attachments':{'Aura':[0,0,.18],'Seal':[0,-depth/2-.42,1.02 if wood else 1.23],'LidSpark':[0,0,h+(.65 if wood else 1.48 if rare else 1.85)]},
  'effect':{'common':'Warm gold motes; short opening sparkle','rare':'Cyan crystal motes and cool seal light','legendary':'Violet wisps, gold star sparks and a pulsing aura'}[tier]}

def bounds(obs):
 pts=[o.matrix_world@Vector(v) for o in obs for v in o.bound_box]
 return [min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]
def frame_camera(obs):
 bpy.context.view_layer.update();cam=bpy.context.scene.camera
 lo,hi=bounds(obs);target=(Vector(lo)+Vector(hi))/2
 cam.location=target+Vector((0,-10,0) if KEY=='coin-front' else (2.0,-10,3.0) if KEY=='coin' else (6,-6,10) if KEY=='golden-bone' else (4.2,-10,4.8));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
 bpy.context.view_layer.update();inv=cam.matrix_world.inverted()
 pts=[inv@(o.matrix_world@Vector(v)) for o in obs for v in o.bound_box]
 span=max(max(v[i] for v in pts)-min(v[i] for v in pts) for i in (0,1));cam.data.ortho_scale=span*1.23
 # Center the projected bounding box, not its world-space box.
 mid=Vector(((min(v.x for v in pts)+max(v.x for v in pts))/2,(min(v.y for v in pts)+max(v.y for v in pts))/2,0))
 cam.location+=cam.rotation_euler.to_matrix()@mid
def stage(obs,transparent=True):
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12 if DRAFT else 40
 scene.cycles.use_denoising=True;scene.render.resolution_x=scene.render.resolution_y=512 if DRAFT else 768
 scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=transparent
 scene.world=bpy.data.worlds.new('StudioWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.61,.72,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
 scene.view_settings.view_transform='AgX'
 if KEY=='coin-front':
  # The HUD coin needs luminous yellow gold at 24–40px, not AgX's muted bronze.
  scene.view_settings.view_transform='Standard';scene.view_settings.exposure=.25
 lo,hi=bounds(obs);target=(Vector(lo)+Vector(hi))/2
 bpy.ops.object.camera_add(location=target+Vector((4.7,-9,5.1)))
 cam=bpy.context.object;cam.name='IconCamera';cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO'
 scene.camera=cam;frame_camera(obs)
 for name,offset,power,size,color in [('Key',(-3,-4,7),850,5,(1,.92,.80)),('Fill',(4,-1,4),650,4,(.80,.90,1)),('Rim',(1,4,6),950,3,(1,.94,.83))]:
  bpy.ops.object.light_add(type='AREA',location=target+Vector(offset));ob=bpy.context.object;ob.name=name;ob.data.energy=power;ob.data.shape='DISK';ob.data.size=size;ob.data.color=color;ob.rotation_euler=(target-ob.location).to_track_quat('-Z','Y').to_euler()
 return scene
def atlas_export(objects,folder):
 # One shared palette, three PBR materials: smooth toy, metal, timber.
 image=bpy.data.images.new('ShopPalette',width=256,height=256,alpha=True)
 tones=list(RGB);pixels=[]
 for y in range(256):
  for x in range(256):pixels.extend((*[c/255 for c in RGB[tones[min(len(tones)-1,(y//32)*8+x//32)]]],1))
 image.pixels.foreach_set(pixels);image.filepath_raw=str(folder/'palette.png');image.file_format='PNG';image.save();image.pack()
 mats={}
 for key,metal,rough in [('Toy',0,.28),('Metal',.22,.28),('Timber',0,.43),('Rubber',0,.44)]:
  mat=bpy.data.materials.new('Palette_'+key);mat.use_nodes=True;p=mat.node_tree.nodes['Principled BSDF'];p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest';mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color']);mats[key]=mat
 for ob in objects:
  old=[m.name for m in ob.data.materials];indices=[p.material_index for p in ob.data.polygons];ob.data.materials.clear()
  for mat in mats.values():ob.data.materials.append(mat)
  for layer in list(ob.data.uv_layers):ob.data.uv_layers.remove(layer)
  uv=ob.data.uv_layers.new(name='ShopPalette')
  for p,idx in zip(ob.data.polygons,indices):
   tone=old[idx];tile=tones.index(tone);p.material_index=1 if tone in ('gold','goldlight','golddark','silver') else (2 if tone in ('wood','woodlight','wooddark') else 3 if tone in ('rubber','rubberdark') else 0)
   for li in p.loop_indices:uv.data[li].uv=((tile%8+.5)/8,(tile//8+.5)/8)
def export_crate(tier,spec):
 folder=OUT/'crates'/tier;folder.mkdir(parents=True,exist_ok=True)
 groups=[];by_role={role:[o for o in PARTS if o.get('role')==role] for role in ('Body','Lid')}
 for role in ('Body','Lid'):
  obs=by_role[role];select(obs);bpy.ops.object.join();ob=bpy.context.object;ob.name=role
  bpy.context.scene.cursor.location=spec['hinge'] if role=='Lid' else (0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');groups.append(ob)
 atlas_export(groups,folder)
 root=bpy.data.objects.new('Crate_'+tier,None);bpy.context.collection.objects.link(root)
 for ob in groups:ob.parent=root
 # Empty locators carry coordinates in Blender; helper creates Roblox Attachments.
 locators=[]
 for name,loc in spec['attachments'].items():
  ob=bpy.data.objects.new('FX_'+name,None);bpy.context.collection.objects.link(ob);ob.parent=root;ob.location=loc;ob.empty_display_size=.15;locators.append(ob)
 select([root]+groups+locators)
 bpy.ops.export_scene.gltf(filepath=str(folder/f'{tier}.glb'),export_format='GLB',use_selection=True,export_extras=True)
 bpy.ops.export_scene.fbx(filepath=str(folder/f'{tier}.fbx'),use_selection=True,object_types={'MESH','EMPTY'},axis_forward='-Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',path_mode='COPY',embed_textures=True,bake_anim=False,add_leaf_bones=False)
 counts={}
 for ob in groups:ob.data.calc_loop_triangles();counts[ob.name]=len(ob.data.loop_triangles);assert counts[ob.name]<20000
 spec['triangles']=counts;spec['root']='bottom center';spec['coordinates']='Blender XYZ; glTF/Roblox = (x,z,-y), 1 unit = 1 stud'
 spec['robloxHinge']=[spec['hinge'][0],spec['hinge'][2],-spec['hinge'][1]]
 spec['robloxAttachments']={n:[p[0],p[2],-p[1]] for n,p in spec['attachments'].items()}
 (folder/'manifest.json').write_text(json.dumps(spec,indent=2))
 return groups

def export_plunger():
 folder=OUT/'models/plunger';folder.mkdir(parents=True,exist_ok=True)
 grouped={role:[o for o in PARTS if o.get('role')==role] for role in ('RubberCup','Handle')};objects=[]
 for role,parts in grouped.items():
  select(parts);bpy.ops.object.join();ob=bpy.context.object;ob.name=role
  bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');objects.append(ob)
 atlas_export(objects,folder)
 root=bpy.data.objects.new('Plunger',None);bpy.context.collection.objects.link(root)
 for ob in objects:ob.parent=root
 select([root]+objects)
 bpy.ops.export_scene.gltf(filepath=str(folder/'plunger.glb'),export_format='GLB',use_selection=True,export_extras=True)
 bpy.ops.export_scene.fbx(filepath=str(folder/'plunger.fbx'),use_selection=True,object_types={'MESH','EMPTY'},axis_forward='-Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',path_mode='COPY',embed_textures=True,bake_anim=False,add_leaf_bones=False)
 spec={'root':'authored origin matching GadgetModel, not bounding-box center','coordinates':'Blender Z-up; Roblox +Y handle and -Y suction cup. 1 unit = 1 stud.','gripRoblox':[0,1.30,0],'tipRoblox':[0,-1.32,0],'boundsBlender':bounds(objects),'triangles':{}}
 for ob in objects:
  ob.data.calc_loop_triangles();spec['triangles'][ob.name]=len(ob.data.loop_triangles);assert len(ob.data.loop_triangles)<20000
 (folder/'manifest.json').write_text(json.dumps(spec,indent=2))
 return objects

def export_supply(key):
 folder=OUT/'models'/key;folder.mkdir(parents=True,exist_ok=True)
 roles=('GumBody','Fuse') if key=='bubblegum-bomb' else ('GoldenBone',)
 grouped={role:[o for o in PARTS if o.get('role')==role] for role in roles};objects=[]
 for role,parts in grouped.items():
  select(parts)
  if len(parts)>1:bpy.ops.object.join()
  ob=bpy.context.object;ob.name=role
  bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
  bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');objects.append(ob)
 atlas_export(objects,folder)
 root=bpy.data.objects.new('BubblegumBomb' if key=='bubblegum-bomb' else 'GoldenBoneAsset',None);bpy.context.collection.objects.link(root)
 for ob in objects:ob.parent=root
 coords={'FuseTip':(.62,-.05,1.38)} if key=='bubblegum-bomb' else {'GlintA':(0,-.95,0),'GlintB':(0,.95,0)}
 locators=[]
 for name,point in coords.items():
  ob=bpy.data.objects.new('FX_'+name,None);bpy.context.collection.objects.link(ob);ob.location=point;ob.parent=root;ob.empty_display_size=.10;locators.append(ob)
 select([root]+objects+locators)
 bpy.ops.export_scene.gltf(filepath=str(folder/f'{key}.glb'),export_format='GLB',use_selection=True,export_extras=True)
 bpy.ops.export_scene.fbx(filepath=str(folder/f'{key}.fbx'),use_selection=True,object_types={'MESH','EMPTY'},axis_forward='-Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',path_mode='COPY',embed_textures=True,bake_anim=False,add_leaf_bones=False)
 lo,hi=bounds(objects)
 spec={'root':'authored center at (0,0,0)','runtimeKey':'gum' if key=='bubblegum-bomb' else 'golden','boundsBlender':[lo,hi],
  'sizeRoblox':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'coordinates':'Blender XYZ to Roblox (x,z,-y); 1 unit = 1 stud',
  'attachmentsRoblox':{n:[p[0],p[2],-p[1]] for n,p in coords.items()},'triangles':{},'effects':'Optional SupplyEffects helper; no particle geometry exported'}
 for ob in objects:ob.data.calc_loop_triangles();spec['triangles'][ob.name]=len(ob.data.loop_triangles);assert len(ob.data.loop_triangles)<20000
 (folder/'manifest.json').write_text(json.dumps(spec,indent=2))
 return objects

def export_coin():
 folder=OUT/'models/coin';folder.mkdir(parents=True,exist_ok=True)
 bpy.context.view_layer.update()
 for ob in PARTS:ob.matrix_world=Matrix.Translation(Vector((0,0,-1)))@ob.matrix_world
 select(PARTS);bpy.ops.object.join();ob=bpy.context.object;ob.name='Coin'
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 atlas_export([ob],folder)
 root=bpy.data.objects.new('SnoutCoin',None);bpy.context.collection.objects.link(root);ob.parent=root
 select([root,ob])
 bpy.ops.export_scene.gltf(filepath=str(folder/'coin.glb'),export_format='GLB',use_selection=True)
 bpy.ops.export_scene.fbx(filepath=str(folder/'coin.fbx'),use_selection=True,object_types={'MESH','EMPTY'},axis_forward='-Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',path_mode='COPY',embed_textures=True,bake_anim=False,add_leaf_bones=False)
 ob.data.calc_loop_triangles();assert len(ob.data.loop_triangles)<10000
 lo,hi=bounds([ob]);spec={'root':'center of coin rim, (0,0,0)','coordinates':'Front is Roblox +Z, up is +Y; 1 unit = 1 stud','sizeRoblox':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'triangles':{'Coin':len(ob.data.loop_triangles)},'icon':'../../coin.png'}
 (folder/'manifest.json').write_text(json.dumps(spec,indent=2));return [ob]

BUILDERS={'coin':lambda:coin((0,0,1),1),'coin-front':lambda:coin((0,0,1),1),'income':income,'capacity':capacity,'locks':vault_lock,'fences':fence_upgrade,'lockpicks':pick_tools,'sack':loot_sack,'boots':speed_boots,'tiptoe':sneak_thief,'upgrades':sack,'home':house,'companions':dog,'rides':scooter,'supplies':supplies,'plunger':plunger,'bubblegum-bomb':bubblegum_asset,'golden-bone':golden_bone_asset,
 'style':lambda:crate('common'),'crate-common':lambda:crate('common'),'crate-rare':lambda:crate('rare'),'crate-legendary':lambda:crate('legendary')}
for key,build in BUILDERS.items():
 if ONLY and key not in ONLY:continue
 reset(key);spec=build();bpy.context.view_layer.update();folder=OUT/'sources';folder.mkdir(exist_ok=True)
 if key.startswith('crate-'):
  tier=key.removeprefix('crate-');obs=export_crate(tier,spec)
 elif key=='plunger':obs=export_plunger()
 elif key=='coin':obs=export_coin()
 elif key in ('bubblegum-bomb','golden-bone'):obs=export_supply(key)
 else:obs=PARTS[:]
 scene=stage(obs);scene.render.filepath=str(OUT/f'{key}.png');bpy.ops.wm.save_as_mainfile(filepath=str(folder/f'{key}.blend'))
 if not SKIP_RENDER:bpy.ops.render.render(write_still=True)
 else:assert (OUT/f'{key}.png').exists()
 if key.startswith('crate-') and not SKIP_RENDER:
  # Opening proof uses the exported lid's hinge and never writes back the saved closed scene.
  lid=bpy.data.objects.get('Lid');lid.rotation_euler.x=math.radians(-100);frame_camera(obs)
  scene.render.filepath=str(OUT/f'{key}-open.png');bpy.ops.render.render(write_still=True);lid.rotation_euler.x=0
 for ob in obs:ob.data.calc_loop_triangles()
 stats={'parts':len(obs),'triangles':sum(len(o.data.loop_triangles) for o in obs),'source':f'sources/{key}.blend','image':f'{key}.png'}
 REPORT[key]=stats;print('ICON_READY',key,json.dumps(stats),flush=True)
 path=OUT/'build-report.json';old=json.loads(path.read_text()) if path.exists() else {};old[key]=stats;path.write_text(json.dumps(old,indent=2))
assert hashlib.sha256(MASTER.read_bytes()).hexdigest()==MASTER_HASH
path=OUT/'build-report.json';old=json.loads(path.read_text()) if path.exists() else {}
old.update(REPORT);path.write_text(json.dumps(old,indent=2))
print('ICON_SYSTEM_COMPLETE',len(REPORT),flush=True)
