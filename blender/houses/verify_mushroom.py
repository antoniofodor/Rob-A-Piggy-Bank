"""Headless geometry checks on authored file; not a Studio playtest."""
import bpy,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parents[2]/'assets/houses/models/mushroom-v1'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'mushroom.blend'))
deps=bpy.context.evaluated_depsgraph_get();bodies=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.name.startswith('REVIEW_')]
# Test the standing avatar lane through the front opening only.
hits=[]
for x in (-1.8,0,1.8):
 for z in (1,3,5.2):
  start=Vector((x,-2,z));direction=Vector((0,1,0))
  for o in bodies:
   inv=o.matrix_world.inverted();local=inv@start;d=inv.to_3x3()@direction
   bvh=BVHTree.FromObject(o,deps);point,normal,index,distance=bvh.ray_cast(local,d.normalized(),3/d.length)
   if point is not None:
    world=o.matrix_world@point
    if -1.5<world.y<.7:hits.append({'mesh':o.name,'laneX':x,'height':z,'hitY':world.y})
assert not hits,hits
expected=len(bodies)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(OUT/'mushroom-visual.fbx'))
count=sum(o.type=='MESH' for o in bpy.context.scene.objects)
assert count==expected,(count,expected)
report={'doorwayStandingLaneSamples':9,'blockedSamples':hits,'fbxRoundTripMeshCount':count,'expectedMeshCount':expected,'studioPlaytest':'pending'}
(OUT/'asset-checks.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
