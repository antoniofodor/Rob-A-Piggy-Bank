--!strict
--[[
	GadgetFlight

	Draws every thrown gadget on THIS client. The server decides what a throw
	hit and never draws it; each client flies its own copy along
	`Config.throwPointAt`, oriented by `GadgetModel.flightCFrame`, from the
	`GadgetFlight` broadcast, and stops it where `GadgetFlightEnd` says the
	server's real one stopped.

	WHY NOT A SERVER MODEL. That is what it was, and a part the server moves
	every frame reaches a client in lurches -- measured on a plunger that was
	correctly cup-first along its arc on the server, and read on the thrower's
	screen as not moving through the air at all. A client copy runs on the
	client's own frame clock, so it is as smooth as anything else on screen.

	THE THROWER SEES THEIRS AT ONCE. Waiting for the broadcast would put a
	ping of dead air between the arm coming over and the plunger leaving it,
	which is the whole moment the throw animation exists to sell. So
	`ThrowAim` calls `predict` at the release, the same launch delay the
	server uses is waited out locally, and the copy leaves from where the
	thrower's own hand is on their own screen. When the broadcast for that
	throw arrives it is matched to the prediction rather than drawn twice.

	TIME IS SERVER TIME for everybody else: the broadcast carries the
	launch's `GetServerTimeNow`, so a copy that arrives late starts partway
	along its arc rather than a ping behind the real one.

	PRESENTATION ONLY. Nothing here can hit anything, refund anything or tell
	anybody they were hit. A local copy that stops on a wall the server did
	not hit simply waits there, hidden, for the server's end.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GadgetFX = require(ReplicatedStorage.Shared.GadgetFX)
local GadgetModel = require(ReplicatedStorage.Shared.GadgetModel)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GadgetFlight = {}

type Flight = {
	key: string,
	spec: any,
	model: Model?,
	origin: Vector3,
	velocity: Vector3,
	-- os.clock() the flight left the hand on this client's clock.
	startAt: number,
	spin: number,
	id: number?,
	ended: boolean,
	-- Where the server said it stopped, once it has.
	stopAt: Vector3?,
	lingerUntil: number?,
}

local flights: { Flight } = {}
local folder: Folder? = nil

-- Local predictions still waiting for their broadcast, oldest first. A
-- throw has a 1.5 second cooldown, so there is almost never more than one.
local pending: { Flight } = {}

-- How long a copy stays visible where it stopped. A beat, so a plunger
-- that hits a wall is SEEN to hit it rather than vanishing in mid-air.
local LINGER = 0.12

local function ensureFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "GadgetFlights"
	f.Parent = workspace
	folder = f
	return f
end

local function spawnModel(flight: Flight)
	local ok, model = pcall(GadgetModel.build, flight.key, true)
	if not ok or not model then
		return
	end
	model.Name = "ThrownGadget"
	model:PivotTo(GadgetModel.flightCFrame(flight.spec, flight.origin, flight.velocity, 0, flight.spin))
	model.Parent = ensureFolder()
	flight.model = model
end

local function finish(flight: Flight)
	if flight.model then
		flight.model:Destroy()
		flight.model = nil
	end
	flight.ended = true
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function step()
	local now = os.clock()
	local ignore: { Instance } = { ensureFolder() }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore

	for i = #flights, 1, -1 do
		local flight = flights[i]
		local t = now - flight.startAt

		if flight.ended then
			table.remove(flights, i)
		elseif flight.lingerUntil then
			if now >= flight.lingerUntil then
				finish(flight)
				table.remove(flights, i)
			end
		elseif t >= 0 then
			if not flight.model then
				spawnModel(flight)
			end
			local model = flight.model
			local cf = GadgetModel.flightCFrame(flight.spec, flight.origin, flight.velocity, t, flight.spin)
			local pos = cf.Position

			-- STOPPED BY THE SERVER: snap to where it really ended. Checked by
			-- distance along the path rather than by time, because the end
			-- message arrives a ping late and the copy may already be past it.
			local stop = flight.stopAt
			local flat = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(flight.origin.X, 0, flight.origin.Z)).Magnitude
			local stopFlat = if stop
				then (Vector3.new(stop.X, 0, stop.Z) - Vector3.new(flight.origin.X, 0, flight.origin.Z)).Magnitude
				else math.huge

			if stop and flat >= stopFlat - 0.05 then
				if model then
					model:PivotTo(cf.Rotation + stop)
				end
				flight.lingerUntil = now + LINGER
			elseif t >= Config.THROW.maxSeconds then
				-- Only the off-the-world backstop: a real throw always lands.
				if model then
					model:PivotTo(cf)
				end
				flight.lingerUntil = now + LINGER
			else
				-- The world, locally. Same segment cast the server makes, so a
				-- fence stops the copy where it stops the real one.
				local prevT = math.max(0, t - 1 / 30)
				local prev = Config.throwPointAt(flight.origin, flight.velocity, prevT)
				local hit = workspace:Raycast(prev, pos - prev, params)
				if hit then
					if model then
						model:PivotTo(cf.Rotation + hit.Position)
					end
					flight.lingerUntil = now + LINGER
				elseif model then
					model:PivotTo(cf)
				end
			end
		end
	end
end

-- The thrower's own copy, drawn the moment the arm lets go.
function GadgetFlight.predict(key: string, origin: Vector3, velocity: Vector3, delay: number)
	local spec = Config.GADGETS[key]
	if not spec then
		return
	end
	local flight: Flight = {
		key = key,
		spec = spec,
		model = nil,
		origin = origin,
		velocity = velocity,
		startAt = os.clock() + delay,
		spin = math.random() * math.pi * 2,
		id = nil,
		ended = false,
		stopAt = nil,
		lingerUntil = nil,
	}
	table.insert(flights, flight)
	table.insert(pending, flight)
	-- A throw the server refused never gets a broadcast; drop the claim
	-- rather than letting it swallow the next real one.
	task.delay(delay + 1.5, function()
		local i = table.find(pending, flight)
		if i then
			table.remove(pending, i)
		end
	end)
end

-- Drops the thrower's newest unclaimed prediction: the server refused it.
function GadgetFlight.cancelPrediction()
	local flight = table.remove(pending)
	if flight then
		finish(flight)
	end
end

local function byId(id: number): Flight?
	for _, flight in ipairs(flights) do
		if flight.id == id then
			return flight
		end
	end
	return nil
end

function GadgetFlight.start()
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(step)
		if not ok then
			warn("[GadgetFlight] " .. tostring(err))
		end
	end)

	Remotes.get("GadgetFlight").OnClientEvent:Connect(function(thrower, key, origin, velocity, serverTime, id)
		if typeof(origin) ~= "Vector3" or typeof(velocity) ~= "Vector3" or type(id) ~= "number" then
			return
		end
		local spec = Config.GADGETS[key]
		if not spec then
			return
		end
		if thrower == Players.LocalPlayer then
			local mine = table.remove(pending, 1)
			if mine then
				mine.id = id
				return
			end
		end
		local elapsed = workspace:GetServerTimeNow() - (serverTime :: number)
		table.insert(flights, {
			key = key,
			spec = spec,
			model = nil,
			origin = origin,
			velocity = velocity,
			startAt = os.clock() - math.max(0, elapsed),
			spin = math.random() * math.pi * 2,
			id = id,
			ended = false,
			stopAt = nil,
			lingerUntil = nil,
		})
	end)

	-- THE ZAPPER'S ARC, drawn here for everybody including the zapper: it is
	-- a quarter of a second of lightning, and there is no flight to predict.
	Remotes.get("GadgetZap").OnClientEvent:Connect(function(_zapper, from, to)
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
			return
		end
		GadgetFX.arc(ensureFolder(), from, to, 0.25)
	end)

	-- KNOCKED DOWN BY A GADGET. The server has already stunned us for
	-- `seconds`; this makes it look like a fall. Same shape as the fence
	-- knockback in ClientMain, for the same measured reason:
	-- `PlatformStand` is what lets the push land at all, since a stunned
	-- humanoid otherwise damps every horizontal velocity to nothing. A small
	-- spin about the side axis tips the body over backwards, away from
	-- whoever threw it.
	Remotes.get("GadgetKnock").OnClientEvent:Connect(function(direction, seconds, knock)
		if typeof(direction) ~= "Vector3" or type(seconds) ~= "number" or type(knock) ~= "table" then
			return
		end
		local player = Players.LocalPlayer
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			return
		end
		local flat = Vector3.new(direction.X, 0, direction.Z)
		flat = if flat.Magnitude > 1e-3 then flat.Unit else -root.CFrame.LookVector
		local back = math.clamp(tonumber(knock.back) or 0, 0, 20)
		local up = math.clamp(tonumber(knock.up) or 0, 0, 20)

		humanoid.PlatformStand = true
		root.AssemblyLinearVelocity = flat * back + Vector3.new(0, up, 0)
		root.AssemblyAngularVelocity = flat:Cross(Vector3.yAxis) * -7

		-- Cleared by CHARACTER, not a bare flag: a respawn mid-fall hands out
		-- a new humanoid, and this timer must not touch the wrong one.
		task.delay(math.clamp(seconds, 0.2, 3), function()
			if player.Character == character and humanoid.Health > 0 then
				humanoid.PlatformStand = false
				root.AssemblyAngularVelocity = Vector3.zero
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end)

	Remotes.get("GadgetFlightEnd").OnClientEvent:Connect(function(id, stopAt)
		if type(id) ~= "number" or typeof(stopAt) ~= "Vector3" then
			return
		end
		local flight = byId(id)
		if not flight then
			return
		end
		-- The thrower's copy left from their own screen's hand, so the
		-- server's stop point is re-expressed along THEIR arc: the same
		-- horizontal distance from their origin, which is what the step
		-- compares against.
		flight.stopAt = stopAt
	end)
end

return GadgetFlight
