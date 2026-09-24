"""Install the selected revisions locally and stage narrow, replayable Studio edits."""
import json,re
from pathlib import Path
from approved_skin_batch import ROOT,HERE,SPECS,report

SHARED=ROOT/'src/ReplicatedStorage/Shared'
runtime=json.loads((HERE/'runtime-source.json').read_text())
imports=json.loads((HERE/'imported-all.json').read_text())
og={x['key']:x for x in json.loads((HERE.parent/'og-refresh-v2/design-specs.json').read_text())['skins']}
config=(SHARED/'Config.luau').read_text()
motion=(SHARED/'ArcadeMotionData.luau').read_text()
payload={'rows':{},'packs':{},'motion':{},'patches':[],'revisions':{s['key']:s['revision'] for s in SPECS}}
def nums(v):return ', '.join(f'{x:.9g}' for x in v)
def rgb(v):return 'Color3.fromRGB('+nums(v)+')'
def vec(v):return 'Vector3.new('+nums(v)+')'
def row_range(source,table,key,multiline=True):
    start=source.index(table+' = {')
    match=re.search(r'\n\t'+re.escape(key)+r' = ',source[start:])
    if not match:return None
    a=start+match.start()+1
    # The next top-level closing brace ends this Config table.
    table_end=source.index('\n}',start)
    if a>table_end:return None
    b=source.index('\n\t},',a)+4 if multiline else source.index('\n',a)
    return a,b
def setrow(source,table,key,row,multiline=True):
    span=row_range(source,table,key,multiline)
    if span:a,b=span;return source[:a]+row+source[b:]
    at=source.index(table+' = {')+len(table+' = {')
    return source[:at]+'\n'+row+source[at:]
def put(table,key,row,multiline=True):
    global config
    config=setrow(config,table,key,row,multiline)
    payload['rows'].setdefault(table,{})[key]={'source':row,'multiline':multiline}
def pack(name,slots,strength=0):
    props={'AlphaMode':'Overlay','ColorMap':'','MetalnessMap':'','RoughnessMap':'','NormalMap':'','EmissiveMaskContent':'','EmissiveStrength':strength}
    props.update(slots)
    payload['packs'][name]=props
    (SHARED/'SurfacePacks'/f'{name}.model.json').write_text(json.dumps({'className':'SurfaceAppearance','properties':props},indent=2)+'\n')
def patch(relative,before,after):
    path=ROOT/'src'/relative
    source=path.read_text()
    if after in source:
        pass
    elif before in source:
        assert source.count(before)==1,(relative,before[:50])
        path.write_text(source.replace(before,after,1))
    else:raise AssertionError((relative,'patch target changed'))
    payload['patches'].append({'path':relative.replace('/','.'),'before':before,'after':after})

for spec in SPECS:
    key=spec['key'];r=report(spec)
    receipt=json.loads((HERE/key/'roblox-uploads.json').read_text())['assets']
    assert all(a.get('moderationState')=='Approved' for a in receipt.values()),key
    for group in ('body','trim'):
        slots={}
        for channel,prop in [('color','ColorMap'),('metal','MetalnessMap'),('rough','RoughnessMap'),('emissive','EmissiveMaskContent')]:
            if group+'_'+channel in receipt:slots[prop]='rbxassetid://'+receipt[group+'_'+channel]['assetId']
        assert slots.get('ColorMap')
        pack(key if group=='body' else key+'_trim',slots,.7 if key=='aurora' else .9 if key=='neonmint' else 0)
    a,b=row_range(config,'Config.SKINS',key)
    old=config[a:b]
    # Preserve economy fields and ordering while replacing only the visual recipe.
    fields={n:re.search(r'\b'+n+r' = ([^,\n]+)',old).group(1) for n in ('name','order','chest','rarity')}
    if key=='finalboss':fields['name']='"Spellcaster"'
    money=re.search(r'sellBasis = ([^,\n]+)',old)
    meta=', '.join(n+' = '+v for n,v in fields.items())+((', sellBasis = '+money.group(1)) if money else '')
    palette=og[key]['palette'] if key in og else {'mechaplayer':[[165,186,199],[50,202,242]],'finalboss':[[63,38,94],[184,125,236]],'jackpot':[[119,36,58],[235,209,151]]}[key]
    extras=''
    if spec['tier']=='legendary':extras=f'\n\t\taura = "arcade_{key}", glowEyes = false, parts = {{ Eye = Color3.fromRGB(27, 27, 32) }},'
    if key=='mechaplayer':extras+='\n\t\teyeForward = 0.156, groundLift = 0.63,'
    if key=='finalboss':extras+='\n\t\tgroundLift = 0.24,'
    put('Config.SKINS',key,f'\t{key} = {{\n\t\t{meta},\n\t\tbody = {rgb(palette[0])}, trim = {rgb(palette[1])},\n\t\tmaterial = Enum.Material.SmoothPlastic, transparency = 0, surface = "{key}", authoredCoat = true,{extras}\n\t}},')
    put('Config.SURFACE_PACKS',key,f'\t{key} = {{ name = {fields["name"]}, template = "{key}", trimTemplate = "{key}_trim" }},',False)
    parts=runtime[key]['parts']
    if not parts:continue
    imported={x['name']:x for x in imports[key]};assert set(imported)==set(parts)
    access=[f'\t{key} = {{'];anim=[f'\t{key} = {{']
    for name,p in parts.items():
        mesh=imported[name]
        assert max(abs(x/100-y) for x,y in zip(mesh['cf'][:3],p['center']))<.002
        assert max(abs(x/100-y) for x,y in zip(mesh['size'],p['size']))<.002
        surface=''
        if p['images']:
            texture=next(t for t in r['textures'] if Path(t['file']).name==p['images'][0])
            role=Path(texture['file']).stem if texture['role']=='shoulder_color' else texture['role']
            surface='arcade_'+key+'_'+name
            pack(surface,{'ColorMap':'rbxassetid://'+receipt[role]['assetId']})
        material='Neon' if p['emission']>.4 else 'Metal' if p['metallic']>.4 else 'SmoothPlastic'
        access.append(f'\t\t{{ part = "{name}", id = "{mesh["id"]}", offset = {vec(p["center"])}, size = {vec(p["size"])}, colour = {rgb([255,255,255] if surface else p["color"])}, material = Enum.Material.{material}'+(f', surfaceTemplate = "{surface}"' if surface else '')+' },')
        if p['samples']:
            anim.append(f'\t\t["{name}"] = {{')
            anim.extend('\t\t\t{'+nums(sample)+'},' for sample in p['samples'])
            anim.append('\t\t},')
    access.append('\t},');anim.append('\t},')
    put('Config.SKIN_ACCESSORIES',key,'\n'.join(access))
    put('Config.SKIN_ACCESSORY_MODELS',key,f'\t{key} = "{receipt["accessories"]["assetId"]}",',False)
    if spec['tier']=='legendary':
        row='\n'.join(anim);payload['motion'][key]=row
        # MotionData has an anonymous return table.
        motion=setrow(motion.replace('return {','Motion = {',1),'Motion',key,row).replace('Motion = {','return {',1)

# Spellcaster's former boss aura follows the approved purple and gold palette.
a,b=row_range(config,'Config.SKIN_AURAS','arcade_finalboss')
aura=config[a:b]
aura=re.sub(r'name = "[^"]+"','name = "Spellcaster Sparks"',aura)
aura=re.sub(r'color = ColorSequence.new\([^\n]+', 'color = ColorSequence.new(Color3.fromRGB(182, 125, 242), Color3.fromRGB(239, 200, 106)),',aura)
put('Config.SKIN_AURAS','arcade_finalboss',aura)
(SHARED/'Config.luau').write_text(config)
(SHARED/'ArcadeMotionData.luau').write_text(motion)

pm='ReplicatedStorage/Shared/PiggyModel.luau'
patch(pm,'\tsa.Parent = part\n\tif tier.spectral == true then','\tsa.Parent = part\n\tif tier.authoredCoat == true then part.Color = Color3.new(1, 1, 1) end\n\tif tier.spectral == true then')
patch(pm,'\tSpectralFX.attach(model, body, key)\n\tlocal worn', '''\tSpectralFX.attach(model, body, key)
\t-- Reseat the Mecha eyes against its face plate; undo this on skin change.
\tlocal visual = key and Config.getSkin(key)
\tlocal eyeForward = visual and visual.eyeForward or 0
\tfor _, eye in ipairs(model:GetChildren()) do
\t\tif eye:IsA("BasePart") and eye.Name == "Eye" then
\t\t\tlocal delta = eyeForward - (eye:GetAttribute("SkinEyeForward") or 0)
\t\t\tif delta ~= 0 then
\t\t\t\tlocal welds = {}
\t\t\t\tfor _, w in ipairs(eye:GetChildren()) do
\t\t\t\t\tif w:IsA("WeldConstraint") and w.Enabled then w.Enabled = false; table.insert(welds, w) end
\t\t\t\tend
\t\t\t\teye.CFrame += body.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -delta * bodyScale(body)))
\t\t\t\tfor _, w in ipairs(welds) do w.Enabled = true end
\t\t\tend
\t\t\teye:SetAttribute("SkinEyeForward", eyeForward)
\t\tend
\tend
\tlocal worn''')
patch(pm,'\t\t\tmesh.WorldPivot = CFrame.new(MINI_CENTRE)\n\t\t\treturn mesh', '''\t\t\t-- Thicker approved boots keep the original sole clearance on displays.
\t\t\tlocal lift = (skin.groundLift or 0) * bodyScale(body)
\t\t\tif lift ~= 0 then mesh:PivotTo(mesh:GetPivot() + Vector3.new(0, lift, 0)) end
\t\t\tmesh.WorldPivot = CFrame.new(MINI_CENTRE)
\t\t\treturn mesh''')
bank='ServerScriptService/Services/PiggyBank.luau'
patch(bank,'\tlocal tier = Config.getSkin(skinKey)\n', '''\tlocal tier = Config.getSkin(skinKey)
\t-- Preserve sole clearance for the approved full boots, including skin changes.
\tlocal lift = tier.groundLift or 0
\tlocal liftDelta = lift - (refs.model:GetAttribute("SkinGroundLift") or 0)
\tif liftDelta ~= 0 then
\t\tlocal offset = Vector3.new(0, liftDelta, 0)
\t\trefs.model:PivotTo(refs.model:GetPivot() + offset)
\t\trefs.origin += offset
\tend
\trefs.model:SetAttribute("SkinGroundLift", lift)
''')
anim='ReplicatedStorage/Shared/ArcadeAnimator.luau'
patch(anim,'jackpot = true, finalboss = true, mechaplayer = true }','jackpot = true, finalboss = true, mechaplayer = true, aurora = true, neonmint = true }')
patch(anim,'sets[marker] = { body = body, parts = parts, surfaces = surfaces }','sets[marker] = { body = body, parts = parts, surfaces = surfaces, key = key }')
patch(anim,'local pulse = 0.88 + 0.12 * math.cos(t * math.pi / 3)', '''local pulse = if set.key == "aurora" or set.key == "neonmint"
\t\t\t\tthen 1.015 - .155 * math.cos(t * math.pi * 2 / 3)
\t\t\t\telse 0.88 + 0.12 * math.cos(t * math.pi / 3)''')
(HERE/'studio-sync.json').write_text(json.dumps(payload)+'\n')
print('Staged eight revisions,',len(payload['packs']),'surface templates and',sum(len(x['parts']) for x in runtime.values()),'accessory meshes.')
