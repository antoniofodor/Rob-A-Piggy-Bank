--!strict
--[[
	HomeService

	The three things a defender buys and keeps in the house.

	THE GUARD DUTY TREAT exists to get people out of the house.

	The economy needs players robbing each other, and what stops them is
	anxiety about their own vault: there was no "lock up before you go out"
	action anywhere in this game, so the only way to protect a full piggy was
	to sit on it. A player choosing to sit still is the worst outcome the
	design has, and this is the answer to it.

	It does NOT grant immunity. A Golden Bone still gets through -- the same
	line the chase-break already draws. A prepared defender makes robbing them
	cost twelve times more (30,000 instead of 2,500), rather than making it
	impossible, because an always-alert Titan runs at 17 against a thief
	carrying at 16 and "cannot be bribed" would simply mean "cannot be robbed".

	And it is loudly visible -- neon collar, ON GUARD on the nameplate. The
	counter to a buff should be information rather than a fight: a thief reads
	it from the pavement and goes to one of the other eleven plots. The
	defender gets peace of mind, the robber loses seconds rather than coins,
	and nobody burns a Golden Bone finding out.

	THE SPRINKLER is a joke and is meant to stay one. It nudges trespassers
	toward the gate and soaks them. No damage, no stun, no slow; they can walk
	straight back in. Anything with teeth would be a fourth defence stacking on
	the fence, the dog and the locks -- and it would bite during a steal
	attempt, because a thief cracking a lock is stood still on that very lawn.

	THE PATROL RADIO is the one thing here that is not about your own plot,
	and it is the reason this file's title changed. It calls a police patrol
	onto the street early, for 75,000 coins, and it does not survive being
	described as a defence: what it actually does is start a sixty-second
	window in which the officer will come for whoever is top of the wanted
	board, which is normally the player doing best in the server. That is the
	point of it -- it is the one lever the rest of the street has against a
	runaway leader, and the closest thing this game has to a pressure valve.

	IT BUYS THE TIMING AND NEVER THE TARGET. `PoliceService.call` takes no
	arguments at all. The caller cannot name anybody, cannot exclude
	themselves, and gets no protection: if they are the most wanted thief then
	they have just called an officer out for themselves, which the shop card
	says in as many words. See the note above `Config.POLICE.callLockout` for
	why the lockout rather than the price is what caps it.

	NONE OF THE THREE CAN BE AIMED AT ANYBODY. There is no target argument on
	the remote at all: the server acts on the caller's own plot, on the caller,
	or on nothing. That is what keeps all of these out of the harassment
	bracket the gadgets had to be designed around.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HomeModel = require(ReplicatedStorage.Shared.HomeModel)
local DataService = require(script.Parent.DataService)
local HeldItemService = require(script.Parent.HeldItemService)
local PlotService = require(script.Parent.PlotService)
local GuardDog = require(script.Parent.GuardDog)
local PoliceService = require(script.Parent.PoliceService)
local StealthService = require(script.Parent.StealthService)

local HomeService = {}

-- Plots with a sprinkler running, and when it stops.
local sprinkling: { [any]: number } = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

-- Shared with bones and gadgets. All three are things you hold a stock of and
-- spend, the keys cannot collide, and sharing means these inherit the same
-- treatment for free -- including surviving rebirth, which is right for the
-- same reason: a treat is gone the moment it is used.
local function stock(data: any): { [string]: number }
	if type(data.consumables) ~= "table" then
		data.consumables = {}
	end
	return data.consumables
end

-- ============================================================
-- THE SPRINKLER
-- ============================================================

local function buildSprinkler(plot: any): Model
	local model = HomeModel.build("sprinkler")
	-- On the lawn between the gate and the piggy, off to one side so it never
	-- sits under the collect or steal prompt.
	model:PivotTo(plot.cframe * CFrame.new(9, Config.PLOT_SIZE.Y / 2, 12))
	model.Name = "Sprinkler"
	model.Parent = plot.model

	local head = model:FindFirstChild("Nozzle") :: BasePart?
	if head then
		local spray = Instance.new("ParticleEmitter")
		spray.Name = "Spray"
		spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		spray.Color = ColorSequence.new(Color3.fromRGB(210, 240, 255), Color3.fromRGB(120, 190, 235))
		spray.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		spray.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		spray.Lifetime = NumberRange.new(1.0, 1.6)
		spray.Rate = 90
		spray.Speed = NumberRange.new(18, 26)
		spray.SpreadAngle = Vector2.new(70, 180)
		spray.Acceleration = Vector3.new(0, -30, 0)
		spray.LightEmission = 0.4
		spray.Parent = head
	end

	return model
end

-- Everyone standing inside this plot's fence who is not its owner.
--
-- The fence rectangle, not the plot slab -- the same shape PlotService puts
-- its barriers around. Measuring from the slab would leave the whole back
-- garden outside the sprinkler's reach.
local function trespassers(plot: any): { Player }
	-- The fence rectangle is 64 x 48 now, so its width and its front line are
	-- two different numbers -- see Config.PLOT_HALF_WIDTH.
	local halfWidth = Config.PLOT_HALF_WIDTH
	local frontZ = Config.PLOT_FRONT_LINE
	local found = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= plot.owner then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local at = plot.cframe:PointToObjectSpace(root.Position)
				if math.abs(at.X) <= halfWidth and at.Z <= frontZ and at.Z >= -Config.YARD_DEPTH then
					table.insert(found, player)
				end
			end
		end
	end
	return found
end

local function soak(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	if not root:FindFirstChild("Soaked") then
		local drip = Instance.new("ParticleEmitter")
		drip.Name = "Soaked"
		drip.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		drip.Color = ColorSequence.new(Color3.fromRGB(180, 220, 245))
		drip.Size = NumberSequence.new(0.5, 0)
		drip.Transparency = NumberSequence.new(0.3, 1)
		drip.Lifetime = NumberRange.new(0.5, 0.9)
		drip.Rate = 22
		drip.Speed = NumberRange.new(1, 3)
		drip.Acceleration = Vector3.new(0, -22, 0)
		drip.Parent = root
		task.delay(3, function()
			if drip.Parent then
				drip:Destroy()
			end
		end)
	end
end

-- A shove toward the gate, and nothing else.
--
-- Deliberately weak. Anything strong enough to actually clear a lawn would be
-- a defence rather than a joke, and at this plot spacing it would throw people
-- into the road -- which is somebody else's front garden.
--
-- Written as a velocity rather than a CFrame nudge because the client owns its
-- own character: a position write fights the player's own movement and rubber
-- bands, where an impulse reads as being shoved.
local function shove(plot: any, player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	-- Out toward the street, which is plot-local +Z.
	local out = plot.cframe.LookVector * -1
	local flat = Vector3.new(out.X, 0, out.Z)
	local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, 1)

	root.AssemblyLinearVelocity = dir * Config.SPRINKLER_PUSH
		+ Vector3.new(0, Config.SPRINKLER_LIFT, 0)
end

function HomeService.useSprinkler(player: Player, spec: any): boolean
	local plot = PlotService.getPlot(player)
	if not plot then
		notify(player, "You need a plot first.", "warn")
		return false
	end

	if sprinkling[plot] and os.clock() < sprinkling[plot] then
		notify(player, "Your sprinkler is already running.", "warn")
		return false
	end

	sprinkling[plot] = os.clock() + spec.duration
	local model = buildSprinkler(plot)

	task.spawn(function()
		local spin = 0
		local nextShove = 0
		local base = model:GetPivot()

		while sprinkling[plot] and os.clock() < sprinkling[plot] and model.Parent do
			-- Spins every frame, shoves on a slower beat. A shove per frame
			-- would be a launcher rather than a nudge.
			spin += 0.08
			model:PivotTo(base * CFrame.Angles(0, spin, 0))

			if os.clock() >= nextShove then
				nextShove = os.clock() + Config.SPRINKLER_TICK
				for _, victim in ipairs(trespassers(plot)) do
					shove(plot, victim)
					soak(victim)
				end
			end
			RunService.Heartbeat:Wait()
		end

		sprinkling[plot] = nil
		if model.Parent then
			model:Destroy()
		end
	end)

	notify(player, ("Sprinkler on for %d seconds."):format(spec.duration), "good")
	return true
end

-- ============================================================
-- THE TREAT
-- ============================================================

function HomeService.useTreat(player: Player, spec: any): boolean
	local plot = PlotService.getPlot(player)
	if not plot then
		notify(player, "You need a plot first.", "warn")
		return false
	end

	-- Refused BEFORE the treat is spent. A dog that does not exist cannot go
	-- on guard duty, and an item consumed for nothing is indistinguishable
	-- from an item that does not work.
	if plot.dog.level <= 0 then
		notify(player, "You don't have a guard dog yet. Buy one first.", "warn")
		return false
	end

	-- The reason comes back from GuardDog rather than being guessed at here:
	-- "already guarding" and "not allowed another yet" are different
	-- refusals, and the player needs to know which one they hit.
	local ok, why = GuardDog.setGuardDuty(plot.dog, spec.duration)
	if not ok then
		notify(player, ("%s."):format(why or "Your dog can't take that right now"), "warn")
		return false
	end

	notify(player, ("%s is on guard duty for %d minutes. Go and rob somebody!"):format(
		Config.getDogTier(plot.dog.level).name, math.floor(spec.duration / 60 + 0.5)), "good")
	return true
end

-- ============================================================
-- THE RADIO
-- ============================================================

-- Nothing here decides anything. The whole of this function is: ask the
-- patrol to come out, say what it said, and spend the radio only if it did.
--
-- Which is the design, not a thin wrapper around a bigger one. Every question
-- worth asking -- is a patrol already out, has somebody just called one, is
-- the street still inside its lockout -- belongs to PoliceService because
-- PoliceService is the thing that knows, and a copy of any of those tests in
-- here would be a second reader of a field that drifts. `GuardDog.isOffDuty`
-- exists for the same reason: BoneService copied that comparison out once and
-- the two disagreed in opposite directions the moment a second clock appeared.
function HomeService.useRadio(player: Player, spec: any): boolean
	local ok, message = PoliceService.call()
	if not ok then
		-- Named, and the radio is NOT spent. An item consumed for nothing is
		-- indistinguishable from an item that is broken, which is the same
		-- line the bone and guard-duty refusals draw.
		notify(player, message, "warn")
		return false
	end

	-- Only the caller hears this one. The street gets its own announcement
	-- when the sirens start, and that one deliberately does not name anybody.
	notify(player, message, "police")
	return true
end

-- ============================================================
-- BUYING AND USING
-- ============================================================

function HomeService.buy(player: Player, key: string)
	local spec = Config.HOME_ITEMS[key]
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

	notify(player, ("%s bought. You have %d."):format(spec.name, stock(data)[key]), "good")
	DataService.save(player)
	HomeService.push(player)
end

function HomeService.use(player: Player, key: string)
	local spec = Config.HOME_ITEMS[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end

	-- YOU HAVE TO BE HOLDING IT. The prop in the hand is a tell other players
	-- read off the pavement, so a use that never drew anything would be a lie
	-- about the street. Named rather than silent: the fix is one keypress and
	-- a refusal nobody can read is indistinguishable from a broken item.
	if not HeldItemService.holding(player, key) then
		notify(player, ("Hold the %s out first."):format(spec.name), "warn")
		return
	end

	local held = stock(data)[key] or 0
	if held <= 0 then
		notify(player, ("You have no %s left."):format(spec.name), "warn")
		return
	end

	-- Each `use` returns whether it actually happened, and the stock is only
	-- spent on a true. Every refusal above notifies first, so nothing here
	-- ever fails silently.
	local used = false
	if spec.style == "treat" then
		used = HomeService.useTreat(player, spec)
	elseif spec.style == "sprinkler" then
		used = HomeService.useSprinkler(player, spec)
	elseif spec.style == "radio" then
		used = HomeService.useRadio(player, spec)
	end

	if not used then
		return
	end

	stock(data)[key] = held - 1
	DataService.save(player)
	HomeService.push(player)
	HeldItemService.revalidate(player)
end

function HomeService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local held = stock(data)
	local plot = PlotService.getPlot(player)

	local list = {}
	for key, spec in pairs(Config.HOME_ITEMS) do
		list[key] = {
			name = spec.name,
			order = spec.order,
			cost = spec.cost,
			blurb = spec.blurb,
			detail = spec.detail,
			duration = spec.duration,
			held = held[key] or 0,
		}
	end

	Remotes.get("HomeState"):FireClient(player, {
		items = list,
		-- So the HUD can show the buff running rather than leaving the player
		-- guessing whether the thing they just spent ten thousand coins on
		-- actually took.
		guardSeconds = if plot then math.floor(GuardDog.guardSecondsLeft(plot.dog)) else 0,
		-- And how long until another treat may be used, so the shop can say
		-- "ready in 3m 20s" instead of only refusing once the button is pressed.
		guardLockSeconds = if plot then math.floor(GuardDog.guardLockSecondsLeft(plot.dog)) else 0,
	})
end

function HomeService.start()
	Remotes.get("HomeRequest").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		HomeService.buy(player, key)
	end)

	-- No target argument, by construction. The server acts on the caller's own
	-- plot or on nothing at all, so there is no player here to name.
	Remotes.get("HomeUse").OnServerEvent:Connect(function(player, key)
		-- Nothing but climbing out, while you are in a bin. The client hides
		-- the control, so this only ever fires for a client that was written
		-- to ignore it.
		if StealthService.isHidden(player) then
			return
		end
		if type(key) ~= "string" then
			return
		end
		HomeService.use(player, key)
	end)

	-- Keeps the guard-duty countdown on the HUD honest without a remote per
	-- second. Two seconds is well inside what a six-minute timer needs.
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in ipairs(Players:GetPlayers()) do
				local plot = PlotService.getPlot(player)
				if plot and GuardDog.guardSecondsLeft(plot.dog) > 0 then
					HomeService.push(player)
				end
			end
		end
	end)
end

return HomeService
