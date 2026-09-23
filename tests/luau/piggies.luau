-- The six lawn pedestals: the slot grid, the placement rules and the boot
-- audit, isolated from Roblox rendering and from saved player data.
-- docs/PIGGY-COLLECTION-PLAN.md §3, §4a.
--
-- WHAT THIS SUITE CAN AND CANNOT SEE, stated up front because the gap is
-- where this feature's remaining risk lives. It asserts ARITHMETIC and
-- BOOKKEEPING -- which slot a piggy lands on, what a count does, whether six
-- coordinates fit on a lawn. It cannot see a plinth, a prompt, a buffer
-- accruing or a piggy seated 0.05 studs into its own pedestal, because all of
-- those are engine behaviour. Those want a Play session and a photograph.
local Config, sources = ...
local checks = 0
local function check(ok, message)
	assert(ok, message)
	checks += 1
end
local function contains(problems, code)
	for _, p in problems do
		if p:find("[" .. code .. "]", 1, true) then
			return true
		end
	end
	return false
end
-- Set a field, run the audit, put it back. The same shape `tests/luau/audits`
-- uses, and for the same reason: an audit nobody has seen FIRE is an audit
-- whose question has not been checked. `auditFences` was clean through the
-- entire period every fence tier in the game was jumpable.
local function provoke(tbl, key, value, code)
	local old = tbl[key]
	tbl[key] = value
	local ok, problems = pcall(Config.auditPiggySlots)
	tbl[key] = old
	check(ok and contains(problems, code), "audit catches " .. code .. " at " .. tostring(key))
end

-- ------------------------------------------------------------ THE GRID
local N = Config.PIGGY_LAWN_SLOT_COUNT
check(N == 6, "six lawn slots (designer decision 2026-09-20)")
check(#Config.auditPiggySlots() == 0, "the shipped six fit on the lawn")

-- FRONT TO BACK IS THE INTERFACE, not an incidental ordering: it is what
-- `firstFreePiggySlot` walks, so a crate's piggies grow toward the street
-- rather than appearing behind the house.
local previous = math.huge
for i, slot in ipairs(Config.PIGGY_LAWN_SLOTS) do
	check(slot.offset.Z <= previous,
		("slot %d (%s) is no further forward than the one before it"):format(i, slot.id))
	previous = slot.offset.Z
end
check(Config.PIGGY_LAWN_SLOTS[1].offset.Z > Config.PIGGY_LAWN_SLOTS[N].offset.Z,
	"the first slot is genuinely in front of the last")

-- `Vector3` IS NOT IN SCOPE IN A SUITE. The harness stubs the Roblox value
-- constructors into the environment it loads CONFIG in, and the tests run in
-- the plain one -- so an offset is built the way the stub builds it, which is
-- also the only shape the audit reads (`o.X`, `o.Z`).
local function at(x: number, z: number)
	return { X = x, Y = 0, Z = z }
end

-- Every rule the audit owns, provoked one at a time.
provoke(Config, "PIGGY_LAWN_SLOT_COUNT", N + 1, "piggy.count")
provoke(Config.PIGGY_LAWN_SLOTS[1], "offset", at(0, 0), "piggy.occupied")
-- THE KENNEL, WHICH IS AT (-25, 18) NOW AND NOT (25, 16). It was moved to the
-- front-LEFT corner so the pedestals could grow -- swept properly, its own
-- audit rectangle was what held them to 6.0. This line has to move with it,
-- and it is the one that would catch the two halves drifting: the geometry
-- lives in `PlotService.KENNEL_X` and the reservation lives in `Config`.
provoke(Config.PIGGY_LAWN_SLOTS[1], "offset", at(-25, 18), "piggy.occupied")
-- AND THE CORNER IT LEFT IS FREE GROUND NOW, which is worth asserting rather
-- than noting: nothing may reserve (25, 16) any more.
do
	local old = Config.PIGGY_LAWN_SLOTS[1].offset
	Config.PIGGY_LAWN_SLOTS[1].offset = at(25, 16)
	local ok, problems = pcall(Config.auditPiggySlots)
	Config.PIGGY_LAWN_SLOTS[1].offset = old
	check(ok and not contains(problems, "piggy.occupied"),
		"the kennel's old front-right corner reserves nothing now")
end
provoke(Config.PIGGY_LAWN_SLOTS[1], "offset", at(0, 20), "piggy.occupied")
-- THE DOORSTEP CRATE, standing in for the ACORN OAK this line used to
-- provoke at (-25, 16). The oak and its basket are retired, so that ground
-- went free -- and the KENNEL has since moved into it, which is what paid for
-- the pedestals growing from 6.0 to 8.0.
provoke(Config.PIGGY_LAWN_SLOTS[1], "offset",
	at(0, -Config.HOUSE_FRONT_LINE + 2), "piggy.occupied")
provoke(Config.PIGGY_LAWN_SLOTS[1], "offset", at(40, 4), "piggy.lawn")
provoke(Config.PIGGY_LAWN_SLOTS[1], "offset", at(-25, -22), "piggy.house")
provoke(Config.PIGGY_LAWN_SLOTS[1], "id", Config.PIGGY_LAWN_SLOTS[2].id, "piggy.id")
-- Two slots in one place. Set the FIRST onto the second's own coordinate.
provoke(Config.PIGGY_LAWN_SLOTS[1], "offset", Config.PIGGY_LAWN_SLOTS[2].offset, "piggy.overlap")

-- ------------------------------------------------------- THE COLLECT PADS
-- THE PADS ARE THE HALF NOTHING WAS CHECKING, and they had a live fault: on
-- the uneven layout that shipped, the middle and back pads overlapped by 0.30
-- studs -- two stone faces at the same height, intersecting. It went unseen
-- because the hand check measured their widths and forgot their depths, and
-- because a pad is not axis-aligned, so neither a plan view nor a bounding
-- box would have said so.
--
-- EVERY PAD RULE IS PROVOKED THROUGH THE PAD SPEC RATHER THAN BY MOVING A
-- SLOT, which is what keeps each one isolated: moving a slot far enough to
-- cross two pads also overlaps two bases, so the test would pass on the
-- wrong code.
check(Config.PIGGY_PEDESTAL.pad.size.X > Config.PIGGY_PEDESTAL.base.X,
	"the pad oversails its own pedestal, so it reads as part of it")

-- THE FACE IS THE HIGHEST COURSE, and this is the regression test for TWO
-- reported bugs that are the same rule misread in opposite directions.
--
--   FLUSH  -> the face's top and the surround's top both landed on 0.26, so
--             they z-fought across the whole face: "clipping through the
--             floor".
--   SUNK   -> dropped below the surround's top it stopped fighting and went
--             out of sight, because a surround is a SOLID SLAB and nothing
--             here can be dug: "the collect buttons are invisible".
--
-- So the test is not "they differ" -- flush and sunk both differ from each
-- other. It is that the FACE IS ON TOP, by a visible margin.
do
	local pad = Config.PIGGY_PEDESTAL.pad
	local surroundTop = pad.size.Y - pad.sink
	local faceBottom = surroundTop - pad.faceSink
	local faceTop = faceBottom + pad.faceSink + pad.faceProud
	check(faceTop > surroundTop + 0.05,
		("the pad's face stands %.2f proud of its surround"):format(faceTop - surroundTop))
	check(faceBottom < surroundTop,
		"the face bites into the surround, so their shared plane is a butt joint")
	check(surroundTop > 0.3,
		("the pad stands %.2f proud of the grass, so it reads as a button"):format(surroundTop))
	check(pad.sink > 0,
		"the pad sinks into the lawn rather than sharing a plane with it")
	-- The face is inset on BOTH horizontal axes or the surround is not a
	-- surround -- it is a frame with one open side.
	check(pad.size.X - pad.rim * 2 > 0 and pad.size.Z - pad.rim * 2 > 0,
		"the rim leaves a border showing around the face")
end

-- AND THE FIGURE THE BUTTON CARRIES IS PAINTED ON IT AND CAPPED. Six of these
-- per lawn on ten lawns, so an uncapped one is the wall-of-text failure the
-- shop fascia already paid for.
check(Config.PIGGY_PEDESTAL.pad.labelRange > 0
	and Config.PIGGY_PEDESTAL.pad.labelRange < 200,
	"the pad's figure carries to the owner's own lawn and no further")
-- THE FIGURE IS ON THE FACE, NOT OVER IT (designer call 2026-09-21). The
-- checks that used to sit here asserted a BillboardGui's stud lift and stud
-- size, so they are the regression test for the floating label rather than for
-- this one -- kept in spirit: what has to hold now is that the canvas is sized
-- off the pad's own geometry and turned to run along it.
do
	local pad = Config.PIGGY_PEDESTAL.pad
	check(pad.labelLift == nil and pad.labelSize == nil,
		"the billboard's lift and stud size are gone rather than left dangling")
	check(pad.labelPixelsPerStud > 0, "the canvas is sized in pixels per stud")
	-- A QUARTER TURN, BECAUSE A `Face = Top` CANVAS MAPS ITS X TO THE PAD'S
	-- SHORT AXIS -- measured at 166 x 474 px on a face 7.4 x 2.6 studs. At
	-- rotation 0 the figure runs ALONG the pad and reads bottom-to-top, which
	-- is what shipped in the first build of this and was photographed.
	check(pad.labelRotation % 180 == 90,
		"and the figure is turned a quarter, so it runs across the pad not along it")
	-- FILLS THE FACE WITHOUT TOUCHING ITS EDGES, which is the state this
	-- project records as "`TextFits` true while the glyphs sit exactly on the
	-- frame edge".
	check(pad.labelFill.X > 0.5 and pad.labelFill.X < 1,
		"the figure fills most of the pad's long axis and not all of it")
	check(pad.labelFill.Y > 0.5 and pad.labelFill.Y < 1,
		"and most of the short axis, clear of the rim")
	-- THE FACE IT IS PAINTED ON HAS TO BE WIDER THAN IT IS DEEP, or the
	-- rotation above is turning the type onto the SHORT axis and the whole
	-- derivation inverts.
	local long = pad.size.X - pad.rim * 2
	local short = pad.size.Z - pad.rim * 2
	check(long > short, "the pad's face is wider than it is deep, which the turn assumes")
	check(long > 0 and short > 0, "and the rim leaves a face to paint on at all")
end

-- GREEN WHEN READY, RED WHEN NOT (designer call 2026-09-21). These were money
-- gold and the pedestal's own stone, which differ by saturation alone -- and
-- the question this button is asked from across a lawn is go or do not go.
do
	local pad = Config.PIGGY_PEDESTAL.pad
	-- Channel-wise rather than against a named constant, because `Config`
	-- deliberately cannot require `Theme` (it is pure data pulled in by every
	-- server service) so these are Theme's own numbers copied in. What the
	-- suite can hold is that they really are a green and a red, which is what
	-- goes wrong if somebody edits one and not the other.
	-- The harness stubs `Color3.fromRGB` as the argument list itself, so the
	-- channels are [1], [2], [3] rather than a `.value` field -- reading it
	-- wrong came back nil and looked like a missing colour.
	local ready, empty = pad.readyColour, pad.emptyColour
	local rr, rg, rb = ready[1], ready[2], ready[3]
	local er, eg, eb = empty[1], empty[2], empty[3]
	check(rr ~= nil and er ~= nil, "both pad states carry a colour")
	check(rg > rr and rg > rb, "ready is a green: its green channel leads")
	check(er > eg and er > eb, "empty is a red: its red channel leads")
	-- AND THEY HAVE TO DIFFER IN HUE RATHER THAN ONLY IN LEVEL, which is
	-- precisely what the gold/stone pair failed at.
	check(math.abs(rg - eg) > 60 or math.abs(rr - er) > 60,
		"the two states are different colours, not two levels of one")
	-- AND THE STATE SURVIVES WITHOUT THE HUE, which is the check that was
	-- missing. Green against red separates by only 1.93:1 in LUMINANCE and
	-- red/green is THE colour-blind pair, so the pad cannot be carried by
	-- colour alone -- this file's own Legendary-is-drawn-thicker rule. The
	-- second channel is the FIGURE, so an empty pad has to print something
	-- rather than going blank. The build before this one hid it.
	check(Config.formatCoins(0) ~= "",
		"an empty pad has a figure to print, so the state is not hue-only")
	-- The source half of this -- that nothing DISABLES the figure on either
	-- pad -- is already asserted in the collect-sound section below, where
	-- `pedestalSrc` and `plotSrc` are in scope. Repeating it here would be a
	-- second copy, and reading those locals before they exist is the nil
	-- global this suite has already tripped on once.
end

-- ------------------------------------------------- THE NAME OVER ITS HEAD
-- Tier-coloured, designer call 2026-09-21. `piggyTierColour` is one function
-- because the two-step -- `rarityOf` on the SPEC, then an index into
-- `RARITIES` -- is exactly the shape somebody shortens to `RARITIES[key]`,
-- which hands back nil and throws on a lawn.
do
	local seen = {}
	local n = 0
	for key in pairs(Config.SKINS) do
		local colour = Config.piggyTierColour(key)
		check(colour ~= nil, ("%s's name has a colour"):format(key))
		n += 1
	end
	check(n > 0, "there are skins to colour")
	-- An unknown key is the RETIRED-SKIN case, which `getSkin` already answers
	-- by falling back to the default rather than throwing -- so the name over a
	-- pedestal holding a key no catalogue knows is written in the default
	-- skin's tier rather than killing the dress.
	check(Config.piggyTierColour("no-such-skin-key")
		== Config.piggyTierColour(Config.DEFAULT_SKIN),
		"a retired key falls back to the default skin's tier rather than throwing")
	-- FOUR DISTINCT COLOURS, or the tier is not being said at all. Identity is
	-- the right test here: the harness stubs `Color3.fromRGB`, so two tiers
	-- sharing a row would share the stub object.
	for _, a in ipairs(Config.RARITY_ORDER) do
		for _, b in ipairs(Config.RARITY_ORDER) do
			if a ~= b then
				check(Config.RARITIES[a].colour ~= Config.RARITIES[b].colour,
					("%s and %s are told apart by colour"):format(a, b))
			end
		end
	end
	check(Config.PIGGY_NAME.range > Config.PIGGY_PEDESTAL.pad.labelRange,
		"a name carries further than a figure, because a visitor reads the name")
	-- STUD-SIZED AND NO WIDER THAN THE PIGGY IT NAMES. The pixel version was
	-- 190 by 44, so the guard is a magnitude one: anything over a few studs
	-- here is a pixel count that survived the conversion.
	local piggyWidth = 2.2 * Config.PIGGY_PEDESTAL.display
	check(Config.PIGGY_NAME.size.X > 0 and Config.PIGGY_NAME.size.X <= piggyWidth,
		("the name is %.1f studs wide against a piggy %.1f across"):format(
			Config.PIGGY_NAME.size.X, piggyWidth))
	check(Config.PIGGY_NAME.size.Y > 0 and Config.PIGGY_NAME.size.Y < 3,
		"the name is a stud-scale height rather than a pixel count")
	check(Config.PIGGY_NAME.gap > 0,
		"there is clear air between the ears and the label's bottom edge")
end

-- SQUARE TO THE PLOT. This is the regression test for a reported bug: the pads
-- used to take `piggyPedestalYaw`, which is the angle to the till and is
-- therefore different for every row, so the three in a column sat at 103.5,
-- 80.9 and 60.8 degrees -- splayed 43 degrees apart and square to nothing.
-- `piggyPadYaw` snaps that to the nearest quarter turn.
--
-- ASSERTED AS A MULTIPLE OF 90 RATHER THAN AS +-90, so the rule still holds if
-- a later column is added on the centre line where inward is +-Z.
for i = 1, N do
	local yaw = Config.piggyPadYaw(i)
	local quarters = yaw / (math.pi / 2)
	check(math.abs(quarters - math.floor(quarters + 0.5)) < 1e-9,
		("slot %d's pad lies square to the plot"):format(i))
end
-- AND THE PIGGY IS STILL TURNED INWARD, which is the designer's call and the
-- thing the pad fix must NOT have undone. Every slot is at |x| 25, so every
-- pedestal yaw is genuinely off-square -- if these two ever agreed, the pads
-- would be crooked again.
do
	local offSquare = 0
	for i = 1, N do
		if math.abs(Config.piggyPedestalYaw(i) - Config.piggyPadYaw(i)) > 1e-9 then
			offSquare += 1
		end
	end
	check(offSquare == N, "all six piggies still face the till rather than the pad's way")
end

-- A pad wide enough to reach the row behind it. The bases do not move.
provoke(Config.PIGGY_PEDESTAL.pad, "size", { X = 16, Y = 0.34, Z = 3.4 },
	"piggy.padoverlap")
-- A pad shoved inward until it stands in the till.
provoke(Config.PIGGY_PEDESTAL.pad, "gap", 12, "piggy.padoccupied")
-- A pad wide enough to run off the side of the lawn.
provoke(Config.PIGGY_PEDESTAL.pad, "size", { X = 48, Y = 0.34, Z = 3.4 },
	"piggy.padlawn")
-- THE HOUSE CHECK REACHES A PAD'S WIDTH, NOT ITS OFFSET, and that changed with
-- the yaw. While the pad was turned it projected diagonally forward, so its
-- offset could never carry it toward the wall; square to the plot the offset is
-- pure X and the pad's WIDE axis lies along Z, centred on the row. So a wide
-- enough pad on the back row reaches the house even though the pedestal
-- clears it -- which is exactly the failure worth catching, since pad width
-- tracks the base.
provoke(Config.PIGGY_PEDESTAL.pad, "size", { X = 20, Y = 0.34, Z = 3.6 },
	"piggy.padhouse")

-- AND THE GATE WALK EXEMPTION IS NOT EXERCISED, WHICH IS RECORDED RATHER THAN
-- FAKED. A pad may stand in the gate walk on purpose -- a pad is a thing you
-- walk over, so ground a player already crosses is where one most belongs --
-- but measured on the shipped layout no pad goes near it: they span plot
-- |x| 16.2..19.8 against a walk that ends at 12. So the `pad = false` flag is
-- a decision with no test under it, because there is no mutation that lands a
-- pad in the walk without its bounding box also catching the till.

-- ------------------------------------------------------------ THE SAVE
-- A brand new save's shape, built the way `DataService.defaultData` does.
local function fresh()
	return {
		piggies = {
			owned = { [Config.DEFAULT_SKIN] = 1 },
			till = Config.DEFAULT_SKIN,
			slots = { {}, {}, {}, {}, {}, {} },
		},
		tillBuffer = 0,
	}
end

local data = fresh()
check(#Config.piggySlots(data) == N, "a fresh save holds one entry per slot")
check(Config.firstFreePiggySlot(data) == 1, "a fresh lawn is empty: the front slot is free")
-- THE STARTER CLASSIC IS ON THE TILL AND NOT ON THE GRASS, which is the one
-- placement every save is guaranteed and the reason the lawn starts bare.
check(Config.piggyPlacedCount(data, Config.DEFAULT_SKIN) == 1, "the starter Classic is placed")
check(Config.piggySpareCount(data, Config.DEFAULT_SKIN) == 0, "and it is not spare: it is standing on the till")

-- DENSE AND NEVER SPARSE. A save that arrives short, long, or with a
-- non-table in a slot is reconciled here rather than in a schema branch --
-- and a mixed array/dictionary is what `SetAsync` starts refusing.
local ragged = fresh()
ragged.piggies.slots = { { key = "classic", buffer = 5 }, 7, nil, {} }
local fixed = Config.piggySlots(ragged)
check(#fixed == N, "a short save grows to six")
check(fixed[1].key == "classic" and fixed[1].buffer == 5, "and keeps what was already in slot one")
for i = 2, N do
	check(type(fixed[i]) == "table" and fixed[i].key == nil,
		("slot %d came back as an empty table"):format(i))
end
local long = fresh()
long.piggies.slots[N + 3] = { key = "classic" }
check(#Config.piggySlots(long) == N, "a save written against more slots is trimmed to six")
local bare = { tillBuffer = 0 }
check(#Config.piggySlots(bare) == N and bare.piggies ~= nil,
	"a save with no piggies table at all is given one")

-- ------------------------------------------------------------ PLACEMENT
data = fresh()
-- A CRATE PLACES ITSELF, FRONT TO BACK, with nothing to press.
local keys = { "bullion", "diamond", "prismatic", "pearl", "cow", "lava" }
for i, key in ipairs(keys) do
	check(Config.SKINS[key] ~= nil, ("the test's %s key is really in the catalogue"):format(key))
	check(Config.addPiggy(data, key, true) == i,
		("a crate piggy lands on slot %d, front to back"):format(i))
end
check(Config.firstFreePiggySlot(data) == nil, "six placed, and the lawn is full")

-- THE SEVENTH IS REFUSED OUTRIGHT AND BUMPS NOTHING (designer ruling
-- 2026-09-21). There is no inventory: a piggy you own is one standing
-- somewhere, so a copy that cannot be placed does not enter the collection at
-- all. The earlier version of this incremented `owned` and then failed to
-- find a slot, which left a count that disagreed with the lawn and nothing to
-- explain it -- and `ChestService.whyCannotOpen` is what stops a crate ever
-- reaching this state in the first place.
check(Config.addPiggy(data, "bullion", true) == nil, "the seventh is refused a slot")
check(data.piggies.owned.bullion == 1, "and the count did not move: no ghost copy")
check(Config.piggyPlacedCount(data, "bullion") == 1, "one copy, standing")
check(Config.piggySpareCount(data, "bullion") == 0, "and nothing spare, because nothing can be")

-- A ROUND-UP OR A SNATCH IS OWNED WITHOUT BEING PLACED -- the player carried
-- it home and chooses where it goes. RECORDED AS A KNOWN TENSION rather than
-- asserted as right: under "placement is ownership" a carried piggy arguably
-- should not count as owned until it is stood up, and the placement verb that
-- would settle it is not built. What this pins is only that `place = false`
-- takes no slot, which the herd and snatch paths both need.
local byHand = fresh()
check(Config.addPiggy(byHand, "lava", false) == nil, "a round-up takes no slot on its own")
check(byHand.piggies.owned.lava == 1, "but it is owned")
check(Config.firstFreePiggySlot(byHand) == 1, "and the lawn is untouched, waiting for a placement")

-- ------------------------------------------------------------ REMOVAL
-- A SNATCH TAKES THE COPY AND THE COUNT WITH IT. This is what §8 means by
-- "losing a piggy is losing permanent progress" and why `LOSS_CAP` is owed a
-- second clause -- which it does not have yet.
data = fresh()
Config.addPiggy(data, "lava", true)
Config.piggySlots(data)[1].buffer = 1234
check(Config.removePiggy(data, 1) == "lava", "removal hands back what was standing there")
check(Config.piggySlots(data)[1].key == nil, "the slot is empty")
check(Config.piggySlots(data)[1].buffer == 0,
	"and its buffer went with it as ZERO, never as a windfall (plan §4a)")
check(data.piggies.owned.lava == nil, "the last copy leaves no zero entry behind")
check(Config.removePiggy(data, 1) == nil, "removing from an empty slot is a no-op, not an error")
check(Config.removePiggy(data, 2) == nil, "and so is removing from a slot that was never filled")

-- Two copies, one taken: the count comes down by one and the other stays.
data = fresh()
Config.addPiggy(data, "cow", true)
Config.addPiggy(data, "cow", true)
check(data.piggies.owned.cow == 2, "two copies owned")
check(Config.removePiggy(data, 1) == "cow", "one taken")
check(data.piggies.owned.cow == 1, "one left")
check(Config.piggyPlacedCount(data, "cow") == 1, "and it is still standing on slot two")

-- ------------------------------------------------------------ THE TILL
-- The till counts as a placement, because §3 says the piggy on it "earns like
-- any other". A count that ignored it would make the starter Classic read as
-- spare and hand a new player a free placement they already have.
data = fresh()
data.piggies.till = "lava"
data.piggies.owned = { lava = 1 }
check(Config.piggyPlacedCount(data, "lava") == 1, "the till is a placement")
check(Config.piggySpareCount(data, "lava") == 0, "so the only copy is not also spare")
Config.addPiggy(data, "lava", true)
check(Config.piggyPlacedCount(data, "lava") == 2, "till plus one pedestal")
check(Config.piggySpareCount(data, "lava") == 0, "both copies standing")

-- ------------------------------------------------------------ RATES
-- Rarity is a MULTIPLE of a Classic one, which is the whole of what a tier
-- buys here. Not yet solved against `auditRobbery` -- see plan §8, which
-- calls that the single largest remaining piece of work.
local base = Config.getIncomeRate(0, 0)
check(Config.getPiggyIncomeRate("common", 0, 0) == base, "a common earns exactly BASE_INCOME")
check(Config.getPiggyIncomeRate("rare", 0, 0) == base * Config.PIGGY_RARITY_INCOME.rare,
	"a rare is a clean multiple of it")
check(Config.getPiggyIncomeRate("legendary", 0, 0) == base * Config.PIGGY_RARITY_INCOME.legendary,
	"and so is a legendary")
-- A MISSING OR UNKNOWN RARITY EARNS THE FLOOR, NEVER NOTHING. A skin shipped
-- with no tag should pay like a common; paying zero is a pedestal that is
-- visibly standing there doing nothing, which reads as broken.
check(Config.getPiggyIncomeRate(nil, 0, 0) == base, "no rarity tag earns the floor")
check(Config.getPiggyIncomeRate("mythic", 0, 0) == base,
	"and so does a tier this ladder does not carry")
check(Config.PIGGY_RARITY_INCOME.common == 1, "common IS the floor, so BASE_INCOME keeps its meaning")
-- THE LADDER HAS TO CLIMB, whatever the numbers end up being: a tier that
-- pays less than the one under it makes the rarer piggy the worse piggy --
-- and the BUFFER CAP is derived from this same multiplier, so it would invert
-- with it. `epic` was added after the fact because exactly one skin carries
-- it, which is the shape of edit most likely to land out of order.
--
-- WALKED OFF `RARITY_ORDER`, NEVER A LITERAL LIST. This carried its own
-- `{ "common", "rare", "epic", "legendary" }`, which is a SECOND COPY of the
-- ladder in the one file whose job is catching the first copy being wrong --
-- and a five-tier re-tag is queued (docs/PIGGY-COLLECTION-BUILD-ORDER.md
-- Stage 8), so a pinned four would have gone on asserting four rungs of a
-- five-rung ladder and reported clean. That is `Crates.luau` keeping its own
-- copy of this exact table and growing an epic row that could never fill.
for i = 2, #Config.RARITY_ORDER do
	local tier, below = Config.RARITY_ORDER[i], Config.RARITY_ORDER[i - 1]
	local paid, under = Config.PIGGY_RARITY_INCOME[tier],
		Config.PIGGY_RARITY_INCOME[below]
	-- A tier with no row at all is `auditEconomy`'s problem to report rather
	-- than this loop's to crash on -- nil > nil throws, and a suite that dies
	-- accuses whatever it was testing instead of naming the gap.
	if paid ~= nil and under ~= nil then
		check(paid > under, ("%s pays more than %s"):format(tier, below))
	end
end
-- AND THE AUDIT IS WHAT CATCHES A TIER WITH NO ROW, which is the case the
-- loop above deliberately skips. Provoked rather than trusted: an audit
-- nobody has seen FIRE is an audit whose question has not been checked.
do
	local order = Config.RARITY_ORDER
	table.insert(order, "mythic")
	local fired = false
	for _, problem in ipairs(Config.auditEconomy()) do
		if problem:find("mythic", 1, true) then fired = true end
	end
	table.remove(order)
	check(fired, "a tier on the ladder with no income row is reported at boot")
	check(#Config.auditEconomy() == 0, "and the shipped ladder is clean again after")
end
-- Every skin in the catalogue has to land on a rate, or a pedestal wearing it
-- would earn the floor by accident rather than by design.
local untagged = 0
for key, skin in pairs(Config.SKINS) do
	if skin.rarity == nil or Config.PIGGY_RARITY_INCOME[skin.rarity] == nil then
		untagged += 1
	end
end
check(untagged == 0, ("every skin carries a rarity this ladder prices (%d do not)"):format(untagged))

-- THE BUFFER CAP IS PER SLOT AND NOW PER TIER (designer call 2026-09-21).
--
-- `PIGGY_BUFFER_SECONDS` IS THE COMMON'S CAP AND THEREFORE THE LAP CLOCK, so
-- the plan's 90-120s band still describes the number a player laps against --
-- common's multiplier is 1 and 1 to any power is 1.
check(Config.PIGGY_BUFFER_SECONDS >= 60 and Config.PIGGY_BUFFER_SECONDS <= 180,
	"the lap clock is in the minute-or-two band plan §4a asks for")
check(Config.piggyBufferSeconds("common") == Config.PIGGY_BUFFER_SECONDS,
	"and a common holds exactly that, so the exponent cannot move the baseline")
do
	-- IT CLIMBS WITH THE TIER. The entry this replaces asserted the opposite
	-- property ("everything comes ripe together"), which the flat cap bought
	-- and which is deliberately spent -- see PIGGY_BUFFER_TIER_POWER. What
	-- must hold now is that the ladder runs the RIGHT WAY: a better piggy is
	-- more forgiving of a late lap, never less.
	local previous = 0
	for _, tier in ipairs(Config.RARITY_ORDER) do
		if Config.PIGGY_RARITY_INCOME[tier] then
			local seconds = Config.piggyBufferSeconds(tier)
			check(seconds > previous,
				("%s holds longer than the tier below it (%.1fs)"):format(tier, seconds))
			previous = seconds
		end
	end

	-- AND IT CLIMBS FAR MORE SLOWLY THAN INCOME DOES, which is the whole job
	-- of the exponent. The two MULTIPLY into the coin cap, and the product of
	-- two curves nobody checked is this economy's most repeated post-mortem --
	-- straight through, a legendary would hold 25 minutes and stop being a lap.
	local top, topName = 1, "common"
	for key, multiplier in pairs(Config.PIGGY_RARITY_INCOME) do
		if multiplier > top then top, topName = multiplier, key end
	end
	local durationSpread = Config.piggyBufferSeconds(topName)
		/ Config.piggyBufferSeconds("common")
	check(durationSpread > 1.5 and durationSpread < 4,
		("the duration spread is %.2fx -- a real ladder, still a lap"):format(durationSpread))
	check(durationSpread < top,
		("and flatter than the income ladder's own %.0fx"):format(top))

	-- THE COIN CAP IS THE PRODUCT, and it is what "a cap corresponding to the
	-- tier" actually asks for -- so it has to have got STEEPER, not just
	-- differently shaped.
	local coinSpread = (top * Config.piggyBufferSeconds(topName))
		/ Config.piggyBufferSeconds("common")
	check(coinSpread > top,
		("the coin cap spread is %.0fx against the income ladder's %.0fx"):format(
			coinSpread, top))

	-- AN UNKNOWN OR MISSING TIER HOLDS THE FLOOR, never nothing and never nil.
	-- A nil would be `rate * nil` inside the accrual loop, which throws; a zero
	-- would be a pedestal that can never hold anything, which reads as a piggy
	-- that has stopped working. Same fallback and same reason as the rate.
	check(Config.piggyBufferSeconds(nil) == Config.PIGGY_BUFFER_SECONDS,
		"no tier holds the floor duration")
	check(Config.piggyBufferSeconds("mythic") == Config.PIGGY_BUFFER_SECONDS,
		"and so does a tier this ladder does not carry")

	-- DERIVED, NOT A SECOND TABLE, which is the property that stops a tier
	-- half-landing: there is no map of durations to forget to add a row to.
	-- Every rarity the catalogue actually uses has to come back with one.
	local missing = 0
	for key, skin in pairs(Config.SKINS) do
		if Config.piggyBufferSeconds(skin.rarity) <= 0 then
			missing += 1
		end
	end
	check(missing == 0,
		("every skin's tier has a buffer duration (%d do not)"):format(missing))
end


-- ------------------------------------------- WHAT A COLLECTION ACTUALLY EARNS
-- `Config.getIncomeRate` was a player's whole income until a lawn started
-- earning, so every reader that meant "what this player earns" asked it --
-- including `robberyRates`, which is why `auditRobbery` reported zero problems
-- while robbing returned 0.459x idling against a floor of 3.0x.
do
	local one = Config.getIncomeRate(20, 0)
	local lawn = Config.fullLawn("common")
	check(#lawn == Config.PIGGY_LAWN_SLOT_COUNT + 1,
		"a full lawn is every pedestal plus the till")
	-- THE SUMMATION IS A SUM, checked against the arithmetic by hand rather
	-- than against itself.
	check(math.abs(Config.collectionRate(lawn, 20, 0) - one * #lawn) < 1e-6,
		"a lawn of commons earns exactly one pig's rate per placement")
	local top, topName = 1, "common"
	for key, multiplier in pairs(Config.PIGGY_RARITY_INCOME) do
		if multiplier > top then top, topName = multiplier, key end
	end
	check(math.abs(Config.collectionRate(Config.fullLawn(topName), 20, 0)
		- one * #lawn * top) < 1e-6,
		"and a lawn of the top tier earns that times the top multiplier")
	-- AN EMPTY LAWN EARNS NOTHING, which is the case a pedestal with no piggy
	-- on it produces and the one a `nil` hole in the array would have hidden.
	check(Config.collectionRate({}, 20, 0) == 0, "nothing placed earns nothing")
	-- MIXED, because a real lawn is never uniform and the audit's canonical
	-- ones are the only uniform lawns in the game.
	check(math.abs(Config.collectionRate({ "common", topName }, 20, 0)
		- one * (1 + top)) < 1e-6, "a mixed lawn is the sum of its placements")
	-- AN UNTAGGED RARITY EARNS THE FLOOR rather than nothing, the same rule
	-- `getPiggyIncomeRate` already keeps: a skin shipped with no tag should pay
	-- like a common, and paying zero is a pedestal visibly doing nothing.
	check(math.abs(Config.collectionRate({ "mythic" }, 20, 0) - one) < 1e-6,
		"a tier this ladder does not carry earns the floor")
	-- THE FRIEND BONUS IS OPTIONAL AND MULTIPLIES THE WHOLE LAWN, for the
	-- reason it is optional on `getIncomeRate`: offline accrual passes nothing.
	check(Config.collectionRate(lawn, 20, 0, 0.5)
		> Config.collectionRate(lawn, 20, 0),
		"a friend bonus lifts the whole collection")
end

-- `robberyRates` IDLES ON A WHOLE LAWN NOW (designer decision 2026-09-22):
-- the target is still the centre pig, but the thief's own income is the till
-- plus six placed piggies, so the comparison is against a lawn of commons.
do
	local robbing, idling = Config.robberyRates(20, 0, 0)
	check(idling > Config.getIncomeRate(20, 0) * 3600 * 6,
		"idling is the whole lawn, till included")
	check(robbing / idling >= Config.ROBBERY_ADVANTAGE.min,
		"cold robbing beats a lawn of commons by the floor")

	local f = Config.robberyFigures()
	check(f.hot > f.cold and f.hot <= Config.ROBBERY_ADVANTAGE.max,
		"five stars pay more than none and stay under the ceiling")
	check(f.coldTopLawn < f.cold,
		"a thief on a lawn of the top rarity idles more than a resident can pay -- printed, not audited")

	-- THE RATE CANCELS. A resident's pig is seconds of its income and idling
	-- is seconds of the thief's, so a peer pair reads the same at every level.
	local r1, i1 = Config.robberyRates(0, 0, 0)
	local r2, i2 = Config.robberyRates(40, 10, 0)
	check(math.abs(r1 / i1 - r2 / i2) < 1e-6,
		"the ratio is flat across level and rebirth")

	-- THE STARS: five double a delivery, the floor never reaches zero, and
	-- quiet fades them one at a time.
	check(math.abs(Config.getStarPayout(Config.WANTED_STARS.max) - 2) < 1e-9,
		"five stars double a delivery")
	check(Config.getStarFloorScale == nil and Config.POLICE.wantedFloorSeconds == nil,
		"the patrol's sheet floor is retired: the stars are the only thing that sends it")
	check(Config.starsAfterQuiet(5, Config.WANTED_STARS.fade - 1) == 5
		and Config.starsAfterQuiet(5, Config.WANTED_STARS.fade) == 4
		and Config.starsAfterQuiet(2, Config.WANTED_STARS.fade * 10) == 0,
		"stars fade one per window of quiet and never below zero")
	check(Config.revengePayout() > Config.HEIST_PAYOUT,
		"revenge pays more than a plain delivery, derived from it")
	check(Config.LOSS_CAP ~= nil and Config.LOSS_CAP.fraction > 0,
		"the loss cap stays: a crack of the bank is a fraction of somebody's whole wealth")
end

-- AND THE AUDIT IS CLEAN, which is the whole point of the change: it reported
-- the collection imbalance on every boot until the idle side was re-derived
-- against the lawn and the payout and the resident pig were solved beside it.
do
	local problems = Config.auditRobbery()
	check(#problems == 0, "auditRobbery is clean on the lawn economy: "
		.. table.concat(problems, " | "))
end

-- ------------------------------------------------- THE COLLECT SOUND
-- A collect had no audible feedback at all: the pad repaints its face and
-- drops its figure, which answers a player who is looking AT it, and a collect
-- is done at walking pace by somebody looking where they are going.
--
-- WHAT THIS SUITE CAN SEE IS THE CUE AND THE PITCH, NOT THE NOISE. Nothing
-- offline can hear a Sound, so what is asserted is that the id is one the
-- catalogue actually carries, that the levels sit under the pig's own, and
-- that the pitch is a real number for every share a live collect can produce.
-- Whether it SOUNDS like collecting is a headphones question.
local snd = Config.PIGGY_PEDESTAL.pad.sound
check(type(snd) == "table", "the collect pad carries a sound spec")
check(type(snd.id) == "string" and snd.id ~= "", "with a real asset id on it")
-- THE ID IS ONE OF `Config.SOUNDS`, NEVER A LITERAL TYPED HERE. A raw
-- rbxassetid in this table would be a second copy of an id with nothing to
-- keep it in step -- and every note in `Config.SOUNDS` about third-party audio
-- being moderated away without warning is about ids that live in ONE place.
local fromCatalogue = nil
for name, id in pairs(Config.SOUNDS) do
	if id == snd.id then
		fromCatalogue = name
		break
	end
end
check(fromCatalogue ~= nil, "and the id comes out of Config.SOUNDS rather than a literal")
check(fromCatalogue == "BANK", "specifically BANK -- the cue that already means coins went in")

-- QUIETER AND SHORTER-RANGE THAN THE PIG'S OWN BANK. This is the rule
-- `playCoinDrop` writes down ("anything louder becomes nagging") turned into
-- an assertion: a rebirth fires once, a collect can fire seven times in a lap.
-- The pig's bank is built at 0.6 over 70 studs in `PiggyBank.addSounds`.
check(snd.volume > 0, "the collect is audible")
check(snd.volume < 0.6, "and quieter than the once-per-rebirth bank it shares an id with")
check(snd.distance < 70, "and carries less far than the pig's own")
-- Under the pad's own figure range, because both exist for the same reader:
-- the owner walking their own grass.
check(snd.distance <= Config.PIGGY_PEDESTAL.pad.labelRange,
	"and no further than the figure on the same pad")

-- THE PITCH LADDER. `PlaybackSpeed` is a raw resample in this engine -- the
-- ride audio entry measures what a 40% shift costs in grain -- so the band
-- has to stay near 1.0 as well as climbing.
check(snd.pitchHigh > snd.pitchLow, "a fuller buffer chimes higher than an emptier one")
check(snd.pitchLow > 0.7 and snd.pitchHigh < 1.4,
	"and the whole band stays near 1.0, where a resample is not grainy")
check(Config.piggyCollectPitch(0) == snd.pitchLow, "an empty-ish collect lands on the floor")
check(Config.piggyCollectPitch(1) == snd.pitchHigh, "a completely full buffer lands on the ceiling")
-- MONOTONIC ACROSS THE WHOLE RANGE, which is the only thing that makes the
-- cue readable as a report on how full the pad was.
local previousPitch = -math.huge
for step = 0, 20 do
	local pitch = Config.piggyCollectPitch(step / 20)
	check(pitch > previousPitch, ("pitch climbs at share %.2f"):format(step / 20))
	previousPitch = pitch
end
-- SQUARE ROOT RATHER THAN LINEAR, and this is the assertion that says so: the
-- midpoint sits ABOVE the straight line between the two ends, which is what
-- spreads the SMALL hauls out instead of bunching them all on the floor.
local midpoint = Config.piggyCollectPitch(0.5)
check(midpoint > (snd.pitchLow + snd.pitchHigh) / 2,
	"the curve favours the small hauls, so they differ from each other")

-- EVERY SHARE A LIVE COLLECT CAN HAND IT LANDS IN THE BAND. The quotient has
-- a RATE underneath it, so an empty pedestal divides by zero -- and a nan
-- PlaybackSpeed is SILENCE, which is the one failure shape indistinguishable
-- from this feature never having been wired up.
local zero = 0
for _, odd in { -1, 0, 0.5, 1, 2, 1e9, zero / zero, 1 / zero, -1 / zero } do
	local pitch = Config.piggyCollectPitch(odd)
	check(pitch == pitch, "a share of " .. tostring(odd) .. " is not a nan pitch")
	check(pitch >= snd.pitchLow and pitch <= snd.pitchHigh,
		"and stays inside the band: " .. tostring(odd))
end
check(Config.piggyCollectPitch(nil) == snd.pitchLow, "and a missing share reads as the floor")

-- THE REASON CAPACITY IS NOT THE DENOMINATOR USED TO BE MEASURED HERE: a
-- common's full buffer was a real share of the pig at every level and a
-- legendary's OVERFLOWED it, so a capacity-based pitch would have pinned
-- every good piggy at the ceiling. The measurement is unrunnable now -- the
-- pig has no capacity at all -- and the CONCLUSION stands more firmly for
-- it: the slot's own ceiling, `rate * piggyBufferSeconds`, is capacity-free
-- and is the right denominator. Pinned as the absence rather than the ratio.
check(Config.getCapacity == nil, "there is no capacity for the pitch to be measured against")
-- The slot's OWN ceiling cannot saturate, by construction: the accrual loop
-- caps a buffer at exactly it, so `take / ceiling` never exceeds 1.
check(Config.piggyCollectPitch(1) == snd.pitchHigh,
	"while the slot's own ceiling tops out exactly at the top of the band")

-- ONE BUILDER FOR ALL SEVEN PADS, which is the property the FIGURE already
-- had to learn the hard way: the till is a top-level number while the six are
-- an array, so anything written per-pedestal covers six of seven and looks
-- complete. Measured in the source, because the two callers are in different
-- files and no runtime check here can see both.
local pedestalSrc = sources.PiggyPedestal
local bankSrc = sources.PiggyBank
check(pedestalSrc:find("function PiggyPedestal.buildPadSound", 1, true) ~= nil,
	"the pad sound has one shared builder")
-- AND THE BANK BUILDS NO PAD AT ALL (designer decision 2026-09-22): the
-- centre pig drips straight into the balance, so the shared builder has six
-- callers on the plinths and none on the pig.
check(bankSrc:find("PiggyPedestal.buildPadSound(", 1, true) == nil,
	"and the bank builds no pad: it drips")
-- NEITHER FILE BUILDS A PAD SOUND OF ITS OWN. The whole point of the shared
-- builder is that there is nowhere else a Sound named for a pad can appear.
-- COUNTED PLAIN, NEVER WITH `gsub`. A Lua pattern eats `(` and `)` as a
-- CAPTURE, so `gsub('Instance.new("Sound")', "")` silently matches nothing at
-- all against source that plainly contains it -- it came back 0 here first
-- time and read as the shared builder being missing. `find` with the plain
-- flag is the only honest way to count a code fragment.
local function countPlain(haystack, needle)
	local n, at = 0, 1
	while true do
		local from, to = haystack:find(needle, at, true)
		if not from then
			return n
		end
		n, at = n + 1, to + 1
	end
end
check(countPlain(pedestalSrc, 'Instance.new("Sound")') == 1,
	"and PiggyPedestal constructs exactly one Sound")
check(countPlain(bankSrc, "PadCollect") == 0,
	"with PiggyBank naming no pad sound of its own")

-- AND THE FIGURE IS A SURFACE RATHER THAN A BILLBOARD, IN THE SOURCE. This is
-- the regression guard for "floating above it": the pad figure and the piggy's
-- NAME label are both world type built in this one file, and only the name is
-- supposed to hang in the air. A `BillboardGui` count of exactly one is what
-- says the pad's did not quietly come back.
check(countPlain(pedestalSrc, 'Instance.new("SurfaceGui")') == 1,
	"the pad figure is built as a surface")
check(countPlain(pedestalSrc, 'Instance.new("BillboardGui")') == 1,
	"and the only billboard left in the file is the name over the piggy's head")
check(pedestalSrc:find("Enum.NormalId.Top", 1, true) ~= nil,
	"painted on the pad's top face")
-- THE TILL GOES THROUGH THE SAME BUILDER, so it cannot be left floating on the
-- one placement every player meets first -- the failure its FIGURE already had
-- once, when the six pedestals carried a number and the till carried nil.
check(countPlain(bankSrc, 'Instance.new("SurfaceGui")') == 0
	and countPlain(bankSrc, "PiggyPedestal.buildPadFigure(") == 0,
	"and the bank prints no pad figure either, having no pad")
-- NOTHING TOGGLES THE FIGURE OFF ANY MORE. The colour carries the state and
-- the number is always printed, so an `Enabled` write here would be a third
-- state the two channels do not describe.
check(countPlain(pedestalSrc, "padLabel.Enabled") == 0,
	"and nothing hides the figure, because red already says not-ready")

-- THE COLLECT ROUTES TO THE PAD THAT BANKED IT. The cheap version plays the
-- till's existing cue for every collect, which would put the noise 25 studs
-- from the pedestal the player is standing on.
local plotSrc = sources.PlotService
check(plotSrc:find("function PlotService.playCollect", 1, true) ~= nil,
	"PlotService routes a collect to a slot")
check(plotSrc:find("pedestal.padSound", 1, true) ~= nil, "reaching the pedestal's own sound")
check(plotSrc:find("collectPadSound", 1, true) == nil, "and never a till sound: the bank has no pad")
-- Nothing toggles the till's figure off either: the colour is the state.
check(countPlain(plotSrc, "collectPadLabel") == 0,
	"and nothing hides the till's figure, for the same reason")
-- AND IT IS ACTUALLY FIRED. A cue nothing calls is the shape of bug this
-- project keeps recording: `PlotService.playBank` sat with one caller, and the
-- whole standing event countdown was a display nobody had written.
local econSrc = sources.EconomyService
check(econSrc:find("PlotService.playCollect(", 1, true) ~= nil,
	"and a collect actually fires it")
-- OFF `take` RATHER THAN `buffered`, because the clamp above it can leave most
-- of a fat buffer behind -- and a cue pitched off what was WAITING would ring
-- out a big collect the player did not get, one line after a toast saying so.
check(econSrc:find("take / ceiling", 1, true) ~= nil,
	"pitched off what was banked, not off what was waiting")

-- ------------------------------------------- WHAT IT EARNS, UNDER THE NAME
-- Designer call 2026-09-21. The name says WHICH piggy; the row under it says
-- what that is worth per second, which is the number the one decision this
-- lawn creates -- which piggy stands in a slot -- is actually made on.
do
	local spec = Config.PIGGY_NAME
	check(spec.rateHeight > 0, "there is a rate row at all")
	-- SECONDARY, AND THE ONLY WAY TO SAY SO IS THE HEIGHT: both rows are
	-- TextScaled, so a rate row as tall as the name renders type as big as
	-- the name and the pair reads as two names rather than as a label and
	-- its figure.
	check(spec.rateHeight < spec.size.Y,
		"the rate is shorter than the name it hangs under")
	-- AND NOT MUCH SHORTER, which is the half that had no guard. It shipped at
	-- 52% of the name and was reported as needing to be larger -- measured, 24
	-- rendered pixels against the name's 47 from a plinth's length away. A
	-- lower bound is what stops a later tidy-up quietly putting it back.
	local share = spec.rateHeight / spec.size.Y
	check(share > 0.6, ("the rate is read rather than looked for (%.0f%% of the name)")
		:format(share * 100))
	check(share < 0.9, ("and still subordinate to it (%.0f%%)"):format(share * 100))
	-- AND THE PAIR IS STILL A LABEL RATHER THAN A BANNER. The whole billboard
	-- is what gets lifted off the piggy's crown, so the guard that caught the
	-- pixel-sized version has to be re-run against the TOTAL rather than
	-- against the name row it used to be the whole of.
	local total = spec.size.Y + spec.rateHeight
	check(total < 3, "both rows together are a stud-scale height")
	check(total < spec.size.X, "the label is still wider than it is tall")
end

-- THE FIGURE ITSELF, DRIVEN THROUGH THE REAL FUNCTION rather than asserted
-- about. `setRate` is three lines and every one of them is a rule: the
-- formatter is shared with the HUD so the two can never disagree, nil says
-- NOTHING rather than zero, and the write is guarded so the economy tick
-- does not replicate six strings a tick forever.
do
	local body = assert(sources.PiggyPedestal:match(
		"(function PiggyPedestal%.setRate.-)\nend")) .. "\nend"
	local run = assert(loadstring(
		"local Config = ...; local PiggyPedestal = {} " .. body ..
		" return PiggyPedestal", "setRate"))
	local Pedestal = run(Config)
	local writes = 0
	local text = setmetatable({}, {
		__index = function(t, k) return rawget(t, "_" .. k) end,
		__newindex = function(t, k, v) writes += 1; rawset(t, "_" .. k, v) end,
	})
	text.Text = ""
	writes = 0
	local refs = { rateText = text }

	Pedestal.setRate(refs, 10)
	check(text.Text == "+10/s",
		("a common at level zero reads +10/s, not %q"):format(text.Text))
	-- THE SAME FORMATTER THE HUD'S RATE PILL USES, which is what stops the
	-- two readouts drifting into two different roundings of one number.
	Pedestal.setRate(refs, 12345)
	check(text.Text == ("+%s/s"):format(Config.formatCoins(12345)),
		"a big rate goes through Config.formatCoins")

	-- NIL IS NOT ZERO. A rate that has not arrived yet is blank; a pedestal
	-- printing +0/s under a legendary is wrong in the direction that makes a
	-- player stop believing the number.
	Pedestal.setRate(refs, nil)
	check(text.Text == "", "an unknown rate says nothing rather than zero")
	Pedestal.setRate(refs, 0)
	check(text.Text == "", "and neither does a slot earning nothing")

	-- WRITTEN ONLY WHEN IT CHANGED. This runs six times a plot on the economy
	-- tick and a Text write replicates to every client in range, so a rate
	-- that has not moved has to cost nothing.
	Pedestal.setRate(refs, 10)
	local before = writes
	for _ = 1, 20 do Pedestal.setRate(refs, 10) end
	check(writes == before, "a rate that did not move is not rewritten")

	-- AND AN EMPTY PEDESTAL HAS NO ROW AT ALL, because `dress` destroys the
	-- label with the piggy. Passing a rate to one must be a no-op rather than
	-- an index of nil on the accrual tick.
	Pedestal.setRate({}, 999)
	check(true, "a pedestal with no rate row is left alone")
end

-- THE WIRING, WHICH IS THE HALF THAT FAILS SILENTLY. The label is built in
-- `Shared` and the number lives two services away, so the feature is one
-- registration line from building perfectly and staying blank forever -- and
-- a blank row looks exactly like a feature that was never added.
check(sources.PlotService:find("PiggyPedestal.setRate(pedestal", 1, true) ~= nil,
	"the pedestal loop paints the rate beside the buffer")
check(sources.PlotService:find("function PlotService.registerPiggyRates", 1, true) ~= nil,
	"PlotService asks for the rate rather than deriving a pre-boost one")
check(sources.EconomyService:find("function EconomyService.pedestalRates", 1, true) ~= nil,
	"EconomyService answers it, boost and friend bonus included")

-- ------------------------------------------- GRASS DOES NOT GROW THROUGH
-- Reported as the grass clipping through the collect buttons, and measured
-- live that is precisely what it was: a pad face stands 0.06 studs above the
-- lawn and a tuft reaches 1.29, so every blade near one grew straight
-- through it. `GrassTuft.clearance` is the veto the scatter never had.
--
-- THE PREDICATE IS RUN, NOT DESCRIBED. Parts are stubbed as plain tables --
-- nothing here builds an Instance -- because what is worth pinning is the
-- BAND RULE and its three exemptions, and every one of those is arithmetic
-- over a CFrame and a Size.
do
	local body = assert(sources.GrassTuft:match(
		"(function GrassTuft%.clearance.-)\nend")) .. "\nend"
	local run = assert(loadstring(
		"local Config = ...; local GrassTuft = {} " .. body ..
		" return GrassTuft", "clearance"))
	local Grass = run(Config)
	local spec = Config.grassTuft()
	check(spec ~= nil, "the catalogue carries a tuft to reason about")
	local reach = spec.size.Y * spec.maxScale - spec.sink

	-- A surface at y = 0, so every figure below reads as studs above the lawn.
	local function part(x, z, bottom, height, w, d, anchored)
		return {
			Anchored = anchored ~= false,
			Size = { X = w, Y = height, Z = d },
			CFrame = {
				Position = { X = x, Y = bottom + height / 2, Z = z },
				RightVector = { X = 1, Y = 0, Z = 0 },
				UpVector = { X = 0, Y = 1, Z = 0 },
				LookVector = { X = 0, Y = 0, Z = 1 },
			},
			IsA = function(_, class) return class == "BasePart" end,
		}
	end
	local function model(parts)
		return { GetDescendants = function() return parts end }
	end
	local function at(x, z) return { X = x, Y = 0, Z = z } end

	-- THE REPORTED BUG, in the geometry that produced it: a collect pad face
	-- 0.06 proud of the lawn, 7 studs across.
	local pad = Grass.clearance(model({ part(0, 0, -0.2, 0.26, 7, 7) }), 0)
	check(pad ~= nil, "a pad 0.06 studs proud still blocks grass")
	check(not pad(at(0, 0)), "and no tuft is planted on it")
	check(pad(at(20, 0)), "while the rest of the lawn is untouched")

	-- THE MARGIN IS HALF A TUFT, because a clump 2.8 studs across centred
	-- just outside a pad still leans over it. Just inside the margin is
	-- refused; just outside it is planted.
	local edge = 3.5
	local half = math.max(spec.size.X, spec.size.Z) * spec.maxScale / 2
	check(not pad(at(edge + half - 0.05, 0)), "a tuft leaning over the edge is refused")
	check(pad(at(edge + half + 0.05, 0)), "one clear of it by its own width is planted")

	-- ABOVE THE BAND IS NOT A BLOCKER. House FX, a sign's board and every
	-- billboard hang in the air, and a bounding box would catch all of them
	-- -- the trap that once recorded the Sky Castle as 16.6 studs too wide
	-- when it was measuring orbiting shards at altitude.
	check(Grass.clearance(model({ part(0, 0, reach + 0.1, 4, 20, 20) }), 0) == nil,
		"something hanging clear of the tallest tuft blocks nothing")
	-- And the one just inside it does, because that one really is clipped.
	check(Grass.clearance(model({ part(0, 0, reach - 0.1, 4, 20, 20) }), 0) ~= nil,
		"something inside the band blocks, however high its top")

	-- BELOW THE BAND IS NOT A BLOCKER EITHER, which is the stone trim: it
	-- tops out 0.2 studs UNDER the lawn -- proud of the world ground rather
	-- than of the grass -- and it rings the whole yard, so catching it would
	-- take every blade on the plot.
	check(Grass.clearance(model({ part(0, 0, -2, 1.8, 68, 160) }), 0) == nil,
		"the stone trim never enters the band and costs no grass")

	-- AN UNANCHORED PART IS NEVER A BLOCKER, WHICH IS THE GUARD DOG. It
	-- WALKS, so a patch cleared under one is a patch cleared where it
	-- happened to be standing -- a bald spot in the middle of a lawn with
	-- nothing on it. Measured live: zero dog parts block on any of ten plots.
	check(Grass.clearance(model({ part(0, 0, 0, 2, 6, 6, false) }), 0) == nil,
		"a dog standing on the lawn takes no grass with it")

	-- AND THE GROUND ITSELF IS NAMED RATHER THAN DEDUCED. A lawn slab's top
	-- IS the surface, so it sits exactly on the band's floor -- excluded by a
	-- comparison that is true by a hair rather than by intent. Both halves
	-- are asserted, because the second is what `ignore` is actually for.
	local flush = part(0, 0, -1, 1, 64, 64)
	check(Grass.clearance(model({ flush }), 0) == nil,
		"a slab whose top is exactly the surface is not standing on it")
	-- A HAIR THE OTHER SIDE OF ZERO AND IT TAKES THE WHOLE LAWN. That is one
	-- float away from the line above, on a part 64 studs across, so the
	-- surfaces being planted are named rather than left to arithmetic.
	local proud = part(0, 0, -1, 1.001, 64, 64)
	check(Grass.clearance(model({ proud }), 0) ~= nil,
		"the same slab a thousandth proud would refuse every spot on it")
	check(Grass.clearance(model({ proud }), 0, { [proud] = true }) == nil,
		"which is exactly what `ignore` exists to stop")
end

-- THE WIRING, which is the half that fails silently: the veto exists and is
-- worth nothing unless the lawn is replanted around what is standing on it,
-- and a lawn is planted at three different moments.
check(sources.PlotService:find("function PlotService.plantGrass", 1, true) ~= nil,
	"the lawn has one planting path")
do
	local calls = select(2, sources.PlotService:gsub("PlotService%.plantGrass%(plot%)", ""))
	-- A BUILD, A HOUSE TIER AND AN ORNAMENT. The first two arrive after the
	-- grass was planted and the third both arrives AND leaves, which is why
	-- this is a replant rather than a trim.
	check(calls == 3, ("the lawn is replanted at all three sites that change it (%d)"):format(calls))
end

-- ------------------------------------------- THE COLLECT BUTTON'S COLOURS
-- The pad is asked ONE question from across a lawn -- go or do not go -- and
-- it answers with a red/green pair. Both halves of that are measurable and
-- neither errors when it breaks, which is the shape this file's audits exist
-- for: a pad tuned to a prettier green that nobody can see from the pavement
-- reads as the feature simply not being there.
--
-- THE HARNESS STUBS `Color3.fromRGB` AS ITS OWN ARGUMENTS, so a tone here is
-- a plain {r, g, b} and real WCAG arithmetic runs offline. That is worth
-- knowing: colour choices in this project are otherwise defended only in
-- prose, and prose does not fail.
do
	local function channel(v)
		local c = v / 255
		return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
	end
	local function luminance(tone)
		return 0.2126 * channel(tone[1]) + 0.7152 * channel(tone[2]) + 0.0722 * channel(tone[3])
	end
	local function contrast(a, b)
		local la, lb = luminance(a), luminance(b)
		local hi, lo = math.max(la, lb), math.min(la, lb)
		return (hi + 0.05) / (lo + 0.05)
	end
	local pad = Config.PIGGY_PEDESTAL.pad
	-- The two grounds a pad is read against, written out here because they
	-- live in `PlotService` and `Theme`, neither of which this suite loads.
	local LAWN = { 94, 128, 68 }
	local INK = { 41, 32, 27 }

	-- A PAD THAT CANNOT BE PICKED OUT OF THE GRASS IS A BUTTON NOBODY WALKS
	-- TO. The mint this replaced measured 2.29 and the money green 2.33, so
	-- the floor is set just under the pair that has actually shipped.
	check(contrast(pad.readyColour, LAWN) >= 2.2,
		("a ready pad is visible against the lawn (%.2f)"):format(contrast(pad.readyColour, LAWN)))

	-- AND THE TWO STATES DIFFER IN LIGHTNESS, NOT ONLY IN HUE. Red against
	-- green is precisely the pair that goes for a colour-blind nine-year-old,
	-- so go/no-go may not rest on hue alone -- and the tempting fix for this
	-- button, darkening the green until it looks like a banknote, is exactly
	-- what collapses it: swept, hue 150 at value 0.50 lands at 1.33.
	check(contrast(pad.readyColour, pad.emptyColour) >= 1.8,
		("ready and empty differ in lightness as well as hue (%.2f)"):format(
			contrast(pad.readyColour, pad.emptyColour)))

	-- THE FIGURE IS CARRIED BY ITS STROKE RATHER THAN BY ITS FILL, which is
	-- what lets the number be white on a saturated button. What has to clear
	-- the large-type floor is the INK OUTLINE against each state -- the fill
	-- itself measures under 2 on the green and is not the governing pair.
	for name, ground in { ready = pad.readyColour, empty = pad.emptyColour } do
		check(contrast(INK, ground) >= 3.0,
			("the figure's stroke reads on the %s pad (%.2f)"):format(name, contrast(INK, ground)))
	end

	-- MONEY GREEN IS A SATURATION CLAIM, so it is asserted as one. A tone
	-- whose channels are close together is a pastel however bright it is, and
	-- the mint this replaced sat at 0.72 of full.
	local hi = math.max(pad.readyColour[1], pad.readyColour[2], pad.readyColour[3])
	local lo = math.min(pad.readyColour[1], pad.readyColour[2], pad.readyColour[3])
	check(hi > 0 and (hi - lo) / hi >= 0.9,
		("the ready pad is a saturated green rather than a mint (%.2f)"):format((hi - lo) / hi))
	check(pad.readyColour[2] > pad.readyColour[1] and pad.readyColour[2] > pad.readyColour[3],
		"and it is green rather than some other saturated thing")
end

-- AND THE FIGURE IS PAPER ON AN OPAQUE INK STROKE. The transparency is the
-- load-bearing half -- a soft stroke puts the FILL back in charge, and the
-- fill measures 1.82 on the green -- so it is pinned rather than left to the
-- next person to nudge.
check(sources.PiggyPedestal:find("amount.TextColor3 = Theme.PAPER", 1, true) ~= nil,
	"the collect figure is white")
check(sources.PiggyPedestal:find("amount.TextStrokeColor3 = Theme.INK", 1, true) ~= nil,
	"with a black stroke")
-- A PATTERN RATHER THAN A LITERAL, so `0.35` cannot pass as `0`: the class
-- refuses a digit or a point straight after the zero.
check(sources.PiggyPedestal:find("amount%.TextStrokeTransparency = 0[^%.0-9]") ~= nil,
	"and the stroke is fully opaque, which is what carries the fill")

-- ------------------------------- WHAT A ROBBERY IS MEASURED IN, AND COSTS
-- Designer call 2026-09-21. Most Wanted ranks on the VALUE OF PIGGIES taken
-- off other players, and bail is a share of the thief's own till rather
-- than a multiple of a haul that no longer has a coin figure.
do
	-- A PIGGY'S WORTH IS ITS SELL VALUE AND MUST NOT BE A SECOND PRICE. The
	-- pedestal's sell prompt already prints this number while you hold the
	-- button; a rap sheet priced any other way would be two valuations of
	-- one object, drifting the first time either moved.
	for key in pairs(Config.SKINS) do
		if Config.piggyWorth(key) ~= Config.sellValue("skin", key) then
			check(false, ("%s is worth one number, not two"):format(key))
		end
	end
	check(true, "every piggy's rap-sheet worth is its sell value")

	-- AND IT CLIMBS WITH THE TIER, or the board would rank a thief who took
	-- six commons above one who took a legendary -- which is the collection
	-- saying one thing and the leaderboard another.
	local function dearest(tier)
		local best = 0
		for key, skin in pairs(Config.SKINS) do
			if Config.rarityOf(skin) == tier then
				best = math.max(best, Config.piggyWorth(key))
			end
		end
		return best
	end
	check(dearest("legendary") > dearest("common"),
		"the dearest legendary outranks the dearest common on a rap sheet")

	-- AN UNKNOWN KEY IS WORTH NOTHING RATHER THAN THROWING. A snatch runs
	-- inside somebody's robbery, and a retired skin key reaching the board
	-- must not take the delivery down with it.
	check(Config.piggyWorth("no-such-piggy") == 0,
		"a key no catalogue carries scores zero rather than erroring")

	-- BAIL IS A SHARE, AND THE SHARE IS SURVIVABLE BY CONSTRUCTION. The old
	-- `3x the haul` needed a cap to stop an eighty-to-one punishment; a
	-- fraction cannot produce one, and that is the property worth pinning.
	local f = Config.POLICE.bailFraction
	check(f > 0 and f < 0.5,
		("bail takes a real but survivable share of the till (%.2f)"):format(f))
	check(Config.POLICE.bailMultiple == nil,
		"and the multiple it replaced is gone rather than left to be read")

	-- THE THREE SURFACES QUOTE ONE NUMBER. The poster, the pull-over warning
	-- and the dev console each word it differently and must not each do the
	-- arithmetic -- `CLAUDE.md`'s own rule about a second copy of a grammar.
	check(Config.bailPercent() == math.floor(f * 100 + 0.5),
		"the published percentage is the charged fraction")
	check(Config.bailPercent() >= 1,
		"and it is a whole percent a nine-year-old can hold in their head")
end

-- THE WIRING, and the sequencing that keeps the board lit while the snatch
-- is built: the coin path still feeds the rap sheet, so nothing goes dark.
check(sources.PoliceService:find("data.coins * Config.POLICE.bailFraction", 1, true) ~= nil,
	"bail is charged against the thief's own till")
check(sources.PoliceService:find("chargeBail(thief: Player)", 1, true) ~= nil,
	"and it takes no haul argument it would only ignore")
check(sources.SocialService:find("SocialService.recordSteal", 1, true) ~= nil,
	"the rap sheet still has a source, so Most Wanted is not dark")


-- ============================================================
-- CARRYING A PIGGY BETWEEN PEDESTALS
-- ============================================================
--
-- docs/PIGGY-COLLECTION-PLAN.md §3 and §5: take your own off its plinth,
-- snatch somebody else's off theirs, and put one down on a free slot of your
-- own. What this suite can see is the same half it can see of the collect
-- path -- the BOOKKEEPING and the constants -- and not the plinth, the
-- prompt, the five-second dwell or a piggy in somebody's arms. Those want a
-- Play session.
do
	local function lawn()
		return { piggies = { owned = {}, till = Config.DEFAULT_SKIN, slots = {} } }
	end
	local function placedCount(data)
		local n = 0
		for _, entry in ipairs(Config.piggySlots(data)) do
			if entry.key ~= nil then
				n += 1
			end
		end
		return n
	end

	-- A PLACEMENT LANDS ON THE SLOT IT IS ASKED FOR, which is the whole of
	-- why this function exists beside `addPiggy`: a crate lands front to
	-- back, and a piggy somebody CARRIED HOME is placed by hand.
	local data = lawn()
	local last = Config.PIGGY_LAWN_SLOT_COUNT
	check(Config.placePiggy(data, "cow", last), "a carried piggy lands on the slot it is given")
	check(Config.piggySlots(data)[last].key == "cow", "on THAT slot and not the first free one")
	check(Config.firstFreePiggySlot(data) == 1, "with the front of the lawn untouched")
	check(data.piggies.owned.cow == 1, "and ownership goes up with the placement")

	-- AND THE BUFFER IS ZERO, NEVER WHAT THE SLOT WAS HOLDING. Plan §4a: a
	-- piggy taken off a lawn brings its buffer as zero rather than as a
	-- windfall, because the object was the target and its small change never
	-- was.
	Config.piggySlots(data)[2].buffer = 4321
	check(Config.placePiggy(data, "cow", 2), "a second copy places beside the first")
	check(Config.piggySlots(data)[2].buffer == 0, "and it starts on an empty buffer")
	check(data.piggies.owned.cow == 2, "duplicates place individually and both are owned")

	-- AN OCCUPIED SLOT IS REFUSED RATHER THAN OVERWRITTEN, and the count does
	-- not move. An overwrite destroys a piggy with nothing in any log --
	-- `slots` would hold the new key while `owned` still counted the old one,
	-- and the collection total and the lawn would disagree for the rest of
	-- that save's life.
	check(not Config.placePiggy(data, "tiger", 2), "an occupied pedestal refuses a placement")
	check(Config.piggySlots(data)[2].key == "cow", "and what was standing there is still standing")
	check(data.piggies.owned.tiger == nil, "a refused placement bumps nothing")

	-- OFF THE END OF THE LAWN IS REFUSED TOO. `piggySlots` grows its array to
	-- the slot count, so an unguarded write past the end would be a sparse
	-- table -- which is neither an array nor a dictionary to JSON, and is
	-- exactly where `SetAsync` starts refusing saves.
	check(not Config.placePiggy(data, "tiger", 0), "slot 0 is the till and is not a pedestal")
	check(not Config.placePiggy(data, "tiger", last + 1), "and there is no slot past the last one")
	check(#Config.piggySlots(data) == last, "the array stays exactly as long as the lawn")

	-- ------------------------------------------------------------
	-- A ROUND TRIP LEAVES NOTHING BEHIND
	-- ------------------------------------------------------------
	--
	-- Taking a piggy off a plinth and putting it back is the commonest thing
	-- this feature does, and it is the one that has to be exactly reversible:
	-- `take` removes it (which decrements `owned`, because placement IS
	-- ownership under the six-slot lawn) and `place` puts it back. A drift of
	-- one in either direction is a piggy minted or destroyed by tidying.
	local before = placedCount(data)
	local key = Config.removePiggy(data, 2)
	check(key == "cow", "taking one off hands back what was standing there")
	check(data.piggies.owned.cow == 1, "and the count comes down while it is in your arms")
	check(Config.placePiggy(data, key, 1), "putting it down on a different slot works")
	check(data.piggies.owned.cow == 2, "the count comes straight back")
	check(placedCount(data) == before, "and the lawn holds exactly as many as it did")
	check(Config.piggySlots(data)[2].key == nil, "the slot it came off is empty")
	check(Config.piggySlots(data)[1].key == "cow", "and it is standing where it was put")

	-- A RECOVERY PUTS IT BACK WHERE IT WAS, which is what `putBack` tries
	-- first. Landing on whatever slot happened to be free would reshuffle a
	-- victim's lawn every time somebody failed to rob them -- a cost the
	-- victim pays for winning.
	local victim = lawn()
	Config.placePiggy(victim, "cow", 1)
	Config.placePiggy(victim, "tiger", 4)
	local taken = Config.removePiggy(victim, 4)
	check(Config.firstFreePiggySlot(victim) == 2, "a robbed lawn has a hole in the middle of it")
	check(Config.placePiggy(victim, taken, 4), "and a recovered piggy goes back into that hole")
	check(Config.piggySlots(victim)[2].key == nil, "rather than to the front of the lawn")
end

-- ------------------------------------------------------------
-- THE FOUR HOLDS AND THE FIVE SECONDS
-- ------------------------------------------------------------
do
	local haul = Config.PIGGY_HAUL

	-- A LADDER OF CONSEQUENCE, which is the same argument `PIGGY_SELL.hold`
	-- and `SMASH.hold` make. Taking your own costs nobody anything; taking
	-- somebody else's takes one of the seven things they own.
	check(haul.takeHold > 0, "even the free verb needs a hold, because three prompts share this key")
	check(haul.snatchHold > haul.takeHold, "taking somebody else's is dearer than taking your own")
	check(haul.snatchHold > Config.SMASH.hold, "and dearer than a smash, which only takes coins")
	check(haul.snatchHold < Config.PIGGY_SELL.hold,
		"and cheaper than selling, which is the one thing here that cannot be undone")
	check(haul.placeHold == haul.takeHold,
		"putting one down costs what picking it up did -- one gesture, two halves")

	-- DERIVED, NOT COPIED. A nab is a nab whether what is dropped is coins or
	-- a piggy, and a lawn's cooldown is the street's own. Two copies of
	-- either would be two answers to one question, which is how
	-- `SHOP_BANK_PIG_SECONDS` came to be wrong by 62%.
	check(haul.nabHold == Config.NAB.hold, "a piggy nab holds exactly as long as a coin nab")
	check(haul.victimCooldown == Config.STEAL_COOLDOWN,
		"and one lawn may be picked over on the street's own cooldown")

	-- THE DWELL IS A WHOLE PLOT'S WALK, AND IT IS THE CHASER'S BODY THAT
	-- DECIDES THAT RATHER THAN THE THIEF'S.
	--
	-- The first version of this check measured the dwell against CARRY speed
	-- and failed -- 60 studs against a 64-stud lawn -- which is the "measure
	-- the wrong body" fault this project keeps recording. The person the five
	-- seconds exist for is the VICTIM, and a victim is not carrying anything:
	-- they run at `BASE_WALK_SPEED` while the thief walks home at
	-- `CARRY_SPEED_MULTIPLIER` of it.
	--
	-- Which is also why the thief is caught at all. The shortest getaway is
	-- one plot: the thief covers it at 12 and the victim at 16, so the victim
	-- is already arriving as the dwell starts -- and the dwell is then a
	-- whole extra plot's walk of slack for one who set off late, went round
	-- the houses, or had to get off a ride first.
	check(haul.secureSeconds * Config.BASE_WALK_SPEED >= Config.PLOT_SPACING,
		("the dwell is a whole plot's walk for somebody chasing (%.0f studs against %.0f)")
			:format(haul.secureSeconds * Config.BASE_WALK_SPEED, Config.PLOT_SPACING))
	check(Config.PLOT_SPACING / (Config.BASE_WALK_SPEED * Config.CARRY_SPEED_MULTIPLIER)
		> Config.PLOT_SPACING / Config.BASE_WALK_SPEED,
		"and a loaded thief is slower over that ground than the person chasing them")
end

-- ------------------------------------------------------------
-- THREE VERBS, AND NO CLIENT EVER SEES TWO OF THEM
-- ------------------------------------------------------------
do
	-- EVERY KIND CARRIES ALL THREE CHANNELS, which is this project's own rule
	-- rather than a nicety: colour is never the only signal, because colour
	-- alone separates these three only for players who can see three.
	for _, kind in { "take", "snatch", "place" } do
		local style = Config.PROMPTS[kind]
		check(style ~= nil, kind .. " is a prompt kind of its own")
		check(type(style.verb) == "string" and #style.verb > 0, kind .. " says a word")
		check(style.glyph ~= nil and #style.glyph >= 4,
			kind .. " carries a four-byte glyph, which has no monochrome text form to fall back to")
	end
	check(Config.PROMPTS.take.verb ~= Config.PROMPTS.snatch.verb,
		"taking your own and taking somebody else's do not say the same word")

	-- SNATCH WEARS STEAL'S OWN RED, deliberately: it is the same crime
	-- against the same person by a different door, so a player who has
	-- learned that red means somebody is about to lose something does not
	-- have to learn it twice.
	local function same(a, b)
		return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
	end
	check(same(Config.PROMPTS.snatch.tone, Config.PROMPTS.steal.tone),
		"a snatch is the same red a coin robbery is")
	check(same(Config.PROMPTS.take.tone, Config.PROMPTS.collect.tone),
		"and taking your own is the same gold banking your own is")
	check(not same(Config.PROMPTS.place.tone, Config.PROMPTS.snatch.tone),
		"putting one down is not the colour of taking one")

	-- THE EXCLUSIVITY GUARANTEE, ASSERTED AT THE PLACE IT IS MADE. Three
	-- verbs share one plinth on one key, so what keeps `PromptUI`'s
	-- one-card-per-part assumption true is that the two owner rules are exact
	-- complements: the owner's prompt names the owner, the snatch REFUSES the
	-- owner, and no client can ever match both.
	local src = sources.PiggyPedestal
	check(src:find("Config.PROMPT_OWNER_ATTRIBUTE", 1, true) ~= nil
		and src:find("Config.PROMPT_DENY_OWNER_ATTRIBUTE", 1, true) ~= nil,
		"the haul prompts are attributed as complements")

	-- TAKE AND PLACE ARE SEPARATED BY THE PLINTH, which is the other half of
	-- "never two cards on one key". Both are the owner's, so the owner rule
	-- cannot tell them apart -- what does is that one is live only while
	-- something is standing here and the other only while nothing is.
	check(src:find("refs.takePrompt.Enabled = owned and refs.key ~= nil", 1, true) ~= nil
		and src:find("refs.placePrompt.Enabled = owned and refs.key == nil", 1, true) ~= nil,
		"take and place are exact opposites on the plinth's own occupancy")

	-- ONE FUNCTION OWNS THE OWNER AND `Enabled` FOR ALL FOUR PROMPTS ON A
	-- PLINTH, which is what makes "the owner, then Enabled, always" a
	-- property of that function rather than of the distance between two
	-- loops. `dress` says what the cards READ and switches nothing on.
	check(src:find("dress") ~= nil and src:find("refs%.%w*[Pp]rompt%.Enabled = ") ~= nil,
		"prompts are switched somewhere")
	local _, enables = src:gsub("refs%.%w+Prompt%.Enabled = ", "")
	check(enables == 8, ("every Enabled write is in setHaul or republish (%d)"):format(enables))

	-- AND A PLOT CHANGING HANDS BOUNCES THEM ACROSS A REAL FRAME. Writing the
	-- owner before `Enabled` is necessary and is NOT sufficient: the client's
	-- one-time sweep can land between the two replications and refuse a
	-- prompt the reader owns, and its rules may only ever refuse -- so nothing
	-- would ever take it back. Measured on a live plot at three of six sell
	-- prompts locally dead with the owner attribute correct on both sides.
	check(src:find("function PiggyPedestal.republish", 1, true) ~= nil,
		"a plinth can be re-published from scratch")
	check(src:find("task.delay(REPUBLISH_DELAY", 1, true) ~= nil,
		"across a real frame, because an off-and-on inside one frame replicates as no change at all")
	check(src:find("if refs.generation ~= generation then", 1, true) ~= nil,
		"and a later republish wins rather than whichever timer lands last")
	check(sources.PlotService:find("if claimed then", 1, true) ~= nil,
		"and it is the plot changing hands that triggers it, not every repaint")

	-- AND NEITHER PROMPT'S KIND EVER CHANGES UNDER A CARD THAT IS ALREADY UP.
	-- `PromptUI` builds a card on `PromptShown` and never rebuilds it, so a
	-- prompt that swapped kinds would leave the word on screen describing the
	-- verb it used to be -- at exactly the commonest moment there is, a player
	-- standing at the plinth they have just cleared.
	check(src:find("setPromptKind(refs%.") == nil,
		"a dressed pedestal never re-styles a prompt that may be on screen")
	check(src:find("PROMPT_SLOT_ATTRIBUTE, 1", 1, true) ~= nil,
		"and they take card slot 1, beside the sell prompt's 0")
	check(src:find("Enum.KeyCode.X", 1, true) ~= nil and src:find("Enum.KeyCode.E", 1, true) ~= nil,
		"sell keeps X and the haul takes E, which are different keys on one part")

	-- AND `PromptUI` ACTUALLY READS THE NEW ONE. An attribute nobody reads is
	-- a refusal that never happens, and the failure is silent: the owner
	-- would simply be shown two cards on one key with no error anywhere.
	check(sources.PromptUI:find("Config.PROMPT_DENY_OWNER_ATTRIBUTE", 1, true) ~= nil,
		"the client refuses a snatch prompt to the person it names")
end

-- ------------------------------------------------------------
-- WHAT THE SERVICE MAY NOT DO
-- ------------------------------------------------------------
do
	local src = sources.PiggyHaulService

	-- SPEED GOES THROUGH `HeistService` AND NOWHERE ELSE. That function owns
	-- the stun, the snag, the ride, the tiptoe, the climb, the dodge and the
	-- burst as well as the carry penalty, so a `WalkSpeed` write from out here
	-- would be a second answer that loses to whichever of those fires next --
	-- and `BASE_WALK_SPEED` is the number every one of them is calibrated
	-- against.
	-- A WRITE RATHER THAN THE WORD, because the sentence explaining why this
	-- file must not touch WalkSpeed contains it -- and a check that a comment
	-- trips is a check nobody can keep.
	check(src:find("WalkSpeed%s*=") == nil,
		"the haul never writes WalkSpeed itself")
	check(src:find("HeistService.haulChanged", 1, true) ~= nil,
		"it tells HeistService instead")

	-- THE POSE IS A FUNCTION OF THE MODEL'S PRESENCE, so the carried piggy
	-- has to be named what `CarryPose` looks for. A literal here would be the
	-- second copy of a name with no compiler behind it -- the failure that
	-- left four shop vault prompts dead for a whole session.
	check(src:find("Config.LOOT_MODEL_NAME", 1, true) ~= nil,
		"the carried model is named through the constant CarryPose reads")
	check(src:find("CarryPose.HOLD", 1, true) ~= nil,
		"and it sits where the measured hands are, rather than at a number chosen here")

	-- EVERY ENDING THAT IS NOT A SECURE GOES HOME. A nab, a dog, an arrest, a
	-- death and a disconnect are five ways to stop being a thief and one way
	-- for a piggy to be deleted from the game, so they share one function.
	local _, homes = src:gsub("returnHome%(", "")
	check(homes >= 5, ("every losing ending returns the piggy (%d sites)"):format(homes))

	-- A STOLEN ONE CANNOT BE PRESSED INTO PLACE. A prompt is instant, so a
	-- thief who could press one on arrival would never be catchable on their
	-- own lawn -- which would delete the five seconds the whole feature turns
	-- on.
	check(src:find("if not haul.own then", 1, true) ~= nil,
		"the place prompt refuses a piggy that is not yours yet")
	check(src:find("secureSeconds", 1, true) ~= nil,
		"and names the dwell that is")

	-- AND THE SNATCH ASKS THE SHIELD THROUGH THE ONE FUNCTION THAT OWNS IT.
	-- A second answer to "is this player protected" is the second
	-- implementation that drifts, and the one that drifts is always the one
	-- nobody is testing.
	check(src:find("HeistService.whyCannotSnatch", 1, true) ~= nil,
		"a snatch asks HeistService whether the victim is shielded")
	check(src:find("HeistService.dropShield", 1, true) ~= nil,
		"and taking somebody's piggy ends your own protection, exactly as cracking their pig does")
end

-- ------------------------------------------------------------
-- THE SWAP: THE ONLY WAY A PIGGY LEAVES THE TILL
-- ------------------------------------------------------------
--
-- Designer decision 2026-09-22: "a pig must be on the bank till at all
-- times so in order to move one off the player will have to swap another
-- piggy onto it by carrying one of their other piggies or a freshly caught
-- one up to the till and holding the swap button."
--
-- THE REAL SERVICE IS RUN, against doubles for everything it requires, which
-- is the shape `tests/luau/handoff` uses for HeistService and for the same
-- reason: the books are the one thing nothing on screen can say, and the
-- swap moves a count that no `Config` door moves for it (`placePiggy` and
-- `removePiggy` are slot-bound; the till is slot 0).
do
	local src = sources.PiggyHaulService
	local function inst(class)
		local o = { ClassName = class, Name = class, attributes = {} }
		function o:SetAttribute(k, v) self.attributes[k] = v end
		function o:GetAttribute(k) return self.attributes[k] end
		function o:Destroy() self.Parent = nil; self.destroyed = true end
		o.Triggered = { Connect = function() return {} end }
		return o
	end
	local vm = {}
	local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vm) end
	vm.__sub = function(a, b)
		return { Magnitude = math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2 + (a.Z - b.Z) ^ 2) }
	end
	local frame = setmetatable({}, { __mul = function(a) return a end })
	local built = {}
	local modules = {
		Config = Config,
		Remotes = { get = function(name)
			return { FireClient = function(_, p, msg, kind)
				p.notes = p.notes or {}
				table.insert(p.notes, { name = name, msg = msg, kind = kind })
			end }
		end },
		PiggyModel = {
			build = function(key)
				local body = inst("Part"); body.Position = vec(0, 0, 0)
				local m = inst("Model"); m.PrimaryPart = body; m.key = key
				function m:PivotTo() end
				table.insert(built, m)
				return m
			end,
			bodyOf = function(m) return m.PrimaryPart end,
		},
		CarryPose = { HOLD = frame },
		Theme = { FONT = "F", PAPER = "p", INK = "i", GOLD = "g" },
		DataService = { get = function(p) return p.data end, save = function() end },
		PlotService = {
			setSwapOffer = function(plot, key) plot.offer = key; plot.offers = (plot.offers or 0) + 1 end,
			getAll = function() return {} end, getPlot = function() return nil end,
			yardContaining = function() return nil end,
			setPiggySlots = function() end, setPiggyBuffers = function() end,
		},
		ResidentService = { get = function(plot) return plot.resident end },
		CosmeticsService = { applyToPlot = function(p) p.repaints = (p.repaints or 0) + 1 end },
		EconomyService = { push = function() end },
		HeistService = {
			isCarrying = function(p) return p.coins == true end,
			haulChanged = function(p) p.speedChanges = (p.speedChanges or 0) + 1 end,
			whyCannotSnatch = function() return nil end,
			dropShield = function() end, isDodgeImmune = function() return false end,
		},
		SocialService = { recordSteal = function() end },
	}
	local names = setmetatable({}, { __index = function(_, k) return k end })
	local env = setmetatable({
		game = { GetService = function(_, name)
			return if name == "ReplicatedStorage" then { Shared = names } else {}
		end },
		require = function(n) return assert(modules[n], tostring(n)) end,
		script = { Parent = names },
		Instance = { new = inst },
		UDim2 = { new = function() return {} end, fromScale = function() return {} end },
		Vector3 = { new = vec },
		os = { clock = function() return 100 end },
		warn = function() end,
	}, { __index = getfenv() })
	local run = assert(loadstring(src, "PiggyHaulService"))
	setfenv(run, env)
	local H = run()

	local D = Config.DEFAULT_SKIN
	local X = "bronze"
	check(Config.SKINS[X] ~= nil and X ~= D, "the test piggy is a real skin that is not the starter")
	local serial = 0
	local function actor(coins)
		serial += 1
		local root = { Position = vec(0, 0, 0), CFrame = frame }
		local humanoid = { Health = 100 }
		local char = { attributes = {} }
		function char:SetAttribute(k, v) self.attributes[k] = v end
		function char:GetAttribute(k) return self.attributes[k] end
		function char:FindFirstChild(n) return if n == "HumanoidRootPart" then root else nil end
		function char:FindFirstChildOfClass(_) return humanoid end
		local p = { UserId = serial, DisplayName = "P" .. serial, Parent = true, Character = char, coins = coins }
		p.data = { incomeLevel = 0, rebirths = 0, cosmetics = { owned = {}, skin = D },
			piggies = { owned = { [D] = 1, [X] = 1 }, till = D,
				slots = { { key = X }, {}, {}, {}, {}, {} } } }
		return p
	end
	local function plotFor(p)
		local plot = { owner = p, index = serial, pedestals = {},
			piggy = { body = { Position = vec(0, 0, 0) }, swapPrompt = inst("ProximityPrompt") } }
		for i = 1, N do plot.pedestals[i] = { plinth = { Position = vec(0, 0, 0) } } end
		return plot
	end
	local function ownedTotal(p)
		local n = 0
		for _, c in pairs(p.data.piggies.owned) do n += c end
		return n
	end
	local function lastNote(p)
		return p.notes and p.notes[#p.notes] or nil
	end

	-- THE HAPPY PATH: take, swap, place, and the books balance at every step.
	local p = actor(false)
	local plot = plotFor(p)
	check(ownedTotal(p) == 2, "two copies to start: the starter on the till and one on a plinth")
	H.take(p, plot, 1)
	check(H.isHauling(p), "take lifts the plinth piggy into the owner's arms")
	check(p.data.piggies.owned[X] == nil and ownedTotal(p) == 1,
		"a piggy in your arms stands nowhere, so the count comes down with it")
	check(plot.offer == X, "and the bank offers to take exactly the piggy being carried")
	check(p.data.piggies.till == D, "the till is untouched by a take")

	H.swap(p, plot)
	check(p.data.piggies.till == X, "swap puts the carried key on the till")
	check(H.isHauling(p), "and the owner is still carrying")
	check(built[#built].key == D, "what they now carry is the old till piggy, built through the same attach")
	check(p.data.piggies.owned[X] == 1 and p.data.piggies.owned[D] == nil and ownedTotal(p) == 1,
		"the incoming copy is counted on the till and the outgoing copy is uncounted in the arms")
	check(plot.offer == D, "the bank's offer now names the piggy that came off it")
	check(p.repaints and p.repaints >= 2, "the plot was repainted, which is what re-dresses and re-rates the bank")
	local note = lastNote(p)
	check(note and note.kind == "good" and note.msg:find(Config.getSkin(X).name, 1, true) ~= nil,
		"the swap is announced with the piggy that went on")

	H.place(p, plot, 1)
	check(not H.isHauling(p), "placing the old till piggy empties the hands")
	check(p.data.piggies.slots[1].key == D and p.data.piggies.till == X,
		"the old till piggy stands on the plinth the new one came off")
	check(ownedTotal(p) == 2 and p.data.piggies.owned[X] == 1 and p.data.piggies.owned[D] == 1,
		"owned matches standing again: two copies, one per placement")
	check(plot.offer == nil, "and the bank stops offering once the hands are empty")

	-- A PIG IS ON THE TILL AT ALL TIMES: there is no take-from-till verb.
	check(src:find("PiggyHaulService.takeTill", 1, true) == nil
		and src:find("piggies.till = nil", 1, true) == nil,
		"nothing in the service ever clears the till")
	check(countPlain(src, "piggies.till = incoming") == 1,
		"and the swap is the one writer of the till key")

	-- REFUSED OUT LOUD: empty hands.
	local q = actor(false)
	local plotQ = plotFor(q)
	H.swap(q, plotQ)
	note = lastNote(q)
	check(note and note.kind == "warn" and note.msg:find("not carrying", 1, true) ~= nil,
		"swapping with empty hands is refused by name")
	check(q.data.piggies.till == D and ownedTotal(q) == 2, "and nothing moved")

	-- REFUSED OUT LOUD: a bag of coins is not a piggy.
	q.coins = true
	H.swap(q, plotQ)
	note = lastNote(q)
	check(note and note.kind == "warn" and note.msg:find("coins", 1, true) ~= nil,
		"a coin carry cannot go on the till")
	check(q.data.piggies.till == D, "and the till is untouched")
	q.coins = false

	-- REFUSED OUT LOUD: somebody else's bank.
	H.take(q, plotQ, 1)
	check(H.isHauling(q), "q is carrying their own piggy")
	H.swap(q, plot)
	note = lastNote(q)
	check(note and note.kind == "warn" and note.msg:find("not your", 1, true) ~= nil,
		"a swap on another player's plot is refused by name")
	check(plot.owner.data.piggies.till == X and q.data.piggies.till == D and H.isHauling(q),
		"neither till moved and q still holds their piggy")
	-- Residents are never swapped: a plot with no owner is refused the same way.
	local resident = { piggies = { owned = { [X] = 1 }, till = D, slots = { { key = X }, {}, {}, {}, {}, {} } } }
	local plotR = { owner = nil, index = 99, resident = resident, pedestals = {},
		piggy = { body = { Position = vec(0, 0, 0) } } }
	for i = 1, N do plotR.pedestals[i] = { plinth = { Position = vec(0, 0, 0) } } end
	H.swap(q, plotR)
	check(lastNote(q).kind == "warn" and resident.piggies.till == D, "a resident's till is never swapped")

	-- REFUSED OUT LOUD: a stolen piggy has to be secured first, exactly as
	-- the place prompt refuses it, or the swap would be a snatch that can
	-- never be interrupted on the thief's own lawn.
	local t = actor(false)
	local plotT = plotFor(t)
	H.snatch(t, plotR, 1)
	check(H.isHauling(t) and t.Character:GetAttribute(Config.PIGGY_HAUL_ATTRIBUTE) == "stolen",
		"t snatched the neighbour's piggy")
	check(plotT.offer == nil, "a stolen haul never lights the bank's swap prompt")
	H.swap(t, plotT)
	note = lastNote(t)
	check(note and note.kind == "warn"
		and note.msg:find(tostring(Config.PIGGY_HAUL.secureSeconds), 1, true) ~= nil,
		"a stolen piggy cannot be swapped onto the till before it is secured")
	check(t.data.piggies.till == D and H.isHauling(t), "and nothing moved")

	-- THE PROMPT ITSELF, read off the sources: on the bank's Body, owner-only,
	-- on its own card slot, born refused, and only ever enabled by
	-- `PlotService.setSwapOffer`.
	local bank = sources.PiggyBank
	check(countPlain(bank, 'prompt.Name = "SwapPrompt"') == 1, "the bank builds a SwapPrompt")
	check(countPlain(bank, 'Config.setPromptKind(prompt, "swap")') == 1, "styled as the swap kind")
	check(bank:find('prompt.Name = "SwapPrompt".-PROMPT_SLOT_ATTRIBUTE, 2%)') ~= nil,
		"on card slot 2, clear of the steal (0) and smash (1) cards")
	check(bank:find('prompt.Name = "SwapPrompt".-prompt.Enabled = false.-SetAttribute%(Config.PROMPT_OWNER_ATTRIBUTE, 0%)') ~= nil,
		"born disabled and attributed to nobody, in that order")
	check(countPlain(bank, "buildSwapPrompt(body)") == 1 and countPlain(bank, "swapPrompt = swapPrompt") == 1,
		"built on the bank only: the shop vault gets none")
	check(bank:find("swapHold", 1, true) ~= nil, "and its hold is Config.PIGGY_HAUL.swapHold")
	local plotSrc = sources.PlotService
	check(countPlain(plotSrc, "swapPrompt:SetAttribute(Config.PROMPT_OWNER_ATTRIBUTE, ownerId)") == 1,
		"setPiggySlots writes the swap prompt's owner beside the six plinths'")
	check(plotSrc:find("function PlotService.setSwapOffer", 1, true) ~= nil
		and countPlain(plotSrc, "swapPrompt.Enabled = ") == 2,
		"setSwapOffer owns Enabled (plus the unowned-plot off switch)")
	check(plotSrc:find("local offered = plot.owner ~= nil and key ~= nil", 1, true) ~= nil,
		"and an unowned plot never offers")
	check(countPlain(src, "PlotService.setSwapOffer(") >= 3,
		"the haul service publishes the offer on take, on every ending, and on swap")
	check(src:find("swapPrompt.Triggered:Connect", 1, true) ~= nil, "and wires the prompt at start")
	check(countPlain(sources.ClientMain, "swapPrompt.Enabled") == 0
		and countPlain(sources.ClientMain, "SwapPrompt") == 0,
		"the client never writes the swap prompt: PromptUI's owner rule is its whole client side")
	check(Config.PROMPTS.swap ~= nil and Config.PROMPTS.swap.verb == "SWAP", "the card says SWAP")
	check(Config.PIGGY_HAUL.swapHold > Config.PIGGY_HAUL.placeHold
		and Config.PIGGY_HAUL.swapHold < Config.PIGGY_HAUL.snatchHold,
		"the swap hold sits between putting one down and taking somebody else's")

	-- AND THE BANK WEARS THE TILL. `applyToPlot` dresses from the till key
	-- and mirrors it into the wardrobe field, so the rate, the pig and the
	-- sign are one key; the bag's old wear-a-skin tap refuses out loud.
	local cos = sources.CosmeticsService
	check(countPlain(cos, "local skinKey = Config.piggyKeyAt(data, 0)") == 1,
		"the bank is dressed from the till key")
	check(countPlain(cos, "cosmetics.skin = skinKey") == 1, "and the wardrobe field mirrors it")
	check(countPlain(cos, "data.cosmetics.skin = key") == 0,
		"equipSkin no longer writes the wardrobe field behind the till's back")
	check(cos:find("hold SWAP", 1, true) ~= nil, "it names the swap instead")
end

-- ------------------------------------------------------------
-- WHAT A NEIGHBOUR KEEPS ON THEIR PLINTHS
-- ------------------------------------------------------------
do
	local spec = Config.RESIDENTS

	-- NON-ZERO, because zero is a broken feature rather than a safe default:
	-- sixty empty plinths is an acquisition route with nothing on it, and a
	-- snatch prompt that never appears anywhere is indistinguishable from the
	-- snatch not being built.
	check(spec.piggyCount > 0, "a neighbour keeps something on their lawn")
	check(spec.piggyCount <= Config.PIGGY_LAWN_SLOT_COUNT,
		"and never more than there are plinths to stand them on")
	check(spec.piggyCount < Config.PIGGY_LAWN_SLOT_COUNT,
		"and leaves room, so a picked-over lawn reads as picked over")

	-- CAPPED RATHER THAN SCALED, which is `docs/PIGGY-PACKS-PLAN.md` §10e's
	-- second requirement. The residents' own level offset is downward-only on
	-- the rule that "residents richer than the thief are a faucet, full
	-- stop"; a lawn that seeded the top tier is that faucet one level up,
	-- with no audit in existence that would catch it.
	local cap = Config.rarityRank(spec.piggyTopRarity)
	check(cap > 0, "the cap names a real tier")
	check(cap < Config.rarityRank("legendary"),
		"and it is below the top of the ladder")

	-- AND THE DRAW ACTUALLY HONOURS IT. Re-run here against the same
	-- catalogue and the same exclusions the service uses, because the cap is
	-- a number in one file and the filter is a line in another.
	local drawable, over = 0, 0
	for _, skin in pairs(Config.SKINS) do
		if not Config.isEarnedElsewhere(skin) and skin.aura == nil then
			if Config.rarityRank(Config.rarityOf(skin)) <= cap then
				drawable += 1
			else
				over += 1
			end
		end
	end
	check(drawable >= spec.piggyCount,
		("there are enough piggies under the cap to stock a lawn (%d)"):format(drawable))
	check(over > 0,
		"and the cap is holding something back rather than admitting the whole catalogue")

	-- THE SAME TWO EXCLUSIONS THE NEIGHBOUR'S OWN PIG TAKES. A pass skin on
	-- scenery advertises a paid exclusive; an aura is particles thrown off a
	-- body rather than colour on one, which is the "variety that LIES"
	-- failure this project records for gardens advertising wealth that is not
	-- there.
	local src = sources.ResidentService
	check(src:find("Config.isEarnedElsewhere(spec) and spec.aura == nil\r?\n?%s*and Config.rarityRank") ~= nil
		or src:find("and Config.rarityRank(Config.rarityOf(spec)) <= cap", 1, true) ~= nil,
		"the lawn draw excludes earned-elsewhere and aura'd skins and caps the tier")
	check(src:find("Config.addPiggy(resident", 1, true) ~= nil,
		"and it seeds through the one door every other source of a piggy uses")
end

-- ------------------------------------------------------------
-- WHICH WAY A DISPLAY LOOKS, AND THE MEASUREMENT THAT SETTLED IT
-- ------------------------------------------------------------
--
-- Reported as "some piggies are slightly tilted inwards", and both of those
-- words are arithmetic. `Config.piggyPedestalYaw` aims a display at the till
-- at the exact angle to it; everything it stands on is SQUARE to the plot,
-- because the pad has to be (`piggyPadYaw` quantises to a quarter turn) and
-- the plinth follows the pad. So the display sat askew on its own plinth by
-- the difference between those two, which is nothing like uniform.
local worstOff = 0
for i = 1, N do
	local inward = math.deg(Config.piggyPedestalYaw(i))
	local square = math.deg(Config.piggyPadYaw(i))
	local off = math.abs(inward - square)
	worstOff = math.max(worstOff, off)
	-- THE PAD IS SQUARE AND THE INWARD ANGLE IS NOT, which is the whole of
	-- why one of them could not be used for both. A quarter turn keeps the
	-- pad's 8.4-stud width off the 10-stud row pitch; the true angle lands
	-- it diagonally across it.
	check(math.abs(square % 90) < 0.0001,
		("the pad's yaw is square to the plot: slot %d"):format(i))
	check(off > 3.0,
		("and the inward angle is not, so a display seated on it reads askew: slot %d off %.1f"):format(i, off))
end
-- PINNED, because the SPREAD is the reason this read as a fault rather than
-- as an arrangement: the middle pair are within five degrees of square and
-- look straight, so it was "some" rather than all, and the worst is 26
-- degrees, which reads as a prop knocked out of line. A layout change that
-- made these agree would make the reversal below moot, and nothing else
-- would say so.
check(math.abs(worstOff - 25.64) < 0.05,
	("the worst display-against-plinth offset is 25.6 degrees, measured (%.2f)"):format(worstOff))
check(math.abs(math.deg(Config.piggyPedestalYaw(3)) - 85.43) < 0.05,
	"and the middle row was only 4.6 degrees off, which is why it looked straight")
-- WHICH IS WHY NOTHING IS SEATED ON IT: the quantiser below turns that spread
-- of 64/85/108 into one angle per column, so all three rows land parallel.
check(Config.piggyPadYaw(1) == Config.piggyPadYaw(3)
	and Config.piggyPadYaw(3) == Config.piggyPadYaw(5),
	"the quarter turn is the same down a whole column, where the bearing was not")

-- SO BOTH THE PAD AND THE PIGGY TAKE THE QUANTISED QUARTER TURN, WHICH IS THE
-- ONLY THING THAT IS SQUARE AND INWARD AT ONCE. Designer call, stated as the
-- result: "all turned 90 degrees on the right and the left side turned 270
-- degrees so they are all facing inwards".
--
-- ASSERTED AS THE FACING DIRECTION RATHER THAN AS AN ANGLE, because an angle
-- has four spellings and a direction has one. A +Z-authored model turned by
-- yaw faces (sin yaw, cos yaw), and inward means that vector points back at
-- the plot's own centre line -- so this is the same statement the designer
-- made, in the form that cannot be satisfied by 90 degrees the wrong way.
for i = 1, N do
	local slot = Config.PIGGY_LAWN_SLOTS[i]
	local yaw = Config.piggyPadYaw(i)
	local faceX = math.sin(yaw)
	check(math.abs(math.abs(faceX) - 1) < 0.0001,
		("a display faces squarely along X: slot %d"):format(i))
	-- INWARD: the facing X and the slot's own X have opposite signs, so the
	-- left column looks right and the right column looks left. Sign rather
	-- than a pinned +90/-90 pair, so this survives a slot moving column.
	check(faceX * slot.offset.X < 0,
		("and it faces the middle of the lawn rather than the fence: slot %d"):format(i))
end
-- AND THE TWO NUMBERS THE DESIGNER NAMED, PINNED. `x -25` is the viewer's
-- RIGHT looking in from the street, because the street is plot-local +Z.
check(math.abs(math.deg(Config.piggyPadYaw(1)) - 90) < 0.0001,
	"the x -25 column -- the viewer's right -- is turned 90 degrees")
check(math.abs(math.deg(Config.piggyPadYaw(2)) + 90) < 0.0001,
	"and the x +25 column is turned 270")

-- THE SEATING IS A SOURCE GUARD because a `PivotTo` on a live model is not
-- readable offline. What can be read is that neither the pad nor the display
-- asks for the TRUE bearing any more, and that both ask the same quantiser.
-- COUNTED AS A CALL, not as a mention: the notes still name the function they
-- stopped seating on, because a reversal that does not say what it reversed
-- is a decision nobody can re-open.
check(countPlain(pedestalSrc, "Config.piggyPedestalYaw(") == 0,
	"nothing is seated on the true bearing to the till")
check(countPlain(pedestalSrc, "Config.piggyPadYaw(index)") == 1,
	"the pad takes the quarter turn")
check(countPlain(pedestalSrc, "Config.piggyPadYaw(refs.index)") == 1,
	"and the display takes the same one, so the animal cannot face off its own button")
check(Config.piggyPedestalYaw(99) == 0,
	"an unknown slot asks for no turn rather than throwing")

-- ------------------------------------------------------------
-- A GREEN BUTTON MEANS STEPPING ON IT WILL WORK
-- ------------------------------------------------------------
--
-- Reported as "walking over the button the piggies do the animation, then if
-- you quickly walk over them again when it is green they do not". Two numbers
-- that had never been multiplied: `setBuffered` called a pad ready at one
-- whole coin and a buffer refills continuously, so a pad went back to GREEN
-- within a tick of being emptied -- while the touch cooldown went on refusing
-- it. Green meant nothing for that second, which is the silent-refusal
-- failure wearing a button.
local padSpec = Config.PIGGY_PEDESTAL.pad
check(padSpec.reaction > 0, "the collect reaction has a length")
check(padSpec.cooldown == padSpec.reaction,
	"and the pad's cooldown IS that length, so the red window is the performance")
-- ONE NUMBER, THREE READERS: the clip, the debounce and the light. The clip
-- is in a different file, which is where a second copy would live.
check(countPlain(sources.PiggyIdle, "Config.PIGGY_PEDESTAL.pad.reaction") == 1,
	"the collect clip reads its length from the pad rather than keeping a copy")
check(countPlain(sources.PiggyIdle, "length = 1.55") == 0,
	"and the literal it used to carry is gone")

-- THE HOP IS KEYED TO A COUNTER ON THE PAD, NEVER TO `Sound.Played`. A
-- replicated `Play()` on a clip that is still running changes no property, so
-- `Played` on a client fired once per 4.1s clip however many collects landed
-- inside it -- measured live as three server plays arriving as two `Played`s.
-- Reported as the collect animation "only firing after 30+ seconds".
check(countPlain(sources.PiggyIdle, ".Played:Connect") == 0,
	"PiggyIdle no longer listens to Sound.Played")
check(countPlain(sources.PiggyIdle, "GetAttributeChangedSignal(PiggyPedestal.COLLECT_ATTRIBUTE)") == 1,
	"and hops off the pad's collect counter instead")
check(countPlain(sources.PiggyPedestal, "PiggyPedestal.COLLECT_ATTRIBUTE = ") == 1,
	"the attribute name is written once, in PiggyPedestal")
check(countPlain(sources.PiggyPedestal, "SetAttribute(PiggyPedestal.COLLECT_ATTRIBUTE") == 1,
	"and playPadCollect is the one writer of the counter")
check(countPlain(sources.PiggyIdle, "\"PadCollects\"") == 0,
	"PiggyIdle carries no second copy of the attribute name")

-- THE PREDICATE, RUN RATHER THAN READ. Extracted and executed against a
-- stubbed clock, which is the shape `tests/luau/shopdrops` already uses for
-- `rollShopDrop`: `PiggyPedestal` requires PiggyModel and Theme and cannot be
-- loaded here, but one function body can.
local readyBody = assert(pedestalSrc:match(
	"function PiggyPedestal%.padReady%((.-)\nend\n"),
	"padReady is still a standalone function")
local clock = 1000
local padEnv = setmetatable({
	Config = Config,
	Workspace = { GetServerTimeNow = function() return clock end },
}, {__index = getfenv()})
local loadReady = assert(loadstring("return function(" .. readyBody .. "\nend", "padReady"))
setfenv(loadReady, padEnv)
local padReady = loadReady()

check(padReady(0, nil) == false, "an empty pad is never ready")
check(padReady(0, clock - 99) == false, "and stays unready however long ago it fired")
check(padReady(5, nil) == true, "a pad that has never fired and holds coins is ready")
-- THE BUG ITSELF: a coin has already accrued and the pad cannot fire.
check(padReady(5, clock) == false,
	"the instant after a collect the face is NOT ready, though a coin is already waiting")
check(padReady(5, clock - padSpec.cooldown / 2) == false,
	"half way through the reaction it is still not ready")
-- SAMPLED JUST PAST THE EDGE RATHER THAN ON IT. `clock - cooldown` read back
-- as 1.5499999999999545 of elapsed time -- the boundary is not representable,
-- and asserting on it tests the float rather than the rule. The rule is that
-- the window closes: dark throughout it, lit after.
check(padReady(5, clock - padSpec.cooldown - 0.001) == true,
	"and it lights again as soon as the window has closed")
check(padReady(5, clock - padSpec.cooldown - 10) == true, "and stays lit after that")
-- A STAMP FROM THE FUTURE IS IGNORED RATHER THAN HOLDING A PAD DARK FOREVER.
-- `GetServerTimeNow` is a shared clock, but a clock correction must not be
-- able to switch a button off for the rest of a session -- the `busyUntil`
-- failure, where one field read in two directions made a 30,000-coin bone
-- buy nothing at all.
check(padReady(5, clock + 60) == true, "a stamp in the future cannot hold a pad dark")

-- THERE WAS A THIRD TERM, THE ROOM IN THE OWNER'S PIG, and it is gone with
-- the pig's ceiling. It existed because a full pig refused every collect on
-- the lawn (measured: coins pinned at 73,789, six pads GREEN, 20.9K waiting
-- on each, every collect refused). Nothing refuses a collect now, so the
-- term came out WITH the refusal it mirrored -- left in, it went negative
-- the moment coins passed the old cap and darkened every pad on every lawn
-- while every collect worked. A pad reads what is waiting and the reaction
-- window, and nothing else may darken it.
check(padReady(5, nil, 0) == true, "no room term: a third argument cannot darken a pad")
check(padReady(5, nil, -100) == true, "not even a negative one")
check(padReady(0, nil, 500) == false, "an empty pad is still dark")
check(padReady(5, clock, 500) == false, "and the reaction window still holds")
check(countPlain(plotSrc, "Config.getCapacity") == 0,
	"setPiggyBuffers derives no room: there is no capacity to derive it from")
check(countPlain(plotSrc, "setBuffered(pedestal, amount)") == 1,
	"the pedestals are handed the figure alone")
check(countPlain(plotSrc, "collectPadFiredAt)") == 0,
	"and the till has no pad to be handed one (it drips, 2026-09-22)")

-- EVERY PAD GOES THROUGH IT, which is what stops six pedestals disagreeing
-- about what green means. The till's face used to be painted by a second
-- copy of `whole > 0` in PlotService; the till has no face now at all.
check(countPlain(pedestalSrc, "PiggyPedestal.padReady(whole, refs.padFiredAt)") == 1,
	"the pedestals' face reads the predicate")
check(countPlain(plotSrc, "PiggyPedestal.padReady(whole,") == 0,
	"and PlotService paints no till face")
check(countPlain(plotSrc, "if whole > 0 then pad.readyColour") == 0,
	"with the second copy of the readiness test gone")
-- AND EXACTLY ONE LINE IN THE FILE LIGHTS A PAD. The builder painted a fresh
-- face green and `dress` repainted it green on a piggy with an empty buffer,
-- both corrected a tick later -- the same lie as the one above, at the other
-- end of a pedestal's life. A pad is born dark and only the readout lights it.
check(countPlain(pedestalSrc, "readyColour") == 1,
	"only setBuffered lights a pad; the builder and dress leave it dark")

-- AND THE STAMP IS WRITTEN WHERE A COLLECT ACTUALLY BANKED, never on a mere
-- touch: `EconomyService`'s cooldown is per player and a visitor crossing
-- your lawn must not be able to paint your button red.
check(countPlain(plotSrc, "pedestal.padFiredAt = now") == 1,
	"playCollect stamps the pedestal pad it just emptied")
check(countPlain(plotSrc, "plot.piggy.collectPadFiredAt = now") == 0,
	"and never a till stamp: the bank has no pad (2026-09-22)")
check(countPlain(econSrc, "padFiredAt") == 0,
	"and the touch handler writes no pad stamp of its own")
-- ONE REPAINT WHEN THE WINDOW LAPSES, so the green arrives on time rather
-- than up to a whole economy tick late.
check(econSrc:find("task.delay(cool, function()", 1, true) ~= nil
	and econSrc:find("PIGGY_PEDESTAL.pad.cooldown", 1, true) ~= nil,
	"a collect schedules the repaint that lights the pad again")

-- ------------------------------------------------------------
-- A MINI LOOKS EXACTLY LIKE IT WAS BUILT, AND IT IS THE SIZE ITS ROW SAYS
-- ------------------------------------------------------------
--
-- Designer, 2026-09-21: "we need the minis to look exactly like they were
-- built not missing designs etc. also the piggies should be different sizes
-- as well ... bee and lady bugs should be smaller but lions and tigers
-- should be larger". Before this the mini on every plinth wore the row's
-- swatch colours and nothing else -- no coat, no fur, no animation, no aura
-- -- so fifteen of the nineteen animal skins were unrecognisable on the one
-- surface the collection is displayed on.
do
	local modelSrc = sources.PiggyModel
	local herdSrc = sources.HerdService
	local clientSrc = sources.ClientMain
	local bankSrc = sources.PiggyBank

	-- THE SCALE IS A BAND AROUND 1, AND AN UNKNOWN ROW IS 1.
	check(Config.PIGGY_SCALE.min < 1 and Config.PIGGY_SCALE.max > 1,
		"the display scale band brackets the size everything is solved against")
	check(Config.piggyScale(nil) == 1 and Config.piggyScale("no-such-piggy") == 1,
		"no key and an unknown key are both scale 1 rather than a throw")
	check(Config.piggyScale("classic") == 1, "a row with no scale is scale 1")
	check(Config.piggyScale("bee") < 1 and Config.piggyScale("ladybird") < 1,
		"the bee and the ladybird are smaller, as asked")
	check(Config.piggyScale("tiger") > 1 and Config.piggyScale("lion") > 1,
		"the tiger and the lion are larger, as asked")
	do
		local old = Config.SKINS.bee.scale
		Config.SKINS.bee.scale = 9
		check(Config.piggyScale("bee") == Config.PIGGY_SCALE.max,
			"an out-of-band scale is clamped to the band rather than rendered")
		Config.SKINS.bee.scale = old
	end
	-- AND THE AUDIT SAYS SO, because a clamp is silent. Provoked both ways:
	-- a row outside the band, and a band the row pitch cannot hold.
	provoke(Config.SKINS.bee, "scale", 9, "piggy.scale")
	provoke(Config.PIGGY_SCALE, "max", 5, "piggy.scale")
	-- The widest display the band allows leaves daylight on the shipped row.
	local widest = 2.2 * Config.PIGGY_PEDESTAL.display * Config.PIGGY_SCALE.max
	local pitch = math.huge
	for i = 1, N do
		for j = i + 1, N do
			local a, b = Config.PIGGY_LAWN_SLOTS[i].offset, Config.PIGGY_LAWN_SLOTS[j].offset
			if math.abs(a.X - b.X) < 0.5 then
				pitch = math.min(pitch, math.abs(a.Z - b.Z))
			end
		end
	end
	check(widest < pitch,
		("the widest display (%.2f) fits the %.1f-stud pitch"):format(widest, pitch))

	-- WHO HONOURS IT: the pedestal and the herd. WHO DOES NOT: the till and
	-- the carried mini, which are seated on pinned numbers and a measured
	-- hug (`CarryPose.HOLD`). A property of the placement, not of the skin.
	check(countPlain(pedestalSrc, "Config.piggyScale(key)") == 1,
		"the pedestal reads the row's scale")
	check(countPlain(pedestalSrc, "PiggyModel.scale(model, factor)") == 1
		and countPlain(pedestalSrc, "MINI_CENTRE_Y * factor") == 1,
		"and lifts the display by the same factor it scaled it by")
	-- A HERD MEMBER IS THE PEDESTAL'S OWN SIZE (designer, 2026-09-22), which
	-- is `display` TIMES the row's scale rather than the row's scale alone --
	-- the same skin stood 7.2 studs across on a plinth and 2.2 in the grass,
	-- a third of it, which is the two-animals-for-one-skin fault this whole
	-- block is about. One expression in HerdService, read by the scale, the
	-- lift and the formation, so the two surfaces cannot drift.
	check(countPlain(herdSrc, "Config.PIGGY_PEDESTAL.display * Config.piggyScale(key)") == 1,
		"a herd member stands at the pedestal's own factor")
	check(countPlain(herdSrc, "PiggyModel.scale(model, factor)") == 1
		and countPlain(herdSrc, "PiggyModel.MINI_CENTRE_Y * (factor - 1)") == 1,
		"and lifts by the same factor it scaled by, less the ground offset its `at` already carries")
	-- THREE SEATS NOW, NOT TWO: the build, the airborne frame of a drop or a
	-- recall, and the walking frame. Every one of them adds the lift AND the
	-- air, or a pack falls through the grass on the way down.
	check(countPlain(herdSrc, "member.lift + member.fall, 0), member.facing") == 3,
		"and all three of its seats add the lift and the fall together")
	check(countPlain(herdSrc, "Vector3.new(0, member.lift, 0)") == 0,
		"with no seat left that forgets the air")
	check(countPlain(bankSrc, "piggyScale") == 0, "the till never scales")

	-- THE MINI CARRIES EVERYTHING THE TILL DOES: key, coat, ruff, eyes, aura.
	check(countPlain(modelSrc, 'mesh:SetAttribute("SkinKey", skinKey)') == 1,
		"a mini carries its key, which is what the client animator reads")
	check(countPlain(modelSrc, "PiggyModel.applySurface(body, skin)") == 1
		and countPlain(modelSrc, "PiggyModel.applySurface(p, skin, true)") == 1,
		"the coat goes on the body and on the trim")
	check(countPlain(modelSrc, "PiggyModel.applyFur(mesh, body, skin, false)") == 1,
		"the ruff is welded on")
	check(countPlain(modelSrc, "PiggyModel.buildSkinAura(body)") == 1,
		"an aura'd skin gets its emitter")
	check(countPlain(modelSrc, "overrides[d.Name]") >= 2 and modelSrc:find("glowEyes", 1, true) ~= nil,
		"per-part colours and glowing eyes are read on the mini")
	check(modelSrc:find("task.spawn(ensureFurTemplate, setName)", 1, true) ~= nil,
		"fur sets load in prewarm rather than inside a build on the tick")
	-- AND THE LOADER IS DECLARED ABOVE THE PREWARM THAT SPAWNS IT. A `local`
	-- below its reader is a nil global, and this one shipped that way for one
	-- boot: `task.spawn(nil)` from `prewarm` took Main and the HUD down
	-- together. Twelfth instance in this project.
	check((modelSrc:find("local function ensureFurTemplate", 1, true) or math.huge)
		< (modelSrc:find("function PiggyModel.prewarm", 1, true) or 0),
		"ensureFurTemplate is declared above prewarm")
	check((modelSrc:find("local function furSetsInUse", 1, true) or math.huge)
		< (modelSrc:find("function PiggyModel.prewarm", 1, true) or 0),
		"and so is furSetsInUse")
	check(countPlain(modelSrc, "function PiggyModel.scale(") == 1
		and modelSrc:find("PiggyModel.configureAura(sa, spec, bodyScale(body))", 1, true) ~= nil,
		"a scaled mini re-derives its aura against its new body")

	-- ONE IMPLEMENTATION, TWO PIGS. PiggyBank dresses the till through the
	-- same three calls and keeps no copy of the coat or the fur.
	check(countPlain(bankSrc, "PiggyModel.applySurface(") == 1
		and countPlain(bankSrc, "PiggyModel.applyFur(") == 1
		and countPlain(bankSrc, "PiggyModel.configureAura(") == 1,
		"the till is dressed through PiggyModel")
	check(countPlain(bankSrc, "local FUR_NAME") == 0 and countPlain(bankSrc, '"SurfacePacks"') == 0,
		"and PiggyBank keeps no second copy of the coat or the fur")

	-- THE CLIENT COLLECTS THE MINIS BY NAME, and the names it watches are the
	-- names the builders write. `Trim` is on the animated list, which its own
	-- comment has demanded since the mesh pig's trim became one part.
	check(clientSrc:find("MINI_NAMES = { Display = true, HerdPiggy = true, [Config.LOOT_MODEL_NAME] = true }", 1, true) ~= nil,
		"the animator watches pedestal displays, herd members and carried piggies")
	check(clientSrc:find('"Trim", "Snout"', 1, true) ~= nil,
		"the mesh trim part is on the animated list")
	check(clientSrc:find("inst.Destroying:Once", 1, true) ~= nil,
		"and an entry leaves the list with its model")
	check(countPlain(pedestalSrc, 'model.Name = "Display"') == 1
		and countPlain(herdSrc, 'model.Name = "HerdPiggy"') == 1,
		"the two names the collector watches are the two the builders write")
end

-- ------------------------------------------------------------
-- THE EPIC TIER ON THE ANIMAL SHELF
-- ------------------------------------------------------------
--
-- Designer rule 2026-09-21: an epic has "an aura/glow/animation and either a
-- pattern or small amount of geometry". And it has to READ ON A PLINTH, so
-- every one below is built from something the mini renders.
do
	local epics = {}
	for key, skin in pairs(Config.SKINS) do
		if skin.chest == "animal" and Config.rarityOf(skin) == "epic" then
			table.insert(epics, key)
		end
	end
	table.sort(epics)
	check(#epics == 4, "four animal epics: " .. table.concat(epics, ", "))
	for _, key in ipairs(epics) do
		local skin = Config.SKINS[key]
		check(skin.aura ~= nil, key .. " glows (an aura)")
		check(skin.pattern ~= nil or skin.fx ~= nil or skin.fur ~= nil,
			key .. " has a pattern, geometry or fur, so it reads on a plinth")
		check(Config.skinAura(skin) ~= nil, key .. "'s aura passes the epic gate")
		check(skin.cost == nil, key .. " is never bought")
		check(not Config.isEarnedElsewhere(skin), key .. " is crate stock")
		check(not table.find(Config.herdSkinPool("epic"), key),
			key .. " never spawns in a herd, because herds exclude auras")
		check(Config.piggyScale(key) >= Config.PIGGY_SCALE.min, key .. " has a legal scale")
	end
	check(Config.SKINS.hedgehog.pattern.kind == "shards" and Config.SKINS.hedgehog.pattern.parting == 0,
		"the hedgehog is quills with no parting")
	check(Config.SKINS.stormstone.pattern.glowEvery == 2,
		"storm stone lights every second shard")
	-- `FUR_SETS` read directly rather than through `furMesh`, which subtracts
	-- two Vector3s and the offline stub's Vector3 is a table.
	check(Config.SKINS.lion.furSet == "lionmane" and Config.FUR_SETS.lionmane ~= nil,
		"the lion wears its own ruff set (id pending upload: see Config.FUR_SETS.lionmane)")
	check(Config.SKINS.lion.furFlat == true
		and sources.PiggyModel:find("if tier.furFlat then", 1, true) ~= nil,
		"and the ruff is one flat colour rather than the body sheet through the cylinder unwrap")
	check(Config.SKINS.peacock.fx == "peacock"
		and sources.SkinFX:find("builders.peacock = function", 1, true) ~= nil,
		"the peacock's fan has a builder")

	-- THE CRATES AUTHORISE THE TIER THEY NOW STOCK, on the og shelf's ladder.
	check(#(Config.chestPool("animal").epic or {}) == 4, "the animal crate stocks the four")
	local odds = Config.CHESTS.animal.odds
	check(odds.common == 52 and odds.rare == 32 and odds.epic == 12 and odds.legendary == 4,
		"the animal crate is back on the plan's 52/32/12/4")
	check(odds.epic == 3 * odds.legendary and Config.COMBINE.need == 3,
		"epic = 3 x legendary, which is what holds COMBINE.need at 3")
	for _, key in ipairs({ "animalrare", "animallegendary" }) do
		check(Config.CHESTS[key].odds.epic ~= nil and #(Config.chestPool(key).epic or {}) == 4,
			key .. " authorises epic and stocks it")
	end
	check(Config.CHESTS.animalrare.odds.epic == Config.CHESTS.ograre.odds.epic
		and Config.CHESTS.animallegendary.odds.epic == Config.CHESTS.oglegendary.odds.epic,
		"the animal tier crates mirror the og ones")

	-- PARTY PIGGY IS EPIC ON THE DESIGNER'S CALL, and its confetti finally
	-- passes the gate that refused it at rare.
	check(Config.rarityOf(Config.SKINS.firstday) == "epic"
		and Config.skinAura(Config.SKINS.firstday) ~= nil,
		"Party Piggy is epic and its confetti aura is built")

	local ok, problems = pcall(Config.auditRandomOutcomes)
	check(ok and #problems == 0, "the random-outcome audit is clean with the epic tier stocked"
		.. (ok and #problems > 0 and (": " .. problems[1]) or ""))
	check(#Config.auditPiggySlots() == 0, "and so is the slot audit, scale included")
end

print(("piggies: %d checks passed"):format(checks))
