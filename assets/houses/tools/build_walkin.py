"""Convert saved exterior geometry to an empty walk-in shell, preserving sources.

Blender -b -t 4 --python-exit-code 1 --python assets/houses/tools/build_walkin.py -- modern
Writes the next revision, never overwrites the source package. No mesh uploads.
"""
import sys,json,math,shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import bpy,bmesh
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
from house_paths import house_slug
from walkin_catalogue import SPECS,EXISTING,MATERIALS,AUTHOR_SCALE,folder

ROOT=Path(__file__).resolve().parents[3]
slug=sys.argv[sys.argv.index('--')+1]
rev,room,entry=SPECS[slug];stem=house_slug(slug)
source=ROOT/'assets/houses'/folder(slug,rev)
out=ROOT/'assets/houses'/folder(slug,rev+1);out.mkdir(parents=True,exist_ok=True)
old=json.loads((source/'geometry-report.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(source/f'{stem}.blend'))
scene=bpy.context.scene
author_scale=AUTHOR_SCALE[slug]
# Scale the authored scene around its ground origin. The review camera/lights
# move with it, while the new room and doors are built in final stud units.
for o in list(scene.objects):
    if o.parent is None:o.matrix_world=Matrix.Scale(author_scale,4)@o.matrix_world
    if o.type=='CAMERA':o.data.ortho_scale*=author_scale
    if o.type=='LIGHT':o.data.energy*=author_scale**2
bpy.context.view_layer.update()
room=tuple(v*author_scale for v in room);entry=tuple(v*author_scale for v in entry)
assert room[5]-room[4]>=8 and entry[4]>=7,(slug,'interior brief clearance')
for o in list(scene.objects):
    if o.type=='EMPTY' or o.get('preview'):
        bpy.data.objects.remove(o,do_unlink=True)
visual=[o for o in scene.objects if o.type=='MESH' and not o.name.startswith('REVIEW')]
for o in visual:
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    bm.to_mesh(o.data);bm.free()
for o in visual:o.hide_render=False;o.hide_set(False)

def material(name,rgb):
    m=bpy.data.materials.new(name);m.use_nodes=True
    def linear(v):v=v/255;return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
    col=tuple(linear(v) for v in rgb)+(1,)
    m.diffuse_color=col;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=col
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
    return m
mats=[material(n,c) for n,c in zip(('WalkFloor','WalkWall','WalkDoor'),MATERIALS[slug])]
trim=material('WalkTrim',tuple(min(255,int(c*1.13)) for c in MATERIALS[slug][2]))
colliders=list(old.get('collisionBoxesDraft',old.get('collisionBoxes',[]))) if slug in EXISTING else []
for collider in colliders:
    for key in ('blenderLocation','sizeXYZ'):collider[key]=[v*author_scale for v in collider[key]]
    if slug=='mushroom' and collider['name'] in ('Wall_02','Wall_06'):collider['name']='Side'+collider['name']

def box(name,lo,hi,mat=None,solid=False):
    bpy.ops.mesh.primitive_cube_add(size=1,location=tuple((a+b)/2 for a,b in zip(lo,hi)))
    o=bpy.context.object;o.name=name;o.dimensions=tuple(b-a for a,b in zip(lo,hi))
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if mat:o.data.materials.append(mat);o['section']=name;visual.append(o)
    if solid:colliders.append({'name':name,'blenderLocation':list(o.location),'sizeXYZ':list(o.dimensions)})
    return o

def bounds(o):
    pts=[o.matrix_world@Vector(p) for p in o.bound_box]
    return ([min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)])

def carve(lo,hi,targets=None):
    cutter=box('CUTTER',lo,hi);cutter.data.materials.append(mats[1]);bpy.context.view_layer.update()
    for o in list(targets if targets is not None else visual):
        a,b=bounds(o)
        if any(b[i]<=lo[i]+.00001 or a[i]>=hi[i]-.00001 for i in range(3)):continue
        bpy.context.view_layer.objects.active=o
        mod=o.modifiers.new('Walk-in opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
        bpy.ops.object.modifier_apply(modifier=mod.name)
        if not len(o.data.polygons):visual.remove(o);bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.objects.remove(cutter,do_unlink=True)

def remove(o):
    visual.remove(o);bpy.data.objects.remove(o,do_unlink=True)

x0,x1,y0,y1,floor,ceiling=room
dx,dy,threshold,width,height=entry
# Strip the old fixed door and, for the first prototype, built-in furniture.
furniture=('FeaturedPlinth','Shelf','RecordDesk','DeskLeg','RecordBook','AchievementBoard','Rug')
for o in list(visual):
    n=o.name
    if (slug=='mushroom' and n.startswith(furniture+('Door_Open','DoorKnob'))) or (slug=='slime' and n.startswith('Door_')):
        remove(o)

# Section meshes in the exterior sources contain overlapping, disconnected
# closed solids. Cut each solid separately: treating overlapping components as
# one Boolean volume can invert a face and leave a wall across the passage.
for o in list(visual):
    o['walkSection']=o.get('section',o.name)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='LOOSE');bpy.ops.object.mode_set(mode='OBJECT')
visual=[o for o in scene.objects if o.type=='MESH' and not o.name.startswith('REVIEW')]

if slug=='galleon':
    # This section includes the fixed door and the narrow old gangplank. Both
    # are replaced by the full-width accessible entrance below.
    for o in list(visual):
        if o.get('walkSection')=='Entrance':remove(o)

if slug not in EXISTING:
    # A rectangular room inside the existing shell; all overlapping facade
    # masses are cut too, so hollowing one solid cannot leave a hidden blocker.
    carve((x0-.14,y0-.14,floor-.02),(x1+.14,y1+.14,ceiling+.14))
    # Floor/lining are physical structure, not furniture. Separate colliders
    # avoid the convex mesh hull filling the entire room in Roblox.
    box('WalkFloor',(x0-.14,y0-.14,floor-.28),(x1+.14,y1+.14,floor),mats[0],True)
    box('WalkCeiling',(x0-.14,y0-.14,ceiling),(x1+.14,y1+.14,ceiling+.12),mats[1],True)
    box('WalkSideLeftWall',(x0-.12,y0,floor),(x0,y1,ceiling),mats[1],True)
    box('WalkSideRightWall',(x1,y0,floor),(x1+.12,y1,ceiling),mats[1],True)
    box('WalkRearWall',(x0,y1,floor),(x1,y1+.12,ceiling),mats[1],True)
    # Jambs on either side of the entrance, never a collider over the opening.
    left,right=dx-width/2,dx+width/2
    for name,lo,hi in [('WalkFrontLeft',(x0,y0-.12,floor),(left,y0,ceiling)),('WalkFrontRight',(right,y0-.12,floor),(x1,y0,ceiling))]:
        if hi[0]>lo[0]:box(name,lo,hi,mats[1],True)
    if ceiling>floor+height+.05:box('WalkLintel',(left,y0-.12,floor+height),(right,y0,ceiling),mats[1],True)
    # Remove the old door and bore a real passage through all intermediate
    # masses (hive porch, castle gatehouse, fishbowl sleeve, etc.).
    # Leave a gap behind the lining. Cutting exactly at its visible surface
    # would leave overlapping cut faces from the exterior solids and cause
    # black seams / z-fighting down the tunnel and across the threshold.
    carve((left-.045,dy-.9,threshold-.32),(right+.045,y0+1.0,max(floor,threshold)+height+.24),[o for o in visual if 'walkSection' in o])
    # Fixed entrance tunnel walls/ceiling tie distant facades to their room.
    # Fishbowl is a dry passage through the glass dome; no water simulation.
    if y0-dy>1.5:
        box('WalkPassageLeft',(left-.2,dy,threshold),(left,y0-.12,floor+height),mats[1],True)
        box('WalkPassageRight',(right,dy,threshold),(right+.2,y0-.12,floor+height),mats[1],True)
        box('WalkPassageCeiling',(left-.2,dy,floor+height),(right+.2,y0-.12,floor+height+.2),mats[1],True)
    if floor>threshold+.1:
        steps=max(1,math.ceil((floor-threshold)/.35));run=min(y0-dy-1,steps*.8)
        box('WalkPassageFloor',(left,dy,threshold-.25),(right,y0-run,threshold),mats[0],True)
        for i in range(steps):
            a=y0-run+i*run/steps;b=y0-run+(i+1)*run/steps;top=threshold+(floor-threshold)*(i+1)/steps
            if i==steps-1:b=y0-.14
            box('WalkInnerStep'+str(i),(left,a,threshold-.25),(right,b,top),mats[0],True)
    else:box('WalkPassageFloor',(left,dy,threshold-.25),(right,y0-.14,floor),mats[0],True)
    # Continuous shallow steps replace the old fragmented approach, with each
    # rise <= .35 stud. The surface starts at the surrounding ground.
    steps=max(1,math.ceil(threshold/.35));run=steps*.68
    carve((left-.16,dy-run-.1,-.01),(right+.16,dy+.01,threshold+.15))
    for i in range(steps):
        top=threshold*(i+1)/steps
        box('WalkApproach'+str(i),(left-.12,dy-run+i*.68,-.02),(right+.12,dy-run+(i+1)*.68+.025,top),mats[0],True)

else:
    # Keep the existing rooms/stairs. Clear only the body-sized threshold and
    # bridge any gap between porch and interior; no furniture is introduced.
    carve((dx-width/2+.12,dy-.9,threshold+.13),(dx+width/2-.12,y0+1,threshold+6.2))
    box('WalkThreshold',(dx-width/2,dy-.25,threshold-.15),(dx+width/2,y0+.4,threshold+.06),mats[0],True)

# A split pair keeps each swept leaf short. Both rotate out toward the street,
# remain non-colliding and open in advance; no prompt or stopping required.
door_objects=[];hinges=[]
def door_panel(name,left,right,front,back,bottom,top,mat):
    if slug!='mushroom':return box(name,(left,front,bottom),(right,back,top),mat)
    # Preserve the Toadstool's arched surround: rectangular panels would clip
    # its top corners when closed, even though the player clearance passes.
    outline=[(left,bottom),(right,bottom)]
    for i in range(9):
        x=right+(left-right)*i/8
        cap=5.35*author_scale+math.sqrt(max(0,(2.75*author_scale)**2-(x-dx)**2))-.12
        outline.append((x,min(top,cap)))
    n=len(outline);verts=[(x,y,z) for y in (front,back) for x,z in outline]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new(name,mesh);scene.collection.objects.link(o);o.data.materials.append(mat);visual.append(o)
    return o
for side in (-1,1):
    left=dx-width/2 if side<0 else dx+.035
    right=dx-.035 if side<0 else dx+width/2
    o=door_panel('HouseDoorLeaf_'+('L' if side<0 else 'R'),left+.04,right-.04,dy-.18,dy+.02,threshold+.06,threshold+height-.10,mats[2])
    hinge=(dx+side*width/2,dy-.08,threshold)
    door_objects.append(o);hinges.append({'name':o.name,'hingeBlender':list(hinge),'openDegrees':side*100,'sizeXYZ':list(o.dimensions),'closedCenterBlender':list(o.location)})
    # A single inset panel and handle keep the doors readable and low poly.
    panel=door_panel(o.name+'_Panel',left+.21,right-.21,dy-.215,dy-.185,threshold+.28,threshold+height-.33,trim)
    door_objects.append(panel)
    knobx=right-.28 if side<0 else left+.28
    handle=box(o.name+'_Handle',(knobx-.065,dy-.34,threshold+height*.43),(knobx+.065,dy-.215,threshold+height*.43+.65),trim)
    door_objects.append(handle)
    for item in (o,panel,handle):item['section']=o.name

# New doorway frame covers the old small panel edge without decorating rooms.
if slug not in EXISTING:
    for sx in (-1,1):box('WalkEntryJamb'+str(sx),(dx+sx*width/2-.13,dy-.27,threshold),(dx+sx*width/2+.13,dy+.07,threshold+height+.16),trim)
    box('WalkEntryHeader',(dx-width/2-.13,dy-.27,threshold+height),(dx+width/2+.13,dy+.07,threshold+height+.25),trim)

# Validate free body volumes and floor support on a grid, independently of
# collider metadata. Door panels are intentionally excluded in the open state.
bpy.context.view_layer.update()
static=[o for o in visual if o not in door_objects]
trees=[]
for o in static:
    trees.append((o.name,BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons])))
def probe(x,y,z):
    support=[]
    for name,t in trees:
        hit,_,_,_=t.ray_cast(Vector((x,y,z+.6)),Vector((0,0,-1)),2)
        if hit is not None:support.append(hit.z)
    actual=max(support) if support else None
    if actual is None:return ['missing floor',x,y,z]
    for ox,oy in ((0,0),(-.85,0),(.85,0),(0,-.85),(0,.85)):
        for name,t in trees:
            hit,_,_,_=t.ray_cast(Vector((x+ox,y+oy,actual+.15)),Vector((0,0,1)),5.65)
            if hit is not None:
                if name.startswith(('WalkInnerStep','WalkApproach')) and hit.z-actual<=.8:continue
                return ['headroom',name,x,y,hit.z]
    for zz in (actual+1,actual+3,actual+5.3):
        for axis in (Vector((1,0,0)),Vector((0,1,0))):
            for name,t in trees:
                hit,_,_,_=t.ray_cast(Vector((x,y,zz))-axis*.85,axis,1.7)
                if hit is not None:return ['body',name,x,y,zz]
    return None
samples=[]
margin=2.5 if slug=='slime' else 1.4
for i in range(5):
    for j in range(5):samples.append((x0+margin+(x1-x0-2*margin)*i/4,y0+margin+(y1-y0-2*margin)*j/4,floor))
for j in range(15):
    y=dy+(max(y0+1,dy+1)-dy)*j/14
    if floor>threshold+.1:
        run=min(y0-dy-1,math.ceil((floor-threshold)/.35)*.8)
        z=threshold+(floor-threshold)*max(0,min(1,(y-(y0-run))/run))
    else:z=floor
    samples.append((dx,y,z))
findings=[v for p in samples if (v:=probe(*p))]
if findings:print('CLEARANCE_FINDINGS '+json.dumps(findings),flush=True)
assert not findings,findings

# Restore compact sections after the per-solid cuts. This preserves the same
# material-split import strategy without shipping hundreds of tiny meshes.
groups={}
for o in visual:
    if o in door_objects:continue
    key=o.get('walkSection',o.get('section',o.name))
    groups.setdefault(key,[]).append(o)
for name,items in groups.items():
    if len(items)<2:continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in items:o.select_set(True)
    bpy.context.view_layer.objects.active=items[0];bpy.ops.object.join()
    joined=bpy.context.object;joined.name=name;joined['section']=name
    visual=[o for o in visual if o not in items]+[joined]

# Triangulate, measure and write an editable source + grouped exchange files.
stats=[];points=[];palette={}
bpy.ops.object.select_all(action='DESELECT')
for o in visual:
    o.select_set(True);bpy.context.view_layer.objects.active=o
    if not o.get('section'):o['section']=o.name
    for slot in o.material_slots:
        if slot.material is None:slot.material=mats[1]
    mod=o.modifiers.new('Walk-in triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(o.data)
    boundary=[e for e in bm.edges if e.is_boundary]
    if 0<len(boundary)<=12:
        # Exact Boolean intersections can leave a tiny triangular numeric gap
        # at a trimmed frame edge. Close only these small boundary loops.
        bmesh.ops.holes_fill(bm,edges=boundary,sides=4)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
        bm.to_mesh(o.data)
    bad=sum(not e.is_manifold for e in bm.edges);bm.free()
    stats.append({'name':o.name,'triangles':len(o.data.polygons),'nonManifoldEdges':bad})
    points.extend(o.matrix_world@v.co for v in o.data.vertices)
    for m in o.data.materials:
        def srgb(c):return round(255*(12.92*c if c<=.0031308 else 1.055*c**(1/2.4)-.055))
        palette[m.name]=[srgb(c) for c in m.diffuse_color[:3]]
lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
assert all(s['nonManifoldEdges']==0 and s['triangles']<20000 for s in stats),[s for s in stats if s['nonManifoldEdges'] or s['triangles']>=20000]
report={'id':slug,'revision':rev+1,'sourceRevision':rev,'status':'Bare walk-in shell; Studio import and avatar playtest pending','visualMeshes':len(stats),'triangles':sum(s['triangles'] for s in stats),'meshes':stats,'boundsBlender':{'min':lo,'max':hi,'size':[hi[i]-lo[i] for i in range(3)]},'paletteRGB':palette,'collisionBoxesDraft':colliders,'mountsBlender':{'Door_Exit':[dx,dy-1,threshold]},'floorHeight':floor,'reference':old.get('reference','assets/houses/docs/HOUSE-TIER-BRIEF.md'),'routesBlender':[],'walkIn':{'roomBounds':list(room),'entry':list(entry),'doors':hinges,'probes':len(samples),'blocked':findings,'furnished':False,'accessibleFloors':1,'geometryClearance':'1.7-stud body, 5.8-stud height; 25 room-grid and 15 doorway samples','collision':'Dedicated floors and walls; visual meshes and animated doors must not collide'}}
report['walkIn']['bakedExteriorScale']=author_scale
report['walkIn']['runtimeDisplayScale']=1.0
report['mountsBlender']['Wall']=[(x0+x1)/2,(16.6*author_scale if slug=='mushroom' else y1-.18),floor+4.2]
report['mountYawBlender']={'Wall':180,'Door_Exit':180}
assert x1-x0>=12.3,(slug,'display wall too narrow')
assert hi[0]-lo[0]<=62.5 and hi[1]-lo[1]<=57,(slug,'resized footprint exceeds plot',report['boundsBlender'])
(out/'geometry-report.json').write_text(json.dumps(report,indent=2))
(out/'door-handoff.json').write_text(json.dumps({'id':slug,'doors':hinges,'automatic':True,'triggerRadiusStuds':10,'holdOpenSeconds':1.5,'swingSeconds':.35,'CanCollide':False,'runtime':'HouseDoorAnimator.client.luau; prepare-in-studio.luau or build_house_runtime.py creates the pivot markers'},indent=2))
for name in ('animation-handoff.json','material-overrides.json'):
    if (source/name).exists():
        data=json.loads((source/name).read_text())
        if name=='animation-handoff.json':
            def scaled_fx(value,key=''):
                if isinstance(value,dict):return {k:scaled_fx(v,k) for k,v in value.items()}
                if isinstance(value,list):
                    if key in ('centerBlender','hingeBlender'):return [v*author_scale for v in value]
                    return [scaled_fx(v,key) for v in value]
                if isinstance(value,(int,float)) and (key.endswith('Studs') or key in ('radius','height','tailEnvelope')):return value*author_scale
                return value
            data=scaled_fx(data)
        (out/name).write_text(json.dumps(data,indent=2))
bpy.ops.export_scene.fbx(filepath=str(out/f'{stem}-visual.fbx'),use_selection=True,object_types={'MESH'},axis_forward='Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
bpy.ops.wm.obj_export(filepath=str(out/f'{stem}-visual.obj'),export_selected_objects=True,forward_axis='Z',up_axis='Y',export_materials=True)
scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.render.engine='CYCLES';scene.cycles.samples=8
scene.render.filepath=str(out/'exterior.png')
bpy.ops.wm.save_as_mainfile(filepath=str(out/f'{stem}.blend'))
camera=scene.camera
def render(name,pos=None,target=None,inside=False):
    if pos:
        camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    if inside:camera.data.type='PERSP';camera.data.lens=16;camera.data.clip_start=.05
    scene.render.filepath=str(out/name);bpy.ops.render.render(write_still=True)
# Preview doors open; the saved file and exported geometry stay in closed pose.
for h in hinges:
    pivot=Vector(h['hingeBlender']);transform=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(h['openDegrees']),4,'Z')@Matrix.Translation(-pivot)
    for o in door_objects:
        if o.get('section')==h['name']:o.matrix_world=transform@o.matrix_world
render('exterior.png')
# Interior preview uses a temporary soft fill; it is never exported.
light=bpy.data.lights.new('REVIEW_InteriorFill','AREA');lamp=bpy.data.objects.new(light.name,light);scene.collection.objects.link(lamp)
lamp.location=((x0+x1)/2,(y0+y1)/2,ceiling-.4);light.energy=350;light.size=8
render('interior.png',((x0+x1)/2,y0+.7,floor+5.2),((x0+x1)/2,y1-1,floor+4),True)
render('entry.png',(dx,dy-5,threshold+4.2),(dx,y0+4,floor+4),True)
print('WALKIN_COMPLETE '+json.dumps({'id':slug,'folder':out.name,'probes':len(samples),'triangles':report['triangles']}),flush=True)
