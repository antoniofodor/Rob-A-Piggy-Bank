--!strict
--[[
	LassoService -- catching a wild piggy (docs/LASSO-PLAN.md).

	A catch is a THROW AND A ROLL, never a hold (designer, 2026-09-23). The
	client locks on to a landed piggy by the id `HerdService` stamps on it
	(`Config.LASSO_TARGET_ATTRIBUTE`) and sends that id and nothing else; this
	file decides everything about whether the throw may happen, spends the
	lasso, runs the rope, counts the taps, rolls, and hands a caught piggy to
	`PiggyHaulService` to be carried home.

	THE ORDER OF A THROW, AND WHY EVERY REFUSAL IS BEFORE THE SPEND.
	  1. A lasso in hand, with stock behind it.
	  2. Empty hands and no rope already out.
	  3. The piggy exists, is on the ground, is nobody's yet, and has no rope
	     on it (ONE ROPE AT A TIME -- designer).
	  4. Within `LASSO.range + slack` of it.
	  5. A dazed piggy inside its catcher window: only the catcher.
	  6. Somewhere at home to put it.
	Only then is one lasso spent. A lasso spent on a refusal is an item that
	appears broken, which is the failure this project refuses above all others.

	THE ROPE: `flight`, then the `struggle`. During the struggle the piggy is
	LOCKED (`HerdService.setBusy`) and taps from the thrower -- and only the
	thrower -- are counted against the SERVER clock, capped at `tapRate` a
	second from the moment the struggle began, so an autoclicker earns exactly
	what a fast child earns (the crack's argument). Walking past `leash`,
	dying or leaving snaps the rope, which is a miss.

	THE ROLL IS `Config.lassoChance` AND NOTHING ELSE. `misses` comes from a
	pity table keyed by (thrower, piggy) that belongs to that thrower alone
	and is dropped when the piggy leaves the wild (caught, recalled, woken
	from a daze) -- `HerdService.registerGone` tells us.

	WHAT CROSSES THE WIRE: `LassoThrow(id)`, `LassoTap()` and `LassoBuy(key,
	count?)` in; `LassoState` to everybody (the rope is a picture the whole
	street sees) and `LassoStock` to one player out. Every number a player is
	shown about the odds is `Config.lassoDescription`, generated from the same
	table this rolls against.

	THE ELITE LASSO IS A PAID RANDOM ITEM. It is bought through
	`ProductService` (the same `PolicyService` gate and receipt ledger the
	crates use), never here, and nothing turns one into coins.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local HeldItemService = require(script.Parent.HeldItemService)
local HerdService = require(script.Parent.HerdService)
local PiggyHaulService = require(script.Parent.PiggyHaulService)
local HeistService = require(script.Parent.HeistService)
local ProductService = require(script.Parent.ProductService)

local LassoService = {}

type Rope = {
	id: string,
	thrower: Player,
	key: string,
	rarity: string,
	-- "flight" | "struggle"
	phase: string,
	startedAt: number,
	struggleStart: number,
	endsAt: number,
	taps: number,
}

-- [target id] = the rope on it. One per piggy by construction.
local ropes: { [string]: Rope } = {}
-- [thrower] = the id their rope is on. One per thrower.
local ropeOf: { [Player]: string } = {}
-- [thrower][target id] = misses. The thrower's alone, and only on that piggy.
local pity: { [Player]: { [string]: number } } = {}
-- What each player was last pushed, so a price change (a level, a rebirth)
-- is noticed by the slow poll rather than by a hook into every service that
-- can move one.
local lastPriced: { [Player]: string } = {}

-- The roll, injectable so a suite can drive both outcomes.
local random: () -> number = math.random

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function alive(player: Player): boolean
	if player.Parent == nil then
		return false
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.Health > 0 and rootOf(player) ~= nil
end

local function skinName(key: string): string
	local skin = Config.SKINS[key]
	return if skin and skin.name then skin.name else key
end

local function stockOf(data: any): { [string]: number }
	if type(data.consumables) ~= "table" then
		data.consumables = {}
	end
	return data.consumables
end

-- EVERYBODY SEES THE ROPE. `startedAt`/`endsAt` are always numbers in server
-- time, so a client can draw the flight and the TAP bar off one clock.
local function broadcast(rope: Rope, phase: string, startedAt: number, endsAt: number)
	Remotes.get("LassoState"):FireAllClients({
		id = rope.id,
		thrower = rope.thrower.UserId,
		key = rope.key,
		rarity = rope.rarity,
		phase = phase,
		startedAt = startedAt,
		endsAt = endsAt,
	})
end

-- ============================================================
-- STOCK AND PRICES
-- ============================================================

function LassoService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local stock = stockOf(data)
	local held: { [string]: number } = {}
	local prices: { [string]: number } = {}
	local incomeLevel = tonumber((data :: any).incomeLevel) or 1
	local rebirths = tonumber((data :: any).rebirths) or 0
	local elite = { allowed = not ProductService.restricted(player), productId = 0 }
	for key, spec in pairs(Config.LASSOS) do
		held[key] = stock[key] or 0
		local price = Config.lassoPrice(key, incomeLevel, rebirths)
		if price then
			prices[key] = price
		end
		if spec.robux then
			elite.productId = tonumber(spec.productId) or 0
		end
	end
	lastPriced[player] = ("%d:%d"):format(incomeLevel, rebirths)
	Remotes.get("LassoStock"):FireClient(player, {
		stock = held,
		prices = prices,
		rebirths = rebirths,
		elite = elite,
	})
end

-- THE STARTER STOCK, ONCE PER SAVE. A new player with no lassos and no coins
-- cannot catch anything, so a save starts with `Config.LASSO.starter`. The
-- flag rather than the stock decides it: a player who spends every lasso must
-- not be handed the starter again on the next join.
function LassoService.grantStarter(player: Player): boolean
	local data = DataService.get(player)
	if not data or (data :: any).lassoStarter == true then
		return false
	end
	local stock = stockOf(data)
	for key, n in pairs(Config.LASSO.starter) do
		if Config.LASSOS[key] then
			stock[key] = (stock[key] or 0) + n
		end
	end;
	(data :: any).lassoStarter = true
	DataService.save(player)
	return true
end

function LassoService.onPlayerReady(player: Player)
	LassoService.grantStarter(player)
	LassoService.push(player)
end

-- A COIN LASSO. The Elite tier is refused here and bought through
-- `ProductService`: a Robux chance is a paid random item and has one door.
function LassoService.buy(player: Player, key: any, count: any)
	if type(key) ~= "string" then
		return
	end
	local spec = Config.LASSOS[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end
	if spec.robux then
		notify(player, ("The %s is bought with Robux in the shop."):format(spec.name), "warn")
		return
	end
	local rebirths = tonumber((data :: any).rebirths) or 0
	if (spec.rebirths or 0) > rebirths then
		notify(player, ("Rebirth %d unlocks the %s."):format(spec.rebirths, spec.name), "warn")
		return
	end
	local n = math.clamp(math.floor(tonumber(count) or 1), 1, 10)
	local each = Config.lassoPrice(key, tonumber((data :: any).incomeLevel) or 1, rebirths)
	if not each then
		return
	end
	local price = each * n
	if (data.coins or 0) < price then
		notify(player, ("Need %s more coins for %s."):format(
			Config.formatCoins(price - (data.coins or 0)),
			if n == 1 then "a " .. spec.name else ("%d %ss"):format(n, spec.name)), "warn")
		return
	end
	data.coins -= price
	local stock = stockOf(data)
	stock[key] = (stock[key] or 0) + n
	DataService.save(player)
	LassoService.push(player)
	notify(player, ("%s bought. You have %d."):format(
		if n == 1 then spec.name else ("%d %ss"):format(n, spec.name), stock[key]), "good")
end

-- THE ELITE RECEIPT, registered with `ProductService`, which has already
-- recorded it and asked the policy gate. A pack into the stock; never coins.
function LassoService.grantPack(player: Player, key: string): boolean
	local spec = Config.LASSOS[key]
	local data = DataService.get(player)
	if not spec or not spec.robux or not data then
		return false
	end
	local stock = stockOf(data)
	stock[key] = (stock[key] or 0) + (spec.pack or 1)
	DataService.save(player)
	LassoService.push(player)
	notify(player, ("%d %ss added. You have %d."):format(spec.pack or 1, spec.name, stock[key]), "good")
	return true
end

-- ============================================================
-- THE THROW
-- ============================================================

-- The pity a thrower has built on one piggy.
function LassoService.missesOf(player: Player, id: string): number
	local mine = pity[player]
	return if mine then mine[id] or 0 else 0
end

-- Every refusal, in the order the header gives, before anything is spent.
-- Returns the reason, or nil and what the throw needs.
local function whyNot(player: Player, id: any): (string?, any?)
	local key = HeldItemService.get(player)
	local spec = if key then Config.LASSOS[key] else nil
	if not key or not spec then
		return "Hold a lasso out first.", nil
	end
	local data = DataService.get(player)
	if not data then
		return "Your save is not loaded yet. Try again in a moment.", nil
	end
	if (stockOf(data)[key] or 0) <= 0 then
		return ("You have no %s left."):format(spec.name), nil
	end
	if ropeOf[player] then
		return "You already have a rope out.", nil
	end
	if PiggyHaulService.isHauling(player) or HeistService.isCarrying(player) then
		return "Your hands are full already.", nil
	end
	if type(id) ~= "string" then
		return "There is no piggy there.", nil
	end
	local herd, member = HerdService.find(id)
	if not herd or not member or member.taken then
		return "That piggy is gone.", nil
	end
	if not HerdService.onGround(herd, member) then
		return "That one is not on the ground yet.", nil
	end
	if ropes[id] or member.busy ~= nil then
		return "Somebody already has a rope on that one.", nil
	end
	local root = rootOf(player)
	if not root or not alive(player) then
		return "You cannot throw right now.", nil
	end
	if (root.Position - member.at).Magnitude > Config.LASSO.range + Config.LASSO.slack then
		return "Get closer to lasso it.", nil
	end
	local dazed = member.dazed
	if dazed and dazed.catcher ~= nil and dazed.catcher ~= player.UserId and now() < dazed.openAt then
		local owner = Players:GetPlayerByUserId(dazed.catcher)
		return ("Only %s can grab that one for %ds."):format(
			if owner then owner.DisplayName else "its catcher",
			math.max(1, math.ceil(dazed.openAt - now()))), nil
	end
	if not PiggyHaulService.hasRoom(player) then
		return "No room at home. Make room on your lawn or in your hallway first.", nil
	end
	return nil, { key = key, spec = spec, data = data, member = member }
end

function LassoService.throw(player: Player, id: any): boolean
	local why, ctx = whyNot(player, id)
	if why then
		notify(player, why, "warn")
		return false
	end
	local key: string = ctx.key
	local member = ctx.member
	local data = ctx.data

	-- SPENT NOW, caught or not (designer): a miss visibly snaps it.
	local stock = stockOf(data)
	stock[key] = (stock[key] or 0) - 1
	DataService.save(player)
	LassoService.push(player)
	HeldItemService.revalidate(player)

	local t = now()
	local rope: Rope = {
		id = id :: string,
		thrower = player,
		key = key,
		rarity = member.tier,
		phase = "flight",
		startedAt = t,
		struggleStart = t + Config.LASSO.flight,
		endsAt = t + Config.LASSO.flight + Config.LASSO.struggle,
		taps = 0,
	}
	ropes[rope.id] = rope
	ropeOf[player] = rope.id
	HerdService.setBusy(rope.id, player.UserId)
	broadcast(rope, "flight", t, rope.struggleStart)
	return true
end

-- A TAP COUNTS ONLY IN THE STRUGGLE, ONLY FROM THE THROWER, and only while
-- the running total is under what `tapRate` allows since the struggle began.
-- A budget rather than a gap between taps, so a child tapping unevenly at
-- the cap is not penalised for network jitter.
function LassoService.tap(player: Player)
	local id = ropeOf[player]
	local rope = if id then ropes[id] else nil
	if not rope or rope.phase ~= "struggle" then
		return
	end
	local t = now()
	if t < rope.struggleStart or t >= rope.endsAt then
		return
	end
	local allowed = math.floor((t - rope.struggleStart) * Config.LASSO.tapRate) + 1
	if rope.taps < allowed then
		rope.taps += 1
	end
end

local function endRope(rope: Rope)
	ropes[rope.id] = nil
	if ropeOf[rope.thrower] == rope.id then
		ropeOf[rope.thrower] = nil
	end
	HerdService.setBusy(rope.id, nil)
end

-- A rope whose piggy vanished under it (caught by a pick-up race, cleared by
-- the admin, recalled): it simply goes, and every client is told so -- a rope
-- left drawn to nothing is the picture lying.
local function vanish(rope: Rope)
	endRope(rope)
	local t = now()
	broadcast(rope, "snapped", t, t)
end

local function snap(rope: Rope, why: string?)
	endRope(rope)
	local player = rope.thrower
	local mine = pity[player]
	if not mine then
		mine = {}
		pity[player] = mine
	end
	mine[rope.id] = (mine[rope.id] or 0) + 1
	local t = now()
	broadcast(rope, "snapped", t, t)
	local root = rootOf(player)
	if root then
		HerdService.flee(rope.id, root.Position)
	end
	if player.Parent then
		notify(player, why or "The rope snapped! It got away -- your odds on it are better now.", "warn")
	end
end

local function caught(rope: Rope)
	local player = rope.thrower
	local herd, member = HerdService.find(rope.id)
	-- WHOSE DROPPED CATCH THIS WAS, read before it leaves the wild. Lassoing
	-- somebody else's is a robbery; the catcher lassoing their own is not.
	local robbed: Player? = nil
	if member and member.dazed and member.dazed.catcher ~= nil and member.dazed.catcher ~= player.UserId then
		robbed = Players:GetPlayerByUserId(member.dazed.catcher)
	end
	endRope(rope)
	if not herd or not member then
		return
	end
	local key = HerdService.take(rope.id)
	if not key then
		return
	end
	local ok, why = PiggyHaulService.startWild(player, key, robbed, false)
	if ok then
		-- THE LASSO GOES AWAY THE MOMENT A PIGGY IS IN YOUR ARMS (designer,
		-- 2026-09-23: a catch "should then look like a regular carry and the
		-- lasso is put away"). Silent: the catch toast is the news. `Main`'s
		-- veto stops it being drawn again until the carry ends.
		HeldItemService.putAway(player)
	end
	if not ok then
		-- Hands filled during the struggle: it lands dazed at their feet, the
		-- catch theirs to pick up, rather than vanishing.
		local root = rootOf(player)
		if root then
			HerdService.spawnDazed(key, root.Position, player.UserId)
		end
		notify(player, why or "You could not hold on to it.", "warn")
	else
		notify(player, ("You caught %s! Carry it home to keep it."):format(skinName(key)), "good")
	end
	local t = now()
	broadcast(rope, "caught", t, t)
	if ok and robbed and robbed.Parent then
		notify(robbed, ("%s lassoed your %s!"):format(player.DisplayName, skinName(key)), "alarm")
	end
end

local function resolve(rope: Rope)
	local misses = LassoService.missesOf(rope.thrower, rope.id)
	local chance = Config.lassoChance(rope.key, rope.rarity, rope.taps, misses)
	if random() < chance then
		caught(rope)
	else
		snap(rope, nil)
	end
end

-- ONE POLL FOR EVERY ROPE: the phases, the leash, and a thrower who died or
-- left. A poll rather than timers, because a rope has four endings and a
-- timer per ending is four cancellations waiting to be forgotten.
function LassoService.step()
	local t = now()
	for id, rope in pairs(table.clone(ropes)) do
		local player = rope.thrower
		local herd, member = HerdService.find(id)
		if not herd or not member or member.taken then
			vanish(rope)
		elseif not alive(player) then
			snap(rope, nil)
		else
			local root = rootOf(player)
			if root and (root.Position - member.at).Magnitude > Config.LASSO.leash then
				snap(rope, "You walked too far and the rope snapped!")
			elseif rope.phase == "flight" and t >= rope.struggleStart then
				rope.phase = "struggle"
				broadcast(rope, "struggle", rope.struggleStart, rope.endsAt)
			elseif rope.phase == "struggle" and t >= rope.endsAt then
				resolve(rope)
			end
		end
	end
end

-- A DAZED PIGGY PICKED UP BY HAND: the catcher, and only the catcher.
function LassoService.pickup(player: Player, id: string)
	local herd, member = HerdService.find(id)
	if not herd or not member or member.taken or not member.dazed then
		notify(player, "That piggy is gone.", "warn")
		return
	end
	if member.dazed.catcher ~= player.UserId then
		notify(player, "That is not your catch. Lasso it instead.", "warn")
		return
	end
	if ropes[id] or member.busy ~= nil then
		notify(player, "Somebody already has a rope on that one.", "warn")
		return
	end
	if PiggyHaulService.isHauling(player) or HeistService.isCarrying(player) then
		notify(player, "Your hands are full already.", "warn")
		return
	end
	local root = rootOf(player)
	if not root or (root.Position - member.at).Magnitude > Config.HERDS.range + 4 then
		notify(player, "Get closer to pick it up.", "warn")
		return
	end
	if not PiggyHaulService.hasRoom(player) then
		notify(player, "No room at home. Make room on your lawn or in your hallway first.", "warn")
		return
	end
	local key = HerdService.take(id)
	if not key then
		return
	end
	local ok, why = PiggyHaulService.startWild(player, key, nil, true)
	if ok then
		HeldItemService.putAway(player)
	end
	if not ok then
		HerdService.spawnDazed(key, root.Position, player.UserId)
		notify(player, why or "You could not hold on to it.", "warn")
	end
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

local function forget(player: Player)
	local id = ropeOf[player]
	if id and ropes[id] then
		vanish(ropes[id])
	end
	ropeOf[player] = nil
	pity[player] = nil
	lastPriced[player] = nil
end

-- A PIGGY LEFT THE WILD: every pity ladder on it goes, for everybody.
local function gone(id: string)
	for _, mine in pairs(pity) do
		mine[id] = nil
	end
	local rope = ropes[id]
	if rope then
		vanish(rope)
	end
end

-- A price moved (a level bought, a rebirth): push the new card.
local function repriceAll()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		if data then
			local stamp = ("%d:%d"):format(tonumber((data :: any).incomeLevel) or 1, tonumber((data :: any).rebirths) or 0)
			if lastPriced[player] ~= nil and lastPriced[player] ~= stamp then
				LassoService.push(player)
			end
		end
	end
end

-- Test seams: the roll, the clock-free step, and the tables.
LassoService._setRandom = function(fn: () -> number)
	random = fn
end
LassoService._ropes = ropes
LassoService._pity = pity
LassoService._gone = gone
LassoService._forget = forget

function LassoService.start()
	HerdService.registerGone(gone)
	HerdService.registerPickup(LassoService.pickup)
	PiggyHaulService.registerWild(HerdService.spawnDazed, HerdService.grantAt)
	ProductService.onLassoReceipt(LassoService.grantPack)
	-- The Elite card's "may this player buy it" arrives a beat after the join.
	ProductService.onPolicy(LassoService.push)

	Remotes.get("LassoThrow").OnServerEvent:Connect(function(player, id)
		LassoService.throw(player, id)
	end)
	Remotes.get("LassoTap").OnServerEvent:Connect(function(player)
		LassoService.tap(player)
	end)
	Remotes.get("LassoBuy").OnServerEvent:Connect(function(player, key, count)
		LassoService.buy(player, key, count)
	end)

	-- PCALLED, the call the herd and the dog watcher make: a rope is a
	-- minigame next to the game underneath it, and a bad frame of it may
	-- never stop anybody playing. Warned once.
	local warned = false
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(LassoService.step)
		if not ok and not warned then
			warned = true
			warn(("[LassoService] step failed: %s"):format(tostring(err)))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(repriceAll)
		end
	end)
	Players.PlayerRemoving:Connect(forget)
end

return LassoService
