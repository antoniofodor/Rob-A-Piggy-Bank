"""Build a compact, editable Acorn for the yard basket. No game files modified.
Run Blender -b -t 4 --python blender/acorn/build_acorn.py.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/acorn'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.unit_settings.system='NONE'
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=700;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.view_settings.view_transform='AgX'
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.24,.29,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
# Approved green/chestnut palette: olive #91A747, yellow-green #B4C56B,
# chestnut #795333, dark stem #513A26, with supporting facet shadows.
palette=[(109,128,48),(129,149,60),(145,167,71),(180,197,107),
         (81,53,31),(103,68,40),(121,83,51),(145,104,66),
         (65,45,28),(81,58,38),(100,73,47),(121,91,61)]
img=bpy.data.images.new('Acorn_BaseColor',width=64,height=64,alpha=True)
pixels=[]
for y in range(64):
 for x in range(64):
  rgb=palette[((y//16)*4+x//16)%len(palette)]
  pixels.extend([*(c/255 for c in rgb),1])
img.pixels.foreach_set(pixels);img.filepath_raw=str(OUT/'acorn-basecolor.png');img.file_format='PNG';img.save();img.pack()
mat=bpy.data.materials.new('Acorn_BaseColor');mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.88
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img;tex.interpolation='Closest'
mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
objects=[]
def mesh(name,vs,fs,tiles):
 m=bpy.data.meshes.new(name);m.from_pydata(vs,[],fs);m.update()
 o=bpy.data.objects.new(name,m);scene.collection.objects.link(o);m.materials.append(mat)
 uv=m.uv_layers.new(name='Palette')
 for p in m.polygons:
  tile=tiles[p.index%len(tiles)]
  for li in p.loop_indices:uv.data[li].uv=((tile%4+.5)/4,(tile//4+.5)/4)
 objects.append(o);return o

def lathe(name,rings,n,tiles,lean=0):
 vs=[];fs=[]
 for j,(z,r) in enumerate(rings):
  for i in range(n):
   a=2*math.pi*i/n
   vs.append((r*math.cos(a)+lean*(z-rings[0][0]),r*math.sin(a),z))
 for j in range(len(rings)-1):
  for i in range(n):
   a=j*n+i;b=j*n+(i+1)%n;c=(j+1)*n+(i+1)%n;d=(j+1)*n+i
   fs.append((a,b,c,d))
 fs.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+i for i in range(n))])
 return mesh(name,vs,fs,tiles)

nut=lathe('Nut',[(0,.035),(.025,.12),(.075,.19),(.14,.233),(.23,.246),(.32,.244),(.44,.233),(.515,.216),(.55,.17)],20,[1,2,2,2,3,2,1,2,2,2])
cap=lathe('Cap',[(.461,.219),(.469,.262),(.484,.292),(.51,.297),(.537,.289),(.592,.269),(.648,.226),(.693,.16),(.721,.081),(.728,.024)],16,[5,6,5,6,7,6,5,6])
# Raised scales with recessed shared seams and bevelled shoulders. All
# boundaries remain connected to the cap, so depth reads without loose spikes.
old=cap.data
vs=[tuple(v.co) for v in old.vertices];fs=[];tiles=[]
for poly in old.polygons:
 indices=list(poly.vertices)
 center=sum((Vector(vs[i]) for i in indices),Vector())/len(indices)
 if len(indices)!=4 or center.z<.538:
  fs.append(tuple(indices));tiles.append(5 if center.z<.49 else 6);continue
 normal=poly.normal.normalized()
 inset=[]
 for index in indices:
  inset.append(len(vs));vs.append(tuple(center+(Vector(vs[index])-center)*.68+normal*.016))
 ci=len(vs);vs.append(tuple(center+normal*.031))
 for j in range(4):
  nxt=(j+1)%4
  fs.append((indices[j],indices[nxt],inset[nxt],inset[j]));tiles.append([5,5,4,6][j])
  fs.append((inset[j],inset[nxt],ci));tiles.append([7,6,5,6][j])
objects.remove(cap);bpy.data.objects.remove(cap,do_unlink=True)
cap=mesh('Cap',vs,fs,tiles)
stem=lathe('Stem',[(.712,.034),(.747,.033),(.787,.026),(.827,.018)],7,[8,9,10,9,8,9,10],.42)
# Mesh origins stay at the shared bottom pivot; GLB axes are Y-up.
for obj in objects:
 obj.data.calc_loop_triangles()
 obj['part_role']=obj.name
 obj['units']='Roblox studs when imported at scale 1'
# Reuse the project's tested static exporter; avoids the installed NumPy mismatch.
sys.path.insert(0,str(ROOT/'blender/tree'))
from export_glb import export_glb
export_glb(objects,OUT/'acorn-basecolor.png',OUT/'acorn.glb')
# Relabel exporter metadata without modifying the shared exporter or binary buffers.
import struct
p=OUT/'acorn.glb';raw=p.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length]);doc['asset']['generator']='Blender Acorn static mesh exporter'
doc['materials'][0]['name']='Acorn_BaseColor';doc['images'][0]['name']='Acorn_BaseColor'
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
binchunk=raw[20+length:];p.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(js)+len(binchunk))+struct.pack('<I4s',len(js),b'JSON')+js+binchunk)
coords=[v.co for o in objects for v in o.data.vertices]
mins=[min(v[i] for v in coords) for i in range(3)];maxs=[max(v[i] for v in coords) for i in range(3)]
report={'triangles':{o.name:len(o.data.loop_triangles) for o in objects},'total_triangles':sum(len(o.data.loop_triangles) for o in objects),'roblox_size':[maxs[0]-mins[0],maxs[2]-mins[2],maxs[1]-mins[1]],'pivot':'rounded nut bottom at ground; shared origin','texture':'64x64 embedded base color only','glb_bytes':p.stat().st_size}
(OUT/'acorn-report.json').write_text(json.dumps(report,indent=2)+'\n')
# Presentation objects are excluded from GLB and grouped in the blend.
stage=bpy.data.collections.new('Presentation (not exported)');scene.collection.children.link(stage)
def to_stage(obj):
 for c in list(obj.users_collection):c.objects.unlink(obj)
 stage.objects.link(obj)
def point(obj,at):obj.rotation_euler=(Vector(at)-obj.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.008));ground=bpy.context.object;ground.name='Backdrop';to_stage(ground)
gmat=bpy.data.materials.new('Backdrop');gmat.diffuse_color=(.12,.16,.18,1);ground.data.materials.append(gmat)
for name,loc,power,size in [('Key',(-2,-3,4),180,2.5),('Fill',(3,-1,2),80,2),('Rim',(0,2,3),130,2)]:
 light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size
 obj=bpy.data.objects.new(name,light);stage.objects.link(obj);obj.location=loc;point(obj,(0,0,.4))
camdata=bpy.data.cameras.new('Camera');camera=bpy.data.objects.new('Camera',camdata);stage.objects.link(camera);scene.camera=camera
camdata.type='ORTHO';camdata.ortho_scale=1.18
camera.location=(1.5,-2.4,1.4);point(camera,(0,0,.405))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'acorn.blend'))
for name,loc in [('three-quarter',(1.5,-2.4,1.4))]:
 camera.location=loc;point(camera,(0,0,.405));scene.render.filepath=str(OUT/f'acorn-{name}.png');bpy.ops.render.render(write_still=True)
camera.location=(1.5,-2.4,1.4);point(camera,(0,0,.405))
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=nut
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_distance=1.8;area.spaces.active.region_3d.view_location=(0,0,.4)
   area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'acorn.blend'))
print('ACORN_REPORT '+json.dumps(report))
