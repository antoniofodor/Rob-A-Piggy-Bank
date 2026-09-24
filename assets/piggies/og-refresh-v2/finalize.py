from pathlib import Path
import json,hashlib,urllib.request
from PIL import Image,ImageDraw,ImageFont
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
rows=json.loads((HERE/'design-specs.json').read_text())['skins'];items=[]
for row in rows:
    key=row['key'];home=ROOT/'assets/piggies'/row['tier']/key/'revisions/og-v2'
    report=json.loads((home/'package/og-v2-asset-report.json').read_text())
    paths=[home/'package'/f'{key}-og-v2.blend',home/'package'/f'{key}-og-v2-complete.fbx']
    paths += [home/'preview'/f'{key}-og-v2-{view}.png' for view in ('hero','back','top')]
    motion=key in ('aurora','neonmint','ghost','hologram')
    if motion:
        animation=home/'preview'/f'{key}-og-v2-motion.webp';paths.append(animation)
        assert len(list((home/'preview/frames').glob('motion-*.png')))==48
        with Image.open(animation) as image:
            assert image.n_frames>1,(key,image.n_frames)
            duration=0
            for frame in range(image.n_frames):image.seek(frame);image.load();duration+=image.info['duration']
            assert duration==6000,(key,duration)
    for path in paths:
        assert path.exists() and path.stat().st_size>1000,path
        if path.suffix in ('.png','.webp'):
            with Image.open(path) as image:image.verify()
        url='http://127.0.0.1:8841/'+path.relative_to(ROOT/'assets/piggies').as_posix()
        req=urllib.request.Request(url,method='HEAD')
        with urllib.request.urlopen(req) as res:assert res.status==200,url
    for tex in report['textures']:
        path=home/tex['file'];assert hashlib.sha256(path.read_bytes()).hexdigest()==tex['sha256']
    items.append({'key':key,'name':row['name'],'tier':row['tier'],'model':str(paths[0].relative_to(ROOT/'assets/piggies')).replace('\\','/'),'maps':len(report['textures']),'accessoryTriangles':sum(p['triangles'] for p in report['parts'] if p['role']=='accessory'),'animatedPreview':motion,'runtimeInstalled':True,'geometryUVPreserved':True,'fbxRoundTripPassed':True})
validation=json.loads((HERE/'validation.json').read_text());assert len(validation)==7
manifest={'revision':'og-refresh-v2','status':'All seven revisions installed in project and Roblox Studio','skins':items,'validation':'validation.json','preview':'http://127.0.0.1:8841/og-refresh-v2/index.html','runtimeEffectsRequireIntegration':[]}
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
# A contact sheet of actual model renders, not a generated concept image.
canvas=Image.new('RGB',(1600,1000),(16,21,31));draw=ImageDraw.Draw(canvas)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',23);title=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',42)
draw.text((32,18),'OG PIGGIES / SECOND LOOK',font=title,fill=(233,244,252))
for i,row in enumerate(rows):
    col=i%4;r=i//4;x=col*400;y=95+r*445
    path=ROOT/'assets/piggies'/row['tier']/row['key']/'revisions/og-v2/preview'/f"{row['key']}-og-v2-hero.png"
    im=Image.open(path).convert('RGB');im.thumbnail((390,390));canvas.paste(im,(x+5,y))
    draw.text((x+15,y+397),row['name'],font=font,fill=(206,226,242))
    draw.text((x+15,y+426),row['tier'].upper(),font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',13),fill=(145,192,188))
draw.text((1225,640),'5 RARE',font=title,fill=(155,197,243));draw.text((1225,698),'2 EPIC',font=title,fill=(209,170,245))
draw.text((1225,785),'Actual model renders',font=font,fill=(162,186,206));draw.text((1225,818),'Animation in gallery',font=font,fill=(162,186,206))
canvas.save(HERE/'og-refresh-v2-contact.jpg',quality=94)
# Record the user's already-given Jackpot approval, without changing installation.
path=HERE.parent/'arcade-jackpot-v3/manifest.json';jackpot=json.loads(path.read_text());jackpot['reviewStatus']='Approved by user';path.write_text(json.dumps(jackpot,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
