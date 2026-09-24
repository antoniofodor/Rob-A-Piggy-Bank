-- Executed in an isolated ServerStorage folder; always cleans up after itself.
-- SPEC and BUILDER_SOURCE are supplied by the local verification runner.
local storage = game:GetService("ServerStorage")
local testKit = Instance.new("Folder")
testKit.Name = "TreehouseInterior_Verification_" .. game:GetService("HttpService"):GenerateGUID(false)
testKit.Parent = storage
local hall
local checks = {}
local function check(value, message)
	assert(value, message)
	table.insert(checks, message)
end
local function frame(part)
	return CFrame.new(part.position[1], part.position[2], part.position[3], table.unpack(part.rotation))
end
local function close(a, b)
	return (a.Position-b.Position).Magnitude < 0.001 and a.LookVector:Dot(b.LookVector) > 0.9999
end
local ok, problem = xpcall(function()
	local templates = Instance.new("Folder")
	templates.Name = "Templates"
	templates.Parent = testKit
	for name, spec in SPEC.templates do
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = templates
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = Vector3.new(.15, .15, .15)
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.Parent = model
		model.PrimaryPart = root
		for mountName, at in spec.mounts do
			local attachment = Instance.new("Attachment")
			attachment.Name = mountName
			attachment.CFrame = frame(at)
			attachment.Parent = root
		end
		for _, data in spec.parts do
			local folder = model:FindFirstChild(data.group)
			if not folder then
				folder = Instance.new(if string.match(data.group, "^Panel_") or data.group == "Lock" then "Model" else "Folder")
				folder.Name = data.group
				folder.Parent = model
			end
			local part = Instance.new(if data.shape == "Wedge" then "WedgePart" else "Part")
			if part:IsA("Part") and data.shape == "Cylinder" then part.Shape = Enum.PartType.Cylinder end
			part.Name = data.name
			part.Size = Vector3.new(table.unpack(data.size))
			part.CFrame = frame(data)
			part.Anchored = true
			part.CanCollide = data.collide
			part.CanQuery = data.collide
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = data.transparency
			local rgb = SPEC.palette[data.material]
			part.Color = Color3.fromRGB(table.unpack(rgb))
			part.Material = Enum.Material.SmoothPlastic
			part.Parent = folder
			if data.name == "RequirementSign" then
				local gui = Instance.new("SurfaceGui")
				gui.Name = "RequirementGui"
				gui.Face = Enum.NormalId.Back
				gui.Parent = part
				local label = Instance.new("TextLabel")
				label.Name = "Requirement"
				label.Parent = gui
			end
		end
	end
	local module = Instance.new("ModuleScript")
	module.Name = "Builder"
	module.Source = BUILDER_SOURCE
	module.Parent = testKit
	local Builder = require(module)
	local at = CFrame.new(130, -10000, 240) * CFrame.Angles(0, math.rad(37), 0)
	hall = Builder.build(storage, at, {capacity=6, rebirths=0, requirement=function(room)
		if room <= 3 then return (room-1)*2 end
		return nil
	end})
	check(#hall.rooms == 1, "Six slots build exactly one room")
	check(#hall.rooms[1].Pedestals:GetChildren() == 6, "Six independent pedestal models")
	check(close(hall.lobby.PrimaryPart.Entry.WorldCFrame, at), "Entry aligns at a translated, rotated origin")
	check(close(hall.lobby.PrimaryPart.Exit.WorldCFrame, hall.rooms[1].PrimaryPart.Entry.WorldCFrame), "Vestibule and room connect without a gap")
	for i = 1, 6 do
		local room = hall.rooms[1]
		local slot = room.PrimaryPart:FindFirstChild(string.format("Slot_%02d", i))
		local inward = if i <= 3 then room:GetPivot().RightVector else -room:GetPivot().RightVector
		check(slot.WorldCFrame.LookVector:Dot(inward) > .999, "Collection plate faces the aisle: " .. i)
		check(Builder.piggyMount(hall, 1, i) ~= nil, "Piggy mount exists: " .. i)
	end
	local gate = hall.gates[1]
	local barrier = gate:FindFirstChild("GateBarrier", true)
	check(barrier.CanCollide and not gate:GetAttribute("Open"), "Rebirth gate starts physically locked")
	local jambs = {}
	for _, part in gate.Frame:GetChildren() do
		if part.Name == "DoorJamb" then
			table.insert(jambs, part)
			check(part.CanCollide, "Door jamb is physically solid")
			local x = math.abs(gate:GetPivot():PointToObjectSpace(part.Position).X)
			check(x-part.Size.X/2 <= barrier.Size.X/2+.001, "Closed barrier meets jamb without a bypass gap")
		end
	end
	check(#jambs == 2, "Two solid door jambs frame the passage")
	check(gate:FindFirstChild("Requirement", true).Text == "NEED 2 REBIRTHS", "Door label uses supplied requirement")
	Builder.setRebirths(hall, 2)
	check(barrier.CanCollide, "Meeting rebirth count cannot open onto missing floor")
	Builder.setRebirths(hall, 0)
	Builder.setCapacity(hall, 7)
	check(#hall.rooms == 2 and #hall.rooms[2].Pedestals:GetChildren() == 1, "Seventh slot appends a room and exactly one pedestal")
	check(close(hall.rooms[1].PrimaryPart.Exit.WorldCFrame, hall.rooms[2].PrimaryPart.Entry.WorldCFrame), "Repeated room connections align")
	check(not gate:GetAttribute("Open"), "Appending a room does not bypass the rebirth lock")
	local closed = gate.Panel_1_L.TimberPanel.CFrame
	Builder.setRebirths(hall, 2)
	check(not barrier.CanCollide and gate:GetAttribute("Open"), "Required rebirth opens the built passage")
	-- Check the actual colliders in an isolated area, far below the live map.
	hall.model.Parent = workspace
	task.wait()
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = {hall.model}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = {hall.model}
	overlap.RespectCanCollide = true
	for roomIndex, room in hall.rooms do
		for _, distance in {2, 9, 19, 29, 36} do
			local sample = room:GetPivot() * CFrame.new(0, 3, -distance)
			local floor = workspace:Raycast(sample.Position, -sample.UpVector*6, rayParams)
			check(floor ~= nil and floor.Instance.Name == "Floor", "Continuous aisle floor: room " .. roomIndex .. " at " .. distance)
			check(#workspace:GetPartBoundsInBox(sample, Vector3.new(3, 5, 3), overlap) == 0, "Avatar clearance: room " .. roomIndex .. " at " .. distance)
		end
	end
	local gateSample = gate:GetPivot()*CFrame.new(0, 3, 0)
	check(#workspace:GetPartBoundsInBox(gateSample, Vector3.new(3, 5, 3), overlap) == 0, "Open gate leaves a physically unobstructed passage")
	hall.model.Parent = storage
	for _, group in gate:GetChildren() do
		if group:IsA("Model") and string.match(group.Name, "^Panel_") then
			for _, part in group:GetDescendants() do
				if part:IsA("BasePart") then
					local localAt = gate:GetPivot():PointToObjectSpace(part.Position)
					check(localAt.Y-part.Size.Y/2 >= 13.4*28/22.55, "Open panel clears the 16.6-stud doorway: " .. group.Name .. "/" .. part.Name)
				end
			end
		end
	end
	Builder.setRebirths(hall, 0)
	check(close(gate.Panel_1_L.TimberPanel.CFrame, closed), "Relocking restores the original door pose")
	Builder.setSlot(hall, 1, 3, false)
	check(Builder.piggyMount(hall, 1, 3) == nil, "Removing one pedestal also removes its piggy attachment")
	check(#hall.rooms[1].Pedestals:GetChildren() == 5, "Other pedestals remain independently present")
	Builder.setSlot(hall, 1, 3, true)
	Builder.setSlot(hall, 1, 3, true)
	check(#hall.rooms[1].Pedestals:GetChildren() == 6, "Restoring a slot is idempotent")
	local count = #hall.model:GetDescendants()
	Builder.setCapacity(hall, 7)
	check(#hall.model:GetDescendants() == count, "Repeated capacity refresh creates no duplicates")
	Builder.setCapacity(hall, 0)
	check(#hall.rooms[1].Pedestals:GetChildren() == 0 and #hall.rooms[2].Pedestals:GetChildren() == 0, "Zero capacity removes all stations without touching the room shell")
	check(hall.lobby.PrimaryPart:FindFirstChild("Achievements") ~= nil, "Dedicated future achievement mount is retained")
	local base = hall.model:GetPivot()
	hall.model:PivotTo(CFrame.new(-90, -9000, 10)*CFrame.Angles(0, -1.1, 0))
	Builder.setRebirths(hall, 2)
	Builder.setRebirths(hall, 0)
	local actualLocal = gate.PrimaryPart.CFrame:ToObjectSpace(gate.Panel_1_L.TimberPanel.CFrame)
	local expectedLocal = gate.Panel_1_L.TimberPanel:GetAttribute("ClosedLocal")
	check(close(actualLocal, expectedLocal), "Doors remain correct after moving and rotating the whole hall")
	Builder.appendRoom(hall)
	Builder.setRebirths(hall, 99)
	check(not hall.gates[3]:GetAttribute("Open"), "Terminal gate remains closed when no future requirement exists")
	check(not pcall(function() Builder.setSlot(hall, 1, 7, true) end), "Invalid seventh room slot is rejected")
	check(not pcall(function() Builder.setCapacity(hall, -1) end), "Negative capacity is rejected")
end, debug.traceback)
if hall and hall.model then hall.model:Destroy() end
testKit:Destroy()
return game:GetService("HttpService"):JSONEncode({passed=ok, count=#checks, checks=checks, error=if ok then nil else problem})
