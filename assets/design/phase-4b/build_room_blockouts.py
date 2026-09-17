"""Static visual blockouts + mount contract, no gameplay or award scripts.
Exports Roblox XML models for Fable to review/import outside the live map.
"""
from pathlib import Path
import json, math, xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parent/'rooms'
PALETTE={'Theme.PAPER':(255,247,232),'Theme.PAPER_DEEP':(237,220,194),
 'Theme.SAND':(245,225,198),'Theme.SAND_DEEP':(224,198,166),
 'Theme.INK':(41,32,27),'Theme.SLAB':(54,44,37),'Theme.MUTED':(107,84,69),
 'Theme.GOLD':(255,203,61),'Theme.GOOD':(59,209,129),'Theme.HUE.gear':(64,147,230),
 'Theme.HUE.effects':(181,97,255)}
THEMES={
 'cozy':dict(wall='Theme.PAPER_DEEP',trim='Theme.MUTED',accent='Theme.GOOD'),
 'classic':dict(wall='Theme.PAPER',trim='Theme.MUTED',accent='Theme.SAND_DEEP'),
 'modern':dict(wall='Theme.PAPER',trim='Theme.SLAB',accent='Theme.HUE.gear'),
 'royal':dict(wall='Theme.SAND',trim='Theme.SLAB',accent='Theme.GOLD')}
MOUNTS=[
 dict(name='Featured',position=[0,.85,24],yaw=0,envelope=[12,11,6]),
 dict(name='Shelf_1',position=[-14.5,.05,8],yaw=-90,envelope=[11.4,11,4.8]),
 dict(name='Shelf_2',position=[-14.5,.05,21],yaw=-90,envelope=[11.4,11,4.8]),
 dict(name='Shelf_3',position=[14.5,.05,8],yaw=90,envelope=[11.4,11,4.8]),
 dict(name='Shelf_4',position=[14.5,.05,21],yaw=90,envelope=[11.4,11,4.8]),
 dict(name='Wall',position=[0,8.4,29.5],yaw=0,envelope=[12,4.4,.5]),
 dict(name='Record',position=[10,5.8,.5],yaw=180,envelope=[7,4.8,.5]),
 dict(name='Plaque_Legacy',position=[-10,5.8,.5],yaw=180,envelope=[7,4.8,.5]),
 dict(name='Door_Exit',position=[0,.1,1.6],yaw=0,envelope=[6,9,2])]
def prop(parent,typ,name,value):
 e=ET.SubElement(parent,typ,{'name':name});e.text=str(value);return e
def vector(parent,name,v):
 e=ET.SubElement(parent,'Vector3',{'name':name})
 for k,n in zip('XYZ',v):ET.SubElement(e,k).text=str(n)
def cf(parent,name,v,yaw=0):
 e=ET.SubElement(parent,'CoordinateFrame',{'name':name});c=round(math.cos(math.radians(yaw)),8);s=round(math.sin(math.radians(yaw)),8)
 for k,n in zip(['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'],v+[c,0,s,0,1,0,-s,0,c]): ET.SubElement(e,k).text=str(n)
def xml_model(theme,parts):
 root=ET.Element('roblox',{'version':'4'});ET.SubElement(root,'External').text='null';ET.SubElement(root,'External').text='nil'
 model=ET.SubElement(root,'Item',{'class':'Model','referent':'Model'});p=ET.SubElement(model,'Properties');prop(p,'string','Name','TrophyRoom_'+theme.title()+'_BLOCKOUT');prop(p,'Ref','PrimaryPart','Root')
 for i,part in enumerate(parts+[dict(name='Root',size=[.2,.2,.2],pos=[0,0,0],token='Theme.INK',collide=False,transparent=1)]):
  ref='Root' if part['name']=='Root' else 'P'+str(i);item=ET.SubElement(model,'Item',{'class':'Part','referent':ref});p=ET.SubElement(item,'Properties');prop(p,'string','Name',part['name']);vector(p,'size',part['size']);cf(p,'CFrame',part['pos']);prop(p,'bool','Anchored','true');prop(p,'bool','CanCollide',str(part.get('collide',False)).lower());prop(p,'bool','CanQuery',str(part.get('collide',False)).lower());prop(p,'bool','CanTouch','false');prop(p,'float','Transparency',part.get('transparent',0));prop(p,'token','Material',272);prop(p,'token','TopSurface',0);prop(p,'token','BottomSurface',0)
  rgb=PALETTE[part['token']];prop(p,'Color3uint8','Color3uint8',(255<<24)|(rgb[0]<<16)|(rgb[1]<<8)|rgb[2])
  if ref=='Root':
   for mount in MOUNTS:
    a=ET.SubElement(item,'Item',{'class':'Attachment','referent':'A'+mount['name']});ap=ET.SubElement(a,'Properties');prop(ap,'string','Name',mount['name']);cf(ap,'CFrame',mount['position'],mount['yaw']);prop(ap,'bool','Visible','false')
 ET.indent(root);return ET.tostring(root,encoding='unicode')
def build(theme):
 t=THEMES[theme];parts=[]
 def box(n,size,pos,token=None,collide=False):parts.append(dict(name=n,size=size,pos=pos,token=token or t['trim'],collide=collide))
 box('Floor',[37.2,.4,31.2],[0,-.2,15],'Theme.PAPER_DEEP',True)
 box('Wall_Back',[37.2,14,.6],[0,7,30.3],t['wall'],True)
 for sign in [-1,1]:
  box('Wall_Side'+str(sign),[.6,14,30],[sign*18.3,7,15],t['wall'],True)
  box('Wall_Front'+str(sign),[14.8,14,.6],[sign*11.2,7,-.3],t['wall'],True)
 box('Door_LintelWall',[7.6,4,.6],[0,12,-.3],t['wall'],True)
 box('Ceiling',[37.2,.4,31.2],[0,14.2,15],t['wall'],True)
 # Four ring pieces with butt joints, not overlapping slabs.
 for y,h in [(.35,.7),(13.5,.5)]:
  box('Ring_Back'+str(y),[36,h,.3],[0,y,29.8])
  for sign in [-1,1]:box('Ring_Side'+str(sign)+str(y),[.3,h,29.5],[sign*17.8,y,14.9])
  for sign in [-1,1]:box('Ring_Front'+str(sign)+str(y),[14,h,.3],[sign*10.9,y,.2])
 for sign in [-1,1]:box('Door_Jamb'+str(sign),[.5,9.8,.8],[sign*3.6,4.9,0])
 box('Door_Header',[7.7,.5,.8],[0,10.05,0])
 # Door visual is deliberately non-colliding: Fable supplies validated teleport.
 for sign in [-1,1]:
  box('Door_Leaf'+str(sign),[3.25,9,.3],[sign*1.65,4.5,-.15],t['trim'])
  box('Door_Handle'+str(sign),[.12,.8,.2],[sign*.45,4.4,.1],t['accent'])
 for x in [-10,10]:
  box('FrontBoard'+str(x),[7.6,5.4,.2],[x,5.8,.2],t['trim'])
  for side in [-1,1]:box('BoardSide'+str(x)+str(side),[.2,5.0,.2],[x+side*3.65,5.8,.4],t['accent'])
  for side in [-1,1]:box('BoardRail'+str(x)+str(side),[7.5,.2,.2],[x,5.8+side*2.6,.4],t['accent'])
 box('AchievementBacking',[13,5.2,.18],[0,8.4,29.8],t['trim'])
 for sign in [-1,1]:
  box('AchievementSide'+str(sign),[.22,4.8,.2],[sign*6.35,8.4,29.6],t['accent'])
  box('AchievementRail'+str(sign),[12.9,.22,.2],[0,8.4+sign*2.5,29.6],t['accent'])
 # Floor display bays accept complete existing Decor trophies, not tiny shelf trinkets.
 for sign in [-1,1]:
  for z in [8,21]:
   for dz in [-5.75,5.75]:box(f'BayPost{sign}_{z}_{dz}',[.7,11.5,.5],[sign*17.35,5.75,z+dz])
   box(f'BayHeader{sign}_{z}',[.7,.5,12],[sign*17.35,11.75,z])
   box(f'BayInset{sign}_{z}',[.16,10.6,10.8],[sign*17.9,5.7,z],t['trim'])
   box(f'BayAccent{sign}_{z}',[.12,.2,10.4],[sign*17.7,10.7,z],t['accent'])
 box('Featured_Base',[12,.6,6],[0,.3,24],t['trim'])
 box('Featured_Top',[11.6,.2,5.6],[0,.7,24],'Theme.PAPER')
 # Four untextured wall lights; emitters/brightness intentionally not added.
 for x in [-8,8]:
  box('LampBracket'+str(x),[.4,1.5,.5],[x,7,29.55])
  box('Lamp'+str(x),[.65,1.15,.65],[x,7,29.1],'Theme.GOLD')
 for x in [-5.4,5.4]:
  box('EntryLampBracket'+str(x),[.4,1.5,.5],[x,6.8,.45])
  box('EntryLamp'+str(x),[.65,1.15,.65],[x,6.8,.9],'Theme.GOLD')
 if theme=='cozy':
  for z in [5,24]:box('Beam'+str(z),[35.4,.6,.55],[0,12.9,z])
 elif theme=='classic':
  for x in [-15,-8,8,15]:
   box('Pilaster'+str(x),[.6,10,.5],[x,6,29.4]);box('Capital'+str(x),[1,.35,.8],[x,11.2,29.2],'Theme.SAND_DEEP')
 elif theme=='modern':
  for sign in [-1,1]:box('LightSlot'+str(sign),[.08,.16,25],[sign*17.6,12.3,15],t['accent'])
 elif theme=='royal':
  for x in [-13,0,13]:
   for dx in [-2.6,2.6]:box('ArchLeg'+str(x)+str(dx),[.4,2.2,.4],[x+dx,10.4,29.1],t['accent'])
   for dx,y,w in [(-1.8,11.6,1.2),(0,12,2.4),(1.8,11.6,1.2)]:box('ArchCrown'+str(x)+str(dx),[w,.4,.4],[x+dx,y,29.1],t['accent'])
 return parts
def coplanar(parts):
 bad=[]
 for i,a in enumerate(parts):
  for b in parts[i+1:]:
   for axis in range(3):
    other=[v for v in range(3) if v!=axis]
    if all(min(a['pos'][j]+a['size'][j]/2,b['pos'][j]+b['size'][j]/2)-max(a['pos'][j]-a['size'][j]/2,b['pos'][j]-b['size'][j]/2)>1e-5 for j in other):
     # Coincident outward-facing faces only; opposite faces at a butt joint are fine.
     for sign in [-1,1]:
      if abs(a['pos'][axis]+sign*a['size'][axis]/2-b['pos'][axis]-sign*b['size'][axis]/2)<1e-5:bad.append([a['name'],b['name'],axis,sign])
 return bad
reports={}
for theme in THEMES:
 parts=build(theme);bad=coplanar(parts)
 (ROOT/(theme+'-blockout.rbxmx')).write_text(xml_model(theme,parts),encoding='utf-8')
 (ROOT/(theme+'-geometry.json')).write_text(json.dumps(parts,indent=2),encoding='utf-8')
 reports[theme]={'structuralParts':len(parts),'basePartsIncludingRoot':len(parts)+1,'attachments':len(MOUNTS),'coplanarSameFacingPairs':bad,'status':'DRAFT blockout; not Studio-validated or approved art'}
(ROOT/'mount-contract.json').write_text(json.dumps({'units':'studs','pivot':'floor at front doorway centre','front':'-Z','inside':'+Z','defaultTheme':'classic','innerSize':[36,14,30],'mounts':MOUNTS,'themes':THEMES,'palette':PALETTE,'mountOrientation':'Attachment LookVector points toward viewer. Legacy Decor front is +Z; adapter must account for builder orientation.'},indent=2),encoding='utf-8')
(ROOT/'geometry-report.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
print(json.dumps(reports))
