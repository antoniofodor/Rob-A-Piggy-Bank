"""Build all three gameplay-sized defaults from frozen v1 art specifications."""
import copy
import json
from pathlib import Path
import native_writer as writer
from resize import resize, HEIGHT

ROOT = Path(__file__).resolve().parents[1]
THEMES = {
    'treehouse': ('treehouse', 'Treehouse'),
    'cardboard-fort': ('cardboard-fort', 'CardboardFort'),
    'beehive-cottage': ('beehive-cottage', 'BeehiveCottage'),
}

def avatar(parent, x, forward, material):
    model, _ = writer.item(parent, 'Model', 'ScaleAvatar_DeleteMe')
    for name, dx, z, size in [('Torso',0,3.1,(2,2,1)),('Head',0,4.95,(1.4,1.7,1.4)),
        ('LeftArm',-1.5,3.1,(1,2,1)),('RightArm',1.5,3.1,(1,2,1)),
        ('LeftLeg',-.5,1.05,(1,2.1,1)),('RightLeg',.5,1.05,(1,2.1,1))]:
        writer.add_part(model, {'name':name,'position':[x+dx,z,-forward],
            'size':list(size),'rotation':writer.IDENTITY[:],
            'material':material if name=='Torso' else 'referenceSkin',
            'shape':'Block','collide':False,'transparency':0,'group':'Reference'})

for theme, (stem, title) in THEMES.items():
    out = ROOT/theme
    out.mkdir(exist_ok=True)
    writer.OUT = out
    spec = json.loads((ROOT/'generate/inputs'/f'{theme}.json').read_text())
    resize(spec['templates'])
    spec.update(roomLength=40,clearWidth=60,centerLane=28,doorClearWidth=32.6*60/38,
        doorClearHeight=13.4*HEIGHT,ceilingHeight=32,slotsPerRoom=6,
        achievementClearSize=[10,6*HEIGHT],
        status='Default themed kit; mapped into default.project.json')
    writer.PALETTE = spec['palette']
    writer.TEMPLATES = spec['templates']
    # Review-only reference colors. No avatars are included in the kit templates.
    writer.PALETTE.update(referenceSkin=[216,205,177],referenceThief=[50,65,85],referenceOwner=[165,60,61])
    (out/'geometry.json').write_text(json.dumps(spec,indent=2))
    root = writer.root_xml()
    kit, _ = writer.item(root,'Model',title+'InteriorKit')
    templates, _ = writer.item(kit,'Folder','Templates')
    for name in writer.TEMPLATES:
        writer.add_model(templates,name)
    builder = (ROOT/'generate/inputs'/f'{theme}-Builder.luau').read_text()
    builder = builder.replace('16.1-(2.24+row*4.45)', '(16.1-(2.24+row*4.45))*32/22.55')
    (out/'Builder.luau').write_text(builder)
    _, props = writer.item(kit,'ModuleScript','Builder')
    writer.prop(props,'ProtectedString','Source',builder)
    writer.save_xml(root,stem+'-interior-kit.rbxmx')
    root = writer.root_xml()
    demo, _ = writer.item(root,'Model',title+'Interior_Review')
    writer.add_model(demo,'AchievementVestibule','Entrance')
    for room in range(2):
        writer.add_model(demo,'RoomShell',f'Room_{room+1:02}',[0,0,-40*room])
        writer.add_model(demo,'RebirthGate',f'Gate_{room+1:02}',[0,0,-40*(room+1)],opened=room==0)
        for slot in range(6):
            at = writer.TEMPLATES['RoomShell']['mounts'][f'Slot_{slot+1:02}']
            pos = at['position'][:]
            pos[2] -= 40*room
            writer.add_model(demo,'Pedestal',f'Pedestal_{room*6+slot+1:02}',pos,-90 if slot<3 else 90)
    avatar(demo,0,4,'referenceThief')
    avatar(demo,24,20,'referenceOwner')
    writer.save_xml(root,stem+'-interior-review.rbxmx')
    budget={name:{'parts':len(t['parts'])+1,'collidingParts':sum(p['collide'] for p in t['parts'])} for name,t in spec['templates'].items()}
    (out/'part-budget.json').write_text(json.dumps(budget,indent=2))
    project={'name':title+' Wide Interior','tree':{'$className':'DataModel',
        'Workspace':{'$className':'Workspace','Review':{'$path':stem+'-interior-review.rbxmx'},
            'ReviewSpawn':{'$className':'SpawnLocation','$properties':{'Anchored':True,'CanCollide':False,'Transparency':1,'Neutral':True,'Duration':0,'Position':[0,.6,-4],'Size':[4,1,4]}}},
        'ServerStorage':{'$className':'ServerStorage',title+'InteriorKit':{'$path':stem+'-interior-kit.rbxmx'}},
        'StarterPlayer':{'$className':'StarterPlayer','$properties':{'CameraMaxZoomDistance':11},
            'StarterPlayerScripts':{'$className':'StarterPlayerScripts','Camera':{'$path':'../generate/preview-camera.client.luau'}}},
        'Lighting':{'$className':'Lighting','$properties':{'ClockTime':14.5,'Brightness':2,'Ambient':[.55,.52,.45],'OutdoorAmbient':[.65,.68,.65],'GlobalShadows':False}}}}
    (out/'preview.project.json').write_text(json.dumps(project,indent=2))
    print(theme, budget)
