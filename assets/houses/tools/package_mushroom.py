"""Generate primitive collision/mount companion from Blender's measured report."""
from pathlib import Path
import json, math, xml.etree.ElementTree as E
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'assets/houses/toadstool-cottage-v1'
r=json.loads((OUT/'geometry-report.json').read_text())
root=E.Element('roblox',{'version':'4'});model=E.SubElement(root,'Item',{'class':'Model','referent':'model'})
def prop(parent,kind,name,value):
 e=E.SubElement(parent,kind,{'name':name});e.text=str(value);return e
def vec(parent,name,v):
 e=E.SubElement(parent,'Vector3',{'name':name})
 for k,val in zip(('X','Y','Z'),v):E.SubElement(e,k).text=str(val)
def cf(parent,name,p,a=0):
 e=E.SubElement(parent,'CoordinateFrame',{'name':name});c=math.cos(a);s=math.sin(a)
 for k,val in zip(('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'),(*p,c,0,s,0,1,0,-s,0,c)):E.SubElement(e,k).text=str(val)
props=E.SubElement(model,'Properties');prop(props,'string','Name','MushroomCollisionAndMounts_DRAFT');prop(props,'Ref','PrimaryPart','root')
def part(name,p,size,a=0,solid=True,ref=None):
 item=E.SubElement(model,'Item',{'class':'Part','referent':ref or name});q=E.SubElement(item,'Properties')
 prop(q,'string','Name',name);prop(q,'bool','Anchored','true');prop(q,'bool','CanCollide',str(solid).lower());prop(q,'bool','CanTouch','false');prop(q,'bool','CanQuery',str(solid).lower());prop(q,'bool','CastShadow','false');prop(q,'float','Transparency',1)
 vec(q,'size',size);cf(q,'CFrame',p,a);return item
anchor=part('Root',(0,0,0),(1,1,1),solid=False,ref='root')
for b in r['collisionBoxes']:
 x,y,z=b['blenderLocation'];sx,sy,sz=b['sizeXYZ'];part(b['name'],(-x,z,y),(sx,sz,sy),b['rotationZ'])
# Ceiling over central room. Keep fixed even if any later roof ornaments animate.
part('CeilingCentral',(0,9.4,8.5),(12,.25,16))
mounts={}
for name,(x,y,z) in r['mountsBlender'].items():
 mounts[name]=[-x,z,y];item=E.SubElement(anchor,'Item',{'class':'Attachment','referent':'mount_'+name});q=E.SubElement(item,'Properties');prop(q,'string','Name',name);cf(q,'CFrame',(-x,z,y))
E.indent(root);E.ElementTree(root).write(OUT/'toadstool-cottage-collision-mounts.rbxmx',encoding='utf-8',xml_declaration=True)
positions=[]
for line in (OUT/'toadstool-cottage-visual.obj').read_text().splitlines():
 if line.startswith('v '):positions.append([float(n) for n in line.split()[1:4]])
lo=[min(p[i] for p in positions) for i in range(3)];hi=[max(p[i] for p in positions) for i in range(3)]
bad=[m for m in r['meshes'] if m['nonManifoldEdges'] or m['triangles']>20000]
assert not bad,bad
assert hi[0]-lo[0]<=60 and hi[2]-lo[2]<=57
report={'visualMeshes':r['visualObjectCount'],'triangles':r['totalTriangles'],'nonManifoldMeshes':bad,'objBoundsRobloxAxes':{'min':lo,'max':hi,'size':[hi[i]-lo[i] for i in range(3)]},'collisionParts':len(r['collisionBoxes'])+1,'mounts':mounts,'studioScaleCollisionCameraAndLiveFootprint':'pending','coordinateConversion':'Blender (x,y,z) -> export (-x,z,y), matched by companion model'}
(OUT/'package-report.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
