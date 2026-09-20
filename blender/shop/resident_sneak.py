"""Pose the existing Resident_5 design for the shop icon.

Primitive sizes, colours and face transforms come from resident-reference.json,
captured read-only from the running NPC. CSG templates follow Decor.luau.
Executed with build_icon_system's geometry/render helpers in scope.
"""
def build():
 data=json.loads((ROOT/'blender/shop/resident-reference.json').read_text())['parts']
 reference={p['name']:p for p in data}
 unit=reference['Head']['size'][0]/4.7
 convert=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
 hip=Vector((0,0,1.12))
 pose=Matrix.Translation(hip)@Matrix.Rotation(-.22,4,'Y')@Matrix.Translation(-hip)@Matrix.Translation(Vector((0,0,2.76)))@Matrix.Scale(.60,4)@convert
 def material(p):
  name='NPC_'+p['name']
  if name not in M:
   mat=bpy.data.materials.new(name);mat.use_nodes=True
   rgb=tuple(c*255 for c in p['color']);shader=mat.node_tree.nodes['Principled BSDF']
   shader.inputs['Base Color'].default_value=(*linear(rgb),1);shader.inputs['Roughness'].default_value=.42
   M[name]=mat
  return name
 for p in data:material(p)
 def frame(p):
  c=p['cf'];return Matrix(((c[3],c[4],c[5],c[0]),(c[6],c[7],c[8],c[1]),(c[9],c[10],c[11],c[2]),(0,0,0,1)))
 def subtract(ob,cutter):
  select([ob]);mod=ob.modifiers.new('Original NPC CSG','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
  bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
 def raw_box(loc,size):
  bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=size
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return o
 def primitive(p):
  size=Vector(p['size']);name=p['name'];tone=material(p)
  if p.get('mesh',{}).get('kind')=='Sphere':
   size=Vector(tuple(size[i]*p['mesh']['scale'][i] for i in range(3)));o=ball(name,(0,0,0),size/2,tone)
  elif p['shape']=='Ball':o=ball(name,(0,0,0),size/2,tone)
  elif p['shape']=='Cylinder':
   bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=1,depth=2,rotation=(0,math.pi/2,0))
   o=bpy.context.object;bpy.ops.object.transform_apply(location=False,rotation=True,scale=False);o.dimensions=size;o=finish(o,name,tone)
  else:o=box(name,(0,0,0),size,tone,.025)
  o.matrix_world=frame(p);return o
 head_names={'Head','Eye','Pupil','Brow','Ear','Nose','Mouth','Neck','Tee'}
 first=len(PARTS)
 for p in data:
  name=p['name']
  if name in head_names:primitive(p)
  elif name=='Hair':
   center=Vector((0,.35591*unit,-.03829*unit));o=ball('Hair',center,(2.39203*unit,)*3,material(p))
   n=Vector((0,-.50000,.86603));cut=raw_box(center+n*(1.02776+4)*unit,(8*unit,)*3)
   cut.rotation_euler=Vector((1,0,0)).rotation_difference(n).to_euler();subtract(o,cut)
   # Two original wedge cuts form the diagonal razor notch above the brow.
   for loc,vx,vy in [((1.33206,1.20332,1.33090),(.63278,.50304,.58868),(-.69665,.70172,.14921)),((1.49229,1.04192,1.29658),(-.63278,-.50304,-.58868),(.69665,-.70172,-.14921))]:
    w,h,d=(1.2207*unit,.2300*unit,1.3400*unit)
    verts=[(x,y,z) for x in (-w/2,w/2) for y,z in ((-h/2,-d/2),(-h/2,d/2),(h/2,d/2))]
    mesh=bpy.data.meshes.new('Notch');mesh.from_pydata(verts,[],[(2,1,0),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    cut=bpy.data.objects.new('Notch',mesh);bpy.context.collection.objects.link(cut)
    vz=(-.33803,-.50452,.79448);r=Matrix((vx,vy,vz)).transposed().to_4x4();r.translation=center+Vector(loc)*unit;cut.matrix_world=r;subtract(o,cut)
  elif name=='EyeOutline':
   o=ball(name,(0,0,0),(.84*unit,)*3,material(p))
   bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.752*unit,depth=4*unit,rotation=(0,math.pi/2,0));subtract(o,bpy.context.object)
   o.matrix_world=frame(p)
  elif name=='Eyelid':
   o=ball(name,(0,0,0),(.86*unit,)*3,material(p));subtract(o,raw_box((0,(.60-3)*unit,0),(6*unit,)*3))
   f=frame(p);side=1 if p['cf'][0]>0 else -1
   f.translation=Vector((side*.86*unit,-.09*unit,1.71426*unit));o.matrix_world=f
 # Match Decor.dripNecklace in authored Roblox coordinates, relative to Head.
 def chain_point(t):
  return Vector((1.52*math.sin(t),12.92-.77*max(0,math.cos(t))**1.8,.15+1.16*math.cos(t)+.60*math.sin(t)**2))
 def link_at(center,rotation,name):
  points=[rotation@Vector((.1325*math.cos(a),.2425*math.sin(a),0))+center for a in [j*math.tau/32 for j in range(33)]]
  return tube(name,[(p-Vector((0,15.4,0)))*unit for p in points],.0375*unit,'gold')
 for i in range(32):
  t=i*math.tau/32;tangent=(chain_point(t+.001)-chain_point(t-.001)).normalized();outward=Vector((math.sin(t),0,math.cos(t)))
  right=tangent.cross(outward).normalized();rotation=Matrix((right,tangent,right.cross(tangent))).transposed()@Matrix.Rotation(math.radians(65 if i%2 else 0),3,'Y')
  link_at(chain_point(t),rotation,'ChainLink')
 link_at(Vector((0,11.99,1.40)),Matrix.Rotation(math.radians(65),3,'Y'),'PendantBail')
 def jewel_disc(name,y,z,r,depth,tone):
  return disc(name,(0,(y-15.4)*unit,z*unit),r*unit,depth*unit,tone,False)
 jewel_disc('Pendant',11.57,1.40,.525,.18,'gold')
 jewel_disc('PendantFace',11.57,1.51,.425,.04,'golddark')
 ball('PendantSnout',(0,(11.57-15.4)*unit,1.56*unit),Vector((.265,.17,.06))*unit,'goldlight')
 for x in (-.105,.105):ball('PendantNostril',(x*unit,(11.57-15.4)*unit,1.619*unit),Vector((.0375,.07,.0125))*unit,'golddark')
 # Recreate the resident's flat PIGGY tee graphic in the same local plane.
 p=reference['TeePrint'];center=Vector(p['cf'][:3]);front=center.z+.021
 bpy.ops.object.text_add(location=(0,center.y+.28,front));text=bpy.context.object;text.data.body='PIGGY';text.data.align_x='CENTER';text.data.size=.22
 select([text]);bpy.ops.object.convert(target='MESH');finish(bpy.context.object,'PIGGY_Print','white')
 tube('PrintedRoundel',[(.20*math.cos(a),center.y-.18+.20*math.sin(a),front) for a in [i*math.tau/24 for i in range(25)]],.009,'white')
 ball('PrintedSnout',(0,center.y-.18,front),(.13,.082,.008),'white')
 for x in (-.045,.045):ball('PrintedNostril',(x,center.y-.18,front+.009),(.020,.035,.005),'ink')
 bpy.context.view_layer.update()
 for o in PARTS[first:]:o.matrix_world=pose@o.matrix_world
 # Pose the resident's trouser legs and block-shaped white shoes in a crouch.
 def limb(name,a,b,width,depth,tone):
  a,b=Vector(a),Vector(b);o=box(name,(a+b)/2,(width,depth,(b-a).length),tone,.045)
  o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
 for side,hip,knee,ankle,foot in [(-1,(-.25,0,1.19),(-.66,-.15,.77),(-.72,-.28,.25),(-.89,-.36,.13)),(1,(.25,.10,1.19),(.56,.23,.74),(.83,.12,.29),(.70,.01,.15))]:
  limb('NPC_Thigh',hip,knee,.33,.35,'NPC_Leg');limb('NPC_Calf',knee,ankle,.33,.35,'NPC_Leg')
  ball('NPC_Ankle',ankle,(.13,)*3,'NPC_Ankle')
  o=box('NPC_WhiteShoe',foot,(.66,.38,.24),'NPC_Shoe',.045)
  box('NPC_Sole',(foot[0],foot[1],foot[2]-.10),(.71,.40,.075),'NPC_Sole',.018)
 # Short tee sleeves, bare arms and hands, keeping the NPC's established outfit.
 for shoulder,elbow,hand in [((-.79,0,1.97),(-1.04,-.14,1.53),(-1.18,-.30,1.86)),((.36,.03,2.02),(.73,-.14,1.66),(1.03,-.27,1.61))]:
  shoulder=Vector(shoulder);elbow=Vector(elbow);sleeve_end=shoulder+(elbow-shoulder)*.61
  limb('NPC_Sleeve',shoulder,sleeve_end,.38,.44,'NPC_Sleeve')
  tube('NPC_BareArm',[sleeve_end,elbow,hand],.12,'NPC_Arm');ball('NPC_Hand',hand,(.15,)*3,'NPC_Hand')
 first=len(PARTS);sack(loose_coins=False);transform_new(first,(1.07,-.10,.44),.56)
