"""Sculpted Gloop House against the approved green exterior/interior reference."""
import bpy,math,sys,json,argparse
from pathlib import Path
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from house_art import HouseArt

parser=argparse.ArgumentParser();parser.add_argument('--draft',action='store_true')
opt=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
a=HouseArt('slime',2,{
    'Wall':(111,193,28),'WallLight':(145,218,36),'Roof':(22,104,46),
    'Frame':(25,91,29),'DeepGreen':(25,65,27),'Floor':(108,167,39),
    'Puddle':(118,205,25),'Purple':(117,46,133),'PurpleShade':(77,31,94),
    'PurpleLight':(151,67,165),
    'Gold':(236,179,55),'Amber':(255,193,65),'Cream':(233,220,163),
    'Stone':(201,191,150),'Book':(90,117,46),'Leaf':(40,116,42),
})
F=.5
def roofz(x,y):
    ridge=max(0,1-math.sqrt((x+1.1)**2+.45**2)/16.5)
    return 12.8+7*ridge**1.2+.6*math.cos((y-7)*.28)+.3*math.sin(x*.3+y*.2)+math.exp(-((x-7)/3.5)**2-((y-12)/6)**2)

def prism(name,path,bottom,top,mat):
    n=len(path);vs=[(x,y,z) for z in (bottom,top) for x,y in path]
    return a.tag(a.mesh(name,vs,[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat))

def closed_roof():
    outline=a.rounded_outline(31,28,4.8,16);n=len(outline);vs=[];rings=36
    for j in range(rings):
        t=1-j/(rings+.1)
        for x,y in outline:
            x=x*t;y=11.5+y*t;vs.append((x,y,roofz(x,y)))
    vs.append((0,11.5,roofz(0,11.5)));topcount=len(vs)
    faces=[]
    for j in range(rings-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    for i in range(n):faces.append(((rings-1)*n+i,(rings-1)*n+(i+1)%n,topcount-1))
    vs.extend((x,y,z-1.15) for x,y,z in list(vs))
    faces.extend(tuple(v+topcount for v in reversed(f)) for f in list(faces))
    for i in range(n):faces.append((i,i+topcount,(i+1)%n+topcount,(i+1)%n))
    return a.tag(a.mesh('Thick asymmetric goo roof',vs,faces,'Roof'))

print('Sculpting hollow green wall shell',flush=True)
a.section='Walls';a.smooth=True
outer=a.rounded_outline(26,24,4);inner=a.rounded_outline(23.8,21.8,2.9)
assert len(outer)==len(inner)
n=len(outer);levels=[0,.18,.4,.65,.84,1];vs=[]
for inside,path in enumerate((outer,inner)):
    for j,t in enumerate(levels):
        for i,(x,y) in enumerate(path):
            angle=math.atan2(y,x)
            bulge=(math.sin(t*math.pi)*(.033+.025*math.sin(angle*5+.4))) if not inside else 0
            xx=x*(1+bulge);yy=y*(1+bulge)+11.5
            z=.35+t*(roofz(xx,yy)-.65-.35)
            vs.append((xx,yy,z))
faces=[];offset=n*len(levels)
for j in range(len(levels)-1):
    for i in range(n):
        q=(i+1)%n
        faces.append((j*n+i,j*n+q,(j+1)*n+q,(j+1)*n+i))
        faces.append((offset+j*n+i,offset+(j+1)*n+i,offset+(j+1)*n+q,offset+j*n+q))
for i in range(n):
    q=(i+1)%n;top=(len(levels)-1)*n
    faces.append((i,offset+i,offset+q,q))
    faces.append((top+i,top+q,offset+top+q,offset+top+i))
wall=a.tag(a.mesh('Continuous hollow wall',vs,faces,'Wall'))
wallparts=[wall]
for side in (-1,1):
    for y,z,scale in ((2,3.9,(2.1,2.3,3.8)),(20.7,4.1,(2.1,2.3,4)),(10,3.1,(1.35,2.4,2.9))):
        wallparts.append(a.ellipsoid('Swollen wall corner',(side*11.5,y,z),scale,'Wall'))
    wallparts.append(a.droplet('Melted front wall',side*4.2,-.55,roofz(side*4.2,0)-1,6.8,1.05,'Wall'))
wall=a.fuse(wallparts,'Sculpted hollow walls',.19,10500,True)
# Windows and entrance are cut after sculpting, so openings remain clean.
doorcut=a.arch_shape('Door cut',6.4,6.4,.1,6,'Wall',(0,-.2,0))
a.cut(wall,doorcut)

def window(p,angle=0,front=False):
    a.section='FrontWindows' if front else 'SideWindows';a.hide_cut=front
    cut=a.arch_shape('Window cut',4.2,5.8,3.0,6,'Wall',p,angle)
    a.cut(wall,cut)
    frame=a.arch_shape('Rounded slime window frame',5.25,5.8,2.5,.95,'Frame',p,angle)
    hole=a.arch_shape('Window frame opening',4.15,5.8,3.02,3,'Frame',p,angle)
    a.cut(frame,hole);a.bevel(frame,.13,2)
    glass=a.arch_shape('Warm amber pane',4.13,5.8,3.04,.14,'Amber',p,angle)
    # Front local -Y points outside; rotate it to +X on the right side.
    m=Matrix.Translation(Vector(p))@Matrix.Rotation(angle,4,'Z')
    for name,pos,size in [('Vertical mullion',(0,-.64,5.4),(.22,.23,4.7)),('Cross mullion',(0,-.64,5.35),(4.25,.23,.25))]:
        o=a.box(name,pos,size,'Frame',.06);bpy.context.view_layer.update();o.matrix_world=m@o.matrix_world
    for o in (frame,glass):
        for f in o.data.polygons:f.use_smooth=True
    drip=a.droplet('Window hood drip',0,0,8.6,1.6,.38,'Frame')
    drip.matrix_world=m@Matrix.Translation(Vector((.7,-.42,0)))@drip.matrix_world

window((-8.3,-.7,0),front=True);window((8.3,-.7,0),front=True)
window((13.1,11.5,0),math.pi/2);window((-13.1,11.5,0),-math.pi/2)

a.section='EntryFrame';a.hide_cut=True
frame=a.arch_shape('Thick rounded green doorway',8.1,6.4,.3,1.05,'Frame',(0,-.65,0))
a.cut(frame,a.arch_shape('Doorway clear opening',6.4,6.4,.1,3,'Frame',(0,-.65,0)))
a.bevel(frame,.18,3)
a.section='Door'
door=a.arch_shape('Purple oak door',6.16,6.35,F,.36,'Purple')
a.bevel(door,.1,2)
for x in (-2.25,-1.5,-.75,0,.75,1.5,2.25):
    top=6.35+math.sqrt(max(0,3.08**2-x*x))-.15
    a.box('Purple plank groove',(x,-.194,(F+.15+top)/2),(.045,.025,top-F-.15),'PurpleShade',.008)
a.ellipsoid('Purple door knob',(2.05,-.4,4.45),(.34,.29,.34),'PurpleLight')
pose=Matrix.Translation(Vector((-3.1,-1.2,0)))@Matrix.Rotation(math.radians(-100),4,'Z')@Matrix.Translation(Vector((3.1,0,0)))
bpy.context.view_layer.update()
for o in a.visual:
    if o['section']=='Door':o.matrix_world=pose@o.matrix_world

print('Sculpting roof, drips and puddles',flush=True)
a.section='Roof';a.hide_cut=True;a.smooth=True
roofparts=[closed_roof()]
for x in (-13,-10,-7,-4,-1,2,5,8,11,14):
    roofparts.append(a.ellipsoid('Fat rolled front eave',(x,-1.85,roofz(x,-1.85)-.55),(2.0,1.35,1.2),'Roof'))
for side in (-1,1):
    for y in (3,8,13,18,23):
        roofparts.append(a.ellipsoid('Fat side eave',(side*14.35,y,roofz(side*14.35,y)-.65),(1.25,2.9,1.15),'Roof'))
for x,length,r in [(-13,3.5,1.2),(-9,4.3,1.25),(-4.8,4.7,1.4),(1.0,3.4,1.45),(5.8,4.4,1.25),(10.5,3.6,1.25),(13.5,2.8,1.1)]:
    roofparts.append(a.droplet('Front roof drip',x,-1.9,roofz(x,-1.9)-.25,length,r,'Roof'))
for side in (-1,1):
    for y,length in ((3,3.2),(9,3.9),(16,3.4),(22,2.8)):
        roofparts.append(a.droplet('Side roof drip',side*14.2,y,roofz(side*14.2,y)-.2,length,1.25,'Roof'))
roof=a.fuse(roofparts,'Continuous sagging roof',.18,10000,True)

a.section='Chimney'
parts=[]
for z,xy,sc in [(15.7,(7.3,17),(1.8,1.7,2.4)),(18.4,(7.8,17.2),(1.5,1.5,2.5)),(21,(8,17.3),(1.65,1.5,2.0)),(22.5,(7.8,17.3),(2.1,1.9,.85))]:
    parts.append(a.ellipsoid('Slime chimney',(*xy,z),sc,'WallLight'))
for i in range(6):
    angle=i*math.tau/6
    parts.append(a.droplet('Chimney overhang drip',7.8+math.cos(angle)*1.6,17.3+math.sin(angle)*1.45,22.4,1.3+(i%3)*.4,.55,'WallLight'))
a.fuse(parts,'Blob chimney',.16,2300,True)

a.section='PulseDrips';a.hide_cut=True
motions=[]
for i,(x,y,length,r) in enumerate([(-11.2,-2.0,2.2,.55),(12.9,5,2.7,.55),(9,23.6,2.1,.55)],1):
    top=roofz(x,y)-.5
    o=a.droplet('HouseFX_Pulse_'+str(i),x,y,top,length,r,'Roof')
    # Retain the semantic pivot when this section is exported separately.
    pivot=Vector((x,y,top))
    for v in o.data.vertices:v.co-=pivot
    o.location=pivot;o['section']='HouseFX_Pulse_'+str(i)
    motions.append({'object':o['section'],'pivotBlender':list(pivot),'kind':'pulse','scaleZ':[1,1.045],'periodSeconds':5.5+i*.4,'phaseSeconds':i*.8,'collision':False})

a.section='Puddles';a.hide_cut=False
base=[]
for x,y in a.rounded_outline(29.5,27.5,5):
    angle=math.atan2(y,x);s=1+.032*math.sin(angle*7)+.02*math.cos(angle*11)
    base.append((x*s,11.5+y*s))
parts=[prism('Broad continuous slime pool',base,.01,.35,'Puddle')]
outline=a.rounded_outline(27,25,4.5)
for i,(x,y) in enumerate(outline[::3]):
    if y<-10 and abs(x)<4:continue
    parts.append(a.ellipsoid('Foundation goo',(x,y+11.5,.27),(2.0,1.65,.35),'Puddle'))
for x,y,s in [(-11,-1.4,.8),(-6,-1.5,.7),(6,-1.6,.8),(11,-.8,.9),(14,6,.8),(-14,17,.75)]:
    parts.append(a.ellipsoid('Goo bubble',(x,y,s*.65),(s,s*.9,s),'Puddle'))
a.fuse(parts,'Continuous slime puddle',.13,3500,True)

a.section='Floor'
prism('Flat interior floor',[(x,y+11.5) for x,y in a.rounded_outline(25,23,3.5)],.1,F,'Floor')
for i,(y,z,w) in enumerate([(-1,.35,6),(-3.3,.22,4.9),(-5.6,.12,4)]):
    prism('Pale entry stone '+str(i),[(x,y+yy) for x,yy in a.rounded_outline(w,1.95,.65,4)],z-.2,z,'Stone')

# NOTHING IS FURNISHED IN HERE, AND THE STATIONS ARE NOT AUTHORED EITHER.
#
# This house used to draw its own arched trophy cabinet with three shelves, a
# featured pedestal on a rug, a legacy panel with an emblem, a records desk
# with an open book, two plants and a bench. All of it is gone, and it is a
# hand-over rather than a loss: `TrophyRoom.standFor` draws the shelf boards,
# the hero pedestal and the record desk from the MOUNT NAMES, so the room is a
# bare shell plus a handful of coordinates.
#
# THE REASON IS CONSISTENCY ACROSS EIGHTEEN HOUSES. An authored cabinet is THIS
# house's cabinet: every other house needs its own drawn, exported and
# uploaded, in its own place, at its own spacing -- and this one's shelves sat
# 3.0 apart against the treehouse's 4.0, so the same trophy was a different
# size depending on whose house you were standing in. Drawn from the mounts,
# every house shows the same stations at the same size, and a template's only
# job is to say where they are and how many shelves it carries.
#
# What is authored here is the ROOM: the floor, the walls, the windows and the
# doorway. That is the part that should differ between houses.

# Preview awards are excluded from exports. Fable supplies actual earned
# trophies at the named mounts, so a new owner is not granted fake awards.
a.section='ExampleAwards';a.preview=True
def cup(x,y,z,s=1):
    a.box('Example cup base',(x,y,z+.12*s),(.9*s,.9*s,.24*s),'Gold',.07*s)
    a.ellipsoid('Example cup stem',(x,y,z+.62*s),(.16*s,.16*s,.53*s),'Gold')
    profile=[(.2,.8),(.55,1.0),(.8,1.6),(.83,1.85),(.72,1.85),(.69,1.65),(.44,1.12),(.15,.98)]
    vs=[];n=16
    for r,h in profile:
        for i in range(n):
            ang=i*math.tau/n;vs.append((x+r*s*math.cos(ang),y+r*s*math.sin(ang),z+h*s))
    fs=[]
    for j in range(len(profile)):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,((j+1)%len(profile))*n+(i+1)%n,((j+1)%len(profile))*n+i))
    bowl=a.tag(a.mesh('Example gold cup',vs,fs,'Gold'))
    for f in bowl.data.polygons:f.use_smooth=True
    for side in (-1,1):
        pts=[(x+side*(.6+.5*math.sin(t*math.pi/8))*s,y,z+(1.65-t*.1)*s) for t in range(9)]
        for p,q in zip(pts,pts[1:]):a.rod('Cup handle',p,q,.075*s,'Gold')

cup(0,13.6,F+1.68,1.25)
cup(-8,20.2,F+2.38,.65);cup(-5,20.2,F+4.58,.72)
for x,z in ((-5,F+2.75),(-8,F+4.97)):
    a.ellipsoid('Example medal',(x,20.2,z),(.48,.16,.48),'Gold')
a.preview=False

# Stable attachment names plus explicit approach points for proximity menus.
# THE SAME LAYOUT AS THE TREEHOUSE, IN THIS ROOM'S OWN DIMENSIONS -- shelves
# along the left wall 4.0 apart and 3.5 up, the hero on a pedestal off the
# doorway walk, the rack across the rear wall and the record desk to the right.
# Measured against this room's interior: x -11.80..11.80, y 0.55..22.35, floor
# z 0.50, ceiling 12.75.
#
# The YAW says which way the thing standing there looks: 180 faces the doorway,
# 90 faces off the left wall into the room, 270 off the right wall. Without one
# a mount faces the rear wall, which is the frame every mount used to have.
mounts=[
    ('Featured',(5.0,6.0,F+1.2),180),
    ('Shelf_1',(-10.40,9.0,F+2.03),90),('Shelf_2',(-10.40,13.0,F+2.03),90),
    ('Shelf_3',(-10.40,9.0,F+5.53),90),('Shelf_4',(-10.40,13.0,F+5.53),90),
    ('Wall',(0,22.15,6.5),180),
    # The mount IS the desk surface: `standFor` draws the top at it and the
    # legs down to the floor, so it sits at desk height rather than at the
    # height the old authored book happened to be.
    ('Record',(7.0,18.0,F+1.3),180),
    ('Plaque_Legacy',(11.60,8.0,6.0),270),
    ('Door_Exit',(0,-1,F),180),
    # The six interaction markers the brief fixes, kept for the prompts that
    # are not built yet. They cost no upload -- mounts travel in the geometry
    # report -- so they can move for free once there is something to open.
    ('Interact_Achievements',(-9.0,11.0,4.5),90),('Stand_Achievements',(-7.0,11.0,F),90),
    ('Interact_Records',(7.0,18.0,3.4),180),('Stand_Records',(7.0,15.6,F),180),
    ('Interact_Legacy',(11.3,8.0,6.0),270),('Stand_Legacy',(9.0,8.0,F),270),
]
for name,p,yaw in mounts:a.mount(name,p,yaw)
a.collider('Floor',(0,11.5,.3),(24.6,22.6,.4))
for side in (-1,1):
    a.collider('SideWall'+str(side),(side*12.35,11.5,6.5),(1.1,22,12))
    a.collider('FrontJamb'+str(side),(side*8,0,6.5),(9.5,1.1,12))
a.collider('RearWall',(0,22.9,6.5),(24.6,1.1,12))
a.collider('DoorLintel',(0,0,11.4),(6.4,1.1,3.6))
a.collider('Ceiling',(0,11.5,12.9),(23.5,21.6,.3))
routes=[{'name':'Entry to open centre','points':[[0,-7,F],[0,1,F],[0,8,F]]},
        {'name':'Achievement approach','points':[[0,8,F],[-6.5,10,F],[-6.5,17.3,F]]},
        {'name':'Records approach','points':[[0,8,F],[6.5,10,F],[7.1,14.9,F]]},
        {'name':'Legacy approach','points':[[7.1,14.9,F],[3.5,14.9,F],[3.5,18.8,F],[1,18.8,F]]}]
(a.out/'animation-handoff.json').write_text(json.dumps({'status':'decorative motion specification only; no runtime animation installed','drips':motions,'constraints':'Only scale hanging goo, anchored at its top. Keep wall, doorway, floor and collision static.'},indent=2))
a.merge_sections()
report=a.export_art({'reference':'assets/houses/design/fantasy-v2/gloop-house-concept.png','floorHeight':F,'doorWidth':6.4,'doorCrownHeight':9.6,'routesBlender':routes,'status':'physical art revision with draft interaction mounts; Studio import and actual avatar tests pending','coordinateMapping':'Blender (x,y,z) -> Roblox FBX/OBJ (-x,z,y)','previewAwards':'excluded from all exports; actual player trophies belong to runtime data'})

# Cutaway is a render-only copy of the shell, closed at the clipping plane.
original=next(o for o in a.visual if o['section']=='Walls')
cutwall=original.copy();cutwall.data=original.data.copy();cutwall.name='REVIEW_CutawayWall';a.scene.collection.objects.link(cutwall)
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,-5,12));cutter=bpy.context.object;cutter.dimensions=(65,15,40)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bpy.context.view_layer.objects.active=cutwall
mod=cutwall.modifiers.new('Interior presentation cut','BOOLEAN');mod.object=cutter;mod.operation='DIFFERENCE';mod.solver='EXACT'
bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True);cutwall.hide_render=True
for name in ('Wall','WallLight','Roof','Frame','Puddle','Purple','PurpleLight'):
    node=a.mat[name].node_tree.nodes.get('Principled BSDF');node.inputs['Roughness'].default_value=.38;node.inputs['Coat Weight'].default_value=.1;node.inputs['Specular IOR Level'].default_value=.22
roofshader=a.mat['Roof'].node_tree.nodes.get('Principled BSDF')
roofshader.inputs['Roughness'].default_value=.56;roofshader.inputs['Coat Weight'].default_value=.025
try:a.scene.view_settings.look='AgX - Medium High Contrast'
except TypeError:pass
amber=a.mat['Amber'].node_tree.nodes.get('Principled BSDF');amber.inputs['Emission Color'].default_value=(1,.5,.06,1);amber.inputs['Emission Strength'].default_value=.8
gold=a.mat['Gold'].node_tree.nodes.get('Principled BSDF');gold.inputs['Metallic'].default_value=.2;gold.inputs['Roughness'].default_value=.3
a.stage((0,9,9),46,(38,-48,32),opt.draft)
a.render_view('exterior.png')
if not opt.draft:
    a.render_view('front.png',(0,-60,17),scale=42)
    original.hide_render=True;cutwall.hide_render=False
    for o in a.visual:
        if o['hide_cut']:o.hide_render=True
    a.render_view('interior.png',(0,-38,44),(0,11,5),37.5)
    for o in a.visual:o.hide_render=False
    cutwall.hide_render=True
a.save_source()
print('GLOOP_V2_SAVED',flush=True)
