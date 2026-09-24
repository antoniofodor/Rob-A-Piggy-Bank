"""Sample the actual body/trim cross sections for a fitted client scan band."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/piggies/common/cow/source/cow_closed.blend'))
groups=[('Body',0,0,16),('Snout',0,-.80,12)]
# Scan the four feet separately; the band's samples cannot cut through the pig.
groups += [('Legs',x,y,6) for x in (-.50,.50) for y in (-.48,.54)]
groups += [('Ears',x,-.35,6) for x in (-.56,.56)]
rows=[]
for i in range(73):
 z=-1.15+i/72*2.55;frame=[]
 for name,cx,cy,count in groups:
  ob=bpy.data.objects[name];points=[]
  if (name=='Legs' and not -1.02<z<-.52) or (name=='Ears' and not .72<z<1.309):
   frame.append([]);continue
  for j in range(count):
   a=math.tau*j/count;d=Vector((math.cos(a),math.sin(a),0));center=Vector((cx,cy,z))
   radius=2.5 if name in ('Body','Snout') else .40 if name=='Ears' else .34
   hit,pt,n,_=ob.ray_cast(center+d*radius,-d,distance=radius*1.85)
   if hit and (pt-center).dot(d)>-.04:
    pt+=n*.009
    # Body's importer frame: Blender X is mirrored, Z becomes up, Y becomes local Z.
    points.append([round(-pt.x*6,5),round(pt.z*6,5),round(pt.y*6,5)])
   else:points.append(False)
  frame.append(points)
 rows.append(frame)
out=['-- Actual mesh cross sections, sampled by og-refresh-v2/extract_scan.py.','return {','\tminY = -6.9, maxY = 8.4,','\tcounts = { '+', '.join(str(g[3]) for g in groups)+' },','\tframes = {']
for frame in rows:
 groups_out=[]
 for pts in frame:
  groups_out.append('{'+','.join('false' if p is False else 'Vector3.new('+','.join(map(str,p))+')' for p in pts)+'}')
 out.append('\t\t{'+','.join(groups_out)+'},')
out+=['\t},','}']
(ROOT/'src/ReplicatedStorage/Shared/SpectralScanData.luau').write_text('\n'.join(out)+'\n')
(HERE/'scan-data.json').write_text(json.dumps({'groups':groups,'frames':len(rows),'counts':[g[3] for g in groups]})+'\n')
print('EXTRACTED_SCAN',len(rows),sum(g[3] for g in groups),flush=True)
