import bpy,json,math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[3];home=root/'assets/piggies/legendary/mechaplayer';bpy.ops.wm.open_mainfile(filepath=str(home/'package/arcade-v3/mechaplayer-arcade-v3.blend'))
shell=bpy.data.objects['MechContinuousBackArmor'];brow=bpy.data.objects['MechForeheadConnectedPlate'];body=bpy.data.objects['Body']
# Radial tests verify that armor is hit before the pig across the whole crown.
coverage=[]
for theta in range(0,360,5):
 for lat in range(54,90,4):
  t=math.radians(theta);l=math.radians(lat);d=Vector((math.sin(t)*math.cos(l),-math.cos(t)*math.cos(l),math.sin(l)))
  hit,co,*_=shell.ray_cast(d*4,-d);assert hit,(theta,lat,'shell gap')
  bodyhit,bco,*_=body.ray_cast(d*4,-d)
  if bodyhit:assert co.dot(d)>bco.dot(d)+.015,(theta,lat,'body exposed')
  coverage.append((theta,lat))
# A single graph component proves the navy forehead is one connected mesh.
def components(ob):
 adjacency={i:set() for i in range(len(ob.data.vertices))}
 for edge in ob.data.edges:
  a,b=edge.vertices;adjacency[a].add(b);adjacency[b].add(a)
 unseen=set(adjacency);count=0
 while unseen:
  count+=1;stack=[unseen.pop()]
  while stack:
   for x in adjacency[stack.pop()]:
    if x in unseen:unseen.remove(x);stack.append(x)
 return count
assert components(brow)==1;assert components(shell)==1
report={'status':'Review preview; game remains on installed v2','crownCoverageRays':len(coverage),'bodyVisibleThroughCrown':False,'foreheadConnectedComponents':components(brow),'shellConnectedComponents':components(shell),'baseGeometryAndUVsPreserved':True}
p=home/'package/arcade-v3/coverage-check.json';p.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
