"""Sampled walk-route clearance and FBX round-trip checks, not Studio validation."""
import bpy,sys,json,math
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
slug=sys.argv[sys.argv.index('--')+1];out=ROOT/'assets/houses'/f'{house_slug(slug)}-v1';r=json.loads((out/'geometry-report.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(out/f'{house_slug(slug)}.blend'));deps=bpy.context.evaluated_depsgraph_get()
objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.name.startswith('REVIEW_')]
trees=[(o,o.matrix_world.inverted(),BVHTree.FromObject(o,deps)) for o in objects]
# Test the exported proxy volumes as well as the visible surfaces.
for b in r['collisionBoxes']:
 bpy.ops.mesh.primitive_cube_add(size=1,location=b['blenderLocation']);o=bpy.context.object;o.name='CHECK_PROXY_'+b['name'];o.scale=b['sizeXYZ']
 if 'rotationMatrix' in b:o.rotation_euler=Matrix(b['rotationMatrix']).to_euler()
 else:o.rotation_euler.z=b['rotationZ']
 bpy.context.view_layer.update();trees.append((o,o.matrix_world.inverted(),BVHTree.FromObject(o,deps)))
samples=[];blocked=[];unsupported=[]
for route in r['routesBlender']:
 for p,q in zip(route['points'],route['points'][1:]):
  p=Vector(p);q=Vector(q);steps=max(1,math.ceil((q-p).length/.5))
  for i in range(steps+1):
   point=p.lerp(q,i/steps);support=[]
   # Physical floor height under the sample comes from collision boxes,
   # rather than linear interpolation between stair tops.
   for b in r['collisionBoxes']:
    if b.get('role')=='guard':continue
    x,y,z=b['blenderLocation'];sx,sy,sz=b['sizeXYZ'];a=-b['rotationZ'];dx=point.x-x;dy=point.y-y
    lx=dx*math.cos(a)-dy*math.sin(a);ly=dx*math.sin(a)+dy*math.cos(a);top=z+sz/2
    if abs(lx)<=sx/2+.001 and abs(ly)<=sy/2+.001 and abs(top-point.z)<.65:support.append(top)
   if not support:
    if point.z>.65:unsupported.append(list(point))
    foot=point.z
   else:foot=max(support)
   for dx,dy in ((0,0),(-.85,0),(.85,0),(0,-.85),(0,.85)):
    start=Vector((point.x+dx,point.y+dy,foot+.2))
    for o,inv,tree in trees:
     direction=inv.to_3x3()@Vector((0,0,1));hit,_,_,_=tree.ray_cast(inv@start,direction.normalized(),5.6*direction.length)
     if hit is not None:
      world=o.matrix_world@hit
      if .65<world.z-foot<5.7:blocked.append({'mesh':o.name,'sample':[round(v,3) for v in start],'aboveFloor':round(world.z-foot,3)})
   # Horizontal cross-rays catch vertical walls/doors whose top is above the
   # standing-height rays, including a centre point accidentally inside a wall.
   for height in (1,3.5,5.5):
    for axis in (Vector((1,0,0)),Vector((0,1,0))):
     start=Vector((point.x,point.y,foot+height))-axis*.85
     for o,inv,tree in trees:
      direction=inv.to_3x3()@axis;hit,_,_,_=tree.ray_cast(inv@start,direction.normalized(),1.7*direction.length)
      if hit is not None:blocked.append({'mesh':o.name,'sample':[round(v,3) for v in start],'bodyCrossRayHeight':height})
   samples.append(list(point))
expected=len(objects);bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(out/f'{house_slug(slug)}-visual.fbx'));count=sum(o.type=='MESH' for o in bpy.context.scene.objects)
bpy.context.view_layer.update();vertices=[o.matrix_world@v.co for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices]
bounds={key:[fn(v[i] for v in vertices) for i in range(3)] for key,fn in [('min',min),('max',max)]}
roundtrip_error=max(abs(bounds[key][i]-r['boundsBlender'][key][i]) for key in ('min','max') for i in range(3))
report={'id':slug,'routeSamples':len(samples),'method':'Five vertical rays plus horizontal cross-rays at three body heights per centreline sample; 1.7-unit footprint, visual surfaces and collision proxies; stair steps under 0.65 excluded. Not a swept avatar or Studio test.','blockedClearanceSamples':blocked,'unsupportedElevatedSamples':unsupported,'fbxRoundTripMeshCount':count,'expectedMeshCount':expected,'fbxRoundTripBounds':bounds,'fbxRoundTripMaxBoundsError':roundtrip_error,'studioPlaytest':'pending'}
(out/'asset-checks.json').write_text(json.dumps(report,indent=2));print(json.dumps({'id':slug,'samples':len(samples),'blocked':len(blocked),'unsupported':len(unsupported),'meshes':count}));assert count==expected
if blocked or unsupported:print('ROUTE_FINDINGS '+json.dumps((blocked+unsupported)[:16]))
assert not blocked and not unsupported,'Offline route findings must be resolved before handoff'
assert roundtrip_error<.001,'FBX round trip changed the authored geometry bounds'
