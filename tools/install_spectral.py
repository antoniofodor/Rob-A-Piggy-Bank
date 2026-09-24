"""Install only the approved Ghost/Hologram maps and stage scoped Studio patches."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1];SHARED=ROOT/'src/ReplicatedStorage/Shared';HERE=ROOT/'assets/piggies/og-refresh-v2'
packs={}
for key in ('ghost','hologram'):
    home=ROOT/'assets/piggies/epic'/key/'revisions/og-v2'
    receipt=json.loads((home/'roblox-uploads.json').read_text())
    assert all(a.get('moderationState')=='Approved' for a in receipt['assets'].values()),key+' still moderating'
    for group in ('body','trim'):
        a=receipt['assets'];name=key if group=='body' else key+'_trim'
        properties={'AlphaMode':'Transparency','ColorMap':'rbxassetid://'+a[group+'_rgba']['assetId'],'MetalnessMap':'','NormalMap':'','RoughnessMap':'rbxassetid://'+a[group+'_rough']['assetId'],'EmissiveMaskContent':'rbxassetid://'+a[group+'_emissive']['assetId'],'EmissiveStrength':.6 if key=='ghost' else 1.1}
        pack={'className':'SurfaceAppearance','properties':properties};packs[name]=properties
        (SHARED/'SurfacePacks'/f'{name}.model.json').write_text(json.dumps(pack,indent=2)+'\n')
config=(SHARED/'Config.luau').read_text();skins={}
for key,nextmarker in [('ghost','\n\tcharcoal = {'),('hologram','\n\t-- THE STRIPED')]:
    a=config.index('\t'+key+' = {',config.index('Config.SKINS = {'));b=config.index(nextmarker,a);skins[key]=config[a:b]
a=config.index('\twisp = {',config.index('Config.SKIN_AURAS = {'));b=config.index('\n\t},',a)+len('\n\t},')
payload={'packs':packs,'skins':skins,'wisp':config[a:b],'modules':{name:(SHARED/(name+'.luau')).read_text() for name in ('SpectralScanData','SpectralFX')}}
(HERE/'studio-sync.json').write_text(json.dumps(payload)+'\n')
print('Installed 4 alpha/emissive SurfacePacks; staged only the spectral runtime changes.')
