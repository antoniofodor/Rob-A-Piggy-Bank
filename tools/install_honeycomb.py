"""Install current Honeycomb maps and a replaceable three-piece honey tail."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
HOME=ROOT/'assets/piggies/rare/honeycomb'
OUT=HOME/'revisions/hexagonal-installed'
SHARED=ROOT/'src/ReplicatedStorage/Shared'
assets=json.loads((OUT/'roblox-uploads.json').read_text())['assets']
assert all(a['moderationState']=='Approved' for a in assets.values())
payload={'rows':{},'packs':{},'motion':{},'patches':[]}
config=(SHARED/'Config.luau').read_text()
def put(table,key,row,multiline=True):
 global config
 start=config.index(table+' = {');end=config.index('\n}',start)
 m=re.search(r'\n\t'+re.escape(key)+r' = ',config[start:end])
 if m:
  a=start+m.start()+1;b=config.index('\n\t},',a)+4 if multiline else config.index('\n',a)
  config=config[:a]+row+config[b:]
 else:
  at=start+len(table+' = {');config=config[:at]+'\n'+row+config[at:]
 payload['rows'].setdefault(table,{})[key]={'source':row,'multiline':multiline}
def patch(file,before,after):
 p=ROOT/'src'/file;s=p.read_text()
 if after not in s:
  assert s.count(before)==1,(file,before[:60]);p.write_text(s.replace(before,after,1))
 payload['patches'].append(dict(path=file.replace('/','.'),before=before,after=after))
for group in ('body','trim'):
 name='honeycomb'+('_trim' if group=='trim' else '')
 p=SHARED/'SurfacePacks'/f'{name}.model.json';d=json.loads(p.read_text())
 props=d['properties'];props['ColorMap']='rbxassetid://'+assets[group+'_color']['assetId']
 props['EmissiveStrength']=0;props['EmissiveMaskContent']=''
 p.write_text(json.dumps(d,indent=2)+'\n');payload['packs'][name]=props
start=config.index('\thoneycomb = {',config.index('Config.SKINS = {'));end=config.index('\n\t},',start)+4
row=config[start:end]
if 'authoredCoat = true' not in row:row=row.replace('surface = "honeycomb",','surface = "honeycomb", authoredCoat = true,')
put('Config.SKINS','honeycomb',row)
put('Config.SKIN_ACCESSORY_MODELS','honeycomb','\thoneycomb = "'+assets['accessories']['assetId']+'",',False)
rows=['\thoneycomb = {']
colors={'HoneyTrim':[255,255,255],'Tail':[239,145,22],'HoneyDrop':[255,199,88],'HoneyDropHighlight':[255,248,226]}
report=json.loads((OUT/'accessories-report.json').read_text())
def vec(v):return 'Vector3.new('+', '.join(f'{x:.9g}' for x in v)+')'
for p in json.loads((OUT/'imported-parts.json').read_text()):
 name=p['name'];offset=[v/100 for v in p['cf'][:3]];size=[v/100 for v in p['size']]
 assert max(abs(a-b) for a,b in zip(offset,report[name]['center']))<.002
 assert max(abs(a-b) for a,b in zip(size,report[name]['size']))<.002
 material='Glass' if name=='HoneyDrop' else 'SmoothPlastic'
 extra=', transparency = 0.22' if name=='HoneyDrop' else ', replaces = "Trim", surfaceTemplate = "honeycomb_trim"' if name=='HoneyTrim' else ''
 rows.append(f'\t\t{{ part = "{name}", id = "{p["id"]}", offset = {vec(offset)}, size = {vec(size)}, colour = Color3.fromRGB('+', '.join(map(str,colors[name]))+f'), material = Enum.Material.{material}{extra} }},')
rows.append('\t},');put('Config.SKIN_ACCESSORIES','honeycomb','\n'.join(rows))
(SHARED/'Config.luau').write_text(config)
file='ReplicatedStorage/Shared/PiggyModel.luau'
patch(file,'\t\t\tmesh.Transparency = 0','\t\t\tmesh.Transparency = entry.transparency or 0')
before='function PiggyModel.applyAccessories(model: Instance, body: BasePart, key: string?, anchored: boolean)\n\tSpectralFX.attach(model, body, key)'
after='''function PiggyModel.applyAccessories(model: Instance, body: BasePart, key: string?, anchored: boolean)
	-- Restore any base piece hidden by the previous accessory set.
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			local previous = part:GetAttribute("AccessoryHiddenFrom")
			if type(previous) == "number" then
				-- applySkin may already have assigned the next coat's alpha.
				if part.Transparency == 1 then part.Transparency = previous end
				part:SetAttribute("AccessoryHiddenFrom", nil)
			end
		end
	end
	SpectralFX.attach(model, body, key)'''
patch(file,before,after)
before='\t\t\tpart.Size = entry.size * s\n\t\t\t-- SEATED OFF THE BODY'
after='''			part.Size = entry.size * s
			if entry.replaces then
				local base = model:FindFirstChild(entry.replaces)
				if base and base:IsA("BasePart") then
					base:SetAttribute("AccessoryHiddenFrom", base.Transparency)
					base.Transparency = 1
				end
			end
			-- SEATED OFF THE BODY'''
patch(file,before,after)
p=SHARED/'ShopSkinCards.luau';s=p.read_text();old=re.search(r'\thoneycomb = "[^"]+",',s).group()
new='\thoneycomb = "rbxassetid://'+assets['shop_card']['assetId']+'",'
patch('ReplicatedStorage/Shared/ShopSkinCards.luau',old,new)
(OUT/'studio-sync.json').write_text(json.dumps(payload))
print('Staged Honeycomb coat, translucent drop, replacement tail and shop card.')
