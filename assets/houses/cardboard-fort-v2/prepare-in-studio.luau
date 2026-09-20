-- Select ONLY the newly imported FBX model in Studio, then run this file
-- in the Command Bar. It validates before editing; use Undo to reverse it.
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local data = HttpService:JSONDecode([==[{"name": "cardboard-fort", "bounds": {"min": [-11.0, -2.6500000953674316, -0.02000001072883606], "max": [11.0, 17.799999237060547, 13.40000057220459], "size": [22.0, 20.44999933242798, 13.420000582933426]}, "meshCount": 41, "meshes": {"Foundation_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "MainBox_Tape": {"colorRGB": [217, 188, 135], "transparency": 0}, "BoxFlaps_CardDark": {"colorRGB": [116, 78, 42], "transparency": 0}, "BoxWindows_CardLight": {"colorRGB": [187, 143, 91], "transparency": 0}, "Patches_CardDark": {"colorRGB": [116, 78, 42], "transparency": 0}, "Approach_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "Foundation_CardDark": {"colorRGB": [116, 78, 42], "transparency": 0}, "MainBox_Card": {"colorRGB": [161, 113, 67], "transparency": 0}, "MainBox_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "MainBox_CardLight": {"colorRGB": [187, 143, 91], "transparency": 0}, "BoxFlaps_CardLight": {"colorRGB": [187, 143, 91], "transparency": 0}, "BoxWindows_Ink": {"colorRGB": [29, 27, 37], "transparency": 0}, "BoxWindows_DarkGlass": {"colorRGB": [31, 43, 70], "transparency": 0}, "BoxWindows_Tape": {"colorRGB": [217, 188, 135], "transparency": 0}, "Patches_CardLight": {"colorRGB": [187, 143, 91], "transparency": 0}, "Patches_Tape": {"colorRGB": [217, 188, 135], "transparency": 0}, "Approach_CardLight": {"colorRGB": [187, 143, 91], "transparency": 0}, "Doodles_RedPencil": {"colorRGB": [166, 61, 49], "transparency": 0}, "WalkFloor_WalkFloor": {"colorRGB": [144, 106, 68], "transparency": 0}, "WalkCeiling_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "WalkSideLeftWall_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "WalkSideRightWall_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "WalkRearWall_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "WalkFrontLeft_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "WalkFrontRight_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "WalkLintel_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "WalkPassageLeft_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "WalkPassageRight_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "WalkPassageCeiling_WalkWall": {"colorRGB": [183, 145, 100], "transparency": 0}, "WalkPassageFloor_WalkFloor": {"colorRGB": [144, 106, 68], "transparency": 0}, "WalkApproach0_WalkFloor": {"colorRGB": [144, 106, 68], "transparency": 0}, "WalkApproach1_WalkFloor": {"colorRGB": [144, 106, 68], "transparency": 0}, "HouseDoorLeaf_L_WalkDoor": {"colorRGB": [128, 90, 53], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim": {"colorRGB": [144, 101, 59], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim.001": {"colorRGB": [144, 101, 59], "transparency": 0}, "HouseDoorLeaf_R_WalkDoor": {"colorRGB": [128, 90, 53], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim": {"colorRGB": [144, 101, 59], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim.001": {"colorRGB": [144, 101, 59], "transparency": 0}, "WalkEntryJamb-1_WalkTrim": {"colorRGB": [144, 101, 59], "transparency": 0}, "WalkEntryJamb1_WalkTrim": {"colorRGB": [144, 101, 59], "transparency": 0}, "WalkEntryHeader_WalkTrim": {"colorRGB": [144, 101, 59], "transparency": 0}}, "collisions": [{"name": "WalkFloor", "blenderLocation": [0.0, 7.550000190734863, 0.4099999964237213], "sizeXYZ": [13.680000305175781, 13.380000114440918, 0.2800000011920929]}, {"name": "WalkCeiling", "blenderLocation": [0.0, 7.550000190734863, 9.109999656677246], "sizeXYZ": [13.680000305175781, 13.380000114440918, 0.11999999731779099]}, {"name": "WalkSideLeftWall", "blenderLocation": [-6.760000228881836, 7.550000190734863, 4.800000190734863], "sizeXYZ": [0.11999999731779099, 13.100000381469727, 8.5]}, {"name": "WalkSideRightWall", "blenderLocation": [6.760000228881836, 7.550000190734863, 4.800000190734863], "sizeXYZ": [0.11999999731779099, 13.100000381469727, 8.5]}, {"name": "WalkRearWall", "blenderLocation": [0.0, 14.15999984741211, 4.800000190734863], "sizeXYZ": [13.399999618530273, 0.11999999731779099, 8.5]}, {"name": "WalkFrontLeft", "blenderLocation": [-4.800000190734863, 0.9399999976158142, 4.800000190734863], "sizeXYZ": [3.799999952316284, 0.11999999731779099, 8.5]}, {"name": "WalkFrontRight", "blenderLocation": [4.800000190734863, 0.9399999976158142, 4.800000190734863], "sizeXYZ": [3.799999952316284, 0.11999999731779099, 8.5]}, {"name": "WalkLintel", "blenderLocation": [0.0, 0.9399999976158142, 8.699999809265137], "sizeXYZ": [5.800000190734863, 0.11999999731779099, 0.699999988079071]}, {"name": "WalkPassageLeft", "blenderLocation": [-3.0, 0.16500000655651093, 4.449999809265137], "sizeXYZ": [0.20000000298023224, 1.4299999475479126, 7.800000190734863]}, {"name": "WalkPassageRight", "blenderLocation": [3.0, 0.16500000655651093, 4.449999809265137], "sizeXYZ": [0.20000000298023224, 1.4299999475479126, 7.800000190734863]}, {"name": "WalkPassageCeiling", "blenderLocation": [0.0, 0.16500000655651093, 8.449999809265137], "sizeXYZ": [6.199999809265137, 1.4299999475479126, 0.20000000298023224]}, {"name": "WalkPassageFloor", "blenderLocation": [0.0, 0.1550000011920929, 0.42500001192092896], "sizeXYZ": [5.800000190734863, 1.409999966621399, 0.25]}, {"name": "WalkApproach0", "blenderLocation": [0.0, -1.5575000047683716, 0.1274999976158142], "sizeXYZ": [6.039999961853027, 0.7049999833106995, 0.29499998688697815]}, {"name": "WalkApproach1", "blenderLocation": [0.0, -0.8774999976158142, 0.26499998569488525], "sizeXYZ": [6.039999961853027, 0.7049999833106995, 0.5699999928474426]}], "doors": [{"name": "HouseDoorLeaf_L", "hingeBlender": [-2.9, -0.63, 0.55], "openDegrees": -100, "sizeXYZ": [2.7850000858306885, 0.20000000298023224, 7.639999866485596], "closedCenterBlender": [-1.4674999713897705, -0.6299999952316284, 4.429999828338623]}, {"name": "HouseDoorLeaf_R", "hingeBlender": [2.9, -0.63, 0.55], "openDegrees": 100, "sizeXYZ": [2.7850000858306885, 0.20000000298023224, 7.639999866485596], "closedCenterBlender": [1.4674999713897705, -0.6299999952316284, 4.429999828338623]}], "mounts": {"Door_Exit": [0, -1.55, 0.55], "Wall": [0.0, 13.92, 4.75]}, "mountYaws": {"Wall": 180, "Door_Exit": 180}}]==])
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
