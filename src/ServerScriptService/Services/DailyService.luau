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
	-- anybody finish the thief's collection. See Config.LOOT.

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
	end

	notify(player, message, "good")
	DataService.save(player)
	DailyService.push(player)
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
