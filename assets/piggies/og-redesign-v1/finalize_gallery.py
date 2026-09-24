"""Validate deliverables, generate per-skin manifests and an offline review gallery."""
from pathlib import Path
from collections import Counter
import hashlib,html,json,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
spec=json.loads((HERE/'design-specs.json').read_text())
delivered={
 'supernova':'Dark aubergine solar coat with amber flowing fissures, a dark snout and gold eyes. Six rooted tapered flame fins shape the flanks and rump, with bobbing glowing cinders and a sunburst aura preview. The face and front hat space stay clear.',
 'prismatic':'Blue-violet triangular jewel facets, lavender snout and cool glowing eyes. Six rainbow diamond prisms sway along a thin rear semicircle arc, keeping the face clear. Spectral emission pulses and a restrained rainbow sparkle aura complete the design.',
 'stormcaller':'Storm-slate coat with sparse branching cyan lightning, navy snout and blue eyes. Two faceted cloud clusters and angular lightning forks bob beside the rear flanks. Small blue motes preview the storm aura.',
 'hologram':'Deep teal coat with cyan scanlines and grid, magenta signal bars, cyan eyes and snout. Gentle emission pulses and cyan aura motes create the hologram effect.'
}
rows=[];totals=Counter()
for s in spec['skins']:
    s=dict(s)
    if s['key'] in delivered:
        s['conceptDesign']=s['design']
        s['design']=delivered[s['key']]
    key=s['key'];home=ROOT/'assets/piggies'/s['tier']/key
    report=json.loads((home/'package/og-v1-asset-report.json').read_text())
    assert report['baseGeometryAndUVPreserved'],key
    assert all(p['nonManifoldEdges']==0 and p['triangles']<20000 for p in report['parts']),key
    assert all(e['roundTripChecked'] and e.get('roundTripBoundsError',1)<.001 for e in report['exports']),key
    required=[home/'preview'/f'{key}-og-v1-{view}.png' for view in ('concept','hero','back')]
    required.extend([home/'source'/f'{key}-og-v1-procedural.blend',home/'package'/f'{key}-og-v1.blend',home/'package'/f'{key}-og-v1-complete.fbx'])
    if s['tier']!='rare':
        required.append(home/'preview'/f'{key}-og-v1-motion.png')
        assert report['aura'] and report['animation']['materialPulse']
        assert report['animation']['loopClosureError']<1e-5
    if s['tier']=='legendary':
        assert report['animation']['animatedGeometry']>=6
        assert report['animation']['faceClearanceSampledFrames']==9
    for p in required:assert p.exists() and p.stat().st_size>0,p
    for t in report['textures']:
        p=home/t['file'];assert hashlib.sha256(p.read_bytes()).hexdigest()==t['sha256'],p
    prefix=f"../{s['tier']}/{key}"
    data={**s,'prefix':prefix,'triangles':sum(p['triangles'] for p in report['parts']),
          'addedTriangles':sum(p['triangles'] for p in report['parts'] if p['role']=='accessory'),
          'maps':len(report['textures']),'blender':f'{prefix}/package/{key}-og-v1.blend',
          'hero':f'{prefix}/preview/{key}-og-v1-hero.png','back':f'{prefix}/preview/{key}-og-v1-back.png',
          'concept':f'{prefix}/preview/{key}-og-v1-concept.png',
          'motion':f'{prefix}/preview/{key}-og-v1-motion.png' if s['tier']!='rare' else None}
    rows.append(data);totals[s['tier']]+=1
    manifest={'key':key,'name':s['name'],'tier':s['tier'],'path':home.relative_to(ROOT).as_posix(),
              'status':report['status'],'revision':'og-redesign-v1','templates':{},'idSources':{},
              'config':{'status':'in Config.SKINS; existing runtime appearance unchanged; new revision not installed'},
              'concept':f'preview/{key}-og-v1-concept.png','prompt':'generate/og-v1-concept-prompt.txt','conceptMethod':'built-in image_gen',
              'source':f'source/{key}-og-v1-procedural.blend','review':f'package/{key}-og-v1.blend',
              'generator':str((HERE/'build_og.py').relative_to(ROOT)),'report':'package/og-v1-asset-report.json',
              'maps':report['textures'],'tierEvidence':report['tierChecks'],'animation':report['animation'],
              'files':{room:sorted(p.name for p in (home/room).iterdir() if p.is_file() and p.suffix not in ('.blend1','.pyc')) for room in ('source','generate','sheets','preview','package')}}
    (home/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    rule=spec['tierRules'][s['tier']]
    (home/'README.md').write_text(f'''# {s['name']} — OG redesign v1

{s['design']}

**Tier: {s['tier'].title()}.** {rule}.

- [Concept](preview/{key}-og-v1-concept.png), generated with built-in image_gen; exact prompt in `generate/og-v1-concept-prompt.txt`.
- [Actual model render](preview/{key}-og-v1-hero.png) and [rear](preview/{key}-og-v1-back.png).
- [Packed Blender review](package/{key}-og-v1.blend). Play frames 1–145 at 24 fps for the six-second loop on epics/legendaries.
- [Editable procedural source](source/{key}-og-v1-procedural.blend).
- [Complete FBX](package/{key}-og-v1-complete.fbx), with optional accessories-only FBX when this design has geometry.
- {len(report['textures'])} 1024 px maps in `sheets/`; all original pig geometry and UVs preserved.
- {data['addedTriangles']} added triangles; closed meshes and FBX round trips verified in `package/og-v1-asset-report.json`.

Blender -b --python assets/piggies/og-redesign-v1/build_og.py -- --skin {key}

The FBX is a static import pose. Animation and material pulses live in the packed Blender scene.
The AURA collection is a visual proxy for Roblox's `{s['aura'] or 'none'}` emitter and is excluded from FBX exports.
Roblox upload and installation are pending. Do not stack the new geometry on the old shards/FX.
Use the existing shared pig meshes and replace their maps; the complete FBX is a standalone option.
Preserve the existing rarity, income, order and price. The concept is an art target; PNG model views show the delivered geometry and materials.
''',encoding='utf-8')

(HERE/'manifest.json').write_text(json.dumps({'revision':'og-redesign-v1','counts':dict(totals),'built':len(rows),'status':'Local assets complete; Roblox upload/integration pending','skins':rows},indent=2)+'\n',encoding='utf-8')
(HERE/'README.md').write_text('''# OG Piggies — redesign v1

15 individual concepts and 15 Blender assets: six rares, six epics, three legendaries.

Open `index.html` for the concept/model comparison gallery. Each pig's files are under its tier/key folder.
`design-specs.json` records the designs and tier evidence. `concept-receipts.json` records the exact built-in image_gen prompts and source paths.

Current tier authority: the designer's 2026-09-21 amendment in CLAUDE.md and Config's animal-epic comment.
The older PIGGY-SKIN-MAP's aura-only epic definition is superseded.

- Rare: authored coat/material, with modest embedded unlit accents on Rockslide and Quartz.
- Epic: a distinct visible coat plus emissive detail, a gentle material animation and its named aura.
- Legendary: coat, glow, aura and substantial animated solar/prism/cloud geometry. Rear orbital sway keeps the face clear.

All original body/trim/eye geometry and UVs are preserved. Every export is reimported to verify geometry counts and bounds.
Each mesh is closed and below 20,000 triangles. Six-second animation loops close continuously; legendary face clearance is sampled at nine frames.
Color maps are baked from spatial procedural materials at 2048 and reduced to 1024. Glow and Verdigris material masks are separate.

Live Config, SurfacePacks, skin prices/rarities and published Roblox assets are unchanged.
Install only after uploading the relevant maps/accessory meshes and capturing their IDs. The FBXs carry static import poses; the Blender scenes retain animation.
Existing runtime color animation must not replace full-color coats. Drive emitted strength or selected overlay regions instead. Use existing aura emitters rather than importing preview motes.

Rebuild: `python assets/piggies/og-redesign-v1/build_batch.py --keys marble,rockslide,quartz,banker,tiedye,verdigris,ghost,charcoal,starlight,nightlight,sugarrush,hologram,supernova,prismatic,stormcaller`
Then run `python assets/piggies/og-redesign-v1/finalize_gallery.py`.
''',encoding='utf-8')

page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OG Piggies · Concepts & Models</title>
<style>
:root{font-family:Inter,Segoe UI,sans-serif;color:#edeaf3;background:#11121a;color-scheme:dark}*{box-sizing:border-box}body{margin:0}header{padding:48px 5vw 24px;background:linear-gradient(120deg,#252333,#13151e)}.eyebrow{letter-spacing:.24em;font-size:12px;color:#c5a47b}h1{font-size:clamp(34px,5vw,64px);margin:10px 0}header p{color:#bfc0cc;max-width:760px;line-height:1.6}.tools{display:flex;gap:12px;flex-wrap:wrap;align-items:center;padding:18px 5vw;background:#1b1c27;position:sticky;top:0;z-index:2}button,select{font:inherit;padding:10px 17px;border:1px solid #555365;border-radius:30px;color:#e7e3ef;background:#272735;cursor:pointer}button.active{background:#eee7dc;color:#262131;border-color:#eee7dc}.legend{margin-left:auto;font-size:12px;color:#aaa5b8}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:24px;padding:30px 5vw}.card{background:#1e202b;border:1px solid #343440;border-radius:16px;overflow:hidden}.picture{width:100%;aspect-ratio:1;object-fit:contain;display:block;background:#bbbfc5;cursor:zoom-in}.info{padding:20px}.tag{text-transform:uppercase;font-size:10px;letter-spacing:.18em;color:#79b8ff}.epic .tag{color:#c699ff}.legendary .tag{color:#e6bb69}.card h2{margin:6px 0 10px;font-size:24px}.desc{font-size:13px;line-height:1.55;color:#bfc1ce;min-height:82px}.links{display:flex;gap:15px;flex-wrap:wrap;font-size:12px}.links a{color:#e0cbac}.evidence{font-size:11px;color:#9a9cae;margin:13px 0}.viewlabel{float:right;font-size:11px;color:#aaa5b8}footer{padding:24px 5vw 50px;color:#aaa7b6;font-size:13px;line-height:1.6}dialog{padding:0;border:none;background:#171820;border-radius:10px;max-width:94vw;max-height:96vh}dialog img{display:block;max-width:92vw;max-height:89vh;object-fit:contain}dialog button{position:absolute;right:12px;top:12px;background:#171820cc}dialog::backdrop{background:#08090de8}@media(max-width:1000px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){.grid{grid-template-columns:1fr}.legend{display:none}}
</style><header><div class="eyebrow">ROB A PIGGY BANK / OG COLLECTION</div><h1>Fifteen new identities.</h1><p>Six rares. Six epics. Three legendaries. Compare each concept with its actual Blender model, inspect the back, and open the editable asset.</p></header>
<nav class="tools"><button class="active" data-tier="all">All 15</button><button data-tier="rare">Rare · 6</button><button data-tier="epic">Epic · 6</button><button data-tier="legendary">Legendary · 3</button><select aria-label="Image view" id="view"><option value="hero">Actual model · front</option><option value="back">Actual model · back</option><option value="concept">Concept artwork</option><option value="motion">Second animation pose</option></select><span class="legend">LOCAL ASSETS · ROBLOX INSTALLATION PENDING</span></nav><main class="grid" id="cards"></main><footer>Rare: coat / material. Epic: coat + glow / motion + aura. Legendary: substantial moving geometry + glow + aura.<br>Concepts are art targets. Model views are renders of the delivered files. Particle proxies stay in Blender; runtime uses the named Roblox aura. FBX exports are static; Blender files retain the six-second animation.</footer><dialog id="zoom"><button aria-label="Close enlarged image">Close ×</button><img alt="Enlarged piggy preview"></dialog>
<script>const rows=__ROWS__;let tier='all';const root=document.querySelector('#cards'),view=document.querySelector('#view');
function draw(){root.replaceChildren();rows.filter(r=>tier==='all'||r.tier===tier).forEach(r=>{const card=document.createElement('article');card.className='card '+r.tier;const mode=view.value;const src=r[mode]||r.hero;card.innerHTML=`<img class="picture" loading="lazy" src="${src}" alt="${r.name} ${mode}"><div class="info"><span class="tag">${r.tier}</span><span class="viewlabel">${mode==='concept'?'CONCEPT':mode==='motion'&&r.tier==='rare'?'STATIC MODEL':'ACTUAL MODEL'}</span><h2>${r.name}</h2><div class="desc">${r.design}</div><div class="evidence">${r.maps} maps · ${r.addedTriangles.toLocaleString()} added triangles${r.aura?' · '+r.aura+' aura':''}</div><div class="links"><a href="${r.blender}">Blender file ↗</a><a href="${r.prefix}/package/${r.key}-og-v1-complete.fbx">FBX ↗</a><a href="${r.prefix}/README.md">Asset notes ↗</a></div></div>`;card.querySelector('img').onclick=()=>{const d=document.querySelector('#zoom');d.querySelector('img').src=src;d.showModal()};root.append(card)})}
document.querySelectorAll('[data-tier]').forEach(b=>b.onclick=()=>{tier=b.dataset.tier;document.querySelectorAll('[data-tier]').forEach(x=>x.classList.toggle('active',x===b));draw()});view.onchange=draw;document.querySelector('#zoom button').onclick=()=>document.querySelector('#zoom').close();draw();</script></html>'''
(HERE/'index.html').write_text(page.replace('__ROWS__',json.dumps(rows)),encoding='utf-8')
print('Validated and catalogued',len(rows),'assets;',dict(totals),'maps:',sum(r['maps'] for r in rows))
