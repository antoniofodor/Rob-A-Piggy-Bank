"""Rainbow Tiger piggy silhouette, approved option C swept charcoal accents.

Blender -b -t 4 --python-exit-code 1 --python this_file.py -- [--draft]
Works on copies of the shared pig. No source overwrite or runtime installation.
"""
from pathlib import Path
import bpy,bmesh,math,json,hashlib,sys
from mathutils import Vector,Quaternion
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform,tessellate_polygon

ROOT=Path(__file__).resolve().parents[1]
import sys as _sys;_sys.path.insert(0,str(ROOT));import paths
OUT=Path(paths.animal_package('rainbowtiger'))
SOURCE=Path(paths.PARTS);OLD=Path(paths.skin_blend('rainbowtiger'))
INPUTS={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (SOURCE,OLD,Path(paths.skin_map('rainbowtiger','body')),Path(paths.skin_map('rainbowtiger','trim')))}
# The approved study folder can be pointed elsewhere (RTIGER_BEARD_STUDY) when
# it has been rebuilt out of tree with make/build_rainbowtiger_beard_study.py.
import os
STUDY=Path(os.environ.get('RTIGER_BEARD_STUDY') or paths.skin_study('rainbowtiger','beard-shape-study'))
for filename in ('beard-shape-study.blend','beard-flow-color.png','beard-flow-normal.png'):
    p=STUDY/filename
    INPUTS[str(p)]=hashlib.sha256(p.read_bytes()).hexdigest()
DRAFT='--draft' in sys.argv;SCALE=6
RGB={'Coat':(24,25,29),'Cuff':(48,51,61),'Ruff':(174,180,190),'RuffShade':(98,105,118),'Snout':(45,46,53),'EarInner':(67,62,77),'Feet':(18,19,24),'Eyes':(231,65,91),
     'Coral':(231,65,91),'Orange':(247,134,29),'Gold':(244,209,42),'Lime':(73,214,100),'Cyan':(27,164,238),'Blue':(71,101,222),'Violet':(157,65,220)}
HUES=['Coral','Orange','Gold','Lime','Cyan','Blue','Violet']
def linear(rgb):return tuple(c/255/12.92 if c/255<=.04045 else ((c/255+.055)/1.055)**2.4 for c in rgb)
def select(obs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));scene=bpy.context.scene
CORE=['Body','Snout','Ears','Legs','Tail','EyePreview']
for o in list(bpy.data.objects):
    if o.name not in CORE:bpy.data.objects.remove(o,do_unlink=True)
mats={}
for name,rgb in RGB.items():
    m=bpy.data.materials.new('RainbowTiger_'+name);m.use_nodes=True;m.diffuse_color=(*linear(rgb),1)
    b=m.node_tree.nodes['Principled BSDF'];b.inputs['Base Color'].default_value=m.diffuse_color
    b.inputs['Roughness'].default_value=.65 if name in HUES else .8;b.inputs['Specular IOR Level'].default_value=.2
    mats[name]=m
    if name=='Eyes':
        b.inputs['Emission Color'].default_value=m.diffuse_color;b.inputs['Emission Strength'].default_value=.3
parts=[];preserved=[]
def bind(o,tone,bone='Root'):
    o['tone']=tone;o['bone']=bone;o.hide_render=False;o.hide_viewport=False;o.hide_select=False;o.hide_set(False);o.data.materials.clear();o.data.materials.append(mats[tone]);parts.append(o)
    return o
for name in CORE:
    o=bpy.data.objects[name]
    for mod in list(o.modifiers):o.modifiers.remove(mod)
    preserved.append({'part':name,'vertices':len(o.data.vertices),'positionsSHA256':hashlib.sha256(str([tuple(v.co) for v in o.data.vertices]).encode()).hexdigest()})
    tone={'Body':'Coat','Snout':'Snout','Ears':'Coat','Legs':'Feet','Tail':'Coat','EyePreview':'Eyes'}[name]
    inner=[p.index for p in o.data.polygons if p.material_index==1] if name=='Ears' else []
    bind(o,tone,'Tail' if name=='Tail' else 'Root')
    if name=='Ears':
        o.data.materials.append(mats['EarInner'])
        for i in inner:o.data.polygons[i].material_index=1
    if name=='EyePreview':o.name='Eyes'
    for f in o.data.polygons:f.use_smooth=True
body=bpy.data.objects['Body'];body.data.calc_loop_triangles()
triangles=[tuple(t.vertices) for t in body.data.loop_triangles]
tree=BVHTree.FromPolygons([v.co for v in body.data.vertices],triangles,all_triangles=True)

def surface(y,theta,side):
    direction=Vector((side*math.sin(theta),0,math.cos(theta)))
    hit,normal,index,_=tree.ray_cast(Vector((0,y,0))+direction*3,-direction,3.1)
    assert hit is not None,('stripe missed body',y,theta,side)
    a,b,c=[body.data.vertices[i] for i in triangles[index]]
    smooth=barycentric_transform(hit,a.co,b.co,c.co,a.normal,b.normal,c.normal).normalized()
    return hit,smooth

def flank_surface(y,z,side):
    # Fixed world height keeps a stripe horizontal even where the spherical
    # body narrows toward its front/rear. Angular wrapping bends it vertically.
    hit,normal,index,_=tree.ray_cast(Vector((side*3,y,z)),Vector((-side,0,0)),3.1)
    assert hit is not None,('horizontal stripe missed body',y,z,side)
    a,b,c=[body.data.vertices[i] for i in triangles[index]]
    return hit,barycentric_transform(hit,a.co,b.co,c.co,a.normal,b.normal,c.normal).normalized()

def mesh(name,verts,faces,tone,bone='Root'):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);bind(ob,tone,bone)
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    return ob

# A clean painted coat replaces the overlapping raised stripe shells.
sys.path.insert(0,str(Path(__file__).resolve().parent))
from rainbowtiger_clean_stripes import build_coat
body_coat=mats['Coat'].copy();body_coat.name='RainbowTiger_BodyCoat'
body.data.materials.clear();body.data.materials.append(body_coat)
coat_report=build_coat(body,body_coat,OUT,RGB)

# Preserve the existing inner-ear fans and gradient tail plume. The approved
# textured beard study replaces the old cheek and beard geometry below.
# Seat ear locks directly against the concave inner-ear mesh.
ear_source=bpy.data.objects['Ears'];ear_source.data.calc_loop_triangles()
ear_vertices=[v.co.copy() for v in ear_source.data.vertices]
ear_triangles=[tuple(t.vertices) for t in ear_source.data.loop_triangles if ear_source.data.polygons[t.polygon_index].material_index==1]
ear_inner_tree=BVHTree.FromPolygons(ear_vertices,ear_triangles,all_triangles=True)
ear_full_tree=BVHTree.FromPolygons(ear_vertices,[tuple(t.vertices) for t in ear_source.data.loop_triangles],all_triangles=True)

lock_groups={}
def bezier(points,t):
    a,b,c,d=map(Vector,points);v=1-t
    return a*v**3+3*b*v*v*t+3*c*v*t*t+d*t**3

def lock(group,points,width,depth,bone,kind='charcoal',hue=.5,shape=0):
    vv,ff,uv=lock_groups.setdefault((group,bone,kind),([],[],[]));start=len(vv)
    facial=group=='BeardFur' or group.startswith('CheekFur')
    detailed=group in ('BeardFur','EarFur') or group.startswith('CheekFur')
    rings=32 if facial else (28 if detailed else 19);segments=16 if detailed else 12
    def along(t):
        p=bezier(points,t)
        if group=='BeardFur' or group.startswith('CheekFur'):
            # Bury broad root caps in the coat while retaining their overlap.
            p.y+=.16*(1-t)**3
        if group=='EarFur':
            ray=Vector((p.x,-2,p.z));direction=Vector((0,1,0))
            hit=ear_inner_tree.ray_cast(ray,direction,4)[0]
            if hit is None:hit=ear_full_tree.ray_cast(ray,direction,4)[0]
            if hit is not None:p.y=hit.y+.006+.10*(1-t)**6
        return p
    if group=='EarFur':depth*=.60
    previous_spread=float('inf')
    for j in range(rings):
        # More sections near both ends resolve a soft rounded taper, without
        # the long final triangle that made the previous tips look sharp.
        t=.5-.5*math.cos(math.pi*(j+.15)/(rings+.15)) if facial else j/rings
        c=along(t)
        tangent=(along(min(1,t+.005))-along(max(0,t-.005))).normalized()
        normal=Vector((0,-1,0))
        if group=='TailPlume':
            if abs(normal.dot(tangent))>.93:normal=Vector((1,0,0))
            across=tangent.cross(normal).normalized();normal=across.cross(tangent).normalized()
        else:
            # Stable relief sections avoid twisting as a C/S curl changes its
            # depth direction. Broad side faces stay smooth through the bend.
            across=Vector((tangent.z,0,-tangent.x)).normalized()
        # Root blends into the body, fullest near one-third, hooked taper at end.
        fullness=(1.18+.22*math.sin(math.pi*t*(1+.12*shape)))*(1-t)**(.70+.11*(shape%3))
        if group=='EarFur':
            # Fuller roots, then a gradual nearly linear taper to a fine point.
            # The existing surface projection keeps the tuft along the inner ear.
            fullness=1.8*(1-t)**1.05*(1+.10*math.sin(math.pi*t))
        if group=='BeardFur' or group.startswith('CheekFur'):
            # Reference locks taper at BOTH ends, with a soft full middle.
            # Narrow roots tuck under neighbouring locks to keep the ruff dense.
            fullness=(.05*(1-t)**3+1.40*math.sin(math.pi*t)**.82)*(1-.22*t)
        if kind=='rainbow':fullness=(.52+.8*math.sin(math.pi*t))*(1-t)**.62
        spread=width*fullness
        if group=='EarFur':
            # The wide fan must not cross the medial rim onto the forehead.
            clearance=abs(along(t).x)-.025-abs(normal.x)*depth*fullness*1.06
            spread=min(spread,max(.006,clearance/max(abs(across.x),.01)))
        if group=='BeardFur' or group.startswith('CheekFur'):
            # Do not let a broad sweep fold through its own inside radius.
            a,b,c,d=map(Vector,points)
            velocity=3*(1-t)**2*(b-a)+6*(1-t)*t*(c-b)+3*t*t*(d-c)
            accel=6*(1-t)*(c-2*b+a)+6*t*(d-2*c+b)
            # Sections lie in XZ with depth along Y, so constrain their inside
            # radius in XZ too. A 3D radius allows the silhouette to fold over.
            velocity.y=0;accel.y=0
            bend=velocity.cross(accel).length
            if bend>1e-8:
                radius_limit=max(.0001,.80*velocity.length**3/bend)
                # Smoothly approach the inside-radius limit; a hard minimum
                # produced an abrupt shoulder before the hooked tip.
                spread=spread/(1+(spread/radius_limit)**4)**.25
            if t>.45:spread=min(spread,previous_spread)
        previous_spread=spread
        section_depth=depth*fullness
        if group=='BeardFur' or group.startswith('CheekFur'):
            # A tight bend must narrow in depth too; otherwise the tip becomes
            # a flared fin despite its narrow front silhouette.
            section_depth*=min(1,spread/max(width*fullness,1e-8))
        for q in range(segments):
            angle=q*math.tau/segments
            ridge=1+(0 if facial else .055)*math.cos(angle*4)
            vv.append(tuple(along(t)+across*(math.cos(angle)*spread)+normal*(math.sin(angle)*section_depth*ridge)))
            uv.append((q/segments if kind!='rainbow' else max(0,min(1,hue+(q/segments-.5)*.12)),t))
    vv.append(tuple(along(1)));uv.append((.5 if kind!='rainbow' else hue,1))
    ff.append(tuple(start+q for q in reversed(range(segments))))
    for j in range(rings-1):
        for q in range(segments):ff.append((start+j*segments+q,start+j*segments+(q+1)%segments,start+(j+1)*segments+(q+1)%segments,start+(j+1)*segments+q))
    for q in range(segments):ff.append((start+(rings-1)*segments+q,start+(rings-1)*segments+(q+1)%segments,start+rings*segments))

for side in (-1,1):
    bone='Ruff_L' if side<0 else 'Ruff_R'
    # Four overlapping blades span the inner ear from the upper tip to its
    # lower outside corner, while sharing roots beside the forehead.
    # Keep the paths on the ear surface rather than floating in front of it.
    ear_paths=[
      ((.075,-.49,.845),(.18,-.55,.96),(.47,-.48,1.01),(.42,-.42,1.145)),
      ((.085,-.49,.835),(.23,-.55,.95),(.53,-.48,.89),(.59,-.41,1.035)),
      ((.095,-.49,.820),(.30,-.54,.88),(.59,-.46,.78),(.65,-.40,.900)),
      ((.110,-.49,.800),(.32,-.52,.82),(.57,-.43,.66),(.665,-.39,.735))]
    for i,points in enumerate(ear_paths):lock('EarFur',[(side*x,y,z) for x,y,z in points],[.094,.106,.112,.092][i],.041,'Root',shape=i)

# The approved study replaces all earlier cheek/beard swept tubes.
from rainbowtiger_fit_beard import fit_approved_beard
fit_approved_beard(STUDY,OUT,mesh)

# Low-profile relaxed arches sit clear of the round eyes.
for side in (-1,1):
    vv=[];ff=[];rows=19;segments=8
    for j in range(rows):
        t=j/(rows-1);x=side*(.22+.235*t);z=.495+.047*math.sin(math.pi*t)
        hit,n,idx,_=tree.ray_cast(Vector((x,-3,z)),Vector((0,1,0)),4)
        assert hit is not None
        aa,bb,cc=[body.data.vertices[i] for i in triangles[idx]]
        n=barycentric_transform(hit,aa.co,bb.co,cc.co,aa.normal,bb.normal,cc.normal).normalized()
        w=.003+.014*math.sin(math.pi*t)**.5
        for q in range(segments):
            angle=q*math.tau/segments
            vv.append(tuple(hit+n*(.004+.010*math.cos(angle))+Vector((0,0,w*math.sin(angle)))))
    ff.append(tuple(reversed(range(segments))))
    for j in range(rows-1):
        for q in range(segments):ff.append((j*segments+q,j*segments+(q+1)%segments,(j+1)*segments+(q+1)%segments,(j+1)*segments+q))
    ff.append(tuple((rows-1)*segments+q for q in range(segments)))
    ob=mesh('SoftBrow_'+str(side),vv,ff,'Coat')
    for f in ob.data.polygons:f.use_smooth=True

tail_pivot=Vector((0,.77,.29))
# The plume is one compact curled silhouette made of five overlapping locks.
for j in range(5):
    x=(j-2)*.045
    points=[(x*.25,1.32,.58),(x*1.8,1.48,.69),(x*1.5-.02,1.60,.91),(-.12+x*.48,1.56,1.08-.03*abs(j-2))]
    lock('TailPlume',points,.098,.072,'Tail','rainbow',j/4)

def fur_material(kind):
    filename='rainbowtiger-'+{'charcoal':'charcoal-fur','beard':'beard-fur','rainbow':'tail-gradient'}[kind]+'.png'
    image=bpy.data.images.new('RainbowTiger_'+kind,width=256,height=256,alpha=True)
    pixels=[];srgb=lambda rgb:tuple(c/255 for c in rgb);palette=[srgb(RGB[h]) for h in HUES]
    for y in range(256):
        v=y/255
        for x in range(256):
            u=x/255
            if kind!='rainbow':
                fade=v*v*(3-2*v);a=srgb((42,45,53));b=srgb((180,183,191))
                if kind=='beard':
                    fade=min(1,v*1.35);fade=fade*fade*(3-2*fade)
                    a=srgb((52,55,63));b=srgb((185,188,195))
                color=[a[c]*(1-fade)+b[c]*fade for c in range(3)]
            else:
                at=u*(len(palette)-1);i=min(len(palette)-2,int(at));f=at-i
                color=[palette[i][c]*(1-f)+palette[i+1][c]*f for c in range(3)]
                fade=max(0,min(1,(v-.12)/.72));fade=fade*fade*(3-2*fade)
                base=srgb((221,224,231));color=[base[c]*(1-fade)+color[c]*fade for c in range(3)]
            # A few flowing strand lines, baked into the color map for Roblox.
            strand=.91+.09*math.cos(math.tau*(u*13+.08*math.sin(v*math.pi)))
            if kind=='charcoal':strand=.975+.025*math.cos(math.tau*(u*29+.10*math.sin(v*math.pi)))
            if kind=='beard':strand=.978+.022*math.cos(math.tau*(u*37+.24*math.sin(v*math.pi)))
            pixels.extend([c*strand for c in color]+[1])
    image.pixels=pixels;image.filepath_raw=str(OUT/filename);image.file_format='PNG';image.save();image.pack()
    mat=mats['Ruff'].copy();mat.name='RainbowTiger_'+kind+'_Fur';nodes=mat.node_tree.nodes
    tex=nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Linear'
    mat.node_tree.links.new(tex.outputs['Color'],nodes['Principled BSDF'].inputs['Base Color'])
    return mat,filename
fur_mats={kind:fur_material(kind) for kind in ('charcoal','beard','rainbow')}
for (name,bone,kind),(v,f,coords) in lock_groups.items():
    ob=mesh(name,v,f,'RuffShade' if kind=='charcoal' else 'Ruff',bone)
    for f in ob.data.polygons:f.use_smooth=True
    uv=ob.data.uv_layers.new(name='FurUV')
    for loop in ob.data.loops:uv.data[loop.index].uv=coords[loop.vertex_index]
    mat,filename=fur_mats[kind];ob.data.materials.clear();ob.data.materials.append(mat);ob['colorTexture']=filename
N=Vector((0,math.sqrt(36-1.9**2),-1.9)).normalized();U=Vector((1,0,0));V=N.cross(U).normalized()
added=[o for o in parts if o.name not in ('Body','Snout','Ears','Legs','Tail','Eyes')]
blocked=[]
for o in added:
    t=BVHTree.FromPolygons([v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons])
    for i in range(48):
        for fraction in (.0,.5,1):
            offset=(U*math.cos(i*math.tau/48)+V*math.sin(i*math.tau/48))*(1.95/6)*fraction
            if t.ray_cast(N*1.7+offset,-N,.95)[0] is not None:blocked.append(o.name)
assert not blocked,('rear plate blocked',blocked)

# Convert both editable scene and exported geometry to final stud units.
checks=[]
for o in parts:
    select([o]);o.scale*=SCALE;o.location*=SCALE;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bad=sum(not e.is_manifold for e in bm.edges);bm.to_mesh(o.data);bm.free()
    assert bad==0,(o.name,bad)
    assert len(o.data.polygons)<20000,(o.name,len(o.data.polygons))
    checks.append({'name':o.name,'bone':o['bone'],'tone':o['tone'],'colorRGB':RGB[o['tone']],'triangles':len(o.data.polygons),'nonManifoldEdges':bad,'colorTexture':o.get('colorTexture'),'normalTexture':o.get('normalTexture')})
bones={'Root':(Vector((0,0,0)),None),'Tail':(tail_pivot*SCALE,'Root'),'Ruff_L':(Vector((-.6,-.5,.25))*SCALE,'Root'),'Ruff_R':(Vector((.6,-.5,.25))*SCALE,'Root')}
arm=bpy.data.armatures.new('RainbowTiger_Skeleton');rig=bpy.data.objects.new('RainbowTiger_Rig',arm);scene.collection.objects.link(rig)
select([rig]);bpy.ops.object.mode_set(mode='EDIT')
for name,(pivot,parent) in bones.items():
    bone=arm.edit_bones.new(name);bone.head=pivot;bone.tail=pivot+Vector((0,0,1))
    if parent:bone.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for o in parts:
    o.vertex_groups.clear();vg=o.vertex_groups.new(name=o['bone']);vg.add(list(range(len(o.data.vertices))),1,'REPLACE')
    o.parent=rig;mod=o.modifiers.new('RainbowTigerRig','ARMATURE');mod.object=rig
scene.render.fps=30;scene.frame_start=1;scene.frame_end=121
for name in bones:
    pb=rig.pose.bones[name];pb.rotation_mode='QUATERNION'
    for frame in range(1,122,4):
        theta=math.tau*(frame-1)/120;angle=math.radians(3 if name=='Tail' else 1.2)*math.sin(theta) if name!='Root' else 0
        axis=Vector((0,0,1)) if name=='Tail' else Vector((0,1,0))
        q=pb.bone.matrix_local.to_quaternion();pb.rotation_quaternion=q.inverted()@Quaternion(axis,angle)@q
        pb.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=name)
if rig.animation_data:rig.animation_data.action.name='RainbowTiger_Idle'
# The emission image is black outside the stripes; the black coat stays dark.
pulse_shader=body_coat.node_tree.nodes['Principled BSDF']
for frame in range(1,122,4):
    pulse=(.5-.5*math.cos(math.tau*(frame-1)/120))**4
    pulse_shader.inputs['Emission Strength'].default_value=.08+.95*pulse
    pulse_shader.inputs['Emission Strength'].keyframe_insert('default_value',frame=frame)
motion=[{'part':'Body','material':'RainbowTiger_BodyCoat','emissionTexture':'rainbowtiger-stripe-emission.png','phase':0,'emissionMin':.08,'emissionMax':1.03}]
# Both eyes share one material, so their smooth RGB loop stays synchronized.
eye_shader=mats['Eyes'].node_tree.nodes['Principled BSDF']
eye_shader.inputs['Emission Strength'].default_value=1.25
for i,tone in enumerate(HUES+[HUES[0]]):
    frame=1+i*120/len(HUES);color=(*linear(RGB[tone]),1)
    for channel in ('Base Color','Emission Color'):
        eye_shader.inputs[channel].default_value=color;eye_shader.inputs[channel].keyframe_insert('default_value',frame=frame)
scene.frame_set(1);select(parts+[rig])
common=dict(use_selection=True,object_types={'MESH','ARMATURE'},axis_forward='-Z',axis_up='Y',add_leaf_bones=False,armature_nodetype='NULL',path_mode='COPY',embed_textures=True,use_triangles=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False)
bpy.ops.export_scene.fbx(filepath=str(OUT/'rainbowtiger-complete.fbx'),bake_anim=False,**common)
bpy.ops.export_scene.fbx(filepath=str(OUT/'rainbowtiger-idle.fbx'),bake_anim=True,bake_anim_simplify_factor=0,**common)
def bounds(obs):
    pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices]
    return {key:[fn(v[i] for v in pts) for i in range(3)] for key,fn in [('min',min),('max',max)]}
before=bounds(parts);known=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(OUT/'rainbowtiger-complete.fbx'),use_anim=False)
imports=[o for o in bpy.data.objects if o not in known];meshes=[o for o in imports if o.type=='MESH'];after=bounds(meshes)
error=max(abs(a-b) for k in before for a,b in zip(before[k],after[k]));assert error<.001 and len(meshes)==len(parts),(error,[o.name for o in meshes],[o.name for o in parts])
assert sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)==sum(row['triangles'] for row in checks),('FBX triangle mismatch',[(o.name,sum(len(p.vertices)-2 for p in o.data.polygons)) for o in meshes],checks)
assert all(o.vertex_groups for o in meshes),'FBX lost weights'
assert not any(o.name.startswith(('FootCuff','FootTuft','Brow_')) for o in parts),'Rejected cuff or angry brow geometry returned'
for o in meshes:
    if o.name.startswith(('Body','CheekFur','CheekFill','EarFur','BeardFur')):
        assert o.data.uv_layers and any(n.type=='TEX_IMAGE' and n.image for m in o.data.materials for n in m.node_tree.nodes),'Fur texture/UV lost in export'
    if o.name.startswith(('CheekFur','CheekFill','BeardFur')):
        nodes=[n for m in o.data.materials for n in m.node_tree.nodes]
        assert any(n.type=='NORMAL_MAP' for n in nodes),'Beard normal map lost in FBX'
        assert any(n.type=='TEX_IMAGE' and n.image and 'beard-flow-normal' in n.image.name for n in nodes),'Beard stroke image lost in FBX'
import_tail=next(o for o in meshes if o.name.startswith('TailPlume'))
assert import_tail.data.uv_layers,'Tail gradient UVs lost in FBX'
assert any(n.type=='TEX_IMAGE' and n.image for m in import_tail.data.materials for n in m.node_tree.nodes),'FBX lost tail color texture'

for o in imports:bpy.data.objects.remove(o,do_unlink=True)
scene.frame_set(1)
report={'skin':'rainbowtiger','rarity':'legendary','chest':'animal','status':'Approved option C built; model review and Studio integration pending','design':'Option C: compact swept charcoal cheek and ear locks, soft relaxed arches, bare feet, curled rainbow-gradient tail, black piggy with clean UV-painted wraparound stripes; one inner and one outer face stripe per eye','inputHashes':INPUTS,'preservedSourceParts':preserved,'meshCount':len(parts),'triangles':sum(r['triangles'] for r in checks),'meshes':checks,'coat':coat_report,'sourceToStudScale':6,'bodyWidthStuds':12,'boundsStuds':before,'fbxRoundTripBoundsError':error,'addedGeometryVaultBlocked':blocked,'animation':{'periodSeconds':4,'fps':30,'frames':[1,121],'bones':{n:{'pivotStuds':list(v),'parent':p} for n,(v,p) in bones.items()},'tailSwayDegrees':3,'ruffSwayDegrees':1.2,'pulseCurve':'(0.5 - 0.5*cos(2*pi*(time/4-phase)))^4','groups':motion,'notes':'Idle FBX contains bone motion. Material pulse stays in Blender and must be implemented by Fable on the Body stripe-only emission mask; preserve its fixed color texture. No particle aura.'}}
report['animation']['tailColor']={'part':'TailPlume','colorTexture':'rainbowtiger-tail-gradient.png','behavior':'Continuous UV-mapped silver-to-rainbow color on the fur; preserve the texture rather than applying flat Color. Tail moves with its bone.','sha256':hashlib.sha256((OUT/'rainbowtiger-tail-gradient.png').read_bytes()).hexdigest()}
report['animation']['charcoalFur']={'parts':['EarFur'],'colorTexture':'rainbowtiger-charcoal-fur.png','behavior':'Preserve original inner-ear fan material.'}
report['animation']['beardFur']={'parts':['CheekFur_-1','CheekFur_1','CheekFill_-1','CheekFill_1','BeardFur'],'colorTexture':'beard-flow-color.png','normalTexture':'beard-flow-normal.png','behavior':'Approved dense curved locks hug the snout rim, with overlapping inner cheek fills and three chin locks rooted beneath the snout. Preserve color/normal maps with white part tint. Cheeks follow Ruff_L/R; under-snout BeardFur follows Root.'}
report['design']+='; approved full overlapping banana-shaped beard with flowing textured strokes, fitted from the reviewed study'
report['animation']['eyes']={'part':'Eyes','periodSeconds':4,'paletteRGB':[RGB[t] for t in HUES],'glowStrengthPreview':1.25,'behavior':'Both eyes cycle smoothly through the same RGB palette in sync; brightness stays steady.'}
(OUT/'rainbowtiger-asset-report.json').write_text(json.dumps(report,indent=2));(OUT/'animation-handoff.json').write_text(json.dumps(report['animation'],indent=2))
world=bpy.data.worlds.new('RainbowTigerReview');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.48,.54,.62,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6
for name,pos,power,size in [('Key',(-20,-27,35),4500,22),('Fill',(25,-10,16),2800,20),('Rim',(3,22,28),4000,18)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size
    o=bpy.data.objects.new('REVIEW_'+name,data);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,before['min'][2]-.03));ground=bpy.context.object;ground.name='REVIEW_Ground';ground.data.materials.append(mats['Ruff'])
cam=bpy.data.objects.new('REVIEW_Camera',bpy.data.cameras.new('REVIEW_Camera'));scene.collection.objects.link(cam);scene.camera=cam
cam.data.type='ORTHO';cam.data.ortho_scale=20
scene.render.engine='CYCLES';scene.cycles.samples=8 if DRAFT else 24;scene.cycles.use_denoising=True
scene.render.resolution_x=640 if DRAFT else 900;scene.render.resolution_y=scene.render.resolution_x;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG'
shots=[('hero',(-23,-31,16),(0,0,0)),('front',(0,-36,12),(0,0,1)),('crown',(-8,-21,30),(0,0,2)),('rear',(1,32,12),(0,1,1)),('side',(-36,0,5),(0,0,.2))]
for name,pos,target in shots:
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/f'rainbowtiger-{name}.png');bpy.ops.render.render(write_still=True)
cam.location=shots[0][1];cam.rotation_euler=(Vector(shots[0][2])-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/'rainbowtiger-hero.png')
select(parts+[rig]);bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rainbowtiger-complete.blend'))
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==sha for p,sha in INPUTS.items())
print('RAINBOW_TIGER_READY',json.dumps({'meshes':len(parts),'triangles':report['triangles'],'fbxError':error}),flush=True)
