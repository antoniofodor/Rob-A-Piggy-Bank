-- Select ONLY the newly imported FBX model in Studio, then run this file
-- in the Command Bar. It validates before editing; use Undo to reverse it.
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local data = HttpService:JSONDecode([==[{"name": "beehive-cottage", "bounds": {"min": [-14.0, -4.62999963760376, -0.02000001072883606], "max": [14.0, 25.5, 22.360000610351562], "size": [28.0, 30.12999963760376, 22.3800006210804]}, "meshCount": 40, "meshes": {"Foundation_Grass": {"colorRGB": [91, 121, 61], "transparency": 0}, "EntrancePod_WaxLight": {"colorRGB": [222, 171, 71], "transparency": 0}, "Approach_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "HoneycombWindows_Amber": {"colorRGB": [250, 177, 57], "transparency": 0}, "Approach_WaxLight": {"colorRGB": [222, 171, 71], "transparency": 0}, "HoneycombWindows_WaxDark": {"colorRGB": [125, 77, 29], "transparency": 0}, "BeehiveShell_WaxLight": {"colorRGB": [222, 171, 71], "transparency": 0}, "HoneyDrips_Honey": {"colorRGB": [236, 151, 24], "transparency": 0}, "WaxChimney_Ink": {"colorRGB": [29, 27, 37], "transparency": 0}, "Garden_WaxDark": {"colorRGB": [125, 77, 29], "transparency": 0}, "WalkFloor_WalkFloor": {"colorRGB": [177, 128, 63], "transparency": 0}, "WalkCeiling_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "WalkSideLeftWall_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "WalkSideRightWall_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "WalkRearWall_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "WalkFrontLeft_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "WalkFrontRight_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "WalkLintel_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "WalkPassageLeft_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "WalkPassageRight_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "WalkPassageCeiling_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "WalkPassageFloor_WalkFloor": {"colorRGB": [177, 128, 63], "transparency": 0}, "WalkApproach0_WalkFloor": {"colorRGB": [177, 128, 63], "transparency": 0}, "WalkApproach1_WalkFloor": {"colorRGB": [177, 128, 63], "transparency": 0}, "WalkApproach2_WalkFloor": {"colorRGB": [177, 128, 63], "transparency": 0}, "HouseDoorLeaf_L_WalkDoor": {"colorRGB": [53, 117, 111], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim": {"colorRGB": [59, 132, 125], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim.001": {"colorRGB": [59, 132, 125], "transparency": 0}, "HouseDoorLeaf_R_WalkDoor": {"colorRGB": [53, 117, 111], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim": {"colorRGB": [59, 132, 125], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim.001": {"colorRGB": [59, 132, 125], "transparency": 0}, "WalkEntryJamb-1_WalkTrim": {"colorRGB": [59, 132, 125], "transparency": 0}, "WalkEntryJamb1_WalkTrim": {"colorRGB": [59, 132, 125], "transparency": 0}, "WalkEntryHeader_WalkTrim": {"colorRGB": [59, 132, 125], "transparency": 0}, "BeehiveShell_Wax": {"colorRGB": [190, 133, 40], "transparency": 0}, "BeehiveShell_WalkWall": {"colorRGB": [232, 191, 102], "transparency": 0}, "BeehiveShell_WaxDark": {"colorRGB": [125, 77, 29], "transparency": 0}, "WaxChimney_WaxDark": {"colorRGB": [125, 77, 29], "transparency": 0}, "WaxChimney_WaxLight": {"colorRGB": [222, 171, 71], "transparency": 0}, "Garden_Leaf": {"colorRGB": [61, 107, 61], "transparency": 0}}, "collisions": [{"name": "WalkFloor", "blenderLocation": [0.0, 12.0, 0.8600000143051147], "sizeXYZ": [12.880000114440918, 12.279999732971191, 0.2800000011920929]}, {"name": "WalkCeiling", "blenderLocation": [0.0, 12.0, 11.0600004196167], "sizeXYZ": [12.880000114440918, 12.279999732971191, 0.11999999731779099]}, {"name": "WalkSideLeftWall", "blenderLocation": [-6.360000133514404, 12.0, 6.0], "sizeXYZ": [0.11999999731779099, 12.0, 10.0]}, {"name": "WalkSideRightWall", "blenderLocation": [6.360000133514404, 12.0, 6.0], "sizeXYZ": [0.11999999731779099, 12.0, 10.0]}, {"name": "WalkRearWall", "blenderLocation": [0.0, 18.059999465942383, 6.0], "sizeXYZ": [12.600000381469727, 0.11999999731779099, 10.0]}, {"name": "WalkFrontLeft", "blenderLocation": [-4.650000095367432, 5.940000057220459, 6.0], "sizeXYZ": [3.299999952316284, 0.11999999731779099, 10.0]}, {"name": "WalkFrontRight", "blenderLocation": [4.650000095367432, 5.940000057220459, 6.0], "sizeXYZ": [3.299999952316284, 0.11999999731779099, 10.0]}, {"name": "WalkLintel", "blenderLocation": [0.0, 5.940000057220459, 10.0], "sizeXYZ": [6.0, 0.11999999731779099, 2.0]}, {"name": "WalkPassageLeft", "blenderLocation": [-3.0999999046325684, 2.065000057220459, 5.0], "sizeXYZ": [0.20000000298023224, 7.630000114440918, 8.0]}, {"name": "WalkPassageRight", "blenderLocation": [3.0999999046325684, 2.065000057220459, 5.0], "sizeXYZ": [0.20000000298023224, 7.630000114440918, 8.0]}, {"name": "WalkPassageCeiling", "blenderLocation": [0.0, 2.065000057220459, 9.100000381469727], "sizeXYZ": [6.400000095367432, 7.630000114440918, 0.20000000298023224]}, {"name": "WalkPassageFloor", "blenderLocation": [0.0, 2.055000066757202, 0.875], "sizeXYZ": [6.0, 7.610000133514404, 0.25]}, {"name": "WalkApproach0", "blenderLocation": [0.0, -3.4375, 0.15666666626930237], "sizeXYZ": [6.239999771118164, 0.7049999833106995, 0.35333332419395447]}, {"name": "WalkApproach1", "blenderLocation": [0.0, -2.757499933242798, 0.3233333230018616], "sizeXYZ": [6.239999771118164, 0.7049999833106995, 0.6866666674613953]}, {"name": "WalkApproach2", "blenderLocation": [0.0, -2.077500104904175, 0.49000000953674316], "sizeXYZ": [6.239999771118164, 0.7049999833106995, 1.0199999809265137]}], "doors": [{"name": "HouseDoorLeaf_L", "hingeBlender": [-3.0, -1.83, 1.0], "openDegrees": -100, "sizeXYZ": [2.884999990463257, 0.20000000298023224, 7.840000152587891], "closedCenterBlender": [-1.5175000429153442, -1.8300000429153442, 4.980000019073486]}, {"name": "HouseDoorLeaf_R", "hingeBlender": [3.0, -1.83, 1.0], "openDegrees": 100, "sizeXYZ": [2.884999990463257, 0.20000000298023224, 7.840000152587891], "closedCenterBlender": [1.5175000429153442, -1.8300000429153442, 4.980000019073486]}], "mounts": {"Door_Exit": [0, -2.75, 1.0], "Wall": [0.0, 17.82, 5.2]}, "mountYaws": {"Wall": 180, "Door_Exit": 180}}]==])
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
