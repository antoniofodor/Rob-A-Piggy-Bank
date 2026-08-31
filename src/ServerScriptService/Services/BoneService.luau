--!strict
--[[
	BoneService

	Throwing a bone to bait a guard dog off its post.

	This is the offence tree's answer to the one defence purchase that had no
	answer. Why bones exist and why they don't simply delete the dog is
	argued in Config.BONES; this file is only the mechanism.

	Two decisions worth knowing before reading the code:

	THE CLIENT NEVER SENDS A POSITION. It sends a bone key and nothing else.
	The server picks the target itself from its own dog positions, so there is
	no coordinate to forge and no range check to defeat -- the usual shape of
	a thrown-object exploit has nowhere to attach.

	THE THROW AUTO-TARGETS the nearest dog that can actually take the bone.
	There is no aiming. Most of this audience is on a touchscreen, where
	lobbing an object at a moving dog is a fight with the camera rather than
	with the defender -- and "get it near the dog" was never the interesting
	decision. The interesting decisions are which bone to spend, and whether
	to spend one at all.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local GuardDog = require(script.Parent.GuardDog)
local BoneModel = require(ReplicatedStorage.Shared.BoneModel)

local BoneService = {}

local lastThrow: { [Player]: number } = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Saves written before schema 7 have no stock table. Reconcile fills it on
-- load, but every reader guards anyway: a nil here would be a nil index in
-- the middle of a throw rather than a clean zero.
local function stock(data: any): { [string]: number }
	if type(data.consumables) ~= "table" then
		data.consumables = {}
	end
	return data.consumables
end

-- ============================================================
-- FLIGHT
-- ============================================================

-- Lerps the bone along a fixed parabola from hand to ground.
--
-- Not physics. An unanchored part rolls down a slope, catches a fence post,
-- or drops through the seam between two slabs, and the dog then walks to
-- wherever it ended up instead of where it was thrown. Everything else that
-- moves in this game is anchored and lerped for the same reason.
local function arc(model: Model, from: Vector3, to: Vector3)
	local peak = 6 + (to - from).Magnitude * 0.08
	local spin = math.random() * math.pi * 2
	local started = os.clock()

	while model.Parent do
		local t = (os.clock() - started) / Config.BONE_FLIGHT
		if t >= 1 then
			break
		end
		local pos = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * peak, 0)
		model:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 9, spin, t * 5))
		RunService.Heartbeat:Wait()
	end

	if model.Parent then
		-- Rolled onto its side so it reads as lying on the grass rather than
		-- standing on end.
		model:PivotTo(CFrame.new(to) * CFrame.Angles(0, spin, math.rad(90)))
	end
end

-- ============================================================
-- TARGETING
-- ============================================================

-- The nearest dog to `from` that is both close enough and able to take a bone.
--
-- Returns the reason it found nothing, so a refusal can name it. "No dog in
-- range" and "that dog is already asleep" are completely different situations
-- to a player standing at a fence, and one message for both is the kind of
-- silence that reads as a broken button.
local function findTarget(from: Vector3, breaksChase: boolean): (any?, string?)
	local best: any = nil
	local bestDist = math.huge
	local nearestAny = math.huge
	local sawChasing = false
	local sawResting = false

	for _, plot in ipairs(PlotService.getAll()) do
		local dog = plot.dog
		if dog.level > 0 then
			local dist = (dog.body.Position - from).Magnitude
			-- Tracked at ANY distance, not just within range. Judging "is
			-- there a dog here at all" from the in-range set alone made the
			-- too-far message unreachable, so standing just outside throwing
			-- distance of a dog in plain sight said there was no dog.
			nearestAny = math.min(nearestAny, dist)

			if dist <= Config.BONE_THROW_RANGE then
				if dog.lured then
					sawResting = true
				elseif dog.chasing then
					if breaksChase then
						if dist < bestDist then
							best, bestDist = plot, dist
						end
					else
						sawChasing = true
					end
				elseif os.clock() < dog.busyUntil then
					sawResting = true
				elseif dist < bestDist then
					best, bestDist = plot, dist
				end
			end
		end
	end

	if best then
		return best, nil
	end
	-- Chasing beats resting when both are in range: it is the one refusal
	-- that names a rule the player can act on.
	if sawChasing then
		return nil, "It has already seen you -- only a Golden Bone stops a chase."
	end
	if sawResting then
		return nil, "That dog is already off duty."
	end
	if nearestAny < math.huge then
		return nil, "Too far -- get closer to the dog."
	end
	return nil, "There is no guard dog near you."
end

-- ============================================================
-- THROWING
-- ============================================================

function BoneService.throw(player: Player, key: string)
	local spec = Config.BONES[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end

	local root = getRoot(player)
	if not root then
		return
	end

	local held = stock(data)[key] or 0
	if held <= 0 then
		notify(player, ("You have no %s left."):format(spec.name), "warn")
		return
	end

	local now = os.clock()
	if now - (lastThrow[player] or 0) < Config.BONE_THROW_COOLDOWN then
		return
	end

	-- Everything that can refuse is checked BEFORE a bone leaves the pocket.
	-- A bone spent on a dog that was never going to take it is
	-- indistinguishable from the item not working.
	local plot, reason = findTarget(root.Position, spec.breaksChase)
	if not plot then
		notify(player, reason or "Nothing to throw that at.", "warn")
		return
	end

	lastThrow[player] = now
	stock(data)[key] = held - 1
	BoneService.push(player)

	local dog = plot.dog
	local nap = Config.getBoneNap(key, dog.level)

	-- `true` for the glow: this one lands in the grass and has to be findable
	-- from the far side of a fence. The shop icon asks for the same model
	-- without it, since a ViewportFrame ignores lights in the scene.
	local model = BoneModel.build(key, true)
	-- BoneModel names its models per style, which is right for the shop
	-- icons but not for the one lying in the grass: everything in workspace
	-- that belongs to a throw should be findable under one name.
	model.Name = "ThrownBone"
	model.Parent = workspace

	-- Lands just SHORT of the dog rather than on it, so there is always a trot
	-- over to it. That walk is the only thing that tells the plot's owner
	-- their dog was bought off rather than broken.
	local toward = dog.body.Position
	local from = root.Position + Vector3.new(0, 2, 0)
	local flat = Vector3.new(toward.X - from.X, 0, toward.Z - from.Z)
	local back = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, 1)
	local landing = toward - back * 3.5
	landing = Vector3.new(landing.X, dog.originCF.Position.Y + 0.6, landing.Z)

	task.spawn(function()
		arc(model, from, landing)

		local ok, why = GuardDog.lure(dog, model, nap, spec.breaksChase)
		if not ok then
			-- The dog's state changed during the half-second the bone was in
			-- the air. Give it back rather than charge for a race the player
			-- had no way to see coming.
			if model.Parent then
				model:Destroy()
			end
			stock(data)[key] = (stock(data)[key] or 0) + 1
			BoneService.push(player)
			notify(player, ("Too late -- %s Bone returned."):format(why or "it was busy."), "warn")
			return
		end

		local tier = Config.getDogTier(dog.level)
		notify(player, ("%s took the %s -- %d seconds."):format(
			if tier then tier.name else "The dog", spec.name, math.floor(nap + 0.5)), "good")

		local owner = plot.owner
		if owner and owner ~= player then
			notify(owner, ("%s threw a %s to your dog!"):format(player.DisplayName, spec.name), "warn")
		end
	end)

	DataService.save(player)
end

-- ============================================================
-- BUYING
-- ============================================================

function BoneService.buy(player: Player, key: string)
	local spec = Config.BONES[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end

	if data.coins < spec.cost then
		notify(player, ("Need %d more coins for a %s."):format(spec.cost - data.coins, spec.name), "warn")
		return
	end

	data.coins -= spec.cost
	stock(data)[key] = (stock(data)[key] or 0) + 1

	notify(player, ("%s bought. Press G near a guard dog."):format(spec.name), "good")
	DataService.save(player)
	BoneService.push(player)
end

-- ============================================================
-- STATE
-- ============================================================

function BoneService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local held = stock(data)
	local bones: { [string]: any } = {}
	for key, spec in pairs(Config.BONES) do
		bones[key] = {
			name = spec.name,
			order = spec.order,
			cost = spec.cost,
			nap = spec.nap,
			colour = spec.colour,
			blurb = spec.blurb,
			breaksChase = spec.breaksChase,
			held = held[key] or 0,
		}
	end

	Remotes.get("GearState"):FireClient(player, bones)
end

function BoneService.start()
	Remotes.get("BoneThrow").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		BoneService.throw(player, key)
	end)

	Remotes.get("GearRequest").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		BoneService.buy(player, key)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)
end

return BoneService
