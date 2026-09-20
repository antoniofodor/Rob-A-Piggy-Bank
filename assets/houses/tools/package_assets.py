"""Companion collision/mount RBXMX and measured reports for offline assets."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug
import json,math,sys,xml.etree.ElementTree as E
ROOT=Path(__file__).resolve().parents[3]
def package(slug):
 out=ROOT/'assets/houses'/f'{house_slug(slug)}-v1';r=json.loads((out/'geometry-report.json').read_text())
 root=E.Element('roblox',{'version':'4'});model=E.SubElement(root,'Item',{'class':'Model','referent':'model'})
 def prop(p,kind,name,value):e=E.SubElement(p,kind,{'name':name});e.text=str(value);return e
 def vector(p,name,v):
  e=E.SubElement(p,'Vector3',{'name':name})
  for k,value in zip(('X','Y','Z'),v):E.SubElement(e,k).text=str(value)
 def frame(p,name,v,angle=0,matrix=None):
  e=E.SubElement(p,'CoordinateFrame',{'name':name});c=math.cos(angle);s=math.sin(angle)
  values=[c,0,s,0,1,0,-s,0,c] if matrix is None else [x for row in matrix for x in row]
  for k,value in zip(('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'),(*v,*values)):E.SubElement(e,k).text=str(value)
 def part(name,p,size,angle,solid,ref,matrix=None):
  item=E.SubElement(model,'Item',{'class':'Part','referent':ref});q=E.SubElement(item,'Properties');prop(q,'string','Name',name)
  for key,value in [('Anchored',True),('CanCollide',solid),('CanQuery',solid),('CanTouch',False),('CastShadow',False)]:prop(q,'bool',key,str(value).lower())
  prop(q,'float','Transparency',1);vector(q,'size',size);frame(q,'CFrame',p,angle,matrix);return item
 q=E.SubElement(model,'Properties');prop(q,'string','Name',slug+'_CollisionAndMounts_DRAFT');prop(q,'Ref','PrimaryPart','root')
 anchor=part('Root',(0,0,0),(1,1,1),0,False,'root')
 for i,b in enumerate(r['collisionBoxes']):
  x,y,z=b['blenderLocation'];sx,sy,sz=b['sizeXYZ'];matrix=None
  if 'rotationMatrix' in b:
   # B R B^T for B mapping Blender (x,y,z) to Roblox (-x,z,y).
   order=[0,2,1];sign=[-1,1,1];matrix=[[sign[u]*sign[v]*b['rotationMatrix'][order[u]][order[v]] for v in range(3)] for u in range(3)]
  part(b['name'],(-x,z,y),(sx,sz,sy),b['rotationZ'],True,'part_'+str(i),matrix)
 mounts={}
 for name,(x,y,z) in r['mountsBlender'].items():
  item=E.SubElement(anchor,'Item',{'class':'Attachment','referent':'mount_'+name});q=E.SubElement(item,'Properties');prop(q,'string','Name',name);frame(q,'CFrame',(-x,z,y));mounts[name]=[-x,z,y]
 E.indent(root);E.ElementTree(root).write(out/f'{house_slug(slug)}-collision-mounts.rbxmx',encoding='utf-8',xml_declaration=True)
 pts=[list(map(float,line.split()[1:4])) for line in (out/f'{house_slug(slug)}-visual.obj').read_text().splitlines() if line.startswith('v ')]
 lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)]
 bad=[m for m in r['meshes'] if m['nonManifoldEdges'] or m['triangles']>20000]
 assert not bad,bad
 assert hi[0]-lo[0]<=60 and hi[2]-lo[2]<=57
 report={'id':slug,'visualMeshes':r['visualObjectCount'],'triangles':r['totalTriangles'],'collisionParts':len(r['collisionBoxes']),'basePartsIncludingRoot':r['visualObjectCount']+len(r['collisionBoxes'])+1,'objBoundsRoblox':{'min':lo,'max':hi,'size':[hi[i]-lo[i] for i in range(3)]},'nonManifoldMeshes':bad,'mounts':mounts,'studioScaleCollisionCameraAndFootprint':'pending','coplanarAudit':'pending','actualTrophyInstanceBudget':'additional, not included'}
 (out/'package-report.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:report[k] for k in ('id','visualMeshes','triangles','collisionParts','basePartsIncludingRoot','objBoundsRoblox')}))
 return report
if __name__=='__main__':
 for slug in sys.argv[1:]:package(slug)
