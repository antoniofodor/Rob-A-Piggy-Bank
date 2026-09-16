"""Build the approved oak concept as editable, textured Blender geometry.
Run: Blender -b -t 4 --python blender/tree/build_oak.py
Outputs stay separate from the previously uploaded Studio asset.
"""
import bpy
import math
import random
import json
import os
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/tree/blender'
OUT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(218)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for d in list(bpy.data.materials): bpy.data.materials.remove(d)
scene = bpy.context.scene
scene.unit_settings.system = 'NONE'
scene.render.engine = 'CYCLES'
scene.cycles.samples = 40
scene.cycles.use_denoising = True
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'AgX'
scene.world.color = (0.28, 0.28, 0.28)

# A single base-colour atlas, no normal/roughness maps. A face occupies one
# solid tile so the exported texture retains the authored faceted palette.
wood = [(112,59,30),(129,68,33),(145,77,37),(160,87,42),(174,96,46),(188,109,55),(202,122,64),(217,141,78)]
leaves = [(42,83,31),(48,95,32),(54,106,33),(61,119,35),(72,133,39),(86,147,44),(106,164,51),(131,182,62),
          (152,195,73),(167,205,86),(70,121,37),(89,146,45),(104,157,47),(120,173,56),(140,187,65),(158,197,73)]
colours = wood + leaves
image = bpy.data.images.new('Oak_BaseColor',width=256,height=256,alpha=True)
# The base-colour image stores the authored sRGB swatches directly.
pixels=[]
for y in range(256):
    for x in range(256):
        tile=(y//32)*8+x//32
        rgb=colours[tile%len(colours)]
        pixels.extend([*(c/255 for c in rgb),1])
image.pixels.foreach_set(pixels)
image.filepath_raw=str(OUT/'oak-basecolor.png')
image.file_format='PNG'
image.save()
image.pack()
mat=bpy.data.materials.new('Oak_BaseColor')
mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value=.87
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest'
mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])

def mesh_obj(name,verts,faces):
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
    o=bpy.data.objects.new(name,m);scene.collection.objects.link(o);return o

wood_objects=[]
def branch(name, points, sides=12, ridge=.09):
    verts=[];faces=[]
    for j,(x,y,z,r) in enumerate(points):
        p=Vector((x,y,z))
        prev=Vector(points[max(0,j-1)][:3]);nxt=Vector(points[min(len(points)-1,j+1)][:3])
        tangent=(nxt-prev).normalized()
        helper=Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0))
        u=tangent.cross(helper).normalized();v=tangent.cross(u).normalized()
        for i in range(sides):
            a=i*2*math.pi/sides
            rr=r*(1+ridge*math.cos(5*a+.25*j)+.035*math.sin(3*a+.8*j))
            q=p+rr*(u*math.cos(a)+v*math.sin(a))
            verts.append(tuple(q))
    for j in range(len(points)-1):
        for i in range(sides):
            a=j*sides+i;b=j*sides+(i+1)%sides;c=(j+1)*sides+(i+1)%sides;d=(j+1)*sides+i
            faces.append((a,b,c,d))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(points)-1)*sides+i for i in range(sides)))
    o=mesh_obj(name,verts,faces);wood_objects.append(o);return o

# The trunk is a leaning, twisting fork with broad buttresses, not a cylinder.
branch('Main',[(0,0,.24,1.12),(.04,.03,.8,.96),(.13,.04,1.6,.81),(.06,.05,2.7,.73),
              (-.12,.04,3.8,.66),(-.3,.08,4.8,.54),(-.65,.12,5.85,.43),(-.8,.22,6.95,.30),
              (-.35,.3,8.1,.20),(-.2,.35,9.8,.045)],16,.16)
branch('RightFork',[(-.10,.08,3.55,.57),(.48,.12,4.6,.43),(1.32,.18,5.45,.32),(2.1,.16,5.8,.24),
                    (3.03,.22,6.48,.16),(3.7,.32,7.3,.04)],12,.13)
branch('LeftFork',[(-.05,0,2.7,.58),(-.8,-.03,3.95,.40),(-1.85,-.05,4.55,.31),(-2.8,.03,4.8,.19),
                   (-3.48,.08,5.65,.10),(-3.75,.14,6.9,.025)],12,.12)
branch('UpperLeft',[(-.5,.15,5.3,.35),(-1.2,.2,6.45,.28),(-1.9,.25,7.15,.19),(-2.6,.35,8.25,.035)],10,.10)
branch('UpperRight',[(-.68,.2,6.4,.29),(.12,.38,7.15,.23),(1.2,.55,7.8,.18),(2.15,.5,8.8,.025)],10,.1)
branch('LowRight',[(.18,.1,2.6,.43),(.9,-.1,3.8,.30),(1.9,-.24,4.42,.23),(2.85,-.2,4.68,.16),(3.65,-.1,5.5,.03)],10,.13)
branch('BackFork',[(0,.23,3.2,.43),(.2,1.1,4.8,.32),(-.35,1.9,6.0,.22),(-1.0,2.4,7.1,.04)],10,.1)
branch('BackRight',[(.1,.3,4,.35),(1.1,1.35,5.6,.26),(2.05,1.9,6.95,.045)],10,.1)
branch('LeftTwig',[(-2.05,.01,4.55,.18),(-2.3,-.52,5.35,.12),(-2.7,-.72,6.2,.025)],8,.07)
branch('RightTwig',[(2.0,.15,5.7,.18),(2.2,-.5,6.7,.10),(2.65,-.65,7.45,.025)],8,.07)
# Six compact spreading roots disappear cleanly into the trunk.
for i,(a,length) in enumerate([(-2.9,1.75),(-1.85,1.9),(-.7,1.7),(.30,1.7),(1.35,1.65),(2.25,1.6)]):
    dx,dy=math.cos(a),math.sin(a)
    branch('Root'+str(i),[(.3*dx,.3*dy,1.55,.46),(.65*dx,.65*dy,.75,.47),
                         (1.1*dx,1.1*dy,.31,.34),(length*dx,length*dy,.14,.17),
                         ((length+.2)*dx,(length+.2)*dy,.09,.025)],10,.11)
# Short cut branch on the exposed lower trunk provides one clear bark detail.
branch('Knot',[(.15,-.47,2.65,.25),(.15,-.83,2.85,.23),(.15,-.92,2.95,.18)],10,.08)

bpy.ops.object.select_all(action='DESELECT')
for o in wood_objects:o.select_set(True)
bpy.context.view_layer.objects.active=wood_objects[0]
bpy.ops.object.join();trunk=bpy.context.object;trunk.name='Trunk'
# Fuse branch junctions into one continuous editable wood surface.
remesh=trunk.modifiers.new('Joined branching','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.085;remesh.use_smooth_shade=False
bpy.ops.object.modifier_apply(modifier=remesh.name)
smooth=trunk.modifiers.new('Gentle junction smoothing','SMOOTH');smooth.factor=.45;smooth.iterations=2
bpy.ops.object.modifier_apply(modifier=smooth.name)
trunk.data.calc_loop_triangles()
dec=trunk.modifiers.new('Faceted wood budget','DECIMATE');dec.ratio=min(1,2400/len(trunk.data.loop_triangles))
bpy.ops.object.modifier_apply(modifier=dec.name)

# Distinct irregular crowns and hanging scallops leave visible forks between
# the masses. Real depth on all sides, no billboard leaf cards.
foliage=[]
def lobe(name, center, radii, seed, subdivision=3, droop=0):
    rng=random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivision,radius=1,location=center)
    o=bpy.context.object;o.name=name
    for vert in o.data.vertices:
        q=vert.co.copy()
        a=math.atan2(q.y,q.x)
        warp=1+.07*math.sin(a*5+seed)+.05*math.cos(a*3+q.z*4+seed*.5)+rng.uniform(-.055,.055)
        vert.co=(q.x*radii[0]*warp,q.y*radii[1]*warp,q.z*radii[2]*warp-droop*max(0,-q.z)**2)
    foliage.append(o);return o
crowns=[
 ((.0,.38,9.35),(1.72,1.52,1.48),11),
 ((-2.00,.22,8.10),(1.75,1.50,1.25),21),
 ((2.15,.40,8.22),(1.82,1.55,1.28),31),
 ((-3.24,-.05,6.32),(1.63,1.43,1.29),41),
 ((3.27,.05,6.32),(1.62,1.41,1.28),51),
 ((-1.40,-.60,7.30),(1.22,1.04,1.02),61),
 ((1.85,-.80,7.05),(1.28,1.05,1.10),71),
 ((-.8,1.96,7.00),(1.8,1.50,1.30),81),
 ((1.75,1.73,6.75),(1.64,1.34,1.22),91),
 ((.48,1.78,8.75),(1.64,1.38,1.28),101),
]
for idx,(center,radii,seed) in enumerate(crowns):
    lobe('Crown_%02d'%idx,center,radii,seed)
    # Chunky, pointed leaf masses form an irregular scalloped skirt. Their
    # surfaces are closed volumes, not thin leaf cards or little spheres.
    for j in range(10):
        ring=0 if j<6 else 1
        count=6 if ring==0 else 4
        a=2*math.pi*(j if ring==0 else j-6)/count+seed*.35+.24*math.sin(j*2+seed)
        radial=.71 if ring==0 else .58
        c=Vector((center[0]+math.cos(a)*radii[0]*radial,
                  center[1]+math.sin(a)*radii[1]*radial,
                  center[2]+(-.26 if ring==0 else .26)*radii[2]+.10*math.sin(a*3)))
        rx=radii[0]*(.40 if ring==0 else .36)
        ry=radii[1]*.40
        rz=radii[2]*(.72 if ring==0 else .60)
        verts=[(0,0,.65)]
        for level,wide,deep in ((.27,.84,.60),(-.30,.72,.48)):
            for k in range(8):
                angle=2*math.pi*k/8
                verts.append((math.cos(angle)*wide,math.sin(angle)*deep,level+.05*math.sin(angle*3)))
        verts.append((.09*math.sin(seed+j),.06,-1.0))
        faces=[]
        for k in range(8):
            nxt=(k+1)%8
            faces.extend([(0,1+k,1+nxt),(1+k,9+k,9+nxt),(1+k,9+nxt,1+nxt),(17,9+nxt,9+k)])
        out=[]
        for x,y,z in verts:
            # Width lies tangent to the crown, depth points outwards.
            q=Vector((-math.sin(a)*x*rx+math.cos(a)*y*ry,
                       math.cos(a)*x*rx+math.sin(a)*y*ry,z*rz))
            out.append(tuple(c+q))
        leaf=mesh_obj('LeafMass',out,faces)
        foliage.append(leaf)

bpy.ops.object.select_all(action='DESELECT')
for o in foliage:o.select_set(True)
bpy.context.view_layer.objects.active=foliage[0]
bpy.ops.object.join();canopy=bpy.context.object;canopy.name='Canopy'
# Bake object locations, normalize width to the actual 8.5-stud compact lawn budget,
# and keep both object origins at the same trunk-ground contact.
for o in (trunk,canopy):
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
xs=[v.co.x for v in canopy.data.vertices]
scale=8.5/(max(xs)-min(xs))
minimum=min(v.co.z for v in trunk.data.vertices)
for o in (trunk,canopy):
    for v in o.data.vertices:
        v.co=Vector((v.co.x*scale,v.co.y*scale,(v.co.z-minimum)*scale))
    o.data.update()
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    o.data.materials.clear();o.data.materials.append(mat)
    for f in o.data.polygons:f.use_smooth=False
    while o.data.uv_layers: o.data.uv_layers.remove(o.data.uv_layers[0])
    uv=o.data.uv_layers.new(name='OakUV');uv.active_render=True
    rng=random.Random(338 if o==trunk else 554)
    for face in o.data.polygons:
        if o==trunk:
            # Coherent longitudinal bark facets, rather than random confetti.
            a=math.atan2(face.center.y,face.center.x)
            shade=3+1.1*math.cos(a+1)+.7*math.sin(a*5+face.center.z*.2)
            shade+=.35*rng.uniform(-1,1)
            tile=max(0,min(7,round(shade)))
        else:
            # Upward facets read fresh green; undersides remain forest green.
            light=max(-1,min(1,.75*face.normal.z-.35*face.normal.x-.25*face.normal.y))
            shade=round(4+4*light+rng.uniform(-.6,.6))
            tile=8+max(0,min(9,shade))
        tx,ty=tile%8,tile//8
        for li in face.loop_indices:
            # Small UV island inside its swatch; preserves real UV area.
            corner=face.loop_indices[:].index(li)
            angle=corner*2*math.pi/len(face.loop_indices)
            uv.data[li].uv=((tx+.5+.22*math.cos(angle))/8,(ty+.5+.22*math.sin(angle))/8)
    o['reference']='assets/tree/tree-oak-render-v2.png'
    o['role']='wood' if o==trunk else 'foliage; animate separately'

# A reference board is available in the saved Blender file, hidden in renders.
reference=bpy.data.images.load(str(ROOT/'assets/tree/tree-oak-render-v2.png'))
reference.pack()
bpy.ops.object.empty_add(type='IMAGE',location=(0,3,5.5),rotation=(math.pi/2,0,0))
ref=bpy.context.object;ref.name='Approved reference (guide only)';ref.data=reference;ref.empty_display_size=12;ref.hide_render=True;ref.hide_set(True)

# Neutral studio lighting, no ground in the exported tree.
def area(name,location,energy,size,target=(0,0,5)):
    bpy.ops.object.light_add(type='AREA',location=location)
    o=bpy.context.object;o.name=name;o.data.energy=energy;o.data.shape='DISK';o.data.size=size
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
area('Key',(-7,-10,16),1800,8)
area('Fill',(8,-4,10),900,9)
area('Rim',(1,8,15),1400,7)
bpy.ops.object.camera_add(location=(13,-22,13))
camera=bpy.context.object;camera.name='Oak preview camera';camera.data.type='ORTHO';camera.data.ortho_scale=12.2;scene.camera=camera

# Export only the two mesh objects. glTF converts Blender Z-up to Y-up.
bpy.ops.object.select_all(action='DESELECT')
for o in (trunk,canopy):o.select_set(True)
bpy.context.view_layer.objects.active=trunk
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from export_glb import export_glb
export_glb((trunk,canopy),OUT/'oak-basecolor.png',OUT/'oak.glb')
stats={
 'reference':'../tree-oak-render-v2.png',
 'method':'Blender geometry authored against the approved image, not automatic image-to-3D reconstruction',
 'units':'1 Blender unit = 1 intended Roblox stud; GLB is Y-up',
 'parts':{},'installedInStudio':False,
}
for o in (trunk,canopy):
    o.data.calc_loop_triangles()
    coords=[v.co for v in o.data.vertices]
    mn=[min(v[i] for v in coords) for i in range(3)];mx=[max(v[i] for v in coords) for i in range(3)]
    stats['parts'][o.name]={'triangles':len(o.data.loop_triangles),'vertices':len(o.data.vertices),
                          'boundsBlender':{'min':mn,'max':mx},
                          'sizeRoblox':[mx[0]-mn[0],mx[2]-mn[2],mx[1]-mn[1]],
                          'offsetRoblox':[(mx[0]+mn[0])/2,(mx[2]+mn[2])/2,-(mx[1]+mn[1])/2]}
    assert len(o.data.loop_triangles)<10000,(o.name,len(o.data.loop_triangles))
(OUT/'oak-report.json').write_text(json.dumps(stats,indent=2)+'\n')
# Save editable source before rendering, so previews are independently recoverable.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'oak.blend'))
# Four reproducible views of the actual mesh, used for acceptance and handoff.
for label,location in [('three-quarter',(12,-23,12)),('front',(0,-26,9)),('side',(26,0,9)),('rear',(0,26,9))]:
    if os.environ.get('OAK_PREVIEW_ONLY') and label!='three-quarter': continue
    camera.location=location
    camera.rotation_euler=(Vector((0,0,4.5))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/('oak-'+label+'.png'))
    bpy.ops.render.render(write_still=True)
camera.location=(12,-23,12);camera.rotation_euler=(Vector((0,0,4.5))-camera.location).to_track_quat('-Z','Y').to_euler()
# A neutral 5.5-stud block character shows scale without inventing gameplay.
if not os.environ.get('OAK_PREVIEW_ONLY'):
    guide=[]
    guideMat=bpy.data.materials.new('Scale guide grey');guideMat.diffuse_color=(.48,.53,.58,1)
    def block(name,location,size):
        bpy.ops.mesh.primitive_cube_add(size=1,location=location)
        o=bpy.context.object;o.name=name;o.dimensions=size
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        o.data.materials.append(guideMat);guide.append(o)
        bevel=o.modifiers.new('Soft edges','BEVEL');bevel.width=.06;bevel.segments=1
    block('Guide torso',(5.4,0,3),(1.8,.9,2))
    block('Guide head',(5.4,0,4.75),(1.4,1.3,1.5))
    for sign in (-1,1):
        block('Guide leg',(5.4+sign*.46,0,1),(.82,.85,2))
        block('Guide arm',(5.4+sign*1.2,0,3.1),(.55,.65,1.8))
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025))
    ground=bpy.context.object;ground.name='Preview ground (not exported)'
    groundMat=bpy.data.materials.new('Preview ground');groundMat.diffuse_color=(.22,.27,.22,1);ground.data.materials.append(groundMat)
    camera.location=(2,-27,10)
    camera.rotation_euler=(Vector((1.5,0,4.2))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=14.8
    scene.render.filepath=str(OUT/'oak-scale.png')
    bpy.ops.render.render(write_still=True)
    for o in guide+[ground]:bpy.data.objects.remove(o,do_unlink=True)
    camera.data.ortho_scale=12.2
    camera.location=(12,-23,12);camera.rotation_euler=(Vector((0,0,4.5))-camera.location).to_track_quat('-Z','Y').to_euler()
# Open into a useful material-coloured overview, with the tree selected.
bpy.ops.object.select_all(action='DESELECT')
for o in (trunk,canopy):o.select_set(True)
bpy.context.view_layer.objects.active=trunk
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_distance=17
            a.spaces.active.region_3d.view_location=(0,0,4.5)
            a.spaces.active.region_3d.view_perspective='CAMERA'
            a.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'oak.blend'))
print('OAK_RESULT '+json.dumps(stats))
