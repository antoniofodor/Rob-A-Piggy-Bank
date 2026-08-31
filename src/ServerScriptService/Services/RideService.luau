--!strict
--[[
	RideService

	Skateboards, bikes, scooters, hoverboards and the scrambler: what a player
	gets around on between plots.

	WHAT A RIDE IS FOR, AND WHAT IT IS NOT FOR

	"Speed is the currency" is the load-bearing rule this feature runs straight
	into. BASE_WALK_SPEED (16) is what the carry penalty, the three dog speeds,
	every fence snag and the length of a getaway are all calibrated against,
	and anything that makes a player faster than 16 invalidates all of them at
	once. Every ride in Config.RIDES does exactly that -- the scrambler doubles
	it -- so the entire design of this service is the set of conditions under
	which it is switched OFF:

		* You are carrying loot.          (protects the getaway)
		* Someone is carrying yours.      (protects the offence tree)
		* A fence has you snagged.        (protects the fence)
		* You are inside anybody's yard.  (protects the lawn)

	The first three are HeistService.rideBlockReason, because that module owns
	all of them. The fourth is geometry and lives here.

	What is left over is the street, which was the one part of this game that
	was pure walking: twelve plots at 64-stud spacing means a lap on foot is
	the better part of a minute of holding W. A ride buys that back, and it is
	the most VISIBLE thing anyone owns -- a house stands 70 studs back and a
	skin is on a piggy, but a board is under you, moving, in the middle of the
	street where everybody is. That is the whole purchase. Like a house, it
	confers nothing else.

	MOUNTING IS AUTOMATIC. There is no button and no prompt.

	Deliberate, and the same call the decorations made: this audience is mostly
	on a touchscreen, the HUD already carries a collect prompt, a steal prompt
	and a rebirth button, and "press E to get on your skateboard" is a rule to
	learn for something the game can just decide. You walk out of your gate and
	you are on it; you step onto a lawn and you are off it. The dismount is
	also a mechanic in its own right -- it is how a thief finds out, physically
	rather than through a message, that the getaway is run on foot.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RideModel = require(ReplicatedStorage.Shared.RideModel)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local HeistService = require(script.Parent.HeistService)

local RideService = {}

-- The model currently welded under each rider, and which ride it is.
local mounted: { [Player]: { model: Model, key: string, baseHip: number } } = {}

-- The last reason a player was refused, so the same message is not fired
-- every tick. Walking around your own lawn would otherwise be a toast every
-- tenth of a second.
local lastReason: { [Player]: string } = {}

-- Who has already been told why their ride comes off at a gate.
--
-- Said ONCE per session and then never again. Silence is wrong -- a board
-- that vanishes with no explanation reads as the expensive thing they just
-- bought being broken -- but so is a toast every time somebody steps onto
-- their own lawn, which is a thing they do constantly. Once is the whole
-- budget.
local toldAboutGates: { [Player]: boolean } = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function rides(data: any)
	if type(data.rides) ~= "table" then
		data.rides = { owned = {}, equipped = "" }
	end
	if type(data.rides.owned) ~= "table" then
		data.rides.owned = {}
	end
	if type(data.rides.equipped) ~= "string" then
		data.rides.equipped = ""
	end
	return data.rides
end

-- ============================================================
-- MOUNTING
-- ============================================================

-- The FLOOR under a character, in world space, derived from the root rather
-- than raycast for it.
--
-- HipHeight plus half the root part is the standard formula. Measured against
-- a raycast on a real R15 character standing on a plot it came out 0.002
-- studs off, which is the whole reason it is used instead: a raycast would
-- also have to decide what counts as ground, and a decoration or a coin pile
-- under the player would answer it wrongly.
--
-- Note this returns the same value whatever HipHeight is set to -- raising
-- HipHeight lifts the root by exactly as much as it subtracts. That is what
-- makes the mount work: the rider goes UP onto the deck and the wheels stay
-- on the road.
local function floorCFrame(root: BasePart, humanoid: Humanoid): CFrame
	return root.CFrame * CFrame.new(0, -(humanoid.HipHeight + root.Size.Y / 2), 0)
end

local function dismount(player: Player)
	local current = mounted[player]
	if not current then
		return
	end
	mounted[player] = nil
	current.model:Destroy()

	-- Back down off the deck. Restoring the REMEMBERED value rather than
	-- subtracting the ride's stand height, so a respawn in between (which
	-- gives the new humanoid the rig default) cannot leave a player walking
	-- around permanently one stud taller than everybody else.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.HipHeight = current.baseHip
	end

	HeistService.setRideMultiplier(player, 1)
	RideService.push(player)
end

-- Is the model we think is mounted still on the character we think it is on?
--
-- Dying destroys the character and every welded model with it, but leaves
-- `mounted` holding a reference and -- far worse -- leaves the multiplier set
-- inside HeistService. A thief who respawned mid-chase would have walked away
-- at scrambler speed with no board visible and nothing on screen to explain
-- it. Respawning is not something this module gets told about, so it checks.
local function mountIsLive(player: Player): boolean
	local current = mounted[player]
	return current ~= nil
		and current.model.Parent ~= nil
		and current.model.Parent == player.Character
end

local function mount(player: Player, key: string)
	local spec = Config.getRide(key)
	local character = player.Character
	if not spec or not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	-- THE RIDER GOES UP; THE RIDE STAYS ON THE ROAD.
	--
	-- Every ride is authored with y = 0 at the ground, so seating one at the
	-- character's feet buries the rider's shins in their own deck -- measured
	-- at 0.98 studs of skateboard through the ankles. HipHeight is what fixes
	-- it: raising it lifts the character clear by exactly the height of the
	-- surface they are standing on, and the model then goes on the floor
	-- underneath to fill the gap.
	--
	-- Order matters. HipHeight is set FIRST and the placement is computed from
	-- the new value, because the weld locks in whatever offset exists at that
	-- moment and the character has not physically risen yet. Reading the
	-- position back after setting it would catch the character mid-rise and
	-- weld the board a stud into the air.
	local baseHip = humanoid.HipHeight
	humanoid.HipHeight = baseHip + (spec.stand or 0)

	local at = floorCFrame(root, humanoid)

	local model = RideModel.build(key)
	model:PivotTo(at)
	RideModel.addTrail(model, spec.accent)

	-- Welded, not anchored. An anchored part welded to a humanoid pins the
	-- humanoid in place; every part is already Massless so this adds nothing
	-- to how the character walks or jumps.
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end

	model.Parent = character

	mounted[player] = { model = model, key = key, baseHip = baseHip }
	HeistService.setRideMultiplier(player, spec.multiplier)
	RideService.push(player)
end

-- ============================================================
-- THE GATE
-- ============================================================

-- Nil when the player should be riding, otherwise why not.
--
-- `silent` reasons are the normal state of affairs rather than a refusal --
-- standing on your own lawn is not a rejection worth a toast, it is just
-- where you are. Only the heist reasons are worth telling somebody about,
-- and only once each.
local function blockReason(player: Player, data: any): (string?, boolean)
	local equipped = rides(data).equipped
	if equipped == "" or not Config.getRide(equipped) then
		return "none", true
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return "no character", true
	end

	local heist = HeistService.rideBlockReason(player)
	if heist then
		return heist, false
	end

	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return "no character", true
	end

	-- TWO TESTS, AND THE REDUNDANCY IS DELIBERATE.
	--
	-- `isOnStreet` is the positive rule and the one that matches what a player
	-- is told: rides are for the street. It is narrower than "not in a yard" --
	-- it also rules out the woodland behind the plots and the twelve-stud
	-- alleys between neighbouring yards, which are public ground but are not a
	-- street, and which nobody should be crossing at 33 studs a second.
	--
	-- `yardContaining` is a veto on top of it. The two cannot disagree with the
	-- layout as it stands -- the corridor stops at the front fences -- but if
	-- the plots are ever moved, one of these is balance-critical and the other
	-- is tidiness, and this is the order that fails safe. A ride inside a yard
	-- breaks the fence, the dog and the steal; a ride in the woods is only
	-- untidy.
	if PlotService.yardContaining(root.Position) then
		return "on a lawn", true
	end
	if not Config.isOnStreet(root.Position) then
		return "off the street", true
	end

	return nil, true
end

local function step()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		if data then
			local reason, silent = blockReason(player, data)
			local equipped = rides(data).equipped

			-- A mount that died with its character counts as no mount, and has
			-- to be cleared through dismount rather than forgotten, because the
			-- speed multiplier lives in HeistService and outlives the model.
			if mounted[player] and not mountIsLive(player) then
				dismount(player)
			end

			if reason then
				if mounted[player] then
					dismount(player)
					if not silent and lastReason[player] ~= reason then
						notify(player, reason, "warn")
					elseif silent and not toldAboutGates[player] then
						toldAboutGates[player] = true
						notify(player, "Rides are for the street -- you hop off at the gate.", "warn")
					end
				end
				lastReason[player] = reason
			else
				lastReason[player] = nil
				local current = mounted[player]
				if not current then
					mount(player, equipped)
				elseif current.key ~= equipped then
					-- Swapped ride while out on the street.
					dismount(player)
					mount(player, equipped)
				end
			end
		end
	end
end

-- ============================================================
-- BUYING AND EQUIPPING
-- ============================================================

function RideService.buy(player: Player, key: string)
	local spec = Config.RIDES[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end

	local owned = rides(data).owned

	-- Already owned? Then this is a toggle, not a purchase -- the same shape
	-- as decorations and accessories, and for the same reason: putting a ride
	-- away has to be possible, and toggling beats a refund because no coins
	-- move and there is nothing to farm by buying and selling.
	if owned[key] then
		if rides(data).equipped == key then
			rides(data).equipped = ""
			notify(player, ("%s put away."):format(spec.name), "good")
		else
			rides(data).equipped = key
			notify(player, ("Riding the %s."):format(spec.name), "good")
		end
		DataService.save(player)
		RideService.push(player)
		return
	end

	if data.coins < spec.cost then
		notify(player, ("Need %d more coins for the %s."):format(spec.cost - data.coins, spec.name), "warn")
		return
	end

	data.coins -= spec.cost
	owned[key] = true
	-- Straight onto it. Buying a ride and then having to tap it again to use
	-- it is a second step for a decision already made.
	rides(data).equipped = key

	notify(player, ("%s unlocked! Head out to the street."):format(spec.name), "good")
	DataService.save(player)
	RideService.push(player)
end

function RideService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local owned = rides(data).owned
	local equipped = rides(data).equipped

	local list = {}
	for key, spec in pairs(Config.RIDES) do
		list[key] = {
			name = spec.name,
			order = spec.order,
			cost = spec.cost,
			blurb = spec.blurb,
			-- Shown as a percentage rather than a multiplier: "+35% on the
			-- street" is a sentence a nine year old reads once, where "x1.35"
			-- is one they have to work out.
			boost = math.floor((spec.multiplier - 1) * 100 + 0.5),
			owned = owned[key] == true,
			equipped = equipped == key,
		}
	end

	Remotes.get("RideState"):FireClient(player, {
		rides = list,
		riding = mounted[player] ~= nil,
	})
end

-- Everything the admin wipe has to clear, in one place, so a field added here
-- cannot be forgotten there.
function RideService.clear(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.rides = { owned = {}, equipped = "" }
	dismount(player)
	RideService.push(player)
end

function RideService.start()
	Remotes.get("RideRequest").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		RideService.buy(player, key)
	end)

	Players.PlayerRemoving:Connect(function(player)
		mounted[player] = nil
		lastReason[player] = nil
		toldAboutGates[player] = nil
	end)

	-- Dying drops the ride, the same way it drops loot. The model goes with
	-- the old character on its own; this is here for the multiplier, which
	-- does not.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			dismount(player)
		end)
	end)

	-- Polled, not event-driven, and for the reason the guard dog's patrol was
	-- rewritten from a long task.wait: a player can cross a fence line by any
	-- route, and the four things that gate a ride change independently of each
	-- other and of anything this module could listen to.
	--
	-- Ten times a second. The work is a rectangle test per plot per player --
	-- 144 comparisons a tick at a full server -- and the cost of being slower
	-- is overshoot: at the scrambler's 33.6 studs/sec, a tenth of a second is
	-- 3.4 studs past the fence line before the board disappears. A quarter of
	-- a second would be eight, which is far enough into a yard to notice.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		step()
	end)
end

return RideService
