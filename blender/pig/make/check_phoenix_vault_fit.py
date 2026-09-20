"""Review Phoenix with runtime-sized vaults in the actual dial frame; no scene edits."""
from pathlib import Path
import bpy,math,json,hashlib,re
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];REPO=ROOT.parents[1];OUT=ROOT.parents[1]/'assets/skins/animal/legendary/phoenix'
runtime=REPO/'src/ServerScriptService/Services/PiggyBank.luau';config=REPO/'src/ReplicatedStorage/Shared/Config.luau'
code=runtime.read_text(encoding='utf-8');cfg=config.read_text(encoding='utf-8')
def constant(name):return float(re.search(r'local '+name+r' = ([0-9.]+)',code)[1])
body_y=constant('BODY_Y');radius=constant('BODY_R');drop=constant('DIAL_Y')-body_y
N=Vector((0,math.sqrt(radius*radius-drop*drop),drop)).normalized();U=Vector((1,0,0));V=N.cross(U).normalized()
O=Vector((0,0,body_y-(.5+1.02*6)))
seat=O+N*(radius+constant('MESH_DIAL_OUT'))
tiers=[dict(name=n,rgb=tuple(map(int,(r,g,b))),radius=float(rad),spokes=int(sp)) for n,r,g,b,rad,sp in re.findall(r'name = "(Iron|Bronze|Steel|Gold)", metal = Color3.fromRGB\((\d+), (\d+), (\d+)\), radius = ([0-9.]+), spokes = (\d+)',cfg)]
source=OUT/'phoenix-complete.blend';digest=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source));scene=bpy.context.scene;scene.frame_set(55)
vertices=[];polys=[];deps= bpy.context.evaluated_depsgraph_get()
for ob in list(scene.objects):
    if ob.type=='MESH' and 'Feathers' in ob.name:
        ev=ob.evaluated_get(deps);m=ev.to_mesh();offset=len(vertices)
        vertices.extend([ev.matrix_world@v.co for v in m.vertices]);polys.extend([tuple(offset+i for i in p.vertices) for p in m.polygons]);ev.to_mesh_clear()
tree=BVHTree.FromPolygons(vertices,polys)
fit=[]
for tier in tiers:
    gaps=[]
    for i in range(128):
        direction=U*math.cos(i*math.tau/128)+V*math.sin(i*math.tau/128)
        gap=2.0
        for j in range(81):
            dr=j*.025
            if tree.ray_cast(O+N*12+direction*(tier['radius']+dr),-N,9)[0] is not None:gap=dr;break
        gaps.append(gap)
    fit.append(dict(tier=tier['name'],radius=tier['radius'],maxBareGap=max(gaps),meanBareGap=sum(gaps)/len(gaps),gapByAngle=gaps))
def linear(rgb):return tuple(c/255/12.92 if c/255<=.04045 else ((c/255+.055)/1.055)**2.4 for c in rgb)
def material(name,rgb):
    m=bpy.data.materials.new(name);m.diffuse_color=(*linear(rgb),1);m.use_nodes=True
    p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Metallic'].default_value=.7;p.inputs['Roughness'].default_value=.33;return m
created=[]
def cylinder(name,r,depth,out,mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=r,depth=depth,location=seat+N*out)
    ob=bpy.context.object;ob.name=name;ob.rotation_euler=N.to_track_quat('Z','Y').to_euler();ob.data.materials.append(mat);created.append(ob)
for tier in tiers:
    if tier['name'] not in ('Iron','Gold'):continue
    metal=material('Vault_'+tier['name'],tier['rgb']);dark=material('VaultFace',(38,30,34));plate=material('VaultPlate',tuple(round(c*.55+d*.45) for c,d in zip(tier['rgb'],(24,24,28))))
    cylinder('Review_DialPlate',tier['radius'],constant('DIAL_THICK'),0,plate)
    cylinder('Review_DialFace',tier['radius']*.66,.5,constant('FACE_OUT'),dark)
    cylinder('Review_DialHub',.4,.5,constant('HUB_OUT'),metal)
    reach=tier['radius']*.66
    for i in range(tier['spokes']):
        a=i*math.tau/tier['spokes'];d=U*math.cos(a)+V*math.sin(a);side=N.cross(d)
        bpy.ops.mesh.primitive_cube_add(size=1,location=seat+N*constant('SPOKE_OUT')+d*(reach/2+.24))
        ob=bpy.context.object;ob.name='Review_DialSpoke';ob.rotation_euler=Matrix((N,d,side)).transposed().to_euler();ob.scale=(.4,reach,.3);ob.data.materials.append(metal);created.append(ob)
    cam=scene.camera;cam.location=(0,35,8);cam.rotation_euler=(Vector((0,1,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=24
    scene.render.resolution_x=760;scene.render.resolution_y=760;scene.cycles.samples=12
    scene.render.filepath=str(OUT/f'phoenix-vault-{tier["name"].lower()}.png');bpy.ops.render.render(write_still=True)
    for ob in created:bpy.data.objects.remove(ob,do_unlink=True)
    created=[]
report=dict(sceneSHA256=digest,runtimeSHA256=hashlib.sha256(runtime.read_bytes()).hexdigest(),configSHA256=hashlib.sha256(config.read_bytes()).hexdigest(),axisOrigin=list(O),normal=list(N),seat=list(seat),fit=fit)
report['method']='128 radial samples per tier in the runtime dial frame; Blender reconstruction of runtime plate/wheel dimensions, not a Studio screenshot'
report['previews']={f:hashlib.sha256((OUT/f).read_bytes()).hexdigest() for f in ('phoenix-vault-iron.png','phoenix-vault-gold.png')}
(OUT/'vault-fit-checks.json').write_text(json.dumps(report,indent=2))
assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
print('VAULT_FIT',json.dumps({t['tier']:t['maxBareGap'] for t in fit}))
assert all(t['maxBareGap']==0 for t in fit), 'Bare gap remains around a fitted vault'
