-- Select ONLY the newly imported FBX model in Studio, then run this file
-- in the Command Bar. It validates before editing; use Undo to reverse it.
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local data = HttpService:JSONDecode([==[{"name": "wonky-townhouse", "bounds": {"min": [-14.5, -3.0, -0.02000001072883606], "max": [14.5, 24.0, 35.76600646972656], "size": [29.0, 27.0, 35.7860064804554]}, "meshCount": 54, "meshes": {"Foundation_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "Storey1_BrickLight": {"colorRGB": [186, 100, 67], "transparency": 0}, "Storey2_DarkGlass": {"colorRGB": [31, 43, 70], "transparency": 0}, "Storey3_DarkGlass": {"colorRGB": [31, 43, 70], "transparency": 0}, "Tilted steep roof_Trim": {"colorRGB": [234, 211, 165], "transparency": 0}, "UpperChimney_Trim": {"colorRGB": [234, 211, 165], "transparency": 0}, "ConnectingCollars_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "EntryCanopy_Jade": {"colorRGB": [57, 113, 110], "transparency": 0}, "Approach_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "Foundation_Stone": {"colorRGB": [162, 164, 176], "transparency": 0}, "Storey1_Brick": {"colorRGB": [159, 73, 55], "transparency": 0}, "Storey1_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "Storey1_Trim": {"colorRGB": [234, 211, 165], "transparency": 0}, "Storey1_Ink": {"colorRGB": [29, 27, 37], "transparency": 0}, "Storey1_Amber": {"colorRGB": [250, 177, 57], "transparency": 0}, "Storey1_DarkGlass": {"colorRGB": [31, 43, 70], "transparency": 0}, "Storey2_Plaster": {"colorRGB": [217, 176, 121], "transparency": 0}, "Storey2_Trim": {"colorRGB": [234, 211, 165], "transparency": 0}, "Storey2_Ink": {"colorRGB": [29, 27, 37], "transparency": 0}, "Storey3_Jade": {"colorRGB": [57, 113, 110], "transparency": 0}, "Storey3_Trim": {"colorRGB": [234, 211, 165], "transparency": 0}, "Storey3_Ink": {"colorRGB": [29, 27, 37], "transparency": 0}, "Tilted steep roof_Slate": {"colorRGB": [58, 79, 103], "transparency": 0}, "UpperChimney_Brick": {"colorRGB": [159, 73, 55], "transparency": 0}, "ConnectingCollars_Slate": {"colorRGB": [58, 79, 103], "transparency": 0}, "Approach_Stone": {"colorRGB": [162, 164, 176], "transparency": 0}, "AttachedDownpipes_Slate": {"colorRGB": [58, 79, 103], "transparency": 0}, "Lanterns_Amber": {"colorRGB": [250, 177, 57], "transparency": 0}, "LanternFrames_Gold": {"colorRGB": [214, 163, 65], "transparency": 0}, "WalkFloor_WalkFloor": {"colorRGB": [119, 83, 60], "transparency": 0}, "WalkCeiling_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "WalkSideLeftWall_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "WalkSideRightWall_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "WalkRearWall_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "WalkFrontLeft_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "WalkFrontRight_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "WalkLintel_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "WalkPassageLeft_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "WalkPassageRight_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "WalkPassageCeiling_WalkWall": {"colorRGB": [214, 187, 150], "transparency": 0}, "WalkPassageFloor_WalkFloor": {"colorRGB": [119, 83, 60], "transparency": 0}, "WalkApproach0_WalkFloor": {"colorRGB": [119, 83, 60], "transparency": 0}, "WalkApproach1_WalkFloor": {"colorRGB": [119, 83, 60], "transparency": 0}, "WalkApproach2_WalkFloor": {"colorRGB": [119, 83, 60], "transparency": 0}, "HouseDoorLeaf_L_WalkDoor": {"colorRGB": [57, 85, 99], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim": {"colorRGB": [64, 96, 111], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim.001": {"colorRGB": [64, 96, 111], "transparency": 0}, "HouseDoorLeaf_R_WalkDoor": {"colorRGB": [57, 85, 99], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim": {"colorRGB": [64, 96, 111], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim.001": {"colorRGB": [64, 96, 111], "transparency": 0}, "WalkEntryJamb-1_WalkTrim": {"colorRGB": [64, 96, 111], "transparency": 0}, "WalkEntryJamb1_WalkTrim": {"colorRGB": [64, 96, 111], "transparency": 0}, "WalkEntryHeader_WalkTrim": {"colorRGB": [64, 96, 111], "transparency": 0}, "LanternFrames_Timber": {"colorRGB": [98, 68, 40], "transparency": 0}}, "collisions": [{"name": "WalkFloor", "blenderLocation": [0.0, 10.0, 0.8100000023841858], "sizeXYZ": [13.479999542236328, 16.280000686645508, 0.2800000011920929]}, {"name": "WalkCeiling", "blenderLocation": [0.0, 10.0, 9.0600004196167], "sizeXYZ": [13.479999542236328, 16.280000686645508, 0.11999999731779099]}, {"name": "WalkSideLeftWall", "blenderLocation": [-6.659999847412109, 10.0, 4.974999904632568], "sizeXYZ": [0.11999999731779099, 16.0, 8.050000190734863]}, {"name": "WalkSideRightWall", "blenderLocation": [6.659999847412109, 10.0, 4.974999904632568], "sizeXYZ": [0.11999999731779099, 16.0, 8.050000190734863]}, {"name": "WalkRearWall", "blenderLocation": [0.0, 18.059999465942383, 4.974999904632568], "sizeXYZ": [13.199999809265137, 0.11999999731779099, 8.050000190734863]}, {"name": "WalkFrontLeft", "blenderLocation": [-4.75, 1.940000057220459, 4.974999904632568], "sizeXYZ": [3.700000047683716, 0.11999999731779099, 8.050000190734863]}, {"name": "WalkFrontRight", "blenderLocation": [4.75, 1.940000057220459, 4.974999904632568], "sizeXYZ": [3.700000047683716, 0.11999999731779099, 8.050000190734863]}, {"name": "WalkLintel", "blenderLocation": [0.0, 1.940000057220459, 8.600000381469727], "sizeXYZ": [5.800000190734863, 0.11999999731779099, 0.800000011920929]}, {"name": "WalkPassageLeft", "blenderLocation": [-3.0, 0.6399999856948853, 4.574999809265137], "sizeXYZ": [0.20000000298023224, 2.4800000190734863, 7.25]}, {"name": "WalkPassageRight", "blenderLocation": [3.0, 0.6399999856948853, 4.574999809265137], "sizeXYZ": [0.20000000298023224, 2.4800000190734863, 7.25]}, {"name": "WalkPassageCeiling", "blenderLocation": [0.0, 0.6399999856948853, 8.300000190734863], "sizeXYZ": [6.199999809265137, 2.4800000190734863, 0.20000000298023224]}, {"name": "WalkPassageFloor", "blenderLocation": [0.0, 0.6299999952316284, 0.824999988079071], "sizeXYZ": [5.800000190734863, 2.4600000381469727, 0.25]}, {"name": "WalkApproach0", "blenderLocation": [0.0, -2.2874999046325684, 0.1483333259820938], "sizeXYZ": [6.039999961853027, 0.7049999833106995, 0.33666667342185974]}, {"name": "WalkApproach1", "blenderLocation": [0.0, -1.6074999570846558, 0.30666667222976685], "sizeXYZ": [6.039999961853027, 0.7049999833106995, 0.653333306312561]}, {"name": "WalkApproach2", "blenderLocation": [0.0, -0.9275000095367432, 0.4650000035762787], "sizeXYZ": [6.039999961853027, 0.7049999833106995, 0.9700000286102295]}], "doors": [{"name": "HouseDoorLeaf_L", "hingeBlender": [-2.9, -0.6799999999999999, 0.95], "openDegrees": -100, "sizeXYZ": [2.7850000858306885, 0.20000000298023224, 7.090000152587891], "closedCenterBlender": [-1.4674999713897705, -0.6800000071525574, 4.554999828338623]}, {"name": "HouseDoorLeaf_R", "hingeBlender": [2.9, -0.6799999999999999, 0.95], "openDegrees": 100, "sizeXYZ": [2.7850000858306885, 0.20000000298023224, 7.090000152587891], "closedCenterBlender": [1.4674999713897705, -0.6800000071525574, 4.554999828338623]}], "mounts": {"Door_Exit": [0, -1.6, 0.95], "Wall": [0.0, 17.82, 5.15]}, "mountYaws": {"Wall": 180, "Door_Exit": 180}}]==])
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
