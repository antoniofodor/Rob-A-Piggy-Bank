"""Native-part architecture with a fixed chase floor and distinct theme silhouettes."""
import copy
import json
import math
from pathlib import Path
import native_writer as k

BASE=json.loads((Path(__file__).parent/'approved-wide-geometry.json').read_text())
T=None

def box(name,p,size,mat='trim',collide=False,rot=None,group='Shell',shape='Block'):
    return k.box(name,p,size,mat,collide,rot,group,shape)

def beam(name,a,b,width=.4,mat='trim',depth=None,group='Shell'):
    k.beam(name,a,b,width,mat,depth,group)

def disc(name,p,r,h,mat,normal='up',group='Details',collide=False):
    return k.cylinder(name,p,r,h,mat,group,normal,collide)

def profile():
    s=T['style']
    if s=='town': return [(-30.5,22),(4,32),(30.5,22)]
    if s in ('neon','storm'): return [(-30.5,22),(-25,28),(-18,32),(18,32),(25,28),(30.5,22)]
    if s in ('crystal','void','portal'): return [(-30.5,22),(-22,27),(-7,32),(9,30.5),(23,27),(30.5,22)]
    if s in ('haunted','fairy'): return [(-30.5,22),(-18,27.5),(0,32),(18,27.5),(30.5,22)]
    return [(-30.5,22),(-24,27),(-13,30.5),(0,32),(13,30.5),(24,27),(30.5,22)]

def side_ring(side,y,z,r,mat='trim',segments=12,width=.35):
    x=side*29.25
    for i in range(segments):
        a,b=i*math.tau/segments,(i+1)*math.tau/segments
        beam('WindowRim',(x,y+r*math.cos(a),z+r*math.sin(a)),
             (x,y+r*math.cos(b),z+r*math.sin(b)),width,mat,group='Windows')

def window(side,y):
    s=T['style']; x=side*29.55; z=11.6
    def wbox(name,dy,dz,sz,mat,tilt=0,depth=.23):
        return box(name,(x-side*.2,y+dy,z+dz),(depth,sz[0],sz[1]),mat,
                   rot=k.rotation(x=tilt),group='Windows')
    if s in ('mushroom','aquarium','ship','gold','gloop'):
        radius=4.5 if s=='aquarium' else 3.6
        disc('Daylight',(x,y,z),radius,.18,'glass','side','Windows')
        side_ring(side,y,z,radius+.1,'gold' if s in ('ship','gold') else 'trim',width=.42)
        if s=='aquarium':
            for i in range(3):
                xx=x-side*(.2+i*.035)
                disc('WaterBubble',(xx,y+2.1-i*.55,z+1+i*.8),.32-i*.045,.05,'cream','side','Windows')
            for dy,h in ((-2.3,3.2),(-1.6,2.3)):
                beam('Kelp',(x-side*.4,y+dy,z-3.8),(x-side*.4,y+dy+.25,z-3.8+h),.22,'leaf',group='Windows')
            disc('FishBody',(x-side*.42,y+.4,z-.5),.62,.08,'gold','side','Windows')
            wbox('FishTail',1.1,-.5,(.7,.7),'gold',45,.12)
            disc('FishEye',(x-side*.52,y+.15,z-.3),.09,.03,'metal','side','Windows')
        elif s=='ship':
            wbox('SeaHorizon',0,-.4,(6.8,.23),'cream')
            for i in range(8):
                a=i*math.tau/8
                disc('PortholeRivet',(side*29.0,y+3.72*math.cos(a),z+3.72*math.sin(a)),.13,.13,'gold','side','Windows')
        elif s=='gold':
            for dy in (-.65,.65):
                disc('SnoutNostril',(x-side*.28,y+dy,z-.2),.24,.09,'trim','side','Windows')
            for dy in (-3,3):
                wbox('PigEar',dy,3.6,(1.5,1.5),'gold',45)
        else:
            wbox('WindowCrossV',0,0,(.2,6.9),'trim')
            wbox('WindowCrossH',0,0,(6.9,.2),'trim')
    elif s in ('haunted','ice','sky','fairy'):
        wbox('TallWindow',0,-.6,(6.2,7.4),'glass')
        wbox('WindowCrown',0,3.1,(4.4,4.4),'glass',45)
        pts=[(-3.3,-4.4),(3.3,-4.4),(3.3,2),(0,6),(-3.3,2),(-3.3,-4.4)]
        for a,b in zip(pts,pts[1:]):
            beam('PointedWindow',(side*29.12,y+a[0],z+a[1]),(side*29.12,y+b[0],z+b[1]),.34,group='Windows')
        wbox('Mullion',0,.1,(.18,10),'trim')
        if s=='ice':
            for sign in (-1,1):
                beam('FrostBranch',(side*29,y,z-2),(side*29,y+sign*2.7,z+1.8),.14,'cream',group='Windows')
        if s=='sky':
            for dy,dz,r in ((-1.7,-1,1.1),(0,-.4,1.6),(1.7,-1,1.1)):
                disc('Cloud',(side*29.0,y+dy,z+dz),r,.05,'cream','side','Windows')
        if s=='fairy':
            for i in range(4):
                wbox('VineLeaf',-3.7+i*.18,-3+i*2,(.65,1.1),'leaf',(-1)**i*35)
    elif s in ('crystal','void','portal'):
        radius=4.9
        wbox('FacetWindow',0,0,(6.6,6.6),'glass',45)
        side_ring(side,y,z,radius,'accent',4,.45)
        beam('FacetSplit',(side*29.0,y,z-radius),(side*29.0,y,z+radius),.16,'cream',group='Windows')
        if s=='portal': side_ring(side,y,z,5.8,'trim',8,.3)
        if s=='void':
            for dy,dz in ((-1,1.8),(1.8,.6),(.5,-2.1)):
                wbox('Star',dy,dz,(.32,.32),'cream',45)
    else:
        tilt=4*side if s=='town' else 0
        wbox('WindowBacking',0,0,(7.6,8.7),'glass',tilt)
        for dy in (-4,4): wbox('WindowStile',dy,0,(.45,9.5),'cream' if s=='town' else 'accent',tilt)
        for dz in (-4.6,4.6): wbox('WindowRail',0,dz,(8.4,.42),'cream' if s=='town' else 'accent',tilt)
        if s=='neon':
            for i,h in enumerate((3.3,5.5,4.2)):
                wbox('CitySilhouette',-2.3+i*2.2,-4+h/2,(1.6,h),'trim')
        else:
            wbox('Crossbar',0,0,(7.8,.25),'trim',tilt)
            wbox('Upright',0,0,(.2,8.9),'trim',tilt)

def ribs(y):
    s=T['style']; pts=profile()
    for side in (-1,1):
        box('Pier',(side*29,y,10.6),(1.1,1.1,21.2),'trim')
        box('PierFoot',(side*29,y,.8),(1.5,1.45,1.6),'accent')
        if s in ('sky','gold','ice','haunted'):
            box('PierCapital',(side*29,y,20.5),(2,1.5,.9),'cream')
        if s in ('ship','fairy','town','mushroom'):
            beam('KneeBrace',(side*29,y,16),(side*23,y,22),.65)
        if s in ('crystal','void','storm','portal'):
            beam('FacetBrace',(side*29,y,16),(side*25,y,22),.6,'accent')
    for a,b in zip(pts,pts[1:]):
        beam('VaultRib',(a[0],y,a[1]),(b[0],y,b[1]),.65 if s!='ship' else .95)
    if s=='neon':
        beam('CeilingConduit',(-22,y,28.3),(22,y,28.3),.16,'accent')
    if s=='portal':
        beam('PortalArc',(-23,y-.25,26.6),(-7,y-.25,31.5),.22,'accent')
    if s=='mushroom':
        for x in (-20,-10,0,10,20):
            disc('CapSpot',(x,y,28.4 if abs(x)==20 else 30.2),1.25,.1,'cream',group='Canopy')
    if s=='fairy':
        for side in (-1,1):
            for i in range(3):
                box('LeafBracket',(side*(26-i*1.5),y,23+i*.55),(2.6,1.4,.45),'leaf',
                    rot=k.rotation(y=side*25,z=side*-20),group='Canopy',shape='Wedge')

def fixture(side,y):
    s=T['style']; x=side*28.5; z=17.8
    if s in ('crystal','ice','void'):
        box('CrystalSconce',(x,y,z),(1.0,1.25,2.9),'accent',rot=k.rotation(z=side*15),group='Fixtures',shape='Wedge')
        box('CrystalEdge',(x-side*.3,y,z),(.18,1.0,2.3),'cream',group='Fixtures')
    elif s in ('storm','portal','neon'):
        if s=='storm':
            for a,b in [((-1,1.8),(.65,.35)),((.65,.35),(-.5,.15)),((-.5,.15),(1,-1.8))]:
                beam('Lightning',(x,y+a[0],z+a[1]),(x,y+b[0],z+b[1]),.28,'accent',group='Fixtures')
        else:
            box('LightStrip',(x,y,z),(.22,.42,3.7),'accent',group='Fixtures')
            box('StripMount',(x+side*.12,y,z),(.25,.95,4.15),'trim',group='Fixtures')
    elif s=='gloop':
        disc('GloopBubble',(x,y,z),1,.15,'accent','side','Fixtures')
        disc('BubbleGlint',(x-side*.12,y-.3,z+.35),.25,.05,'cream','side','Fixtures')
    else:
        box('LampBracket',(x+side*.6,y,z+.7),(1.6,.18,.2),'trim',group='Fixtures')
        box('LampGlass',(x,y,z),(.7,.9,1.5),'pink' if s=='fairy' else 'glass',group='Fixtures')
        for dz in (-.86,.86): box('LampCap',(x,y,z+dz),(1.0,1.15,.18),'gold' if s in ('ship','gold') else 'trim',group='Fixtures')
        if s=='haunted':
            for dy in (-.65,.65): box('Candle',(x,y+dy,z+.6),(.16,.16,.8),'cream',group='Fixtures')
        if s=='ship':
            side_ring(side,y,14.4,1.15,'cream',10,.18)
            beam('RopeTail',(side*29.2,y-1,13.8),(side*29.2,y-.7,10),.16,'cream',group='Fixtures')

def shell(length,start=0,room=True):
    s=T['style']; center=start+length/2
    box('Floor',(0,center,-.42),(60,length,.84),'trim',True,group='Collision')
    box('FloorFinish',(0,center,-.025),(59.98,length,.10),'floor',group='FloorFinish')
    for side in (-1,1):
        box('SideWall',(side*30.35,center,11),(.7,length,22),'wall',True,group='Collision')
        box('Skirting',(side*29.75,center,.55),(.38,length,1.1),'trim')
        box('DadoRail',(side*29.7,center,5.2),(.3,length,.24),'accent')
        box('EaveRail',(side*29.7,center,21.8),(.45,length,.5),'trim')
        if s in ('town','haunted','ship','gold','portal'):
            for i,y in enumerate(range(int(start)+2,int(start+length),4)):
                box('WallPanel',(side*29.91,y,2.8),(.16,3.65,4.1),
                    'accent' if s in ('town','portal') and (i+side)%3==0 else 'wall')
                box('PanelStile',(side*29.69,y+1.9,2.8),(.23,.13,4.5),'trim')
        if s in ('sky','storm','ice'):
            for z in (7,14,20): box('MasonryCourse',(side*29.9,center,z),(.12,length,.10),'cream')
        if s=='gloop':
            box('GloopBand',(side*29.6,center,20.9),(.6,length,1.6),'trim')
            for i,y in enumerate(range(int(start)+3,int(start+length),6)):
                height=1.4+(i%3)*.65
                box('SlimeDrip',(side*29.45,y,20-height/2),(.6,1.1,height),'trim')
                disc('DripTip',(side*29.45,y,20-height),.55,.6,'trim','side')
        if s in ('neon','void'):
            for z in (1.8,20): box('EdgeLine',(side*29.55,center,z),(.12,length,.11),'accent')
            if s=='neon': box('MagentaServiceLine',(side*29.55,center,5.4),(.12,length,.085),'pink')
    pts=profile()
    for i,(a,b) in enumerate(zip(pts,pts[1:])):
        beam('RoofFacet',(a[0],center,a[1]),(b[0],center,b[1]),.5,
            'accent' if s=='mushroom' and i%2==0 else 'roof',depth=length,group='Roof')
    if s in ('town','fairy','mushroom','ship'):
        for y in range(int(start)+2,int(start+length),3):
            box('FloorSeam',(0,y,.031),(59.8,.07,.018),'trim',group='FloorFinish')
    elif s in ('crystal','void','portal','neon'):
        for x in (-10,10): box('LaneEdge',(x,center,.04),(.12,length-1,.035),'accent',group='FloorFinish')
    else:
        for y in range(int(start)+4,int(start+length),8):
            box('TileJoint',(0,y,.03),(59.9,.065,.02),'wall',group='FloorFinish')
    if room:
        for y in (1,20,39): ribs(y)
        for side in (-1,1):
            for y in (8,20,32): window(side,y)
            for y in (14,26): fixture(side,y)
        if s in ('ice','crystal'):
            for side in (-1,1):
                for i,y in enumerate((5,11,17,23,29,35)):
                    box('OverheadShard',(side*27.7,y,22.5),(1.05,1.0,2.5+i%2),'accent',
                        rot=k.rotation(z=180),group='Canopy',shape='Wedge')
        if s=='gold':
            for y in (8,20,32):
                disc('CoinCoffer',(0,y,31.2),3.4,.18,'gold',group='Canopy')
                disc('CoinInset',(0,y,31.08),2.7,.1,'cream',group='Canopy')
        if s=='fairy':
            for x,y,col in ((-8,12,'pink'),(8,28,'glass')):
                box('LanternCord',(x,y,28.1),(.1,.1,5.6),'trim',group='Canopy')
                disc('Lantern',(x,y,25),.9,1.6,col,group='Canopy')
                disc('LanternCap',(x,y,25.9),1,.15,'gold',group='Canopy')

def fill_end(y,group,bottom=20.1):
    pts=profile()
    for a,b in zip(pts,pts[1:]):
        width=b[0]-a[0]; low=min(a[1],b[1]); delta=abs(b[1]-a[1])
        box('UpperWall',((a[0]+b[0])/2,y,(bottom+low)/2),(width,1,low-bottom),'wall',True,group=group)
        if delta>.001:
            box('VaultGable',((a[0]+b[0])/2,y,(a[1]+b[1])/2),(1,width,delta),'wall',True,
                rot=k.rotation(y=90 if b[1]>a[1] else -90),group=group,shape='Wedge')

def pedestal():
    s=T['style']; k.template('Pedestal')
    if s in ('town','neon','ship','portal','storm'):
        box('Foot',(0,0,.18),(6.1,6.1,.36),'trim',True,group='Base')
        box('Body',(0,0,.89),(5.55,5.55,1.1),'door',True,group='Base')
        box('Rim',(0,0,1.49),(5.95,5.95,.18),'accent',group='Base')
        box('DisplayTop',(0,0,1.63),(5.6,5.6,.12),'top',True,group='Base')
        if s in ('town','ship'):
            for side in (-1,1):
                box('CrateBand',(side*2.3,0,.92),(.28,5.6,1.05),'trim',group='Base')
        if s=='portal':
            k.current['parts']=[p for p in k.current['parts'] if p['name']!='DisplayTop']
            for side in (-1,1): box('DisplayTop',(side*1.4,0,1.63),(2.8,5.6,.12),'glass' if side<0 else 'top',True,group='Base')
        if s=='neon':
            for side in (-1,1): box('LightEdge',(side*2.79,0,1.15),(.07,5.1,.13),'accent',group='Base')
    elif s in ('crystal','ice','void'):
        for name,z,width,h,mat,col in [('Foot',.18,4.3,.36,'trim',True),('FacetBody',.9,3.95,1.1,'door',True),('Rim',1.49,4.2,.18,'accent',False),('DisplayTop',1.63,3.95,.12,'top',True)]:
            box(name,(0,0,z),(width,width,h),mat,col,rot=k.rotation(y=45),group='Base')
    else:
        for name,z,r,h,mat,col in [('Foot',.18,3.05,.36,'trim',True),('Body',.89,2.77,1.1,'door',True),('Rim',1.49,2.97,.18,'accent',False),('DisplayTop',1.63,2.78,.12,'top',True)]:
            disc(name,(0,0,z),r,h,mat,group='Base',collide=col)
        if s=='fairy':
            for i in range(6):
                a=i*math.tau/6
                box('LeafRim',(2.55*math.cos(a),2.55*math.sin(a),1.25),(1.05,.55,.45),'leaf',rot=k.rotation(y=-i*60),group='Base',shape='Wedge')
        if s=='mushroom':
            for i in range(8):
                a=i*math.tau/8
                disc('CapSpot',(2.7*math.cos(a),2.7*math.sin(a),1.585),.15,.045,'cream',group='Base')
        if s=='gloop':
            for i in range(6):
                a=i*math.tau/6
                disc('SlimeFoot',(2.45*math.cos(a),2.45*math.sin(a),.27),.55,.32,'accent',group='Base')
    box('CollectionPlate',(0,3.3,.19),(2.8,1.05,.34),'trim',True,group='Collect')
    box('CollectionInset',(0,3.3,.37),(2.45,.82,.09),'accent',group='Collect')
    disc('CoinMedallion',(0,2.82,.95),.5,.09,'gold','front','Collect')
    disc('CoinCenter',(0,2.88,.95),.37,.05,'cream','front','Collect')
    box('CoinMark',(0,2.93,.95),(.10,.04,.45),'trim',group='Collect')
    for name,p in [('Piggy',(0,0,1.69)),('CashLabel',(0,2.98,1.25)),('Collect',(0,3.3,.42))]: k.mount(name,p)

def gate():
    s=T['style']; k.template('RebirthGate')
    remap={'plaster':'wall','plasterLight':'cream','wood':'door','woodLight':'accent','woodDark':'trim','gold':'gold','goldLight':'cream'}
    for original in BASE['templates']['RebirthGate']['parts']:
        if original['name'] in ('JambWall','HeaderWall','Gable','DeepTimberHeader','HeaderInlay'): continue
        part=copy.deepcopy(original); part['material']=remap.get(part['material'],'trim')
        if part['name']=='RequirementSign': part['material']='cream'
        k.current['parts'].append(part)
    for side in (-1,1):
        box('JambWall',(side*28.6,.3,10.05),(4.2,1,20.1),'wall',True,group='Frame')
    fill_end(.3,'Frame')
    box('Header',(0,-.6,20),(54,1.2,2),'trim',True,group='Frame')
    box('HeaderInlay',(0,-1.23,20.1),(51.8,.10,.6),'accent',group='Frame')
    for row in range(3):
        z=(2.24+row*4.45)*32/22.55
        for side in (-1,1):
            x=side*8.13*60/38; group=f'Panel_{row+1}_{"L" if side<0 else "R"}'
            if s in ('aquarium','ship','gold','gloop','mushroom'):
                disc('DoorMedallion',(x,-.46,z),1.65,.08,'accent','front',group)
                disc('DoorInset',(x,-.53,z),1.25,.06,'glass' if s in ('ship','aquarium') else 'door','front',group)
            elif s in ('crystal','ice','void','portal','haunted'):
                box('DoorDiamond',(x,-.47,z),(2.6,.14,2.6),'accent',rot=k.rotation(z=45),group=group)
            elif s=='storm':
                beam('DoorBolt',(x-1.4,-.5,z+1.4),(x+.4,-.5,z),.25,'accent',group=group)
                beam('DoorBolt',(x+.4,-.5,z),(x-.5,-.5,z-1.4),.25,'accent',group=group)
            else:
                for dx in (-3,3): box('DoorInlay',(x+dx,-.48,z),(.13,.12,3.8),'cream' if s=='sky' else 'accent',group=group)
    if s in ('crystal','ice','void','portal'):
        box('LockFacet',(0,-.55,9.8),(5.4,.14,5.4),'accent',rot=k.rotation(z=45),group='Lock')
    elif s in ('sky','gold','mushroom'):
        for x in (-2.1,0,2.1): disc('LockCrest',(x,-.52,10.3),1.8,.1,'accent','front','Lock')
    k.mount('Entry',(0,0,0)); k.mount('Exit',(0,0,0))

def lobby():
    k.template('AchievementVestibule',14); shell(14,-14,False); ribs(-12.5)
    window(1,-7); fixture(1,-2.5)
    box('AchievementBacking',(-29.42,-7,11),(.2,10.6,8.6),'cream',group='AchievementAlcove')
    for y in (-12.55,-1.45): box('AlcoveStile',(-29.1,y,11),(.5,.4,9.2),'trim',group='AchievementAlcove')
    for z in (6.5,15.5): box('AlcoveRail',(-29.1,-7,z),(.5,11.5,.38),'trim',group='AchievementAlcove')
    box('EmptyDisplayShelf',(-28.6,-7,6.2),(1.7,11.5,.35),'accent',group='AchievementAlcove')
    for side in (-1,1):
        box('EntryWall',(side*18.5,-14,10.05),(23,.8,20.1),'wall',True,group='Entry')
        box('EntryDoorJamb',(side*7,-13.5,7.5),(.6,.9,15),'trim',True,group='Entry')
    box('EntryUpperWall',(0,-14,17.55),(14,.8,5.1),'wall',True,group='Entry')
    box('EntryLintel',(0,-13.45,15.1),(14.7,1,.65),'trim',group='Entry')
    fill_end(-14,'Entry')
    for name,p,yaw in [('Entry',(0,-14,0),0),('Exit',(0,0,0),0),('Door_Exit',(0,-13.5,0),180),('Arrival',(0,-10,0),0),('Achievements',(-28.9,-7,11),-90)]: k.mount(name,p,yaw)

def build(theme):
    global T
    T=theme; k.TEMPLATES={}; k.PALETTE=theme['palette']
    k.template('RoomShell',40); shell(40)
    k.mount('Entry',(0,0,0)); k.mount('Exit',(0,40,0))
    for side_i,side in enumerate((-1,1)):
        for i,y in enumerate((8,20,32),1): k.mount(f'Slot_{side_i*3+i:02}',(side*18,y,.03),side*90)
    pedestal(); gate(); lobby()
    return copy.deepcopy(k.TEMPLATES)
