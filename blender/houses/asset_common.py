"""Offline house asset helpers. Coordinates X across, Y inward, Z up."""
import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
class Asset:
 def __init__(self,slug,palette):
  self.slug=slug;self.out=ROOT/'assets/houses/models'/f'{slug}-v1';self.out.mkdir(parents=True,exist_ok=True)
  bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
  self.scene=bpy.context.scene;self.scene.unit_settings.system='NONE';self.scene.render.engine='CYCLES';self.scene.cycles.samples=24;self.scene.cycles.use_denoising=True
  self.scene.render.resolution_x=1200;self.scene.render.resolution_y=1000;self.scene.render.resolution_percentage=100;self.scene.render.image_settings.file_format='PNG';self.scene.view_settings.view_transform='AgX'
  self.scene.world.use_nodes=True;self.scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.74,.79,.86,1);self.scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
  self.visual=[];self.cutaway=[];self.colliders=[];self.mounts={};self.routes=[];self.palette=palette;self.mat={}
  for name,rgb in palette.items():
   m=bpy.data.materials.new(name);m.use_nodes=True
   c=[v/255 for v in rgb];c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
   m.diffuse_color=tuple(c)+(1,);n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=m.diffuse_color;n.inputs['Roughness'].default_value=.78;self.mat[name]=m
 def keep(self,o,name,mat):o.name=name;o.data.materials.append(self.mat[mat]);self.visual.append(o);return o
 def cube(self,name,p,size,mat,rot=0,solid=False):
  bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.dimensions=size;o.rotation_euler.z=rot;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);self.keep(o,name,mat)
  if solid:self.collider(name,p,size,rot)
  return o
 def collider(self,name,p,size,rot=0):self.colliders.append({'name':name,'blenderLocation':list(p),'sizeXYZ':list(size),'rotationZ':rot})
 def sphere(self,name,p,scale,mat,ico=False):
  if ico:bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=p)
  else:bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=p)
  o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return self.keep(o,name,mat)
 def cylinder(self,name,p,r,d,mat,n=16,normal=(0,0,1)):
  bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=d,location=p);o=bpy.context.object;o.rotation_euler=Vector(normal).to_track_quat('Z','Y').to_euler();return self.keep(o,name,mat)
 def beam(self,name,p,q,r,mat):
  p=Vector(p);q=Vector(q);return self.cylinder(name,(p+q)/2,r,(q-p).length,mat,8,q-p)
 def mesh(self,name,vs,fs,mat):
  m=bpy.data.meshes.new(name);m.from_pydata(vs,[],fs);m.update();bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(m);bm.free()
  o=bpy.data.objects.new(name,m);self.scene.collection.objects.link(o);return self.keep(o,name,mat)
 def cut(self,o,cutter):
  bpy.context.view_layer.objects.active=o;m=o.modifiers.new('Opening','BOOLEAN');m.object=cutter;m.operation='DIFFERENCE';m.solver='EXACT';bpy.ops.object.modifier_apply(modifier=m.name);self.visual.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
 def arch(self,name,p,width,spring,depth,bottom,mat):
  r=width/2;path=[(-r,bottom),(r,bottom),(r,spring)]+[(r*math.cos(i*math.pi/12),spring+r*math.sin(i*math.pi/12)) for i in range(1,13)]
  n=len(path);vs=[(p[0]+x,p[1]+y,z) for y in (-depth/2,depth/2) for x,z in path];fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
  return self.mesh(name,vs,fs,mat)
 def window(self,wall,p,r,n,frame,glass):
  first=len(self.visual)
  self.cut(wall,self.cylinder('CutWindow',p,r,2,'Wall',24,n));self.cylinder(wall.name+'_Pane',p,r*.96,.13,glass,24,n)
  for side in (-1,1):
   bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=6,major_radius=r+.11,minor_radius=.17,location=Vector(p)+Vector(n)*.53)
   o=bpy.context.object;o.location=Vector(p)+Vector(n)*side*.53;o.rotation_euler=Vector(n).to_track_quat('Z','Y').to_euler();self.keep(o,wall.name+'_WindowFrame',frame)
  tangent=Vector((-n[1],n[0],0));center=Vector(p)+Vector(n)*.56
  self.beam('WindowMullionH',center-tangent*r,center+tangent*r,.09,frame);self.beam('WindowMullionV',center-Vector((0,0,r)),center+Vector((0,0,r)),.09,frame)
  if wall in self.cutaway:self.cutaway.extend(self.visual[first:])
 def open_door(self,width,spring,floor,mat,frame):
  trim=self.arch('DoorFrame',(0,-.5),width+.6,spring,.32,floor-.04,frame);self.cut(trim,self.arch('FrameCut',(0,-.5),width,spring,1,floor-.2,frame));self.cutaway.append(trim)
  o=self.arch('Door_Open',(0,0),width-.15,spring,.28,floor,mat)
  for v in o.data.vertices:v.co.x+=width/2
  o.location=(-width/2,-.8,0);o.rotation_euler.z=math.radians(-102);self.cutaway.append(o)
  return o
 def mount(self,name,p):
  self.mounts[name]=list(p);o=bpy.data.objects.new(name,None);self.scene.collection.objects.link(o);o.location=p;o.empty_display_type='ARROWS';o.empty_display_size=.45
 def merge_static(self,name,predicate):
  # One exported object per flat material, retaining transform-independent geometry.
  groups={}
  for o in self.visual:
   if predicate(o):groups.setdefault(o.data.materials[0].name,[]).append(o)
  for mat,items in groups.items():
   if len(items)<2:continue
   bpy.ops.object.select_all(action='DESELECT')
   for o in items:o.select_set(True)
   bpy.context.view_layer.objects.active=items[0];bpy.ops.object.join();joined=bpy.context.object;joined.name=name+'_'+mat
   self.visual=[o for o in self.visual if o not in items]+[joined]
 def shelves(self,center,floor,mat,trim):
  x,y=center
  for z in (floor+2.5,floor+4.7):self.cube('DisplayShelf',(x,y,z),(4.4,1.35,.22),mat)
  for dx in (-1.95,1.95):self.cube('ShelfSupport',(x+dx,y+.2,floor+3.4),(.2,.55,4.8),trim)
  for i,(dx,z) in enumerate([(-1,floor+2.62),(1,floor+2.62),(-1,floor+4.82),(1,floor+4.82)],1):self.mount('Shelf_'+str(i),(x+dx,y,z))
 def finish(self,camera,interior,look,scale,meta):
  bpy.context.view_layer.update();stats=[];coords=[]
  for o in self.visual:
   o.data.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(o.data);stats.append({'name':o.name,'triangles':len(o.data.loop_triangles),'nonManifoldEdges':sum(not e.is_manifold for e in bm.edges),'material':o.data.materials[0].name});bm.free();coords.extend(o.matrix_world@v.co for v in o.data.vertices)
  lo=[min(v[i] for v in coords) for i in range(3)];hi=[max(v[i] for v in coords) for i in range(3)]
  report={'id':self.slug,'status':'offline physical prototype; Studio import, camera and playtest pending','paletteRGB':self.palette,'visualObjectCount':len(self.visual),'totalTriangles':sum(m['triangles'] for m in stats),'meshes':stats,'boundsBlender':{'min':lo,'max':hi,'size':[hi[i]-lo[i] for i in range(3)]},'collisionBoxes':self.colliders,'mountsBlender':self.mounts,'routesBlender':self.routes,'coordinateMapping':'Blender (x,y,z) -> Roblox/export (-x,z,y)',**meta}
  assert not [m for m in stats if m['nonManifoldEdges'] or m['triangles']>20000],stats
  assert hi[0]-lo[0]<=60 and hi[1]-lo[1]<=57,(lo,hi)
  bpy.ops.object.select_all(action='DESELECT')
  for o in self.visual:
   o.select_set(True);bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('ExportTriangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.ops.wm.obj_export(filepath=str(self.out/f'{self.slug}-visual.obj'),export_selected_objects=True,forward_axis='Z',up_axis='Y',export_materials=True)
  bpy.ops.export_scene.fbx(filepath=str(self.out/f'{self.slug}-visual.fbx'),use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_UNITS',axis_forward='Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
  reviewmat=bpy.data.materials.new('REVIEW_Backdrop');reviewmat.diffuse_color=(.7,.66,.59,1)
  bpy.ops.mesh.primitive_plane_add(size=250,location=(0,0,-.16));o=bpy.context.object;o.name='REVIEW_Ground';o.data.materials.append(reviewmat)
  for name,p,power,size in [('Key',(-25,-30,45),9000,25),('Fill',(30,-10,32),6000,22),('Rim',(5,32,42),10000,20)]:
   d=bpy.data.lights.new('REVIEW_'+name,'AREA');o=bpy.data.objects.new('REVIEW_'+name,d);self.scene.collection.objects.link(o);o.location=p;d.energy=power;d.shape='DISK';d.size=size;o.rotation_euler=(Vector(look)-o.location).to_track_quat('-Z','Y').to_euler()
  d=bpy.data.cameras.new('REVIEW_Camera');cam=bpy.data.objects.new('REVIEW_Camera',d);self.scene.collection.objects.link(cam);self.scene.camera=cam;d.type='ORTHO';d.ortho_scale=scale
  def render(file,loc,target):
   cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();self.scene.render.filepath=str(self.out/file);bpy.ops.render.render(write_still=True)
  render('exterior.png',camera,look);render('front.png',(look[0],look[1]-60,look[2]+10),look)
  for o in self.cutaway:o.hide_render=True
  render('interior.png',interior,look)
  for o in self.cutaway:o.hide_render=False
  # Save the source on its normal exterior view, not the temporary cutaway.
  cam.location=camera;cam.rotation_euler=(Vector(look)-cam.location).to_track_quat('-Z','Y').to_euler()
  bpy.ops.wm.save_as_mainfile(filepath=str(self.out/f'{self.slug}.blend'))
  (self.out/'geometry-report.json').write_text(json.dumps(report,indent=2));print('ASSET_REPORT '+json.dumps({k:report[k] for k in ('id','visualObjectCount','totalTriangles','boundsBlender')}))
