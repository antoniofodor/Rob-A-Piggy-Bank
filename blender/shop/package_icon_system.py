"""Package actual Blender renders for review, including small-size proofs."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,re
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/shop-ui/icon-system-v1'
NAMES={'coin':'Standard coin','income':'Earn Faster','capacity':'Bigger Piggy Bank','upgrades':'Upgrades','home':'Home','companions':'Companions','rides':'Rides','supplies':'Supplies','style':'Style & Crates','crate-common':'Common crate','crate-rare':'Rare crate','crate-legendary':'Legendary crate'}
ICONS={**NAMES,'coin-front':'Currency coin — front view'}
# `locks` and `fences` are still rendered and still uploaded; the SHOP no
# longer reads them -- their cards fall through to `UpgradePreview`, which
# builds the vault dial and the fence tier actually being bought. See the
# note in ShopIcons.luau. Left here so a rebuild keeps producing proofs.
UPGRADES={'locks':'Vault Lock','fences':'Fence','lockpicks':'Lockpicks','sack':'Bigger Sack','boots':'Getaway Speed','tiptoe':'Sneak'}
ICONS.update(UPGRADES)
report=json.loads((OUT/'build-report.json').read_text());assert set(ICONS)<=set(report)
uploads=json.loads((OUT/'roblox-uploads.json').read_text()) if (OUT/'roblox-uploads.json').exists() else {'icons':{}}
manifest={'version':1,'status':'icons integrated in shop source; world models provided separately' if uploads['icons'] else 'review — not uploaded or installed','renderStyle':'Smooth beveled 3D models; transparent PNG; no baked particles or outer glow','icons':{}}
(OUT/'small').mkdir(exist_ok=True)
for key,name in ICONS.items():
 p=OUT/f'{key}.png';im=Image.open(p).convert('RGBA');assert im.size==(768,768)
 alpha=im.getchannel('A');box=alpha.getbbox();assert box and min(box[:2])>8 and max(box[2:])<760,(key,box)
 assert alpha.getextrema()==(0,255)
 for size in (32,48,64,128,256):im.resize((size,size),Image.Resampling.LANCZOS).save(OUT/'small'/f'{key}-{size}.png')
 manifest['icons'][key]={'name':name,'image':f'{key}.png','source':f'sources/{key}.blend','assetId':uploads['icons'].get(key),'alphaBounds':box,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
tiers={};definitions=['--!strict','-- Generated from exported geometry; position values are Roblox XYZ in studs.','local Definitions: {[string]: any} = {']
for tier,color,rate,size,burst in [('common',(255,196,79),3,.15,5),('rare',(86,227,255),9,.21,10),('legendary',(190,129,255),15,.25,16)]:
 spec=json.loads((OUT/f'crates/{tier}/manifest.json').read_text());tiers[tier]=spec
 attachments=', '.join(f'{n}={{{", ".join(map(str,p))}}}' for n,p in spec['robloxAttachments'].items())
 definitions.append(f' {tier} = {{color={{{", ".join(map(str,color))}}}, rate={rate}, sparkSize={size}, burst={burst}, hinge={{{", ".join(map(str,spec["robloxHinge"]))}}}, attachments={{{attachments}}}}},')
definitions+=['}','return Definitions']
# CrateDefinitions.luau and CratePresentation.luau were removed on 2026-09-23:
# a client crate-presentation draft that nothing in src/ ever adopted, because
# Shared/Crates.luau and Config.CHESTS do that job. `definitions` is still
# built above so the manifest arithmetic below is unchanged; re-add the write
# here if the draft is ever wanted again.
manifest['crates']=tiers
if (OUT/'models/plunger/manifest.json').exists():
 manifest['models']={'plunger':json.loads((OUT/'models/plunger/manifest.json').read_text())}
if (OUT/'models/coin/manifest.json').exists():
 manifest.setdefault('models',{})['coin']=json.loads((OUT/'models/coin/manifest.json').read_text())
supplies={}
for key in ('bubblegum-bomb','golden-bone'):
 path=OUT/f'models/{key}/manifest.json'
 if path.exists():supplies[key]=json.loads(path.read_text());manifest.setdefault('models',{})[key]=supplies[key]
if supplies:
 defs=['--!strict','-- Generated from the exported supply-model attachment coordinates.','local Definitions: {[string]: any} = {']
 for key,spec in supplies.items():
  points=', '.join(f'{n}={{{", ".join(map(str,p))}}}' for n,p in spec['attachmentsRoblox'].items())
  defs.append(f' ["{key}"] = {{attachments={{{points}}}}},')
 defs+=['}','return Definitions'];(OUT/'models/SupplyDefinitions.luau').write_text('\n'.join(defs))
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
# Native ImageRect crops are derived from alpha bounds, so new renders stay large.
registry=ROOT/'src/ReplicatedStorage/Shared/ShopIcons.luau'
crop_lines=['-- BEGIN GENERATED UPGRADE CROPS','local crops = {']
for key in ('income','capacity',*UPGRADES):
 x0,y0,x1,y1=manifest['icons'][key]['alphaBounds'];x0=max(0,x0-16);y0=max(0,y0-16);x1=min(768,x1+16);y1=min(768,y1+16)
 crop_lines.append(f' ["{key}"] = {{{x0}, {y0}, {x1-x0}, {y1-y0}}},')
crop_lines+=['}','-- END GENERATED UPGRADE CROPS']
source=registry.read_text();source,count=re.subn(r'-- BEGIN GENERATED UPGRADE CROPS.*?-- END GENERATED UPGRADE CROPS','\n'.join(crop_lines),source,flags=re.S);assert count==1
registry.write_text(source,encoding='utf-8')
try:font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',24)
except OSError:font=ImageFont.load_default()
sheet=Image.new('RGB',(1440,1280),'#fff6e1');draw=ImageDraw.Draw(sheet)
for i,(key,name) in enumerate(NAMES.items()):
 x=(i%4)*360;y=(i//4)*410
 draw.rounded_rectangle((x+12,y+12,x+348,y+398),radius=24,fill=['#ffe8a1','#cceff0','#e6dbff'][i//4])
 im=Image.open(OUT/f'{key}.png').convert('RGBA').resize((316,316),Image.Resampling.LANCZOS);sheet.paste(im,(x+22,y+23),im)
 draw.text((x+180,y+351),name,font=font,fill='#2e2332',anchor='mm')
draw.text((25,1250),'Smooth icon system / shared snout emblem / review v1',font=font,fill='#2e2332')
sheet.save(OUT/'contact-sheet.png')
upgrade_sheet=Image.new('RGB',(1200,820),'#fff6e1');udraw=ImageDraw.Draw(upgrade_sheet)
for i,(key,title) in enumerate(UPGRADES.items()):
 x=i%3*400;y=i//3*410
 udraw.rounded_rectangle((x+10,y+10,x+390,y+400),radius=24,fill='#d9ebfa' if i<2 else '#f3deed')
 im=Image.open(OUT/f'{key}.png').convert('RGBA');im.thumbnail((340,340),Image.Resampling.LANCZOS);upgrade_sheet.paste(im,(x+30,y+14),im)
 udraw.text((x+200,y+373),title,font=font,fill='#2e2332',anchor='mm')
upgrade_sheet.save(OUT/'defend-rob-sheet.png')
cards=''.join(f'<article class="icon-card"><div class="art"><img src="{key}.png" alt="{name}"></div><h3>{name}</h3><div class="size-proof"><img src="small/{key}-32.png" width="32" height="32" alt="32 pixel preview"><img src="small/{key}-48.png" width="48" height="48" alt="48 pixel preview"><span>32 / 48 px</span></div><a href="{key}.png">PNG</a> <a href="sources/{key}.blend">Blender</a></article>' for key,name in ICONS.items() if not key.startswith('crate-'))
crates=''.join(f'''<article class="crate-card {tier}"><div class="crate-art"><img id="{tier}-art" src="crate-{tier}.png" alt="{tier} crate"><div class="sparks" aria-hidden="true">{''.join(f'<i style="--n:{i}">✦</i>' for i in range(3 if tier=='common' else 7 if tier=='rare' else 12))}</div></div><h3>{tier.title()}</h3><p>{desc}</p><div class="crate-options"><button onclick="crateMode('{tier}','closed',this)" aria-pressed="true">Shop</button><button onclick="crateMode('{tier}','open',this)" aria-pressed="false">Open lid</button><button onclick="crateMode('{tier}','fx',this)" aria-pressed="false">Effect study</button></div><div class="downloads"><a href="crates/{tier}/{tier}.glb">GLB</a><a href="crates/{tier}/{tier}.fbx">FBX</a><a href="sources/crate-{tier}.blend">Blender</a></div></article>''' for tier,desc in [('common','Warm timber, brass bands and the shared snout coin seal.'),('rare','Blue reinforced chest, silver trim and a crystal-topped lid.'),('legendary','Violet and gold, crowned lid, wing trim and a snout clasp.')])
page='''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Shop icons · Review 01</title><style>
*{box-sizing:border-box}body{margin:0;background:#f5eedf;color:#31263a;font:16px/1.5 system-ui,sans-serif}main{max-width:1320px;margin:auto;padding:38px 26px 70px}h1{font-size:46px;line-height:1.1;margin:10px 0 16px;letter-spacing:-1.5px}h2{font-size:30px;margin:40px 0 8px}h3{font-size:21px;margin:10px 0}p{max-width:820px;margin:8px 0 18px}.eyebrow{font-size:12px;font-weight:900;letter-spacing:2px;color:#695771}.pill{border:2px solid #382c3c;border-radius:20px;padding:5px 12px;font-size:12px;font-weight:800;background:#e3d4fa}header{display:flex;align-items:center;justify-content:space-between;gap:20px}a{color:#64409b;font-weight:700}button{font:inherit;cursor:pointer;border:2px solid #3d2c46;border-radius:12px;padding:8px 14px;background:#fff8e9;color:#382840;font-weight:800}button[aria-pressed=true]{background:#ffd044;box-shadow:0 3px 0 #866022}button:focus-visible,a:focus-visible{outline:3px solid #246bec;outline-offset:3px}.shop{display:grid;grid-template-columns:160px 285px 1fr;gap:15px;background:#fff9e9;border:3px solid #382c3c;border-radius:25px;padding:16px;box-shadow:0 8px 0 #ded1ba}.shop-top{grid-column:1/-1;display:flex;align-items:center;gap:12px;padding:6px 8px;background:#ffd54e;border-radius:14px;font-weight:950;font-size:28px}.balance{margin-left:auto;display:flex;align-items:center;background:#fff5d5;border:2px solid #4f3531;border-radius:13px;padding:0 15px 0 4px;font-size:22px}.balance img{width:48px;height:48px}.nav{display:flex;flex-direction:column;gap:10px}.nav div{display:flex;align-items:center;gap:7px;background:#ddf1df;border:2px solid #594457;border-radius:13px;padding:5px;font-size:13px;font-weight:850}.nav img{width:39px;height:39px;object-fit:contain}.nav div:nth-child(1){background:#ffdc65}.nav div:nth-child(3){background:#d5eafb}.nav div:nth-child(4){background:#ffd4d9}.nav div:nth-child(5){background:#e7daf7}.nav div:nth-child(6){background:#d0f0e8}.choices{display:grid;gap:12px}.choice{position:relative;padding:10px;text-align:left;background:linear-gradient(#ffeaa5,#ffd56a);border:3px solid #a37d3e;box-shadow:none}.choice[aria-pressed=true]{box-shadow:0 0 0 3px #fff5a0,0 0 18px #ffd041;background:linear-gradient(#ffe79a,#ffcc43);border-color:#77502d}.choice img{width:100%;height:154px;object-fit:contain}.choice h3{font-size:21px;line-height:1.1;margin:4px 0}.choice .check{display:none;position:absolute;right:-10px;top:-10px;background:#30be63;color:#fff;border:3px solid #fff;border-radius:50%;width:32px;height:32px;text-align:center;line-height:26px;font-size:23px;box-shadow:0 0 0 2px #206d40}.choice[aria-pressed=true] .check{display:block}.requirement{font-size:11px;display:inline-block;color:#fff;background:#76409b;border:2px solid #482857;border-radius:12px;padding:4px 8px;letter-spacing:.2px}.hero{border:3px solid #765333;border-radius:18px;background:radial-gradient(ellipse at 50% 45%,#fff4b9,#e6ab3c);padding:16px;display:flex;flex-direction:column}.hero h3{font-size:30px;margin:0}.hero-art{height:255px;display:grid;place-items:center}.hero-art img{width:100%;height:100%;object-fit:contain;filter:drop-shadow(0 9px 8px #94581535)}.stats{display:flex;align-items:center;gap:10px}.stat{flex:1;background:#fff3ce;border:2px solid #634b31;border-radius:12px;padding:8px 12px;font-weight:900;font-size:21px;white-space:nowrap}.stat small{display:block;font-size:10px}.next{background:#daf8ca;border-color:#418334}.arrow{font-size:26px;font-weight:900}.cta{background:linear-gradient(#a856d5,#71318e);color:#fff;text-align:center;border:2px solid #44244f;border-radius:13px;margin-top:13px;padding:12px;font-weight:900}.caption{font-size:13px;color:#706270}.icons{display:grid;grid-template-columns:repeat(4,1fr);gap:17px}.icon-card{background:#fffaf0;border:1px solid #ddcfb7;border-radius:19px;padding:14px;text-align:center}.art{aspect-ratio:1;background:radial-gradient(#fff5d9,#f0e7d8);border-radius:14px}.art img{width:100%;height:100%;object-fit:contain}.size-proof{height:60px;display:flex;align-items:center;justify-content:center;gap:10px}.size-proof span{font-size:11px;color:#7e7181}.icon-card a{font-size:12px;margin:0 7px}.crates{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}.crate-card{background:#fffaf0;border:2px solid #d4c1a2;border-radius:20px;padding:15px}.crate-card.rare{border-color:#8fbcdf}.crate-card.legendary{border-color:#b698d8}.crate-art{aspect-ratio:1;position:relative;border-radius:13px;background:radial-gradient(#fdf2d4,#ead4b2);overflow:hidden}.rare .crate-art{background:radial-gradient(#e3f6ff,#b7d6ed)}.legendary .crate-art{background:radial-gradient(#ecddff,#c5abeb)}.crate-art>img{width:100%;height:100%;object-fit:contain;position:relative;z-index:1}.crate-card p{font-size:13px;min-height:42px}.crate-options{display:flex;gap:6px;flex-wrap:wrap}.crate-options button{font-size:12px;padding:6px 10px}.downloads{display:flex;gap:14px;margin-top:16px;font-size:12px}.sparks{display:none;position:absolute;inset:0;pointer-events:none;z-index:2}.with-fx .sparks{display:block}.sparks i{position:absolute;left:calc(12% + mod(var(--n)*37,76)*1%);top:calc(15% + mod(var(--n)*19,65)*1%);font-size:calc(10px + mod(var(--n),3)*5px);font-style:normal;color:#fff3bd;text-shadow:0 0 9px #eaba32;animation:twinkle 2s calc(var(--n)*-.3s) infinite}.rare .sparks i{color:#f2ffff;text-shadow:0 0 10px #39c8ff}.legendary .sparks i{color:#fff3bc;text-shadow:0 0 12px #af60ff}.legendary.with-fx .crate-art{box-shadow:inset 0 -30px 40px #9958ff66}.coin-band{display:flex;align-items:center;gap:24px;padding:22px;background:#fff9eb;border-radius:18px;border:1px solid #ddcfb7}.coin-band .coin-main{width:190px}.coin-band h3{margin-top:0}.coin-sizes{display:flex;align-items:center;gap:20px}.coin-sizes div{display:grid;justify-items:center;font-size:11px;color:#706270}.note{padding:18px;background:#e9dfef;border-radius:13px;font-size:14px;margin-top:20px}@keyframes twinkle{0%,100%{opacity:0;transform:translateY(6px) scale(.4)}45%{opacity:1;transform:translateY(-4px) scale(1)}}@media(prefers-reduced-motion:reduce){.sparks i{animation:none;opacity:.7}}@media(max-width:1050px){.shop{grid-template-columns:125px 230px 1fr}.nav div{font-size:11px}.nav img{width:30px;height:30px}.stat{font-size:17px}.icons{grid-template-columns:repeat(3,1fr)}}@media(max-width:760px){main{padding:22px 14px}header{align-items:flex-start}h1{font-size:34px}.shop{grid-template-columns:1fr}.shop-top{font-size:22px}.nav{display:none}.choices{grid-template-columns:1fr 1fr}.choice img{height:125px}.choice h3{font-size:17px}.hero-art{height:280px}.crates{grid-template-columns:1fr}.icons{grid-template-columns:repeat(2,1fr)}.coin-band{gap:12px;flex-wrap:wrap}.coin-band .coin-main{width:140px}.coin-sizes{gap:10px}.pill{white-space:nowrap}}
</style></head><body><main><header><div><div class="eyebrow">ROB A PIGGY BANK / ASSET REVIEW 01</div><h1>A brighter icon language.</h1></div><span class="pill">Ready for your review</span></header><p>Smooth, modeled icons with a shared piggy-snout coin. Large shapes, consistent lighting and clean transparent backgrounds. These are the actual asset renders.</p>
<div class="shop"><div class="shop-top">‹ &nbsp; Upgrades <div class="balance"><img src="coin.png" alt="Gold snout coin">125.1M</div></div><nav class="nav">NAV</nav><div class="choices"><button class="choice" onclick="selectUpgrade('income')" id="income-choice" aria-pressed="true"><span class="check">✓</span><h3>Earn Faster</h3><img src="income.png" alt="Piggy, clock and coins"><span class="requirement">▣ &nbsp; LEVEL 42 / 42 · REBIRTH</span></button><button class="choice" onclick="selectUpgrade('capacity')" id="capacity-choice" aria-pressed="false"><span class="check">✓</span><h3>Bigger Piggy Bank</h3><img src="capacity.png" alt="Small piggy growing into a large piggy"><span class="requirement">▣ &nbsp; LEVEL 42 / 42 · REBIRTH</span></button></div><section class="hero"><h3 id="hero-title">Earn Faster</h3><span class="caption">LEVEL 42</span><div class="hero-art"><img id="hero-image" src="income.png" alt="Earn Faster preview"></div><div class="stats"><div class="stat"><small>NOW</small><span id="now">160.8K / sec</span></div><span class="arrow">➜</span><div class="stat next"><small>AFTER REBIRTH</small><span id="next">176.9K / sec</span></div></div><div class="cta">⟳ &nbsp; REBIRTH TO UNLOCK MORE</div></section></div><p class="caption">Interactive visual study. Click either upgrade to compare its icon. Income uses the supplied screenshot values; capacity uses a qualitative comparison. This page is a local review, not the live game.</p>
<h2>One coin, everywhere.</h2><p>The raised snout and recessed nostrils replace the star. The same emblem appears on upgrade coins, the money bag, and every crate tier.</p><div class="coin-band"><img class="coin-main" src="coin.png" alt="Gold coin with a raised piggy snout"><div><h3>The reusable currency asset</h3><div class="coin-sizes">COINSIZES</div></div></div>
<h2>The icon family</h2><p>Eight shop icons plus the shared currency icon. Each includes an editable Blender source and transparent PNGs down to 32 pixels.</p><section class="icons">CARDS</section>
<h2>Three tiers. Three silhouettes.</h2><p>Closed shop renders have no particles or aura. Inspect each open lid, or switch on the animated effect study.</p><section class="crates">CRATES</section><p class="caption">Effect study is a browser motion illustration. The supplied Roblox helper implements tier-colored particles, lights, bursts and lid motion; its final appearance still needs Studio review.</p><div class="note"><b>Prepared for integration:</b> GLB / FBX models, separate opening lids, effect anchor coordinates, <a href="README.md">import notes</a>. Image uploads and live UI installation follow art review. Existing crate prices and reward pools are unchanged.</div><p><a href="contact-sheet.png">Open the complete contact sheet</a> · <a href="manifest.json">Asset manifest</a></p></main><script>
function selectUpgrade(key){document.querySelectorAll('.choice').forEach(b=>b.setAttribute('aria-pressed',String(b.id===key+'-choice')));document.getElementById('hero-image').src=key+'.png';let income=key==='income';document.getElementById('hero-title').textContent=income?'Earn Faster':'Bigger Piggy Bank';document.getElementById('hero-image').alt=income?'Earn Faster icon':'Bigger Piggy Bank icon';document.getElementById('now').textContent=income?'160.8K / sec':'Current size';document.getElementById('next').textContent=income?'176.9K / sec':'More storage'}
function crateMode(tier,mode,button){let card=button.closest('.crate-card');card.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));card.classList.toggle('with-fx',mode==='fx');document.getElementById(tier+'-art').src='crate-'+tier+(mode==='open'?'-open':'')+'.png'}
</script></body></html>'''
nav=''.join(f'<div><img src="{key}.png" alt="">{NAMES[key]}</div>' for key in ['upgrades','home','companions','rides','supplies','style'])
sizes=''.join(f'<div><img src="small/coin-front-{s}.png" width="{s}" height="{s}" alt="Front-facing coin at {s} pixels">{s} px</div>' for s in (32,48,64,128))
page=page.replace('src="coin.png"','src="coin-front.png"')
page=page.replace('The reusable currency asset','Front-facing currency icon')
page=page.replace('<div class="coin-sizes">COINSIZES</div>','<div class="coin-sizes">COINSIZES</div><p><a href="coin-front.png">Front-view PNG (768 px)</a> · <a href="small/coin-front-128.png">128 px for HUD / shop</a> · <a href="sources/coin-front.blend">Blender source</a></p>')
page=page.replace('NAV',nav).replace('COINSIZES',sizes).replace('CARDS',cards).replace('CRATES',crates)
if uploads['icons']:
 page=page.replace('Image uploads and live UI installation follow art review.','The icons are uploaded and wired into the shop source. World-model installation is separate.')
 # The packaged copy of ShopIcons.luau was removed on 2026-09-23. A second
 # copy of a live module, in a folder Rojo does not sync, only tracks src/ on
 # the day somebody re-runs this script -- and it HAD drifted, still carrying
 # the retired `acorn` row and pointing at an assets/acorn-ui/ that no longer
 # exists. src/ReplicatedStorage/Shared/ShopIcons.luau is the one copy.
if (OUT/'plunger.png').exists():
 page=page.replace('<h2>Three tiers.', '<h2>The new plunger</h2><p>The Supplies icon now combines this plunger with Bubblegum Bomb gum and a golden bone. The model has a hollow rubber cup, reinforced rim, wooden shaft and rounded grip.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:18px"><figure class="icon-card" style="margin:0"><img src="plunger.png" alt="Smooth red plunger model" style="width:100%;max-height:350px;object-fit:contain"><figcaption>New plunger model</figcaption></figure><figure class="icon-card" style="margin:0"><img src="plunger-underside.png" alt="Hollow underside of the rubber plunger cup" style="width:100%;max-height:350px;object-fit:contain"><figcaption>Hollow cup inspection</figcaption></figure></div><p><a href="models/plunger/plunger.glb">Plunger GLB</a> · <a href="models/plunger/plunger.fbx">Plunger FBX</a> · <a href="sources/plunger.blend">Blender source</a> · <a href="models/plunger/README.md">Import notes</a></p><h2>Three tiers.')
(OUT/'index.html').write_text(page,encoding='utf-8')
if len(supplies)==2:
 asset_cards=''
 for key,title in [('bubblegum-bomb','Bubblegum Bomb'),('golden-bone','Golden Bone')]:
  asset_cards+=f'<article class="icon-card"><img src="{key}.png" alt="{title} standalone model" style="width:100%;max-height:350px;object-fit:contain"><h3>{title}</h3><p style="font-size:13px">{sum(supplies[key]["triangles"].values()):,} triangles · optional effects</p><a href="models/{key}/{key}.glb">GLB</a><a href="models/{key}/{key}.fbx">FBX</a><a href="sources/{key}.blend">Blender</a><a href="models/{key}/README.md">Import notes</a></article>'
 page=page.replace('<h2>Three tiers.', '<h2>Standalone supplies</h2><p>Separate game assets matching the approved Supplies icon. Golden sparkles and fuse sparks are provided as optional runtime effects.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:18px">'+asset_cards+'</div><p><a href="models/SupplyEffects.luau">Supply effect helper</a></p><h2>Three tiers.')
 (OUT/'index.html').write_text(page,encoding='utf-8')
print('PACKAGED',len(ICONS),'icons; transparent margins and small-size exports checked')

# One package-local file index, generated from real files, not a second runtime asset-ID registry.
models=[('Snout coin','models/coin','coin','coin'),('Plunger','models/plunger','plunger','plunger'),
 ('Bubblegum Bomb','models/bubblegum-bomb','bubblegum-bomb','bubblegum-bomb'),('Golden Bone','models/golden-bone','golden-bone','golden-bone'),
 ('Common crate','crates/common','common','crate-common'),('Rare crate','crates/rare','rare','crate-rare'),('Legendary crate','crates/legendary','legendary','crate-legendary')]
required=set();lines=['# Files for importing into the game','',
 'Everything linked here is inside `assets/shop-ui/icon-system-v1/`. The index is rebuilt from the actual files.',
 '', '## 3D models', '', '| Asset | GLB | FBX | Blender source | Texture |', '|---|---|---|---|---|']
for title,folder,stem,source in models:
 paths=[f'{folder}/{stem}.glb',f'{folder}/{stem}.fbx',f'sources/{source}.blend',f'{folder}/palette.png']
 required.update(paths);required.add(f'{folder}/manifest.json')
 lines.append('| '+title+' | '+' | '.join(f'[{label}]({path})' for label,path in zip(('GLB','FBX','Blender','PNG'),paths))+' |')
lines+=['','## UI icons','','Transparent PNGs for ImageLabels and ImageButtons. These are artwork rather than interactive UI controls.','', '| Icon | 768 px | 256 px | 128 px | 64 px | 48 px | 32 px |','|---|---|---|---|---|---|---|']
for key,title in ICONS.items():
 paths=[f'{key}.png']+[f'small/{key}-{size}.png' for size in (256,128,64,48,32)];required.update(paths);required.add(f'sources/{key}.blend')
 lines.append('| '+title+' | '+' | '.join(f'[PNG]({path})' for path in paths)+' |')
lines+=['','## Effects and previews','',
 
 '- [Supply effect helper](models/SupplyEffects.luau) and [definitions](models/SupplyDefinitions.luau).',
 '- The icon registry is src/ReplicatedStorage/Shared/ShopIcons.luau; this package no longer ships a copy.',
 '- [Review gallery](index.html) and [contact sheet](contact-sheet.png).',
 '- [Import notes](README.md); each supply model folder also contains its own README.',
 '', 'Files have been checked for presence and nonzero size. The model exports have separate geometry/round-trip validation reports.',
 'GLB/FBX files are explicitly included by the repository ignore rules. No commit or upload is performed by packaging.',
 'The approved UI icons are uploaded and connected in the shop source. Import game models separately; files in assets/ are not automatically loaded by Rojo.', '']
if uploads['icons']:required.add('roblox-uploads.json')
required.update(['models/SupplyEffects.luau','models/SupplyDefinitions.luau','index.html','contact-sheet.png','defend-rob-sheet.png','README.md'])
files=[]
for relative in sorted(required):
 path=(OUT/relative).resolve();assert path.is_relative_to(OUT.resolve()) and path.is_file() and path.stat().st_size>0,relative
 files.append({'path':relative,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT/'FILES.md').write_text('\n'.join(lines),encoding='utf-8')
(OUT/'file-audit.json').write_text(json.dumps({'models':len(models),'icons':len(ICONS),'allFilesInsideAssets':True,'files':files},indent=2))
print('ASSET_FILES_VERIFIED',len(files),'files;',len(models),'game models;',len(ICONS),'UI icons')
