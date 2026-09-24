--!strict
-- Presentation of existing Config formulas, never a second upgrade economy.
--
-- ONE ROW PER RUNG, AND IT IS THE ROW THAT MOVES (designer, this session).
-- This file used to print every stat an upgrade touches -- three of them for
-- Bigger Sack -- against the level above. Two things were wrong with that and
-- only the first was the complaint.
--
-- IT WAS TOO MUCH TO READ. A card selling one purchase answered with a table,
-- and a nine-year-old deciding whether to spend four million coins has to get
-- the answer from a glance. So a rung shows WHAT THIS PURCHASE CHANGES and
-- nothing else: `rows` builds every candidate an upgrade has and returns only
-- those whose value actually MOVES between the two levels.
--
-- AND IT PRINTED ROWS THAT READ THE SAME ON BOTH SIDES, which is worse than
-- verbose -- it is a purchase advertising itself as doing nothing. Lockpicks
-- is the one that made this unavoidable: its spare picks go 0, 1, 1, 2, 2 and
-- its notch widens only at level 2, so any FIXED row is flat on two of the
-- four rungs. Filtering on change makes that structurally impossible rather
-- than something the next person has to notice, and it is why the rule is
-- worth more than the row count it saves.
--
-- STUDS ARE GONE AND EVERYTHING MOVEMENT-RELATED IS A PERCENT INCREASE
-- (designer, this session). "18.00 studs/s" is a unit this audience has never
-- met and cannot compare against anything; "+9% faster" is the same fact in
-- the one unit they already own. The baseline is the upgrade's OWN level 0,
-- so the number answers "how much better than no upgrade at all", and level 0
-- reads "Normal" rather than "+0%" -- a plus sign in front of a zero is the
-- flat row this file exists to refuse, wearing a percentage.
local Config = require(script.Parent.Config)
local Facts = {}

-- AT MOST TWO. A rung that genuinely changes three things at once -- the Gold
-- lock is the only one, tightening its notch, quickening its pins and
-- deepening its drift together -- still gets a card somebody reads rather
-- than a table. Candidates are ordered most-important-first for exactly this
-- reason: what falls off the bottom is the least of what changed.
local MAX_ROWS = 2

local function pct(n: number): string
	return ("%d%%"):format(math.floor(n * 100 + 0.5))
end

-- A gain over the upgrade's own level 0, which is what "increase" means to
-- the person reading it. `word` is the direction: faster, more, smaller.
local function gain(now: number, base: number, word: string): string
	if base <= 0 or math.abs(now / base - 1) < 0.005 then
		return "Normal"
	end
	return ("+%s %s"):format(pct(now / base - 1), word)
end

local function seconds(n: number): string
	return ("%.1fs"):format(n)
end

local function yesno(b: boolean): string
	return if b then "Yes" else "No"
end

-- Every candidate an upgrade can show, most important first. A candidate is a
-- LABEL and a function of the level, so `rows` can ask it for both columns and
-- compare -- which is the whole mechanism, and the reason nothing here may
-- read the player's own state: a value that depended on live coins or
-- rebirths could differ between the two columns for a reason the purchase did
-- not cause.
local CANDIDATES: { [string]: { { label: string, value: (number) -> string } } } = {
	-- WHAT A BIGGER SACK IS FOR, IN ONE NUMBER. It scaled the first slice, the
	-- whole five-slice run and the smash share, and those are three views of
	-- one multiplier -- `sackScale` -- so printing all three was printing the
	-- same purchase three times. The clean run is the one a player is buying.
	sack = {
		{ label = "Coins you take", value = function(l)
			return gain(Config.getCrackTotal(l), Config.getCrackTotal(0), "more")
		end },
	},

	-- CARRY SPEED AS A GAIN, NOT AS STUDS. It caps at `BASE_WALK_SPEED`, so
	-- the top rung is "+33% faster" and never "faster than everyone chasing
	-- you" -- which is the rule `getCarryMultiplier` enforces with its own
	-- `math.min` and the reason this can be sold honestly as a percentage.
	boots = {
		{ label = "Speed carrying coins", value = function(l)
			return gain(Config.getCarryMultiplier(l), Config.getCarryMultiplier(0), "faster")
		end },
	},

	tiptoe = {
		{ label = "Sneaking speed", value = function(l)
			return gain(Config.getTiptoeMultiplier(l), Config.getTiptoeMultiplier(0), "faster")
		end },
	},

	-- FORGIVENESS FIRST, because that is what the rung buys and the blurb now
	-- says so. A missed pin ENDS a crack, so this count is the difference
	-- between leaving with one slice and leaving with five.
	lockpicks = {
		{ label = "Mistakes forgiven", value = function(l)
			return tostring(Config.lockpickPerk(l).spares)
		end },
		{ label = "Pin target size", value = function(l)
			return gain(Config.lockpickPerk(l).wider, Config.lockpickPerk(0).wider, "bigger")
		end },
		{ label = "Read locks from the street", value = function(l)
			return yesno(Config.canCase(l))
		end },
	},

	-- EACH METAL CHANGES SOMETHING A THIEF CAN WATCH HAPPEN (`Config.CRACK_LOCKS`),
	-- so the candidates are those three things in the order they bite: the
	-- notch narrows, then the pins quicken, then the notch starts drifting.
	locks = {
		{ label = "Thief's target", value = function(l)
			local lock, open = Config.crackLock(l), Config.crackLock(0)
			if lock.width >= open.width then
				return "Wide open"
			end
			return ("%s smaller"):format(pct(1 - lock.width / open.width))
		end },
		{ label = "Pin speed", value = function(l)
			local lock, open = Config.crackLock(l), Config.crackLock(0)
			if lock.sweep >= open.sweep then
				return "Normal"
			end
			return ("%s faster"):format(pct(open.sweep / lock.sweep - 1))
		end },
		-- "MOVING TARGET" AND NOT "TARGET SLIDES ABOUT" (designer, this
		-- session: "that doesn't even make sense"). `drift` swings the notch's
		-- centre up and down while the thief aims -- Config's own line for the
		-- Steel tier is "the notch DRIFTS up and down while you aim" -- and a
		-- moving target is the phrase every reader of this card already owns.
		-- The old wording was a description of the mechanism written by
		-- somebody who had just read the mechanism.
		{ label = "Moving target", value = function(l)
			return yesno(Config.crackLock(l).drift > 0)
		end },
	},

	-- THE TIER NAME LEADS, because a fence is the one upgrade whose PURCHASE
	-- is a visibly different object -- and the card's artwork is now that
	-- object too (see `ShopIcons`). Level 0 is genuinely no fence at all.
	fences = {
		{ label = "Your fence", value = function(l)
			local tier = Config.FENCE_TIERS[l]
			return if tier then tier.label else "None"
		end },
		-- THE SHOCK OUTRANKS THE SLOW, AND THAT ORDERING IS A BUG FIX RATHER
		-- THAN A PREFERENCE. An Electric Fence slows LESS than the Barbed Wire
		-- under it -- 50% against 58% -- and buys a 2.5-second stun instead,
		-- which is the whole of why it costs more. Ranked the other way the
		-- card sold that rung as "Slows thieves by: 58% -> 50%": a purchase
		-- advertising itself as a downgrade, which is worse than the flat row
		-- this file already refuses, because it is actively wrong about which
		-- way the ladder runs.
		{ label = "Shocks them", value = function(l)
			local tier = Config.FENCE_TIERS[l]
			return yesno(tier ~= nil and (tier.stun or 0) > 0)
		end },
		{ label = "Slows thieves by", value = function(l)
			local tier = Config.FENCE_TIERS[l]
			return pct(if tier then 1 - tier.slow else 0)
		end },
		{ label = "Slow lasts", value = function(l)
			local tier = Config.FENCE_TIERS[l]
			return seconds(if tier then tier.duration else 0)
		end },
	},
}

-- AN `income` BRANCH STOOD HERE, printing coins per second against the next
-- income level with the player's live bonuses folded in. It went with the Earn
-- Faster rung (designer, 2026-09-23): a stat comparison for a row no shelf can
-- sell is copy outliving the thing it describes. A key with no candidates
-- returns nothing, which is what `tests/luau/shopui.luau` asserts for both it
-- and the retired Bigger Piggy Bank.
function Facts.rows(key: string, level: number, nextLevel: number, _state: any): { any }
	local candidates = CANDIDATES[key]
	if not candidates then
		return {}
	end
	local rows = {}
	for _, candidate in ipairs(candidates) do
		local now, after = candidate.value(level), candidate.value(nextLevel)
		if now ~= after then
			table.insert(rows, { label = candidate.label, now = now, after = after })
			if #rows >= MAX_ROWS then
				break
			end
		end
	end
	-- NOTHING MOVED, WHICH MEANS THIS IS THE TOP OF THE TREE -- `nextLevel` is
	-- clamped to `level` there, so every candidate compares against itself.
	-- The card still has to say what the player ended up with, so the headline
	-- candidate is printed with both columns equal. That equality is asserted
	-- rather than incidental: the shop suite walks every upgrade to its max and
	-- refuses a maxed card that invents an improvement.
	if #rows == 0 then
		local top = candidates[1]
		rows[1] = { label = top.label, now = top.value(level), after = top.value(level) }
	end
	return rows
end

return Facts
