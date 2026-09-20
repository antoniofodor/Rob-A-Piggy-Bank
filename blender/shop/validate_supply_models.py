"""Check both standalone supply exports, pivots, mesh budgets and material packing."""
from pathlib import Path
import bpy,bmesh,json,hashlib,math
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/shop-ui/icon-system-v1'
def bounds(obs):
 bpy.context.view_layer.update();pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices]
 return [min(p[i] for p in pts) for i in range(3)]+[max(p[i] for p in pts) for i in range(3)]
for key,names in [('coin',{'Coin'}),('bubblegum-bomb',{'GumBody','Fuse'}),('golden-bone',{'GoldenBone'})]:
 folder=OUT/'models'/key;source=OUT/f'sources/{key}.blend';digest=hashlib.sha256(source.read_bytes()).hexdigest()
 bpy.ops.wm.open_mainfile(filepath=str(source));parts=[bpy.data.objects[n] for n in names]
 expected=bounds(parts);counts={}
 for ob in parts:
  bm=bmesh.new();bm.from_mesh(ob.data);assert all(e.is_manifold for e in bm.edges),ob.name;bm.free()
  ob.data.calc_loop_triangles();counts[ob.name]=len(ob.data.loop_triangles);assert counts[ob.name]<20000
  assert ob.location.length<1e-6 and all(abs(s-1)<1e-6 for s in ob.scale)
  assert all(math.isfinite(c) for v in ob.data.vertices for c in v.co)
 checks={}
 for ext in ('glb','fbx'):
  bpy.ops.wm.read_factory_settings(use_empty=True)
  if ext=='glb':bpy.ops.import_scene.gltf(filepath=str(folder/f'{key}.glb'))
  else:bpy.ops.import_scene.fbx(filepath=str(folder/f'{key}.fbx'))
  imported=[o for o in bpy.data.objects if o.type=='MESH'];assert {o.name for o in imported}==names
  assert not any(o.type in ('CAMERA','LIGHT') for o in bpy.data.objects)
  err=max(abs(a-b) for a,b in zip(expected,bounds(imported)));assert err<1e-4
  assert any(im.packed_file for im in bpy.data.images)
  checks[ext]={'boundsMaxError':err,'embeddedPalette':True,'meshCount':len(imported)}
 assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
 report={'triangles':counts,'closedManifold':True,'exportChecks':checks,'sourceSHA256':digest}
 (folder/'validation.json').write_text(json.dumps(report,indent=2));print('SUPPLY_VERIFIED',key,json.dumps(report))
