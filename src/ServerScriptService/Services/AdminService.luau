--!strict
--[[
	AdminService

	A developer console for the owner. Grant coins, set upgrade levels, jump to
	late-game state, and clear the new-player shield so a two-player test does
	not start with fifteen minutes of nothing happening.

	SECURITY MODEL

	The only thing that grants access is this file, on the server, checking
	`isAdmin` at the top of the one and only handler. Everything else is
	convenience.

	In particular, the client panel is NOT a security boundary. A RemoteEvent
	exists for every client whether or not their panel was built, and anyone
	can fire it with an exploit -- hiding a button protects nothing. That is
	why authorisation happens here and not in ClientMain, why it happens before
	any argument is even read, and why every rejection is logged with the
	UserId that attempted it.

	Admission on a LIVE server is the Config allowlist OR being the place's own
	creator. The second exists so this keeps working if the experience is
	republished under a different account, which has already happened once.

	In STUDIO everybody is admitted, so local multiplayer tests have a working
	panel on every client. That branch is guarded by RunService:IsStudio() and
	is therefore dead code in production.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local GuardDog = require(script.Parent.GuardDog)
local UpgradeService = require(script.Parent.UpgradeService)
local CosmeticsService = require(script.Parent.CosmeticsService)
local ProgressionService = require(script.Parent.ProgressionService)
local HeistService = require(script.Parent.HeistService)
local BoneService = require(script.Parent.BoneService)
local PoliceService = require(script.Parent.PoliceService)
local EventService = require(script.Parent.EventService)
local SetService = require(script.Parent.SetService)
local ChestService = require(script.Parent.ChestService)
local SocialService = require(script.Parent.SocialService)
local RideService = require(script.Parent.RideService)
local GadgetService = require(script.Parent.GadgetService)
local HomeService = require(script.Parent.HomeService)
local StealthService = require(script.Parent.StealthService)

local AdminService = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

-- The whole gate. Called before anything else, every single request.
function AdminService.isAdmin(player: Player): boolean
	-- Everyone is an admin in Studio.
	--
	-- Studio's local multiplayer test hands its extra clients placeholder
	-- UserIds that will never match a real allowlist entry, so a two-player
	-- test would otherwise have no admin on either client -- exactly when the
	-- panel is most useful, since it is what clears the new-player shield.
	--
	-- This cannot widen access in production: RunService:IsStudio() is false
	-- on every live server, and the allowlist below is the only thing that
	-- admits anyone there.
	if RunService:IsStudio() then
		return true
	end

	if Config.isAdminUserId(player.UserId) then
		return true
	end
	-- Place owner, but only for a user-owned place. A group-owned place has a
	-- CreatorId that is a GROUP id, and comparing it against a UserId would
	-- eventually admit whichever unlucky player's UserId happened to match.
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return false
end

-- Reapplies everything a data change implies. Coins and vault ride the
-- economy tick already; upgrades and cosmetics have to be pushed by hand.
local function refresh(player: Player)
	UpgradeService.applyToPlot(player)
	UpgradeService.push(player)
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
	ProgressionService.push(player)
end

-- ============================================================
-- COMMANDS
-- ============================================================
--
-- Each returns a message to show the caller. Arguments arrive from a client
-- and are therefore untrusted even from an admin: every one is type-checked
-- and clamped rather than used raw.

-- COMMANDS THAT REFUSE A TARGET AND ALWAYS ACT ON THE CALLER.
--
-- `reset` wipes a save. With a player dropdown at the top of the panel, one
-- mis-set selection is somebody else's account gone -- and unlike every other
-- command here that is not recoverable by pressing another button. An admin
-- who genuinely means to wipe another player can still do it from a real
-- console; the panel will not do it by accident.
local SELF_ONLY: { [string]: boolean } = {
	reset = true,
}

local commands: { [string]: (Player, any, any) -> string? } = {}

commands.coins = function(player, amount)
	local data = DataService.get(player)
	if not data or type(amount) ~= "number" then
		return nil
	end
	local n = math.clamp(math.floor(amount), -1e12, 1e12)
	data.coins = math.max(0, data.coins + n)
	return ("Coins now %d"):format(math.floor(data.coins))
end

commands.vault = function(player, amount)
	local data = DataService.get(player)
	if not data or type(amount) ~= "number" then
		return nil
	end
	data.vault = math.clamp(math.floor(amount), 0, 1e12)
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.updatePile(plot, data.vault, Config.getCapacity(data.capacityLevel))
	end
	return ("Vault set to %d"):format(math.floor(data.vault))
end

commands.upgrade = function(player, key, level)
	local data = DataService.get(player)
	local def = type(key) == "string" and Config.UPGRADES[key]
	if not data or not def or type(level) ~= "number" then
		return nil
	end
	data.upgrades[key] = math.clamp(math.floor(level), 0, def.max)
	refresh(player)
	return ("%s set to %d"):format(def.name, data.upgrades[key])
end

commands.house = function(player, level)
	local data = DataService.get(player)
	if not data or type(level) ~= "number" then
		return nil
	end
	data.houseLevel = math.clamp(math.floor(level), 0, Config.MAX_HOUSE_LEVEL)
	-- Moved in, not just unlocked. A dev command that sets the ladder without
	-- moving the player into it would build nothing, which reads as the
	-- command having failed.
	data.houseShown = data.houseLevel
	-- Full refresh: the sign names the house, so setting the level by hand has
	-- to reapply the whole plot or the sign goes stale.
	refresh(player)
	return ("Moved into the %s"):format(Config.getHouseTier(data.houseLevel).name)
end

commands.rebirths = function(player, count)
	local data = DataService.get(player)
	if not data or type(count) ~= "number" then
		return nil
	end
	data.rebirths = math.clamp(math.floor(count), 0, 999)
	refresh(player)
	return ("Rebirths set to %d"):format(data.rebirths)
end

commands.skin = function(player, key)
	local data = DataService.get(player)
	if not data or type(key) ~= "string" or not Config.SKINS[key] then
		return nil
	end
	data.cosmetics.owned[key] = true
	data.cosmetics.skin = key
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
	return ("Wearing %s"):format(Config.getSkin(key).name)
end

commands.unlockall = function(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	for key in pairs(Config.SKINS) do
		data.cosmetics.owned[key] = true
	end
	for key in pairs(Config.EFFECTS) do
		data.cosmetics.ownedEffects[key] = true
	end
	data.houseLevel = Config.MAX_HOUSE_LEVEL
	data.houseShown = Config.MAX_HOUSE_LEVEL
	if type(data.accessories) ~= "table" then
		data.accessories = { owned = {}, worn = {} }
	end
	for key in pairs(Config.ACCESSORIES) do
		data.accessories.owned[key] = true
	end
	if type(data.rides) ~= "table" then
		data.rides = { owned = {}, equipped = "" }
	end
	for key in pairs(Config.RIDES) do
		data.rides.owned[key] = true
	end
	RideService.push(player)
	-- applyToPlot rather than setHouseLevel: the sign names the house, so
	-- building it alone leaves the board announcing the old one.
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
	return "Every skin, effect, house, accessory and ride unlocked"
end

-- Empties the accessory collection without touching anything else.
--
-- `reset` also clears it, but reset takes the rebirths with it -- and the
-- thing most worth looking at in the collection tab is the LOCKED state,
-- which is unreachable once a save has rolled everything.
commands.cleargear = function(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	data.accessories = { owned = {}, worn = {} }
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.applyAccessories(plot, data.accessories.worn)
	end
	DataService.save(player)
	CosmeticsService.push(player)
	return "Accessory collection emptied"
end

commands.maxupgrades = function(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	for key, def in pairs(Config.UPGRADES) do
		data.upgrades[key] = def.max
	end
	-- Their CURRENT ceiling, not the absolute one: maxing a player past what
	-- their rebirth count has unlocked would put them in a state the purchase
	-- path cannot produce, which is exactly the sort of thing a dev command
	-- should not be able to fake.
	data.incomeLevel = Config.maxLevel(data.rebirths)
	data.capacityLevel = Config.maxLevel(data.rebirths)
	refresh(player)
	return "All upgrades maxed"
end

-- Puts the dog on cooldown without needing a robbery, so the kennel/sleep
-- cycle can be watched on demand rather than only after a real chase.
commands.dognap = function(player, seconds)
	local plot = PlotService.getPlot(player)
	if not plot then
		return nil
	end
	local secs = if type(seconds) == "number" then math.clamp(seconds, 1, 300) else 20
	-- napUntil rather than busyUntil, so the command works even while the
	-- dog is on guard duty. A dev command that silently does nothing for
	-- six minutes is worse than no dev command.
	plot.dog.napUntil = os.clock() + secs
	return ("Dog off duty for %ds. It should head for the kennel."):format(secs)
end

-- Ten of every bone. Testing a bone means throwing it at a dog that is on
-- duty, and a dog is only on duty for the first few seconds of each cycle --
-- so a test run burns stock far faster than it can be earned.
-- Reports the dog's actual state rather than what it looks like it is
-- doing. Added because a Golden Bone landing on a guarded dog LOOKED
-- fine from outside -- the bone was taken, the message was right -- while
-- three separate clocks disagreed about whether the dog was off duty.
-- The nameplate is a proxy, and this stops the next one being debugged
-- by watching a label and guessing.
commands.dogstate = function(player)
	local plot = PlotService.getPlot(player)
	if not plot or not plot.dog then
		return nil
	end
	local dog = plot.dog
	local now = os.clock()
	return ("lvl %d | nap %+.1fs | busy %+.1fs | guard %+.1fs | chasing=%s lured=%s sleeping=%s distracted=%s | offDuty=%s ready=%s | plate=%q"):format(
		dog.level,
		dog.napUntil - now, dog.busyUntil - now, dog.guardUntil - now,
		tostring(dog.chasing), tostring(dog.lured), tostring(dog.sleeping),
		tostring(dog.distracted),
		tostring(GuardDog.isOffDuty(dog)), tostring(GuardDog.isReady(dog)),
		dog.breedLabel.Text)
end

-- Calls a patrol immediately instead of waiting out the eight-minute cycle.
--
-- Without this the feature is close to untestable: a chase lasts thirty
-- seconds and only starts if somebody robs during a forty-five second window,
-- so verifying one change would mean sitting through the timer for each
-- attempt. That is exactly how a feature ends up shipped unverified.
-- A TOGGLE, not just a trigger. Waiting out a forty-five second patrol plus a
-- thirty second pursuit to get back to a quiet street is most of the time cost
-- of testing anything else on this list.
commands.police = function(player)
	if PoliceService.isOut() then
		return PoliceService.standDown()
	end
	return PoliceService.trigger()
end

-- Puts you on the plaza board, or takes you off it. Toggling OFF is the more
-- useful half: a rap sheet is only cleared by a most-wanted arrest, so without
-- this the only way to stop being hunted is to be caught.
commands.mostwanted = function(player)
	local suspect = SocialService.getMostWanted()
	if suspect == player then
		SocialService.clearHeat(player)
		SocialService.refresh()
		return "Rap sheet cleared. You are off the board."
	end
	local record = SocialService.makeMostWanted(player)
	return ("You are MOST WANTED with %d on the sheet. Bail would be %d."):format(
		record, record * Config.POLICE.bailMultiple)
end

-- Reports what the patrol is actually doing rather than what it looks like it
-- is doing -- the same reason `dogstate` exists. The car being on the street
-- says nothing about whether an alarm is pending or whether the pursuit has
-- already committed, and those are the two states a bug would hide in.
-- Puts an officer onto you without needing a second player and a real
-- robbery. `amount` is the notional loot the bail is calculated from.
commands.bust = function(player, amount)
	local n = if type(amount) == "number" then math.clamp(math.floor(amount), 1, 1e9) else 10000
	return PoliceService.bust(player, n)
end

-- Starts a session event now. Waiting fifteen minutes to watch a two-minute
-- raid is how a feature ends up shipped unverified, which is the same argument
-- `police` and `dognap` already make. It fakes only the SCHEDULER -- the
-- warning, the arrival, the beams, the siphon, the throw, the prompt and the
-- payout are all the real path.
-- Grants medals and re-pushes the set state. Two jobs on purpose: earning
-- medals legitimately means sitting through a whole event, and the set panel
-- is only pushed on a change -- so without this there is no way to look at
-- your own sets on demand, which is exactly the shape of thing that ships
-- unverified.
-- Opens a chest for real, through the same path the shop will use. There is no
-- UI for chests yet, so this is currently the only way a human can reach one --
-- which is exactly the shape of thing this file already warns about: a command
-- that exists with no way for a person to trigger it is a command that ships
-- unverified.
-- Builds every animation this game needs as a real uploaded asset into
-- ReplicatedStorage.AnimationDump, so they can be published once and their ids
-- pasted into Config.ANIMATIONS.
--
-- THIS EXISTS BECAUSE `RegisterKeyframeSequence` IS STUDIO-ONLY. Everything
-- animated here is assembled at runtime and registered for a `hash://` id,
-- which works in Studio and is refused in a published game -- so the dodge
-- roll and every rider pose are dead on the live site while passing every test
-- in here. See Config.ANIMATIONS.
--
-- Run it in STUDIO, not live: the sequences are the thing being uploaded, and
-- a live server cannot register or publish them anyway.
commands.animdump = function(player)
	local RidePose = require(game:GetService("ReplicatedStorage").Shared.RidePose)
	local DodgeRoll = require(game:GetService("ReplicatedStorage").Shared.DodgeRoll)

	local existing = ReplicatedStorage:FindFirstChild("AnimationDump")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "AnimationDump"
	folder.Parent = ReplicatedStorage

	local made, failed = 0, {}
	local function put(name: string, seq: Instance?)
		if seq then
			seq.Name = name
			seq.Parent = folder
			made += 1
		else
			table.insert(failed, name)
		end
	end

	if DodgeRoll.buildSequence then
		put("dodgeRoll", DodgeRoll.buildSequence())
	else
		table.insert(failed, "dodgeRoll (no buildSequence export)")
	end
	if RidePose.buildSequenceFor then
		for _, key in ipairs(Config.animationKeys()) do
			if key ~= "dodgeRoll" then
				put(key, RidePose.buildSequenceFor(key))
			end
		end
	else
		table.insert(failed, "ride poses (no buildSequenceFor export)")
	end

	return ("Built %d into ReplicatedStorage.AnimationDump%s"):format(made,
		#failed > 0 and (". Missing: " .. table.concat(failed, ", ")) or
		". Publish each, then paste the ids into Config.ANIMATIONS.")
end

commands.chest = function(player, key, times)
	local chestKey = tostring(key or "classics")
	if not Config.CHESTS[chestKey] then
		local names = {}
		for k in pairs(Config.CHESTS) do
			table.insert(names, k)
		end
		table.sort(names)
		return ("No chest '%s'. Try: %s"):format(chestKey, table.concat(names, ", "))
	end
	local n = math.clamp(tonumber(times) or 1, 1, 25)
	local lines = {}
	for _ = 1, n do
		local tier, kind, itemKey, dup = ChestService.open(player, chestKey)
		if not tier then
			table.insert(lines, "refused")
			break
		end
		table.insert(lines, ("%s %s%s"):format(tier, itemKey, dup and " (dupe)" or ""))
	end
	return table.concat(lines, ", ")
end

commands.combine = function(player, tier, key)
	local t, chestKey = tostring(tier or "common"), tostring(key or "classics")
	local target, _, itemKey, dup = ChestService.combine(player, t, chestKey)
	if not target then
		return "refused"
	end
	return ("%s -> %s %s%s"):format(t, target, itemKey, dup and " (dupe)" or "")
end

commands.shards = function(player, amount)
	local data = DataService.get(player)
	local n = tonumber(amount) or 3
	if not data then
		return nil
	end
	for _, t in ipairs({ "common", "rare", "epic", "legendary" }) do
		data.shards[t] = (data.shards[t] or 0) + n
	end
	ChestService.push(player)
	return ("Shards: +%d of each tier"):format(n)
end

-- Grants roll tokens. Same shape and same reason as `medals` below: earning
-- these legitimately means claiming a daily or sitting through a whole event,
-- and the roll button reads the balance, so a dev grant has to push too --
-- which CosmeticsService.awardTokens already does.
commands.tokens = function(player, amount)
	local n = tonumber(amount) or 0
	if n <= 0 then
		return "Amount must be positive."
	end
	CosmeticsService.awardTokens(player, n, "Dev grant:")
	return ("Tokens: %d"):format(CosmeticsService.getTokens(player))
end

commands.medals = function(player, amount)
	local n = if type(amount) == "number" then math.floor(amount) else 0
	if n ~= 0 then
		SetService.award(player, n, "Admin.")
	else
		SetService.push(player)
	end
	return ("Medals: %d"):format(SetService.getMedals(player))
end

commands.event = function(player, name)
	return EventService.trigger(if type(name) == "string" then name else nil)
end

commands.eventstate = function(player)
	return EventService.status()
end

commands.policestate = function(player)
	return PoliceService.status()
end

-- Puts coins on your own rap sheet, which is otherwise only ever written by a
-- completed delivery -- so without this, verifying MOST WANTED needs a second
-- player, a real robbery and a run home first. Same argument as `police` and
-- `bust` above.
--
-- Note the board only picks somebody up on its refresh tick, and only once
-- their sheet clears their own income floor, so a small number here can
-- legitimately do nothing. It says which.
commands.wanted = function(player, amount)
	local n = if type(amount) == "number" then math.floor(amount) else 100000
	SocialService.recordSteal(player, n)
	-- YOUR OWN sheet, not the board. The board only moves on its refresh tick,
	-- so reading the winner back here always reports the state from before this
	-- command ran -- which reads exactly like the command having done nothing.
	return ("Rap sheet +%d, now %d. Board updates within %ds."):format(
		n,
		SocialService.getHeat(player),
		Config.LEADERBOARD_REFRESH)
end

-- Fakes one most-wanted ESCAPE, which is the real award path -- so this tests
-- the unlock, the auto-wear and the toast rather than just stuffing a flag in.
-- Without it, verifying the gear means topping the board and then outrunning an
-- officer for thirty seconds, per attempt.
commands.gear = function(player, count)
	local n = if type(count) == "number" then math.clamp(math.floor(count), 1, 50) else 1
	local earned = nil
	for _ = 1, n do
		earned = CosmeticsService.recordWantedEscape(player) or earned
	end
	return ("%d escape(s) recorded. Unlocked this run: %s"):format(n, earned or "nothing new")
end

commands.bones = function(player, count)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	if type(data.consumables) ~= "table" then
		data.consumables = {}
	end
	local n = if type(count) == "number" then math.clamp(math.floor(count), 0, 99) else 10
	for key in pairs(Config.BONES) do
		data.consumables[key] = n
	end
	-- Gadgets share the same stock table, and land in the same hole: testing
	-- one means throwing it at a robbery already in progress, which is a
	-- narrow window that burns stock far faster than it can be earned.
	for key in pairs(Config.GADGETS) do
		data.consumables[key] = n
	end
	for key in pairs(Config.HOME_ITEMS) do
		data.consumables[key] = n
	end
	for key in pairs(Config.THIEF_KIT) do
		data.consumables[key] = n
	end
	BoneService.push(player)
	GadgetService.push(player)
	HomeService.push(player)
	StealthService.push(player)
	return ("%d of everything throwable"):format(n)
end

commands.shield = function(player)
	local shields, cooldowns = HeistService.openSeason()
	return ("Open season: %d shield(s) dropped, %d cooldown/limit pair(s) cleared"):format(
		shields, cooldowns)
end

commands.reset = function(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	data.coins = 0
	data.vault = 0
	data.incomeLevel = 1
	data.capacityLevel = 1
	data.rebirths = 0
	data.houseLevel = 0
	data.houseShown = 0
	for key in pairs(Config.UPGRADES) do
		data.upgrades[key] = 0
	end
	data.cosmetics.owned = {}
	data.cosmetics.ownedEffects = {}
	data.cosmetics.skin = Config.DEFAULT_SKIN
	data.cosmetics.effect = Config.DEFAULT_EFFECT

	-- Decorations, bone stock and the pity counter, which this command used to
	-- miss.
	--
	-- It claimed "brand-new player" while leaving every ornament owned AND
	-- placed -- and because refresh re-applies the collection to the plot, they
	-- were immediately rebuilt on a lawn that was supposed to be empty. A dev
	-- command that lies about what it wiped is worse than one that does less,
	-- because the state it leaves behind gets mistaken for a bug in the feature
	-- being tested.
	data.decor = { owned = {}, placed = {} }
	data.consumables = {}
	data.accessories = { owned = {}, worn = {} }
	data.sinceLegendary = 0
	-- Through RideService rather than by clearing the field here, because the
	-- player may be ON one right now: the model is welded to their character
	-- and the multiplier is held inside HeistService, and neither of those is
	-- reachable from a table assignment.
	RideService.clear(player)

	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.buildFence(plot, 0)
		PlotService.setDogLevel(plot, 0)
		PlotService.setLockLevel(plot, 0)
		PlotService.setDecor(plot, data.decor.placed)
		PlotService.applyAccessories(plot, data.accessories.worn)
		PlotService.setHouseLevel(plot, 0)
		PlotService.updatePile(plot, 0, Config.getCapacity(1))
	end
	refresh(player)
	BoneService.push(player)
	GadgetService.push(player)
	HomeService.push(player)
	-- Through the service: a disguise in progress has hidden character parts
	-- and a ward living inside HeistService, and neither is reachable from a
	-- table assignment here.
	StealthService.clear(player)
	DataService.save(player)
	return "Save wiped back to a brand-new player"
end

-- ============================================================
-- WIRING
-- ============================================================

function AdminService.push(player: Player)
	Remotes.get("AdminState"):FireClient(player, AdminService.isAdmin(player))
end

function AdminService.start()
	Remotes.get("AdminRequest").OnServerEvent:Connect(function(player, command, targetId, a, b)
		-- Authorise FIRST, before reading a single argument -- and that now
		-- matters more than it did, because one of those arguments names
		-- somebody else. The order is the whole protection: nothing below
		-- this block runs for a player who is not on the allowlist, so the
		-- target argument is only ever read on behalf of an admin.
		if not AdminService.isAdmin(player) then
			warn(("[AdminService] DENIED %s (userId %d) tried '%s'"):format(
				player.Name, player.UserId, tostring(command)))
			return
		end

		if type(command) ~= "string" then
			return
		end
		local handler = commands[command]
		if not handler then
			notify(player, ("Unknown command '%s'"):format(command), "warn")
			return
		end

		-- THE TARGET IS RESOLVED SERVER-SIDE FROM A USERID, never taken as an
		-- object and never trusted as a name. The client sends a number; this
		-- looks it up in the live player list, so a stale or invented id
		-- resolves to nobody rather than to whoever happens to match.
		local target = player
		if not SELF_ONLY[command] and type(targetId) == "number" and targetId ~= player.UserId then
			local found = Players:GetPlayerByUserId(targetId)
			if not found then
				notify(player, "That player has left the server.", "warn")
				return
			end
			target = found
		end

		local ok, result = pcall(handler, target, a, b)
		if not ok then
			warn(("[AdminService] '%s' errored for %s: %s"):format(command, target.Name, tostring(result)))
			notify(player, ("'%s' failed. Check the server log."):format(command), "warn")
			return
		end

		-- Every accepted command is logged, and the log now names BOTH ends.
		-- "who did it" stopped being enough the moment a command could be
		-- pointed at somebody else: if an account is ever compromised, the
		-- server log is the only record of what was done and to whom.
		print(("[AdminService] %s (%d) ran '%s' on %s (%d) -> %s"):format(
			player.Name, player.UserId, command, target.Name, target.UserId, tostring(result)))

		-- Answered to the CALLER, always. They pressed the button; the target
		-- may not even know the panel exists.
		local said = result or ("'%s' did nothing. Bad arguments?"):format(command)
		if target ~= player then
			said = ("[%s] %s"):format(target.DisplayName, said)
		end
		notify(player, said, "good")
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(AdminService.push, player)
	end)
end

return AdminService
