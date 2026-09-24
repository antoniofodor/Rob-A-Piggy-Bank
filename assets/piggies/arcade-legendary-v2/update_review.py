from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[3];old=root/'assets/piggies/arcade-build-v1';here=Path(__file__).resolve().parent
p=old/'manifest.json';data=json.loads(p.read_text());summaries={
'mechaplayer':'Rebuilt with layered navy shoulder guards, fitted steel shell panels, chunky three-piece boots, raised cyan vents, recessed turbine thrusters, navy ear rims and a clean pale face. Black eyes match the reference; the hardware supplies the glow.',
'finalboss':'Broad brass-edged pauldrons, large pink energy gems, fitted plum shell plates with raised luminous seams, armored hips and mounted rear crystals. Black eyes and exposed pink face match the reference.',
'jackpot':'A fuller arched reel housing with side lamps, raised gold rails, rivets, a rear shield and a fitted saddle. The original three reels and floating tokens retain their animation.'}
revised=[]
for key in ('mechaplayer','finalboss','jackpot'):
 r=next(s for s in data['skins'] if s['key']==key);home=old.parent/'legendary'/key;report=json.loads((home/'package/arcade-v2/asset-report.json').read_text())
 r['previous']=f'../legendary/{key}/preview/{key}-arcade-v1-hero.png';r['design']=summaries[key];r['revision']='arcade-legendary-v2'
 for v in ('hero','back','motion'):r[v]=f'../legendary/{key}/preview/arcade-v2/{key}-v2-{v}.png'
 r['blend']=f'../legendary/{key}/package/arcade-v2/{key}-arcade-v2.blend';r['fbx']=f'../legendary/{key}/package/arcade-v2/{key}-arcade-v2-complete.fbx'
 r['addedTriangles']=sum(x['triangles'] for x in report['parts'] if x['role']=='accessory');r['accessoryParts']=len([x for x in report['parts'] if x['role']=='accessory'])
 if key=='mechaplayer':r['maps']=2
 revised.append(r)
p.write_text(json.dumps(data,indent=2)+'\n')
page=(old/'index.html').read_text(encoding='utf-8')
start=page.index('const rows=')+len('const rows=');end=page.index(';let mode=',start);page=page[:start]+json.dumps(data['skins'])+page[end:]
page=page.replace('${r.prefix}/package/${r.key}-arcade-v1.blend',"${r.blend || r.prefix+'/package/'+r.key+'-arcade-v1.blend'}").replace('${r.prefix}/package/${r.key}-arcade-v1-complete.fbx',"${r.fbx || r.prefix+'/package/'+r.key+'-arcade-v1-complete.fbx'}")
page=page.replace('Local Blender assets complete. Roblox installation pending. Animation lives in Blender; FBXs are static. Aura motes are preview proxies.','Imported into Studio. Legendaries received a second geometry pass; FBXs are static and the game runs the authored animation.')
page=page.replace('Ten piggies, including six new Arcade designs.','Ten Arcade piggies. The three legendaries now have expanded 3D armor and hardware. <a href="../arcade-legendary-v2/index.html">Compare the Legendary revision</a>.')
(old/'index.html').write_text(page,encoding='utf-8')
start=page.index('const rows=')+len('const rows=');end=page.index(';let mode=',start);page=page[:start]+json.dumps(revised)+page[end:]
page=page.replace('Player One has entered.','Legendary geometry, second pass.').replace('Arcade Piggies · Expanded Collection','Arcade Legendaries · Geometry v2')
page=page.replace('<button data-view="motion">Animation pose</button>','<button data-view="motion">Animation pose</button><button data-view="previous">Previous build</button>')
page=page.replace('<a href="arcade-collection-v2.blend">Open the complete Blender collection</a>','<a href="../arcade-build-v1/index.html">Back to the full Arcade collection</a>')
(here/'index.html').write_text(page,encoding='utf-8')
(here/'manifest.json').write_text(json.dumps({'revision':'arcade-legendary-v2','skins':revised},indent=2)+'\n')
print('Updated reference/front/rear/before comparisons for all three legendaries.')
