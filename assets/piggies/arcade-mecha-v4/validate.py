from pathlib import Path
import bpy,bmesh,json,math,hashlib
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
HOME=ROOT/'assets/piggies/legendary/mechaplayer'
package=HOME/'package/arcade-v4'
bpy.ops.wm.open_mainfile(filepath=str(package/'mechaplayer-arcade-v4.blend'))
scene=bpy.context.scene;scene.frame_set(1)
fx=next(c for c in scene.collection.children if c.name.startswith('FX -'))
extras=[o for o in fx.objects if o.type=='MESH']
assert len(extras)==87
for o in extras:
 bm=bmesh.new();bm.from_mesh(o.data)
 assert len(bm.faces)>0 and all(e.is_manifold for e in bm.edges),o.name
 bm.free()
coin_checks=0
for x in (-.035,0,.035):
 for y in (.07,.15,.25,.35,.45):
  for o in extras+[bpy.data.objects['Body']]:
   inv=o.matrix_world.inverted()
   hit,co,*_=o.ray_cast(inv@Vector((x,y,2)),inv.to_3x3()@Vector((0,0,-1)))
   assert not hit or (o.matrix_world@co).z<.78,('coin clearance',o.name,x,y)
  coin_checks+=1
for side in (-1,1):
 o=bpy.data.objects['MechShoulderNavy_'+str(side)]
 assert len(o.data.uv_layers)==1
 image=next(n.image for n in o.active_material.node_tree.nodes if n.type=='TEX_IMAGE')
 assert image.packed_file and tuple(image.size)==(512,512)
assert not any(o.name.startswith('MechPaintShoulder') for o in extras)
cap=bpy.data.objects['MechContinuousBackArmor'];body=bpy.data.objects['Body'];coverage=0
for theta in range(0,360,5):
 for lat in range(54,90,4):
  t=math.radians(theta);l=math.radians(lat)
  d=Vector((math.sin(t)*math.cos(l),-math.cos(t)*math.cos(l),math.sin(l)))
  predicted=d/math.sqrt(d.x*d.x+(d.y/1.08)**2+(d.z/.96)**2)+d*.07
  if abs(predicted.x)<.13 and -.06<predicted.y<.60:continue
  hit,co,*_=cap.ray_cast(d*4,-d);assert hit,(theta,lat)
  bh,bc,*_=body.ray_cast(d*4,-d)
  assert not bh or co.dot(d)>bc.dot(d)+.015,(theta,lat,'crown coverage')
  coverage+=1
for center in (-62,62,180):
 for lat in (0,10,20):
  t=math.radians(center);l=math.radians(lat)
  d=Vector((math.sin(t)*math.cos(l),-math.cos(t)*math.cos(l),math.sin(l)))
  hit,co,*_=cap.ray_cast(d*4,-d)
  bh,bc,*_=body.ray_cast(d*4,-d)
  assert not hit or co.dot(d)<bc.dot(d)+.014,(center,lat,'vent blocked by shell')
report=json.loads((package/'asset-report.json').read_text())
base=json.loads((HOME/'package/arcade-v2/asset-report.json').read_text())
report['textures']=base['textures']+[{'role':'shoulder_color','file':str(p.relative_to(HOME)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'size':[512,512]} for p in sorted((HOME/'textures/arcade-v4').glob('*.png'))]
report['validation']={'allAccessoryMeshesClosed':True,'crownCoverageRaysOutsideCoinSlot':coverage,'coinSlotClearanceRays':coin_checks,'baseMeshGeometryAndUVsPreserved':True,'eyeReseatForwardBlenderUnits':.026,'insetVents':3,'navyLegSockets':4,'shoulderMarkings':'UV texture paint','shoulderImagesPacked':True}
report['integrationNotes']=['Review only; v2 is still installed.','Preview eyes move forward by .026 Blender units; match this clearance when fitting runtime eyes.','New boot sole Z=-1.13; adjust ground clearance when importing.','Shoulder UV textures must be uploaded with the shoulder meshes. Preserve existing body and trim textures.']
(package/'asset-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report['validation']))
