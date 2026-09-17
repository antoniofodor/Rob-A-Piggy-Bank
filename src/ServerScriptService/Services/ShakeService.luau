--!strict
-- Tree/ground stock is separate from spendable storage. Every accepted drag
-- moves one server-owned Acorn into refundable carry escrow, never the HUD wallet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ResidentService = require(script.Parent.ResidentService)

local ShakeService = {}
local hooks: any
local active: { [Player]: any } = {}
local cooldowns: { [number]: { [number]: number } } = {}
local serial = 0
local cooldownReady: { [Player]: number } = {}
local function pushCooldowns(thief: Player)
	local now, snapshot = workspace:GetServerTimeNow(), {}
	for victimId, byThief in pairs(cooldowns) do
		local deadline = byThief[thief.UserId]
		if deadline and deadline > now then snapshot[victimId] = deadline end
	end
	Remotes.get("AcornCooldown"):FireClient(thief, snapshot)
end
local function wallet(victim: any): any
	return if hooks.player(victim) then DataService.get(victim) else victim.acornStock
end
local function balance(victim: any, source: string): number
	local data = wallet(victim)
	if not data then return 0 end
	return math.max(0, math.floor(if source == "tree" then data.groundAcorns or 0
		else if hooks.player(victim) then data.loot else data.acorns or 0))
end
local function publish(victim: any)
	local plot, data = hooks.plot(victim), wallet(victim)
	if plot and data and (plot.owner or ResidentService.get(plot)) == victim then
		PlotService.updateAcorns(plot, balance(victim, "storage"))
		if hooks.player(victim) then
			-- A player's tree also carries the owner's next-acorn clock.
			PlotService.publishTree(plot, data)
		else
			PlotService.updateTreeAcorns(plot, data.treeAcorns or 0, data.groundAcorns or 0)
		end
	end
	if hooks.player(victim) then hooks.pushBalance(victim) end
end
local function change(victim: any, source: string, delta: number): boolean
	local data = wallet(victim)
	if not data then return false end
	if source == "tree" then data.groundAcorns = (data.groundAcorns or 0) + delta
	elseif hooks.player(victim) then data.loot += delta
	else data.acorns = (data.acorns or 0) + delta end
	publish(victim)
	return true
end
local function reserved(victim: any, source: string): number
	local total = 0
	for _, attempt in pairs(active) do
		if attempt.source == source and hooks.id(attempt.victim) == hooks.id(victim) then total += attempt.take - attempt.caught end
	end
	return total
end
local function valid(thief: Player, attempt: any): string?
	local plot = attempt.plot
	if not thief.Parent or not DataService.get(thief) then return "gone" end
	local root, humanoid = hooks.root(thief), hooks.humanoid(thief)
	local target = if attempt.source == "storage" then plot.acornStorage and plot.acornStorage.body
		else plot.acornTree and plot.acornTree.collider
	if not root or not humanoid or humanoid.Health <= 0 or not target or not target.Parent then return "gone" end
	if (root.Position - target.Position).Magnitude > Config.STEAL_RANGE + 4 then return "range" end
	if (plot.owner or ResidentService.get(plot)) ~= attempt.victim then return "gone" end
	if hooks.disabled(thief) then return "stopped" end
	local owner = plot.owner
	if owner and owner ~= thief then
		local ownerRoot, ownerHumanoid = hooks.root(owner), hooks.humanoid(owner)
		if ownerRoot and ownerHumanoid and ownerHumanoid.Health > 0
			and (ownerRoot.Position - target.Position).Magnitude <= Config.OWNER_INTERRUPT_RANGE then return "chased" end
	end
	return nil
end
local function push(thief: Player, attempt: any?, reason: string?, id: number?)
	Remotes.get("ShakeState"):FireClient(thief, if attempt then {
		id = attempt.id, count = attempt.take, caught = attempt.caught, source = attempt.source,
		startedAt = attempt.startedAt, endsAt = attempt.endsAt,
		victim = hooks.name(attempt.victim), plot = attempt.plot.model, own = thief == attempt.victim,
	} else { ended = true, reason = reason, id = id })
end
function ShakeService.finish(thief: Player, reason: string)
	local attempt = active[thief]
	if not attempt then return end
	active[thief] = nil
	push(thief, nil, reason, attempt.id)
	if reason == "chased" then hooks.notify(thief, "The owner reached you! Run with your basket.", "warn")
	elseif reason == "range" then hooks.notify(thief, "You stepped away. Carry your basket home.", "warn")
	elseif reason == "done" and attempt.caught == 0 then hooks.notify(thief, "None collected. Drag each Acorn into the basket.", "warn") end
end
function ShakeService.isShaking(thief: Player): boolean
	return active[thief] ~= nil
end
-- STORAGE IS A BANK AND A TREE BELONGS TO ITS OWNER (MASTER-PLAN 19.3, step
-- 2.6). Every refusal below names itself, because a prompt that does nothing
-- is indistinguishable from a broken one. Storage is never a source for
-- anybody; another occupant's tree is a source only while
-- `hooks.theftOpen()` says an acorn-theft event (Harvest Moon) is live.
function ShakeService.open(thief: Player, victim: any, source: string?)
	source = source or "tree"
	if source ~= "tree" and source ~= "storage" then return end
	if active[thief] then return end
	if source == "storage" then
		if thief == victim then
			hooks.notify(thief, "Your stored Acorns are already available to spend. Bring a basket here to deposit it.", "info")
		else
			hooks.notify(thief, "Stored Acorns are banked. Nobody can take them.", "warn")
		end
		return
	end
	if thief ~= victim and not (hooks.theftOpen and hooks.theftOpen()) then
		hooks.notify(thief, "Only its owner can shake this tree.", "warn"); return
	end
	local data = wallet(victim)
	local reason = hooks.reason(thief, victim)
	if reason then hooks.notify(thief, reason, "warn"); return end
	local plot = hooks.plot(victim)
	if not data or not plot or plot.shop or not plot.acornTree or not plot.acornStorage then
		hooks.notify(thief, "There is no Acorn tree or storage here.", "warn"); return
	end
	local now = workspace:GetServerTimeNow()
	local byThief = cooldowns[hooks.id(victim)] or {}
	cooldowns[hooks.id(victim)] = byThief
	if thief ~= victim and (byThief[thief.UserId] or 0) > now then
		pushCooldowns(thief)
		hooks.notify(thief, ("Wait %ds before raiding here again."):format(math.ceil(byThief[thief.UserId] - now)), "warn"); return
	end
	-- Check position/ownership before shaking anything off the tree.
	local invalid = valid(thief, {plot = plot, victim = victim, source = source})
	if invalid then hooks.notify(thief, if invalid == "chased" then "The owner is guarding these Acorns." else "Get closer on foot.", "warn"); return end
	Config.expireGroundAcorns(data, os.time())
	local shook = false
	if source == "tree" and (data.groundAcorns or 0) == 0 then
		-- Settle time at the old fill level before emptying. `online` only
		-- matters for a player's tree; a resident's stock has no rebirths.
		Config.growAcorns(data, os.time(), hooks.player(victim) ~= nil)
		data.groundAcorns, data.treeAcorns = data.treeAcorns or 0, 0
		data.acornsDroppedAt = os.time()
		shook = data.groundAcorns > 0
	end
	publish(victim)
	local held = reserved(victim, source)
	local available = math.max(0, balance(victim, source) - held)
	local take = math.min(Config.ACORNS.growCap, available)
	if take <= 0 then hooks.notify(thief, "No loose or ripe Acorns yet.", "warn"); return end
	serial += 1
	local attempt = { id = serial, victim = victim, plot = plot, source = source, take = take, caught = 0,
		seen = {}, startedAt = now + Config.ACORNS.startDelay, endsAt = now + Config.ACORNS.startDelay + Config.ACORNS.shakeSeconds }
	active[thief] = attempt
	if not hooks.player(victim) then
		-- A resident does not bank a crop out from under an active round.
		data.collectingUntil = attempt.endsAt + Config.ACORNS.catchGrace
		publish(victim)
	end
	-- Leave enough time for a fresh round started just before ground expiry.
	data.acornsDroppedAt = math.max(data.acornsDroppedAt or 0,
		os.time() + math.ceil(Config.ACORNS.shakeSeconds + Config.ACORNS.startDelay + Config.ACORNS.catchGrace) - Config.ACORNS.groundSeconds)
	if thief ~= victim then
		byThief[thief.UserId] = now + Config.ACORNS.shakeCooldown
		pushCooldowns(thief)
	end
	if shook then plot.model:SetAttribute(Config.PLOT_SHAKE_ATTRIBUTE, attempt.startedAt) end
	hooks.opened(thief, victim, plot, source)
	if active[thief] == attempt then push(thief, attempt) end
end
function ShakeService.catch(thief: Player, id: any, index: any)
	local attempt = active[thief]
	if not attempt or id ~= attempt.id or type(index) ~= "number" or index % 1 ~= 0
		or index < 1 or index > attempt.take or attempt.seen[index] then return end
	local invalid = valid(thief, attempt)
	if invalid then ShakeService.finish(thief, invalid); return end
	local now = workspace:GetServerTimeNow()
	if now < attempt.startedAt + Config.ACORNS.catchMinSeconds then return end
	if now > attempt.endsAt + Config.ACORNS.catchGrace then ShakeService.finish(thief, "done"); return end
	if balance(attempt.victim, attempt.source) < 1 then
		ShakeService.finish(thief, "empty"); return
	end
	attempt.seen[index] = true
	local receipt = { at = now, amount = 1, source = attempt.source }
	if not change(attempt.victim, attempt.source, -1) then receipt.amount = 0; ShakeService.finish(thief, "gone"); return end
	if not hooks.caught(thief, attempt.victim, receipt) then
		ShakeService.refund(attempt.victim, 1, {receipt})
		ShakeService.finish(thief, "gone"); return
	end
	attempt.caught += 1
	push(thief, attempt)
	if attempt.caught == attempt.take then ShakeService.finish(thief, "done") end
end
function ShakeService.refund(victim: any, amount: number, receipts: { any })
	local remaining = amount
	for _, receipt in ipairs(receipts) do
		local back = math.min(remaining, receipt.amount)
		if back > 0 then
			local source = receipt.source or "storage"
			if source == "tree" then
				local data = wallet(victim)
				if data then
					Config.expireGroundAcorns(data, os.time())
					data.acornsDroppedAt = os.time()
				end
			end
			if not change(victim, source, back) then return end
			receipt.amount -= back
			remaining -= back
		end
		if remaining <= 0 then break end
	end
end
function ShakeService.poll()
	for thief, attempt in pairs(active) do
		local reason = valid(thief, attempt)
		if reason then ShakeService.finish(thief, reason)
		elseif workspace:GetServerTimeNow() > attempt.endsAt + Config.ACORNS.catchGrace then ShakeService.finish(thief, "done") end
	end
end
function ShakeService.leaving(player: Player)
	cooldownReady[player] = nil
	ShakeService.finish(player, "gone")
	local finish = {}
	for thief, attempt in pairs(active) do if attempt.victim == player then table.insert(finish, thief) end end
	for _, thief in ipairs(finish) do ShakeService.finish(thief, "gone") end
end
function ShakeService.configure(context: any) hooks = context end
function ShakeService.start()
	Remotes.get("AcornCooldown").OnServerEvent:Connect(function(player)
		local now = workspace:GetServerTimeNow()
		if cooldownReady[player] and now - cooldownReady[player] < 1 then return end
		cooldownReady[player] = now
		pushCooldowns(player)
	end)
	Remotes.get("ShakeCatch").OnServerEvent:Connect(ShakeService.catch)
	Remotes.get("ShakeStop").OnServerEvent:Connect(function(player, id)
		local attempt = active[player]
		if attempt and attempt.id == id then ShakeService.finish(player, "stop") end
	end)
	task.spawn(function() while true do task.wait(Config.DOG_WATCH.pollRate); ShakeService.poll() end end)
end
return ShakeService
