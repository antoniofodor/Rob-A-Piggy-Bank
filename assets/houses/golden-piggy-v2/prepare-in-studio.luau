-- Select ONLY the newly imported FBX model in Studio, then run this file
-- in the Command Bar. It validates before editing; use Undo to reverse it.
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local data = HttpService:JSONDecode([==[{"name": "golden-piggy", "bounds": {"min": [-31.049999237060547, -7.590000152587891, -0.020000040531158447], "max": [31.049999237060547, 37.95000076293945, 55.88999938964844], "size": [62.099998474121094, 45.540000915527344, 55.909999430179596]}, "meshCount": 54, "meshes": {"Foundation_PigShade": {"colorRGB": [183, 125, 30], "transparency": 0}, "Ears_EarPink": {"colorRGB": [205, 100, 105], "transparency": 0}, "Snout_PigShade": {"colorRGB": [183, 125, 30], "transparency": 0}, "BellyEntrance_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "Approach_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "EarBalconies_Timber": {"colorRGB": [98, 68, 40], "transparency": 0}, "CoinSlot_Ink": {"colorRGB": [29, 27, 37], "transparency": 0}, "Ears_PigLight": {"colorRGB": [247, 202, 84], "transparency": 0}, "Snout_Snout": {"colorRGB": [225, 119, 145], "transparency": 0}, "Snout_Ink": {"colorRGB": [29, 27, 37], "transparency": 0}, "Snout_Amber": {"colorRGB": [250, 177, 57], "transparency": 0}, "BellyEntrance_PigGold": {"colorRGB": [231, 179, 57], "transparency": 0}, "Approach_PigLight": {"colorRGB": [247, 202, 84], "transparency": 0}, "EarBalconies_PigShade": {"colorRGB": [183, 125, 30], "transparency": 0}, "CoinSlot_PigShade": {"colorRGB": [183, 125, 30], "transparency": 0}, "PigBody_PigShade": {"colorRGB": [183, 125, 30], "transparency": 0}, "RoundWindows_PigShade": {"colorRGB": [183, 125, 30], "transparency": 0}, "HouseFX_SlotCoin_PigShade": {"colorRGB": [183, 125, 30], "transparency": 0}, "TailChimney_PigGold": {"colorRGB": [231, 179, 57], "transparency": 0}, "HouseFX_FlankAccent_1_PigLight": {"colorRGB": [247, 202, 84], "transparency": 0}, "HouseFX_FlankAccent_2_PigLight": {"colorRGB": [247, 202, 84], "transparency": 0}, "WalkFloor_WalkFloor": {"colorRGB": [194, 146, 50], "transparency": 0}, "WalkCeiling_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "WalkSideLeftWall_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "WalkSideRightWall_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "WalkRearWall_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "WalkFrontLeft_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "WalkFrontRight_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "WalkLintel_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "WalkPassageLeft_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "WalkPassageRight_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "WalkPassageCeiling_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "WalkPassageFloor_WalkFloor": {"colorRGB": [194, 146, 50], "transparency": 0}, "WalkApproach0_WalkFloor": {"colorRGB": [194, 146, 50], "transparency": 0}, "WalkApproach1_WalkFloor": {"colorRGB": [194, 146, 50], "transparency": 0}, "WalkApproach2_WalkFloor": {"colorRGB": [194, 146, 50], "transparency": 0}, "WalkApproach3_WalkFloor": {"colorRGB": [194, 146, 50], "transparency": 0}, "WalkApproach4_WalkFloor": {"colorRGB": [194, 146, 50], "transparency": 0}, "WalkApproach5_WalkFloor": {"colorRGB": [194, 146, 50], "transparency": 0}, "WalkApproach6_WalkFloor": {"colorRGB": [194, 146, 50], "transparency": 0}, "HouseDoorLeaf_L_WalkDoor": {"colorRGB": [147, 100, 35], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim": {"colorRGB": [166, 112, 39], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim.001": {"colorRGB": [166, 112, 39], "transparency": 0}, "HouseDoorLeaf_R_WalkDoor": {"colorRGB": [147, 100, 35], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim": {"colorRGB": [166, 112, 39], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim.001": {"colorRGB": [166, 112, 39], "transparency": 0}, "WalkEntryJamb-1_WalkTrim": {"colorRGB": [166, 112, 39], "transparency": 0}, "WalkEntryJamb1_WalkTrim": {"colorRGB": [166, 112, 39], "transparency": 0}, "WalkEntryHeader_WalkTrim": {"colorRGB": [166, 112, 39], "transparency": 0}, "PigBody_PigGold": {"colorRGB": [231, 179, 57], "transparency": 0}, "PigBody_WalkWall": {"colorRGB": [232, 201, 112], "transparency": 0}, "RoundWindows_Amber": {"colorRGB": [250, 177, 57], "transparency": 0}, "HouseFX_SlotCoin_PigLight": {"colorRGB": [247, 202, 84], "transparency": 0}, "TailChimney_PigShade": {"colorRGB": [183, 125, 30], "transparency": 0}}, "collisions": [{"name": "WalkFloor", "blenderLocation": [0.0, 19.665000915527344, 2.068000078201294], "sizeXYZ": [32.02000045776367, 16.149999618530273, 0.2800000011920929]}, {"name": "WalkCeiling", "blenderLocation": [0.0, 19.665000915527344, 17.309999465942383], "sizeXYZ": [32.02000045776367, 16.149999618530273, 0.11999999731779099]}, {"name": "WalkSideLeftWall", "blenderLocation": [-15.930000305175781, 19.665000915527344, 9.729000091552734], "sizeXYZ": [0.11999999731779099, 15.869999885559082, 15.041999816894531]}, {"name": "WalkSideRightWall", "blenderLocation": [15.930000305175781, 19.665000915527344, 9.729000091552734], "sizeXYZ": [0.11999999731779099, 15.869999885559082, 15.041999816894531]}, {"name": "WalkRearWall", "blenderLocation": [0.0, 27.65999984741211, 9.729000091552734], "sizeXYZ": [31.739999771118164, 0.11999999731779099, 15.041999816894531]}, {"name": "WalkFrontLeft", "blenderLocation": [-10.005000114440918, 11.670000076293945, 9.729000091552734], "sizeXYZ": [11.729999542236328, 0.11999999731779099, 15.041999816894531]}, {"name": "WalkFrontRight", "blenderLocation": [10.005000114440918, 11.670000076293945, 9.729000091552734], "sizeXYZ": [11.729999542236328, 0.11999999731779099, 15.041999816894531]}, {"name": "WalkLintel", "blenderLocation": [0.0, 11.670000076293945, 15.593999862670898], "sizeXYZ": [8.279999732971191, 0.11999999731779099, 3.312000036239624]}, {"name": "WalkPassageLeft", "blenderLocation": [-4.239999771118164, 5.356500148773193, 8.072999954223633], "sizeXYZ": [0.20000000298023224, 12.506999969482422, 11.729999542236328]}, {"name": "WalkPassageRight", "blenderLocation": [4.239999771118164, 5.356500148773193, 8.072999954223633], "sizeXYZ": [0.20000000298023224, 12.506999969482422, 11.729999542236328]}, {"name": "WalkPassageCeiling", "blenderLocation": [0.0, 5.356500148773193, 14.038000106811523], "sizeXYZ": [8.680000305175781, 12.506999969482422, 0.20000000298023224]}, {"name": "WalkPassageFloor", "blenderLocation": [0.0, 5.346499919891357, 2.0829999446868896], "sizeXYZ": [8.279999732971191, 12.487000465393066, 0.25]}, {"name": "WalkApproach0", "blenderLocation": [0.0, -5.304500102996826, 0.1477142870426178], "sizeXYZ": [8.520000457763672, 0.7049999833106995, 0.3354285657405853]}, {"name": "WalkApproach1", "blenderLocation": [0.0, -4.624499797821045, 0.30542856454849243], "sizeXYZ": [8.520000457763672, 0.7049999833106995, 0.650857150554657]}, {"name": "WalkApproach2", "blenderLocation": [0.0, -3.944499969482422, 0.46314287185668945], "sizeXYZ": [8.520000457763672, 0.7049999833106995, 0.9662857055664062]}, {"name": "WalkApproach3", "blenderLocation": [0.0, -3.2644999027252197, 0.6208571195602417], "sizeXYZ": [8.520000457763672, 0.7049999833106995, 1.2817143201828003]}, {"name": "WalkApproach4", "blenderLocation": [0.0, -2.5845000743865967, 0.7785714268684387], "sizeXYZ": [8.520000457763672, 0.7049999833106995, 1.5971428155899048]}, {"name": "WalkApproach5", "blenderLocation": [0.0, -1.9045000076293945, 0.9362857341766357], "sizeXYZ": [8.520000457763672, 0.7049999833106995, 1.9125714302062988]}, {"name": "WalkApproach6", "blenderLocation": [0.0, -1.2244999408721924, 1.093999981880188], "sizeXYZ": [8.520000457763672, 0.7049999833106995, 2.2279999256134033]}], "doors": [{"name": "HouseDoorLeaf_L", "hingeBlender": [-4.14, -0.9769999999999999, 2.2079999999999997], "openDegrees": -100, "sizeXYZ": [4.025000095367432, 0.20000000298023224, 11.569999694824219], "closedCenterBlender": [-2.0875000953674316, -0.9769999980926514, 8.053000450134277]}, {"name": "HouseDoorLeaf_R", "hingeBlender": [4.14, -0.9769999999999999, 2.2079999999999997], "openDegrees": 100, "sizeXYZ": [4.025000095367432, 0.20000000298023224, 11.569999694824219], "closedCenterBlender": [2.0875000953674316, -0.9769999980926514, 8.053000450134277]}], "mounts": {"Door_Exit": [0.0, -1.8969999999999998, 2.2079999999999997], "Wall": [0.0, 27.419999999999998, 6.4079999999999995]}, "mountYaws": {"Wall": 180, "Door_Exit": 180}}]==])
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
