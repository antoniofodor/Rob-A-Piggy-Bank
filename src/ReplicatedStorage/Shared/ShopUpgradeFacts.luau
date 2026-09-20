--!strict
-- Presentation of existing Config formulas, never a second upgrade economy.
local Config = require(script.Parent.Config)
local Facts = {}
function Facts.rows(key: string, level: number, nextLevel: number, state: any): { any }
	state = state or {}
	local rows = {}
	local function add(label: string, now: string, after: string)
		table.insert(rows, { label = label, now = now, after = after })
	end
	local function pct(n: number): string return ("%.1f%%"):format(n * 100) end
	local function seconds(n: number): string return ("%.2fs"):format(n) end
	if key == "income" then
		local factor = if state.rate then state.rate / math.max(Config.getIncomeRate(level, state.rebirths or 0, state.friendBonus), .001) else 1
		add("Coins / second", Config.formatCoins(Config.getIncomeRate(level, state.rebirths or 0, state.friendBonus) * factor),
			Config.formatCoins(Config.getIncomeRate(nextLevel, state.rebirths or 0, state.friendBonus) * factor))
	elseif key == "capacity" then
		add("Piggy capacity", Config.formatCoins(Config.getCapacity(level)), Config.formatCoins(Config.getCapacity(nextLevel)))
	elseif key == "sack" then
		add("First crack slice", pct(Config.getCrackSlice(1, level)), pct(Config.getCrackSlice(1, nextLevel)))
		add("All slices landed", pct(Config.getCrackTotal(level)), pct(Config.getCrackTotal(nextLevel)))
		add("Smash share", pct(Config.getSmashFraction(level)), pct(Config.getSmashFraction(nextLevel)))
	elseif key == "boots" then
		add("Carrying speed", ("%.2f studs/s"):format(Config.BASE_WALK_SPEED * Config.getCarryMultiplier(level)),
			("%.2f studs/s"):format(Config.BASE_WALK_SPEED * Config.getCarryMultiplier(nextLevel)))
	elseif key == "tiptoe" then
		add("Sneak speed", ("%.2f studs/s"):format(Config.BASE_WALK_SPEED * Config.getTiptoeMultiplier(level)),
			("%.2f studs/s"):format(Config.BASE_WALK_SPEED * Config.getTiptoeMultiplier(nextLevel)))
	elseif key == "lockpicks" then
		-- WHAT THE RUNG BUYS IS FORGIVENESS, so that is the first row: how
		-- many missed pins a crack survives (`Config.LOCKPICK_PERKS`). The
		-- notch bonus is the small second half, and the top rung's verb --
		-- reading any lock from the pavement -- is printed where it changes.
		local now, after = Config.lockpickPerk(level), Config.lockpickPerk(nextLevel)
		add("Spare picks per crack", tostring(now.spares), tostring(after.spares))
		add("Notch size", ("+%d%%"):format(math.floor((now.wider - 1) * 100 + 0.5)),
			("+%d%%"):format(math.floor((after.wider - 1) * 100 + 0.5)))
		if Config.canCase(nextLevel) ~= Config.canCase(level) or Config.canCase(level) then
			add("Read locks from the street", if Config.canCase(level) then "Yes" else "No",
				if Config.canCase(nextLevel) then "Yes" else "No")
		end
	elseif key == "locks" then
		-- THE TWIST FIRST, because each metal changes something a thief can
		-- SEE (`Config.CRACK_LOCKS`), and then the one number that decides a
		-- greedy run: how long the collar sits in the fifth pin's notch.
		local function twist(lvl: number): string
			local lock, open = Config.crackLock(lvl), Config.crackLock(0)
			local parts = {}
			if lock.width < open.width then
				table.insert(parts, ("-%d%% notch"):format(math.floor((1 - lock.width) * 100 + 0.5)))
			end
			if lock.sweep < open.sweep then table.insert(parts, "fast pins") end
			if lock.drift > 0 then table.insert(parts, "drifting notch") end
			return if #parts == 0 then "Open" else table.concat(parts, ", ")
		end
		add("Pin lock", twist(level), twist(nextLevel))
		add("Thief's last pin", seconds(Config.getCrackWindow(Config.CRACK.maxSteps, level, 0)),
			seconds(Config.getCrackWindow(Config.CRACK.maxSteps, nextLevel, 0)))
	elseif key == "fences" then
		local a, b = Config.FENCE_TIERS[level], Config.FENCE_TIERS[nextLevel]
		add("Fence", if a then a.label else "None", if b then b.label else "None")
		add("Crossing slow", pct(if a then 1 - a.slow else 0), pct(if b then 1 - b.slow else 0))
		add("Slow lasts", seconds(if a then a.duration else 0), seconds(if b then b.duration else 0))
	end
	return rows
end
return Facts
