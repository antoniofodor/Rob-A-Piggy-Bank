"""Write import helpers, readable handoffs and a gallery for verified shells."""
import json,html
from pathlib import Path
from walkin_catalogue import SPECS,folder
from house_paths import house_slug
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'assets/houses'

PREPARE='''-- Select ONLY the newly imported FBX model in Studio, then run this file
-- in the Command Bar. It validates before editing; use Undo to reverse it.
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local data = HttpService:JSONDecode([==[__DATA__]==])
local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select one freshly imported house model")
local model = selected[1]
assert(not model:FindFirstChild("HouseDoorHinge_L", true), "This model is already prepared")
local meshes = {}
local lo, hi = Vector3.new(math.huge,math.huge,math.huge), Vector3.new(-math.huge,-math.huge,-math.huge)
for _, part in model:GetDescendants() do
    if part:IsA("MeshPart") then
        local name = part.Name
        local row = data.meshes[name] or data.meshes[name:match("^[^.]+")]
        assert(row, "Mesh not in this house's manifest: "..name)
        assert((part.Size-part.MeshSize).Magnitude < 0.05, "Use a fresh, unscaled import")
        local _,_,_,r00,r01,r02,r10,r11,r12,r20,r21,r22 = part.CFrame:GetComponents()
        assert(math.abs(r00-1)+math.abs(r11-1)+math.abs(r22-1)+math.abs(r01)+math.abs(r02)+math.abs(r10)+math.abs(r12)+math.abs(r20)+math.abs(r21)<0.001, "Use an unrotated import")
        lo=lo:Min(part.Position-part.Size/2);hi=hi:Max(part.Position+part.Size/2)
        table.insert(meshes,{part=part,row=row})
    end
end
assert(#meshes == data.meshCount, "Select the complete exported model")
local b = data.bounds
local expected = Vector3.new(b.size[1],b.size[3],b.size[2])
local actual = hi-lo
local ratios = {actual.X/expected.X,actual.Y/expected.Y,actual.Z/expected.Z}
assert(math.max(table.unpack(ratios))-math.min(table.unpack(ratios))<0.05,"Import scale differs between axes")
local scale = 3/(ratios[1]+ratios[2]+ratios[3])
local origin = Vector3.new(-b.max[1],b.min[3],b.min[2])
local function fromBlender(v) return Vector3.new(-v[1],v[3],v[2]) end
local record = ChangeHistoryService:TryBeginRecording("PrepareWalkInHouse")
assert(record, "Studio cannot record this edit right now; stop Play and retry")
for _, item in meshes do
    local p,row=item.part,item.row
    p.CFrame=CFrame.new((p.Position-lo)*scale+origin)
    p.Size*=scale
    p.Color=Color3.fromRGB(table.unpack(row.colorRGB))
    p.Material=Enum.Material.SmoothPlastic
    p.Transparency=row.transparency
    p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
end
for i, box in data.collisions do
    local p=Instance.new("Part");p.Name="Collide_"..box.name
    p.Size=Vector3.new(box.sizeXYZ[1],box.sizeXYZ[3],box.sizeXYZ[2])
    -- +rotationZ, never -: see the note in build_house_runtime.py. The
    -- Blender-to-Roblox map is two reflections and therefore keeps the
    -- rotation's sense; negating it is a quarter turn on the diagonals.
    p.CFrame=CFrame.new(fromBlender(box.blenderLocation))*CFrame.Angles(0,(box.rotationZ or 0),0)
    p.Transparency=1;p.Anchored=true;p.CanCollide=true;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=model
end
for _, door in data.doors do
    local side=door.name:sub(-1)
    local p=Instance.new("Part");p.Name="HouseDoorHinge_"..side
    p.Size=Vector3.new(.15,.15,.15);p.CFrame=CFrame.new(fromBlender(door.hingeBlender))
    p.Transparency=1;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
    local angle=Instance.new("NumberValue");angle.Name="OpenDegrees";angle.Value=-door.openDegrees;angle.Parent=p;p.Parent=model
end
for name, position in data.mounts do
    local p=Instance.new("Part");p.Name="Mount_"..name
    p.Size=Vector3.new(.2,.2,.2)
    p.CFrame=CFrame.new(fromBlender(position))*CFrame.Angles(0,-math.rad(data.mountYaws[name] or 0),0)
    p.Transparency=1;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=model
end
model.Name=data.name.."_WalkIn"
ChangeHistoryService:FinishRecording(record,Enum.FinishRecordingOperation.Commit)
print("Prepared "..model.Name..": scale, flat colours, transparency, collision and automatic door pivots. Place it in Workspace to playtest. Runtime catalogue integration still needs its imported mesh IDs.")
'''

def main():
    cards=[];inventory=[]
    for slug,(rev,_,_) in SPECS.items():
        out=BASE/folder(slug,rev+1);stem=house_slug(slug)
        geo=json.loads((out/'geometry-report.json').read_text())
        imp=json.loads((out/'roblox-import-report.json').read_text())
        door_file=out/'door-handoff.json'
        door_data=json.loads(door_file.read_text())
        door_data['runtime']='HouseDoorAnimator.client.luau; prepare-in-studio.luau or build_house_runtime.py creates the pivot markers'
        door_file.write_text(json.dumps(door_data,indent=2))
        assert not geo['walkIn']['blocked'] and imp['fbxRoundTripMaxBoundsError']<.001,slug
        overrides=json.loads((out/'material-overrides.json').read_text()) if (out/'material-overrides.json').exists() else {}
        meshes={m['name']:{'colorRGB':m['colorRGB'],'transparency':overrides.get(m['material'],{}).get('RobloxTransparency',0)} for m in imp['meshes']}
        data={'name':stem,'bounds':geo['boundsBlender'],'meshCount':imp['meshCount'],'meshes':meshes,'collisions':geo['collisionBoxesDraft'],'doors':geo['walkIn']['doors'],'mounts':geo['mountsBlender'],'mountYaws':geo.get('mountYawBlender',{})}
        (out/'prepare-in-studio.luau').write_text(PREPARE.replace('__DATA__',json.dumps(data)),encoding='utf-8')
        x0,x1,y0,y1,f,c=geo['walkIn']['roomBounds'];name=stem.replace('-',' ').title()
        fish='\nFishbowl: outer dome transparency **0.82**, bubbles **0.62**. The inner living pod is opaque; the dry entrance passes through an actual opening in the dome. The import helper applies these values automatically.\n' if slug=='modern' else ''
        (out/'README.md').write_text(f'''# {name} — empty walk-in revision {rev+1}

[Exterior preview](exterior.png) · [Inside](interior.png) · [Entrance](entry.png) · [All walk-in houses](../walk-in.html)

The main floor is accessible through a real opening. Bare walls, floor and ceiling; no furniture, trophies, rugs or interior decorations. Existing exterior details are retained. Upper exterior storeys are not additional accessible floors in this revision.

## Import into Studio

1. Import **[{stem}-roblox.fbx]({stem}-roblox.fbx)** as one model, without rotating or resizing it.
2. **Before preparing or resizing**, record the fresh mesh IDs with [dump_house_import.luau](../tools/dump_house_import.luau), setting `MODEL` to the imported model's name. Save the returned text to `dump.txt`, then run `python assets/houses/tools/record_house_import.py {slug} {rev+1} dump.txt`. Earlier `studio-import.json` files refer to different geometry and must not be reused. The recorder needs the original unscaled import.
3. For a standalone walk-through, select the imported model and run [prepare-in-studio.luau](prepare-in-studio.luau) in the Studio Command Bar while stopped. It sets stud scale, flat colors, transparency, separate collision boxes, display mounts and door hinges. It moves the prepared house to its authored origin; move the whole model to the desired location afterward. The operation supports Undo.
4. Put the model in Workspace and Play with Rojo connected. `HouseDoorAnimator.client.luau` opens the separate doors as any player approaches and holds them open until everyone has passed. Door leaves never collide and cannot trap players.
5. To replace the live catalogue template after recording the fresh IDs, run `python assets/houses/tools/build_house_runtime.py {slug} {rev+1}`. This generates the template with collision, display mounts, glass properties and hinges directly from the authored report; the standalone helper is not required for that route.

The FBX alone does not install the companion collision or Roblox material properties. The helper above applies them; do not enable collision on the visual meshes, since a convex hull would seal the room again.
{fish}
## Files and checks

- [{stem}.blend]({stem}.blend): editable source, doors in closed reference pose.
- `{stem}-visual.obj` / `.mtl`: grouped exchange source.
- `{stem}-collision-mounts.rbxmx`: collision companion in Blender-to-Roblox axes; the Studio helper also creates the doors' pivot markers.
- `geometry-report.json`: {geo['walkIn']['probes']} avatar-body samples, room and doorway dimensions, collision boxes, door pivots.
- `roblox-import-report.json`: {imp['meshCount']} material-split meshes, {imp['triangles']:,} triangles; FBX round-trip maximum bounds error {imp['fbxRoundTripMaxBoundsError']:.8f} studs.
- `door-handoff.json`: 100° outward swing, 10-stud proximity, 0.35-second transition and 1.5-second hold.

Room clear rectangle: **{x1-x0:.1f} × {y1-y0:.1f} studs**, floor-to-ceiling **{c-f:.1f} studs**. Floor at Z={f:.2f} in Blender. Your approved exterior resize ({geo['walkIn']['bakedExteriorScale']:.2f}×) is baked into this source; the runtime display multiplier is **1.0**. `Mount_Wall` and its 180° facing mark the empty display wall without adding any decoration. Static mesh topology and sampled clearance pass. Live avatar/camera, eight-player/mobile performance, door sweep and plot/fence clearance still require Studio playtesting. These files have not uploaded new mesh IDs or replaced existing live templates.

## Rebuild

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 3 --python-exit-code 1 --python assets/houses/tools/build_walkin.py -- {slug}
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 3 --python-exit-code 1 --python assets/houses/tools/export_house_roblox.py -- {slug} {rev+1}
python assets/houses/tools/build_walkin_handoff.py
```

Previous art is preserved in [{folder(slug,rev)}](../{folder(slug,rev)}/README.md). Stable game ID remains `{slug}`. Gingerbread is seasonal and outside this permanent-house pass.
''',encoding='utf-8')
        card=f'<article><h2>{html.escape(name)}</h2><a href="{out.name}/README.md"><img src="{out.name}/exterior.png" alt="{name} walk-in exterior"></a><div class="pair"><img src="{out.name}/entry.png" alt="{name} doorway"><img src="{out.name}/interior.png" alt="{name} bare room"></div><p>{x1-x0:.1f} × {y1-y0:.1f} room · {c-f:.1f} headroom</p><a href="{out.name}/README.md">Import notes</a> · <a href="{out.name}/{stem}-roblox.fbx">Roblox FBX</a></article>'
        cards.append(card);inventory.append({'id':slug,'folder':out.name,'revision':rev+1,'name':name,'fbx':f'{out.name}/{stem}-roblox.fbx','blend':f'{out.name}/{stem}.blend','walkIn':True,'studioIntegration':'pending new mesh import','clearanceSamples':geo['walkIn']['probes']})
    page='<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Walk-in house library</title><style>body{background:#f6efdF;color:#302b25;font:16px/1.5 system-ui;margin:24px}main{max-width:1440px;margin:auto}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:20px}article{background:#fff9ef;padding:18px;border:1px solid #dcccb7;border-radius:16px}img{width:100%;display:block;border-radius:8px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px}h2{font-size:21px}a{color:#365c63}</style><main><h1>18 empty, walk-in houses</h1><p>Real entrances, bare interior shells and separate floor/wall collision. Automatic non-blocking swing doors. New Blender revisions and Roblox exports; fresh Studio imports and playtests are still required.</p><p><a href="README.md">Asset index</a></p><div class="grid">'+''.join(cards)+'</div></main></html>'
    (BASE/'walk-in.html').write_text(page,encoding='utf-8')
    (BASE/'index.html').write_text(page,encoding='utf-8')
    (BASE/'walk-in-manifest.json').write_text(json.dumps({'count':len(inventory),'models':inventory},indent=2))
    print('Prepared 18 model handoffs, Studio helpers and the walk-in gallery.')
if __name__=='__main__':main()
