"""Ice Phoenix: curved feather geometry following the original Phoenix concept.

Writes only assets/piggies/legendary/phoenix/package/. Original concept, old art and master stay intact.
"""
from pathlib import Path
import sys,math,json,hashlib,struct,zlib
import bpy,bmesh
from mathutils import Vector,Quaternion
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT));sys.path.insert(0,str(Path(__file__).parent))
import paths
OUT=Path(paths.animal_package('phoenix'));OUT.mkdir(exist_ok=True)
MASTER=Path(paths.PARTS);CONCEPT=Path(paths.skin_study('phoenix','concepts-v2'))/'crystal-crown-refined.png'
# The concept raster is provenance only (nothing reads its pixels), so a
# working tree without it still builds; the report records which it was.
INPUTS={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (MASTER,CONCEPT,Path(paths.skin_blend('phoenix'))) if p.exists()}
DRAFT='--draft' in sys.argv;SCALE=6
RGB={'Ivory':(225,232,226),'Frost':(217,240,249),'Snout':(134,185,210),'Sky':(149,194,218),'Azure':(92,143,187),'Indigo':(69,100,153),'Eye':(23,38,57),'InnerEar':(76,129,172),
     'FeatherPearl':(167,209,229),'FeatherSky':(98,160,205),'FeatherAzure':(63,121,178),'FeatherIndigo':(59,92,149),'GlowPearl':(146,210,230),'GlowSky':(104,177,221),'GlowAzure':(106,150,210),'Face':(225,232,226)}
def linear(rgb):return tuple(c/255/12.92 if c/255<=.04045 else ((c/255+.055)/1.055)**2.4 for c in rgb)
def select(obs):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs:ob.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
def mix(a,b,t):return tuple(round(x*(1-t)+y*t) for x,y in zip(a,b))
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
from phoenix_crystal_atlas import build as build_atlas,uv as atlas_uv
tones=list(RGB);atlas_report=build_atlas(OUT,RGB)
bpy.ops.wm.open_mainfile(filepath=str(MASTER));scene=bpy.context.scene
CORE=['Body','Snout','Ears','Legs','Tail','EyePreview']
for ob in list(bpy.data.objects):
    if ob.name not in CORE:bpy.data.objects.remove(ob,do_unlink=True)
coat=bpy.data.materials.new('Phoenix_FeatherAtlas');coat.use_nodes=True;nt=coat.node_tree;b=nt.nodes['Principled BSDF']
b.inputs['Roughness'].default_value=.38;b.inputs['Specular IOR Level'].default_value=.38
for name in ('color','emissive'):
    image=bpy.data.images.load(str(OUT/f'phoenix_{name}.png'),check_existing=False)
    if name=='emissive':image.colorspace_settings.name='Non-Color'
    image.pack();node=nt.nodes.new('ShaderNodeTexImage');node.image=image;node.label='Phoenix '+name
    if name=='color':nt.links.new(node.outputs['Color'],b.inputs['Base Color']);nt.links.new(node.outputs['Color'],b.inputs['Emission Color'])
    else:
        gain=nt.nodes.new('ShaderNodeMath');gain.operation='MULTIPLY';gain.label='Phoenix frost shimmer';nt.links.new(node.outputs['Color'],gain.inputs[0]);nt.links.new(gain.outputs[0],b.inputs['Emission Strength'])
parts=[];preserved=[];feather_count=0
bones={'Root':(Vector((0,0,0)),None),'Tail':(Vector((0,.77,.29)),'Root'),
       'Mantle_L':(Vector((-.6,.2,.3)),'Root'),'Mantle_R':(Vector((.6,.2,.3)),'Root'),
       'Ruff_L':(Vector((-.58,-.61,.16)),'Root'),'Ruff_R':(Vector((.58,-.61,.16)),'Root')}
def palette_uv(tone,t=0,u=.5):return atlas_uv(tones.index(tone),u,t)
for name in CORE:
    ob=bpy.data.objects[name];ob.hide_render=False;ob.hide_viewport=False;ob.hide_set(False);ob.hide_select=False
    for mod in list(ob.modifiers):ob.modifiers.remove(mod)
    preserved.append(dict(part=name,vertices=len(ob.data.vertices),positionsSHA256=hashlib.sha256(str([tuple(v.co) for v in ob.data.vertices]).encode()).hexdigest()))
    inner={p.index for p in ob.data.polygons if p.material_index==1} if name=='Ears' else set()
    ob['bone']='Tail' if name=='Tail' else 'Root';parts.append(ob)
    for uv in list(ob.data.uv_layers):ob.data.uv_layers.remove(uv)
    uv=ob.data.uv_layers.new(name='PhoenixPalette');ob.data.materials.clear();ob.data.materials.append(coat)
    for p in ob.data.polygons:
        tone={'Body':'Ivory','Snout':'Snout','Ears':'Frost','Legs':'Indigo','Tail':'Sky','EyePreview':'Eye'}[name]
        if name=='Body':tone='Ivory' if p.center.y<-.40 else ('Sky' if p.center.y<.15 else 'Azure')
        if name=='Legs' and p.center.z<-.87:tone='Frost'
        if p.index in inner:tone='InnerEar'
        for li in p.loop_indices:
            v=ob.data.vertices[ob.data.loops[li].vertex_index].co
            if name=='Body' and p.center.y<-.40:
                uv.data[li].uv=palette_uv('Face',(v.z+1)/2,(v.x+1)/2)
            elif name=='Snout' and p.center.y<-.92 and p.center.z>.23:
                uv.data[li].uv=palette_uv('Snout',(v.z+.8)/1.3,(v.x+.6)/1.2)
            else:uv.data[li].uv=palette_uv(tone)
        p.use_smooth=True
    if name=='EyePreview':ob.name='Eyes'
body=bpy.data.objects['Body'];tree=BVHTree.FromPolygons([v.co for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons])
tail_mesh=bpy.data.objects['Tail'].data
tail_tree=BVHTree.FromPolygons([v.co for v in tail_mesh.vertices],[list(p.vertices) for p in tail_mesh.polygons])
root_seats=[]
from phoenix_vault_geometry import N,O,U,V,SEAT,BORE,vault_blocked

def surface(point):
    radial=point.normalized();hit,normal,_,_=tree.ray_cast(radial*3,-radial,4)
    radius=1/math.sqrt(radial.x**2+(radial.y/1.08)**2+(radial.z/.96)**2)
    if hit is None or normal.dot(radial)<.25 or hit.dot(radial)<radius-.10:
        # Continue the outer envelope over openings; reserved() removes these feathers.
        hit=radial/math.sqrt(radial.x**2+(radial.y/1.08)**2+(radial.z/.96)**2)
        normal=Vector((hit.x,hit.y/1.08**2,hit.z/.96**2)).normalized()
    return hit,normal

def reserved(data):
    bvh=BVHTree.FromPolygons([v.co for v in data.vertices],[list(p.vertices) for p in data.polygons])
    if vault_blocked(bvh):return True
    for x in (-.06,-.045,0,.045,.06):
        for y in (0,.09,.18,.27,.36,.45,.525):
            if bvh.ray_cast(Vector((x,y,2.3)),Vector((0,0,-1)),1.4)[0] is not None:return True
    return False

def feather(name,start,direction,normal,length,width,tone,bone,drape=False):
    global feather_count
    start=Vector(start);d=Vector(direction).normalized();n=Vector(normal).normalized();n=(n-d*n.dot(d)).normalized();side=d.cross(n).normalized()
    conforms=drape or name.startswith(('Ruff_','Face_','Cheek_'))
    is_vault=name.startswith('VaultBlend_')
    def contact(point):
        if not is_vault:return surface(point)
        p=point-O;offset=p-N*p.dot(N)
        hit,sn,_,_=tree.ray_cast(O+N*2+offset,-N,2)
        assert hit is not None and (hit-O).dot(N)>.7
        return hit,sn
    is_crown=name.startswith('Crown_');is_tail=name.startswith('TailFan_')
    if is_crown:
        hit,sn=surface(start);start=hit-sn*.024
    elif is_tail:
        hit,sn,_,_=tail_tree.find_nearest(start);start=hit-sn*.016
    verts=[];faces=[];ts=[];us=[];rings=11;around=8
    def seated(point,t):
        if not conforms:return point
        hit,sn=contact(point)
        # Root penetrates the body; the vane follows its contour closely.
        height=(-.006+.035*smooth(t/.35)+.010*t*t) if is_vault else (-.022+.045*smooth(t/.35)+.018*t*t)
        return hit+sn*height
    for i in range(rings):
        t=i/rings;shape=math.sin(math.pi*(.045+.955*t))**.80
        center=start+d*(length*t)+n*length*((.015 if drape else .23)*t*t+.055*math.sin(math.pi*t))+side*length*.07*t*t
        for j in range(around):
            angle=j*math.tau/around;across=math.cos(angle);depth=math.sin(angle)
            point=center+side*(width*.5*shape*across)
            if conforms:
                point=seated(point,t)
                _,sn=contact(point);point+=sn*(.013*shape*depth)
            else:point+=n*(.035*shape*depth)
            verts.append(tuple(point))
            ts.append(t);us.append(.5+.43*across)
    tip=start+d*length+n*length*(.015 if drape else .23)+side*length*.07
    tip=seated(tip,1)
    verts.append(tuple(tip));ts.append(1);us.append(.5);tip_index=len(verts)-1
    faces.append(tuple(reversed(range(around))))
    for i in range(rings-1):
        for j in range(around):faces.append((i*around+j,i*around+(j+1)%around,(i+1)*around+(j+1)%around,(i+1)*around+j))
    for j in range(around):faces.append(((rings-1)*around+j,(rings-1)*around+(j+1)%around,tip_index))
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    if conforms and reserved(data):
        bpy.data.meshes.remove(data);return None
    weight=data.attributes.new(name='TipWeight',type='FLOAT',domain='POINT')
    for i,t in enumerate(ts):weight.data[i].value=1 if is_tail else smooth((t-.12)/.72)
    if conforms or is_crown:
        for point in verts[:around]:
            hit,sn=contact(Vector(point));root_seats.append((Vector(point)-hit).dot(sn))
    ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);data.materials.append(coat);ob['bone']=bone;ob['tone']=tone
    uv=data.uv_layers.new(name='PhoenixPalette')
    for p in data.polygons:
        p.use_smooth=True
        for li in p.loop_indices:
            vi=data.loops[li].vertex_index;uv.data[li].uv=palette_uv(tone,ts[vi]*(.63 if is_vault else 1),us[vi])
    parts.append(ob);feather_count+=1;return ob

# Overlapping mantle, following the pig's broad shoulders down its flanks.
for row,(theta,count) in enumerate([(.12,8),(.30,14),(.48,18),(.70,22),(.92,26),(1.14,28),(1.36,30),(1.58,30),(1.80,28),(2.02,26),(2.24,24),(2.46,20),(2.66,16),(2.84,12)]):
    for j in range(count):
        phi=math.tau*(j+.5*(row%2))/count
        raw=Vector((math.sin(theta)*math.cos(phi),1.08*math.sin(theta)*math.sin(phi),.96*math.cos(theta)))
        x,y,z=raw
        if y<-.43:continue
        radial=Vector((x,y/1.08**2,z/.96**2)).normalized();hit,n,_,_=tree.ray_cast(raw+radial, -radial,2)
        if hit is None:continue
        direction=(Vector((math.cos(theta)*math.cos(phi),math.cos(theta)*math.sin(phi),-math.sin(theta)))+Vector((0,.30,0))).normalized()
        bone=('Mantle_L' if x<0 else 'Mantle_R') if theta<2.25 and y<.60 else 'Root'
        tone='FeatherSky' if y<.1 else ('FeatherAzure' if theta<1.6 else 'FeatherIndigo')
        if row in (2,4,6) and j%5==1:tone='GlowSky' if y<.3 else 'GlowAzure'
        ob=feather(f'Mantle_{row}_{j}',hit-n*.02,direction,n,.44 if theta<1.6 else .37,.35 if theta<1.6 else .32,tone,bone,True)
        if ob and y>=.60:ob['meshGroup']='BackMantle'

# Small coverts begin beside the slot and fan outward, leaving only its narrow lane.
for sign in (-1,1):
    for i,y in enumerate((.02,.15,.28,.41,.54)):
        p=Vector((sign*.095,y,.96));hit,n=surface(p)
        feather(f'BackSlot_{sign}_{i}',hit,(sign,.12,-.05),n,.28,.20,'FeatherSky','Root',True)
for i,y in enumerate((.67,.84)):
    hit,n=surface(Vector((0,y,.80)))
    feather(f'BackSpine_{i}',hit,(0,1,-.35),n,.26,.28,'FeatherAzure','Root',True)
# Short coverts can fit below the vault where the long mantle pieces cannot.
for i,x in enumerate((-.30,-.15,0,.15,.30)):
    for j,z in enumerate((-.45,-.57,-.69,-.81)):
        hit,n,_,_=tree.ray_cast(Vector((x,3,z)),Vector((0,-1,0)),4)
        if hit is not None:
            ob=feather(f'BackLower_{i}_{j}',hit,(x*.2,0,-1),n,.17,.19,'FeatherAzure','Root',True)
            if ob:ob['meshGroup']='BackCover'
for i,x in enumerate((-.16,0,.16)):
    hit,n=surface(Vector((x,-.17,.96)))
    ob=feather(f'BackFront_{i}',hit,(0,-1,0),n,.20,.22,'FeatherSky','Root',True)
    if ob:ob['meshGroup']='BackCover'

for sign,label in [(-1,'L'),(1,'R')]:
    for row in range(3):
        for k in range(6):
            start=(sign*(.60-.016*k+.030*row),-.69+row*.085,.46-k*.155)
            feather(f'Ruff_{label}_{row}_{k}',start,(sign*.52,.24,-.70),(sign*.55,-1,.1),.46+row*.04,.27,'GlowPearl' if k==2 and row==0 else ('FeatherPearl' if row==0 else 'FeatherSky'),'Ruff_'+label)
    for k in range(5):
        feather(f'Face_{label}_{k}',(sign*(.50-.06*k),-.83,.03-.125*k),(sign*.32,.1,-.9),(sign*.3,-1,.1),.33,.24,'FeatherPearl','Root')
    # Close-set cheek cover reaches the snout sides without masking the eyes.
    for row,x in enumerate((.48,.60,.72)):
        for k,z in enumerate((.18,.015,-.15,-.315,-.48)):
            hit,n,_,_=tree.ray_cast(Vector((sign*x,-3,z)),Vector((0,1,0)),4)
            if hit is not None:
                feather(f'Cheek_{label}_{row}_{k}',hit,(sign*.18,.08,-1),n,.25,.24,'FeatherPearl' if row<2 else 'FeatherSky','Root')

# Seven crown feathers share three existing animation groups, ahead of the slot.
for i,pivot in enumerate([(0,-.47,.90),(-.27,-.51,.84),(.27,-.51,.84)]):
    bones['Crest_'+str(i)]=(Vector(pivot),'Root')
for i,(x,y,z,length,bone) in enumerate([(0,-.47,.91,.99,'Crest_0'),(-.23,-.49,.87,.85,'Crest_1'),(.23,-.49,.87,.85,'Crest_2'),(-.40,-.54,.78,.65,'Crest_1'),(.40,-.54,.78,.65,'Crest_2'),(-.12,-.72,.72,.56,'Crest_1'),(.12,-.72,.72,.56,'Crest_2')]):
    feather('Crown_'+str(i),(x,y,z),(x*1.15,.08,1),(0,-1,0),length,.37 if i<5 else .31,'GlowSky' if i<5 else 'GlowPearl',bone)

# Low rearward tail fan shares the original curled tail's bone.
for i,a in enumerate([-.85,-.57,-.28,0,.28,.57,.85]):
    feather('TailFan_'+str(i),(.08*math.sin(a),1.27,.57),(.70*math.sin(a),.66,.67*math.cos(a)),(0,-.55,.8),.80 if i!=3 else .95,.29,'GlowAzure' if i%2==0 else 'GlowSky','Tail')

# Small overlapping feathers continue down all four legs, above the pale hoof rim.
leg_count=0
for side,x in [('L',-.5),('R',.5)]:
    for end,y in [('F',-.48),('B',.54)]:
        for row,z in enumerate([-.54,-.675,-.81]):
            for j in range(10):
                a=math.tau*(j+.5*(row%2))/10;n=Vector((math.cos(a),math.sin(a),0))
                ob=feather(f'Leg_{side}{end}_{row}_{j}',Vector((x,y,z))+n*.202,(n.x*.08,n.y*.08,-1),n,.165 if row==2 else .205,.17,'FeatherSky' if j%3 else 'GlowPearl','Root')
                ob['meshGroup']='Leg_'+side+end;leg_count+=1

# Feather roots tuck beneath even the smallest door; outward vanes merge into
# the coat. This is plumage following the body, not a raised vault collar.
vault_feathers=0
for i in range(48):
    angle=i*math.tau/48;d=U*math.cos(angle)+V*math.sin(angle)
    hit,n,_,_=tree.ray_cast(O+N*2+d*(1.49/6),-N,2)
    if hit is None:continue
    length=.11+.085*(.5+.5*math.sin(i*2.399963))
    ob=feather(f'VaultBlend_{i}',hit,d,n,length,.13,'FeatherSky' if i%4==0 else 'FeatherAzure','Root',True)
    if ob:ob['meshGroup']='VaultBlend';vault_feathers+=1

# Feather pieces share one atlas; group by bone for a compact import hierarchy.
groups={}
for ob in parts[6:]:groups.setdefault(ob.get('meshGroup',ob['bone']),[]).append(ob)
parts=parts[:6]
for group,obs in groups.items():
    bone=obs[0]['bone']
    select(obs)
    if len(obs)>1:bpy.ops.object.join()
    ob=bpy.context.object;ob.name='Phoenix_'+group+'_Feathers';ob['bone']=bone;parts.append(ob)
glow_materials={};glow_groups=[]
PHASES={'Root':0,'Ruff_L':.06,'Ruff_R':.12,'Crest_0':0,'Crest_1':.09,'Crest_2':.17,'Mantle_L':.22,'Mantle_R':.29,'Tail':.43}
for ob in parts:
    bone=ob['bone']
    if bone not in glow_materials:
        m=coat.copy();m.name='PhoenixFrost_'+bone;glow_materials[bone]=m
    ob.data.materials.clear();ob.data.materials.append(glow_materials[bone])
    ob['glowPhase']=PHASES[bone]
    glow_groups.append(dict(part=ob.name,phase=PHASES[bone]))
blocked=[];coin_blocked=[]
for ob in parts[6:]:
    t=BVHTree.FromPolygons([v.co for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons])
    if vault_blocked(t):blocked.append(ob.name)
    for x in (-.045,0,.045):
        for y in (0,.09,.18,.27,.36,.45,.525):
            if t.ray_cast(Vector((x,y,2.3)),Vector((0,0,-1)),1.4)[0] is not None:coin_blocked.append(ob.name)
assert not blocked and not coin_blocked,(blocked,coin_blocked)
checks=[]
for ob in parts:
    select([ob]);ob.scale*=SCALE;ob.location*=SCALE;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bad=sum(not e.is_manifold for e in bm.edges);bm.to_mesh(ob.data);bm.free()
    assert bad==0 and len(ob.data.polygons)<20000,(ob.name,bad,len(ob.data.polygons))
    checks.append(dict(name=ob.name,bone=ob['bone'],triangles=len(ob.data.polygons),nonManifoldEdges=bad))
arm=bpy.data.armatures.new('Phoenix_Skeleton');rig=bpy.data.objects.new('Phoenix_Rig',arm);scene.collection.objects.link(rig);select([rig]);bpy.ops.object.mode_set(mode='EDIT')
for name,(pivot,parent) in bones.items():
    bone=arm.edit_bones.new(name);bone.head=pivot*SCALE;bone.tail=pivot*SCALE+Vector((0,0,1))
    if parent:bone.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for ob in parts:
    ob.vertex_groups.clear();vg=ob.vertex_groups.new(name=ob['bone'])
    weights=ob.data.attributes.get('TipWeight')
    if weights and ob['bone'] not in ('Root','Tail'):
        roots=ob.vertex_groups.new(name='Root')
        for v in ob.data.vertices:
            w=weights.data[v.index].value
            if w>0:vg.add([v.index],w,'REPLACE')
            if w<1:roots.add([v.index],1-w,'REPLACE')
    else:vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    ob.parent=rig;mod=ob.modifiers.new('PhoenixRig','ARMATURE');mod.object=rig
scene.render.fps=30;scene.frame_start=1;scene.frame_end=121
for index,name in enumerate(bones):
    pb=rig.pose.bones[name];pb.rotation_mode='QUATERNION';q=pb.bone.matrix_local.to_quaternion()
    amplitude=0 if name=='Root' else (1.5 if name.startswith('Mantle') else 3)
    for frame in range(1,122,4):
        theta=math.tau*(frame-1)/120;angle=math.radians(amplitude)*math.sin(theta+index*.38)
        axis=Vector((0,0,1)) if name=='Tail' else Vector((1,0,.1));pb.rotation_quaternion=q.inverted()@Quaternion(axis.normalized(),angle)@q;pb.keyframe_insert('rotation_quaternion',frame=frame,group=name)
rig.animation_data.action.name='Phoenix_Idle'
for bone,m in glow_materials.items():
    socket=next(n for n in m.node_tree.nodes if n.label=='Phoenix frost shimmer').inputs[1]
    for frame in range(1,122,4):
        theta=math.tau*((frame-1)/120-PHASES[bone])
        socket.default_value=1.1+4.4*(.5-.5*math.cos(theta))**2+.15*math.sin(theta*3)
        socket.keyframe_insert('default_value',frame=frame)
scene.frame_set(1);select(parts+[rig]);action=rig.animation_data.action;rig.animation_data.action=None
for pb in rig.pose.bones:pb.rotation_quaternion=(1,0,0,0)
bpy.context.view_layer.update()
common=dict(use_selection=True,object_types={'MESH','ARMATURE'},axis_forward='-Z',axis_up='Y',add_leaf_bones=False,armature_nodetype='NULL',path_mode='COPY',embed_textures=True,use_triangles=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False)
def bounds(obs):
    points=[o.matrix_world@v.co for o in obs for v in o.data.vertices]
    return {k:[fn(p[i] for p in points) for i in range(3)] for k,fn in [('min',min),('max',max)]}
before=bounds(parts);bpy.ops.export_scene.fbx(filepath=str(OUT/'phoenix-complete.fbx'),bake_anim=False,**common)
known=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(OUT/'phoenix-complete.fbx'),use_anim=False)
imports=[o for o in bpy.data.objects if o not in known];meshes=[o for o in imports if o.type=='MESH'];after=bounds(meshes)
error=max(abs(a-b) for k in before for a,b in zip(before[k],after[k]));assert error<.001 and len(meshes)==len(parts),(error,len(meshes))
assert all(o.vertex_groups and o.data.uv_layers for o in meshes)
assert sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)==sum(r['triangles'] for r in checks)
for ob in imports:bpy.data.objects.remove(ob,do_unlink=True)
rig.animation_data.action=action;scene.frame_set(1);select(parts+[rig]);bpy.ops.export_scene.fbx(filepath=str(OUT/'phoenix-idle.fbx'),bake_anim=True,bake_anim_simplify_factor=0,**common)
report=dict(skin='phoenix',rarity='legendary',chest='animal',status='Curved feather model revision for review; Studio integration pending',inputHashes=INPUTS,preservedSourceParts=preserved,meshCount=len(parts),triangles=sum(r['triangles'] for r in checks),meshes=checks,featherCount=feather_count,bodyWidthStuds=12,sourceToStudScale=6,boundsStuds=before,fbxRoundTripBoundsError=error,addedGeometryVaultBlocked=blocked,addedGeometryCoinBlocked=coin_blocked,paletteRGB=RGB,maps=[dict(file=p.name,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in (OUT/'phoenix_color.png',OUT/'phoenix_emissive.png')],animation=dict(periodSeconds=4,fps=30,frames=[1,121],bones={n:dict(pivotStuds=list(v*SCALE),parent=p) for n,(v,p) in bones.items()},pulseCurve='0.8 + 1.65*(0.5-0.5*cos(theta)) + 0.20*sin(3*theta), theta=2*pi*time/4',notes='FBX contains feather and tail bone motion. Emissive mask and client companion animate the flame tips in Studio.'))
report['displayName']='Ice Phoenix'
report['vaultFit']=dict(axisOriginStuds=list(O*6),plateSeatStuds=list(SEAT*6),underlapFeathers=vault_feathers,runtimeFrame=True)
assert root_seats and max(root_seats)<.001,max(root_seats)
report['featherAttachment']=dict(rootVerticesChecked=len(root_seats),maximumSignedRootGap=max(root_seats),surfaceFollowing=True,rootPinnedWeights=True,backCoverage='Contour-following feathers across back; only functional slot and vault clearance reserved',cheekRowsPerSide=3)
report['crystalCrown']=dict(crownFeathers=7,tailFeathers=7,legFeathers=leg_count,atlas=atlas_report,concept=str(CONCEPT),faceMarkings='Mirrored frost branches and six-ray forehead motif; narrow upper snout flourish')
report['animation'].update(glowGroups=glow_groups,pulseCurve='1.1 + 4.4*(0.5-0.5*cos(theta))^2 + 0.15*sin(3*theta), theta=2*pi*(time/4-phase)',notes='Feather roots are pinned; tips move with weighted bones. Emissive mask and client companion reproduce the stronger frost-tip pulse in Studio.')
(OUT/'phoenix-asset-report.json').write_text(json.dumps(report,indent=2));(OUT/'animation-handoff.json').write_text(json.dumps(report['animation'],indent=2))
world=bpy.data.worlds.new('PhoenixReview');world.use_nodes=True;scene.world=world;world.node_tree.nodes['Background'].inputs[0].default_value=(.48,.54,.62,1);world.node_tree.nodes['Background'].inputs[1].default_value=.65
for name,pos,power,size in [('Key',(-20,-27,35),4500,22),('Fill',(25,-10,16),2800,20),('Rim',(3,22,28),4000,18)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size;ob=bpy.data.objects.new('REVIEW_'+name,data);scene.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
floor=bpy.data.materials.new('ReviewGround');floor.use_nodes=True;floor.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*linear((151,159,151)),1)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,before['min'][2]-.03));bpy.context.object.name='REVIEW_Ground';bpy.context.object.data.materials.append(floor)
cam=bpy.data.objects.new('REVIEW_Camera',bpy.data.cameras.new('REVIEW_Camera'));scene.collection.objects.link(cam);scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=22
scene.render.engine='CYCLES';scene.cycles.samples=8 if DRAFT else 24;scene.cycles.use_denoising=True;scene.render.resolution_x=640 if DRAFT else 900;scene.render.resolution_y=scene.render.resolution_x;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG'
from stormwolf_lightning import compositor
compositor(scene);scene.frame_set(55)
shots=[('hero',(-25,-33,18),(0,.1,1)),('front',(0,-36,11),(0,0,1)),('crown',(-8,-21,34),(0,0,2)),('rear',(0,35,13),(0,1,1)),('detail',(-17,-30,17),(0,-2.8,3.7))]
for name,pos,target in shots:
    cam.data.ortho_scale=13 if name=='detail' else (26 if name in ('crown','rear') else 22)
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/f'phoenix-{name}.png');bpy.ops.render.render(write_still=True)
cam.data.ortho_scale=22;cam.location=shots[0][1];cam.rotation_euler=(Vector(shots[0][2])-cam.location).to_track_quat('-Z','Y').to_euler();scene.frame_set(1)
select(parts+[rig]);bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'phoenix-complete.blend'))
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==sha for p,sha in INPUTS.items())
print('PHOENIX_READY',json.dumps(dict(meshes=len(parts),triangles=report['triangles'],feathers=feather_count,fbxError=error)),flush=True)
