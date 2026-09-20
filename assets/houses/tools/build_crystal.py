"""Crystal Spire exterior from the saved concept. No interiors/runtime changes."""
import bpy, math, sys, argparse
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from exterior_art import ExteriorArt

p=argparse.ArgumentParser();p.add_argument('--draft',action='store_true')
opt=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
a=ExteriorArt('crystal',1,{
    'Rock':(76,74,88),'RockLight':(98,95,111),'RockShade':(53,52,66),'Stone':(137,129,144),
    'Violet':(110,43,190),'VioletLight':(144,63,219),'VioletDeep':(68,24,130),
    'Glow':(143,49,229),'Ink':(30,25,37),'Door':(63,45,67),'Frame':(88,73,104),
    'Amber':(255,182,66),'Brass':(190,144,74),
})

def shard(name,x,y,z,r,h,lean=(0,0),section='Crystals'):
    a.section=section
    n=6;verts=[]
    levels=[(0,.77),(.12,1),(.39,.91),(.68,.96),(.83,.64)]
    for ring,(level,rad) in enumerate(levels):
        for i in range(n):
            ang=i*math.tau/n+math.pi/6+.09*math.sin(ring*2.1)
            irregular=.035*math.sin(i*2.3+ring) if 0<ring<4 else 0
            verts.append((x+r*rad*math.cos(ang)+lean[0]*level,y+r*rad*math.sin(ang)+lean[1]*level,z+h*(level+irregular)))
    verts.append((x+lean[0],y+lean[1],z+h))
    fs=[tuple(range(n-1,-1,-1))]
    for ring in range(len(levels)-1):
        for i in range(n):
            aa,bb,cc,dd=ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i
            fs.extend([(aa,bb,cc),(aa,cc,dd)])
    for i in range(n):fs.append((24+i,24+(i+1)%n,30))
    o=a.tag(a.mesh(name,verts,fs,'Violet'))
    for mat in ('VioletLight','VioletDeep'):o.data.materials.append(a.mat[mat])
    for i,face in enumerate(o.data.polygons):face.material_index=[0,0,2,0,1,0,0,2,0,1,0,0][i%12]
    return o

a.section='Foundation'
a.cylinder_art('Faceted stone plinth',(0,9,.5),11.9,1,'RockShade',12)
# Pin the decorative front wall to Y=0 and keep it closed for the MVP.
a.section='RockShell'
a.prism('Ground rock facade',[(-9,.5),(9,.5),(10,7),(7,11),(3,13),(-1,10.5),(-6,12),(-10,7)],0,8,'Rock')
a.rock('Rear shoulder',(-.5,12,8),(10.8,8,9),'RockShade',2)
# Tall asymmetric rock fingers frame the glowing central tower rather than hiding it.
a.prism('Left tall basalt shoulder',[(-7,8),(-2.9,8),(-3.2,32),(-4.8,35),(-7,29)],3,11,'RockLight')
a.prism('Right mid basalt shoulder',[(3,6),(8,7),(8.4,22),(6.4,27),(3.1,22.5)],4,12,'Rock')
a.prism('Front central basalt tooth',[(-1.8,7),(2.9,8),(1.7,18),(-.5,21),(-2,17)],1.2,5.5,'RockLight')
a.prism('Left side rock',[(-11,1),(-7,1),(-6.8,16),(-9,19),(-11,13)],5,12,'Rock')
a.prism('Right side rock',[(7,1),(11,2),(10.4,14),(8.4,17),(6.7,12)],8,16,'RockLight')
for rock in list(a.visual):
    if rock.get('section')=='RockShell':a.bevel(rock,.4,1)
for i,(x,y,z,s) in enumerate([(-9,1,2,(2.6,2.4,2.8)),(-10,7,3,(2.0,3,4)),(9,2,2,(2.4,2.2,3)),(9,13,3,(2.4,3,4)),(-7,17,2,(3,2.4,3)),(4,18,2,(3.3,2.6,3))]):
    a.rock('Foundation boulder '+str(i),(x,y,z),s,'RockLight' if i%2 else 'Rock',i)

shard('Dominant central crystal',.4,8.5,9,4.0,36,(.8,-.2))
shard('Left crown crystal',-7.1,8.8,14,1.8,11,(-1,-.7))
shard('Right crown crystal',7.6,11.8,14,1.8,13,(1.2,.5))
shard('Rear crown crystal',-1,15.3,16,2.4,17,(-1,1))
for i,(x,y,z,r,h) in enumerate([(-9.3,-.1,.8,.75,3.7),(-6.7,-.5,.8,.55,2.7),(8.8,.7,.8,.9,4.8),(9.8,8.7,3,.8,5.8),(-10,12,4,1,6.5)]):
    shard('Small crystal '+str(i),x,y,z,r,h,(.25,0))

# Continuous embedded accent seams, separate groups for safe colour-only pulse.
for i,(x,y,z,r,h) in enumerate([(-2.5,5.15,12,.23,15),(.1,4.82,8,.27,12),(4,6.1,17,.22,12)],1):
    o=shard('HouseFX_CrystalAccent_'+str(i),x,y,z,r,h,(.4,0),'HouseFX_CrystalAccent_'+str(i))
    o.data.materials.clear();o.data.materials.append(a.mat['Glow'])
    for f in o.data.polygons:f.material_index=0

a.section='Entry'
a.pointed('Deep door reveal',3.4,-.18,.8,5.7,8.2,'RockShade',.45)
a.pointed('Door frame',3.4,-.45,.8,5.15,7.65,'Frame',.38)
a.pointed('Closed timber door',3.4,-.69,1,4.3,6.95,'Door',.16)
for dx in (-1.25,-.62,0,.62,1.25):
    a.box('Door board seam',(3.4+dx,-.81,3.75),(.035,.04,5.3),'Ink',0)
a.tube('Door knocker',(4.25,-.88,3.2),.23,.055,'Brass',(0,-1,0),12)
a.box('Door threshold',(3.4,-.6,.86),(5.8,1.2,.3),'Stone',.04)
for i in range(3):
    a.box('Approach slab '+str(i),(3.4,-3.2+i*.95,.18+i*.24),(5.9-i*.25,1.08,.35+i*.04),'Stone',.07)

a.section='Windows'
a.pointed_window('Warm ground window',-5.1,-.10,2.2,2.6,4.8,'Frame','Amber')
a.pointed_window('Unlit tall left window',-5.1,2.9,24,1.6,4.8,'RockShade','VioletDeep')
a.pointed_window('Unlit right window',6,3.88,16,1.7,4.3,'RockShade','VioletDeep')
a.pointed_window('Unlit central window',.2,1.05,12,1.4,3.9,'RockShade','VioletDeep')
a.glow('Glow',.85);a.glow('Amber',.65)
fx=[{'section':'HouseFX_CrystalAccent_'+str(i),'kind':'pulse','periodSeconds':9,'phase':(i-1)/3,'intensity':[.45,.8],'fixedGeometry':True} for i in range(1,4)]
a.complete('assets/houses/design/mvp-exteriors/crystal-spire-concept.png',(0,8,21),(57,-73,46),55,fx,opt.draft)
