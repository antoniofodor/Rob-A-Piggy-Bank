"""Rainbow Tiger piggy silhouette, black coat and swept silver tiger ruff.

Blender -b -t 4 --python-exit-code 1 --python this_file.py -- [--draft]
Works on copies of the shared pig. No source overwrite or runtime installation.
"""
from pathlib import Path
import bpy,bmesh,math,json,hashlib,sys
from mathutils import Vector,Quaternion
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform,tessellate_polygon

ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'skins/rainbowtiger/legendary-v1';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'pig/pig_parts.blend';OLD=ROOT/'skins/rainbowtiger/rainbowtiger.blend'
INPUTS={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (SOURCE,OLD,OLD.parent/'rainbowtiger_body_color.png',OLD.parent/'rainbowtiger_trim_color.png')}
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

# Individually outlined broad tiger markings, authored from the supplied hero
# reference. Project the silhouettes onto the pig, then mirror the other flank.
# Unlike a repeated ribbon, each patch has its own width, bends and taper.
OUTLINES=[
 ('Coral',[(272,350),(287,373),(325,386),(346,419),(391,451),(342,434),(320,411),(280,400),(269,379)]),
 ('Orange',[(244,432),(274,452),(294,470),(333,482),(362,501),(386,557),(436,630),(369,590),(333,541),(272,513),(250,480)]),
 ('Gold',[(185,499),(210,520),(233,541),(263,551),(300,574),(330,628),(351,639),(400,653),(445,685),(468,727),(519,791),(450,744),(397,693),(347,683),(312,671),(278,637),(258,594),(211,561)]),
 ('Lime',[(169,566),(189,595),(216,607),(235,624),(272,688),(308,711),(374,734),(399,747),(460,805),(418,798),(373,767),(312,754),(270,728),(219,655),(194,641),(180,626)]),
 ('Cyan',[(172,653),(197,681),(226,700),(260,749),(289,778),(315,791),(355,797),(394,815),(358,820),(327,813),(299,799),(242,753),(215,723),(187,706)]),
 ('Blue',[(198,738),(227,769),(258,791),(313,819),(354,835),(426,849),(374,854),(318,842),(267,818),(229,790)]),
 ('Violet',[(247,803),(281,834),(323,854),(376,868),(404,870),(360,877),(309,860),(277,840)])
]
view=Vector((-23,-31,16)).normalized();rotation=(-view).to_track_quat('-Z','Y')
right=rotation@Vector((1,0,0));up=rotation@Vector((0,1,0))
stripe_parts=[]
for tone,outline in OUTLINES:
    planar=[Vector(((x-455)/350,(610-y)/350,0)) for x,y in outline]
    bm=bmesh.new();lookup={}
    for tri in tessellate_polygon([planar]):
        vv=[]
        for co in tri:
            if isinstance(co,int):co=planar[co]
            key=tuple(co)
            if key not in lookup:lookup[key]=bm.verts.new(co)
            vv.append(lookup[key])
        bm.faces.new(vv)
    bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=3,use_grid_fill=True)
    bm.verts.ensure_lookup_table();bm.verts.index_update()
    verts=[]
    for v in bm.verts:
        origin=right*v.co.x+up*v.co.y+view*4
        hit,n,idx,_=tree.ray_cast(origin,-view,6)
        assert hit is not None,('reference outline misses body',tone,tuple(v.co))
        aa,bb,cc=[body.data.vertices[i] for i in triangles[idx]]
        normal=barycentric_transform(hit,aa.co,bb.co,cc.co,aa.normal,bb.normal,cc.normal).normalized()
        verts.append(tuple(hit+normal*.018))
    faces=[tuple(v.index for v in f.verts) for f in bm.faces];bm.free()
    ob=mesh('PrismStripe_'+tone,verts,faces,tone)
    select([ob]);sol=ob.modifiers.new('Inset thickness','SOLIDIFY');sol.thickness=.032;sol.offset=-1
    bpy.ops.object.modifier_apply(modifier=sol.name)
    # Mirror closed geometry without welding unrelated tapered tips.
    count=len(ob.data.vertices);vv=[tuple(v.co) for v in ob.data.vertices]
    ff=[tuple(p.vertices) for p in ob.data.polygons]
    vv += [(-x,y,z) for x,y,z in vv]
    ff += [tuple(count+i for i in reversed(f)) for f in ff]
    ob.data.clear_geometry();ob.data.from_pydata(vv,[],ff);ob.data.update()
    for f in ob.data.polygons:f.use_smooth=True
    stripe_parts.append(ob)

# Continue each existing flank marking over the rear hemisphere. Endpoints
# are measured from the authored patches so the extension meets that stripe.
# Taper beside the central tail/vault area, as in the reference's rear view.
for k,source in enumerate(stripe_parts):
    tone=source['tone'];pts=[v.co.copy() for v in source.data.vertices if v.co.x<0]
    amin=min(math.atan2(-p.x,p.y) for p in pts);join=amin+.28
    band=[p.z for p in pts if abs(math.atan2(-p.x,p.y)-join)<.08]
    lo,hi=min(band),max(band);zjoin=(lo+hi)/2;width=min(.075,(hi-lo)*.36)
    begin=[.32,.29,.33,.40,.53,.64,.79][k]
    vv=[];ff=[];rows=33;cols=3
    for side in (-1,1):
        start=len(vv)
        for j in range(rows):
            t=j/(rows-1);angle=begin+(join-begin)*t
            # A few broad irregular bends, preserving the hand-shaped look.
            z=zjoin+(.055+.008*(k%3))*(1-t)+.023*math.sin(t*math.pi*2+(k%2)*.7)*math.sin(t*math.pi)
            w=width*min(1,t*5+.015)*(1+.17*math.sin(t*math.pi*3+k))
            direction=Vector((side*math.sin(angle),math.cos(angle),0))
            for layer in (0,1):
                for q in range(cols):
                    height=z+(q-1)*w
                    hit,n,idx,_=tree.ray_cast(direction*3+Vector((0,0,height)),-direction,3.5)
                    assert hit is not None,('rear stripe missed',tone)
                    aa,bb,cc=[body.data.vertices[i] for i in triangles[idx]]
                    normal=barycentric_transform(hit,aa.co,bb.co,cc.co,aa.normal,bb.normal,cc.normal).normalized()
                    vv.append(tuple(hit+normal*(.0178 if layer==0 else -.014)))
        def ix(j,l,q):return start+j*cols*2+l*cols+q
        for j in range(rows-1):
            for layer in (0,1):
                for q in range(cols-1):ff.append((ix(j,layer,q),ix(j+1,layer,q),ix(j+1,layer,q+1),ix(j,layer,q+1)))
            for q in (0,cols-1):ff.append((ix(j,0,q),ix(j,1,q),ix(j+1,1,q),ix(j+1,0,q)))
        for j in (0,rows-1):
            for q in range(cols-1):ff.append((ix(j,0,q),ix(j,0,q+1),ix(j,1,q+1),ix(j,1,q)))
    ob=mesh('RearStripe_'+tone,vv,ff,tone)
    for f in ob.data.polygons:f.use_smooth=True

# Small paired forehead markings converge inward above the eyes, matching the
# reference's exposed facial stripes. Use front projection, not flank wrapping.
for number,(tone,outline) in enumerate([
 ('Orange',[(.38,.77),(.30,.785),(.255,.745),(.215,.705),(.115,.615),(.235,.654),(.29,.686)]),
 ('Gold',[(.40,.615),(.305,.61),(.25,.584),(.205,.548),(.095,.467),(.215,.500),(.29,.522)])]):
    for side in (-1,1):
        pts=[Vector((side*x,z,0)) for x,z in outline];bm=bmesh.new();lookup={}
        for tri in tessellate_polygon([pts]):
            vv=[]
            for co in tri:
                if isinstance(co,int):co=pts[co]
                key=tuple(co)
                if key not in lookup:lookup[key]=bm.verts.new(co)
                vv.append(lookup[key])
            bm.faces.new(vv)
        bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=3,use_grid_fill=True)
        bm.verts.ensure_lookup_table();bm.verts.index_update();vv=[]
        for v in bm.verts:
            hit,n,idx,_=tree.ray_cast(Vector((v.co.x,-3,v.co.y)),Vector((0,1,0)),4)
            assert hit is not None,'Forehead marking missed body'
            aa,bb,cc=[body.data.vertices[i] for i in triangles[idx]]
            normal=barycentric_transform(hit,aa.co,bb.co,cc.co,aa.normal,bb.normal,cc.normal).normalized()
            vv.append(tuple(hit+normal*.019))
        ob=mesh(f'FaceStripe_{tone}_{side}',vv,[tuple(v.index for v in f.verts) for f in bm.faces],tone);bm.free()
        select([ob]);mod=ob.modifiers.new('Inset forehead marking','SOLIDIFY');mod.thickness=.031;mod.offset=-1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for f in ob.data.polygons:f.use_smooth=True

# Swept curved locks, with rounded cross sections and flowing tapered ends.
# The curve is deliberately broad: no rigid diamonds or stacked plate pattern.
tuft_groups={};tuft_uv={}
def tuft(group,base,tip,width,thickness,tone,bone,bend=(0,0,0),gradient_u=None,gradient_top=1):
    base,tip,bend=Vector(base),Vector(tip),Vector(bend)
    axis=(tip-base).normalized();front=Vector((0,-1,0))
    if abs(axis.dot(front))>.94:front=Vector((0,0,1))
    across=axis.cross(front).normalized();front=across.cross(axis).normalized()
    vv,ff=tuft_groups.setdefault((group,tone,bone),([],[]));s=len(vv);segments=8
    profile=[.65,1,.92,.72,.48,.25,.075]
    for j,w in enumerate(profile):
        t=j/7;c=base.lerp(tip,t)+bend*math.sin(t*math.pi)
        for q in range(segments):
            angle=q*math.tau/segments
            vv.append(tuple(c+across*(width*w*math.cos(angle))+front*(thickness*w*math.sin(angle))))
    vv.append(tuple(tip))
    if gradient_u is not None:
        uv=tuft_uv.setdefault((group,tone,bone),[])
        uv.extend([(gradient_u,j/7*gradient_top) for j in range(7) for q in range(segments)]+[(gradient_u,gradient_top)])
    ff.append(tuple(s+i for i in reversed(range(segments))))
    for j in range(len(profile)-1):
        for q in range(segments):ff.append((s+j*segments+q,s+j*segments+(q+1)%segments,s+(j+1)*segments+(q+1)%segments,s+(j+1)*segments+q))
    for q in range(segments):ff.append((s+6*segments+q,s+6*segments+(q+1)%segments,s+7*segments))

for side in (-1,1):
    bone='Ruff_L' if side<0 else 'Ruff_R'
    for row,y in enumerate((-.81,-.70,-.58)):
        for j in range(6):
            angle=math.radians(58+j*14+row*3)
            hit,n=surface(y,angle,side);base=hit-n*.055
            # Locks sweep backward along the coat and curl down at their ends.
            tip=hit+Vector((side*(.17+.035*math.sin(j)),.16+row*.018,-.27-.045*((j+row)%3)))
            tuft(bone,base,tip,.125+.012*(j%3),.047,'Ruff' if row!=1 else 'RuffShade',bone,(side*.12,-.055,.02))
    for j in range(3):
        tuft('Cheek_'+bone,(side*(.44+j*.05),-.87,.25-j*.10),(side*(.72+j*.035),-.59,.18-j*.16),.095,.065,'Ruff',bone,(side*.07,-.07,.07))
    for j in range(4):
        tuft('EarFur', (side*(.48+j*.045),-.445,.76+j*.02), (side*(.48+j*.056),-.43,1.03+j*.027),.047,.036,'Ruff','Root',(side*.025,-.05,.04))
    # Inner corners angle downward; the glow remains visible below the brow.
    tuft('Brow', (side*.46,-.865,.49),(side*.235,-1.015,.407),.064,.048,'Coat','Root',(0,-.035,.028))

# Connected ankle fur cuffs: dark outer fur with a short silver under-fringe.
# Shared sculpted surfaces hug the leg rather than separate bead/claw shapes.
for side in (-1,1):
    for foot,y in enumerate((-.46,.51)):
        center=Vector((side*.49,y,0));count=40
        for layer,tone in enumerate(('Ruff','Cuff')):
            verts=[];faces=[]
            for inner in (0,1):
                for ring in range(3):
                    for q in range(count):
                        j=q//4;f=q%4;angle=q*math.tau/count+(.105 if layer==0 else 0)
                        tooth=[0,.42,1,.46][f]
                        length=.105+.036*math.sin(j*2.1+foot)
                        z=[-.625,-.715,-.758-length*tooth][ring]-(.01 if layer==0 else 0)
                        radius=[.223,.264,.254+.025*tooth][ring]+(.012 if layer==1 else 0)-inner*.022
                        # A small ridge on each fur point provides faceted volume.
                        if ring==1:radius+=.047*math.sin(f*math.pi/4)
                        verts.append(tuple(center+Vector((radius*math.cos(angle),radius*math.sin(angle),z))))
            def ix(inner,ring,q):return inner*3*count+ring*count+(q%count)
            for inner in (0,1):
                for ring in (0,1):
                    for q in range(count):faces.append((ix(inner,ring,q),ix(inner,ring,q+1),ix(inner,ring+1,q+1),ix(inner,ring+1,q)))
            for ring in (0,2):
                for q in range(count):faces.append((ix(0,ring,q),ix(1,ring,q),ix(1,ring,q+1),ix(0,ring,q+1)))
            mesh(f'FootCuff_{side}_{foot}_{tone}',verts,faces,tone)

tail_pivot=Vector((0,.77,.29))
# One continuous furry plume. Color is a UV gradient on the actual locks,
# rather than separate colored solids sitting on the tips.
for j in range(7):
    phi=math.tau*j/7;x=.084*math.cos(phi);z=.085*math.sin(phi)
    base=Vector((x*.48,1.31,.55+z*.2));end=Vector((x*1.55,1.52+.055*math.sin(phi),1.00+z))
    tuft('TailPlume',base,end,.110,.077,'Ruff','Tail',(x*.55,.105,-.012),gradient_u=(j+.5)/7)
for j in range(9):
    phi=math.tau*j/9;dx=math.cos(phi);dy=math.sin(phi)
    tuft('TailPlume',(.045*dx,1.34+.045*dy,.60),(.155*dx,1.48+.10*dy,.86+.035*(j%3)),.081,.058,'Ruff','Tail',(.045*dx,.06*dy,.018),gradient_u=(j+.5)/9,gradient_top=.60)
for (name,tone,bone),(v,f) in tuft_groups.items():
    ob=mesh(name+'_'+tone if name in ('Ruff_L','Ruff_R','FootTufts') else name,v,f,tone,bone)
    for f in ob.data.polygons:f.use_smooth=True
    if (name,tone,bone) in tuft_uv:
        coords=tuft_uv[(name,tone,bone)];uv=ob.data.uv_layers.new(name='TailGradientUV')
        for loop in ob.data.loops:uv.data[loop.index].uv=coords[loop.vertex_index]
        ob['colorTexture']='rainbowtiger-tail-gradient.png'
        image=bpy.data.images.new('RainbowTiger_TailGradient',width=256,height=256,alpha=True)
        pixels=[];base_rgb=linear((202,207,217));palette=[linear(RGB[h]) for h in HUES]
        for y in range(256):
            v=y/255;fade=max(0,min(1,(v-.38)/.48));fade=fade*fade*(3-2*fade)
            for x in range(256):
                u=x/255*(len(palette)-1);i=min(len(palette)-2,int(u));f=u-i
                color=[palette[i][c]*(1-f)+palette[i+1][c]*f for c in range(3)]
                pixels.extend([base_rgb[c]*(1-fade)+color[c]*fade for c in range(3)]+[1])
        image.pixels=pixels;image.filepath_raw=str(OUT/'rainbowtiger-tail-gradient.png');image.file_format='PNG';image.save();image.pack()
        mat=mats['Ruff'].copy();mat.name='RainbowTiger_TailGradient';nodes=mat.node_tree.nodes
        tex=nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Linear'
        mat.node_tree.links.new(tex.outputs['Color'],nodes['Principled BSDF'].inputs['Base Color'])
        ob.data.materials.clear();ob.data.materials.append(mat)

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
    checks.append({'name':o.name,'bone':o['bone'],'tone':o['tone'],'colorRGB':RGB[o['tone']],'triangles':len(o.data.polygons),'nonManifoldEdges':bad,'colorTexture':o.get('colorTexture')})
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
motion=[]
for i,tone in enumerate(HUES):
    b=mats[tone].node_tree.nodes['Principled BSDF'];b.inputs['Emission Color'].default_value=(*linear(RGB[tone]),1)
    for frame in range(1,122,4):
        pulse=(.5-.5*math.cos(math.tau*((frame-1)/120-i/len(HUES))))**4
        b.inputs['Emission Strength'].default_value=.08+.95*pulse;b.inputs['Emission Strength'].keyframe_insert('default_value',frame=frame)
    motion.append({'part':'PrismStripe_'+tone,'alsoParts':[o.name for o in parts if o.name.startswith(('FaceStripe_'+tone,'RearStripe_'+tone))],'colorRGB':RGB[tone],'phase':i/len(HUES),'emissionMin':.08,'emissionMax':1.03})
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
assert sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)==sum(row['triangles'] for row in checks)
assert all(o.vertex_groups for o in meshes),'FBX lost weights'
import_tail=next(o for o in meshes if o.name.startswith('TailPlume'))
assert import_tail.data.uv_layers,'Tail gradient UVs lost in FBX'
assert any(n.type=='TEX_IMAGE' and n.image for m in import_tail.data.materials for n in m.node_tree.nodes),'FBX lost tail color texture'

for o in imports:bpy.data.objects.remove(o,do_unlink=True)
scene.frame_set(1)
report={'skin':'rainbowtiger','rarity':'legendary','chest':'animal','status':'Black tiger revision for review; Studio integration pending','design':'Black charcoal piggy, swept silver ruff, ear and foot tufts, continuous gradient tail fur, inner forehead markings, determined brows and individually outlined broad rainbow markings; no mohawk','inputHashes':INPUTS,'preservedSourceParts':preserved,'meshCount':len(parts),'triangles':sum(r['triangles'] for r in checks),'meshes':checks,'sourceToStudScale':6,'bodyWidthStuds':12,'boundsStuds':before,'fbxRoundTripBoundsError':error,'addedGeometryVaultBlocked':blocked,'animation':{'periodSeconds':4,'fps':30,'frames':[1,121],'bones':{n:{'pivotStuds':list(v),'parent':p} for n,(v,p) in bones.items()},'tailSwayDegrees':3,'ruffSwayDegrees':1.2,'pulseCurve':'(0.5 - 0.5*cos(2*pi*(time/4-phase)))^4','groups':motion,'notes':'Idle FBX contains bone motion. Material pulse stays in Blender and must be implemented by Fable on the named flank and forehead stripe parts; do not tint Body. No particle aura.'}}
report['animation']['tailColor']={'part':'TailPlume','colorTexture':'rainbowtiger-tail-gradient.png','behavior':'Continuous UV-mapped silver-to-rainbow color on the fur; preserve the texture rather than applying flat Color. Tail moves with its bone.','sha256':hashlib.sha256((OUT/'rainbowtiger-tail-gradient.png').read_bytes()).hexdigest()}
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
