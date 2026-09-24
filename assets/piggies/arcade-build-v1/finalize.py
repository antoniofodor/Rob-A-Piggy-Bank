"""Validate all Arcade assets and publish local concept/model review files."""
from pathlib import Path
import hashlib,json,shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
spec=json.loads((HERE/'design-specs.json').read_text());rows=[]
for s in spec['skins']:
    key=s['key'];home=HERE.parent/s['tier']/key
    r=json.loads((home/'package/arcade-v1-asset-report.json').read_text())
    assert r['baseGeometryAndUVPreserved']
    assert all(p['nonManifoldEdges']==0 and p['triangles']<20000 for p in r['parts'])
    assert all(e['roundTripChecked'] and e['roundTripBoundsError']<.001 for e in r['exports'])
    if s['tier']!='rare':assert r['animation']['loopClosureError']<1e-5
    if s['tier']=='legendary':assert r['animation']['faceClearanceSampledFrames']==9
    for t in r['textures']:
        p=home/t['file'];assert hashlib.sha256(p.read_bytes()).hexdigest()==t['sha256']
    concept=home/'preview'/f'{key}-arcade-v1-concept.png'
    shutil.copy2(HERE.parent/'arcade-concepts-v1'/s['concept'],concept)
    files=[home/'package'/f'{key}-arcade-v1.blend',home/'source'/f'{key}-arcade-v1-procedural.blend',home/'package'/f'{key}-arcade-v1-complete.fbx']
    files.extend(home/'preview'/f'{key}-arcade-v1-{v}.png' for v in ('hero','back'))
    if s['tier']!='rare':files.append(home/'preview'/f'{key}-arcade-v1-motion.png')
    assert all(p.exists() and p.stat().st_size>0 for p in files)
    prefix=f"../{s['tier']}/{key}"
    added=sum(p['triangles'] for p in r['parts'] if p['role']=='accessory')
    data={**s,'prefix':prefix,'maps':len(r['textures']),'addedTriangles':added}
    for v in ('hero','back','concept','motion'):data[v]=f'{prefix}/preview/{key}-arcade-v1-{v}.png' if v!='motion' or s['tier']!='rare' else None
    rows.append(data)
    (home/'manifest.json').write_text(json.dumps({**s,'revision':'arcade-build-v1','status':'Local Blender assets complete; Roblox integration pending','conceptMethod':'built-in image_gen','maps':r['textures'],'animation':r['animation'],'tierEvidence':r['tierChecks'],'report':'package/arcade-v1-asset-report.json','review':f'package/{key}-arcade-v1.blend'},indent=2)+'\n')
    (home/'README.md').write_text(f'''# {s['name']} — Arcade v1

{s['design']}

Tier: **{s['tier'].title()}**. {len(r['textures'])} maps; {added} added accessory triangles.

- [Packed Blender review](package/{key}-arcade-v1.blend)
- [Procedural source](source/{key}-arcade-v1-procedural.blend)
- [Complete static FBX](package/{key}-arcade-v1-complete.fbx)
- [Front](preview/{key}-arcade-v1-hero.png), [rear](preview/{key}-arcade-v1-back.png), [concept](preview/{key}-arcade-v1-concept.png)
- [Validation report](package/arcade-v1-asset-report.json)

Original six pig meshes and UVs are unchanged. All export meshes are closed and each is under 20,000 triangles. FBX reimports verified counts and bounds.
For animated assets play frames 1–145 at 24 fps (six seconds). FBX files are static import poses; the packed Blender file retains animation. The separate AURA collection is preview geometry and is excluded from exports.
New aura names are design proposals, not existing Roblox emitters. Roblox upload, Config rows, placement and runtime animation remain unimplemented.
Player One uses pixel-shaded texture artwork on the original smooth silhouette. It is not a 2D sprite or pixelated camera effect. Its revised authored coat qualifies as Rare; the original simple Common concept is superseded.

Rebuild: `blender -b --python assets/piggies/arcade-build-v1/build_arcade.py -- --skin {key}`.
''',encoding='utf-8')
(HERE/'manifest.json').write_text(json.dumps({'revision':'arcade-build-v1','count':len(rows),'status':'Local assets complete; Roblox integration pending','skins':rows},indent=2)+'\n')
(HERE/'README.md').write_text('''# Arcade — expanded collection

Ten completed local assets: four Rares, three Epics and three Legendaries. This expansion adds Pixel, Circuit Board, Power-Up, Synthwave, Final Boss and Mecha Player.
Player One follows the selected 16-bit concept; the resulting authored coat moves this starter from the original Common proposal to Rare. The wider 24-piggy lineup remains a proposal.

Open `index.html` to compare original concepts and actual model renders. `arcade-collection-v2.blend` contains the overview plus ten individual asset scenes. Individual packed Blender files, source files, static FBXs and baked maps are linked in each card.

Player One approximates sprite shading with fixed pixel clusters, a limited palette, dithered transitions and 1P badges on the existing smooth mesh. Retro Carpet uses printed colored shapes. Respawn has seven small animated cube accessories. Jackpot has three separate rotating symbol reels, a fitted saddle/housing, bulbs and six moving gold tokens.

Mesh/UV preservation, closed meshes, per-mesh triangle limits, FBX round-trip bounds, animation loop closure and legendary face clearance are checked by the builder. The finalizer verifies texture hashes and required files. The aura collections are preview proxies, not exported particle systems. New aura keys require implementation in Roblox.

These are local assets only. No live Config or published Roblox content was changed. Full animation stays in Blender; the FBXs carry static import poses. No automatic pixelation of the in-game silhouette is claimed.

Concepts were generated with built-in image_gen. Exact prompts and originals are in `../arcade-concepts-v1/`; selected references are copied into each asset's preview folder.

Run `python assets/piggies/arcade-build-v1/prepare_builder.py` after editing the spatial-paint or geometry source fragments, then `python assets/piggies/arcade-build-v1/build_batch.py --keys playerone,retrocarpet,respawn,jackpot,pixel,circuitboard,powerup,synthwave,finalboss,mechaplayer` and `python assets/piggies/arcade-build-v1/finalize.py`.
''',encoding='utf-8')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Arcade Piggies · Expanded Collection</title>
<style>*{box-sizing:border-box}body{margin:0;background:#171320;color:#f7ebda;font:16px Segoe UI,sans-serif}header{padding:40px 5vw 24px;background:linear-gradient(120deg,#33203d,#181420)}small{color:#5ed7ed;letter-spacing:.2em}h1{font-size:clamp(32px,5vw,60px);margin:12px 0}p{line-height:1.6;color:#c9bdcf;max-width:800px}nav{position:sticky;top:0;background:#211a2c;z-index:2;display:flex;gap:10px;flex-wrap:wrap;padding:16px 5vw}button,select{font:inherit;color:#eee4ed;background:#34243d;border:1px solid #78538b;border-radius:9px;padding:10px 15px;cursor:pointer}button.active{color:#151223;background:#6fe0ec}main{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:25px;padding:28px 5vw}article{border:1px solid #47324e;border-radius:14px;overflow:hidden;background:#221b2c}img{display:block;width:100%;aspect-ratio:1.35;object-fit:contain;background:#2b2534;cursor:zoom-in}.info{padding:20px}h2{margin:8px 0}.tag{text-transform:uppercase;color:#7cc9ee;font-size:12px;letter-spacing:.15em}.epic .tag{color:#db9af5}.legendary .tag{color:#f8cb65}.meta{font-size:12px;color:#baadbf}a{color:#83dce6}.links{display:flex;flex-wrap:wrap;gap:15px;margin-top:18px;font-size:13px}footer{padding:16px 5vw 40px;font-size:13px;color:#b6a8c0;line-height:1.6}dialog{padding:0;background:#251e30;max-width:95vw;border:1px solid #78538b;border-radius:10px}dialog img{width:auto;max-width:92vw;max-height:87vh;aspect-ratio:auto}dialog button{position:absolute;right:12px;top:12px}dialog::backdrop{background:#09060cec}@media(max-width:800px){main{grid-template-columns:1fr}}</style>
<header><small>ROB A PIGGY BANK / ARCADE</small><h1>Player One has entered.</h1><p>Ten piggies, including six new Arcade designs. Switch between concept art, the actual front and rear, and a second animation pose.</p></header>
<nav><button data-view="hero" class="active">Actual front</button><button data-view="back">Actual rear</button><button data-view="concept">Concept art</button><button data-view="motion">Animation pose</button></nav><main id="cards"></main><footer>Player One is Rare for its authored pixel coat; its 3D silhouette stays smooth. The wider 24-piggy collection is still a proposal.<br>Local Blender assets complete. Roblox installation pending. Animation lives in Blender; FBXs are static. Aura motes are preview proxies.<br><a href="arcade-collection-v2.blend">Open the complete Blender collection</a> · <a href="../og-redesign-v1/index.html">OG collection</a></footer><dialog><button aria-label="Close enlarged preview">Close ×</button><img alt="Enlarged piggy preview"></dialog>
<script>const rows=__ROWS__;let mode='hero';function draw(){const root=document.querySelector('#cards');root.replaceChildren();for(const r of rows){const el=document.createElement('article');el.className=r.tier;const src=r[mode]||r.hero;el.innerHTML=`<img src="${src}" alt="${r.name} ${mode}"><div class="info"><span class="tag">${r.tier} / ${mode==='concept'?'CONCEPT':'ACTUAL MODEL'}</span><h2>${r.name}</h2><p>${r.design}</p><div class="meta">${r.maps} maps · ${r.addedTriangles.toLocaleString()} added triangles</div><div class="links"><a href="${r.prefix}/package/${r.key}-arcade-v1.blend">Blender</a><a href="${r.prefix}/package/${r.key}-arcade-v1-complete.fbx">FBX</a><a href="${r.prefix}/README.md">Build notes</a></div></div>`;el.querySelector('img').onclick=()=>{document.querySelector('dialog img').src=src;document.querySelector('dialog').showModal()};root.append(el)}}document.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>{mode=b.dataset.view;document.querySelectorAll('[data-view]').forEach(x=>x.classList.toggle('active',x===b));draw()});document.querySelector('dialog button').onclick=()=>document.querySelector('dialog').close();draw();</script></html>'''
(HERE/'index.html').write_text(page.replace('__ROWS__',json.dumps(rows)),encoding='utf-8')
print('Validated',len(rows),'assets;',sum(r['maps'] for r in rows),'maps;',[(r['key'],r['addedTriangles']) for r in rows])

# Keep the active Legendary revision visible when rebuilding the original batch gallery.
if (HERE/'active-revisions.json').exists():
    import runpy
    runpy.run_path(str(HERE.parent/'arcade-legendary-v2/update_review.py'),run_name='__main__')
