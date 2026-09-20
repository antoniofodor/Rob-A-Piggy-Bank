"""Remaining saved fantasy concepts -> exterior-only Blender models.

Blender -b --python this_file.py -- portal (or another stable house ID).
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from house_paths import house_slug
import bpy,math,sys,json
from pathlib import Path
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from fantasy_parts import FantasyArt,BASE

def art(slug,palette):return FantasyArt(slug,1,{**BASE,**palette})
def ref(slug):return f'assets/houses/design/fantasy-v3/{house_slug(slug)}.png'

def portal():
    a=art('portal',{'WarmWall':(218,204,173),'WarmRoof':(64,87,119),'FarWall':(92,53,136),'FarRoof':(33,99,111),'Rim':(63,35,120),'Glow':(117,44,194)})
    a.base(40,32,y=12)
    # Follow the saved concept's facade split; front/back prose ambiguity is documented.
    for side,wall,roof in [(-1,'WarmWall','WarmRoof'),(1,'FarWall','FarRoof')]:
        a.section='NearHouse' if side<0 else 'FarHouse'
        a.box('Half house wall',(side*8.2,12,8.8),(16.35,24,16),wall,.18)
        a.box('Lower belt',(side*8.2,-.16,1.8),(16.4,.4,.7),'Cream' if side<0 else 'Teal',.05)
        for x in (side*.6,side*15.7):a.box('Corner post',(x,-.28,8.5),(.45,.45,15.4),'Cream' if side<0 else 'Teal',.06)
        a.roof('RoofHalf'+str(side),side*8.2,12,18,27,16.5,6,roof,'Cream' if side<0 else 'Teal',5)
        a.section='Dormer'+str(side)
        a.prism('Dormer face',[(side*8.2-2.4,17),(side*8.2+2.4,17),(side*8.2+2.4,21),(side*8.2,24.5),(side*8.2-2.4,21)],-.5,3.6,wall)
        a.pointed_window('Unlit dormer',side*8.2,-.65,18.1,2.2,4,'Cream' if side<0 else 'Teal','DarkGlass')
        a.roof('Dormer roof'+str(side),side*8.2,1.6,6,5.2,21.5,3.5,roof,'Cream' if side<0 else 'Teal',3)
        for obj in a.visual:
            if obj.get('section') in ('Dormer'+str(side),'Dormer roof'+str(side)):obj.location.y-=2
        a.section='Chimneys';a.box('Chimney',(side*13,17,23),(2.5,2.8,9),wall,.08)
        for z in (21,24,27):a.box('Chimney course',(side*13,17,z),(2.9,3.2,.4),'Cream' if side<0 else 'Teal',.06)
    a.door(-8.2,-.4,1.0,4.5,7.5,'Cream','Timber')
    a.section='Windows'
    for x in (-13,-3.5):a.pointed_window('Warm ground window',x,-.16,4,2.1,4.7,'Cream','Amber')
    for x in (5.2,11.4):a.pointed_window('Far ground window',x,-.16,4,2.5,5,'Teal','DarkGlass')
    # Ring lies in Y/Z and separates the two facade halves as in the saved image.
    a.section='PortalFrame';a.tube('Standing ring',(0,12,20.5),19.2,1.05,'Rim',(1,0,0),48)
    a.tube('Inner collar',(.08,12,20.5),18.3,.20,'Teal',(1,0,0),48)
    fx=[]
    for i in range(12):
        t=i*math.tau/12;y=12+19.2*math.cos(t);z=20.5+19.2*math.sin(t)
        a.section='HouseFX_RingRim_'+str(i+1)
        a.gem('Ring jewel',(1.1,y,z),.7,2.2,'Glow' if i%2 else 'Teal')
        fx.append({'section':a.section,'kind':'cycle','periodSeconds':8,'phase':i/12,'fixedGeometry':True})
    for i in range(3):
        a.section='HouseFX_DecorStep_'+str(i+1)
        a.box('Floating decorative slab',(21.5,10+i*2,9+i*4),(3.7,3.5,.6),'Teal',.12)
        fx.append({'section':a.section,'kind':'bob','periodSeconds':8,'phase':i/3,'amplitudeStuds':.3})
    a.section='Garden'
    for x,y in [(-17,2),(-16,20),(16,22),(16,3)]:
        a.rock('Garden rock',(x,y,1.4),(1.4,1.4,1.5),'Stone',x)
    a.steps(6,4,.25,.85)
    # Shift approach to the near-house doorway.
    for o in a.visual:
        if o.get('section')=='Approach':o.location.x-=8.2
    for x in (-11.3,-5.1):a.lantern('Near lantern',(x,-.7,9),'Amber',.75)
    a.glow('Glow',.75)
    a.finish(ref('portal'),(0,12,19),(68,-78,45),57,fx)

def thundercloud():
    a=art('thundercloud',{'Wall':(62,80,113),'Trim':(109,133,176),'Roof':(49,65,96),'Cloud':(91,108,143),'CloudLight':(112,129,163),'Lightning':(141,109,229),'Rain':(67,150,228)})
    a.base(34,26,'Cloud',y=11,top=2)
    a.section='CloudFoundation'
    for i,(x,y,s) in enumerate([(-16,3,6),(16,3,6),(-20,12,5),(20,12,5),(-13,22,6),(13,22,6),(0,24,6),(-9,0,5),(9,0,5)]):
        a.rock('Faceted cloud '+str(i),(x,y,6),(s,s*.86,s*.82),'CloudLight' if i%2 else 'Cloud',i)
    a.section='CurtainWalls'
    a.box('Fortress lower hall',(0,16,13),(30,16,17),'Wall',.3)
    a.box('Battlement band',(0,7.6,21.3),(32,.9,.7),'Trim',.06)
    for x in range(-15,16,3):a.box('Wall merlon',(x,7.5,22.2),(1.0,1.0,1.3),'Trim',.06)
    a.oct_tower('CentralTower',0,11,4,6.3,39,'Wall','Trim','Roof',10)
    for x in (-13,13):a.oct_tower('SideTower'+str(x),x,8,4,4.5,28,'Wall','Trim','Roof',8)
    a.door(0,4.15,5.1,5.2,8,'Trim','Timber')
    # Tall central tower front is at Y=4.7. Stair connects from outside clouds.
    a.steps(8,10,.51,1.0,y=3.7,mat='Trim')
    for x in (-4.65,4.65):
        a.section='StairRails'
        a.rod('Fixed stone stair rail',(x,-5.4,1.8),(x,4,6.8),.38,'Trim')
        for y,z in [(-5.5,1.5),(3.7,6.2)]:a.lantern('Stair lamp',(x,y,z),'Amber',.8)
    fx=[]
    for side in (-1,1):
        a.section='HouseFX_CloudLightning_'+str(side)
        points=[(side*x,-2.6,z) for x,z in [(5.5,6.5),(9,7.5),(12,6.4),(15,8),(19,7.0)]]
        for u,v in zip(points,points[1:]):a.rod('Lightning inlay',u,v,.22,'Lightning')
        fx.append({'section':a.section,'kind':'beacon','periodSeconds':10,'phase':0 if side<0 else .5,'fixedGeometry':True})
    for i,(x,y) in enumerate([(-20,3),(-16,0),(-10,-1),(10,-1),(16,0),(20,3)],1):
        a.section='HouseFX_RainBar_'+str(i);a.box('Rain streak',(x,y,1.8),(.15,.18,1.6),'Rain',.035)
        fx.append({'section':a.section,'kind':'cycle','periodSeconds':3,'phase':i/6,'travelStuds':1.5,'constraint':'Fade before reset; never flash'})
    a.section='Crest';a.gem('Storm diamond',(0,4.28,19),1.7,4,'Trim')
    a.section='HallWindows'
    for x in (-7.7,7.7):a.pointed_window('Hall warm window',x,7.45,7,1.4,4.8,'Trim','Amber')
    a.glow('Lightning',.8);a.glow('Rain',.25)
    a.finish(ref('thundercloud'),(0,10,25),(65,-85,48),65,fx)

def void():
    a=art('void',{'Black':(17,17,19),'BlackRoof':(24,21,31),'BlackTrim':(32,27,41),'Trace':(105,34,187),'Star':(163,65,224),'Nebula':(49,16,85),'Planet':(55,27,88)})
    a.base(49,34,'BlackTrim',y=12,top=1.2)
    a.section='Manor'
    a.box('Central manor',(0,12,14),(16,24,25.6),'Black',.14)
    for x in (-12.5,12.5):
        a.box('Side wing',(x,13,8),(9,22,13.6),'Black',.15)
        a.roof('Wing roof'+str(x),x,13,12,25,15,5,'BlackRoof','Trace',4)
        a.box('Upper front bay',(x*.58,3.6,21),(7,8,15),'Black',.1)
        a.roof('Bay roof'+str(x),x*.58,4,9,11,28.5,5,'BlackRoof','Trace',4)
        for z in (8,21):a.pointed_window('Star window',x if z==8 else x*.58,1.5 if z==8 else -.57,z-3,2.2,6,'BlackTrim','Nebula')
    a.roof('Central roof',0,12,20,26,27,7,'BlackRoof','Trace',5)
    a.section='CentralTower'
    a.cylinder_art('Octagonal upper tower',(0,14,41),6.3,22,'Black',8)
    for z in (31,51):a.cylinder_art('Tower cornice',(0,14,z),7,.65,'BlackTrim',8)
    # Closed hemisphere dome, lower half intersects tower and never implies an interior.
    dome=a.ellipsoid('Observatory dome',(0,14,51),(6.5,6.5,7.0),'BlackRoof',False)
    a.cut(dome,a.box('Dome lower cutter',(0,14,42.99),(20,20,16),'BlackRoof',0))
    for i in range(8):
        t=i*math.tau/8
        x=6.38*math.cos(t);y=14+6.38*math.sin(t)
        a.rod('Tower edge trace',(x,y,32),(x,y,51),.085,'Trace')
        path=[(6.55*math.cos(t)*math.cos(j*math.pi/16),14+6.55*math.sin(t)*math.cos(j*math.pi/16),51+7.1*math.sin(j*math.pi/16)) for j in range(9)]
        for u,v in zip(path,path[1:]):a.rod('Dome rib trace',u,v,.085,'Trace')
    a.gem('Top violet finial',(0,14,59),.48,2,'Trace')
    a.pointed_window('Tower star window',0,7.57,37,2.7,9,'BlackTrim','Nebula')
    for x in (-17,17):
        a.section='WingSpires';a.cylinder_art('Slender wing turret',(x,13,17),.65,30,'Black',8)
        a.cone('Wing pointed roof',(x,13,33),1.2,0,5,'BlackRoof',8);a.gem('Wing finial',(x,13,36),.3,1.2,'Trace')
    a.door(0,-.4,1.6,5.8,9,'BlackTrim','Timber')
    a.section='PortalDoor';a.tube('Circular violet entrance',(0,-.65,6.2),4.85,.17,'Trace',(0,-1,0),32)
    a.steps(8,5,.32,.9,mat='BlackTrim')
    for x in (-13,-9,9,13):
        a.section='GroundWindows';a.pointed_window('Warm lower window',x,1.62,3,1.4,3.8,'BlackTrim','Amber')
    fx=[]
    for i,x in enumerate((-8.2,8.2,-16.8,16.8),1):
        a.section='HouseFX_EdgeTrace_'+str(i)
        a.rod('Front vertical trace',(x,-.3 if abs(x)<9 else 1.65,1.5),(x,-.3 if abs(x)<9 else 1.65,27 if abs(x)<9 else 14),.095,'Trace')
        fx.append({'section':a.section,'kind':'pulse','periodSeconds':12,'phase':(i-1)/4,'fixedGeometry':True})
    for i,(x,y,z) in enumerate([(0,7.05,41),(-7.25,-.96,21),(7.25,-.96,21)],1):
        a.section='HouseFX_StarInset_'+str(i)
        a.star('Large star',x,y,z,.58,'Star')
        for dx,dz in [(-.5,-1.4),(.4,1.6),(.5,-2.1)]:a.star('Small star',x+dx,y,z+dz,.14,'Star')
        fx.append({'section':a.section,'kind':'cycle','periodSeconds':15,'phase':(i-1)/3,'fixedGeometry':True})
    a.section='MainOrbitRing';a.tube('Fixed tilted silhouette ring',(0,12,24),24,.22,'Trace',(.13,.35,1),64)
    for i,(x,y,z,r) in enumerate([(-21,10,43,2.7),(21,15,37,1.6)],1):
        a.section='HouseFX_Planet_'+str(i);a.rock('Planet',(x,y,z),(r,r,r),'Planet',i)
        if i==1:a.tube('Planet ring',(x,y,z),3.65,.12,'Star',(.3,0,1),24)
        fx.append({'section':a.section,'kind':'orbit','periodSeconds':36 if i==1 else 48,'centerBlender':[0,12,z],'radius':abs(x),'phase':.5 if i==1 else 0,'height':z})
    a.section='HouseFX_Comet';a.gem('Comet head',(18,15,50),1,2,'Planet')
    a.rod('Comet trail',(18,15,50),(22,15,54),.24,'Trace')
    fx.append({'section':a.section,'kind':'orbit','periodSeconds':60,'centerBlender':[0,12,50],'radius':18,'phase':0,'tailEnvelope':5.7})
    a.glow('Trace',.8);a.glow('Star',.8)
    for mat in ('Black','BlackRoof','BlackTrim'):
        node=a.mat[mat].node_tree.nodes['Principled BSDF'];node.inputs['Specular IOR Level'].default_value=0;node.inputs['Roughness'].default_value=1
    a.finish(ref('void'),(0,12,28),(72,-90,49),69,fx)

def villa():
    a=art('villa',{'Wall':(225,210,175),'Moss':(74,105,43),'Roof':(73,112,41),'RoofEdge':(60,85,35),'Cap':(171,63,57),'RoseGlow':(211,43,107),'VioletGlow':(116,40,205),'AmberGlow':(243,131,21)})
    a.base(30,25,'Moss',y=10.3,top=.55)
    a.section='CottageShell'
    a.prism('Crooked cream facade',[(-11.8,.55),(11.8,.55),(11.1,10),(1,14.4),(-11.2,10.3)],0,20,'Wall')
    for x in (-11.4,0,11.2):
        a.box('Timber upright',(x,-.18,5.5),(.48,.55,10),'RoofEdge',.09)
    a.box('Front lintel',(0,-.3,9.5),(22.7,.7,.6),'Moss',.1)
    a.roof('Bowed moss roof',0,10,28,24,10,5.7,'Roof','RoofEdge',8,True)
    a.section='Chimney'
    a.box('Crooked stone chimney',(-8,15,14.6),(2.7,3,7),'Stone',.12)
    for z in (13,15.5,18):a.box('Chimney course',(-8,15,z),(3,3.3,.32),'RoofEdge',.06)
    a.section='RoundDoor'
    a.disc('Circular moss frame',0,-.43,4.4,3.6,4,.33,'RoofEdge')
    a.disc('Round closed green door',0,-.68,4.4,3.1,3.52,.20,'Moss')
    for x in (-1.8,-.9,0,.9,1.8):a.box('Door seam',(x,-.81,4.45),(.035,.04,5.45),'RoofEdge',0)
    a.tube('Black door knocker',(.7,-.93,4.0),.34,.08,'Ink',(0,-1,0))
    a.section='Windows'
    for x in (-7.1,7.1):
        a.box('Cream window surround',(x,-.3,5.3),(3.7,.4,4.6),'Cream',.1)
        a.box('Warm pane',(x,-.56,5.3),(2.9,.12,3.8),'Amber',.03)
        a.box('Window mullion',(x,-.66,5.3),(.17,.12,3.9),'RoofEdge',.02)
        a.box('Window crossbar',(x,-.66,5.3),(3,.12,.17),'RoofEdge',.02)
        a.box('Window box',(x,-.95,3),(3.9,1.2,.7),'Moss',.08)
        # Flattened caps have a broad proud brim rather than coplanar spots.
        a.ellipsoid('Toadstool window hood',(x,-.6,7.7),(2.5,1.3,1.0),'Cap',False)
        for dx,dz in [(-1.2,.45),(.0,.82),(1.1,.55)]:a.ellipsoid('Pale raised cap spot',(x+dx,-1.54,7.65+dz),(.36,.12,.22),'Cream',False)
        for j in range(4):a.rock('Box leaf',(x-1.3+j*.85,-1.2,3.55),(.5,.4,.6),'Leaf',j)
    a.section='Ivy'
    for i in range(11):
        z=1.1+i*.82;x=-10.6+.3*math.sin(i)
        a.rod('Ivy stem',(x,-.45,z),(x+.2,-.45,z+.95),.06,'Leaf')
        for dx in (-.55,.55):a.rock('Ivy leaf',(x+dx,-.57,z+.4),(.5,.16,.62),'Leaf',i)
    a.section='LanternString'
    points=[(-8+i*.8,-3.0,11.1+.026*(-8+i*.8)**2) for i in range(21)]
    for u,v in zip(points,points[1:]):a.rod('Bowed lantern cord',u,v,.055,'Ink')
    fx=[]
    for i,x in enumerate((-6.4,-3.2,0,3.2,6.4)):
        z=11.1+.026*x*x
        mat=['AmberGlow','RoseGlow','VioletGlow','AmberGlow','RoseGlow'][i]
        a.section='LanternString';a.rod('Lantern hanger',(x,-3.0,z),(x,-3.0,z-.55),.045,'Ink')
        section='HouseFX_Lantern_'+str(i+1);a.lantern('Fairy lantern',(x,-3.0,z-1),mat,.85,section)
        a.glow(mat,.65);fx.append({'section':section,'kind':'pulse','periodSeconds':8,'phase':i/5,'fixedGeometry':True})
    a.section='GroundGarden'
    for x,y in [(-12,1),(12,1),(-12,16),(12,17)]:
        a.rock('Shrub',(x,y,1.1),(1.6,1.1,1.2),'Moss',x)
    a.section='SideWindow';a.round_window('Cottage side window',(11.85,10,5.7),1.7,'Moss','Amber',(1,0,0))
    a.steps(5.8,3,.19,.85,mat='Stone')
    a.finish(ref('villa'),(0,9,8),(36,-48,29),40,fx)

def modern():
    a=art('modern',{'Pod':(233,220,184),'DomeGlass':(24,139,151),'DomeRim':(36,163,181),'PodTrim':(54,126,141),'Sand':(216,191,140),'CoralOrange':(222,106,41),'CoralPink':(216,95,140),'Seaweed':(29,121,91),'BubbleGlass':(114,213,222)})
    a.section='Foundation'
    a.cylinder_art('Circular stone border',(0,15,.6),19.3,1.2,'Stone',40)
    a.cylinder_art('Sand bed',(0,15,1.24),18.7,.12,'Sand',40)
    a.section='PodShell';a.ellipsoid('Cream enclosed pod',(0,15,8.4),(11,10.3,8),'Pod',False)
    a.tube('Pod top band',(0,15,14.2),7.2,.24,'PodTrim',(0,0,1),32)
    a.section='PodWindows'
    for side in (-1,1):
        a.round_window('Porthole',(side*7.5,7.22,8.8),2.15,'PodTrim','DarkGlass',(side*.57,-.82,0))
        a.round_window('Side porthole',(side*11.05,14,8.8),1.65,'PodTrim','DarkGlass',(side,0,0))
    # Watertight thin dome with two concentric hemispheres and an annular foot.
    a.section='AquariumShell';n=48;rings=16;vs=[];fs=[]
    for radius in (18.3,18.12):
        offset=len(vs)
        for j in range(rings):
            elev=j/rings*math.pi/2
            for i in range(n):
                t=i*math.tau/n
                vs.append((radius*math.cos(elev)*math.cos(t),15+radius*math.cos(elev)*math.sin(t),1.35+radius*math.sin(elev)))
        top=len(vs);vs.append((0,15,1.35+radius))
        local=[]
        for j in range(rings-1):
            for i in range(n):local.append((offset+j*n+i,offset+j*n+(i+1)%n,offset+(j+1)*n+(i+1)%n,offset+(j+1)*n+i))
        for i in range(n):local.append((offset+(rings-1)*n+i,offset+(rings-1)*n+(i+1)%n,top))
        fs.extend(local if offset==0 else [tuple(reversed(f)) for f in local])
    inner=n*rings+1
    for i in range(n):fs.append((i,inner+i,inner+(i+1)%n,(i+1)%n))
    shell=a.tag(a.mesh('Transparent aquarium dome',vs,fs,'DomeGlass'))
    for face in shell.data.polygons:face.use_smooth=True
    a.section='DomeRim';a.tube('Ground glass rim',(0,15,1.4),18.4,.22,'DomeRim',(0,0,1),48)
    # Fixed opaque sleeve / closed end door. No opening or interior mechanics.
    a.section='EntranceSleeve'
    a.arch_shape('Dry entry sleeve',6,4.4,.95,8.7,'PodTrim',(0,.5,0))
    a.arch_shape('Cream closed sleeve face',5.25,4.4,1.15,.15,'Pod',(0,-3.96,0))
    a.door(0,-4.10,1.18,3.8,5.8,'PodTrim','Pod')
    a.round_window('Door porthole',(0,-4.88,5),.65,'PodTrim','DarkGlass')
    a.steps(6,4,.3,.7,y=-4.5)
    a.section='CoralGarden'
    for i,(x,y) in enumerate([(-13,5),(13,5),(-15,14),(15,15),(-9,26),(11,26)]):
        col='CoralPink' if i%2 else 'CoralOrange'
        for dx,dy,height in [(0,0,4.0),(-1,.2,2.6),(1.1,.3,3.2)]:
            a.rod('Coral branch',(x,y,1.4),(x+dx,y+dy,1.4+height),.33,col)
        a.rock('Sea rock',(x+1.5,y+1,2),(1.4,1.3,1.3),'Stone',i)
    for i in range(12):
        t=i*math.tau/12;x=15.6*math.cos(t);y=15+15.6*math.sin(t)
        if y<4 and abs(x)<6:continue
        for j in range(3):a.ellipsoid('Seaweed frond',(x+(j-1)*.55,y,2.6+j*.5),(.36,.35,1.9+j*.5),'Seaweed',False)
    fx=[]
    for i,(x,y,z,r) in enumerate([(-13,6,12,.8),(-12,8,15,.5),(12,9,13,1),(10,11,17,.45)],1):
        a.section='HouseFX_Bubble_'+str(i);a.ellipsoid('Bubble',(x,y,z),(r,r,r),'BubbleGlass',True)
        fx.append({'section':a.section,'kind':'bob','periodSeconds':7,'phase':i/4,'amplitudeStuds':.3})
    for mat,alpha in [('DomeGlass',.18),('BubbleGlass',.38)]:
        node=a.mat[mat].node_tree.nodes['Principled BSDF'];node.inputs['Alpha'].default_value=alpha;node.inputs['Roughness'].default_value=.15
    (a.out/'material-overrides.json').write_text(json.dumps({'DomeGlass':{'RobloxTransparency':.82,'Material':'SmoothPlastic','CanCollide':False},'BubbleGlass':{'RobloxTransparency':.62,'Material':'SmoothPlastic','CanCollide':False},'note':'Apply after import; flat RGB alone does not reproduce the transparent shell.'},indent=2))
    a.finish(ref('modern-readable'),(0,14,8),(41,-49,30),48,fx)

def palace():
    a=art('palace',{'IceWall':(181,209,232),'IceTrim':(215,234,248),'IceRoof':(66,145,211),'IceDeep':(30,82,157),'IceAccent':(25,99,218)})
    a.base(48,34,'IceTrim',y=10.5,top=1.0)
    a.section='PalaceHall';a.box('Wide icy hall',(0,13,14),(36,25,24),'IceWall',.14)
    for z in (3.7,14,25.7):a.box('Palace horizontal course',(0,.28,z),(38,1,.65),'IceTrim',.08)
    a.box('Flat ice roof',(0,13,26.0),(37,26,.55),'IceTrim',.07)
    for x in (-17.6,17.6):a.oct_tower('IceTurret'+str(x),x,4.5,1.0,4.2,27,'IceWall','IceTrim','IceRoof',8)
    a.section='Colonnade'
    for x in (-13.5,-9,-5.9,5.9,9,13.5):
        height=23 if abs(x)<6 else 10
        a.box('Column foot',(x,-.85,2.9),(1.4,1.6,.8),'IceTrim',.07)
        a.box('Tall square ice column',(x,-.85,3.2+height/2),(.72,.9,height),'IceTrim',.05)
        a.box('Column capital',(x,-.85,3.5+height),(1.4,1.6,.7),'IceTrim',.06)
    a.section='Pediment';a.prism('Grand icy pediment',[(-8.2,26),(8.2,26),(0,32.2)],-1.4,.25,'IceTrim')
    a.prism('Pediment blue inset',[(-6.6,26.6),(6.6,26.6),(0,31.4)],-1.52,-1.43,'IceWall')
    a.gem('Pediment crystal',(0,-1.9,28.8),1.45,3.8,'IceDeep')
    a.section='Windows'
    for x in (-11.2,-7.5,7.5,11.2):
        a.pointed_window('Warm ice lower window',x,-.05,4.3,1.7,5,'IceTrim','Amber')
        a.pointed_window('Cold upper window',x,-.05,17,1.7,5.3,'IceTrim','DarkGlass')
    a.door(0,-.45,4.4,5.6,10.5,'IceTrim','IceDeep');a.steps(10,10,.44,.8,y=-.7,mat='IceTrim')
    fx=[]
    for group in range(4):
        a.section='HouseFX_IcicleAccent_'+str(group+1)
        for i in range(group,26,4):
            x=-18.5+i*1.48;length=2.1+(i%3)*.65
            a.cone('Hanging front icicle',(x,-.44,25.2-length/2),0,.36,length,'IceAccent',5)
        fx.append({'section':a.section,'kind':'pulse','periodSeconds':12,'phase':group/4,'fixedGeometry':True})
    # Frozen fountain stays beside, never on, the central approach.
    a.section='FrozenFountain'
    a.cylinder_art('Octagonal fountain basin',(-16,-3.5,1.35),4.1,1.15,'IceTrim',8)
    a.cylinder_art('Frozen water',(-16,-3.5,1.98),3.7,.1,'IceRoof',8)
    for i,(dx,dy,height) in enumerate([(0,0,5),(-1.6,0,3),(1.3,.5,3.8)]):a.gem('Frozen fountain shard',(-16+dx,-3.5+dy,2+height/2),.8,height,'IceRoof')
    a.glow('IceAccent',.45)
    a.finish(ref('palace'),(0,10,17),(62,-75,41),59,fx)

def goldenpig():
    a=art('goldenpig',{'PigGold':(231,179,57),'PigLight':(247,202,84),'PigShade':(183,125,30),'Snout':(225,119,145),'EarPink':(205,100,105)})
    a.base(45,33,'PigShade',y=11,top=.75)
    a.section='PigBody';a.ellipsoid('Faceted golden bank',(0,12,18),(18.2,13.5,16),'PigGold',False)
    for x in (-10.5,10.5):
        for y in (6,20):a.box('Piggy foot',(x,y,4.2),(5.5,6.0,7.8),'PigShade',.8)
    a.section='Ears'
    for side in (-1,1):
        x=side*12
        a.prism('Pointed piggy ear',[(x-side*4.4,28),(x+side*4.0,28),(x+side*3.4,40.5),(x-side*1.8,37)],7.5,11.4,'PigLight')
        a.prism('Ear pink inset',[(x-side*2.4,30),(x+side*2.7,30),(x+side*2.5,38),(x-side*.7,35.6)],7.28,7.45,'EarPink')
    a.section='Snout'
    a.disc('Round pink snout',0,-2.05,21.2,5.9,4.2,2.6,'Snout')
    for x in (-2.2,2.2):
        a.disc('Nostril window well',x,-3.43,21.4,.92,1.5,.18,'Ink')
        a.disc('Nostril warm glass',x,-3.55,21.4,.56,1.12,.12,'Amber')
        a.box('Nostril divider',(x,-3.68,21.4),(.12,.1,2.25),'PigShade',.025)
    a.section='RoundWindows'
    for side in (-1,1):
        a.round_window('Pig cheek window',(side*10.5,1.1,17.2),1.9,'PigShade','Amber',(side*.45,-.89,0))
        a.round_window('Pig flank window',(side*18.25,12,18),1.7,'PigShade','Amber',(side,0,0))
    a.section='BellyEntrance';a.arch_shape('Projecting belly entrance',7.4,7.6,.9,8.8,'PigGold',(0,4.4,0))
    a.door(0,-.4,1.6,5,7.3,'PigShade','Timber');a.steps(6.5,5,.32,.8,y=-.8,mat='PigLight')
    a.section='EarBalconies'
    for x in (-12.8,12.8):
        a.box('Ear balcony floor',(x,4.9,29.8),(6.1,4.5,.55),'PigShade',.16)
        for dx in (-2.6,2.6):a.box('Balcony post',(x+dx,2.8,30.9),(.3,.3,2),'Timber',.04)
        a.box('Balcony top rail',(x,2.8,31.9),(6,.4,.35),'PigShade',.07)
        for dx in (-1.3,0,1.3):a.box('Balcony baluster',(x+dx,2.8,30.8),(.16,.22,1.9),'Timber',.03)
    a.section='CoinSlot'
    a.box('Coin slot frame',(0,12,34),(7.2,3.1,.48),'PigShade',.12)
    a.box('Dark coin slot',(0,12,34.27),(6.0,1.7,.12),'Ink',.04)
    a.section='HouseFX_SlotCoin';a.cylinder_art('Floating gold coin',(0,12,37.5),2.0,.35,'PigLight',24,(0,-1,0))
    a.tube('Coin rim',(0,11.77,37.5),1.72,.10,'PigShade',(0,-1,0),24)
    a.section='TailChimney'
    a.tube('Curled tail chimney',(4,24.8,33.8),1.8,.43,'PigShade',(1,0,0),20)
    a.rod('Tail chimney base',(4,24,30),(4,24,34),.52,'PigGold')
    fx=[{'section':'HouseFX_SlotCoin','kind':'bob','periodSeconds':7,'phase':0,'amplitudeStuds':.35}]
    for i,side in enumerate((-1,1),1):
        a.section='HouseFX_FlankAccent_'+str(i)
        a.ellipsoid('Golden flank shimmer',(side*17.35,13,20),(.19,2.5,3.2),'PigLight',False)
        fx.append({'section':a.section,'kind':'pulse','periodSeconds':12,'phase':i/3,'fixedGeometry':True})
    (a.out/'scope-note.json').write_text(json.dumps({'availability':'Earned completion house, never a coin purchase','referenceNote':'Golden Piggy at far right of saved fantasy lineup; other obsolete lineup entries are not used.'},indent=2))
    a.finish('assets/houses/design/fantasy-v2/fantasy-lineup.png',(0,12,20),(60,-74,40),56,fx)

def candy():
    a=art('candy',{'Biscuit':(164,95,46),'BiscuitEdge':(122,65,31),'Icing':(249,233,205),'CandyRed':(202,54,69),'CandyPink':(218,89,132),'CandyGreen':(76,155,91)})
    a.base(33,29,'BiscuitEdge',y=10.7,top=.7)
    a.section='GingerbreadShell';a.box('Biscuit house',(0,11,8.9),(25,22,16.4),'Biscuit',.18)
    a.roof('Sweet tiled roof',0,11,29,26,17.2,7,'CandyPink','Icing',7)
    a.section='IcingTrim'
    for x in (-12.5,12.5):a.rod('Corner icing',(x,-.1,.9),(x,-.1,17),.25,'Icing')
    for z in (1.2,9.8,16.8):a.box('Icing belt',(0,-.23,z),(25.5,.5,.42),'Icing',.12)
    for i in range(17):a.ellipsoid('Scalloped eave icing',(-13+i*1.62,-2,16.9),(.95,.42,.46),'Icing',False)
    a.door(0,-.55,1.2,4.8,7,'Icing','BiscuitEdge')
    a.section='Windows'
    for x in (-7.8,7.8):
        a.pointed_window('Warm candy window',x,-.2,3,2.7,5,'Icing','Amber')
        a.pointed_window('Unlit upper candy window',x,-.2,11.1,2.5,4.6,'Icing','DarkGlass')
    a.section='Porch'
    a.box('Porch canopy',(0,-2,9),(10,5.2,.5),'BiscuitEdge',.16)
    for x in (-4.2,4.2):
        a.cylinder_art('Candy cane post',(x,-3.8,5),.32,8,'Icing',12)
        for j in range(8):a.cylinder_art('Red candy stripe',(x,-3.8,1.3+j),.335,.38,'CandyRed',12)
    a.section='SweetGarden'
    for i,(x,y) in enumerate([(-13,0),(13,0),(-14,9),(14,9),(-13,21),(13,21)]):
        mat=['CandyPink','CandyGreen','CandyRed'][i%3]
        a.ellipsoid('Gumdrop',(x,y,1.5),(1.3,1.3,1.4),mat,False)
    a.section='Lollipop'
    a.rod('Lollipop weathervane stem',(0,11,24),(0,11,27),.12,'Icing')
    a.cylinder_art('Lollipop disc',(0,11,27),1.5,.3,'CandyRed',20,(0,-1,0))
    a.tube('Lollipop icing spiral',(0,10.79,27),.9,.16,'Icing',(0,-1,0),20)
    a.steps(6,4,.3,.85,y=-1,mat='Icing')
    (a.out/'scope-note.json').write_text(json.dumps({'availability':'SEASONAL ASSET ONLY','runtime':'Does not approve the current permanent 8M candy registry row; no catalogue changes.'},indent=2))
    a.finish('assets/houses/design/fantasy-v2/fantasy-lineup.png',(0,10,13),(47,-60,34),45,[])

BUILDERS={'portal':portal,'thundercloud':thundercloud,'void':void,'villa':villa,'modern':modern,'palace':palace,'goldenpig':goldenpig,'candy':candy}
if __name__=='__main__':
    slug=sys.argv[sys.argv.index('--')+1];BUILDERS[slug]()
