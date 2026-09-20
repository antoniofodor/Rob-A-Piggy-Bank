"""Build the six remaining permanent houses as exterior-only Blender assets.

The four re-themes follow HOUSE-TIER-BRIEF section 4; tower/castle follow
the existing rebuilt Luau silhouettes. No reference bitmap is invented.
"""
import bpy,math,sys,json
from pathlib import Path
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from fantasy_parts import FantasyArt,BASE

def art(slug,palette):return FantasyArt(slug,1,{**BASE,**palette})
BRIEF='assets/houses/docs/HOUSE-TIER-BRIEF.md'
RUNTIME='src/ReplicatedStorage/Shared/House.luau'

def line(a,name,points,r,mat):
    for p,q in zip(points,points[1:]):a.rod(name,p,q,r,mat)

def rect_window(a,name,x,y,z,w,h,frame,glass):
    a.box(name+' recess',(x,y,z),(w+.45,.22,h+.45),'Ink',.03)
    a.box(name+' pane',(x,y-.16,z),(w,.15,h),glass,.025)
    for dx in (-w/2,w/2):a.box(name+' jamb',(x+dx,y-.3,z),(.2,.26,h+.3),frame,.04)
    for dz in (-h/2,h/2):a.box(name+' rail',(x,y-.3,z+dz),(w+.3,.26,.2),frame,.04)
    a.box(name+' mullion',(x,y-.3,z),(.12,.2,h),frame,.02)
    a.box(name+' crossbar',(x,y-.3,z),(w,.2,.12),frame,.02)

def hex_window(a,name,x,y,z,r):
    points=[(x+r*math.cos(math.pi/6+i*math.tau/6),z+r*math.sin(math.pi/6+i*math.tau/6)) for i in range(6)]
    a.prism(name+' timber frame',points,y-.12,y+.2,'WaxDark')
    inner=[(x+(xx-x)*.76,z+(zz-z)*.76) for xx,zz in points]
    a.prism(name+' honey pane',inner,y-.28,y-.14,'Amber')
    for i in (1,3,5):a.rod(name+' radial mullion',(x,y-.34,z),(inner[i][0],y-.34,inner[i][1]),.07,'WaxDark')

def shack():
    a=art('shack',{'Card':(161,113,67),'CardLight':(187,143,91),'CardDark':(116,78,42),'Tape':(217,188,135),'Crayon':(52,101,153),'RedPencil':(166,61,49)})
    a.base(22,20,'CardDark',y=7.8,top=.45)
    a.section='MainBox';a.box('Large packing box',(0,7.6,5.2),(15.8,14.8,9.5),'Card',.08)
    # Raised patches, wide tape seams and corrugation make the material legible.
    a.box('Front overlap flap',(3.95,-.01,5.1),(7.85,.16,9.35),'CardLight',.025)
    for x in (-7.95,0,7.95):a.box('Vertical packing tape',(x,-.17,5.3),(.62,.08,9.55),'Tape',.01)
    for y in (3.0,11.0):a.box('Side packing tape',(8.02,y,5.25),(.08,.62,9.55),'Tape',.01)
    a.box('Sealed lid',(0,7.6,10.0),(16.2,15.1,.3),'CardLight',.03)
    a.box('Top seam tape',(0,7.6,10.2),(1.0,15.15,.07),'Tape',.008)
    a.section='BoxFlaps'
    for side in (-1,1):
        flap=a.box('Open lid flap',(side*6.0,7.6,11.55),(5.0,15.1,.22),'CardLight',.025)
        flap.rotation_euler.y=-side*.59
        for j in range(9):
            # Corrugated edge marks stand proud of the front end of each flap.
            xx=side*(4.2+j*.44);zz=11.55+(abs(xx)-6)*math.sin(.59)
            a.box('Corrugated flap edge',(xx,-.01,zz),(.07,.13,.13),'CardDark',.005)
    a.section='CrayonEntrance'
    a.box('Closed cardboard door',(0,-.25,3.9),(4.7,.16,6.8),'CardDark',.035)
    a.box('Door face',(0,-.36,3.9),(4.28,.1,6.45),'Card',.02)
    line(a,'Wobbly blue crayon outline',[(-2.25,-.44,.65),(-2.36,-.44,6.9),(-2.1,-.44,7.3),(2.14,-.44,7.17),(2.3,-.44,.65)],.10,'Crayon')
    a.disc('Crayon handle',1.46,-.5,3.45,.22,.2,.09,'Crayon')
    a.section='BoxWindows'
    for x in (-5.3,5.3):
        rect_window(a,'Cut paper window',x,-.28,6.6,2.25,2.3,'Tape','DarkGlass')
        a.box('Folded little awning',(x,-.8,8.0),(2.9,1.5,.16),'CardLight',.025).rotation_euler.x=.15
    a.section='Patches'
    a.box('Side repair patch',(8.12,8,4.8),(.17,5.6,4.0),'CardLight',.025)
    for y in (5.8,10.2):a.box('Patch tape',(8.25,y,4.8),(.08,.6,4.5),'Tape',.01)
    a.box('Small stacked box',(-6.5,13.7,11.8),(4.0,3.8,3.1),'CardDark',.04)
    a.box('Small box tape',(-6.5,11.73,11.8),(.5,.1,3.2),'Tape',.008)
    a.section='Doodles'
    # A hand-drawn sun and two tufts of grass are original geometric marks.
    a.tube('Crayon sun',(8.26,8,5),.85,.08,'RedPencil',(1,0,0),12)
    for i in range(8):
        t=i*math.tau/8
        a.rod('Sun ray',(8.27,8+1.08*math.cos(t),5+1.08*math.sin(t)),(8.27,8+1.48*math.cos(t),5+1.48*math.sin(t)),.055,'RedPencil')
    a.section='Approach'
    a.box('Cardboard welcome mat',(0,-1.45,.5),(5.4,2.4,.12),'CardLight',.035)
    a.finish(BRIEF,(0,7,6.3),(31,-40,24),29,[])

def cottage():
    a=art('cottage',{'Wax':(190,133,40),'WaxLight':(222,171,71),'WaxDark':(125,77,29),'Honey':(236,151,24),'DoorBlue':(46,115,116),'Grass':(91,121,61)})
    a.base(28,28,'Grass',y=11.5,top=.65)
    # Stacked closed tapered rings create a skep profile, with recessed seams.
    a.section='BeehiveShell'
    profile=[(1.0,9.4),(3.0,10.6),(5.1,11.2),(7.2,11.3),(9.3,10.9),(11.4,10.0),(13.5,8.8),(15.6,7.1),(17.7,4.8),(19.2,2.3)]
    for i,((z,r),(nz,nr)) in enumerate(zip(profile,profile[1:])):
        a.cone('Stacked wax course',(0,12,(z+nz)/2),r,nr,nz-z+.18,'WaxLight' if i%2 else 'Wax',32)
        a.tube('Wax course bead',(0,12,z+.14),r,.19,'WaxDark',(0,0,1),32)
    a.cone('Rounded hive crown',(0,12,19.45),2.4,.8,1.3,'WaxLight',24)
    a.section='HoneyDrips'
    for i in range(12):
        t=i*math.tau/12;length=1.3+(i%3)*.38;rad=8.6+.69*length
        top=(8.45*math.cos(t),12+8.45*math.sin(t),14.0)
        tip=(rad*math.cos(t),12+rad*math.sin(t),14.0-length)
        a.rod('Honey running down wax',top,tip,.34,'Honey')
        a.ellipsoid('Rounded honey drop',tip,(.37,.37,.47),'Honey',False)
    a.tube('Honey collar',(0,12,14.0),8.28,.42,'Honey',(0,0,1),32)
    a.section='EntrancePod'
    a.arch_shape('Projecting wax entry',7.1,5.6,.65,6.2,'WaxLight',(0,1.65,0))
    a.door(0,-1.58,.95,4.7,7.2,'WaxDark','DoorBlue')
    a.steps(6.4,4,.23,.8,y=-1.8,mat='WaxLight')
    a.section='HoneycombWindows'
    for side in (-1,1):
        # Rotate each frame onto the hive tangent rather than projecting a
        # flat facade window beyond the edge of the curved silhouette.
        first=len(a.visual);hex_window(a,'Hexagonal front window',0,0,0,1.9)
        a.transformed_group(a.visual[first:],Matrix.Translation((side*6.85,2.9,8.2))@Matrix.Rotation(side*.64,4,'Z'))
    # Side window and its frame transform together onto the tangent plane.
    before=len(a.visual);hex_window(a,'Hexagonal flank window',0,0,0,1.8)
    matrix=Matrix.Translation((11.42,12,8.0))@Matrix.Rotation(math.pi/2,4,'Z')
    a.transformed_group(a.visual[before:],matrix)
    a.section='WaxChimney'
    a.cone('Wax chimney',(4.0,14.5,19.1),1.45,1.3,5.5,'WaxDark',6)
    a.cone('Chimney rim',(4,14.5,22),1.7,1.6,.6,'WaxLight',6)
    a.cylinder_art('Dark chimney inset',(4,14.5,22.32),1.13,.08,'Ink',6)
    a.section='Garden'
    for x,y in [(-10,0),(10,0),(-11,22),(11,22)]:
        for dx,dy in [(-.5,0),(.5,0),(0,.7)]:a.ellipsoid('Leaf tuft',(x+dx,y+dy,1.3),(.5,.35,.85),'Leaf',False)
        a.cylinder_art('Hexagonal stepping stone',(x,y+1,.8),1.1,.35,'WaxDark',6)
    a.finish(BRIEF,(0,11,10),(36,-46,29),36,[])

def townhouse():
    a=art('townhouse',{'Brick':(159,73,55),'BrickLight':(186,100,67),'Plaster':(217,176,121),'Jade':(57,113,110),'Slate':(58,79,103),'Trim':(234,211,165)})
    a.base(29,27,'Stone',y=10.5,top=.7)
    # Transform the complete floor groups, including windows and trim, so all
    # attachments follow the crooked structure rather than floating off it.
    floor_specs=[]
    for level,(cx,angle,wall,w,d) in enumerate([(0,-3,'Brick',18,19),(-.8,5,'Plaster',19,20),(1.0,-5,'Jade',17.5,18.5)]):
        zbase=.7+level*8.3;start=len(a.visual);a.section='Storey'+str(level+1)
        a.box('Crooked storey shell',(0,10,4.55),(w,d,8.9),wall,.11)
        for z in (.35,8.65):a.box('Heavy storey belt',(0,10,z),(w+.7,d+.7,.48),'Trim',.05)
        for x in (-w/2,w/2):a.box('Front corner upright',(x,10-d/2-.12,4.5),(.45,.5,8.5),'Trim',.06)
        for x in (-5.4,5.4):rect_window(a,'Tall crooked window',x,10-d/2-.17,4.9,2.7,4.35,'Trim','Amber' if level==0 else 'DarkGlass')
        # One side window built in a local front plane, then rotated outward.
        first=len(a.visual);rect_window(a,'Side sash',0,0,4.7,3.1,4,'Trim','DarkGlass')
        a.transformed_group(a.visual[first:],Matrix.Translation((w/2+.17,10,0))@Matrix.Rotation(math.pi/2,4,'Z'))
        if level==0:
            for row in range(4):
                for col in range(5):
                    x=-7+col*3.25+(row%2)*.7
                    a.box('Proud brick',(x,10-d/2-.11,1.8+row*1.65),(1.0,.17,.42),'BrickLight',.03)
        if level==2:
            a.roof('Tilted steep roof',0,10,21,22,8.85,7.4,'Slate','Trim',5)
            a.section='UpperChimney';a.box('Leaning chimney',(5.7,14,14),(2.2,2.5,7.2),'Brick',.07)
            a.box('Chimney cap',(5.7,14,17.7),(2.7,3.0,.45),'Trim',.06)
        a.section='AttachedDownpipes'
        a.rod('Storey downpipe',(-w/2-.45,10-d/2-.3,1),(-w/2-.45,10-d/2-.3,8.0),.14,'Slate')
        for zz in (2,7):a.rod('Pipe mounting bracket',(-w/2,10-d/2,zz),(-w/2-.45,10-d/2-.3,zz),.075,'Slate')
        matrix=Matrix.Translation((cx,0,zbase))@Matrix.Rotation(math.radians(angle),4,'Y')
        a.transformed_group(a.visual[start:],matrix)
        floor_specs.append((matrix,w,d))
    # Closed tapered collars fill the triangular void between tilted storeys.
    # Their bottom/top rings are embedded in the adjacent shells, so the
    # architectural lean never leaves a floor apparently floating in air.
    def ring(matrix,w,d,z):
        return [tuple(matrix@Vector((x,y,z))) for x,y in [(-w/2,10-d/2),(w/2,10-d/2),(w/2,10+d/2),(-w/2,10+d/2)]]
    def collar(name,lower,upper):
        a.tag(a.mesh(name,lower+upper,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'Slate'))
    a.section='ConnectingCollars'
    m,w,d=floor_specs[0]
    collar('Ground support collar',ring(Matrix.Identity(4),w,d,.6),ring(m,w,d,.5))
    for i in range(2):
        m,w,d=floor_specs[i];nm,nw,nd=floor_specs[i+1]
        collar('Interstorey support collar',ring(m,w,d,7.4),ring(nm,nw,nd,1.6))
        a.rod('Downpipe connector',m@Vector((-w/2-.45,10-d/2-.3,8.0)),nm@Vector((-nw/2-.45,10-nd/2-.3,1)),.14,'Slate')
    a.door(0,-.44,.9,4.5,7,'Trim','Slate');a.steps(6,3,.3,.86,mat='Stone')
    a.section='EntryCanopy';a.box('Sloping entry canopy',(0,-1.0,8),(7,3.2,.38),'Jade',.08).rotation_euler.y=.04
    a.section='FacadeDetails'
    a.lantern('Entry lantern',(3.55,-.9,6.4),'Amber',.8)
    a.finish(BRIEF,(0,10,17),(42,-54,31),46,[])

def manor():
    a=art('manor',{'Wall':(110,112,132),'WallLight':(139,140,152),'Trim':(192,179,155),'Roof':(76,49,91),'RoofEdge':(111,72,121),'Door':(100,64,83),'Moss':(65,91,71)})
    a.base(43,33,'Stone',y=12,top=.85)
    a.section='ManorShell'
    a.box('Central manor',(0,12,11.0),(23,23,20.4),'Wall',.13)
    for x in (-14.8,14.8):a.box('Side wing',(x,13,7.0),(9,19,12.4),'WallLight',.12)
    a.roof('Central steep roof',0,12,26,26,21.3,8.3,'Roof','RoofEdge',6)
    for x in (-14.8,14.8):a.roof('Wing roof'+str(x),x,13,11,22,13.2,5.0,'Roof','Trim',4)
    a.section='GabledBays'
    for x in (-7,7):
        a.prism('Tall front gable',[(x-3.8,1),(x+3.8,1),(x+3.8,22),(x,28),(x-3.8,22)],-1.3,4,'Wall')
        a.roof('Front bay roof'+str(x),x,1.4,8.8,6.5,22,6.8,'Roof','Trim',4)
        a.section='BayWindows'
        for z,glass in [(4.0,'Amber'),(14.1,'DarkGlass')]:a.pointed_window('Gothic sash',x,-1.46,z,2.35,5.2,'Trim',glass)
        a.round_window('Attic round window',(x,-2.05,24.0),.75,'Trim','DarkGlass')
    a.section='WallDetails'
    for z in (2.0,11.8):a.box('Front masonry belt',(0,.32,z),(24,.5,.5),'Trim',.055)
    for x in (-18,18):
        a.pointed_window('Wing window',x,3.32,4.2,2.0,5.8,'Trim','Amber')
        for z in (3,6,9,12):a.box('Corner quoin',(x,3.3,z),(1.1,.3,.7),'Wall',.045)
    # Small off-centre lookout and bent chimneys retain a house silhouette.
    a.section='Lookout';a.oct_tower('AtticLookout',-7.5,17.5,21.5,3.0,10.0,'WallLight','Trim','Roof',5.5)
    a.section='CrookedChimneys'
    for side in (-1,1):
        x=side*14.5
        line(a,'Bent chimney core',[(x,15,17),(x,15,22),(x+side*1.6,15,24),(x+side*1.6,15,27)],.9,'Wall')
        a.box('Chimney pot',(x+side*1.6,15,27.15),(2.6,2.7,.6),'Trim',.07)
        a.box('Chimney dark opening',(x+side*1.6,15,27.5),(1.55,1.65,.1),'Ink',.015)
    a.door(0,-.4,1.6,5.3,8.2,'Trim','Door');a.steps(7.4,5,.32,.85,y=-.65)
    a.section='Porch';a.box('Porch canopy',(0,-1.5,10.5),(9.7,5.2,.5),'Roof',.1)
    for x in (-4,4):
        a.box('Porch post',(x,-3.5,5.7),(.48,.48,8.8),'Trim',.06)
        a.rod('Porch diagonal brace',(x,-3.5,8.0),(x*.65,-3.5,10.2),.16,'Trim')
    # Haunting is conveyed through architectural details and light, no actor.
    fx=[]
    for i,x in enumerate((-4.8,4.8),1):
        section='HouseFX_PorchLantern_'+str(i)
        a.lantern('Haunted porch lantern',(x,-2,8.0),'Amber',1,section)
        fx.append({'section':section,'kind':'pulse','periodSeconds':11,'phase':i/3,'fixedGeometry':True})
    a.section='GroundDetails'
    for x,y in [(-19,4),(19,5),(-17,25),(17,25)]:a.rock('Mossy hedge',(x,y,1.5),(1.3,1,1.6),'Moss',x)
    a.finish(BRIEF,(0,11,17),(57,-73,38),54,fx)

def neontower():
    a=art('neontower',{'Core':(44,57,81),'Frame':(32,42,64),'Metal':(134,151,174),'Glass':(36,79,100),'Cyan':(27,168,189),'Magenta':(152,42,160),'BlueNeon':(48,83,186)})
    a.base(33,33,'Frame',y=12,top=1.1)
    a.section='TowerStructure';a.box('Six storey core',(0,11,21.5),(24,22,40.8),'Core',.14)
    for x in (-12.0,12.0):
        for y in (0,22):
            a.box('Full height column',(x,y,21.5),(1.5,1.5,41.2),'Frame',.09)
            a.box('Column footing',(x,y,1.65),(2.3,2.3,1.0),'Metal',.07)
    fx=[]
    for floor in range(6):
        z=1.1+floor*6.8;a.section='Floor'+str(floor+1)
        a.box('Floor spandrel',(0,11,z+.5),(24.5,22.5,1.0),'Frame',.065)
        for y in (-.1,22.1):
            a.box('Curtain wall glazing',(0,y,z+3.65),(21.5,.18,4.4),'Glass',.025)
            for x in (-8,-4,0,4,8):a.box('Window mullion',(x,y+(-.14 if y<0 else .14),z+3.65),(.17,.15,4.5),'Metal',.02)
        for x in (-12.1,12.1):
            a.box('Side curtain wall',(x,11,z+3.65),(.18,19.5,4.4),'Glass',.025)
            for y in (4,8,12,16,20):a.box('Side mullion',(x+(-.14 if x<0 else .14),y,z+3.65),(.15,.17,4.5),'Metal',.02)
        section='HouseFX_FloorBand_'+str(floor+1);a.section=section
        col=('Cyan','BlueNeon','Magenta')[floor%3]
        a.box('Front light band',(0,-.43,z+6.15),(23,.22,.24),col,.025)
        for x in (-12.43,12.43):a.box('Side light band',(x,11,z+6.15),(.22,22.7,.24),col,.025)
        fx.append({'section':section,'kind':'cycle','periodSeconds':12,'phase':floor/6,'fixedGeometry':True})
        a.section='HouseFX_Riser_'+str(floor+1)
        for x in (-11.8,11.8):a.box('Front corner chase',(x,-.88,z+3.6),(.22,.22,5.8),'Cyan',.025)
        fx.append({'section':a.section,'kind':'chase','periodSeconds':10,'phase':floor/6,'fixedGeometry':True})
    a.section='Crown'
    for z,w,d,h in [(42.3,27,25,.9),(44.0,19,17,2.8),(45.8,22,20,.6)]:a.box('Stepped crown',(0,11,z),(w,d,h),'Frame',.09)
    a.rod('Aerial mast',(0,11,46),(0,11,53.3),.24,'Metal')
    a.section='HouseFX_Beacon';a.gem('Crown beacon',(0,11,53),1.0,2.0,'Cyan')
    fx.append({'section':a.section,'kind':'pulse','periodSeconds':9,'phase':0,'fixedGeometry':True})
    for i in range(6):
        a.section='HouseFX_CrownHalo_'+str(i+1);t=i*math.tau/6
        a.ellipsoid('Halo light',(3.8*math.cos(t),11+3.8*math.sin(t),49.5),(.55,.55,.55),'Cyan',False)
        fx.append({'section':a.section,'kind':'orbit','periodSeconds':24,'phase':i/6,'centerBlender':[0,11,49.5],'axisBlender':[0,0,1]})
    a.section='EntryLobby'
    a.box('Projecting lobby',(0,-.6,5.1),(12,2.5,8),'Core',.09)
    rect_window(a,'Lobby closed double door',0,-1.93,5.0,6.5,6.8,'Metal','Glass')
    for x in (-.5,.5):a.rod('Door pull',(x,-2.35,3.8),(x,-2.35,5.0),.07,'Metal')
    a.box('Entrance canopy',(0,-2.9,9.6),(15,6.7,.6),'Frame',.08)
    for x in (-6,6):a.rod('Canopy column',(x,-5.5,1.1),(x,-5.5,9.4),.21,'Metal')
    a.section='HouseFX_Entrance';a.box('Canopy light',(0,-6.29,9.5),(13,.16,.24),'Cyan',.02)
    fx.append({'section':a.section,'kind':'pulse','periodSeconds':12,'phase':.4,'fixedGeometry':True})
    a.steps(9,4,.28,.75,y=-2.3,mat='Metal')
    for mat in ('Cyan','Magenta','BlueNeon'):a.glow(mat,.55)
    a.finish(RUNTIME,(0,10,26),(58,-73,42),62,fx)

def skycastle():
    a=art('skycastle',{'CastleStone':(151,150,166),'DarkStone':(112,110,135),'LightStone':(184,179,192),'PurpleRoof':(90,52,124),'Banner':(171,54,88),'Rune':(135,39,199)})
    a.base(49,43,'DarkStone',y=15,top=1.2)
    a.section='Keep'
    a.box('Battered plinth',(0,15,2.1),(42,33,2),'LightStone',.3)
    a.box('Square sky keep',(0,15,18.1),(35,28,31.3),'CastleStone',.12)
    for z in (3.7,18,33.5):a.box('Keep masonry course',(0,15,z),(35.6,28.6,.65),'DarkStone',.05)
    a.box('Corbel table',(0,15,34.5),(37,30,1.0),'DarkStone',.07)
    a.box('Parapet walk',(0,15,35.6),(36.5,29.5,1.35),'CastleStone',.07)
    a.section='Battlements'
    for x in (-14,-9.3,-4.65,0,4.65,9.3,14):
        for y in (.4,29.6):a.box('Crenellation',(x,y,37),(2.7,1.9,2.1),'LightStone',.08)
    for x in (-17.8,17.8):
        for y in (5,10,15,20,25):a.box('Side crenellation',(x,y,37),(1.9,2.7,2.1),'LightStone',.08)
    fx=[]
    # Four round towers with stepped purple caps preserve the existing castle.
    for i,(x,y) in enumerate([(-17.5,1),(17.5,1),(-17.5,29),(17.5,29)],1):
        a.section='Turret'+str(i)
        a.cylinder_art('Corner turret',(x,y,21),4.2,39.6,'CastleStone',16)
        for z in (2.2,20.2,39.0):a.cylinder_art('Turret corbel',(x,y,z),4.7,.85,'DarkStone',16)
        for j in range(4):a.cone('Stepped turret cap',(x,y,40.5+j*1.25),4.9-j*1.05,4.35-j*1.05,1.4,'PurpleRoof',16)
        if i<=2:
            for z,glass in [(5,'Amber'),(25,'DarkGlass')]:a.pointed_window('Turret slit',x,y-4.34,z,1.1,5,'LightStone',glass)
        a.section='HouseFX_Finial_'+str(i);a.gem('Violet finial',(x,y,45.8),.65,1.7,'Rune')
        fx.append({'section':a.section,'kind':'pulse','periodSeconds':12,'phase':i/4,'fixedGeometry':True})
    a.section='Masonry'
    for row in range(5):
        for side in (-1,1):
            x=side*(10.0+(row%2)*2.0);z=6+row*5.3
            a.box('Raised old stone',(x,.83,z),(3.7,.3,1.35),'LightStone' if row%2 else 'DarkStone',.08)
    a.section='KeepWindows'
    for x in (-10.5,10.5):
        for z in (10,21,28):a.pointed_window('Keep arrow slit',x,.7,z,.8,3.8,'DarkStone','Amber' if z==10 else 'DarkGlass')
    a.section='Gatehouse';a.box('Projecting gatehouse',(0,0,12.7),(14.5,9,20.5),'CastleStone',.13)
    a.box('Gate corbel',(0,0,23.3),(15.7,10.2,1),'DarkStone',.1)
    for x in (-5.3,0,5.3):a.box('Gatehouse merlon',(x,0,24.8),(2.8,9.6,2.0),'LightStone',.1)
    a.arch_shape('Closed gate recess',9.2,12.0,2.5,.25,'DarkStone',(0,-4.66,0))
    a.arch_shape('Closed timber gate',7.4,11.8,2.7,.15,'Timber',(0,-4.85,0))
    for x in (-3,-1.5,0,1.5,3):a.box('Portcullis upright',(x,-5.03,7.8),(.19,.22,10),'DarkStone',.025)
    for z in (4,7,10,12):a.box('Portcullis crossbar',(0,-5.08,z),(7.2,.21,.18),'DarkStone',.025)
    a.section='Banner';a.prism('Hanging rose banner',[(-1.8,22),(1.8,22),(1.8,17),(0,15.5),(-1.8,17)],-4.85,-4.67,'Banner')
    a.rod('Banner pole',(-2.6,-5.0,22.3),(2.6,-5.0,22.3),.13,'Gold')
    a.gem('Banner crest',(0,-5.12,19.2),.75,2.1,'Gold')
    a.steps(12,7,.4,.8,y=-5.2,mat='LightStone')
    for i in range(5):
        a.section='HouseFX_Rune_'+str(i+1);x=-10+i*5
        a.gem('Keep rune',(x,.42,31.6),.5,1.65,'Rune')
        fx.append({'section':a.section,'kind':'chase','periodSeconds':13,'phase':i/5,'fixedGeometry':True})
    for i,(x,y,z) in enumerate([(-24,8,33),(24,11,31),(-21,32,43),(21,32,41)],1):
        a.section='HouseFX_FloatingShard_'+str(i)
        a.gem('Floating stone shard',(x,y,z),1.5,4.0,'DarkStone')
        a.gem('Violet shard underside',(x,y,z-1.3),1.0,1.5,'Rune')
        fx.append({'section':a.section,'kind':'bob','periodSeconds':11,'phase':i/4,'amplitudeStuds':.4,'note':'Use constrained bob for MVP; full orbital sweep is not validated.'})
    a.glow('Rune',.6)
    a.finish(RUNTIME,(0,13,23),(67,-84,49),66,fx)

BUILDERS={'shack':shack,'cottage':cottage,'townhouse':townhouse,'manor':manor,'neontower':neontower,'skycastle':skycastle}
if __name__=='__main__':BUILDERS[sys.argv[sys.argv.index('--')+1]]()
