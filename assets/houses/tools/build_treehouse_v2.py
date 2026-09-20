"""Reference-led Treehouse rebuild. Run with Blender --background --python.

Source reference: assets/houses/design/fantasy-v2/treehouse-concept.png.
The rendering is real mesh geometry; no generated-image finishing pass.
"""
import bpy, bmesh, math, random, json, sys, argparse
from pathlib import Path
from collections import defaultdict
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asset_common import Asset, ROOT

args = argparse.ArgumentParser()
args.add_argument('--draft', action='store_true')
opt = args.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
# ONE GENERATOR PER SECTION, SO AN EDIT IN ONE CANNOT MOVE ANOTHER.
#
# There used to be a single `random.Random(31)` drawn from by the deck boards,
# the shingles, the stair treads, the bridge planks, the canopy jitter, the
# stepping stones and the interior floor -- in that order, all off one stream.
# So REMOVING SEVEN DOOR PLANKS re-dealt every draw after them: the canopy
# jittered differently and the house's own bounds moved 0.43 studs wide and
# 0.37 tall. Measured, and it is the expensive kind of coupling here, because
# the exterior is 68 UPLOADED MESHES -- an interior tweak that perturbs the
# canopy turns a free change into a manual re-import.
#
# `random.Random` takes a string seed and is deterministic across runs, so a
# generator named per section is stable and independent. The canopy cannot
# hear the door any more.
def srng(section):
    return random.Random('treehouse/' + section)

rng = srng('bark')
deckRng = srng('deck')
roofRng = srng('roof')
stairRng = srng('stairs')
bridgeRng = srng('bridge')
leafRng = srng('canopy')
groundRng = srng('ground')
roomRng = srng('interior')
a = Asset('treehouse', {
    'Plaster': (217,178,122), 'PlasterLight': (235,200,145),
    'Timber': (123, 76, 39),
    'Wood': (169,110,58), 'WoodLight': (190,134, 76),
    'WoodShade': (145,89,44), 'Bark': (115,70,34), 'BarkLight': (148,91,43),
    'BarkDark': ( 90,54,28),
    'Roof': ( 62,119,47),
    'RoofLight': (75,134,49), 'RoofDark': (53,106,43),
    'Leaf': ( 74,132,48), 'LeafLight': (106,155, 57),
    'LeafDark': ( 45,99, 47),
    'Rope': (184,139,76), 'Iron': (69,65,43), 'Gold': (229,162,41),
    'Amber': (255,192,63), 'WindowBlue': ( 49,113,146),
    'Stone': (125,133,117), 'StoneLight': (155,156,133), 'Cream': (235,218,177),
    'BookGreen': (78,118,75), 'BookRed': (156,80,43), 'Rug': (98,140, 65),
})
a.out = ROOT / 'assets/houses/treehouse-v2'
a.out.mkdir(parents=True, exist_ok=True)
section = 'Structure'
cutaway = False
F = 14.5

def tag(o):
    o['section'] = section
    o['cutaway'] = cutaway
    return o

def box(name, p, size, mat='Wood', bevel=.06, rot=0):
    x,y,z=(v/2 for v in size)
    vs=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    o=tag(a.mesh(name,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat))
    o.location=p;o.rotation_euler.z=rot
    if bevel:
        bm=bmesh.new();bm.from_mesh(o.data)
        bmesh.ops.bevel(bm,geom=list(bm.edges),offset=min(bevel,min(size)*.2),segments=1,affect='EDGES')
        bm.to_mesh(o.data);bm.free()
    return o

def cylinder(name,p,r,d,mat='Wood',n=12,normal=(0,0,1)):
    return tag(a.cylinder(name,p,r,d,mat,n,normal))

def ball(name,p,scale,mat='Leaf',detail=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=detail,radius=1,location=p)
    o=bpy.context.object; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return tag(a.keep(o,name,mat))

def beam(name,p,q,width=.4,depth=None,mat='Timber',bevel=.05):
    p,q=Vector(p),Vector(q)
    o=box(name,(p+q)/2,(width,depth or width,(q-p).length),mat,bevel)
    o.rotation_euler=(q-p).to_track_quat('Z','Y').to_euler()
    return o

def cord(name,points,r=.08,mat='Rope'):
    for p,q in zip(points,points[1:]): tag(a.beam(name,p,q,r,mat))

def branch(name,points,radii):
    n=9; vs=[]
    for j,(p,r) in enumerate(zip(points,radii)):
        for i in range(n):
            angle=i*2*math.pi/n+.12*math.sin(j)
            rr=r*(1+.12*math.sin(i*2.9+j*.7))
            vs.append((p[0]+rr*math.cos(angle),p[1]+rr*math.sin(angle),p[2]))
    fs=[tuple(range(n-1,-1,-1)),tuple(range((len(points)-1)*n,len(points)*n))]
    for j in range(len(points)-1):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    o=tag(a.mesh(name,vs,fs,'Bark'))
    o.data.materials.append(a.mat['BarkLight']);o.data.materials.append(a.mat['BarkDark'])
    for polygon in o.data.polygons:
        polygon.material_index=rng.choices((0,1,2),weights=(6,2,1))[0]
    return o

def plant(p,s=1):
    for k in range(5):
        angle=k*2.4
        o=ball('Pointed forest leaf',(p[0]+math.cos(angle)*s*.35,p[1]+math.sin(angle)*s*.35,p[2]+s*.55),(s*.35,s*.17,s*.95),'Leaf' if k%2 else 'LeafLight',1)
        o.rotation_euler=(math.sin(angle)*.6,math.cos(angle)*.6,angle)

post_positions=set()
def post(p,height=3.1):
    x,y,z=p
    key=tuple(round(v,3) for v in (x,y,z,height))
    if key in post_positions:return
    post_positions.add(key)
    box('Heavy railing post',(x,y,z+height/2),(.55,.55,height),'WoodShade',.065)
    box('Square post cap',(x,y,z+height+.08),(.7,.7,.24),'WoodLight',.07)

def rail(p,q):
    p,q=Vector(p),Vector(q)
    steps=max(1,math.ceil((q-p).length/3.6))
    for i in range(steps+1):post(p.lerp(q,i/steps))
    for h,w in ((2.65,.32),(.65,.24)):
        beam('Deck rail',p+Vector((0,0,h)),q+Vector((0,0,h)),w,mat='Wood')
    for i in range(steps*2):
        v=p.lerp(q,(i+.5)/(steps*2))
        box('Railing baluster',(v.x,v.y,v.z+1.55),(.22,.22,1.75),'Wood',.03)

def lantern(p,size=1):
    x,y,z=p
    box('Lantern glowing core',(x,y,z+.62*size),(.7*size,.7*size,1.1*size),'Amber',.035)
    for dx in (-.41,.41):
        for dy in (-.41,.41):box('Lantern cage',(x+dx*size,y+dy*size,z+.65*size),(.11*size,.11*size,1.3*size),'Iron',.02)
    box('Lantern foot',(x,y,z),(.96*size,.96*size,.18*size),'Iron',.04)
    vs=[(x+dx*size,y+dy*size,z+1.35*size) for dx,dy in ((-.6,-.6),(.6,-.6),(.6,.6),(-.6,.6))]+[(x,y,z+1.9*size)]
    tag(a.mesh('Pyramid lantern hood',vs,[(0,3,2,1),(0,1,4),(1,2,4),(2,3,4),(3,0,4)],'Iron'))

# A visibly branching oak, rooted into the ground rather than a straight pole.
section='Oak'
branch('Twisting main trunk',[(0,6,0),(-1,7,5),(0,9,10),(2,18,14),(3,18,21),(4,18,29),(6,18,35)],[4.7,4,3.8,3.4,2.8,1.7,.7])
for p,r in [((-8,-1,0),2.1),((8,0,0),2.4),((-7,13,0),2),((9,15,0),2)]:
    branch('Oak buttress',[p,((p[0]+1)*.5,(p[1]+7)*.5,4),(0,8,9)],[r,r*.9,.9])
branch('Left spreading bough',[(1,17,15),(-6,17,20),(-13,14,25),(-18,8,29)],[2.1,1.8,1.2,.5])
branch('Upper left fork',[(0,17,23),(-8,17,30),(-11,18,35)],[1.6,1.1,.4])
branch('Right spreading bough',[(3,17,20),(11,17,25),(15,16,31)],[2,1.3,.5])
branch('Left structural oak fork',[(-2,7,0),(-5,10,8),(-11,13,15),(-14,14,21)],[3.2,2.2,1.7,1.1])
branch('Right structural oak fork',[(1,8,0),(5,12,9),(9,16,16),(12,17,23)],[3,2.5,2,1.2])
for i in range(5):
    angle=i*1.8
    beam('Raised bark crease',(3*math.cos(angle),7+3*math.sin(angle),1),(-.5+3*math.cos(angle),8+3*math.sin(angle),7),.13,mat='BarkDark',bevel=0)

# Deck has distinct planks, broad fascia and diagonal support brackets.
section='Deck'
a.collider('Main deck',(0,5,14.15),(24,20,.7))
for i in range(25):
    y=-4.6+i*.8
    box('Deck floorboard',(0,y,14.2),(24,.77,.6),deckRng.choice(['Wood','WoodLight','WoodShade']),.035)
for y in (-5.05,15.05):box('Deck fascia',(0,y,13.95),(24.65,.55,.95),'WoodShade')
for x in (-12.05,12.05):box('Deck fascia',(x,5,13.95),(.55,19.55,.95),'WoodShade')
for x in (-10,-5,5,10):
    beam('Oak deck bracket',(x*.35,7,8.5),(x,2,13.5),.85,mat='Timber')
for x in (-9,0,9):box('Deck joist',(x,5,13.35),(.65,20,.6),'Timber')

# Cream infill and square timber-framed windows match the reference.
section='Cabin'; cutaway=True
front=box('Front plaster',(0,0,19.75),(17,.65,10.5),'Plaster',0)
a.cut(front,tag(a.cube('Door cutter',(0,0,18.8),(5.8,2,8.8),'Plaster')))
section='Cabin'; cutaway=False
left=box('Left plaster',(-8.15,6.6,19.75),(.7,12.5,10.5),'Plaster',0)
right=box('Right plaster',(8.15,6.6,19.75),(.7,12.5,10.5),'Plaster',0)
rear=box('Rear plaster',(0,13.15,19.75),(17,.65,10.5),'Plaster',0)
for side in (-1,1):a.collider('Cabin side '+str(side),(side*8.15,6.6,19.75),(.7,12.5,10.5))
a.collider('Cabin rear',(0,13.15,19.75),(17,.65,10.5))
for x in (-5.7,5.7):a.collider('Front jamb',(x,0,19.75),(5.4,.65,10.5))
a.collider('Door lintel',(0,0,24.1),(5.8,.65,1.8))

def window(wall,p,width,height,side=False,blue=False,hide=False):
    global cutaway
    previous=cutaway;cutaway=hide
    x,y,z=p
    a.cut(wall,tag(a.cube('Window cutter',p,(2,width,height) if side else (width,2,height),'Plaster')))
    def piece(name,u,v,w,sz,mat):
        pp=(x+w,y+u,z+v) if side else (x+u,y+w,z+v)
        ss=(sz[2],sz[0],sz[1]) if side else (sz[0],sz[2],sz[1])
        return box(name,pp,ss,mat,.04)
    piece('Window glass',0,0,0,(width-.12,height-.12,.14),'WindowBlue' if blue else 'Amber')
    for u in (-width/2,width/2):piece('Window side frame',u,0,.48 if side else -.48,(.25,height+.45,.3),'Timber')
    for v in (-height/2,height/2):piece('Window lintel',0,v,.48 if side else -.48,(width+.7,.32,.4),'Timber')
    piece('Window cross mullion',0,0,.56 if side else -.56,(.14,height,.14),'WoodShade')
    piece('Window cross mullion',0,0,.56 if side else -.56,(width,.14,.14),'WoodShade')
    piece('Deep window sill',0,-height/2-.2,.7 if side else -.7,(width+.7,.22,.8),'Wood')
    cutaway=previous

window(front,(-5.8,0,19.4),2.25,3.25,hide=True)
window(front,(5.8,0,19.4),2.25,3.25,hide=True)
window(right,(8.15,5,19.4),2.4,3.3,side=True)
window(right,(8.15,10,19.4),2.4,3.3,side=True)
for x in (-8.5,8.5):
    for y in (0,13.3):box('Massive corner timber',(x,y,19.8),(1,1.05,10.9),'Timber')
for y in (-.4,13.55):
    for z in (15.1,24.6):box('Horizontal cabin timber',(0,y,z),(17.8,.9,.85),'Timber')
for side in (-1,1):
    for z in (15.1,24.6):box('Side cabin timber',(side*8.5,6.6,z),(.7,13.5,.7),'Timber')
cutaway=True
for x in (-3.3,3.3):box('Doorway timber',(x,-.35,19.2),(.65,.8,9.4),'WoodShade')
box('Door crown beam',(0,-.5,23.9),(7.5,1,.85),'Timber')
# THERE IS NO DOOR LEAF, AND THE OPENING IS THE DOOR. Every piece that frames
# it stays -- the two jamb timbers, the crown beam and the lintel collider --
# so this is a framed opening rather than a hole.
#
# The leaf used to swing to about 102 degrees, which put it FIVE STUDS INTO the
# cabin three studs left of the doorway: from the doorstep it was a wooden slab
# across the left half of the room, hiding the wall the trophy shelves now run
# along, and it intersected the bench. The room is a display surface on all
# four sides now, so nothing may stand in the middle of it.
#
# LAYING IT FLAT AGAINST A WALL WAS TRIED FIRST AND THERE IS NOWHERE TO PUT IT.
# Hinged on either jamb, a 5-stud leaf lying along the front wall spans from
# the jamb (x +-2.9) to the side wall's inner face (x +-7.8) -- and the front
# wall's two windows sit at x -6.925..-4.675 and 4.675..6.925, dead centre of
# that span, so a flat door covers a window whichever way it swings. Outward is
# refused by the old comment's own constraint, which still holds: the leaf
# would stand on the porch across the top of the stair.
#
# AN OPENABLE DOOR IS A DIFFERENT JOB, not a tuning of this one. The leaf would
# have to leave `merge_static` as its own mesh so the runtime can pivot it, and
# it would want a prompt -- against a room whose whole purpose is that a visitor
# WALKS IN and reads the collection, which the brief states as requiring no
# menu. Nothing here blocks it later: an openable door would simply give this
# opening a leaf again, hinged rather than posed.
#
# The leaf carried no collider, so it never blocked walking -- only sight. That
# is what made this a free deletion.
cutaway=False

# Pitched roof with curved eaves and individual overlapping shingle courses.
section='Roof';cutaway=True
profile=[(0,33.1),(2,31.4),(4,29.6),(6,27.75),(8,26.1),(10.3,25.1)]
def roofz(x):
    x=abs(x)
    for (p,z),(q,w) in zip(profile,profile[1:]):
        if p<=x<=q:return z+(w-z)*(x-p)/(q-p)
    return profile[-1][1]
for y in (0,13.15):
    path=[(-8.5,24.4),(8.5,24.4)]+[(x,roofz(x)-.32) for x in (8.5,8,6,4,2,0,-2,-4,-6,-8,-8.5)]
    n=len(path);vs=[(x,y+d,z) for d in (-.32,.32) for x,z in path]
    g=tag(a.mesh('Gable plaster',vs,[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],'PlasterLight'))
    if y==0:window(g,(0,0,28.05),2.35,2.65,blue=True,hide=True)
    for x in (-4,4):box('Gable upright',(x,y-.4,27),( .35,.4,4.7),'Timber')
for side in (-1,1):
    for j in range(len(profile)-1):
        x,z=profile[j];q,w=profile[j+1]
        vs=[(side*x,-1.2,z-.2),(side*q,-1.2,w-.2),(side*q,14.5,w-.2),(side*x,14.5,z-.2),(side*x,-1.2,z-.55),(side*q,-1.2,w-.55),(side*q,14.5,w-.55),(side*x,14.5,z-.55)]
        tag(a.mesh('Solid roof substrate',vs,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'RoofDark'))
    for row in range(9):
        x0=row*1.13;x1=min(10.5,x0+1.4)
        for col in range(7):
            y0=-1.3+col*2.3+(0.15 if row%2 else 0);y1=min(14.65,y0+2.28)
            # Raised tails overlap the next course without coplanar faces.
            z0=roofz(min(x0,10.3))+.10;z1=roofz(min(x1,10.3))+.35+roofRng.uniform(-.015,.015)
            vs=[(side*x0,y0,z0),(side*x1,y0,z1),(side*x1,y1,z1),(side*x0,y1,z0),(side*x0,y0,z0-.18),(side*x1,y0,z1-.18),(side*x1,y1,z1-.18),(side*x0,y1,z0-.18)]
            tag(a.mesh('Overlapping green shingle',vs,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],roofRng.choices(['Roof','RoofLight','RoofDark'],[15,4,1])[0]))
    for y in (-1.4,14.65):
        for (x,z),(q,w) in zip(profile,profile[1:]):beam('Carved gable verge',(side*x,y,z-.3),(side*q,y,w-.3),.55,.75,'Timber',.07)
box('Ridge cap',(0,6.6,33.12),(.6,16.8,.45),'RoofDark')
box('Front gable finial',(0,-1.35,33.45),(.85,.8,.9),'WoodShade',.08)

# Reference staircase: two substantial flights below the FRONT porch.
section='Stairs';cutaway=False
def flight(name,start,end,count,width=5):
    start,end=Vector(start),Vector(end)
    delta=end-start;flat=Vector((delta.x,delta.y,0));length=flat.length
    forward=flat.normalized();across=Vector((forward.y,-forward.x,0));angle=math.atan2(-forward.x,forward.y)
    for i in range(count):
        p=start+delta*((i+.5)/count);top=start.z+delta.z*(i+1)/count
        if i==count-1 and abs(end.z-F)<.01:top+=.06
        o=box(name+' tread',(p.x,p.y,top-.22),(width,length/count+.015,.44),stairRng.choice(['Wood','WoodLight']),.035,angle)
        a.collider(name+' step '+str(i),(p.x,p.y,top-.22),(width,length/count,.44),angle)
        # Shallow vertical risers make the stairs read as solid joinery.
        p2=start+delta*(i/count)
        box(name+' riser',(p2.x,p2.y,top-.48),(width,.15,.65),'WoodShade',.025,angle)
    for side in (-1,1):
        p=start+across*side*(width/2+.05);q=end+across*side*(width/2+.05)
        beam('Solid stair stringer',p+Vector((0,0,-.3)),q+Vector((0,0,-.3)),.5,1,'WoodShade')
        steps=max(2,round(length/3.4))
        for i in range(steps+1):post(p.lerp(q,i/steps),3.1)
        beam('Stair handrail',p+Vector((0,0,2.8)),q+Vector((0,0,2.8)),.4,.45,'Wood')
        beam('Stair lower rail',p+Vector((0,0,.7)),q+Vector((0,0,.7)),.22,.25,'WoodShade')
flight('Lower stairs',(-6,-26,0),(-6,-16,7.25),13,5.2)
for i in range(6):box('Landing floor',(-6,-15.5+i*.7,7.0),(7,.68,.5),'Wood',.04)
a.collider('Stair landing',(-6,-13.75,7),(7,4.2,.5))
flight('Upper stairs',(-6,-11.7,7.25),(0,-5,14.5),13,5.2)
rail((-9.4,-16,7.25),(-9.4,-11.8,7.25));rail((-9.4,-11.8,7.25),(-8.7,-11.8,7.25))
for x,y,z in ((-8.7,-25.6,3.1),(-9.4,-15.7,10.35),(-3.5,-16,10.35),(3.1,-5,17.8)):
    lantern((x,y,z),.9)
for x,y in ((-8,-14),(-3.5,-14)):beam('Landing support',(x,y,0),(x,y,7),.65,mat='Timber')

section='Railings'
rail((-12,-5,F),(-3.1,-5,F));rail((3.1,-5,F),(12,-5,F))
rail((-12,-5,F),(-12,15,F));rail((-12,15,F),(12,15,F))
rail((12,-5,F),(12,1.4,F));rail((12,6.6,F),(12,15,F))

# Sagging rope bridge, small roofed lookout, independent supporting tree.
section='Bridge'
for i in range(12):
    x=12+(i+.5)*8.85/12;t=(x-12)/8.85;z=F-.75*math.sin(math.pi*t)
    box('Bridge plank',(x,4,z-.16),(8.85/12-.025,4.3,.32),bridgeRng.choice(['Wood','WoodLight']),.04)
    a.collider('Bridge plank '+str(i),(x,4,z-.16),(8.85/12,4.3,.32))
for y in (1.75,6.25):
    points=[(12.1+i*.75,y,F+2.8-1.15*math.sin(math.pi*i/12)) for i in range(13)]
    cord('Bridge top rope',points,.115)
    cord('Bridge bottom rope',[(x,y,z-1.9) for x,y,z in points],.09)
    for i in range(1,12,2):
        p=Vector(points[i]);cord('Bridge hanging ties',[p,p-Vector((0,0,2.1))],.065)
section='Lookout'
for i in range(11):box('Lookout floor',(25.05,.25+i*.72,14.22),(8.4,.69,.55),'Wood',.03)
a.collider('Lookout floor',(25.05,3.85,14.22),(8.4,8,.55))
for y in (0,7.8):box('Lookout fascia',(25.05,y,13.9),(8.8,.4,.8),'WoodShade')
rail((21,0,F),(29.2,0,F));rail((29.2,0,F),(29.2,7.8,F));rail((21,7.8,F),(29.2,7.8,F))
for x in (22.8,27.6):box('Lookout roof post',(x,5.1,17.1),(.5,.5,5.4),'Timber')
for side in (-1,1):
    o=box('Lookout green roof',(25.2+side*1.65,5.1,20.2),(3.8,4.7,.35),'Roof',.04)
    o.rotation_euler.y=side*math.radians(18)
beam('Pulley arm',(22.8,5.1,19.9),(21.5,1,19.9),.35,mat='Timber')
cylinder('Pulley wheel',(21.5,1,19.35),.45,.25,'WoodShade',12,(1,0,0))
cord('Bucket suspension',[(21.5,1,19.1),(21.5,1,9)],.065)
for i in range(10):
    angle=i*math.tau/10
    box('Bucket stave',(21.5+math.cos(angle)*.65,1+math.sin(angle)*.65,8.5),(.43,.22,1.1),'Wood',.02,angle+math.pi/2)
for z in (8.05,8.85):
    bpy.ops.mesh.primitive_torus_add(major_radius=.65,minor_radius=.065,major_segments=12,minor_segments=4,location=(21.5,1,z));tag(a.keep(bpy.context.object,'Bucket iron band','Iron'))
branch('Lookout tree',[(26,6,0),(25.5,5,8),(25.5,6,14),(27,9,19),(27,10,23)],[1.9,1.5,1.2,1,.5])
for x,y in ((22,1),(28,1),(22,7),(29,7)):beam('Lookout diagonal support',(25.5,5,10),(x,y,14),.5,mat='Timber')

# Chunky masses surround the architecture. Subtle per-face colour changes,
# rather than a tiny collection of identical spheres, preserve the concept.
section='Canopy';cutaway=False
foliage=[((-17,8,26),(5.9,5,5.5)),((-12,13,30),(6.5,5.2,5.3)),((-8,18,33),(6,5.7,5)),((0,19,34),(7,6,5)),((7,18,34),(6,5.5,5)),((13,15,30),(6,5.2,5)),((17,11,26),(4.3,4.3,4.7)),((-19,4,23),(4.8,4.2,4.9)),((-14,14,22),(4.8,4.5,4.5)),((9,21,27),(5.4,5.4,4.8)),((0,22,27),(6,4.5,4.5)),((27,8,22),(5.3,4.4,4.2)),((-8,16,13),(5.2,4,4.2)),((11,16,16),(4.5,4,4))]
for i,(p,s) in enumerate(foliage):
    o=ball('Sculpted oak canopy',p,s,['Leaf','LeafLight','LeafDark'][i%3],2)
    for v in o.data.vertices:v.co*=leafRng.uniform(.93,1.06)
    o.data.materials.append(a.mat['LeafLight']);o.data.materials.append(a.mat['LeafDark'])

# Small ground accents are part of the asset; no large landscape mesh.
section='GroundDetails';cutaway=False
for p,s in [((-9,0,.8),(2.2,1.7,1.7)),((8,-1,1),(2.5,2,2.1)),((-6,11,.5),(2,2,1)),((8,14,.8),(2.3,1.5,1.5)),((26,3,.7),(2,1.4,1.3)),((-11,-14,.6),(1.6,1.3,1.3))]:ball('Faceted stone',p,s,'Stone',1)
for x,y,s in [(-11,-1,1.3),(-8,3,1.6),(9,1,1.2),(10,10,1.8),(-9,12,1.1),(25,1,1.2),(29,5,1),(-10,-15,.9),(1,-1,1.3)]:plant((x,y,.1),s)
for i in range(3):ball('Entry stepping stone',(-6+groundRng.uniform(-.3,.3),-26.9-i*.4,.1),(1.1,.55,.16),'StoneLight',1)

# Warm interior layout and porch accessories shown in the reference.
section='Interior'
for i in range(16):box('Interior floor plank',(0,.5+i*.78,F+.045),(15.7,.75,.08),roomRng.choice(['Wood','WoodLight']),.015)
# NOTHING IS FURNISHED IN HERE. A trophy room is a BARE SHELL plus mounts, and
# everything a display needs is drawn by `TrophyRoom.standFor` off the mount
# names -- the shelf boards, the hero pedestal and the record desk.
#
# THE REASON IS CONSISTENCY ACROSS EIGHTEEN HOUSES, not tidiness. A rug, a
# bench and a records table authored here are THIS house's rug, bench and
# table: every other house would need its own drawn, exported and uploaded, and
# a player moving in would meet a different room with different furniture in
# different places. Drawn from the mounts, every house gets the same stations
# in the same shape for nothing, and a template's only job is to say WHERE and
# how many.
#
# What was here: a green woven rug and its border, a records table with four
# legs and an open book on it, and a bench with feet and a cushion. The table
# was the load-bearing one -- it existed to hold the career board at desk
# height -- and that is exactly the piece `standFor` now draws.
# NO DISPLAY FURNITURE IS AUTHORED HERE ANY MORE, AND THAT IS A DELIBERATE
# HAND-OVER RATHER THAN A DELETION.
#
# The rear-wall bookcase that used to stand here put its four shelf mounts ONE
# STUD apart on a 15.7-wide wall, so every trophy on it was scaled to a sixth
# of the size it was drawn at (assets/houses/docs/TROPHY-DISPLAY-PROPOSAL.md has the
# figures). The mounts moved to the left wall, 4.0 apart and 3.5 up -- and
# authoring the case to match them here does not reach the game: a template's
# visible geometry is UPLOADED MESHES, so furniture moved in this file changes
# nothing until 68 meshes are re-imported by hand, while the MOUNTS travel for
# free in the geometry report. Measured, that shipped a trophy hanging in mid
# air against a bare wall.
#
# So `TrophyRoom.standFor` draws the boards, the brackets and the hero pedestal
# from the mount names, and this file authors the mounts and the room. One owner
# for display furniture, and every future template gets it from its mounts.
# NO DRAWN FRAMES ON THE REAR WALL ANY MORE. `TrophyRoom.fillWall` builds the
# whole rack from the one `Wall` mount -- a frame for every achievement, filled
# with the trophy where it is earned and left as an empty socket where it is
# not -- so art drawing three more frames would double up on it, and at a
# fixed three would disagree with a catalogue of ten.
# The hero trophy's pedestal is drawn by `TrophyRoom.standFor` from the
# Featured mount, for the reason above. What this file owns is WHERE it stands:
# off-centre and to the right, clear of the rug and out of the doorway walk.

for x in (-5.7,5.7):
    box('Porch flower box',(x,-1.3,F+.8),(2.5,1.4,1.5),'WoodShade')
    for dx in (-.75,0,.75):plant((x+dx,-1.3,F+1.5),.6)
cutaway=True
for x in (-3.8,3.8):
    beam('Lantern bracket',(x,0,23.5),(x,-1,23.5),.15,mat='Iron')
    lantern((x,-1,21.8),.65)
cutaway=False
# THE MOUNTS. Names are the contract `TrophyRoom` reads (brief B2); where they
# are is art's choice, and this is the choice: the four shelves 4.0 apart along
# the LEFT wall's case, the hero on its own pedestal, the rack centred on the
# rear wall with the whole 15.6 studs of it to lay out in, and Legacy on the
# right wall where it is distinct from the achievement frames.
# THE YAW IS PART OF THE MOUNT: which way the thing standing there LOOKS.
# 180 faces the doorway (out of the room, -y in Blender), 90 faces off the left
# wall into the room, 270 faces off the right wall. 0 is the frame a mount has
# always had, which points at the rear wall -- so every mount that displays
# anything says something here.
for name,p,yaw in [
    ('Featured',(5.2,3.65,F+1.2),180),
    ('Shelf_1',(-6.4,5.15,F+2.03),90),('Shelf_2',(-6.4,9.15,F+2.03),90),
    ('Shelf_3',(-6.4,5.15,F+5.53),90),('Shelf_4',(-6.4,9.15,F+5.53),90),
    # 12.65 rather than 12.3: the rack's own backing plate is a tenth of a
    # stud thick, so a mount half a stud off the wall left the whole wall of
    # frames floating clear of it.
    ('Wall',(0,12.65,F+5.5),180),
    # THE MOUNT IS THE DESK SURFACE now that `standFor` draws the desk: its
    # top lands at the mount and its legs reach the floor. F+2.95 was the
    # height the AUTHORED book happened to sit at, on a table that is gone.
    ('Record',(5.4,9.3,F+1.3),180),
    # BETWEEN THE RIGHT WALL'S TWO WINDOWS, which the first placement sat
    # inside: they span y 3.8..6.2 and 8.8..11.2, so anything at y 4.5 hangs
    # over glass. Latent today because Legacy is deferred and this mount draws
    # nothing -- which is exactly the sort of thing that ships the day it does.
    ('Plaque_Legacy',(7.6,7.5,F+4.5),270),
    ('Door_Exit',(0,-1,F),180),
]:a.mount(name,p,yaw)

# Decorative ladder from the rear of the deck, as in the reference.
section='Ladder'
for x in (8.8,10.8):beam('Hanging ladder side',(x,14.5,5),(x,14.5,14),.1,mat='Rope',bevel=0)
for z in range(5,15):beam('Hanging ladder rung',(8.7,14.5,z),(10.9,14.5,z),.16,mat='Wood',bevel=.025)

# Keep stable named sections, while joining static pieces into bounded meshes.
groups=defaultdict(list)
for o in a.visual:groups[(o['section'],bool(o['cutaway']))].append(o)
merged=[]
for (name,hide),items in groups.items():
    chunks=[];chunk=[];count=0
    for o in items:
        o.data.calc_loop_triangles();n=len(o.data.loop_triangles)
        if count+n>16000 and chunk:chunks.append(chunk);chunk=[];count=0
        chunk.append(o);count+=n
    if chunk:chunks.append(chunk)
    for i,chunk in enumerate(chunks):
        bpy.ops.object.select_all(action='DESELECT')
        for o in chunk:o.select_set(True)
        bpy.context.view_layer.objects.active=chunk[0]
        if len(chunk)>1:bpy.ops.object.join()
        o=bpy.context.object;o.name=f'{name}_{i+1:02d}';o['cutaway']=hide
        merged.append(o)
a.visual=merged

# Export only asset geometry; staging lights/camera/ground never ship.
bpy.ops.object.select_all(action='DESELECT')
stats=[];points=[]
for o in a.visual:
    o.select_set(True);bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Triangulate export','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(o.data)
    stats.append({'name':o.name,'triangles':len(o.data.polygons),'nonManifoldEdges':sum(not e.is_manifold for e in bm.edges)})
    bm.free();points.extend(o.matrix_world@v.co for v in o.data.vertices)
lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
intrusions=[tuple(p) for o in a.visual if o['section']=='Oak' for v in o.data.vertices for p in [o.matrix_world@v.co] if -7.7<p.x<7.7 and .7<p.y<12.7 and F+.2<p.z<24.5]
assert not intrusions,('Oak vertices inside usable cabin',intrusions)
assert all(m['nonManifoldEdges']==0 and m['triangles']<20000 for m in stats),stats
assert hi[0]-lo[0]<60 and hi[1]-lo[1]<57,(lo,hi)
bpy.ops.export_scene.fbx(filepath=str(a.out/'treehouse-visual.fbx'),use_selection=True,object_types={'MESH'},axis_forward='Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
bpy.ops.wm.obj_export(filepath=str(a.out/'treehouse-visual.obj'),export_selected_objects=True,forward_axis='Z',up_axis='Y',export_materials=True)
bpy.ops.export_scene.gltf(filepath=str(a.out/'treehouse-visual.glb'),export_format='GLB',use_selection=True)
report={'id':'treehouse','revision':2,'reference':'assets/houses/design/fantasy-v2/treehouse-concept.png','status':'reference-led Blender art revision; no Studio integration or gameplay clearance certification','visualMeshes':len(stats),'triangles':sum(x['triangles'] for x in stats),'meshes':stats,'boundsBlender':{'min':lo,'max':hi,'size':[hi[i]-lo[i] for i in range(3)]},'paletteRGB':a.palette,'collisionBoxesDraft':a.colliders,'mountsBlender':a.mounts,'mountYawBlender':a.mountYaw,'floorHeight':F,'frontPlane':0,'coordinateMapping':'Blender (x,y,z) -> Roblox FBX/OBJ (-x,z,y)','studioChecks':'pending','geometryNote':'Static multipart art. Bridge is visibly sagged; collision and route integration need live testing.'}
(a.out/'geometry-report.json').write_text(json.dumps(report,indent=2))

amber=a.mat['Amber'].node_tree.nodes.get('Principled BSDF')
amber.inputs['Emission Color'].default_value=(1,.4,.035,1);amber.inputs['Emission Strength'].default_value=.8
# Save preview emission for the render only; exporter above remains flat colour.
a.scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.95,.93,.85,1)
a.scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
a.scene.cycles.samples=24 if opt.draft else 48
a.scene.render.resolution_x=1100 if opt.draft else 1600
a.scene.render.resolution_y=1100 if opt.draft else 1600
a.scene.view_settings.exposure=.4
try:a.scene.view_settings.look='AgX - Medium High Contrast'
except TypeError:pass
ground=bpy.data.materials.new('REVIEW warm ivory');ground.use_nodes=True;ground.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.93,.88,.76,1)
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.45));g=bpy.context.object;g.name='REVIEW_Ground';g.data.materials.append(ground)
# A small staging patch echoes the reference illustration. It is excluded
# from exports and clearly named REVIEW so the game keeps its own terrain.
def stage_patch(name,center,rx,ry,color):
    vs=[]
    for i in range(28):
        angle=i*math.tau/28;r=1+.08*math.sin(i*3.7)
        vs.append((center[0]+rx*r*math.cos(angle),center[1]+ry*r*math.sin(angle),-.39))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],[tuple(range(28))]);mesh.update()
    obj=bpy.data.objects.new(name,mesh);a.scene.collection.objects.link(obj)
    mat=bpy.data.materials.new(name);mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1);obj.data.materials.append(mat)
stage_patch('REVIEW Grass patch',(1,5),16,13,(.38,.46,.12))
stage_patch('REVIEW Lookout grass',(26,5),5.3,4.5,(.38,.46,.12))
stage_patch('REVIEW Sandy path',(-6,-24),5.5,7,(.67,.43,.19))
look=Vector((3,1.5,19))
for name,p,energy,size,color in [('Key',(-28,-38, 60),21000,30,(1,.85,.64)),('Fill',(40,-15,40),10000,26,(.74,.84,1)),('Rim',(10,35,60),24000,25,(1,.96,.8))]:
    d=bpy.data.lights.new('REVIEW_'+name,'AREA');o=bpy.data.objects.new('REVIEW_'+name,d);a.scene.collection.objects.link(o);o.location=p;d.energy=energy;d.shape='DISK';d.size=size;d.color=color;o.rotation_euler=(look-o.location).to_track_quat('-Z','Y').to_euler()
for p in ((0,3,20),(0,9,21)):
    d=bpy.data.lights.new('REVIEW Interior fill','AREA');o=bpy.data.objects.new(d.name,d);a.scene.collection.objects.link(o);o.location=p;d.energy=150;d.color=(1,.66,.3);d.size=5
d=bpy.data.cameras.new('REVIEW_Camera');cam=bpy.data.objects.new(d.name,d);a.scene.collection.objects.link(cam);a.scene.camera=cam;d.type='ORTHO';d.ortho_scale=67
def render(name,p,target=look,scale=67):
    cam.location=p;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();d.ortho_scale=scale
    a.scene.render.filepath=str(a.out/name);bpy.ops.render.render(write_still=True)
render('exterior.png',(39,-65,40))
if not opt.draft:
    render('front.png',(3,-75,32),look,64)
    for o in a.visual:
        if o['cutaway']:o.hide_render=True
    render('interior.png',(-28,-48,62),(0,5,18),46)
    for o in a.visual:o.hide_render=False
cam.location=(39,-65,40);cam.rotation_euler=(look-cam.location).to_track_quat('-Z','Y').to_euler();d.ortho_scale=67
bpy.ops.wm.save_as_mainfile(filepath=str(a.out/'treehouse.blend'))
print('TREEHOUSE_V2_REPORT '+json.dumps({k:report[k] for k in ('visualMeshes','triangles','boundsBlender')}))
