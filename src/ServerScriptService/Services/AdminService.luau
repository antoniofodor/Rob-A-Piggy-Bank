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
local TrophyService = require(script.Parent.TrophyService)
local ProgressionService = require(script.Parent.ProgressionService)
local HeistService = require(script.Parent.HeistService)
local BoneService = require(script.Parent.BoneService)
local PoliceService = require(script.Parent.PoliceService)
local TrafficService = require(script.Parent.TrafficService)
local EventService = require(script.Parent.EventService)
local SetService = require(script.Parent.SetService)
local ChestService = require(script.Parent.ChestService)
local SocialService = require(script.Parent.SocialService)
local RideService = require(script.Parent.RideService)
local GadgetService = require(script.Parent.GadgetService)
local HomeService = require(script.Parent.HomeService)
local StealthService = require(script.Parent.StealthService)
local DailyService = require(script.Parent.DailyService)

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

-- Fills the pig to capacity, which is the state most worth testing: a full
-- pig has stopped earning and is the best target on the street.
commands.fill = function(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	data.coins = math.max(data.coins, Config.getCapacity(data.capacityLevel))
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.updatePile(plot, data.coins, Config.getCapacity(data.capacityLevel))
	end
	return ("Piggy bank at %d"):format(math.floor(data.coins))
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

-- FIRES THE REBIRTH SHOW WITHOUT PAYING THE REBIRTH GATE.
--
-- The gate is a multiple of a capacity that is itself climbing -- 6.0M at
-- rebirth 1 and 193.8M at rebirth 10 -- so the only way to see the show at
-- the top of its ladder is to play for a fortnight or to fake the balance
-- ten times over. The show is the one part of a rebirth that has to be
-- LOOKED AT rather than read back, and this is what makes that affordable.
--
-- It goes through `PlotService.fireFireworks`, which is the shipped path
-- and the only writer, so what is exercised is the real thing rather than
-- a second one that could pass while it fails.
commands.fireworks = function(player, rank)
	local plot = PlotService.getPlot(player)
	if not plot then
		return "no plot"
	end
	local rebirths = if type(rank) == "number" then math.floor(rank) else 1
	PlotService.fireFireworks(plot, rebirths)
	return ("Fireworks at rebirth %d -- %d shells"):format(
		rebirths, Config.fireworkShells(rebirths))
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
	-- THE DOG'S THREE CATALOGUES, which this command claimed to cover and did
	-- not. It has said "every ... unlocked" since it was written, and coats,
	-- kennels and toys each landed after it -- so a dev opening the shop to
	-- look at a card found it locked and had no reason to suspect the TOOL
	-- rather than the feature. The same silent-omission shape this project
	-- keeps recording, on the thing used to look for it.
	if type(data.dogs) ~= "table" then
		data.dogs = { owned = {}, equipped = "", name = "", namedAt = 0,
			kennels = {}, kennel = "", toys = { owned = {}, out = {} } }
	end
	if type(data.dogs.toys) ~= "table" then
		data.dogs.toys = { owned = {}, out = {} }
	end
	for key in pairs(Config.DOG_COATS) do
		data.dogs.owned[key] = true
	end
	for key in pairs(Config.DOG_KENNELS) do
		data.dogs.kennels[key] = true
	end
	-- OWNED, NOT OUT. Putting all three toys on the lawn would be this command
	-- making a placement decision on somebody's behalf; the point of it is to
	-- unlock what is buyable, and what is standing where is the next thing a
	-- dev wants to try for themselves.
	for key in pairs(Config.DOG_TOYS) do
		data.dogs.toys.owned[key] = true
	end
	-- The catch effects, added in the same change as the catalogue rather
	-- than the session after it -- which is the entry directly above this
	-- one being obeyed for once instead of recorded again.
	if type(data.catch) ~= "table" then
		data.catch = { owned = {}, equipped = Config.DEFAULT_CATCH }
	end
	for key in pairs(Config.CATCH_EFFECTS) do
		data.catch.owned[key] = true
	end

	RideService.push(player)
	-- applyToPlot rather than setHouseLevel: the sign names the house, so
	-- building it alone leaves the board announcing the old one.
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
	return "Every skin, effect, house, ride, coat, kennel, toy and catch effect unlocked"
end

-- Empties the accessory collection without touching anything else.
--
-- `reset` also clears it, but reset takes the rebirths with it -- and the
-- thing most worth looking at in the collection tab is the LOCKED state,
-- which is unreachable once a save has rolled everything.
-- FIRES YOUR OWN CATCH EFFECT ON YOURSELF, and it exists because the real
-- trigger cannot be reached alone.
--
-- A catch effect goes off when a nab EMPTIES a thief, which needs a second
-- player carrying somebody else's coins -- the same wall the whole heist
-- system is behind, and this project has ten entries under "Not yet
-- verified" that read `needs a second player`. This is the cheap way past
-- it for the half that is purely a picture.
--
-- IT WRITES THE SAME TWO ATTRIBUTES `HeistService` WRITES, in the same
-- order, so what is exercised is the real publish and the real client
-- renderer rather than a second path that could pass while the shipped one
-- fails. What it does NOT exercise is who WINS a multi-nabber tug, which
-- is server arithmetic and still wants two people.
--
-- A server command is not a dev tool until it is on the panel, so it is on
-- the panel.
commands.catchfx = function(player)
	local key = CosmeticsService.catchEffectOf(player)
	if key == Config.DEFAULT_CATCH then
		return "No catch effect equipped -- buy one on the Worn tab first"
	end
	local character = player.Character
	if not character then
		return nil
	end
	character:SetAttribute(Config.CATCH_ATTRIBUTE, key)
	character:SetAttribute(Config.CATCH_COUNT_ATTRIBUTE,
		(character:GetAttribute(Config.CATCH_COUNT_ATTRIBUTE) or 0) + 1)
	return ("Fired %s on you"):format(Config.CATCH_EFFECTS[key].name)
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
	-- The dog's three wardrobes on the same line as its state, because the
	-- question this command gets asked is "why does the dog look like that"
	-- as often as "why is it asleep", and the answer to the first one used to
	-- be nowhere at all.
	local function dogToysOut(d: any): string
		local out = {}
		for key in pairs(Config.DOG_TOYS) do
			if d.toysOut and d.toysOut[key] then
				table.insert(out, key)
			end
		end
		table.sort(out)
		return if #out > 0 then table.concat(out, ",") else "none"
	end
	return ("lvl %d | nap %+.1fs | busy %+.1fs | guard %+.1fs | chasing=%s lured=%s sleeping=%s distracted=%s | offDuty=%s ready=%s | plate=%q"):format(
		dog.level,
		dog.napUntil - now, dog.busyUntil - now, dog.guardUntil - now,
		tostring(dog.chasing), tostring(dog.lured), tostring(dog.sleeping),
		tostring(dog.distracted),
		tostring(GuardDog.isOffDuty(dog)), tostring(GuardDog.isReady(dog)),
		dog.breedLabel.Text)
		.. (" | coat=%q kennel=%q name=%q | toys out: %s"):format(
			dog.coat, dog.kennel, dog.name, dogToysOut(dog))
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
-- PUTS A DELIVERY VAN ON THE ROAD NOW.
--
-- The gap between runs is 70 to 150 seconds, so without this the only way
-- to look at one is to stand on the pavement and wait -- and a van is a
-- thing that has to be LOOKED AT rather than read back, since every claim
-- about it is about how the street reads.
--
-- It goes through `TrafficService.send`, which is the shipped path and
-- refuses for the shipped reason: a van waits out a patrol, and this says
-- so rather than quietly doing nothing.
commands.van = function(player)
	return TrafficService.send()
end

commands.vanoff = function(player)
	return TrafficService.clear()
end

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
	local SneakWalk = require(game:GetService("ReplicatedStorage").Shared.SneakWalk)
	local CarryPose = require(game:GetService("ReplicatedStorage").Shared.CarryPose)

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

	-- THE PLAYER'S OWN ANIMATIONS EACH HAVE THEIR OWN BUILDER, AND THIS USED
	-- TO ASSUME THERE WAS EXACTLY ONE OF THEM.
	--
	-- The ride loop reads `Config.animationKeys`, which is every key the
	-- RUNTIME asks for -- and it fed all of them to `RidePose.buildSequenceFor`
	-- except `dodgeRoll`, on the assumption that everything else is a ride.
	-- The moment a SECOND player-owned animation existed, that assumption put
	-- `sneak` through a builder which knows nothing about the key, got nil
	-- back, and reported it MISSING -- so the one command whose entire job is
	-- producing sequences to upload could not produce the animation that has
	-- to be uploaded before it works live at all.
	--
	-- Exactly the stance bug recorded elsewhere in this project, one layer
	-- along: a key the runtime asks for that the pipeline cannot build, failing
	-- silently at the end nobody looks at. The list is a TABLE rather than a
	-- hardcoded exception now, so a third player-owned animation is one row
	-- here and the ride loop skips it for free.
	local own: { [string]: (() -> Instance?)? } = {
		dodgeRoll = DodgeRoll.buildSequence,
		sneak = SneakWalk.buildSequence,
		carry = CarryPose.buildSequence,
	}
	-- WALKED RATHER THAN LISTED A SECOND TIME, which is what the paragraph
	-- above actually promises. There used to be a hardcoded `{"dodgeRoll",
	-- "sneak"}` here as well as the table, so "one row" was really two -- and
	-- the row that gets forgotten is the loop rather than the builder, because
	-- forgetting the builder throws and forgetting the loop just quietly does
	-- not dump the animation. Sorted so the output does not reshuffle between
	-- runs; `pairs` has no order to rely on.
	local ownNames: { string } = {}
	for name in pairs(own) do
		table.insert(ownNames, name)
	end
	table.sort(ownNames)
	for _, name in ipairs(ownNames) do
		local build = own[name]
		if build then
			put(name, build())
		else
			table.insert(failed, name .. " (no buildSequence export)")
		end
	end
	if RidePose.buildSequenceFor then
		for _, key in ipairs(Config.animationKeys(RidePose.animationKeys())) do
			if own[key] == nil then
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
	local chestKey = tostring(key or "og")
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

-- FORCE A DAILY CLAIM AT A GIVEN RUNG.
--
-- The ladder is seven days long and the interesting rung is the last one, so
-- without this the only way to exercise day seven is to play for a week. It
-- winds `lastDay` back a day and sets the streak to `day - 1`, then claims
-- through the REAL path -- so the rung, the payout, the streak arithmetic and
-- the save all run exactly as they would on a Sunday.
commands.daily = function(player, day)
	local data = DataService.get(player)
	if not data then
		return "no data"
	end
	local want = math.clamp(tonumber(day) or 7, 1, #Config.DAILY_CYCLE)
	data.daily.streak = want - 1
	data.daily.lastDay = Config.dayIndex() - 1
	DailyService.claim(player)
	local reward = Config.dailyReward(want)
	return ("claimed day %d (%s)"):format(want, reward.short or reward.kind)
end

-- WINDS THE DAILY BACK AND LEAVES IT UNCLAIMED, so the mailbox flag goes
-- UP and stays up.
--
-- `commands.daily` above winds the clock back and then CLAIMS in the same
-- breath, which is exactly right for testing a reward and useless for
-- testing the thing that says a reward is waiting: the flag is down again
-- before anybody can look at it. This stops one step short.
--
-- It pushes through `DailyService.push`, which is the one writer that
-- raises the flag AND fills the board -- so what is exercised is the
-- shipped path rather than a second one that could pass while it fails.
commands.post = function(player)
	local data = DataService.get(player)
	if not data then
		return "no data"
	end
	data.daily.lastDay = Config.dayIndex() - 1
	DailyService.push(player)
	return "Daily wound back and left unclaimed -- the flag should be up"
end
commands.combine = function(player, tier, key)
	local t, chestKey = tostring(tier or "common"), tostring(key or "og")
	local target, _, itemKey, dup = ChestService.combine(player, t, chestKey)
	if not target then
		return "refused"
	end
	return ("%s -> %s %s%s"):format(t, target, itemKey, dup and " (dupe)" or "")
end

-- SPARES, AND THE ITEM UNDERNEATH EACH ONE.
--
-- A spare is an EXTRA copy, so handing one out without the base copy would put
-- the save in a state the real code cannot produce: two of something the player
-- does not own. The grant runs first for exactly that reason, and it is what
-- makes this command a usable test of selling as well as of combining -- there
-- is a last copy to sell precisely because there is an item to own.
--
-- One item per tier per COIN chest, so all four tiers are stocked and the two
-- currencies stay apart: the alien cache is skipped, because event loot is not
-- something a dev grant should be able to manufacture by accident.
-- THE TROPHY SHELF, WOUND FORWARD.
--
-- A trophy is a record of things done over an ACCOUNT'S lifetime -- five
-- distinct skins robbed, a hundred thousand coins stolen, three thieves
-- stopped on your own lawn -- so the only honest way to see one without
-- this is to play for an evening with a second player on the street.
-- That is exactly the shape of thing that ships unverified, which is the
-- argument `daily`, `bust` and `dognap` each already make.
--
-- IT WRITES THE COUNTERS AND THEN GOES THROUGH THE REAL PATH.
-- `TrophyService.check` is what a delivery, a nab and an escape all call,
-- so the threshold test, the auto-slot, the toast, the lawn rebuild and
-- the shop push are the shipped code rather than a second copy of it.
-- The one thing faked is how the numbers got that big.
--
-- `n` is how far past each threshold to wind: 1 lands every trophy at its
-- first grade and 4 fills the ladders, which are the two pictures worth
-- looking at.
commands.trophies = function(player, amount)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local n = math.clamp(math.floor(tonumber(amount) or 1), 0, 12)

	if type(data.trophies) ~= "table" then
		data.trophies = { victims = {}, caught = 0, bestSpree = 0,
			plinths = {}, plinth = "" }
	end
	local t = data.trophies

	if n == 0 then
		-- THE WAY BACK, and it has to exist: every other row on this panel
		-- is undone by pressing another one, and a shelf that could only
		-- ever fill would make the empty case -- which is what every new
		-- player sees -- the one state nobody could look at twice.
		t.victims = {}
		t.caught = 0
		data.totalStolen = 0
		if data.gear then
			data.gear.escapes = 0
		end
		for key in pairs(Config.TROPHIES) do
			data.decor.owned[key] = nil
			for slot, placed in pairs(data.decor.placed) do
				if placed == key then
					data.decor.placed[slot] = nil
				end
			end
		end
		local plot = PlotService.getPlot(player)
		if plot then
			PlotService.setDecor(plot, data.decor.placed)
		end
		TrophyService.refresh(player)
		DataService.save(player)
		CosmeticsService.push(player)
		return "Trophy shelf cleared: no skins, no haul, no catches, no escapes."
	end

	-- ROBBED SKINS ARE DEALT FROM THE REAL CATALOGUE, sorted, so the same
	-- press gives the same shelf twice -- and so the rarest-first sort the
	-- case does can be READ rather than taken on trust.
	local want = Config.TROPHIES.victimshelf.need * n
	local keys: { string } = {}
	for key, spec in pairs(Config.SKINS) do
		if not Config.isEarnedElsewhere(spec) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	for i = 1, math.min(want, #keys) do
		t.victims[keys[i]] = true
	end

	t.caught = Config.TROPHIES.medalboard.need * n
	data.totalStolen = math.max(data.totalStolen,
		Config.TROPHIES.haulvault.need * math.pow(2, n - 1))
	if data.gear then
		data.gear.escapes = Config.TROPHIES.sirenpost.need * n
	end

	TrophyService.check(player)
	TrophyService.refresh(player)
	DataService.save(player)
	CosmeticsService.push(player)

	local seen = 0
	for _ in pairs(t.victims) do
		seen += 1
	end
	return ("Trophies: %d skins robbed, %s stolen, %d caught, %d escapes."):format(
		seen, Config.formatCoins(data.totalStolen), t.caught,
		(data.gear and data.gear.escapes) or 0)
end

-- Stands every trophy on a plinth without paying for it. Separate from
-- the row above because the two halves of this shelf are deliberately
-- bought and earned, and a dev trigger that did both at once would make
-- the one picture worth checking -- a full case on bare concrete --
-- unreachable.
commands.plinth = function(player, key)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local want = if type(key) == "string" then key else ""
	if want ~= "" and not Config.TROPHY_PLINTHS[want] then
		return ("No such plinth: %s"):format(want)
	end
	if type(data.trophies) ~= "table" then
		return nil
	end
	if want ~= "" then
		data.trophies.plinths[want] = true
	end
	data.trophies.plinth = want
	TrophyService.refresh(player)
	DataService.save(player)
	CosmeticsService.push(player)
	return ("Trophies now stand on %s."):format(
		Config.trophyPlinth(want).name)
end

commands.spares = function(player, amount)
	local data = DataService.get(player)
	local n = tonumber(amount) or 3
	if not data then
		return nil
	end

	local granted, added = 0, 0
	for chestKey, chest in pairs(Config.CHESTS) do
		if (chest.currency or "coins") == "coins" then
			local _, pool = ChestService.liveOdds(chestKey)
			for _, tier in ipairs({ "common", "rare", "epic", "legendary" }) do
				local entries = pool[tier]
				if entries and #entries > 0 then
					local kind, key = Config.chestEntry(chestKey, entries[1])
					if SetService.grant(player, kind, key) then
						granted += 1
					end
					local id = kind .. ":" .. key
					data.spares[id] = (data.spares[id] or 0) + n
					added += n
				end
			end
		end
	end

	ChestService.push(player)
	return ("Spares: +%d across the coin chests, %d items granted"):format(added, granted)
end

-- Grants loot. Earning it legitimately means delivering a robbery, and the
-- roll button and the set panel both read the balance, so a dev grant has to
-- push -- which SetService.award already does.
commands.loot = function(player, amount)
	local n = if type(amount) == "number" then math.floor(amount) else 0
	if n ~= 0 then
		SetService.award(player, n, "Dev grant.")
	else
		SetService.push(player)
	end
	return ("Loot: %d"):format(SetService.getLoot(player))
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
-- Note the board only picks somebody up on its refresh tick, so it says the
-- sheet back rather than the winner. Any amount at all now puts you on the
-- poster if it is the biggest in the server -- the income floor no longer
-- gates that, only whether the PATROL comes for you.
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
	-- "limit" was the retired per-victim cap; only the cooldown is left.
	return ("Open season: %d shield(s) dropped, %d cooldown pair(s) cleared"):format(
		shields, cooldowns)
end

commands.reset = function(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	data.coins = 0
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
