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
