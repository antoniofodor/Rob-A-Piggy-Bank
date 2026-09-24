"""Revise the approved gem armor into one fitted mage robe and full boots."""
scene['revision']='arcade-mage-v4';scene['displayName']='Spellcaster'
plum=bpy.data.materials['finalboss_v2_Overdrive armor']
violet=bpy.data.materials['finalboss_v2_Overdrive inset facets']
gold=bpy.data.materials['finalboss_v2_Overdrive champagne gold']
pink=bpy.data.materials['finalboss_v2_Overdrive energy']
dark=bpy.data.materials['finalboss_v2_Overdrive sockets']
# Softer robe finish keeps the new mantle from reading as floating metal fins.
plum.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.55
violet.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.5

def remove(o):
 if o in extras:extras.remove(o)
 bpy.data.objects.remove(o,do_unlink=True)
def cut(target,cutter):
 bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT');target.select_set(True);bpy.context.view_layer.objects.active=target
 m=target.modifiers.new('Fitted opening','BOOLEAN');m.solver='MANIFOLD';m.operation='DIFFERENCE';m.object=cutter;bpy.ops.object.modifier_apply(modifier=m.name)
for o in list(extras):
 if o.name.startswith(('OverdriveContinuousShell','OverdriveInsetPlate','OverdriveAnkle')) or o.name in ['OverdriveChannelBed_%s_2'%s for s in (-1,1)]+['OverdriveEnergyChannel_%s_2'%s for s in (-1,1)]:remove(o)

def surface(theta,lat,lift):
 t=math.radians(theta);l=math.radians(lat);d=Vector((math.sin(t)*math.cos(l),-math.cos(t)*math.cos(l),math.sin(l)))
 hit,co,*_=parts['Body'].ray_cast(d*4,-d)
 if not hit or co.dot(d)<.70:co=d/math.sqrt(d.x*d.x+(d.y/1.08)**2+(d.z/.96)**2)
 return co+d*lift

# A single connected shell extends from the crown, around both sides and fully
# below the belly. A real front opening exposes the face; boots fill leg apertures.
n=64;lats=[-87,-80,-70,-60,-50,-42,-32,-20,-8,4,16,28,40,50,60,70,80,87]
vs=[tuple(surface(i*360/n,lat,.067)) for lat in lats for i in range(n)]
bottom=len(vs);vs.append(tuple(surface(0,-90,.067)));top=len(vs);vs.append(tuple(surface(0,90,.067)))
fs=[]
for row in range(len(lats)-1):
 for i in range(n):
  theta=(i+.5)*360/n;near_face=theta<45 or theta>315
  if near_face and lats[row]>=-20 and lats[row+1]<=50:continue
  fs.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i))
for i in range(n):
 fs.append((bottom,(i+1)%n,i));j=(len(lats)-1)*n;fs.append((top,j+i,j+(i+1)%n))
robe=mesh('MageContinuousRobe',vs,fs,plum);robe.data.materials.append(violet)
# The violet mantle is part of the same mesh, with no separated triangular plates.
for f in robe.data.polygons:
 center=sum((robe.data.vertices[i].co for i in f.vertices),Vector())/len(f.vertices)
 if center.z>.62:f.material_index=1
 f.use_smooth=True
bm=bmesh.new();bm.from_mesh(robe.data)
loose=[v for v in bm.verts if not v.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.to_mesh(robe.data);bm.free()
bpy.ops.object.select_all(action='DESELECT');robe.select_set(True);bpy.context.view_layer.objects.active=robe
m=robe.modifiers.new('Closed robe lining','SOLIDIFY');m.thickness=.083;m.offset=-1;m.use_even_offset=True;bpy.ops.object.modifier_apply(modifier=m.name)
slot=box('TEMP_coin_slot',(0,.27,1.02),(.174,.57,.63),dark,0);cut(robe,slot);remove(slot)
for side in (-1,1):
 for j,y in enumerate((-.48,.54)):
  cutter=cylinder('TEMP_leg_opening',(side*.5,y,-.95),.233,1.05,dark,n=24);cut(robe,cutter);remove(cutter)

def boot(name,x,y):
 # One closed solid shoe, including the sole, with no exposed pink toes or heels.
 profile=[(.25,-1.065),(.284,-1.038),(.284,-.953),(.263,-.913),(.246,-.72),(.246,-.60),(.219,-.54)]
 n=24;verts=[]
 for r,z in profile:
  shift=-.022 if z<-.91 else 0
  for j in range(n):
   t=j*math.tau/n;verts.append((x+r*math.cos(t),y+shift+r*math.sin(t),z))
 faces=[tuple(reversed(range(n))),tuple((len(profile)-1)*n+j for j in range(n))]
 faces.extend([(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(profile)-1) for j in range(n)])
 o=mesh(name,verts,faces,violet);o.data.materials.append(dark)
 for f in o.data.polygons:
  if f.center.z< -1.0:f.material_index=1
  f.use_smooth=len(f.vertices)==4
 return o

for side in (-1,1):
 for j,y in enumerate((-.48,.54)):
  tag='%s_%s'%(side,j);x=side*.5
  boot('MageFullBoot_'+tag,x,y)
  ring('MageBootGoldCuff_'+tag,(x,y,-.665),.253,.22,.035,gold,n=24)
  ring('MageBootSoleWelt_'+tag,(x,y-.022,-1.026),.286,.25,.014,gold,n=24)
  # Small diamond clasps, facing forward, give the boots a spellcaster identity.
  for suffix,r,depth,matr in [('Setting',.094,.033,gold),('Gem',.062,.045,pink)]:
   verts=[(x,y-.269-depth,-.82),(x,y-.257,-.82)]+[(x+u*r,y-.273,-.82+v*r) for u,v in [(0,1),(1,0),(0,-1),(-1,0)]]
   faces=[(0,2+i,2+(i+1)%4) for i in range(4)]+[(1,2+(i+1)%4,2+i) for i in range(4)]
   mesh('MageBoot'+suffix+'_'+tag,verts,faces,matr)

bpy.context.view_layer.update();bpy.data.objects['ReviewGround'].location.z=-1.075
# Verify the robe really covers the underside, excluding the four fitted shoes.
under_checks=0
for x in (-.72,-.35,0,.35,.72):
 for y in (-.72,-.30,0,.30,.72):
  if any(math.hypot(x-s*.5,y-ly)<.28 for s in (-1,1) for ly in (-.48,.54)):continue
  bh,bc,*_=parts['Body'].ray_cast(Vector((x,y,-2)),Vector((0,0,1)))
  if not bh:continue
  hit,co,*_=robe.ray_cast(Vector((x,y,-2)),Vector((0,0,1)))
  assert hit and co.z<bc.z-.008,('underside uncovered',x,y,tuple(co),tuple(bc));under_checks+=1
for x in (-.3181,.3181):
 hit,co,*_=robe.ray_cast(Vector((x,-2,.3636)),Vector((0,1,0)))
 assert not hit or co.y>-.8,('eye obstructed',tuple(co))
# Every exposed leg vertex must sit inside its full boot envelope, below the robe.
leg_checks=0
for v in parts['Legs'].data.vertices:
 p=parts['Legs'].matrix_world@v.co
 if p.z>-.60:continue
 side=-1 if p.x<0 else 1;j=0 if p.y<0 else 1;y=(-.48,.54)[j]
 b=bpy.data.objects['MageFullBoot_%s_%s'%(side,j)]
 d=Vector((p.x-side*.5,p.y-y,0));d.normalize()
 hit,co,*_=b.ray_cast(p+d,-d)
 assert hit and (co-p).dot(d)>0,('leg exposed',side,j,tuple(p));leg_checks+=1
bm=bmesh.new();bm.from_mesh(robe.data);todo=set(bm.verts);components=0
while todo:
 components+=1;stack=[todo.pop()]
 while stack:
  v=stack.pop()
  for e in v.link_edges:
   other=e.other_vert(v)
   if other in todo:todo.remove(other);stack.append(other)
bm.free();assert components==1,('robe split into disconnected pieces',components)
robe_validation={'undersideCoverageRays':under_checks,'coveredLegVertices':leg_checks,'robeConnectedComponents':components,'integratedMantle':True,'fullBoots':4}
print('ROBE_CHECKS',robe_validation,flush=True)
