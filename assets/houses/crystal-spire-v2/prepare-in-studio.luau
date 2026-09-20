-- Select ONLY the newly imported FBX model in Studio, then run this file
-- in the Command Bar. It validates before editing; use Undo to reverse it.
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local data = HttpService:JSONDecode([==[{"name": "crystal-spire", "bounds": {"min": [-18.55572509765625, -5.796999931335449, -0.020000040531158447], "max": [18.44499969482422, 32.39500045776367, 69.75], "size": [37.00072479248047, 38.19200038909912, 69.77000004053116]}, "meshCount": 47, "meshes": {"RockShell_RockLight": {"colorRGB": [98, 95, 111], "transparency": 0}, "Crystals_VioletLight": {"colorRGB": [144, 63, 219], "transparency": 0}, "HouseFX_CrystalAccent_1_Glow": {"colorRGB": [143, 49, 229], "transparency": 0}, "HouseFX_CrystalAccent_2_Glow": {"colorRGB": [143, 49, 229], "transparency": 0}, "HouseFX_CrystalAccent_3_Glow": {"colorRGB": [143, 49, 229], "transparency": 0}, "Entry_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "Windows_VioletDeep": {"colorRGB": [68, 24, 130], "transparency": 0}, "RockShell_Rock": {"colorRGB": [76, 74, 88], "transparency": 0}, "RockShell_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "RockShell_RockShade": {"colorRGB": [53, 52, 66], "transparency": 0}, "Crystals_Violet": {"colorRGB": [110, 43, 190], "transparency": 0}, "Crystals_VioletDeep": {"colorRGB": [68, 24, 130], "transparency": 0}, "Entry_RockShade": {"colorRGB": [53, 52, 66], "transparency": 0}, "Entry_Frame": {"colorRGB": [88, 73, 104], "transparency": 0}, "Entry_Stone": {"colorRGB": [137, 129, 144], "transparency": 0}, "Windows_Ink": {"colorRGB": [30, 25, 37], "transparency": 0}, "Windows_Frame": {"colorRGB": [88, 73, 104], "transparency": 0}, "Windows_Amber": {"colorRGB": [255, 182, 66], "transparency": 0}, "Windows_RockShade": {"colorRGB": [53, 52, 66], "transparency": 0}, "Foundation_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "WalkFloor_WalkFloor": {"colorRGB": [108, 92, 122], "transparency": 0}, "WalkCeiling_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "WalkSideLeftWall_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "WalkSideRightWall_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "WalkRearWall_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "WalkFrontLeft_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "WalkFrontRight_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "WalkLintel_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "WalkPassageLeft_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "WalkPassageRight_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "WalkPassageCeiling_WalkWall": {"colorRGB": [144, 126, 162], "transparency": 0}, "WalkPassageFloor_WalkFloor": {"colorRGB": [108, 92, 122], "transparency": 0}, "WalkApproach0_WalkFloor": {"colorRGB": [108, 92, 122], "transparency": 0}, "WalkApproach1_WalkFloor": {"colorRGB": [108, 92, 122], "transparency": 0}, "WalkApproach2_WalkFloor": {"colorRGB": [108, 92, 122], "transparency": 0}, "WalkApproach3_WalkFloor": {"colorRGB": [108, 92, 122], "transparency": 0}, "WalkApproach4_WalkFloor": {"colorRGB": [108, 92, 122], "transparency": 0}, "HouseDoorLeaf_L_WalkDoor": {"colorRGB": [84, 49, 106], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim": {"colorRGB": [94, 55, 119], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim.001": {"colorRGB": [94, 55, 119], "transparency": 0}, "HouseDoorLeaf_R_WalkDoor": {"colorRGB": [84, 49, 106], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim": {"colorRGB": [94, 55, 119], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim.001": {"colorRGB": [94, 55, 119], "transparency": 0}, "WalkEntryJamb-1_WalkTrim": {"colorRGB": [94, 55, 119], "transparency": 0}, "WalkEntryJamb1_WalkTrim": {"colorRGB": [94, 55, 119], "transparency": 0}, "WalkEntryHeader_WalkTrim": {"colorRGB": [94, 55, 119], "transparency": 0}, "Foundation_RockShade": {"colorRGB": [53, 52, 66], "transparency": 0}}, "collisions": [{"name": "WalkFloor", "blenderLocation": [1.3949999809265137, 13.2524995803833, 1.4874999523162842], "sizeXYZ": [18.56999969482422, 17.174999237060547, 0.2800000011920929]}, {"name": "WalkCeiling", "blenderLocation": [1.3949999809265137, 13.2524995803833, 13.699999809265137], "sizeXYZ": [18.56999969482422, 17.174999237060547, 0.11999999731779099]}, {"name": "WalkSideLeftWall", "blenderLocation": [-7.809999942779541, 13.2524995803833, 7.633749961853027], "sizeXYZ": [0.11999999731779099, 16.895000457763672, 12.012499809265137]}, {"name": "WalkSideRightWall", "blenderLocation": [10.600000381469727, 13.2524995803833, 7.633749961853027], "sizeXYZ": [0.11999999731779099, 16.895000457763672, 12.012499809265137]}, {"name": "WalkRearWall", "blenderLocation": [1.3949999809265137, 21.760000228881836, 7.633749961853027], "sizeXYZ": [18.290000915527344, 0.11999999731779099, 12.012499809265137]}, {"name": "WalkFrontLeft", "blenderLocation": [-3.797499895095825, 4.744999885559082, 7.633749961853027], "sizeXYZ": [7.90500020980835, 0.11999999731779099, 12.012499809265137]}, {"name": "WalkFrontRight", "blenderLocation": [9.842499732971191, 4.744999885559082, 7.633749961853027], "sizeXYZ": [1.3949999809265137, 0.11999999731779099, 12.012499809265137]}, {"name": "WalkLintel", "blenderLocation": [4.650000095367432, 4.744999885559082, 13.329999923706055], "sizeXYZ": [8.989999771118164, 0.11999999731779099, 0.6200000047683716]}, {"name": "WalkPassageLeft", "blenderLocation": [0.054999999701976776, 1.683750033378601, 7.323750019073486], "sizeXYZ": [0.20000000298023224, 6.002500057220459, 11.392499923706055]}, {"name": "WalkPassageRight", "blenderLocation": [9.244999885559082, 1.683750033378601, 7.323750019073486], "sizeXYZ": [0.20000000298023224, 6.002500057220459, 11.392499923706055]}, {"name": "WalkPassageCeiling", "blenderLocation": [4.650000095367432, 1.683750033378601, 13.119999885559082], "sizeXYZ": [9.390000343322754, 6.002500057220459, 0.20000000298023224]}, {"name": "WalkPassageFloor", "blenderLocation": [4.650000095367432, 1.6737500429153442, 1.502500057220459], "sizeXYZ": [8.989999771118164, 5.982500076293945, 0.25]}, {"name": "WalkApproach0", "blenderLocation": [4.650000095367432, -4.364999771118164, 0.15275000035762787], "sizeXYZ": [9.229999542236328, 0.7049999833106995, 0.34549999237060547]}, {"name": "WalkApproach1", "blenderLocation": [4.650000095367432, -3.684999942779541, 0.3154999911785126], "sizeXYZ": [9.229999542236328, 0.7049999833106995, 0.6710000038146973]}, {"name": "WalkApproach2", "blenderLocation": [4.650000095367432, -3.005000114440918, 0.47824999690055847], "sizeXYZ": [9.229999542236328, 0.7049999833106995, 0.9965000152587891]}, {"name": "WalkApproach3", "blenderLocation": [4.650000095367432, -2.325000047683716, 0.640999972820282], "sizeXYZ": [9.229999542236328, 0.7049999833106995, 1.3220000267028809]}, {"name": "WalkApproach4", "blenderLocation": [4.650000095367432, -1.6449999809265137, 0.8037499785423279], "sizeXYZ": [9.229999542236328, 0.7049999833106995, 1.6475000381469727]}], "doors": [{"name": "HouseDoorLeaf_L", "hingeBlender": [0.15500000000000025, -1.3975, 1.6275000000000002], "openDegrees": -100, "sizeXYZ": [4.380000114440918, 0.20000000298023224, 11.232500076293945], "closedCenterBlender": [2.384999990463257, -1.3975000381469727, 7.303750038146973]}, {"name": "HouseDoorLeaf_R", "hingeBlender": [9.145, -1.3975, 1.6275000000000002], "openDegrees": 100, "sizeXYZ": [4.380000114440918, 0.20000000298023224, 11.232500076293945], "closedCenterBlender": [6.914999961853027, -1.3975000381469727, 7.303750038146973]}], "mounts": {"Door_Exit": [4.65, -2.3175, 1.6275000000000002], "Wall": [1.3949999999999996, 21.52, 5.827500000000001]}, "mountYaws": {"Wall": 180, "Door_Exit": 180}}]==])
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
    p.CFrame=CFrame.new(fromBlender(box.blenderLocation))*CFrame.Angles(0,-(box.rotationZ or 0),0)
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
