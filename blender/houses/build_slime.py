"""All-green Gloop House, with physically hollow walls and fixed floor."""
import sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from asset_common import Asset
a=Asset('slime',{'Wall':(117,205,48),'Goo':(55,143,39),'Roof':(28,108,50),'Trim':(28,83,40),'Purple':(107,44,126),'Floor':(100,155,46),'Glass':(248,195,78),'Cream':(218,221,169),'Gold':(255,203,61)})
floor=.4
# Thick roof and continuous front/rear silhouettes avoid coplanar corner seams.
xs=[-13.1,-11,-6,0,6,11,13.1];zs=[12.3,13,14.8,16.5,15.3,13.1,12.2]
def roofheight(x):
 for j in range(len(xs)-1):
  if xs[j]<=x<=xs[j+1]:return zs[j]+(zs[j+1]-zs[j])*(x-xs[j])/(xs[j+1]-xs[j])
 return 12.5
def endwall(name,y,thickness):
 path=[(-12,.35),(12,.35)]+[(x,roofheight(x)-.4-(.3 if y>0 else 0)) for x in reversed([-12,-11,-6,0,6,11,12])]
 n=len(path);verts=[(x,y+d,z) for d in (-thickness/2,thickness/2) for x,z in path]
 return a.mesh(name,verts,[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],'Wall')
a.cube('Floor',(0,11,.2),(24,22,.4),'Floor',solid=True)
front=endwall('FrontSlimeWall',0,1);a.cutaway.append(front)
a.cut(front,a.arch('DoorCut',(0,0),6,5.8,3,-.2,'Wall'))
for x in (-7.8,7.8):a.window(front,(x,0,5.6),1.65,(0,-1,0),'Goo','Glass')
for side in (-1,1):
 a.collider('FrontJamb'+str(side),(side*7.5,0,6),(9,1,11.3))
a.collider('FrontLintel',(0,0,10.25),(6,1,2.8))
for side in (-1,1):
 wall=a.cube('SideSlimeWall'+str(side),(side*11.6,10.85,6.35),(.8,20.7,12),'Wall',solid=True)
 a.window(wall,(side*11.6,7.5,5.6),1.65,(side,0,0),'Goo','Glass')
rear=endwall('RearSlimeWall',21.6,.8)
a.collider('RearSlimeWall',(0,21.6,6),(24,.8,11.3))
a.collider('Ceiling',(0,11,11.6),(23,21,.3))
a.open_door(6,5.8,floor,'Purple','Trim')
# Broad layered goo roof with a closed underside; no stair surfaces move.
vs=[(x,y,z+(0 if y==-1.3 else -.3)) for y in (-1.3,23) for x,z in zip(xs,zs)]
vs += [(x,y,z-.55+(0 if y==-1.3 else -.3)) for y in (-1.3,23) for x,z in zip(xs,zs)]
faces=[]
for j in range(6):faces.extend([(j,j+1,j+8,j+7),(j+14,j+21,j+22,j+15),(j,j+14,j+15,j+1),(j+7,j+8,j+22,j+21)])
faces.extend([(0,7,21,14),(6,20,27,13)])
roof=a.mesh('GooRoof',vs,faces,'Roof');a.cutaway.append(roof)
for i,x in enumerate((-11,-8,-5,0,5,8,11)):
 o=a.sphere('RoofLip_%02d'%i,(x,-.75,roofheight(x)-.3),(1.8,1.25,.8),'Roof');a.cutaway.append(o)
for i,(x,y,z,s) in enumerate([(-10,-.4,9.7,2.0),(-5.5,-.45,10.3,1.6),(4.8,-.5,10.6,1.35),(10,-.5,9.4,2.4),(-12.1,5,9.6,2.1),(-12.1,15,10,1.6),(12.1,6,9.2,2.5),(12.1,15.3,10.2,1.5),(6,22,10,1.9),(-6,22,9.5,2.2)]):
 if y<0:z=roofheight(x)-s+.1
 o=a.sphere('EaveDrip_%02d'%i,(x,y,z),(1.1,1,s),'Goo');a.cutaway.append(o)
for side in (-1,1):
 for j,y in enumerate((1.2,11.3,20.4)):
  a.sphere('WallLobe',(side*11.6,y,3.8),(1.6,2.4,3.8),'Wall')
 for x in (5,8,11):a.sphere('PuddleFront',(side*x,-.8,.32),(2.0,1.6,.4),'Goo')
 for y in (5,10,16,21):a.sphere('PuddleSide',(side*12.2,y,.32),(1.5,2.2,.4),'Goo')
chimney=a.sphere('GooChimney',(7,17,14.8),(1.3,1.2,2.8),'Wall');a.cutaway.append(chimney)
for dx,dy,h in ((-.8,0,1),(0,-.7,1.4),(.7,.3,.9)):
 o=a.sphere('ChimneyDrip',(7+dx,17+dy,16.1),(.5,.5,h),'Goo');a.cutaway.append(o)
for i in range(3):a.cube('EntryStone_'+str(i),(0,-1.1-i*1.5,.14),(5.9,1.6,.25),'Cream',solid=True)
a.cube('FeaturedPlinth',(0,17.6,1.1),(3,2.6,1.4),'Goo');a.mount('Featured',(0,17.6,1.82))
a.shelves((-6.5,18.5),floor,'Goo','Trim')
a.cube('AchievementFrame',(7,21,6.2),(4.8,.3,3.5),'Trim');a.cube('AchievementInset',(7,20.78,6.2),(4.25,.15,2.95),'Goo');a.mount('Wall',(7,20.65,6.2))
a.cube('RecordTable',(7,17.5,2.8),(4.4,1.9,.35),'Goo')
for x in (5.3,8.7):a.cube('RecordLeg',(x,17.5,1.55),(.35,1.4,2.4),'Trim')
a.cube('RecordBook',(7,17.5,3.07),(1.8,1.2,.18),'Cream');a.mount('Record',(7,17.5,3.2));a.mount('Plaque_Legacy',(0,21,7));a.mount('Door_Exit',(0,-1,.4))
a.cube('InsetRug',(0,10.5,.43),(7,7,.05),'Trim')
a.routes=[{'name':'Ground_to_display','points':[[0,-6,.4],[0,0,.4],[0,8,.4],[0,14,.4]],'clearWidth':4,'clearHeight':6}]
a.finish((33,-38,29),(28,-30,44),(0,9,6.5),41,{'floorHeight':.4,'doorWidth':6,'doorCrownHeight':8.8,'animation':'None authored; Epic. Decorative drips can be wired separately if desired.','coplanarAudit':'pending','avatarRouteValidation':'sampled offline; live avatar pending'})
