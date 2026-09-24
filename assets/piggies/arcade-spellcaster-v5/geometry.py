"""A sculpted mage hood with real ear openings, fitted over the approved robe."""
scene['revision']='arcade-spellcaster-v5';scene['displayName']='Spellcaster'
plum=bpy.data.materials['finalboss_v2_Overdrive armor']
violet=bpy.data.materials['finalboss_v2_Overdrive inset facets']
gold=bpy.data.materials['finalboss_v2_Overdrive champagne gold']
pink=bpy.data.materials['finalboss_v2_Overdrive energy']
dark=bpy.data.materials['finalboss_v2_Overdrive sockets']
lining=mat('Mage hood lining',(34,15,47),.06)
lining.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.68

def remove(o):
 if o in extras:extras.remove(o)
 bpy.data.objects.remove(o,do_unlink=True)
def cut(target,cutter):
 bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT');target.select_set(True);bpy.context.view_layer.objects.active=target
 mod=target.modifiers.new('Tailored opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='MANIFOLD';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name)

def hood_point(u,v):
 phi=math.radians(135*u)
 # Pointed face arch, softly raised crown, and a back edge seated inside the robe.
 front=Vector((.82*math.sin(phi),-.98+.18*abs(u)**1.8,.13+.90*math.cos(phi)))
 guess=Vector((.95*math.sin(phi),-.07+.47*abs(u)**1.3,.12+.88*math.cos(phi)))
 d=guess.normalized();hit,co,*_=parts['Body'].ray_cast(d*4,-d)
 if not hit or co.dot(d)<.7:co=d/math.sqrt(d.x*d.x+(d.y/1.08)**2+(d.z/.96)**2)
 back=co+d*.052
 q=front.lerp(back,v)
 q.x+=.070*math.sin(math.pi*v)*math.sin(phi)
 q.z+=.185*math.sin(math.pi*v)*max(0,math.cos(phi))**1.4
 # Soft cloth folds down each cheek without separate floating pieces.
 q.x+=.013*math.sin(3*phi)*math.sin(math.pi*v)
 return q

nu=64;nv=16
verts=[tuple(hood_point(-1+2*i/nu,j/nv)) for j in range(nv+1) for i in range(nu+1)]
faces=[(j*(nu+1)+i,j*(nu+1)+i+1,(j+1)*(nu+1)+i+1,(j+1)*(nu+1)+i) for j in range(nv) for i in range(nu)]
hood=mesh('MageHoodCloth',verts,faces,violet);hood.data.materials.append(lining);hood.data.materials.append(gold)
for p in hood.data.polygons:p.use_smooth=True
bpy.ops.object.select_all(action='DESELECT');hood.select_set(True);bpy.context.view_layer.objects.active=hood
solid=hood.modifiers.new('Thick lined fabric','SOLIDIFY');solid.thickness=.064;solid.offset=-1;solid.use_even_offset=True;solid.material_offset=1;solid.material_offset_rim=1
bpy.ops.object.modifier_apply(modifier=solid.name)

# Cut the actual ear shapes, expanded slightly for a tailored fabric clearance.
earcut=parts['Ears'].copy();earcut.data=parts['Ears'].data.copy();fx.objects.link(earcut);earcut.name='TEMP_ear_clearance'
earcut.data.materials.clear();earcut.data.materials.append(gold)
for p in earcut.data.polygons:p.material_index=0
for v in earcut.data.vertices:
 cx=.51 if v.co.x>0 else -.51
 v.co.x=cx+(v.co.x-cx)*1.13
 v.co.y=-.36+(v.co.y+.36)*1.25
 v.co.z=.85+(v.co.z-.85)*1.065
cut(hood,earcut);bpy.data.objects.remove(earcut,do_unlink=True)
# The hood ends ahead of the coin opening; an explicit clearance bore guarantees
# it cannot bridge the lip after interpolation or solidification.
slot=box('TEMP_slot_clearance',(0,.28,1.12),(.245,.66,.78),dark,0);cut(hood,slot);remove(slot)

def tube(name,points,radius,material,n=6):
 vs=[]
 for i,point in enumerate(points):
  p=Vector(point);t=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
  a=Vector((0,0,1)) if abs(t.z)<.95 else Vector((1,0,0));u=t.cross(a).normalized();v=t.cross(u).normalized()
  for j in range(n):vs.append(tuple(p+radius*(math.cos(j*math.tau/n)*u+math.sin(j*math.tau/n)*v)))
 fs=[tuple(reversed(range(n))),tuple((len(points)-1)*n+j for j in range(n))]
 fs.extend([(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(points)-1) for j in range(n)])
 return mesh(name,vs,fs,material)

rim=[hood_point(-1+2*i/96,0) for i in range(97)]
tube('MageHoodRolledFaceHem',rim,.027,plum,8)
tube('MageHoodGoldFacePiping',[p+Vector((0,-.023,0)) for p in rim],.0105,gold,6)

# Carry the geometric pink routes into the hood as symmetrical fitted embroidery.
# These paths stay on the cheek fabric, away from the ear cutouts and coin slot.
for side in (-1,1):
 path=[(side*.91,.20),(side*.74,.20),(side*.67,.29),(side*.54,.29),(side*.44,.20)]
 points=[]
 for (ua,va),(ub,vb) in zip(path,path[1:]):
  count=max(3,math.ceil(abs(ub-ua)*80))
  for i in range(count):
   u=ua+(ub-ua)*i/count;v=va+(vb-va)*i/count
   q=hood_point(u,v)
   # Surface normal from the parametric derivatives.
   du=hood_point(u+.001,v)-hood_point(u-.001,v);dv=hood_point(u,v+.001)-hood_point(u,v-.001)
   normal=du.cross(dv).normalized()
   if normal.dot(Vector((q.x,-1,q.z)))<0:normal=-normal
   points.append(q+normal*.016)
  # Include the final endpoint once.
 u,v=path[-1];q=hood_point(u,v);points.append(q+Vector((side*.012,-.008,.004)))
 tube('MageHoodPinkEmbroidery_'+str(side),points,.0085,pink)

# A small central diamond clasps the front arch, echoing the robe and boots.
center=hood_point(0,0)+Vector((0,-.037,-.025))
for label,r,y_offset,material in [('GoldSigil',.067,0,gold),('PinkSigil',.037,-.018,pink)]:
 vs=[tuple(center+Vector((0,y_offset-.020,0))),tuple(center+Vector((0,y_offset+.005,0)))]
 vs.extend(tuple(center+Vector((x*r,y_offset,z*r))) for x,z in [(0,1),(1,0),(0,-1),(-1,0)])
 fs=[(0,2+i,2+(i+1)%4) for i in range(4)]+[(1,2+(i+1)%4,2+i) for i in range(4)]
 mesh('MageHood'+label,vs,fs,material)

# Hide only the old route sections under the hood, keeping exposed robe designs.
for o in list(extras):
 if o.name.startswith(('OverdriveEnergyChannel_','OverdriveChannelBed_')) and o.name.endswith('_0'):
  # The new face embroidery replaces the old vertical face route for a clean seam.
  remove(o)

bpy.context.view_layer.update()
# Eyes and nostrils remain visible along front viewing rays.
face_checks=0
for x,z in [(-.3181,.3636),(.3181,.3636),(-.19,-.10),(.19,-.10),(0,.55)]:
 for o in [o for o in extras if o.name.startswith('MageHood')]:
  inv=o.matrix_world.inverted();hit,co,*_=o.ray_cast(inv@Vector((x,-3,z)),inv.to_3x3()@Vector((0,1,0)))
  assert not hit or (o.matrix_world@co).y>-.80,('hood obscures face',o.name,x,z,tuple(co))
 face_checks+=1
# Both ear tips must remain in front of the hood from the hero camera direction.
ear_tips=[];direction=Vector((-4,-6,2.8)).normalized()
for side in (-1,1):
 candidates=[parts['Ears'].matrix_world@v.co for v in parts['Ears'].data.vertices if v.co.x*side>0]
 tip=max(candidates,key=lambda p:p.z)
 hit,co,*_=hood.ray_cast(tip+direction*3,-direction)
 assert not hit or (co-tip).dot(direction)<-.005,('covered ear tip',side,tuple(tip),tuple(co))
 ear_tips.append(tuple(tip))
hood_validation={'earOpenings':2,'visibleEarTips':ear_tips,'faceClearanceRays':face_checks,'realClosedFabricThickness':.064,'baseEarsUnchanged':True}
print('HOOD_CHECKS',hood_validation,flush=True)
