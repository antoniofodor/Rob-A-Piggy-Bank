"""Beached Galleon exterior from the saved broadside concept. No interiors."""
import bpy,math,sys,argparse
from pathlib import Path
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from exterior_art import ExteriorArt
p=argparse.ArgumentParser();p.add_argument('--draft',action='store_true')
opt=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
a=ExteriorArt('galleon',1,{
 'Hull':(102,64,37),'HullLight':(130,82,46),'HullDark':(72,44,30),'Deck':(159,112,62),
 'Gold':(201,149,63),'GoldLight':(226,179,88),'Cream':(237,220,184),'Red':(172,52,43),
 'Rope':(170,137,89),'Ink':(38,29,26),'Window':(32,61,79),'Amber':(255,177,58),
 'Sand':(193,164,111),'Rock':(113,111,102),
})

# Rounded toy hull: broadside is the house frontage, bow left and stern right.
outline=[(-1,.1),(-.9,-.66),(-.68,-1),(.72,-1),(1,-.7),(1,.72),(.72,1),(-.68,1),(-.9,.65)]
def hullband(name,z1,z2,s1,s2,mat):
    rings=[]
    for z,s in [(z1,s1),(z2,s2)]:
        rings.extend((21*x*s,8+8*y*s,z+max(0,-x-.67)*5) for x,y in outline)
    n=len(outline)
    fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return a.tag(a.mesh(name,rings,fs,mat))

a.section='Ground'
o=a.cylinder_art('Shallow sand foundation',(0,8,.3),1,.6,'Sand',14)
o.scale=(22.4,10.3,1)
bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
for i,(x,y) in enumerate([(-18,3),(-20,9),(18,3),(19,12),(-14,14),(12,15)]):
    a.rock('Beaching rock '+str(i),(x,y,1.1),(1.8,1.3,1.5),'Rock',i)

a.section='HullCourses'
levels=[(.8,.7),(3,.9),(5.8,.98),(8.5,1),(11.3,1),(13.4,1)]
for i,((z1,s1),(z2,s2)) in enumerate(zip(levels,levels[1:])):
    hullband('Broad hull course '+str(i),z1,z2-.06,s1,s2,'HullLight' if i%2==0 else 'Hull')
    hullband('Hull course shadow '+str(i),z2-.055,z2+.02,s2,s2,'HullDark')
a.section='HullTrim'
for z in (3.1,10.7,13.5):hullband('Continuous brass band '+str(z),z,z+.28,.93 if z<4 else 1.007,.93 if z<4 else 1.007,'Gold')
# Broad rub strakes and side ribs read without texture or tiny planks.
for x in (-14,-9,-4,1,6,11,16):
    a.box('Front hull rib',(x,-.18,10.9),(.26,.28,4.8),'Gold',.05)
    a.box('Rear hull rib',(x,16.18,10.9),(.26,.28,4.8),'Gold',.05)

a.section='Deck'
hullband('Deck slab',13.72,14.02,1.0,1.0,'Deck')
for x in range(-12,18,3):a.box('Deck board seam',(x,8,14.055),(.06,14,.035),'HullDark',0)
# Two broad fixed rails, with chunky widely-spaced balusters.
a.section='Rails'
for y in (-.15,16.15):
    a.box('Broadside rail',(0,y,16.3),(32,.58,.48),'Gold',.12)
    for x in range(-15,18,3):
        a.box('Rail baluster',(x,y,15.05),(.35,.4,2.3),'HullDark',.07)
        a.cylinder_art('Baluster cap',(x,y,16.02),.35,.32,'Gold',8)
for x in (-17.4,20.5):
    a.box('End rail',(x,8,16.3),(.5,12,.45),'Gold',.1)
    for y in (3,6,9,12):a.box('End baluster',(x,y,15.2),(.4,.35,2),'HullDark',.07)

# Stern cabin: small enough that the mast remains the dominant silhouette.
a.section='SternCabin'
a.box('Raised stern cabin',(13.2,9.0,18.7),(12.4,12.2,9.3),'HullLight',.35)
for x in (7.0,19.4):
    a.box('Cabin corner',(x,2.7,18.7),(.55,.58,9.7),'Gold',.1)
a.box('Cabin lower belt',(13.2,2.65,16.1),(12.7,.5,.38),'Gold',.08)
a.box('Cabin upper belt',(13.2,2.65,22.95),(13,.6,.5),'Gold',.08)
# Roof courses on a shallow barrel roof, authored as separate closed strips.
roofline=[(6.35+i*1.7,24.4-.035*(6.35+i*1.7-13.2)**2) for i in range(9)]
a.prism('Solid barrel roof cap',[(6.35,22.6),(19.95,22.6)]+list(reversed(roofline)),2.65,15.5,'HullDark')
for i in range(7):
    x=6.7+i*1.85
    z=24.5-.035*(x-13.2)**2
    a.box('Stern roof course '+str(i),(x,9,z),(1.88,13,.4),'HullDark' if i%2 else 'Hull',.12)
for y in (2.35,15.65):
    points=[(6.4+i*1.7,y,24.6-.035*(6.4+i*1.7-13.2)**2) for i in range(9)]
    for j,(u,v) in enumerate(zip(points,points[1:])):a.rod('Roof rim '+str(j),u,v,.22,'Gold')

def window(name,x,y,z,w,h,lit=False):
    a.arch_shape(name+'_Frame',w+.4,z+h-w/2,z-.15,.32,'Gold',(x,y,0))
    a.arch_shape(name+'_Pane',w-.12,z+h-w/2-.05,z+.05,.14,'Amber' if lit else 'Window',(x,y-.25,0))
    a.box(name+'_Mullion',(x,y-.38,z+h*.42),(.13,.14,h*.83),'HullDark',.03)
    a.box(name+'_Crossbar',(x,y-.38,z+h*.4),(w-.1,.14,.14),'HullDark',.03)
    a.box(name+'_Sill',(x,y-.2,z-.23),(w+.75,.75,.3),'Gold',.08)

a.section='Windows'
for i,x in enumerate((-11.2,-6.4,6.9,11.8)):
    window('Ground window '+str(i),x,-.20,4.3,2.6,4.4,True)
for i,x in enumerate((9.0,13.2,17.3)):
    window('Unlit stern window '+str(i),x,2.55,17.8,2.4,4.0,False)
for i,y in enumerate((6.1,10.9)):
    start=len(a.visual)
    window('Unlit cabin side window '+str(i),0,-.15,17.8,2.4,4,False)
    bpy.context.view_layer.update()
    transform=Matrix.Translation((19.5,y,0))@Matrix.Rotation(math.pi/2,4,'Z')
    for obj in a.visual[start:]:obj.matrix_world=transform@obj.matrix_world

a.section='Entrance'
a.arch_shape('Door deep frame',5.7,7,2.7,.45,'HullDark',(0,-.30,0))
a.arch_shape('Door brass frame',5.2,7,2.8,.3,'Gold',(0,-.62,0))
a.arch_shape('Closed door',4.45,7,3,.2,'HullLight',(0,-.83,0))
for x in (-1.4,-.7,0,.7,1.4):a.box('Door plank joint',(x,-.97,5.4),(.04,.04,4.7),'HullDark',0)
a.cylinder_art('Door porthole',(0,-1.03,7.0),.74,.16,'Window',16,(0,-1,0))
a.tube('Door porthole frame',(0,-1.16,7.0),.78,.13,'Gold',(0,-1,0))
a.tube('Door knocker',(1.25,-1.17,4.7),.24,.06,'Gold',(0,-1,0),12)
# Fixed gangplank is outside the ship, deliberately closed at the house door.
for i in range(8):
    y=-6.0+i*.64;z=.5+i*.35
    a.box('Gangplank tread '+str(i),(0,y,z),(5.6,.7,.27),'Deck',.045)
for x in (-3.0,3.0):
    for y,z in ((-6,.7),(-1.5,3.0)):
        a.box('Gangplank post',(x,y,z+1.0),(.55,.55,2.6),'Hull',.1)
        a.cylinder_art('Post cap',(x,y,z+2.37),.46,.24,'Gold',8)
    a.rod('Gangplank rope',(x,-6,2.2),(x,-1.5,4.5),.10,'Rope')

# Tall main mast, lookout and red/cream half-furled sail.
a.section='Mast'
a.cylinder_art('Main mast',(-4,8,30),.53,33,'Hull',12)
for z in (16,23,30,37,43):a.cylinder_art('Mast binding',(-4,8,z),.63,.35,'Gold',12)
a.cylinder_art('Lookout floor',(-4,8,43.1),2.4,.55,'HullDark',14)
for i in range(12):
    angle=i*math.tau/12;x=-4+2.12*math.cos(angle);y=8+2.12*math.sin(angle)
    a.box('Lookout baluster',(x,y,44.1),(.23,.23,1.65),'HullDark',.04)
a.tube('Lookout top rail',(-4,8,45.0),2.22,.22,'Gold',segments=16)
a.rod('Sail yard',(-18.5,7.5,38),(10.5,7.5,38),.30,'HullDark')

a.section='HouseFX_SailDecor'
# Every stripe is a closed thick ribbon with exactly shared, non-overlapping edges.
for stripe in range(10):
    x0=-17.5+stripe*2.65;x1=x0+2.65
    verts=[];segments=8
    for side in (0,1):
        for j in range(segments+1):
            t=j/segments;z=37.8-t*12
            for x in (x0,x1):
                y=6.9-1.7*math.sin(t*math.pi)+.38*math.cos((x+4)*.15)+side*.10
                verts.append((x,y,z+.25*math.cos((x+4)*.22)*t))
    ring=(segments+1)*2;faces=[]
    for j in range(segments):
        u=j*2;faces.extend([(u,u+1,u+3,u+2),(ring+u+2,ring+u+3,ring+u+1,ring+u)])
    # seal perimeter of each stripe volume
    boundary=[0,1]+list(range(3,ring,2))+[ring-2]+list(range(ring-4,0,-2))
    for u,v in zip(boundary,boundary[1:]+boundary[:1]):faces.append((u,v,v+ring,u+ring))
    a.tag(a.mesh('Sail stripe '+str(stripe),verts,faces,'Red' if stripe%2==0 else 'Cream'))
    a.cylinder_art('Furled sail roll '+str(stripe),((x0+x1)/2,6.65,37.2),.83,2.65,'Red' if stripe%2==0 else 'Cream',12,(1,0,0))

a.section='Rigging'
for end in ((-18.5,7.5,38),(10.5,7.5,38),(-18,7,15),(19,9,16)):
    a.rod('Standing rigging',(-4,8,45),end,.07,'Rope')
# Narrow rope ladder stays off the silhouette of the door and clear of the front window row.
u=Vector((4,10,14.3));v=Vector((-1,9,37.7))
for dx in (-.85,.85):a.rod('Rope ladder side',u+Vector((dx,0,0)),v+Vector((dx,0,0)),.08,'Rope')
for i in range(17):
    t=i/16;at=u.lerp(v,t);a.rod('Ladder rung '+str(i),at+Vector((-.9,0,0)),at+Vector((.9,0,0)),.09,'HullDark')
# Decorative bowsprit and simple wheel, no flags or weapons.
a.rod('Bowsprit',(-17,8,15),(-22.6,8,20),.28,'HullDark')
a.cylinder_art('Wheel stand',(4.5,4,15),.22,2,'HullDark',8)
a.tube('Stern wheel',(4.5,4,17),1.25,.18,'HullDark',(0,-1,0),16)
for i in range(8):
    t=i*math.tau/8
    a.rod('Wheel spoke',(4.5,4,17),(4.5+1.58*math.cos(t),4,17+1.58*math.sin(t)),.1,'Gold')

def lantern(name,x,y,z,scale=1,fx=False):
    a.section='HouseFX_MastLanternAccent' if fx else 'Lanterns'
    a.box(name+'_Glow',(x,y,z),(scale*.65,scale*.65,scale*.9),'Amber',.1)
    a.section='LanternFrames'
    a.cylinder_art(name+'_Base',(x,y,z-scale*.56),scale*.57,scale*.18,'HullDark',6)
    a.cylinder_art(name+'_Cap',(x,y,z+scale*.57),scale*.65,scale*.22,'Gold',6)
    for dx,dy in ((-1,-1),(-1,1),(1,-1),(1,1)):
        a.rod(name+'_Post',(x+dx*scale*.38,y+dy*scale*.38,z-scale*.45),(x+dx*scale*.38,y+dy*scale*.38,z+scale*.48),scale*.06,'HullDark')
    a.cylinder_art(name+'_Finial',(x,y,z+scale*.8),scale*.15,scale*.4,'Gold',8)

lantern('Masthead lantern',-4,8,47.5,1.9,True)
for x in (-3.5,3.5):lantern('Door lantern',x,-.8,9.6,.8)
for x in (7.0,19.2):lantern('Cabin lantern',x,3.1,25.5,.75)
a.glow('Amber',.65)
fx=[{'section':'HouseFX_MastLanternAccent','kind':'pulse','periodSeconds':7,'phase':0,'intensity':[.4,.75]},
    {'section':'HouseFX_SailDecor','kind':'sway','periodSeconds':11,'phase':.2,'amplitudeDegrees':2,'hingeBlender':[-4,7.5,38],'axisBlender':'X','optionalForMVP':True}]
a.complete('assets/houses/design/mvp-exteriors/beached-galleon-concept.png',(0,7,24),(62,-86,48),61,fx,opt.draft)
