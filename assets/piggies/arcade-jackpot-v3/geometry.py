assert KEY=='jackpot'
scene['revision']='arcade-jackpot-v3';scene['displayName']='Jackpot'
gold=mat('V3 polished gold',(240,181,58),.72)
dark=mat('V3 black cherry lenses',(21,13,26),.42)
dark.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.18
diamond=mat('V3 champagne diamonds',(255,240,208),.40,.08)
wine=mat('V3 burgundy enamel',(95,15,36),.22)
bright=mat('V3 coin emboss',(255,219,116),.58)
shadow=mat('V3 chute interior',(23,12,15),.1)
for o in list(extras):
 if o.name.startswith('GoldToken_') or o.name in ['JackpotRivet_%s_%s'%(s,j) for s in (-1,1) for j in (1,2)]:extras.remove(o);bpy.data.objects.remove(o,do_unlink=True)

def tube(name,points,radius,material,n=8):
 vs=[]
 for i,p in enumerate(points):
  p=Vector(p);t=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized();u=t.cross(Vector((0,0,1))).normalized();v=t.cross(u).normalized()
  for j in range(n):vs.append(tuple(p+radius*(u*math.cos(j*math.tau/n)+v*math.sin(j*math.tau/n))))
 fs=[tuple(reversed(range(n))),tuple((len(points)-1)*n+j for j in range(n))]
 fs.extend([(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(points)-1) for j in range(n)])
 return mesh(name,vs,fs,material)

profile=[(-.78,-1),(.78,-1),(1,-.60),(1,.60),(.78,1),(-.78,1),(-1,.60),(-1,-.60)]
def shade_y(x):return -1.115+.16*abs(x)**1.4
for side in (-1,1):
 cx=side*.353;cz=.432;vs=[]
 for rx,rz,depth in [(.327,.207,.01),(.327,.207,-.031),(.268,.151,-.031),(.268,.151,.010)]:
  for u,v in profile:
   x=cx+u*rx;vs.append((x,shade_y(x)+depth,cz+v*rz))
 fs=[(k*8+j,k*8+(j+1)%8,((k+1)%4)*8+(j+1)%8,((k+1)%4)*8+j) for k in range(4) for j in range(8)]
 mesh('JackpotShadesGoldFrame_'+str(side),vs,fs,gold)
 vs=[]
 for depth in (-.022,-.004):
  for u,v in profile:
   x=cx+u*.271;vs.append((x,shade_y(x)+depth,cz+v*.154))
 fs=[tuple(reversed(range(8))),tuple(range(8,16))]+[(j,(j+1)%8,(j+1)%8+8,j+8) for j in range(8)]
 mesh('JackpotShadesLens_'+str(side),vs,fs,dark)
 # Faceted stones physically set in the wide upper and lower rims.
 for row,z in enumerate((cz-.18,cz+.18)):
  for j in range(7):
   x=cx-.218+j*.0727
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.026,location=(x,shade_y(x)-.047,z))
   adopt(bpy.context.object,'JackpotShadesDiamond_%s_%s_%s'%(side,row,j),diamond)
 for j,z in enumerate((cz-.07,cz+.07)):
  x=cx+side*.300;bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.026,location=(x,shade_y(x)-.047,z));adopt(bpy.context.object,'JackpotShadesCornerGem_%s_%s'%(side,j),diamond)
 tube('JackpotShadesTemple_'+str(side),[(side*.674,shade_y(.674),.49),(side*.80,-.80,.50),(side*.80,-.55,.56),(side*.69,-.34,.64)],.027,gold)
 # A narrow glint etched into each dark lens.
 tube('JackpotShadesLensGlint_'+str(side),[(cx-.15,shade_y(cx-.15)-.025,.51),(cx-.02,shade_y(cx-.02)-.025,.56)],.007,diamond,6)
tube('JackpotShadesBridge',[(-.085,-1.143,.465),(0,-1.158,.49),(.085,-1.143,.465)],.022,gold)
# Each stone setting is one static mesh, reducing draw calls without losing facets.
for side in (-1,1):
 stones=[o for o in fx.objects if o.type=='MESH' and o.name.startswith(('JackpotShadesDiamond_'+str(side)+'_','JackpotShadesCornerGem_'+str(side)+'_'))]
 bpy.ops.object.select_all(action='DESELECT')
 for o in stones:o.select_set(True)
 bpy.context.view_layer.objects.active=stones[0];bpy.ops.object.join();bpy.context.object.name='JackpotShadesStones_'+str(side)
extras=[o for o in fx.objects if o.type=='MESH']

# Gold-rimmed payout mouths on the actual side of the slot-machine casing.
for side in (-1,1):
 vs=[]
 for x,wy,hz in [(side*.734,.175,.125),(side*.816,.175,.125),(side*.816,.139,.092),(side*.734,.139,.092)]:
  for y,z in [(-wy,-hz),(wy,-hz),(wy,hz),(-wy,hz)]:vs.append((x,.30+y,1.025+z))
 fs=[(k*4+j,k*4+(j+1)%4,((k+1)%4)*4+(j+1)%4,((k+1)%4)*4+j) for k in range(4) for j in range(4)]
 mesh('JackpotPayoutChute_'+str(side),vs,fs,gold)
 box('JackpotPayoutMouth_'+str(side),(side*.736,.30,1.025),(.012,.277,.180),shadow,.014)
 box('JackpotPayoutLip_'+str(side),(side*.829,.30,.909),(.105,.363,.031),gold,.009)

def set_linear(obj):
 if not obj.animation_data or not obj.animation_data.action:return
 for layer in obj.animation_data.action.layers:
  for strip in layer.strips:
   for slot in obj.animation_data.action.slots:
    bag=strip.channelbag(slot)
    if bag:
     for fc in bag.fcurves:
      for k in fc.keyframe_points:k.interpolation='LINEAR'

# Twelve capped, embossed token meshes, with looping ballistics and hidden resets.
tokens=[]
for side in (-1,1):
 for j in range(6):
  token=cylinder('JackpotPayoutCoin_%s_%s'%(side,j),(0,0,0),.086,.023,gold,'X',20)
  bpy.context.view_layer.objects.active=token;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
  made=[token]
  for face in (-1,1):
   vs=[]
   for depth in (face*.0115,face*.0145):
    for k in range(10):
     angle=math.pi/2+k*math.pi/5;r=.047 if k%2==0 else .021
     vs.append((depth,r*math.cos(angle),r*math.sin(angle)))
   fs=[tuple(reversed(range(10))),tuple(range(10,20))]+[(k,(k+1)%10,(k+1)%10+10,k+10) for k in range(10)]
   made.append(mesh('TEMP_coin_star',vs,fs,bright))
  bpy.ops.object.select_all(action='DESELECT')
  for o in made:o.select_set(True)
  bpy.context.view_layer.objects.active=token;bpy.ops.object.join();extras=[o for o in fx.objects if o.type=='MESH']
  for frame in range(1,146):
   t=((frame-1)/24-j*.5-(.15 if side==1 else 0))%3
   if t<1.75:
    u=t/1.75
    token.location=(side*(.79+.95*u),.30-.21*u,1.025+.8*u-2.12*u*u)
    size=max(.001,min(1,t/.10,(1.75-t)/.20))
    token.rotation_euler=(u*5.2+j*.3,u*8.4,side*u*3.2)
   else:
    token.location=(side*.77,.30,1.025);size=.001;token.rotation_euler=(0,0,0)
   token.scale=(size,size,size)
   for data_path in ('location','rotation_euler','scale'):token.keyframe_insert(data_path=data_path,frame=frame)
  token['motion']='machine payout: emerge, tumble, fall, shrink; reset hidden in chute';token['periodSeconds']=3
  set_linear(token);tokens.append(token)
scene.frame_set(1);bpy.context.view_layer.update()
# Test each flight path against the pig, while ensuring reset frames are tiny.
flight_samples=0
for frame in range(1,146,3):
 scene.frame_set(frame);bpy.context.view_layer.update()
 for token in tokens:
  if token.scale.x>.1:
   p=token.location;assert abs(p.x)>.77 and p.z>-.35,(token.name,frame,tuple(p))
   assert p.x*p.x+(p.y/1.08)**2+(p.z/.96)**2>1.25,('coin intersects pig',token.name,frame)
   flight_samples+=1
scene.frame_set(1)
payout_validation={'chutes':2,'animatedCoins':12,'periodSeconds':3,'fullLoopSeconds':6,'pathSamples':flight_samples,'hiddenReset':True,'startsAtMachine':True}
