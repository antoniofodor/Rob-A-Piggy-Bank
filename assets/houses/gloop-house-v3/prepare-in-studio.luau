-- Select ONLY the newly imported FBX model in Studio, then run this file
-- in the Command Bar. It validates before editing; use Undo to reverse it.
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local data = HttpService:JSONDecode([==[{"name": "gloop-house", "bounds": {"min": [-15.565890312194824, -6.574999809265137, -0.28260424733161926], "max": [15.916542053222656, 25.901432037353516, 23.340402603149414], "size": [31.48243236541748, 32.47643184661865, 23.623006850481033]}, "meshCount": 40, "meshes": {"Walls_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "FrontWindows_Amber": {"colorRGB": [255, 193, 65], "transparency": 0}, "SideWindows_Amber": {"colorRGB": [255, 193, 65], "transparency": 0}, "EntryFrame_Frame": {"colorRGB": [25, 91, 29], "transparency": 0}, "Roof_Roof": {"colorRGB": [22, 104, 46], "transparency": 0}, "HouseFX_Pulse_1_Roof": {"colorRGB": [22, 104, 46], "transparency": 0}, "HouseFX_Pulse_2_Roof": {"colorRGB": [22, 104, 46], "transparency": 0}, "HouseFX_Pulse_3_Roof": {"colorRGB": [22, 104, 46], "transparency": 0}, "Puddles_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "Floor_Stone": {"colorRGB": [201, 191, 150], "transparency": 0}, "Walls_Wall": {"colorRGB": [111, 193, 28], "transparency": 0}, "FrontWindows_Frame": {"colorRGB": [25, 91, 29], "transparency": 0}, "SideWindows_Frame": {"colorRGB": [25, 91, 29], "transparency": 0}, "Puddles_Puddle": {"colorRGB": [118, 205, 25], "transparency": 0}, "Floor_Floor": {"colorRGB": [108, 167, 39], "transparency": 0}, "Floor_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "Chimney_WallLight": {"colorRGB": [145, 218, 36], "transparency": 0}, "WalkFloor_WalkFloor": {"colorRGB": [90, 128, 65], "transparency": 0}, "WalkCeiling_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "WalkSideLeftWall_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "WalkSideRightWall_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "WalkRearWall_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "WalkFrontLeft_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "WalkFrontRight_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "WalkLintel_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "WalkPassageLeft_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "WalkPassageRight_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "WalkPassageCeiling_WalkWall": {"colorRGB": [132, 183, 77], "transparency": 0}, "WalkPassageFloor_WalkFloor": {"colorRGB": [90, 128, 65], "transparency": 0}, "WalkApproach0_WalkFloor": {"colorRGB": [90, 128, 65], "transparency": 0}, "WalkApproach1_WalkFloor": {"colorRGB": [90, 128, 65], "transparency": 0}, "HouseDoorLeaf_L_WalkDoor": {"colorRGB": [176, 107, 50], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim": {"colorRGB": [198, 120, 56], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim.001": {"colorRGB": [198, 120, 56], "transparency": 0}, "HouseDoorLeaf_R_WalkDoor": {"colorRGB": [176, 107, 50], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim": {"colorRGB": [198, 120, 56], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim.001": {"colorRGB": [198, 120, 56], "transparency": 0}, "WalkEntryJamb-1_WalkTrim": {"colorRGB": [198, 120, 56], "transparency": 0}, "WalkEntryJamb1_WalkTrim": {"colorRGB": [198, 120, 56], "transparency": 0}, "WalkEntryHeader_WalkTrim": {"colorRGB": [198, 120, 56], "transparency": 0}}, "collisions": [{"name": "WalkFloor", "blenderLocation": [0.0, 11.5, 0.36000001430511475], "sizeXYZ": [18.280000686645508, 19.280000686645508, 0.2800000011920929]}, {"name": "WalkCeiling", "blenderLocation": [0.0, 11.5, 12.710000038146973], "sizeXYZ": [18.280000686645508, 19.280000686645508, 0.11999999731779099]}, {"name": "WalkSideLeftWall", "blenderLocation": [-9.0600004196167, 11.5, 6.574999809265137], "sizeXYZ": [0.11999999731779099, 19.0, 12.149999618530273]}, {"name": "WalkSideRightWall", "blenderLocation": [9.0600004196167, 11.5, 6.574999809265137], "sizeXYZ": [0.11999999731779099, 19.0, 12.149999618530273]}, {"name": "WalkRearWall", "blenderLocation": [0.0, 21.059999465942383, 6.574999809265137], "sizeXYZ": [18.0, 0.11999999731779099, 12.149999618530273]}, {"name": "WalkFrontLeft", "blenderLocation": [-6.0, 1.940000057220459, 6.574999809265137], "sizeXYZ": [6.0, 0.11999999731779099, 12.149999618530273]}, {"name": "WalkFrontRight", "blenderLocation": [6.0, 1.940000057220459, 6.574999809265137], "sizeXYZ": [6.0, 0.11999999731779099, 12.149999618530273]}, {"name": "WalkLintel", "blenderLocation": [0.0, 1.940000057220459, 10.824999809265137], "sizeXYZ": [6.0, 0.11999999731779099, 3.6500000953674316]}, {"name": "WalkPassageLeft", "blenderLocation": [-3.0999999046325684, 0.5649999976158142, 4.75], "sizeXYZ": [0.20000000298023224, 2.630000114440918, 8.5]}, {"name": "WalkPassageRight", "blenderLocation": [3.0999999046325684, 0.5649999976158142, 4.75], "sizeXYZ": [0.20000000298023224, 2.630000114440918, 8.5]}, {"name": "WalkPassageCeiling", "blenderLocation": [0.0, 0.5649999976158142, 9.100000381469727], "sizeXYZ": [6.400000095367432, 2.630000114440918, 0.20000000298023224]}, {"name": "WalkPassageFloor", "blenderLocation": [0.0, 0.5550000071525574, 0.375], "sizeXYZ": [6.0, 2.609999895095825, 0.25]}, {"name": "WalkApproach0", "blenderLocation": [0.0, -1.7575000524520874, 0.11500000208616257], "sizeXYZ": [6.239999771118164, 0.7049999833106995, 0.27000001072883606]}, {"name": "WalkApproach1", "blenderLocation": [0.0, -1.0774999856948853, 0.23999999463558197], "sizeXYZ": [6.239999771118164, 0.7049999833106995, 0.5199999809265137]}], "doors": [{"name": "HouseDoorLeaf_L", "hingeBlender": [-3.0, -0.83, 0.5], "openDegrees": -100, "sizeXYZ": [2.884999990463257, 0.20000000298023224, 8.34000015258789], "closedCenterBlender": [-1.5175000429153442, -0.8299999833106995, 4.730000019073486]}, {"name": "HouseDoorLeaf_R", "hingeBlender": [3.0, -0.83, 0.5], "openDegrees": 100, "sizeXYZ": [2.884999990463257, 0.20000000298023224, 8.34000015258789], "closedCenterBlender": [1.5175000429153442, -0.8299999833106995, 4.730000019073486]}], "mounts": {"Door_Exit": [0, -1.75, 0.5], "Wall": [0.0, 20.82, 4.7]}, "mountYaws": {"Wall": 180, "Door_Exit": 180}}]==])
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
