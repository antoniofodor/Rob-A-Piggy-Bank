--!strict
-- ============================================================
-- A LAWN PEDESTAL: A PLINTH, THE PIGGY STANDING ON IT, AND ONE PROMPT
-- ============================================================
--
-- Six of these stand on every residential plot (`Config.PIGGY_LAWN_SLOTS`).
-- Each one holds at most one piggy out of its owner's collection, that piggy
-- fills a buffer of its own, and the prompt on the plinth banks the buffer
-- into the till. See docs/PIGGY-COLLECTION-PLAN.md §3, §4a.
--
-- IN `Shared` FOR THE REASON `House`, `Decor` and `PiggyModel` ARE: the shop
-- renders the real item. A card advertising an indoor plot or a placement
-- preview has to be able to build the same object the lawn does, and a second
-- nearly-identical copy on the client is the duplicate this project keeps
-- recording as the thing that drifts.
--
-- THE PROMPT OUTLIVES THE PIGGY, WHICH IS THE ONE STRUCTURAL DECISION HERE.
-- Re-dressing a pedestal destroys and rebuilds the DISPLAY and never the
-- plinth or the prompt on it -- so the prompt keeps its identity across every
-- swap, and the per-plot `Triggered:Connect` that `EconomyService` makes once
-- at startup stays connected. Rebuilding the prompt with the piggy would mean
-- re-wiring a signal on every crate open, and the connection that gets
-- forgotten is the one that fails silently.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- For the one clock both ends of a pad cooldown may read. See `padReady`.
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)
-- For the font and the ink the two world labels are stroked in. `Theme`
-- requires nothing, so a server-side builder may take it -- which is the rule
-- the verge boards got wrong: "the UI files" is not the same set as "the files
-- that build UI".
local Theme = require(ReplicatedStorage.Shared.Theme)

local PiggyPedestal = {}

export type Refs = {
	-- The slot this pedestal is, 1..Config.PIGGY_LAWN_SLOT_COUNT. Published on
	-- the plinth as an attribute too, so a client that has only the Instance
	-- can say which slot it is looking at.
	index: number,
	model: Model,
	-- The plinth top course. The display is seated on it -- so how high a
	-- piggy stands is read from the part rather than from a second copy of
	-- the arithmetic.
	--
	-- AND IT IS WHAT THE PROMPTS HANG ON AND WHAT THE NAME LABEL IS ADORNED
	-- TO, which is why an INDOOR placement hands `buildIndoor` the plot's own
	-- face part rather than a plinth of its own: `PiggyHaulService.reach`
	-- measures a press against this, so it has to be at the pedestal.
	plinth: BasePart,
	-- WHERE THE DISPLAY STANDS: a GROUND frame, +Z the way the piggy faces.
	--
	-- A FIELD RATHER THAN AN EXPRESSION IN `dress`, and that is what lets one
	-- `dress` serve a lawn plinth and an indoor plot. It used to be the
	-- plinth's own top face turned by `piggyPadYaw` of the slot index -- which
	-- is a LAWN answer (the six slots stand at |x| 25 and face the till) and
	-- is nonsense for slot 40 in somebody's hallway. The builder that knows
	-- the geometry states it once; `dress` reads it.
	seat: CFrame,
	-- THE COLLECT BUTTON, AND IT IS A PLACE RATHER THAN A PRESS. A flat pad
	-- on the grass in front of the pedestal: you walk over it and the buffer
	-- banks. `pad` is what `Touched` fires on and `padFace` is the coloured
	-- top that says whether there is anything waiting.
	pad: BasePart,
	padFace: BasePart,
	-- WHAT THE BUTTON SAYS, held by reference rather than looked back up by
	-- name. `setBuffered` runs off the economy tick, so a `FindFirstChild` per
	-- pedestal per tick would be six lookups a tick per plot for something that
	-- cannot move -- and this project has already paid for finding a part by
	-- name twice (the castle's four `Finial`s, the kennel's two `Roof`s).
	padAmount: TextLabel,
	-- The canvas the figure is painted on. A SurfaceGui rather than a
	-- BillboardGui since the number moved onto the face -- see
	-- `buildPadFigure`, and `PIGGY_PEDESTAL.pad.labelRange` for the
	-- measurement that reversed it.
	padLabel: SurfaceGui,
	-- WHAT THE BUTTON SOUNDS LIKE. Held by reference for the same reason the
	-- figure is: a collect looks it up, and this project has paid twice for
	-- finding a part by name (the castle's four `Finial`s, the kennel's two
	-- `Roof`s). Parented to the pad, so it dies with it and is positional at
	-- the pedestal that was actually emptied.
	padSound: Sound,
	-- WHEN THIS PAD LAST BANKED SOMETHING, on `Workspace:GetServerTimeNow`.
	--
	-- WHAT IT IS FOR IS THE COLOUR, NOT THE REFUSAL. The refusal is
	-- `EconomyService`'s, keyed per player per pad, because `Touched` fires for
	-- anybody who walks over a lawn and a thief crossing yours must not be able
	-- to spend your cooldown. This is the other half: a fact about the PAD --
	-- it just paid out -- which is what its face has to report so that green
	-- never means "nothing will happen". See `PiggyPedestal.padReady`.
	--
	-- ONE STAMP PER PAD IS HONEST BECAUSE ONLY ONE PLAYER CAN EVER COLLECT
	-- FROM IT. `collectPiggy` refuses anybody but `plot.owner`, so there is no
	-- second player whose window this could disagree with -- and it is written
	-- only when a collect actually BANKED, never when one was merely attempted,
	-- so a visitor walking over it cannot paint it red.
	padFiredAt: number?,
	-- Letting this one go for coins, which is the only way a slot empties
	-- without somebody stealing it. Its own key and its own card slot -- see
	-- `build` for why both are needed.
	sellPrompt: ProximityPrompt,
	-- LIFTING A PIGGY OFF THIS PLINTH, OR PUTTING ONE DOWN ON IT.
	--
	-- THREE VERBS, THREE PROMPTS, ONE KEY, AND NEVER TWO LIVE AT ONCE -- see
	-- `build` for how that is guaranteed rather than remembered. `take` and
	-- `place` are the owner's and are separated by whether anything is
	-- standing here; `snatch` is everybody else's and exists only while there
	-- is something to take.
	takePrompt: ProximityPrompt,
	placePrompt: ProximityPrompt,
	snatchPrompt: ProximityPrompt,
	-- WHO OWNS THIS PLINTH, AND WHETHER THEY HAVE A PIGGY OF THEIR OWN IN
	-- THEIR ARMS RIGHT NOW. Both are inputs to the PLACE prompt and to
	-- nothing else -- an empty plinth is only worth offering while there is
	-- something to put on it.
	--
	-- HELD HERE RATHER THAN PASSED, because the three facts that decide that
	-- prompt arrive on three different clocks: the owner on a claim, the
	-- carry on every take, swap and ending, and `key` on every placement and
	-- sale. One painter reads all three, so whichever fires last cannot
	-- answer for the other two.
	ownerId: number?,
	carrying: boolean?,
	-- WHICH RE-PUBLISH IS THE LIVE ONE. `republish` switches every prompt off
	-- and switches the right ones back a beat later, so a SECOND republish
	-- starting inside that beat would have two timers racing to restore
	-- against two different owners -- and the loser would win, because it
	-- lands last. Stamped on the way in and checked on the way out.
	generation: number?,
	-- The piggy currently standing here, or nil for an empty slot.
	display: Model?,
	-- The piggy's NAME over its head, in its tier's colour. Rebuilt by `dress`
	-- rather than repainted, because both the word and the colour are functions
	-- of the key -- so there is no state here that can disagree with what is
	-- standing on the plinth.
	nameLabel: BillboardGui?,
	-- WHAT IT EARNS, ON THE ROW UNDER THE NAME. Held by reference for the
	-- reason `padAmount` is: `setRate` runs off the economy tick, so a
	-- `FindFirstChild` per pedestal per tick would be six lookups a tick per
	-- plot for a label that cannot move. It lives and dies with `nameLabel`,
	-- which is its parent -- so an empty pedestal has neither.
	rateText: TextLabel?,
	key: string?,
}

local STONE = Color3.fromRGB(214, 200, 176)
local STONE_DARK = Color3.fromRGB(176, 162, 140)

-- WHAT A COLLECT BUTTON SAYS, built once for the SEVEN pads on a lawn.
--
-- EXPORTED RATHER THAN COPIED, because the till has one of these too and it is
-- built in `PiggyBank` from different geometry. This project has paid for a
-- near-identical second copy often enough to have a rule about it -- the mini
-- piggy, `Decor.buildOne`, `RideSound`'s key grammar -- and the failure here
-- would be the sharpest kind: the till's figure drifting from the pedestals'
-- on the one placement every player meets in their first minute.
--
-- IT IS PAINTED ON THE FACE, NOT FLOATED OVER IT (designer call 2026-09-21).
-- `PIGGY_PEDESTAL.pad.labelRange` carries the measurement that reversed the
-- billboard this replaces, and `labelRotation` carries the one that decided
-- which way the type runs. Both were photographed rather than reasoned about.
--
-- ON THE FACE RATHER THAN THE SURROUND, so the figure sits on the coloured
-- part that is already saying ready-or-not: one object, two channels, the way
-- the guard dog's collar and its nameplate both report guard duty. It is also
-- what makes the number die with the button rather than outliving it.
--
-- `AlwaysOnTop` FALSE, deliberately, for two reasons `CLAUDE.md` records. A
-- figure that punches through the pedestal in front of it reads as a HUD
-- element rather than as part of the lawn, which is the argument the street
-- boards are built on; and the always-on-top pass is composited AFTER
-- `screen_capture` takes its frame, so a true here would make every one of
-- these invisible to every screenshot ever taken of them -- which is how six
-- systems in this game went unlooked-at for months. It is false, and that is
-- the only reason the two captures that settled this design exist.
--
-- THE TYPE IS PAPER WITH AN OPAQUE INK STROKE (designer call 2026-09-21),
-- AND THE MEASUREMENT THAT ARGUED FOR THE INVERSE IS STILL RIGHT AND STILL
-- HERE, because it is the reason the stroke has to be opaque.
--
-- It read: paper on the ready green is 1.86:1 -- a label you can see is
-- there and cannot read -- while ink on it is 8.06 and on the empty red
-- 4.26, clearing the large-type floor on both states from one colour. Every
-- figure in that sentence is a FILL against a GROUND, and it is the right
-- comparison for a label with no outline or a soft one.
--
-- AN OPAQUE OUTLINE CHANGES WHICH PAIR GOVERNS. What carries a stroked
-- glyph is the STROKE against the ground, and ink measures 8.23 on the
-- money green and 4.26 on the red -- so the fill is free to be the colour
-- cash is, and it separates from its own outline at 14.98. That is not a
-- special case invented here: it is what the piggy NAMES have always done,
-- where four tier colours measuring 1.65 to 3.74 against bare lawn are
-- legible entirely because of the ink round them.
-- THE FIGURE ITSELF, ON WHICHEVER SURFACE IT IS PAINTED ON.
--
-- SPLIT OUT FROM `buildPadFigure` SO THAT THE LOOK OF THE NUMBER AND THE
-- SURFACE IT IS PAINTED ON ARE TWO DECISIONS. Every decision about how the
-- number looks (the font, the paper fill, the opaque ink stroke, the scaling,
-- the always-on-top refusal) is here, once, so no two canvases can drift into
-- disagreeing about what a cash readout is.
--
-- THERE IS ONLY ONE CANVAS TODAY AND THERE WERE TWO FOR A DAY. A hall plot
-- painted its figure on a SIGN standing proud of the pedestal's lane-facing
-- surface, where the authored kits put a `CashLabel` mount -- and the sign
-- stood in front of the pedestal's own coin emblem and covered it (designer,
-- 2026-09-23: *"the placard in front ... blocks the little coin emblem"*).
-- The number is on the button in both places now, which is what the lawn
-- always did. The split stays, because what it costs is nothing and what it
-- buys is that the next surface cannot re-decide the typography.
--
-- `fill` IS IN THE CANVAS'S OWN UNITS and `turn` is applied after it, which
-- is what lets the pad's figure run ALONG a surface whose canvas maps its X
-- to the short axis. See `buildPadFigure`.
function PiggyPedestal.buildFigure(part: BasePart, name: string,
	face: Enum.NormalId, pixelsPerStud: number, fill: Vector2, turn: number,
	range: number): (SurfaceGui, TextLabel)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	-- PIXELS PER STUD, so the canvas is a function of the part's own size and
	-- the type scales with the object rather than with the screen. The same
	-- sizing the shop fascias, the patrol plate and the van all use.
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.AlwaysOnTop = false
	gui.MaxDistance = range
	gui.Parent = part

	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.Size = UDim2.fromScale(fill.X, fill.Y)
	amount.AnchorPoint = Vector2.new(0.5, 0.5)
	amount.Position = UDim2.fromScale(0.5, 0.5)
	amount.Rotation = turn
	amount.BackgroundTransparency = 1
	amount.Font = Theme.FONT
	amount.TextScaled = true
	amount.TextColor3 = Theme.PAPER
	-- CONTEXTUAL STROKE RATHER THAN `Theme.outline`, which sets Border mode
	-- and outlines the label's invisible RECTANGLE -- a floating box instead
	-- of a readout, which is the two-word difference `RobberMark` records.
	--
	-- AND OPAQUE, WHICH IS THE WHOLE OF WHY PAPER WORKS HERE. See the note
	-- above: paper on the ready green measures 1.82:1, which as a bare FILL is
	-- a label you can see and cannot read. A hard ink outline moves the
	-- question -- what carries the glyph is then the STROKE against the
	-- ground, 8.23 on the green and 4.26 on the empty red, both clear of the
	-- large-type floor from one colour. That is the same technique the piggy
	-- NAMES already run on: four tier colours that measure 1.65 to 3.74
	-- against bare lawn and are legible because of the ink round them.
	amount.TextStrokeColor3 = Theme.INK
	amount.TextStrokeTransparency = 0
	amount.Parent = gui
	return gui, amount
end

function PiggyPedestal.buildPadFigure(face: BasePart): (SurfaceGui, TextLabel)
	local padSpec = Config.PIGGY_PEDESTAL.pad
	-- SIZED IN THE CANVAS'S OWN UNITS, WHICH ARE TURNED A QUARTER. The canvas
	-- maps its X to the pad's SHORT axis (measured: 166 x 474 px on a face
	-- 7.4 x 2.6 studs), so a label that is to end up running ALONG the pad has
	-- to be authored wide in SHORT-AXIS widths and then rotated.
	--
	-- AND BOTH RATIOS COME OFF THE FACE THAT WAS HANDED IN RATHER THAN OFF THE
	-- SPEC, which is what the note here has claimed since it was written and
	-- is only true now. There are three pads in this game -- the six on a
	-- lawn, the till's, and one per unlocked plot in the hall -- and only the
	-- first two are built from `PIGGY_PEDESTAL.pad`. Read from the spec, an
	-- indoor face of a different shape would be typeset to the lawn's aspect
	-- and run off its own edges; read from the part, a pad that changes shape
	-- carries its figure with it and there is no second number to re-derive.
	local long = face.Size.X
	local short = face.Size.Z
	return PiggyPedestal.buildFigure(face, "PadFigure", Enum.NormalId.Top,
		padSpec.labelPixelsPerStud,
		Vector2.new((long / short) * padSpec.labelFill.X,
			(short / long) * padSpec.labelFill.Y),
		padSpec.labelRotation, padSpec.labelRange)
end

-- WHAT A COLLECT SOUNDS LIKE, built once for the SEVEN pads on a lawn.
--
-- SHARED WITH THE TILL FOR THE REASON `buildPadFigure` IS. The till's pad is
-- the seventh placement and is built by `PiggyBank` rather than here, and the
-- figure entry directly above records what happened the last time the two
-- were written separately: six pedestals carrying a number and the till --
-- the placement every player meets in their first minute -- carrying nil. A
-- second copy of six properties is the copy that drifts.
--
-- PARENTED TO THE PAD RATHER THAN THE FACE, which is a lifetime decision and
-- not a positional one -- they are half a stud apart. The pad is the part
-- `Touched` fires on and the part that outlives every owner a plot ever has
-- (`dress` rebuilds the display and never either of them), so the sound
-- cannot be destroyed by anything that redresses the pedestal.
function PiggyPedestal.buildPadSound(pad: BasePart): Sound
	local spec = Config.PIGGY_PEDESTAL.pad.sound
	local sound = Instance.new("Sound")
	sound.Name = "PadCollect"
	sound.SoundId = spec.id
	sound.Volume = spec.volume
	sound.RollOffMaxDistance = spec.distance
	-- The mode every other 3D sound in this game uses (`addSounds`), so a
	-- collect falls off the way a chime, a milestone and an alarm already do.
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = pad
	return sound
end

-- A buffer just banked. `fullness` is how full it was, 0..1 -- see
-- `Config.piggyCollectPitch`, which owns the pitch so the pedestals and the
-- till cannot disagree about what a full buffer sounds like.
--
-- TAKES THE SOUND RATHER THAN THE REFS, because the till's lives on
-- `PiggyBank`'s own Refs and there is no shape both tables share. One
-- implementation, two callers, and nothing here has to know which kind of
-- placement it is playing for.
--
-- TOLERATES NIL, for the reason every sound player in this project does:
-- `SOUNDS.SIREN` ships empty on purpose, and a pad built before its sound
-- exists must bank the coins rather than throw on the way to doing it.
--
-- AND IT COUNTS THE COLLECT ON THE PAD, BECAUSE A REPLICATED `Play()` IS NOT
-- AN EVENT ON THE CLIENT. `PiggyIdle` used to hop off `Sound.Played`, which
-- on a client only fires when `Playing` goes false -> true. The server calls
-- `Play()` on every collect, and a `Play()` on a sound that is still playing
-- changes no replicated property -- so the client saw NOTHING for the 4.1s
-- the clip runs, and a player pacing over a pad kept restarting the server's
-- clip and never saw a second hop until they stopped for longer than it.
-- Measured live: three server plays at t, t+1 and t+6 reached the client as
-- exactly two `Played`s, the middle one lost. Reported as "it only fires
-- after 30+ seconds".
--
-- A COUNTER RATHER THAN A FLAG, for the reason `DodgeRoll` and `BinExit`
-- are: a boolean set true twice fires one signal. Every client in range
-- restarts the sound and the hop itself off the change, so the second
-- collect inside a clip is heard AND seen. The server's own `Play()` stays,
-- so anything that only listens to the sound is unchanged.
PiggyPedestal.COLLECT_ATTRIBUTE = "PadCollects"

function PiggyPedestal.playPadCollect(sound: Sound?, fullness: number?)
	if not sound then
		return
	end
	sound.PlaybackSpeed = Config.piggyCollectPitch(fullness)
	local pad = sound.Parent
	if pad then
		pad:SetAttribute(PiggyPedestal.COLLECT_ATTRIBUTE,
			(tonumber(pad:GetAttribute(PiggyPedestal.COLLECT_ATTRIBUTE)) or 0) + 1)
	end
	sound:Play()
end

-- ------------------------------------------------------------
-- THE FOUR PROMPTS ON A PLINTH
-- ------------------------------------------------------------
--
-- EXPORTED FOR THE REASON `buildPadFigure` AND `buildPadSound` ARE: there is
-- a second placement builder now (`Shared/IndoorPedestal`, the hall's own
-- plots) and it needs the identical four prompts on different geometry. A
-- near-identical second copy of four prompts is four chances for an indoor
-- plinth to carry a different key, a different hold or -- worst -- a
-- different `Enabled` at birth, which is the state that poisons a client's
-- opening sweep and cannot be taken back.
--
-- `stand` IS THE PART THEY HANG ON, which is the lawn's plinth top course
-- and a hall plot's own face marker. A prompt measures to its part's centre,
-- so this is also what `PiggyHaulService.reach` measures a press against.
function PiggyPedestal.buildPrompts(stand: BasePart)
	-- THE COLLECT IS NOT IN HERE, AND THE SPLIT IS BY CONSEQUENCE.
	--
	-- Collect used to be a prompt on this same part, and the pair needed a
	-- second key and a card slot to avoid colliding. It is a floor pad now,
	-- which leaves these alone on the plinth -- so the sell goes back to card
	-- slot 0 and the two-cards-on-one-part problem goes away.
	--
	-- WHY THE TWO VERBS END UP AS DIFFERENT KINDS OF CONTROL IS THE POINT:
	-- collecting is frequent, harmless and done on the move, so it is a place
	-- you cross; selling is rare, permanent and the only thing here a
	-- nine-year-old could regret, so it stays a deliberate 1.8-second hold.
	-- Making the destructive one the easy one would have been exactly
	-- backwards.
	--
	-- `X` CHECKED AGAINST THE WHOLE MAP, not assumed free: the only two
	-- ProximityPrompt keys in the entire source are `G` (smash) and `J` (grow
	-- tree), and the client bindings are Q, B, V, R, I, Escape, F2 and the
	-- number row. X is unused by any of them. Kept rather than moved to `E`
	-- now that it is alone, because `E` is what a player brushes past
	-- everything else in this game with.
	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.Name = "SellPrompt"
	sellPrompt.ActionText = "Sell Piggy"
	sellPrompt.ObjectText = ""
	Config.setPromptKind(sellPrompt, "sell")
	sellPrompt.KeyboardKeyCode = Enum.KeyCode.X
	sellPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	sellPrompt.HoldDuration = Config.PIGGY_SELL.hold
	sellPrompt.MaxActivationDistance = Config.COLLECT_RANGE
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.Enabled = false
	sellPrompt:SetAttribute(Config.PROMPT_OWNER_ATTRIBUTE, 0)
	sellPrompt.Parent = stand

	-- ------------------------------------------------------------
	-- PICKING ONE UP, AND PUTTING ONE DOWN
	-- ------------------------------------------------------------
	--
	-- THREE VERBS, THREE PROMPTS, ONE KEY, AND EXACTLY ONE CARD PER READER.
	--
	-- The three are TAKE (your own, off your own plinth), SNATCH (somebody
	-- else's) and PLACE (one you are carrying, onto an empty slot of yours).
	-- They are three `Config.PROMPTS` kinds rather than one because a single
	-- kind would have to choose one tone for all three, and every choice is a
	-- lie two thirds of the time: red on your own lawn for tidying your own
	-- collection, or gold for robbing a child.
	--
	-- AND THREE INSTANCES RATHER THAN TWO, WHICH REVERSES THE OBVIOUS SAVING.
	-- Take and Place can never both apply -- a plinth is occupied or it is
	-- not -- and both are the OWNER'S, so one prompt could carry them with
	-- `dress` swapping its kind when the key changes. It cost more than it
	-- saved, in two ways that are both invisible until somebody plays it:
	--
	-- A CARD IS BUILT ON `PromptShown` AND NEVER REBUILT. So a kind that
	-- changes under a card already on screen leaves the card saying the old
	-- word -- and the commonest moment in this whole feature is exactly that
	-- one, a player taking their own piggy and standing there reading TAKE
	-- PIGGY over the empty plinth they just cleared.
	--
	-- AND `Enabled` WOULD NEVER TRANSITION. `PromptUI`'s rules may only ever
	-- REFUSE, so what lets a client take a refusal back is the server's own
	-- `Enabled` going false -> true again; a single prompt that is enabled in
	-- both states never does, so a client that refused it while the plot was
	-- unowned would refuse it forever. Three prompts each switch on and off
	-- as the plinth fills and empties, which re-arms the client rule for
	-- free and is the same shape the sell prompt has always had.
	--
	-- WHICH ONE A CLIENT SEES IS THE TWO OWNER RULES, AND THAT IS WHAT MAKES
	-- ONE KEY SAFE. `PROMPT_OWNER_ATTRIBUTE` refuses take and place on every
	-- screen but the owner's; `PROMPT_DENY_OWNER_ATTRIBUTE` refuses snatch on
	-- the owner's and nobody else's. The two are exact complements, and the
	-- occupancy of the plinth separates take from place on the server -- so no
	-- client ever has two of these enabled at once, which is the exclusivity
	-- guarantee `PromptUI` is built on, kept BY CONSTRUCTION rather than by
	-- anybody remembering.
	--
	-- `E` RATHER THAN A FOURTH LETTER. The whole map was checked before it
	-- was taken: the ProximityPrompt keys in this game are `E` (steal,
	-- collect, shop, post, crate, recover, hide, dig), `G` (smash), `J` (grow
	-- tree) and `X` (sell, on this same plinth), and the client bindings are
	-- Q, B, V, R, I, Escape, F2 and the number row. `E` is what a player
	-- brushes past everything else in this game with, which is exactly right
	-- for the commonest verb here and is why the destructive one next to it
	-- kept `X`.
	--
	-- NOTHING ELSE ON THIS LAWN IS ON `E` WITHIN REACH. The till's own steal,
	-- smash and collect controls sit at the plot centre, and the nearest
	-- pedestal column is |x| 25 -- more than twice `Config.STEAL_RANGE` away
	-- -- so the two-prompts-on-one-key collision that cost the shop doors
	-- nine studs of their own room cannot happen here. INDOORS THE SAME
	-- MEASUREMENT HOLDS AND IS TIGHTER: a hall plot's neighbour is 9.4 studs
	-- along its own platform (10.0 in an authored kit) against a
	-- `COLLECT_RANGE` of 9, so two plinths' cards can overlap at the midpoint
	-- and the nearer one wins -- which is the ordinary "walk up to the one
	-- you mean" case rather than a collision between two different verbs.
	--
	-- CARD SLOT 1, BESIDE THE SELL'S 0. Sell is live on exactly the states
	-- `takePrompt` is live on, so the owner genuinely sees two cards at an
	-- occupied plinth of their own -- which is the steal/smash pattern and
	-- for the same reason: what to do with this piggy is a choice, and a
	-- choice you cannot see is not one.
	local function haulPrompt(name: string, deny: boolean): ProximityPrompt
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = Config.COLLECT_RANGE
		prompt.RequiresLineOfSight = false
		Config.setPromptSlot(prompt, 1)
		-- BORN REFUSED AND BORN ATTRIBUTED TO NOBODY, which is the order this
		-- project has already paid for once. A plot is built at server startup
		-- with no owner, so a prompt that arrived enabled would be shown to
		-- every client on every resident lawn for as long as it took an owner
		-- to be written -- and `PromptUI`'s rules only ever REFUSE, so the
		-- later owner write could not have taken it back.
		prompt.Enabled = false
		prompt:SetAttribute(
			if deny then Config.PROMPT_DENY_OWNER_ATTRIBUTE else Config.PROMPT_OWNER_ATTRIBUTE,
			0)
		prompt.Parent = stand
		return prompt
	end
	local takePrompt = haulPrompt("PiggyTakePrompt", false)
	takePrompt.ActionText = "Take Piggy"
	Config.setPromptKind(takePrompt, "take")
	takePrompt.HoldDuration = Config.PIGGY_HAUL.takeHold

	local placePrompt = haulPrompt("PiggyPlacePrompt", false)
	placePrompt.ActionText = "Place Piggy"
	Config.setPromptKind(placePrompt, "place")
	placePrompt.HoldDuration = Config.PIGGY_HAUL.placeHold

	local snatchPrompt = haulPrompt("PiggySnatchPrompt", true)
	snatchPrompt.ActionText = "Snatch Piggy"
	Config.setPromptKind(snatchPrompt, "snatch")
	snatchPrompt.HoldDuration = Config.PIGGY_HAUL.snatchHold

	return sellPrompt, takePrompt, placePrompt, snatchPrompt
end

-- ------------------------------------------------------------
-- WALKING OVER A PAD, DEBOUNCED
-- ------------------------------------------------------------
--
-- `Touched` IS NOT AN ENTRY EVENT, AND THAT IS THE ENTIRE DIFFICULTY.
--
-- It fires PER CHARACTER PART and re-fires on every re-contact: measured on
-- an electric fence, fourteen parts reporting on the first contact frame and
-- eighteen fires over four seconds while standing still. That is the bug that
-- made a fence stun renew itself faster than it could expire, and it is the
-- single most expensive lesson in this codebase about this one event.
--
-- What it costs HERE is not a freeze, because a collect is idempotent -- it is
-- one crossing banking seven times. So every pad keeps a per-player stamp.
--
-- KEYED PER PLAYER PER PAD, never per player alone. Per player, walking from
-- one pedestal to the next inside the cooldown would silently skip the second
-- pad -- and the whole mechanic is a lap of them, so the pads are crossed in
-- quick succession by design.
--
-- IN `Shared` BECAUSE THERE ARE TWO PAD BUILDERS NOW. `EconomyService` wires
-- the six lawn pads and `InteriorService` wires a hall's; a second copy of
-- this debounce is the near-identical duplicate this project keeps recording,
-- on the one event it has the most scar tissue about.
--
-- THE STAMPS LIVE IN THE CLOSURE AND NOT IN A MODULE TABLE, which is the one
-- thing this does differently from the copy it replaces. A lawn pad lives for
-- the server's life, so a table keyed on it never has to give anything back;
-- an INDOOR pad is destroyed every time a hallway is rebuilt, and a strong
-- table keyed on the Instance would hold every pad this server ever built.
-- Held in the closure the stamps die with the connection, which dies with the
-- pad -- and nothing ever read that table anyway.
function PiggyPedestal.wirePad(pad: BasePart, slot: number,
	collect: (Player, number) -> ())
	local stamps: { [Player]: number } = {}
	pad.Touched:Connect(function(hit: BasePart)
		-- The character a part belongs to, and nothing else: a thrown bone or
		-- a rolling ride part touching a pad is not somebody collecting.
		local character = hit.Parent
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		local last = stamps[player]
		if last and (now - last) < Config.PIGGY_PEDESTAL.pad.cooldown then
			return
		end
		stamps[player] = now
		collect(player, slot)
	end)
end

-- ------------------------------------------------------------
-- BUILD
-- ------------------------------------------------------------

-- `ground` is the plinth's own footprint centre AT GRASS LEVEL, turned with
-- the plot -- so the far row's half turn comes in with it and nothing here
-- has to know which row it is on. Every offset below is local to that frame.
-- What the house's own art is called once it is standing on the lawn, and
-- which kit it came from. The second is what stops a Sky Castle's plinth
-- being reused for a Beach Villa: the part NAMES are identical between
-- kits, so without it a re-theme would leave one house's stump standing
-- under another's, with nothing erroring. Same reason `FUR_SET_ATTRIBUTE`
-- exists one object along.
local ART_NAME = "HouseArt"
-- WHICH WAY THE STAND FACES: THE WAY THE PIGGY ON IT DOES, WHICH IS THE SEAT'S
-- OWN ROTATION AND A HALF TURN.
--
-- Reported on 2026-09-23 as *"the stand that they sit on is what was facing
-- the wrong way"*, and measured on a live plot it was exactly that. A kit's
-- `Pedestal` is authored with its FRONT on its own -Z -- the side that faces
-- the lane in a hallway -- and everything that says so is on that side.
-- Measured in the plot's own frame with the art hung untouched:
--
--     CollectionPlate   z -3.30      the collect apron
--     CoinMedallion     z -2.82      the emblem, and the reported one
--     @CashLabel        z -2.98      the readout mount
--
-- So all three pointed at the HOUSE, which is the one direction on a lawn
-- that nobody ever looks from.
--
-- A HALF TURN WAS THE FIRST ANSWER AND IT WAS 90 DEGREES SHORT (*"it looks
-- like the stand need to be rotated 90 degrees clockwise"*). Facing the
-- street is where a stand would point if a player read it from the pavement,
-- and that is not where they read it from: the six collect pads are on the
-- INBOARD side (`Config.piggyPadYaw`) precisely because the walk between the
-- pedestals runs up the middle of the lawn. THE FACE BELONGS ON THE SIDE THE
-- ROUTE IS ON, which is the same rule the hall already keeps -- in there the
-- pedestal's front faces the lane, and the lane is the only ground anybody
-- walks on.
--
-- TAKEN FROM `refs.seat` RATHER THAN RE-DERIVED FROM THE SLOT INDEX, which is
-- the whole reason this is one line. The seat is the frame the pedestal's own
-- BUILDER published -- the inward quarter on a lawn, the plot's own frame in
-- a hallway -- so the stand inherits whatever that builder decided, the far
-- row's half turn rides on it, and a second expression that has to agree with
-- the display's facing never exists. `dress` re-deriving that turn from
-- `refs.index` is the bug `Refs.seat` was made a field to kill; deriving the
-- ART from the index would have been the same bug on the other object.
--
-- AND THE HALF TURN IS THE AUTHORING CONVENTION, NOT A DESIGN CHOICE: a seat
-- points +Z where the piggy looks and a kit points -Z where its front is, so
-- the two differ by pi by construction. If a kit ever ships authored the
-- other way round, this is the one line that changes.
local ART_TURN = CFrame.Angles(0, math.pi, 0)
local ART_KIT_ATTRIBUTE = "ArtKit"

--[[
	Dress this plinth in the house's own pedestal, or put the stone back.

	`template` is a kit's `Pedestal` Model (ThemedInterior.pedestalTemplate)
	or nil for the generic stone. Returns the seat the piggy should stand on,
	which the caller writes back to `refs.seat`.

	THE STONE COURSES STAY AND GO INVISIBLE, WHICH IS THE WHOLE TRICK. This
	file's `Refs` hands out `plinth` as a single BasePart and fourteen things
	read it -- it is the model's PrimaryPart, it carries the slot attribute
	and the slot KEY attribute, all four prompts hang off it, and the seat is
	derived from its top face. A kit's pedestal is a MODEL of eighteen parts,
	so swapping one for the other would have meant re-homing every one of
	those readers. Kept as an invisible anchor, not one of them changes.

	That is the same split the fences already use -- one invisible slab
	carries the collision and everything visible is `CanCollide` off -- and the
	same one the ladder uses, where a truss nobody can see is what is
	actually climbed and the rails are the picture.

	THE SEAT COMES FROM THE ART'S OWN `Piggy` ATTACHMENT rather than from the
	stone's top face. Every kit authors one on its `Root`, which is where
	that kit's designer decided a piggy stands on that pedestal -- a stump,
	a barrel and a crystal column are not the same height and must not be
	made so. The stone's own top is the fallback and nothing else.

	THE TURN IS THE SEAT'S OWN AND IS NEVER RE-DERIVED HERE. Only the
	POSITION moves: the rotation is lifted off the `refs.seat` this plinth's
	builder already published, so dressing a plinth cannot turn the piggy
	standing on it. Re-deriving it from the slot index through the pad
	quantiser is the reversal `tests/luau/piggies.luau` pins at the bottom of
	the seating section -- that is a LAWN answer, and nonsense for slot 40 in
	somebody's hallway, which is exactly why the seating became a field in
	the first place. Two expressions that have to agree became one that
	cannot.

	It also means a kit's own frame cannot leak in. A kit pedestal carries
	the rotation of the room it was authored in, so the art is measured for
	its POSITION alone and the piggy keeps facing whichever way its builder
	decided -- inward at the till on a lawn, and whatever the hall chose
	indoors.
]]
function PiggyPedestal.setArt(refs: Refs, template: Model?): CFrame
	local model = refs.plinth.Parent
	local worn = model and model:FindFirstChild(ART_NAME)
	local kitName = if template then template:GetFullName() else nil

	-- A DIFFERENT HOUSE'S ART IS TORN DOWN RATHER THAN RESEATED. The parts
	-- are named the same in every kit, so reusing one would be one house's
	-- geometry at another's offsets.
	if worn and worn:GetAttribute(ART_KIT_ATTRIBUTE) ~= kitName then
		worn:Destroy()
		worn = nil
	end

	local stoneSeat = refs.plinth.CFrame * CFrame.new(0, refs.plinth.Size.Y / 2, 0)

	if not template or not model then
		if worn then
			worn:Destroy()
		end
		-- THE STONE COMES BACK VISIBLE, not merely left alone: a house tier
		-- can be moved DOWN into, and a plot whose kit stopped resolving must
		-- not be six invisible plinths with piggies floating over them.
		for _, part in ipairs(model and model:GetChildren() or {}) do
			if part:IsA("BasePart") and (part.Name == "Base" or part.Name == "Plinth") then
				part.Transparency = 0
			end
		end
		return CFrame.new(stoneSeat.Position) * refs.seat.Rotation
	end

	if not worn then
		local clone = template:Clone()
		clone.Name = ART_NAME
		clone:SetAttribute(ART_KIT_ATTRIBUTE, kitName)
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				-- THE THREE FALSES THE STONE ALREADY TAKES, and for its reasons:
				-- this stands on the ground a defender defends and a thief runs
				-- across, so it may never body-block a chase or eat a raycast
				-- meant for a piggy. Kit art is authored for a room where the
				-- floor collides, so it arrives wanting all three.
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CastShadow = false
			end
		end
		clone.Parent = model
		worn = clone
	end

	-- SEATED ON THE GROUND THE STONE STANDS ON, which is the plinth's own
	-- base rather than the model's pivot: `build` sets `WorldPivot` to the
	-- ground frame, but a caller is free to move the model afterwards and
	-- the plinth is the thing every other offset here is measured from.
	local art = worn :: Model
	-- POSITION FROM THE PLINTH, ROTATION FROM THE SEAT. Those are two
	-- questions and the plinth can only answer the first: it is a square
	-- course carrying the plot's own frame, so `base` alone would stand the
	-- art facing the house. See `ART_TURN`.
	local base = refs.plinth.CFrame * CFrame.new(0, -refs.plinth.Size.Y / 2, 0)
	art:PivotTo(CFrame.new(base.Position) * refs.seat.Rotation * ART_TURN)

	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and (part.Name == "Base" or part.Name == "Plinth") then
			part.Transparency = 1
		end
	end

	local root = art.PrimaryPart
	local piggy = root and root:FindFirstChild("Piggy")
	local at = if piggy and piggy:IsA("Attachment")
		then piggy.WorldCFrame.Position
		else stoneSeat.Position
	return CFrame.new(at) * refs.seat.Rotation
end

function PiggyPedestal.build(parent: Instance, ground: CFrame, index: number): Refs
	local spec = Config.PIGGY_PEDESTAL
	local model = Instance.new("Model")
	model.Name = ("PiggyPedestal_%d"):format(index)

	local function course(name: string, size: Vector3, y: number, colour: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = ground * CFrame.new(0, y + size.Y / 2, 0)
		part.Color = colour
		-- Flat colour, never a textured material: the house pass took `Brick`,
		-- `Slate` and `Concrete` off every building in this game and a stone
		-- plinth on the lawn in front of one would be the last noisy object on
		-- the street.
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		-- THE THREE FALSES ARE NOT ONE DECISION. CanCollide and CanQuery are
		-- gameplay rules -- this stands on the ground a defender defends and a
		-- thief runs across, so it may never body-block a chase or eat a
		-- raycast meant for a piggy. CastShadow is a render cost and rides
		-- along with the other lawn geometry.
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end

	-- A wider base course under a narrower top one. Sunk 0.1 into the grass,
	-- and each course sunk 0.1 into the one under it: ANYTHING STANDING ON
	-- SOMETHING SINKS ABOUT 0.1 INTO IT, which is the convention the low-poly
	-- house rebuild settled on after a hundred-odd coplanar pairs came from
	-- details sized to land exactly on what they stood on.
	course("Base", spec.base, -0.1, STONE_DARK)
	local plinth = course("Plinth", spec.plinth, spec.base.Y - 0.2, STONE)

	plinth:SetAttribute(Config.PIGGY_SLOT_ATTRIBUTE, index)

	-- ------------------------------------------------------------
	-- THE COLLECT BUTTON IS A PLACE YOU WALK, NOT A KEY YOU PRESS
	-- ------------------------------------------------------------
	--
	-- Designer call 2026-09-21, and it is the mechanic §4a actually asked for.
	-- That section's whole argument is the "physical, walk over buttons" feel
	-- the comparison games have and this game does not -- and then the first
	-- build delivered it as a ProximityPrompt, which is a player standing
	-- still holding E seven times. A pad you cross turns the collect route
	-- into one lap of your own lawn with nothing pressed at all.
	--
	-- IT SITS IN FRONT OF THE PEDESTAL, on the inward side, so every pad lands
	-- on the inside of the lawn where the walk between them already goes.
	-- Sited on the far side it would ask the player to squeeze between the
	-- pedestal and the fence.
	--
	-- AND IT IS SQUARE TO THE PLOT, WHICH IS `piggyPadYaw` AND NOT
	-- `piggyPedestalYaw` -- and the difference is the whole of two reported
	-- bugs, one at each end. The TRUE bearing to the till depends on how far
	-- back a slot sits, so sharing it turned the three pads in a column to
	-- 103.5, 80.9 and 60.8 degrees: flat stones splayed 43 degrees apart,
	-- square to nothing. The quantised quarter turn lands every one of them
	-- flush, which is also what keeps the pad's 8.4-stud width off the 10-stud
	-- row pitch rather than diagonally across it.
	--
	-- AND `dress` TAKES THE SAME YAW, which is the second half of that story.
	-- The display was seated on the exact bearing and read as askew on its own
	-- square plinth -- so the piggy and the button in front of it are one
	-- number rather than two that have to be kept in step. Where a display
	-- LOOKS and where you STAND to collect turned out to be the same question
	-- once both of them had to be square.
	--
	-- `CanCollide` FALSE AND `CanTouch` TRUE, which is the trampoline mat's
	-- own arrangement and for the same reason: everything on this lawn is
	-- non-colliding because a defender defends on it and a thief runs across
	-- it, and `Touched` fires on overlap without collision. So the pad can
	-- never body-block a chase, and it cannot be used as cover.
	local yaw = Config.piggyPadYaw(index)
	local padSpec = spec.pad
	local padAt = ground * CFrame.Angles(0, yaw, 0)
		* CFrame.new(0, 0, spec.base.Z / 2 + padSpec.gap + padSpec.size.Z / 2)

	local function padPart(name: string, size: Vector3, y: number, colour: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = padAt * CFrame.new(0, y + size.Y / 2, 0)
		part.Color = colour
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end

	-- A SURROUND AND A FACE, because one flat slab on grass is a painted
	-- rectangle rather than a button. The surround stands proud and the face
	-- sits INSIDE it, which is the recess rule this project already turns on
	-- everywhere it wants something to read as sunken: a recess is made by
	-- standing something proud AROUND the dark, never by sinking the dark,
	-- because the eye takes the highest line as the surface.
	--
	-- AND THE WORD "INSIDE" IS WHAT GOT THIS WRONG TWICE. Flush, the face and
	-- the surround shared a top plane and z-fought across the whole face --
	-- reported as the buttons clipping through the floor. Sunk BELOW the
	-- surround's top, they stopped fighting and the face went out of sight
	-- altogether, because a surround is a solid slab and there is nothing
	-- hollow for a face to sit down in -- reported as the buttons being
	-- invisible. Nothing here can be DUG; that is the moat's own rule.
	--
	-- SO THE FACE IS THE HIGHEST COURSE and the surround shows as a border
	-- around it. It bites `faceSink` into the surround, which makes their
	-- shared plane a BUTT JOINT rather than a coplanar pair, and stands
	-- `faceProud` above it. Its thickness is the sum of those two, so there is
	-- no third number to set inconsistently. See `PIGGY_PEDESTAL.pad`.
	local sink = padSpec.sink
	local surroundTop = padSpec.size.Y - sink
	local pad = padPart("CollectPad", padSpec.size, -sink, STONE_DARK)
	-- CanTouch is what makes this a button at all, and it is the only part
	-- here that has it: one touch source rather than two overlapping ones.
	pad.CanTouch = true
	local padFace = padPart("CollectPadFace",
		Vector3.new(padSpec.size.X - padSpec.rim * 2,
			padSpec.faceSink + padSpec.faceProud,
			padSpec.size.Z - padSpec.rim * 2),
		-- BORN RED, AND NOTHING BUT `setBuffered` MAY EVER LIGHT IT. A pad is
		-- a READOUT, and a freshly built pedestal is empty -- so a face
		-- painted green here is a button claiming it will pay out before
		-- anybody has asked it. It was, for the second or so until the first
		-- economy tick. Same fault as the one that made green mean nothing for
		-- a second after a collect (see `padReady`), in miniature and at the
		-- other end of a pedestal's life.
		surroundTop - padSpec.faceSink, padSpec.emptyColour)
	padFace.CanTouch = false

	local padLabel, padAmount = PiggyPedestal.buildPadFigure(padFace)
	local padSound = PiggyPedestal.buildPadSound(pad)

	pad:SetAttribute(Config.PIGGY_SLOT_ATTRIBUTE, index)

	-- THE FOUR PROMPTS, WHICH ARE `buildPrompts`' NOW. Extracted rather than
	-- left inline because the hall's own plots need the identical four on
	-- different geometry -- see that function.
	local sellPrompt, takePrompt, placePrompt, snatchPrompt =
		PiggyPedestal.buildPrompts(plinth)

	model.PrimaryPart = plinth
	model.WorldPivot = ground
	model.Parent = parent

	return {
		index = index,
		model = model,
		plinth = plinth,
		-- SEATED OFF THE PLINTH'S OWN TOP FACE rather than off a stack of
		-- constants: the courses' heights are already in
		-- `Config.PIGGY_PEDESTAL` and adding them up again here is a second
		-- description of how tall this thing is.
		--
		-- AND TURNED INWARD BY A QUARTER, NEVER BY THE EXACT ANGLE TO THE
		-- TILL -- the pad's own `Config.piggyPadYaw`, which is the SAME yaw
		-- the button in front of it takes. Designer call 2026-09-21, stated as
		-- the result rather than as the mechanism: *"they should all be turned
		-- 90 degrees on the right and the left side should be turned 270
		-- degrees so they are all facing inwards"*, and those two numbers are
		-- what that function returns. From the street the viewer's RIGHT
		-- column is plot-local x -25, whose inward direction is +X, which is a
		-- +90 yaw on a +Z-authored model; their LEFT is x +25, inward is -X,
		-- 270. There is no third case: every slot is at |x| 25.
		--
		-- AND THE PIGGY IS NOT WHAT WAS FACING THE WRONG WAY, WHICH IS THE
		-- CORRECTION THAT MATTERS HERE. Reported on 2026-09-23 as *"the lawn
		-- pedestals are facing the wrong way they should be facing forward"*,
		-- this line was dropped for an hour and the six were pointed at the
		-- street -- answered with *"no now the piggies are facing the wrong
		-- way, the stand that they sit on is what was facing the wrong way"*.
		-- The STAND is `setArt`'s business and its own note carries the
		-- measurement. The lesson is the cheaper one: TWO THINGS STACKED ON
		-- ONE SPOT HAVE TWO FACINGS, and a report that names the spot names
		-- neither -- so measure which of them is actually pointing wrong
		-- before turning the one that was mentioned.
		--
		-- THE FAULT WAS NEVER "INWARD", IT WAS "NOT SQUARE", and getting that
		-- distinction wrong cost a revision in each direction. The first build
		-- used `Config.piggyPedestalYaw` -- the TRUE bearing to the till,
		-- which is a different angle per row because the rows are at different
		-- depths. A plinth, its base course and its pad are all square to the
		-- plot (the pad has to be, or its 8.4-stud width lands diagonally
		-- across a 10-stud row pitch), so an exact bearing put every display
		-- ASKEW ON ITS OWN SQUARE PLINTH:
		--
		--     front row (z 8)    107.74 deg    17.7 off the plinth
		--     middle    (z -2)    85.43        4.6 off
		--     back      (z -12)   64.36       25.6 off
		--
		-- Reported as *"some piggies are slightly tilted inwards"*, and both of
		-- those words are that table: the middle pair are within five degrees
		-- of square and read as straight, so it IS some rather than all, and
		-- the worst of the others is 26 degrees, which reads as a prop knocked
		-- out of line. The revision after that dropped the yaw entirely and
		-- was refused the other way -- *"thats not right all piggies are
		-- facing toward the street"* -- because square-to-the-plot has FOUR
		-- answers and only one of them is inward.
		--
		-- SO: A TURN READS AS DELIBERATE WHEN IT IS SQUARE TO WHAT IT STANDS
		-- ON, AND THE QUANTISED QUARTER IS THE ONLY THING THAT IS BOTH. It
		-- lands flush on the plinth AND faces the centrepiece, which is what
		-- the arrangement was always for: six two-thirds-size piggies looking
		-- at the big one rather than a shop rack all showing the same flank.
		--
		-- A PLAIN YAW AND DELIBERATELY NOT `CFrame.lookAt`. The frame already
		-- carries the plot's rotation, so the far row's half turn comes along
		-- for free; and because it is a yaw rather than a `lookAt`, the
		-- +Z-authored model needs no half-turn correction and cannot pick up
		-- the backwards-model bug this project has recorded four times.
		seat = plinth.CFrame * CFrame.new(0, plinth.Size.Y / 2, 0)
			* CFrame.Angles(0, Config.piggyPadYaw(index), 0),
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

-- ------------------------------------------------------------
-- THE NAME OVER ITS HEAD, IN ITS TIER'S COLOUR
-- ------------------------------------------------------------
--
-- Designer call 2026-09-21. The colour is the whole of why this is worth
-- more than a label: six names in one ink would say what is on the lawn,
-- and six names in four colours say which of them is worth anything -- so
-- a visitor reads the shape of somebody's collection without counting.
--
-- SHARED WITH THE TILL SINCE 2026-09-23, WHICH IS WHY IT IS A FUNCTION.
-- It was inlined in `dress` for as long as a pedestal was the only thing
-- in the game wearing one, and the designer then asked for the centre pig
-- to be named too. A second copy over there would have been a second
-- answer to where a label hangs, how far it reads from and what colour a
-- tier is -- the near-identical duplicate this project records more often
-- than any other fault, and the one that drifts the first time either side
-- is touched. One builder, two callers, and the only thing they disagree
-- about is the SECOND ROW.
--
-- THE NAME AND THE COLOUR ARE BOTH DERIVED FROM THE KEY, here rather than
-- passed in, so a caller cannot hand over a word that disagrees with the
-- tier its colour is drawn from.
--
-- `adornee` IS WHAT THE LIFT IS MEASURED FROM and is not always the thing
-- being named: a pedestal hangs its label on the PLINTH -- the one part
-- there that is guaranteed to exist and never moves, while the display on
-- top of it is destroyed and rebuilt on every dressing -- and the till
-- hangs it on the pig's own body, because a till has no plinth. The crown
-- is measured over `model` either way, so what the label clears is the
-- thing it is about rather than the thing it is parented to.
--
-- LIFTED OFF THE CROWN OF WHAT WAS ACTUALLY SEATED, measured rather than
-- derived from a nominal height, and that is what fixes "clipping their
-- heads". The first build lifted by the ordinary mini's own ear reach
-- times the display scale, which is right for exactly one case: a
-- LEGENDARY is a whole model of 9 to 24 meshes standing over a hidden pig
-- (`Config.LEGENDARIES`) with a silhouette of its own, so a lift solved
-- against a sphere put the label through a dragon's head.
--
-- PER PART, IN WORLD SPACE, WHICH IS THE ONLY WAY TO MEASURE A MODEL HERE.
-- `Model:GetBoundingBox` is oriented by the pivot and transposes extents --
-- this project has it recorded twice, once measuring a house's orbiting
-- shards at altitude and once reporting the tube man's HEIGHT as the
-- widest ornament in the game. The projection below is the formula
-- `CLAUDE.md` prescribes instead.
--
-- Returns the billboard and its second row, so a caller that repaints that
-- row (a pedestal does, every economy tick) keeps a handle on it.
function PiggyPedestal.nameplate(model: Model, adornee: BasePart, key: string,
	second: string?, secondColour: Color3?): (BillboardGui, TextLabel)

	local spec = Config.PIGGY_NAME
	local skin = Config.getSkin(key)
	local name = (skin and skin.name) or key
	local crown = -math.huge
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local cf = part.CFrame
			local half = math.abs(cf.RightVector.Y) * part.Size.X / 2
				+ math.abs(cf.UpVector.Y) * part.Size.Y / 2
				+ math.abs(cf.LookVector.Y) * part.Size.Z / 2
			crown = math.max(crown, cf.Position.Y + half)
		end
	end
	-- A MODEL WITH NO PARTS CANNOT HAPPEN AND IS ANSWERED ANYWAY, because
	-- `-math.huge` would put the label under the world and a pedestal's
	-- caller runs off the economy tick -- a name a little low is a far
	-- smaller fault than a piggy that throws while being dressed.
	if crown == -math.huge then
		crown = adornee.Position.Y + adornee.Size.Y / 2
	end

	-- ADORNED TO A PART THAT NEVER MOVES, with the whole lift expressed in
	-- world space from its centre. The label's own half-height is in the sum,
	-- so the GAP is clear air under the bottom edge rather than to its middle
	-- -- which is what the first build got wrong twice over.
	-- TWO ROWS, ONE BILLBOARD, AND THE TOTAL IS WHAT THE LIFT IS SOLVED
	-- AGAINST. The name takes the top `size.Y` studs and the second row the
	-- `rateHeight` under it, so the figure sits between the name and the
	-- piggy's own head -- which is the order the two are read in.
	local total = spec.size.Y + spec.rateHeight
	local label = Instance.new("BillboardGui")
	label.Name = "PiggyName"
	label.Size = UDim2.fromScale(spec.size.X, total)
	label.StudsOffsetWorldSpace = Vector3.new(0,
		(crown - adornee.Position.Y) + spec.gap + total / 2, 0)
	-- NOT always-on-top, for the two reasons `build` records on the pad: a
	-- label that punches through the house reads as HUD rather than as lawn,
	-- and the always-on-top pass is invisible to `screen_capture`.
	label.AlwaysOnTop = false
	label.MaxDistance = spec.range
	label.Adornee = adornee
	label.Parent = adornee

	local nameText = Instance.new("TextLabel")
	nameText.Name = "Name"
	nameText.Size = UDim2.fromScale(1, spec.size.Y / total)
	nameText.BackgroundTransparency = 1
	nameText.Font = Theme.FONT
	nameText.TextScaled = true
	nameText.Text = name
	nameText.TextColor3 = Config.piggyTierColour(key)
	-- THE STROKE IS LOAD-BEARING HERE RATHER THAN DECORATIVE. The four tier
	-- colours are authored as CARD grounds, so against bare lawn they measure
	-- 1.65 to 3.74 and epic purple on grass is the worst of them; against ink
	-- they are 4.65 to 10.53. Contextual mode, which strokes the GLYPHS --
	-- `Theme.outline` sets Border and would draw a box round the label.
	nameText.TextStrokeColor3 = Theme.INK
	nameText.TextStrokeTransparency = 0.1
	nameText.Parent = label

	-- ------------------------------------------------------------
	-- AND THE ROW UNDER IT
	-- ------------------------------------------------------------
	--
	-- WHAT GOES HERE IS THE ONE THING THE TWO CALLERS DISAGREE ABOUT. A
	-- pedestal leaves it EMPTY and `setRate` fills in what that piggy earns
	-- on the next economy tick; the till passes a fixed word, because a till
	-- earns nothing at all and a rate row there could only ever read +0/s.
	--
	-- GOLD BY DEFAULT, WHICH IS THIS GAME'S ONE COLOUR RULE RATHER THAN A
	-- CHOICE: gold means money and pink means the pig. The collect pad on the
	-- grass below says money a different way -- a banknote-green button with a
	-- white figure on it -- so the two read as one statement about this
	-- pedestal without being the same colour: what it MAKES, and what is
	-- WAITING. A caller whose row is not a figure passes its own colour.
	--
	-- IT DOES NOT TAKE THE TIER COLOUR. Four coloured names picked out of six
	-- is a collection read at a glance; eight coloured rows is a wall, and
	-- this row is the SECONDARY half of the pair -- see `Config.PIGGY_NAME`.
	local rateText = Instance.new("TextLabel")
	rateText.Name = "Rate"
	rateText.Position = UDim2.fromScale(0, spec.size.Y / total)
	rateText.Size = UDim2.fromScale(1, spec.rateHeight / total)
	rateText.BackgroundTransparency = 1
	rateText.Font = Theme.FONT
	rateText.TextScaled = true
	rateText.Text = second or ""
	rateText.TextColor3 = secondColour or Theme.GOLD
	rateText.TextStrokeColor3 = Theme.INK
	rateText.TextStrokeTransparency = 0.1
	rateText.Parent = label
	return label, rateText
end

-- ------------------------------------------------------------
-- DRESSING
-- ------------------------------------------------------------

-- Put a piggy on this pedestal, or clear it with `key = nil`.
--
-- IDEMPOTENT ON THE KEY, and that is what makes it safe to call from the
-- repaint path rather than only from the moment something changes: a pedestal
-- already wearing the right piggy is left alone, so the economy tick can push
-- the whole lawn every half second without rebuilding six models a tick.
function PiggyPedestal.dress(refs: Refs, key: string?)
	if refs.key == key then
		return
	end
	if refs.display then
		refs.display:Destroy()
		refs.display = nil
	end
	-- THE NAME GOES WITH THE PIGGY, always, and it is destroyed here rather
	-- than hidden: both the word and the colour are functions of the key, so
	-- there is no state to keep in step -- an empty pedestal has no name label
	-- at all, and a re-dressed one gets a new one.
	if refs.nameLabel then
		refs.nameLabel:Destroy()
		refs.nameLabel = nil
		refs.rateText = nil
	end
	refs.key = key
	refs.plinth:SetAttribute(Config.PIGGY_SLOT_KEY_ATTRIBUTE, key)

	-- ------------------------------------------------------------
	-- WHICH OF THE THREE VERBS THIS PLINTH IS OFFERING
	-- ------------------------------------------------------------
	--
	-- `ownPrompt` FLIPS AND `snatchPrompt` APPEARS AND DISAPPEARS, and both
	-- are written HERE rather than at the placement sites for the reason this
	-- whole function exists: `PlotService.setPiggySlots` is the one door every
	-- repaint comes through -- a crate open, a sale, a snatch, a delivery, a
	-- rebirth, a join -- so a state written anywhere else is a state that can
	-- be missed at five of those six.
	--
	-- NOTHING HERE WRITES `Enabled`, AND THAT IS THE HALF THAT HAD TO BE GOT
	-- RIGHT RATHER THAN THE WORDING.
	--
	-- Whether either of these is available at all depends on the plot's
	-- OWNER, which this function does not know and must not learn -- so it is
	-- `PiggyPedestal.setHaul` that switches them, from `setPiggySlots`, which
	-- knows both. Getting that wrong is not cosmetic: `PromptUI`'s rules may
	-- only ever REFUSE, so a prompt that is already `Enabled` when a client
	-- first sweeps an unowned plot is refused on that screen forever and the
	-- later owner write cannot take it back. This project has shipped exactly
	-- that once, on these same seven prompts, and the fix was the same one --
	-- make the server's own `Enabled` go false -> true at the moment the state
	-- becomes live, so there is a change for the client to answer.
	refs.snatchPrompt.ObjectText = ""
	refs.takePrompt.ObjectText = ""
	if key == nil then
		-- AN EMPTY PLINTH OF YOUR OWN ADVERTISES `PLACE`, AND IT IS AN
		-- AFFORDANCE RATHER THAN A DEAD CONTROL. A player standing at it with
		-- nothing in their arms presses it and is told, out loud, that they
		-- are not carrying anything -- which is how the placement verb is
		-- LEARNED, and it is the difference this project draws between a
		-- refusal that speaks and one that does not. The rule refused here is
		-- not "a control that looks available and does nothing"; it is "a
		-- control that looks available and does nothing WITHOUT SAYING SO".
		--
		-- The alternative was gating it on whether the reader is carrying,
		-- which cannot be done with the instrument this game has: a client
		-- rule may only ever turn a prompt OFF, so one refused because your
		-- hands were empty could never come back when they were not.
		refs.sellPrompt.ObjectText = ""
		refs.sellPrompt:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE, nil)
		-- The pad goes RED with the pedestal. An empty slot has nothing to
		-- bank, so a button reading ready there would be the one thing this
		-- project refuses above all others: a control that looks live and does
		-- nothing when used.
		refs.padFace.Color = Config.PIGGY_PEDESTAL.pad.emptyColour
		refs.pad:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE, nil)
		-- AND THE FIGURE READS ZERO RATHER THAN VANISHING, which reverses the
		-- rule that stood here ("a pad reading a stale amount under an empty
		-- plinth is the worst of the three states this label can be in"). That
		-- was about a STALE amount and it is still right about one; what it got
		-- wrong is treating a blank as the safe alternative. Now the number is
		-- painted ON the button, a blank one is a coloured tile with nothing on
		-- it -- indistinguishable from paving -- where a red button reading 0 is
		-- unmistakably a readout that currently has nothing to give.
		refs.padAmount.Text = Config.formatCoins(0)
		return
	end

	local model = PiggyModel.build(key)
	-- ANCHOR WHATEVER YOU ARE HANDED. `PiggyModel` builds UNANCHORED and
	-- Massless on purpose -- its own comment says so -- because its usual job
	-- is being welded to a running thief, and an anchored part welded to a
	-- humanoid pins the humanoid. Stood on a plinth with nothing to weld to it
	-- simply falls, which is exactly how three of four shop-window displays
	-- vanished on their first build. `ShopFront` inverts the same rule for the
	-- same reason.
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end

	local spec = Config.PIGGY_PEDESTAL
	-- THE DISPLAY SCALE TIMES THE SKIN'S OWN (designer, 2026-09-21: "bee and
	-- lady bugs should be smaller but lions and tigers should be larger").
	-- `Config.piggyScale` is clamped to `PIGGY_SCALE` and `auditPiggySlots`
	-- refuses a band the row pitch cannot hold, so this cannot put two
	-- neighbours through each other. Through `PiggyModel.scale` rather than
	-- `ScaleTo` directly, because the aura's spark size is in studs and has
	-- to follow the body.
	local factor = spec.display * Config.piggyScale(key)
	PiggyModel.scale(model, factor)

	-- SEATED ON `refs.seat`, WHICH IS THE BUILDER'S OWN MEASUREMENT.
	-- `PiggyModel`'s pivot is the mini's BODY CENTRE, so the lift is that
	-- centre's height above the model's own origin, scaled -- and the origin
	-- is where the feet are. See `Refs.seat` for why the frame is a field
	-- rather than the plinth-and-yaw expression that used to stand here.
	local lift = PiggyModel.MINI_CENTRE_Y * factor
	-- ONE FRAME FOR THE PIGGY AND ITS BUTTON ON THE LAWN, WHICH IS THE
	-- PROPERTY TO KEEP. A display at one angle on a pad at another is exactly
	-- the reported bug, so `build` derives both from one quantised yaw rather
	-- than from two expressions that have to be kept in step.
	model:PivotTo(refs.seat * CFrame.new(0, lift, 0))
	model.Name = "Display"
	model.Parent = refs.model

	refs.display = model
	local skin = Config.getSkin(key)
	local name = (skin and skin.name) or key

	-- THE NAME OVER ITS HEAD, through the shared builder so the till and a
	-- plinth cannot disagree about where a label hangs or what colour a tier
	-- is. BORN EMPTY, never at a guessed rate: what a piggy earns is a fact
	-- about its OWNER as well as about itself -- the income tree, rebirths, a
	-- friend bonus and a daily boost all multiply into it -- and none of that
	-- is reachable from a builder in `Shared`. `setRate` fills it in on the
	-- very next economy tick, and a blank row is the honest picture until it
	-- does.
	local label, rateText = PiggyPedestal.nameplate(model, refs.plinth, key)

	refs.nameLabel = label
	refs.rateText = rateText
	-- AND THE PAD DOES *NOT* LIGHT HERE, which reverses the line that stood
	-- in its place ("the pad lights the moment something is standing here").
	-- That claim was about the pedestal being OCCUPIED, which the piggy
	-- standing on it and the name over its head both say already -- and the
	-- face is not for that. The face answers one question, will stepping on
	-- this bank anything, and a piggy that has just been put down has an empty
	-- buffer. So it is left dark and `setBuffered` lights it when there is
	-- something to light it for.
	--
	-- WHAT IT COSTS IS UP TO ONE TICK OF RED on a rejoin, where a save's
	-- buffers arrive with the piggies. That is the safe direction: a light
	-- that is late is a light somebody steps on a second later, and a light
	-- that is early is the silent refusal this whole pass is about.
	refs.padFace.Color = Config.PIGGY_PEDESTAL.pad.emptyColour

	-- WHAT LETTING IT GO IS WORTH, ON THE CARD, WHILE YOU HOLD. This is the
	-- whole of the guard against selling something by accident -- there is no
	-- confirmation dialogue and deliberately so (see `Config.PIGGY_SELL`) --
	-- so the figure has to be on screen for the 1.8 seconds the hold takes.
	--
	-- Through `formatSellValue`, so the card and the payout are one number.
	-- It used to have to know that a skin paid ACORNS rather than coins;
	-- there is one currency now and the function is a coin formatter.
	refs.sellPrompt.ObjectText = name
	refs.sellPrompt:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE,
		Config.formatSellValue("skin", Config.sellValue("skin", key)))

	-- AND BOTH HAUL CARDS NAME THE PIGGY, which is the whole of what makes a
	-- lawn a shopping list rather than six identical plinths. A thief reads
	-- WHICH one they are about to take before they commit to a 1.5-second
	-- hold on somebody's defended ground, and an owner tidying their own
	-- collection reads which one they are about to pick up.
	--
	-- The name and nothing else: what a piggy is WORTH belongs on the sell
	-- card, where the number is the decision. On these two it would be a
	-- price tag on something nobody is buying.
	refs.takePrompt.ObjectText = name
	refs.snatchPrompt.ObjectText = name
end

-- WHETHER AN EMPTY PLINTH IS WORTH OFFERING, WHICH IS THREE FACTS RATHER
-- THAN ONE: it has to be owned, it has to be empty, and its owner has to be
-- holding a piggy of their own. One function reads all three and is the only
-- writer of that prompt's `Enabled`.
--
-- THE CARRY HALF REVERSES A DECISION RECORDED IN `PiggyHaulService.place`,
-- which read: *an empty plinth of your own advertises PLACE whether or not
-- your hands are full, because a client rule may only ever turn a prompt OFF
-- and one refused for empty hands could never come back when they were not.*
-- Every word of that is true OF A CLIENT RULE, and it was the wrong place to
-- answer the question. A plot has exactly one owner, the prompt already names
-- them through `PROMPT_OWNER_ATTRIBUTE`, and the only person who can press it
-- is that owner -- so the SERVER can switch it both ways without ever showing
-- a live control to somebody it would refuse. That is precisely what the
-- bank's swap prompt has done since it shipped, through
-- `PlotService.setSwapOffer`.
--
-- THE OUT-LOUD REFUSAL IN `place` STAYS, and stays for a reason rather than
-- out of caution: a prompt is a picture and the server is the guard, so it
-- goes on naming what to do instead for anybody who reaches it another way.
local function paintPlace(refs: Refs)
	refs.placePrompt.Enabled = (refs.ownerId or 0) ~= 0
		and refs.carrying == true
		and refs.key == nil
end

-- WHAT THE OWNER IS HOLDING, ON ITS OWN CLOCK.
--
-- Called by `PlotService.setPlaceOffer` at the three moments a carry starts,
-- ends or changes. Nothing else about the plinth is touched: who owns it and
-- what is standing on it are two other questions with two other writers, and
-- this one only ever re-asks the painter above.
function PiggyPedestal.setCarrying(refs: Refs, carrying: boolean)
	refs.carrying = carrying
	paintPlace(refs)
end

-- WHO THIS PLINTH'S TWO HAUL PROMPTS ARE FOR, AND WHETHER EITHER IS LIVE.
--
-- SPLIT FROM `dress` BECAUSE IT ANSWERS A DIFFERENT QUESTION ON A DIFFERENT
-- CLOCK, which is the same split `setBuffered` and `setRate` already make.
-- What is STANDING here is a fact about the save; WHOSE it is, is a fact
-- about the plot, and a plot changes hands without a single piggy moving.
-- Folded into `dress` the owner could only ever be republished when the key
-- changed -- and `dress` returns early when it has not, so an empty slot
-- would keep the departed owner's attribute for the rest of the server's
-- life.
--
-- THE TWO WRITES ARE IN THIS ORDER AND THE ORDER IS LOAD-BEARING. The
-- attribute first, then `Enabled`, because `PromptUI` answers an `Enabled`
-- change by re-running its refusal against whatever the attribute says at
-- that instant -- so enabling first is enabling against a stale owner, which
-- refuses the prompt on the right person's screen permanently.
--
-- AND `ownerId` 0 IS NOBODY, which is what makes an unclaimed lawn safe. A
-- resident's plot and a released one both publish 0: no client matches it, so
-- `ownPrompt` is refused everywhere, and `snatchPrompt` -- which refuses the
-- id it NAMES rather than everyone else -- is refused nowhere. That is the
-- correct reading of both: you cannot tidy a neighbour's collection, and
-- anybody at all may take from it.
--
-- AND THE THIRD ARGUMENT IS WHETHER THE OWNER IS CARRYING, which a repaint
-- has to carry because it is the one of the three facts this file cannot see
-- for itself. `PlotService` remembers it on the plot; see `setPlaceOffer`.
function PiggyPedestal.setHaul(refs: Refs, ownerId: number, carrying: boolean)
	refs.ownerId = ownerId
	refs.carrying = carrying
	refs.sellPrompt:SetAttribute(Config.PROMPT_OWNER_ATTRIBUTE, ownerId)
	refs.takePrompt:SetAttribute(Config.PROMPT_OWNER_ATTRIBUTE, ownerId)
	refs.placePrompt:SetAttribute(Config.PROMPT_OWNER_ATTRIBUTE, ownerId)
	refs.snatchPrompt:SetAttribute(Config.PROMPT_DENY_OWNER_ATTRIBUTE, ownerId)
	-- OWNED PLOTS ONLY FOR THE OWNER'S THREE, and that is not tidiness. An
	-- unowned plinth's take, place and sell would be refused on every screen
	-- in the game by the owner rule -- which is fine -- and they would also be
	-- `Enabled` true from server boot, which is the state that poisons a
	-- client's first sweep and cannot be taken back.
	local owned = ownerId ~= 0
	refs.sellPrompt.Enabled = owned and refs.key ~= nil
	refs.takePrompt.Enabled = owned and refs.key ~= nil
	paintPlace(refs)
	-- SOMETHING TO TAKE, AND NOBODY HAS TO OWN IT. A resident's lawn is the
	-- only place a solo player meets this verb at all.
	refs.snatchPrompt.Enabled = refs.key ~= nil
end

-- SWITCH ALL FOUR OFF AND SWITCH THE RIGHT ONES BACK A BEAT LATER.
--
-- THIS EXISTS BECAUSE "WRITE THE OWNER BEFORE YOU ENABLE" IS NECESSARY AND
-- NOT SUFFICIENT, which is a correction to a fix this project already made
-- and recorded as done.
--
-- `PromptUI`'s rules may only ever REFUSE, so what makes them safe is that
-- the server's own `Enabled` goes false -> true AFTER the owner lands, giving
-- the client a change to answer. The hole is the client's ONE-TIME SWEEP: it
-- walks every prompt in the world once at startup and refuses anything whose
-- owner is not the reader -- and if that sweep lands between the `Enabled`
-- replication and the OWNER replication for a given pedestal, it refuses a
-- prompt the reader owns, and nothing ever changes again to take it back.
--
-- MEASURED, ON A LIVE PLOT, and the shape is what makes it so easy to miss:
-- the owner attribute read CORRECTLY on the client, the server read
-- `Enabled = true`, and three of six sell prompts were locally false with no
-- error anywhere -- so a player could not sell half their own collection.
-- Bouncing those three across a frame from the server fixed all three, which
-- is what confirmed the diagnosis rather than a reading of the code.
--
-- A REAL FRAME HAS TO PASS, which is the whole reason this is two steps and a
-- delay rather than `Enabled = false; Enabled = true`. Roblox replicates the
-- value a property HAS at the end of a frame, so an off-and-on inside one
-- frame is no change at all and the client hears nothing.
--
-- AND IT RESTORES BY RECOMPUTING RATHER THAN BY REMEMBERING. `setHaul` reads
-- `refs.key` and the owner as they are when the timer fires, so a piggy sold,
-- snatched or placed during the beat is answered correctly -- where a
-- remembered "it was true" would put back the state of a plinth that has
-- since changed.
local REPUBLISH_DELAY = 0.2

function PiggyPedestal.republish(refs: Refs, ownerId: number)
	refs.sellPrompt.Enabled = false
	refs.takePrompt.Enabled = false
	refs.placePrompt.Enabled = false
	refs.snatchPrompt.Enabled = false
	local generation = (refs.generation or 0) + 1
	refs.generation = generation
	task.delay(REPUBLISH_DELAY, function()
		-- A LATER REPUBLISH HAS ALREADY TAKEN OVER. Two timers restoring
		-- against two different owners would be settled by whichever landed
		-- last rather than by which was current, which is how a plot claimed
		-- and released inside a fifth of a second would come back wearing the
		-- departed owner's prompts.
		if refs.generation ~= generation then
			return
		end
		-- AND THE CARRY IS RE-READ RATHER THAN CAPTURED, for the same
		-- reason the key and the owner are: a piggy picked up or put down
		-- during the beat is answered correctly, where a remembered "they
		-- were holding one" restores a state that has since ended.
		PiggyPedestal.setHaul(refs, ownerId, refs.carrying == true)
	end)
end

-- WHAT THIS PAD HAS WAITING: said in its colour AND printed on it.
--
-- THE FIGURE IS ON THE FACE (designer call 2026-09-21), and the two entries
-- that used to sit here are worth keeping because each was half right.
--
-- The first read: "type on the floor is unreadable at standing height... if
-- the figure is wanted back it belongs on a billboard over the pedestal, not
-- on the pad." The worry is sound and the number behind it was never taken.
-- Measured from a player's own camera a pad is 234 x 56 pixels with its depth
-- reading at 55% of true, so the type is legible on the face -- and a figure
-- floating above the button is not the button saying anything.
-- `PIGGY_PEDESTAL.pad.labelRange` carries that measurement in full.
--
-- The second read: "NOTHING WAITING MEANS NO LABEL, which is the rob badge's
-- rule rather than a saving: a chip reading 0 forever is wallpaper, and
-- wallpaper is what a player stops seeing." That is right about a chip and
-- wrong about a button. The rob badge hangs in the air over somebody else's
-- pig, where an absence is the cheapest possible state; this is a physical
-- control on your own lawn that is THERE either way, so the only question is
-- whether it is labelled. Unlabelled it is a coloured tile.
--
-- SO THE COLOUR IS THE STATE AND THE FIGURE IS THE DETAIL, which is the split
-- the ring and the pips already make on the wanted chip: green or red answers
-- "walk the lap" from across the lawn without being read, and the number
-- answers "is this one worth it" once you are looking at it.
--
-- The amount is still published as an attribute too, because it costs nothing
-- and it is what a probe reads to check the buffer without the save.
-- WHETHER A PAD'S FACE SHOULD READ READY.
--
-- ONE PREDICATE FOR SEVEN PADS, and it was two expressions before this. The
-- till's face is painted inline in `PlotService.setPiggyBuffers` and the six
-- pedestals' here, both testing `whole > 0` -- the near-identical second copy
-- this project has a rule about, on the one signal a player reads while
-- walking. Now there is one place the question is answered and the till is a
-- caller.
--
-- TWO TERMS, AND THE SECOND ONE IS THE BUG THIS EXISTS FOR. A buffer refills
-- continuously, so `whole > 0` goes true again within a tick of a collect --
-- and for `pad.cooldown` after that the pad cannot fire. A green button that
-- does nothing is the silent-refusal failure this project refuses above all
-- others, and a player walking over their own grass has no other channel to
-- be told on. So a pad is ready when there is a whole coin waiting AND it may
-- actually fire.
--
-- THE FIGURE IS NOT SUPPRESSED WITH THE COLOUR, which matters because the
-- number is the second channel that keeps this readable for a colour-blind
-- player (green against red separates by 1.93:1 in luminance -- they are THE
-- colour-blind pair). A cooling pad prints what is genuinely waiting, and
-- since the window is one reaction long that is a second or two of accrual --
-- a figure that reads as near-nothing anyway. It stays honest in both
-- channels rather than one of them lying to protect the other.
--
-- `Workspace:GetServerTimeNow` RATHER THAN `os.clock`, which is a process
-- uptime that means nothing off the machine it was read on -- the shield
-- attribute's own lesson. Nothing reads this from a client today; a stamp that
-- could not survive being published would be a landmine for the first thing
-- that wanted to.
function PiggyPedestal.padReady(whole: number, firedAt: number?): boolean
	if whole <= 0 then
		return false
	end
	-- THERE WAS A THIRD TERM, THE ROOM IN THE OWNER'S PIG, and it is gone
	-- with the pig's ceiling. It existed because a full pig refused every
	-- collect and a green pad over a refused collect was six buttons
	-- contradicting the toast they produced (measured: coins pinned at
	-- 73,789, six pads GREEN, 20.9K waiting on each, every collect refused).
	-- Nothing refuses a collect now, so the term is not stale, it would be a
	-- lie the other way: a room that goes negative once coins pass the old
	-- cap darkens every pad on the lawn while every collect works. What is
	-- left is what is waiting and the reaction window.
	if firedAt then
		local since = Workspace:GetServerTimeNow() - firedAt
		if since >= 0 and since < Config.PIGGY_PEDESTAL.pad.cooldown then
			return false
		end
	end
	return true
end

--- The face is decided by what is waiting and the reaction window (`padReady`);
--- the figure is always what is waiting.
function PiggyPedestal.setBuffered(refs: Refs, amount: number)
	local pad = Config.PIGGY_PEDESTAL.pad
	if refs.key == nil then
		refs.padFace.Color = pad.emptyColour
		refs.pad:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE, nil)
		local zero = Config.formatCoins(0)
		if refs.padAmount.Text ~= zero then
			refs.padAmount.Text = zero
		end
		return
	end
	-- A WHOLE COIN, NOT A FRACTION, which is what stops this repainting the
	-- pad on every tick of a buffer that is still filling: the economy loop
	-- calls this whenever a buffer moved, and a buffer moves continuously.
	local whole = math.floor(amount)
	local ready = PiggyPedestal.padReady(whole, refs.padFiredAt)
	refs.padFace.Color = if ready then pad.readyColour else pad.emptyColour
	local text = Config.formatCoins(whole)
	refs.pad:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE, text)
	-- WRITTEN ONLY WHEN IT CHANGED. This runs off the economy tick for six
	-- pedestals on every plot, and a `Text` write is a property replication to
	-- every client in range -- so a guard here is the difference between six
	-- writes a plot when a buffer rolls over a coin and six writes a plot per
	-- tick forever.
	if refs.padAmount.Text ~= text then
		refs.padAmount.Text = text
	end
end

-- WHAT THIS PIGGY EARNS, ON THE ROW UNDER ITS NAME.
--
-- SPLIT FROM `setBuffered` FOR THE REASON `setBuffered` IS SPLIT FROM
-- `dress`: three facts about one pedestal, on three different clocks. What
-- is STANDING here changes when somebody opens a crate or sells one; what is
-- BANKED here changes every tick; what it EARNS changes when its owner buys
-- an income level, rebirths, claims a boost or has a friend walk in. Folding
-- the third into the second would mean the rate could only ever be repainted
-- by a buffer moving, which is very nearly true and is not a rule anybody
-- would want to have to remember.
--
-- `rate` IS THE LIVE ONE, BOOST AND FRIEND BONUS INCLUDED, and that is the
-- whole reason it is passed in rather than derived here. A module in
-- `Shared` can reach `Config.getPiggyIncomeRate` and cannot reach either
-- multiplier, so a figure computed at this end would under-report for the
-- entire length of every boost -- and disagree with the HUD's own rate pill,
-- which is two claims about one number with no way for a player to tell
-- which is lying. `EconomyService` owns the arithmetic; this prints it.
--
-- NIL SAYS NOTHING RATHER THAN SAYING ZERO. A pedestal whose rate has not
-- arrived yet is not a pedestal earning nothing, and a row reading +0/s over
-- a legendary is worse than a blank one: it is wrong, and it is wrong in the
-- direction that makes a player stop trusting the number.
--
-- WRITTEN ONLY WHEN IT CHANGED, the same guard the pad figure carries and
-- for the same reason -- this runs off the economy tick for six pedestals on
-- every plot, and a `Text` write replicates to every client in range. A rate
-- moves a handful of times a session, so after the first tick this is six
-- string comparisons and no replication at all.
function PiggyPedestal.setRate(refs: Refs, rate: number?)
	local text = refs.rateText
	if not text then
		return
	end
	local shown = if rate ~= nil and rate > 0
		then ("+%s/s"):format(Config.formatCoins(rate))
		else ""
	if text.Text ~= shown then
		text.Text = shown
	end
end

return PiggyPedestal
