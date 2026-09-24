"""Build the seven OG refreshes without altering live Config or shared pig meshes.

blender -b --python assets/piggies/og-refresh-v2/build.py -- --skin marble
Each skin owns a procedural source, packed animated review, FBXs, maps and renders.
"""
from pathlib import Path
import argparse, colorsys, hashlib, json, math, random, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SPECS = json.loads((HERE/'design-specs.json').read_text())['skins']
argv = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument('--skin', required=True)
parser.add_argument('--quick', action='store_true')
ARGS = parser.parse_args(argv)
SPEC = next(s for s in SPECS if s['key']==ARGS.skin)
KEY, TIER = SPEC['key'], SPEC['tier']
HOME = ROOT/'assets/piggies'/TIER/KEY/'revisions/og-v2'
for room in ('source','generate','sheets','preview','package'):(HOME/room).mkdir(parents=True,exist_ok=True)
CORE = ('Body','Snout','Ears','Legs','Tail','EyePreview')
SOURCE = ROOT/'assets/piggies/common/cow/source/cow_closed.blend'
random.seed(20260923 + sum(map(ord,KEY)))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene;scene.name = SPEC['name']+' - OG v2'
scene.render.fps=24;scene.frame_start=1;scene.frame_end=145
asset=bpy.data.collections.new('ASSET - mesh and coat');scene.collection.children.link(asset)
fxcol=bpy.data.collections.new('FX - animated geometry');scene.collection.children.link(fxcol)
auracol=bpy.data.collections.new('AURA - preview only; use Roblox emitter');scene.collection.children.link(auracol)
stage=bpy.data.collections.new('REVIEW - cameras and lights');scene.collection.children.link(stage)
with bpy.data.libraries.load(str(SOURCE),link=False) as (a,b):b.objects=list(CORE)
parts=dict(zip(CORE,b.objects));assert all(parts.values())
for name,ob in parts.items():
    asset.objects.link(ob);ob.name=name;ob.hide_render=False;ob.hide_viewport=False;ob.hide_select=False;ob.hide_set(False)
    for modifier in list(ob.modifiers):ob.modifiers.remove(modifier)
    for face in ob.data.polygons:face.use_smooth=True
def signature(ob):
    return hashlib.sha256(json.dumps(([list(v.co) for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons],[[list(v.uv) for v in uv.data] for uv in ob.data.uv_layers])).encode()).hexdigest()
signatures={n:signature(o) for n,o in parts.items()}
def lin(rgb):return tuple(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb)
def assign(ob,mat):
    ob.data.materials.clear();ob.data.materials.append(mat)
    for p in ob.data.polygons:p.material_index=0
def move(ob,col):
    for c in list(ob.users_collection):c.objects.unlink(ob)
    col.objects.link(ob)
def flat(name,rgb,emission=0,metal=0,rough=.6):
    m=bpy.data.materials.new(KEY+'_'+name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*lin(rgb),1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    p.inputs['Specular IOR Level'].default_value=.3
    p.inputs['Emission Color'].default_value=(*lin(rgb),1);p.inputs['Emission Strength'].default_value=emission
    m.diffuse_color=(*lin(rgb),1)
    return m

class Paint:
    def __init__(self,name,base):
        self.mat=flat(name,base);self.nt=self.mat.node_tree;self.n=self.nt.nodes;self.l=self.nt.links
        self.bs=self.n.get('Principled BSDF')
        self.tex=self.n.new('ShaderNodeTexCoord').outputs['Object']
        n=self.n.new('ShaderNodeSeparateXYZ');self.l.new(self.tex,n.inputs[0])
        self.x,self.y,self.z=(n.outputs[k] for k in 'XYZ')
        self.color=self.rgb(base);self.glow=0;self.metal=0;self.rough=.65
    def rgb(self,v):
        n=self.n.new('ShaderNodeRGB');n.outputs[0].default_value=(*lin(v),1);return n.outputs[0]
    def wire(self,v,s):
        if isinstance(v,(int,float)):s.default_value=(v,v,v,1) if s.type=='RGBA' else v
        else:self.l.new(v,s)
    def op(self,kind,a,b=0):
        n=self.n.new('ShaderNodeMath');n.operation=kind;self.wire(a,n.inputs[0]);self.wire(b,n.inputs[1]);return n.outputs[0]
    def vec(self,x,y,z):
        n=self.n.new('ShaderNodeCombineXYZ')
        for v,s in zip((x,y,z),n.inputs):self.wire(v,s)
        return n.outputs[0]
    def noise(self,scale,detail=2,vec=None):
        n=self.n.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=scale;n.inputs['Detail'].default_value=detail;n.inputs['Roughness'].default_value=.55
        self.l.new(vec or self.tex,n.inputs['Vector']);return n.outputs['Fac']
    def vor(self,scale,feature='DISTANCE_TO_EDGE',vec=None):
        n=self.n.new('ShaderNodeTexVoronoi');n.feature=feature;n.inputs['Scale'].default_value=scale
        self.l.new(vec or self.tex,n.inputs['Vector']);return n
    def mix(self,a,b,f):
        n=self.n.new('ShaderNodeMixRGB');self.wire(f,n.inputs[0])
        for v,s in zip((a,b),n.inputs[1:3]):
            if isinstance(v,(list,tuple)):s.default_value=(*lin(v),1)
            else:self.l.new(v,s)
        return n.outputs[0]
    def ramp(self,f,colors,interpolation='LINEAR'):
        n=self.n.new('ShaderNodeValToRGB');n.color_ramp.interpolation=interpolation
        for i,c in enumerate(colors):
            e=n.color_ramp.elements[i] if i<2 else n.color_ramp.elements.new(i/(len(colors)-1))
            e.position=i/(len(colors)-1);e.color=(*lin(c),1)
        self.l.new(f,n.inputs[0]);return n.outputs['Color']
    def ellipse(self,axes,center,radii):
        d=0
        for a,c,r in zip(axes,center,radii):
            q=self.op('DIVIDE',self.op('SUBTRACT',a,c),r);d=self.op('ADD',d,self.op('MULTIPLY',q,q))
        return self.op('LESS_THAN',d,1)
    def stripe(self,phase,width):
        return self.op('LESS_THAN',self.op('ABSOLUTE',self.op('SINE',phase)),width)
    def finish(self):
        self.l.new(self.color,self.bs.inputs['Base Color']);self.l.new(self.color,self.bs.inputs['Emission Color'])
        self.wire(self.opacity,self.bs.inputs['Alpha']);self.wire(self.glow,self.bs.inputs['Emission Strength']);self.wire(self.metal,self.bs.inputs['Metallic']);self.wire(self.rough,self.bs.inputs['Roughness'])
        for label,value in [('BAKE_COLOR',self.color),('BAKE_EMISSIVE',self.glow),('BAKE_METAL',self.metal),('BAKE_ROUGH',self.rough),('BAKE_ALPHA',self.opacity)]:
            node=self.n.new('ShaderNodeEmission');node.label=label;node.name=label
            self.wire(value,node.inputs['Color'])
        return self.mat

exec(compile((HERE/'paint.py').read_text(),str(HERE/'paint.py'),'exec'))

extras=[];aura=[]
def mesh(name,verts,faces,material,col=fxcol):
    data=bpy.data.meshes.new(KEY+'_'+name);data.from_pydata(verts,[],faces);data.update()
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    ob=bpy.data.objects.new(name,data);col.objects.link(ob);assign(ob,material)
    (aura if col==auracol else extras).append(ob);return ob
def crystal(name,base,direction,radius,material,sides=6):
    base=Vector(base);d=Vector(direction);axis=d.normalized();ref=Vector((0,1,0))
    if abs(ref.dot(axis))>.9:ref=Vector((1,0,0))
    u=axis.cross(ref).normalized();v=axis.cross(u).normalized();verts=[]
    if name.startswith('OrbitPrism'):
        for i in range(4):
            a=math.tau*i/4;verts.append(base+d*.5+radius*(math.cos(a)*u+math.sin(a)*v))
        verts.extend([base,base+d]);faces=[]
        for i in range(4):faces.extend([(4,(i+1)%4,i),(5,i,(i+1)%4)])
        return mesh(name,verts,faces,material)
    for t,r in [(0,.8),(.65,1)]:
        for i in range(sides):
            a=math.tau*i/sides;verts.append(base+d*t+radius*r*(math.cos(a)*u+math.sin(a)*v))
    verts.extend([base-axis*.03,base+d]);faces=[]
    for i in range(sides):
        j=(i+1)%sides;faces.extend([(i,j,j+sides,i+sides),(2*sides,j,i),(2*sides+1,i+sides,j+sides)])
    return mesh(name,verts,faces,material)
def tube(name,points,radii,material,col=fxcol,sides=7):
    points=list(map(Vector,points));verts=[]
    for i,p in enumerate(points):
        d=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
        ref=Vector((0,0,1)) if abs(d.z)<.9 else Vector((0,1,0))
        u=d.cross(ref).normalized();v=d.cross(u).normalized()
        for j in range(sides):
            a=j*math.tau/sides;verts.append(p+radii[i]*(math.cos(a)*u+math.sin(a)*v))
    faces=[]
    for i in range(len(points)-1):
        for j in range(sides):
            k=i*sides+j;l=i*sides+(j+1)%sides;faces.append((k,l,l+sides,k+sides))
    faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))])
    return mesh(name,verts,faces,material,col)
def loop_bob(ob,height=.05,phase=0):
    start=ob.location.copy()
    for f in (1,37,73,109,145):
        ob.location=start+Vector((0,0,height*math.sin((f-1)/144*math.tau+phase)))
        ob.keyframe_insert(data_path='location',frame=f)
    ob['motion']='bob';ob['bobSourceUnits']=height
def loop_spin(ob):
    ob.rotation_euler.z=0;ob.keyframe_insert(data_path='rotation_euler',frame=1)
    ob.rotation_euler.z=math.tau;ob.keyframe_insert(data_path='rotation_euler',frame=145)
    ob['motion']='orbit';ob['periodSeconds']=6
    if ob.animation_data:
        action=ob.animation_data.action
        for slot in action.slots:
            for layer in action.layers:
                for strip in layer.strips:
                    bag=strip.channelbag(slot)
                    if bag:
                        for curve in bag.fcurves:
                            for point in curve.keyframe_points:point.interpolation='LINEAR'

def loop_sway(ob,phase=0):
    # Keep the moving halo in the rear hemisphere for its entire loop.
    # A full revolution would pass straight through the face and snout.
    for frame in (1,37,73,109,145):
        ob.rotation_euler.z=.07*math.sin((frame-1)/144*math.tau+phase)
        ob.keyframe_insert(data_path='rotation_euler',frame=frame)
    ob['motion']='orbital sway';ob['periodSeconds']=6

exec(compile((HERE/'geometry.py').read_text(),str(HERE/'geometry.py'),'exec'))

assert signatures=={n:signature(o) for n,o in parts.items()}
scene['skinKey']=KEY;scene['revision']='og-refresh-v2';scene['tier']=TIER;scene['aura']=SPEC['aura'] or ''
scene['design']=SPEC['design'];scene['runtimeStatus']='Local authoring complete; Roblox upload/integration pending'
scene.frame_set(1)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HOME/'source'/f'{KEY}-og-v2-procedural.blend'))

# Bake each material's actual 3D field to the original UVs. No UV painting.
scene.render.engine='CYCLES';scene.cycles.samples=1;scene.cycles.device='CPU'
scene.render.bake.margin=12;scene.render.bake.use_selected_to_active=False
maps={};size=1024
groups={'body':[parts['Body']],'trim':[parts[n] for n in ('Snout','Ears','Legs','Tail')]}
channels=['color','metal','rough']+(['emissive'] if KEY in ('aurora','neonmint','ghost','hologram') else [])+(['alpha'] if TIER=='epic' else [])
for group,objects in groups.items():
    materials={m for ob in objects for m in ob.data.materials};saved={}
    for mat in materials:
        output=next(n for n in mat.node_tree.nodes if n.type=='OUTPUT_MATERIAL')
        saved[mat]=output.inputs['Surface'].links[0].from_socket
    for channel in channels:
        image=bpy.data.images.new(KEY+'_'+group+'_'+channel,(size if KEY in ('ghost','hologram') else size*2),(size if KEY in ('ghost','hologram') else size*2),alpha=True)
        if channel!='color':image.colorspace_settings.name='Non-Color'
        for mat in materials:
            nt=mat.node_tree;output=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL')
            nt.links.new(nt.nodes['BAKE_'+channel.upper()].outputs[0],output.inputs['Surface'])
            tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image;nt.nodes.active=tex
        bpy.ops.object.select_all(action='DESELECT')
        for ob in objects:ob.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.bake(type='EMIT')
        image.scale(size,size)
        pixels=np.empty(size*size*4,dtype=np.float32);image.pixels.foreach_get(pixels);pixels[3::4]=1;image.pixels.foreach_set(pixels)
        path=HOME/'sheets'/f'{KEY}_og_v2_{group}_{channel}.png';image.filepath_raw=str(path);image.file_format='PNG';image.save();image.pack()
        maps[group,channel]=(image,path)
        print('BAKED',KEY,group,channel,flush=True)
    for mat in materials:
        nt=mat.node_tree;output=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');nt.links.new(saved[mat],output.inputs['Surface'])
    # Reconstruct the reviewed surface from the actual exported image maps.
    mat=flat(group+'_Baked',P[0],rough=.65);nt=mat.node_tree;p=nt.nodes['Principled BSDF']
    for channel,socket in [('color','Base Color'),('metal','Metallic'),('rough','Roughness'),('alpha','Alpha'),('emissive','Emission Strength')]:
        if (group,channel) not in maps:continue
        tex=nt.nodes.new('ShaderNodeTexImage');tex.image=maps[group,channel][0]
        nt.links.new(tex.outputs['Color'],p.inputs[socket])
        if channel=='color':nt.links.new(tex.outputs['Color'],p.inputs['Emission Color'])
    decorate_material(mat,group)
    for ob in objects:assign(ob,mat)

    # A portable RGBA color map accompanies the separate opacity map.
    if (group,'alpha') in maps:
        color=maps[group,'color'][0];alpha=maps[group,'alpha'][0]
        rgba=np.empty(size*size*4,dtype=np.float32);a=np.empty_like(rgba)
        color.pixels.foreach_get(rgba);alpha.pixels.foreach_get(a);rgba[3::4]=a[0::4]
        im=bpy.data.images.new(KEY+'_'+group+'_rgba',size,size,alpha=True)
        im.pixels.foreach_set(rgba);path=HOME/'sheets'/f'{KEY}_og_v2_{group}_rgba.png'
        im.filepath_raw=str(path);im.file_format='PNG';im.save();im.pack();maps[group,'rgba']=(im,path)

scene.frame_set(1)
motion_checks={}
if TIER!='rare':
    original={ob.name:ob.matrix_world.copy() for ob in extras+aura}
    scene.frame_set(145);bpy.context.view_layer.update()
    closure=max((max(abs(ob.matrix_world[i][j]-original[ob.name][i][j]) for i in range(4) for j in range(4)) for ob in extras+aura),default=0)
    assert closure<1e-5,('animation seam',KEY,closure)
    motion_checks['loopClosureError']=closure
    if TIER=='legendary':
        for frame in (1,19,37,55,73,91,109,127,145):
            scene.frame_set(frame);bpy.context.view_layer.update()
            for ob in extras:
                for vertex in ob.data.vertices:
                    v=ob.matrix_world@vertex.co
                    assert not (abs(v.x)<.64 and v.y<-.72 and -.60<v.z<.70),('FX in face clearance',KEY,ob.name,frame)
        motion_checks['faceClearanceSampledFrames']=9
    scene.frame_set(1)
exported=[]
for label,objects in [('complete',list(parts.values())+extras),('accessories',extras)]:
    if not objects:continue
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    path=HOME/'package'/f'{KEY}-og-v2-{label}.fbx'
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=6.0,apply_unit_scale=False,bake_space_transform=True,axis_forward='-Z',axis_up='Y',use_mesh_modifiers=False,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
    before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(path),use_anim=False)
    imported=[ob for ob in bpy.data.objects if ob not in before];import_mesh=[ob for ob in imported if ob.type=='MESH']
    expected=sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in objects)
    assert len(import_mesh)==len(objects),(KEY,label,'FBX mesh count',len(import_mesh),len(objects),[o.name for o in import_mesh])
    assert sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in import_mesh)==expected,(KEY,label,'FBX triangle count')
    def bounds(obs,factor=1):
        pts=[(ob.matrix_world@v.co)*factor for ob in obs for v in ob.data.vertices]
        return [min(p[i] for p in pts) for i in range(3)]+[max(p[i] for p in pts) for i in range(3)]
    bounds_error=max(abs(a-b) for a,b in zip(bounds(objects,6),bounds(import_mesh)))
    assert bounds_error<.001,(KEY,label,'FBX bounds',bounds_error)
    for ob in imported:bpy.data.objects.remove(ob,do_unlink=True)
    exported.append({'file':path.name,'meshCount':len(objects),'triangles':expected,'roundTripChecked':True,'roundTripBoundsError':bounds_error})

world=bpy.data.worlds.new(KEY+'_World');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(*lin((181,193,211)),1)
world.node_tree.nodes['Background'].inputs[1].default_value=.35 if TIER=='epic' else .5
def light(name,pos,power,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);stage.objects.link(ob);ob.location=pos;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
light('Key',(-3,-4,6),230 if TIER=='epic' else 340,5);light('Fill',(4,-1,3),90 if TIER=='epic' else 180,4);light('Rim',(1,4,5),310,3)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-1.025));ground=bpy.context.object;ground.name='ReviewGround';move(ground,stage);assign(ground,flat('Ground',((39,51,69) if TIER=='epic' else (166,176,189)),rough=.95))
data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',data);stage.objects.link(camera);scene.camera=camera;data.type='ORTHO';data.ortho_scale=4.0 if TIER=='legendary' else 3.45
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.transparent_max_bounces=12;scene.cycles.use_denoising=True
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.image_settings.file_format='PNG'
shots=[('hero',(-4,-6,2.8),(0,0,.08)),('back',(-4,6,2.8),(0,0,.08)),('top',(-3,-4,6),(0,0,.08))]
for name,pos,target in shots:
    camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(HOME/'preview'/f'{KEY}-og-v2-{name}.png');bpy.ops.render.render(write_still=True)
camera.location=shots[0][1];camera.rotation_euler=(Vector(shots[0][2])-camera.location).to_track_quat('-Z','Y').to_euler()
if TIER!='rare':
    # A real second animation state catches static/disconnected FX accidentally shipped as motion.
    scene.frame_set(37);scene.render.filepath=str(HOME/'preview'/f'{KEY}-og-v2-motion.png');bpy.ops.render.render(write_still=True);scene.frame_set(1)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False;area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=parts['Body']
bpy.ops.wm.save_as_mainfile(filepath=str(HOME/'package'/f'{KEY}-og-v2.blend'))
checks=[]
for ob in list(parts.values())+extras:
    bm=bmesh.new();bm.from_mesh(ob.data);nonmanifold=sum(not e.is_manifold for e in bm.edges);bm.free()
    tris=sum(len(p.vertices)-2 for p in ob.data.polygons)
    assert tris<20000 and nonmanifold==0,(KEY,ob.name,tris,nonmanifold)
    pts=[ob.matrix_world@v.co for v in ob.data.vertices];lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
    checks.append({'name':ob.name,'role':'base' if ob in parts.values() else 'accessory','triangles':tris,'nonManifoldEdges':nonmanifold,'motion':ob.get('motion'),
        'offsetRobloxStuds':[(lo[0]+hi[0])*3,(lo[2]+hi[2])*3+6.62,-(lo[1]+hi[1])*3],
        'sizeRobloxStuds':[(hi[i]-lo[i])*6 for i in (0,2,1)]})
assert signatures=={n:signature(ob) for n,ob in parts.items()}
report={'skin':KEY,'name':SPEC['name'],'tier':TIER,'revision':'og-refresh-v2','status':'Built locally; Roblox upload and installation pending','design':SPEC['design'],
    'baseGeometryAndUVPreserved':True,'sourceGeometrySignatures':signatures,'parts':checks,'exports':exported,'aura':SPEC['aura'],
    'auraPreviewObjects':len(aura),'auraExcludedFromMeshExports':True,'animation':{'frames':[1,145],'fps':24,'loopSeconds':6,'animatedGeometry':sum(bool(o.animation_data) for o in extras),'materialPulse':KEY in ('aurora','neonmint','ghost','hologram'),**motion_checks},
    'tierChecks':{'authoredCoat':True,'glowAndAura':TIER!='rare','substantialAnimatedGeometry':TIER=='legendary' and len(extras)>=6},
    'textures':[{'role':g+'_'+ch,'file':str(path.relative_to(HOME)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[1024,1024]} for (g,ch),(im,path) in maps.items()],
    'generator':'assets/piggies/og-refresh-v2/build.py','runtimeNotes':'Review asset, not installed. Ghost/Hologram need explicit alpha support and shader-equivalent runtime effects; see README. Use supplied maps on shared body/trim; replace old procedural pattern. Preserve rarity. Use existing aura key; preview motes are not export meshes. New accessories replace, not stack with, old shard/FX geometry. Full Blender animation is retained in packed blend; FBX is a static import pose.'}
(HOME/'package/og-v2-asset-report.json').write_text(json.dumps(report,indent=2)+'\n')
(HOME/'generate/og-v2-spec.json').write_text(json.dumps(SPEC,indent=2)+'\n')
print('OG_COMPLETE',KEY,json.dumps({'extraTriangles':sum(p['triangles'] for p in checks if p['role']=='accessory'),'maps':len(maps),'basePreserved':True}),flush=True)
