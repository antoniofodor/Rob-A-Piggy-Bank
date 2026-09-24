"""Mecha review revision: continuous upper shell and connected navy forehead.
Preserves the installed v2 assets; exports a separate v3 review package.
"""
from pathlib import Path
import bpy,bmesh,json,math,hashlib,argparse,sys
import numpy as np
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
p=argparse.ArgumentParser();p.add_argument('--skin',required=True);a=p.parse_args(args);KEY=a.skin
HOME=ROOT/'assets/piggies/legendary'/KEY
bpy.ops.wm.open_mainfile(filepath=str(HOME/'package/arcade-v2'/f'{KEY}-arcade-v2.blend'))
scene=bpy.context.scene;scene.name='MECHA v3 - closed crown and connected forehead';scene.frame_set(1)
scene['revision']='arcade-mecha-v3';scene['runtimeStatus']='Review preview, not installed'
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
assert KEY=='mechaplayer'
for ob in list(extras):
 if ob.name.startswith(('MechBrow_','MechShell_')) or ob.name=='MechDorsalSpine':
  extras.remove(ob);bpy.data.objects.remove(ob,do_unlink=True)
steel=next(m for m in bpy.data.materials if m.name=='mechaplayer_v2_Steel')
navy=next(m for m in bpy.data.materials if m.name=='mechaplayer_v2_Navy armor')
# One closed shell continues the side armor through the crown without a cap rim. The pole is
# triangulated once, rather than a collapsed ring which would leave degenerates.
def surface(theta,lat,lift):
 t=math.radians(theta);l=math.radians(lat)
 d=Vector((math.sin(t)*math.cos(l),-math.cos(t)*math.cos(l),math.sin(l)))
 hit,co,norm,_=parts['Body'].ray_cast(d*4,-d)
 if not hit or co.dot(d)<=0:co=d/math.sqrt(d.x*d.x+(d.y/1.08)**2+(d.z/.96)**2)
 return co+d*lift
segments=48;rings=9;vertices=[];faces=[]
# Shared latitude rings keep the crown tessellation even at the face opening.
for row in range(rings):
 lat=50+(89-50)*row/(rings-1)
 for i in range(segments):vertices.append(tuple(surface(i*360/segments,lat,.067)))
vertices.append(tuple(surface(0,90,.067)));pole=len(vertices)-1
for row in range(rings-1):
 for i in range(segments):
  q=row*segments+i;r=row*segments+(i+1)%segments;faces.append((q,r,r+segments,q+segments))
for i in range(segments):faces.append(((rings-1)*segments+i,(rings-1)*segments+(i+1)%segments,pole))
# Extend the same surface down the back and sides, sharing its first crown ring.
columns=list(range(7,42));above=columns[:]
for lat in (39,28,17,6,-5,-16,-27,-38):
 below=[]
 for i in columns:
  below.append(len(vertices));vertices.append(tuple(surface(i*360/segments,lat,.067)))
 for j in range(len(columns)-1):faces.append((below[j],below[j+1],above[j+1],above[j]))
 above=below
cap=mesh('MechContinuousBackArmor',vertices,faces,steel)
# Orient the open skin outward before adding its closed inner wall.
bm=bmesh.new();bm.from_mesh(cap.data);bm.normal_update()
if sum(f.normal.dot(f.calc_center_median()) for f in bm.faces)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
bm.to_mesh(cap.data);bm.free()
bpy.ops.object.select_all(action='DESELECT');cap.select_set(True);bpy.context.view_layer.objects.active=cap
solid=cap.modifiers.new('Closed armor wall','SOLIDIFY');solid.thickness=.081;solid.offset=-1;solid.use_even_offset=True
bpy.ops.object.modifier_apply(modifier=solid.name)
for poly in cap.data.polygons:poly.use_smooth=True
# Replace both separate forehead islands with one continuous stepped plate.
verts=[];nx=20;ny=5
for layer,lift in enumerate((.061,.093)):
 for j in range(ny+1):
  for i in range(nx+1):
   theta=-46+92*i/nx
   lower=49 if abs(theta)<30 else 53
   lat=lower+(73-lower)*j/ny
   verts.append(tuple(surface(theta,lat,lift)))
k=(nx+1)*(ny+1);fs=[]
for layer in (0,1):
 for j in range(ny):
  for i in range(nx):
   q=layer*k+j*(nx+1)+i;fs.append((q,q+1,q+nx+2,q+nx+1))
border=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
for i,q in enumerate(border):r=border[(i+1)%len(border)];fs.append((q,r,r+k,q+k))
forehead=mesh('MechForeheadConnectedPlate',verts,fs,navy)
for poly in forehead.data.polygons:
 if poly.index<2*nx*ny:poly.use_smooth=True
# Fine raised panel seams identify the crown as armor, with steel underneath
# every seam; they cannot reveal the pig's body.
def seam(name,theta):
 points=[surface(theta,lat,.070) for lat in (-28,-16,-4,8,20,32,44,56,68,80,86)]
 vs=[];sides=6
 for i,p in enumerate(points):
  direction=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
  u=direction.cross(p.normalized()).normalized();v=direction.cross(u).normalized()
  for j in range(sides):vs.append(tuple(p+.0045*(math.cos(j*math.tau/sides)*u+math.sin(j*math.tau/sides)*v)))
 fs=[]
 for i in range(len(points)-1):
  for j in range(sides):fs.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
 fs += [tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))]
 return mesh(name,vs,fs,navy)
for theta in (90,180,270):seam('MechCrownSeam_'+str(theta),theta)
# Seat the rear vent on the new continuous shell instead of leaving it buried.
for ob in extras:
 if ob.name=='MechRearVent' or ob.name.startswith('MechRearSignal_'):
  ob.location.y+=.085
new_textures=[]

scene.frame_set(1);bpy.context.view_layer.update()
# Recalculate normals and reject open geometry or base changes before export.
checks=[]
for o in list(parts.values())+extras:
 bm=bmesh.new();bm.from_mesh(o.data);non=sum(not e.is_manifold for e in bm.edges);bm.free();tri=sum(len(p.vertices)-2 for p in o.data.polygons)
 assert non==0 and tri<20000,(o.name,non,tri)
 pts=[o.matrix_world@v.co for v in o.data.vertices];lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)]
 checks.append({'name':o.name,'role':'base' if o in parts.values() else 'accessory','triangles':tri,'nonManifoldEdges':non,'motion':o.get('motion'),'offsetRobloxStuds':[(lo[0]+hi[0])*3,(lo[2]+hi[2])*3+6.62,-(lo[1]+hi[1])*3],'sizeRobloxStuds':[(hi[0]-lo[0])*6,(hi[2]-lo[2])*6,(hi[1]-lo[1])*6]})
assert signatures=={n:signature(o) for n,o in parts.items()}

# Check crown coverage before spending time exporting or rendering.
coverage_rays=0
for theta in range(0,360,5):
 for lat in range(54,90,4):
  t=math.radians(theta);l=math.radians(lat);d=Vector((math.sin(t)*math.cos(l),-math.cos(t)*math.cos(l),math.sin(l)))
  hit,co,*_=cap.ray_cast(d*4,-d);assert hit,(theta,lat,'crown gap')
  bodyhit,bco,*_=parts['Body'].ray_cast(d*4,-d)
  if bodyhit:assert co.dot(d)>bco.dot(d)+.015,(theta,lat,'crown exposes body')
  coverage_rays+=1

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
package=HOME/'package/arcade-v3';package.mkdir(exist_ok=True);preview=HOME/'preview/arcade-v3';preview.mkdir(exist_ok=True)
exports=[]
for label,obs in [('accessories',extras),('complete',list(parts.values())+extras)]:
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];path=package/f'{KEY}-arcade-v3-{label}.fbx'
 bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=6,apply_unit_scale=False,bake_space_transform=True,axis_forward='-Z',axis_up='Y',use_mesh_modifiers=False,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
 before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(path),use_anim=False);made=[o for o in bpy.data.objects if o not in before];meshes=[o for o in made if o.type=='MESH'];assert len(meshes)==len(obs)
 def bounds(objects,scale):
  points=[o.matrix_world@v.co*scale for o in objects for v in o.data.vertices];return [min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]
 error=max(abs(a-b) for a,b in zip(bounds(obs,6),bounds(meshes,1)));assert error<.001,error
 for o in made:bpy.data.objects.remove(o,do_unlink=True)
 exports.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'meshCount':len(obs),'roundTripChecked':True,'roundTripBoundsError':error})
report=json.loads((HOME/'package/arcade-v2/asset-report.json').read_text());report.update(revision='arcade-mecha-v3',status='Review preview; not installed in game',parts=checks,exports=exports,animation={'loopSeconds':6,'fps':24,'frames':[1,145],'loopClosureError':closure,'faceClearanceSampledFrames':9})
report['runtimeNotes']='Mecha v3 review only. Continuous closed crown/back armor and one connected navy forehead plate. V2 remains installed in the game.'
if new_textures:report['textures']=new_textures
(package/'asset-report.json').write_text(json.dumps(report,indent=2)+'\n')
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.cycles.samples=24
cam=scene.camera;cam.data.ortho_scale=3.9
for label,pos,target in [('hero',(-4,-6,2.8),(0,0,.10)),('back',(-4,6,2.8),(0,0,.10)),('top',(-2,3,7),(0,0,.15))]:
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(preview/f'{KEY}-v3-{label}.png');bpy.ops.render.render(write_still=True)
cam.location=(-4,-6,2.8);cam.rotation_euler=(Vector((0,0,.1))-cam.location).to_track_quat('-Z','Y').to_euler();scene.frame_set(37);scene.render.filepath=str(preview/f'{KEY}-v3-motion.png');bpy.ops.render.render(write_still=True);scene.frame_set(1)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(package/f'{KEY}-arcade-v3.blend'))
print('V3_COMPLETE',KEY,'parts',len(extras),'triangles',sum(x['triangles'] for x in checks if x['role']=='accessory'),flush=True)
