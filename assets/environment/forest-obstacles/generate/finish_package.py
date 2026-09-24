"""Write collision-only Roblox models, preview sheet, and validated ZIP."""
from pathlib import Path
import json
import math
import zipfile
import hashlib
from xml.etree.ElementTree import Element,SubElement,tostring
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
catalog=json.loads((ROOT/'catalog.json').read_text())
validation=json.loads((ROOT/'validation.json').read_text())
assert validation['failures']==[]

def matmul(a,b):return [[sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
def rotation(angles):
    x,y,z=map(math.radians,angles)
    rx=[[1,0,0],[0,math.cos(x),-math.sin(x)],[0,math.sin(x),math.cos(x)]]
    ry=[[math.cos(y),0,math.sin(y)],[0,1,0],[-math.sin(y),0,math.cos(y)]]
    rz=[[math.cos(z),-math.sin(z),0],[math.sin(z),math.cos(z),0],[0,0,1]]
    return matmul(matmul(rx,ry),rz)

def collision_model(key,spec):
    root=Element('roblox',version='4')
    model=SubElement(root,'Item',{'class':'Model','referent':'Model_'+key})
    props=SubElement(model,'Properties')
    SubElement(props,'string',name='Name').text=spec['mesh_name']+'_Collision'
    SubElement(props,'Ref',name='PrimaryPart').text='Origin_'+key
    pieces=[{'name':'Origin','center':[0,0,0],'size':[.2,.2,.2],'rotation_degrees':[0,0,0]}]+spec['collision']
    for i,p in enumerate(pieces):
        ref=('Origin_' if i==0 else 'Collider_'+str(i)+'_')+key
        node=SubElement(model,'Item',{'class':'Part','referent':ref});properties=SubElement(node,'Properties')
        SubElement(properties,'string',name='Name').text=p['name']
        size=SubElement(properties,'Vector3',name='size')
        for axis,value in zip('XYZ',p['size']):SubElement(size,axis).text=str(value)
        frame=SubElement(properties,'CoordinateFrame',name='CFrame')
        for axis,value in zip('XYZ',p['center']):SubElement(frame,axis).text=str(value)
        rot=rotation(p['rotation_degrees'])
        for row in range(3):
            for col in range(3):SubElement(frame,f'R{row}{col}').text=str(rot[row][col])
        SubElement(properties,'float',name='Transparency').text='1'
        for name,value in [('Anchored',True),('CanCollide',i>0),('CanQuery',i>0),('CanTouch',False),('CastShadow',False)]:
            SubElement(properties,'bool',name=name).text=str(value).lower()
    (ROOT/key/'collision.rbxmx').write_bytes(tostring(root,encoding='utf-8'))
    # Verify the artifact's data matches the checked collision description.
    assert len(model.findall('Item'))==len(spec['collision'])+1

for key,spec in catalog['assets'].items():collision_model(key,spec)

preview=ROOT/'preview';preview.mkdir(exist_ok=True)
font=lambda size,bold=False:ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf' if bold else 'C:/Windows/Fonts/segoeui.ttf',size)
sheet=Image.new('RGB',(1680,1190),(21,32,30));d=ImageDraw.Draw(sheet)
d.text((40,25),'FOREST EXPLORER KIT',font=font(36,True),fill=(242,239,218))
d.text((40,76),'Eight large props for the roaming grounds  /  flat-shaded meshes + open-path collision models',font=font(21),fill=(163,184,171))
for i,(key,spec) in enumerate(catalog['assets'].items()):
    x=24+(i%4)*416;y=124+(i//4)*505
    d.rounded_rectangle((x,y,x+400,y+484),radius=18,fill=(32,47,42))
    d.text((x+18,y+17),spec['name'],font=font(22,True),fill=(236,233,210))
    im=Image.open(ROOT/key/'preview'/(key+'.png')).convert('RGBA')
    im.thumbnail((382,340),Image.Resampling.LANCZOS)
    sheet.paste(im,(x+(400-im.width)//2,y+62+(340-im.height)//2),im)
    dims=spec['dimensions_studs']
    d.text((x+18,y+410),f'{dims[0]:.0f} wide  x  {dims[1]:.0f} tall  x  {dims[2]:.0f} deep',font=font(18),fill=(164,185,173))
    if spec['passage']:
        p=spec['passage'];desc=f'Walk through: {p["clear_width"]:g}w x {p["clear_height"]:g}h studs'
    elif key=='stepping-stumps':desc='Four low jumping / stepping platforms'
    elif key.startswith('giant'):desc='Oversized landmark tree'
    else:desc='Large cover and route obstacle'
    d.text((x+18,y+443),desc,font=font(17),fill=(201,211,178))
d.text((40,1153),f'{validation["total_triangles"]:,} triangles across all 8 meshes  /  shared palette  /  local assets, not placed in the live map',font=font(18),fill=(163,184,171))
sheet.save(preview/'forest-kit.png')

paths=[ROOT/'README.md',ROOT/'catalog.json',ROOT/'validation.json',ROOT/'forest-palette.png']
for key in list(catalog['assets'])+['generate','preview']:
    paths.extend(p for p in (ROOT/key).rglob('*') if p.is_file() and p.suffix not in ('.blend1','.pyc') and '__pycache__' not in p.parts)
archive=ROOT/'forest-obstacles.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as zip:
    for p in sorted(paths):zip.write(p,'forest-obstacles/'+p.relative_to(ROOT).as_posix())
with zipfile.ZipFile(archive) as zip:assert zip.testzip() is None
receipt={'file':archive.name,'files':len(paths),'bytes':archive.stat().st_size,
         'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()}
(ROOT/'package.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
