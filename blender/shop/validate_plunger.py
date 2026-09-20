"""Validate plunger exports and inspect its actual hollow suction cup."""
from pathlib import Path
import bpy,bmesh,json,hashlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/shop-ui/icon-system-v1'
folder=OUT/'models/plunger';source=OUT/'sources/plunger.blend';digest=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
meshes=[bpy.data.objects[n] for n in ('RubberCup','Handle')]
def bounds(obs):
 bpy.context.view_layer.update();pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices]
 return [min(p[i] for p in pts) for i in range(3)]+[max(p[i] for p in pts) for i in range(3)]
expected=bounds(meshes);counts={}
for ob in meshes:
 bm=bmesh.new();bm.from_mesh(ob.data);assert all(e.is_manifold for e in bm.edges),ob.name;bm.free()
 ob.data.calc_loop_triangles();counts[ob.name]=len(ob.data.loop_triangles);assert counts[ob.name]<20000
cup=meshes[0];tree=BVHTree.FromPolygons([cup.matrix_world@v.co for v in cup.data.vertices],[list(p.vertices) for p in cup.data.polygons])
depths=[]
for x,y in [(0,0),(.25,0),(-.25,0),(0,.25),(0,-.25)]:
 hit,_,_,_=tree.ray_cast(Vector((x,y,-2)),Vector((0,0,1)),3)
 assert hit and hit.z>-.65,(x,y,hit)
 depths.append(round(hit.z,5))
# Render an inspection view from underneath without modifying the saved model.
scene=bpy.context.scene;scene.camera.location=(4,-7,-5)
scene.camera.rotation_euler=(Vector((0,0,.1))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.ortho_scale=4.7;scene.cycles.samples=24;scene.render.filepath=str(OUT/'plunger-underside.png')
bpy.ops.render.render(write_still=True)
checks={}
for ext in ('glb','fbx'):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 if ext=='glb':bpy.ops.import_scene.gltf(filepath=str(folder/'plunger.glb'))
 else:bpy.ops.import_scene.fbx(filepath=str(folder/'plunger.fbx'))
 imported=[o for o in bpy.data.objects if o.type=='MESH'];assert {o.name for o in imported}=={'RubberCup','Handle'}
 assert not any(o.type in ('CAMERA','LIGHT') for o in bpy.data.objects)
 err=max(abs(a-b) for a,b in zip(expected,bounds(imported)));assert err<1e-4
 assert any(im.packed_file for im in bpy.data.images)
 checks[ext]={'boundsError':err,'packedPalette':True}
assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
report={'triangles':counts,'closedManifold':True,'innerCupHitsZ':depths,'exports':checks,'sourceSHA256':digest}
(folder/'validation.json').write_text(json.dumps(report,indent=2));print('PLUNGER_VERIFIED',json.dumps(report))
