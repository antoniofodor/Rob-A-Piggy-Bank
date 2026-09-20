--!strict
--[[
	Pets -- the follower, and where it goes.

	RUNS ENTIRELY ON THE CLIENT, and nothing about a pet exists on the server
	except one string. The server publishes `Config.PET_ATTRIBUTE` on the
	PLAYER and never touches a part; every machine builds and drives what it
	can see for itself.

	That is the call the animated skins, the moat and `HouseFX` all already
	make, and the arithmetic is the same: driving eight pets server-side is a
	CFrame write per part per frame, replicated to everybody -- roughly a
	dozen parts each at sixty frames is thousands of property updates a second
	to say something every client could derive from a character position it
	already has. A pet CONFERS NOTHING, so there is no outcome riding on where
	it is, which is exactly what makes deriving it safe. Compare the officer,
	which IS posed on the server: the catch depends on his position, so the
	server has to own it.

	================================================================
	THE THREE TRAPS, AND WHY THEY COLLAPSE INTO TWO RULES
	================================================================

	`docs/MASTER-PLAN.md` calls the integration the known trap and names three
	places a pet has to be handled: the wheelie bin, mounting a ride, and the
	arrest teleport. All three are the same failure -- something attached to a
	character that does not follow the character through a state change --
	and it has already happened once, when `StealthService.hideCharacter`
	walked the descendants ONCE and left a board mounted afterwards floating
	as a motorbike over a bin.

	THE FIX IS NOT TO HANDLE THREE CASES. IT IS TO NEVER ATTACH.

	A pet is not welded, not parented to the character, and not in the
	character's descendant list at all -- so `hideCharacter` cannot miss it,
	because `hideCharacter` never sees it. What replaces the three hooks is
	two rules, both of which read the character rather than a flag:

	  1. A PET IS VISIBLE EXACTLY WHEN ITS OWNER IS. Not "when a hidden flag
	     is false" -- a boolean the pet has to check is a second piece of
	     state that can disagree with what is actually on screen, which is the
	     argument the guard dog's watcher already makes when it reads measured
	     SPEED rather than a stealth flag. `hideCharacter` sets every part's
	     Transparency to 1 and that replicates, so the character's own
	     visibility IS the signal. Anything added later that hides a player
	     the same way is handled with no new code.

	  2. A PET FOLLOWS, AND SNAPS WHEN THE GAP IS ABSURD. A lerp handles
	     walking, running and a scrambler at 33 studs a second; a distance
	     threshold handles anything that was not travel. The arrest teleport
	     is the case that motivated it -- a thief is put back at their own
	     gate from up to 245 studs away -- and it is deliberately written as
	     "too far to have run there" rather than as a teleport hook, so a
	     future teleport nobody tells this file about is handled too.

	Mounting needs nothing at all under those two rules, which is the test
	that they are the right ones: the rider stays visible and keeps moving, so
	the pet stays visible and keeps up.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PetModel = require(ReplicatedStorage.Shared.PetModel)

local Pets = {}

-- How far behind and to the side a pet walks. Behind, because a pet in front
-- of somebody is a pet they walk through; to the side, because directly
-- behind is where the third-person camera sits and a pet there is a pet you
-- are permanently looking at rather than one you notice.
local FOLLOW_BACK = 4.2
local FOLLOW_SIDE = 2.0

-- Per second, as a fraction of the remaining gap. High enough that a pet
-- keeps up with a Volt Scrambler at 33.6 studs a second and low enough that
-- it still reads as following rather than as being welded.
local FOLLOW_RATE = 9.0

-- Past this, it did not run there. See rule 2 above -- an arrest teleport is
-- up to 245 studs, a plot-to-plot walk is 80, and the widest gap ordinary
-- travel can open in one frame at scrambler speed is under a stud.
local SNAP_STUDS = 26

-- How fast a pet turns to face where it is going. Eased rather than snapped,
-- and WRAPPED to take the short way round -- without the wrap, turning from
-- just past -170 degrees to just past +170 eases the long way through zero,
-- which is the bug the patrol car's lane change and the skateboard's stance
-- both had to fix.
local TURN_RATE = math.rad(540)

type Entry = {
	player: Player,
	key: string,
	model: Model,
	primary: BasePart,
	hover: boolean,
	at: CFrame?,
	yaw: number?,
}

local entries: { [Player]: Entry } = {}
local root: Folder? = nil

local function wrapAngle(a: number): number
	return (a + math.pi) % (math.pi * 2) - math.pi
end

local function destroy(player: Player)
	local entry = entries[player]
	if entry then
		entry.model:Destroy()
		entries[player] = nil
	end
end

local function ensure(player: Player)
	local key = player:GetAttribute(Config.PET_ATTRIBUTE)
	local spec = if type(key) == "string" and key ~= "" then Config.PETS[key] else nil

	local entry = entries[player]
	if entry and entry.key == key then
		return
	end
	destroy(player)
	if not spec or not root then
		return
	end

	local model = PetModel.build(key :: string)
	if not model then
		-- A RETIRED PET IS NOTHING RATHER THAN AN ERROR, the same graceful
		-- degradation `Decor.buildOne` makes for a retired ornament. The save
		-- is pruned against the catalogue, so this only fires for a key that
		-- was retired between the attribute being written and this running.
		return
	end
	local primary = model.PrimaryPart
	if not primary then
		model:Destroy()
		return
	end
	model.Parent = root
	entries[player] = {
		player = player,
		key = key :: string,
		model = model,
		primary = primary,
		hover = spec.hover == true,
	}
end

local function step(dt: number)
	local now = os.clock()
	for player, entry in pairs(entries) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")

		if not hrp or not hrp:IsA("BasePart") then
			-- No character: park it out of sight rather than destroying it,
			-- because a respawn is common and rebuilding a dozen parts on
			-- every one of them is work to produce the same pet.
			entry.model:PivotTo(CFrame.new(0, -500, 0))
			entry.at = nil
			continue
		end

		-- RULE 1: visible exactly when its owner is. Read off the character
		-- rather than off a flag, so it cannot disagree with the screen.
		--
		-- THE HEAD, NEVER THE ROOT. HumanoidRootPart is Transparency 1 on every
		-- character all the time, so reading it made every pet permanently
		-- "hidden": invisible, and parked at hip height behind its owner. The
		-- wheelie bin hides EVERY part, so the head answers the same question.
		local head = (character :: Model):FindFirstChild("Head")
		local hidden = head ~= nil and head:IsA("BasePart") and head.Transparency >= 1
		for _, d in ipairs(entry.model:GetDescendants()) do
			if d:IsA("BasePart") then
				local base = d:GetAttribute("PetTransparency")
				if base == nil then
					base = d.Transparency
					d:SetAttribute("PetTransparency", base)
				end
				d.Transparency = if hidden then 1 else base :: number
			end
		end
		if hidden then
			-- Kept AT the owner while hidden rather than parked, so coming
			-- out of a bin does not also play a pet sprinting in from the
			-- horizon. It is invisible; where it is costs nothing.
			entry.model:PivotTo(hrp.CFrame * CFrame.new(0, 0, FOLLOW_BACK))
			entry.at = nil
			continue
		end

		local ownerCF = hrp.CFrame
		local goal = ownerCF * CFrame.new(FOLLOW_SIDE, 0, FOLLOW_BACK)
		local target = goal.Position

		-- THE PET STANDS ON ITS OWNER'S GROUND. The model's pivot is its feet
		-- (PetModel), and the ground is derived from the root the way
		-- RideService does: root centre, less half the root, less HipHeight.
		-- A mounted rider's HipHeight is raised by the ride's `stand`, so that
		-- is taken back off, or the pet would walk at deck height. Queries are
		-- no use here: the driveways and kerbs are CanQuery false. A hovering
		-- pet is built higher already, so all it adds is the bob.
		local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
		local hip = if humanoid then humanoid.HipHeight else 2
		for _, child in ipairs((character :: Model):GetChildren()) do
			if child:IsA("Model") and child.Name:sub(1, 5) == "Ride_" then
				local ride = Config.RIDES[child.Name:sub(6)]
				hip -= (ride and ride.stand) or 0
				break
			end
		end
		local ground = ownerCF.Position.Y - hrp.Size.Y / 2 - hip
		local lift = if entry.hover then math.sin(now * 2.4) * 0.28 else 0
		target = Vector3.new(target.X, ground + lift, target.Z)

		local current = entry.at
		local nextPos: Vector3
		if not current or (current.Position - target).Magnitude > SNAP_STUDS then
			-- RULE 2: too far to have run there. An arrest teleport, a
			-- respawn, or anything else that moves a character without
			-- travelling.
			nextPos = target
		else
			local alpha = 1 - math.exp(-FOLLOW_RATE * dt)
			nextPos = current.Position:Lerp(target, alpha)
		end

		-- Face the way it is moving, easing and taking the short way round.
		-- Falls back to the owner's own facing when standing still, or a pet
		-- at rest spins to whatever the last sub-millimetre of drift was.
		local delta = nextPos - (current and current.Position or nextPos)
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local wantYaw
		if flat.Magnitude > 0.02 then
			wantYaw = math.atan2(flat.X, flat.Z)
		else
			local ov = ownerCF.LookVector
			wantYaw = math.atan2(ov.X, ov.Z)
		end
		local yaw = entry.yaw
		if not yaw then
			yaw = wantYaw
		else
			local diff = wrapAngle(wantYaw - yaw)
			local maxStep = TURN_RATE * dt
			yaw += math.clamp(diff, -maxStep, maxStep)
		end
		entry.yaw = yaw

		local cf = CFrame.new(nextPos) * CFrame.Angles(0, yaw, 0)
		entry.at = cf
		entry.model:PivotTo(cf)
	end
end

function Pets.start(_localPlayer: Player)
	if not Config.PETS_ENABLED then return end
	if root then
		return
	end
	root = Instance.new("Folder")
	;(root :: Folder).Name = "Pets"
	;(root :: Folder).Parent = workspace

	local function watch(player: Player)
		ensure(player)
		player:GetAttributeChangedSignal(Config.PET_ATTRIBUTE):Connect(function()
			ensure(player)
		end)
	end

	-- EVERY PLAYER ALREADY HERE AS WELL AS EVERY ONE WHO ARRIVES. Connecting
	-- only to `PlayerAdded` misses everybody present when this runs, which is
	-- every player in Play Solo and the first into any server -- the trap the
	-- wheelie bin's own release hook shipped with and the one the jump fix
	-- had to answer as well.
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(destroy)

	-- Heartbeat rather than RenderStepped, deliberately. A frame of lag on a
	-- decoration that trots behind you is invisible, and this project has
	-- already recorded that RenderStepped does not fire at all in a Studio
	-- session whose viewport is not drawing -- which cost most of an
	-- afternoon on the gadget preview and would make a pet look broken for a
	-- reason that has nothing to do with pets.
	-- WARNED ONCE, NEVER PER FRAME. The loop is pcalled for the reason the
	-- guard dog's watcher is -- a pet is a cosmetic-grade feature and may
	-- never take the HUD down with it -- but a warning sixty times a second
	-- is not a report, it is a way of making the output window useless to the
	-- next person reading it for something else. Same call the gadget aim
	-- preview's own step already makes.
	local warned = false
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok and not warned then
			warned = true
			warn("[Pets] step failed, pets are frozen: " .. tostring(err))
		end
	end)
end

return Pets
