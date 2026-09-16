--!strict
--[[
	DailyService

	One claim a day, on a seven-day cycle that repeats.

	The ladder lives in Config.DAILY_CYCLE and is fixed and published: you can
	see day 7 from day 1, and nothing about a claim is random. That is the wall
	rather than a preference -- coins are sellable, so a random daily reward
	would be a random outcome sitting downstream of a coin purchase.

	Days are UTC day INDICES, not timestamps. The only question ever asked is
	"which day was that", and storing the day directly means no clock, timezone
	or daylight saving can get between the save and the answer. It also makes
	the claim unforgeable from the client: the server reads its own os.time and
	the client sends nothing but "I would like to claim".

	Boosts are granted into a pocket, never applied on claim. See Config.BOOSTS.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local StealthService = require(script.Parent.StealthService)
local CosmeticsService = require(script.Parent.CosmeticsService)
-- For the mailbox flag. Safe rather than a cycle: PlotService requires
-- PiggyBank, GuardDog, House, Decor, GrassTuft, SoundKit and ThiefModel,
-- and none of them reaches back here.
local PlotService = require(script.Parent.PlotService)

local DailyService = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

-- Streak state for a save, as of now. Returns the streak the NEXT claim would
-- be worth, and whether there is a claim available at all.
--
-- Kept separate from claiming so the panel and the grant agree by
-- construction: the number on the button is computed by the same function
-- that pays out.
local function pending(data: any): (number, boolean)
	local today = Config.dayIndex()
	local last = data.daily.lastDay

	if last == today then
		return data.daily.streak, false
	end
	-- One missed day is forgiven, two ends it. Config.DAILY_GRACE_DAYS.
	if last > 0 and today - last <= Config.DAILY_GRACE_DAYS then
		return data.daily.streak + 1, true
	end
	return 1, true
end

function DailyService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local streak, claimable = pending(data)
	local _, day = Config.dailyReward(streak)

	-- THE FLAG RIDES THE SAME PUSH THE BOARD DOES, which is what makes them
	-- impossible to disagree.
	--
	-- The obvious alternative is to raise it once at join and lower it on
	-- claim, and that is two writers for one fact: a claim that failed, a
	-- streak that lapsed while somebody was standing there, a dev command
	-- winding the clock back -- each is a path where one of the two moves
	-- and the other does not. `push` already runs at every one of those
	-- moments, because the BOARD has to be right at every one of them.
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.setMail(plot, claimable)
		-- AND THE CRATE RIDES THE SAME PUSH, for the identical reason. It is
		-- a fact in the save -- `daily.crate` is the chest this player is
		-- still owed -- and `push` already runs at every moment that fact can
		-- change: the claim that creates one, the open that clears one, and
		-- the first push after a rejoin, which is what puts a crate back on
		-- the step for somebody who dropped before walking over to it.
		--
		-- An empty string is nothing rather than a chest named "", which is
		-- what `setCrate` turns into a hidden box.
		local owed = data.daily.crate
		PlotService.setCrate(plot, if owed ~= "" then owed else nil)
	end

	Remotes.get("DailyState"):FireClient(player, {
		claimable = claimable,
		streak = data.daily.streak,
		nextStreak = streak,
		day = day,
		lifetime = data.daily.lifetime,
		boosts = data.boosts,
		-- Seconds left rather than an absolute time: the client's clock is not
		-- the server's, and a countdown is the only thing the HUD does with it.
		boostLeft = math.max(0, data.boostUntil - os.time()),
	})
end

-- What one reward is worth to THIS player, right now.
--
-- Coin rewards are seconds of their own income, so the ladder keeps its value
-- from the first day to the thousandth. The floor is what stops a brand new
-- player being handed 3,000 coins for a week of turning up.
local function coinValue(data: any, reward: any): number
	local rate = Config.getIncomeRate(data.incomeLevel, data.rebirths, 0)
	return math.max(reward.floor, math.floor(rate * reward.seconds))
end

function DailyService.claim(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local streak, claimable = pending(data)
	if not claimable then
		-- Never fail silently: a rejection the player cannot see is
		-- indistinguishable from a broken button.
		notify(player, "You have already claimed today. Come back tomorrow!", "warn")
		return
	end

	local reward = Config.dailyReward(streak)

	data.daily.lastDay = Config.dayIndex()
	data.daily.streak = streak
	data.daily.lifetime += 1

	-- NO LOOT HERE, since the pivot: loot is the currency you go out and
	-- earn, and a ladder that paid it would let a player who never robs
	-- anybody finish the thief's collection. See Config.ACORNS.

	local message
	if reward.kind == "coins" then
		local amount = coinValue(data, reward)
		data.coins += amount
		message = ("Day %d: %s coins!"):format(streak, tostring(amount))
	elseif reward.kind == "boost" then
		data.boosts[reward.boost] = (data.boosts[reward.boost] or 0) + 1
		local boost = Config.BOOSTS[reward.boost]
		message = ("Day %d: %s for %d minutes. Tap it when your piggy bank has room!")
			:format(streak, boost.name, boost.seconds // 60)
	elseif reward.kind == "bone" then
		data.consumables[reward.bone] = (data.consumables[reward.bone] or 0) + reward.count
		message = ("Day %d: %s!"):format(streak, reward.label)
	elseif reward.kind == "golden" then
		data.consumables.golden = (data.consumables.golden or 0) + 1
		local amount = coinValue(data, reward)
		data.coins += amount
		message = ("Day %d: a Golden Bone and %s coins!"):format(streak, tostring(amount))
	elseif reward.kind == "crate" then
		local chest = Config.CHESTS[reward.crate]
		-- THE CRATE IS OWED, NOT OPENED. Written into the save here and paid
		-- out at the doorstep, which is the whole of what moved: the reveal
		-- used to fire while the player was still looking at this board, so
		-- the one rung on the ladder that pays something playing cannot had
		-- no moment of its own.
		--
		-- It survives a disconnect BY DESIGN. That is the price of moving it
		-- out of the claim: a player who drops between pressing this and
		-- reaching their own front door would otherwise lose a seven-day
		-- streak's reward to a dropped session, which is the worst thing this
		-- ladder could do to somebody who has turned up all week.
		data.daily.crate = reward.crate
		message = ("Day %d: a free %s! It is on your doorstep."):format(
			streak, chest and chest.name or "crate")
	end

	notify(player, message, "good")

	DataService.save(player)
	DailyService.push(player)
end

-- OPENING WHAT IS ON THE STEP.
--
-- THE SAME ORDERING AS THE CLAIM, AND FOR THE SAME REASON. The field is
-- cleared and SAVED before `grantFree` runs, because that call grants an
-- item, writes spares, pushes two balances and fires a reveal -- so paying
-- out first and clearing afterwards would let a disconnect in the middle
-- leave a crate still standing on a step that has already been opened.
-- The other order costs a dropped reveal in the same window and hands out
-- nothing twice, which is the side this project has already chosen once.
--
-- Required lazily rather than at the top of the file: ChestService reaches
-- SetService, which reaches the five catalogues' own services, and pulling
-- that chain in at load time from here is how a require cycle gets built.
function DailyService.openCrate(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local key = data.daily.crate
	if key == "" or not Config.CHESTS[key] then
		-- Never fail silently. The prompt is switched off in both of these
		-- states, so reaching here means a client fired the remote by hand --
		-- and a chest retired out from under a save lands here too, which is
		-- the case worth saying something about.
		data.daily.crate = ""
		notify(player, "There is nothing on your doorstep.", "warn")
		DailyService.push(player)
		return
	end

	data.daily.crate = ""
	DataService.save(player)
	-- The step is cleared BEFORE the reveal, so the box is gone by the time
	-- the reel is on screen rather than a second afterwards.
	DailyService.push(player)

	local ChestService = require(script.Parent.ChestService)
	ChestService.grantFree(player, key)
end

-- Activating a boost the player already holds.
--
-- Refuses while one is already running rather than stacking or queueing. Two
-- 2x boosts running at once would be 4x, which is a number nothing in the
-- economy was balanced against, and silently extending the first one instead
-- would spend a reward the player thought they were saving.
function DailyService.useBoost(player: Player, key: string)
	local data = DataService.get(player)
	if not data then
		return
	end

	local boost = Config.BOOSTS[key]
	if not boost then
		return
	end

	if (data.boosts[key] or 0) <= 0 then
		notify(player, "You don't have that boost.", "warn")
		return
	end

	if data.boostUntil > os.time() then
		notify(player, ("A boost is already running. %d seconds left.")
			:format(data.boostUntil - os.time()), "warn")
		return
	end

	data.boosts[key] -= 1
	data.boostUntil = os.time() + boost.seconds
	data.boostMult = boost.multiplier

	notify(player, ("%s active for %d minutes!"):format(boost.name, boost.seconds // 60), "good")
	DailyService.push(player)
end

-- The live multiplier, for the accrual loop. Expired boosts read as 1.
function DailyService.getMultiplier(player: Player): number
	local data = DataService.get(player)
	if not data or data.boostUntil <= os.time() then
		return 1
	end
	return data.boostMult
end

-- Called by Main once the save is loaded, before the first push.
--
-- A boost bought before a rejoin has almost always expired by the time the
-- player is back, and a stale boostUntil would leave a save holding a
-- multiplier it is no longer entitled to.
function DailyService.onPlayerReady(player: Player)
	local data = DataService.get(player)
	if data and data.boostUntil <= os.time() then
		data.boostUntil = 0
		data.boostMult = 1
	end
	DailyService.push(player)
end

function DailyService.start()
	-- THE MAILBOX IS THE WAY BACK TO THE BOARD, and until now there was not
	-- one.
	--
	-- The board opens itself 1.5 seconds after joining, once per session, and
	-- nothing else in the game opened it -- so a player who closed it without
	-- claiming had lost the day, with a reward still sitting there and
	-- nothing on screen to say so. That is the silent-failure rule broken by
	-- an absence rather than by a refusal.
	--
	-- IT SENDS NOTHING. The client already holds the whole snapshot from
	-- `DailyState`; this says "look at it", which is the same shape as every
	-- other click in this game meaning "now" rather than "now, and here is
	-- the outcome".
	PlotService.onMailCheck(function(player: Player)
		Remotes.get("DailyOpen"):FireClient(player)
	end)

	-- AND THE DOORSTEP CRATE, which is the day-seven reward given a moment
	-- of its own. Registered here rather than in PlotService for the reason
	-- the mailbox is: PlotService stands the box up and detects the press,
	-- and this service owns the save field that says what is in it.
	PlotService.onCrateOpen(function(player: Player)
		DailyService.openCrate(player)
	end)

	Remotes.get("DailyRequest").OnServerEvent:Connect(function(player)
		DailyService.claim(player)
	end)

	Remotes.get("BoostUse").OnServerEvent:Connect(function(player, key)
		-- Nothing but climbing out, while you are in a bin. The client hides
		-- the control, so this only ever fires for a client that was written
		-- to ignore it.
		if StealthService.isHidden(player) then
			return
		end
		if type(key) == "string" then
			DailyService.useBoost(player, key)
		end
	end)
end

return DailyService
