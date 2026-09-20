"""Toadstool Cottage visual asset prototype. Blender background build; no runtime edits.
Coordinates: Blender X right, Y into house, Z up. Numeric units are design studs.
"""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'assets/houses/toadstool-cottage-v1';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.unit_settings.system='NONE'
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1100;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.70,.78,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
scene.view_settings.view_transform='AgX'
def material(name,rgb):
 def linear(v):
  v=v/255;return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
 m=bpy.data.materials.new(name);m.diffuse_color=tuple(linear(v) for v in rgb)+(1,);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=m.diffuse_color;bs.inputs['Roughness'].default_value=.85
 return m
M={n:material(n,c) for n,c in {'Cap':(151,46,60),'CapDark':(114,35,46),'Cream':(237,218,179),'Spot':(255,239,201),'Timber':(100,65,40),'Trim':(62,43,31),'Stone':(170,151,119),'Glass':(228,172,64),'Gold':(255,203,61),'Green':(93,125,62),'Rug':(164,80,49)}.items()}
visual=[];roof=[];front=[];colliders=[];mounts={}
def keep(o,name,mat):
 o.name=name;o.data.materials.append(M[mat]);visual.append(o);return o
def cube(name,loc,size,mat,angle=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=size;o.rotation_euler.z=angle
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return keep(o,name,mat)
def cylinder(name,loc,radius,depth,mat,n=16,normal=None):
 bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=radius,depth=depth,location=loc);o=bpy.context.object
 if normal is not None:o.rotation_euler=Vector(normal).to_track_quat('Z','Y').to_euler()
 return keep(o,name,mat)
def sphere(name,loc,scale,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=loc);o=bpy.context.object;o.scale=scale
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return keep(o,name,mat)
def torus(name,loc,radius,tube,mat,normal=(0,0,1)):
 bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=6,location=loc,major_radius=radius,minor_radius=tube)
 o=bpy.context.object;o.rotation_euler=Vector(normal).to_track_quat('Z','Y').to_euler();return keep(o,name,mat)
def mesh(name,verts,faces,mat):
 m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
 bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(m);bm.free()
 o=bpy.data.objects.new(name,m);scene.collection.objects.link(o);return keep(o,name,mat)
def cut(o,cutter):
 bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('Opening','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;mod.solver='EXACT';bpy.ops.object.modifier_apply(modifier=mod.name)
 visual.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
def arch(name,center,width,spring,depth,bottom,mat):
 r=width/2;outline=[(-r,bottom),(r,bottom),(r,spring)]
 outline += [(r*math.cos(i*math.pi/12),spring+r*math.sin(i*math.pi/12)) for i in range(1,13)]
 verts=[(center[0]+x,center[1]+y,z) for y in (-depth/2,depth/2) for x,z in outline];n=len(outline)
 faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,verts,faces,mat)
def cap(name,cx,cy,bottom,rad,height):
 n=24;rings=[(rad,bottom),(.97*rad,bottom+.13*height),(.83*rad,bottom+.48*height),(.55*rad,bottom+.83*height),(.12*rad,bottom+height)]
 verts=[(cx+r*math.cos(i*math.tau/n),cy+r*math.sin(i*math.tau/n),z) for r,z in rings for i in range(n)]
 faces=[tuple(range(n-1,-1,-1))]
 for j in range(len(rings)-1):
  for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
 faces.append(tuple(range((len(rings)-1)*n,len(rings)*n)))
 return mesh(name,verts,faces,'Cap')
def collider(name,loc,size,angle=0):colliders.append({'name':name,'blenderLocation':loc,'sizeXYZ':size,'rotationZ':angle})
# Main octagonal shell; front structural wall lies on Y=0.
R=8.5;CY=8.5;FLOOR=.35;H=9.5;W=2*R*math.tan(math.pi/8)+.12
floor=cylinder('Floor',(0,CY,.175),R/math.cos(math.pi/8)+.04,.35,'Timber',8);floor.rotation_euler.z=math.pi/8
collider('FloorCentral',(0,CY,.175),(12,17,.35))
collider('FloorRight',(7.2,CY,.175),(2.4,12,.35));collider('FloorLeft',(-7.2,CY,.175),(2.4,12,.35))
for i in range(8):
 a=-math.pi/2+i*math.pi/4;n=(math.cos(a),math.sin(a),0);t=(-math.sin(a),math.cos(a),0);x=R*n[0];y=CY+R*n[1];rot=a+math.pi/2
 wall=cube('Wall_%02d'%i,(x,y,FLOOR+H/2),(W,.7,H),'Cream',rot)
 if i==0:
  cut(wall,arch('DoorCut',(0,0),5.6,5.35,2,-.1,'Cream'));front.append(wall)
  for side in (-1,1):collider('DoorJamb'+str(side),(side*(2.8+(W/2-2.8)/2),0,5.1),(W/2-2.8,.7,9.5))
  collider('DoorLintel',(0,0,9.25),(5.6,.7,1.2))
 else:
  collider('Wall_%02d'%i,(x,y,FLOOR+H/2),(W,.7,H),rot)
  if i in (1,7,2,6):
   cutter=cylinder('WindowCut',(x,y,5.4),1.55,2,'Cream',20,n);cut(wall,cutter)
   glass=cylinder('WindowGlass_%d'%i,(x,y,5.4),1.5,.12,'Glass',20,n)
   for side in (-1,1):torus('WindowFrame_%d_%d'%(i,side),(x+side*.43*n[0],y+side*.43*n[1],5.4),1.63,.19,'Trim',n)
   cross=cube('WindowCrossH_%d'%i,(x+.46*n[0],y+.46*n[1],5.4),(3.1,.16,.17),'Timber',rot)
   cube('WindowCrossV_%d'%i,(x+.46*n[0],y+.46*n[1],5.4),(.17,.16,3.1),'Timber',rot)
 for j in (-1,1) if i==0 else (0,):
  width=(W-5.8)/2 if i==0 else W
  offset=j*(2.9+width/2) if i==0 else 0
  o=cube('Plinth_%d_%d'%(i,j),(x+offset*t[0],y+offset*t[1],.7),(width,.95,.75),'Stone',rot)
  if i==0:front.append(o)
 beam=cube('TopBeam_%d'%i,(x,y,9.65),(W,.85,.4),'Timber',rot);roof.append(beam)
 a2=a+math.pi/8;rad=R/math.cos(math.pi/8)
 post=cube('CornerPost_%d'%i,(rad*math.cos(a2),CY+rad*math.sin(a2),5),(.48,.48,9.6),'Timber',rot)
# Door frame is an arched open band, never a blocking solid panel.
frame=arch('DoorFrame',(0,-.45),6.2,5.35,.35,.3,'Trim');cut(frame,arch('FrameCut',(0,-.45),5.6,5.35,1,.1,'Trim'));front.append(frame)
door=arch('Door_Open',(0,0),5.45,5.35,.3,.35,'Timber')
hinge=Vector((-2.725,-.6,0))
for v in door.data.vertices:v.co-=Vector((-2.725,0,0))
door.location=hinge;door.rotation_euler.z=math.radians(-105);front.append(door)
knob=sphere('DoorKnob',(0,0,0),(.16,.16,.16),'Gold');knob.parent=door;knob.location=(4.8,-.24,3.7);front.append(knob)
for k in range(3):
 step=cube('EntryStep_%d'%k,(0,-1-k*.8,.12+(2-k)*.055),(5.7,.86,.18+(2-k)*.11),'Stone');collider(step.name,tuple(step.location),tuple(step.dimensions))
# Main roof cap, raised cream spots; no decals or coplanar discs.
roof.append(cap('MushroomCap',0,CY,9.65,12.6,4.15))
roof.append(cylinder('CapUnderside',(0,CY,9.58),12.45,.24,'Cream',24))
for idx,(a,r,z,size) in enumerate([(-1.4,9.5,11.4,1.5),(-.6,7.4,12.4,1.2),(-2.3,6,12.9,1.7),(.6,9.5,11.4,1.5),(2.0,8,12.1,1.6),(2.9,10,11.2,1.2),(0,2,13.7,1.4)]):
 profile=[(12.6,9.65),(12.222,10.1895),(10.458,11.642),(6.93,13.0945),(1.512,13.8)]
 for (r0,z0),(r1,z1) in zip(profile,profile[1:]):
  if r1<=r<=r0:
   slope=(z1-z0)/(r0-r1);z=z0+(r0-r)*slope+.09;break
 o=sphere('RaisedSpot_%d'%idx,(r*math.cos(a),CY+r*math.sin(a),z),(size,size,.2),'Spot')
 o.rotation_euler=Vector((slope*math.cos(a),slope*math.sin(a),1)).to_track_quat('Z','Y').to_euler();roof.append(o)
# Small chimney and two baby mushrooms, assembled as low-poly forms.
roof.append(cylinder('ChimneyStem',(6,CY+3,12),.65,3,'Cream',10));roof.append(cap('ChimneyCap',6,CY+3,13.4,1.8,1))
for idx,(x,y,r) in enumerate([(8,-.3,1.3),(9.8,1.7,.8)]):
 cylinder('BabyStem_%d'%idx,(x,y,.55),r*.35,1.1,'Cream',10);cap('BabyCap_%d'%idx,x,y,1,r,1.1*r)
# Interior furniture and empty trophy mounts. Actual awards are runtime-mounted.
cube('FeaturedPlinth',(0,14.8,1),(2.6,2,1.3),'Stone')
cube('ShelfLower',(-4,14.2,3.0),(4,1.3,.26),'Timber');cube('ShelfUpper',(-4,14.2,5.0),(4,1.3,.26),'Timber')
for x in (-5.65,-2.35):cube('ShelfUpright',(x,14.4,3.9),(.22,.6,4.4),'Trim')
cube('RecordDesk',(4,13.2,2.7),(3.4,1.6,.3),'Timber')
for x in (2.6,5.4):cube('DeskLeg',(x,13.2,1.4),(.25,1.2,2.4),'Timber')
cube('RecordBook',(4,13.2,2.96),(1.5,1,.16),'Cream')
cube('AchievementBoard',(5.85,12.5,5.7),(2.7,.24,2.7),'Trim',-math.pi/4)
rug=cylinder('Rug',(0,8,.38),3.3,.05,'Rug',24)
for name,pos in {'Featured':(0,14.8,1.7),'Shelf_1':(-4.9,14.1,3.14),'Shelf_2':(-3.1,14.1,3.14),'Shelf_3':(-4.9,14.1,5.14),'Shelf_4':(-3.1,14.1,5.14),'Wall':(5.85,12.5,5.7),'Record':(4,13.2,3.1),'Plaque_Legacy':(0,16.45,6.7),'Door_Exit':(0,-1,.4)}.items():
 o=bpy.data.objects.new(name,None);scene.collection.objects.link(o);o.location=pos;o.empty_display_type='ARROWS';o.empty_display_size=.5;mounts[name]=list(pos)
# Mesh audit and actual bounds before rendering props are introduced.
bpy.context.view_layer.update()
stats=[];bounds=[]
for o in visual:
 o.data.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(o.data)
 stats.append({'name':o.name,'triangles':len(o.data.loop_triangles),'boundaryEdges':sum(e.is_boundary for e in bm.edges),'nonManifoldEdges':sum(not e.is_manifold for e in bm.edges),'material':o.data.materials[0].name});bm.free()
 bounds.extend(o.matrix_world@Vector(c) for c in o.bound_box)
lo=[min(p[i] for p in bounds) for i in range(3)];hi=[max(p[i] for p in bounds) for i in range(3)]
report={'status':'first visual mesh prototype; Studio scale/collision validation pending','units':'numeric Blender units intended as studs; verify importer scale','coordinateMapping':'Export target Blender (x,y,z) -> Roblox (-x,z,y), front -Z; pivot at front-wall ground. Verify import axis and scale in Studio.', 'boundsBlender':{'min':lo,'max':hi,'size':[hi[i]-lo[i] for i in range(3)]},'meshes':stats,'totalTriangles':sum(s['triangles'] for s in stats),'visualObjectCount':len(visual),'mountsBlender':mounts,'collisionBoxes':colliders,'doorClearWidth':5.6,'doorSpringHeight':5.35,'doorCrownHeight':8.15,'floorHeight':.35,'ceilingHeight':9.65,'coplanarPairAudit':'pending','studioPlaytest':'pending'}
(OUT/'geometry-report.json').write_text(json.dumps(report,indent=2))
# Apply object transforms and triangulate to make the static export predictable.
bpy.ops.object.select_all(action='DESELECT')
for o in visual:o.select_set(True)
bpy.context.view_layer.objects.active=visual[0]
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
for o in visual:
 mod=o.modifiers.new('ExportTriangles','TRIANGULATE')
 bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.wm.obj_export(filepath=str(OUT/'toadstool-cottage-visual.obj'),export_selected_objects=True,forward_axis='Z',up_axis='Y',export_materials=True)
try:
 bpy.ops.export_scene.fbx(filepath=str(OUT/'toadstool-cottage-visual.fbx'),use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_UNITS',axis_forward='Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
 report['fbxExport']='success'
except Exception as exc:report['fbxExport']=str(exc)
# Render studio is local review only and excluded from exports.
ground=cube('REVIEW_Ground',(0,8,-.18),(200,200,.1),'Cream');visual.remove(ground)
for name,loc,power,size in [('Key',(-18,-18,35),3500,20),('Fill',(20,-4,22),2300,18),('Rim',(0,26,30),4000,14)]:
 data=bpy.data.lights.new('REVIEW_'+name,'AREA');o=bpy.data.objects.new('REVIEW_'+name,data);scene.collection.objects.link(o);o.location=loc;data.energy=power;data.shape='DISK';data.size=size;o.rotation_euler=(Vector((0,8,6))-o.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('REVIEW_Camera');camera=bpy.data.objects.new('REVIEW_Camera',data);scene.collection.objects.link(camera);scene.camera=camera;data.type='ORTHO';data.ortho_scale=34
def render(name,loc,target):
 camera.location=loc;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/name);bpy.ops.render.render(write_still=True)
render('exterior.png',(27,-30,25),(0,7,6.5))
render('front.png',(0,-38,17),(0,7,6.4))
for o in roof+front:o.hide_render=True
render('interior.png',(22,-28,32),(0,8,3.5))
for o in roof+front:o.hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'toadstool-cottage.blend'))
(OUT/'geometry-report.json').write_text(json.dumps(report,indent=2))
print('MUSHROOM_REPORT '+json.dumps({k:report[k] for k in ('visualObjectCount','totalTriangles','boundsBlender','fbxExport')}))
