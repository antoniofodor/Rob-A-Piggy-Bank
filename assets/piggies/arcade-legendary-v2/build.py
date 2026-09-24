"""Geometry revision of the three approved Arcade legendaries; preserves v1 files."""
from pathlib import Path
import bpy,bmesh,json,math,hashlib,argparse,sys
import numpy as np
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
p=argparse.ArgumentParser();p.add_argument('--skin',required=True);a=p.parse_args(args);KEY=a.skin
HOME=ROOT/'assets/piggies/legendary'/KEY
bpy.ops.wm.open_mainfile(filepath=str(HOME/'package'/f'{KEY}-arcade-v1.blend'))
scene=bpy.context.scene;scene.name=KEY+' - Arcade legendary v2';scene.frame_set(1)
parts={n:bpy.data.objects[n] for n in ('Body','Snout','Ears','Legs','Tail','EyePreview')}
fx=next(c for c in scene.collection.children if c.name.startswith('FX -'))
extras=[o for o in fx.objects if o.type=='MESH']; original_count=len(extras)
def signature(o):return hashlib.sha256(json.dumps(([list(v.co) for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],[[list(v.uv) for v in uv.data] for uv in o.data.uv_layers])).encode()).hexdigest()
signatures={n:signature(o) for n,o in parts.items()}
def lin(rgb):return tuple(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb)
def mat(name,rgb,metal=0,emit=0):
 m=bpy.data.materials.new(KEY+'_v2_'+name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF')
 b.inputs['Base Color'].default_value=(*lin(rgb),1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=.42
 b.inputs['Emission Color'].default_value=(*lin(rgb),1);b.inputs['Emission Strength'].default_value=emit;m.diffuse_color=(*lin(rgb),1);return m
def adopt(o,name,material):
 o.name=name
 for c in list(o.users_collection):c.objects.unlink(o)
 fx.objects.link(o);o.data.materials.clear();o.data.materials.append(material);extras.append(o);return o
def mesh(name,verts,faces,material):
 d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update();o=bpy.data.objects.new(name,d);fx.objects.link(o);o.data.materials.append(material);extras.append(o)
 bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(d);bm.free();return o
def box(name,pos,size,material,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=adopt(bpy.context.object,name,material);o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Machined corners','BEVEL');mod.width=bevel;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def cylinder(name,pos,r,depth,material,axis='Z',n=16):
 rot={'Z':(0,0,0),'X':(0,math.pi/2,0),'Y':(math.pi/2,0,0)}[axis]
 bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=depth,location=pos,rotation=rot);return adopt(bpy.context.object,name,material)
def ring(name,pos,ro,ri,depth,material,axis='Z',n=16):
 vs=[]
 for z,r in [(-depth/2,ro),(depth/2,ro),(depth/2,ri),(-depth/2,ri)]:
  for j in range(n):
   t=j*math.tau/n;v=Vector((r*math.cos(t),r*math.sin(t),z))
   if axis=='Y':v=Vector((v.x,v.z,v.y))
   if axis=='X':v=Vector((v.z,v.x,v.y))
   vs.append(tuple(v))
 fs=[]
 for k in range(4):
  for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,((k+1)%4)*n+(j+1)%n,((k+1)%4)*n+j))
 o=mesh(name,vs,fs,material);o.location=pos;return o
def child(o,parent):
 bpy.context.view_layer.update();world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world
 return o
def sway(o,axis,amount,phase=0):
 start=o.rotation_euler.copy()
 for f in range(1,146,18):
  o.rotation_euler=start.copy();o.rotation_euler[axis]+=amount*math.sin((f-1)/144*math.tau+phase);o.keyframe_insert(data_path='rotation_euler',frame=f)
 o['motion']='hinged armor sway';scene.frame_set(1)
def patch(name,theta0,theta1,lat0,lat1,material,depth=.075,nx=5,ny=4,lift=-.018):
 vs=[]
 for layer in (0,1):
  for j in range(ny+1):
   lat=math.radians(lat0+(lat1-lat0)*j/ny)
   for i in range(nx+1):
    theta=math.radians(theta0+(theta1-theta0)*i/nx);d=Vector((math.sin(theta)*math.cos(lat),-math.cos(theta)*math.cos(lat),math.sin(lat)))
    hit,co,norm,_=parts['Body'].ray_cast(d*4,-d)
    if not hit or co.dot(d)<=0:
     # The legacy rear closure is recessed; bridge it with the outer shell.
     co=d/math.sqrt(d.x*d.x+(d.y/1.08)**2+(d.z/.96)**2)
    vs.append(tuple(co+d*(lift+depth*layer)))
 k=(nx+1)*(ny+1);fs=[]
 for layer in (0,1):
  for j in range(ny):
   for i in range(nx):
    q=layer*k+j*(nx+1)+i;fs.append((q,q+1,q+nx+2,q+nx+1))
 border=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
 for i,q in enumerate(border):r=border[(i+1)%len(border)];fs.append((q,r,r+k,q+k))
 return mesh(name,vs,fs,material)
def sideplate(name,side,cy,cz,hy,hz,outer,material,inner=.78):
 profile=[(-.78,-1),(.57,-1),(1,-.48),(1,.5),(.52,1),(-.66,1),(-1,.45),(-1,-.5)]
 vs=[(side*x,cy+y*hy,cz+z*hz) for x in (inner,outer) for y,z in profile];n=len(profile)
 fs=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
 pivot=Vector((side*outer,cy,cz));o=mesh(name,[tuple(Vector(v)-pivot) for v in vs],fs,material);o.location=pivot;return o
def gem(name,side,cy,cz,x,r,material):
 vs=[(side*(x-.03),cy,cz),(side*(x+.10),cy,cz)]+[(side*x,cy+dy*r,cz+dz*r) for dy,dz in [(0,1),(1,0),(0,-1),(-1,0)]]
 fs=[(0,2+j,2+(j+1)%4) for j in range(4)]+[(1,2+(j+1)%4,2+j) for j in range(4)]
 return mesh(name,vs,fs,material)
if KEY in ('mechaplayer','finalboss'):
 for o in list(extras):bpy.data.objects.remove(o,do_unlink=True)
 extras=[]
if KEY=='mechaplayer':
 steel=mat('Steel',[198,210,219],.55);navy=mat('Navy armor',[30,44,70],.4);edge=mat('Edge steel',[113,138,160],.55);dark=mat('Inset shadow',[15,24,38],.1);cyan=mat('Cyan vents',[40,225,250],.15,1.15);orange=mat('Hazard orange',[247,137,33])
 for side in (-1,1):
  # Separate shell panels follow the body and have buried inner surfaces.
  for j,(lo,hi) in enumerate([(48,86),(88,127),(129,168)]):patch(f'MechShell_{side}_{j}',side*lo,side*hi,-38,56,steel,.085)
  patch(f'MechBrow_{side}',side*8,side*46,47,70,navy,.045,nx=4,ny=2)
  plate=sideplate(f'MechShoulderFrame_{side}',side,.18,.13,.48,.48,1.13,edge,.74)
  inset=sideplate(f'MechShoulderNavy_{side}',side,.18,.15,.425,.415,1.175,navy,1.11);child(inset,plate)
  arm=sideplate(f'MechLowerGuard_{side}',side,.14,-.18,.17,.29,1.235,steel,1.14);child(arm,plate)
  pivot=cylinder(f'MechHinge_{side}',(side*1.265,.13,.03),.095,.055,dark,'X');child(pivot,plate)
  pin=cylinder(f'MechHingePin_{side}',(side*1.30,.13,.03),.043,.025,edge,'X');child(pin,plate)
  for j in range(3):
   o=box(f'MechShoulderHazard_{side}_{j}',(side*1.195,.31+j*.095,.29),(.022,.046,.18),orange,.005);o.rotation_euler.x=-.3;child(o,plate)
  sway(plate,1,.028,side)
  # Raised front vents bridge the shoulder and face without covering the eyes.
  panel=box(f'MechVentRecess_{side}',(side*.88,-.54,.15),(.14,.35,.49),navy,.045);panel.rotation_euler.z=side*-.30
  for j in range(3):
   slat=box(f'MechVentLight_{side}_{j}',(side*.975,-.54,-.005+j*.135),(.035,.245,.05),cyan,.008);slat.rotation_euler.z=side*-.30
  for j,yy in enumerate((-.48,.54)):
   ring(f'MechBootSole_{side}_{j}',(side*.5,yy,-.94),.287,.183,.19,navy,n=12)
   ring(f'MechBootBand_{side}_{j}',(side*.5,yy,-.785),.294,.184,.14,steel,n=12)
   ring(f'MechBootUpper_{side}_{j}',(side*.5,yy,-.665),.261,.184,.13,navy,n=12)
   box(f'MechBootScreen_{side}_{j}',(side*.5,yy-.285,-.793),(.22,.035,.073),dark,.013)
   box(f'MechBootSignal_{side}_{j}',(side*.5,yy-.308,-.793),(.155,.012,.036),cyan,.004)
   for h in range(3):
    stripe=box(f'MechBootHazard_{side}_{j}_{h}',(side*.795,yy-.11+h*.085,-.785),(.018,.043,.112),orange,.003);stripe.rotation_euler.x=-.30
  # Deep turbine housings with visible lips, throats and segmented luminous rings.
  box(f'MechThrusterMount_{side}',(side*.59,.83,.23),(.43,.39,.55),navy,.045)
  cylinder(f'MechThrusterBody_{side}',(side*.59,1.02,.21),.285,.43,navy,'Y',20)
  ring(f'MechThrusterLip_{side}',(side*.59,1.265,.21),.297,.231,.13,edge,'Y',20)
  cylinder(f'MechThrusterThroat_{side}',(side*.59,1.273,.21),.229,.022,dark,'Y',20)
  ring(f'MechTurbineGlow_{side}',(side*.59,1.291,.21),.207,.160,.02,cyan,'Y',20)
  rotor=[]
  for j in range(10):
   t=j*math.tau/10;o=box(f'MechTurbineFin_{side}_{j}',(side*.59+.18*math.cos(t),1.31,.21+.18*math.sin(t)),(.065,.04,.026),navy,.004);o.rotation_euler.y=-t;rotor.append(o)
  # Join same-material fins into one rotating mesh, preserving a real hub pivot.
  bpy.ops.object.select_all(action='DESELECT')
  for o in rotor:o.select_set(True)
  bpy.context.view_layer.objects.active=rotor[0];bpy.ops.object.join();rotor[0].name=f'MechTurbineRotor_{side}';extras=[o for o in fx.objects if o.type=='MESH']
  scene.cursor.location=(side*.59,1.31,.21);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');o=rotor[0]
  for f,angle in [(1,0),(145,math.tau)]:o.rotation_euler=(0,angle,0);o.keyframe_insert(data_path='rotation_euler',frame=f)
  o['motion']='turbine rotation'
 patch('MechDorsalSpine',165,195,20,73,navy,.055,nx=4,ny=5)
 box('MechRearVent',(0,1.076,.18),(.27,.08,.43),navy,.025)
 for j in range(3):box('MechRearSignal_'+str(j),(0,1.13,.045+j*.125),(.18,.018,.042),cyan,.005)
elif KEY=='finalboss':
 plum=mat('Plum armor',[64,27,76],.25);violet=mat('Violet facets',[91,37,108],.25);gold=mat('Brass bevel',[211,149,65],.58);pink=mat('Energy channels',[250,35,153],.1,1.05);dark=mat('Joint sockets',[27,15,39],.2)
 for side in (-1,1):
  for j,(lo,hi) in enumerate([(47,88),(91,133),(136,173)]):
   patch(f'BossShellBorder_{side}_{j}',side*lo,side*hi,-43,67,pink,.047)
   patch(f'BossShellPanel_{side}_{j}',side*(lo+2),side*(hi-2),-41,65,plum,.075)
  guard=sideplate(f'BossPauldronRim_{side}',side,-.04,.23,.49,.49,1.15,gold,.74)
  top=sideplate(f'BossPauldronPlate_{side}',side,-.04,.25,.427,.423,1.20,violet,1.13);child(top,guard)
  jewel=gem(f'BossPauldronGem_{side}',side,-.04,.29,1.225,.245,pink);child(jewel,guard)
  for j,yy in enumerate((-.43,.36)):
   hinge=cylinder(f'BossPivot_{side}_{j}',(side*1.2,yy,.26),.105,.12,gold,'X');child(hinge,guard)
   pin=cylinder(f'BossPivotCore_{side}_{j}',(side*1.27,yy,.26),.052,.025,dark,'X');child(pin,guard)
  sway(guard,0,.022,side)
  for j,yy in enumerate((-.46,.52)):
   lower=sideplate(f'BossHipRim_{side}_{j}',side,yy,-.44,.245,.21,.93,gold,.60)
   sideplate(f'BossHipPlate_{side}_{j}',side,yy,-.425,.205,.17,.966,plum,.925)
  for j in range(2):
   yy=.69+j*.08;zz=-.30+j*.28
   cylinder(f'BossRearSocket_{side}_{j}',(side*.77,yy,zz),.14,.18,dark,'Y')
   gem(f'BossRearCrystal_{side}_{j}',side,yy,zz,.92,.13,pink)
 patch('BossBackSpine',164,196,-27,70,gold,.105,nx=4,ny=6)
 patch('BossBackInset',169,191,-20,65,plum,.135,nx=3,ny=6)
 # Rear central jewel is mounted to the back shell.
 o=gem('BossBackGem',1,0,0,0,.19,pink);o.rotation_euler.z=math.pi/2;o.location=(0,1.15,.1)
elif KEY=='jackpot':
 brass=mat('Housing gold',[217,156,53],.64);ivory=mat('Warm ivory',[242,219,165]);burgundy=mat('Reel casing',[111,28,48],.2);bulb=mat('Amber bulbs',[255,191,55],.2,1.25)
 # Replace the old saddle with several fitted closed sections under the machine.
 for o in list(extras):
  if o.name=='ReelSaddle':extras.remove(o);bpy.data.objects.remove(o,do_unlink=True)
 patch('JackpotBackSaddle',75,285,57,82,brass,.10,nx=12,ny=3)
 for side in (-1,1):
  # Arched housing end caps: extruded half-disc plus base, with raised trim.
  points=[(-.055,.95)]+[(.29+.355*math.cos(t),1.18+.365*math.sin(t)) for t in [math.pi-math.pi*j/12 for j in range(13)]]+[(.645,.95)]
  n=len(points);vs=[(side*x,y,z) for x in (.605,.70) for y,z in points];fs=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
  mesh(f'JackpotArchCase_{side}',vs,fs,burgundy)
  # Ten large studded rim lamps make the silhouette read beyond the reel print.
  for j in range(7):
   t=math.pi-math.pi*j/6;y=.29+.362*math.cos(t);z=1.18+.374*math.sin(t)
   cylinder(f'JackpotLampSocket_{side}_{j}',(side*.72,y,z),.057,.065,brass,'X',12)
   cylinder(f'JackpotLamp_{side}_{j}',(side*.759,y,z),.036,.018,bulb,'X',12)
  box(f'JackpotBasePlinth_{side}',(side*.64,.29,.96),(.18,.80,.13),brass,.03)
  for j in range(4):cylinder(f'JackpotRivet_{side}_{j}',(side*.743,.02+j*.18,.973),.024,.02,ivory,'X',10)
 # A raised rear shield and gold rails retain the open view of the moving reels.
 box('JackpotBackShield',(0,.687,1.195),(1.40,.11,.57),brass,.10)
 box('JackpotBackEnamel',(0,.752,1.205),(1.13,.026,.34),burgundy,.035)
 box('JackpotCrestRail',(0,.29,1.592),(1.43,.12,.085),brass,.025)
 for j in (-1,0,1):box(f'JackpotRearBadge_{j}',(j*.30,.78,1.21),(.125,.025,.125),brass,.015).rotation_euler.y=math.pi/4
else:raise ValueError(KEY)
# The reference faces have black eyes; all glow is in fitted hardware.
if KEY in ('mechaplayer','finalboss'):
 eye=mat('Black eyes',[21,23,29]);parts['EyePreview'].data.materials.clear();parts['EyePreview'].data.materials.append(eye)
new_textures=[]
if KEY=='mechaplayer':
 # Restore the original ear material groups before baking a clean steel face.
 with bpy.data.libraries.load(str(ROOT/'assets/piggies/common/cow/source/cow_closed.blend'),link=False) as (src,dst):dst.objects=['Ears']
 ear_source=dst.objects[0]
 ear_indices=[p.material_index for p in ear_source.data.polygons]
 bpy.data.objects.remove(ear_source,do_unlink=True)
 white=mat('Clean porcelain steel',[215,222,230],.12);earnavy=mat('Navy ear rims',[33,47,72],.2)
 for name in ('Body','Snout','Tail'):
  parts[name].data.materials.clear();parts[name].data.materials.append(white)
 parts['Legs'].data.materials.clear();parts['Legs'].data.materials.append(earnavy)
 parts['Ears'].data.materials.clear();parts['Ears'].data.materials.append(earnavy);parts['Ears'].data.materials.append(white)
 for face,index in zip(parts['Ears'].data.polygons,ear_indices):face.material_index=min(index,1)
 scene.render.engine='CYCLES';scene.cycles.samples=1;scene.render.bake.margin=12
 sheet=HOME/'sheets/arcade-v2';sheet.mkdir(exist_ok=True)
 for group,objects in {'body':[parts['Body']],'trim':[parts[n] for n in ('Snout','Ears','Legs','Tail')]}.items():
  mats={m for o in objects for m in o.data.materials};saved={}
  image=bpy.data.images.new(KEY+'_v2_'+group,1024,1024,alpha=True)
  for m in mats:
   nt=m.node_tree;bs=nt.nodes.get('Principled BSDF');out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');saved[m]=bs.outputs[0]
   emit=nt.nodes.new('ShaderNodeEmission');emit.inputs[0].default_value=bs.inputs['Base Color'].default_value;nt.links.new(emit.outputs[0],out.inputs['Surface'])
   tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image;nt.nodes.active=tex
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.bake(type='EMIT')
  pixels=np.empty(1024*1024*4,dtype=np.float32);image.pixels.foreach_get(pixels);pixels[3::4]=1;image.pixels.foreach_set(pixels)
  path=sheet/f'{KEY}_arcade_v2_{group}_color.png';image.filepath_raw=str(path);image.file_format='PNG';image.save();image.pack()
  new_textures.append({'role':group+'_color','file':str(path.relative_to(HOME)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[1024,1024]})
  for m in mats:
   nt=m.node_tree;out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');nt.links.new(saved[m],out.inputs['Surface'])
  baked=mat('v2 '+group,[255,255,255],.12);nt=baked.node_tree;tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image;nt.links.new(tex.outputs['Color'],nt.nodes['Principled BSDF'].inputs['Base Color'])
  for o in objects:
   o.data.materials.clear();o.data.materials.append(baked)
   for poly in o.data.polygons:poly.material_index=0

scene.frame_set(1);bpy.context.view_layer.update()
# Recalculate normals and reject open geometry or base changes before export.
checks=[]
for o in list(parts.values())+extras:
 bm=bmesh.new();bm.from_mesh(o.data);non=sum(not e.is_manifold for e in bm.edges);bm.free();tri=sum(len(p.vertices)-2 for p in o.data.polygons)
 assert non==0 and tri<20000,(o.name,non,tri)
 pts=[o.matrix_world@v.co for v in o.data.vertices];lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)]
 checks.append({'name':o.name,'role':'base' if o in parts.values() else 'accessory','triangles':tri,'nonManifoldEdges':non,'motion':o.get('motion'),'offsetRobloxStuds':[(lo[0]+hi[0])*3,(lo[2]+hi[2])*3+6.62,-(lo[1]+hi[1])*3],'sizeRobloxStuds':[(hi[0]-lo[0])*6,(hi[2]-lo[2])*6,(hi[1]-lo[1])*6]})
assert signatures=={n:signature(o) for n,o in parts.items()}
# Parent motion and placement verified throughout the loop; face stays open.
rest={o.name:o.matrix_world.copy() for o in extras}
for frame in (1,19,37,55,73,91,109,127,145):
 scene.frame_set(frame);bpy.context.view_layer.update()
 for o in extras:
  for v in o.data.vertices:
   q=o.matrix_world@v.co
   assert not(abs(q.x)<.62 and q.y<-.76 and -.60<q.z<.65),(KEY,o.name,'face clearance',frame)
closure=max(abs(o.matrix_world[i][j]-rest[o.name][i][j]) for o in extras for i in range(4) for j in range(4));assert closure<1e-4,closure
scene.frame_set(1)
package=HOME/'package/arcade-v2';package.mkdir(exist_ok=True);preview=HOME/'preview/arcade-v2';preview.mkdir(exist_ok=True)
exports=[]
for label,obs in [('accessories',extras),('complete',list(parts.values())+extras)]:
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];path=package/f'{KEY}-arcade-v2-{label}.fbx'
 bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=6,apply_unit_scale=False,bake_space_transform=True,axis_forward='-Z',axis_up='Y',use_mesh_modifiers=False,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
 before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(path),use_anim=False);made=[o for o in bpy.data.objects if o not in before];meshes=[o for o in made if o.type=='MESH'];assert len(meshes)==len(obs)
 def bounds(objects,scale):
  points=[o.matrix_world@v.co*scale for o in objects for v in o.data.vertices];return [min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]
 error=max(abs(a-b) for a,b in zip(bounds(obs,6),bounds(meshes,1)));assert error<.001,error
 for o in made:bpy.data.objects.remove(o,do_unlink=True)
 exports.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'meshCount':len(obs),'roundTripChecked':True,'roundTripBoundsError':error})
report=json.loads((HOME/'package/arcade-v1-asset-report.json').read_text());report.update(revision='arcade-legendary-v2',status='Rebuilt geometry; integration pending',parts=checks,exports=exports,animation={'loopSeconds':6,'fps':24,'frames':[1,145],'loopClosureError':closure,'faceClearanceSampledFrames':9})
if new_textures:report['textures']=new_textures
(package/'asset-report.json').write_text(json.dumps(report,indent=2)+'\n')
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.cycles.samples=32
cam=scene.camera;cam.data.ortho_scale=3.9
for label,pos,target in [('hero',(-4,-6,2.8),(0,0,.10)),('back',(-4,6,2.8),(0,0,.10))]:
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(preview/f'{KEY}-v2-{label}.png');bpy.ops.render.render(write_still=True)
cam.location=(-4,-6,2.8);cam.rotation_euler=(Vector((0,0,.1))-cam.location).to_track_quat('-Z','Y').to_euler();scene.frame_set(37);scene.render.filepath=str(preview/f'{KEY}-v2-motion.png');bpy.ops.render.render(write_still=True);scene.frame_set(1)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(package/f'{KEY}-arcade-v2.blend'))
print('V2_COMPLETE',KEY,'parts',len(extras),'triangles',sum(x['triangles'] for x in checks if x['role']=='accessory'),flush=True)
