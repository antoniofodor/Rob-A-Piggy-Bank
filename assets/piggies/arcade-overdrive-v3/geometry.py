"""Overdrive: fitted energy armor and a rotating rear reactor."""
assert KEY=='finalboss'
scene['displayName']='Overdrive';scene['revision']='arcade-overdrive-v3';scene['runtimeStatus']='Review only'
for o in list(extras):bpy.data.objects.remove(o,do_unlink=True)
extras=[]
plum=mat('Overdrive armor',(53,25,66),.35)
violet=mat('Overdrive inset facets',(87,35,98),.3)
gold=mat('Overdrive champagne gold',(218,164,79),.68)
dark=mat('Overdrive sockets',(24,13,33),.22)
pink=mat('Overdrive energy',(255,34,151),.12,1.3)
pale=mat('Overdrive hot core',(255,148,222),.05,1.6)
rose=mat('Overdrive lower facets',(166,17,92),.18,.35)
skin=mat('Overdrive clean pink',(231,133,174),.03)
inner=mat('Overdrive inner ear',(180,73,119),.02)
for name in ('Body','Snout','Legs','Tail'):
 o=parts[name];o.data.materials.clear();o.data.materials.append(skin)
with bpy.data.libraries.load(str(ROOT/'assets/piggies/common/cow/source/cow_closed.blend'),link=False) as (a,b):b.objects=['Ears']
original=b.objects[0];indices=[p.material_index for p in original.data.polygons];bpy.data.objects.remove(original,do_unlink=True)
parts['Ears'].data.materials.clear();parts['Ears'].data.materials.append(skin);parts['Ears'].data.materials.append(inner)
for p,i in zip(parts['Ears'].data.polygons,indices):p.material_index=min(i,1)

def cut(target,cutter):
 bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT');target.select_set(True);bpy.context.view_layer.objects.active=target
 m=target.modifiers.new('Functional aperture','BOOLEAN');m.solver='MANIFOLD';m.operation='DIFFERENCE';m.object=cutter;bpy.ops.object.modifier_apply(modifier=m.name)
def remove(o):
 if o in extras:extras.remove(o)
 bpy.data.objects.remove(o,do_unlink=True)
def surface(theta,lat,lift):
 t=math.radians(theta);l=math.radians(lat);d=Vector((math.sin(t)*math.cos(l),-math.cos(t)*math.cos(l),math.sin(l)))
 hit,co,*_=parts['Body'].ray_cast(d*4,-d)
 if not hit or co.dot(d)<.7:co=d/math.sqrt(d.x*d.x+(d.y/1.08)**2+(d.z/.96)**2)
 return co+d*lift

# Reuse the proven pig-fitting crown topology, with its own Overdrive finish.
source=ROOT/'assets/piggies/legendary/mechaplayer/package/arcade-v3/mechaplayer-arcade-v3.blend'
with bpy.data.libraries.load(str(source),link=False) as (a,b):b.objects=['MechContinuousBackArmor']
shell=b.objects[0];fx.objects.link(shell);shell.name='OverdriveContinuousShell';shell.data.materials.clear();shell.data.materials.append(plum);extras.append(shell)
slot=box('TEMP_coin_slot',(0,.27,1.02),(.174,.57,.63),dark,0);cut(shell,slot);remove(slot)

def tube(name,points,radius,material,n=6):
 vs=[]
 for i,p in enumerate(points):
  p=Vector(p);direction=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])).normalized()
  axis=Vector((0,0,1)) if abs(direction.z)<.95 else Vector((1,0,0));u=direction.cross(axis).normalized();v=direction.cross(u).normalized()
  for j in range(n):vs.append(tuple(p+radius*(math.cos(j*math.tau/n)*u+math.sin(j*math.tau/n)*v)))
 fs=[tuple(reversed(range(n))),tuple((len(points)-1)*n+j for j in range(n))]
 fs.extend([(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(points)-1) for j in range(n)])
 return mesh(name,vs,fs,material)

# Routed luminous channels sit inside narrow dark tracks, rather than printing
# a noisy shell texture. Angular paths echo an arcade power meter.
for side in (-1,1):
 for j,path in enumerate([
  [(48,-31),(48,-9),(52,2),(52,34),(59,45),(59,62),(74,75)],
  [(126,-35),(126,-17),(137,-6),(137,24),(145,36),(145,64),(137,75)],
  [(87,53),(104,60),(110,74),(112,81)],
 ]):
  sampled=[]
  for (ta,la),(tb,lb) in zip(path,path[1:]):
   steps=max(1,math.ceil(max(abs(tb-ta),abs(lb-la))/2))
   sampled.extend([(ta+(tb-ta)*i/steps,la+(lb-la)*i/steps) for i in range(steps)])
  sampled.append(path[-1])
  pts=[surface(side*t,l,.080) for t,l in sampled]
  tube('OverdriveChannelBed_%s_%s'%(side,j),pts,.024,dark)
  tube('OverdriveEnergyChannel_%s_%s'%(side,j),[surface(side*t,l,.103) for t,l in sampled],.012,pink)
 # Small raised inset panels break up the crown without changing its coverage.
 for j,(t0,t1,l0,l1) in enumerate([(65,105,41,69),(113,133,40,67),(67,121,-40,-23)]):
  o=patch('OverdriveInsetPlate_%s_%s'%(side,j),side*t0,side*t1,l0,l1,violet,.035,nx=5,ny=3,lift=.052)
  for poly in o.data.polygons:poly.use_smooth=False

# The coin opening receives a simple fitted lip; the center remains open.
for side in (-1,1):
 pts=[]
 for j in range(12):
  y=.006+j*.528/11;x=side*.085;z=.96*math.sqrt(1-x*x-(y/1.08)**2)+.075;pts.append((x,y,z))
 tube('OverdriveSlotRail_'+str(side),pts,.012,gold)

def body_x(y,z):return math.sqrt(max(.12,1-(y/1.08)**2-(z/.96)**2))
def shield(name,side,cy,cz,sy,sz):
 profile=[(0,1),(.60,.70),(1,.12),(.68,-.66),(0,-1),(-.65,-.68),(-1,.13),(-.56,.76)]
 vs=[]
 # Back, outside bevel edge, thin gold face, violet inside border, raised center.
 for scale,lift in [(1,.025),(1,.09),(.92,.11)]:
  for y,z in profile:
   yy=cy+y*sy*scale;zz=cz+z*sz*scale;vs.append((side*(body_x(yy,zz)+lift),yy,zz))
 center=len(vs);vs.append((side*(body_x(cy,cz)+.16),cy,cz))
 fs=[tuple(reversed(range(8)))]
 fs.extend([(j,(j+1)%8,8+(j+1)%8,8+j) for j in range(8)])
 fs.extend([(8+j,8+(j+1)%8,16+(j+1)%8,16+j) for j in range(8)])
 fs.extend([(16+j,16+(j+1)%8,center) for j in range(8)])
 o=mesh(name,vs,fs,gold);o.data.materials.append(violet);o.data.materials.append(plum)
 for f in o.data.polygons:
  if f.index>=17:f.material_index=1 if f.index%3 else 2
 pivot=Vector((side*(body_x(cy,cz)+.06),cy,cz));o.data.transform(Matrix.Translation(-pivot));o.location=pivot
 return o

def crystal(name,pos,r,material=pink,axis='X',side=1):
 # An octagonal diamond with a bevel and a separate hot central facet.
 profile=[(0,1),(.23,.68),(1,0),(.68,-.23),(0,-1),(-.23,-.68),(-1,0),(-.68,.23)]
 vs=[]
 for depth,scale in [(-.024,1),(.015,1),(.058,.68)]:
  for u,v in profile:
   q=Vector((side*depth,u*r*scale,v*r*scale))
   if axis=='Y':q=Vector((q.y,q.x,q.z))
   vs.append(tuple(q))
 fs=[tuple(reversed(range(8)))];fs.extend([(k*8+j,k*8+(j+1)%8,(k+1)*8+(j+1)%8,(k+1)*8+j) for k in range(2) for j in range(8)]);fs.append(tuple(range(16,24)))
 o=mesh(name,vs,fs,material);o.data.materials.append(pale);o.data.materials.append(rose);o.location=pos
 for f in o.data.polygons:
  if material==pink and f.index==17:f.material_index=1
  elif material==pink and 9<=f.index<=16:f.material_index=2 if f.index%3==0 else 0
 return o

def pulse(o,amount=.035,phase=0):
 for f in range(1,146,12):
  t=(f-1)/144*math.tau;s=1+amount*math.sin(t*2+phase);o.scale=(s,s,s);o.keyframe_insert(data_path='scale',frame=f)
 o['motion']='two energy pulses per six-second loop';scene.frame_set(1)

for side in (-1,1):
 guard=shield('OverdriveShoulderShield_'+str(side),side,.09,.16,.51,.52)
 # Nested diamond socket and emitter are seated inside the shield's silhouette.
 socket=crystal('OverdriveDiamondSocket_'+str(side),(side*1.105,.09,.21),.285,gold,side=side);child(socket,guard)
 well=crystal('OverdriveDiamondWell_'+str(side),(side*1.13,.09,.21),.251,dark,side=side);child(well,guard)
 core=crystal('OverdriveShoulderCore_'+str(side),(side*1.165,.09,.21),.21,side=side);child(core,guard);pulse(core,.035,side)
 for j,y in enumerate((-.34,.49)):
  pin=cylinder('OverdriveHinge_'+str(side)+'_'+str(j),(side*1.045,y,.22),.071,.105,gold,'X',12);child(pin,guard)
  inset=cylinder('OverdriveHingeInset_'+str(side)+'_'+str(j),(side*1.104,y,.22),.038,.015,dark,'X',12);child(inset,guard)
 sway(guard,0,.016,side)
 # Low hip armor and four embedded charge cells on each flank.
 shield('OverdriveHipPlate_'+str(side),side,.09,-.47,.45,.19)
 box('OverdriveChargeMeterFrame_'+str(side),(side*1.039,.04,-.44),(.056,.53,.15),gold,.022)
 box('OverdriveChargeMeterWell_'+str(side),(side*1.07,.04,-.44),(.014,.48,.112),dark,.014)
 for j in range(4):
  box('OverdriveChargeCell_%s_%s'%(side,j),(side*1.080,-.13+j*.113,-.44),(.008,.077,.066),pink if j<3 else pale,.005)
 # Exposed pink feet distinguish Overdrive from Mecha's boots.
 for j,y in enumerate((-.48,.54)):
  ring('OverdriveAnkleCuff_%s_%s'%(side,j),(side*.5,y,-.81),.263,.18,.095,plum,n=16)
  ring('OverdriveAnkleRim_%s_%s'%(side,j),(side*.5,y,-.774),.266,.18,.018,gold,n=16)

# Rear reactor remains below the tail and away from the crown coin slot.
cylinder('OverdriveReactorMount',(0,1.066,-.08),.365,.14,plum,'Y',16)
ring('OverdriveReactorGoldRim',(0,1.151,-.08),.36,.296,.065,gold,'Y',16)
cylinder('OverdriveReactorWell',(0,1.153,-.08),.295,.024,dark,'Y',16)
ring('OverdriveReactorEnergyRing',(0,1.173,-.08),.271,.231,.018,pink,'Y',24)
core=crystal('OverdriveRearCore',(0,1.22,-.08),.185,axis='Y');pulse(core,.045)
# One rotor object contains eight capped marker blocks; transform animation exports
# with the existing sampled Arcade motion pipeline.
rotor_parts=[]
for j in range(8):
 t=j*math.tau/8;o=box('TEMP_rotor_'+str(j),(.315*math.sin(t),1.20,-.08+.315*math.cos(t)),(.047,.038,.080),gold,.008);o.rotation_euler.y=t;rotor_parts.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in rotor_parts:o.select_set(True)
bpy.context.view_layer.objects.active=rotor_parts[0];bpy.ops.object.join();rotor=bpy.context.object;rotor.name='OverdriveRotatingReactor'
extras=[o for o in fx.objects if o.type=='MESH']
bpy.context.scene.cursor.location=(0,1.20,-.08);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');rotor.rotation_euler=(0,0,0)
for f in range(1,146,12):rotor.rotation_euler.y=(f-1)/144*math.tau;rotor.keyframe_insert(data_path='rotation_euler',frame=f)
rotor['motion']='one reactor rotation per six seconds';scene.frame_set(1)
for side in (-1,1):
 # Rear energy cartridges read as mounted hardware, with exposed luminous faces.
 for j in range(2):
  x=side*(.57+j*.14);z=-.25+j*.29
  mount=box('OverdriveCartridgeMount_%s_%s'%(side,j),(x,.90,z),(.20,.23,.21),dark,.035)
  gem_o=crystal('OverdriveCartridge_%s_%s'%(side,j),(x,1.055,z),.115,axis='Y');pulse(gem_o,.026,j)

# Preserve the six-second sparse pixel aura already in the review scene.
scene.frame_set(1)
