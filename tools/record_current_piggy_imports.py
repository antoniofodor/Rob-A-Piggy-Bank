"""Record verified active revisions without replacing historical source records."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT/'assets/piggies'
def save(p,d):p.write_text(json.dumps(d,indent=2)+'\n')
revs={'mechaplayer':'arcade-v4','finalboss':'spellcaster-v5','jackpot':'jackpot-v3'}
save(BASE/'arcade-build-v1/active-revisions.json',revs)
for key,rev in revs.items():
 gallery={'mechaplayer':'arcade-mecha-v4','finalboss':'arcade-spellcaster-v5','jackpot':'arcade-jackpot-v3'}[key]
 for path in (BASE/gallery/'manifest.json',BASE/'legendary'/key/'manifest.json'):
  d=json.loads(path.read_text());d.update(status='Installed in project and Roblox Studio',installedRevision=rev,runtimeInstalled=True,publishedLive=False,robloxUploads=f'assets/piggies/approved-imports-20260923/{key}/roblox-uploads.json')
  if key=='finalboss':d['name']='Spellcaster'
  save(path,d)
p=BASE/'og-refresh-v2/manifest.json';d=json.loads(p.read_text());d['status']='All seven revisions installed in project and Roblox Studio';d['runtimeEffectsRequireIntegration']=[]
for row in d['skins']:row['runtimeInstalled']=True
save(p,d)
home=BASE/'rare/honeycomb';receipt=json.loads((home/'revisions/hexagonal-installed/roblox-uploads.json').read_text())
p=home/'manifest.json';d=json.loads(p.read_text());d.update(status='Installed in project and Roblox Studio',installedRevision='hexagonal-honeycomb',runtimeInstalled=True,publishedLive=False,robloxUploads='revisions/hexagonal-installed/roblox-uploads.json')
d['authoringRevision']['status']='Installed: current maps, honey-drop tail assembly and shop card'
d['derivedPackage']['note']='Current hexagonal coat and replacement trim assembly are installed in Roblox Studio.'
d['shopCard'].update(status='Installed',robloxAssetId='rbxassetid://'+receipt['assets']['shop_card']['assetId'])
for group in ('body','trim'):
 a=receipt['assets'][group+'_color'];aid='rbxassetid://'+a['assetId'];d['templates'][group]['ids']['ColorMap']=aid
 d['idSources'][aid]={'file':f'sheets/honeycomb_{group}_color.png','sha256':a['sha256'],'status':'Approved and installed','role':group+' ColorMap'}
d['closedBack']['note']='Current hexagonal body/trim maps installed; closed-back geometry retained.'
save(p,d)
p=BASE/'legendary/rainbowtiger/manifest.json';d=json.loads(p.read_text());d.update(installedRevision='tail-tip-v2',runtimeInstalled=True,status='Installed: no cheek/chin beard, plume rooted at tail tip',publishedLive=False,revisionReport='revisions/tail-tip-v2/revision.json');save(p,d)
save(BASE/'approved-imports-20260923/import-status.json',{'studioInstalled':True,'publishedLive':False,'verified':['aurora','banker','rockslide','quartz','neonmint','ghost','hologram','mechaplayer','finalboss','jackpot','rainbowtiger','honeycomb'],'textureAudit':'All Studio SurfacePacks matched project. Source-hash audit found Honeycomb stale; replaced its two maps and tail/trim assembly.','build':'Rojo build passed','testSuite':'Piggies suite blocked by existing source-location assertion: MINI_NAMES moved to Shared/SkinAnimator but test still searches old client source.','runtimeTests':'Honeycomb mini/full-size appearance, scale, replacement trim and skin-switch cleanup; previous eight imports and Rainbow Tiger configuration verified.'})
print('Recorded current active revisions and Honeycomb installation.')
