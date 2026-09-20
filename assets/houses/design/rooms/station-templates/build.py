"""Rebuild B2 furniture studies, mount contracts, plans and offline checks.

No runtime source, house geometry or existing art is modified.
"""
import html
import json
import math
import re
from pathlib import Path
import xml.etree.ElementTree as ET

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
THEME = {k: tuple(map(int, rgb.split(','))) for k, rgb in re.findall(
    r'Theme\.(\w+) = Color3.fromRGB\(([^)]+)\)',
    (ROOT / 'src/ReplicatedStorage/Shared/Theme.luau').read_text(encoding='utf-8'))}
SPECS = [
    ('cozy', 'Worn timber / Common', 16, 12, 10.5, 2, 1, 'ACORN', 'MUTED', 'SAND'),
    ('classic', 'Framed timber / Rare', 18, 14, 11, 4, 2, 'SLAB', 'ACORN', 'SAND'),
    ('modern', 'Recessed cases / Epic', 22, 16, 11.5, 6, 3, 'SLAB', 'COOL', 'PAPER'),
    ('royal', 'Stepped gallery / Legendary', 26, 20, 13, 10, 4, 'PRESTIGE', 'GOLD_DEEP', 'PAPER'),
]

def colour(token):
    return '#%02x%02x%02x' % THEME[token]

def build(spec):
    key, title, w, d, h, count, walls, body, trim, inset = spec
    parts, mounts = [], []
    def part(name, p, size, token):
        parts.append(dict(name=name, position=p, size=size, token=token))
    def mount(name, p, size=None, yaw=180, purpose='display'):
        mounts.append(dict(name=name, position=p, usableSize=size, yawDegrees=yaw,
                           purpose=purpose, facing='local +Z faces viewer'))
    rows = 1 if count <= 4 else 2
    cols = count // rows
    rack_w = (cols - 1) * 4 + 3.4
    rack_z = d - 1.9
    # Each item gets a physical 3.4 x 3.0 shelf and 2.8-cubed usable space.
    for row in range(rows):
        y = 3.2 if rows == 1 else 1.8 + row * 3.4
        part(f'CollectionShelf_{row+1}', [0, y-.18, rack_z], [rack_w,.36,3], body)
        part(f'ShelfLip_{row+1}', [0, y-.2, rack_z-1.52], [rack_w,.22,.12], trim)
        for col in range(cols):
            x = (col-(cols-1)/2)*4
            mount(f'Shelf_{row*cols+col+1}', [x,y,rack_z], [2.8,2.8,2.8])
    rack_top = 6.3 if rows == 1 else 8.3
    for x in [-rack_w/2-.2,rack_w/2+.2]:
        part('CabinetUpright', [x,rack_top/2,rack_z+.95], [.3,rack_top,.45], trim)
    part('CabinetBack', [0,rack_top/2,d-.24], [rack_w+.7,rack_top,.22], body)
    for i in range(walls):
        x = (i-(walls-1)/2)*4
        y = 7.8 if rows == 1 else 9.7
        part(f'AchievementFrame_{i+1}', [x,y,d-.51], [3.7,2.8,.25], trim)
        part(f'AchievementInset_{i+1}', [x,y,d-.70], [3.4,2.5,.10], inset)
        # wall payload occupies the space in front of the decorative frame.
        mount('Wall' if i == 0 else f'Wall_{i+1}', [x,y-1.25,d-1.02], [3.4,2.5,.4])
    fx = -w/2+2.6
    part('FeaturedFoot', [fx,.25,3], [4.4,.5,4.4], trim)
    part('FeaturedBase', [fx,1.1,3], [3.5,1.2,3.5], body)
    part('FeaturedTop', [fx,1.85,3], [4.4,.3,4.4], trim)
    mount('Featured', [fx,2,3], [4.2,4.2,4.2])
    rx = w/2-2.6
    part('RecordsDesk', [rx,2.5,3], [4.2,.35,2.6], body)
    for dx in [-1.65,1.65]:
        part('DeskLeg', [rx+dx,1.15,3.6], [.3,2.3,.35], trim)
    part('BookCover', [rx,2.76,3], [2.7,.14,1.9], trim)
    part('BookPages', [rx,2.9,3], [2.5,.14,1.75], inset)
    part('BookSpine', [rx,3,3], [.1,.08,1.8], body)
    mount('Record', [rx,2.68,3], [4,2.3,2.2])
    part('LegacyFrame', [w/2-.23,4.1,7], [.25,3.5,3.2], trim)
    part('LegacyFace', [w/2-.43,4.1,7], [.10,3.1,2.8], inset)
    mount('Plaque_Legacy', [w/2-.8,2.55,7], [2.8,3.1,.4], yaw=-90)
    for label, stand, anchor in [
        ('Achievements', [0,0,d-5.5], [0,3,d-3.6]),
        ('Records', [rx,0,5.5], [rx,3,4]),
        ('Legacy', [w/2-3.8,0,7], [w/2-1,4,7]),
    ]:
        mount('Interact_'+label, anchor, purpose='interaction')
        mount('Stand_'+label, stand, purpose='standing')
    mount('Door_Exit', [0,0,0], purpose='doorstep')
    return dict(id=key, title=title, status='Draft furniture study; not integrated',
                clearInterior=[w,h,d], minimumDoor=[4,7], parts=parts, mounts=mounts,
                palette=dict(body=body,trim=trim,inset=inset),
                targetCounts=dict(featured=1,collection=count,wall=walls,records=1,legacy=1))

def bounds(p, size):
    return [[p[i]-size[i]/2 for i in range(3)], [p[i]+size[i]/2 for i in range(3)]]

def overlap(a,b):
    return all(a[0][i]<b[1][i]-1e-6 and a[1][i]>b[0][i]+1e-6 for i in range(3))

def verify(data):
    w,h,d = data['clearInterior']
    envelope=[[-w/2,0,0],[w/2,h,d]]
    errors=[]
    volumes=[]
    for m in data['mounts']:
        if not m['usableSize']:
            continue
        sx,sy,sz=m['usableSize']
        if abs(m['yawDegrees'])==90:
            sx,sz=sz,sx
        x,y,z=m['position']
        box=bounds([x,y+sy/2,z],[sx,sy,sz])
        volumes.append((m['name'],box))
    for name,box in volumes+[(p['name'],bounds(p['position'],p['size'])) for p in data['parts']]:
        if any(box[0][i]<envelope[0][i]-1e-6 or box[1][i]>envelope[1][i]+1e-6 for i in range(3)):
            errors.append('Outside proposed room: '+name)
    for i,(name,a) in enumerate(volumes):
        for other,b in volumes[i+1:]:
            if overlap(a,b): errors.append('Display overlap: '+name+' / '+other)
    obstacles=[bounds(p['position'],p['size']) for p in data['parts']]
    obstacles.extend(b for _,b in volumes)
    samples=0
    # Conservative 2.4 x 6.0 x 2.4 body; two straight segments to every station.
    for m in data['mounts']:
        if m['purpose']!='standing': continue
        x,_,z=m['position']
        route=[[0,0,1.3],[0,0,z],[x,0,z]]
        for a,b in zip(route,route[1:]):
            n=max(1,math.ceil(math.dist(a,b)/.1))
            for step in range(n+1):
                t=step/n
                p=[a[i]+(b[i]-a[i])*t for i in range(3)]
                p[1]=3.05
                box=bounds(p,[2.4,6,2.4])
                samples+=1
                if any(overlap(box,obs) for obs in obstacles):
                    errors.append('Route obstruction: '+m['name']);break
    assert not errors, (data['id'],errors)
    return dict(status='PASS', furnitureParts=len(data['parts']),helperRootParts=1,
                attachments=len(data['mounts']),displayVolumes=len(volumes),
                sampledRoutePositions=samples,bodyProxy=[2.4,6,2.4],step=.1,
                scope='Proposed room envelope, display/display overlap, sampled furniture and display clearance. Not actual house fit, continuous physics, camera or runtime grid validation.')

def export_model(data):
    root=ET.Element('roblox',version='4')
    model=ET.SubElement(root,'Item',{'class':'Model','referent':'Study'})
    props=ET.SubElement(model,'Properties')
    ET.SubElement(props,'string',name='Name').text='B2_'+data['id']+'_FURNITURE_DRAFT'
    def addprop(props, kind, name, value):
        el=ET.SubElement(props,kind,name=name)
        el.text=str(value)
        return el
    def vector(props,name,p):
        el=ET.SubElement(props,'Vector3',name=name)
        for k,v in zip('XYZ',p): ET.SubElement(el,k).text=str(v)
    def frame(props,p,yaw=0):
        el=ET.SubElement(props,'CoordinateFrame',name='CFrame')
        a=math.radians(yaw);c,s=round(math.cos(a),8),round(math.sin(a),8)
        for k,v in zip(['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'],p+[c,0,s,0,1,0,-s,0,c]):
            ET.SubElement(el,k).text=str(v)
    for i,p in enumerate(data['parts']+[dict(name='MountRoot',position=[0,0,0],size=[.1,.1,.1],token='INK')]):
        item=ET.SubElement(model,'Item',{'class':'Part','referent':f'Part{i}'})
        props=ET.SubElement(item,'Properties')
        addprop(props,'string','Name',p['name']);vector(props,'size',p['size']);frame(props,p['position'])
        for name,value in [('Anchored','true'),('CanCollide','false'),('CanTouch','false'),('CanQuery','false')]:
            addprop(props,'bool',name,value)
        addprop(props,'token','Material',272) # SmoothPlastic
        addprop(props,'token','TopSurface',0);addprop(props,'token','BottomSurface',0)
        rgb=THEME[p['token']]
        addprop(props,'Color3uint8','Color3uint8',255*2**24+rgb[0]*2**16+rgb[1]*256+rgb[2])
        token=ET.SubElement(item,'Item',{'class':'StringValue','referent':f'Token{i}'})
        tp=ET.SubElement(token,'Properties');addprop(tp,'string','Name','ThemeToken');addprop(tp,'string','Value',p['token'])
        if p['name']=='MountRoot':
            addprop(props,'float','Transparency',1)
            for j,m in enumerate(data['mounts']):
                marker=ET.SubElement(item,'Item',{'class':'Attachment','referent':f'Mount{j}'})
                mp=ET.SubElement(marker,'Properties');addprop(mp,'string','Name',m['name'])
                frame(mp,m['position'],m['yawDegrees'])
    ET.indent(root)
    path=OUT/(data['id']+'.rbxmx');ET.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
    check=ET.parse(path)
    assert len(check.findall('.//Item[@class="Part"]'))==len(data['parts'])+1
    assert len(check.findall('.//Item[@class="Attachment"]'))==len(data['mounts'])

def plan(data):
    w,h,d=data['clearInterior'];scale=15;ox=270;oy=65
    def xy(x,z):return ox+x*scale,oy+(d-z)*scale
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 540 {d*scale+160}" role="img" aria-label="{data["id"]} measured top view">']
    svg.append(f'<rect width="540" height="{d*scale+160}" fill="{colour("PAPER")}"/>')
    svg.append(f'<g font-family="Arial,sans-serif" fill="{colour("INK")}"><text x="24" y="30" font-size="18" font-weight="bold">{w} × {d} studs · clear height {h}</text>')
    svg.append(f'<rect x="{ox-w*scale/2}" y="{oy}" width="{w*scale}" height="{d*scale}" fill="{colour("SAND")}" stroke="{colour("INK")}" stroke-width="3"/>')
    # Footprints intentionally combine heights; elevations are explicit in JSON.
    for p in data['parts']:
        x,_,z=p['position'];sx,_,sz=p['size'];px,py=xy(x-sx/2,z+sz/2)
        svg.append(f'<rect x="{px}" y="{py}" width="{sx*scale}" height="{sz*scale}" fill="{colour(p["token"])}" stroke="{colour("INK")}" stroke-width=".5"/>')
    for m in data['mounts']:
        if m['purpose']!='standing':continue
        x,_,z=m['position'];px,py=xy(x,z);_,entry=xy(0,0)
        svg.append(f'<path d="M {ox} {entry} V {py} H {px}" fill="none" stroke="{colour("MUTED")}" stroke-width="2" stroke-dasharray="5 4"/>')
        svg.append(f'<circle cx="{px}" cy="{py}" r="18" fill="{colour("PAPER")}" stroke="{colour("INK")}"/><text x="{px}" y="{py+5}" text-anchor="middle" font-size="14">{m["name"][6]}</text>')
    _,fy=xy(0,0)
    svg.append(f'<path d="M {ox-30} {fy} h 60" stroke="{colour("PAPER")}" stroke-width="5"/><text x="{ox}" y="{fy+28}" font-size="14" text-anchor="middle">4-stud entrance · origin (0,0,0)</text>')
    svg.append(f'<text x="24" y="{fy+58}" font-size="13">A achievements · R records · L Legacy</text></g></svg>')
    (OUT/(data['id']+'.svg')).write_text(''.join(svg),encoding='utf-8')

def main():
    models=[build(spec) for spec in SPECS];reports={}
    for data in models:
        reports[data['id']]=verify(data);export_model(data);plan(data)
        (OUT/(data['id']+'.json')).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    (OUT/'checks.json').write_text(json.dumps(reports,indent=2)+'\n')
    cards=[]
    for m in models:
        c=m['targetCounts'];key=m['id'];r=reports[key]
        cards.append(f'<article><div class="eyebrow">{key.upper()} · DRAFT</div><h2>{m["title"]}</h2><img src="{key}.svg" alt="{key} furniture floor plan"><p>{c["collection"]} collection positions · {c["wall"]} achievement panels<br>{r["furnitureParts"]} furniture parts + 1 hidden mount root</p><p><a href="{key}.rbxmx">Roblox furniture model</a> · <a href="{key}.json">Dimensions and mounts</a></p></article>')
    page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>B2 · Walk-in display studies</title><style>
    *{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font:16px/1.55 system-ui,sans-serif}main{max-width:1180px;margin:auto;padding:32px 24px}h1{font-size:clamp(28px,4vw,44px);line-height:1.12;margin:8px 0 20px}h2{font-size:21px;margin:5px 0 12px}.eyebrow{font-size:12px;font-weight:800;letter-spacing:.12em}.intro{max-width:780px}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px;margin:28px 0}article{border:1px solid var(--ink);border-radius:14px;padding:20px;background:var(--sand)}img{width:100%;display:block;border-radius:8px}a{color:var(--ink);text-underline-offset:3px}.note{padding:16px 20px;border-left:4px solid var(--ink);background:var(--sand)}@media(max-width:700px){main{padding:22px 14px}.grid{grid-template-columns:1fr}article{padding:16px}}
    </style><body><main><div class="eyebrow">ROB A PIGGY BANK / BRIEF B2 / SEPTEMBER 17</div><h1>One doorway.<br>Three places to show your story.</h1><p class="intro">Measured furniture studies for the achievement cabinet, career records book and Legacy plaque. Every layout retains one featured trophy and full menu access. Bigger rooms add display positions.</p><p class="note"><strong>Draft for review.</strong> These are furniture assets inside proposed clear room envelopes. The starter still needs a hollow shell. Current runtime wall-grid and mount-reader behavior require adaptation before integration.</p><div class="grid">'''+''.join(cards)+'''</div><p><a href="HANDOFF.md">Read the integration handoff</a> · <a href="checks.json">Offline geometry checks</a></p><p>Plans are schematic top views, not renders or pavement photographs. Studio avatar, camera, pursuit, owner/visitor menus and mobile checks remain pending.</p></main></body></html>'''
    page=page.replace('Every layout retains one featured trophy and full menu access.', 'Every layout reserves one featured trophy; full menu access is required by the brief.')
    page=page.replace('Current runtime wall-grid and mount-reader behavior require adaptation before integration.', 'The current runtime has simplified to stat panels; this broader B2 furniture study remains deferred pending scope alignment.')
    page=page.replace('*{box-sizing',f':root{{--paper:{colour("PAPER")};--ink:{colour("INK")};--sand:{colour("SAND")}}}*{{box-sizing')
    (OUT/'index.html').write_text(page,encoding='utf-8')
    print(json.dumps(reports,indent=2))

if __name__=='__main__':main()
