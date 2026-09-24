"""Targeted v4 hard-surface revision. Executed inside build.py's scene context."""
steel=bpy.data.materials['mechaplayer_v2_Steel']
navy=bpy.data.materials['mechaplayer_v2_Navy armor']
edge=bpy.data.materials['mechaplayer_v2_Edge steel']
dark=bpy.data.materials['mechaplayer_v2_Inset shadow']
cyan=bpy.data.materials['mechaplayer_v2_Cyan vents']
orange=bpy.data.materials['mechaplayer_v2_Hazard orange']
orange.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*lin((255,172,30)),1)
face_mat=mat('Face ceramic',(221,230,237),.15)
face_mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.55
cap=bpy.data.objects['MechContinuousBackArmor']

def remove(o):
 if o in extras:extras.remove(o)
 bpy.data.objects.remove(o,do_unlink=True)

def cut(target,cutter):
 for obj in (target,cutter):
  bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
  if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=bm.faces)
  bm.to_mesh(obj.data);bm.free()
 bpy.context.view_layer.update()
 bpy.ops.object.select_all(action='DESELECT');target.select_set(True);bpy.context.view_layer.objects.active=target
 mod=target.modifiers.new('Machined recess','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='MANIFOLD';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name)
 print('CUT',target.name,cutter.name,len(target.data.vertices),flush=True)

def surface(theta,lat,lift):
 t=math.radians(theta);l=math.radians(lat);d=Vector((math.sin(t)*math.cos(l),-math.cos(t)*math.cos(l),math.sin(l)))
 hit,co,normal,_=parts['Body'].ray_cast(d*4,-d)
 if not hit or co.dot(d)<=0:co=d/math.sqrt(d.x*d.x+(d.y/1.08)**2+(d.z/.96)**2)
 return co+d*lift

# Slot is measured from the original Body: X +/- .065, Y .01 to .53.
# Open the preserved crown and its center seam, without altering the source pig.
slot=box('TEMP_slot',(0,.27,1.02),(.174,.57,.63),dark,0)
for o in [cap]+[o for o in extras if o.name.startswith('MechCrownSeam_')]:cut(o,slot)
remove(slot)
def slot_border():
 # Four closed rings follow the crown curvature; the center is a real opening.
 vs=[]
 for w,y0,y1,lift in [(.108,-.034,.574,.075),(.072,.006,.534,.075),(.072,.006,.534,-.010),(.108,-.034,.574,-.010)]:
  for x,y in [(-w,y0),(w,y0),(w,y1),(-w,y1)]:
   z=.96*math.sqrt(1-x*x-(y/1.08)**2)+lift;vs.append((x,y,z))
 fs=[(k*4+j,k*4+(j+1)%4,((k+1)%4)*4+(j+1)%4,((k+1)%4)*4+j) for k in range(4) for j in range(4)]
 return mesh('MechOpenCoinSlotRim',vs,fs,navy)
slot_border()

# Strip away the bolt-on vents, bars, boots, and boxy shoulder backing.
for o in list(extras):
 if o.name.startswith(('MechVent','MechRearVent','MechRearSignal','MechBoot','MechShoulder','MechLowerGuard','MechHinge')):remove(o)

def prism(name,profile,material,axis='X',level=1,thickness=.0018):
 # Thin closed decal geometry. Broad skewed faces, no rounded stick bevels.
 vs=[]
 for a in (level-thickness,level):
  for u,v in profile:vs.append((a,u,v) if axis=='X' else (u,a,v))
 n=len(profile);fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
 return mesh(name,vs,fs,material)

# Inlaid navy shoulder armor sits behind its steel rim.
for side in (-1,1):
 frame=sideplate('MechShoulderFrame_'+str(side),side,.20,.13,.46,.45,1.09,edge,inner=.84)
 cutter=sideplate('TEMP_shoulder',side,.20,.15,.405,.39,1.32,dark,inner=1.037)
 cut(frame,cutter);remove(cutter)
 panel=sideplate('MechShoulderNavy_'+str(side),side,.20,.15,.405,.39,1.055,navy,inner=1.029)
 guard=sideplate('MechLowerGuard_'+str(side),side,.08,-.19,.18,.26,1.15,steel,inner=1.036)
 cylinder('MechHinge_'+str(side),(side*1.166,.07,-.035),.076,.022,dark,'X')
 cylinder('MechHingePin_'+str(side),(side*1.181,.07,-.035),.032,.016,edge,'X')
 for j in range(3):
  y=.07+j*.145
  prism('MechPaintShoulder_%s_%s'%(side,j),[(y,.09),(y+.09,.09),(y-.07,.38),(y-.16,.38)],orange,level=side*1.057,thickness=side*.0018)

# Polygonal conforming panel tools, in longitude / latitude surface space.
def rounded_rect(x0,x1,y0,y1,c=2):
 return [(x0+c,y0),(x1-c,y0),(x1,y0+c),(x1,y1-c),(x1-c,y1),(x0+c,y1),(x0,y1-c),(x0,y0+c)]

def outline_mesh(name,poly,lo,hi,material):
 # Subdivide edges and fan rings so the face follows the curved body, not a chord.
 boundary=[]
 for i,(u,v) in enumerate(poly):
  u1,v1=poly[(i+1)%len(poly)]
  steps=max(1,int(max(abs(u1-u),abs(v1-v))/3)+1)
  boundary.extend([(u+(u1-u)*j/steps,v+(v1-v)*j/steps) for j in range(steps)])
 center=(sum(u for u,v in boundary)/len(boundary),sum(v for u,v in boundary)/len(boundary))
 vs=[];n=len(boundary);nr=3
 for lift in (lo,hi):
  vs.append(tuple(surface(*center,lift)))
  for r in range(1,nr+1):
   for u,v in boundary:vs.append(tuple(surface(center[0]+(u-center[0])*r/nr,center[1]+(v-center[1])*r/nr,lift)))
 k=1+n*nr;fs=[]
 for layer in (0,k):
  fs.extend([(layer,layer+1+j,layer+1+(j+1)%n) for j in range(n)])
  for r in range(nr-1):
   a=layer+1+r*n;b=a+n
   fs.extend([(a+j,a+(j+1)%n,b+(j+1)%n,b+j) for j in range(n)])
 a=1+(nr-1)*n
 fs.extend([(a+j,a+(j+1)%n,a+(j+1)%n+k,a+j+k) for j in range(n)])
 o=mesh(name,vs,fs,material)
 for f in o.data.polygons:f.use_smooth=True
 return o

def surface_rim(name,outer,inner,material,top=.067,bottom=.012):
 # Matching edge samples give a clean annulus without boolean shading slivers.
 vs=[];steps=5
 for poly,lift in [(outer,top),(inner,top),(inner,bottom),(outer,bottom)]:
  for i,(u,v) in enumerate(poly):
   u1,v1=poly[(i+1)%len(poly)]
   for j in range(steps):vs.append(tuple(surface(u+(u1-u)*j/steps,v+(v1-v)*j/steps,lift)))
 n=len(outer)*steps
 fs=[(k*n+j,k*n+(j+1)%n,((k+1)%4)*n+(j+1)%n,((k+1)%4)*n+j) for k in range(4) for j in range(n)]
 return mesh(name,vs,fs,material)

def inlaid_vent(name,center):
 outer=rounded_rect(center-14,center+14,-9,29,2.5)
 inner=rounded_rect(center-12,center+12,-7,27,2.5)
 cutter=outline_mesh('TEMP_vent',rounded_rect(center-13,center+13,-8,28,2.5),-.07,.15,dark)
 for ob in [cap]+[o for o in extras if o.name.startswith('MechCrownSeam_')]:cut(ob,cutter)
 remove(cutter)
 # Rim also supplies the small missing front corner outside the crown's face opening.
 rim=surface_rim(name+'Rim',outer,inner,steel)
 outline_mesh(name+'Inset',rounded_rect(center-13,center+13,-8,28,2.5),.003,.017,navy)
 for j in range(3):
  lat=-2+j*10
  outline_mesh(name+'Light_'+str(j),rounded_rect(center-9,center+9,lat,lat+3.4,.6),.018,.023,cyan)
 return rim

for side in (-1,1):
 inlaid_vent('MechRecessedSide_'+str(side),side*62)

inlaid_vent('MechRecessedRear',180)

# Replace the deep, flat shoulder boxes with plates fitted to the round shell.
# Navy lies below the rim; the lower guard remains a separate hinged module.
for o in list(extras):
 if o.name.startswith(('MechShoulderFrame','MechShoulderNavy','MechPaintShoulder')):remove(o)
paint_textures=[]
def shoulder_paint(side,center):
 # Real UV paint avoids even the tiny raised highlights of thin decal geometry.
 import struct,zlib
 size=512
 yy,xx=np.mgrid[0:size,0:size];theta=center-24+(xx+.5)/size*48;lat=35-(yy+.5)/size*59
 rgb=np.zeros((size,size,3),dtype=np.uint8);rgb[:]=[30,44,70]
 for j in range(3):
  base=center-13+j*9;shift=-side*8*(lat-8)/19
  mask=(lat>=8)&(lat<=27)&(theta>=base+shift)&(theta<=base+shift+6)
  rgb[mask]=[255,172,30]
 def chunk(tag,data):return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
 raw=b''.join(b'\0'+row.tobytes() for row in rgb)
 path=HOME/'textures/arcade-v4'/('mecha-shoulder-'+str(side)+'.png');path.parent.mkdir(parents=True,exist_ok=True)
 path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))
 m=navy.copy();m.name='Mecha_v4_painted_shoulder_'+str(side);m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.48
 tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path));tex.image.pack();m.node_tree.links.new(tex.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
 paint_textures.append(str(path.relative_to(ROOT)))
 return m
for side in (-1,1):
 center=side*103
 outer=rounded_rect(center-24,center+24,-24,35,6)
 inner=rounded_rect(center-22,center+22,-22,33,6)
 surface_rim('MechShoulderFrame_'+str(side),outer,inner,edge,.113,.045)
 panel=outline_mesh('MechShoulderNavy_'+str(side),rounded_rect(center-23,center+23,-23,34,6),.057,.078,shoulder_paint(side,center))
 uv=panel.data.uv_layers.new(name='Shoulder paint')
 for loop in panel.data.loops:
  v=panel.data.vertices[loop.vertex_index].co
  theta=math.degrees(math.atan2(v.x,-v.y));lat=math.degrees(math.atan2(v.z,math.hypot(v.x,v.y)))
  uv.data[loop.index].uv=((theta-center+24)/48,(lat+24)/59)

# A distinct fitted face plate and its narrow dark perimeter seam.
face_poly=[(-37,-45),(37,-45),(44,-32),(44,35),(35,49),(25,52),(-25,52),(-35,49),(-44,35),(-44,-32)]
gasket_poly=[(u*1.012,v*1.012) for u,v in face_poly]
gasket=surface_rim('MechFacePlateGasket',gasket_poly,face_poly,navy,.012,-.003)
face=outline_mesh('MechFacePlate',face_poly,.006,.025,face_mat)
for side in (-1,1):
 poly=[(side*35,-5),(side*47,-7),(side*47,8),(side*35,11)]
 cutter=outline_mesh('TEMP_connector',poly,-.025,.10,dark)
 for o in (face,gasket):cut(o,cutter)
 remove(cutter)
 outline_mesh('MechInsetCheekConnector_'+str(side),poly,.003,.018,navy)

# Compact boots with a visible navy upper joint, broad steel belt, recessed front
# screen and painted diagonal markings laid on the curved belt itself.
def lathe(name,cx,cy,profile,material,n=24):
 vs=[(cx+r*math.cos(j*math.tau/n),cy+r*math.sin(j*math.tau/n),z) for r,z in profile for j in range(n)]
 fs=[(k*n+j,k*n+(j+1)%n,((k+1)%len(profile))*n+(j+1)%n,((k+1)%len(profile))*n+j) for k in range(len(profile)) for j in range(n)]
 o=mesh(name,vs,fs,material)
 for f in o.data.polygons:f.use_smooth=True
 return o

for side in (-1,1):
 for j,y in enumerate((-.48,.54)):
  x=side*.5;tag='%s_%s'%(side,j)
  # Body socket wraps the actual intersection, exposing navy between white shell and boot.
  lathe('MechLegSocket_'+tag,x,y,[(.217,-.79),(.262,-.70),(.270,-.60),(.222,-.55),(.176,-.55),(.176,-.79)],navy)
  lathe('MechJointPiston_'+tag,x,y,[(.205,-.84),(.205,-.62),(.178,-.62),(.178,-.84)],dark)
  lathe('MechBootUpper_'+tag,x,y,[(.267,-.875),(.265,-.81),(.234,-.755),(.19,-.755),(.185,-.875)],navy)
  lathe('MechBootSole_'+tag,x,y,[(.19,-1.13),(.268,-1.13),(.29,-1.10),(.29,-.966),(.279,-.944),(.19,-.944)],navy)
  band=lathe('MechBootSteelBelt_'+tag,x,y,[(.185,-.967),(.293,-.967),(.293,-.816),(.266,-.802),(.185,-.802)],steel)
  # Flat front is cut into the curved belt; dark screen and light sit behind its rim.
  screen_cut=box('TEMP_boot_screen',(x,y-.28,-.896),(.185,.16,.080),dark,.006)
  cut(band,screen_cut);remove(screen_cut)
  box('MechBootDisplayWell_'+tag,(x,y-.241,-.896),(.182,.014,.078),dark,.004)
  box('MechBootDisplay_'+tag,(x,y-.253,-.896),(.135,.006,.035),cyan,.003)
  # Paint follows the outside radius with diagonal shifts and clipped flat ends.
  def clip(poly,limit,keep_greater):
   result=[]
   for a,b in zip(poly,poly[1:]+poly[:1]):
    ina=a[0]>=limit if keep_greater else a[0]<=limit
    inb=b[0]>=limit if keep_greater else b[0]<=limit
    if ina:result.append(a)
    if ina!=inb:
     t=(limit-a[0])/(b[0]-a[0]);result.append((limit,a[1]+t*(b[1]-a[1])))
   return result
  for h in range(3):
   base=(math.pi if side==-1 else 0)-.62+h*.36
   poly=[(base,-.952),(base+.235,-.952),(base+.535,-.830),(base+.300,-.830)]
   vs=[];faces=[];step=math.tau/24
   for f in range(math.floor(base/step),math.ceil((base+.535)/step)):
    clipped=clip(clip(poly,f*step,True),(f+1)*step,False)
    if len(clipped)<3:continue
    n=len(clipped);offset=len(vs)
    for radius in (.29325,.2944):
     for angle,z in clipped:
      t=(angle-f*step)/step
      vx=(1-t)*math.cos(f*step)+t*math.cos((f+1)*step)
      vy=(1-t)*math.sin(f*step)+t*math.sin((f+1)*step)
      vs.append((x+radius*vx,y+radius*vy,z))
    faces.extend([tuple(offset+k for k in reversed(range(n))),tuple(offset+n+k for k in range(n))])
    faces.extend([(offset+k,offset+(k+1)%n,offset+(k+1)%n+n,offset+k+n) for k in range(n)])
   mesh('MechPaintBoot_'+tag+'_'+str(h),vs,faces,orange)

# Reseat the existing eyes slightly forward of the new ceramic face plate.
parts['EyePreview'].location.y-=.026
bpy.data.objects['ReviewGround'].location.z=-1.142
new_textures=paint_textures
