--!strict
-- Standalone, server-owned asset assembly. No currency, remotes or save changes.
-- Templates and this module live together under BeehiveCottageInteriorKit.
local RunService = game:GetService("RunService")
local Builder = {}
local templates = script.Parent:WaitForChild("Templates")

export type Hall = {
	model: Model,
	lobby: Model,
	rooms: {Model},
	gates: {Model},
	requirement: (number) -> number?,
	rebirths: number,
	capacity: number,
}

local function whole(value: number, name: string): number
	assert(value == value and value >= 0 and value < math.huge and value % 1 == 0, name .. " must be a nonnegative integer")
	return value
end

local function serverOnly()
	assert(not RunService:IsRunning() or RunService:IsServer(), "Interior assembly and unlocks belong to the server")
end

local function clone(name: string, parent: Instance, at: CFrame): Model
	local source = templates:FindFirstChild(name)
	assert(source and source:IsA("Model"), "Missing interior template: " .. name)
	local model = source:Clone()
	model:PivotTo(at)
	model.Parent = parent
	return model
end

local function anchor(model: Model, name: string): Attachment
	local root = model.PrimaryPart
	assert(root, "Template needs a Root PrimaryPart")
	local value = root:FindFirstChild(name)
	assert(value and value:IsA("Attachment"), "Missing anchor: " .. name)
	return value
end

local function atConnection(model: Model, name: string, target: CFrame)
	-- Works when a template's connection is offset from its pivot, as in the lobby.
	local localFrame = model:GetPivot():ToObjectSpace(anchor(model, name).WorldCFrame)
	model:PivotTo(target * localFrame:Inverse())
end

local function setGate(gate: Model, open: boolean, required: number?)
	local root = gate.PrimaryPart :: BasePart
	for _, panel in gate:GetChildren() do
		if panel:IsA("Model") and string.match(panel.Name, "^Panel_") then
			for _, part in panel:GetDescendants() do
				if part:IsA("BasePart") then
					local stored = part:GetAttribute("ClosedLocal")
					local closed: CFrame
					if typeof(stored) == "CFrame" then
						closed = stored
					else
						closed = root.CFrame:ToObjectSpace(part.CFrame)
						part:SetAttribute("ClosedLocal", closed)
					end
					local row = (tonumber(string.match(panel.Name, "^Panel_(%d)")) :: number)-1
					local offset = if open then CFrame.new(0, (16.1-(2.24+row*4.45))*33/22.55, -(1.1+row*.85)) else CFrame.identity
					part.CFrame = root.CFrame * offset * closed
				end
			end
		end
	end
	local barrier = gate:FindFirstChild("GateBarrier", true) :: BasePart
	barrier.CanCollide = not open
	barrier.CanQuery = not open
	local lock = gate:FindFirstChild("Lock") :: Model
	for _, child in lock:GetDescendants() do
		if child:IsA("BasePart") then
			child.Transparency = if open then 1 else 0
		elseif child:IsA("SurfaceGui") then
			child.Enabled = not open
		elseif child:IsA("TextLabel") then
			child.Text = if required then string.format("NEED %d REBIRTH%s", required, if required == 1 then "" else "S") else "END OF HALL"
		end
	end
	gate:SetAttribute("Open", open)
	gate:SetAttribute("RequiredRebirths", required)
end

local function refreshGates(hall: Hall)
	for i, gate in hall.gates do
		local required = hall.requirement(i+1)
		if required ~= nil then whole(required, "door requirement") end
		-- Never open onto missing floor, even if the configured requirement is met.
		setGate(gate, i < #hall.rooms and required ~= nil and hall.rebirths >= required, required)
	end
end

function Builder.appendRoom(hall: Hall): Model
	serverOnly()
	local i = #hall.rooms+1
	local previous = if i == 1 then hall.lobby else hall.rooms[i-1]
	local room = clone("RoomShell", hall.model, CFrame.identity)
	room.Name = string.format("Room_%02d", i)
	atConnection(room, "Entry", anchor(previous, "Exit").WorldCFrame)
	local slots = Instance.new("Folder")
	slots.Name = "Pedestals"
	slots.Parent = room
	table.insert(hall.rooms, room)
	local gate = clone("RebirthGate", hall.model, anchor(room, "Exit").WorldCFrame)
	gate.Name = string.format("Gate_%02d", i)
	table.insert(hall.gates, gate)
	refreshGates(hall)
	return room
end

function Builder.setSlot(hall: Hall, roomIndex: number, slotIndex: number, unlocked: boolean): Model?
	serverOnly()
	whole(roomIndex, "room index")
	whole(slotIndex, "slot index")
	assert(slotIndex >= 1 and slotIndex <= 6, "A room has exactly six slots")
	local room = hall.rooms[roomIndex]
	assert(room, "Room is not built")
	local folder = room:FindFirstChild("Pedestals") :: Folder
	local name = string.format("Pedestal_%02d", slotIndex)
	local existing = folder:FindFirstChild(name)
	if not unlocked then
		if existing then existing:Destroy() end
		return nil
	end
	if existing then return existing :: Model end
	local pedestal = clone("Pedestal", folder, anchor(room, string.format("Slot_%02d", slotIndex)).WorldCFrame)
	pedestal.Name = name
	pedestal:SetAttribute("RoomIndex", roomIndex)
	pedestal:SetAttribute("SlotIndex", slotIndex)
	pedestal:SetAttribute("PlotIndex", (roomIndex-1)*6+slotIndex)
	return pedestal
end

function Builder.setCapacity(hall: Hall, capacity: number)
	serverOnly()
	whole(capacity, "capacity")
	while #hall.rooms < math.max(1, math.ceil(capacity/6)) do Builder.appendRoom(hall) end
	for roomIndex = 1, #hall.rooms do
		for slotIndex = 1, 6 do
			Builder.setSlot(hall, roomIndex, slotIndex, (roomIndex-1)*6+slotIndex <= capacity)
		end
	end
	hall.capacity = capacity
	refreshGates(hall)
end

function Builder.setRebirths(hall: Hall, rebirths: number)
	serverOnly()
	hall.rebirths = whole(rebirths, "rebirths")
	refreshGates(hall)
end

function Builder.build(parent: Instance, at: CFrame, options: {
	capacity: number?, rebirths: number?, requirement: (number) -> number?,
}): Hall
	serverOnly()
	assert(type(options.requirement) == "function", "Supply the game's room -> rebirth requirement function")
	local model = Instance.new("Model")
	model.Name = "BeehiveCottageInterior"
	model.Parent = parent
	local lobby = clone("AchievementVestibule", model, CFrame.identity)
	atConnection(lobby, "Entry", at)
	local hall: Hall = {model=model, lobby=lobby, rooms={}, gates={},
		requirement=options.requirement, rebirths=whole(options.rebirths or 0, "rebirths"), capacity=0}
	Builder.setCapacity(hall, options.capacity or 0)
	return hall
end

function Builder.piggyMount(hall: Hall, roomIndex: number, slotIndex: number): Attachment?
	local room = hall.rooms[roomIndex]
	if not room then return nil end
	local folder = room:FindFirstChild("Pedestals")
	local pedestal = if folder then folder:FindFirstChild(string.format("Pedestal_%02d", slotIndex)) else nil
	return if pedestal and pedestal:IsA("Model") then anchor(pedestal, "Piggy") else nil
end

return Builder
