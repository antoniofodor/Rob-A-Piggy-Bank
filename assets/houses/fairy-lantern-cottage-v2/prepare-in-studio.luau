-- Select ONLY the newly imported FBX model in Studio, then run this file
-- in the Command Bar. It validates before editing; use Undo to reverse it.
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local data = HttpService:JSONDecode([==[{"name": "fairy-lantern-cottage", "bounds": {"min": [-21.0, -4.961599826812744, -0.02000001072883606], "max": [21.0, 31.920000076293945, 25.423999786376953], "size": [42.0, 36.88159990310669, 25.44399979710579]}, "meshCount": 56, "meshes": {"Foundation_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "CottageShell_Moss": {"colorRGB": [74, 105, 43], "transparency": 0}, "Bowed moss roof_RoofEdge": {"colorRGB": [60, 85, 35], "transparency": 0}, "Chimney_RoofEdge": {"colorRGB": [60, 85, 35], "transparency": 0}, "RoundDoor_Moss": {"colorRGB": [74, 105, 43], "transparency": 0}, "Windows_Moss": {"colorRGB": [74, 105, 43], "transparency": 0}, "Approach_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "Foundation_Moss": {"colorRGB": [74, 105, 43], "transparency": 0}, "CottageShell_Wall": {"colorRGB": [225, 210, 175], "transparency": 0}, "CottageShell_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "CottageShell_RoofEdge": {"colorRGB": [60, 85, 35], "transparency": 0}, "Bowed moss roof_Roof": {"colorRGB": [73, 112, 41], "transparency": 0}, "Chimney_Stone": {"colorRGB": [162, 164, 176], "transparency": 0}, "RoundDoor_RoofEdge": {"colorRGB": [60, 85, 35], "transparency": 0}, "Windows_Cream": {"colorRGB": [235, 218, 181], "transparency": 0}, "Windows_Cap": {"colorRGB": [171, 63, 57], "transparency": 0}, "Windows_Leaf": {"colorRGB": [61, 107, 61], "transparency": 0}, "Windows_Amber": {"colorRGB": [250, 177, 57], "transparency": 0}, "Windows_RoofEdge": {"colorRGB": [60, 85, 35], "transparency": 0}, "Approach_Stone": {"colorRGB": [162, 164, 176], "transparency": 0}, "Ivy_Leaf": {"colorRGB": [61, 107, 61], "transparency": 0}, "LanternString_Ink": {"colorRGB": [29, 27, 37], "transparency": 0}, "HouseFX_Lantern_1_AmberGlow": {"colorRGB": [243, 131, 21], "transparency": 0}, "LanternFrames_Gold": {"colorRGB": [214, 163, 65], "transparency": 0}, "HouseFX_Lantern_2_RoseGlow": {"colorRGB": [211, 43, 107], "transparency": 0}, "HouseFX_Lantern_3_VioletGlow": {"colorRGB": [116, 40, 205], "transparency": 0}, "HouseFX_Lantern_4_AmberGlow": {"colorRGB": [243, 131, 21], "transparency": 0}, "HouseFX_Lantern_5_RoseGlow": {"colorRGB": [211, 43, 107], "transparency": 0}, "GroundGarden_Moss": {"colorRGB": [74, 105, 43], "transparency": 0}, "SideWindow_Moss": {"colorRGB": [74, 105, 43], "transparency": 0}, "WalkFloor_WalkFloor": {"colorRGB": [130, 104, 60], "transparency": 0}, "WalkCeiling_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "WalkSideLeftWall_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "WalkSideRightWall_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "WalkRearWall_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "WalkFrontLeft_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "WalkFrontRight_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "WalkLintel_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "WalkPassageLeft_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "WalkPassageRight_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "WalkPassageCeiling_WalkWall": {"colorRGB": [226, 215, 181], "transparency": 0}, "WalkPassageFloor_WalkFloor": {"colorRGB": [130, 104, 60], "transparency": 0}, "WalkApproach0_WalkFloor": {"colorRGB": [130, 104, 60], "transparency": 0}, "WalkApproach1_WalkFloor": {"colorRGB": [130, 104, 60], "transparency": 0}, "WalkApproach2_WalkFloor": {"colorRGB": [130, 104, 60], "transparency": 0}, "HouseDoorLeaf_L_WalkDoor": {"colorRGB": [68, 111, 51], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim": {"colorRGB": [76, 125, 57], "transparency": 0}, "HouseDoorLeaf_L_WalkTrim.001": {"colorRGB": [76, 125, 57], "transparency": 0}, "HouseDoorLeaf_R_WalkDoor": {"colorRGB": [68, 111, 51], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim": {"colorRGB": [76, 125, 57], "transparency": 0}, "HouseDoorLeaf_R_WalkTrim.001": {"colorRGB": [76, 125, 57], "transparency": 0}, "WalkEntryJamb-1_WalkTrim": {"colorRGB": [76, 125, 57], "transparency": 0}, "WalkEntryJamb1_WalkTrim": {"colorRGB": [76, 125, 57], "transparency": 0}, "WalkEntryHeader_WalkTrim": {"colorRGB": [76, 125, 57], "transparency": 0}, "LanternFrames_Timber": {"colorRGB": [98, 68, 40], "transparency": 0}, "SideWindow_Amber": {"colorRGB": [250, 177, 57], "transparency": 0}}, "collisions": [{"name": "WalkFloor", "blenderLocation": [0.0, 14.0, 0.7699999809265137], "sizeXYZ": [26.31999969482422, 25.479999542236328, 0.2800000011920929]}, {"name": "WalkCeiling", "blenderLocation": [0.0, 14.0, 12.65999984741211], "sizeXYZ": [26.31999969482422, 25.479999542236328, 0.11999999731779099]}, {"name": "WalkSideLeftWall", "blenderLocation": [-13.079999923706055, 14.0, 6.755000114440918], "sizeXYZ": [0.11999999731779099, 25.200000762939453, 11.6899995803833]}, {"name": "WalkSideRightWall", "blenderLocation": [13.079999923706055, 14.0, 6.755000114440918], "sizeXYZ": [0.11999999731779099, 25.200000762939453, 11.6899995803833]}, {"name": "WalkRearWall", "blenderLocation": [0.0, 26.65999984741211, 6.755000114440918], "sizeXYZ": [26.040000915527344, 0.11999999731779099, 11.6899995803833]}, {"name": "WalkFrontLeft", "blenderLocation": [-8.539999961853027, 1.340000033378601, 6.755000114440918], "sizeXYZ": [8.960000038146973, 0.11999999731779099, 11.6899995803833]}, {"name": "WalkFrontRight", "blenderLocation": [8.539999961853027, 1.340000033378601, 6.755000114440918], "sizeXYZ": [8.960000038146973, 0.11999999731779099, 11.6899995803833]}, {"name": "WalkLintel", "blenderLocation": [0.0, 1.340000033378601, 12.074999809265137], "sizeXYZ": [8.119999885559082, 0.11999999731779099, 1.0499999523162842]}, {"name": "WalkPassageLeft", "blenderLocation": [-4.159999847412109, 0.04500000178813934, 6.230000019073486], "sizeXYZ": [0.20000000298023224, 2.4700000286102295, 10.640000343322754]}, {"name": "WalkPassageRight", "blenderLocation": [4.159999847412109, 0.04500000178813934, 6.230000019073486], "sizeXYZ": [0.20000000298023224, 2.4700000286102295, 10.640000343322754]}, {"name": "WalkPassageCeiling", "blenderLocation": [0.0, 0.04500000178813934, 11.649999618530273], "sizeXYZ": [8.520000457763672, 2.4700000286102295, 0.20000000298023224]}, {"name": "WalkPassageFloor", "blenderLocation": [0.0, 0.03500000014901161, 0.7850000262260437], "sizeXYZ": [8.119999885559082, 2.450000047683716, 0.25]}, {"name": "WalkApproach0", "blenderLocation": [0.0, -2.877500057220459, 0.14166666567325592], "sizeXYZ": [8.359999656677246, 0.7049999833106995, 0.3233333230018616]}, {"name": "WalkApproach1", "blenderLocation": [0.0, -2.197499990463257, 0.2933333218097687], "sizeXYZ": [8.359999656677246, 0.7049999833106995, 0.6266666650772095]}, {"name": "WalkApproach2", "blenderLocation": [0.0, -1.5175000429153442, 0.4449999928474426], "sizeXYZ": [8.359999656677246, 0.7049999833106995, 0.9300000071525574]}], "doors": [{"name": "HouseDoorLeaf_L", "hingeBlender": [-4.06, -1.27, 0.9099999999999999], "openDegrees": -100, "sizeXYZ": [3.944999933242798, 0.20000000298023224, 10.479999542236328], "closedCenterBlender": [-2.047499895095825, -1.2699999809265137, 6.210000038146973]}, {"name": "HouseDoorLeaf_R", "hingeBlender": [4.06, -1.27, 0.9099999999999999], "openDegrees": 100, "sizeXYZ": [3.944999933242798, 0.20000000298023224, 10.479999542236328], "closedCenterBlender": [2.047499895095825, -1.2699999809265137, 6.210000038146973]}], "mounts": {"Door_Exit": [0.0, -2.19, 0.9099999999999999], "Wall": [0.0, 26.419999999999998, 5.11]}, "mountYaws": {"Wall": 180, "Door_Exit": 180}}]==])
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
