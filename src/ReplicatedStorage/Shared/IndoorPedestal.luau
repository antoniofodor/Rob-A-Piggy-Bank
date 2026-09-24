--!strict
-- ============================================================
-- AN INDOOR PLACEMENT: THE COLLECT PAD AND THE PIGGY
-- ============================================================
--
-- The hall behind a player's front door holds `Config.indoorPlots(rebirths)`
-- floor plots (docs/PIGGY-COLLECTION-PLAN.md section 6), and this is what
-- stands on one. It is the SECOND BUILDER of a `PiggyPedestal.Refs` and it is
-- deliberately nothing more than that: every piece of STATE -- what is
-- standing here, what is waiting, what it earns, who may take it -- is
-- `PiggyPedestal.dress`, `.setBuffered`, `.setRate` and `.setHaul`, unchanged,
-- so there is one set of those functions for the lawn and the hall alike.
--
-- THE TILL IS THE PRECEDENT AND IT IS EXACT. `PiggyBank` builds the seventh
-- placement's pad from completely different geometry and calls
-- `PiggyPedestal.buildPadFigure`, `.buildPadSound` and `.playPadCollect` to do
-- it -- that module's own header says those are exported for precisely this
-- reason. This is the same move for the eighth onward.
--
-- WHAT IT DOES NOT BUILD IS THE PEDESTAL. A kit's pedestal is its own art,
-- cloned per unlocked station by the kit's Builder (`Pedestal_%02d` under a
-- room's `Pedestals` folder); the generic hall's is the `PlotDrum` course
-- `HouseInterior.buildPlot` stands on every plot. Either way the object is
-- already there and `plot.ground`, `plot.collect` and `plot.cash` are the
-- three frames it publishes. So this file never measures a room.
--
-- ================================================================
-- THE COLLECT IS THE LAWN'S, DOWN TO THE SLOT INDEX
-- ================================================================
--
-- One dense array of placements: slot 0 is the bank, 1..6 are the lawn, and
-- the hall is the slots after it (`HouseInterior.slotOfPlot`). So walking over
-- an indoor pad calls the SAME `EconomyService.collectPiggy` the six lawn pads
-- call, with a bigger number -- no second economy, no second prompt kind, and
-- every reader that already walks `Config.piggySlots` picks an indoor piggy up
-- for free.
--
-- ================================================================
-- NOTHING DIFFERS FROM A LAWN PEDESTAL BUT THE GEOMETRY IT STANDS ON
-- ================================================================
--
-- THE FIGURE IS PAINTED ON THE BUTTON, WHICH IS WHAT THE LAWN DOES. It stood
-- for a day on a SIGN of its own instead -- a plaque held proud of the mount
-- the kits author for a cash readout (`Pedestal.CashLabel`, on all three) --
-- and that plaque stood in front of the pedestal and covered the coin emblem
-- on it. Designer, 2026-09-23: *"the pedestals inside the hall have a placard
-- in front showing the coin value which blocks the little coin emblem on them
-- get rid of those the coin amount can be shown on the button itself just
-- like it does outside the lawn"*.
--
-- SO IT IS `PiggyPedestal.buildPadFigure` IN HERE TOO, and the reason that
-- call fits with no argument of its own is that the pad stopped being a
-- different shape: `HouseInterior.INDOOR_PAD` is 8.4 x 3.6, the lawn's own
-- button, on the designer's call the day before. A READOUT ON A SHARED
-- OBJECT IS BUILT BY WHOEVER OWNS THE OBJECT.
--
-- WHAT THE PAD WAS ALREADY DOING, IT STILL DOES: its COLOUR answers "is the
-- lap worth walking" from the far end of the hall without being read, and the
-- number answers "how much" to somebody standing on it. Two channels, one
-- part, and `PiggyPedestal.setBuffered` is still the only writer of either.
--
-- `plot.cash` IS THEREFORE A FRAME NOTHING STANDS ON, AND THAT IS
-- DELIBERATE. It is the ART's own mount -- authored in all three kits,
-- published by both room builders -- so it is a fact about the room rather
-- than about this file, and `ThemedInterior`'s assert on the `CashLabel`
-- anchor is what catches a kit that lost one. It is named here so the next
-- reader meets it on purpose rather than by grep.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HouseInterior = require(ReplicatedStorage.Shared.HouseInterior)
local PiggyPedestal = require(ReplicatedStorage.Shared.PiggyPedestal)

local IndoorPedestal = {}

-- The pad's own courses, in the hall's own vocabulary rather than the lawn's
-- stone: a dark surround with the lit face standing proud INSIDE it, which is
-- the recess rule this project turns on everywhere it wants something to read
-- as sunken -- a recess is made by standing something PROUD around the dark,
-- never by sinking the dark, because the eye takes the highest line as the
-- surface. `PIGGY_PEDESTAL.pad`'s own entry records the two wrong builds that
-- produced that rule.
local SURROUND = Color3.fromRGB(70, 74, 80)

-- ============================================================
-- BUILD
-- ============================================================

--[[
	Stand one indoor placement on `plot`.

	`parent` is a folder inside the hall model -- NEVER the model itself, which
	is what `tests/luau/interior.luau` sweeps for the entrance-to-plot
	sightline. A pad lies on the floor between a reader and the plot behind
	it, so it goes where that sweep does not mistake it for the room.

	`slot` is the SAVE slot (`HouseInterior.slotOfPlot(plot.index)`), and it is
	what every state function and the collect pad carry -- not the plot index,
	which is a fact about the hallway and means nothing to a save.
]]
function IndoorPedestal.build(parent: Instance, plot: HouseInterior.Plot,
	slot: number): PiggyPedestal.Refs
	local model = Instance.new("Model")
	model.Name = ("IndoorPedestal_%d"):format(slot)

	local size = HouseInterior.INDOOR_PAD
	-- THE LAWN'S OWN RIM AND RELIEF, READ RATHER THAN COPIED. These were
	-- three numbers of this file's own (0.3 / 0.08 / 0.12) while an indoor
	-- pad was 5.4 x 2.0 and the lawn's 0.5 rim would have eaten half of it.
	-- `INDOOR_PAD` is the lawn's 8.4 x 3.6 now, so a second set is the
	-- near-identical copy that drifts -- and it would drift where it shows
	-- least, because `buildPadFigure` typesets against the FACE and a rim of
	-- a different size is a figure of a different size.
	local padSpec = Config.PIGGY_PEDESTAL.pad

	local function padPart(name: string, extent: Vector3, y: number, colour: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = extent
		part.CFrame = plot.collect * CFrame.new(0, y + extent.Y / 2, 0)
		part.Color = colour
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		-- THE THREE FALSES ARE NOT ONE DECISION, and the first two are the
		-- reason a pad can be a button at all. A ROOM IS NOT SCENERY -- the
		-- hall's floor, walls and platforms collide, deliberately -- but a pad
		-- is a trigger laid on that floor, so it may never body-block
		-- somebody walking the lane and may never eat a query meant for the
		-- pedestal behind it. `Touched` fires on overlap without collision,
		-- which is the trampoline mat's own arrangement.
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end

	-- SUNK INTO THE FLOOR IT STANDS ON, so no face of the surround is the
	-- floor's own: anything standing on something sinks about 0.1 into it,
	-- which is the convention the low-poly house rebuild settled on after a
	-- hundred-odd coplanar pairs came from details sized to land exactly on
	-- what they stood on.
	local sink = padSpec.sink
	local surroundTop = size.Y - sink
	local pad = padPart("CollectPad", size, -sink, SURROUND)
	-- CanTouch is what makes this a button, and it is the only part here that
	-- has it: one touch source rather than two overlapping ones.
	pad.CanTouch = true
	local padFace = padPart("CollectPadFace",
		Vector3.new(size.X - padSpec.rim * 2,
			padSpec.faceSink + padSpec.faceProud,
			size.Z - padSpec.rim * 2),
		-- BORN RED, AND NOTHING BUT `setBuffered` MAY EVER LIGHT IT. A pad is
		-- a READOUT and a freshly built placement has an empty buffer, so a
		-- face painted green here is a button claiming it will pay out before
		-- anybody has asked it.
		surroundTop - padSpec.faceSink, padSpec.emptyColour)

	pad:SetAttribute(Config.PIGGY_SLOT_ATTRIBUTE, slot)
	-- THE NUMBER AND THE NOISE, BOTH THE LAWN'S OWN. `buildPadFigure` reads
	-- the face it is handed, so the figure is turned, scaled and filled by
	-- this pad's dimensions rather than by the six outside.
	--
	-- THE CANVAS'S QUARTER TURN HOLDS IN HERE FOR THE REASON IT HOLDS OUT
	-- THERE, which is worth stating because it looks as though it could not.
	-- `PIGGY_PEDESTAL.pad.labelRotation` is ONE number for every pad in the
	-- game, and it works because the reader is always on the pad's own local
	-- +Z side: outdoors a pad is sited between its piggy and the walk, and in
	-- here `plot.collect` is published with +Z at the LANE, which is the only
	-- ground anybody in this hall walks on.
	local padLabel, padAmount = PiggyPedestal.buildPadFigure(padFace)
	local padSound = PiggyPedestal.buildPadSound(pad)

	-- ------------------------------------------------------------
	-- AND THE FOUR PROMPTS, ON A STAND INSIDE THIS MODEL
	-- ------------------------------------------------------------
	--
	-- AN INVISIBLE PART OF OUR OWN RATHER THAN `plot.face`, AND THAT IS A
	-- LIFETIME DECISION. A placement is DESTROYED when its plot re-locks or
	-- when the hallway is rebuilt to hold more rooms; `plot.face` belongs to
	-- the hall and outlives both, so prompts parented there would survive
	-- their own pedestal -- four live controls at a plot with nothing standing
	-- on it, which is the silent-failure shape this project refuses above all
	-- others. On a part inside this model, `model:Destroy()` takes the whole
	-- placement with it and there is nothing to remember.
	--
	-- IT IS ALSO WHAT `PiggyPedestal.Refs.plinth` MEANS: the part the prompts
	-- hang on, the part the name label is adorned to, and the part
	-- `PiggyHaulService.reach` measures a press against. One part answering
	-- all three is what stops the prompt and the reach test disagreeing about
	-- where the pedestal is.
	--
	-- ADDRESSABLE, the same way each builder's own plot face is: a client
	-- handed this part by a prompt can say which slot and which plot it is
	-- looking at with no lookup.
	local stand = Instance.new("Part")
	stand.Name = "Stand"
	stand.Size = Vector3.new(4.0, 0.2, 4.0)
	stand.CFrame = plot.ground * CFrame.new(0, -0.1, 0)
	stand.Transparency = 1
	stand.Anchored = true
	stand.CanCollide = false
	stand.CanQuery = false
	stand.CanTouch = false
	stand.CastShadow = false
	stand:SetAttribute(Config.PIGGY_SLOT_ATTRIBUTE, slot)
	stand:SetAttribute("Plot", plot.index)
	stand:SetAttribute("Room", plot.room)
	stand.Parent = model

	-- THE SNATCH PROMPT IS BUILT AND IS UNREACHABLE TODAY, deliberately.
	-- `Config.HOUSE_DOOR.ownerOnly` means the only person who can be standing
	-- in here is the owner, and `PROMPT_DENY_OWNER_ATTRIBUTE` refuses a snatch
	-- on exactly that one screen -- so it is invisible to the only reader
	-- there is. Building it anyway is what makes plan section 5a (reaching an
	-- indoor piggy is a harder version of the same robbery) a matter of
	-- letting a visitor through the door rather than a matter of finding out
	-- which prompts a hall forgot to grow.
	local sellPrompt, takePrompt, placePrompt, snatchPrompt =
		PiggyPedestal.buildPrompts(stand)

	model.PrimaryPart = stand
	model.WorldPivot = plot.ground
	model.Parent = parent

	return {
		index = slot,
		model = model,
		plinth = stand,
		-- THE PLOT'S OWN FRAME, WHICH IS WHY `dress` NEEDED THIS AS A FIELD.
		-- A kit's is its `Pedestal.Piggy` anchor half-turned onto the model
		-- convention and the generic hall's is the top of its plot face; both
		-- already face the lane, so a piggy takes the frame as-is.
		seat = plot.ground,
		pad = pad,
		padFace = padFace,
		padAmount = padAmount,
		padLabel = padLabel,
		padSound = padSound,
		sellPrompt = sellPrompt,
		takePrompt = takePrompt,
		placePrompt = placePrompt,
		snatchPrompt = snatchPrompt,
		display = nil,
		nameLabel = nil,
		key = nil,
	}
end

return IndoorPedestal
