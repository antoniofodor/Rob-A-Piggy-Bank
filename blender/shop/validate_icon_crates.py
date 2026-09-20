"""Check both real export formats, materials, hinge placement and source integrity."""
from pathlib import Path
import bpy,bmesh,json,hashlib,math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/shop-ui/icon-system-v1'
def bounds(objects):
 bpy.context.view_layer.update()
 pts=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
 return [min(p[i] for p in pts) for i in range(3)]+[max(p[i] for p in pts) for i in range(3)]
report={}
for tier in ('common','rare','legendary'):
 source=OUT/f'sources/crate-{tier}.blend';digest=hashlib.sha256(source.read_bytes()).hexdigest()
 bpy.ops.wm.open_mainfile(filepath=str(source));parts=[bpy.data.objects[n] for n in ('Body','Lid')]
 expected=bounds(parts);spec=json.loads((OUT/f'crates/{tier}/manifest.json').read_text())
 assert abs(expected[2])<.001
 assert (bpy.data.objects['Lid'].location-Vector(spec['hinge'])).length<1e-5
 counts={}
 for ob in parts:
  ob.data.calc_loop_triangles();counts[ob.name]=len(ob.data.loop_triangles);assert counts[ob.name]<20000
  bm=bmesh.new();bm.from_mesh(ob.data);bad=sum(not e.is_manifold for e in bm.edges);bm.free();assert bad==0,(tier,ob.name,bad)
  assert all(m is not None for m in ob.data.materials)
  assert all(math.isfinite(v) for p in ob.data.vertices for v in p.co)
  assert ob.data.uv_layers
 assert counts==spec['triangles']
 checks={}
 for extension in ('glb','fbx'):
  bpy.ops.wm.read_factory_settings(use_empty=True)
  if extension=='glb':bpy.ops.import_scene.gltf(filepath=str(OUT/f'crates/{tier}/{tier}.glb'))
  else:bpy.ops.import_scene.fbx(filepath=str(OUT/f'crates/{tier}/{tier}.fbx'))
  meshes=[o for o in bpy.data.objects if o.type=='MESH'];assert len(meshes)==2
  assert {o.name for o in meshes}=={'Body','Lid'}
  assert not any(o.type in ('CAMERA','LIGHT') for o in bpy.data.objects)
  error=max(abs(a-b) for a,b in zip(expected,bounds(meshes)));assert error<1e-4,(tier,extension,error)
  assert any(im.packed_file for im in bpy.data.images), 'Export lost the packed palette'
  checks[extension]={'boundsMaxError':error,'meshes':len(meshes),'packedPalette':True}
 assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
 report[tier]={'triangles':counts,'closedManifold':True,'exportChecks':checks,'sourceSHA256':digest}
(OUT/'crate-validation.json').write_text(json.dumps(report,indent=2))
print('CRATES_VERIFIED',json.dumps(report))
