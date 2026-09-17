"""Raised oak cabin with a continuous switchback stair, deck and bridge."""
import sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from asset_common import Asset
from mathutils import Vector
a=Asset('treehouse',{'Wall':(229,206,160),'Timber':(132,86,47),'Dark':(71,45,28),'Roof':(61,103,47),'Leaf':(84,138,72),'LeafLight':(117,159,72),'LeafDark':(56,111,64),'Glass':(241,186,74),'Rope':(169,139,84),'Stone':(144,134,110),'Cream':(239,225,186),'Gold':(255,203,61)})
F=10
a.cylinder('OakTrunk',(0,6,4.9),2.5,9.8,'Timber',10);a.collider('Trunk',(0,6,4.8),(4.3,4.3,9.6))
for dx,dy in ((4,0),(-4,2),(2,4),(-3,-3)):
 a.beam('OakRoot',(0,6,1.3),(dx,6+dy,.15),.65,'Timber')
# Branches rise behind the cabin, leaving the interior and display shelves clear.
a.beam('RearOakSupport',(0,6,4.5),(0,15,8),1.25,'Timber')
for p,q,r in [((0,15,8),(-7,17,23),1),((0,15,8),(8,17,24),1.1),((0,15,8),(0,20,26),1.25)]:a.beam('OakBough',p,q,r,'Timber')
a.cube('MainDeck',(0,5,9.75),(20,18,.5),'Timber',solid=True)
for x in (-7,0,7):a.cube('DeckBeam',(x,5,9.2),(.5,18,.6),'Dark')
# Cabin walls leave the front deck and side stair approaches clear.
front=a.cube('CabinFront',(0,0,14.5),(14,.7,9),'Wall');a.cutaway.append(front)
a.cut(front,a.arch('DoorCut',(0,0),5.4,15.1,2,9.7,'Wall'))
for x in (-5.1,5.1):a.window(front,(x,0,14.6),1.05,(0,-1,0),'Dark','Glass')
for side in (-1,1):
 a.collider('DoorSide'+str(side),(side*4.85,0,14.5),(4.3,.7,9))
 wall=a.cube('CabinSide'+str(side),(side*6.65,5.85,14.5),(.7,11,9),'Wall',solid=True)
 a.window(wall,(side*6.65,5.6,14.4),1.45,(side,0,0),'Dark','Glass')
 for y in (0,12):a.cube('CornerFrame',(side*6.7,y,14.5),(.45,.9,9.2),'Dark')
a.collider('DoorLintel',(0,0,18.6),(5.4,.7,.8))
a.cube('CabinRear',(0,11.7,14.5),(14,.7,9),'Wall',solid=True)
door=a.open_door(5.4,15.1,F,'Timber','Dark')
door.location.y=.8;door.rotation_euler.z=math.radians(102)
for y in (-.45,12.05):a.cube('HorizontalTrim',(0,y,18.65),(14.5,.4,.4),'Dark')
# Closed gables follow the underside of the roof; no open triangular voids.
for y in (0,12):
 vs=[(-7,y-.3,18.9),(7,y-.3,18.9),(0,y-.3,22.6),(-7,y+.3,18.9),(7,y+.3,18.9),(0,y+.3,22.6)]
 g=a.mesh('GableWall',vs,[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],'Wall');a.cutaway.append(g)
 for side in (-1,1):
  o=a.beam('GableTrim',(side*7,y-.42,18.9),(0,y-.42,22.6),.16,'Dark');a.cutaway.append(o)
# Pitched roof halves have thickness and overlap at ridge; front is removed for cutaway.
for side in (-1,1):
 vs=[(0,-1.1,23),(side*8.4,-1.1,18.7),(side*8.4,13.1,18.7),(0,13.1,23),(0,-1.1,22.6),(side*8.4,-1.1,18.3),(side*8.4,13.1,18.3),(0,13.1,22.6)]
 o=a.mesh('RoofHalf',vs,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'Roof');a.cutaway.append(o)
 for k in range(1,4):
  x=side*k*2.05;z=23-abs(x)*4.3/8.4
  o=a.cube('RoofCourse',(x,6,z+.045),(.19,14.2,.16),'LeafDark');a.cutaway.append(o)
a.collider('CabinCeiling',(0,6,19.15),(13.5,11.5,.3))
# Ground -> first flight -> landing -> returning flight -> upper landing -> front deck.
for i in range(12):
 top=(i+1)*5/12
 a.cube('LowerTread_%02d'%i,(-17,-6.5+i,top-.16),(4.4,1,.32),'Timber',solid=True)
 a.cube('UpperTread_%02d'%i,(-11.5,4.5-i,5+(i+1)*5/12-.16),(4.4,1,.32),'Timber',solid=True)
a.cube('MidLanding',(-14.25,7,4.8),(10,4,.4),'Timber',solid=True)
a.cube('UpperLanding',(-11.5,-8.5,9.8),(4.5,3,.4),'Timber',solid=True)
a.cube('DeckLink',(-6.875,-7.5,9.8),(4.75,7,.4),'Timber',solid=True)
# Rails grouped into long posts/rails, not dozens of little pickets.
def rail(name,p,q):
 a.beam(name+'_Top',p,q,.11,'Dark');a.beam(name+'_Lower',(p[0],p[1],p[2]-1.15),(q[0],q[1],q[2]-1.15),.07,'Rope')
 direction=Vector(q)-Vector(p);rotation=direction.to_track_quat('Z','Y').to_matrix()
 a.colliders.append({'name':name+'_Guard','blenderLocation':list((Vector(p)+Vector(q))/2-Vector((0,0,1.3))),'sizeXYZ':[.28,2.8,direction.length],'rotationZ':0,'rotationMatrix':[list(row) for row in rotation],'role':'guard'})
 for i in (0,.5,1):
  x=p[0]+(q[0]-p[0])*i;y=p[1]+(q[1]-p[1])*i;z=p[2]+(q[2]-p[2])*i
  a.cube(name+'_Post',(x,y,z-1.35),(.22,.22,2.9),'Dark')
for x in (-19.1,-14.9):rail('LowerStairRail',(x,-7,3.0),(x,5,8))
for x in (-13.6,-9.4):rail('UpperStairRail',(x,5,8),(x,-7,13))
for x in (-19,-15):a.beam('StairStringer',(x,-7,.1),(x,5,4.6),.2,'Dark')
for x in (-13.5,-9.5):a.beam('StairStringer',(x,5,4.8),(x,-7,9.6),.2,'Dark')
rail('LandingRear',(-19.1,8.8,8),(-9.4,8.8,8))
rail('LandingLeft',(-19.1,5,8),(-19.1,8.8,8))
rail('LandingRight',(-9.4,5,8),(-9.4,8.8,8))
rail('UpperLandingSouth',(-13.6,-9.85,12.8),(-9.25,-9.85,12.8))
rail('UpperLandingWest',(-13.6,-9.85,12.8),(-13.6,-7,12.8))
rail('DeckLinkSouth',(-9.1,-10.85,12.8),(-4.65,-10.85,12.8))
rail('DeckLinkEast',(-4.65,-10.85,12.8),(-4.65,-4.1,12.8))
rail('DeckLinkWest',(-9.1,-6.5,12.8),(-9.1,-4.1,12.8))
rail('DeckFrontRight',(2.5,-3.9,12.8),(9.8,-3.9,12.8))
rail('DeckFrontLeft',(-4.1,-3.9,12.8),(-3,-3.9,12.8))
rail('DeckRear',(-9.8,13.8,12.8),(9.8,13.8,12.8))
rail('DeckSideLeft',(-9.8,-3.9,12.8),(-9.8,13.8,12.8))
rail('DeckSideRightFront',(9.8,-3.9,12.8),(9.8,5.9,12.8))
rail('DeckSideRightRear',(9.8,10.1,12.8),(9.8,13.8,12.8))
# Side bridge and small platform. Ropes remain scenery; fixed invisible rails guard edges.
a.cube('BridgeFloor',(12.05,8,9.8),(4.1,4,.4),'Timber',solid=True)
a.cube('SidePlatform',(17.1,8,9.75),(6,6,.5),'Timber',solid=True)
for y in (6.1,9.9):rail('BridgeRope',(10.1,y,12.6),(14.3,y,12.6))
rail('PlatformOuter',(19.9,5.2,12.7),(19.9,10.8,12.7))
for y in (5.15,10.85):rail('PlatformEdge',(14.4,y,12.7),(19.9,y,12.7))
# Geometry budget: canopy uses a small number of broad faceted masses.
for i,(p,s,c) in enumerate([((-7,16,23),(6,5,4.5),'Leaf'),((0,20,26),(7,5.7,5),'LeafLight'),((7.5,17,24),(6,6,5),'Leaf'),((-10,10,25),(4.5,4,3.7),'LeafDark'),((10.5,11,25),(5,4.5,4),'LeafLight')]):
 o=a.sphere('Canopy_%02d'%i,p,s,c,True);a.cutaway.append(o)
a.beam('PulleyUpright',(18,9,10),(18,9,15),.15,'Dark');a.beam('PulleyArm',(18,9,15),(20,9,15),.16,'Dark');a.beam('BucketRope',(19.5,9,14.9),(19.5,9,9.5),.04,'Rope');a.cylinder('Bucket',(19.5,9,9.05),.5,.9,'Timber',10)
# Interior display points with clear central floor; no awarded trophies baked in.
a.shelves((-3.8,10.7),F,'Timber','Dark');a.cube('FeaturedPlinth',(3.5,9.4,10.8),(2.5,2,1.3),'Dark');a.mount('Featured',(3.5,9.4,11.48))
a.cube('RecordDesk',(3.8,5,12.6),(3.4,1.6,.3),'Timber')
for x in (2.4,5.2):a.cube('DeskLeg',(x,5,11.4),(.25,1.3,2.4),'Dark')
a.cube('RecordBook',(3.8,5,12.9),(1.5,1,.18),'Cream');a.mount('Record',(3.8,5,13));a.mount('Wall',(6.15,8.4,15));a.mount('Plaque_Legacy',(0,11.15,16));a.mount('Door_Exit',(0,-1,10))
a.cube('Rug',(0,5,10.035),(5,6,.05),'Roof')
a.routes=[{'name':'Ground_to_cabin','points':[[-17,-8,0],[-17,-6.5,.4167],[-17,4.5,5],[-17,7,5],[-11.5,7,5],[-11.5,4.5,5.4167],[-11.5,-6.5,10],[-11.5,-8.2,10],[-7,-8.2,10],[-7,-2,10],[0,-2,10],[0,1,10],[0,6,10]],'clearWidth':3.5,'clearHeight':6}]
a.routes.append({'name':'Cabin_to_side_platform','points':[[0,6,10],[0,-2,10],[8.3,-2,10],[8.3,8,10],[17,8,10]],'clearWidth':2.8,'clearHeight':6})
a.merge_static('RailAssembly',lambda o:any(s in o.name for s in ('StairRail','LandingRear','LandingLeft','LandingRight','UpperLandingSouth','UpperLandingWest','DeckLinkSouth','DeckLinkEast','DeckLinkWest','DeckFront','DeckRear','DeckSide','BridgeRope','PlatformOuter','PlatformEdge')))
a.finish((37,-45,32),(28,-34,47),(-1,7,14),54,{'floorHeight':10,'doorWidth':5.4,'doorCrownHeight':17.8,'animation':'None; Rare. All routes and decks are static.','coplanarAudit':'pending','stairRiser':5/12,'stairTreadDepth':1,'avatarRouteValidation':'offline samples only; live avatar and camera pending'})
