--!strict
--[[
	Config
	Every tunable number in the game lives here. Nothing else should hardcode
	a balance value -- if you find yourself typing a number in a service,
	it probably belongs in this file instead.

	All values are starting points from the design doc and expected to move
	once real players touch the game.
]]

-- A NOTE ON EVERY `tone` IN THIS FILE.
--
-- They are `Theme`'s accent family and they are written out as numbers here
-- rather than required, because Config requires NOTHING -- it is pure data,
-- pulled in by every server service, and making it depend on a UI module to
-- name a colour would be the wrong trade by a distance.
--
-- The family is derived, so a new tone is not a taste decision: take the hue
-- you want and build it at saturation 0.72, value 0.90 -- or value 0.82 if
-- the hue falls between 80 and 200, because green and lime read much
-- brighter than red and blue at the same value. Four tones sit off it on
-- purpose and each says why at its own entry: money is the real GOLD, the
-- prank is pulled back from a pure magenta, hiding is deliberately a neutral,
-- and the shop door and the alien recovery are moved off GOOD's own green so
-- that four different meanings are not one colour.

local Config = {}

-- ============================================================
-- ECONOMY
-- ============================================================

-- Coins added to the vault per second, before upgrades and rebirths.
Config.BASE_INCOME = 10

-- How much the vault holds before income stops. A full vault is the
-- return hook -- it should fill in roughly 8 minutes at level 1.
Config.BASE_CAPACITY = 5000

-- Each income upgrade multiplies the rate by this.
Config.INCOME_GROWTH = 1.35

-- Each capacity upgrade multiplies storage by this.
Config.CAPACITY_GROWTH = 1.40

-- ---------------------------------------------------------------- TWO BANDS
--
-- THE LADDER IS TWO CURVES, NOT ONE, AND BAND A IS UNTOUCHED ON PURPOSE.
--
-- Levels 1-20 keep exactly the growth they always had: the first two hours of
-- this game were never the problem and that curve is well tuned. Levels 21-40
-- are a second band with GENTLER growth on both sides -- income and cost --
-- because a single curve extended to 40 does not work in either direction.
-- At 1.35 income the rate reaches 121K/s and trivialises everything; at 1.55
-- cost the top level runs to 10.6B and nobody ever buys it.
--
-- The gap between the two growth rates is what sets pacing: cost outruns
-- income by 1.55/1.35 = 14.8% per level in band A, and by 1.26/1.16 = 8.6% in
-- band B. Each level takes longer than the last in both, more gently up top,
-- which is what keeps a 168M purchase feeling like a goal instead of a wall.
Config.BAND_TOP = 20
Config.INCOME_GROWTH_B = 1.16
Config.CAPACITY_GROWTH_B = 1.19
Config.INCOME_COST_GROWTH_B = 1.26
Config.CAPACITY_COST_GROWTH_B = 1.16

-- The hard ceiling. What a player can actually reach is `Config.maxLevel`,
-- which is lower until they have rebirthed enough -- see the note there.
Config.ABSOLUTE_MAX_LEVEL = 40

-- Levels a single rebirth adds to the reachable ceiling.
Config.LEVELS_PER_REBIRTH = 2

-- Cost of the first upgrade. Must be reachable in under a minute --
-- the first win has to land immediately.
Config.INCOME_BASE_COST = 400
Config.CAPACITY_BASE_COST = 600

-- Cost multiplier per level owned.
Config.INCOME_COST_GROWTH = 1.55
Config.CAPACITY_COST_GROWTH = 1.60

-- ------------------------------------------------- THE AFFORDABILITY CEILING
--
-- A RUNG MAY NEVER COST MORE THAN THE PIG THAT HAS TO PAY FOR IT, AND BEFORE
-- THIS THE LADDER DEADLOCKED AT LEVEL 17 OF 20.
--
-- Every growth number above is written as "cost outruns value, so each level
-- takes longer than the last" -- which is the correct shape for a ladder and
-- was correct here for the whole life of the project. It stopped being
-- correct the day the pig became the wallet. With an unbounded bank a price
-- above your income rate is a WAIT; with a balance bounded by capacity it is
-- a WALL, because the money to pay it cannot be held at one time however long
-- anybody waits.
--
-- Measured against the live curves before this constant existed: capacity
-- cost grows 1.60 against a capacity that grows 1.40, so the price gains 14%
-- on the pig every level and passes it at LEVEL 17. Capacity level 17 holds
-- 1.09M and level 18 costs 1.11M -- 20 of the 40 rungs unbuyable, the income
-- tree following at 31, and the rebirth gate (one full pig at the CEILING
-- level, 2.99M at rebirth 0) unreachable by a player whose pig had stopped at
-- 1.09M. Idling alone could not finish the game or leave it.
--
-- SO THE CEILING IS A FRACTION OF THE PIG, AND THE CLAMP IS WHAT MAKES THIS
-- STRUCTURAL RATHER THAN TUNED. Growth constants could have been retuned to
-- push the crossing past level 40 and it would have worked and it would have
-- been a coincidence -- the next price edit, the next band, the next rebirth
-- ceiling puts the wall back with nothing to say so. `math.min` against the
-- pig cannot regress: the geometric curve governs while it is the smaller of
-- the two, which is the whole of band A and every price this game has ever
-- shipped, and the pig governs after that.
--
-- WHAT IT COSTS, STATED PLAINLY: above the crossing the price is pinned to a
-- constant share of capacity, so it grows at the CAPACITY curve (1.40, then
-- 1.19) rather than at the cost curve, and a late upgrade is about 30-50%
-- cheaper than the old number nobody could pay. Time per upgrade goes from
-- rising-to-infinite to CONSTANT -- a fixed number of pig-fills, about 13
-- minutes of idling each -- which is a legible pace rather than a wall.
--
-- TWO FRACTIONS, NOT ONE, because a single ceiling would make the two trees
-- cost exactly the same at every clamped level and delete the "which one is
-- cheaper right now" decision that the base costs exist to create. The pair
-- keeps the ratio the base costs already have (400/600 = 0.688), so income
-- stays the cheaper rung all the way up.
--
-- Capacity's own clamp is the no-deadlock guarantee and the reason it is the
-- looser of the two: the pig can ALWAYS buy its own next size, so a player
-- who has poured everything into income can always grow their way out. The
-- income clamp is measured against the capacity at the INCOME level, which is
-- deliberately conservative -- it means your pig has to be roughly as big as
-- your income is high, which is a real coupling and the honest one. A bounded
-- wallet limits every purchase by construction; this only stops that being
-- fatal.
Config.UPGRADE_COST_CEILING = {
	income = 0.55,
	capacity = 0.80,
}

-- ============================================================
-- OFFLINE ACCRUAL
-- ============================================================

-- Vault keeps filling while logged off, up to this many seconds.
-- 8 hours deliberately covers a school day, so an after-school player
-- always comes back to a full vault. Income never decays past the cap.
Config.OFFLINE_CAP_SECONDS = 8 * 60 * 60

-- ============================================================
-- REBIRTH
-- ============================================================

-- REBIRTH COSTS A MULTIPLE OF YOUR OWN CAPACITY, NEVER A FLAT NUMBER.
--
-- This was a flat 1,000,000, and a flat gate cannot survive an economy that
-- grows: measured, it is 334 seconds of income the first time you cap the
-- ladder and EIGHT SECONDS by rebirth 10. It vanishes exactly as the decision
-- it guards gets more serious.
--
-- The obvious fix is worse. A geometric gate compounds faster than income
-- does -- income rises about 1.35x per rebirth, so a 3x gate diverges from it
-- and the gap becomes a wall: simulated, 1M x 3^rebirths spends 60 days stuck
-- at gates and 1M x 5^rebirths never finishes at all.
--
-- Capacity is the one anchor that can do neither. It rides the same curve the
-- player's own economy rides, so the gate can no more evaporate than it can
-- run away, and it stays correct with nothing to re-derive when the ladder
-- next changes. It is also the only version a nine-year-old can read: fill
-- your piggy bank, measured on the bar they are already watching.
--
-- ONE, NOT TWO, SINCE THE PIG BECAME THE WALLET. Income alone can never carry
-- a player past capacity now, so "twice over" was reachable only by robbing.
-- "Fill it" is reachable by idling and FASTER by robbing, which is the right
-- way round for the decision this economy most needs players to make.
Config.REBIRTH_CAPACITY_MULTIPLE = 1

-- Permanent income bonus per rebirth, additive: 1 + (rebirths * 0.12)
--
-- WAS 0.25, AND HAD TO COME DOWN THE MOMENT REBIRTH STARTED RAISING THE
-- CEILING, because the two levers multiply each other. At 0.25 against a
-- 40-level ladder the top rate is 204K/s, which earns the entire 1.62B of
-- content in about two hours; at 0.12 it settles at 93K/s and the ceiling
-- does the work. The multiplier is now the small half of prestige and the
-- unlocked levels are the large half, which is the way round that keeps
-- rebirthing worth doing at rebirth 9.
Config.REBIRTH_MULTIPLIER = 0.12

-- ============================================================
-- SOCIAL
-- ============================================================

-- Income bonus per friend in the same server. This is the growth engine:
-- inviting someone is a mechanical advantage, not a favour you do the game.
Config.FRIEND_BONUS_PER = 0.10
Config.FRIEND_BONUS_MAX = 0.50

-- The "get them back" marker over a thief's plot lasts Config.REVENGE.window,
-- which is also how long robbing them back pays triple. One number on purpose.

Config.LEADERBOARD_SIZE = 8
Config.LEADERBOARD_REFRESH = 5

-- ============================================================
-- FEEDBACK
-- ============================================================

-- Fill fractions that get a celebration. 100% matters most: income stops at
-- a full vault, so that one is functional feedback, not just a flourish.
Config.MILESTONES = { 0.25, 0.5, 0.75, 1.0 }

-- Free Creator Store audio. Swap these for your own uploads before launch --
-- some free assets ask for creator credit, and third-party audio can be
-- moderated out from under you without warning.
Config.SOUNDS = {
	COIN_DROP = "rbxassetid://4608067546",
	MILESTONE = "rbxassetid://2415965014",
	BANK = "rbxassetid://101396758527961",
	ALARM = "rbxassetid://1470797856",

	-- Dog audio, all from Roblox's licensed Pro Sound Effects library.
	--
	-- That library is the reason these are safe. The Creator Store is full of
	-- free-to-take dog barks that are lifted from Minecraft or Undertale --
	-- "free" there means costing no Robux, not cleared for use, and a
	-- copyright strike moderates the asset away and leaves a silent game.
	-- Every id below is Pro Sound Effects, which Roblox licensed wholesale.
	--
	-- The breed barks are coyotes, not dogs: the library has no domestic dog,
	-- and a coyote bark pitched up reads as a terrier far better than a
	-- pitched-down one reads as a mastiff. Pitch does the rest, per tier.
	DOG_SNARL = "rbxassetid://9120790555",  -- Wolf Snarl, 1.98s -- the catch
	DOG_SQUEAK = "rbxassetid://9125994773", -- Squeeze Toy, 0.51s -- the bone
	DOG_WHINE = "rbxassetid://9113952398",  -- Coyote whimper, 3.19s

	-- The arrest, both halves. Pro Sound Effects, like the dog audio, and for
	-- the same reason: the Creator Store's free sirens, stings and "wasted"
	-- noises are overwhelmingly ripped from games and television, and a
	-- copyright strike moderates the asset away and leaves the scene silent
	-- after players have already learned what it sounds like. Searched and
	-- verified loading at 1.30s and 2.50s.
	--
	-- The cell door is deliberately NOT a dramatic drone. A door clanging
	-- shut is the same beat, it is funnier, it is nobody's property, and it
	-- is the one sound in the sequence that says "sentenced" rather than
	-- "you died" -- which matters when nothing here actually kills anybody.
	SHUTTER = "rbxassetid://9113678227",   -- Camera Shutter 1, Ricoh XR-M
	CELL_DOOR = "rbxassetid://9117911726", -- Prison Door 2, latch and rattle

	-- RIDE AUDIO. Pro Sound Effects, like the dog and the arrest, and chosen
	-- the same way -- the Creator Store's vehicle audio is overwhelmingly
	-- engine samples ripped out of driving games, and a strike moderates the
	-- asset away and leaves the ride silent after players have learned what
	-- it sounds like. Every id below is verified loading, with its length.
	--
	-- FIVE SOUNDS FOR SIX RIDES. It was three, on the reasoning that pitch
	-- could do the rest -- the same trick the dog barks use, one coyote and
	-- three breeds. That holds for the scooter and it did NOT hold for the
	-- bike or the disc, and both failures are recorded here because the
	-- reasoning looked sound in both cases.
	--
	-- CLOSE-MICD WHEELS ARE THE HARSHNESS, AND NO AMOUNT OF VOLUME FIXES A
	-- PERSPECTIVE. The roll used to be "CU Wheels, recorded from FRONT" --
	-- a close-up microphone pointed straight at the bearings. Close-up is
	-- all grind and grit with none of the air that makes a rolling sound
	-- pleasant, and it is what people meant by obnoxious after the volume
	-- had already been halved twice. It is the SIDE recording of the same
	-- session now: the same board, the same session, a perspective with
	-- some distance in it. Reach for the mic position before the fader.
	--
	-- PRO SOUND EFFECTS DOES HAVE BICYCLES AND NOT ONE OF THEM IS USABLE,
	-- which is a different statement from the one that used to stand here
	-- and it took a measurement to tell them apart. There IS a whole
	-- "Vehicles - Bicycles" category, so "no bicycle at all" was false. A
	-- bicycle pedal recording duly went in on the strength of its NAME --
	-- and shipped a BMX with no sound whatever, because every bicycle in
	-- the library is a quiet, sparse field recording. Measured mean
	-- loudness against the skateboard's 344: Pedal 1 is 2.5 and Pedal 2 is
	-- 1.6 (both over 98% silence), Spokes 102 is 3.5, Sting Ray 3 is 11.9,
	-- Spokes 201 is 16.8, and the best of them -- Training Wheel, the only
	-- one that is even continuous -- is 24.6. The loudest bicycle here is
	-- a fourteenth of the board. None of that is fixable with gain: there
	-- is nothing on the tape to turn up.
	--
	-- So the bike rides on RIDE_TYRE, pitched below the scrambler. That is
	-- a real pneumatic tyre, which is the thing a BMX actually rolls on and
	-- a far closer match than a skateboard's hard urethane, and it is
	-- constant with no silence in it at all.
	--
	-- NEVER CHOOSE AN ASSET BY ITS NAME AND CATEGORY. `PlaybackLoudness` on
	-- a playing Sound reports real output level; sample it for a couple of
	-- seconds before believing a recording is what its title says.
	RIDE_ROLL = "rbxassetid://9125955711",  -- Skateboard, constant roll, from the SIDE, 14.69s
	RIDE_TYRE = "rbxassetid://9112886237",  -- Tyre constant, airy whine, 27.01s
	RIDE_HOVER = "rbxassetid://9125767459", -- Pod cruising, constant tone, 27.02s
	RIDE_DISC = "rbxassetid://9119412672",  -- Spaceship hover, deep power drone, 19.17s

	-- The patrol siren. DELIBERATELY EMPTY until a licensed id goes here.
	--
	-- Every sound player tolerates an empty SoundId, so the patrol ships
	-- silent rather than shipping with a placeholder nobody remembers to
	-- swap. A siren is exactly the sound the Creator Store is worst for:
	-- the free ones are ripped from television, and a copyright strike
	-- moderates the asset away and leaves this silent anyway -- after
	-- players have already learned to listen for it. Pro Sound Effects
	-- has sirens; use one of those.
	-- THE SIREN, WHICH WAS DELIBERATELY EMPTY AND IS NOT ANY MORE. The
	-- entry that stood here said the patrol ships silent rather than
	-- shipping "a placeholder nobody remembers to swap", and that a siren is
	-- exactly the sound the Creator Store is worst for because the free ones
	-- are ripped from television. Both halves were right and the second one
	-- was measured this session rather than assumed: a search for "siren
	-- police" returns fifteen results, of which ONE is Pro Sound Effects and
	-- the rest include "All credits go to the original owners of this audio.
	-- Not made by me."
	--
	-- WHAT THE OLD ENTRY NAMED AS THE FIX IS WHAT FILLED IT: "Pro Sound
	-- Effects has sirens." This is that siren. It is a cleared asset from the
	-- library Roblox licensed wholesale rather than a placeholder, so the
	-- failure the empty string was protecting against -- a strike moderating
	-- the asset away after players have learned to listen for it -- is the
	-- same risk every other id in this table already carries and no worse.
	--
	-- IT IS STILL TOLERATED EMPTY, which is the half that must not be lost.
	-- `PoliceService` assigns this to the car's Sound and then checks the id
	-- is non-empty before playing, so blanking this line ships a silent
	-- patrol exactly as before rather than an error.
	SIREN = "rbxassetid://9117810961", -- Police Siren Slow Vehicle Away 2, 11.22s

	-- ---------------------------------------------------------------
	-- THE PLACEHOLDER PASS, September 2026.
	-- ---------------------------------------------------------------
	--
	-- Nine actions had no sound at all: throwing a gadget, landing one on
	-- somebody, the patrol siren, an event starting, the last seconds of the
	-- countdown, a nab, a slice of the crack, a fence snag, and the crate
	-- reel. Every id below is Pro Sound Effects, every one was built as a
	-- Sound and read back before it was written down, and the length beside
	-- each is measured rather than copied from its store page.
	--
	-- THEY ARE EXPLICITLY PLACEHOLDERS AND THAT IS A DECISION RATHER THAN AN
	-- APOLOGY. Nothing here has been LISTENED to -- nothing in this
	-- toolchain can hear -- so what is verified is that each id resolves and
	-- plays, never that it sounds right. The one time measurement caught a
	-- bad audio choice in this project it caught it only because a BMX went
	-- completely silent; a recording that is merely WRONG passes every check
	-- available here. Swapping any of them is one line and needs no other
	-- change.
	--
	-- AND THE CATEGORY THAT HAS NO GOOD ANSWER IS UI CUES, which is worth
	-- writing down because the next person will search for one. Pro Sound
	-- Effects is a FIELD RECORDING library: it has no beeps, chimes or
	-- interface blips in it, and the Creator Store's supply of those is
	-- overwhelmingly ripped -- a search for a clock tick returns four
	-- results labelled "From Limbus Company". So the cues below are all
	-- PHYSICAL EVENTS standing in for interface sounds: a real switch for a
	-- tick, a real electrical arc for a shock, a real table impact for a
	-- catch. That is why they are defensible as placeholders and it is also
	-- their main weakness.

	-- Throwing and landing. The whoosh is a swish and the hit is a wet
	-- spurt -- comedic rather than violent, which is the register
	-- `Config.NOTIFY.prank` already sets for the one thing done TO you that
	-- costs you nothing.
	GADGET_THROW = "rbxassetid://9120742716", -- Whoosh Thick Quick 2, 0.54s
	GADGET_HIT = "rbxassetid://9120628915",   -- Web Shoot Juicy Spurt 4, 0.81s

	-- The nab: a short blunt impact, no snarl and no crunch. A nab is a
	-- hand on a bag rather than a hit, and this is the one cue in the set
	-- played on a CHILD being caught by another child -- so it is the one
	-- where the register matters most.
	NAB = "rbxassetid://9119912427", -- Table Impact Drop Leg 1, 0.65s

	-- The fence. A real electrical arc, and it fires only on tiers that
	-- actually shock -- the same `stun > 0` test that decides whether a
	-- crossing throws you off, so a rickety fence stays silent because a
	-- rickety fence does nothing.
	FENCE_ZAP = "rbxassetid://9116279560", -- Lightning Burst 56, 0.79s

	-- An event starting. A single-note klaxon rather than the 3.3s version,
	-- because this lands UNDER the banner's own twenty-second warning and a
	-- long alarm would still be going when the reader has finished reading.
	EVENT_ALARM = "rbxassetid://9118805665", -- Sci Fi Klaxon 2, single note, 1.74s

	-- ONE CLICK, THREE JOBS, and the sharing is deliberate rather than
	-- thrift. A crack slice landing, a countdown second passing and a crate
	-- reel tile going by are all THE SAME OBJECT -- a mechanical detent --
	-- which is the one condition under which this project's shared-recording
	-- trick has ever worked: the BMX and the scrambler share a tyre because
	-- they genuinely have the same part, and the bike and the skateboard did
	-- NOT share a roll because they do not. Pitch and volume separate the
	-- three at the call sites.
	--
	-- 0.41s IS WHY THIS ONE AND NOT THE OTHER CANDIDATE. A 1.68s car-switch
	-- recording measured alongside it contains a toggle ON and a toggle OFF,
	-- so at one tick a second the tail of each click would land under the
	-- head of the next.
	CLICK = "rbxassetid://9116363186", -- Mack Truck light switch, 0.41s
}

-- ============================================================
-- MUSIC
-- ============================================================
--
-- APM MUSIC, which is to music what Pro Sound Effects is to the rest of this
-- file: a real production-music library that Roblox licensed wholesale, on
-- the Creator Store under `APMOfficial` and tagged "Courtesy of APM Music".
-- Every id below is verified loading, with the length it reported.
--
-- The alternative on the Creator Store is `DistrokidOfficial` -- artists'
-- released songs opted in through DistroKid. Legal, and wrong for this:
-- those are SONGS, with vocals, uneven mastering and unpredictable content
-- for an under-12 audience. Production music is written to sit underneath
-- something, which is the entire job here. Everything else on the store is
-- the usual trap -- "free" means costing no Robux, not cleared -- and music
-- is the worst category for it, since that is where the ripped uploads are.
--
-- The tone is not a coincidence. Searching APM for comedy and caper cues
-- lands on exactly the genre a game about robbing a neighbour's piggy bank
-- wants: light, jaunty, cartoon-heist. A track called "Kitsch Comedy" is
-- doing more work here than a well-produced track that thinks the game is
-- serious.
Config.MUSIC = {
	-- Well under the effects. Music is the bed; the siren, the dog and the
	-- ride are the things that have to be heard OVER it.
	VOLUME = 0.18,
	FADE = 2.0,

	-- THE SILENCE IS THE FEATURE, and it is why the tracks are long.
	--
	-- Nobody has ever been driven mad by a game that goes quiet; everybody
	-- has been driven mad by a forty-five second loop. So a track plays
	-- ONCE, then the street is quiet for a minute or two, then a different
	-- one plays. Six tracks at 90-170 seconds against gaps of 55-110 puts
	-- the earliest possible repeat about twenty minutes out.
	GAP = { 55, 110 },

	-- Nothing at all for the first stretch after joining. A player who has
	-- just loaded in is reading a HUD, not listening to an overture.
	START_DELAY = 14,

	-- What is left of the music while something is actually speaking. The
	-- patrol is PUBLISHED on purpose -- fifteen seconds of siren before the
	-- car appears, so robbing during one is a choice rather than bad luck --
	-- and music that covers that quietly undoes the design.
	DUCK = 0.22,
	DUCK_FADE = 0.4,

	-- A mute is a button press and has to feel like one; the musical fade is
	-- four times slower and left the score audible for about five seconds
	-- after the press. RESUME_DELAY is the other half of the same idea: long
	-- enough not to slam a cue in on the press, short enough that the button
	-- plainly did something.
	OFF_FADE = 0.5,
	RESUME_DELAY = 2.5,

	TRACKS = {
		{ id = "rbxassetid://1845448393", name = "Kitsch Comedy" },     -- 108.0s
		{ id = "rbxassetid://1836298044", name = "Comedy Situation" },  -- 105.1s
		{ id = "rbxassetid://1839278197", name = "Jaunty Twist" },      --  91.6s
		{ id = "rbxassetid://1839278525", name = "Lucky Twist" },       --  91.4s
		{ id = "rbxassetid://1845270155", name = "Happy Go Lucky" },    -- 113.4s
		{ id = "rbxassetid://1848359977", name = "LA Express" },        -- 171.9s
	},
}

-- ============================================================
-- THE HEIST
-- ============================================================
--
-- Every number below exists to stop one specific failure: a strong player
-- parking on a weak player's plot and farming them until they quit. They are
-- caps, not discouragements -- the griefing case has to be impossible, not
-- merely unrewarding.

-- Fraction of the victim's piggy bank taken per successful grab.
--
-- 8%, up from 5% in the robbing pivot. The pig is the whole wallet now, so
-- this reads against everything the victim has rather than against a pile
-- they were about to bank -- and what the THIEF gets is this times
-- HEIST_PAYOUT below, which is where most of the incentive actually lives.
Config.STEAL_FRACTION = 0.08

-- STOLEN COINS COUNT DOUBLE. The thief banks the haul times this; the extra
-- is minted by the game, not taken from the victim.
--
-- This is the lever of the whole pivot. While the thief's gain and the
-- victim's loss were the same number, every point of incentive was a point of
-- pain, so the reward could never be raised without the game becoming a
-- bullying simulator. Decoupled, robbing is the best earning rate on the
-- street and being robbed is still a few minutes of income. Bail, the rap
-- sheet and totalStolen all measure what the VICTIM lost, never this figure.
Config.HEIST_PAYOUT = 2

-- WHAT A VICTIM CAN LOSE IN AN HOUR, whoever is robbing them.
--
-- This replaces "banked coins are untouchable" as the rule that keeps a
-- robbery survivable. Tracked PER VICTIM and never per thief: a per-thief cap
-- is no protection when seven of them take turns. The fraction is measured
-- against what the victim had at the start of the window (their current
-- balance plus what has already been taken), so a pig cannot be emptied by
-- inches. The refusal names it, because a cap the thief cannot see reads as
-- stealing being broken.
--
-- 45% AND NOT 25%, AND THE NUMBER IS SOLVED OUT OF `Bigger Sack` RATHER THAN
-- CHOSEN. At 25% this cap was quietly gutting an entire upgrade rung. A clean
-- five-slice run scales with the sack, so measured against the live curves it
-- runs 21.9 / 26.8 / 31.7 / 36.7 / 41.6 per cent across the five levels -- and
-- every rung above the first was PARTLY REFUNDED TO THE VICTIM, with a maxed
-- sack losing 40% of what it asked for. A player could buy four levels of
-- "Take more coins per grab" and watch three of them do nothing to a real
-- person. Same family as the Tiptoe rung that sat on disk describing an
-- upgrade that did not exist: a thing bought with coins that is silently not
-- paid, with nothing in any log to say so.
--
-- 45% clears the top of that ladder by 3.4 points, so every rung now pays in
-- full against a player exactly as it already did against a resident. THE
-- CEILING IS THEREFORE THE SACK'S RUNG COUNT, which is the same derivation
-- `TIPTOE.max` and `Config.CASING` already use -- if the sack ever grows a
-- fifth level this has to be re-solved rather than left to bind again.
--
-- WHAT IT STILL BUYS IS THE THING IT WAS WRITTEN FOR, and that is why it went
-- up rather than away. `STEAL_COOLDOWN` is per THIEF per victim, so seven
-- players can rob one child seven times in a minute: measured, uncapped that
-- leaves them 2.3% of their pig at a maxed sack and 17.7% at a bare one. The
-- cap holds it to 45% however many people take turns.
--
-- AND IT BOUNDS THE AUTOMATED PATH, WHICH IS THE SHARPER OF THE TWO now that
-- residents rob players. `HeistService.residentTake` goes through the same
-- `lossAllowance`, so without this a row of neighbours strips a pig 20% at a
-- time on a loop, with nobody choosing to do it -- a child logs off rich and
-- comes back poor having been robbed by robots. Since the pivot merged
-- `vault` into `coins` there is no safe pool behind this any more: it is the
-- only bound left on what a real person can lose.
Config.LOSS_CAP = {
	fraction = 0.45,
	window = 60 * 60,
}

-- REVENGE PAYS TRIPLE. Robbing somebody who robbed YOU inside `window` pays
-- `payout` times the haul instead of HEIST_PAYOUT, and `loot` extra on top.
--
-- One table, because the marker over the thief's plot lasts exactly `window`
-- too: the picture and the rule are the same number and cannot disagree.
--
-- TEN MINUTES, AND WITHIN ONE SESSION ONLY. The grudge lives in a table keyed
-- on the Player and is dropped when they leave, which is the right scope: a
-- plot is RELEASED when its owner logs off, so nobody is ever robbed while
-- away and there is no grievance waiting for anybody at the start of a
-- session. What this rewards is answering back while the thief is still on
-- the street.
Config.REVENGE = {
	window = 10 * 60,
	payout = 3,
}

-- A ROBBED PIG WEARS A PLASTER for this long. A tell and nothing else: it says
-- "somebody got in here" to the street and costs the victim nothing. The idea
-- it replaced -- losing your HOUSE for being robbed too much -- was rejected
-- because losing permanent progress is the one thing every big game on the
-- platform protects, and for this audience it is an uninstall.
Config.ROBBED_MARK_SECONDS = 5 * 60
Config.PLOT_ROBBED_ATTRIBUTE = "RobbedUntil"

-- How close a thief must be to the victim's piggy to start a grab.
-- HOW CLOSE YOU HAVE TO BE TO BANK YOUR OWN COINS.
--
-- It was 16, hardcoded in PiggyBank, and the piggy's Body is 12 across -- so
-- the prompt reached TEN STUDS past its own surface and an owner could bank
-- from a third of the way across their lawn, before they had visibly arrived
-- at the thing they were banking into.
--
-- 9 puts it 3 studs off the surface: close enough that you are standing at
-- the piggy, far enough that you do not have to be inside it. Deliberately
-- TIGHTER than STEAL_RANGE below, which is the one relation here that means
-- something -- an owner walking to their own piggy should not get the prompt
-- from further out than a thief needs to reach it.
-- `COLLECT_RANGE` WAS HERE. There is no collect prompt since the pivot: the
-- pig is the wallet and nothing is banked. The note above is kept because the
-- relation it describes -- an owner should never reach their own piggy from
-- further out than a thief -- would apply to anything that ever replaced it.

Config.STEAL_RANGE = 11

-- Per-victim limits. Both are per thief, so a popular target isn't drained
-- by one determined attacker.
--
-- THIS IS THE PLAYER FIGURE. A resident carries its own, shorter one -- see
-- `RESIDENTS.stealCooldown` for why a protection a child needs is not a
-- protection an empty house needs, and `Config.stealCooldownFor` for the one
-- place that chooses between them.
Config.STEAL_COOLDOWN = 60

-- `STEAL_MAX_PER_VICTIM` WAS HERE AND IS RETIRED. It was 3: a lifetime cap on
-- how many times one thief could ever rob one victim in a session, on top of
-- the 60-second cooldown. Two things were wrong with it. It is the only limit
-- in this game a player could permanently EXHAUST -- in an eight-player server
-- that is 21 robberies and then the offence tree has nothing left to point at,
-- which is the "every session is identical" fault that session events exist to
-- fix, arriving from the other direction. And it could not be read from
-- outside: a cooldown counts down and a cap simply says no, forever, with the
-- refusal the only place it was ever mentioned.
--
-- The cooldown does the anti-camping job on its own. It always did the part
-- that mattered -- a thief standing on one lawn is earning nothing for 60
-- seconds, and the getaway is 53 studs each way.

-- Grace period on a player's FIRST EVER SESSION, and now a CEILING rather
-- than a duration -- see `HeistService.dropShield`.
--
-- THE SHIELD ENDS WHEN YOU COMMIT YOUR FIRST ROBBERY. *Nobody can touch your
-- piggy until you take somebody else's* is one sentence carrying the rule,
-- the theme and the trade at once; the player chooses when it ends; and it
-- self-clears with no new save field.
--
-- IT WAS TEN MINUTES AGAINST SESSIONS THAT RUN FIFTEEN TO TWENTY-FIVE, which
-- meant a player's entire first session had the emotional half of this game
-- switched off. They never got robbed, so they never learned that being
-- robbed is survivable, never felt the grievance the revenge window is built
-- to create, and never learned this is a PvP game at all -- they learned it
-- was an idle game, and then got robbed on session two and experienced it as
-- a betrayal of what they had been taught. That is the same argument that
-- already took JOIN_SHIELD down from fifteen minutes, applied to the one
-- session where it matters most.
--
-- Two minutes is what is left for a player who never robs anybody: long
-- enough to find the controls, short enough that the street is real before
-- they log off.
Config.NEW_PLAYER_SHIELD = 120

-- Grace period on every LATER join. Ninety seconds, down from fifteen minutes
-- for everybody: on a game whose sessions run fifteen to twenty-five minutes,
-- a fifteen-minute shield per join meant about half of any server could not
-- be robbed at any moment, which read exactly like robbing being broken.
Config.JOIN_SHIELD = 90

-- Carrying is slow and obvious. This is the entire risk half of the trade.
Config.CARRY_SPEED_MULTIPLIER = 0.75
Config.BASE_WALK_SPEED = 16

-- NABBING A THIEF: anyone nearby can do it, including bystanders.
--
-- IT IS CALLED A NAB BECAUSE "TAG" WAS FOUR WORDS AT ONCE AND NAMED THE WRONG
-- HALF OF THE ACTION. Inside this project alone it already meant a
-- `CollectionService` tag, the character `Nametag`, and the plot sign -- and
-- `HeistService.nab` is also what the guard dog calls, so the one word covered
-- a player pressing a prompt and a dog catching somebody. It also named the
-- TOUCH rather than the OUTCOME, which is the opposite of every other prompt
-- in this game: `BANK COINS`, `OPEN IT`, `RECOVER`, `STEAL`.
--
-- The words that were ruled out are worth keeping, because each is taken by
-- something this game already does: `snag` is the fence penalty, `catch` is
-- `DOG_TIERS.catchRadius`, `bust`/`BUSTED` is the arrest scene's stamp, and
-- `collar` is the guard-duty tell. And `tackle`/`takedown` are refused for the
-- audience for the same reason the officer carries no baton -- Roblox's
-- maturity questionnaire is answered by what is literally in the model, and a
-- verb describing violence is that same decision made in text.
--
-- WHAT IS STILL WRONG WITH IT, AND IS THE NEXT THING TO FIX: this is a 0.4
-- second hold with exactly two outcomes -- all the coins or none -- paying the
-- person who presses it nothing at all. It is the terminal action of the
-- entire defence half of the game and it is what a STEAL used to be before
-- `Config.CRACK` turned that into a decision. See `docs/MASTER-PLAN.md`; the
-- rename is step one of three and the fields below grow with it.
Config.NAB = {
	-- A hold rather than a touch, and it is measured against
	-- `Config.DODGE.immunity` (0.5) rather than chosen: a dodge has to be able
	-- to beat it outright, so that eating one costs the nabber the whole hold
	-- and they have to start again. That is a real read-and-counter and it is
	-- currently invisible to both players.
	hold = 0.4,

	-- The prompt's reach. Generous on purpose: this is the only prompt in the
	-- game welded to a MOVING target, pressed by somebody who is also running,
	-- by an audience mostly on tablets. `HeistService` re-checks it
	-- server-side with slack on top, because the prompt's range is a client
	-- hint.
	distance = 14,

	-- ------------------------------------------------------------------
	-- THE TUG. A NAB WAS 100/0 AND IS A DECISION ON BOTH SIDES NOW.
	-- ------------------------------------------------------------------
	--
	-- The crack turned a steal from a transaction into a decision and that
	-- surgery was performed on the THIEF and on nobody else. Measured against
	-- the old nab, the defender's half of the same robbery was: one 0.4s
	-- hold, two outcomes, no decision, and it paid them NOTHING. Everything
	-- the crack was built to fix applied word for word to the terminal action
	-- of the entire defence half of the game.
	--
	-- Coins now flow back PER TICK while somebody holds the prompt. Let go,
	-- lose them, or get dodged, and you keep what has already come home.

	-- How often a slice goes back. Five ticks a second: fast enough that the
	-- figure over the thief's head visibly falls rather than stepping, slow
	-- enough that a full recovery is several distinct events rather than one.
	tickRate = 0.2,

	-- HOW LONG A CLEAN RECOVERY TAKES, AND IT IS MEASURED AGAINST THE
	-- GETAWAY RATHER THAN CHOSEN.
	--
	-- The shortest run home is 53 studs at carry speed, about 4.4 seconds. A
	-- tug that recovered everything in a fifth of that would be the old
	-- binary nab with extra frames; one that took most of the run would make
	-- a single nabber a hard stop, which is the wall this design refuses
	-- everywhere else. One second is a fifth of the getaway: long enough to
	-- contain a decision, short enough that two children are not standing
	-- still in a game about movement.
	recoverSeconds = 1.0,

	-- WHAT THE NABBER EARNS, MINTED, AND THE EXPLOIT CLOSES ITSELF.
	--
	-- Minted rather than taken from the victim, for the reason
	-- `HEIST_PAYOUT` is 2: a rescue fee deducted from the person being
	-- rescued is "every point of incentive is a point of pain" with the sign
	-- flipped. It overflows capacity like a DELIVERY rather than being
	-- refused like a sale -- a sale is a trade the player chose and a bounty
	-- arrives because somebody else robbed somebody.
	--
	-- ANY VALUE BELOW `HEIST_PAYOUT` MAKES A STAGED ROBBERY STRICTLY WORSE
	-- THAN SIMPLY DELIVERING IT. Two friends farming this -- A robs B, C nabs
	-- A, repeat -- give up the haul times 2.0 to gain the haul times this
	-- number. At 0.25 that is an eight-to-one loss before the stun and the
	-- broken spree. The exploit is closed by arithmetic rather than by a
	-- check, which is the only kind that cannot be forgotten.
	bounty = 0.25,

	-- SPLIT AMONG WHOEVER TOOK PART, NEVER MULTIPLIED. One fee per robbery
	-- divided by the crowd, so piling on stops being individually profitable
	-- without anybody being refused. Paid per tick to whoever is holding at
	-- that tick, so somebody who joins late earns from the moment they join
	-- and no earlier.

	-- THE PER-THIEF REST, AND IT IS THE LOAD-BEARING HALF OF ALL OF THIS.
	--
	-- Measured off the live numbers: a thief carries at 12 and a free
	-- bystander runs at 16, so a chaser closes 4 studs a second over a
	-- 4.42-second getaway -- which means a bystander starting up to THIRTY
	-- STUDS BEHIND still gets inside `distance` with `hold` to spare. A thief
	-- has exactly one dodge per run (`DODGE.cooldown` is 5s against a 4.4s
	-- getaway), so against n chasers one dodge loses to n - 1 of them.
	--
	-- SHIPPING THE BOUNTY WITHOUT THIS MAKES ROBBING HARDER AND GIVES
	-- NOTHING BACK. It is the same shape as one wheelie bin per pursuit and
	-- `STEAL_COOLDOWN` per thief per victim: the rest is on the PERSON BEING
	-- ACTED ON, so the bound on what an entire street can do to one child is
	-- the same bound as one player on their own.
	--
	-- THE INVARIANT, MEASURED AND WRITTEN DOWN RATHER THAN LEFT AS A TUNING
	-- PASS: NO COMBINATION OF BYSTANDERS MAY REDUCE A WELL-PLAYED ROBBERY TO
	-- UNWINNABLE.
	--
	--     tug duty cycle = recoverSeconds / (recoverSeconds + cooldown)
	--
	-- At 1.0 and 3.0 that is 25%: a thief can be under a tug for at most a
	-- QUARTER of any stretch of time, however many people are holding, because
	-- the rest is on the thief rather than on the nabber. Eight players cannot
	-- do more to one child than one player can.
	--
	-- Raising `recoverSeconds` or lowering this number raises that fraction,
	-- and the two multiply -- which is the shape of mistake this file records
	-- more than any other. `LOSS_CAP` x `HEIST_PAYOUT`, capacity x income, a
	-- resident's pig x a capacity ladder: two curves tuned in separate sessions
	-- and never multiplied together, found months later by somebody happening
	-- to measure.
	cooldown = 3.0,
}
-- HOW CLOSE AN OWNER HAS TO GET TO THEIR OWN LOCK TO BREAK UP A ROBBERY.
--
-- Wider than `STEAL_RANGE` (11) on purpose: the thief is already standing at
-- the pig, so a range equal to theirs would mean the owner has to be close
-- enough to touch them. 16 is arriving on the lawn rather than winning a
-- wrestling match, which is what "being home means something" should feel
-- like -- and it is still well inside the 64-stud plot, so an owner standing
-- at their own gate does not passively suppress every robbery on the lawn.
--
-- IT IS THE OWNER'S ONLY DEFENCE WHILE THEY ARE HOME, which is what sizes it.
-- `releaseDog` stands the dog down for a present owner -- two hard stops on
-- one lawn is how a plot becomes a wall -- so this replaces the dog rather
-- than stacking on it.
Config.OWNER_INTERRUPT_RANGE = 16

-- ============================================================
-- THE GATE JAM
-- ============================================================
--
-- THE OWNER-LOCKED GATE WAS PROPOSED AND REFUSED, AND THIS IS THE
-- INVERSION THAT SURVIVED.
--
-- Locking your own gate fails three ways: it contradicts the rule that the
-- gate is always open at every tier (24 studs at Rickety and still 8 at the
-- Moat), it does nothing about a camping owner who is already standing on
-- the lawn, and it is defence stacking on the one plot that already has a
-- defender in it. What is salvageable is the same idea pointed the other
-- way: let the THIEF jam it, behind them, on the way out.
--
-- THAT PUTS IT WHERE THIS DESIGN ACTUALLY WANTS PRESSURE -- the getaway,
-- where every other cost in this game already lands.
--
-- A PROMPT ON THE GATE RATHER THAN A HOT BAR SLOT. The number row is full
-- at ten, the eleventh consumable already had to take a letter, and there
-- are fewer letters left than it looks. A prompt costs no slot and
-- `Config.PROMPTS` is already the vocabulary for giving one a colour, a
-- glyph and a verb.
Config.GATE_JAM = {
	-- Coins every use, like every other counter in this game. A consumable
	-- whose abuse would matter needs a price AND a clock, but this one has a
	-- natural clock already: it is only reachable while carrying, and a
	-- carry lasts seconds.
	cost = 2500,

	-- TWO TO THREE SECONDS, AND THE GETAWAY IS WHAT SETS IT.
	--
	-- The run home is 53 studs at carry speed, about 4.4 seconds. A jam that
	-- lasted five would cover essentially the whole getaway and delete the
	-- defence; two to three breaks the line without erasing the run. Same
	-- rule as the wheelie bin, which is sold on buying a BREATH rather than
	-- an escape.
	seconds = 2.5,

	-- WHAT CROSSING A JAMMED GATE COSTS, and it is a SNAG rather than a
	-- wall.
	--
	-- A solid part would be the honest picture and it cannot have the one
	-- property this needs: a `CanCollide` gate blocks EVERYBODY, including
	-- the owner, and shutting a child out of their own garden is precisely
	-- the griefing case this feature has to be unable to produce. Roblox
	-- collision groups are per PART rather than per player, so there is no
	-- arrangement of one part that stops a chaser and admits an owner.
	--
	-- A penalty volume can ask who is crossing. So the gate stays passable
	-- and passing it costs you, which is the same instrument the fences
	-- already use and lands in the same place: `HeistService.applyFencePenalty`
	-- via `PlotService.onFencePenalty`, so a jam and a fence cannot drift
	-- apart in how they slow somebody.
	--
	-- SIZED AGAINST WHAT A CHASER ACTUALLY GAINS, AND THE FIRST NUMBERS WERE
	-- WRONG BY A FACTOR OF TWO AND A HALF.
	--
	-- 0.35 for 2.0s reads modest and is not: a chaser held at 5.6 instead of
	-- 16 for two seconds loses 20.8 STUDS. Over the whole 4.42-second getaway
	-- a free chaser only closes 4 studs a second on a carrying thief -- 17.7
	-- studs in total -- so one jam did not slow the chase down, it deleted it
	-- outright and handed back more ground than the chaser could ever make up.
	--
	-- That is the wheelie bin's own rule broken: a counter here BUYS A BREATH
	-- AND NEVER AN ESCAPE. The bin's exit burst is deliberately worth about one
	-- dodge, 4.8 studs, for exactly this reason.
	--
	-- At 0.55 for 1.2s a crossing costs 8.6 studs -- about half what a chaser
	-- gains over a full getaway, so it is a real setback that still leaves the
	-- chase winnable. Two curves multiplied without anybody checking the
	-- product is the mistake this file records more than any other, and this
	-- one was caught by measuring rather than by playing.
	slow = 0.55,
	duration = 1.2,
}

Config.STUN_SECONDS = 4

-- How close a thief must get to their own piggy to deliver the loot.
--
-- Sized against PLOT_SPACING deliberately. STEAL_RANGE + DROPOFF_RADIUS must
-- stay well under the spacing, or a thief could stand in their own drop-off
-- zone and rob a neighbour without ever running -- and the run is the entire
-- risk half of the trade. At 11 + 9 against a spacing of 80 the shortest
-- possible getaway is 60 studs, about 5.0 seconds at carry speed -- it was 37
-- studs before the plot was widened and 53 while arriving was the whole of
-- delivering, and this is the number that moved with both.
--
-- SO THIS IS THE LEVER IF ROBBING EVER READS AS TOO HARD. A drop-off radius is
-- a fraction of your own plot rather than an absolute distance, so it can grow
-- with the plot and hand the run back without touching PLOT_SPACING, which the
-- alley and the row length both depend on.
--
-- IT WENT 16 -> 9 WHEN ARRIVING STOPPED BEING DELIVERING, AND THE TWO HALVES
-- OF THAT ARE WORTH SEPARATING because only one of them is a balance change.
--
-- The ACTION changed: a thief used to cross an invisible sixteen-stud circle
-- and the coins banked themselves, and now they walk up to the pig and press
-- DELIVER. That is the loop closing -- the pig is the wallet, so the wallet is
-- where money goes -- and it is the same rule a neighbour now obeys, so the
-- street reads one way for both. It also makes a silent state change into a
-- thing a nine-year-old can see.
--
-- The DISTANCE is the balance change and it was measured before it was made.
-- `robberyCycleSeconds` derives the run from this constant, so shrinking it
-- lengthens every getaway in the game and drops the audited advantage:
--
--     reach   run   cycle    worst advantage (8 players, cold)
--       16    53    21.23s        3.37x
--        9    60    22.25s        3.22x
--        0    69    23.56s        3.04x     <- floor is 3.00
--
-- NINE RATHER THAN ZERO, AND THAT IS THE WHOLE REASON THERE IS STILL A RADIUS
-- AT ALL. Requiring a thief to actually touch the pig spends the entire audit
-- margin: 3.04x against a `ROBBERY_ADVANTAGE.min` of 3.0 is one per cent of
-- headroom on the invariant that says perfect robbing must beat standing
-- still. Nine studs is three studs off a twelve-stud pig's surface -- close
-- enough that a player is unambiguously AT it, which is the thing the change
-- was for -- and it keeps seven per cent. It is also exactly what the retired
-- `COLLECT_RANGE` was, and for the same reason: that one was deliberately
-- tighter than `STEAL_RANGE` so an owner could not reach their own pig from
-- further out than a thief needs to.
Config.DROPOFF_RADIUS = 9

-- How many coin discs make up a full piggy. Income and capacity scale
-- together, so a coin lands roughly every 15 seconds at every level -- the
-- drip cadence stays constant as you upgrade, which is what makes it feel
-- like a heartbeat rather than a progress bar.
Config.COIN_COUNT = 32

-- ============================================================
-- DEFENCE AND OFFENCE
-- ============================================================
--
-- The design pillar the whole game hangs on: a coin spent on one tree is
-- gone from the other. Nobody can buy both. Within a week players sort
-- themselves into turtles and bandits, argue about which is better, and have
-- a reason to keep playing that isn't a bigger number.
--
-- So these are priced against each other, not against income. If one tree is
-- clearly better value the identity split collapses and everyone builds the
-- same thing.

Config.UPGRADES = {
	locks = {
		tree = "defense", order = 1, name = "Vault Lock", max = 4,
		baseCost = 1800, growth = 2.1,
		blurb = "Thieves need longer to crack your piggy",
	},
	fences = {
		tree = "defense", order = 2, name = "Fence", max = 5,
		baseCost = 2600, growth = 2.4,
		blurb = "Slower and nastier to climb over",
	},
	dog = {
		tree = "defense", order = 3, name = "Guard Dog", max = 3,
		baseCost = 5000, growth = 2.6,
		blurb = "Chases thieves and nabs them for you",
	},
	lockpicks = {
		tree = "offense", order = 1, name = "Lockpicks", max = 4,
		baseCost = 1800, growth = 2.1,
		blurb = "Crack piggies faster",
	},
	sack = {
		tree = "offense", order = 2, name = "Bigger Sack", max = 4,
		baseCost = 2600, growth = 2.4,
		blurb = "Take more coins per grab",
	},
	boots = {
		tree = "offense", order = 3, name = "Speed Boots", max = 4,
		baseCost = 3400, growth = 2.3,
		blurb = "Run faster while carrying stolen goods",
	},
	-- SNEAKERS ARE BOUGHT LAST, AND THE PRICE SAYS WHY. A tiptoe at `base`
	-- (5.6) is already under Scruffy's `notice` of 11 and Rex's 10.2, and a
	-- MAXED one (9.6) is still nothing to a Titan's 0 -- so this rung buys no
	-- access to anything. What it buys is CROSSING THE SAME LAWN IN LESS
	-- TIME, 5.6 to 9.6, a 71% faster approach, and time on a lawn is the
	-- window in which an owner comes home, a patrol arrives, or somebody
	-- else's noise wakes the dog you were being careful about.
	--
	-- That is refinement rather than a new capability, which is what a LAST
	-- rung is everywhere else in this game, so it carries the highest base
	-- cost in its tree and the ascending ladder is preserved. `max` is 4
	-- because that is exactly what `TIPTOE.base + 4 x perLevel` needs to
	-- reach `TIPTOE.max`; the rung count is derived from the stat rather
	-- than chosen, so retuning the stat cannot silently strand a rung.
	--
	-- It sits beside Speed Boots on purpose: one pair of shoes for getting
	-- IN quietly and one for getting OUT quickly, which is the trade this
	-- whole tree is about.
	tiptoe = {
		tree = "offense", order = 4, name = "Sneakers", max = 4,
		baseCost = 4200, growth = 2.2,
		blurb = "Cross a lawn quicker while sneaking",
	},
}

function Config.getUpgradeCost(key: string, currentLevel: number): number
	local def = Config.UPGRADES[key]
	if not def then
		return math.huge
	end
	return math.floor(def.baseCost * (def.growth ^ currentLevel))
end

-- LOCKS AND LOCKPICKS ARE STILL THE SAME AXIS PULLED FROM BOTH ENDS, AND IT
-- IS NO LONGER A DURATION. `Config.STEAL_HOLD` and `getStealHold` used to
-- live here and turned those two trees into how many seconds somebody stood
-- still; `Config.getCrackWindow` turns them into how wide the target is.
--
-- Retired rather than left standing, because a function nothing calls is a
-- second answer to a question this game now answers somewhere else -- and the
-- next person to want "how hard is this lock" would have found two.

function Config.getStealFraction(thiefSack: number): number
	return Config.STEAL_FRACTION + thiefSack * 0.018
end

-- Caps at 1.0: boots cancel the carry penalty, they never make you faster
-- than everyone chasing you.
function Config.getCarryMultiplier(thiefBoots: number): number
	return math.min(1, Config.CARRY_SPEED_MULTIPLIER + thiefBoots * 0.065)
end

-- ============================================================
-- CRACKING A PIG -- THE GREED DIAL
-- ============================================================
--
-- LIVE. `HeistService` owns the attempt and every decision in it -- which
-- slice, which zone, hit or miss -- and `Shared/Crack.luau` draws it. The
-- client is told the schedule and reports a TAP carrying no claim about
-- whether it landed; the server reads its own clock and decides. That is the
-- same split the bone throw and the ladder already make, arriving at the one
-- place in this game where a player's timing is worth money.
--
-- WHAT IT REPLACES: a single fixed hold that took a single fixed
-- STEAL_FRACTION. That is a transaction, and a transaction performed forty
-- times an hour is the reason a robbery feels the same every time. The hold
-- is also the one moment in this game where the game switches itself off --
-- every tuned number here is a SPEED, and the central action is standing
-- still.
--
-- WHAT IT IS: the crack is a sequence of steps. Each step landed banks
-- another SLICE of the victim's pig and the window for the next one shrinks.
-- The thief walks away whenever they like and keeps what they have already
-- banked; a miss ends the attempt and they still keep it. So the mechanic is
-- push-your-luck rather than a checklist, and it is the first thing in this
-- design that can produce a PARTIAL OUTCOME -- "I bailed at three because
-- the dog turned round" -- which is what makes a repeated action generate
-- stories instead of receipts.
--
-- THE SLICES GROW, WHICH IS THE ENTIRE REASON TO STAY. A flat slice makes
-- the last step worth exactly as much as the first, so there is no
-- temptation and no decision; the whole mechanic collapses back into a hold
-- with extra taps. Growing, the step you are deciding about is always the
-- most valuable one you have been offered.
Config.CRACK = {
	-- Fraction of the victim's pig banked by the FIRST step landed.
	--
	-- Deliberately tiny. This is the "take the minimum for the least action"
	-- end of the dial: one quick tap, two per cent, gone before anybody has
	-- crossed the lawn. It has to be worth doing or a cautious player has no
	-- move at all, and it has to be small or nobody ever gambles.
	baseSlice = 0.02,

	-- Each further slice is worth this much more than the one before.
	stepGrowth = 1.4,

	-- How many slices a pig can give up in one attempt.
	--
	-- FIVE, AND THE ARITHMETIC PICKED IT rather than taste. The slices run
	-- 2.0, 2.8, 3.9, 5.5 and 7.7 per cent, so a clean run takes 21.9% at a
	-- bare sack and 41.6% at a maxed one -- which is what `LOSS_CAP` is now
	-- solved against, so it is the SACK rather than this step count that sets
	-- the ceiling.
	--
	-- THIS ARGUMENT USED TO RUN THE OTHER WAY AND NO LONGER DOES, which is
	-- worth recording because the number did not move. It read: a clean run
	-- takes 21.9% against a cap of 25%, so a greedy thief empties their whole
	-- hourly allowance in one attempt and no further, and a sixth step would
	-- reach 28.9% and be silently clamped to nothing. Raising the cap to 45%
	-- to stop it gutting Bigger Sack took that reasoning with it: a sixth
	-- step would now FIT.
	--
	-- Five stays on its own merits. The slices grow 1.4x, so a sixth is worth
	-- 10.8% of a pig by itself -- half as much again as the whole base run's
	-- last slice, and the "one rung worth more than everything under it"
	-- shape this file already rejected when Bigger Sack was scaled. The step
	-- count is a pacing decision now rather than a consequence of the cap.
	--
	-- It also calibrates against what this game already does: today's flat
	-- 8% take lands between step three (8.7%) and step two (4.8%). So the
	-- robbery players have now becomes the MIDDLE of the new range rather
	-- than its floor or its ceiling, and nothing about the economy moves
	-- until somebody chooses to be greedy.
	maxSteps = 5,

	-- Seconds to land the first step, and what that window is multiplied by
	-- for each step after it.
	--
	-- 1.8 falling to 0.94 by step five. Sized for a nine-year-old's thumb on
	-- a tablet rather than for a mouse: the last window is still most of a
	-- second, and the pressure is meant to come from the DOG crossing the
	-- lawn behind you, not from reaction time.
	windowStart = 1.8,
	windowDecay = 0.85,

	-- What the victim's Vault Lock and the thief's Lockpicks do to that
	-- window. This IS the lock-versus-lockpick axis now -- the flat hold it
	-- used to be expressed in is retired -- and it is what makes the two
	-- trees feel like they are fighting rather than co-existing.
	lockDecayPenalty = 0.04,
	pickWindowBonus = 0.18,

	-- Floor, so no combination of lock levels can produce a window nobody
	-- could hit. Defence buys TIME, never immunity -- the rule the fences
	-- already live under, arriving at the lock.
	minWindow = 0.55,

	-- How long the marker takes to cross the dial once. The window above is
	-- a WIDTH IN SECONDS, so this is what turns it into a share of the bar:
	-- step one is 1.8 of 2.6, about 69% of the track, and step five is 36%.
	-- Against a maxed Vault Lock the fifth zone clamps to minWindow, which
	-- is 21% -- tight, and still a fifth of the bar rather than a pixel.
	--
	-- The marker PING-PONGS rather than wrapping, so it crosses the zone
	-- twice a period and a missed pass is not a missed step.
	sweepSeconds = 2.6,

	-- THERE IS DELIBERATELY NO CLOCK ON A STEP. A step runs until it is
	-- tapped or the attempt is abandoned, and the comment on windowStart is
	-- what decides that: the pressure is meant to come from the DOG crossing
	-- the lawn behind you, not from reaction time. A second countdown would
	-- put the tension back in the timer and take it out of the street --
	-- which is the fault the flat hold had, wearing a dial.

	-- Slack either side of the zone, in seconds, because the tap crosses the
	-- wire. A tap is judged on the SERVER's clock at the moment it arrives,
	-- so a player on a 90ms link is judged about a tenth of a second later
	-- than they pressed and would lose the trailing edge of every zone they
	-- cut fine. Applied to both edges rather than only the late one: the
	-- most an early tap can buy is a zone it was already aiming at.
	tapGrace = 0.12,

	-- The hold that OPENS the lock, before any of the above.
	--
	-- Short on purpose, and it is the one piece of the old flat hold that
	-- survives. It is not a difficulty gate -- the lock expresses itself in
	-- the windows now -- it is what stops a brushed prompt starting a
	-- robbery, which matters more here than it did before: an attempt now
	-- drops your shield, wakes a dog on a miss and can be walked away from
	-- with nothing.
	openHold = 0.5,
}

-- THE ALARM FIRES ON A FAILED SLICE AND NEVER ON A SUCCESSFUL ROBBERY.
--
-- Today `attemptSteal` pings the victim the instant a steal completes, which
-- is the only moment it COULD fire when a steal is atomic. A crack that
-- happens in slices has five moments to choose from, and the choice decides
-- whether robbing a present player is possible at all: alarm on the first
-- slice and the owner always wins, alarm on completion and the owner can
-- never defend, only chase.
--
-- Alarm on a MISS is the third answer and it is the one that makes skill
-- worth having. A thief who lands every slice takes the coins and the victim
-- finds out from their balance, the plaster and the delivery line; a thief
-- who fumbles brings the whole street down on themselves.
--
-- IT DOES NOT MAKE A CLEAN ROBBERY INVISIBLE, which is the objection to
-- check it against. The thief still carries a labelled miniature of the
-- victim's own pig, still wears a Highlight visible through walls, and can
-- still be nabbed by anybody who spots them. What a silent crack buys is
-- that nobody was TOLD -- it is stealth of the alarm, never stealth of the
-- getaway, and the run home is as public as it ever was.
Config.CRACK_ALARM_ON_MISS = true

-- ============================================================
-- THE SMASH -- THE OTHER WAY IN
-- ============================================================
--
-- ONE PIG, TWO ROBBERIES, AND THE CHOICE IS MADE BEFORE ANYTHING IS TOUCHED.
-- A crack is quiet, slow and greedy: five slices, no alarm unless you fumble,
-- and the Vault Lock fighting you for every one of them. A smash is loud,
-- quick and small: one hold, a fixed take, and the dog and the owner both
-- know about it the instant it lands.
--
-- WHAT IT IS ACTUALLY FOR IS MAKING THE TWO DEFENCE RUNGS POINT AT DIFFERENT
-- ATTACKS, which is the half to protect if any of these numbers ever move. A
-- Vault Lock narrows the crack's windows and does NOTHING to a smash, because
-- there is no lock being picked. A dog is nearly irrelevant to a clean crack
-- -- the alarm only fires on a fumble -- and is the entire cost of a smash.
-- So the two stop being "more defence" and become answers to different
-- questions: a well-locked pig with no dog is soft to a smash, a well-guarded
-- pig with no lock is soft to a crack, and a thief can read BOTH from the
-- pavement, because the dial says one and the kennel says the other.
--
-- THE TAKE IS THE CRACK'S OWN LADDER RATHER THAN A NUMBER OF ITS OWN, and
-- that is what stops the two drifting apart. `getSmashFraction` is exactly
-- `getCrackFraction(SMASH.steps)`, so it inherits `baseSlice`, `stepGrowth`
-- and the Bigger Sack scaling in one expression. A second constant here would
-- be a second description of what a robbery is worth, and this file has paid
-- for that twice already -- `RESIDENTS.pigSeconds` solved against a take that
-- was then replaced, and `SHOP_BANK_PIG_SECONDS` pinned and wrong by 62% on
-- the first boot that audited it.
--
-- SCALING WITH THE SACK IS NOT OPTIONAL. Bigger Sack is sold as "take more
-- coins per grab", and a smash that ignored it would be a rung bought with
-- coins that quietly does nothing for anybody who prefers the loud way in.
-- That is the Tiptoe rung sitting on disk describing an upgrade that did not
-- exist, and the Bigger Sack levels silently refunded by `LOSS_CAP`, arriving
-- a third time.
--
-- ============================================================
-- WHY TWO SLICES AND NOT THREE
-- ============================================================
--
-- A SMASH MUST PAY STRICTLY LESS PER SECOND THAN A CLEAN CRACK, or it is not
-- a choice, it is the answer -- and `auditRobbery`'s entire model rests on the
-- crack being optimal play. It measures `robberyCycleSeconds(maxSteps)` and
-- calls the result an UPPER BOUND on what a thief can earn. A faster way in
-- that paid better per second would make that sentence false with nothing in
-- the audit changing and nothing in any log, which is this project's
-- most-repeated failure exactly: two curves multiplied without anybody
-- checking the product.
--
-- Measured on the live server, at both ends of the sack ladder:
--
--                crack cycle   smash cycle   smash as a share of the rate
--     house         21.23s        9.53s                  49%
--     shop          16.85s        5.15s                  72%
--
-- The share is FLAT across the sack, because both sides scale on the same
-- `sackScale` -- 4.80% against 21.89% at level 0 and 9.12% against 41.59% at
-- level 4 is 0.219 either way. That constancy is the property to keep: a
-- ratio that MOVED would mean no single step count is right for both ends of
-- the game, which is the argument `RESIDENTS.pigSeconds` already turns on.
--
-- Three slices was the tempting answer, because 8.7% is almost exactly the
-- flat 8% take this game shipped with for its whole life and there is a neat
-- story in restoring it as the loud option. The arithmetic refuses it: on a
-- house it is 92% of a clean crack's rate for 45% of the exposure, so nobody
-- would ever crack anything again.
--
-- AND A CLAIM THAT STOOD HERE FOR ONE SESSION WAS SIMPLY FALSE, WHICH IS
-- RECORDED RATHER THAN QUIETLY DELETED because it is this file's own most
-- expensive class. It read: a three-slice smash would push a six-target lap
-- to about 55s against a 60-second `STEAL_COOLDOWN` and break `auditRobbery`'s
-- fourth check. **A LAP IS CYCLE TIME TIMES TARGETS AND CONTAINS NO STEP
-- COUNT AT ALL**, so it is 57.2s at two slices and 57.2s at three, and the
-- step count could never have moved it. The reasoning was written from the
-- shape of the concern rather than from the expression, it was plausible, it
-- named a real check, and it was wrong -- exactly the `gable()` comment and
-- the kennel rotation, caught this time by measuring before anybody believed
-- it. THE RATE ABOVE IS THE WHOLE ARGUMENT FOR TWO SLICES; the lap never
-- had anything to do with it.
--
-- WHAT THE LAP ACTUALLY SAYS IS BETTER NEWS AND IS WORTH KEEPING. At 57.2s
-- against a 60-second cooldown a smash-only thief is COOLDOWN-BOUND: they
-- arrive back at the first pig three seconds early and wait, so their real
-- rate falls to 47% of a clean crack rather than 49%. The mechanic
-- self-limits, and it does so through a number that was already there for
-- other reasons. A shop-only smasher is bound far harder -- four shops lap in
-- 20.6s against the same 60 -- which is what makes the 72% above a best case
-- that cannot be sustained rather than a rate anybody can farm.
--
-- THE SHOP COLUMN IS THE THIN END AND IS THE THING TO WATCH. 72% is a lot
-- closer to 100% than the house's 49%, because a shop's run home is short so
-- the cycle is mostly the hold -- and a shop has no dog and nobody home, so
-- the alarm this path buys costs a thief less there than anywhere else. It
-- stays under the crack at every level and the cooldown does the rest, but if
-- shop smashing ever reads as the only thing worth doing, the lever is
-- `SMASH.hold` rather than `steps`: lengthening the hold moves the cycle
-- without touching the take, so it costs the house nothing.
--
-- SO WHY WOULD ANYBODY SMASH? Three reasons, and not one of them is money:
--
--   * IT CANNOT BE MISSED. A crack is five timing tests, and a maxed Vault
--     Lock clamps the fifth window to `minWindow`. For a nine-year-old the
--     EXPECTED value of a crack on a defended pig is a long way under 21.9%;
--     a smash is 4.8% with certainty.
--   * IT IS OVER. 1.3 seconds standing on somebody's lawn against 13.5, and
--     a dog crossing that lawn is measured in seconds.
--   * THE LOCK DOES NOT APPLY. It is the answer to the one defence that had
--     no answer.
--
-- Everything else about it is worse, which is the trade: a fifth of the
-- coins, the dog awake before you have moved, and the owner told who did it.
Config.SMASH = {
	-- How many of the crack's slices a smash is worth. See above -- this is the
	-- number the whole trade turns on, bounded ABOVE by the crack having to
	-- stay the best rate in the game and BELOW by a smash having to be worth
	-- the alarm it raises.
	steps = 2,

	-- The hold, in seconds.
	--
	-- DERIVED FROM THE DIAL RATHER THAN PICKED, and the sentence it is derived
	-- from is the one a player should end up feeling: A SMASH TAKES LESS TIME
	-- THAN ONE SLICE OF A CRACK. Half a sweep, which is 1.3s today and follows
	-- `sweepSeconds` if the dial is ever re-paced.
	--
	-- It is deliberately LONGER than `CRACK.openHold`, which is the opposite of
	-- what "near-instant" sounds like and is right for the same reason that
	-- hold exists at all. Opening a lock can be walked away from having taken
	-- nothing. A smash cannot: one press drops your shield, empties a fifth of
	-- somebody's pig, wakes their dog and tells them your name. It may never be
	-- startable by a brushed prompt.
	hold = Config.CRACK.sweepSeconds / 2,
}

-- Fraction of the pig a smash takes. One expression, for the reason in
-- `Config.SMASH`: there is only one description of what a robbery is worth.
function Config.getSmashFraction(thiefSack: number): number
	return Config.getCrackFraction(Config.SMASH.steps, thiefSack)
end

-- WHAT THE BIGGER SACK BUYS NOW THAT A TAKE IS A DECISION.
--
-- It used to scale the one flat take, and with the flat take gone it had to
-- land somewhere or a whole rung of the offence tree would have gone inert
-- without anything erring. Two candidates were rejected before this one:
-- more STEPS puts the sixth slice at 10.8% of a pig and the ninth at 29.5%,
-- so one rung would be worth more than the entire base run; and a wider
-- WINDOW is the Lockpicks rung, which already owns that axis.
--
-- So it scales every SLICE, expressed as a ratio against the flat fraction
-- it used to be -- 1.00 at level 0 rising to 1.90 at level 4 -- rather than
-- as a second curve. One definition of what the sack is worth, so moving
-- that curve moves this with it.
--
-- AND IT PAYS OUT ON A RESIDENT AND IS CAPPED AGAINST A CHILD, which falls
-- out of the arithmetic rather than being arranged. A clean five-step run is
-- 21.9% of a pig at level 0 against a LOSS_CAP of 25%, so there is almost no
-- headroom left: a maxed sack asks for 41.6% and a real victim's allowance
-- refuses everything past a quarter. A resident has no cap at all, so the
-- rung pays in full there. The incentive points at the empty house, which is
-- the direction this design needs it to point.
local function sackScale(thiefSack: number): number
	return Config.getStealFraction(thiefSack) / Config.STEAL_FRACTION
end

-- Fraction of the pig banked by landing the `step`-th slice alone, 1-based.
function Config.getCrackSlice(step: number, thiefSack: number): number
	local n = math.floor(step)
	if n < 1 or n > Config.CRACK.maxSteps then
		return 0
	end
	return Config.CRACK.baseSlice * (Config.CRACK.stepGrowth ^ (n - 1)) * sackScale(thiefSack)
end

-- Fraction of the pig banked by landing exactly `steps` slices.
function Config.getCrackFraction(steps: number, thiefSack: number): number
	local total = 0
	for n = 1, math.min(math.max(0, math.floor(steps)), Config.CRACK.maxSteps) do
		total += Config.getCrackSlice(n, thiefSack)
	end
	return total
end

-- What the whole bar is worth if every step lands. The panel draws the pig
-- draining, so this is the number the far end of that gauge represents.
function Config.getCrackTotal(thiefSack: number): number
	return Config.getCrackFraction(Config.CRACK.maxSteps, thiefSack)
end

-- Seconds available to land step `step`, 1-based.
function Config.getCrackWindow(step: number, victimLocks: number, thiefPicks: number): number
	local decay = Config.CRACK.windowDecay - victimLocks * Config.CRACK.lockDecayPenalty
	decay = math.clamp(decay, 0.5, 0.98)
	local window = Config.CRACK.windowStart * (decay ^ math.max(0, step - 1))
	window += thiefPicks * Config.CRACK.pickWindowBonus
	return math.max(Config.CRACK.minWindow, window)
end

-- ============================================================
-- TIPTOE
-- ============================================================
--
-- LIVE. `HeistService.currentSpeed` reads `getTiptoeMultiplier`, the C key
-- and the SNEAK button drive it through `TiptoeRequest`, and it is measured
-- at 5.60 studs a second against a base walk of 16.
--
-- AND `perLevel` AND `max` ARE LIVE TOO, which they were not for a while:
-- they described an upgrade rung that did not exist, and `currentSpeed`
-- passed a hardcoded level 0, so every player tiptoed at `base`. The rung is
-- `Config.UPGRADES.tiptoe` -- Sneakers, on the offence tree -- and the 0 is
-- now `UpgradeService.getLevel(player, "tiptoe")`.
--
-- WHAT THE RUNG DOES NOT BUY IS THE PART TO KEEP STRAIGHT: `base` already
-- clears two of the three breeds and `max` clears none that `base` does not,
-- so a level is a FASTER approach and never a quieter one. Whether sneaking
-- works at all is the DOG's tier to decide, which is why `notice` lives over
-- there and not here.
--
-- AND THE THING IT IS A COUNTER TO IS LIVE NOW. `DOG_TIERS.notice` and
-- `DOG_WATCH` were both unread for a while -- `GuardDog` only reacted to a
-- COMPLETED steal, so a tiptoe was a slower walk that nothing in the game
-- could notice. It shipped in that order on purpose, because a watching dog
-- with no way past it would make a plot un-robbable and defence buys time,
-- never immunity. The bill has arrived: `HeistService` watches every lawn and
-- a sneak is now the difference between a dog that sleeps through you and a
-- dog that comes. Measured on one lawn in one session -- 22 seconds at 5.88
-- studs a second left Scruffy asleep; walking that same lawn at 15.97 brought
-- it out in 2.0 seconds.
--
-- A tiptoe is a MULTIPLIER ON currentSpeed and never a stealth flag, which
-- is the same decision Config.DODGE, the wheelie bin's exit burst and
-- CLIMB_MULTIPLIER each already record. currentSpeed is the one function
-- that owns every speed in this game, so a factor added there inherits all
-- of them with no new balance code: a stun still returns 0 before it is
-- reached, a fence snag still scales it, a ride still refuses it.
--
-- AND THE DOG READS SPEED, NOT A FLAG. That is the load-bearing half. A
-- boolean the dog has to check is a second piece of state that can disagree
-- with how fast somebody is actually moving; a threshold on speed cannot.
-- Everything else then falls out for free -- a thief snagged on an electric
-- fence is quiet because they are slow, and a thief CARRYING is always loud,
-- because carry speed is above every tier's threshold by construction:
--
--     TIPTOE at max (9.6)  <  a dog's `notice`  <  CARRY_SPEED (12)
--
-- So you can sneak IN and you can never sneak the money OUT. The toll lands
-- on the getaway, which is where every other cost in this game already
-- lands.
--
-- THE UPGRADE BUYS TIME, NOT INVISIBILITY, and the ceiling is structural
-- rather than imposed. BASE_WALK_SPEED is the number every system here is
-- calibrated against and Speed Boots had to be capped at 1.0 by hand to
-- respect it; a tiptoe cannot violate it at any level, because the whole
-- point of the stat is that it is below walking pace. What a rung buys is
-- crossing the same lawn in less time, never a lower chance of being seen --
-- WHETHER sneaking works at all is the DOG's tier to decide, not the
-- thief's.
Config.TIPTOE = {
	-- Multiplier on currentSpeed with no upgrades: 5.6 studs/sec.
	base = 0.35,
	-- Per rung of the (not yet written) offence upgrade.
	perLevel = 0.0625,
	-- 0.6 of base walk, so 9.6 studs/sec fully upgraded -- under carry speed
	-- by 2.4, which is the margin that keeps the ordering above true.
	max = 0.6,
}

function Config.getTiptoeMultiplier(level: number): number
	return math.min(Config.TIPTOE.max, Config.TIPTOE.base + level * Config.TIPTOE.perLevel)
end

-- ============================================================
-- RESIDENTS -- THE NEIGHBOURS WHO ARE ALWAYS IN
-- ============================================================
--
-- A plot with no player on it is currently a dead frontage: `release` strips
-- it back to a bare slab with an empty pig, and `attemptSteal` requires a
-- `victim: Player`, so it cannot be robbed either. On a three-player server
-- that is five of eight houses standing empty, which reads as an abandoned
-- game AND leaves nothing to rob.
--
-- A RESIDENT IS THE SUPPLY SIDE OF THE CORE LOOP. Every unclaimed plot gets
-- one: a name on the sign, a pig that fills, and defences. What it buys:
--
--   * robbing is available in the first five seconds regardless of who else
--     is online, which is what the thirty-second storyboard rests on
--   * an UNCAPPED source of targets. Config.LOSS_CAP exists to stop a child
--     being emptied by seven people taking turns; nobody is behind these, so
--     nothing needs capping -- which is what lets robbing become the primary
--     income WITHOUT being robbed getting any worse for a real player
--   * the whole heist system becomes testable by one person, which roughly
--     ten entries in CLAUDE.md's "Not yet verified" section are waiting on
--
-- THEY ARE A RESOURCE, NOT A RIVAL. No revenge marker, no place on the
-- Richest Piggies or Most Wanted boards, no rap sheet. A resident is scenery
-- that happens to be worth money.
-- WHAT A NEIGHBOUR SAYS WHEN THEY ARE STANDING ABOUT.
--
-- The street reads as a street because there are people on it, and until now
-- those people did nothing but stand and occasionally walk. A line over a
-- neighbour's head is the cheapest thing in this game that makes the world
-- feel inhabited rather than populated -- no new system, no input, no state
-- a player can be wrong about.
--
-- IT ONLY HAPPENS WHEN SOMEBODY IS THERE TO HEAR IT, and that is the half
-- worth being deliberate about. A street of neighbours talking to an empty
-- pavement is a server burning ticks on nobody; more to the point, walking up
-- to a house and having its owner say something is a REACTION, and a line
-- that was already running when you arrived is scenery. The server tests for
-- a real character inside `range` before it picks a line at all.
--
-- THE SERVER PICKS THE LINE AND EVERY CLIENT SEES THE SAME ONE, which is the
-- rule the leaderboards already keep: two players standing together must not
-- be told the neighbour said two different things. The bubble is a
-- BillboardGui with `MaxDistance` on it, so WHO SEES IT is still per viewer
-- and costs the server nothing -- the same split the dog's nameplate makes.
--
-- ADD LINES HERE AND NOWHERE ELSE. The list is the whole vocabulary; nothing
-- reads an index into it, so a line can be added, reordered or removed
-- without touching a line of code.
Config.RESIDENT_CHATTER = {
	lines = {
		"I can see you wanna vibe with me",
		"Just say you wan' vibe with me",
	},

	-- How close a character has to be before a neighbour bothers, in studs.
	-- Sized against the street rather than picked: `PLOT_SPACING` is 80, so
	-- at 60 a player standing on one lawn can hear the neighbour whose lawn
	-- they are on and not the one two doors down -- which is what keeps a
	-- walk down the street a sequence of encounters rather than a chorus.
	range = 60,

	-- Seconds between one neighbour's lines, drawn fresh each time. A pair
	-- rather than a single interval because eight residents on one clock
	-- speak in lockstep, which reads as a mechanism rather than as people --
	-- the same argument the fireworks' jitter and the patrol's schedule make.
	--
	-- AND THE FLOOR IS WHAT STOPS IT BEING NAGGING. `playCoinDrop`'s comment
	-- calls a coin every fifteen seconds a heartbeat and anything louder
	-- nagging; a person repeating themselves is worse than a coin, so the
	-- gap starts well above it.
	minGap = 14,
	maxGap = 30,

	-- How long a line stays up. Long enough to read at a walk -- the notify
	-- cards solve the same problem with `NOTIFY_READ` and land between 3.9
	-- and 8.9 seconds -- and short enough that a neighbour is not standing
	-- there with a speech bubble welded to them.
	hold = 4.5,
}

Config.RESIDENTS = {
	-- Clearly not players. A nine-year-old has to be able to tell at a
	-- glance whether the house they are about to rob belongs to a person,
	-- because the answer changes whether anybody is going to be upset.
	names = {
		"The Trotters", "Old Man Hamm", "Mrs Curlytail", "The Bacons",
		"Grandpa Grunt", "The Snuffles", "Miss Bristle", "The Snouts",
		"Auntie Crackling", "The Porkchops",
	},

	-- HOW MUCH A RESIDENT'S PIG HOLDS, MEASURED IN SECONDS OF ITS OWN INCOME.
	--
	-- This is the single dial that sets what robbing is worth in this game,
	-- and it replaced a share of `getCapacity` that was quietly broken.
	--
	-- CAPACITY WAS A CATEGORY ERROR, NOT A TUNING MISS. Capacity means *how
	-- much you can hold before you have to spend* -- a storage limit that
	-- exists because a full pig stops earning, which is what drives every
	-- purchase a player makes. A RESIDENT NEVER SPENDS ANYTHING. So capacity
	-- is not the wrong number for one, it is a concept that does not apply,
	-- and borrowing it made a resident's worth ride a curve chosen for a
	-- different job entirely.
	--
	-- What that cost, measured: capacity grows 1.40 a level and income grows
	-- 1.35, so a resident's pig drifted from 300 seconds of its own income at
	-- level 1 to 998 seconds at level 40 -- and robbing went from 3.7x the
	-- return of idling to 12.3x. Two curves multiplied without anybody
	-- checking the product, which is the same mistake `LOSS_CAP` x
	-- `HEIST_PAYOUT` already made one level down.
	--
	-- A CONSTANT RATIO IS THE POINT, NOT A LOWER ONE. The catalogue can be
	-- priced for whatever robbing is worth; what cannot be tuned around is a
	-- ratio that MOVES, because then no single set of prices is right for
	-- both ends of the game and the late game silently becomes one where
	-- anybody who stops robbing stops progressing. Pinned, it is one decision
	-- instead of forty: ratio is about `0.0123 * pigSeconds`, so 400 is
	-- roughly 4.9x the return of standing still, at every level.
	--
	-- It also says out loud what a resident IS worth, which a capacity
	-- fraction never could: a few minutes of your own income, sitting in a
	-- house with nobody in it.
	--
	-- 400 -> 200 WHEN THE SPREE SHIPPED, AND THE TOP OF THE GAME DID NOT
	-- MOVE. At 400 a thief cycling residents earned 8.25x idling, measured,
	-- flat at every level -- and a spree multiplying the payout on top of
	-- that would have taken it to 16.5x and straight through
	-- `ROBBERY_ADVANTAGE.max`. Two curves multiplied without checking the
	-- product, which is the mistake this constant already exists to fix one
	-- level down, and `Config.auditRobbery` caught it before it shipped
	-- rather than months after.
	--
	-- Halved, a COLD thief earns 4.12x and a thief sustaining a full spree
	-- earns 8.25x -- which is exactly what everybody earned before. So the
	-- ceiling of this economy is unchanged and the spree is HOW YOU REACH IT
	-- rather than a new number above it; what got slower is robbing
	-- listlessly, which is the behaviour that should be slower. 4.12x also
	-- lands inside the 3-5x this design has been aiming at since the loop
	-- was first measured.
	pigSeconds = 200,

	-- A RESIDENT'S PER-VICTIM COOLDOWN IS THE SAME AS A PLAYER'S, AND THE
	-- SESSION IT SPENT AT 30 IS WORTH KEEPING BECAUSE THE ARGUMENT FOR
	-- HALVING IT WAS SOUND AND ITS PREMISE IS GONE.
	--
	-- The premise was a supply floor of TWO houses, left over from capping
	-- the server at six against eight plots. At two targets a thief laps the
	-- street in about 42s against a 60s cooldown, so they would spend a
	-- quarter of every cycle waiting and the robbing advantage would still
	-- SLOPE with population -- which is the exact failure the floor exists to
	-- remove. Halving it made the floor saturate and the ratio flat.
	--
	-- `SHOPS` raised the floor to FOUR instead, and four targets lap in
	-- about 85s -- comfortably over 60 -- so the cooldown never binds and the
	-- ratio is flat at every population with no asymmetry needed at all.
	-- Measured: three permanent targets is the threshold, and there are four.
	--
	-- SO THE FOURTH ASYMMETRY IS WITHDRAWN. The three that remain -- no
	-- `LOSS_CAP`, no grudge or revenge marker, no notifications -- are all one
	-- sentence: a resident does not need the protections a CHILD needs.
	-- `STEAL_COOLDOWN` is not one of those. It is the ANTI-FARMING
	-- protection, and farming an NPC is exactly as bad for this economy as
	-- farming a person, so there was never a reason of that shape to shorten
	-- it -- only a reason of arithmetic, and the arithmetic moved.
	--
	-- Kept as its own field rather than deleted, and `Config.stealCooldownFor`
	-- still asks: the two are the same number today and the question is a real
	-- one, so a table with one value in it is cheaper than re-deriving where
	-- the branch went if a later floor makes it want to move again.
	stealCooldown = 60,

	-- Seconds between accrual ticks. Matches EconomyService's own cadence so
	-- a resident's pile climbs at visibly the same rate a player's does.
	tickRate = 1,

	-- A NEIGHBOUR WHO GOES OUT AND ROBS SOMEBODY.
	--
	-- Residents fixed "a quiet server has nothing to rob". This is the mirror
	-- of it: a quiet server has NOBODY TO DEFEND AGAINST, so every rung of
	-- the defence tree -- the Vault Lock, the Fence, the Guard Dog, the Guard
	-- Duty Treat, the Sprinkler -- protects against nothing in a solo
	-- session, and half the shop is inert. A child who spends an afternoon
	-- buying a Mastiff has bought a thing that will never once be used.
	walk = {
		-- SPEED IS THE CURRENCY, AND THIS IS THE WHOLE BALANCE OF THE
		-- FEATURE. `BASE_WALK_SPEED` is 16 and a carrying player does 12; a
		-- neighbour strolls at 9 and carries at 7, so A PLAYER CAN ALWAYS RUN
		-- ONE DOWN -- on their own lawn, on the pavement, or at the
		-- neighbour's gate.
		--
		-- That ordering is what stops this being a tax rather than a game:
		-- the coins are recoverable by doing the thing, every time, with no
		-- purchase involved. Anything that raises these past 12 hands a
		-- player a loss they cannot answer, which is the one outcome this
		-- design will not put in front of a nine-year-old.
		speed = 9,
		carrySpeed = 7,

		-- HOW MANY ARE OUT AT ONCE. Two, and it is a cap on the PICTURE as
		-- much as on the cost: eight neighbours all out at once is a street
		-- where every house is empty and nobody is home, which is the
		-- opposite of what the walk is for. Somebody being out has to be an
		-- EVENT you notice, not the default state of the road.
		--
		-- It also bounds the only real cost here. A resident standing at home
		-- writes nothing at all; two walking is about the replication of the
		-- one patrol officer this game already runs.
		maxOut = 2,

		-- Seconds at home between trips, drawn per resident so the row does
		-- not set off in step.
		restMin = 45,
		restMax = 150,

		-- HOW LONG THEY STAND AT THE PIG. A crack is a DECISION for a player
		-- and a resident has none to make, so what it spends instead is TIME
		-- STANDING IN THE OPEN -- which is precisely the window a victim has
		-- to walk over and do something about it. Shorten this and the
		-- robbery stops being answerable.
		crackSeconds = 6,

		-- What one visit takes, as a share of the pig it finds. Deliberately
		-- close to a player's own clean five-slice run (21.9%) so a neighbour
		-- is never worse to be robbed by than a person -- and `LOSS_CAP` is
		-- applied on top by the one function that owns it, so this is what
		-- they ASK for rather than what they get.
		takeFraction = 0.2,
	},

	-- A RESIDENT IS A PEER, NOT A LADDER OF ITS OWN. Its income and capacity
	-- come from the same curves players use, at a level derived from the
	-- humans in the server -- so an NPC pig is worth robbing at minute one
	-- and still worth robbing at rebirth ten, with no second economy to tune
	-- and nothing that can drift away from the real one.
	--
	-- The AVERAGE rather than the maximum: pinning to the best player in the
	-- server would make every resident as rich as the richest human, which
	-- hands a beginner a target they cannot fail to profit from and hands the
	-- best player nothing worth crossing the street for.
	levelOffset = 0,
	minLevel = 0,

	-- HOW FAR BELOW THE STREET A RESIDENT MAY SIT, and it only ever goes DOWN.
	--
	-- Every resident used to be seated at exactly `currentLevel()`, so eight
	-- identical pigs stood behind eight identical fences with eight identical
	-- dogs. That is "every robbery is the same robbery" one level up from the
	-- verbs: not only did a robbery play the same, there was nothing to choose
	-- between the houses. A spread makes picking a target a decision, and
	-- CASING plus the rob badge are what make both halves of it readable from
	-- the pavement -- how much is in there, and how hard the lock is.
	--
	-- DOWNWARD ONLY, AND THAT IS NOT A PREFERENCE. A resident's pig is
	-- `pigSeconds` of its OWN income, so a resident one level above the thief
	-- is worth `INCOME_GROWTH` times more -- and a thief robs the richest
	-- house they can. Measured against `auditRobbery`'s own ceiling: at
	-- parity a maxed spree returns 8.25x idling against a ceiling of 10, so
	-- there is x1.212 of headroom and ONE level up is x1.35 in band A. A
	-- single upward step puts it at 11.14x at every level below 20 and 15.03x
	-- at +2. Residents richer than the thief are a faucet, full stop.
	--
	-- So the peer-level house is the CEILING of the street rather than a rung
	-- in the middle of it, which is also the right shape: the best-paying
	-- house is the best defended, and the guaranteed-easy ones below pay
	-- least. This is the same conclusion `currentLevel`'s own comment reached
	-- when it chose the average over the maximum, arriving from the audit.
	-- SIX, WHICH IS SIZED AGAINST THE LADDERS BELOW RATHER THAN CHOSEN. The
	-- defences step every 5 to 7 levels (`fencePerLevels` 5, `lockPerLevels`
	-- 6, `dogPerLevels` 7), so a spread of 4 could not reliably move any of
	-- them: measured, a street at level 20 seated every house with the same
	-- dog tier and the variety was carried by the house and the garden alone.
	-- At 6 the bottom of the street is a fence and a lock tier below the top
	-- of it, which is a difference a thief can act on.
	levelSpread = 6,

	-- HOW MANY HOUSES ARE ALWAYS AT THE BOTTOM OF THAT SPREAD.
	--
	-- Two, so a player with base stats -- no Lockpicks, no bones, no Sneakers
	-- -- always has somewhere to go. Without it a random street can seat every
	-- resident near the top, and a new player meets a row of houses whose
	-- dogs they cannot sneak past and whose locks they cannot pick: the
	-- "defence buys time, never immunity" rule broken by a dice roll rather
	-- than by a purchase.
	--
	-- It is a FLOOR rather than a distribution, checked at seat time against
	-- how many easy houses are actually standing, because residents are
	-- seated one at a time as plots free up rather than all at once.
	easyCount = 2,

	-- The garden, on the same shape as the four ladders below it: one more
	-- ornament every `decorPerLevels`, capped at `decorMax`. A richer
	-- neighbour has a fuller lawn, which is free information read from the
	-- pavement -- and it is pure decoration, since every ornament is
	-- CanCollide and CanQuery off and none of it can body-block a thief, a
	-- defender or the dog.
	--
	-- It matches `housePerLevels` so the garden and the building grow
	-- together: a big house with a bare lawn reads as unfinished rather than
	-- as rich.
	decorMax = 4,
	decorPerLevels = 3,

	-- Defences, as the resident's own level divided by these. All three land
	-- at zero while the server's players are new, which is what makes the
	-- FIRST robbery in the storyboard a clean run at a bare plot -- and they
	-- climb on their own as the street does, so a resident never becomes the
	-- free money a maxed player farms instead of playing.
	dogPerLevels = 7,
	fencePerLevels = 5,
	lockPerLevels = 6,
	housePerLevels = 3,
}

-- Published on the plot model so a CLIENT can tell a resident's house from a
-- genuinely empty one. It has to be an attribute rather than something the
-- client infers, for the same reason `PLOT_VAULT_ATTRIBUTE` is: the steal
-- prompt is enabled per viewer, and today that test is `OwnerUserId ~= nil`,
-- which is false for a resident. Nil means the plot is nobody's.
Config.PLOT_RESIDENT_ATTRIBUTE = "ResidentName"

-- The id a resident's steal cooldown travels under, so a CLIENT can key its
-- own per-victim badge the same way it does for a player. It is the negative
-- plot index -- a real UserId is always positive, so the two spaces cannot
-- collide -- and it is published rather than derived from the model's name
-- because parsing "Plot7" for a number is the kind of thing that keeps
-- working right up until somebody renames a plot.
Config.PLOT_RESIDENT_ID_ATTRIBUTE = "ResidentId"

-- The name a given plot's resident wears. Indexed by plot rather than picked
-- at random, so a plot keeps its identity across an owner arriving and
-- leaving -- the house that was the Trotters' before somebody moved in is
-- the Trotters' again afterwards.
function Config.getResidentName(plotIndex: number): string
	local names = Config.RESIDENTS.names
	return names[((plotIndex - 1) % #names) + 1]
end

-- ============================================================
-- GUARD DOGS
-- ============================================================
--
-- Three breeds, not three copies of the same dog with a bigger number. The
-- dog is the most expensive thing in the defence tree, and a purchase nobody
-- can see doesn't feel like a purchase -- each tier has to read as an upgrade
-- from across the plot, before the chase ever happens.
--
-- Speeds are set against the thief, not in the abstract. Scruffy ties an
-- unbooted thief, so she only catches players who skipped Speed Boots; Titan
-- outruns a fully booted one. That keeps the dog a real answer to the offence
-- tree rather than a flat tax on robbing.
--
-- Everything else moves the same direction with each tier: wider jaws
-- (catchRadius), a longer leash (maxChase), and a shorter rest (cooldown).
-- Cooldown is the quiet one that matters most -- against a plot being farmed
-- repeatedly, Titan is back on duty ten seconds sooner than Scruffy.
Config.DOG_TIERS = {
	{
		name = "Scruffy",
		-- Voice. Pitch is what separates the breeds: same library, three
		-- animals. Volume climbs too, so a Titan is audible from further
		-- down the street than a terrier.
		bark = "rbxassetid://9113955391", pitch = 1.45, volume = 0.42,
		breed = "Terrier",
		speed = 12,
		catchRadius = 7,
		-- Speed above which this dog notices somebody on the lawn. See the
		-- TIPTOE block: the ordering that has to hold is tiptoe max (9.6) <
		-- notice < carry speed (12 to 16 with boots), so a sneak gets in and
		-- the money never gets out quietly. 11 clears both by a margin.
		--
		-- LIVE. Read by the lawn watcher in HeistService, through
		-- `GuardDog.noticeSpeed`, against a speed MEASURED from how far
		-- somebody actually moved between ticks -- never `WalkSpeed`, which
		-- is what a character is allowed to do and reads 16 for somebody
		-- standing perfectly still.
		notice = 11,
		cooldown = 34,
		maxChase = 12,
		scale = 0.8,
		-- BREED SHAPE. Three animals out of one part list, and `scale` alone
		-- could only ever produce the SAME dog at three sizes -- which is what
		-- shipped: a terrier, a shepherd and a mastiff that differed by colour
		-- and by nothing else at all.
		--
		--   leg      how tall it stands; everything above the legs is lifted
		--            to match, so the belly never ends up in the grass.
		--   girth    how heavy it is, across and through -- never ALONG, or a
		--            stocky breed comes out longer instead of thicker.
		--   head     how much of the dog is head, scaled about the head's own
		--            centre so the eyes and brow travel with the skull.
		--   earDroop degrees of hang. The clearest breed tell there is, and it
		--            costs nothing: the ears are hinged at their roots.
		--
		-- Low and slight, on short legs, with the biggest ears on the street
		-- for its size. A terrier is mostly ears and attitude.
		shape = { leg = 0.82, girth = 0.94, head = 1.06, earDroop = 0 },
		boneResist = 1.0,
		fur = Color3.fromRGB(198, 154, 98),
		furDark = Color3.fromRGB(158, 116, 68),
		collar = Color3.fromRGB(214, 68, 64),
		glow = false,
		blurb = "Small, loud, and quicker than a thief who skipped boots",
	},
	{
		name = "Rex",
		-- Voice. Pitch is what separates the breeds: same library, three
		-- animals. Volume climbs too, so a Titan is audible from further
		-- down the street than a terrier.
		bark = "rbxassetid://9113956178", pitch = 1.00, volume = 0.55,
		breed = "Shepherd",
		speed = 14.5,
		catchRadius = 8.2,
		-- Tighter than Scruffy and still above a maxed tiptoe. A Shepherd
		-- makes sneaking narrower, never impossible.
		notice = 10.2,
		cooldown = 29,
		maxChase = 15,
		scale = 1.0,
		-- The athlete: longest legs in the catalogue, ordinary build, ears
		-- straight up. It is the one breed that should read as FAST standing
		-- still, and leg length is the only thing that says so.
		shape = { leg = 1.14, girth = 1.00, head = 1.00, earDroop = 0 },
		boneResist = 0.8,
		fur = Color3.fromRGB(126, 94, 66),
		furDark = Color3.fromRGB(72, 52, 38),
		collar = Color3.fromRGB(66, 140, 220),
		glow = false,
		blurb = "Longer legs, longer chase, and a much wider set of jaws",
	},
	{
		name = "Titan",
		-- Voice. Pitch is what separates the breeds: same library, three
		-- animals. Volume climbs too, so a Titan is audible from further
		-- down the street than a terrier.
		bark = "rbxassetid://9113955086", pitch = 0.68, volume = 0.75,
		breed = "Mastiff",
		speed = 17,
		catchRadius = 9.5,
		-- ZERO: a Titan notices ANY movement on the lawn, so no amount of
		-- tiptoeing gets past one. That is not immunity and must not become
		-- it -- it is "cheap counters bounce, the expensive one gets
		-- through", the same shape the Guard Duty Treat and the Raincoat
		-- already hold: a free action beats the two cheap breeds, and a
		-- Titan has to be answered with a BONE. Standing perfectly still is
		-- still unseen, which makes waiting out a patrol a real tactic
		-- rather than a wasted second.
		notice = 0,
		cooldown = 24,
		maxChase = 18,
		scale = 1.3,
		-- Heavy, short-legged and mostly head, with ears that HANG. The droop
		-- is doing the most work: it is the only one of the four that changes
		-- the silhouette rather than its proportions, and at a hundred studs
		-- a hanging ear is the difference between "big dog" and "Mastiff".
		shape = { leg = 0.88, girth = 1.20, head = 1.24, earDroop = 112 },
		boneResist = 0.6,
		fur = Color3.fromRGB(58, 56, 64),
		furDark = Color3.fromRGB(32, 31, 37),
		collar = Color3.fromRGB(246, 198, 52),
		glow = true,
		blurb = "Runs down fully booted thieves. Nothing leaves this plot",
	},
}

-- ============================================================
-- THE DOG IS YOURS -- COATS
-- ============================================================
--
-- The dog is already the most alive thing on a lawn: it patrols, sleeps,
-- barks, wears a collar and a tag, carries a nameplate and has a kennel of
-- its own. Every one of those is decided by which TIER was bought, and none
-- of it is the player's. This is the first thing here that is.
--
-- A COAT IS TASTE. THE TIER IS STILL THE TIER, AND THAT SEPARATION IS THE
-- ONLY REASON THIS IS ALLOWED. A thief reads the dog to decide the risk, so a
-- Scruffy dressed as a Titan would be a defence upgrade sold for money. The
-- tier therefore has to live on a channel no coat can touch.
--
-- IT ALREADY DOES, AND THAT WAS MEASURED BEFORE A LINE OF THIS WAS WRITTEN.
-- `DOG_TIERS` carries `scale`, and `shape` carries `leg`, `girth`, `head` and
-- `earDroop` -- so the three breeds differ in PROPORTION rather than in size,
-- and the relationship INVERTS between the top two:
--
--     Scruffy   scale 0.8   leg 0.82   girth 0.94   head 1.06
--     Rex       scale 1.0   leg 1.14   girth 1.00   head 1.00   tall, narrow
--     Titan     scale 1.3   leg 0.88   girth 1.20   head 1.24   low, wide
--
-- That work was done for exactly this reason -- see BREED SHAPE above, which
-- says in as many words that scale alone "could only ever produce the SAME
-- dog at three sizes... a terrier, a shepherd and a mastiff that differed by
-- colour and by nothing else at all." The colour cue is therefore spare, and
-- freeing it costs the tier read nothing. **ANY FUTURE COSMETIC THAT REACHES
-- `scale` OR `shape` BREAKS THIS AND IS NOT ALLOWED.**
--
-- ONE CATALOGUE, THREE COLOURS, THE SAME SHAPE AS A PIGGY SKIN. `fur` and
-- `furDark` are the body and its muzzle/brow shading, `collar` is the collar
-- and tag -- the direct parallel of a skin's `body` and `trim`, so the shop
-- card, `Config.rarityOf` and the equip toggle all work with nothing new.
--
-- NO EXPLICIT `rarity` FIELD, DELIBERATELY, BECAUSE EVERY ONE OF THESE IS
-- PRICED. `Config.rarityOf` reads an explicit rarity first and falls back to
-- the coin cost, so a priced catalogue derives its own tiers and cannot drift
-- when a price moves. The moment a coat is added that is NOT bought with
-- coins -- a crate-only drop, an event reward -- it needs an explicit
-- `rarity` or it silently falls through to `common`, which is the trap the
-- ten drop-pool skins and all twelve accessories already carry a rarity to
-- avoid.
--
-- AN EMPTY `equipped` MEANS THE BREED'S OWN COLOURS, so there is no "default"
-- row in here to keep in step with `DOG_TIERS`. Equipping a coat you are
-- already wearing takes it off, the same toggle accessories and decorations
-- use, which is the only way to get back to the breed look.
Config.DOG_COATS = {
	chocolate = {
		name = "Chocolate", order = 1, cost = 15000,
		fur = Color3.fromRGB(104, 68, 46), furDark = Color3.fromRGB(68, 42, 28),
		collar = Color3.fromRGB(214, 138, 62),
	},
	husky = {
		name = "Husky", order = 2, cost = 60000,
		fur = Color3.fromRGB(196, 202, 210), furDark = Color3.fromRGB(78, 86, 98),
		collar = Color3.fromRGB(96, 158, 206),
	},
	goldenboy = {
		name = "Golden Boy", order = 3, cost = 150000,
		fur = Color3.fromRGB(226, 174, 96), furDark = Color3.fromRGB(166, 116, 54),
		collar = Color3.fromRGB(206, 62, 78),
	},
	dalmatian = {
		name = "Spotless Dalmatian", order = 4, cost = 400000,
		fur = Color3.fromRGB(232, 232, 228), furDark = Color3.fromRGB(46, 46, 48),
		collar = Color3.fromRGB(206, 62, 78),
	},
	shadow = {
		name = "Shadow", order = 5, cost = 1500000,
		fur = Color3.fromRGB(52, 52, 60), furDark = Color3.fromRGB(28, 28, 34),
		collar = Color3.fromRGB(198, 54, 62),
	},
	glacier = {
		name = "Glacier", order = 6, cost = 12000000,
		fur = Color3.fromRGB(214, 232, 244), furDark = Color3.fromRGB(122, 168, 200),
		collar = Color3.fromRGB(96, 214, 226),
	},
}

-- THE KENNEL IS THE SECOND HALF OF THE PAIR, AND IT REPAINTS THE HOUSE AND
-- NEVER THE ROOF.
--
-- `docs/MASTER-PLAN.md` asks for "the kennel as a display" and gives the reason
-- in one line: *its roof already takes the collar colour so it reads as
-- belonging to the dog*. That is exactly why a kennel skin must not touch the
-- roof. `applyTier` paints `roof` from the coat's `collar`, so the roof is the
-- one surface on that model saying WHOSE dog lives here -- and a bought skin
-- that overrode it would sell a player the ability to make their kennel
-- disagree with their own dog.
--
-- So the two catalogues own two channels of one object: **the kennel says what
-- the house is made of and the coat says who lives in it.** Buy both and they
-- read as a set, which is what the plan wanted from rolling them in one pool
-- -- and it costs nothing to keep true, because neither can reach the other's
-- field.
--
-- TWO TONES, `wood` AND `trim`, WHICH IS THE WHOLE MODEL LESS THE ROOF.
-- `wood` is the floor and the three walls; `trim` is the base course, the door
-- posts, the lintel, the ridge, the eaves and the food bowl. The name board is
-- deliberately `wood` (see `KENNEL` in `GuardDog`), so a skin carries the
-- board with it and the painted name stays legible against whatever the walls
-- become -- the label colour is a literal cream in `GuardDog` rather than a
-- tone, for exactly that reason.
--
-- COINS AND NOT A CRATE ROLL, WHICH IS A DEVIATION FROM THE PLAN AND FOLLOWS
-- THE COATS RATHER THAN THE DOCUMENT. `docs/MASTER-PLAN.md` proposes rolling
-- coats and kennels in one crate pool; coats shipped priced in coins, so a
-- crate-only kennel would put one half of a matched pair behind luck and the
-- other behind a price. `Config.rarityOf` derives a tier from the cost, so a
-- priced catalogue borders itself and cannot drift when a price moves -- and
-- the first kennel added that is NOT bought with coins needs an explicit
-- `rarity` or it silently falls through to `common`.
--
-- AN EMPTY `kennel` MEANS THE PLAIN WOODEN ONE, the same way an empty coat
-- means the breed's own colours. There is no "default" row to keep in step
-- with `KENNEL_WOOD`/`KENNEL_TRIM`, and the toggle is the only way back to it.
Config.DOG_KENNELS = {
	redbrick = {
		name = "Red Brick", order = 1, cost = 10000,
		wood = Color3.fromRGB(168, 86, 72), trim = Color3.fromRGB(232, 226, 214),
	},
	mint = {
		name = "Mint Cottage", order = 2, cost = 45000,
		wood = Color3.fromRGB(146, 206, 180), trim = Color3.fromRGB(244, 248, 244),
	},
	midnight = {
		name = "Midnight", order = 3, cost = 120000,
		wood = Color3.fromRGB(54, 58, 72), trim = Color3.fromRGB(98, 104, 124),
	},
	candy = {
		name = "Candy Cane", order = 4, cost = 350000,
		wood = Color3.fromRGB(238, 232, 226), trim = Color3.fromRGB(206, 62, 78),
	},
	royal = {
		name = "Royal Kennel", order = 5, cost = 2000000,
		wood = Color3.fromRGB(72, 52, 124), trim = Color3.fromRGB(226, 182, 88),
	},
	gilded = {
		name = "Solid Gold", order = 6, cost = 14000000,
		wood = Color3.fromRGB(226, 186, 86), trim = Color3.fromRGB(150, 112, 40),
	},
}

-- THE TOYS, WHICH ARE THE FIRST THING ON A LAWN THAT THE DOG ACTUALLY USES.
--
-- `docs/MASTER-PLAN.md`: *"A ball it fetches, a bed it sleeps in instead of the
-- kennel, a bowl it visits. It already patrols and sleeps on its own clock;
-- two or three places to go makes it read as owned rather than deployed."*
-- That is the whole design and it is worth being exact about why it is cheap:
-- the dog ALREADY walks to a random point inside `DOG_PATROL_RADIUS` and
-- ALREADY settles at its kennel door. A toy does not add a behaviour, it
-- REPLACES the destination of one the dog already had.
--
-- **A TOY MAY NEVER CHANGE AN OUTCOME, AND TWO THINGS ENFORCE THAT RATHER
-- THAN PROMISE IT.**
--
-- First, `spot` is kennel-local and every one of them is inside the patrol
-- radius the dog already wanders, and `GuardDog` CLAMPS the walk to that
-- radius on top -- so no toy, at any offset anybody types here later, can pull
-- a guard dog further from its post than an ordinary patrol step already does.
-- A cosmetic that could station the dog somewhere else would be a defence
-- change sold for coins, which is the line every cosmetic in this game holds.
--
-- Second, **A TOY IS SILENT.** The bark is the "a dog has seen me" signal a
-- thief reads from the pavement, and a ball that squeaked would be a bought
-- object faking a defence tell. The ball bounces and nothing makes a sound.
--
-- THE BED IS THE ONE THAT MOVES A TELL, AND IT SURVIVES BECAUSE THE TELL WAS
-- NEVER THE KENNEL. What a thief has to read is *this plot is unguarded right
-- now*, and that is carried by the sleeping POSTURE, the puff and the OFF DUTY
-- line on the nameplate -- all three of which follow the dog. The dog was
-- never hidden inside the kennel to begin with; it settles at the DOORWAY, in
-- plain sight. A bed a few studs away is the same picture in a different spot,
-- and the puff moved off the kennel roof and onto the dog in the same change
-- so it cannot be left hanging over an empty house.
--
-- THE SPOTS ARE KENNEL-LOCAL AND ARE MEASURED INTO A REAL POCKET, and they
-- have now been measured TWICE -- which is the argument for them being
-- kennel-local rather than plot-local, and it was worth the whole of what it
-- cost.
--
-- The first placement was solved against a kennel standing at plot (26, 17)
-- with no rotation, and it put a Water Bowl at plot z 25.5 against a
-- `PLOT_FRONT_LINE` of 25.6: a 25,000-coin object standing ON the fence and
-- reaching through it. The kennel then MOVED, to (25, 16) with a quarter turn
-- so its doorway faces across the lawn -- and because these offsets are
-- kennel-local they travelled with it automatically and landed, measured on a
-- live plot, at ball (29.0, 10.5), bowl (24.5, 10.5) and bed (27.0, 5.5).
-- All three behind the kennel, and the BED sitting on top of decor slot
-- `lawnH` at (25, 0, 4), where an ornament would have stood inside it.
--
-- **THAT IS THE PROPERTY WORTH KEEPING: a kennel-local offset cannot be left
-- behind by a kennel that moves, only made wrong.** A plot-local one would
-- have gone on pointing at the old corner with the kennel nowhere near it,
-- which is a bug nobody would have thought to look for.
--
-- The turn maps kennel-local +Z onto plot -X, so `plot = (25 - local.Z,
-- 16 + local.X)`. The band that is actually free is bounded on four sides:
-- the GATE WALK at |x| 12, the KENNEL itself from plot x 21.45, decor slot
-- `lawnH` behind it (which an 11.0-stud ornament carries out to plot z 9.5),
-- and `PLOT_FRONT_LINE` at 25.6. Measured in that band, on the live plot:
--
--     ball  plot x 13.67..15.33   z 13.17..14.83
--     bowl  plot x 16.20..18.80   z 10.20..12.80
--     bed   plot x 14.40..18.84   z 17.05..22.95
--
--     bed to the kennel                          1.41 studs
--     bowl to the kennel                         1.45
--     ball to the kennel                         4.92
--     bed to the front fence                     2.65
--     bed to the gate walk                       2.40
--     ball to the gate walk                      1.67
--     bowl to what an ornament in lawnH reaches  0.70
--     closest toy to another toy                 0.87
--     lowest point of any toy                   -0.06, sunk into the lawn
--
-- MEASURE THE KENNEL, NOT ITS WALLS. The first fit here put the bed 0.42
-- studs from the kennel because it was solved against the wall line; measured
-- live the kennel spans plot x 20.25..29.75, because the roof panels are
-- pitched at 28 degrees and reach a stud further out on each side than
-- anything holding them up.
--
-- AND THE BED IS DELIBERATELY OFF THE REST SPOT. The dog rests at plot
-- (17.85, 16) and the bed starts at z 17.05, so settling down is a walk of
-- about four studs rather than a dog lying down exactly where it already
-- stood. A bed the dog is already standing in makes the one toy that changes
-- behaviour look like it changes nothing.
--
-- THE COLOURS LIVE HERE AND THE SHAPES LIVE IN `GuardDog`, which is the same
-- split `DOG_COATS` already makes and it is load-bearing rather than tidy: the
-- SHOP has to draw a swatch for these, and `GuardDog` is a server service the
-- client cannot require. Colours in the geometry and colours again in the
-- payload would be the near-identical second copy this project keeps
-- recording -- and the failure shape is specific and known, because a toy with
-- no swatch renders as a blank cream tile, which is exactly what eleven
-- effects did before they got a gradient.
--
-- `body` and `trim` are the pair every card in this shop already sends;
-- `accent` is the bowl's water and is the one thing here a card does not draw.
--
-- OWNED AND OUT ARE TWO TABLES, the same pair `data.decor` already keeps.
-- One table would make "put it away" mean "sell it", and this game refunds
-- nothing -- so a player who wanted a bare lawn for a week would have to buy
-- the toy again. The card's press is the toggle, which is also what stops an
-- owned toy being a tile that does nothing when tapped.
Config.DOG_TOYS = {
	ball = {
		name = "Squeaky Ball", order = 1, cost = 8000,
		body = Color3.fromRGB(224, 78, 62), trim = Color3.fromRGB(244, 238, 226),
		spot = Vector3.new(-2.0, 0, 10.5),
		kind = "visit",
	},
	bowl = {
		name = "Water Bowl", order = 2, cost = 25000,
		body = Color3.fromRGB(74, 142, 206), trim = Color3.fromRGB(232, 236, 240),
		accent = Color3.fromRGB(128, 196, 236),
		-- Deliberately NOT where the kennel's own food bowl is (kennel-local
		-- x +3.90): that one is scenery on every kennel in the game including
		-- a resident's, and a bought bowl landing on top of it would read as a
		-- purchase that did nothing.
		spot = Vector3.new(-4.5, 0, 7.5),
		kind = "visit",
	},
	bed = {
		name = "Dog Bed", order = 3, cost = 120000,
		body = Color3.fromRGB(206, 152, 168), trim = Color3.fromRGB(158, 100, 122),
		-- Its own column further out, because it is by far the biggest of the
		-- three at 5.4 by 4.2 and will not share one with the other two.
		spot = Vector3.new(4.0, 0, 8.5),
		kind = "sleep",
	},
}

-- How often a patrol step picks a toy instead of a random point, when there is
-- at least one out. Under a half on purpose: a dog that went to a toy EVERY
-- time would stop patrolling and start commuting, and the pacing round the
-- lawn is what the Guard Dog rung actually bought.
Config.DOG_TOY_VISIT_CHANCE = 0.45

-- THE GUARD-DUTY TELL, MOVED OFF THE COLLAR AND ONTO A WORN OBJECT.
--
-- `showGuardDuty` used to flip the collar and tag to `Neon` and write ON GUARD
-- on the nameplate. The collar half cannot survive coats: a player wearing a
-- bright cosmetic collar would make the tell unreadable, which is WORSE than
-- no tell at all -- a thief would burn a 30,000-coin Golden Bone finding out,
-- or get caught by a dog they had every reason to think was bribeable.
--
-- DELETING IT OUTRIGHT IS ALSO WRONG, because it takes guard duty from two
-- channels down to one. The nameplate is a `BillboardGui` with `MaxDistance`
-- 90 and `TextScaled`, so it does reach the pavement -- but it is small there
-- and it would be the only thing left. **A BUFF NOBODY CAN SEE IS A TRAP** is
-- a rule this project already holds, and the whole point of the tell is that
-- the correct response -- go and rob one of the other plots -- is readable
-- before anybody commits.
--
-- So duty gets its OWN object: a hi-vis vest over the dog's back, on for the
-- shift and off the rest of the time. Two channels again, cosmetic collars
-- can be any colour anybody likes, and it is a better picture than a glowing
-- collar ever was -- a dog that visibly clocks in.
--
-- It is NOT in `DOG_COATS` and must never be buyable. It is a state readout,
-- and a state readout somebody can recolour is the same failure as the collar
-- one level along.
Config.DOG_DUTY_VEST = Color3.fromRGB(246, 186, 40)

-- NAMING THE DOG, WHICH IS THE THING THAT ACTUALLY MAKES IT YOURS.
--
-- A coat changes what the dog looks like; a name changes whose it is. It is
-- also the only place in this game where a PLAYER'S OWN TEXT is shown to other
-- players, and that single fact is most of what this costs.
--
-- **THE NAME IS USER-GENERATED CONTENT AND MUST BE FILTERED.** On this
-- platform that means `TextService:FilterStringAsync` on the SERVER, followed
-- by `GetNonChatStringForBroadcastAsync` because the result is shown to
-- everybody rather than to one recipient. Not optional, not a later pass, and
-- not something the client can be trusted to have done -- the client sends
-- what was typed and the server decides what is displayed. The filter call
-- yields and can throw, so it is pcalled, and a failure falls back to the
-- BREED name rather than to the raw text: a moderation call that errors must
-- never fail open.
--
-- FREE, AND THE PLAN SAID ROBUX. `docs/MASTER-PLAN.md` proposes charging for a
-- rename as a SERVICE -- which is the cleanest possible Robux product, since
-- it mints no currency and touches no random outcome. It is free here because
-- there is no developer product id in this game yet (`Config.PASSES.stylePack`
-- is still 0), and shipping a charge against an id that does not exist is a
-- purchase that visibly does nothing. The cooldown below is what stands in for
-- the charge, and it is doing a different job anyway.
--
-- THE COOLDOWN IS ABOUT THE MODERATION API, NOT ABOUT GREED. Every rename is
-- a filter call, and an unbounded rename button is an unbounded call rate on
-- somebody else's service. A child should never be locked out of naming their
-- own pet, so the first name is instant; it is only re-naming that waits.
Config.DOG_NAME = {
	-- Long enough for "Sergeant Barkley", short enough that the kennel board
	-- and the 110px nameplate can both hold it without `TextScaled` quietly
	-- shrinking it to nothing. Measured against the plate rather than chosen.
	maxLength = 16,

	-- Seconds between renames. Not a price and not a punishment: it is a rate
	-- limit on the filter call, and it is short enough that a child who typed
	-- a typo is not stuck with it.
	cooldown = 45,
}

Config.DOG_START_DELAY = 0.9

-- Idle wander between chases. A dog frozen at a corner reads as scenery; one
-- that paces reads as on duty, which is most of what the purchase buys.
Config.DOG_PATROL_RADIUS = 8
Config.DOG_PATROL_SPEED = 0.28 -- fraction of the breed's chase speed
Config.DOG_PATROL_PAUSE = { 2.5, 6.0 }

-- ------------------------------------------------------- THE DOG WATCHES
--
-- LIVE. `HeistService.watchLawns` polls at `pollRate` and is the only thing
-- that reads any of this; `GuardDog` owns the states it puts a dog into
-- (`setOwnerHome`, `alert`, `isWatching`) and knows nothing about players.
--
-- THE PROBLEM IT SOLVED. `GuardDog.chase` used to fire only from a COMPLETED
-- steal, so walking up somebody's drive and working their lock carried no dog
-- risk at all -- every ounce of pressure in this game was on the run home,
-- and the part with the game's name on it was dead air.
--
-- TWO STATES, DECIDED BY WHETHER ANYBODY IS HOME, and between them they fix
-- the thing that killed the first version of this idea: a dog that simply
-- slept whenever its owner left is a pet you paid for and never see.
--
--   OWNER HOME  -- the dog is AWAKE and keeps its owner company. It barks at
--                  an intruder and marks them, and does not chase: the owner
--                  is the defence, and two things that can both hard-stop one
--                  thief on one lawn is how a plot becomes a wall.
--   OWNER AWAY  -- the dog SLEEPS in its kennel, and the lawn is quiet until
--                  somebody makes a noise. Then it is the enforcer, because
--                  nobody else is. A resident's owner is always away.
--
-- AND THE DOG'S OWN POSTURE IS THEREFORE THE TELL for the single most
-- important fact about a target: a dog trotting after somebody means the
-- owner is in and you should expect a fight; a dog curled up in its kennel
-- means the house is empty. Free, no UI, readable from the pavement, using
-- an object that already exists and already moves.
--
-- WHAT WAKES IT. Two things, and both are NOISE rather than presence --
-- standing still on a lawn is never a crime:
--
--   * FOOTSTEPS above the breed's own `notice` speed. Walking (16) wakes any
--     dog; a tiptoe (5.6, or 9.6 fully upgraded) wakes none but a Titan,
--     whose `notice` of 0 means it hears anything that moves at all and has
--     to be answered with a bone instead. That is the ladder this project
--     already runs on -- cheap counters bounce, the expensive one gets
--     through -- arriving at the approach.
--   * A FAILED SLICE OF THE CRACK -- not the crack STARTING, which is what
--     an earlier draft of this block said. The difference is the whole
--     mechanic. If merely working the lock wakes the dog then every robbery
--     is loud, stealth buys only the approach, and a player who is good at
--     the minigame is rewarded with exactly nothing. Waking on a MISS makes
--     the crack the thing skill is spent on: land every slice and the dog
--     sleeps through the entire robbery.
--
--     It also gives the greed dial its teeth, because the two are the same
--     decision seen from either side -- each further slice is worth more AND
--     is another chance to wake the thing that will chase you.
--
-- IT DOES NOT POUNCE. `wakeDelay` is the beat between being disturbed and
-- coming to look, which is what makes a crack a DECISION -- you hear the dog
-- stir and choose whether to finish or bail -- rather than a coin flip. Same
-- shape as DOG_START_DELAY above, and the same reason.
Config.DOG_WATCH = {
	-- How often the lawn is checked. Ten times a second is what the ride
	-- gate already runs at and is far tighter than a dog needs.
	pollRate = 0.1,

	-- Seconds between a disturbance and the dog actually coming. Long enough
	-- to be a warning rather than a verdict.
	wakeDelay = 1.2,

	-- How long the dog stays up with nothing further happening before it
	-- settles back into the kennel. Generous on purpose: a dog that drops
	-- straight back to sleep the instant a thief stops moving would teach
	-- players to walk in one-second bursts, which is a worse game than
	-- either sneaking or running.
	alertSeconds = 12,

	-- A thief caught by a dog while NOT carrying anything is seen off rather
	-- than arrested -- there is no loot to drop. The hold is broken and they
	-- are held still briefly, which costs them the crack they were part way
	-- through and nothing else. Being robbed must stay survivable; so must
	-- failing to rob.
	scareStun = 1.5,
}

-- Returns nil at level 0, which is how every caller checks "is there a dog".
function Config.getDogTier(level: number)
	if level <= 0 then
		return nil
	end
	return Config.DOG_TIERS[math.clamp(level, 1, #Config.DOG_TIERS)]
end

-- ============================================================
-- BONES
-- ============================================================
--
-- The first CONSUMABLE in the game. Every other purchase is a permanent
-- level; a bone is bought, thrown once, and gone.
--
-- It exists because the dog was the only thing in the defence tree with no
-- answer. Locks are answered by lockpicks, fences by taking the gate instead,
-- carry speed by boots -- but a Titan on a plot simply beat anyone who walked
-- in, and "you lose because they bought the expensive one" is the shape of a
-- wall. The same line that governs fences governs dogs: defence buys TIME,
-- never immunity.
--
-- Four things stop the bone from deleting the dog it counters:
--
--   * It costs coins EVERY TIME. Farming a guarded plot becomes an ongoing
--     expense that scales with how well guarded it is -- which is precisely
--     what the defender paid for.
--   * A nap is always shorter than that breed's own cooldown, so a bone buys
--     a window and never a full rest cycle. Waiting out a real chase is still
--     the cheaper option if you have the patience.
--   * Bigger dogs shrug it off (`boneResist` above). A Dog Bone worth nine
--     seconds against Scruffy is worth 5.4 against Titan.
--   * Only the top bone interrupts a chase in progress. The other two have to
--     be thrown BEFORE the dog notices you, which makes them a plan you
--     commit coins to rather than a panic button you mash when barking starts.
--
-- Prices sit deliberately between the two trees' rungs. A Golden Bone costs
-- more than a first Vault Lock, so stocking up is a real alternative to
-- levelling something, not pocket change on the way past.
Config.BONES = {
	bone = {
		name = "Dog Bone", order = 1, cost = 2500, nap = 9, breaksChase = false,
		style = "bone", colour = Color3.fromRGB(238, 230, 208),
		material = Enum.Material.SmoothPlastic,
		blurb = "Buys a getaway. Not long enough to crack a lock as well",
	},
	steak = {
		name = "Juicy Steak", order = 2, cost = 9000, nap = 18, breaksChase = false,
		style = "steak", colour = Color3.fromRGB(176, 68, 62),
		material = Enum.Material.SmoothPlastic,
		blurb = "Long enough for the whole job on most plots",
	},
	golden = {
		name = "Golden Bone", order = 3, cost = 30000, nap = 30, breaksChase = true,
		-- Same silhouette as the Dog Bone, in metal. The shape says "bone" and
		-- the finish says which one, which is how the skins ladder reads too.
		style = "bone", colour = Color3.fromRGB(246, 198, 52),
		material = Enum.Material.Metal,
		blurb = "The only one a dog will break off a chase for",
	},
}

-- How far from the thrower a dog can be lured.
--
-- Sized so a bone reaches the kennel from the KERB: the dog rests about 26
-- studs from the verge, so the whole point -- pre-baiting the dog before you
-- ever set foot on the lawn -- has to work from outside the fence. It stays
-- well under PLOT_SPACING (64) so it cannot casually reach next door's dog.
-- ============================================================
-- DODGE
-- ============================================================
--
-- The one moment in this game with no decisions in it was the chase. A thief
-- runs at 12 and a defender runs at 16, and both of them already know how that
-- ends before it starts -- there is nothing to do but hold W and watch a
-- subtraction happen. This is the timing decision that was missing.
--
-- IT IS A MULTIPLIER ON currentSpeed, NOT A TELEPORT, AND THAT IS THE WHOLE
-- TRICK.
--
-- Everything about a burst of movement is dangerous here, because
-- BASE_WALK_SPEED is what the carry penalty, the three dog speeds, every fence
-- snag and the length of a getaway are all measured against. Implementing this
-- as an impulse or a CFrame nudge would have been a second, parallel way to
-- move that none of those numbers knew about.
--
-- Instead it is one more factor in the function that already owns every speed
-- in the game, which means it inherits all of them without a line of new
-- balance code:
--
--   stunned    -> currentSpeed returns 0 before this is even reached, so a
--                 zapper or an electric fence cannot be rolled out of
--   carrying   -> the dodge scales off 12, not 16
--   snagged    -> a snagged dodge is a slow dodge, in proportion
--   riding     -> refused outright; you do not roll off a moving scrambler
--
-- The DISTANCE is deliberately small. A carrying thief covers 3 studs in a
-- quarter second normally and 7.5 while dodging, so one dodge is worth about
-- four and a half studs -- roughly a tenth off a 37-stud getaway. The point
-- was never the ground gained.
--
-- A DODGE SUPPLIES ITS OWN DIRECTION.
--
-- Being a multiplier means a player standing still dodged at 2.5x of
-- nothing and went nowhere, so the control did nothing at all unless you
-- were already running. The client now drives the humanoid's move
-- direction for the length of the window: whatever is being held, or the
-- way the character is facing when nothing is.
--
-- Note what that is NOT. It is not an impulse, a velocity or a CFrame
-- nudge -- it is the same multiplier as before with a direction attached,
-- so it still goes through the one movement system every other number
-- here is expressed in. A fence still stops the dash dead: measured, a
-- dodge into a piggy bank 1.5 studs away travelled 3.81 studs instead of
-- the 9.76 it covers on open ground.
--
-- The GAIN is unchanged, which is what the balance actually rests on: a
-- carrying thief still nets about four and a half studs over simply
-- running. What is new is only that a stationary player gets to move.
--
-- THE IMMUNITY IS THE POINT. For half a second you cannot be nabbed, caught by
-- a dog, or hit by a gadget. NAB.hold is 0.4s, so a defender who eats a dodge
-- has to start their hold again -- a real cost, paid in the currency of the
-- chase rather than in coins.
--
-- A DODGE BUYS A MOMENT, NEVER AN ESCAPE. The dog keeps chasing, the defender
-- keeps running, and the five-second cooldown means roughly one dodge per
-- getaway. It is a decision about WHEN, which is exactly what the chase had
-- none of.
--
-- Free, and everybody has it. A dodge is a control rather than a power: gating
-- it behind coins would mean new players are playing a different game from
-- everybody else at the only moment that matters. It is also symmetric -- a
-- defender gains the same few studs -- so the pursuit maths is unchanged, and
-- only the immunity favours the person being chased, which is the intent.
Config.DODGE = {
	-- Against whatever the dodger's speed already is, not against 16.
	multiplier = 2.5,
	duration = 0.25,
	-- Longer than the roll, so the tail of it is covered too.
	immunity = 0.5,
	cooldown = 5,
}

-- ============================================================
-- THIEF KIT
-- ============================================================
--
-- The offence tree's answer to the defender's two newest counters.
--
-- Gadgets closed the maxed-boots hole and the Guard Duty Treat closed the
-- cheap-bone hole, and both landed with nothing given back. These are the
-- other half of that trade.
--
-- THE DISGUISE HIDES THE WAIT, NEVER THE GETAWAY.
--
-- Worth being honest about what it is for. The guard dog does not watch an
-- approach at all -- GuardDog.chase only fires from HeistService.attemptSteal,
-- after a completed steal -- so walking up to a piggy was never dangerous.
-- All the pressure in this game is on the run home.
--
-- So this is a WAITING tool. You stand on somebody's lawn as a wheelie bin
-- while their vault fills, or while their sixty-second steal cooldown runs
-- down, or through six minutes of guard duty until the collar stops glowing.
-- That is a new kind of play rather than a shortcut through an old one, and
-- it makes the treat and the disguise argue with each other.
--
-- It is self-limiting by construction, which is why it needs no timer worth
-- tuning: standing still IS the disguise. Move and you are a person again.
-- And it breaks the instant loot is picked up, without exception -- the run
-- home is the risk half of the whole trade and must stay visible.
--
-- THE RAINCOAT MIRRORS THE GUARD DUTY TREAT, DELIBERATELY.
--
-- The two cheap gadgets slide off it; the expensive one still lands. That is
-- the same shape as the treat (cheap bones bounce, the Golden Bone gets
-- through) and it does the same job: it raises the price of stopping somebody
-- rather than making them unstoppable. A defender who wants a warded thief
-- stopped pays 22,000 for the Zapper instead of 1,500 for a Plunger.
--
-- Notice what neither of these touches: SPEED. It stays capped at 16 by
-- getCarryMultiplier, and every one of the dog speeds, fence snags and
-- getaway distances is still measured against it.
-- ============================================================
-- WHEELIE BINS
-- ============================================================
--
-- PUBLIC COVER, OWNED BY NOBODY, BUILT WITH THE ROAD.
--
-- The disguise used to turn you INTO a wheelie bin, which was wrong twice
-- over and both were the same mistake: a costume has to be PLAUSIBLE. `bins`
-- is a verge item, so the decor system will not let an owner put one on their
-- lawn even if they bought it -- and the prop was squared to the WORLD rather
-- than to the plot, so on the six far-row plots it stood backwards to every
-- real ornament around it. Neither was tunable. A hiding PLACE carries none of
-- that burden: the bin is already there, the game put it there, it is already
-- straight, and nobody has to own it.
--
-- A BIN BUYS A BREATH, NEVER AN ESCAPE. Same line the bones draw on the other
-- side of the fight. You do not lose a pursuer by getting in -- they converge
-- on the bin and dig you out. What you buy is the LINE: they arrive stopped,
-- at a known point, and you come out facing wherever you like instead of being
-- run down from behind at 14.5 against your 12.
--
-- SO YOU MAY HIDE WHILE CARRYING, and that reverses the old rule that the
-- disguise broke the instant you picked up loot. The reason that rule existed
-- -- the run home is the risk half of the trade and has to stay visible -- is
-- kept, but paid for with information rather than a refusal: a bin with loot
-- in it overflows, and anyone standing next to it can see which one you are
-- in. Hiding with the goods is riskier than hiding without.
Config.BINS = {
	-- Long enough that diving in with somebody on your heels just gets you
	-- nabbed -- NAB.hold is 0.4, so a 1.2 entry cannot be won from contact.
	-- You have to make a gap first, which is the whole skill.
	enterHold = 1.2,

	-- Shorter than entry. A chaser who has worked out which bin has already
	-- done the hard part; making them out-wait the person hiding would be
	-- charging them twice for it.
	openHold = 0.6,

	-- ONE BIN PER PURSUIT, expressed as a cooldown on the PLAYER rather than
	-- on the bin. Jamming the lid behind you would only send you to the next
	-- one, and bin-to-bin down the street is exactly the kiting this is not
	-- meant to allow. Set against POLICE.chase (30) so a single patrol gets a
	-- single hide.
	cooldown = 20,

	-- A hard ceiling, only so nobody can sit in one forever. Reaching it is
	-- not the point; the pursuit ending is.
	maxSeconds = 120,

	-- TIGHT, AND MEASURED AGAINST THE ROAD RATHER THAN CHOSEN.
	--
	-- A bin hatch sits at |z| 9.8 -- ROAD_HALF_WIDTH plus 1.8, the same verge
	-- line the lamp posts stand on. At 14 that circle reached the centre of
	-- the carriageway, so a player could climb into a bin while standing on
	-- the white line halfway across the street, which is not hiding, it is
	-- teleporting into cover.
	--
	-- At 5 the centreline is 9.8 away and refused, while the kerb at |z| 8 is
	-- 1.8 away and works. You have to actually reach the thing. It cannot be
	-- much tighter than this and stay usable: the tarmac edge is only 1.8
	-- studs from the bin, so any range a running player can hit at all lets
	-- them stand slightly on the road -- what matters is that it is the KERB
	-- and not the middle of the street.
	range = 5,

	-- How far out of the bin you are put when you climb out. Clear of the
	-- 5.8-stud cluster without being a teleport.
	exitPush = 4.5,

	-- COMING OUT IS A VAULT, AND IT IS WORTH ABOUT ONE DODGE.
	--
	-- The exit used to be a silent snap 4.5 studs sideways: the right
	-- position, arrived at with nothing to watch. It now pops the lid, plays
	-- the somersault the dodge already uses, hops, and hands out a short
	-- burst of speed.
	--
	-- THE BURST IS A MULTIPLIER ON currentSpeed, never an impulse -- the same
	-- decision Config.DODGE records and for the same reason. currentSpeed is
	-- the one function that owns every speed in this game, so a factor added
	-- there inherits all of them with no new balance code: a stun returns 0
	-- before it is ever reached, carrying scales it off 12 rather than 16, a
	-- fence snag scales it down proportionally, and a ride refuses it. An
	-- impulse or a CFrame nudge would be the second, parallel way to move that
	-- BASE_WALK_SPEED exists to prevent.
	--
	-- IT TAPERS from `peak` to nothing across `seconds`, which is what makes
	-- it slight rather than a sprint. Mean excess is half the peak, so the
	-- ground it actually buys is 16 x 0.15 x 2.0 = 4.8 studs on foot -- which
	-- is deliberately about ONE DODGE (documented at 4.5), spread over two
	-- seconds instead of half of one. A flat 1.30 for the same window would
	-- buy 9.6 and be worth two.
	--
	-- Carrying, it peaks at 15.6 against an officer's 14.5 and falls back
	-- under them after roughly half a second. That is the whole of it, and it
	-- is deliberate: A BIN BUYS A BREATH, NEVER AN ESCAPE. What you are paid
	-- for is the LINE -- your pursuer arrives stopped at a known point and you
	-- come out facing wherever you like -- and the burst is what makes
	-- choosing that moment feel like it did something. It must never become
	-- enough to simply outrun the person who found you.
	exitBurst = { peak = 1.30, seconds = 2.0 },

	-- Straight up, and only up. 30 studs/s is a 2.29-stud apex against a
	-- normal jump's 7.2 -- a vault out of a bin rather than a launch. Any
	-- HORIZONTAL component here would be exactly the parallel movement system
	-- the note above rules out, so there is none.
	exitHop = 30,

	-- The lid. Hinged at its BACK edge like a real one, thrown open fast and
	-- allowed to drop shut more slowly, because that is the order those two
	-- things happen in and a symmetrical swing reads as a hatch rather than a
	-- lid somebody just burst through.
	lidSwing = 78,
	lidOpen = 0.12,
	lidShut = 0.5,
}

-- ONE ITEM, since the Disguise Kit was removed.
--
-- It had never worked: `prop` named "bins", which is not a key in
-- Config.DECOR_ITEMS, so `Decor.buildOne` returned nil and `conceal` refused
-- SILENTLY -- a 4,000-coin purchase that did nothing and said nothing. The
-- wheelie-bin fantasy it was selling is delivered properly by the public bins
-- NeighborhoodService puts on the kerb, which are a live feature with their
-- own enter prompt, so nothing was lost by dropping the consumable.
-- THE LADDER IS THE OFFENCE TREE'S ANSWER TO THE FENCE TREE, and it is the
-- same shape as a bone against the guard dog: the counter to a purchase that
-- had none, priced per use so beating a defence is an ongoing expense rather
-- than a one-off.
--
-- THERE IS NO BUILT-IN WAY OVER A FENCE ANY MORE. Every segment used to carry
-- a permanent climbing trellis, which made a fence a slower floor rather than
-- a wall and put a ladder on tiers you can step over. A fence is solid now,
-- and the ladder is what crosses it.
--
-- THAT DOES NOT MAKE A PLOT UNCROSSABLE, which is the rule this brushes
-- against. The gate is always open -- 24 studs wide at tier 1, still 8 at
-- tier 5 -- so the plot is enterable by anybody at any tier with no item at
-- all. What the fence now genuinely stops is the SIDE and BACK crossing, the
-- alley shortcut between two neighbours, and what the ladder buys is a route
-- that is not the front door.
--
-- WHICH IS WHY IT IS BOUGHT BEFORE THE ROBBERY RATHER THAN DURING IT. A
-- vault lock hold runs to twelve seconds against a ladder that stands for
-- twenty, so placing your exit and then committing to the lock is a race
-- against your own timer. That is the decision this item exists to create.
--
-- IT BUYS THE CLIMB AND NEVER THE HAZARD. The ClimbZone still sits above the
-- barrier, so an electric fence zaps a laddered climber exactly as it zaps
-- anybody else. Defence buys time; so does the counter.
Config.LADDER = {
	-- Long enough to rob and get back to, short enough that it is a plan
	-- rather than a permanent hole in somebody's fence.
	seconds = 20,
	-- The last stretch fades rather than vanishing. A ladder that disappears
	-- under a climber is fair; one that does it with no warning is a yank.
	fade = 2.5,
	-- How close to a fence you have to be standing to put one up. Deliberately
	-- short: the placement IS your position, so this is the whole of what
	-- stops a ladder appearing on a fence you are nowhere near.
	reach = 9,
	-- How far the top stands above the barrier, so there is something to
	-- mantle onto rather than a climb that ends exactly level with the wall.
	overhang = 1.2,
	-- Kept off a segment's own ends, so a ladder cannot be wedged into the
	-- corner where two barriers meet and end up climbable from neither side.
	margin = 2.0,
}

Config.THIEF_KIT = {
	ladder = {
		name = "Ladder", style = "ladder", order = 1,
		cost = 5000,
		-- Only ever the shop icon and the prop in the hand. The one that goes
		-- against a fence is built to that fence's own height, because `top`
		-- is the climb length and the two must not disagree.
		height = 7.0,
		blurb = "Stand it against any fence too tall to jump",
		detail = "Up for 20 seconds, either way over. The top of the fence still gets you.",
	},
	raincoat = {
		name = "Raincoat", style = "raincoat", order = 2,
		cost = 8000,
		blurb = "The next plunger or bubblegum slides right off",
		detail = "Stays on until something bounces. A Zapper still gets you.",
	},
}

function Config.thiefKitCount(): number
	local n = 0
	for _ in pairs(Config.THIEF_KIT) do
		n += 1
	end
	return n
end

-- ============================================================
-- HOME ITEMS
-- ============================================================
--
-- Things you use on your OWN plot. Neither can be aimed at anybody, anywhere,
-- ever -- they act on your dog and on your lawn, and that is what keeps them
-- out of the harassment bracket the gadgets had to be designed around.
--
-- THE TREAT EXISTS TO GET PEOPLE OUT OF THE HOUSE.
--
-- The economy needs players robbing each other, and the thing that stops them
-- is anxiety about their own vault: there is no "lock up before you go out"
-- action, so the only way to protect a full piggy is to sit on it. That is a
-- player choosing to do nothing, which is the worst outcome the design has.
--
-- It deliberately does NOT grant immunity. A Golden Bone still gets through,
-- which is the same line the chase-break already draws -- the cheap bones are
-- refused, the 30,000-coin master key is not. So a prepared defender makes
-- robbing them cost twelve times more, rather than making it impossible:
--
--     Dog Bone     2,500   bounces off
--     Juicy Steak  9,000   bounces off
--     Golden Bone 30,000   still works
--
-- That matters because an alert dog is genuinely dangerous. A Titan runs at 17
-- against a thief carrying at 16 with boots maxed, so "always awake and cannot
-- be bribed" would be an un-robbable plot, which is the one failure state this
-- whole game is arranged to avoid.
--
-- And it is LOUDLY VISIBLE -- neon collar, ON GUARD on the nameplate. The
-- counter to a buff should be information, not a fight: a thief reads it from
-- the pavement and walks to one of the other eleven plots. The defender gets
-- peace of mind, the robber loses nothing but a few seconds, and nobody burns
-- a Golden Bone finding out.
--
-- THE SPRINKLER IS A JOKE, AND IS MEANT TO STAY ONE.
--
-- No damage, no stun, no slow -- it nudges trespassers toward the gate and
-- soaks them, and they can walk straight back in. That is deliberate on two
-- counts. Loitering is not actually a mechanical problem here (STEAL_COOLDOWN
-- already makes camping a plot pointless), so the
-- irritation is social and the answer should be too. And anything with teeth
-- would be a fourth defence stacking on the fence, the dog and the locks --
-- and would bite during a steal attempt, since a thief cracking a lock is
-- stood still on that very lawn.
-- GUARD DUTY DOES NOT STACK, AND CANNOT BE RE-APPLIED THE MOMENT IT LAPSES.
--
-- Ten treats used to buy an hour: setGuardDuty added its duration to
-- whatever was left, so 100,000 coins bought a dog that never napped and
-- never took a cheap bone. That is immunity, and defence buys TIME.
--
-- Refusing the stack alone does not fix it. Without a lockout an owner
-- simply re-applies the second it expires, and the plot is guarded
-- permanently with no gap -- the same exploit, one click at a time. So the
-- lockout runs from EXPIRY, which is what guarantees the window exists.
--
-- Six minutes on, four off. The dog is bribeable for 40% of every cycle,
-- and which state it is in is readable from the pavement because the
-- collar is lit or it is not.
--
-- It also makes an existing counter reachable. The Wheelie Bin is sold on
-- standing still "through six minutes of guard duty until the collar stops
-- glowing" -- against an owner who could top up on expiry, that wait could
-- never end, and the disguise was advertising something it could not do.
Config.GUARD_DUTY_LOCKOUT = 240

Config.HOME_ITEMS = {
	treat = {
		name = "Guard Duty Treat", style = "treat", order = 1,
		cost = 10000, duration = 360,
		blurb = "Your dog stays awake and refuses bribes for six minutes",
		detail = "Cheap bones bounce off. A Golden Bone still works.",
	},
	sprinkler = {
		name = "Garden Sprinkler", style = "sprinkler", order = 2,
		cost = 3000, duration = 20,
		blurb = "Soaks anybody loitering on your lawn",
		detail = "Pushes them toward the gate. No damage, just rude.",
	},
	-- NO DURATION, deliberately, and it is the only item here without one.
	-- A treat and a sprinkler are buffs that run on your plot for a while;
	-- this is a phone call. What it starts is a patrol, which has its own
	-- published clock that the whole server can already see.
	radio = {
		name = "Patrol Radio", style = "radio", order = 3,
		cost = 75000,
		blurb = "Calls the patrol onto the street right now",
		detail = "You don't get to say who for. It might be you.",
	},
}

-- How hard the sprinkler shoves, and how often it re-shoves.
--
-- Small on purpose. This is a nudge and a laugh, not a launcher: anything
-- strong enough to actually clear the lawn would be a defence, and would throw
-- players into the road, which at these plot spacings means into somebody
-- else's yard.
Config.SPRINKLER_PUSH = 26
Config.SPRINKLER_LIFT = 12
Config.SPRINKLER_TICK = 0.7

function Config.homeItemCount(): number
	local n = 0
	for _ in pairs(Config.HOME_ITEMS) do
		n += 1
	end
	return n
end

-- ============================================================
-- GADGETS
-- ============================================================
--
-- The defender's answer to maxed Speed Boots, and it exists for exactly the
-- reason bones do: a top-of-tree purchase had no counter.
--
-- getCarryMultiplier caps at 1.0, so a thief with boots maxed carries at 16 --
-- the SAME speed as the person chasing them. Nabbing becomes impossible
-- unless you are already standing on top of them. That is the hole. These
-- close it, and nothing more.
--
-- A GADGET BUYS A TAG, NEVER THE CATCH. Three properties hold that line:
--
--   * They cost coins EVERY throw, so defending an attractive plot is an
--     ongoing expense rather than a one-off purchase.
--   * TAGGING still recovers the loot. A gadget is setup: it slows or stops,
--     and you must still close and tag. That keeps the terminal action the
--     one that was already there.
--   * Range is short and FALLS as power rises, so the decisive one cannot
--     reach a thief who already got clear.
--
-- A FOURTH RULE USED TO STAND HERE -- that the ONLY valid target was somebody
-- carrying loot -- and it went in two stages, a session apart. Both are worth
-- keeping, because the first one was only half a fix and read for a while as
-- though it were a whole one.
--
-- IT WAS NEVER ABOUT THE TREE'S BALANCE. It was that a gadget pointable at
-- anybody is a harassment toy handed to under-twelves. But what makes a toy
-- harassment is the EFFECT, not the aim: being able to take somebody's
-- movement away, repeatedly, at will.
--
-- STAGE ONE OPENED THE AIM AND HELD THE EFFECT DOWN. A hit on somebody who
-- was not carrying became a PRANK -- about a second, the zapper's dead stop
-- capped to a blink, and the raincoat never even looked at it. Its own
-- summary line was that it "cannot start, help or finish a robbery, because
-- the SERIOUS effect still requires the target to be carrying."
--
-- STAGE TWO DELETED THAT SENTENCE, BECAUSE IT WAS ALSO A DESCRIPTION OF THE
-- ONE THING THIS GAME CANNOT DO. Every mechanic here is adversarial except a
-- passive friend bonus, and the obvious cooperative play -- you hold the
-- owner, I crack the pig -- was refused by exactly those three numbers. A
-- defender standing on their own lawn could be hit and could not be
-- affected. So the effect opened too: it is the real one now, whoever is
-- hit, and `Config.GADGET_GUARD` is the whole of what keeps that safe. See
-- the note there for why a cooldown on the PERSON BEING HIT is the right
-- instrument and a cap on the effect never was.
--
-- WHAT STILL HOLDS, UNCHANGED, is everything that made a gadget setup rather
-- than a finisher: it costs coins every throw, tagging is still what recovers
-- the loot, and nothing is stolen, dropped or lost by a gadget at any time.
-- A raincoat still sheds the two cheap ones -- and now sheds them for
-- somebody who is not carrying too, WITHOUT being spent, so the grief the old
-- rule was really worried about (burning a 22,000-coin coat with a 1,500-coin
-- throw off somebody who was not even robbing anybody) is still refused.
--
-- AND THE TARGET IS CHOSEN BY THE THROWER NOW RATHER THAN BY PROXIMITY. A
-- gadget used to find the nearest carrier, then the nearest drone, then the
-- nearest anybody, all measured from the thrower -- so "which of those two do
-- I stop" was a decision the game made on your behalf. It is aimed. See
-- Config.THROW.
--
-- The three differ in KIND rather than just in magnitude -- reach, denial,
-- finisher -- which is what stops the cheap two being dead weight once the
-- expensive one is affordable.
--
-- The arithmetic each was tuned against, worst case: thief at 16 (boots
-- maxed), defender at 16, both running in a straight line, NAB.distance 14.
--
--   plunger  from 34 studs -> ends at 24.4   never a catch on its own
--   gum      from 26 studs -> ends at  8.4   a catch, if you run it perfectly
--   zapper   from 18 studs -> ends at  0.7   a catch, but only from close in
Config.GADGETS = {
	plunger = {
		name = "Plunger", style = "plunger", order = 1,
		cost = 1500, range = 34, slow = 0.70, duration = 2.0, stun = 0,
		colour = Color3.fromRGB(196, 66, 58), trim = Color3.fromRGB(168, 124, 82),
		blurb = "Sticks to their back. Throw it at anyone, any time",
		hit = "A plunger just stuck to your back!",
		prank = "%s stuck a plunger to your back!",
	},
	gum = {
		name = "Bubblegum Bomb", style = "gum", order = 2,
		cost = 6000, range = 26, slow = 0.50, duration = 2.2, stun = 0,
		colour = Color3.fromRGB(240, 130, 190), trim = Color3.fromRGB(255, 196, 224),
		blurb = "Bursts into a pink puddle nobody runs through quickly",
		hit = "You're stuck in bubblegum!",
		prank = "%s got you with a bubblegum bomb!",
	},
	zapper = {
		name = "Zapper", style = "zapper", order = 3,
		cost = 22000, range = 18, slow = 0.60, duration = 1.2, stun = 0.6,
		colour = Color3.fromRGB(52, 58, 72), trim = Color3.fromRGB(120, 226, 255),
		blurb = "Stops them dead for half a second. You have to be close",
		hit = "Zapped! You seized up for a moment.",
		prank = "%s zapped you! Bzzzt.",
	},
}

-- Same cooldown as a bone: these are the same gesture, and two different
-- throw feels in one hand would be worse than one.
Config.GADGET_THROW_COOLDOWN = 1.5

-- ============================================================
-- AIMING A GADGET
-- ============================================================
--
-- A GADGET IS AIMED AND A BONE IS NOT, AND THAT SPLIT IS THE WHOLE DESIGN.
--
-- Every throw in this game used to be a guaranteed hit. `arc` re-read the
-- target's position every frame and lerped to it, so the flight was
-- DECORATIVE: pick the item, press the button, it lands, always. There was
-- nothing in a throw to be good at -- and the target was chosen by proximity
-- rather than by the player, so "which of those two do I stop" was a
-- decision the game quietly made on your behalf.
--
-- BONES STAY AUTOMATIC, DELIBERATELY. The whole "cheap counters bounce, the
-- expensive one gets through" balance assumes a bone LANDS: `boneResist` is
-- what makes a tier hard, not somebody's thumb. A dog is also a small fast
-- thing crossing a lawn at up to 17 studs a second, so making that a test of
-- aim would re-price every dog tier by accident and would land hardest on
-- the tablet half of this audience. Nothing in BoneService changed.
--
-- IT IS A BALLISTIC PROJECTILE NOW, AND IT WAS A LOB FOR ONE SESSION. That
-- first version threw along the FLAT facing to a fixed point `spec.range`
-- away, on a fixed parabola -- so pitch was discarded, every throw travelled
-- exactly the same distance whether the target was three studs away or
-- thirty, and it read as tossing a bomb at a marked spot rather than as
-- throwing something AT somebody. Both halves of that were wrong for a
-- plunger.
--
-- What replaces it is the honest version: it launches along the FULL aim
-- direction, pitch included, at `speed`, and `gravity` pulls it down for as
-- long as it is in the air. So the two skills are:
--
--   * POINT AT THEM, in three dimensions rather than two.
--   * LEAD THEM, because it takes real time to arrive.
--   * AND AIM HIGH FOR ANYTHING FAR AWAY, because it drops.
--
-- THE DROPOFF IS THE POINT AND THE TWO NUMBERS ARE SOLVED FOR IT. Drop over
-- a level throw is `gravity/2 * (distance/speed)^2`, so at 60 and 64:
--
--     10 studs   0.9 of drop    inside `hitRadius` -- point straight at them
--     18 studs   2.9            still inside it: the zapper is a flat weapon
--     26 studs   6.0            over it -- the gum needs a little elevation
--     34 studs  10.3            the plunger's far end wants real compensation
--
-- So a gadget is point-and-shoot at conversation range and a judged lob at
-- the end of its reach, with the change arriving gradually rather than at a
-- line somebody drew. That is what `hitRadius` being 4.5 actually buys: it
-- is the distance at which the drop stops mattering.
--
-- GRAVITY IS OURS AND NOT `workspace.Gravity`, WHICH IS 196.2 AND WOULD MAKE
-- THIS UNTHROWABLE. Three reasons and only the first is about feel: a real
-- gravity puts 34 studs of drop on a 34-stud throw, which is a mortar rather
-- than a plunger; the preview on the client has to trace the identical curve
-- and a shared constant is the only way two implementations cannot disagree;
-- and `workspace.Gravity` is a global somebody may retune for jumping, which
-- would silently re-aim every gadget in the game.
--
-- AND THE REMOTE CARRIES A DIRECTION NOW, WHICH REVERSES A RULE AND IS WORTH
-- BEING EXACT ABOUT. `GadgetThrow` used to carry a key and nothing else, and
-- the first aimed version kept that by reading the CHARACTER'S OWN FACING on
-- the server -- which works right up until pitch matters, because a Roblox
-- character cannot look up or down. There is no way to aim a lob from data
-- the server already holds.
--
-- What the old rule protected was "no coordinate to forge and no range check
-- to defeat", and BOTH SURVIVE: the server still owns the origin (its own
-- copy of the root), the speed, the gravity, the range cap, the hit radius
-- and the entire simulation. A direction is not a position -- forging one
-- lets you aim wherever you like, which is the FEATURE. What a forged
-- direction could buy is a perfect lead-and-drop solution every time, and
-- that is the same thing this file already decided about the crack: the best
-- outcome of a perfectly forged client is landing every one, which is also
-- what a good player gets, and a gadget costs coins per throw and only slows
-- somebody down. There is no jackpot here to protect.
Config.THROW = {
	-- Studs a second along the aim direction, and it is a SPEED rather than
	-- a flight time because the lead a player has to learn is "how far do
	-- they move while it is in the air" -- only learnable if the answer does
	-- not change per item. At 60 a plunger crosses its full 34 studs in
	-- 0.57s, over which a runner covers 9.1 against a hit radius of 4.5, so
	-- a throw aimed straight at somebody sprinting sideways still misses.
	speed = 60,

	-- Studs per second squared of drop. See the table above: this is the
	-- number that decides where "point straight at them" stops working, and
	-- it is the one to turn if the dropoff reads as too harsh or too flat.
	gravity = 64,

	-- How close the projectile has to pass to count as a hit. THE ONLY
	-- FORGIVENESS DIAL, and it is what makes the near half of every gadget's
	-- range point-and-shoot: under about 15 studs the drop is inside it.
	hitRadius = 4.5,

	-- How close an aimed throw has to pass an ALIEN DRONE to knock it down,
	-- and it is wider than `hitRadius` for a geometric reason rather than a
	-- generosity one: a drone hovers about fifteen studs up, so measured on
	-- a person's radius an aimed gadget would pass underneath one and a raid
	-- would quietly stop having a counter. Throwing roughly AT one is what a
	-- raid always asked for -- it is a big slow thing over somebody's lawn,
	-- not a sprinting player.
	droneRadius = 18,

	-- How far above the root the throw leaves the hand.
	launchHeight = 2.5,

	-- Degrees the aim may be tilted, up or down. It exists to refuse a
	-- forged straight-up or straight-down direction rather than to shape
	-- play: nothing a player can do with a camera comes near it.
	maxPitch = 75,

	-- A hard stop, so a throw lobbed off the edge of the world cannot leave
	-- a loop running. The ground or the range cap ends every real throw long
	-- before this.
	maxSeconds = 4,
}

-- NORMALISED AND PITCH-CLAMPED, and nil for anything that is not a usable
-- direction. The one place a client's aim is taken apart, so a forged
-- payload meets exactly one gate rather than three call sites that each
-- forgot a different case.
function Config.throwClampDirection(dir: any): Vector3?
	if typeof(dir) ~= "Vector3" then
		return nil
	end
	local m = dir.Magnitude
	-- Rejects (0,0,0) and anything carrying a NaN, which fails every
	-- comparison including this one.
	if not (m > 1e-4) or m ~= m then
		return nil
	end

	local unit = dir.Unit
	local flat = Vector3.new(unit.X, 0, unit.Z)
	if flat.Magnitude < 1e-4 then
		-- Straight up or straight down carries no heading to clamp against,
		-- so there is nothing to salvage.
		return nil
	end

	local limit = math.rad(Config.THROW.maxPitch)
	local pitch = math.clamp(math.asin(math.clamp(unit.Y, -1, 1)), -limit, limit)
	return (flat.Unit * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)).Unit
end

-- The launch velocity for an already-clamped direction.
function Config.throwVelocity(dir: Vector3): Vector3
	return dir * Config.THROW.speed
end

-- Where the projectile is `t` seconds after it left the hand. THE ONE CURVE:
-- the server flies the real thing through this and the client traces its
-- preview through it, so the dotted line somebody is looking at and the
-- throw they are about to make cannot disagree.
function Config.throwPointAt(origin: Vector3, velocity: Vector3, t: number): Vector3
	return origin + velocity * t - Vector3.new(0, 0.5 * Config.THROW.gravity * t * t, 0)
end

-- How far a LEVEL throw falls over a given horizontal distance. The flight
-- itself steps `throwPointAt` rather than calling this; what reads it is the
-- audit below, which is the whole reason it is a function and not a comment.
function Config.throwDrop(distance: number): number
	local t = distance / Config.THROW.speed
	return 0.5 * Config.THROW.gravity * t * t
end

-- IS A GADGET STILL POINT-AND-SHOOT UP CLOSE AND A LOB FAR OUT?
--
-- The whole feel of an aimed throw is one relationship between three numbers
-- -- `speed`, `gravity` and each gadget's `range` -- and NOTHING ABOUT IT
-- ERRORS WHEN IT GOES WRONG. Make gravity a little too low and every throw
-- is flat, so the aiming is decorative and the drop nobody has to think
-- about might as well not exist. Make it a little too high, or lengthen a
-- range, and the near half stops working: a player pointing straight at
-- somebody ten studs away watches it land at their feet, which reads as the
-- item being broken rather than as a skill they have not learned.
--
-- That is the same shape as every other audit in this file. `auditFences`
-- was clean through the entire period every tier was jumpable because it
-- asked the wrong question; `auditRobbery` exists because two curves were
-- multiplied for months without anybody checking the product. So the
-- relationship gets checked at startup rather than remembered.
--
-- TWO QUESTIONS, AND THEY PULL IN OPPOSITE DIRECTIONS ON PURPOSE. The
-- SHORTEST-range gadget has to be flat at its own maximum -- that is what
-- makes the zapper a thing you point -- and the LONGEST-range one has to
-- drop more than `hitRadius` at its maximum, or nobody ever has to aim high
-- and the mechanic is a lie. A single check could be satisfied by making
-- everything flat or everything a mortar; the pair cannot.
function Config.auditThrow(): { string }
	local problems = {}
	local shortest, longest
	for key, spec in pairs(Config.GADGETS) do
		if not shortest or spec.range < Config.GADGETS[shortest].range then
			shortest = key
		end
		if not longest or spec.range > Config.GADGETS[longest].range then
			longest = key
		end
	end
	if not shortest or not longest then
		return problems
	end

	local radius = Config.THROW.hitRadius
	local near = Config.throwDrop(Config.GADGETS[shortest].range)
	if near > radius then
		table.insert(problems, ("the shortest gadget (%s, range %d) already drops %.1f studs at its own maximum, against a hit radius of %.1f -- so there is no distance at which pointing straight at somebody works, and every throw reads as broken. Lower THROW.gravity or raise THROW.speed.")
			:format(Config.GADGETS[shortest].name, Config.GADGETS[shortest].range, near, radius))
	end

	local far = Config.throwDrop(Config.GADGETS[longest].range)
	if far <= radius then
		table.insert(problems, ("the longest gadget (%s, range %d) only drops %.1f studs at its own maximum, inside a hit radius of %.1f -- so nothing in the game ever has to be aimed high and the dropoff is decorative. Raise THROW.gravity or lower THROW.speed.")
			:format(Config.GADGETS[longest].name, Config.GADGETS[longest].range, far, radius))
	end

	return problems
end

-- WHAT A GADGET DOES TO SOMEBODY WHO IS NOT CARRYING ANYTHING: THE SAME
-- THING IT DOES TO EVERYBODY ELSE, WHICH REVERSES WHAT THIS TABLE SAID.
--
-- It held three numbers. A `duration` of 0.9 seconds and a `stunCap` of 0.3
-- are gone, and the rule they encoded went with them: that a hit on a
-- non-carrier is a PRANK, which "cannot start, help or finish a robbery,
-- because the effect that matters in a chase still requires the target to be
-- holding somebody's coins."
--
-- THAT SENTENCE IS ALSO THE ONE THAT MADE HELPING SOMEBODY ROB IMPOSSIBLE,
-- which is why it had to go. A defender standing on their own lawn while a
-- friend cracked their pig was untouchable: you could hit them, and hitting
-- them did nothing worth doing. So the one genuinely cooperative play this
-- game has to offer -- YOU HOLD THEM, I TAKE THE COINS -- could not be made
-- by anybody, and the entire gadget tree was blind to the defensive half of
-- a robbery. Two children robbing a house together is the best thing on
-- offer here and three numbers quietly refused it.
--
-- SO THE EFFECT IS THE REAL ONE NOW, WHOEVER IS HIT, and `targetCooldown` is
-- the only thing left holding the harassment line. That is the right
-- instrument and always was: it is keyed to the PERSON BEING HIT and never
-- to the thrower, so six players with plungers cannot take turns. The bound
-- on what an entire server can do to one child is the same bound as one
-- player on their own, however many are throwing and however rich they are.
--
-- IT IS DERIVED FROM THE PENALTY IT GUARDS RATHER THAN PINNED, which is the
-- rule the fence penalty already lives under: a cooldown shorter than the
-- thing it guards merely lets the next one land as the last expires, which
-- is the same freeze at a slower rate. At `restMultiple` 4 a target can be
-- held for at most a quarter of any stretch of time -- the gum's 2.2 seconds
-- buys 8.8 of quiet and the zapper's 1.2 buys 4.8 -- so a longer gadget
-- earns a longer rest with nothing to remember, and what is actually bounded
-- is the DUTY CYCLE rather than a number somebody typed.
--
-- `minRest` is the floor for anything short enough that the multiple would
-- not produce a real gap.
Config.GADGET_GUARD = {
	restMultiple = 4,
	minRest = 4,
}

-- How long somebody is left alone after taking a gadget outside a robbery.
function Config.gadgetRest(duration: number): number
	return math.max(Config.GADGET_GUARD.minRest, duration * Config.GADGET_GUARD.restMultiple)
end

function Config.gadgetCount(): number
	local n = 0
	for _ in pairs(Config.GADGETS) do
		n += 1
	end
	return n
end

Config.BONE_THROW_RANGE = 42

-- Stops a held button from spraying bones and spawning a dozen models. It is
-- not a balance number; the coin cost is the balance number.
Config.BONE_THROW_COOLDOWN = 1.5

-- Arc time from hand to ground. The bone is lerped along a fixed parabola
-- rather than thrown with physics: an unanchored part rolls, falls through
-- thin geometry, and lands somewhere nobody aimed at. Everything else that
-- moves in this game is anchored and lerped for the same reason.
Config.BONE_FLIGHT = 0.55

-- Nap this bone buys against this dog. Never returns a useless number: even
-- the cheapest bone against Titan is worth more than a standing start.
function Config.getBoneNap(boneKey: string, dogLevel: number): number
	local bone = Config.BONES[boneKey]
	local tier = Config.getDogTier(dogLevel)
	if not bone or not tier then
		return 0
	end
	return bone.nap * tier.boneResist
end

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
--
-- Every toast in the game is `Notify(message, kind)`, and this table is what a
-- kind MEANS: a colour, a glyph, an optional headline, a sound and how long it
-- sits there. Roughly a hundred and thirty call sites across twelve services
-- send one of these strings, so the vocabulary is the only thing that has to
-- be agreed -- and adding a treatment here upgrades every site that already
-- uses that kind, without touching any of them.
--
-- WHY THERE ARE MORE THAN TWO. It was "good" and "warn" for everything, so
-- banking coins, being refused a purchase, and a stranger emptying your piggy
-- bank all arrived as the same grey bar with different words in it. The
-- loudest thing in the game read exactly like the quietest.
--
-- `flash` is the difference between a message and an EVENT. Three kinds have
-- it -- someone is robbing you, a dog is on you, the patrol has you -- and
-- they pulse the screen edges in their own colour. Those three are the only
-- moments where a player has seconds to react and is probably looking at
-- their feet rather than at a corner of the HUD.
--
-- THE SOUNDS ARE NAMES INTO Config.SOUNDS, and several are deliberately
-- absent. The Creator Store's supply of interface cues is largely ripped --
-- searching it for a notification chime returns Undertale, COD Zombies,
-- Fallout 3, SCP and Mr Hopp's Playhouse on the first page -- and Pro Sound
-- Effects, which is the licensed library this project uses, is a field
-- recording collection with no UI beeps in it at all. So the noisy events
-- borrow sounds the game already ships and the quiet ones stay quiet, rather
-- than shipping a strike waiting to happen. A missing sound is not an error;
-- `blast` tolerates it.
-- ICONS ARE BUILT WITH utf8.char, NEVER TYPED OR ESCAPED.
--
-- A four-byte emoji written as a decimal escape is one shell or one editor
-- away from being rewritten into the bytes it names, and Luau answers that
-- with "Malformed string" -- which takes down the whole file, not the glyph.
-- This spelling cannot be rewritten by anything in the pipeline and it says
-- which character it is.
-- EVERY GLYPH CARRIES U+FE0F, AND THE ONE THAT DID NOT WAS THE ODD ONE OUT.
--
-- The six four-byte emoji here have no text form and always render from the
-- colour emoji font. The three BMP symbols do have one, and U+26A0 DEFAULTS
-- to it -- so the warning triangle was drawn by Gotham as a monochrome
-- character while everything beside it was drawn as an emoji. Measured in a
-- 32x32 chip at TextSize 17: every other glyph advances 16.0 pixels and the
-- triangle advanced 12.0, so it sat off centre on the ONE kind players see
-- most, since every refusal in the game is a `warn`.
--
-- VARIATION SELECTOR-16 asks for the emoji form explicitly. Measured after:
-- the triangle advances 16.0 like the rest. It goes on all three BMP glyphs
-- rather than only the broken one, because the tick and the cross happen to
-- default to emoji on THIS machine and that is a per-platform font decision
-- rather than a promise.
--
-- Built with utf8.char and never a decimal escape: this file has already lost
-- an entire HUD to "\240\159\148\138" being rewritten in transit into
-- the bytes it named, which ended the string literal and stopped the whole
-- chunk compiling.
local VS16 = utf8.char(0xFE0F)

local ICON = {
	TICK = utf8.char(0x2705) .. VS16,   -- white heavy check
	WARN = utf8.char(0x26A0) .. VS16,   -- warning triangle
	CROSS = utf8.char(0x274C) .. VS16,  -- cross mark
	BANK = utf8.char(0x1F3E6),  -- bank
	MONEYBAG = utf8.char(0x1F4B0),
	SIREN = utf8.char(0x1F6A8),
	DOG = utf8.char(0x1F415),
	CAR = utf8.char(0x1F693),   -- police car
	PRANK = utf8.char(0x1F92A), -- zany face
	-- Added for the interaction prompts. Every one of these was RENDERED and
	-- measured before it was used, the way this file's own note demands:
	-- at TextSize 40 in GothamBold a real emoji advances 37.0 and a tofu box
	-- advances 20.0, and the two dingbats known to be missing came back at
	-- exactly 20.0 as the control. All of these came back at 37.0.
	BIN = utf8.char(0x1F5D1),
	EYES = utf8.char(0x1F440),
	TROLLEY = utf8.char(0x1F6D2),
	ALIEN = utf8.char(0x1F47D),
	-- The gate jam. U+1F6A7 CONSTRUCTION SIGN -- a barrier, which is what a
	-- jammed gate is, and it is four-byte so it has no monochrome text form to
	-- fall back to. It wants the same render-and-measure check the four above
	-- were given before anybody trusts its width on a prompt card.
	JAM = utf8.char(0x1F6A7),
	-- The mailbox. U+1F4EB CLOSED MAILBOX WITH RAISED FLAG, which is the
	-- picture the prompt is about rather than merely a postbox -- the flag
	-- IS the tell. Four-byte, so it has no monochrome text form to fall
	-- back to and cannot pick up the fault that made the warning triangle
	-- render 4px narrower than everything beside it.
	POST = utf8.char(0x1F4EB),
	-- The doorstep crate. U+1F4E6 PACKAGE -- a delivery, which is what this
	-- is: something that has ARRIVED and is waiting on the step, rather
	-- than a present somebody wrapped. Four-byte, so it has no monochrome
	-- text form to fall back to, and measured with the rest at 37.0.
	CRATE = utf8.char(0x1F4E6),
	-- The smash. U+1F4A5 COLLISION -- the EFFECT rather than the tool, which
	-- is the deliberate half: a hammer would put an implement on a card in a
	-- game whose officer carries no baton, and the starburst says the one
	-- thing this kind is actually about, which is that this way in is LOUD.
	-- Four-byte, so it has no monochrome text form to fall back to and cannot
	-- pick up the fault that made the warning triangle render 4px narrower
	-- than everything beside it.
	SMASH = utf8.char(0x1F4A5),
}

-- EVERY KIND GETS ITS OWN ICON, and that is the point of having one.
--
-- These were ASCII stand-ins to begin with -- "+", "!", "x", "$" -- typeset
-- into a coloured circle, which reads as a typographic accident rather than
-- an icon. Worse, FOUR of the eight shared "!": warn, alarm, chase and police
-- all drew the same chip, so on the three loudest events in the game the icon
-- carried no information at all and the player had to read the words to find
-- out whether they were being robbed, chased or pulled over.
-- HOW LONG A CARD STAYS IS A FUNCTION OF HOW MUCH THERE IS TO READ.
--
-- Every kind used to carry one flat hold, which is the wrong number for every
-- message but one: "Banked 12 coins" and a fourteen-word robbery alert were
-- given the same two-odd seconds, and the long ones were gone before a nine
-- year old had finished the first line. They are also read by somebody who is
-- RUNNING -- the card is not what they are looking at -- so the clock has to
-- cover NOTICING it as well as reading it.
--
-- A kind's `hold` is now a FLOOR, and this is the other half: 2.2 seconds to
-- notice, plus 0.42 a word. Deliberately slower than an adult skim. Worked
-- against real strings: "Banked 12 coins." lands at 3.5s, "Nobody close
-- enough to throw that at." at 5.1, and a full robbery alert at 8.1 against
-- the 4.5 it used to get.
--
-- `max` is the guard on the other side. Nothing here should sit on screen for
-- ten seconds; a message that wants longer than nine wants to be shorter.
Config.NOTIFY_READ = {
	base = 2.2,
	perWord = 0.42,
	max = 9,
}

Config.NOTIFY = {
	-- The two originals. Everything that was not re-kinded still lands here,
	-- so the upgrade is universal even where nobody has revisited the call.
	good = {
		glyph = ICON.TICK, tone = Color3.fromRGB(59, 209, 140),
		sound = "MILESTONE", volume = 0.3, hold = 3.2,
	},
	warn = {
		glyph = ICON.WARN, tone = Color3.fromRGB(230, 104, 64),
		hold = 3.4,
	},

	-- SOMEBODY JUST THREW SOMETHING AT YOU FOR THE LAUGH. Its own kind
	-- because it is the only message in the game that reports a thing done TO
	-- you that costs you nothing, and every other treatment says the wrong
	-- thing about it: `warn` is the refusal orange and reads as "you did
	-- something wrong", `bad` is a real loss and plays a cell door.
	--
	-- Silent, short and unmissable. No flash: the three flashing kinds are
	-- the ones a player has to react to, and there is nothing to do about
	-- this one except throw one back.
	prank = {
		glyph = ICON.PRANK, tone = Color3.fromRGB(230, 64, 179),
		hold = 3.0,
	},

	-- A real loss, as against a refusal. A refusal costs you nothing and
	-- should not sound like it does.
	bad = {
		glyph = ICON.CROSS, tone = Color3.fromRGB(230, 71, 64),
		sound = "CELL_DOOR", volume = 0.25, hold = 4.0,
	},

	-- Coins arriving. The one kind players will see thousands of times, so it
	-- is the shortest and the quietest of the positives.
	money = {
		glyph = ICON.BANK, tone = Color3.fromRGB(255, 203, 61),
		sound = "BANK", volume = 0.35, hold = 2.8,
	},

	-- Loot in your hands. Gold like money, but it is the START of the risky
	-- half of the trade rather than the safe end of it, so it holds longer.
	loot = {
		title = "HAUL", glyph = ICON.MONEYBAG, tone = Color3.fromRGB(255, 203, 61),
		sound = "COIN_DROP", volume = 0.5, hold = 4.0,
	},

	-- SOMEONE IS ROBBING YOU. The single most important message the game ever
	-- sends, and it used to be an orange bar.
	alarm = {
		title = "ROBBERY", glyph = ICON.SIREN, tone = Color3.fromRGB(230, 72, 64),
		sound = "ALARM", volume = 0.7, hold = 5.5, flash = true,
	},

	-- A dog is on you. Loud on purpose: the bark on the dog itself is a 3D
	-- sound that falls off with distance, which is right for everybody else
	-- on the street and useless for the one player being chased -- they are
	-- running AWAY from it, so the one person who most needs to hear it is
	-- the one it fades for. This plays flat, at the front, for them alone.
	--
	-- AMBER, NOT RED, and that is a correction. The note under `police` says
	-- two identical flashes would stop meaning two different things -- and
	-- alarm and chase were the identical pair, both on (226, 72, 64). They are
	-- opposite situations: the alarm is a loss happening at YOUR house while
	-- you are elsewhere, and this is danger to you while you are out robbing.
	-- Red for the one that costs you coins, amber for the one that costs you
	-- the getaway.
	chase = {
		title = "GUARD DOG", glyph = ICON.DOG, tone = Color3.fromRGB(230, 147, 64),
		sound = "DOG_SNARL", volume = 1, hold = 5.5, flash = true,
	},

	-- The patrol. Navy rather than red, because it is the law rather than a
	-- neighbour, and because two identical red flashes would stop meaning
	-- two different things.
	police = {
		title = "PATROL", glyph = ICON.CAR, tone = Color3.fromRGB(64, 117, 230),
		sound = "SIREN", volume = 0.6, hold = 5.0, flash = true,
	},
}

-- ============================================================
-- THE PATROL
-- ============================================================
--
-- A police car drives the street every few minutes, and anyone who robs
-- somebody while it is out gets chased.
--
-- WHAT IT IS FOR. Every risk in this game is owned by the victim: their dog,
-- their fence, their lock, their tag. That makes robbing a quiet plot -- one
-- whose owner is offline, or asleep at their own piggy -- completely free,
-- which is the one hole in the heist economy that no defence purchase can
-- close, because the person who would have bought it is not there. The patrol
-- is the house's own risk: it does not belong to anybody, it cannot be bought,
-- upgraded or bribed, and it does not care whose plot you were standing on.
--
-- IT IS PUBLISHED, AND THAT IS THE DESIGN. The siren sounds fifteen seconds
-- before the car appears and the HUD counts the patrol down, so robbing during
-- one is a CHOICE. A hidden timer would make an identical amount of trouble
-- while turning a decision into bad luck, and bad luck is not a thing a nine
-- year old can get better at. It also makes an item that already exists
-- better: the Disguise Kit is sold as a WAITING tool, and waiting out a patrol
-- crouched on somebody's lawn as a wheelie bin is the best thing it does.
--
-- IT COMMITS TO ONE PURSUIT. Once the officer is out of the car they chase
-- that thief and nobody else, and the patrol ends when the chase does. A car
-- that hoovered up every robbery on the street for forty-five seconds would be
-- a curfew rather than a hazard -- and this way a second thief robbing during
-- a chase gets a completely free run, which is a decoy play worth discovering.
--
-- A PLAYER MAY BUY THE TIMING. A PLAYER MAY NEVER BUY THE TARGET.
--
-- The Patrol Radio calls a patrol out early, which flatly contradicts "it
-- cannot be bought" as that line was first written -- so it is worth being
-- exact about which half of this was ever load-bearing. It was never that the
-- police are unsummonable. It is that NOTHING ANOTHER PLAYER DOES CAN AIM AN
-- OFFICER AT YOU, which is the same shipping requirement the gadgets carry
-- and the reason there is no target argument anywhere in this feature.
--
-- A radio call brings a car onto the street. It does not say who for. The
-- patrol then picks its own target exactly as it always has -- a completed
-- steal during the cruise, or failing that the name on the board -- so the
-- caller has bought sixty seconds of policed street and nothing else. They
-- cannot name anybody, they cannot exclude themselves, and if they are top of
-- the board it is THEM the officer gets out for. See HomeService.useRadio.
--
-- TWO THINGS STOP IT BECOMING A CURFEW, and both matter. `callLockout` puts a
-- floor under how often the street can be policed however rich the caller is,
-- and the fifteen-second siren is still ahead of the car, so a called patrol
-- is as published as a scheduled one. What a radio cannot do is turn the
-- patrol into weather: quiet is still the majority of every cycle.
Config.POLICE = {
	-- Eight minutes between patrols, of which the street is only actually
	-- policed for forty-five seconds. Long enough that a patrol is an event
	-- rather than weather, short enough that a player who wants to see one
	-- does not have to plan an evening around it.
	period = 480,
	warning = 15,
	patrol = 45,

	-- Thirty seconds, as asked for. Outlast it and the officer gives up.
	chase = 30,

	-- The head start, so the chase begins as a chase rather than as a catch.
	-- Same reason DOG_START_DELAY exists.
	startDelay = 1.2,

	-- SPEEDS, and the only numbers here that can break something else.
	--
	-- BASE_WALK_SPEED is 16 and a carrying thief does 12. The officer runs at
	-- 14.5 -- between the two, which is the entire balance of this feature:
	--
	--   carrying (12.0)      -> the officer gains on you, so holding the loot
	--                           through a patrol has a real price
	--   empty-handed (16.0)  -> you outrun them, so DELIVERING is the answer
	--                           and the bail is what you pay for being slow
	--
	-- Nothing here is faster than 16, so no existing calibration moves. The
	-- car is quicker than that, but the car never leaves the road and never
	-- catches anybody -- only the officer's catchRadius can end a chase.
	officerSpeed = 14.5,
	carSpeed = 34,
	catchRadius = 6.5,

	-- BAIL, AND WHY IT IS CAPPED.
	--
	-- Confiscation takes from the PIGGY BANK, which since the pivot is the
	-- only balance there is. What keeps it from costing progress is the cap
	-- below: three times the haul, and never more than is in the pig -- so a
	-- patrol can cost you an afternoon's idle income and can never cost you a
	-- house, a skin or an upgrade, all of which are bought and gone from it.
	--
	-- The multiple is what stops it being a trap. Uncapped, a thief who took
	-- 2,500 off a neighbour while sitting on 200,000 of their own uncollected
	-- coins would lose all 200,000 -- an eighty-to-one punishment, and the
	-- lesson a child takes from that is "never rob anybody again". The economy
	-- needs people robbing each other; the Guard Duty Treat exists for exactly
	-- that reason and this cap is the same argument.
	--
	-- At 3x, bail is always legible as "three times what you took", it always
	-- hurts, and it can never exceed what was already at risk.
	bailMultiple = 3,

	-- Which lane the car drives in, as an offset from the road's centreline.
	-- Well inside ROAD_HALF_WIDTH so it never clips a kerb.
	lane = 4.2,

	-- (Config.DELIVERY, below this table, reads that lane and negates it.)

	-- THE ARREST SCENE'S OWN CLOCK, which is NOT the detention's.
	--
	-- It used to be derived from STUN_SECONDS on the argument that a cutscene
	-- outlasting the thing it narrates steals time the player could have been
	-- playing. That argument was sound and the implementation undid it: the
	-- scene could be dismissed by ANY input from the frame it appeared, with
	-- nothing enforcing the "after the stamp lands" its own comment promised.
	-- So a player still holding W -- which is everyone, they were running --
	-- skipped the whole thing instantly and reported it as too fast.
	--
	-- THE TAP IS WHAT CLOSES IT. The card says "tap to continue", so a timer
	-- that closes it first makes the card a liar -- and that is exactly what
	-- happened at a 5.5-second hold: the scene faded on its own while the
	-- player was still reading the prompt telling them to dismiss it.
	--
	-- So `arrestTimeout` is a BACKSTOP rather than a beat. Thirty seconds is
	-- long enough that it never wins in practice and short enough that a card
	-- can never trap somebody who walked away, put the phone down, or is on a
	-- device where the input never arrives. If this timer is what closed your
	-- scene, something else is wrong.
	--
	-- `arrestSkipAfter` is the other half and the reason the tap needs a gate
	-- at all: the dismiss used to fire from the frame the scene appeared, so
	-- the movement key the player was already holding -- everyone, they were
	-- running from the police -- killed it instantly.
	arrestTimeout = 30,
	arrestSkipAfter = 3.5,

	-- MOST WANTED: the floor a rap sheet has to clear before the patrol will
	-- come looking for somebody who is not currently robbing anybody.
	--
	-- DENOMINATED IN SECONDS OF THAT PLAYER'S OWN INCOME, never a flat number,
	-- for exactly the reason the daily ladder is: a steal takes 5% of a
	-- victim's piggy bank and a piggy bank's capacity climbs without limit, so
	-- any fixed figure is a serious crime on day one and a rounding error by
	-- the weekend. At sixty seconds it always means the same thing -- "you
	-- have taken about a minute of your own earnings off other people" --
	-- which is a real robbery at every point in the game.
	--
	-- The floor exists for one specific failure: in a quiet server, a player
	-- who lifted a single small pile would otherwise be hunted every eight
	-- minutes for the rest of the session.
	--
	-- IT GATES THE PATROL AND NOT THE POSTER, which it used to do both of. As
	-- a filter on who could lead the board it was answering a question it
	-- cannot answer: this number scales with the THIEF's income and rebirths
	-- while loot scales with the VICTIM's vault, so a maxed thief robbing a
	-- poorer neighbour never cleared their own floor however many plots they
	-- emptied, and the board stayed empty in exactly the servers that had a
	-- biggest thief. See SocialService.refreshMostWanted -- the board ranks on
	-- the sheet alone, and this decides whether the leader is worth a car.
	wantedFloorSeconds = 60,

	-- HOW LONG THE STREET MUST BE QUIET BEFORE ANOTHER RADIO CALL IS TAKEN.
	--
	-- This, and not the price, is what caps the Patrol Radio. A maxed player
	-- earns about 3,000 coins a second, so 75,000 is twenty-five seconds of
	-- income to them and no gate at all -- a price can hold back a new player
	-- and can never hold back a finished one. Without a lockout a rich player
	-- chains calls and the patrol stops being an event: forty-five seconds of
	-- car is a hazard, and forty-five seconds of car every minute is a curfew,
	-- which is the exact thing the one-pursuit rule above exists to prevent.
	--
	-- Three minutes of quiet puts the floor at roughly one patrol every four
	-- minutes even with unlimited money -- twice the scheduled rate, so the
	-- street reads as busy rather than occupied, and quiet is still most of
	-- every cycle. It runs from the END of a patrol, the same shape as the
	-- guard-duty lockout and for the same reason: measured from the call, it
	-- would overlap the patrol it started and guarantee no gap at all.
	callLockout = 180,
}

-- ============================================================
-- SESSION EVENTS
-- ============================================================
--
-- WHY THESE EXIST. Both upgrade trees max out at 2h11m, the highest rebirth
-- gate in the game is 6, and both sources of randomness are finite lists that
-- run dry and never refill. The fault that actually costs retention is none of
-- those: it is that NOTHING DIFFERS between a player's third session and their
-- thirtieth except the size of their numbers.
--
-- An event cannot be exhausted, because it is not an item. It has no pool, no
-- catalogue and no completion state, which is exactly the property the two
-- collection rolls do not have.
--
-- THE ALIEN RAID IS THE FLAGSHIP FOR ONE REASON: THE STREET HAS NEVER BEEN ON
-- THE SAME SIDE. Every relationship in this game is adversarial or neutral --
-- stealing, dogs, fences, gadgets, Most Wanted, the patrol -- and the only
-- cooperative mechanic in the entire codebase is FRIEND_BONUS, which is a
-- passive income multiplier rather than an action. So a full server currently
-- means MORE THIEVES. For the length of a raid it means more defenders, and
-- that is the single biggest change available to this design.
--
-- EVERY EVENT OBEYS THE PATROL'S RULES, because they are the same kind of
-- thing: published before it lands, triggerable by nobody, aimable at nobody,
-- and it never costs progress -- what is spent is out of the pig and safe.
Config.EVENTS = {
	-- The quiet stretch between events. The patrol is every eight minutes and
	-- stays the baseline heartbeat; this sits under it so an event is a
	-- bigger, rarer thing than a patrol rather than a competing one.
	period = 900,

	-- Published ahead, exactly like the patrol's fifteen seconds of siren.
	-- Robbing during a patrol is a choice rather than bad luck, and bad luck
	-- is not something a nine year old can get better at. The same is true of
	-- being beamed.
	warning = 20,

	-- WEIGHTED, WITH THE LAST ONE DAMPED RATHER THAN EXCLUDED. See the note
	-- above `pick` in EventService: excluding it looks like the anti-repeat
	-- rule and, at a two-event roster, collapses into strict alternation with
	-- the weights doing nothing at all.
	--
	-- As damped, the raid lands about 41% of slots -- roughly one every 37
	-- minutes -- so it is the thing a session gets built around rather than
	-- something that interrupts one, and it is genuinely unpredictable rather
	-- than nominally random. Adding a third event moves this number; it is
	-- derived from the weights, not pinned.
	roster = {
		-- `set` is which themed set this event's drop rolls from. Rush Hour
		-- has none: it pays medals for turning up and nothing else, because
		-- there is nothing in it to be good at.
		raid = { name = "ALIEN INVASION", weight = 1, seconds = 150, set = "alien" },
		rush = { name = "RUSH HOUR", weight = 2, seconds = 180 },
	},
}

-- WHAT AN EVENT LOOKS LIKE ON THE HUD.
--
-- The same shape as `Config.NOTIFY` and `Config.PROMPTS`: a table of tone,
-- glyph and wording, so adding a third event is a row here rather than a
-- branch in ClientMain. The client used to carry `if raid then ... else ...`
-- in four places -- which is the shape that broke the anti-repeat rule at a
-- two-event roster, and would break again the same way.
--
-- The WARNING line is built from `roster[key].name`, which was already in
-- this file and which the HUD was not reading: it hardcoded "INVASION
-- INCOMING" while the roster said "ALIEN INVASION", so the one place a
-- player learns an event's name disagreed with the one place it is defined.
--
-- TONES ARE WRITTEN AS NUMBERS because Config requires nothing -- it is pure
-- data pulled in by every server service, and making it depend on a UI module
-- to name a colour would be the wrong trade by a distance. The alien cyan is
-- the one `Config.PROMPTS.recover` already uses for taking loot back off a
-- drone, so the event and the action inside it are one colour.
--
-- Both glyphs were RENDERED and measured before being used, the way the ICON
-- table above demands: at TextSize 40 in GothamBold a real emoji advances
-- 37.0 and a tofu box advances 20.0. Both came back at 37.0. The bolt carries
-- VS16 because it is BMP and therefore HAS a monochrome text form -- the same
-- fault that made the notify warning triangle render 4px narrower than every
-- glyph beside it, and a per-platform font decision rather than a promise.
Config.EVENT_UI = {
	raid = {
		glyph = utf8.char(0x1F6F8),
		tone = Color3.fromRGB(59, 204, 209),
		live = "DRONES ON THE STREET",
	},
	rush = {
		glyph = utf8.char(0x26A1) .. VS16,
		tone = Color3.fromRGB(255, 176, 46),
		live = "STEALS ARE DOUBLE",
	},
}

-- THE LAST MINUTE, when the standing countdown stops being furniture.
--
-- A chip that says "next event in 12:41" for fourteen minutes is wallpaper,
-- and wallpaper is what a player stops seeing. This is the window where it
-- changes state and starts asking to be looked at.
--
-- It has to be comfortably LONGER than `EVENTS.warning`, because the warning
-- is when the banner takes the news off this chip entirely: at 20 seconds
-- against a 20-second warning the chip would flip to its loud state and
-- vanish in the same frame, which is a flicker rather than a cue. A minute
-- also happens to be about how long it takes to bank a full pig and get
-- somewhere useful, which is the whole point of telling anybody.
Config.EVENT_SOON = 60

-- HOW MANY SECONDS OF THE WARNING GET A TICK, and it is smaller than the
-- warning itself on purpose.
--
-- `EVENTS.warning` is twenty seconds of banner. A tick running for all of
-- it is a metronome nobody can turn off, and this game already refuses that
-- shape once: the coin drip is tuned so a coin lands about every fifteen
-- seconds because anything louder "becomes nagging". Five is the last
-- moment -- long enough to mean get ready, short enough that the sound is
-- an event rather than a background.
--
-- IT IS CLIENT-SIDE AND PER VIEWER, like the moat and the animated skins:
-- the server publishes the phase and its deadline, and every machine works
-- out for itself which second it is on. Nothing about a tick needs to
-- replicate.
Config.EVENT_TICK_FROM = 5

-- The glyph the standing countdown wears. An hourglass rather than anything
-- about a specific event, because WHICH event is deliberately not known yet
-- -- the roster is rolled when the quiet stretch ends, and a chip naming it
-- early would trade the surprise for a number nobody asked for.
--
-- Rendered and measured like every other glyph in this file: 37.0 at
-- TextSize 40 in GothamBold against a tofu box's 20.0.
Config.EVENT_SOON_GLYPH = utf8.char(0x23F3)

-- Presentation for an event key, or nil for one with no row. A caller that
-- gets nil should draw nothing rather than invent a default: a new event
-- showing up as an unnamed grey bar is worse than not showing up at all, and
-- far easier to notice.
function Config.eventUI(key: string?): { [string]: any }?
	return (Config.EVENT_UI :: any)[key or ""]
end

-- THE RAID.
--
-- It siphons the piggy bank, which since the pivot is the only balance there
-- is. What keeps it survivable is the cap below, the same line the police
-- draw with bail: anything SPENT is gone from the pig and permanently safe.
--
-- It is capped at STEAL_FRACTION, so a raid can never cost more than one bad
-- neighbour -- and everyone present earns a bounty regardless of how it goes,
-- so attending is net positive in expectation even on a failed defence. An
-- event that can only take is a reason to log off during it, which is the
-- exact opposite of what this feature is for.
Config.RAID = {
	-- Drones scale with how many players are actually on the street, so twelve
	-- players is a real fight and two is still winnable.
	dronesPerPlayer = 1,
	minDrones = 2,
	maxDrones = 6,

	-- How long an UNCONTESTED beam takes to reach the cap. The per-second rate
	-- is derived from this rather than stated, so the cap and the pacing can
	-- never drift apart -- raising the cap cannot accidentally make the drain
	-- faster than anybody can reach a drone.
	drainSeconds = 90,

	-- A FLOOR ON THE DRAIN, EXPRESSED AS A MULTIPLE OF THE VICTIM'S OWN
	-- INCOME, because without one the whole raid is invisible to exactly the
	-- player it is aimed at.
	--
	-- Measured: a maxed player sitting on a full vault earns 2,995/s while the
	-- beam took 1,660/s, so the pile did not move for the entire raid. That is
	-- not a tuning accident, it is structural -- the drain is a fraction of
	-- the vault over `drainSeconds` and income is a fraction of the same vault
	-- over a SHORTER time, so income wins at every level of the game.
	--
	-- Coins were leaving the vault the whole time and the loss landed
	-- correctly at the end; it simply could not be seen, which for a
	-- nine-year-old is indistinguishable from nothing happening.
	--
	-- At 2.5 the pile visibly falls at about 1.5x income while the beam holds,
	-- and the CAP still bounds what the raid can ever cost. The floor only
	-- ever makes a drone finish sooner than `drainSeconds`, never take more.
	drainIncomeMultiple = 2.5,

	-- What a knocked-down drone is worth, and how long it lies there. The
	-- window has to be long enough to cross a lawn and hold a prompt.
	groundedSeconds = 12,
	promptHold = 0.9,

	-- Both denominated in SECONDS OF THE PLAYER'S OWN INCOME, never flat
	-- numbers -- the rule the daily ladder already follows, for the reason it
	-- follows it: forty-five thousand coins is a gift on day one and an
	-- insult at three thousand a second.
	bountySeconds = 45,
	breakerSeconds = 20,

	-- Geometry. The saucer hangs above the treeline so it reads from the whole
	-- street; a drone drops to head height where somebody can throw at it.
	hoverY = 46,
	droneY = 17,
	-- Narrower than the drone is wide (3.4), so the drone reads as sitting on
	-- top of its beam rather than being swallowed by it.
	beamRadius = 2.0,
}

-- RUSH HOUR is deliberately the cheapest thing on the roster: a multiplier on
-- one number and a continuous patrol. It exists to prove the event framework
-- takes more than one event rather than being the raid with extra steps, and
-- because not everything on the roster should cost a week.
Config.RUSH = {
	stealMultiplier = 2,
}

-- ============================================================
-- MEDALS AND SETS
-- ============================================================
--
-- WHY A SECOND CURRENCY AT ALL. Events paid coins, and coins are not scarce:
-- measured against the live economy, events contribute 7.5% of hourly income
-- at endgame -- 808K an hour at best against 10.8M an hour of simply standing
-- still. A coin payout is a thank-you, not a reason to come back. Medals are
-- what make attendance compound.
--
-- MEDALS ARE FLAT, AND THAT IS THE ONE PLACE THE SECONDS-OF-INCOME RULE IS
-- DELIBERATELY NOT FOLLOWED. Every other reward here is denominated in the
-- player's own income precisely so it keeps meaning the same thing as they
-- grow. Medals do the opposite ON PURPOSE: a set costs the same number of
-- events for a brand-new player as for a maxed one, so the ladder measures
-- ATTENDANCE and nothing else. Coins scale with the player; medals scale with
-- turning up. A rich player cannot buy their way up this one.
-- WHERE LOOT COMES FROM. `data.loot` is the second currency and the only one
-- besides coins: medals, tokens and the daily token pips were three currencies
-- doing one job badly, and a nine-year-old cannot hold three. Both old fields
-- were merged one-for-one into `loot` at schema 17.
--
-- Legacy event rewards remain here until the Phase 1.9 faucet audit.
-- Piggy deliveries no longer award this currency; trees arrive in Phase 2.
Config.LOOT = {
	event = {
		-- Everybody present when an event resolves. Never zero: an event that
		-- pays nothing to somebody who could not reach a drone is an event that
		-- teaches them not to bother next time.
		attend = 3,
		-- Per drone you personally knocked down. This is the only part that
		-- rewards playing rather than being logged in.
		perDrone = 2,
		-- Shared by everyone when the street clears every drone. A co-operative
		-- bonus has to be co-operative: it pays the people who did nothing too,
		-- or the incentive is to let a neighbour fail.
		cleared = 3,
		-- Paid instead of a drop when a player already owns the whole set, the
		-- same fallback ProgressionService uses when the skin pool is empty.
		-- Paying out beats silently doing nothing.
		setComplete = 10,
	},
}

-- A SET IS A VIEW OVER THE EXISTING CATALOGUES, NEVER A NEW CATALOGUE.
--
-- Every entry below points at an item that lives in Config.SKINS,
-- Config.EFFECTS, Config.ACCESSORIES, Config.DECOR_ITEMS or Config.RIDES as
-- an ordinary member of that table. So there is no new ownership storage, no
-- new save field per item and no new equip path: each item stays in the
-- system that already knows how to build, price, render and wear it, and the
-- set is only a lens for showing them together.
--
-- It also means an item is BOUGHT IN ITS OWN HOME TAB with a medal price
-- instead of a coin price. No new shop section was needed; the shelf each one
-- belongs on already existed.
--
-- THE `set` FIELD ON AN ITEM IS AN EXCLUSION, and it is load-bearing.
-- Accessories and drop-pool skins are roll-only, so an alien hat added to
-- Config.ACCESSORIES would immediately enter the COIN accessory roll and the
-- Martian skin would enter the REBIRTH drop pool -- either of which hands set
-- items to players who have never attended an event, and the set stops
-- meaning attendance. One rule, two pools, both in CosmeticsService.
Config.SETS = {
	alien = {
		name = "Alien Invasion", order = 1, event = "raid",
		tone = Color3.fromRGB(59, 204, 209),
		blurb = "Knocked out of the sky over your own street",
		-- Ordered cheapest first, which is also the order they read as a
		-- ladder on the set card.
		-- FOUR ITEMS, NOT SIX. The Antenna Headband and the Abductor Visor went
		-- with the accessory catalogue. What that costs is the argument this
		-- set was designed on -- that spanning five systems beats six
		-- recolours -- and it still spans four, which is the half of that
		-- argument worth keeping. A set is a VIEW over the existing
		-- catalogues, so dropping two rows is the whole edit: no ownership to
		-- migrate, no grant path to unpick.
		items = {
			{ kind = "decor", key = "crashedDrone" },
			{ kind = "effect", key = "tractor" },
			{ kind = "skin", key = "martian" },
			{ kind = "ride", key = "hoverdisc" },
		},
	},
}

-- The catalogue an item of a given kind lives in. One table rather than a
-- five-branch if, because every reader of a set needs this and a second copy
-- is the one that drifts.
-- THE KINDS `catalogueFor` ANSWERS, NAMED ONCE.
--
-- `catalogueFor` maps a kind to a table and cannot be asked what kinds it
-- knows -- so anything that has to sweep every catalogue was going to keep
-- its own copy of this list, and a copy that drifts by one entry is a
-- catalogue silently skipped rather than an error.
Config.COSMETIC_KINDS = { "skin", "effect", "accessory", "decor", "ride", "catch" }

function Config.catalogueFor(kind: string)
	return (({
		skin = Config.SKINS,
		effect = Config.EFFECTS,
		accessory = Config.ACCESSORIES,
		decor = Config.DECOR_ITEMS,
		ride = Config.RIDES,
		-- A catch effect is owned, equipped and sold exactly as the other five
		-- are, so `SetService.grant`, `.revoke` and `.inUse` reach it for free
		-- rather than through a second grant path.
		catch = Config.CATCH_EFFECTS,
	}) :: any)[kind]
end

function Config.getSetItem(kind: string, key: string)
	local catalogue = Config.catalogueFor(kind)
	return catalogue and catalogue[key] or nil
end

-- ============================================================
-- INTERACTION PROMPTS
-- ============================================================
--
-- WHAT EVERY PROMPT IN THE GAME LOOKS LIKE, in one table.
--
-- They were all the SAME: Roblox's default prompt, a grey pill with a letter
-- in it, drawn identically whether you were banking your own coins or robbing
-- somebody. Seven different actions, one picture -- so the loudest thing a
-- player can do on this street looked exactly like the quietest, and the only
-- way to tell them apart was to read the words.
--
-- This is the argument `Config.NOTIFY` already made for the toast stack, so
-- the shape is deliberately the same: a kind names a TONE, a GLYPH and a
-- WORD, and adding a treatment here restyles every site already using that
-- kind without touching one of them.
--
-- COLOUR IS NEVER THE ONLY SIGNAL. The rarity borders had to learn this --
-- "colour alone separates four tiers only for players who can see four" --
-- so every prompt carries its glyph and its word as well as its tone. Red is
-- a reinforcement of STEAL, not the way you know.
--
-- The tones are borrowed from NOTIFY on purpose, so an action and the toast
-- it produces are the same colour: robbing somebody is the `alarm` red their
-- victim is about to see, banking is the `money` gold, and being chased down
-- is the `chase` amber.
-- WHOSE PROMPT THIS IS, WHEN IT IS ONLY EVER FOR ONE PERSON.
--
-- `PromptUI` already refuses every prompt inside the local player's own
-- character, on the rule that a prompt on your own body is never for you.
-- This is the inverse and the same instrument: a prompt carrying this
-- attribute is disabled on every client EXCEPT the one whose UserId it
-- names.
--
-- `Enabled` written from a client affects only that machine's view, which
-- is the only per-player prompt Roblox offers -- so this is the client
-- declining to ask for a known no, and the server refuses regardless. What
-- it buys is that a thief standing on somebody's lawn does not read CHECK
-- POST over a mailbox that will not open for them, which is a control that
-- looks available and does nothing.
Config.PROMPT_OWNER_ATTRIBUTE = "PromptOwner"

Config.PROMPTS = {
	-- Your own piggy. Gold, and the quietest of the set: this is the thing a
	-- player does a thousand times and it should never shout.
	collect = {
		glyph = ICON.BANK, tone = Color3.fromRGB(255, 203, 61),
		verb = "BANK COINS",
	},

	-- Somebody else's. THE LOUDEST PROMPT IN THE GAME, and the only one that
	-- costs another player anything -- the red is the same red their robbery
	-- alarm will be.
	steal = {
		glyph = ICON.MONEYBAG, tone = Color3.fromRGB(230, 72, 64),
		verb = "STEAL",
	},

	-- The other way into the same pig. See `Config.SMASH`.
	--
	-- IT WEARS `steal`'S OWN RED, WHICH IS A DECISION RATHER THAN A REUSE.
	-- Everywhere else in this vocabulary a shared tone would be a fault: this
	-- file already records that the alarm and the chase had to stop being the
	-- same red, because two identical signals stop meaning two different
	-- things. These two are not two different things. They are one crime by
	-- two methods, they appear TOGETHER on the same pig, and a thief choosing
	-- between them is choosing how rather than whether -- so giving the loud
	-- one a hue of its own would say they were different crimes, which is a
	-- worse lie than the ambiguity it fixes.
	--
	-- What separates them is the other two channels, which is exactly what
	-- this file's own rule asks for: COLOUR IS NEVER THE ONLY SIGNAL. One card
	-- says STEAL and carries a money bag; the other says SMASH and carries a
	-- bang. Either alone is enough -- and on a touchscreen they are the ONLY
	-- things that are, because `keyText` prints HOLD on both when there is no
	-- key to name.
	smash = {
		glyph = ICON.SMASH, tone = Color3.fromRGB(230, 72, 64),
		verb = "SMASH",
	},

	-- Catching a thief who is carrying. Amber, matching the chase alert: this
	-- is the one prompt that appears ON another player and disappears again in
	-- seconds, so it wants to be seen from across a lawn.
	--
	-- "NAB" RATHER THAN "TAG THIEF", and the shorter word is not the reason --
	-- see `Config.NAB` for why the old one was four things at once. What the
	-- length buys is that it drops straight into the card measured for
	-- `STEAL` and `HIDE` with nothing to re-fit, and the row no longer has to
	-- name what it is being done to: a prompt only ever appears on a thief who
	-- is carrying, so "THIEF" was telling the reader something the prompt's
	-- own existence already told them.
	nab = {
		glyph = ICON.SIREN, tone = Color3.fromRGB(230, 147, 64),
		verb = "NAB",
	},

	-- JAMMING THE GATE BEHIND YOU. Orange rather than red, and the register is
	-- the point: this is a thing the THIEF does on the way out rather than a
	-- thing being done to the reader, so it is the caution colour rather than
	-- the alarm one.
	jam = {
		glyph = ICON.JAM, tone = Color3.fromRGB(240, 148, 56),
		verb = "JAM",
	},

	-- Climbing into a wheelie bin. Slate: cover is not a prize and should not
	-- glow like one.
	hide = {
		glyph = ICON.BIN, tone = Color3.fromRGB(140, 120, 104),
		verb = "HIDE",
	},

	-- Tipping somebody else out of one. Its own kind rather than sharing
	-- `hide`, because the two appear on the SAME bin and mean opposite things
	-- -- one of the few places in this game where two prompts sit on one prop.
	dig = {
		glyph = ICON.EYES, tone = Color3.fromRGB(230, 104, 64),
		verb = "OPEN IT",
	},

	-- A shop door. Green, and deliberately the calmest thing on the street:
	-- it costs nothing, risks nothing and is the one prompt a player can take
	-- their time over.
	shop = {
		glyph = ICON.TROLLEY, tone = Color3.fromRGB(129, 209, 59),
		verb = "SHOP",
	},

	-- YOUR OWN MAILBOX, and it is GOLD for the same reason `collect` was:
	-- this game's colour system says gold means money, and what is in the
	-- box is a daily reward denominated in your own income.
	--
	-- SHARING A TONE IS SAFE HERE AND WOULD NOT BE IF COLOUR WERE THE ONLY
	-- SIGNAL. Every prompt in this table carries a tone, a GLYPH and a WORD,
	-- precisely so that two things which are both "your own plot handing you
	-- money" can share a colour without becoming the same object. A mailbox
	-- and a piggy bank are told apart by the picture before the colour is
	-- read at all.
	post = {
		glyph = ICON.POST, tone = Color3.fromRGB(255, 203, 61),
		verb = "CHECK POST",
	},

	-- THE DOORSTEP CRATE, and it is GOLD for the same reason `collect` and
	-- `post` are: this is your own plot handing you something. The three of
	-- them are told apart by glyph and word before the colour is read at
	-- all, which is the whole argument for every prompt carrying all three.
	--
	-- "OPEN CRATE" AND NOT "OPEN IT", which `dig` already owns. Those two
	-- can never appear together -- one is on a wheelie bin on the verge and
	-- the other against a house's front wall -- so sharing would have been
	-- safe and would still have been one word doing two jobs. It also names
	-- the noun, which matters here: what is on the step is the same object
	-- the Crates tab sells, and a player who has opened one for coins should
	-- recognise this as the same thing arriving free.
	--
	crate = {
		glyph = ICON.CRATE, tone = Color3.fromRGB(255, 203, 61),
		verb = "OPEN CRATE",
	},

	-- Taking the loot back off a raid drone.
	recover = {
		glyph = ICON.ALIEN, tone = Color3.fromRGB(59, 204, 209),
		verb = "RECOVER",
	},
}

-- The attribute a prompt carries to say which of the above it is. A NAME and
-- not an index, so a prompt built in one file cannot be silently re-styled by
-- a reorder in another.
Config.PROMPT_KIND_ATTRIBUTE = "PromptKind"

-- WHICH CARD THIS IS WHEN TWO PROMPTS SHARE ONE PART.
--
-- This file already records that two prompts share a part in two places --
-- collect/steal on a piggy's Body, hide/dig on a bin's Hatch -- and that the
-- game GUARANTEES they are exclusive, so exactly one card is ever drawn.
-- `PromptUI` was built on that guarantee: every card takes the same
-- `StudsOffset` and there is no offsetting logic anywhere in it. The note
-- beside that measurement says in as many words that anything adding a third
-- prompt to a shared part has to keep the property.
--
-- THE SMASH IS THE FIRST THING THAT CANNOT KEEP IT. Steal and smash are the
-- two ways into one pig and they have to be READ TOGETHER, because a choice
-- you cannot see is not a choice. So both are live at once, on one part, for
-- the same player. That is the guarantee spent deliberately, and this is what
-- pays for it.
--
-- A SLOT AND NOT A STUD OFFSET, AND THE DIFFERENCE IS WHY THIS IS AN INTEGER.
-- A `BillboardGui` sized in OFFSET pixels is a fixed size on screen at every
-- distance, while `StudsOffset` is a world displacement that projects to
-- FEWER pixels the further away you stand. Against the shipped card: at 5
-- studs the existing 1.6-stud offset is about 152px and two cards would be
-- clear of each other; at `STEAL_RANGE` it is about 69px against a card 82px
-- tall, so a fixed stud offset overlaps at exactly the distance a thief
-- decides from. `PromptUI` grows the billboard by the slot and pins the card
-- to its bottom edge instead, which is a constant PIXEL separation at every
-- range.
--
-- Absent or 0 is the card exactly where it has always been, so every prompt
-- in the game that does not set this is untouched by construction.
Config.PROMPT_SLOT_ATTRIBUTE = "PromptSlot"

-- SETTING A KIND AND SETTING THE STYLE ARE ONE ACTION, AND SPLITTING THEM
-- SHIPPED TWO PROMPTS DRAWN IN ROBLOX'S GREY PILL.
--
-- `PromptUI` adopts a prompt on `PromptShown` and refuses anything still on
-- the DEFAULT style, on the sound reasoning that a default-styled prompt is
-- one nobody has given a kind yet -- and drawing a card over Roblox's own
-- would be worse than either alone. The guard is right. What it cannot see
-- is a prompt that HAS a kind and was never switched to Custom, which is
-- two separate lines at every call site and therefore two chances to write
-- one of them.
--
-- MEASURED: the gate jam and the mailbox both set the attribute, neither
-- set the style, and both rendered as the default pill -- the exact
-- "seven actions, one picture" failure this whole vocabulary exists to
-- fix. Neither errored, and both PASSED a check that read the prompt's
-- properties back: `ActionText`, `HoldDuration`, range and kind were all
-- correct. A property read proves a thing was built and says nothing about
-- whether it was seen.
--
-- One call sets both, so they cannot be written apart. Config is the right
-- home for the same reason `chestEntry` is: it requires nothing, both ends
-- read it, and the emitter and the reader of a format belong together.
function Config.setPromptKind(prompt: ProximityPrompt, kind: string)
	prompt:SetAttribute(Config.PROMPT_KIND_ATTRIBUTE, kind)
	-- Custom suppresses Roblox's own pill. Without it there are two cards,
	-- or -- with PromptUI's guard -- none of ours at all.
	--
	-- AND THE SWEEP THAT CONVERTED THE CALL SITES ATE THIS VERY LINE. The
	-- pattern that stripped the now-redundant `X.Style = ...Custom` from nine
	-- files matched it here too, inside the one function that has to keep it.
	-- Same class as the regex that deleted three blurbs when it was aimed at
	-- one: count the matches before a bulk delete, and check what still reads
	-- the name afterwards.
	prompt.Style = Enum.ProximityPromptStyle.Custom
end

-- What this action is WORTH, printed beside the verb.
--
-- A STEAL PROMPT USED TO SAY NOTHING ABOUT THE ONE THING IT IS FOR. It named
-- the lock and timed the hold, so a thief knew exactly how long they were
-- committing to and had no idea what they were committing to it FOR -- and
-- the piles on two neighbouring lawns look much the same from the gate. The
-- decision this game is built around is "is that one worth the run home", and
-- until now the number that answers it was the one thing not on screen.
--
-- A STRING, ALREADY FORMATTED, because the caller owns the wording -- the
-- same split CosmeticsService.awardTokens makes with its optional `why`.
-- PromptUI is Shared and has no formatter in it; handing it a number would
-- mean a second copy of one.
--
-- Empty or absent draws nothing at all, which is what every prompt that is
-- not about money does.
Config.PROMPT_AMOUNT_ATTRIBUTE = "PromptAmount"

-- A plot's uncollected pile, published so a thief standing at the gate can be
-- told what a grab is worth.
--
-- THIS REVEALS NOTHING THAT WAS NOT ALREADY PUBLIC. The coin pile on the lawn
-- has always shown how full somebody's piggy is -- that is what it is for --
-- so this makes an existing signal precise rather than adding a new one. And
-- it is the victim's piggy bank, which is the whole of what they have and the
-- whole of what is stealable.
--
-- An attribute rather than a per-viewer push because it is one number per
-- plot: the fraction a particular thief takes out of it differs per thief and
-- is applied on the client, over Config's own function, exactly as the steal
-- HOLD already is. Presentation only -- the server re-derives the real amount
-- on the trigger and never reads this back.
Config.PLOT_VAULT_ATTRIBUTE = "VaultAmount"

-- The plot's Vault Lock tier, published for the same reason the pile is: a
-- client has to be able to read it without asking. `PlotService.setLockLevel`
-- writes it and the rob badge's casing row draws it, and going through a
-- constant is what stops those two ends drifting -- the published number is
-- the interface, which this file has already paid for once.
Config.PLOT_LOCK_ATTRIBUTE = "LockLevel"

-- SOMEBODY ON THIS PLOT JUST REBIRTHED, published as a COUNTER.
--
-- A counter and never a flag or a timestamp, for the reason `DodgeRoll`
-- and `CATCH_COUNT_ATTRIBUTE` are counters: an attribute set to the same
-- value twice fires ONE changed signal, so a player who rebirths twice in
-- a session would get one show. Bumping a number cannot collide with
-- itself.
--
-- ATTRIBUTES RATHER THAN A REMOTE, because this is the one thing about a
-- rebirth that is addressed to THE STREET rather than to the player who
-- paid for it. A remote would have to be fired at everybody and would
-- reach nobody who joined a second later; an attribute is already on the
-- plot for anyone who looks. Same call the animated skins and the moat
-- make, and the same division of labour: the server decides, publishes
-- two numbers and never touches it again.
Config.PLOT_FIREWORK_ATTRIBUTE = "FireworkCount"

-- WHICH REBIRTH IT WAS, so the show can be sized to it. Written BEFORE
-- the counter, because the counter is what is watched -- see `Fireworks`,
-- where the read order is the write order reversed.
Config.PLOT_FIREWORK_RANK_ATTRIBUTE = "FireworkRank"

-- THE REBIRTH SHOW.
--
-- Rebirth is the one purchase in this game that costs a player everything
-- they own, and until now the whole of it happened on ONE SCREEN: a toast,
-- a skin drop, and a plot quietly rebuilt at level 0. The street had no
-- way of knowing anybody had done the hard thing, which for the mechanic
-- this design most needs players to press is the wrong way round.
--
-- NEON AND NOT LIGHTS, WHICH IS NOT A STYLE CHOICE. `WorldService` sets
-- `ClockTime` to 14.5 exactly once and nothing ever moves it: THERE IS NO
-- NIGHT IN THIS GAME. A PointLight at brightness 9 over an 18-stud range
-- is invisible in full sun from thirty studs away -- measured, and it is
-- what made the endgame house tiers read as vanilla until they were
-- rebuilt on emissive parts. Neon renders flat out whatever the scene is
-- doing and the shipped BloomEffect takes it from there.
Config.FIREWORKS = {
	-- HOW MANY SHELLS, and it grows with the rebirth count on purpose.
	--
	-- The gate is `REBIRTH_CAPACITY_MULTIPLE` times a capacity that has
	-- itself been climbing, so a tenth rebirth genuinely IS a bigger thing
	-- than a first -- 193.8M against 6.0M, measured. A show that could not
	-- tell those apart would be saying the same sentence about two very
	-- different afternoons.
	--
	-- The cap is not decoration either: `Config.maxLevel` stops opening
	-- ceilings at rebirth 10, so that is where the ladder this is measured
	-- against runs out. Above it the show would grow past the thing it is
	-- describing.
	shells = 4,
	shellsPerRebirth = 1,
	maxShells = 10,

	-- SECONDS BETWEEN LAUNCHES, and the floor on it is an accessibility
	-- number rather than a taste one. `HouseFX` holds the whole game to
	-- three flashes a second; shells rise on a FIXED clock, so bursts
	-- arrive exactly as often as launches and this gap IS the flash rate.
	--
	-- THE NUMBER THAT HAS TO CLEAR THE CEILING IS THE GAP LESS ITS JITTER,
	-- NOT THE GAP. The first pass here was written as "0.45, which is 2.2 a
	-- second, comfortably under" -- and 2.2 is the MEAN. The fastest draw
	-- is 0.45 - 0.15 = 0.30, which is 3.3 a second and OVER the ceiling,
	-- roughly one launch in six. Same shape as every other post-mortem in
	-- this project: two numbers multiplied without anybody checking the
	-- product, and nothing would ever have errored.
	--
	-- 0.52 - 0.14 is 0.38, which is 2.6 a second at its worst and 1.9 at
	-- its mean. ANY EDIT TO EITHER FIELD HAS TO RE-CHECK `1 / (gap -
	-- gapJitter)` against 3.
	--
	-- The jitter is what stops a show being a metronome. Ten evenly spaced
	-- bangs read as a machine; the same ten unevenly spaced read as a
	-- celebration.
	gap = 0.52,
	gapJitter = 0.14,

	-- THE CLIMB. `apex` is measured from the plot slab, so it clears the
	-- 64-stud Neon Tower -- the tallest thing any plot can stand -- by
	-- better than twenty studs, and clears the grove behind it outright.
	-- That is what makes it a STREET event rather than a garden one.
	riseSeconds = 1.15,
	apex = 90,
	apexJitter = 16,
	-- How far off the plot centre a shell may go up from. Well inside the
	-- 64-wide slab, so a shell is never launched from a neighbour's lawn.
	spread = 20,

	-- THE BURST.
	burst = 70,
	burstSpeed = NumberRange.new(26, 46),
	burstLife = NumberRange.new(0.9, 1.7),
	-- SIZED AGAINST THE DISTANCE IT IS READ FROM, WHICH IS NOT ARM'S
	-- LENGTH. It was 2.6, and photographed from 213 studs -- a viewer on
	-- the road, which is where the whole feature is aimed -- every burst
	-- rendered as the SAME WHITE CLOUD whatever colour it was. Six colours
	-- doing the work of one.
	--
	-- The palette was never the problem: photographed from 60 studs the
	-- identical bursts read pink, green, violet and amber. A 2.6-stud
	-- particle at 213 studs is a handful of pixels, and what survives that
	-- is the texture's bright CORE rather than the tint over it. At 4.5
	-- the same shot reads orange and ice-blue as separate colours.
	burstSize = 4.5,
	-- Sparks FALL. Every other effect in this game accelerates upward
	-- because it is being thrown off a piggy bank; this one has already
	-- been thrown and is on its way down, which is the whole read.
	fall = -34,

	-- The flash at the centre of a burst, which is what a particle cloud
	-- alone cannot give you: a hard bright core for a fifth of a second.
	flashSize = 7,
	flashSeconds = 0.28,

	-- HOW ADDITIVE A SPARK IS, AND IT IS NOT 1.
	--
	-- `LightEmission` blends a particle toward pure additive, so at 1 the
	-- colour is added to whatever is behind it and every channel clips.
	-- PHOTOGRAPHED AT 1 AGAINST THE SKY, ALL SIX PALETTE COLOURS RENDERED
	-- AS THE SAME WHITE -- a six-colour palette doing the work of one, with
	-- nothing erroring and nothing in any log to say so. Only a picture
	-- could have said it, which is the rule this project already writes for
	-- CSG holes arriving on a particle system.
	--
	-- It is the Martian skin's lesson one more time: a bright colour driven
	-- flat out is a white hole rather than a glowing thing. The flash CORE
	-- is allowed to stay white-hot -- that is what the middle of a firework
	-- is -- and the sparks are what have to carry the hue.
	--
	-- 0.4 was measured and was still too hot at street distance; 0.25 is
	-- what the picture settled on, alongside a bigger spark. The two are
	-- one decision -- a small particle needs the core, a big one does not.
	--
	-- Named `sparkGlow` and not `glow` deliberately: `glow` is already a
	-- lantern colour on `HOUSE_TIERS`, and this file has one recorded bug
	-- from `glow` and `fxGlow` reading as the same field.
	sparkGlow = 0.25,

	-- SIX COLOURS, AND NONE OF THEM IS GOLD.
	--
	-- Gold means money everywhere else in this game and this is the one
	-- celebration that is explicitly NOT about money -- a rebirth takes
	-- every coin the player had. Painting it in the coin colour would be
	-- the shop's pink-panel mistake at altitude: an accent spent saying
	-- something it does not mean.
	palette = {
		Color3.fromRGB(255, 96, 132),   -- rose
		Color3.fromRGB(120, 226, 255),  -- ice
		Color3.fromRGB(168, 122, 255),  -- prestige violet
		Color3.fromRGB(126, 255, 158),  -- lime
		Color3.fromRGB(255, 152, 72),   -- ember
		Color3.fromRGB(255, 244, 214),  -- white heat
	},
}

-- The show's size, solved in one place because it is a DERIVATION rather
-- than a number: change any of the three fields above and both the clamp
-- and the ladder follow. The alternative is the client keeping its own
-- copy of the arithmetic, which is the near-identical duplicate this
-- project keeps recording -- and the one that drifts silently, since a
-- show that is one shell short looks exactly like a show.
function Config.fireworkShells(rebirths: number): number
	local fw = Config.FIREWORKS
	return math.clamp(
		fw.shells + math.max(0, rebirths - 1) * fw.shellsPerRebirth,
		fw.shells,
		fw.maxShells)
end

-- WHEN THIS PLAYER'S NEW-PLAYER SHIELD LAPSES, in `workspace:GetServerTimeNow`
-- seconds, written on the PLAYER rather than on their plot.
--
-- It belongs on the player because that is what it is a fact about -- and it
-- costs nothing to put it there, since a Player instance replicates to every
-- client already and needs no push of its own. Putting it on the plot would
-- also have meant answering "which plot" at join, which is a race: the shield
-- starts when HeistService sees the player and the plot is seated separately.
--
-- Server time and not `os.clock`, because a client reads this: os.clock is a
-- process uptime and means nothing across the wire.
Config.PLAYER_SHIELD_ATTRIBUTE = "ShieldUntil"

-- TRUE WHILE A PLAYER HAS NEVER SUCCESSFULLY ROBBED ANYBODY.
--
-- The whole of this game's onboarding, and deliberately not a tutorial: the
-- game is called Rob a Piggy Bank, so the instruction is *go and rob a piggy
-- bank*. Anything more is a tutorial for a premise that fits in six words,
-- and a nine-year-old closes a tutorial.
--
-- AN ATTRIBUTE RATHER THAN A REMOTE, the same call `PLAYER_SHIELD_ATTRIBUTE`
-- makes: it replicates on its own, it costs no channel in `Remotes`, and it
-- cannot arrive before the player it describes.
--
-- DERIVED FROM `data.totalStolen` RATHER THAN A NEW SAVE FIELD. That field
-- already means "have you ever got a robbery home", so a schema migration
-- would be inventing a second answer to a question the save already
-- answers -- and this project's rule is that a flag which can disagree with
-- reality eventually does.
Config.PLAYER_FIRST_JOB_ATTRIBUTE = "NeedsFirstJob"

-- WHOSE COINS SOMEBODY IS RUNNING OFF WITH, published on the CARRIER.
--
-- It replaces a Highlight, and the reason is worth writing down because the
-- Highlight was doing its job correctly and was still wrong.
--
-- A carrying thief used to wear a gold Highlight visible through walls, on
-- the rule that a thief must never be able to hide. That is right for a
-- PLAYER thief on an eight-player street. It went badly wrong once residents
-- started robbing each other: `RESIDENTS.walk.maxOut` neighbours are out at
-- any moment, every one of them carrying, so the street was permanently full
-- of glowing figures -- and a signal that is on all the time is one nobody
-- reads. Worse, almost none of it concerned the person looking at it: a
-- neighbour robbing another neighbour is not that player's business.
--
-- SO THE MARK IS PER VIEWER NOW, AND IT ONLY APPEARS FOR THE PERSON BEING
-- ROBBED. This attribute is the whole channel: it carries the UserId of the
-- plot owner whose coins are in those arms, or nothing at all when the
-- victim is a resident or a shop -- because then it is nobody's base and
-- there is nobody to tell. `Shared/RobberMark` reads it on every client and
-- draws over exactly the carriers whose value is the local player's own id.
--
-- ON THE CARRIER RATHER THAN ON THE VICTIM, which is what makes it work for
-- both kinds of thief with one reader. A player thief's Character and a
-- resident's Model are both Instances in `workspace`, both replicate their
-- attributes, and neither needs a remote -- the same shape as `SkinKey` and
-- `DodgeRoll`, where the server publishes a fact and every client decides
-- for itself what to draw.
--
-- WHAT THIS COSTS, STATED PLAINLY: A BYSTANDER CAN NO LONGER SEE A THIEF
-- THROUGH A WALL. The old Highlight was also how somebody uninvolved found a
-- robbery in progress to join in on, and this file's `attachLoot` records
-- that in as many words -- "anyone nearby can tag, not just the victim.
-- Bystanders joining the chase is the bit that turns a robbery into a story."
-- Nabbing is UNCHANGED and still open to anybody: the nab prompt still sits on
-- the loot, at the same range, for everyone. What a bystander loses is the
-- x-ray, not the verb. They can still see a thief they can actually see --
-- who is carrying a labelled miniature of somebody's pig over their head.
Config.CARRY_VICTIM_ATTRIBUTE = "CarryingFrom"

-- WHAT THE CARRIED MINIATURE IS CALLED, and it is here because the name is now
-- an INTERFACE rather than a label.
--
-- For most of this project's life exactly one place wrote it and nothing read
-- it, so a literal in `PiggyModel` was the honest home for it. `CarryPose`
-- changed that: every client watches the character for this child and poses
-- the thief off its presence, which is what keeps the pig and the pose from
-- ever disagreeing about whether somebody is carrying -- they are the same
-- fact. That makes it the `"LockLevel"` shape, and this project has already
-- paid once for leaving one of those as a string: a rename that misses a
-- reader does not error, it reads nil and silently does nothing.
--
-- So the writer and the reader go through here, and the way to find any
-- future reader is to grep the CONSTANT rather than the word.
Config.LOOT_MODEL_NAME = "StolenPiggy"

-- WHETHER THIS CHARACTER IS ACTUALLY TIPTOEING, published so that EVERY
-- client can draw the creep rather than only the person doing it.
--
-- `TiptoeState` already tells the sneaker themselves, and that remote is not
-- enough on its own: it is a FireClient to one player, so nobody else in the
-- server knows. A sneak that only the sneaker can see is worth nothing --
-- half the point of a tiptoe is what it says to somebody watching a figure
-- come up their driveway, and this project prefers a tell to a fight
-- everywhere it can get one.
--
-- IT CARRIES THE EFFECTIVE STATE, NEVER THE INTENT, and that distinction is
-- the whole reason it is written where it is. `HeistService.setTiptoe` is
-- where the button lands, but the tiptoe is also refused mid-CLIMB -- and a
-- climb starts and stops without anybody pressing anything. Published from
-- the button, a player who grabbed a ladder would go on being drawn creeping
-- up it at full walk speed. It is written by `refreshSpeed` instead, off the
-- same test `currentSpeed` uses to decide whether to apply the multiplier at
-- all, so the animation and the speed cannot disagree by construction.
--
-- On the CHARACTER rather than the Player, because it dies with the rig it
-- describes: a respawn clears it for free, which is exactly what a stale
-- "still sneaking" flag on a fresh character would otherwise cost.
Config.SNEAK_ATTRIBUTE = "Sneaking"

-- How high above a carrier's own head the "!" floats, in studs.
--
-- Measured against what is already up there rather than chosen: the loot
-- label sits just over the carried piggy, so the mark has to clear it or the
-- two overlap on exactly the person a victim is trying to read.
Config.ROBBER_MARK_HEIGHT = 4.6

-- Above this many seconds the hold shows a COUNTDOWN as well as a bar.
--
-- This is the HUD half of a problem the vault dial already solves at the
-- piggy: a default prompt draws the same filling circle whether the hold is
-- three seconds or nine, so the whole Vault Lock tree was invisible to the
-- thief standing in front of it. The dial says what tier it is from the
-- street; the number says how long THIS one is going to take.
Config.PROMPT_COUNTDOWN_OVER = 1.5

function Config.promptStyle(kind: string?)
	return (Config.PROMPTS :: any)[kind or ""] or Config.PROMPTS.collect
end

-- ============================================================
-- FENCES
-- ============================================================
--
-- Fences used to be unjumpable walls, which made them a binary: either you
-- could get in or you couldn't. Now they're low enough to vault, and going
-- over snags you.
--
-- That turns every approach into a real choice: hop the fence and land slow
-- and exposed, or run the long way round to the gate and lose the time
-- instead. A wall offers no decision; a hurdle does.
--
-- The gate always exists. A fully sealed plot would trap its owner, and a
-- fence costs its owner time too -- they come home with loot through the
-- same gap.
-- A BARRIER ABOVE `BASE_JUMP_HEIGHT` IS NO LONGER AN UNCLIMBABLE WALL, WHICH
-- IS WHAT LETS THIS LADDER GROW AT ALL.
--
-- This block used to read: every tier from Barbed Wire up stays at the same
-- jumpable 6.0 and escalates the HAZARD instead, because a barrier over the
-- jump height would make its owner un-robbable. That reasoning was right and
-- the constraint it accepted was self-imposed -- it assumed the only way over
-- a fence is a hop. Fences now carry a TRELLIS, so anything can be climbed at
-- a marked point, and height became a tunable again.
--
-- SO THE JUMP CAME DOWN INSTEAD OF THE FENCES GOING UP, and that is the
-- cheaper lever by a wide margin. To put a tier out of hopping range while
-- keeping BASE_JUMP_HEIGHT at 7.2, every tier above it needs to start at 7.3
-- and climb from there -- and measured against a viewer on the pavement, a
-- fence over about 8 studs starts hiding the piggy bank itself. Dropping the
-- jump to 5.5 puts the SAME tiers out of range with the fence heights that
-- are already built, and leaves the whole 6-to-8 band free for tiers that do
-- not exist yet.
--
-- Defence still buys TIME, never immunity, and the line is unmoved: a tier
-- you cannot hop is a tier you climb, and a climb is time. What changed is
-- that the time is now paid on the way over rather than only on the way down.
--
-- WHICH TIERS ARE HOPPABLE IS THEREFORE A FACT ABOUT THREE NUMBERS: the jump,
-- `top`, and the stud the lawn stands above the ground the fence sits on. See
-- `isHoppableFence` and `isClimbedFence` over FENCE_TIERS, which are the only
-- two places that question is ever asked. At 5.5 that is Rickety (3.6) and
-- Picket (4.8) hopped from both sides, and Barbed, Electric and Moat (7.0)
-- climbed from both.
--
-- `top` is the solid barrier. `decorTop` is where the visuals reach, and is
-- cosmetic only -- wire and pickets never collide, so the jump maths only
-- ever depends on `top`.
--
-- `top` is now also the CLIMB HEIGHT: a ladder is built to the fence it goes
-- against, so one number is the barrier, the climb length and what a crossing
-- costs in seconds. See Config.climbSeconds.
-- ============================================================
-- CLIMBING
-- ============================================================
--
-- HOW A FENCE IS CROSSED ONCE IT IS TALLER THAN A JUMP.
--
-- BY BRINGING SOMETHING. Every segment used to carry a permanent TrussPart,
-- which meant the way over was always there and always free -- a fence was a
-- slower floor rather than a wall, and the cheapest tier in the game had a
-- climbing frame bolted to it. `Config.LADDER` is the crossing now and the
-- fence itself is solid.
--
-- THE MECHANISM IS STILL A TRUSS, because Roblox climbs one natively: no new
-- key, no prompt and no movement code, and it inherits every speed rule the
-- game already has. It is INVISIBLE inside the ladder's own geometry, which
-- is measured rather than assumed -- a truss at Transparency 1 still enters
-- the Climbing state and still carried a test character the full 8 studs.
--
-- Its cross-section is locked to 2x2 studs whatever is asked for: measured,
-- (40, 6.5, 2) hands back (40, 2, 2), a beam lying on its side. That is why
-- the picture and the mechanism are separate parts, exactly as the fence's
-- own collision is one invisible slab behind its decoration -- and it is why
-- the ladder has a face on each side of the fence, since a climber's root
-- settles 2.2 to 2.6 studs off the truss centre whatever is drawn there.
--
-- THE PLACEMENT IS THE INFORMATION NOW. This file prefers a tell to a fight,
-- and a permanent lattice said only "a fence can be climbed here, forever". A
-- ladder somebody has just stood up says who is coming over, where, and that
-- they have about twenty seconds left to do it.
--
-- A CLIMB IS A MULTIPLIER ON `currentSpeed`, never a speed of its own -- the
-- same decision the dodge and the wheelie bin's exit burst already record, and
-- for the same reason. `currentSpeed` is the one function that owns every
-- speed in this game, so a factor added there inherits all of them with no new
-- balance code: a stun returns 0 and freezes a climber on the spot, carrying
-- scales the climb off 12 rather than 16, and a fence snag slows the climb it
-- was earned on.
--
-- Measured on a live rig: Roblox climbs a truss at a FIXED FRACTION of
-- WalkSpeed, and it tracks changes mid-climb -- 16 -> 11.18 studs/s, 8 -> 5.59,
-- 4 -> 2.83. That ratio is the engine's, not ours, which is why it is recorded
-- here rather than tuned.
Config.CLIMB_SPEED_RATIO = 0.699

-- Without this a free player climbs at 11.18 studs/s and a 6-stud fence costs
-- 0.54 seconds, which is not a defence, it is a formality. At 0.35 the same
-- fence is 1.53s free and 2.04s carrying -- and the gap between those two is
-- the point: the climb OUT is always dearer than the climb in, so the tax
-- lands on the getaway, which is where this game puts every other cost.
Config.CLIMB_MULTIPLIER = 0.35

-- What a tier actually costs to get over, for the shop card and for anybody
-- balancing a tier. `speed` is the walk speed the climber has at the time, so
-- pass `currentSpeed` and the answer already accounts for loot and snags.
function Config.climbSeconds(height: number, speed: number): number
	local rate = speed * Config.CLIMB_MULTIPLIER * Config.CLIMB_SPEED_RATIO
	if rate <= 0 then
		return math.huge
	end
	return height / rate
end

-- A FENCE IS A STUD TALLER FROM THE STREET THAN FROM THE LAWN, SO EVERY
-- `top` HAS TO CLEAR THE JUMP FROM BOTH SIDES OR FROM NEITHER.
--
-- The fence stands on the world ground and the yard it encloses is the plot
-- slab, one stud up. So the same barrier is `top` from the street and
-- `top - LAWN_LIFT` from the lawn, and a tier in between is hoppable in
-- exactly one direction.
--
-- ALL THREE TOP TIERS SAT IN THAT BAND, AND THEN ALL FIVE WERE JUMPABLE FOR A
-- DIFFERENT REASON. The first pass raised 6.0 to 7.0 on a measurement of the
-- visible feet, which cleared the dead band and did not touch the real fault:
-- an R15 character's feet collide with nothing, so the number to beat is
-- `Config.jumpReach` and it was two studs higher than anybody thought. See
-- COLLISION_FLOAT.
--
-- Against a reach of 6.14 (2.139 of float plus a 4.0 jump) the climbed tiers
-- need `top` at or above 7.14. They are 8.0, so a climber is refused by 0.86
-- from the lawn and by 1.86 from the street, and Picket at 4.8 is still hopped
-- from both sides with 1.34 to spare. `Config.auditFences` refuses the band
-- outright so the next tier added cannot land back in it.
--
-- HEIGHT IS SPENT AS A LEVER, which is why the three top tiers share a number
-- rather than laddering upward. Measured from a viewer on the pavement, over
-- the front fence, to the piggy: at a barrier top of 6.0 about 56% of the pig
-- reads, at 7.0 it is 42%, and at the 7.5 these tiers now stand at it is 35%.
--
-- Keeping the OLD 5.5 jump would have needed `top` at 8.8 to beat the reach,
-- which leaves about a quarter of the pig showing and reads as a prison wall.
-- The jump came down to 4.0 instead so the fence did not have to go further,
-- and there is nothing left in the height budget: a tier above these escalates
-- what the crossing COSTS rather than how tall it is.
Config.FENCE_TIERS = {
	{
		label = "Rickety Fence", style = "rickety",
		gate = 24, top = 3.6, decorTop = 4.2,
		slow = 0.80, duration = 1.5, stun = 0,
		blurb = "Leaning posts and missing planks. Mostly a statement",
	},
	{
		label = "White Picket", style = "picket",
		gate = 18, top = 4.8, decorTop = 5.6,
		slow = 0.62, duration = 2.5, stun = 0,
		blurb = "Neat, taller, and pointed at the top",
	},
	{
		label = "Barbed Wire", style = "barbed",
		gate = 13, top = 8.0, decorTop = 8.9,
		slow = 0.42, duration = 4.0, stun = 0,
		blurb = "Steel posts strung with wire. Going over it hurts",
	},
	{
		label = "Electric Fence", style = "electric",
		gate = 10, top = 8.0, decorTop = 8.9,
		slow = 0.50, duration = 3.0, stun = 2.5,
		blurb = "Live current. Touch it and you're not going anywhere",
	},
	{
		label = "Moat", style = "moat",
		gate = 8, top = 8.0, decorTop = 8.9,
		slow = 0.50, duration = 3.0, stun = 2.5,
		-- Outer edge must stay inside PLOT_SPACING/2 (32) or neighbouring
		-- moats overlap: half (25.6) + 0.5 + width must stay under 32.
		moat = { width = 5, slow = 0.30, duration = 4.0 },
		blurb = "Water on every side. Wade it, or take the long way round",
	},
}

-- What a character can clear from standing. Fence heights are set against it,
-- and a stun drops it to zero so a stunned thief can't hop the fence anyway.
-- WHAT A CHARACTER CAN CLEAR FROM STANDING, and the number that decides which
-- fence tiers are hopped and which are climbed.
--
-- 7.2 -> 5.5. Every fence tier was under the old value, so the whole ladder
-- was one hop and the top three tiers differed only in what they did to you on
-- the way down. At 5.5 the split lands between the tiers already built:
-- Rickety 3.6 and Picket 4.8 are cleared with 0.7 to spare, and the 6.0 of
-- Barbed, Electric and Moat is missed by 0.5 -- so those three become the
-- first fences that genuinely have to be climbed.
--
-- IT IS READ IN EXACTLY ONE PLACE, `HeistService.refreshSpeed`, which is what
-- made this a cheap lever to pull. A stun still drops it to zero there, so a
-- stunned thief can neither walk nor hop.
--
-- What it does NOT break, checked rather than assumed: the trampoline throws
-- 10.1 studs and is unchanged (it is a velocity write, not a jump), and its
-- apex still lands inside every tier's ClimbZone -- which spans `top` to
-- `top + 5` -- so bouncing over a fence pays the same toll as climbing one.
-- The bin exit hop is 2.29 studs and was never near this. Kerbs, the plot
-- slab and the driveway are half-stud steps a humanoid walks up without
-- jumping at all.
Config.BASE_JUMP_HEIGHT = 4.0

-- HOW FAR THE PART OF A CHARACTER THAT ACTUALLY COLLIDES FLOATS ABOVE THEIR
-- FEET, AND IT IS THE NUMBER EVERY FENCE IN THIS GAME WAS MISSING.
--
-- An R15 character's legs and feet DO NOT COLLIDE WITH ANYTHING. Measured on
-- a live rig standing on a lawn at y 0.50, the only parts with `CanCollide`
-- are HumanoidRootPart, LowerTorso and UpperTorso:
--
--     lowest VISUAL point     0.006 above the lawn
--     lowest COLLIDING point  2.139 above the lawn
--
-- `HipHeight` (2.225) holds the whole assembly up there and the legs are
-- decoration hanging off it. So a fence is not cleared by the feet, which
-- pass straight through it; it is cleared by a hull that starts two studs up.
--
-- THAT IS WHY THE TOP THREE TIERS WERE STILL JUMPABLE AFTER BEING RAISED. At
-- BASE_JUMP_HEIGHT 5.5 the collision bottom reached 0.5 + 2.139 + 5.5 = 8.14
-- against a barrier top of 6.50, so it cleared by 1.64 studs -- while a probe
-- measuring the visible feet reported the jump blocked, agreed with the
-- geometry, and disagreed with the game. Every fence height in this project
-- had been tuned against a number that collides with nothing.
--
-- MEASURE THE COLLISION HULL, NEVER THE VISIBLE FEET. It is the same lesson
-- as measuring a building by its parts rather than its bounding box, and as
-- the animated skins' bounding box that was really measuring the sky: the
-- convenient number and the load-bearing one are different numbers.
Config.COLLISION_FLOAT = 2.139

-- How high a jumping character's collision bottom gets above whatever they
-- jumped from. This, not the jump, is what a fence has to beat.
function Config.jumpReach(): number
	return Config.COLLISION_FLOAT + Config.BASE_JUMP_HEIGHT
end

-- How much higher the lawn is than the ground the fence stands on. It is the
-- plot slab's own thickness, derived rather than written down, because the
-- two must not be able to disagree: the whole dead band above is what happens
-- when a fence height is measured against one surface and jumped from another.
--
-- THE ASSIGNMENT ITSELF LIVES DOWN BESIDE `PLOT_SIZE`, and this note is here
-- because this is where it is REASONED about. It was written here and it read
-- a `Config.PLOT_SIZE` that is not defined for another nine hundred lines --
-- so it was `nil.Y`, which throws while Config is still loading and therefore
-- takes down EVERY service and EVERY client at once, not one fence.
--
-- Same trap this file keeps recording for `local` forward references, one
-- level up: a table field reads back nil just as silently, and the only
-- difference is that this one cannot limp on. The readers below are all
-- inside function bodies, which is why they are fine where they are.

-- Hopped from BOTH sides, or climbed from both. Never one of each.
--
-- The street is the taller side, so a tier is hopped only if `top` itself is
-- under the reach; the lawn is the shorter side, so a tier is climbed only
-- once `top - LAWN_LIFT` is not. Between those two is the forbidden band, and
-- it is exactly LAWN_LIFT wide by construction.
--
-- BOTH GO THROUGH `jumpReach`, WHICH IS THE WHOLE FIX. They used to compare
-- against BASE_JUMP_HEIGHT alone, which is the height the feet reach, and the
-- feet are the one part of the character that cannot touch a fence.
function Config.isHoppableFence(tier: any): boolean
	return tier.top < Config.jumpReach()
end

function Config.isClimbedFence(tier: any): boolean
	return tier.top >= Config.jumpReach() + Config.LAWN_LIFT
end

-- A HEIGHT AUDIT, FOR THE SAME REASON `auditEconomy` EXISTS: the failure is a
-- number, and the moment to hear about a number is while you are typing it.
--
-- A tier in the band does not error and does not look wrong. It reads as a
-- fence that works, right up until somebody hops out of a yard they had to
-- climb into -- which is exactly how this shipped and stayed shipped.

-- CAN ANYBODY ACTUALLY WALK ABOUT IN A SHOP? See `Config.SHOP_ROOM` for the
-- three measurements that made this necessary, and note the shape they share
-- with every other post-mortem in this project: two fittings sized correctly
-- and nobody multiplying them against the room they both stand in.
--
-- IT AUDITS GAPS RATHER THAN PLACEMENTS, because a placement is a design
-- decision and a gap is a fact. Moving the counter back is fine; moving it
-- back until nobody fits behind it is not, and only one of those two is
-- something a number can tell you.
--
-- IT CANNOT SEE THE BAY'S RIGHT-HAND EDGE, and that is stated rather than
-- fudged: the display bay is centred on the WINDOW, which falls out of the
-- pier spacing in `ShopFront` and is not a number this file holds. That one
-- check lives over there, next to the arithmetic that produces it.
-- IS EVERY STOLEN SKIN ACTUALLY WINNABLE BACK? This is the rail the whole
-- feature rests on -- `isStealableSkin` is `spec.chest ~= nil`, and that tag
-- is a STRING naming a crate, which is an interface with no compiler behind
-- it exactly like `"LockLevel"` was. A skin pointing at a retired or renamed
-- crate is still stealable and is no longer obtainable by anybody, so a
-- nine-year-old loses it permanently and the message telling them where to
-- get it back names a crate that is not in the shop.
--
-- Nothing about that errors. `chestPool` would simply never emit it, the
-- Crates tab would never show it, and the only symptom is one skin quietly
-- becoming unobtainable. So it is checked at startup, in Studio too, for the
-- reason `auditEconomy` is: the moment to hear about it is while you are
-- typing it.
function Config.auditSkinSteal(): { string }
	local problems = {}

	-- The user's own requirement, kept as a rule rather than as a number
	-- somebody typed once: a player has to be a better prize than a shop, or
	-- there is no reason to take the risk that comes with robbing one.
	-- Measured, `LOSS_CAP` already holds player robberies to about 2.1 an
	-- hour against 173 shop cracks, so this is a floor rather than a ceiling.
	if Config.SKIN_STEAL.chance <= Config.SHOP_VAULT_DROP.chance then
		table.insert(problems, ("a player drops a skin %.0f%% of the time against a shop's %.0f%%; robbing a person is meant to be the bigger prize")
			:format(Config.SKIN_STEAL.chance * 100, Config.SHOP_VAULT_DROP.chance * 100))
	end

	for key, skin in pairs(Config.SKINS) do
		if Config.isStealableSkin(key) then
			local crate = Config.CHESTS[skin.chest]
			if not crate then
				table.insert(problems, ("%s can be stolen and names crate '%s', which does not exist")
					:format(key, tostring(skin.chest)))
			else
				-- NAMING A CRATE IS NOT THE SAME AS BEING IN ONE. `chestPool`
				-- also refuses anything `isEarnedElsewhere`, so a skin that
				-- grew a `pass` or `set` field while keeping its old tag
				-- would pass the test above and still be unreachable.
				local pool = Config.chestPool(skin.chest)
				local found = false
				for _, keys in pairs(pool) do
					for _, k in ipairs(keys) do
						if k == key then
							found = true
							break
						end
					end
				end
				if not found then
					table.insert(problems, ("%s can be stolen but is not in the %s pool it names")
						:format(key, crate.name))
				end
			end
		end
	end
	return problems
end

function Config.auditShopRoom(): { string }
	local u = Config.SHOP_UNIT
	local r = Config.SHOP_ROOM
	local problems = {}

	local function walk(what: string, gap: number)
		if gap < r.minWalk then
			table.insert(problems, ("%s is %.2f studs against a minimum of %.2f"):format(
				what, gap, r.minWalk))
		end
	end

	-- The walkways, front to back.
	walk("the aisle from the door to the vault", u.roomWidth / 2 - r.aisleX)
	walk("the customer strip in front of the counter", r.bayBack - r.counterFront)
	walk("the shopkeeper's pocket behind the counter", r.counterBack + u.roomDepth / 2)

	-- Nothing on the fittings side may reach into the aisle. The counter is
	-- the piece that nearly did, and it is the one this file can measure.
	if r.counterRight > r.aisleX then
		table.insert(problems, ("the counter reaches x %.2f, which is inside the aisle at %.2f")
			:format(r.counterRight, r.aisleX))
	end

	-- AND THE OPEN VAULT DOOR IS THE OBSTACLE BETWEEN THE TWO, so the gap the
	-- shopkeeper leaves their pocket through is measured against the leaf and
	-- not against the aisle behind it.
	--
	-- THE NEAR EDGE FOR THE WALKWAY AND THE FAR EDGE FOR THE AISLE, which is
	-- the split that was missing when both were one number: the counter has
	-- to clear whatever reaches FURTHEST toward it, and the aisle has to
	-- start beyond whatever reaches furthest away from it. Spending one value
	-- on both questions answered the second correctly and the first by a
	-- factor of three.
	walk("the way past the counter to the aisle", r.vaultDoorNearX - r.counterRight)
	if r.aisleX < r.vaultDoorFarX then
		table.insert(problems, ("the aisle starts at x %.2f, inside the swept open vault door at %.2f")
			:format(r.aisleX, r.vaultDoorFarX))
	end

	-- AND THE SHOPKEEPER HAS TO BE STANDING IN THE POCKET RATHER THAN IN THE
	-- FURNITURE. `keeperZ` is derived from the pocket so it cannot drift out
	-- of it; `keeperX` is typed, and this is what catches a typed one.
	if r.keeperX < r.shelfFace or r.keeperX > r.aisleX then
		table.insert(problems, ("the shopkeeper stands at x %.2f, outside the pocket (%.2f to %.2f)")
			:format(r.keeperX, r.shelfFace, r.aisleX))
	end
	if r.keeperZ > r.counterBack or r.keeperZ < -u.roomDepth / 2 then
		table.insert(problems, ("the shopkeeper stands at z %.2f, outside the pocket (%.2f to %.2f)")
			:format(r.keeperZ, -u.roomDepth / 2, r.counterBack))
	end

	return problems
end

function Config.auditFences(): { string }
	local problems = {}
	for i, tier in ipairs(Config.FENCE_TIERS) do
		if not Config.isHoppableFence(tier) and not Config.isClimbedFence(tier) then
			table.insert(problems, ("Fence tier %d (%s) is %.1f studs, inside the %.2f to %.2f band that is hoppable from the lawn but not from the street. Raise it to %.2f or drop it below %.2f.")
				:format(i, tier.label, tier.top,
					Config.jumpReach(), Config.jumpReach() + Config.LAWN_LIFT,
					Config.jumpReach() + Config.LAWN_LIFT, Config.jumpReach()))
		end
	end
	return problems
end

-- A SHOCK THROWS YOU OFF THE FENCE, AND IT HAS TO -- otherwise the stun it
-- comes with traps you inside the thing that caused it.
--
-- The ClimbZone sits ON TOP of the barrier, so a climber who gets shocked is
-- standing in the volume that shocked them. A stun is WalkSpeed 0 AND
-- JumpHeight 0, so they cannot walk out of it or hop off it, and `Touched`
-- re-fires on every settle: measured at 18 fires in 4 seconds, each one
-- renewing a 2.5s stun. The stun never expired. `fenceCooldown` below is what
-- breaks that loop; this is what stops the player being left standing in the
-- zone waiting for it.
--
-- Only tiers that STUN throw you. A rickety fence is meant to be climbable
-- and merely slow, so `stun > 0` is the test rather than a per-tier flag.
--
-- MEASURED, NOT CHOSEN, and the first numbers were silently useless: a plain
-- velocity write buys 0.20 studs of ground, because the humanoid's own control
-- force damps horizontal motion toward MoveDirection * WalkSpeed, which a stun
-- has just set to zero. Vertical is the one axis it does not fight, which is
-- exactly why the trampoline is vertical-only and gets away with it. Under
-- `PlatformStand` the humanoid stops steering and the same push lands: 14/22
-- measured 5.66 studs with a 1.18 apex, off the fence and onto the ground,
-- recovering to Running on its own.
Config.FENCE_KNOCKBACK = {
	back = 14,
	up = 22,
	-- Long enough to cover the flight and no longer. The character is limp
	-- while this runs -- which reads exactly like being zapped off a fence --
	-- and the stun goes on holding them still afterwards, so there is nothing
	-- to be gained by extending it.
	limp = 0.6,
}

-- How long a fence refuses to charge the same player twice.
--
-- This is the loop-breaker, and it has to outlast the penalty it guards or it
-- is not one: a cooldown shorter than `duration` simply lets the second hit
-- land as the first expires, which is the same freeze at a slower rate. Added
-- to the penalty's own duration rather than pinned, so a tier that gets a
-- longer snag gets a longer immunity with nothing to remember.
--
-- The grace on top is what stops a player who lands still touching the zone
-- from being charged again the instant it lapses.
Config.FENCE_PENALTY_GRACE = 1.0

-- ============================================================
-- COSMETICS
-- ============================================================
--
-- The permanent progression track, and the answer to "what am I grinding
-- for?".
--
-- Rebirth wipes every upgrade you own, so power is always temporary. Skins
-- and effects are never wiped -- they accumulate across every rebirth for
-- the life of the account. That split is deliberate: it means there is
-- always something ahead of you that a reset can't take away, and because
-- your piggy is visible from across the map, everything you buy is something
-- other people can see.
--
-- All of it is pure decoration. None of it touches balance, which is what
-- makes it safe to price aggressively.
--
-- EVERY BODY IS OPAQUE, AND THE FIELD IS KEPT ANYWAY. For the life of the
-- project each skin carried a `transparency` of 0.22 to 0.42, for one
-- reason: the coin pile lives INSIDE the piggy and had to show through it.
-- Photographed side by side, that was buying almost nothing and costing a
-- lot -- at 0.30 the coins read as dark smears rather than as gold, the
-- snout stopped reading as part of the face, and a neon house on the far
-- side of the street showed straight through the pig. Opaque, the same
-- model is a solid cartoon object with a real highlight on it.
--
-- WHAT PAID FOR IT IS THAT THE PIG IS NOT SOLID ANY MORE. The vault hatch
-- and the coin slit are genuine bores now, and the generated shell turns out
-- to be a true hollow manifold -- so through the hatch you see the pig's own
-- inner wall, lit, with the pile at the bottom of it. That is a better
-- picture of "how full is this piggy" than a translucent body ever was, and
-- it is the picture a thief gets by walking round the back.
--
-- The field stays because a translucent skin is a perfectly good thing to
-- sell later -- a ghost, a jelly, an ice pig. It is 0 on all 46 today
-- because none of them is that.

Config.DEFAULT_SKIN = "classic"
Config.DEFAULT_EFFECT = "none"

-- ============================================================
-- SURFACE PACKS -- ONE TEXTURE, MANY SKINS
-- ============================================================
--
-- A pack is a SURFACE and a skin is a COLOUR, and keeping those two apart is
-- the whole economy of this. `AlphaMode.Overlay` composites a pack's colour
-- map over the part's own `Color` using the map's ALPHA -- so a map that is
-- transparent everywhere hands the tint entirely to the skin, and one upload
-- becomes gold, chrome, copper, rose gold and anything else somebody types a
-- colour for. Authoring 46 metal skins would have been 46 textures.
--
-- THE MAPS ARE NUMBERS THAT HAPPEN TO BE STORED IN IMAGES, not pictures.
-- Metalness says treat the colour as a reflection rather than as a pigment;
-- roughness says how tightly to focus it. Both are read as LINEAR data, which
-- is why they are authored through Blender with the colourspace forced to
-- Non-Color -- a roughness of 0.30 saved as though it were a photograph comes
-- back as 0.58, and nothing anywhere would error.
--
-- A PACK OVERRIDES `material`, WHICH IS THE TRAP TO REMEMBER. A part carrying
-- a SurfaceAppearance ignores its own Material while going on REPORTING it --
-- so a Neon skin given a pack renders as ordinary metal with `Material` still
-- reading `Neon` in the properties panel, on all 22 of them, silently. That is
-- the `UseJumpPower` family exactly: an API that accepts the write, stores it,
-- reports it back and ignores it. `Config.skinSurface` refuses the pairing
-- rather than trusting nobody will write it.
-- ROJO OWNS THE MAPS AND ONLY THE NAME LIVES HERE, WHICH IS THE FOURTH TIME
-- THIS PROJECT HAS HAD TO MAKE THAT MOVE.
--
-- `SurfaceAppearance.ColorMap` is PLUGIN-GATED: a real Script cannot write it.
-- Measured, from a live server rather than from a probe --
--
--     [AdminService] 'skin' errored: The current thread cannot write
--     'ColorMap' (lacking capability Plugin)
--
-- -- which took `applySkin` down with it, so every skin change in the game
-- threw. `AlphaMode` is NOT gated, so the instance was created and left with
-- a mode set and four empty maps, which is the shape that made it look like a
-- failed asset rather than a refused write.
--
-- SO THE PACK IS A `.model.json` AND IS CLONED RATHER THAN ASSEMBLED, exactly
-- as `MaterialVariant` had to be after the identical refusal. Rojo serialises
-- the instance from source control, so the maps arrive already set and nothing
-- ever writes them. It also lands in `Shared`, which is ALREADY a mapped path
-- -- worth knowing, because `default.project.json` is not hot reloaded and a
-- new branch would have needed `rojo serve` restarting to appear at all.
--
-- TWO COPIES OF FOUR ASSET IDS IS THE DUPLICATE THIS FILE KEEPS RECORDING, so
-- the ids live in the model file and nowhere else. A dangling `template` is
-- safe: the pig simply wears its `material` instead, which is the same
-- fallback an empty mesh id already takes.
-- EMPTY AS IT SHIPS, AND THAT IS A RESULT RATHER THAN AN UNFINISHED JOB. The
-- same shape as `Config.HOUSE_REBUILD`: the machinery is built and proven, and
-- a pack is one row here plus one `.model.json`.
--
-- THE FIRST PACK WAS METAL AND IT WAS MEASURED AS WORSE THAN DOING NOTHING,
-- which is the finding worth keeping. Photographed at one camera under shipped
-- lighting with the pack the only variable: with it, a flat wash of yellow;
-- without it, on stock `Enum.Material.Metal`, a deeper gold with real tonal
-- range and a sheen on the snout and flank. The stock material won.
--
-- WHY, AND IT IS THE OPPOSITE OF THE ARGUMENT THAT BUILT IT. The pack's maps
-- were UNIFORM, on the reasoning that "smooth shiny metal" is a statement
-- about how light behaves and a smooth surface has no detail. True, and
-- self-defeating here: `EnvironmentSpecularScale` is 0.08 -- pulled back
-- deliberately, see `WorldService`, because a bright specular on SmoothPlastic
-- reads as plastic rather than as painted -- so there is almost no environment
-- to reflect, and a perfectly uniform metal has NOTHING LEFT to vary. What
-- makes `Material.Metal` read as metal in this lighting is the tonal variation
-- it carries for free, and the pack replaced exactly that with a flat value.
--
-- Confirmed the two obvious levers were not the constraint either: part
-- `Reflectance` at 1.00 barely moved the picture, and raising
-- `EnvironmentSpecularScale` to 1.00 barely moved it either -- which is worth
-- knowing, because that global is load-bearing for 27 SmoothPlastic skins and
-- would have been a whole-world regression bought for nothing.
--
-- SO A PACK IS FOR WHAT A `Material` CANNOT DO: speckle, crazing, glitter,
-- spots, hammering -- patterns with real variation, which are also the only
-- things that need the UV unwrap. A pack that competes with a stock material
-- has to beat it, and this one was measured losing.
--
-- AND THE FIRST THING A PACK WOULD SILENTLY BREAK IS THE `reflectance` FIELD
-- THE METAL SKINS NOW CARRY. A part wearing a SurfaceAppearance ignores its
-- own `Reflectance` while going on REPORTING the value it was set to -- so
-- putting a `surface` on `bullion` would not merely fail to help, it would
-- quietly delete the thing that makes that skin read as gold, with the
-- property panel still showing 0.45. That is the `UseJumpPower` family
-- exactly: an API that accepts the write, stores it, reads it back and
-- ignores it. Any pack that lands on a metal skin has to carry the shine in
-- its OWN metalness and roughness maps, and this file's note about a
-- capability-gated property applies to the same class of trap.
Config.SURFACE_PACKS = {
	-- THE BAND OVERLAY: ONE IMAGE, EVERY METAL. `AlphaMode.Overlay`
	-- composites this map over the part's own `Color3` using THE MAP'S ALPHA,
	-- so the map carries the BANDING and the skin carries the COLOUR. Gold,
	-- silver, chrome, copper and anything somebody types a colour for come out
	-- of one upload; authoring a texture per metal would have been a texture
	-- per metal forever.
	--
	-- IT VARIES WITH HEIGHT AND IS CONSTANT AROUND THE ANIMAL, which is the
	-- decision the whole thing rests on. The physical story is a horizontally
	-- striped room -- bright sky, dark ground, a bright horizon -- reflected in
	-- a turned cylinder, which is what every swatch in the reference palettes
	-- is a picture of. It also makes the mesh's U seam unable to show: a
	-- cylindrical unwrap smears the faces crossing the back of the animal, and
	-- a pattern that does not vary along U has nothing there to smear.
	--
	-- THE MAP IS NEUTRAL AND MOSTLY SHADOW, and both halves were measured. A
	-- tinted map would drag every skin toward its own colour and make silver
	-- brassy, so it is white and black only. And white does not brighten a
	-- colour, it DESATURATES it -- on a metal, base colour is reflectance
	-- tint, so a strong white band is the move toward chrome. Rendered on gold
	-- and on silver at a highlight alpha of 0.49, silver was right and gold
	-- came out washed out. Highlights peak at 0.17 now and the shadows do the
	-- work, because darkening moves a colour down its own value axis and
	-- leaves the hue alone.
	--
	-- IT NEEDS THE CYLINDRICAL UNWRAP AND CANNOT WORK WITHOUT IT. Measured on
	-- the old `smart_project` UVs, the direction world +Z maps to had a
	-- coherence of 0.583 on the body and 0.282 on the trim, so a band would
	-- have run a different way on every island. The mesh is unwrapped on one
	-- cylinder now and measures 0.941 and 0.857.
	bands = { name = "Polished Metal", template = "bands" },

	-- ------------------------------------------------------------------
	-- THE ANIMAL PACKS: ONE COAT, A SWAPPABLE PATTERN
	-- ------------------------------------------------------------------
	--
	-- THE FUR IS THE DEFAULT LAYER AND THE PATTERN IS THE SEPARABLE ONE, which
	-- is the shape these were asked for in. All three carry the SAME
	-- `pig_fur_normal` in their NormalMap and differ only in the ColorMap, so
	-- adding a new marking is one PNG and one six-line template pointing at
	-- the fur that already exists -- never a new coat.
	--
	-- A PART TAKES EXACTLY ONE `SurfaceAppearance`, so these are COMBINATIONS
	-- rather than a stack. That is the whole reason the fur id is repeated
	-- three times here: it is one uploaded asset referenced three times, not
	-- three uploads, and there is no way to layer two packs on one part.
	--
	-- THE MARKING'S COLOUR LIVES IN THE MAP AND THE BASE COLOUR IN THE SKIN.
	-- Overlay resolves to `lerp(partColour, mapRGB, mapAlpha)`, and a part has
	-- one `Color3` -- so one surface cannot hold two independently variable
	-- colours. Both pattern maps are therefore authored NEAR-BLACK (14,12,14)
	-- with the shape in the alpha, which is the convention that covers nearly
	-- every real animal: tiger, leopard, cow, zebra, giraffe and hyena are all
	-- a dark marking over a base the skin chooses. A LIGHT
	-- marking needs a second map rather than a second colour field.
	--
	-- `trimTemplate` IS THE FUR WITHOUT THE PATTERN, and it is not a detail.
	-- The ears, snout, tail and legs share the body's cylindrical unwrap, so
	-- handing them the striped map would run tiger bars across a snout. They
	-- take the coat and nothing else.
	animal = {
		name = "Fur", template = "animal", trimTemplate = "animal",
	},
	animal_spots = {
		name = "Spotted Fur", template = "animal_spots", trimTemplate = "animal",
	},
	animal_stripes = {
		name = "Striped Fur", template = "animal_stripes", trimTemplate = "animal",
	},

	-- THE FIRST FULL-COLOUR PACK, AND IT WORKS BY THE SAME EXPRESSION READ THE
	-- OTHER WAY. The three above carry a SHAPE in alpha and one constant RGB, so
	-- `lerp(partColour, mapRGB, mapAlpha)` lets one sheet dress a leopard and a
	-- snow leopard off two different `Color3`s. This one is
	-- opaque everywhere, and at alpha 1 that same lerp resolves to `mapRGB` --
	-- the map REPLACES the part's colour outright.
	--
	-- WHAT IT COSTS IS THE COLOURWAY, STATED PLAINLY: `SKINS.bee.body` and
	-- `.trim` stop doing anything, so a colour tweak is a re-bake and a
	-- re-upload rather than a line here. What it buys is that what was painted
	-- in Blender is exactly what ships, with no mask, no marking colour and no
	-- second thing to keep in step.
	--
	-- IT HAS ITS OWN `trimTemplate` RATHER THAN `animal`, because the trim
	-- genuinely carries art here -- a yellow snout and yellow outer ears
	-- against black legs -- which is the thing a single flat `trim` colour
	-- could never say and which `SKINS.bee.parts` was written for and could
	-- not deliver while the split trim stayed unuploaded.
	--
	-- NO NORMAL MAP, unlike the three fur packs above. Those share
	-- `pig_fur_normal` because they are coats; a bumblebee is
	-- `SmoothPlastic` and every preview it was approved from had a smooth
	-- surface. Adding one here would ship a pig nobody has looked at.
	animal_bee = {
		name = "Bumblebee", template = "animal_bee",
		trimTemplate = "animal_bee_trim",
	},
}

-- The pack a skin should actually wear, or nil.
--
-- ONE FUNCTION OWNS BOTH REFUSALS so neither can be forgotten at a call site.
-- A missing pack degrades to a plain skin, which is the same shape as
-- `Config.piggyMesh` returning nil for an empty id: the pig looks ordinary
-- rather than half-dressed.
function Config.skinSurface(tier)
	if not tier or not tier.surface then
		return nil
	end
	-- NEON AND GLASS NEVER TAKE A PACK. See the note above -- a pack overrides
	-- the material while `Material` goes on reporting whatever was set, so the
	-- failure is silent in both directions.
	--
	-- NEON was the known case: it would kill the glow on 22 skins. GLASS was
	-- found by trying to convert the Snow Leopard, whose whole identity is a
	-- glass body carrying deliberately plastic marks -- a pack would have
	-- turned the one thing separating it from the Leopard into grey plastic,
	-- with `material = Enum.Material.Glass` still sitting in its row saying
	-- otherwise. That is the `UseJumpPower` family exactly, and the fix is the
	-- same shape as Neon's: refuse the pairing rather than trusting that
	-- nobody writes it.
	--
	-- ANY MATERIAL WHOSE LOOK IS THE POINT belongs on this list. The test is
	-- not "is it exotic" -- it is whether the skin would still be that skin
	-- rendered as plain plastic.
	if tier.material == Enum.Material.Neon
		or tier.material == Enum.Material.Glass then
		return nil
	end
	local pack = Config.SURFACE_PACKS[tier.surface]
	if not pack or not pack.template then
		return nil
	end
	return pack
end

Config.SKINS = {
	classic = {
		name = "Classic Pink", order = 1, cost = 0, rarity = "common",
		body = Color3.fromRGB(244, 168, 194), trim = Color3.fromRGB(214, 122, 148),
		material = Enum.Material.SmoothPlastic, transparency = 0,
	},
	bubblegum = {
		chest = "og",
		name = "Bubblegum", order = 2, cost = 8000, rarity = "common",
		body = Color3.fromRGB(255, 132, 190), trim = Color3.fromRGB(206, 78, 148),
		material = Enum.Material.SmoothPlastic, transparency = 0,
	},
	mint = {
		chest = "og",
		name = "Mint Choc", order = 3, cost = 20000, rarity = "common",
		body = Color3.fromRGB(148, 226, 190), trim = Color3.fromRGB(88, 62, 52),
		material = Enum.Material.SmoothPlastic, transparency = 0,
	},
	sunset = {
		chest = "og",
		name = "Sunset", order = 4, cost = 45000, rarity = "common",
		body = Color3.fromRGB(255, 158, 92), trim = Color3.fromRGB(206, 92, 108),
		material = Enum.Material.SmoothPlastic, transparency = 0,
	},
	midnight = {
		chest = "og",
		name = "Midnight", order = 5, cost = 90000, rarity = "common",
		body = Color3.fromRGB(78, 84, 156), trim = Color3.fromRGB(44, 48, 96),
		material = Enum.Material.Glass, transparency = 0,
	},
	lava = {
		chest = "og",
		name = "Lava", order = 6, cost = 200000, rarity = "common",
		body = Color3.fromRGB(232, 92, 48), trim = Color3.fromRGB(58, 30, 26),
		material = Enum.Material.Neon, transparency = 0,
	},
	galaxy = {
		chest = "og",
		name = "Galaxy", order = 7, cost = 500000, rarity = "common",
		body = Color3.fromRGB(126, 82, 200), trim = Color3.fromRGB(52, 34, 92),
		material = Enum.Material.Neon, transparency = 0,
	},
	pearl = {
		chest = "og",
		name = "Pearl", order = 8, cost = 1200000, rarity = "common",
		body = Color3.fromRGB(248, 244, 236), trim = Color3.fromRGB(206, 198, 220),
		material = Enum.Material.Glass, transparency = 0,
	},

	-- Earned by rebirthing rather than paid for, so the collection has two
	-- routes into it and a rebirth still hands you something to show off.
	bronze = {
		name = "Bronze", order = 20, unlockRebirths = 1, rarity = "rare",
		body = Color3.fromRGB(196, 132, 74), trim = Color3.fromRGB(150, 96, 50),
		material = Enum.Material.Metal, transparency = 0,
		reflectance = 0.35,
	},
	-- AND THE NOTE THAT USED TO SIT HERE WAS WRONG, WHICH IS WORTH KEEPING
	-- BECAUSE IT SOUNDED RIGHT. It read: "leaf is thin and pale on purpose, so
	-- it keeps its light colour" -- and it kept the two golds apart by keeping
	-- this one BRIGHT, which is precisely the fault `bullion` had just been
	-- fixed for. Measured, it was the worst offender in the whole set: body
	-- luminance 0.753 against bullion's 0.613, so it had 0.247 of headroom to
	-- white where bullion had 0.387. Reported, accurately, as not looking
	-- metallic at all.
	--
	-- THE TWO GOLDS ARE SEPARATED BY HUE AND SATURATION INSTEAD, which costs
	-- neither of them their range: this one is a cool, muted, antique gold
	-- (luminance 0.601) and `bullion` is a warm saturated one. A skin that has
	-- to stay pale to be recognisable cannot be metallic, and this one never
	-- had to.
	goldleaf = {
		name = "Gold Leaf", order = 21, unlockRebirths = 3, rarity = "rare",
		body = Color3.fromRGB(186, 152, 72), trim = Color3.fromRGB(140, 110, 46),
		material = Enum.Material.Metal, transparency = 0,
		reflectance = 0.40,
	},
	-- NO `chest` TAG YET, DELIBERATELY. Skins are crate-only, so a chest tag
	-- is what makes one obtainable -- and adding this to a pool would
	-- rebalance that pool's odds as a side effect of a rendering test. It is
	-- reachable through the admin console until somebody decides which crate
	-- it belongs in, and that decision is a design call rather than a
	-- consequence of shipping the texture.
	-- `Enum.Material.Metal` AND NO SURFACE PACK, WHICH IS A MEASURED CHOICE
	-- RATHER THAN THE ABSENCE OF ONE. This skin wore the metal pack for one
	-- session and was photographed side by side with and without it under
	-- shipped lighting: the stock material is the better-looking metal, for
	-- the reason written at `Config.SURFACE_PACKS`. Putting `surface` back on
	-- this row makes the pig FLATTER, not shinier.
	--
	-- AND THE COLOUR CAME DOWN RATHER THAN THE SHINE GOING UP, WHICH IS THE
	-- HALF THAT ACTUALLY MADE IT READ AS METAL. It shipped at (241, 164, 50),
	-- which is a bright orange-yellow -- and a highlight on a surface that
	-- bright has NOTHING TO BE BRIGHTER THAN. Photographed at one camera
	-- under shipped lighting the pig was a flat orange lozenge with no
	-- hotspot, no rim on the ears and no shading under the belly, against a
	-- Cycles reference whose gold runs from near-white down to deep brown.
	--
	-- A METAL IS READ BY ITS TONAL RANGE, NOT BY ITS BRIGHTNESS. Dropping the
	-- base to (214, 152, 30) and letting `reflectance` put the light back
	-- gives the same average gold with a range around it: measured at one
	-- camera, a warm hotspot on the upper flank, ear rims, and a deep bronze
	-- under the belly. It is DARKER on paper and reads as SHINIER on screen,
	-- which is the opposite of what the numbers look like.
	--
	-- AND `reflectance` IS DEAD ON THIS ROW WHILE THE PACK IS ON IT, WHICH IS
	-- WHY IT IS STILL WRITTEN HERE. A part wearing a SurfaceAppearance ignores
	-- its own `Reflectance` while going on REPORTING the value it was set to --
	-- the `UseJumpPower` family, an API that accepts the write, stores it,
	-- reads it back and ignores it. It is kept rather than deleted because it
	-- is what this skin falls back to if the pack ever fails to load, and
	-- because deleting it would leave the next person to drop the pack with a
	-- flat pig and nothing saying why.
	bullion = {
		name = "Solid Gold", order = 232, cost = 1500000, rarity = "legendary",
		body = Color3.fromRGB(214, 152, 30), trim = Color3.fromRGB(162, 104, 16),
		material = Enum.Material.Metal, transparency = 0,
		reflectance = 0.45,
		surface = "bands",
	},

	diamond = {
		name = "Diamond", order = 22, unlockRebirths = 6, rarity = "legendary",
		body = Color3.fromRGB(150, 226, 236), trim = Color3.fromRGB(104, 190, 208),
		material = Enum.Material.Glass, transparency = 0,
	},

	-- ANIMATED DROP POOL
	--
	-- Not for sale at any price. The only way in is rebirthing, which is what
	-- makes them worth chasing -- coins can buy every skin above this line.
	--
	-- `anim` is read by the CLIENT, never the server. Animating a colour
	-- server-side would replicate a property write per piggy per frame, which
	-- is 700+ writes a second across twelve plots for something every client
	-- can compute for itself from a single attribute.
	ember = {
		chest = "og",
		name = "Ember Glow", order = 30, rarity = "rare",
		body = Color3.fromRGB(226, 104, 52), trim = Color3.fromRGB(120, 44, 30),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "pulse", speed = 1.4, palette = {
			Color3.fromRGB(226, 104, 52), Color3.fromRGB(255, 176, 84),
		} },
	},
	frostbite = {
		chest = "og",
		name = "Frostbite", order = 31, rarity = "rare",
		body = Color3.fromRGB(186, 232, 248), trim = Color3.fromRGB(120, 176, 208),
		material = Enum.Material.Glass, transparency = 0,
		anim = { kind = "pulse", speed = 0.8, palette = {
			Color3.fromRGB(186, 232, 248), Color3.fromRGB(246, 252, 255),
		} },
	},
	toxic = {
		chest = "og",
		name = "Toxic Ooze", order = 32, rarity = "rare",
		body = Color3.fromRGB(140, 226, 84), trim = Color3.fromRGB(66, 122, 40),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "cycle", speed = 0.7, palette = {
			Color3.fromRGB(140, 226, 84), Color3.fromRGB(96, 190, 70), Color3.fromRGB(196, 240, 110),
		} },
	},
	candyswirl = {
		chest = "og",
		name = "Candy Swirl", order = 33, rarity = "rare",
		body = Color3.fromRGB(255, 150, 200), trim = Color3.fromRGB(255, 236, 244),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		anim = { kind = "cycle", speed = 1.1, palette = {
			Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 244, 250), Color3.fromRGB(150, 210, 255),
		} },
	},

	aurora = {
		chest = "og",
		name = "Aurora", order = 40, rarity = "rare",
		body = Color3.fromRGB(96, 226, 190), trim = Color3.fromRGB(60, 110, 150),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "cycle", speed = 0.55, glow = 1.6, palette = {
			Color3.fromRGB(96, 226, 190), Color3.fromRGB(84, 160, 238),
			Color3.fromRGB(178, 118, 236), Color3.fromRGB(96, 226, 190),
		} },
	},
	magma = {
		chest = "og",
		name = "Magma Core", order = 41, rarity = "rare",
		body = Color3.fromRGB(210, 58, 30), trim = Color3.fromRGB(52, 20, 16),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "flicker", speed = 9, glow = 2.2, palette = {
			Color3.fromRGB(150, 32, 18), Color3.fromRGB(255, 148, 44),
		} },
	},
	voidsilk = {
		chest = "og",
		name = "Void Silk", order = 42, rarity = "rare",
		body = Color3.fromRGB(46, 30, 72), trim = Color3.fromRGB(22, 14, 36),
		material = Enum.Material.Glass, transparency = 0,
		anim = { kind = "pulse", speed = 0.5, glow = 1.4, palette = {
			Color3.fromRGB(46, 30, 72), Color3.fromRGB(140, 78, 220),
		} },
	},

	supernova = {
		chest = "og",
		name = "Supernova", order = 50, rarity = "legendary",
		body = Color3.fromRGB(255, 230, 150), trim = Color3.fromRGB(232, 128, 40),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "cycle", speed = 2.2, glow = 4.0, palette = {
			Color3.fromRGB(255, 248, 220), Color3.fromRGB(255, 196, 72),
			Color3.fromRGB(255, 110, 40), Color3.fromRGB(255, 248, 220),
		} },
	},
	stormcaller = {
		chest = "og",
		name = "Stormcaller", order = 51, rarity = "legendary",
		body = Color3.fromRGB(120, 176, 255), trim = Color3.fromRGB(40, 52, 92),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "flicker", speed = 14, glow = 4.5, palette = {
			Color3.fromRGB(64, 96, 176), Color3.fromRGB(232, 246, 255),
		} },
	},
	prismatic = {
		chest = "og",
		name = "Prismatic", order = 52, rarity = "legendary",
		body = Color3.fromRGB(255, 120, 120), trim = Color3.fromRGB(255, 255, 255),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "rainbow", speed = 0.35, glow = 3.5 },
	},

	-- ALIEN SET. Carries `set`, which keeps it out of the rebirth drop pool --
	-- see the note on Config.SETS. Priced in loot and in nothing else.
	martian = {
		name = "Martian", order = 60, set = "alien", loot = 40, rarity = "epic",
		-- DEEP GREEN, NOT PALE GREEN, and that is the same lesson the Marble
		-- Palace's fxGlow taught: Neon renders a colour flat out and the
		-- BloomEffect takes it from there, so a light tint on a twelve-stud
		-- sphere is a white hole rather than a glowing pig. Measured by
		-- looking -- at (126, 232, 132) the skin blew out the piggy, the
		-- lawn, the fence and the ornaments around it into one white mass.
		--
		-- The pulse palette stays WITHIN the greens for the same reason: a
		-- ramp whose top end is near-white spends half its cycle blown out.
		body = Color3.fromRGB(52, 190, 90), trim = Color3.fromRGB(28, 104, 58),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "pulse", speed = 1.1, glow = 2.0, palette = {
			Color3.fromRGB(52, 190, 90), Color3.fromRGB(104, 226, 128),
		} },
	},

	-- ============================================================
	-- THE ANIMAL BUCKET
	-- ============================================================
	--
	-- `chest = "animal"`. Every one of these is a PATTERN skin: the point of
	-- adding patterns at all was that a two-colour skin could only ever make a
	-- "Zebra" that was a white pig with black legs, and a nine-year-old asked
	-- for a zebra is asking for stripes.
	--
	-- The pattern spec is read by PiggyModel.applyPattern, which both the
	-- piggy on the lawn and the piggy in the shop tile go through, so nothing
	-- here can be true in the catalogue and false on the street. Two kinds
	-- only -- `stripes` and `spots` -- because both are proven techniques
	-- already in this repo (the vault's segmented rim and the turtle's
	-- mottling) and a third would be a shape nobody has measured.
	--
	-- SIZES ARE FRACTIONS OF THE BODY RADIUS, never studs, which is what lets
	-- one spec draw a six-stud piggy on a lawn and a 1.1-stud one in a tile.
	--
	-- TIERS ARE PRICED, NOT TAGGED, for everything that can be bought: four
	-- commons under 100K, three rares, three epics, and the two at the top
	-- carry an explicit `rarity` and no price at all. A chest rolls a tier
	-- FIRST and then picks an item of that tier, so a tier with odds and no
	-- stock is a button that takes coins and returns nothing -- which is why
	-- all four are stocked rather than roughly stocked.
	ladybird = {
		chest = "animal",
		name = "Ladybird", order = 100, cost = 25000, rarity = "common", rarity = "common",
		body = Color3.fromRGB(214, 44, 44), trim = Color3.fromRGB(30, 28, 32),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- Small, round, evenly spread and not many: a ladybird's spots are
		-- the one real animal marking that genuinely IS a scatter of discs.
		pattern = {
			kind = "spots", seed = 3,
			colour = Color3.fromRGB(24, 22, 26),
			count = 13, size = 0.11, vary = 0.25,
		},
	},
	cow = {
		chest = "animal",
		name = "Dairy Cow", order = 101, cost = 35000, rarity = "common", rarity = "common",
		-- The trim stays PINK rather than going black with the blotches. It
		-- paints the snout, and a cow's muzzle is the one part of it that is
		-- pink -- so the two channels each say something instead of both
		-- saying "Holstein".
		body = Color3.fromRGB(246, 244, 238), trim = Color3.fromRGB(226, 158, 168),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- Few and LARGE, with heavy size jitter, because a cow is blotches
		-- rather than dots. The difference is entirely `count` against `size`,
		-- which is what the Dalmatian below used to demonstrate before it went
		-- with the flat-paint animals.
		pattern = {
			kind = "spots", seed = 11,
			colour = Color3.fromRGB(34, 32, 38),
			count = 11, size = 0.30, vary = 0.40,
		},
	},

	zebra = {
		chest = "animal",
		name = "Zebra", order = 110, cost = 250000, rarity = "common",
		body = Color3.fromRGB(244, 242, 236), trim = Color3.fromRGB(36, 34, 38),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- THE POLE IS THE MUZZLE, AND THAT IS THE WHOLE SKIN. Every other
		-- pattern in this catalogue girdles the SPINE, which is right for a
		-- bee and was never right for a zebra. Measured on the version this
		-- replaces: the nearest band sat 54 degrees off the snout, so there
		-- was nothing on the face at all, and the lowest one stopped 4.6
		-- degrees ABOVE the equator -- the whole marking was a cap of bars
		-- pulled down over the head with clean white flanks underneath it.
		-- No arrangement of seven spine-girdling bands fixes that, which is
		-- why this is a new axis rather than new numbers.
		--
		-- `axis` aims the pole out through the snout instead, and ONE family
		-- of bands then does all three things a zebra's markings do at once:
		-- a circle of constant angle from that pole is a ring on the FACE
		-- near the pole, a near-vertical stripe down the FLANK at ninety
		-- degrees, and a ring closing on the TAIL beyond it. So the stripes
		-- radiate out of the face, run down the sides and converge on the
		-- rump. Nothing else about the builder changed.
		--
		-- 17.7 DEGREES BELOW THE FORWARD HORIZONTAL, and that is a compromise
		-- between the two piggies one spec has to draw: the plot piggy's own
		-- snout sits at 24.1 degrees and the carried mini's at 13.4, so a pole
		-- aimed at either one is visibly off the other's face.
		--
		-- `faceGap` is what lets a fan cross the face at all. It cuts each
		-- band's arc around the eyeballs rather than drawing a stripe through
		-- one, so a stripe ENDS at the eye and picks up past it -- which is
		-- what a real zebra's face does. 16 degrees against an eyeball six
		-- degrees across leaves about ten degrees of white either side on
		-- BOTH piggies, which is the slack that lets one number serve two
		-- models whose eyes are 7.8 degrees apart. `taper` brings each band to
		-- a point as it runs under the belly, because a band of one width the
		-- whole way round is a hoop rather than a marking.
		--
		-- MEASURED BEFORE IT WAS WRITTEN, against the shipped geometry: 71
		-- segments (the old pattern was 50), clear of the eyeballs by 19.8
		-- degrees on the plot piggy and 19.1 on the mini, clear of the vault
		-- dial by 44.1 -- so a thief still reads the lock tier off the back --
		-- clear of the snout's own 16.4-degree disc by 32.3, which is the ring
		-- of white the reference plush wears round its muzzle, and reaching
		-- 22.2 degrees below the equator against legs that meet the body at
		-- 41.3.
		--
		-- `wobble` jitters each band's position and width off the even
		-- spacing, because nine identical bands at identical intervals is a
		-- barcode.
		--
		-- STILL THE PART-BUILT PATTERN, and it is the last thing about this
		-- skin that is. The painted map (`pig_stripes_bold_color.png`, eleven
		-- bars) is built and looked at and is not uploaded, so there is no
		-- `surface` pack to point at yet -- see the tiger and the leopard for
		-- the shape this takes once there is.
		pattern = {
			kind = "stripes", seed = 13,
			colour = Color3.fromRGB(30, 28, 32),
			axis = Vector3.new(0, -0.32, 1),
			count = 9, width = 0.15, spread = 0.85, arc = 240, wobble = 0.30,
			taper = 0.50, faceGap = 16,
		},
		-- THE FIRST SKIN TO NAME A FUR SET, which is what the set table was
		-- built for. A zebra's mane is a short upright brush between the ears
		-- and nothing else -- handed the default it would wear the tiger's
		-- full ruff and cheek sweeps, which is a lion.
		--
		-- `fur` is the flag AND the colour, so this is what makes the tuft
		-- appear at all. It takes the TRIM's black rather than the body's
		-- white: the plush reference has a solid dark brush, and seven strands
		-- each carrying a fragment of a stripe is noise at that size.
		fur = Color3.fromRGB(36, 34, 38),
		furSet = "crest",
	},
	bee = {
		chest = "animal",
		name = "Bumblebee", order = 111, cost = 400000, rarity = "common",
		-- DEEPER THAN IT WAS, TWICE. (250, 198, 40) is a pale lemon; the
		-- reference is a saturated golden yellow, and against black bands the
		-- pale one reads as washed rather than as a bee. The first correction
		-- to (247, 178, 24) was still light -- looked at beside the reference
		-- the plush is deeper again, and the difference is mostly in the GREEN
		-- channel, which is what separates a lemon from a honey.
		body = Color3.fromRGB(236, 160, 12), trim = Color3.fromRGB(26, 23, 22),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- FOUR FAT BANDS AND NO WOBBLE, which is the whole difference from the
		-- zebra: a bee is regular and a zebra is not, and both come out of the
		-- same three numbers.
		--
		-- THE MAP REPLACED THE PART-BUILT PATTERN, WHICH IS WHAT THE NOTE HERE
		-- HAS BEEN WAITING FOR. `pattern = { kind = "stripes", ... }` drew four
		-- fat bands out of real geometry standing off the body, and its own
		-- comment recorded the fault: it draws the wrong AXIS. A bee's bands are
		-- slices of a loaf from nose to tail; that builder rings the animal at
		-- constant HEIGHT, which is a belt rather than a band and cannot be
		-- turned into one by any of its three numbers.
		--
		-- BOTH ARE DELETED RATHER THAN ONE LEFT DORMANT. A skin carrying a
		-- `surface` AND a `pattern` wears the map with stripe segments standing
		-- on top of it, which reads as the map having failed.
		surface = "animal_bee",
		-- THE ONE SKIN THAT NEEDS THE SPLIT TRIM, AND THE REASON IT EXISTS.
		--
		-- Everything else in the catalogue says its second tone once. The
		-- reference bumblebee has a YELLOW FACE MASK against BLACK EARS and
		-- BLACK LEGS, with the tail coming out of a yellow rump -- two
		-- colours on what used to be one welded MeshPart, which no texture
		-- map can express because a trim part wears a flat colour by design.
		--
		-- Snout and Tail are named; Ears and Legs are not, so they fall
		-- through to `trim` above. A skin says only what differs.
		--
		-- INERT UNTIL THE FOUR PARTS ARE UPLOADED. With `PIGGY_TRIM_PARTS`
		-- unfilled the pig stands up its joined `Trim` and this table matches
		-- nothing, so the bee is a black-trimmed yellow pig -- which is what
		-- it already was, rather than a broken one.
		parts = {
			Snout = Color3.fromRGB(236, 160, 12),
			Tail = Color3.fromRGB(236, 160, 12),
			-- The nostrils stay near-black against the yellow face, which is
			-- what the reference has and what `NEAR_BLACK` already gives --
			-- named here anyway, because the bee is the skin whose face this
			-- was reported on and a default that happens to be right is not
			-- the same as a decision.
			Nostril = Color3.fromRGB(26, 23, 22),
		},
	},

	giraffe = {
		chest = "animal",
		name = "Giraffe", order = 120, cost = 1800000, rarity = "common",
		body = Color3.fromRGB(234, 196, 124), trim = Color3.fromRGB(168, 120, 62),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- Large patches packed close, with LOW jitter: a giraffe reads as a
		-- tiling rather than as a scatter, so the size variation that makes
		-- the cow look natural is exactly wrong here.
		pattern = {
			kind = "spots", seed = 19,
			colour = Color3.fromRGB(150, 96, 44),
			count = 16, size = 0.26, vary = 0.20,
		},
	},
	leopard = {
		chest = "animal",
		name = "Leopard", order = 121, cost = 2400000, rarity = "common",
		body = Color3.fromRGB(232, 186, 110), trim = Color3.fromRGB(128, 86, 44),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- The second skin on a texture pack, and the pair is deliberate: one
		-- stripes, one spots, both live, with the other eight animals left on
		-- the part-built `pattern` so the two can be compared on one street
		-- rather than the whole bucket being converted on an argument.
		-- `fur` IS THE RAISED RUFF, AND IT IS THE BODY'S OWN COLOUR ON
		-- PURPOSE. It came off this skin once, when the lobes had no usable
		-- UVs and could therefore only be a flat colour -- which on a
		-- patterned coat is a PATCH whatever shade it is: cream read as white
		-- blobs stuck on the animal, and the body's colour would have read as
		-- a bald spot where the spots stop.
		--
		-- The lobe mesh is unwrapped on the BODY'S OWN CYLINDER now, so it
		-- samples the same ColorMap at the same place and the pattern carries
		-- straight over the fur. What is left for this field to do is the base
		-- tone UNDER that pattern, which should match the body or the ruff
		-- reads as a different animal stitched on. Give it its own value only
		-- to deliberately make a contrasting mane.
		surface = "animal_spots",
		fur = Color3.fromRGB(232, 186, 110),
	},

	-- CHEST-ONLY. An explicit `rarity` and no `cost`, which is what keeps them
	-- out of the shop's coin grid and stops the free-if-costless fallback in
	-- `Config.isSkinUnlocked` handing them to everybody. Note this also puts
	-- them in the REBIRTH DROP POOL, exactly as the classics' drop skins are:
	-- `Config.getSkinsOfRarity` selects on `rarity` and excludes only `set`.
	tiger = {
		chest = "animal",
		name = "Bengal Tiger", order = 130, rarity = "common",
		body = Color3.fromRGB(238, 132, 36), trim = Color3.fromRGB(250, 240, 228),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- THE FIRST SKIN OFF THE PART-BUILT PATTERN AND ONTO A TEXTURE, and
		-- the `pattern` spec above it is gone rather than kept alongside. The
		-- built version drew eight bands out of PARTS: real geometry standing
		-- proud of the body, which cost parts per pig and could only ever be
		-- bands rather than the tapered wobbling shapes a tiger actually has.
		-- The map draws fifteen, each with its own wobble and taper, for no
		-- parts at all -- and it clears the eyes, which the part version could
		-- not, because a stripe through an eye is the one place this stopped
		-- reading as an animal.
		--
		-- `fur` IS THE THIRD COLOUR AND IT IS NOT OPTIONAL FOR A FURRED SKIN.
		-- The lobes are their own MeshPart, so they cannot carry the body's
		-- pattern map -- their UVs do not correspond to it. Left the body's
		-- colour they read as orange lumps interrupting the stripes; in the
		-- trim's cream they read as a ruff, which is what an animal has.
		-- `fur` IS THE RAISED RUFF, AND IT IS THE BODY'S OWN COLOUR ON
		-- PURPOSE. It came off this skin once, when the lobes had no usable
		-- UVs and could therefore only be a flat colour -- which on a
		-- patterned coat is a PATCH whatever shade it is: cream read as white
		-- blobs stuck on the animal, and the body's colour would have read as
		-- a bald spot where the spots stop.
		--
		-- The lobe mesh is unwrapped on the BODY'S OWN CYLINDER now, so it
		-- samples the same ColorMap at the same place and the pattern carries
		-- straight over the fur. What is left for this field to do is the base
		-- tone UNDER that pattern, which should match the body or the ruff
		-- reads as a different animal stitched on. Give it its own value only
		-- to deliberately make a contrasting mane.
		surface = "animal_stripes",
		fur = Color3.fromRGB(238, 132, 36),
	},
	snowleopard = {
		chest = "animal",
		name = "Snow Leopard", order = 131, rarity = "common",
		body = Color3.fromRGB(228, 234, 244), trim = Color3.fromRGB(150, 164, 184),
		material = Enum.Material.Glass, transparency = 0,
		-- The marks stay PLASTIC on a glass body. Glass at 0.28 would make the
		-- rosettes a suggestion rather than a pattern, and the point of the
		-- material override is exactly this case.
		pattern = {
			kind = "spots", seed = 37,
			colour = Color3.fromRGB(52, 58, 72),
			count = 25, size = 0.14, vary = 0.45,
			material = Enum.Material.SmoothPlastic, transparency = 0.08,
		},
	},
	-- THE ONLY LEGENDARY ON THIS SHELF, AND THE ONLY ONE THAT MEETS THE
	-- TIER'S OWN BRIEF: it glows AND the glow moves. Everything else in the
	-- Animal Kingdom is a painted coat, which is what a common is.
	--
	-- IT IS WEARING PAINT RATHER THAN ITS COAT, AND THAT IS PENDING AN UPLOAD
	-- RATHER THAN A DECISION. `blender/pig/skins/stormwolf/` holds the built
	-- skin -- a near-black marbled animal with forked lightning running
	-- through it, baked through the alpha pass so the bolt CHANNEL is handed
	-- to the animator and the core stays baked. What is missing is the one
	-- thing this repo cannot do for itself: the sheet has to be published
	-- under the developer's own account, and every upload is moderated.
	--
	-- WHEN IT LANDS IT IS ONE FIELD. Add `surface = "stormwolf"` here and a
	-- `SurfacePacks/stormwolf.model.json` beside the other five, exactly as
	-- the tiger and the leopard already resolve. Until then `skinSurface`
	-- returns nil for a skin naming no pack and the body paint below shows --
	-- the same graceful-degradation contract `FUR_SETS.crest` keeps with its
	-- empty id, and the reason an unfinished skin can sit in the catalogue
	-- without erroring.
	--
	-- AND THE MATERIAL MAY NOT BE NEON OR GLASS, which is why a storm animal
	-- is SmoothPlastic. `Config.skinSurface` refuses a pack to either, because
	-- a part wearing a `SurfaceAppearance` ignores its own Material while
	-- going on reporting it -- so a Neon Storm Wolf would silently lose its
	-- coat the day the coat arrived.
	--
	-- PRICED, THOUGH NOTHING BUYS IT. `sellValue` applies its cap only to a
	-- skin carrying a cost, so an unpriced legendary sells for the full tier
	-- value of 1,000,000 out of a 500,000 chest -- a duplicate paying DOUBLE
	-- the open, against this game's rule that a duplicate is always a real
	-- loss. At 500,000 the cap bites at 125,000, which is 25% of an open and
	-- lands inside the 21-35% band the sell ladder was measured for. A cost on
	-- a crate-only skin is a SELL CEILING and nothing else now, because the
	-- rarity beside it is explicit.
	stormwolf = {
		chest = "animal",
		name = "Storm Wolf", order = 140, cost = 500000, rarity = "legendary",
		-- The marble and the storm, straight off the Blender build's own
		-- palette: a near-black animal is a silhouette with nothing in it, so
		-- the dark is swirled blue-violet rather than flat.
		body = Color3.fromRGB(48, 40, 74), trim = Color3.fromRGB(8, 8, 16),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- FLICKER, BECAUSE IT IS LIGHTNING. The palette runs the bolt channel
		-- from a deep storm blue to the near-white core -- which reads right
		-- both ways round: on the bare paint the whole animal flickers, and
		-- under the coat only the alpha-0 bolt channels do, because that is the
		-- only place the part's own Color survives the overlay.
		anim = { kind = "flicker", speed = 13, glow = 3.2, palette = {
			Color3.fromRGB(44, 58, 112), Color3.fromRGB(240, 249, 255),
		} },
	},

	-- ============================================================
	-- THE NEON BUCKET
	-- ============================================================
	--
	-- THE NEON RUN, WHICH IS PART OF `og` NOW RATHER THAN A SHELF OF ITS OWN.
	-- Every body here is Neon and every body here is DEEP,
	-- which is the rule the Martian and the Marble Palace both paid for: Neon
	-- renders a colour flat out and the BloomEffect takes it from there, so a
	-- pale tint on a twelve-stud sphere is a white hole rather than a glowing
	-- pig. The BRIGHT colour is the pattern, which covers a fraction of the
	-- surface and can therefore afford to be loud.
	--
	-- ANIMATION REUSES THE FOUR KINDS THE CLIENT ALREADY DRIVES -- pulse,
	-- cycle, flicker, rainbow. A fifth would mean editing ClientMain, which is
	-- at Luau's 200-local ceiling, for a curve none of these needed.
	--
	-- THE PATTERN DOES NOT ANIMATE, AND THAT IS THE INTENDED READ. The client
	-- animator paints the Body and the four trim names; the marks live in a
	-- `Pattern` folder it never touches, so they hold their colour while the
	-- body cycles underneath. Every trace below is therefore authored either
	-- near-white or near-black -- a mid-tone would disappear for whichever
	-- part of the cycle the body happened to pass through it.
	cyberlime = {
		chest = "og",
		name = "Cyber Lime", order = 200, cost = 12000, rarity = "rare",
		body = Color3.fromRGB(110, 200, 20), trim = Color3.fromRGB(48, 92, 10),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "pulse", speed = 1.2, palette = {
			Color3.fromRGB(110, 200, 20), Color3.fromRGB(150, 232, 56),
		} },
	},
	neonmint = {
		chest = "og",
		name = "Neon Mint", order = 201, cost = 40000, rarity = "rare",
		body = Color3.fromRGB(36, 196, 146), trim = Color3.fromRGB(16, 92, 72),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "pulse", speed = 0.9, palette = {
			Color3.fromRGB(36, 196, 146), Color3.fromRGB(64, 226, 176),
		} },
	},
	hotwire = {
		chest = "og",
		name = "Hot Wire", order = 202, cost = 75000, rarity = "rare",
		body = Color3.fromRGB(168, 26, 34), trim = Color3.fromRGB(72, 14, 18),
		material = Enum.Material.Neon, transparency = 0,
		-- Opaque marks on a 30%-transparent shell. Inheriting the body's own
		-- transparency would wash the trace back toward the colour it is
		-- painted on, which is the whole reason the override exists.
		pattern = {
			kind = "stripes", seed = 41,
			colour = Color3.fromRGB(255, 214, 96),
			count = 4, width = 0.10, spread = 0.60, arc = 210,
			transparency = 0,
		},
		anim = { kind = "pulse", speed = 1.6, palette = {
			Color3.fromRGB(168, 26, 34), Color3.fromRGB(226, 58, 40),
		} },
	},

	laserdream = {
		chest = "og",
		name = "Laser Grid", order = 210, cost = 220000, rarity = "rare",
		body = Color3.fromRGB(152, 24, 112), trim = Color3.fromRGB(68, 10, 52),
		material = Enum.Material.Neon, transparency = 0,
		pattern = {
			kind = "stripes", seed = 47,
			colour = Color3.fromRGB(110, 246, 255),
			count = 7, width = 0.06, spread = 0.78, arc = 195,
			transparency = 0,
		},
		anim = { kind = "cycle", speed = 0.8, glow = 1.8, palette = {
			Color3.fromRGB(152, 24, 112), Color3.fromRGB(96, 28, 168),
			Color3.fromRGB(152, 24, 112),
		} },
	},
	plasma = {
		chest = "og",
		name = "Plasma Ball", order = 211, cost = 480000, rarity = "rare",
		body = Color3.fromRGB(86, 32, 180), trim = Color3.fromRGB(36, 14, 78),
		material = Enum.Material.Neon, transparency = 0,
		pattern = {
			kind = "spots", seed = 53,
			colour = Color3.fromRGB(236, 200, 255),
			count = 17, size = 0.11, vary = 0.40,
			transparency = 0,
		},
		anim = { kind = "flicker", speed = 7, glow = 2.0, palette = {
			Color3.fromRGB(60, 20, 140), Color3.fromRGB(178, 110, 255),
		} },
	},
	vaporwave = {
		chest = "og",
		name = "Vaporwave", order = 212, cost = 850000, rarity = "rare",
		body = Color3.fromRGB(198, 44, 146), trim = Color3.fromRGB(56, 26, 110),
		material = Enum.Material.Neon, transparency = 0,
		pattern = {
			kind = "stripes", seed = 59,
			colour = Color3.fromRGB(76, 232, 236),
			count = 5, width = 0.09, spread = 0.66, arc = 200,
			transparency = 0,
		},
		anim = { kind = "cycle", speed = 0.5, glow = 1.6, palette = {
			Color3.fromRGB(198, 44, 146), Color3.fromRGB(88, 52, 208),
			Color3.fromRGB(76, 180, 226), Color3.fromRGB(198, 44, 146),
		} },
	},

	synthwave = {
		chest = "og",
		name = "Synthwave Sun", order = 220, cost = 1600000, rarity = "rare",
		body = Color3.fromRGB(214, 46, 84), trim = Color3.fromRGB(58, 20, 74),
		material = Enum.Material.Neon, transparency = 0,
		-- The one DARK trace in the bucket, and it is the reference: a
		-- synthwave sun is a bright disc with black bands cut across it, so
		-- here the pattern is the gap rather than the glow.
		pattern = {
			kind = "stripes", seed = 61,
			colour = Color3.fromRGB(28, 10, 44),
			count = 6, width = 0.12, spread = 0.62, arc = 190,
			transparency = 0,
		},
		anim = { kind = "cycle", speed = 0.6, glow = 2.4, palette = {
			Color3.fromRGB(226, 64, 110), Color3.fromRGB(240, 128, 64),
			Color3.fromRGB(250, 196, 88), Color3.fromRGB(226, 64, 110),
		} },
	},
	ultraviolet = {
		chest = "og",
		name = "Ultraviolet", order = 221, cost = 3200000, rarity = "rare",
		body = Color3.fromRGB(58, 20, 140), trim = Color3.fromRGB(24, 8, 60),
		material = Enum.Material.Neon, transparency = 0,
		pattern = {
			kind = "spots", seed = 67,
			colour = Color3.fromRGB(222, 190, 255),
			count = 21, size = 0.09, vary = 0.35,
			transparency = 0,
		},
		anim = { kind = "pulse", speed = 0.7, glow = 2.6, palette = {
			Color3.fromRGB(46, 14, 112), Color3.fromRGB(126, 64, 238),
		} },
	},
	gridrunner = {
		chest = "og",
		name = "Gridrunner", order = 222, cost = 6000000, rarity = "rare",
		body = Color3.fromRGB(14, 84, 104), trim = Color3.fromRGB(6, 36, 48),
		material = Enum.Material.Neon, transparency = 0,
		pattern = {
			kind = "stripes", seed = 71,
			colour = Color3.fromRGB(72, 255, 236),
			count = 7, width = 0.055, spread = 0.80, arc = 195,
			transparency = 0,
		},
		anim = { kind = "flicker", speed = 11, glow = 2.8, palette = {
			Color3.fromRGB(10, 60, 80), Color3.fromRGB(60, 226, 226),
		} },
	},

	hyperdrive = {
		chest = "og",
		name = "Hyperdrive", order = 230, cost = 14000000, rarity = "legendary",
		body = Color3.fromRGB(24, 58, 196), trim = Color3.fromRGB(10, 22, 86),
		material = Enum.Material.Neon, transparency = 0,
		-- Eleven hairline bands over almost the whole sphere: the read is
		-- motion streaks, which is the one thing a band pattern can say that a
		-- spot pattern cannot.
		pattern = {
			kind = "stripes", seed = 73,
			colour = Color3.fromRGB(250, 252, 255),
			count = 8, width = 0.05, spread = 0.82, arc = 185,
			transparency = 0,
		},
		anim = { kind = "flicker", speed = 16, glow = 4.2, palette = {
			Color3.fromRGB(20, 40, 150), Color3.fromRGB(196, 222, 255),
		} },
	},
	singularity = {
		chest = "og",
		name = "Singularity", order = 231, rarity = "legendary",
		-- CHEST-ONLY, like the tiger and the snow leopard. Near-black is a
		-- deliberate abuse of Neon rather than an oversight: Neon at this
		-- value barely lights at all, so the body reads as a hole and the
		-- twenty-four bright specks around it read as what is falling in.
		body = Color3.fromRGB(34, 10, 58), trim = Color3.fromRGB(8, 4, 18),
		material = Enum.Material.Neon, transparency = 0,
		pattern = {
			kind = "spots", seed = 79,
			colour = Color3.fromRGB(255, 238, 180),
			count = 30, size = 0.07, vary = 0.50,
			transparency = 0,
		},
		anim = { kind = "pulse", speed = 0.4, glow = 4.5, palette = {
			Color3.fromRGB(20, 6, 40), Color3.fromRGB(122, 52, 226),
		} },
	},

	-- ---------------------------------------------------------- PASS SKINS
	--
	-- A `pass` FIELD IS AN EXCLUSION FIRST AND A LABEL SECOND, exactly as
	-- `set` is. `Config.isEarnedElsewhere` keeps these out of the rebirth
	-- drop pool, out of every chest, and out of the free-if-costless branch
	-- that would otherwise unlock an unpriced skin for the entire server --
	-- which is a bug this catalogue has actually shipped once, on the
	-- Tractor Beam.
	--
	-- THEY CARRY A `rarity` AND NO `cost`, and both halves are load-bearing.
	-- No cost, because a Robux purchase may hand over a named item and may
	-- never mint the coins that would buy it -- printing a coin price on a
	-- pass skin is that rule broken in the one place a player reads about
	-- it. A rarity, because `Config.rarityOf` reads price when there is no
	-- explicit tier, so without one these would border as `common`.
	velvet = {
		name = "Velvet Rope", order = 70, pass = "vip", rarity = "legendary",
		-- Deep red and gold: the two colours a rope-and-stanchion actually
		-- is, and the one pairing in this catalogue nothing else uses -- the
		-- reds here are all warm pinks and the golds all sit on cream.
		-- SmoothPlastic rather than Neon on purpose: every Neon skin in the
		-- shop is bright, so the loudest thing a paid exclusive could do is
		-- be the one that is deep.
		body = Color3.fromRGB(122, 18, 38), trim = Color3.fromRGB(226, 178, 72),
		material = Enum.Material.SmoothPlastic, transparency = 0,
	},
	firstday = {
		name = "First Day", order = 71, pass = "starterPack", rarity = "rare",
		-- RARE RATHER THAN LEGENDARY, and that is the starter pack knowing
		-- its place. A pack sold to somebody in their first session must not
		-- out-rank the thing sold to somebody in their thirtieth, or the
		-- cheapest purchase in the game is also the best one and there is
		-- nothing left to want.
		body = Color3.fromRGB(96, 186, 232), trim = Color3.fromRGB(250, 246, 232),
		material = Enum.Material.SmoothPlastic, transparency = 0,
	},
}

-- ============================================================
-- THE SKIN COLLECTION -- ONE SHAPE, READ BY EVERY MENU
-- ============================================================
--
-- The shop grid, the inventory's collection log and anything else that lists
-- skins all read THIS, so "how skins are grouped" is one answer rather than
-- one per surface. That is the whole point: the grouping was about to be
-- typed out twice, and two lists of categories drift the first time a crate
-- is added -- which is the near-identical-copy fault this file records for
-- the mini piggy, `Decor.buildOne` and `RideSound`.
--
-- IT IS DERIVED RATHER THAN TYPED, and that is what stops it going stale.
-- A skin's `chest` field already says which themed pool it belongs to, so the
-- categories ARE the distinct chest tags present on skins -- add a crate and
-- tag some skins into it and a new collection appears in both menus with
-- nothing to remember here. A hand-written list would have to be updated in
-- lockstep with the catalogue, and the entry that gets missed is the one that
-- lies.
--
-- THE TIER CRATES ARE EXCLUDED BY CONSTRUCTION, WHICH IS THE HALF A TYPED
-- LIST WOULD HAVE GOT WRONG. `rarecrate` and `legendarycrate` draw ACROSS the
-- themed pools -- their own comment calls them "every skin in the coin
-- economy at rare or better" -- so they are ways to BUY a skin rather than
-- collections to complete. No skin names them in its `chest` field, so
-- walking the skins rather than the chests leaves them out without a rule.
--
-- FUNCTIONS RATHER THAN A TABLE, because this reads `Config.CHESTS`, which is
-- declared three thousand lines below. A top-level table doing that is the
-- forward reference that has taken this whole server down eleven times; a
-- function body cannot run at module load and is safe by construction.
local skinCollectionCache: any = nil

-- Ordered collections, each with the crate that fills it and its own skins in
-- catalogue order. Memoised, because both menus ask on every repaint.
function Config.skinCollections(): any
	if skinCollectionCache then
		return skinCollectionCache
	end

	local byChest: any = {}
	local loose: any = {}
	for key, spec in pairs(Config.SKINS) do
		local tag = spec.chest
		if tag ~= nil then
			byChest[tag] = byChest[tag] or {}
			table.insert(byChest[tag], key)
		else
			table.insert(loose, key)
		end
	end

	local function byOrder(a: string, b: string): boolean
		local sa, sb = Config.SKINS[a], Config.SKINS[b]
		return (sa.order or 0) < (sb.order or 0)
	end

	local out: any = {}
	for tag, keys in pairs(byChest) do
		local crate = Config.CHESTS[tag]
		table.sort(keys, byOrder)
		table.insert(out, {
			key = tag,
			-- THE CRATE'S OWN NAME, never a second one typed here. A category
			-- called anything else would be a player reading "Animals" in
			-- their collection and hunting for a crate called something they
			-- have never seen.
			name = (crate and crate.name) or tag,
			tone = crate and crate.colour,
			chest = tag,
			order = (crate and crate.order) or 999,
			skins = keys,
		})
	end
	table.sort(out, function(a: any, b: any): boolean
		return a.order < b.order
	end)

	-- EVERYTHING NO CRATE FILLS, LAST. The free starter skin, the rebirth
	-- drops, the pass skins and the set skin. They belong in a collection log
	-- -- they are skins somebody can be missing -- and they deliberately do
	-- NOT point at a crate, because no crate can hand them over. `skinSource`
	-- below is what a card shows instead.
	if #loose > 0 then
		table.sort(loose, byOrder)
		table.insert(out, {
			key = "special", name = "Special", chest = nil,
			order = 1000, skins = loose,
		})
	end

	skinCollectionCache = out
	return out
end

-- Which collection a skin sits in, or nil for a key that is not a skin.
function Config.skinCollectionOf(key: string): any
	for _, group in ipairs(Config.skinCollections()) do
		for _, k in ipairs(group.skins) do
			if k == key then
				return group
			end
		end
	end
	return nil
end

-- WHERE A SKIN YOU DO NOT OWN COMES FROM, in one short line a card can print.
--
-- Returns the sentence AND the crate key, so a caller can both SAY it and
-- ACT on it -- the inventory sends the crate key to the shop's Crates tab and
-- prints the sentence underneath. A nil crate key means there is nothing to
-- open, which is exactly the four sources a crate cannot supply.
function Config.skinSource(key: string): (string, string?)
	local spec = Config.SKINS[key]
	if not spec then
		return "", nil
	end
	if spec.unlockRebirths then
		return ("Rebirth %d"):format(spec.unlockRebirths), nil
	end
	if spec.pass then
		local pass = Config.PASSES and Config.PASSES[spec.pass]
		return ((pass and pass.name) or "Game pass"), nil
	end
	if spec.set then
		local set = Config.SETS and Config.SETS[spec.set]
		return ((set and set.name) or "Event set"), nil
	end
	if spec.chest then
		local crate = Config.CHESTS[spec.chest]
		return ((crate and crate.name) or "A crate"), spec.chest
	end
	-- The free starter skin is the only thing that reaches here.
	return "Yours already", nil
end


-- Named for what they actually look like. Roblox ships three particle
-- textures; everything here is those three recoloured and retimed, so
-- promising "hearts" or "confetti" would be writing a cheque the art
-- can't cash.
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

Config.EFFECTS = {
	none = { name = "None", order = 1, cost = 0 },
	-- Deliberately silver-lilac, rising and slow-turning.
	--
	-- The coin drip and the milestone burst are both small, fast, GOLD and
	-- falling. This effect used to be gold and falling too, on the same
	-- texture -- so a 15,000-coin cosmetic looked identical to the feedback
	-- every player already gets for free. The texture is shared (there are
	-- only three built-in ones), so the separation has to come from colour
	-- and motion: these rise, turn, and live twice as long.
	sparkle = {
		name = "Sparkles", order = 2, cost = 15000, texture = SPARK,
		color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 188, 255)),
		rate = 11, speed = NumberRange.new(1, 2.5), size = 1.4, lifetime = NumberRange.new(1.4, 2.2),
		drag = 1.5, accel = Vector3.new(0, 2.5, 0), spread = 180, rotSpeed = 140,
	},
	embers = {
		name = "Embers", order = 3, cost = 40000, texture = FIRE,
		color = ColorSequence.new(Color3.fromRGB(255, 178, 92), Color3.fromRGB(214, 72, 40)),
		rate = 14, speed = NumberRange.new(3, 7), size = 1.3, lifetime = NumberRange.new(0.9, 1.6),
		drag = 1, accel = Vector3.new(0, 7, 0), spread = 45, rotSpeed = 40,
	},
	frost = {
		name = "Frost", order = 4, cost = 90000, texture = SPARK,
		color = ColorSequence.new(Color3.fromRGB(224, 246, 255), Color3.fromRGB(140, 200, 240)),
		rate = 16, speed = NumberRange.new(1, 3), size = 1.1, lifetime = NumberRange.new(1.6, 2.6),
		drag = 2, accel = Vector3.new(0, -4, 0), spread = 180, rotSpeed = 25,
	},
	-- A "Storm Cloud" with no lightning and no light was a polite grey puff for
	-- 220,000 coins. It now boils, and the light strobes so it reads as a
	-- storm from the far end of the street rather than as fog up close.
	storm = {
		name = "Storm Cloud", order = 5, cost = 220000, texture = SMOKE,
		color = ColorSequence.new(Color3.fromRGB(168, 176, 198), Color3.fromRGB(54, 60, 82)),
		rate = 28, speed = NumberRange.new(1, 3), size = 7.0, lifetime = NumberRange.new(2.2, 3.6),
		drag = 3, accel = Vector3.new(0, 1, 0), spread = 75, rotSpeed = 12,
		light = { colour = Color3.fromRGB(170, 205, 255), brightness = 7, range = 26, kind = "strike" },
	},
	-- The most expensive thing in the shop should be the loudest. Roughly
	-- double the fire, half again the size, and a fire-coloured light that
	-- flickers, so it throws colour onto the lawn around it.
	inferno = {
		name = "Inferno", order = 6, cost = 600000, texture = FIRE,
		color = ColorSequence.new(Color3.fromRGB(255, 236, 170), Color3.fromRGB(226, 46, 30)),
		rate = 72, speed = NumberRange.new(7, 15), size = 3.6, lifetime = NumberRange.new(0.7, 1.4),
		drag = 0, accel = Vector3.new(0, 14, 0), spread = 34, rotSpeed = 90,
		light = { colour = Color3.fromRGB(255, 150, 60), brightness = 9, range = 30, kind = "flicker" },
	},

	-- ALIEN SET. Rises rather than falls -- the only effect that does -- which
	-- is the whole read: everything else in this table is thrown off the pig,
	-- and this one is lifting off it.
	tractor = {
		name = "Tractor Beam", order = 60, set = "alien", loot = 25, rarity = "epic",
		texture = SPARK,
		color = ColorSequence.new(Color3.fromRGB(214, 255, 232), Color3.fromRGB(72, 226, 160)),
		rate = 54, speed = NumberRange.new(4, 9), size = 2.4, lifetime = NumberRange.new(1.1, 1.9),
		drag = 1.5, accel = Vector3.new(0, 11, 0), spread = 14, rotSpeed = 30,
		-- Deliberately weaker than Inferno's (9 / 30). This one sits on a skin
		-- that may itself be Neon, and two bright sources on the same piggy
		-- is what turned the whole yard white on the first build.
		light = { colour = Color3.fromRGB(72, 226, 160), brightness = 2.5, range = 18, kind = "steady" },
	},

	-- -------------------------------------------------------- PASS EFFECTS
	--
	-- Same exclusion as the pass skins above, honoured by the same
	-- predicate. No `cost`, so a rarity is stated rather than derived.
	spotlight = {
		name = "Spotlight", order = 70, pass = "vip", rarity = "legendary",
		texture = SPARK,
		-- A NARROW WARM COLUMN, which is the one shape missing from this
		-- table: everything else either falls, boils or scatters over a wide
		-- cone. At spread 10 it reads as a beam standing on the pig rather
		-- than as an aura around it.
		color = ColorSequence.new(Color3.fromRGB(255, 250, 226), Color3.fromRGB(246, 206, 96)),
		rate = 40, speed = NumberRange.new(6, 11), size = 1.8, lifetime = NumberRange.new(1.2, 1.8),
		drag = 0.8, accel = Vector3.new(0, 9, 0), spread = 10, rotSpeed = 20,
		-- Warm and modest. Two bright sources on one piggy compound, and this
		-- one can sit on the Velvet Rope skin, which is deep -- so the light
		-- is what makes that skin read at all rather than something fighting
		-- it. Well under Inferno's 9 / 30 for the same reason the Tractor
		-- Beam is.
		light = { colour = Color3.fromRGB(255, 226, 158), brightness = 3.0, range = 20, kind = "steady" },
	},
	confetti = {
		name = "Confetti", order = 71, pass = "starterPack", rarity = "rare",
		texture = SPARK,
		-- Falls, turns fast, and is the only multi-hue ramp in the table --
		-- which is what says PARTY rather than says a colour. No light: the
		-- starter pack does not out-shine the thing above it.
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 226, 96)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(246, 118, 160)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 196, 246)),
		}),
		rate = 24, speed = NumberRange.new(3, 6), size = 1.1, lifetime = NumberRange.new(1.4, 2.2),
		drag = 1.2, accel = Vector3.new(0, -5, 0), spread = 120, rotSpeed = 220,
	},
}

function Config.getSkin(key: string)
	return Config.SKINS[key] or Config.SKINS[Config.DEFAULT_SKIN]
end

function Config.getEffect(key: string)
	return Config.EFFECTS[key] or Config.EFFECTS[Config.DEFAULT_EFFECT]
end

-- A SKIN'S OWN AURA: the particles a LEGENDARY throws off, which are part of
-- the skin rather than something the player equipped.
--
-- `applyEffect` has always been driven by `cosmetics.effect` alone -- the
-- player's own choice -- so a skin had no say. A legendary in the animal
-- crate is meant to be a different KIND of object from an epic rather than a
-- better picture of one, and this is the half of that which is not paint.
--
-- IT STACKS WITH THE EQUIPPED EFFECT RATHER THAN REPLACING IT. A player
-- wearing Inferno and a legendary skin gets both. That is a deliberate call
-- and the cost is stated: two emitters on one twelve-stud sphere is exactly
-- the crowding this file records for four reward cards firing at once, and
-- the rates want tuning once the pairs can be looked at.
--
-- **AN AURA CARRIES PARTICLES AND NEVER A LIGHT, AND THAT IS THE RULE THAT
-- KEEPS STACKING AFFORDABLE.** A piggy already carries TWO PointLights --
-- `Glow`, which EconomyService drives for vault fill and the skin animator
-- tints, and `AuraLight`, which the equipped effect owns. A third inside one
-- sphere is not a tuning problem, it is the entry above about a lamp at
-- brightness 2.00 rendering the animal as a featureless white blob with no
-- eyes, no snout and no legs. This file also already records that two bright
-- sources COMPOUND, which is why a set effect that may sit on a Neon skin was
-- given a weaker light than Inferno's -- written when a piggy could carry
-- one. So an aura's `light`, if anybody ever writes one, is IGNORED: the
-- glow of a legendary comes from its animated coat and its particles, and the
-- lighting stays the equipped effect's business. A Neon body is therefore no
-- worse off with an aura than without one.
--
-- It is an ORDINARY `Config.EFFECTS` KEY rather than a table of its own, so an
-- aura cannot describe a particle system the effects catalogue could not, and
-- anything learned tuning one is learned for both.
function Config.skinAura(tier: any)
	if not tier or type(tier.aura) ~= "string" then
		return nil
	end
	return Config.EFFECTS[tier.aura]
end

-- ============================================================
-- CATCH EFFECTS
-- ============================================================
--
-- THE THIRD KIND OF COSMETIC, AND THE FIRST ONE THAT LANDS ON SOMEBODY
-- ELSE.
--
-- `Config.EFFECTS` is particles on your own PIGGY and `data.gear` is
-- something worn on your own BODY. Both are seen by other people and
-- neither is a thing you DO to them. A catch effect is a one-shot burst
-- that fires on the THIEF at the moment you pull the loot back out of
-- their hands.
--
-- IT FIRES ON THEM RATHER THAN ON YOU, WHICH IS THE WHOLE DESIGN AND IS
-- ALSO WHAT MAKES IT WORTH BUYING. A cosmetic that plays on your own body
-- during your own win is a cosmetic you cannot watch -- the camera is
-- behind you and you are looking at the person you just caught. Every
-- other cosmetic here is bought to be seen BY other people; this one is
-- bought to be seen by its own owner, and the only way to do that is to
-- put it over there.
--
-- THREE RULES, AND WITHOUT ANY ONE OF THEM THIS IS A HARASSMENT SURFACE.
--
-- 1. IT MAY NEVER CHANGE AN OUTCOME. No slow, no stun, no push, no
--    collision, no query. The stun a nab applies is `STUN_SECONDS` and it
--    belongs to the NAB; this is drawn on top of a thing that already
--    happened. Same line the whole yard is built on -- every ornament is
--    `CanCollide` and `CanQuery` false precisely so a purchase cannot
--    body-block a chase -- and the trampoline's veto is the precedent for
--    what it takes when a cosmetic wants to touch a mechanic at all.
--
-- 2. IT MAY NEVER OBSCURE THE OTHER PLAYER'S VIEW. Nothing here is a
--    ScreenGui, a full-screen flash or a camera write: it is particles in
--    the WORLD at the thief's own feet, so it is loudest to everybody
--    watching and quietest to the person it is on. A burst that blinded
--    the loser would be the one purchase in this game that made somebody
--    else's screen worse, which is exactly what an under-12 audience must
--    never be sold.
--
-- 3. IT EXPIRES WITH `Config.STUN_SECONDS`. The nab holds the thief still
--    for that long and then gives them their legs back; an effect that
--    outlived it would be a mark following somebody who is already
--    running again, which reads as a tag rather than as a flourish.
--    DERIVED rather than pinned, so retuning the stun carries the effect
--    with it -- the same call the arrest scene makes about its own length.
--
-- COINS BUY THESE, AND THAT IS NOT A CONCESSION. Coins are not purchasable
-- with Robux at any price, so a coin route keeps this catalogue outside the
-- paid-random-item rule entirely and keeps the spirit of
-- nothing-locked-behind-money. What a pass may later add is MORE of them,
-- never the only ones.
--
-- THE PRICE SPREAD IS AUTHORED DELIBERATELY, BECAUSE A MISSING SPREAD IS
-- THE EXACT REASON THE EFFECTS TAB STILL HAS A BUY BUTTON. Measured there:
-- five buyable effects at 15K / 40K / 90K / 220K / 600K against
-- `RARITY_BANDS` is three commons and two rares -- no epic, no legendary,
-- and the top end is the entire reason a crate is ever opened. These five
-- span all four tiers by construction (60K / 250K / 1.2M / 3M / 12M), so a
-- catch-effect chest is a row in `Config.CHESTS` whenever one is wanted
-- rather than a re-pricing exercise first.
--
-- THE SHAPE IS `Config.EFFECTS`' SHAPE ON PURPOSE. Same texture, colour,
-- speed, lifetime, spread, accel and rotSpeed fields, so the shop's
-- particle simulation renders one of these with no second implementation --
-- the near-identical copy this file keeps recording as the thing that
-- drifts. What is added is `burst`, because an aura is a RATE and this is a
-- COUNT: an emitter that runs forever against one that goes off once.
Config.DEFAULT_CATCH = "none"

-- The attribute pair the server writes on a thief's character and every
-- client renders from. A COUNTER as well as a key, for the reason
-- `DodgeRoll` is a counter rather than a flag: an attribute set twice
-- fires one changed signal, so nabbing the same person twice in a session
-- would animate once.
Config.CATCH_ATTRIBUTE = "CatchFX"
Config.CATCH_COUNT_ATTRIBUTE = "CatchFXCount"

Config.CATCH_EFFECTS = {
	-- Everybody owns this and it is not nothing: a nab still has its own
	-- sound, its own toast and the loot visibly leaving. None is the
	-- unadorned version of an event that already happens.
	none = { name = "None", order = 1, cost = 0 },

	-- COMMON. Brown-grey, heavy, falling -- the cheapest thing that can
	-- happen to somebody, and the only one in the set with no colour in it.
	dust = {
		name = "Dust Cloud", order = 2, cost = 60000, texture = SMOKE,
		color = ColorSequence.new(Color3.fromRGB(206, 190, 168), Color3.fromRGB(122, 106, 88)),
		rate = 20, burst = 26, speed = NumberRange.new(3, 7), size = 4.2,
		lifetime = NumberRange.new(0.5, 1.0), drag = 3.5, accel = Vector3.new(0, -6, 0),
		spread = 180, rotSpeed = 24,
	},

	-- RARE. The loot coming back out of them, which is literally what a nab
	-- IS -- so this is the one in the set that describes the mechanic rather
	-- than decorating it. Gold, thrown up, falling under its own gravity.
	coins = {
		name = "Coin Shower", order = 3, cost = 250000, texture = SPARK,
		color = ColorSequence.new(Color3.fromRGB(255, 238, 168), Color3.fromRGB(226, 168, 44)),
		rate = 34, burst = 34, speed = NumberRange.new(8, 15), size = 1.5,
		lifetime = NumberRange.new(0.8, 1.4), drag = 0.6, accel = Vector3.new(0, -22, 0),
		spread = 55, rotSpeed = 120,
	},

	-- EPIC. Slow, round and pink, drifting UP -- the one in the set that is
	-- gentle, which is the joke: the loudest thing you can do to somebody is
	-- not always the funniest.
	bubbles = {
		name = "Bubble Trouble", order = 4, cost = 1200000, texture = SPARK,
		color = ColorSequence.new(Color3.fromRGB(255, 236, 248), Color3.fromRGB(246, 152, 206)),
		rate = 22, burst = 24, speed = NumberRange.new(2, 5), size = 2.6,
		lifetime = NumberRange.new(1.4, 2.2), drag = 1.6, accel = Vector3.new(0, 4, 0),
		spread = 180, rotSpeed = 18,
	},

	-- EPIC. The patrol's own blue, in the hands of somebody who is not the
	-- patrol. It carries a light, and the light is BLUE alone rather than
	-- the red-and-blue pair a real one would use: two saturated hues at this
	-- brightness read as one white smear, which is the palace colonnade's
	-- own lesson arriving on a particle.
	sirens = {
		name = "Blue Lights", order = 5, cost = 3000000, texture = SPARK,
		color = ColorSequence.new(Color3.fromRGB(214, 236, 255), Color3.fromRGB(56, 118, 246)),
		rate = 46, burst = 40, speed = NumberRange.new(6, 13), size = 2.0,
		lifetime = NumberRange.new(0.7, 1.3), drag = 1.0, accel = Vector3.new(0, 3, 0),
		spread = 90, rotSpeed = 60,
		light = { colour = Color3.fromRGB(96, 150, 255), brightness = 6, range = 22 },
	},

	-- LEGENDARY, and the top of a catalogue should be the loudest thing in
	-- it. A white-hot upward blast with a light on it. Deliberately the only
	-- entry over ten million, so this ladder has a real legendary rather
	-- than a dear epic -- which is the half `Config.EFFECTS` never had.
	thunder = {
		name = "Thunderclap", order = 6, cost = 12000000, texture = FIRE,
		color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 176, 255)),
		rate = 80, burst = 60, speed = NumberRange.new(12, 24), size = 3.0,
		lifetime = NumberRange.new(0.5, 1.1), drag = 0.4, accel = Vector3.new(0, 10, 0),
		spread = 40, rotSpeed = 150,
		light = { colour = Color3.fromRGB(190, 220, 255), brightness = 9, range = 28 },
	},

	-- ------------------------------------------------------- PASS EXCLUSIVE
	--
	-- FLASHBULBS, AND IT IS THE ONE THAT WRITES ITSELF. This game already
	-- opens its arrest scene with a camera flash and a mugshot card, so a
	-- press pack going off on somebody you have just caught is a picture
	-- the street has already been taught to read -- and it is the only
	-- entry here that is about the CATCHER rather than about the loot.
	--
	-- Short, white and hard: real flashes are over before you have turned
	-- round. 0.35 at the top of the range against the catalogue's next
	-- shortest at 0.5, which is what makes it read as pops rather than as
	-- a cloud.
	paparazzi = {
		name = "Paparazzi", order = 70, pass = "vip", rarity = "legendary",
		texture = SPARK,
		color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 226, 255)),
		rate = 60, burst = 30, speed = NumberRange.new(1, 4), size = 3.4,
		lifetime = NumberRange.new(0.18, 0.35), drag = 4.0, accel = Vector3.new(0, 2, 0),
		spread = 180, rotSpeed = 0,
		-- A single hard white pop. It is the shortest light in the game by a
		-- distance -- see LIGHT_SECONDS in CatchFX, which fades every one of
		-- these over 0.55 -- and that is the whole read.
		light = { colour = Color3.fromRGB(255, 255, 255), brightness = 10, range = 24 },
	},
}

function Config.getCatchEffect(key: string)
	return Config.CATCH_EFFECTS[key] or Config.CATCH_EFFECTS[Config.DEFAULT_CATCH]
end

-- A skin is available if it's free, already bought, or earned by rebirths.
-- ============================================================
-- REBIRTH DROPS
-- ============================================================
--
-- Every rebirth grants exactly one animated skin. The roll decides HOW RARE,
-- never WHETHER -- rebirth already costs a player every upgrade they own, and
-- handing back nothing for that is the fastest way to make people stop doing
-- it. There is no outcome where you get nothing.
--
-- Odds climb with rebirth count but a legendary is reachable on the very first
-- one, at about 3%. That matters: a ladder where the good stuff is gated behind
-- rebirth 20 tells a new player the chase is not for them yet.
--
-- Weights, not probabilities -- they are normalised at roll time, so tuning one
-- line cannot silently break the total.
function Config.getDropWeights(rebirths: number): { [string]: number }
	local r = math.clamp(rebirths, 0, 40)
	return {
		rare = math.max(10, 80 - r * 2.0),
		epic = 18 + r * 1.2,
		legendary = 2 + r * 0.8,
	}
end

-- Rebirths in a row without a legendary before one is guaranteed.
--
-- Pure chance has no floor: a player can be unlucky twelve times running and
-- reasonably conclude the drop is a lie. This caps the worst case at a number
-- somebody can actually see coming.
Config.LEGENDARY_PITY = 12

Config.DROP_RARITIES = { "rare", "epic", "legendary" }

Config.RARITY_COLOURS = {
	rare = Color3.fromRGB(96, 170, 240),
	epic = Color3.fromRGB(176, 110, 236),
	legendary = Color3.fromRGB(248, 190, 72),
}

-- Every skin of a given rarity. Rebuilt per call rather than cached: the pool
-- is tiny and a stale cache after a Config edit is a worse problem than the
-- handful of table allocations this costs.
-- The REBIRTH DROP POOL, and its only caller is CosmeticsService.
--
-- A SET SKIN IS NEVER A DROP, AND NEITHER IS A PASS SKIN. Both carry a
-- rarity like everything else, because the shop borders every card with
-- one -- but rarity is also what puts a skin in this pool, so the Martian
-- would have started falling out of rebirths for players who had never
-- seen an invasion, and a VIP skin would fall out of them for players who
-- never bought the pass. `Config.isEarnedElsewhere` is the exclusion, and
-- this is one of the places it has to be honoured.
function Config.getSkinsOfRarity(rarity: string): { string }
	local out = {}
	for key, skin in pairs(Config.SKINS) do
		if skin.rarity == rarity and not Config.isEarnedElsewhere(skin) then
			table.insert(out, key)
		end
	end
	table.sort(out)
	return out
end

-- Picks a rarity for one rebirth. `rng` is passed in so the caller owns the
-- seed and the whole thing stays testable.
function Config.rollRarity(rebirths: number, sinceLegendary: number, rng: Random): string
	if sinceLegendary >= Config.LEGENDARY_PITY then
		return "legendary"
	end

	local weights = Config.getDropWeights(rebirths)
	local total = 0
	for _, rarity in ipairs(Config.DROP_RARITIES) do
		total += weights[rarity]
	end

	local roll = rng:NextNumber() * total
	for _, rarity in ipairs(Config.DROP_RARITIES) do
		roll -= weights[rarity]
		if roll <= 0 then
			return rarity
		end
	end
	return "rare"
end

-- ONE QUESTION ASKED IN TEN PLACES: DOES THIS ITEM HAVE A SOURCE THAT IS
-- NOT THE COIN SHOP?
--
-- It was written out longhand as `not spec.set` at every one of those
-- sites, which was correct while `set` was the only other source. A Robux
-- pass is the second, and adding `and not spec.pass` ten times is exactly
-- the shape of change this file has a post-mortem about: the raw
-- `"LockLevel"` string had four readers where it looked like two, and
-- converting some of them would have been WORSE than converting none --
-- a missed site does not error, it reads nil and falls through to the
-- wrong branch, silently, forever.
--
-- TWO DIFFERENT QUESTIONS RESOLVE TO THIS ONE PREDICATE, and it is worth
-- being exact about both because they fail in opposite directions:
--
--   MAY IT COME OUT OF A RANDOM POOL? The rebirth drop, the accessory
--   roll and the chest pools. A pass skin falling out of a rebirth would
--   hand a paid exclusive to somebody who never paid.
--
--   IS IT FREE BECAUSE IT HAS NO PRICE? Everything earned elsewhere is
--   unpriced in coins, and `(nil or 0) <= 0` is TRUE -- which is the hole
--   that once unlocked the Tractor Beam for every player in the server
--   from their first second. A pass item is unpriced for the same reason
--   and would go the same way.
--
-- AND THE THIRD SOURCE WAS EXACTLY ONE LINE, WHICH IS THIS FUNCTION
-- BEING PAID FOR. A trophy is EARNED -- by robbing, by stopping a thief,
-- by outrunning a patrol -- so it is unpriced in coins like everything
-- else here, and both halves above apply to it unchanged: a Victim Shelf
-- falling out of a crate would hand over a record of robberies nobody
-- committed, and `(nil or 0) <= 0` would have made all four free.
--
-- SO THE NEXT SOURCE IS ONE LINE HERE RATHER THAN TEN SITES. That is the
-- whole argument for the function existing.
function Config.isEarnedElsewhere(spec: any): boolean
	return spec ~= nil and (spec.set ~= nil or spec.pass ~= nil or spec.trophy ~= nil)
end
function Config.isSkinUnlocked(key: string, owned: { [string]: boolean }, rebirths: number): boolean
	local skin = Config.SKINS[key]
	if not skin then
		return false
	end
	if skin.unlockRebirths then
		return rebirths >= skin.unlockRebirths
	end
	-- A drop-pool skin has no cost, but "no cost" must not read as "free".
	-- Without this, every legendary would be unlocked for everyone from the
	-- first second, because the fallback below treats cost 0 as unlocked.
	--
	-- `isEarnedElsewhere` is here for the same reason and stated separately
	-- rather than leaning on `rarity`: a set skin is priced in LOOT and a
	-- pass skin is priced in Robux, so neither has a `cost`, and either one
	-- authored without a rarity would fall straight through to the free
	-- branch below.
	if skin.rarity or Config.isEarnedElsewhere(skin) then
		return owned[key] == true
	end
	return (skin.cost or 0) <= 0 or owned[key] == true
end

-- ============================================================
-- PLOTS
-- ============================================================

-- Two rows facing each other across a street, not a solid block.
--
-- The block was quietly unfair: in a 4x3 grid the two interior plots had four
-- adjacent neighbours and the corners had two, so how often you got robbed
-- was decided by what time you happened to log in. Facing rows give every
-- plot the same exposure -- two beside, one across -- and put a full piggy
-- permanently in your eyeline, which is the read the whole game runs on.
-- FIVE A SIDE AGAINST EIGHT PLAYERS, SO TWO HOUSES CAN NEVER BE MOVED INTO.
--
-- THIS IS THE SUPPLY FLOOR, AND IT IS THE HALF `SHOPS` COULD NOT BUY.
-- Residents are seated on UNCLAIMED plots, so the number of robbable NPC
-- houses is `PLOT_COUNT - players online` and reaches zero the moment the
-- cap and the plot count are equal -- see MAX_PLAYERS for the measurement
-- that forced the shops, and RESIDENT_FLOOR for what is left standing. The
-- shops fixed the CLIFF; they did not stop the whole non-player supply of
-- this economy being four pigs on a busy street, which is the open risk
-- `docs/MASTER-PLAN.md` Part III D4 records as *eight thieves working four
-- shops will drain them*.
--
-- One column a side puts two permanent resident houses behind those four
-- shops at EVERY population, and it costs no players. That is the trade this
-- design has always preferred: the entry under MAX_PLAYERS records at length
-- that capping the server to buy supply spends the one resource a busy street
-- is made of.
--
-- IT IS TWO CONSTANTS BECAUSE THE DERIVATION WAS ALREADY WRITTEN FOR IT.
-- `RESIDENT_FLOOR` is `SHOP_COUNT + math.max(0, PLOT_COUNT -
-- MAX_PLAYERS)` and `auditRobbery` sweeps population off the same pair, so
-- that second term has been sitting at zero waiting for this rather than
-- needing to be invented.
--
-- AND AN ODD COUNT IS FINE, WHICH A STALE RULE SAID IT WAS NOT. This file
-- used to state that the count "has to be EVEN, because that is what gives
-- the slot grid a true middle to leave empty" -- and that middle gap was
-- removed the day the town square moved onto the verge (*A ROW IS CONTINUOUS,
-- AND THE HOLE IN THE MIDDLE OF IT LASTED ONE PASS*). Verified rather than
-- trusted: `plotColumnX` centres on `(PLOTS_PER_ROW - 1) / 2`, so five
-- columns simply put one at x 0, and every other reader -- `plotCFrame`'s
-- row/column split, `streetMetrics.endX`, the street-tree veto's own
-- `perRow - 1` and `perRow - 2` loops -- is derived from the same number.
--
-- WHAT IT COSTS IS THE WALK, AND THAT IS A DECISION MADE ONCE ALREADY IN THE
-- OTHER DIRECTION. The history below is kept because it is the argument this
-- reopens: the map was cut from six a side to four because the corner-to-
-- corner walk was twenty-one seconds, and `PLOT_SPACING` has grown 64 -> 80
-- since, so a column is dearer now than it was then. The row span goes 240 to
-- 320 studs. One column back is a small version of a cut that was made for
-- good reasons, and the thing to watch is whether the street reads as long
-- again rather than whether the audit passes.
--
-- It was six a side and twelve, and the map that made was too big for what
-- happens on it. Measured before the cut: the far corner of one row to the
-- far corner of the other was 336 studs -- TWENTY-ONE SECONDS of holding W --
-- to buy a getaway that is 27 studs and lasts two. A ten-to-one ratio of
-- travel to game.
--
-- The other half is the lobby. A twelve-cap server sitting at six players
-- reads as abandoned; an eight-cap at six reads as busy, and it fills in half
-- the time. Note what this does NOT fix: part count was never the problem.
-- The whole world measured 1,891 BaseParts with 22 animated per frame, which
-- is nothing -- what eight players saves is eight characters and eight dogs
-- of replication, not geometry.
--
-- What it COSTS is rides. The walk between plots is what a ride is sold
-- against, and halving the street halves that. Four a side rather than three
-- is where that argument stopped.
Config.PLOTS_PER_ROW = 5

-- DERIVED, AND IT HAS TO BE. These were two independent constants, and
-- `plotCFrame` puts row 0 at -z and EVERYTHING ELSE at +z -- so setting the
-- per-row count without the total would have built plots 9..12 silently on
-- top of 5..8, in the same place, with nothing in the log to say so.
Config.PLOT_COUNT = Config.PLOTS_PER_ROW * 2

-- A VAULT IN EVERY SHOP, AND IT IS THE SUPPLY FLOOR THIS ECONOMY NEVER HAD.
-- See `MAX_PLAYERS` for the measurement that forced it: resident houses are
-- seated on UNCLAIMED plots, so the one thing every robbery figure in this
-- game is measured against runs out exactly as the server fills up, and PvP
-- cannot take over because `LOSS_CAP` caps the whole street's theft budget
-- however many people are standing on it.
--
-- AND IT IS NO LONGER A PIGGY BANK, WHICH IS A RULE THIS PROJECT SPENT ON
-- PURPOSE RATHER THAN FORGOT.
--
-- What stood here was a twelve-stud pig on a paving apron, and the entry
-- justifying it said in as many words that a shop target was allowed ONLY
-- because nothing new had been invented to rob: the same hatch, the same
-- crack, the same coin pile, the same rob badge. That was true and the
-- picture it bought was wrong -- a shop with its own piggy bank standing
-- outside it reads as a game object parked on a pavement rather than as a
-- place, and four of them read as it four times.
--
-- So the noun is spent. There are two kinds of thing to rob in this game
-- now: a piggy bank on a lawn, and a vault in a shop. What is bought is that
-- the shops stop being furniture with a target bolted to the front; what is
-- spent is the one-noun rule, and it may not be spent a third time without
-- an argument at least this long.
--
-- WHAT IT DID NOT SPEND IS THE PLOT, WHICH IS WHY IT COST SO LITTLE.
-- `plot.shop` is still the whole implementation and `PlotService.assign`
-- still skips anything carrying one, so `ResidentService` seats a shopkeeper
-- at boot and is never asked to evict them. Everything a robbery touches is
-- keyed off a plot: the steal prompt, the rob badge, the published pile, the
-- lock attribute, the per-victim cooldown id, casing, the crack, the
-- drop-off and the rap sheet. THIS CHANGE MOVED GEOMETRY, NOT A TARGET TYPE.
--
-- WHAT A SHOP DELIBERATELY DOES NOT HAVE IS A DOG OR A FENCE, and that is
-- what pays for the short run home. The vault stands on the back wall of the
-- unit, which is the side facing the HOUSES -- so going inside moves the
-- target CLOSER to every drop-off on the street rather than further from it
-- (see `shopVaultRunStuds`, where that reversed a plan written the other way
-- round). A shop is the FAST, CHEAP, LOUD target -- nothing to get past, a
-- smaller pig, and an alarm that brings the patrol rather than a defender --
-- and a house stays the slow, rich, quiet one. That is variety INSIDE the
-- loop, which is the one thing nothing else was solving.
--
-- THE PLACEMENT LIVES HERE AND NOWHERE ELSE, and it did not used to.
-- `NeighborhoodService` carried its own `gap`, `side` and `name` for each of
-- the four units while this table carried the same three for each till --
-- two copies of one arrangement, which cost nothing for as long as the pig
-- stood on the forecourt and could be a stud out without anybody noticing.
-- It cannot now: the vault stands INSIDE the unit, so a table that disagreed
-- by one gap would put a robbable vault in an empty patch of verge and leave
-- the shop next door with nothing in it. Style, colour and window display
-- stay over there, keyed by `tab`; where a unit STANDS is decided here.
Config.SHOPS = {
	{ tab = "piggy", gap = 0, side = 1, name = "PIGGY OUTFITTERS" },
	{ tab = "home", gap = 2, side = 1, name = "HOME & GARDEN" },
	{ tab = "gear", gap = 0, side = -1, name = "WHEELS & KIT" },
	{ tab = "defend", gap = 2, side = -1, name = "LOCK & KEY" },
}

Config.SHOP_COUNT = #Config.SHOPS

-- THE SHELL, AND THE ROOM INSIDE IT, live further down beside
-- `Config.PLOT_SIZE` -- see `Config.SHOP_UNIT`. They belong HERE, and they
-- cannot be here: the interior floor is a plot slab, so `floorY` is derived
-- from that constant, and a Config field that forward-references another
-- Config field throws while this module is still loading rather than limping
-- the way a nil global does. Eleventh forward reference in this project and
-- the second on a table field.

-- HOW MUCH LESS A SHOP PAYS PER SECOND THAN A HOUSE DOES, and it is the one
-- number here that is a judgement rather than a derivation. Everything else
-- about a vault's pig falls out of it -- see `Config.shopVaultPigSeconds`.
--
-- IT IS LITERALLY THE COINS-PER-SECOND RATIO, which is worth stating because
-- it makes the dial legible. A haul is a share of the pig and the pig is
-- `pigSeconds` of income, so a target's coins per second is
-- `pigSeconds / cycle` -- and `shopVaultPigSeconds` is defined as a house's
-- scaled by the ratio of the two cycles TIMES this. The cycles cancel. A
-- shop pays exactly this fraction of what a house pays, at every level and
-- every rebirth.
--
-- IT WAS 0.85 AND THE RISK ARGUMENT ALWAYS WANTED LESS. A shop has no dog to
-- get past and the carry home is 1.91 seconds against a house's 4.42, so a
-- thief is exposed for 43% as long on the leg that matters and it should pay
-- about that share. The old entry recorded that the economy could not afford it: at a
-- FULL server the shops were the entire non-player supply, so their rate WAS
-- the floor, and `ROBBERY_ADVANTAGE.min` of 3.0x bottomed out at a discount
-- of about 0.73.
--
-- THAT CONSTRAINT WAS LOOSENED BY SOMETHING ELSE ENTIRELY, WHICH IS THE
-- INTERESTING HALF. `PLOTS_PER_ROW` went 4 -> 5, so a full server now has
-- TWO permanent resident houses behind the four shops rather than none --
-- and those two carry the floor while the shops are free to be worth less.
-- Measured at eight players (2 houses + 4 shops), cold: 0.85 gives 3.74x,
-- 0.70 gives 3.36x, 0.65 gives 3.23x and 0.60 gives 3.11x against a floor of
-- 3.0. So the premium risk actually asks for is affordable now, and it was
-- bought by a column of plots rather than by this dial.
--
-- 0.70 rather than the 0.60 the audit would still pass, because the skew
-- check refuses anything under 0.60 outright and sitting on a floor is not a
-- margin. It lands at 3.36x with 12% of headroom.
Config.SHOP_VAULT_DISCOUNT = 0.70

-- The seconds of its own income a shop vault holds, against
-- `RESIDENTS.pigSeconds` for a house.
--
-- DERIVED FROM THE TWO CYCLES RATHER THAN PINNED, and the first version of
-- this was pinned and was wrong by 62%. It was set to 110 on the reasoning
-- that the run home is about half a house's, so the pig should be about half
-- -- and a cycle is not a run. `CRACK.openHold` plus five sweeps of the dial
-- is most of a robbery and does not care how far anybody walked, so a pig
-- priced off the run made a target strictly worse than the one beside it,
-- which nobody would ever choose. `auditRobbery` caught it on the first boot
-- after it was written.
function Config.shopVaultPigSeconds(): number
	local houseCycle = Config.robberyCycleSeconds(Config.CRACK.maxSteps)
	local shopCycle = Config.robberyCycleSeconds(Config.CRACK.maxSteps, Config.shopVaultRunStuds())
	return Config.RESIDENTS.pigSeconds * (shopCycle / houseCycle) * Config.SHOP_VAULT_DISCOUNT
end

-- The centre of a driveway gap, which is where a shop stands.
-- `NeighborhoodService` has its own local doing exactly this; both read
-- `plotColumnX`, so they cannot drift, and this exists so `Config` can answer
-- the question without requiring anything.
function Config.shopGapX(gap: number): number
	return (Config.plotColumnX(gap) + Config.plotColumnX(gap + 1)) / 2
end

-- WHERE A SHOP UNIT STANDS, and therefore where its plot does.
--
-- The unit and the plot inside it share one frame to the stud: the plot
-- origin is the room's own centre, so `buildShopPlot` authors the floor, the
-- vault and the shopkeeper in exactly the coordinates `ShopFront` builds the
-- walls in. Two frames would be two chances to put a vault through a wall,
-- and the wall does not collide, so nothing would ever have said so.
--
-- The one conversion to remember: this frame's y is the PLOT's, half a slab
-- above the pavement `ShopFront` measures its own bands from.
function Config.shopUnitCFrame(spec: { gap: number, side: number }): CFrame
	local m = Config.streetMetrics()
	-- Authored facing +Z like everything else here, so the far verge turns a
	-- half circle to look back across the road and the near one takes none.
	local yaw = if spec.side > 0 then math.pi else 0
	return CFrame.new(Config.shopGapX(spec.gap), 0, spec.side * m.shopZ)
		* CFrame.Angles(0, yaw, 0)
end

-- IS SOMEBODY ACTUALLY IN THE SHOP, and it is what makes "robbed by going
-- inside" true rather than decorative.
--
-- A ProximityPrompt measures to a PART'S CENTRE, so a vault standing on a
-- back wall 0.8 studs thick is two studs from the grass behind the building
-- -- and there is no activation distance that admits a twelve-stud room and
-- excludes a strip right behind its rear wall. Line of sight is not the
-- escape it looks like either: the check runs from the CAMERA, and a
-- third-person camera sits ten studs behind a player who has just stepped
-- inside, so it would refuse the one player standing exactly where they are
-- meant to be.
--
-- So the ROOM is the range. A rectangle in the unit's own frame, tested
-- against where the thief is standing, checked at the moment an attempt
-- opens and polled for as long as it runs -- the same shape as the crack's
-- own range binding, which already ends an attempt when somebody walks away.
--
-- THE REFUSAL IS NAMED, not silent. A prompt that offers an action the
-- server will refuse is the silent-failure rule wearing a button, and this
-- one has an answer a nine-year-old can act on: go in.
--
-- The slack is a stud and a half so the threshold counts. The doorway sits
-- at the room's own front edge, and a rule that refused somebody standing in
-- the door would read as the shop being shut.
Config.SHOP_ROOM_SLACK = 1.5

-- WHAT HOLDS A PLOT'S MONEY, WHICHEVER OF THE TWO IT IS, and it exists
-- because the CLIENT finds that object by NAME.
--
-- The server never had this problem: `plot.piggy` is one field and
-- `PiggyBank.buildVault` returns the same `Refs` a piggy does, so fourteen
-- readers there never learned there were two kinds. The client has no plot
-- record at all -- it is handed a Model out of `workspace.Plots` and has to
-- go looking -- and it was looking for `PiggyBank` and `Body` by name in
-- THREE places: the steal prompt, the rob badge and the skin animator.
--
-- MEASURED, AND IT SHIPPED BROKEN FOR EXACTLY ONE PLAY SESSION. A shop's
-- money is a `ShopVault`, so `bindPlot` waited ten seconds for a child that
-- was never coming and returned: the steal prompt on all four shop vaults
-- stayed `Enabled = false` forever, which is a target nobody can rob and
-- nothing anywhere to say so. That is the `"LockLevel"` lesson from the
-- other end -- an interface with no compiler behind it, found by pressing
-- the thing rather than by reading it.
--
-- So the two names live HERE and nowhere else, and the part inside is `Body`
-- on both so no caller ever has to know a second one. The skin animator is
-- deliberately NOT a caller: it wants the pig specifically, because a vault
-- has no skin to cycle.
--
-- It WAITS, because a plot's children replicate after the plot does and a
-- caller polling on its own would be a fourth copy of this.
Config.PLOT_BANK_NAMES = { "PiggyBank", "ShopVault" }

function Config.waitForPlotBank(plotModel: Instance, timeout: number): Instance?
	local deadline = os.clock() + timeout
	while true do
		for _, name in ipairs(Config.PLOT_BANK_NAMES) do
			local found = plotModel:FindFirstChild(name)
			if found then
				return found
			end
		end
		if os.clock() >= deadline then
			return nil
		end
		task.wait(0.1)
	end
end

function Config.shopRoomHolds(unitCF: CFrame, position: Vector3): boolean
	local u = Config.SHOP_UNIT
	local inside = unitCF:PointToObjectSpace(position)
	return math.abs(inside.X) <= u.roomWidth / 2 + Config.SHOP_ROOM_SLACK
		and math.abs(inside.Z) <= u.roomDepth / 2 + Config.SHOP_ROOM_SLACK
end

-- WHAT A CLEAN CRACK ON A SHOP VAULT HANDS OVER BESIDES COINS.
--
-- PER COMPLETED RUN, never per slice and never per attempt. The crack is a
-- greed dial and its whole shape is that staying in is a decision; a drop
-- per slice would pay for bailing out, which is the one thing it must not
-- reward.
--
-- NO LEGAL QUESTION, and it is worth writing down that there is not one.
-- Coins are not purchasable with Robux at any price, so this is an ordinary
-- in-game reward for in-game effort exactly like a chest: no odds
-- disclosure, no `PolicyService` gate, no regional lockouts. That is the
-- rule under "COINS ARE NOT PURCHASABLE" doing its work.
-- THE SHOPKEEPER, WHO IS THE SHOP'S GUARD DOG.
--
-- `applyLevel`'s `plot.shop` branch ladders ONLY the Vault Lock -- no fence,
-- no dog, no house -- so a shop has ONE defence where a house has four. That
-- is deliberate and it is what makes a shop the fast, cheap, loud target. It
-- also left the figure behind the counter watching a robbery and doing
-- nothing, which `docs/MASTER-PLAN.md` Part III D2 calls worse than not being there
-- at all.
--
-- THIS IS NOT A FOURTH DEFENCE, IT IS THE SECOND ONE. `releaseDog` already
-- returns early on a plot whose dog is tier 0, and every shop's is -- so the
-- shopkeeper is simply what that function does when there is no dog to let
-- off. One branch, and it inherits every call site the dog already has.
--
-- WHAT WAKES THEM IS EXACTLY WHAT WAKES A DOG, AND THAT IS WHAT KEEPS THE
-- ECONOMY AUDIT HONEST. `auditRobbery` models an UPPER BOUND on optimal play
-- -- no dog, no missed slice, no tag, no patrol -- so it is structurally
-- incapable of seeing a defender. That means a shopkeeper who reacted to a
-- CLEAN crack would quietly change what a shop is worth with no audited
-- number moving and nothing in any log, on the four targets that carry the
-- supply floor at a full server (measured 3.37x against a floor of 3.0, which
-- is 12% of headroom to spend).
--
-- So they react to a FUMBLED SLICE and to a SMASH, and to nothing else. Both
-- are already the loud paths; a clean crack stays silent, which preserves the
-- crack's whole skill reward -- the alarm is fumble-only, and stealth of the
-- alarm is the thing a good thief is actually buying. The audit assumes no
-- misses, so a defender that only answers a miss cannot move the bound it
-- prints. It is blind to this CORRECTLY rather than accidentally.
--
-- THE FOOTSTEP PATH EXCLUDES ITSELF, which is worth knowing before anybody
-- "fixes" it. `watchLawns` only calls `releaseDog` behind
-- `GuardDog.isWatching`, and that tests `level > 0` -- so walking into a shop
-- can never start a chase, which it must not, because walking in is how you
-- reach the vault.
Config.SHOPKEEPER = {
	-- THE OFFICER'S OWN NUMBER, AND THE REUSE IS THE POINT. 14.5 sits between
	-- a carrying thief's 12 and a free player's 16, so holding the loot means
	-- losing ground and DELIVERING is the answer -- the counter is a decision
	-- the player already knows how to make. A shopkeeper who could outrun an
	-- empty-handed thief would be a wall rather than a cost, and nothing in
	-- this game may exceed `BASE_WALK_SPEED`.
	speed = 14.5,
	-- 4.5, AND THE TERRIER'S 7 WAS MEASURED TO BE WRONG HERE RATHER THAN
	-- REASONED ABOUT.
	--
	-- A dog's radius is sized against a LAWN, which is 64 studs across. A
	-- shop room is twelve. Measured live with the shopkeeper at its counter
	-- and a thief standing where the smash prompt can actually be reached:
	-- **6.83 studs apart**, which is inside a radius of 7 -- so the catch
	-- fired on the first tick of the chase, the shopkeeper never took a step
	-- (peak distance from the counter 0.00 across a seventeen-second sample),
	-- and robbing a shop became an unavoidable instant arrest. Not a tuning
	-- slip: a radius that covers most of the room makes the room the catch.
	catchRadius = 4.5,
	-- THE BEAT BEFORE THEY MOVE, AND IT IS THE DOG'S OWN NUMBER FOR THE DOG'S
	-- OWN REASON.
	--
	-- `DOG_WATCH.wakeDelay` is 1.2 and its comment is the whole argument:
	-- the gap between being disturbed and being come for is what makes a
	-- crack a DECISION -- you hear it stir and choose whether to finish or
	-- bail -- rather than a coin flip you find out the result of. A
	-- shopkeeper without one is strictly worse than a dog: instant,
	-- unavoidable, and with no tell to read.
	--
	-- It gates the CATCH as well as the walk, which is the half that matters
	-- in a room this size. Gating only the walk would still let a shopkeeper
	-- standing inside the radius take somebody on the first tick.
	wakeDelay = 1.2,
	-- Seconds before they give up and walk back. The Terrier's `maxChase` is
	-- 12 and this matches it, so the cheapest dog in the game and the
	-- shopkeeper cost a thief the same amount of time.
	maxChase = 12,
	-- And a hard leash in studs, because a shop stands on the VERGE and the
	-- street is 350 studs long: a chase with only a clock on it ends with a
	-- shopkeeper stranded outside somebody's house at the far end. Measured
	-- against the run home the whole economy is priced on -- a shop's carry
	-- is 23.0 studs -- so this covers the getaway and stops well short of the
	-- next plot column.
	giveUp = 60,
}

Config.SHOP_VAULT_DROP = {
	chance = 0.20,
	-- What each unit hands over, by the tab its own door opens. A shop drops
	-- what it sells.
	--
	-- THE LAST ROW IS THE REASON THIS FEATURE IS WORTH MORE THAN IT LOOKS.
	-- The `defend` tab sells upgrade LEVELS, which are not items and cannot
	-- drop -- so that shop has to hand over something else, and consumables
	-- are the honest answer. They are also the exact thing a new player
	-- cannot buy: a Titan hears anything that moves, a maxed sneak clears
	-- nothing, and the only bone that breaks a chase in progress costs
	-- 30,000 coins. The counter to the wall is priced above the players the
	-- wall stops, and a cheap easy target that can drop one is the on-ramp.
	kinds = {
		-- `accessory` is gone with the catalogue. An empty section is a header
		-- over an empty grid, which the parked cars' retirement records as
		-- reading like a catalogue that failed to load rather than like a
		-- deliberate removal.
		piggy = { "skin", "effect" },
		home = { "decor" },
		gear = { "ride" },
	},
	-- WEIGHTED BY THE INVERSE OF WHAT IT COSTS, so the cheap counters arrive
	-- often and the expensive one is a prize rather than a faucet. Measured
	-- across the six: plunger 44%, dog bone 26%, gum 11%, steak 7%, zapper
	-- 3% and the Golden Bone 2.2% -- which against a 20% drop chance is one
	-- Golden Bone per roughly seventy minutes of PERFECT robbing, and a
	-- plunger every few jobs.
	--
	-- A flat roll was the alternative and it is a faucet: one in six of 20%
	-- is a 30,000-coin bone every eight minutes, which would price the whole
	-- guard-dog tree out of meaning anything.
	consumables = { "bone", "steak", "golden", "plunger", "gum", "zapper" },
}

-- ============================================================
-- TAKING A SKIN OFF A PLAYER
-- ============================================================
--
-- WHAT THIS COSTS, WRITTEN FIRST BECAUSE IT IS THE ONLY ENTRY IN THIS FILE
-- THAT SPENDS A RULE RATHER THAN KEEPING ONE.
--
-- Three separate entries in `CLAUDE.md` refuse this, and the bluntest reads:
-- *losing permanent progress was proposed as the incentive and rejected -- it
-- is the one thing every big game on the platform protects, and for this
-- audience it is a crying-then-uninstall event a parent sees.* That is still
-- the argument against it. It was put to the owner with the arithmetic below
-- and taken anyway, deliberately, because the collection is the only stake
-- this game has left worth playing for -- so the job here is not to soften it
-- into nothing but to make a REAL loss survivable, which is the same call
-- `chargeBail`'s 3x cap already makes for coins.
--
-- FOUR RAILS, AND EACH ONE IS LOAD-BEARING RATHER THAN POLITENESS:
--
--   1. ONLY A SKIN THAT CAME OUT OF A CRATE CAN BE TAKEN. `isStealableSkin`
--      is `spec.chest ~= nil`, which is exactly the set the coin crates can
--      hand back -- so what a robbery costs is TIME, never the item. It
--      excludes the free default (no tag), the three rebirth drops, the
--      alien set skin and both pass skins for nothing, because none of them
--      carries a chest tag either.
--   2. A SPARE ABSORBS IT. If the victim holds a spare copy the spare is
--      what goes and they keep wearing the skin -- so `data.spares` grows a
--      second job and "keep a spare of the one you love" becomes a real
--      defensive purchase. The loss only ever lands on somebody who chose
--      not to insure.
--   3. ONE PER VICTIM PER HOUR, WHOEVER IS ROBBING. Same shape and same
--      reason as `LOSS_CAP`: seven players taking turns may not strip a
--      child's collection, and the bound has to be on the VICTIM or it is
--      not a bound at all.
--   4. IT IS LOUD AT BOTH ENDS, and the victim's line names the crate it
--      comes back from. A loss a nine-year-old cannot see a route out of is
--      the thing that ends a session.
--
-- AND THE CHANCE IS HIGH ON PURPOSE, WHICH IS ARITHMETIC RATHER THAN NERVE.
-- `LOSS_CAP` already throttles how often a real player can be cracked at all:
-- at 45% of a pig an hour against a 21.9% clean crack, a victim may be robbed
-- 2.05 times an hour ACROSS EVERY THIEF IN THE SERVER, which is about 2.1
-- player robberies an hour for one thief against 173 shop cracks. So the
-- shop's own 20% would land a skin once every two and a half hours -- a
-- feature nobody would ever meet. The protection that made PvP economically
-- pointless is exactly what makes this affordable.
--
-- Measured at the shipped numbers: 1.03 skins an hour for a thief at a bare
-- sack, 0.54 at a maxed one, against the cap's ceiling of one per victim.
--
-- AND IT DELIBERATELY REVERSES WHICH TARGET THE INCENTIVE POINTS AT, WHICH IS
-- THE HALF TO WATCH.
--
-- `LOSS_CAP`'s own entry ends: *what still points a thief at a resident is
-- RISK -- no alarm, no police, no revenge marker, no grudge, no notification.
-- That is a real pull and a weaker one, and if robbing children ever starts
-- reading as the better play, this is the number that did it.* This is that
-- number. A resident and a player pay the same coins, and only one of them
-- has a collection on it.
--
-- IT IS TAKEN AS A TRADE RATHER THAN OVERLOOKED, and the reading that makes
-- it coherent is worth stating: residents are the SAFE INCOME and players are
-- the RISKY PRIZE. A resident cannot sound an alarm, cannot put you on Most
-- Wanted, cannot hold a grudge and cannot rob you back -- so the thing a
-- player robbery pays extra for is the four ways it can go wrong, which is
-- the same shape every other risk premium in this file has. What it must not
-- become is the ONLY thing worth doing: `auditRobbery` cannot see this,
-- because it models coins and this is not coins, so the check is by hand --
-- if the street stops robbing shops and residents entirely, `chance` is the
-- dial and it comes down before anything else does.
-- ============================================================
-- COINS RUSHING INTO THE PIG
-- ============================================================
--
-- WHAT A DELIVERY LOOKS LIKE IN THE WORLD, and it is in the world rather than
-- on the HUD on purpose.
--
-- The first build flew coin tokens across the SCREEN into the piggy bank
-- panel in the top-right, which is reliable and is describing the wrong
-- object. A delivery happens with the player standing on their own lawn
-- inside `DROPOFF_RADIUS` of the actual pig -- the thing the whole game is
-- named after is RIGHT THERE, twelve studs of it, and the payoff was being
-- drawn as a number moving between two corners of a heads-up display.
--
-- CLIENT-SIDE, AND FOR THE PLAYER WHO EARNED IT ONLY. This is a one-second
-- burst of about a dozen parts; done on the server it is a CFrame write per
-- part per frame replicated to everybody, which is the cost that put the
-- animated skins, the moat and `HouseFX` on the client and is a far worse
-- trade for something that happens once. What the STREET gets is the sound,
-- which `PlotService.playBank` already plays in 3D at the pig -- so a
-- neighbour still hears a delivery land without anybody replicating a coin.
--
-- THE FACE IS ONE ID, AND AN EMPTY ONE IS NOT A MISSING FEATURE. With no
-- image the coin is `Theme.coin` -- the drawn gold disc with a struck rim and
-- an off-centre highlight that the HUD already uses, built out of frames and
-- needing no upload at all. That is the same call `SOUNDS.SIREN` makes by
-- shipping empty: a placeholder nobody remembers to swap is worse than a
-- thing that already looks right. Drop an id in and every coin becomes it.
Config.BANK_RUSH = {
	-- Enough to read as a STREAM rather than as a handful. Above about
	-- twenty they stop being countable and start being a smear, which is a
	-- different effect and a worse one -- the point is that these are coins.
	count = 14,

	-- Where they start, in studs above the pig's own centre, and how far
	-- they scatter across it before they come in. The spread is what makes
	-- them arrive as a shower rather than as a column.
	height = 11,
	spread = 4.5,

	-- How big one is, IN PIXELS across, because the face is an offset-sized
	-- BillboardGui -- see `rushCoins`, which records why studs is the
	-- instinct here and is the wrong unit: everything `Theme.coin` draws is
	-- laid out in pixels, so a stud-sized billboard fits its own contents at
	-- exactly one distance.
	--
	-- 44 against a HUD coin chip of 34: a shower of them beside a
	-- twelve-stud pig, read from the drop-off, wants to be a little larger
	-- than the same object sitting in a corner of the screen.
	size = 44,

	-- THE RUSH. `fall` is one coin's trip and `stagger` is the gap between
	-- them starting, so the whole burst lasts `fall + count * stagger` --
	-- about 1.1 seconds, which is under the summary card's own hold and is
	-- what keeps the two reading as one event.
	--
	-- The tween eases IN rather than out, which is the whole word "rush":
	-- it starts slow, gathers, and disappears into the pig fastest at the
	-- moment it arrives. Eased the other way they drift in and settle, which
	-- is what money being put away looks like rather than money being
	-- poured.
	fall = 0.5,
	stagger = 0.045,

	-- A piggy coin icon goes here. Empty means the drawn one.
	image = "",
}

-- ============================================================
-- THE CRACK'S NOTE LADDER
-- ============================================================
--
-- A RISING RUN AS THE SLICES LAND, WHICH IS THE GREED DIAL IN THE ONE CHANNEL
-- A PLAYER WATCHING THE MARKER CAN STILL READ. The slices already grow 1.4x
-- and the gauge already draws the next one getting bigger; both of those are
-- on a screen the thief is staring at a moving marker on.
--
-- IT WAS A LINEAR RAMP AND A LINEAR RAMP IS NOT NOTES. The first version
-- pitched by `1 + 0.04 * step` -- 1.04, 1.08, 1.12, 1.16 -- which is four
-- even steps of about two thirds of a semitone each. Even steps in FREQUENCY
-- are uneven steps in PITCH, because pitch is logarithmic, so what that
-- produced is a slide rather than a tune: audibly rising, and not a scale any
-- ear can name.
--
-- SO THE STEPS ARE INTERVALS. `2^(n/12)` is equal temperament, and the run is
-- the MAJOR PENTATONIC -- 0, 2, 4, 7, 9 semitones -- which is chosen for one
-- property above all: every subset of it, from any starting note, in any
-- order, sounds consonant. That is what makes it safe to DERIVE the run from
-- `CRACK.maxSteps` rather than hand-writing five values. A sixth slice
-- continues into the octave above with nothing to retune; a run of three
-- still sounds like a run of three.
--
-- WHAT IT IS PLAYED ON IS A LIGHT SWITCH, AND THAT IS THE HONEST LIMIT HERE.
-- `SOUNDS.CLICK` is a Mack Truck light switch from Pro Sound Effects: it is
-- percussive and broadband, so it has no pitch centre for an interval to LAND
-- on -- resampled up it reads as a tighter click rather than as a higher
-- note. The intervals below are still the right intervals and this will still
-- sound better than the ramp did, but the change that would actually make it
-- sing is a TUNED source: a marimba, kalimba or glockenspiel hit.
--
-- THAT SOURCE WAS SEARCHED FOR AND NOT FOUND, which is worth writing down
-- because the next person will look too. The Creator Store's free audio for
-- "marimba", "bell", "ding" and "chime" comes back as unattributed user
-- uploads, Minecraft rips (`command_block_hit`, `Trident_return.ogg`), Wii
-- Sports and one asset with `[ULTRAKILL]` in its own name -- exactly what
-- this file already records, confirmed again. The two safe creators on those
-- pages are APMOfficial (APM Music) and Pro Sound Effects, and neither has a
-- single mallet note in it: PSE is a FIELD RECORDING library and APM's are
-- two-to-four-second musical stings. So this ships on the click we already
-- own and license, and swapping the source is a one-line change here.
--
-- 1.682 AT THE TOP, WHICH IS A 68% RESAMPLE AND IS FINE HERE FOR A REASON
-- THIS FILE OTHERWISE ARGUES AGAINST. The ride audio caps its pitching near
-- 30% because `PlaybackSpeed` is a raw resample and a SUSTAINED loop shows
-- the grain badly. A 0.41-second percussive hit is the opposite case -- it is
-- what every sampler in the world does to build a keyboard, and the artefact
-- has no time to be heard. If it ever does read as thin, the lever is the
-- SCALE (drop to 0, 2, 4, 5, 7 and the top comes to 1.498) rather than the
-- count.
Config.CRACK_NOTES = {
	-- Semitones above the root, walked in order and wrapping up an octave
	-- every time it runs out -- so this is a shape rather than a fixed run.
	scale = { 0, 2, 4, 7, 9 },
	octave = 12,
	volume = 0.45,

	-- A MISS FALLS. The comment this replaces argued a fumble should be
	-- silent here "because the alarm and the dog are what a fumble sounds
	-- like" -- and those are the STREET'S answer to it, played in 3D at the
	-- pig for everybody else. This is the thief's own channel, 2D and audible
	-- to nobody else, so the two do not compete and the alarm keeps every bit
	-- of the stealth it is balanced on.
	--
	-- Same split `HeistService` already draws when a chased player hears the
	-- dog's snarl flat at the front: the person it is about is the one the
	-- 3D mix serves worst.
	--
	-- A fifth DOWN from the root, which is the interval an ear reads as
	-- "wrong" fastest without being a comedy sound.
	miss = -7,
	missVolume = 0.4,
}

-- Equal temperament, and the one place this game does the arithmetic.
function Config.semitonePitch(semitones: number): number
	return 2 ^ (semitones / 12)
end

-- The note for a slice, 1-indexed, derived from the shape above rather than
-- read out of a table sized to today's `CRACK.maxSteps`.
function Config.crackNotePitch(step: number): number
	local notes = Config.CRACK_NOTES
	local scale = notes.scale
	local i = math.max(1, math.floor(step)) - 1
	local degree = scale[(i % #scale) + 1]
	return Config.semitonePitch(degree + notes.octave * math.floor(i / #scale))
end

Config.SKIN_STEAL = {
	-- Per COMPLETED crack on a player. A fumbled one takes nothing here for
	-- the same reason it spends no cooldown: what that attempt cost was the
	-- alarm, which is a steeper price and a more interesting one.
	chance = 0.5,

	-- A REVENGE CRACK TAKES ONE FOR CERTAIN, and it needs no new state --
	-- `HeistService` already computes `revenge` from the grudge table two
	-- lines above where this is read. They took something of yours; the game
	-- should not then also roll dice on whether you get to answer it.
	revengeChance = 1.0,

	-- The cap, in skins per victim per rolling window. Held in memory and
	-- keyed on the Player exactly as `LOSS_CAP` is, and dropped when they
	-- leave -- which costs nothing, because a plot is released the moment its
	-- owner logs off and nobody can be robbed while away.
	cap = 1,
	window = 60 * 60,

	-- WORN ON THE THIEF THE MOMENT IT LANDS, which is the half that makes
	-- this a mechanic rather than a transfer. A stolen skin walking about is
	-- the taunt, it is how the street finds out, and it paints the thief as
	-- the obvious revenge target -- so the loudest robber is the most robbed,
	-- and the feature limits itself with nothing to tune.
	wear = true,
}

-- WHICH SKINS MAY BE TAKEN, AND THE PREDICATE IS THE MERCY RAIL.
--
-- `spec.chest ~= nil` is the whole test, and it says one thing: A STOLEN SKIN
-- IS ALWAYS WINNABLE BACK OUT OF THE CRATE IT CAME FROM. Everything without a
-- tag falls out for free and every one of them is something that could never
-- be handed back -- the free default, the three rebirth drops, the alien set
-- item and the two pass skins.
--
-- `isEarnedElsewhere` is stated as well rather than leant on, for the reason
-- `chestPool` states it: "it cannot reach here" is exactly what was true of
-- the free-if-costless hole right up until it was not, and the thing on the
-- other side of this one is a Robux purchase.
function Config.isStealableSkin(key: string): boolean
	local skin = Config.SKINS[key]
	return skin ~= nil
		and key ~= Config.DEFAULT_SKIN
		and skin.chest ~= nil
		and not Config.isEarnedElsewhere(skin)
end

-- EIGHT PLAYERS AGAINST TEN PLOTS, AND THE GAP IS DELIBERATE -- BUT IT IS
-- BOUGHT WITH PLOTS RATHER THAN PAID FOR WITH PLAYERS, WHICH IS THE WHOLE
-- DIFFERENCE FROM THE VERSION THIS FILE REJECTED.
--
-- Read that carefully, because the two look identical in the arithmetic and
-- are opposite decisions. A gap between the cap and the plot count is what
-- guarantees a resident house nobody can evict. It spent one session at
-- `MAX_PLAYERS` 6 against 8 plots, and that was REFUSED -- not because the
-- gap was wrong but because it was opened by taking two children off the
-- street, which is the one resource this design least wants to spend. The gap
-- is now opened from the other end: `PLOTS_PER_ROW` went 4 -> 5, so the cap
-- stays at eight and the street grew a column. Same floor, nobody turned
-- away.
--
-- **THIS IS A PLAIN NUMBER NOW, NOT `Config.PLOT_COUNT`.** It has to be: the
-- moment it is derived from the plot count the gap closes itself the next
-- time anybody adds a column, silently, taking the supply floor with it. The
-- one invariant that still holds is the direction -- `Main` kicks anybody it
-- cannot seat, so this may never go ABOVE `PLOT_COUNT`, and `auditRobbery`
-- refuses that outright.
--
-- The diagnosis that produced all of this is kept below, because it is right
-- and only the first lever was wrong.
--
-- THE DIAGNOSIS: residents are seated on UNCLAIMED plots -- `ResidentService`
-- evicts on claim and seats on release -- so the number of robbable NPC
-- houses is exactly `PLOT_COUNT - players online`, and at a cap equal to the
-- plot count A FULL SERVER HAS NONE. Every figure `auditRobbery` prints is
-- measured against residents, so the entire economic case for robbing
-- evaporated exactly as a server filled up, which is to say exactly when the
-- game was doing well. Measured at level 20: 4.12x idling with three or more
-- residents, 2.92x with two, 1.46x with one, and **0.14x with none**, against
-- a `ROBBERY_ADVANTAGE.min` of 3.0. Same shape as every other post-mortem in
-- this file: two curves multiplied without anybody checking the product --
-- resident supply times server population, one level up from LOSS_CAP times
-- HEIST_PAYOUT.
--
-- THE WRONG LEVER: capping the server at 6 fixed that by REMOVING PLAYERS,
-- and it bought a supply floor that was available far more cheaply. A busy
-- server is the thing this design most wants and the last thing it should
-- spend -- the eight-plot map exists so that eight children share a street,
-- and the entry above records the lobby argument for it in as many words.
--
-- AND PvP CANNOT BE THE ANSWER AT ANY CAP, WHICH IS THE MEASUREMENT THAT
-- SETTLES IT. `LOSS_CAP` lets a victim lose a quarter of their pig an hour
-- across ALL thieves, so the whole server's theft budget is fixed however
-- many people are in it -- adding a player adds a victim AND a competitor in
-- the same breath. Measured at level 20 with every victim permanently full,
-- which is the best case that can exist: one thief's share is 0.07x idling at
-- two players and 0.12x at eight, and even a SOLE thief robbing seven
-- permanently-full neighbours perfectly reaches 0.97x -- still less than
-- standing still. So the supply has to be non-player at every population.
-- That is arithmetic rather than a preference, and no cap fixes it.
--
-- THE RIGHT LEVER IS `SHOPS`: the four shops already standing on the
-- verge each carry a VAULT, robbed exactly as a house is, seated with a
-- resident that can never be evicted because a shop plot can never be
-- claimed. Measured, THREE permanent non-player targets saturate a thief at
-- the original 60-second cooldown -- so four shops put the floor above the
-- requirement at every population from one player to eight, and both this cap
-- and `RESIDENTS.stealCooldown` went back to what they were.
--
-- What DOES still hold from the rule this replaces is the half it was
-- originally written for: `Main` kicks anybody it cannot seat, so this may
-- never go ABOVE `PLOT_COUNT`. `auditRobbery` refuses that outright.
--
-- AND FOUR SHOPS TURNED OUT NOT TO BE THE END OF IT. The sentence above --
-- three permanent targets saturate a thief, so four clears it -- is true of
-- the LAP and says nothing about how much is in the pigs. On a full street
-- those four were the entire non-player supply of the economy, so eight
-- thieves shared them and drained them; `docs/MASTER-PLAN.md` Part III D4
-- lists that as the first number to look at in a real playtest. The extra
-- plot column puts two resident houses behind them at every population, and
-- `RESIDENT_FLOOR` picks that up with no edit because the term was already
-- written.
Config.MAX_PLAYERS = 8

-- The number of robbable pigs that exists no matter how busy the street is.
-- DERIVED rather than stated, so it cannot disagree with the numbers it comes
-- from, and `auditRobbery` measures the economy AT THIS FLOOR -- the worst
-- case rather than the empty-server best case it used to assume.
--
-- The shops are the whole of it on a full server, which is the point:
-- the house term goes to zero exactly when the street is busiest, and that is
-- the failure this floor exists to survive rather than to describe.
Config.RESIDENT_FLOOR = Config.SHOP_COUNT
	+ math.max(0, Config.PLOT_COUNT - Config.MAX_PLAYERS)

-- WIDER THAN IT IS DEEP, AND THAT IS WHAT MADE THE TWO HALVES OF THE FENCE
-- STOP BEING THE SAME NUMBER. It was 48 x 48 -- see PLOT_HALF_WIDTH below,
-- which is the whole of why widening this is not a one-line change.
--
-- X is ACROSS the plot, along the street. Z is depth, and the yard runs back
-- from +Z (the pavement) to -YARD_DEPTH (the back fence).
--
-- 48 -> 64 to fit bigger houses and more lawn.
--
-- THE FIRST VERSION OF THIS COMMENT JUSTIFIED IT WITH THE SKY CASTLE
-- OVERHANGING THE FENCE BY 16.6 STUDS, AND THAT WAS NEVER TRUE. That figure
-- came from `Model:GetBoundingBox`, which includes a house's HouseFX -- so it
-- was measuring the castle's ORBITING SHARDS, at x 30.9 and y 67, sixty-seven
-- studs in the air where no fence has ever been. Measured with the tagged
-- parts excluded, the castle's structure is 48.0 studs wide and fitted the old
-- 51.2 interior comfortably, as did all nine tiers.
--
-- THE REAL CEILING WAS THE CATALOGUE RUNNING OUT OF ROOM. The widest building
-- is the Marble Palace at 49.0, which left 2.2 studs of headroom inside 51.2 --
-- so no wider house tier could ever be added. At 67.2 it is 18.2. That is what
-- this bought, along with a lawn that can hold eight ornaments instead of
-- seven without any of them overlapping.
--
-- Measure a building by its PARTS and skip the HouseFX tag; a bounding box
-- here measures a light show.
Config.PLOT_SIZE = Vector3.new(64, 1, 48)

-- THE SHELL, AND THE ROOM INSIDE IT. Three files need these now -- the one
-- that builds the building, the one that stands a vault and a shopkeeper in
-- it, and this one, which prices the run home off where that vault ended up
-- -- so they live where all three can read them rather than as locals in the
-- builder that happened to need them first.
--
-- WHAT COLLIDES IS THE SHELL AND THE FLOOR, AND NOTHING ELSE IN HERE.
--
-- This entry read "THE INTERIOR IS NOT SOLID AND MUST NOT BECOME SOLID" for
-- the life of the shop vaults, on the argument that `PoliceService` and
-- `GuardDog` both walk in a straight line at their target with no
-- pathfinding -- so a building with solid walls would be a place nothing in
-- the game can reach you, an exploit wanting pathfinding in two services to
-- fix for a cosmetic gain.
--
-- THE ARGUMENT NAMES PATHFINDING AND NEITHER OF THOSE TWO USES ANY, WHICH IS
-- WHAT MAKES IT WRONG RATHER THAN CAUTIOUS. An officer, a guard dog and a
-- shopkeeper are ANCHORED parts driven by `Model:PivotTo` and by per-frame
-- CFrame writes -- there is not a physics-driven body among them -- so a
-- collision hull is not something any of them walks INTO, it is something
-- they walk THROUGH. Making the shell solid takes nothing from a chase and
-- stops the one thing it was ever meant to: reaching a vault on a back wall
-- by standing in the grass behind it, which `Config.shopRoomHolds` had to be
-- written to refuse because the geometry would not.
--
-- So `ShopFront` stands an invisible barrier ring with a gap at the door, and
-- every visible piece of the building stays `CanCollide` false. THE FITTINGS
-- ARE DELIBERATELY STILL WALK-THROUGH: a counter, a shelf run and a display
-- case are a picture of a shop rather than a maze, and `Config.SHOP_ROOM`
-- below is what keeps them out of the walk instead.
-- 21 x 15 RATHER THAN 18 x 14, AND THE ROOM IS WHY.
--
-- The entry below divides this floor into bands and audits the gaps between
-- them. What that audit could not say, because it was reading a broken
-- number, is that the room had nothing left: measured on the shipped build,
-- bay 4.6 + customer strip 2.5 + counter 2.2 + keeper pocket 3.0 came to
-- 12.3 of 12.6, with every band already at its floor. The strip cleared
-- `minWalk` by a TENTH OF A STUD and the way past the counter was 1.05.
--
-- So the fittings could not be rearranged into a room that works -- solved
-- both ways, a turned counter and a moved one, and at 16.4 of width neither
-- fits a counter, a shopkeeper behind it and the vault door's own 1.55-stud
-- intrusion at any walkway worth the name. The room was too small for what
-- it was being asked to hold, which is a thing to fix rather than to shuffle.
--
-- WIDTH IS THE CHEAP AXIS AND THE VERGE SURVEY SAYS SO. That survey measured
-- the buildable band between the kerb and the fences at 47 studs against a
-- forecourt of 21.4; at 21 wide the forecourt is 24.4 and there are still
-- twenty-two studs spare. Depth is the dearer one -- it is spent against the
-- ClimbZone behind and the pavement in front -- so it takes one stud and the
-- width takes three.
Config.SHOP_UNIT = {
	width = 21,
	depth = 15,
	height = 13,
	-- The usable room, inside the wall faces.
	roomWidth = 19.4,
	roomDepth = 13.6,
	-- The interior floor's TOP, above the pavement the unit stands on.
	-- DERIVED, because it is a plot slab: `buildShopPlot` seats an ordinary
	-- plot base in here and everything else in the game measures a plot's
	-- walkable surface as half a slab above its origin.
	--
	-- AND IT IS WHY THIS WHOLE TABLE SITS DOWN HERE RATHER THAN BESIDE
	-- `Config.SHOPS`, WHICH IS WHERE IT BELONGS AND WHERE IT WAS FOR ONE
	-- BOOT. A Config FIELD that forward-references another Config field does
	-- not limp the way a `local` read as a nil global does -- it throws while
	-- this module is still LOADING, and Config is required by every service
	-- and every client. Measured: `nil.Y` twice, once from `Main` and once
	-- from `ClientMain`, no plots, no services, no HUD, and no "Ready" in the
	-- log at all. Same fault `LAWN_LIFT` records four hundred lines below,
	-- walked into again by somebody who had read that entry.
	floorY = Config.PLOT_SIZE.Y,
	-- Where the vault stands, in the unit's own frame. Against the back wall
	-- and on the door's own centre line, so walking in points you at it --
	-- the door sits to one side of the frontage because the display window
	-- takes the other, and a vault in the middle of the back wall would be
	-- behind the counter instead of at the end of the walk.
	-- ON THE DOOR'S OWN CENTRE LINE, WHICH IS WHY THIS MOVED WITH THE WIDTH.
	-- `ShopFront` derives its door from the pier spacing, so a wider unit
	-- puts the entrance further out and a pinned vault would no longer be at
	-- the end of the walk. It is `clear - doorW/2 - 0.15` over there and 5.25
	-- here; move the piers or the door width and re-derive it.
	--
	-- Note both of these are read by `Config.shopVaultRunStuds`, so they are
	-- economy numbers as well as placement ones -- the run home is built out
	-- of them. `SHOP_VAULT_DISCOUNT` is solved against the RATIO of the two
	-- cycles, so coins per second survive a move like this by construction;
	-- `auditRobbery` is what proves it did.
	vaultX = 5.25,
	-- Backed onto the wall rather than pinned: the carcass is 2.4 deep about
	-- its own origin, so this is the back wall's inner face plus 1.2.
	vaultZ = -5.5,
}

-- THE ROOM'S PLAN, AND IT IS A PLAN RATHER THAN A LIST OF PLACEMENTS.
--
-- Three files stand something on this floor -- `ShopFront` builds the
-- fittings, `PlotService` stands the vault, `ResidentService` stands the
-- shopkeeper -- and while each carried its own numbers the room filled up
-- without anybody adding it up. Measured on the shipped build:
--
--   * the display case's backboard stood 1.45 studs in front of the counter
--     top, which is the gap a customer stands in and is NARROWER THAN A
--     CHARACTER, so the one place in the room a person is meant to walk to
--     was the one place they could not fit;
--   * the shopkeeper's pocket, between that counter and the back shelves,
--     was 2.68 -- passable, and it reads as a figure wedged in a slot;
--   * and the garden centre's planted back wall ran the FULL 16.4-stud width
--     of the room at z 0.8, between the door and its own vault.
--
-- None of that errors and none of it is visible from any number the builder
-- prints. So the FLOOR is divided into bands, front to back, the gaps
-- between them are the walkways, and `Config.auditShopRoom` is what stops
-- the next fitting quietly eating one.
--
-- THE MOVE THAT MADE IT FIT WAS TURNING THE SHELVES. On the back wall they
-- spent 1.3 studs of the room's DEPTH, which is the axis the counter, the
-- pocket, the customer strip and the window bay are all competing for; along
-- the LEFT WALL they spend WIDTH, which nothing else wants.
Config.SHOP_ROOM = (function()
	local counterBack = -3.3
	return {
		-- EVERYTHING RIGHT OF THIS IS THE AISLE: the straight walk from the
		-- door to the vault, which is the one line through this room a
		-- robbery depends on. It has to clear the vault's own OPEN DOOR,
		-- which swings out into the room -- see `vaultDoorFarX` below, and
		-- note that the number to clear is NOT `VaultModel.SIZE.doorReach`,
		-- which is a distance along the leaf and not an extent across the
		-- floor.
		-- 2.5 RATHER THAN 1.0, BECAUSE THE DOOR IT HAS TO CLEAR MOVED WITH
		-- THE UNIT. `vaultDoorFarX` is 2.37 now, and an aisle starting
		-- inside the swung leaf is an aisle with a vault door in it -- which
		-- is the second of the two checks below, and it fires on this pair.
		aisleX = 2.5,

		-- The window display, against the glazing. `bayBack` is the back
		-- face of its backboard and is therefore the front edge of the floor;
		-- the bay is centred on the WINDOW, which only `ShopFront` knows, so
		-- that file checks its own right-hand edge against `aisleX`.
		--
		-- 1.4 is what the display needs and not a stud more: `ShopFront`
		-- solves its cap off the model's own turned diagonal, and this is
		-- where that lands with a hand's clearance to the backboard behind
		-- and to the glass in front. Every tenth taken off it is a tenth
		-- added to the customer strip, which is why the audit measures the
		-- strip rather than trusting this.
		-- THE BAY GREW WITH THE GLAZING RATHER THAN STAYING PUT, and it had
		-- to: `ShopFront` derives its window from the pier spacing, so a
		-- wider unit is a wider window, and a 6.2 case behind an 8.25 window
		-- leaves two studs of glass with the shop's own interior behind it --
		-- which is the "an opening needs something behind it" fault this
		-- file already paid for once on the garden centre. `caseWidth` is
		-- the glazing plus about a stud, `bayWidth` a shade under it.
		bayBack = 1.7,
		bayFront = 6.2,
		bayWidth = 9.0,
		caseWidth = 9.4,

		-- WHERE THE VAULT'S OWN OPEN DOOR STANDS ON THIS FLOOR, and it takes
		-- TWO numbers because two different things run into it.
		--
		-- These are `SHOP_UNIT.vaultX` less `VaultModel.SIZE.doorAcrossMax`
		-- and `.doorAcrossMin`, copies for the reason recorded over there:
		-- Config requires nothing and is not about to start requiring a model
		-- builder. Move either and move both.
		--
		-- THIS WAS ONE NUMBER, `vaultDoorX = 0.87`, AND IT WAS THE WRONG EDGE
		-- OF THE WRONG OBJECT -- which is the whole reason the shops read as
		-- unwalkable while this audit reported them clean.
		--
		-- 0.87 is the leaf's FAR edge, the side toward the entrance. The
		-- audit spends it as the NEAR one, in `vaultDoorX - counterRight`, so
		-- it was measuring from the wrong side of a blade a stud thick.
		-- Measured, the leaf runs -0.23 to 0.87, so even leaf-only the way
		-- past the counter was 2.57 rather than the 3.47 being reported.
		--
		-- AND THE LOCK DIAL BOLTED TO THAT LEAF SWINGS WITH IT, which nothing
		-- had ever measured. A 3.9-stud plate on the outward face reaches a
		-- further 1.37 studs into the room: the real near edge is -1.55, and
		-- the real gap between it and the counter is 1.05 STUDS -- against a
		-- `minWalk` of 2.40 and a character about two studs across. Standing
		-- in the customer strip puts that dial 2.2 studs from your face.
		--
		-- Same family as `SHOP_BANK_PIG_SECONDS` and the vault opening sized
		-- against one of four lock tiers: a number measured correctly on one
		-- part, then spent as though it described the whole assembly, with an
		-- audit dutifully passing on it for the life of the feature.
		--
		-- It is an obstacle nothing here can move -- a vault door standing
		-- open is the readout that makes the coin bars visible -- so the
		-- fittings are measured against it rather than the other way round.
		vaultDoorNearX = -0.05,
		vaultDoorFarX = 2.37,

		-- The counter, across the fittings side and stopping well short of
		-- the aisle. It is SHORTER than it was: the old one reached x -0.7,
		-- which left 0.53 studs between it and that open leaf -- two
		-- obstacles in a line with a slot between them rather than a way
		-- past, which is the same fault as the customer strip one band
		-- forward and was one nobody had looked for.
		-- IT IS WIDER, SHALLOWER AND FURTHER LEFT, and every one of those
		-- three is a band paying for a walkway rather than a taste call.
		-- Left and right came off the wider room, which is what finally
		-- lets `counterRight` clear the swung vault door by 3.25 instead of
		-- the 1.05 that was there; the front came back so the customer strip
		-- is 3.3 rather than 2.5. What it costs is 0.5 of counter DEPTH --
		-- 1.7 against 2.2 -- which is the one dimension of a counter nobody
		-- stands in.
		counterBack = counterBack,
		counterFront = -1.6,
		counterLeft = -8.35,
		counterRight = -3.3,

		-- The shelves, along the left wall. `shelfFace` is the face that
		-- looks into the room, so it is where the shopkeeper's pocket starts.
		shelfFace = -8.65,
		shelfBack = -6.5,
		-- Stopping BEHIND the counter's own front line, so the run cannot
		-- put an upright into the customer strip it does not belong in.
		shelfFront = -1.8,

		-- WHERE THE SHOPKEEPER STANDS, and `keeperZ` is DERIVED rather than
		-- typed: it is the middle of the pocket the counter and the back wall
		-- leave between them, and a typed one stops being the middle the
		-- first time either of those moves. That is how the shipped
		-- `SHOP_STAND_AT` came to be where it was: a typed -3.2 put the
		-- shopkeeper 0.55 studs behind a counter with 2.68 studs of pocket
		-- behind it, which is hard up against the furniture rather than
		-- standing in the room.
		-- Behind the counter's own run, which moved left with it. The audit
		-- catches a typed one that falls outside the pocket; it cannot catch
		-- one that merely stopped being central, so it is worth re-deriving
		-- by eye whenever the counter moves.
		keeperX = -6.0,
		keeperZ = (counterBack - Config.SHOP_UNIT.roomDepth / 2) / 2,

		-- WHAT A WALKWAY HAS TO BE TO BE ONE. A character measures about two
		-- studs across, so this is that plus enough not to read as a squeeze.
		--
		-- 3.0 RATHER THAN 2.4, AND THE OLD FLOOR IS PART OF WHY THIS ROOM
		-- READ WRONG WHILE AUDITING CLEAN. The customer strip was 2.50
		-- against 2.40 -- passing by a tenth of a stud -- and it was reported
		-- as a corridor, which is the honest answer: a player is two studs
		-- wide and the third-person CAMERA sits behind them, so a gap that
		-- merely admits the body puts the view inside the furniture. A floor
		-- that a shipped, complained-about gap clears is not a floor.
		--
		-- Raising it is what forced the unit to grow rather than the
		-- fittings to shuffle, which is the point of having one.
		minWalk = 3.0,
	}
end)()

-- Derived the moment its source exists, never before it. See the fence
-- section above for what this is and why it is the slab's own thickness.
Config.LAWN_LIFT = Config.PLOT_SIZE.Y

-- WHERE A WHEEL BELONGS, and it is a fact about the ROAD rather than about
-- whoever is driving on it.
--
-- `NeighborhoodService` lays the tarmac 0.06 proud of the world ground so
-- the two never z-fight -- coplanar surfaces give the renderer nothing to
-- sort by and the grass flickers through the asphalt -- so anything parked
-- at ground level sinks that much into it.
--
-- It lived as a private local in `PoliceService`, which was correct while
-- exactly one thing drove on this road. A second vehicle would have been a
-- second copy of the same derivation, and the failure shape is the one this
-- file keeps recording: the two agree today, somebody re-lays the road, and
-- one of them is left half a stud under the tarmac with nothing erroring.
-- Derived here, in the file that already owns PLOT_SIZE.
Config.ROAD_SURFACE_Y = -Config.PLOT_SIZE.Y / 2 + 0.06

-- How far a fence stands off the slab edge.
Config.FENCE_OFFSET = 1.6

-- THE SIDES AND THE FRONT ARE DIFFERENT NUMBERS, AND EVERYTHING THAT READS ONE
-- OF THEM HAS TO SAY WHICH.
--
-- They were both `PLOT_SIZE.X / 2 + 1.6`, which was correct only because the
-- plot happened to be square. `buildFence` used a single `half` for the side
-- fences (an X extent) AND for the front fence (a Z position), and so did
-- `yardContaining`, `trespassers` and `streetMetrics`. Widening X alone would
-- have moved the FRONT FENCE eight studs toward the road on every plot --
-- silently, because nothing would have errored: the ride gate's boundary, the
-- leaderboard, the wanted poster and all four shop fronts derive from that
-- line, and the verge they stand on had just been widened on purpose.
--
-- This is the same trap this file already records for YARD_DEPTH, one axis
-- over: "anything positioned relative to the yard must measure from
-- YARD_DEPTH, not from the plot slab -- they were the same number until the
-- fence was lengthened". Two numbers that agree by coincidence are one bug
-- waiting for somebody to change either of them.
Config.PLOT_HALF_WIDTH = Config.PLOT_SIZE.X / 2 + Config.FENCE_OFFSET
Config.PLOT_FRONT_LINE = Config.PLOT_SIZE.Z / 2 + Config.FENCE_OFFSET

-- Along the street, centre to centre. The heist maths depends on this being
-- the SHORTEST distance between two plots: STEAL_RANGE + DROPOFF_RADIUS (27)
-- must stay well under it, or a thief could stand in their own drop-off zone
-- and rob a neighbour without ever running. At 80 that sum is 34% of the
-- spacing, against 42% before -- so the rule holds by a wider margin than it
-- did, not a narrower one.
--
-- 64 -> 80, AND IT IS THE PLOT WIDTH THAT DRAGGED IT. The alley between two
-- neighbouring fences is `spacing - (plotWidth + 2 * FENCE_OFFSET)`, which was
-- 12.8 studs. Widening the plot to 64 and leaving the spacing alone would have
-- closed that to a negative number -- neighbouring fences sharing the same
-- ground. Holding the alley at 12.8 is what sets this constant, so the two
-- move together and neither is free.
--
-- WHAT IT COSTS IS THE GETAWAY, and that is the real price of a wider plot.
-- The run from a victim's piggy to your own drop-off is
-- `spacing - STEAL_RANGE - DROPOFF_RADIUS`: 37 studs before, 53 now, which at
-- a carrying speed of 12 is 4.4 seconds against 3.1. A longer run means more
-- chase, which is the good half; it also means an alerted Titan at 17 has
-- 4.4 seconds to close instead of 3.1, which is the half to watch. If robbing
-- starts reading as too hard, DROPOFF_RADIUS is the lever -- it is a fraction
-- of your own plot rather than an absolute, so it can grow with the plot.
--
-- The row is 307 studs across at four plots a side, against 243 before and
-- 371 at the six-a-side layout this all replaced.
Config.PLOT_SPACING = 80

-- Across the street, centre to centre. Wider than PLOT_SPACING so next door
-- stays the easy target and across the road is a choice.
--
-- 104 -> 144, TO MAKE A VERGE WIDE ENOUGH TO BUILD ON. Everything that is not
-- a house -- the two boards, the four shops -- lives in the band between the
-- kerb and the front fences, and at 104 that band was 18.4 studs, which is a
-- driveway and nothing else. At 144 it is 38.4: a pavement with lamp posts and
-- bins on it, and buildings set back behind them.
--
-- NOT 208, WHICH WAS THE ASK, AND THE REASON IS THE ONE NUMBER THAT MOVES THE
-- WRONG WAY. Doubling costs a cross-street robbery 17.3 seconds of carrying
-- against 8.7 today -- and this constant's whole job is that across the road
-- is "a choice" rather than "never", which at seventeen seconds against an
-- alerted Titan doing 17 it is not. It also made the map LONGER than the one
-- this was all meant to shrink: worst-case corner to corner would have gone
-- to 283 studs against the 276 we started with.
--
-- Measured, with the row's own gap closed up:
--
--     spacing   verge band   cross-street   worst steal
--        104       18.4          8.7s        218 /  18.2s
--        144       38.4         12.0s        240 /  20.0s
--        208       70.4         17.3s        283 /  23.6s
--
-- 144 doubles the buildable band and still lands the worst case SHORTER than
-- it was before any of this. 208 buys thirty more studs of verge that nothing
-- needs and pays for it with a map bigger than the one we set out to cut.
--
-- ROAD_HALF_WIDTH is pinned, so all of this widening lands on the verge and
-- none of it on the tarmac -- which is the whole reason that constant is not
-- derived from this one.
Config.STREET_SPACING = 144

-- The carriageway is a FIXED width, not whatever is left over.
--
-- It used to be derived from the moat, which meant widening the street just
-- widened the tarmac and the driveway never grew. Pinning the road is what
-- turns extra street space into driveway.
Config.ROAD_HALF_WIDTH = 8

-- How far the fence runs BACK from the plot centre to enclose the house.
--
-- Only the back moves. The front fence stays at Config.PLOT_FRONT_LINE, which
-- is the line every heist number is tuned against -- a thief approaches from
-- the street, so lengthening the yard behind the piggy changes nothing about
-- the steal, the getaway or the drop-off.
--
-- That used to read `PLOT_SIZE.X / 2 + 1.6`, which was the same number only
-- while the plot was square. It is the DEPTH that sets the front line; the
-- width sets the sides. See PLOT_HALF_WIDTH.
-- WHERE EVERY HOUSE'S FRONT WALL STANDS, measured back from the plot centre.
--
-- Houses used to be seated by their BACK wall, which sounds equivalent to this
-- and is not. Depth varies by 41 studs across the nine tiers, so pinning the
-- back threw every bit of that variation FORWARD onto the lawn: measured, the
-- Sky Castle's front reached z -8.2 and stood on three decoration slots, and
-- the Marble Palace and the Midnight Modern each covered one. A player who
-- bought the best house in the game lost three ornaments to it.
--
-- Pinning the FRONT fixes both halves at once. Every tier now begins the same
-- distance behind the piggy -- which is the view that matters, because a house
-- is looked at from the street -- and no house can reach a slot at any tier,
-- by construction rather than by nine separate checks.
--
-- 28 is DERIVED, not chosen: the rearmost lawn slot is lawnF at z -19, and the
-- deepest ornament in the catalogue (the Giant Rubber Duck at 11.0) standing
-- in it reaches back to -24.5. This clears the furthest an ornament can ever
-- stick out by 3.5 studs. Add a deeper ornament and this is the number to
-- re-derive.
Config.HOUSE_FRONT_LINE = 28

-- Clearance from the deepest house's back wall to the back fence. Was folded
-- into the seating code as a bare `- 5`.
Config.HOUSE_BACK_GAP = 5

-- HOUSE_FRONT_LINE + the deepest house + HOUSE_BACK_GAP, and it has to be at
-- least that or the top tiers push out through the back fence. The Sky Castle
-- measures 56.8 deep, so 28 + 56.8 + 5 = 89.8.
--
-- Lengthening the yard is cheap, which is what makes this the right lever:
-- only the yard's FRONT line is load-bearing. Nothing about the steal, the
-- getaway or the drop-off measures from the back, and the fence, the stone
-- trim, the yard grass and the grove behind the plots all derive from this
-- number rather than keeping their own copy of it.
Config.YARD_DEPTH = 90

-- ============================================================
-- THE ROW
-- ============================================================
--
-- A CONTINUOUS TERRACE. There was briefly a hole in the middle of each row --
-- one empty PLOT_SPACING slot -- and the town square sat in it. It worked and
-- it read as a missing tooth: sixty-four studs of nothing between two houses
-- is not a gap, it is an absence, and it was the widest thing on the street.
--
-- THE SQUARE MOVED SIDEWAYS INSTEAD OF ALONG. Everything it held -- the two
-- boards, the four shops -- now stands on the VERGE, in the band between the
-- kerb and the front fences, which STREET_SPACING was widened to make room
-- for. That band runs the whole length of the street, so there is somewhere
-- to put things without taking a house out of the row to do it.
--
-- The alley between neighbouring plots stays. It is 16 studs slab to slab and
-- 12.8 fence to fence -- `PLOT_SPACING - (PLOT_SIZE.X + 2 * FENCE_OFFSET)` --
-- and holding that second figure is what forced PLOT_SPACING up to 80 when the
-- plot widened. It is load-bearing for the ride gate and the getaway, so the
-- two constants move together and neither is free.
function Config.plotColumnX(col: number): number
	return (col - (Config.PLOTS_PER_ROW - 1) / 2) * Config.PLOT_SPACING
end

-- ============================================================
-- PERSISTENCE
-- ============================================================

-- ============================================================
-- ANIMATIONS
-- ============================================================
--
-- `KeyframeSequenceProvider:RegisterKeyframeSequence` IS STUDIO-ONLY, AND
-- EVERYTHING ANIMATED IN THIS GAME WAS BUILT ON IT.
--
-- The dodge roll and every rider pose are KeyframeSequences assembled at
-- runtime and registered for a `hash://` id. That was chosen deliberately --
-- it means no uploaded asset that moderation can take away, the same reason
-- the ground and the houses are built in code. It works perfectly in Studio.
--
-- IT DOES NOT WORK IN A PUBLISHED GAME. The id that call returns is temporary
-- and local to Studio; live, the call is refused. Both readers pcall it and
-- warn, so nothing crashes -- the dodge still moves you at the right speed and
-- a ride still carries you -- but the character never animates. That is the
-- shape of the bug: it passes every test in Studio and is dead on the site.
--
-- SO EACH ONE NEEDS UPLOADING ONCE, and its id goes here. Until then this
-- table is empty and the readers fall back to registering, which keeps Studio
-- development working exactly as it does today.
--
-- To get them: run the `animdump` admin command in Studio. It builds every
-- sequence below into ReplicatedStorage.AnimationDump. Open each in the
-- Animation Editor and publish it, then paste the id here. They are ordinary
-- animation assets after that and replicate like any other.
--
-- The keys are RidePose's own: `<style>` for the plain pose, `<style>#trick`
-- for the trick, and `<style>@<stance>` once a stance ships -- so a new stance
-- adds a row here as well as a pose.
Config.ANIMATIONS = {
	dodgeRoll = "112707884196284",

	-- THE TIPTOE, AND IT IS DELIBERATELY EMPTY UNTIL SOMEBODY UPLOADS IT.
	--
	-- An empty row reads as "not published yet", so the sneak registers itself
	-- in Studio exactly as the dodge did before it was uploaded, and `Main`
	-- names it at startup on a live server. That warning is the whole safety
	-- net here: `RegisterKeyframeSequence` is refused live, so shipping this
	-- blank means a published game where the tiptoe silently goes back to
	-- being a speed number with the ordinary walk cycle on top -- which is the
	-- precise bug the animation was written to fix, reintroduced by omission.
	sneak = "",

	-- THE CARRY POSE, EMPTY FOR THE SAME REASON AND WITH A SHARPER COST.
	--
	-- A thief holding somebody's piggy is the most-watched three seconds in
	-- this game -- the whole risk half of a robbery is that the run home is
	-- VISIBLE -- and with this row blank on a live server the pose is refused
	-- and the pig goes back to floating in front of a person with their arms
	-- swinging at their sides. The loot, the label and the chase all still
	-- work, which is exactly what makes it the quiet kind of broken.
	carry = "",

	bmx = "114403644299903",
	["bmx#trick"] = "123032044115813",
	skateboard = "90962106232371",
	["skateboard#trick"] = "97117126427423",
	scooter = "106867053658542",
	scrambler = "134490288873353",
	["scrambler#trick"] = "136449255408633",
	hoverboard = "122988506386726",
	hoverdisc = "78211909505189",

	-- THE STANCES, AND THEIR ABSENCE WAS A LIVE BUG RATHER THAN A GAP.
	--
	-- A stance is published as part of the style ("scrambler@onehand"), so it
	-- is a separate key and needs a separate upload -- which the note above
	-- has always said. What it did not say is that nothing ENUMERATED them:
	-- `animationKeys` derived its list from the ride catalogue alone, so the
	-- startup warning could not name these, `animdump` never built them, and
	-- none was ever published. Every rider who picked a style on the live site
	-- lost their pose while every rider who did not was fine, which is exactly
	-- how it was reported.
	--
	-- Uploaded and verified: each id was fetched back with
	-- `GetKeyframeSequenceAsync` and its poses diffed against the sequence
	-- this repo builds for that key, because eight near-identically named
	-- assets published by hand is precisely where two ids get swapped -- and a
	-- swap would look like a subtly wrong pose rather than like an error.
	["bmx@onehand"] = "86219177400254",
	["bmx@onehand#trick"] = "139912200308894",
	-- EMPTY BECAUSE IT IS A NEW POSE AND NOBODY HAS UPLOADED IT YET, and the
	-- row it replaces was `hoverboard@crossed` at 78348588466887 -- an ARMS
	-- FOLDED stance that is retired. That asset is still on the account and
	-- still playable; nothing in the game asks for it any more.
	--
	-- A stance with no id is not a stance that fails loudly. `getAnimationId`
	-- degrades to the pose it is a variant of, so live, a player who picks
	-- Upside Down gets the ORDINARY hoverboard pose and a warning on their own
	-- client -- the ride works, the style is silently absent, and this file
	-- already records that exact bug shipping once as "some vehicles animate,
	-- the e-bike style is not there". `Main` names every empty row at startup
	-- on a live server, which is the whole safety net.
	--
	-- To fill it: run the `animdump` admin command, which builds every
	-- sequence `RidePose.animationKeys()` asks for -- including this one, with
	-- no list to update -- publish `RidePose_hoverboard@upsidedown` from
	-- ReplicatedStorage, and paste the id here. Then fetch it back with
	-- `GetKeyframeSequenceAsync` and diff it against the built sequence, which
	-- is the test this project set itself after eight near-identically named
	-- assets went up by hand: the name on an asset is the one thing nothing in
	-- the engine checks.
	["hoverboard@upsidedown"] = "",
	["scooter@nohands"] = "119583457591823",
	["scrambler@onehand"] = "129207650513579",
	["scrambler@onehand#trick"] = "84072966360791",
	["skateboard@cruise"] = "88999637903592",
	["skateboard@cruise#trick"] = "83514290784857",
}

-- The uploaded id for an animation key, or nil to fall back to registering it.
--
-- An empty string reads as "not uploaded yet" rather than as an id, so a row
-- left blank behaves exactly as it did before this table existed.
function Config.animationId(key: string): string?
	local id = Config.ANIMATIONS[key]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	-- Accept a bare number or a full rbxassetid, because whichever the
	-- Creator Dashboard hands over is the one somebody will paste.
	if id:match("^%d+$") then
		return "rbxassetid://" .. id
	end
	return id
end

-- ============================================================
-- THE PIGGY MESH
-- ============================================================
--
-- The piggy is four MeshParts generated by Studio's own mesh generator, split
-- by COLOUR REGION so the skin system is untouched: `Body` takes `skin.body`
-- and `Ear`, `Snout` and `Tail` take `skin.trim`, exactly as they are already
-- written to the pink sphere and the dark-pink snout, ears, legs and tail.
--
-- AN EMPTY ID BEHAVES EXACTLY AS TODAY, which is the whole reason this shape
-- was chosen over anything cleverer. `Config.ANIMATIONS` already works this
-- way and the argument is the same one: the ids can be filled in one at a
-- time, Studio development is untouched until they are, and the primitives
-- pig stays the fallback rather than being deleted. A fresh empty place plus
-- this repo still gives the identical world, which is the property this whole
-- project is built on -- it just gives a smoother pig once the assets exist.
--
-- OFFSETS ARE TO EACH MESH'S BOUNDING-BOX CENTRE, NOT TO THE PIGGY'S ORIGIN,
-- because that is what a MeshPart is seated by. The four parts do NOT share
-- one: an ear sits high and forward and a tail sits high and behind, so
-- seating them all at the origin -- the obvious reading -- stacks the whole
-- pig inside its own belly. Same family as a UnionOperation's `Position`
-- being its box centre, and as `PivotTo` aiming the PrimaryPart, which sank
-- the patrol car into the road.
--
-- Every number is MEASURED IN STUDIO against the live meshes rather than read
-- off a screen: the generator returns parts at an arbitrary scale and centre,
-- and one pass fits their combined box onto the landmark contract below. Six
-- hand-transcribed numbers per part is six chances to flip a sign, and a
-- seating error does not throw -- it renders a pig with its ears behind its
-- head.
-- THE MESH IS FOUR PARTS, NOT TWO, AND THE GENERATOR IS THE REASON.
--
-- The first meshed pig came out of Blender as ONE welded surface that then had
-- to be CUT into a body half and a trim half -- a closest-point test against a
-- separately remeshed "trim solid", with a margin deciding the fillet zone.
-- That produced a permanently ragged seam at the ear base, and the Blender
-- README recorded it as unfixable at any triangle budget, because "inside the
-- trim volume" is a genuinely ambiguous question in a fillet.
--
-- Studio's own mesh generator hands the parts back ALREADY SEPARATE, so the
-- question is never asked. No classification, no trim solid, and no seam.
--
-- THE PART NAMES ARE THE PRIMITIVES' OWN NAMES ON PURPOSE. `Snout`, `Ear` and
-- `Tail` are exactly what `PiggyBank.applySkin` already collects into its trim
-- list and what ClientMain's ANIMATED_TRIM already drives, so a meshed pig
-- costs neither of them a branch -- see the note over `swapToMesh`.
--
-- EVERY ID HERE IS AN UNTEXTURED MESH, and that is load-bearing rather than
-- incidental. A generated mesh arrives carrying a baked texture with painted
-- eyes and shading on it, and NO PROMPT REMOVES IT -- asking for "no texture,
-- no paint, no facial features" was ignored outright, twice. A MeshPart
-- MULTIPLIES its `Color` against whatever the mesh carries, so a painted pink
-- pig under the Cow skin comes out muddy pink rather than white, silently, on
-- 46 skins at once -- and the three animated skins that rewrite colour every
-- frame would drive that same muddy multiply. Clearing `TextureID` re-mints
-- the mesh, which is where these ids come from.
--
-- THE SIZES ARE ONE UNIFORM SCALE OFF WHAT THE GENERATOR RETURNED, AND THE
-- SCALE WAS CHOSEN TO PIN THE WIDTH. The generation came back 10.230 across
-- and every other number in this game -- the lawn slot grid, the fence
-- clearances, `STEAL_RANGE` measured to the body centre -- was cut against a
-- pig 11.870 across, so the scale is 11.870 / 10.230 = 1.16031 and nothing
-- that measures ACROSS the pig moved. Uniform rather than per axis, because
-- the proportions are what make it read as a pig: squashing it back into the
-- old body's box would have cost 25% of its length and undone the one thing
-- the regeneration was for.
--
-- WHAT DID MOVE IS HEIGHT AND LENGTH, and that is a real bill rather than a
-- footnote. Measured: lawn y 0.500 unchanged, crown y 12.145 against the old
-- 14.256, tail reach z -8.249 against -7.220, snout reach z 9.155 against
-- 7.100. So this pig is two studs lower and four studs longer, and every
-- accessory anchor, the vault dial's own push and the coin pile were
-- re-derived against it rather than inherited.
--
-- The model also arrives YAWED -- this one by -52.13 degrees, on all four
-- parts alike -- so the offsets here are taken after undoing that and after
-- turning the snout onto +Z, which is the direction every other model in
-- this project is authored to face.
-- THE BODY IS ONE MODELLED MESH NOW, NOT FOUR GENERATED ONES, AND THAT COSTS
-- THE TRIM COLOUR.
--
-- Every generated body this project has stood up carried the same two faults:
-- features nobody asked for (cheek nubs, a raised disc on the snout) that no
-- amount of seating could reach, and a segmentation socket wherever a part
-- came off. `segmentation: "explicit"` bought the ear/snout/tail as separate
-- MeshParts -- which is what gave 46 skins their second tone -- and paid for
-- it with a hole in the rump and a face that had to be shaved.
--
-- This body is a modelled piggy bank cut in Blender: the vault hatch and the
-- coin slot are real openings bored through the shell, the cheeks are clean,
-- and there is nothing to cap because nothing came off.
--
-- WHAT IT COSTS, STATED PLAINLY: IT IS A SINGLE MESHPART, SO IT HAS ONE
-- `Color`. The file carries two materials -- the body, and the eyes and
-- nostrils as a mirrored set of four patches -- and Roblox's 3D importer
-- MERGED them rather than splitting them into two parts. So the trim tone
-- every skin is authored in has nothing to attach to today, and the face is
-- carried by the code-built `Eye` and `Nostril` parts seated on the model's
-- own eye and nostril patches (see `MESH_FACE` in PiggyBank).
--
-- Getting the second tone back means splitting the ears and snout into their
-- own OBJECT in Blender -- not merely their own material, which is what the
-- importer just merged away -- and importing that as a second MeshPart. That
-- is one more upload under the developer's own account, which this file
-- records as the most expensive mistake in it, so it is a decision rather
-- than a tidy-up.
-- THE PIG IS TWO OBJECTS AGAIN, AND THAT IS THE WHOLE REASON IT WAS
-- REMODELLED RATHER THAN RESEATED.
--
-- The entry this replaces recorded the cost of the last body in as many
-- words: it was ONE MeshPart, so it had one `Color`, so the second tone all
-- 48 skins are authored in had nothing to attach to. Roblox's importer merges
-- MATERIALS into a single part and splits on OBJECTS -- so a trim material
-- was never going to survive, and the fix was never a seating number.
--
-- `blender/pig/build_pig.py` builds this one as a PAIR from the first vertex:
-- `Body` is the shell, `Trim` is the ears, snout, legs and tail. Two objects,
-- one .obj, two MeshParts, and `applySkin` paints the second exactly as it
-- did on the primitives pig. Nothing about the skin system moves.
--
-- THE OPENINGS ARE CUT IN BLENDER, so there is no run-time CSG anywhere near
-- this. The body is a hollow shell with a 0.30-stud wall and the vault hatch
-- and coin slot are bored through it, which is what `swapToMesh` already
-- turns `DoubleSided` on to read. The hatch is not placed by eye either: it
-- is solved against `dialCFrame`'s own axis, so the lock plate seats over its
-- own hole by construction rather than by somebody matching two numbers.
--
-- THE SCALE IS DERIVED. `PiggyBank.BODY_R` is 6 and the model's own half
-- width is 1.00, so the export runs at exactly 6.0 -- which makes the sphere
-- the whole of PiggyBank is solved against LITERALLY TRUE of this body. The
-- semi-axes come out 6.00 / 6.48 / 5.76 studs against that 6, where the last
-- body missed it by up to 2.2 and left 22 pattern skins seating their spots
-- in mid-air.
Config.PIGGY_MESH = {
	{
		part = "Body",
		trim = false,
		-- PASTE THE ID FROM THE STUDIO IMPORT HERE. An empty id makes
		-- `Config.piggyMesh` return nil for the WHOLE spec, so the pig stays on
		-- primitives rather than standing up half a mesh -- which is the right
		-- way round: a missing id is a pig that looks old, not a pig with no
		-- ears.
		-- 81131525639524 is the SEAM-FIXED body. The bounds did not move --
		-- 12.0000 x 11.5200 x 12.7930, byte-identical to the last one -- so
		-- nothing seated against this pig had to be re-derived, and the ID
		-- CHANGING IS THE ONLY EVIDENCE THE MESH DID: Roblox deduplicates
		-- identical uploads, so a new id proves a new mesh and an unchanged
		-- one would have proved the export never took.
		id = "88003051962029",
		-- Measured off the exported mesh, not typed. `offset.Y` is where the
		-- body's own bounding-box centre lands once the LEGS are standing on
		-- the slab at 0.5, and the Z is not zero because the vault hatch takes
		-- a bite out of the rump and moves that centre forward.
		offset = Vector3.new(0.0000, 6.6200, 0.0835),
		size = Vector3.new(12.0000, 11.5200, 12.7930),
		-- A HALF TURN, BECAUSE THE IMPORTER MIRRORS Z AND NOTHING SAYS SO.
		-- Recorded on the last body and kept: the .obj is authored snout at +Z,
		-- vault at -Z, and it arrives facing the other way, which puts the dial
		-- on the pig's face and the eyes inside its rump. Only a photograph
		-- catches it. If a future import comes in unmirrored this is the line
		-- to drop -- from BOTH entries, or the two parts face opposite ways.
		rot = CFrame.Angles(0, math.pi, 0),
	},
	{
		part = "Trim",
		trim = true,
		id = "91960729236102",
		-- The trim reaches further back than forward -- the tail curls out past
		-- the rump by more than the snout stands off the face -- so its centre
		-- sits behind the body's.
		offset = Vector3.new(0.0000, 7.4869, -0.2544),
		size = Vector3.new(9.3379, 13.9739, 17.0759),
		rot = CFrame.Angles(0, math.pi, 0),
	},
}

-- THE TRIM CAN BE FOUR PARTS INSTEAD OF ONE, AND IT IS ALL-OR-NOTHING.
--
-- `Trim` above is the snout, the ears, the legs and the tail welded together,
-- which is one MeshPart and therefore ONE `Color`. That covers 45 skins,
-- where the second tone is a single colour. It cannot express the bumblebee:
-- the reference has a yellow face against black ears, and no texture map
-- helps, because the map is the BODY's pattern and a trim part wears a flat
-- colour by design.
--
-- `blender/pig/build_pig.py` cuts these four out of the finished trim rather
-- than building them separately, so each carries the exact surface, normals
-- and UVs the joined trim carries -- and it still exports `pig_trim.obj`, so
-- the one-part pig stays a working configuration.
--
-- ALL FOUR OR NONE, WHICH IS THE SAFETY PROPERTY. `piggyMesh` uses these only
-- when every one of them has an id; a single blank falls back to `Trim`
-- whole. The alternative -- skipping blanks individually -- is a pig missing
-- its ears with nothing in any log, which is exactly the failure the Body's
-- own "an empty id makes the WHOLE spec nil" rule exists to prevent, one
-- level down.
--
-- The numbers are measured by `build_pig.py` and printed under
-- "PASTE INTO Config.PIGGY_MESH (split trim)" on every build. Typing one by
-- hand is how a part ends up describing a body that no longer exists.
Config.PIGGY_TRIM_PARTS = {
	{
		part = "Snout",
		trim = true,
		id = "",
		offset = Vector3.new(0.0000, 5.8455, 4.7200),
		size = Vector3.new(6.7845, 7.2333, 7.1272),
		rot = CFrame.Angles(0, math.pi, 0),
	},
	{
		-- BOTH EARS IN ONE MESH, because they are always the same colour and a
		-- second upload to say so would be one too many. `PiggyBank` reads
		-- `Ears` here and `Ear` on the primitives pig, so neither had to be
		-- renamed.
		part = "Ears",
		trim = true,
		id = "",
		offset = Vector3.new(0.0000, 11.8885, 2.1541),
		size = Vector3.new(9.3379, 5.1706, 2.3399),
		rot = CFrame.Angles(0, math.pi, 0),
	},
	{
		part = "Legs",
		trim = true,
		id = "",
		offset = Vector3.new(0.0000, 2.0000, -0.1800),
		size = Vector3.new(8.6400, 3.0000, 8.7600),
		rot = CFrame.Angles(0, math.pi, 0),
	},
	{
		part = "Tail",
		trim = true,
		id = "",
		offset = Vector3.new(-0.0577, 9.5579, -6.5721),
		size = Vector3.new(2.9926, 3.0000, 4.3698),
		rot = CFrame.Angles(0, math.pi, 0),
	},
}

-- ============================================================
-- WHERE THE MESH PIG'S FACE IS
-- ============================================================
--
-- Read by `PiggyBank`, which seats the eyes, the nostrils and the plaster on
-- the twelve-stud pig standing on a lawn, AND by `PiggyModel`, which builds
-- the same mesh at preview size for the victim shelf, the inventory and the
-- crate reel. It lived in PiggyBank while that was the only pig; a second
-- copy for the mini would be two answers to "where are a pig's eyes" on one
-- asset, drifting silently the first time either was touched.
--
-- Every coordinate is in the PLOT-SEAT frame the mesh spec above uses, so a
-- preview scales these by exactly the factor it scales the mesh by.
Config.PIGGY_MESH_FACE = {
	-- Body-local centre of the mesh body, so a seat can be turned to face it.
	bodyCentre = Vector3.new(0, 6.6200, 0),
	-- THE MODELLED BODY CAME WITH ITS OWN EYES AND NOSTRILS, as a second
	-- material carrying four mirrored patches -- and the importer merged that
	-- material into the body, so they are invisible. What they still give is
	-- the one thing guesswork could not: WHERE the person who modelled this
	-- pig put its face. Measured off those patches, the eyes centre on
	-- (+/-1.630, 8.346) with the skin at z 5.118, and the nostrils on
	-- (+/-0.326, 6.667) with the skin at 6.428.
	--
	-- The 1.25-stud ball keeps its 0.14 of sink, so it shows about half a
	-- stud of disc exactly as it did on the generated body.
	eye = { x = 1.909, y = 8.802, z = 5.333 },
	-- AND THE NOSTRILS ARE BACK, because the reason they were dropped has
	-- gone. On the generated snout they were two black boxes standing on a
	-- smooth dome and read as bricks stuck to the nose at every depth tried.
	-- This snout has nostril patches modelled INTO it, so a dark block seated
	-- 0.05 proud sits in a hollow the model already has rather than on a
	-- curve that has nothing to hold it.
	-- Seated at the FLOOR of the dimples the snout is modelled with, pushed
	-- forward by half the block's own depth so it hangs just inside the
	-- hollow. A dark block in a dent reads as a nostril; the same block on a
	-- smooth dome reads as a brick stuck to the nose, which is what retired
	-- them on the generated snout.
	--
	-- AND THE Z WAS WRONG BY 0.89 STUDS, WHICH IS MOST OF THE BLOCK'S OWN
	-- DEPTH -- so the nostrils have been sunk almost entirely INSIDE the
	-- snout, which is why a pig with black nostrils read as having none.
	--
	-- `build_pig.py` computes this seat from the snout's own surface point,
	-- held in a local called `surf` -- and three hundred lines below that, the
	-- EYE PREVIEW loop writes `surf, n = ...` at module scope, once per eye.
	-- So the expression that prints this number had been reading the last
	-- eye's surface point rather than the snout's ever since the preview was
	-- added: -0.9257 against a true -1.0740, which is 0.8903 studs once
	-- scaled. Both are plausible points on the same body, nothing errors, and
	-- the arithmetic either side of it is correct.
	--
	-- The shadowing family this file already records for `legRoll` and the
	-- cylinder axis, in its quietest form. The builder holds `SNOUT_SURF` now
	-- and prints the delta on every run so the correction cannot silently
	-- reverse.
	nostril = { x = 1.050, y = 6.689, z = 7.354 },
	-- THE NOSTRILS ARE GONE ON THE MESH PIG, and there is no seat for them
	-- here because there is no part left to seat. They were a Block 0.50 by
	-- 0.95 by 0.40, which works on the ball pig's CYLINDER snout -- a flat
	-- face, where a dark box standing a third of a stud proud reads as a
	-- dent. The generated snout is domed and smooth, and the same two boxes on
	-- it read as black rectangles stuck to the pig's nose at every depth they
	-- were tried at, flush included. Reported as exactly that.
	--
	-- The primitives piggy keeps them; `swapToMesh` destroys them alongside
	-- the snout and the ears it replaces. If the snout ever wants nostrils
	-- back they are a CUT, like the vault and the coin slit -- a hole in a
	-- surface, not a solid stuck on one.
	-- The plaster is placed BY DIRECTION on the ball; the same direction hits
	-- the mesh's forehead at body-local (0, 4.52, 5.69), and it keeps the
	-- original's 0.06 of sink so the strip's middle beds into the curve.
	plaster = Vector3.new(0, 10.422, 4.783),

	-- THE SPHERE A SKIN'S PATTERN IS PLACED ON, which is NOT the body's own
	-- bounding-box centre -- 8.5 against the body's 6.62. `applyPattern`
	-- places every mark by DIRECTION on a sphere, and this is the sphere that
	-- makes a stripe land where a stripe should on this particular animal.
	--
	-- A COPY of `PiggyBank`'s `BODY_Y` and `BODY_R`, on the same terms as
	-- `SHOP_ROOM.vaultDoorNearX`: Config requires nothing and is not about to
	-- start requiring a service for two numbers. MOVE EITHER AND MOVE BOTH --
	-- the lawn pig and the preview pig have to agree about where a pattern
	-- goes, and the failure is a stripe in a different place on the same skin
	-- depending on which menu you are looking at.
	patternCentre = Vector3.new(0, 8.5, 0),
	patternRadius = 6,

	-- The eyeball the lawn pig seats. A preview scales it with everything
	-- else, so the mini's eyes are the same eyes at the same sink.
	eyeSize = 1.25,
}

-- THE VAULT HATCH IS A REAL BORE AGAIN, AND THE OLD "ANY SUBTRACT BREAKS THIS
-- MESH" FINDING DID NOT SURVIVE THE NEW BODY.
--
-- That finding is real and it is recorded at length: on asset 82135918153310
-- a through-bore, a blind recess and the coin slit each independently stopped
-- the body being drawn at all from a camera behind it, with every geometric
-- measurement agreeing with the version that worked. It was a fact about ONE
-- ASSET rather than about `SubtractAsync`. Re-tested on this body from the
-- same cameras: cut and uncut render identically, and the bore shows the
-- hollow interior with the coin pile behind it.
--
-- `depth` IS MEASURED INWARD FROM THE SKIN AND WAS FOUND BY LOOKING, which is
-- the only instrument that can see a CSG hole -- rays hit the collision hull
-- and a bounding box barely moves. Three depths cut side by side and
-- photographed: 2.0 leaves a shallow DISH (the shell is thicker than it looks
-- once the body is scaled up), 3.5 breaks through cleanly, 6.0 is past the
-- point of buying anything. The shell is not thin here, so grazing it leaves
-- a ragged lip rather than an opening.
--
-- THE RADIUS IS NOT HERE ON PURPOSE. `PiggyBank.VAULT_R` already derives it
-- as `LOCK_TIERS[1].radius - VAULT_COVER`, so the cheapest lock plate covers
-- the hole by construction, and a second copy of that number in this file is
-- the near-identical duplicate that drifts the first time either is touched.
-- This table carries only what is a fact about the CUT.
Config.PIGGY_VAULT = {
	depth = 3.5,
	-- Where the cutter's OUTER face starts, well clear of the skin, so the
	-- mouth of the bore is the pig's own surface rather than a cutter edge.
	standOff = 2.5,
}

-- AND TWO NUBS UNDER THE EYES COME OFF IN THE SAME SUBTRACT.
--
-- The generation left a small hard-edged lump on each cheek, just below and
-- outboard of the eye -- reported as "little extrusions under the eyes", and
-- that is exactly what they are. They are in the MESH, so no amount of moving
-- parts around reaches them, and nothing in the seating numbers was wrong.
--
-- FOUND BY SWEEPING THE FACE RATHER THAN BY EYE, because a lump on a smooth
-- dome has no landmark to measure against. Raycasting a grid across the front
-- of a probe body and printing how far forward the skin reaches, the face
-- falls away smoothly everywhere except one square: at body-local y 2.4 the
-- surface runs 7.44 at x 1.4, jumps to 7.56 at x 1.6, holds that to x 2.0 and
-- drops to 7.17 at x 2.2. A step of nearly half a stud across one sample is
-- not a curve, it is an EDGE -- which is why it catches the light as a nub.
-- Interpolating the neighbours puts the true skin near 7.32 there, so the
-- lump stands about a quarter of a stud proud.
--
-- A SPHERE RATHER THAN A BOX, AND A SMALL ONE. A box leaves a flat facet with
-- a hard rim, which is the same fault one notch quieter. A sphere tangent to
-- the skin cuts a shallow scoop that tapers to nothing at its own edge.
--
-- AND THE RADIUS IS THE WHOLE OF IT: THE FIRST ONE WAS 2.5 AND PUT A WINDOW
-- THROUGH THE PIG'S FACE. The arithmetic said it would stay a stud across --
-- the sphere lifts only 0.07 by 0.6 studs out, against a face falling three
-- times faster -- and that is true of the DEPTH and says nothing about the
-- REACH. A 2.5 ball centred on the cheek spans x -0.68 to 4.32 and y -0.18 to
-- 4.82, which runs straight into the socket the EAR plugs. It did not cut a
-- deep hole; it shaved the thin shell beside an opening that was already
-- there, and the coin pile showed through the result.
--
-- MEASURE THE CUTTER AGAINST WHAT ELSE IT TOUCHES, NOT ONLY AGAINST WHAT IT
-- IS AIMED AT. The lump is 0.55 by 0.35, so the cutter is sized to it: at
-- 0.8 the scoop is confined to about half a stud either side and comes
-- nowhere near the ear.
--
-- MIRRORED ON X from one entry rather than listed twice, so the two cheeks
-- cannot drift apart.
Config.PIGGY_SHAVE = {
	radius = 0.8,
	-- Where the cutter's surface touches: the skin the lump stands on.
	tangent = 7.33,
	at = Vector3.new(1.82, 8.897, 0),
}

-- THE COIN SLIT IS SUBTRACTED OUT OF THE BODY, SO IT IS A REAL HOLE.
--
-- It used to be a black BOX seated inside the body, which is the only thing
-- that works on a sphere: the primitives piggy's dome tops out at 14.50, so a
-- box reaching 14.425 sat under the surface and showed as a dark slit only
-- where its ends broke the curve. The mesh body's crown is 14.14, so the same
-- box stood a third of a stud PROUD along its whole length and read as a bar
-- lying on the pig's back.
--
-- `SubtractAsync` WORKS ON A MESHPART AND HANDS BACK A MESHPART, which is the
-- finding that made this possible and is not what this project's notes said.
-- Everything written here about CSG assumed a `UnionOperation` -- a different
-- class, with a simplified collision hull and no `MeshId`. Measured: 284 ms,
-- the result is a MeshPart, and `Size` and `Position` come back byte-identical
-- to the source, so the seating numbers above did not move.
--
-- THE CUT IS MADE ONCE ON THE TEMPLATE AND CLONED, never per piggy: 284 ms
-- times eight plots is two and a half seconds of server start to say one
-- thing, and the template cache was already there for exactly this reason.
--
-- SIZED AGAINST THE CUT RATHER THAN INHERITED. The shipped 0.7 x 4.2 was
-- chosen while it was mostly buried; as a real opening it gouged a third of
-- the pig's length. Three candidates were built and looked at side by side --
-- 0.70x4.20 deep 1.54, 0.55x3.00 deep 0.89, 0.45x2.40 deep 0.64 -- and the
-- middle one is the only one that reads as a slot from the pavement without
-- reading as damage up close.
-- AND ALL OF THAT IS RETIRED, BECAUSE THE SUBTRACT BROKE THE BODY'S
-- RENDERING. Cut, the piggy is not drawn at all from a camera directly
-- behind it -- see the long note in `PiggyBank.ensureMeshTemplates`, where
-- the through-bore, a blind recess and this slit on its own were each
-- measured breaking it. The openings are drawn parts again and their
-- numbers live in `PiggyBank` beside the mesh's other seating corrections,
-- because they are facts about one generated asset rather than tunables.
--
-- The two tables are left here as a headstone rather than deleted outright:
-- the shapes and the reasoning above are the record of what was tried, and
-- the first instinct on reading that the hatch is a drawn disc again will be
-- to reach for CSG.

-- AND THE VAULT HATCH IS BORED OUT FOR REAL TOO, WHICH RETIRES THE RIM.
--
-- The opening on the back was twelve box segments standing proud around a
-- near-black disc -- the moat's kerb trick, and the only thing available while
-- nothing could be dug: the eye takes the highest line as the surface, so a
-- lip AROUND the dark reads as depth.
--
-- IT CANNOT WORK ON THE MESH, and the reason is measurable rather than a
-- matter of taste. That ring is twelve FLAT segments, which can only lie
-- true on a SPHERE. Measured around the ring on the mesh body, the surface
-- runs from 0.45 studs ABOVE the seat plane to 0.27 BELOW it -- a spread of
-- 0.72 -- so a third of the segments were buried and the rest stood off the
-- pig. No offset fixes that; the back is simply not a sphere. The whole dial
-- sits 0.174 inside the surface for the same reason: `dialCFrame` solves a
-- point on a 6.00 sphere and the mesh is 6.174 out there.
--
-- So the recess is CUT, in the same subtract as the coin slit, and the pig's
-- own surface becomes the lip. The dark disc stays -- it is what makes the
-- opening read as open rather than as a dent -- reseated onto the floor of
-- the bore instead of standing proud of a surface it no longer matches.
--
-- AND IT IS OPEN RATHER THAN FLOORED, WHICH IS THE COIN SLIT'S OWN ANSWER.
-- The first cut kept the near-black disc on the floor of a shallow bore. That
-- is still the moat trick wearing a smaller hat: a dark thing standing in for
-- an opening. The slit in the crown has nothing in it at all, and the vault
-- is the same object, so it gets the same treatment.
--
-- THE BODY IS A THIN SHELL, AND THAT IS THE MEASUREMENT THAT DECIDES THE
-- DEPTH. Cut against a bright backdrop at four depths: 0.15 leaves a solid
-- floor, and 0.25, 0.35 and 0.45 all show the backdrop THROUGH the pig. So
-- the wall is about two tenths of a stud there, and there is no depth that
-- is both a real opening and a closed one -- which also explains the slit,
-- whose 0.89 goes clean through and reads as gold in game because what is
-- behind it is the coin pile.
--
-- 0.60 is chosen to clear the wall outright rather than to graze it: a
-- partial break-through leaves a ragged lip where the cutter skims the inner
-- surface, and the cutter only removes material OUTWARD of the floor, so
-- going deeper cannot reach the far wall.
--
-- `radius` clears the largest tier's plate (DIAL_MAX_R 1.95) by 0.15, so a
-- gold-locked piggy is a door sitting IN a hole rather than a disc covering
-- one. `floor` is measured in from the seat plane along the dial's own axis.
-- (retired with PIGGY_SLOT above)

-- Nil unless EVERY part has an id, because a partial mesh piggy is worse than
-- none: the body would arrive smooth with the old wedge ears and cylinder
-- snout still stuck to it, which reads as a broken model rather than as an
-- unfinished setting. All or nothing is the honest state.
-- ============================================================
-- THE FUR MESH -- RAISED FUR, WORN BY SOME SKINS AND NOT OTHERS
-- ============================================================
--
-- A SEPARATE PART BECAUSE THE BODY IS ONE ASSET WORN BY FORTY-SIX SKINS.
-- Fur modelled into the body would grow on the Solid Gold pig and on all
-- twenty-two neon ones, so the only route to fur that belongs to SOME skins
-- is geometry that can be taken off -- which is what the trim parts already
-- are, and this rides the same mechanism.
--
-- IT IS THE SILHOUETTE AND THE MAP IS THE SURFACE, and neither substitutes
-- for the other. `pig_fur_normal` gives the coat its grain; a normal map
-- cannot make an OUTLINE fuzzy, because it does not move a single vertex. So
-- the fluff a player actually reads from the pavement is these 6,080
-- triangles and nothing else. Measured the other way too: at street distance
-- the normal map contributes nothing visible at all.
--
-- 152 LOBES RATHER THAN THOUSANDS OF STRANDS, and that was arrived at by
-- building the other two. A ten-to-one cone is a QUILL -- reported as "these
-- are big spikes". A short blunt nub half a stud across is a CRUMB: 724 of
-- them read as breakfast cereal stuck to the pig, because at that size every
-- piece is a separate object the eye can count. THERE IS A FLOOR ON A PIECE
-- OF GEOMETRY -- it has to be big enough to be a SHAPE -- so these are
-- squashed domes 1.2 to 1.9 studs across, overlapping into one mass the way
-- a sheep or any plush toy is drawn. It is also the cheaper of the three.
--
-- THE SIZE AND OFFSET ARE MEASURED AGAINST THE BODY'S OWN EXPORT rather than
-- typed, and that check caught a real one: `make_fur_tufts.py` exported in
-- BLENDER UNITS while `build_pig.py` exports in studs, so the mesh was 2.04
-- across instead of 12.24 -- a sixth of the size, which would have imported
-- as a pea and cost an upload to discover. Nothing errors either way and
-- neither file looks wrong alone; only measuring the two exports AGAINST EACH
-- OTHER finds it.
-- THESE TWO GO STALE THE MOMENT THE MESH IS REBUILT, AND THEY DID. They were
-- measured off the WOOL version and left behind when the tufts were reshaped
-- three times -- so `Size` squashed the mesh to 0.88 x 0.92 of itself, which
-- pulls every tuft INWARD toward the cloud's own centre and buries them in the
-- pig. Reported as "fur tufts generated inside of the pig", and it is exactly
-- that: a MeshPart is scaled to whatever `Size` it is given, so a stale size
-- is a silent shrink rather than an error.
--
-- `PiggyBank` DOES NOT WRITE `Size` ANY MORE -- the mesh comes in at its own
-- natural size and this field is a CHECK instead, warned about on mismatch.
-- The offset still has to be carried, because Roblox recentres an imported
-- mesh on its own bounding box and cannot tell you where that sat in Blender.
-- `make_fur_tufts.py` prints both lines ready to paste on every build.
-- THERE IS MORE THAN ONE MANE NOW, AND THE SINGLE MESH WAS WHY EVERY FURRED
-- ANIMAL LOOKED LIKE THE SAME ANIMAL IN DIFFERENT PAINT.
--
-- One `FUR_MESH` meant the tiger, the leopard and anything else that ever
-- wanted fur wore the identical ruff-and-brisket. The reference plush zebra
-- has no ruff and no brisket at all -- it carries a short upright BRUSH on
-- the crown and nothing else -- and there is no parameter on a single mesh
-- that can express that.
--
-- IT IS A TABLE OF SETS RATHER THAN A FIELD ON EACH SKIN, for the reason
-- `SURFACE_PACKS` is: two animals share a mane far more often than they need
-- their own, so the shared thing is named once and pointed at. A skin picks
-- one with `furSet`; leaving it off means `DEFAULT_FUR_SET`, so all four
-- existing furred skins are untouched by this table existing.
--
-- EACH SET IS ITS OWN UPLOAD, which is the honest cost and the reason not to
-- add one per animal. `make_fur_tufts.py` builds them -- `FUR_SET=mane` and
-- `FUR_SET=crest` -- and prints the size/offset block for each.
Config.FUR_SETS = {
	-- The full ruff: a parted crest over the crown, a sweep down each cheek
	-- and a brisket across the chest. 36 tufts, 900 triangles.
	mane = {
		id = "79359659715894",
		size = Vector3.new(13.9434, 12.9934, 10.7314),
		offset = Vector3.new(0.1801, 7.1895, 1.0574),
	},
	-- The zebra's forelock: one short upright band between the ears. 7 tufts,
	-- 175 triangles -- a fifth of the mane, because it is a fifth of the fur.
	--
	-- ID PENDING THE IMPORT of `blender/pig/pig/pig_fur_crest.obj`. An empty id is
	-- a pig with no tuft rather than an error, which is the same contract the
	-- body and the mane already keep -- so this can sit here unfilled and the
	-- zebra simply wears no fur until it is uploaded.
	crest = {
		id = "",
		size = Vector3.new(2.1927, 2.3579, 3.0955),
		offset = Vector3.new(0.1497, 12.2011, 2.4288),
	},
}

-- The set a skin gets when it does not name one. Not a literal at the call
-- site: `applyFur` and `furMesh` both need it, and two copies of a default is
-- how one of them ends up pointing at a set that was renamed.
Config.DEFAULT_FUR_SET = "mane"

-- The fur mesh for a named set, or nil. Same contract as `piggyMesh`: an
-- empty id is a pig with no fur rather than an error, so a set can sit here
-- unuploaded and the skins that want it simply go bare.
--
-- AN UNKNOWN SET NAME IS ALSO NIL RATHER THAN A THROW, and deliberately not a
-- fall back to the default. A skin naming a set that does not exist is a typo,
-- and quietly handing it the mane would put the tiger's ruff on a zebra with
-- nothing in any log -- the silent-wrong-thing this file refuses everywhere
-- else. No fur is visibly missing and gets reported.
function Config.furMesh(setName: string?): { any }?
	local set = Config.FUR_SETS[setName or Config.DEFAULT_FUR_SET]
	if not set then
		return nil
	end
	local id = set.id
	if type(id) ~= "string" or id == "" then
		return nil
	end
	-- THE OFFSET IS HANDED BACK RELATIVE TO THE BODY, not to the plot, and
	-- the body entry is FOUND rather than indexed. Both meshes are measured
	-- in one Blender scene, so the difference of the two offsets is where the
	-- fur sits on the animal -- and doing that subtraction here keeps it
	-- beside the table it reads, where `PiggyBank` cannot get it wrong.
	-- `PIGGY_MESH[1]` happens to be the Body today; a reordered table would
	-- have seated the ruff off an ear with nothing erroring.
	local bodyOffset = nil
	for _, entry in ipairs(Config.PIGGY_MESH) do
		if entry.part == "Body" then
			bodyOffset = entry.offset
			break
		end
	end
	if not bodyOffset then
		return nil
	end
	return {
		id = if id:match("^%d+$") then "rbxassetid://" .. id else id,
		size = set.size,
		offset = set.offset - bodyOffset,
	}
end

-- True when every split trim part has been uploaded. All four or none -- see
-- `PIGGY_TRIM_PARTS`.
function Config.trimIsSplit(): boolean
	for _, entry in ipairs(Config.PIGGY_TRIM_PARTS) do
		if type(entry.id) ~= "string" or entry.id == "" then
			return false
		end
	end
	return true
end

function Config.piggyMesh(): { any }?
	local split = Config.trimIsSplit()
	local rows = {}
	for _, entry in ipairs(Config.PIGGY_MESH) do
		-- THE JOINED TRIM IS DROPPED ONLY WHEN ALL FOUR PIECES CAN REPLACE IT,
		-- so the pig is never standing there with neither.
		if not (split and entry.part == "Trim") then
			table.insert(rows, entry)
		end
	end
	if split then
		for _, entry in ipairs(Config.PIGGY_TRIM_PARTS) do
			table.insert(rows, entry)
		end
	end

	local out = {}
	for _, entry in ipairs(rows) do
		local id = entry.id
		if type(id) ~= "string" or id == "" then
			return nil
		end
		table.insert(out, {
			part = entry.part,
			trim = entry.trim,
			-- A bare number or a full rbxassetid, because whichever Studio
			-- hands over is the one somebody will paste.
			id = if id:match("^%d+$") then "rbxassetid://" .. id else id,
			offset = entry.offset,
			size = entry.size,
			rot = entry.rot,
		})
	end
	return out
end

-- ============================================================
-- THE WORLD'S SURFACES AND SCENERY
-- ============================================================
--
-- Same shape as the piggy mesh above and for exactly the same reason: ids in
-- a table, an accessor that returns nil until they are filled in, and a
-- builder that falls back to what shipped. A fresh empty place plus this repo
-- still gives the identical world; it just gives a better looking one once
-- the assets exist.

-- A bare number or a full rbxassetid, because whichever the Creator Dashboard
-- or Studio hands over is the one somebody will paste. Declared ABOVE both
-- readers -- a `local` written under a function that calls it is a nil global
-- to that function, which this file has now recorded nine times.
local function assetId(id: any): string?
	if type(id) ~= "string" or id == "" then
		return nil
	end
	if id:match("^%d+$") then
		return "rbxassetid://" .. id
	end
	return id
end

-- ------------------------------------------------------------
-- THE LAWN
-- ------------------------------------------------------------
--
-- GRASS IS NOT A MESH PROBLEM, which is the whole reason the lawn is a
-- MaterialVariant rather than another entry in the mesh table below. The pig
-- is one object twelve studs across; the ground is a single 780x560 Part and
-- the lawns are slabs. There is no geometry to replace out here, only a
-- surface, and Studio's material generator is the counterpart to its mesh
-- generator for exactly that job.
--
-- THERE IS NO TEXTURE ON IT TODAY, AND EVERYTHING BELOW IS WHAT A FUTURE ONE
-- WOULD HAVE TO OBEY. The lawn was a generated MaterialVariant for one
-- session; the ground is flat colour now and `name` is empty. The reasoning
-- was kept rather than deleted with the asset, because all of it is still
-- true and the next person to reach for a ground texture needs it.
--
-- A MATERIALVARIANT CANNOT BE BUILT AT RUN TIME. Its properties are
-- capability-gated: `Instance.new("MaterialVariant")` followed by a write to
-- `BaseMaterial` throws *The current thread cannot write 'BaseMaterial'
-- (lacking capability Plugin)* from a real Script. The first build of this
-- did precisely that, in WorldService, and it PASSED every check run through
-- the MCP sandbox and the command bar, because both of those run WITH plugin
-- capability. It failed the first time it ran in an actual server.
--
-- That is the third entry in the same family as `RenderFidelity` and
-- `RegisterKeyframeSequence`: an API that works everywhere except in the
-- game. Anything capability-gated has to be exercised from a real Script
-- before it is believed, because the environment that proves it works is the
-- one environment that is not the game.
--
-- SO A VARIANT HAS TO BE OWNED BY ROJO, as a `.model.json` under
-- `src/MaterialService/` with a matching branch in `default.project.json`.
-- That keeps the property this entire repo is built on -- a fresh empty place
-- plus this repo gives the identical world -- without a runtime write that
-- can never succeed, and it keeps the asset out of the place file where
-- nothing reconciles it and the `GearPreview` trap lives. Note the project
-- file is NOT hot reloaded: adding that branch needs `rojo serve` restarting.
--
-- THE MAPS WOULD LIVE THERE AND ONLY THE NAME HERE, because the name is the
-- only part of it any Luau in this game needs to say. Two copies of four
-- asset ids is the near-identical duplicate that drifts the first time either
-- is touched, which this file has recorded for the mini piggy,
-- `Decor.buildOne` and `RideSound`.
--
-- A DANGLING NAME IS SAFE, and that is load-bearing RIGHT NOW rather than
-- hypothetically: a `MaterialVariant` property naming something
-- MaterialService does not hold falls back to the part's own BaseMaterial.
-- That is exactly what the empty `name` below relies on, and it is why the
-- three services can write it unconditionally without asking whether any
-- variant exists.
--
-- IT WOULD BE OPT-IN PER PART, NEVER A `MaterialService` OVERRIDE. Setting
-- `MaterialService.Grass` repaints every Grass part in the game in one write
-- -- the topiary pig on somebody's lawn, the shop hedge, the flower bed on a
-- house tier -- and a lawn texture tiled every ten studs across a one-stud
-- prop is a smear.
--
-- AND IT MULTIPLIES AGAINST `Part.Color` LIKE ANY OTHER TEXTURE, which is
-- the fact that ended the experiment: twelve generated candidates all pulled
-- the shipped LAWN tint down into a muddy olive, and the FLAT slab was the
-- only one in the comparison showing the actual colour. The pig's texture
-- lesson, arriving on a surface. Anything put here gets looked at ON the lawn
-- colour rather than on white, because what the eye reads is the product of
-- the two.
--
-- ONE FURTHER WARNING BEFORE GENERATING A REPLACEMENT: `generate_material`
-- publishes SIXTEEN images per call to the developer's own Roblox account,
-- and doing it a dozen times got that account moderated. See CLAUDE.md.
Config.GRASS_MATERIAL = {
	-- WHAT THE GROUND IS MADE OF, and the pair is the whole dial. `material`
	-- is the base; `name` is a MaterialVariant to lay over it, or "" for
	-- none. Switching the whole street between a flat ground and any
	-- generated texture is these two lines and nothing else -- which is the
	-- reason they are a pair rather than three services each naming a
	-- material of their own.
	--
	-- FLAT IS THE DEFAULT, AND THAT IS A REVERSAL OF THE FIRST BUILD. This
	-- shipped as a generated painted grass, and painted is not the same thing
	-- as CARTOON: measured against the four candidates and then four more, all
	-- eight read as a good photograph of a lawn rather than as a drawing of
	-- one. What settled it is that A TEXTURE HERE CAN ONLY DARKEN. A material
	-- multiplies `Part.Color`, so every one of the eight pulled the lawn down
	-- into a muddy olive and the FLAT slab was the only one in the comparison
	-- showing the actual `LAWN` green -- bright, pastel and cheerful, which is
	-- the thing being aimed at.
	--
	-- IT IS ALSO ONLY AFFORDABLE BECAUSE THE TUFTS EXIST. A flat plane on its
	-- own is a solid colour field, and the entry below about silhouette is
	-- what makes that fine: the detail moved off the ground and onto the
	-- geometry standing in it. Flat ground plus real blades is the stylised
	-- look; flat ground alone would just be a bare one. Do not turn this back
	-- to flat-with-no-grass.
	--
	-- The generated variants are all still uploaded and any of them is one
	-- `.model.json` away -- `PiggyLawn` is the painted one this shipped with
	-- first. Anything put back here gets looked at ON the lawn colour rather
	-- than on white, because what the eye reads is the product of the two.
	material = Enum.Material.SmoothPlastic,
	name = "",
}

-- ------------------------------------------------------------
-- THE TREE
-- ------------------------------------------------------------
--
-- Twenty-six of these stand in the grove behind the plots -- counted on a
-- live server rather than estimated, because the number decides whether the
-- template cache below is worth having. They close the view behind every
-- plot, which makes them the largest single thing in anybody's picture of
-- this street after the grass itself. What shipped was a brown box with a
-- green ball balanced on it, which from the pavement reads as a lollipop.
--
-- IT KEEPS ITS BAKED TEXTURE, WHICH REVERSES THE PIGGY'S RULE ABOVE. Every
-- word written over `Config.PIGGY_MESH` about stripping `TextureID` is
-- correct and none of it applies here. The pig is stripped because forty-six
-- SKINS multiply a colour onto it, so a painted mesh comes out muddy on
-- forty-five of them and the three animated skins drive that muddy multiply
-- every frame. A tree has no skin system: its colour is a constant in
-- NeighborhoodService and always will be. So the baked shading between the
-- leaf clumps is free depth, and it is the thing that makes the canopy read
-- as clumps at all -- stripped and tinted flat, the same mesh loses its clump
-- definition and looks worse than it does textured.
--
-- Measured on the two builds side by side before this was decided, which is
-- the only reason it was noticed: the obvious move was to copy the pig.
--
-- AND THE TEXTURE HAS TO BE CARRIED HERE, BECAUSE `CreateMeshPartAsync` DOES
-- NOT BRING IT. That call takes a MESH id and nothing else, so the part it
-- hands back is untextured however the asset was authored -- which shipped,
-- briefly, as exactly the flat canopy this entry argues against, with nothing
-- erroring and the trees merely looking worse. A generated mesh and its
-- painted map are two separate uploads, and anything cloning one has to ask
-- for both.
--
-- The piggy never met this because its ids are re-minted UNTEXTURED meshes:
-- the strip happens once at authoring time and there is no map to carry. A
-- `texture` of nil is therefore a legal entry meaning exactly that.
--
-- OFFSETS ARE TO EACH MESH'S BOUNDING-BOX CENTRE, measured from a tree origin
-- at the CENTRE OF THE TRUNK IN XZ AND THE BOTTOM OF THE TRUNK IN Y -- so a
-- tree is seated by standing it on the ground, which is how a tree is placed.
-- Same trap as the pig: seating both parts at one offset stacks the canopy
-- inside the trunk.
Config.TREE_MESH = {
	-- The generated tree at scale 1, trunk base at y 0. `height` and `width`
	-- are what the grove scales against, and `canopyDepth` is what it clears
	-- the fences with -- see the clamp in NeighborhoodService.buildTree.
	height = 13.892,
	width = 12.000,
	canopyDepth = 10.540,

	-- Three sizes, matching the three the box-and-ball tree already picked off
	-- `seed % 3`, so the grove keeps the height spread it was tuned with:
	-- 15.97, 18.06 and 20.14 studs against the old 15.67, 18.50 and 21.33.
	--
	-- UNIFORM, because a stylised tree stretched on one axis stops reading as
	-- the same species -- and because the canopy clearance the grove computes
	-- is only honest if one number describes the whole tree.
	scales = { 1.15, 1.30, 1.45 },

	parts = {
		{
			part = "Trunk",
			id = "121225651399352",
			texture = "71998128730317",
			offset = Vector3.new(0.0000, 4.3699, 0.0000),
			size = Vector3.new(6.4431, 8.7397, 4.6790),
		},
		{
			part = "Canopy",
			id = "94206560447406",
			texture = "116054928983235",
			offset = Vector3.new(-0.0147, 9.7217, -0.0095),
			size = Vector3.new(12.0000, 8.3408, 10.5400),
		},
	},
}

-- Nil unless BOTH parts have an id, and here the piggy's all-or-nothing rule
-- does apply: a mesh canopy floating over a box trunk is a broken tree, not
-- an unfinished setting.
function Config.treeMesh(): { any }?
	local spec = Config.TREE_MESH
	local parts = {}
	for _, entry in ipairs(spec.parts) do
		local id = assetId(entry.id)
		if not id then
			return nil
		end
		table.insert(parts, {
			part = entry.part,
			id = id,
			-- Optional, and nil means an untextured mesh rather than a
			-- missing one -- see the note above.
			texture = assetId(entry.texture),
			offset = entry.offset,
			size = entry.size,
		})
	end
	return {
		height = spec.height,
		width = spec.width,
		canopyDepth = spec.canopyDepth,
		scales = spec.scales,
		parts = parts,
	}
end

-- ------------------------------------------------------------
-- THE FENCE
-- ------------------------------------------------------------
--
-- A REPEATING PANEL, TILED ALONG EACH RUN, AND THE PART COUNT IS MOST OF WHY.
-- The primitive fences build per-picket: `decorPicket` lays a picket AND a
-- rotated tip every 2.6 studs, which on a plot's whole perimeter is about 276
-- parts, and a street where all eight own one is over two thousand -- as much
-- as the entire rest of the world. One panel mesh every ~7 studs replaces
-- that with about 50. Measured on a 44-stud run: 38 primitive parts against
-- 6 panels.
--
-- So this is the rare upgrade that is cheaper than what it replaces, and that
-- is the property to preserve. A future tier that wants a mesh PER POST
-- throws it away.
--
-- IT TOUCHES NOTHING LOAD-BEARING, WHICH IS THE ONLY REASON IT IS SAFE.
-- `PlotService.buildFence` builds three things per segment: an invisible
-- `Barrier` that carries ALL the collision and the ladder's `AlongX`/`Span`
-- attributes, a `ClimbZone` trigger above it, and one call to a decorator.
-- This replaces the decorator and nothing else. Every height rule in this
-- file -- `tier.top`, `jumpReach`, `isHoppableFence`, `auditFences` -- reads
-- the barrier and is untouched. A fence can look like anything; what it
-- COSTS to cross is a different number in a different part.
--
-- THE PANEL STANDS TO `decorTop`, NOT `top`. Those are the two heights a tier
-- carries and confusing them is how a visual change becomes a balance change:
-- `top` is the solid barrier and decides the jump, `decorTop` is where the
-- visuals reach. The mesh is scaled UNIFORMLY off its authored height so it
-- lands on `decorTop`, and only its LENGTH is then stretched to tile the run
-- exactly -- a panel is a flat thing seen side-on, so stretching along the
-- run is invisible where stretching its height would not be.
--
-- IT KEEPS ITS BAKED TEXTURE, for the reason the tree does: a fence has no
-- skin system, so the shading between pickets is free depth. `tint` is a
-- MULTIPLY over that map for a tier that wants to shift it, not a flat
-- colour.
--
-- AN EMPTY OR MISSING ROW FALLS BACK TO THE PRIMITIVE DECORATOR, per style,
-- so the tiers can be done one at a time and a fresh empty place plus this
-- repo still builds the world this repo has always built.
Config.FENCE_MESH = {
	picket = {
		id = "115236091624141",
		texture = "129319305360903",
		-- The generated panel at scale 1: length along X, height, depth.
		size = Vector3.new(6.1413, 4.6939, 0.3500),
	},

	-- THE FIRST RICKETY PANEL WAS REGENERATED AND THE REASON IS WORTH KEEPING.
	-- Asked for "old broken wooden fence, posts leaning at slight angles, one
	-- plank missing", the generator returned CREAM POSTS WITH PALE BLUE RAILS,
	-- perfectly upright and perfectly tidy -- a smart modern rail fence. It
	-- was not subtly wrong, it was the opposite of the brief, and it would
	-- have made the tier's own blurb ("Leaning posts and missing planks") a
	-- lie on screen. Words like "derelict", "rotten", "splintered", "shabby"
	-- and an explicit "dark brown" got it; "old", "weathered" and "broken" did
	-- not. THE GENERATOR ANSWERS ADJECTIVES OF CONDITION, NOT OF AGE, and a
	-- colour it is not told is a colour it will invent.
	rickety = {
		id = "123040692953259",
		texture = "78545697475837",
		size = Vector3.new(2.3975, 2.1072, 0.4000),
	},
	barbed = {
		id = "110789712560510",
		texture = "72915336083332",
		size = Vector3.new(3.0100, 2.2807, 0.3500),
	},
	electric = {
		id = "72116488758769",
		texture = "89401559415439",
		size = Vector3.new(2.4452, 2.0805, 0.3500),
		-- EXTRA WIRES, STRUNG UNDER THE PANEL'S OWN PAIR. The generated panel
		-- carries two cables and puts both of them near the TOP, which left
		-- the bottom two thirds of an eight-stud fence as open air -- it read
		-- as a row of posts rather than as something strung.
		--
		-- Measured off the render: the panel's own cables sit about 8.8 and
		-- 6.8 above FENCE_BASE_Y, two studs apart, so these continue that
		-- spacing rather than being placed by eye.
		--
		-- ONE PART PER WIRE PER SIDE, NOT PER PANEL. They span the whole run,
		-- which is what the primitive `decorElectric` already did and is the
		-- only version that does not undo the part saving: two wires across
		-- five sides is ten parts, where per panel it would be sixty-eight.
		wires = {
			heights = { 4.8, 2.8 },
			thickness = 0.16,
			colour = Color3.fromRGB(70, 140, 240),
		},
	},

	-- `moat` is deliberately absent rather than blank -- it resolves to
	-- `electric` in the accessor below, because the code already does.
}

-- WHAT EACH TIER COSTS IN PARTS, measured rather than assumed, because the
-- whole point of a panel is that it is cheaper than the primitives it
-- replaces. Panel length is the authored length scaled to reach `decorTop`,
-- so a squat mesh tiles more often than a long one:
--
--      rickety   4.8 studs a panel      picket   7.3
--      barbed   12.0                    electric 9.6
--
-- Against a perimeter of roughly 346 studs that is 72, 47, 29 and 36 panels
-- -- every one of them far under the ~276 parts the primitive picket built.

-- The panel for a fence style, or nil to use the primitive decorator.
--
-- MOAT RESOLVES TO ELECTRIC, because it already does in the code: `decorMoat`
-- is a one-line call to `decorElectric` -- the wall is identical and the
-- water is the upgrade, built once for the whole ring rather than per side.
-- Aliasing here rather than duplicating the row is what stops the two drifting
-- the first time either is touched.
function Config.fenceMesh(style: string): { any }?
	local key = if style == "moat" then "electric" else style
	local spec = Config.FENCE_MESH[key]
	if not spec then
		return nil
	end
	local id = assetId(spec.id)
	if not id then
		return nil
	end
	return {
		id = id,
		texture = assetId(spec.texture),
		size = spec.size,
		tint = spec.tint,
		wires = spec.wires,
	}
end

-- ------------------------------------------------------------
-- THE HOUSE
-- ------------------------------------------------------------
--
-- ONE MESH PER ARCHETYPE, STANDING IN FOR THAT TIER'S PRIMITIVE BUILDER.
--
-- This is the same shape as the fence, the tree and the piggy: an id here, an
-- accessor that returns nil when it is unset, and `House.build` falling back
-- to the builder that has always drawn that tier. AN EMPTY ROW IS THE HOUSE
-- THIS GAME ALREADY SHIPS -- nothing in `House.luau` was deleted to make room
-- for this, so a row can be filled, looked at, and emptied again with the old
-- house standing in the same frame.
--
-- WHY A HOUSE AND NOT A PANEL: THE ARGUMENT IS PURELY VISUAL HERE, WHICH IS
-- A FIRST. The fence paid for itself in parts -- 276 primitives down to 47
-- panels -- and that is not the case on a house: measured on the live street,
-- the tiers run 12 to 72 parts, which is nothing. So this buys no frames and
-- is not defended on those grounds. What it buys is that the house stops
-- being the last blocky object on a street whose pig, trees, grass and fences
-- are all rounded meshes. A cottage that is a grey box with two wedges on top
-- reads as a different game from the tree standing next to it.
--
-- SCALED UNIFORMLY, OFF `height` BY PREFERENCE, AND THAT CHOICE IS A
-- MEASUREMENT RATHER THAN A TASTE. A row gives ONE target and the other two
-- axes follow it, because scaling each axis to the tier's own width and depth
-- separately would stretch a generated building into a different one.
--
-- Height is the better handle because it is the axis this world is already
-- tuned on: `STOREY` is 9 studs against a five-stud character, so a two-storey
-- house wants to land near 20 whatever its floor plan. Width cannot do that
-- job, because THE GENERATOR DOES NOT TAKE PROPORTIONS FROM THE SIZE BOX --
-- measured, a cottage asked for at 26 x 20 x 20 came back 10.3 x 20.0 x 12.3,
-- fitted INSIDE the box at its own aspect. So a row that pins width would take
-- a house the generator happened to make narrow and stretch it to fifty studs
-- tall to get there.
--
-- `width` is still accepted and is the right handle for a mesh whose aspect
-- already matches its tier, where the binding constraint is the side fence --
-- the note over HOUSE_TIERS records a Manor whose wings went straight through
-- one. Whichever is given, the other two axes are carried along.
--
-- IT KEEPS ITS BAKED TEXTURE, which is the TREE's rule and deliberately not
-- the PIGGY's. The pig is stripped because forty-six skins multiply a colour
-- onto it and a painted mesh is muddy on forty-five of them. A house has no
-- skin system -- its colours are constants in the tier table -- so the shading
-- baked between the boards, tiles and window frames is free depth, and it is
-- most of what separates a cartoon house from a smooth blob.
--
-- WHAT STAYS PRIMITIVE IS THE LIGHT SHOW. The top four tiers carry `HouseFX`
-- neon parts that are colour-written every frame on every client, and those
-- are geometry the mesh cannot supply: an emissive part is a MATERIAL, not a
-- shape. A row may therefore carry `keepFX`, which runs the tier's own builder
-- for its glowing parts only and drops every solid part it made. That is how
-- a meshed Neon Tower still has bands that cycle.
--
-- `RenderFidelity` IS `Automatic`, FOR THE TREE'S REASON RATHER THAN THE
-- PIGGY'S. A house stands seventy studs behind its own piggy and there are up
-- to eight of them on screen; shedding triangles with distance is exactly what
-- that wants. The pig is `Precise` because it is read from the pavement and is
-- the one object a robbery is about.
Config.HOUSE_MESH = {
	-- Nothing generated yet. Each style falls back to `builders.<style>` in
	-- House.luau until its row is filled, so the catalogue can be done one
	-- tier at a time and a fresh empty place plus this repo still builds the
	-- nine houses this game has always built.
	shack = nil,
	cottage = nil,
	townhouse = nil,
	villa = nil,
	manor = nil,
	modern = nil,
	tower = nil,
	palace = nil,
	castle = nil,
}

-- WHICH STYLES USE THE REBUILT, LOW-POLY BUILDER RATHER THAN THE ORIGINAL.
--
-- The same opt-in shape as HOUSE_MESH above and for the same reason: the
-- houses this game already ships are not deleted to make room for a new look.
-- An empty set is the catalogue exactly as it stands; adding a style swaps
-- that ONE tier and leaves the other eight alone, so a rebuild can be looked
-- at on a real plot next to the originals and backed out by deleting a word.
--
-- WHY A CODE REBUILD AND NOT A MESH, WHICH REVERSES THE INSTINCT THIS PROJECT
-- HAS FOLLOWED SINCE THE PIG. The pig, the trees and the fence panels all went
-- to generated meshes because they are ORGANIC OR CURVED -- a pig is a shape
-- primitives genuinely cannot make, and the whole complaint about it was that
-- it read as blocky. A low-poly cartoon house is the opposite case: the style
-- IS flat polygons with hard edges and flat blocks of colour, which is the
-- native vocabulary Roblox hands you for free. Reaching for a mesh there buys
-- nothing the engine was not already giving, and costs an upload under the
-- developer own account -- see the moderation entry in CLAUDE.md, which is the
-- most expensive thing in this project history.
--
-- WHAT ACTUALLY MAKES A HOUSE READ AS "OLD ROBLOX", measured against the
-- reference art rather than guessed:
--
--   * TEXTURED MATERIALS. The originals use Brick, Slate, WoodPlanks and
--     CorrodedMetal. Every low-poly reference is FLAT COLOUR. SmoothPlastic
--     throughout is the single biggest move, and it is free.
--   * NO TILE ROWS. A roof drawn as two bare wedges is a ramp; a roof drawn
--     as overlapping courses of tiles is a ROOF, and it is the one detail
--     every reference has in common.
--   * UNFRAMED OPENINGS. A flat rectangle of glass laid on a wall is a
--     sticker. A frame, a sill and a mullion cross make it a window.
--   * NOTHING WHERE THE BUILDING MEETS THE GROUND. A plinth is what stops a
--     house looking like a box resting on grass.
Config.HOUSE_REBUILD = {
	-- A style named here stands its REBUILT low-poly builder; a style left out
	-- stands exactly the builder it has always had. Empty means the catalogue
	-- as it shipped, which is what makes the whole rebuild backable-out by
	-- deleting words rather than by reverting a file.
	--
	-- All nine are on. The originals in `House.luau` are still there and still
	-- work -- they are what a removed line here falls back to -- and the one
	-- thing to know before deleting a line is that the ORIGINALS carry the
	-- coplanar flicker this pass was started to fix: thirty-two pairs across
	-- the eight of them, with the Neon Tower alone at thirteen.
	shack = true,
	cottage = true,
	townhouse = true,
	villa = true,
	manor = true,
	modern = true,
	tower = true,
	palace = true,
	castle = true,
}

-- The mesh for a house style, or nil to use the primitive builder.
function Config.houseMesh(style: string): { any }?
	local spec = Config.HOUSE_MESH[style]
	if not spec then
		return nil
	end
	local id = assetId(spec.id)
	if not id then
		return nil
	end
	return {
		id = id,
		texture = assetId(spec.texture),
		height = spec.height,
		width = spec.width,
		yaw = spec.yaw,
		tint = spec.tint,
		keepFX = spec.keepFX,
	}
end

-- ------------------------------------------------------------
-- THE GRASS ITSELF
-- ------------------------------------------------------------
--
-- THE HALF THE MATERIAL CANNOT DO. The painted lawn above makes the ground
-- look like grass, and the ground is still a flat plane -- from standing
-- height a plane reads as a plane however well it is painted. What actually
-- sells a stylised lawn is SILHOUETTE: blades breaking the line where the
-- ground meets everything standing on it. The material and these tufts are
-- two halves of one job rather than two options, and neither is worth much
-- without the other.
--
-- `minScale` AND `maxScale` ARE THE WHOLE BRIEF, WHICH WAS "STICKING UP
-- SLIGHTLY". The clump is authored 2.60 studs tall, which against a rig five
-- studs high is waist-deep meadow -- a different game, and one where a thief
-- crossing a lawn wades through it. At 0.28 to 0.52 a tuft stands 0.73 to
-- 1.35 studs: ankle to mid-shin, tall enough to break the ground line from
-- the pavement and short enough that a lawn still reads as a lawn.
--
-- `perStuds` IS ONE TUFT PER THAT MANY SQUARE STUDS, and it is the number to
-- turn rather than the scales. Density decides whether this reads as grass or
-- as weeds; height decides whether the lawn is still mown. Those are
-- different questions, and mixing them is how a tuning pass ends in a meadow.
--
-- IT KEEPS ITS TEXTURE for the reason the tree does, and NOT for the reason
-- the piggy does not: the painted tips are most of what makes this read as
-- blades rather than as a green wedge, and no skin system multiplies a colour
-- onto grass. The two tints are near-white MULTIPLIES over that map rather
-- than flat colours.
Config.GRASS_TUFT = {
	id = "78478854962917",
	texture = "106168794562242",
	-- The generated clump at scale 1.
	size = Vector3.new(2.7979, 2.6000, 1.4280),
	minScale = 0.28,
	maxScale = 0.52,
	-- One tuft per this many square studs.
	--
	-- 80 was the shipped value and was SEEN only on the textured ground,
	-- where it read as sparse. 45 is REASONING about the flat ground rather
	-- than an observation of it: a flat plane has no texture of its own, so
	-- the tufts now carry ALL of the detail and there have to be more of
	-- them. It has not been looked at -- Studio lost asset delivery in the
	-- same session the ground went flat, so no tuft has ever been rendered
	-- ON it. First thing to check next time the world builds.
	--
	-- The cost is parts: 80 measured 819 tufts in a world of 2,428
	-- BaseParts, so 45 is about 1,450 and roughly 3,050. Worth watching if
	-- this goes lower.
	perStuds = 45,
	-- Sunk a little, because a mesh whose lowest vertex is not exactly on its
	-- bounding-box floor hovers otherwise -- and grass emerging FROM the
	-- ground is the picture, rather than grass balanced on it.
	sink = 0.06,
	-- Near-white MULTIPLIES over the tuft's own painted map, not flat
	-- colours. Brought down with the ground: on a darker lawn the old pair
	-- popped hard enough to read as straw rather than as grass.
	tint = Color3.fromRGB(198, 222, 182),
	tint2 = Color3.fromRGB(160, 192, 142),
}

-- Nil without an id, which blanks the grass rather than breaking anything:
-- the ground keeps its painted material and simply has nothing standing on
-- it, which is exactly the world this repo built before tufts existed.
function Config.grassTuft(): { any }?
	local spec = Config.GRASS_TUFT
	local id = assetId(spec.id)
	if not id then
		return nil
	end
	return {
		id = id,
		texture = assetId(spec.texture),
		size = spec.size,
		minScale = spec.minScale,
		maxScale = spec.maxScale,
		perStuds = spec.perStuds,
		sink = spec.sink,
		tint = spec.tint,
		tint2 = spec.tint2,
	}
end

-- Every key that wants an id, for the startup warning and the dump command.
--
-- THE RIDE KEYS ARE HANDED IN RATHER THAN DERIVED HERE, and that is the fix
-- for the bug the stance rows above describe. This function used to walk
-- `Config.RIDES` itself and emit a style plus its trick, which is the set the
-- CATALOGUE describes and not the set the RUNTIME asks for: a published style
-- carries its stance, so eight keys existed that this list could not see.
--
-- Config requires nothing and must go on requiring nothing, so it cannot ask
-- RidePose -- and RidePose is the one file that knows the "@" and "#" grammar
-- anyway. `RidePose.animationKeys()` is what belongs in `rideKeys`. The
-- parameter is deliberately not optional: a bare call is how this
-- under-reported for a whole release, and it should now be a visible mistake
-- rather than a quiet one.
function Config.animationKeys(rideKeys: { string }): { string }
	-- The two animations that belong to a PLAYER rather than to a ride. Both
	-- are hardcoded because neither is derived from a catalogue -- and the
	-- stance bug is why this list is worth being careful with: `animationKeys`
	-- once described what the CATALOGUE held rather than what the runtime asks
	-- for, so eight keys existed that nothing in the pipeline knew about, and
	-- all three ends failed silently in the same direction.
	local keys = { "dodgeRoll", "sneak", "carry" }
	if type(rideKeys) ~= "table" then
		warn("[Config] animationKeys was called without the ride keys, so it can "
			.. "only report the dodge roll. Pass RidePose.animationKeys().")
		return keys
	end
	for _, key in ipairs(rideKeys) do
		if not table.find(keys, key) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

Config.DATASTORE_NAME = "PiggyBank_Player"

-- Bumping this lets us migrate live saves later instead of wiping them.
-- v2 added the `upgrades` table for the defence and offence trees.
-- v3 added `cosmetics`, which rebirth deliberately does not reset.
-- ============================================================
-- PIG ACCESSORIES -- RETIRED
-- ============================================================
--
-- EVERYTHING FROM HERE TO THE END OF THE LEGAL ARGUMENT DESCRIBES A FEATURE
-- THAT IS NO LONGER IN THE GAME, and it is kept rather than deleted because
-- the second half of it is not about accessories at all. The bullets below
-- describe the retired accessory ROLL; the "paid random item" reasoning after
-- them outlives it and still governs every chest in the game.
--
-- Copy outliving the thing it describes is a fault this file records twice
-- over -- a SNEAKING section still selling a retired disguise kit, and a
-- STREET_SPACING comment justified by a car nobody could find -- so the note
-- goes at the top rather than leaving the next reader to work out which half
-- is still live. See `Config.ACCESSORIES` below for the retirement itself.
--
-- Hats, glasses, capes and shoes, worn one per slot, all four at once. Skins
-- recolour the pig; these sit ON it, so a decorated piggy is a combination
-- rather than a single choice -- which is what makes it worth showing off.
--
-- Won by ROLLING, never bought directly, and a roll can only return something
-- you do not already own. That has three consequences worth stating, because
-- they are the whole design:
--
--   * There are no duplicates, so every roll is progress. A player is never
--     handed something they already have and told it was a prize.
--   * The collection therefore COMPLETES. This is a guaranteed ladder wearing
--     the clothes of a gamble, not a slot machine -- appropriate for an
--     audience that cannot consent to a real one.
--   * The price climbs with how many you own (see getRollCost), so the pace
--     is set by the collection rather than by whoever has the deepest vault.
--     Somebody sitting on ten million cannot clear the pool in one sitting.
--
-- A ROLL IS PAID FOR IN A CURRENCY THAT CANNOT BE BOUGHT, AND THAT IS THE
-- LINE THAT KEEPS THIS LEGAL RATHER THAN A PREFERENCE.
--
-- It used to cost COINS. Roblox defines a paid random item as one bought with
-- Robux OR with in-game currency purchasable with Robux, so the day a coin
-- pack shipped this roll would have become a loot box with no line of code
-- changing here -- and paid random items for an under-13 audience are
-- regulated hard: real numerical odds shown before purchase, and a
-- PolicyService gate that makes the whole feature refuse to open for players
-- in an expanding list of regions. For this audience that is a large share of
-- players meeting a button that does nothing.
--
-- Moving the roll onto an earned-only currency does not merely comply, it
-- steps OUT of the rule entirely: nothing random here is purchased, so there
-- is nothing to disclose and nothing to gate. Coins become ordinary money and
-- a coin pack becomes an ordinary product.
--
-- THE ORDER MATTERS AND IS THE WHOLE POINT: the roll had to move BEFORE the
-- first pack ships, never after. Selling a specific accessory outright for
-- Robux is still fine; selling the roll is not, at any price, ever.
--
-- The same test applies to anything added later. Ask one question of every
-- new random outcome: can a player reach it faster by spending real money? If
-- yes, it does not ship until the answer is no.

-- ============================================================
-- RARITY
-- ============================================================
--
-- ONE LADDER FOR THE WHOLE SHOP, and the bands are global on purpose.
--
-- These four tiers started as the accessory roll's weights and are now what
-- every card in the shop is bordered with, which is why the table is no
-- longer called ACCESSORY_RARITIES. A skin, a decoration, a house and a hat
-- all use the same four words and the same four colours, so a player learns
-- the ladder once and reads every tab with it.
--
-- The bands are absolute coin amounts rather than a curve fitted per tab.
-- That means the effects tab tops out at Rare -- Inferno is the loudest thing
-- in it and still only costs 600,000 -- while decorations reach Legendary and
-- houses spend three tiers there. That is not a gap to paper over, it is the
-- economy telling the truth: a border that meant "expensive FOR AN EFFECT"
-- would be four different ladders wearing one set of colours, and the gold
-- border on a Sky Castle would mean nothing.
Config.RARITIES = {
	-- THE LADDER IS THE SAME FAMILY AS EVERY OTHER COLOUR IN THE GAME, and
	-- three of the four were nearly there already -- a blue, a purple and a
	-- gold two or three steps off `Theme`'s own. They are exactly those now.
	--
	-- COMMON WAS THE ODD ONE, AND ONLY BY HUE. It was a blue-grey at hue 214,
	-- which is a perfectly good neutral in a cold palette and the one thing
	-- this one has no room for: on a warm card, beside a warm outline, it
	-- reads as a colour rather than as an absence of one. Rotated to hue 30
	-- at its EXACT luminance (0.3554 to 0.3561), so nothing about how it
	-- ranks against the other three moved -- only which palette it is from.
	common    = { label = "Common",    weight = 100, colour = Color3.fromRGB(172, 159, 145) },
	rare      = { label = "Rare",      weight = 42,  colour = Color3.fromRGB(64, 147, 230) },
	epic      = { label = "Epic",      weight = 15,  colour = Color3.fromRGB(181, 97, 255) },
	legendary = { label = "Legendary", weight = 4,   colour = Color3.fromRGB(255, 203, 61) },
}

-- THE LADDER IN ORDER, WHICH IS A THING TWO FILES WERE EACH KEEPING THEIR OWN
-- COPY OF. `Config.RARITIES` is a map and a map has no order, so `ChestService`
-- carried `local TIERS = { "common", "rare", "epic", "legendary" }` to walk it
-- deterministically -- and the moment a chest could carry a rarity FLOOR this
-- file needed the same sequence to compare against. Two copies of one grammar
-- is what `RideSound` already paid for by keeping a second copy of the ride-key
-- format and breaking within the hour.
Config.RARITY_ORDER = { "common", "rare", "epic", "legendary" }

-- Where a tier sits on that ladder, 1 to 4, or 0 for something that is not a
-- tier at all. Used to compare against a chest's `floor`; nil-safe on purpose,
-- because a typo in a `floor` should stock the chest with everything rather
-- than empty it and refuse to open.
function Config.rarityRank(tier: string?): number
	for i, name in ipairs(Config.RARITY_ORDER) do
		if name == tier then
			return i
		end
	end
	return 0
end

-- Cheapest first. A cost at or above `from` takes that tier, so the last band
-- a price clears is the one it lands in.
Config.RARITY_BANDS = {
	{ rarity = "rare", from = 100000 },
	{ rarity = "epic", from = 1000000 },
	{ rarity = "legendary", from = 10000000 },
}

-- The tier for anything sold or dropped, from whatever the thing happens to
-- carry. Three sources, in this order, and the order is the point:
--
--   1. An EXPLICIT `rarity`. The drop-pool skins and every accessory have one
--      because they are not bought at all -- there is no price to read, and
--      the rarity is what decides how likely they were in the first place.
--   2. `unlockRebirths`. A rebirth-locked skin is also unpriced, and what it
--      costs is resets rather than coins. Bronze at 1 reset is Rare, Gold
--      Leaf at 3 is Epic, Diamond at 6 is Legendary.
--   3. The PRICE. Everything else in the shop is a direct coin purchase, and
--      in this economy the price is the rarity -- there is no drop rate to
--      express, so pretending otherwise would mean hand-tagging sixty items
--      and re-tagging them every time a price moved.
--
-- Deriving rather than tagging is what keeps this honest as the shop grows: a
-- decoration added at 12 million is Legendary the moment it is priced, with
-- nothing else to remember.
function Config.rarityOf(spec: any): string
	if type(spec.rarity) == "string" and Config.RARITIES[spec.rarity] then
		return spec.rarity
	end

	if type(spec.unlockRebirths) == "number" then
		return if spec.unlockRebirths >= 5 then "legendary"
			elseif spec.unlockRebirths >= 2 then "epic"
			else "rare"
	end

	local cost = spec.cost or 0
	local tier = "common"
	for _, band in ipairs(Config.RARITY_BANDS) do
		if cost >= band.from then
			tier = band.rarity
		end
	end
	return tier
end

-- ============================================================
-- CHESTS
-- ============================================================
--
-- COINS ARE NOT PURCHASABLE WITH ROBUX, AND THAT IS WHAT MAKES ALL OF THIS
-- LEGAL. A chest bought with coins is a paid random item ONLY if those coins
-- can be bought with real money -- so the day a coin pack ships, every chest
-- in this game retroactively becomes a regulated loot box with nothing in this
-- repo having changed. Monetization is direct purchases of NAMED things: pets,
-- rides, passes. Never currency. See the note in CLAUDE.md; this comment is
-- the short version and the rule is not negotiable.
--
-- A CHEST DECLARES ITS ODDS AND ITS MEMBERS DECLARE THEIR CHEST. Membership is
-- a `chest` field on each item rather than a list here, for the reason `zone`
-- and `set` are fields: a list in this table is a second place to remember,
-- and the one that goes stale is always the list.
--
-- A CHEST'S TIER FOR AN ITEM IS `Config.rarityOf`, NOT A NEW FIELD. That
-- function already reads an explicit `rarity`, then `unlockRebirths`, then the
-- price -- so the drop-pool skins keep the rarity they were authored with and
-- the priced ones land where their price already put them. Adding a second
-- notion of tier would be two numbers to disagree.
--
-- WHY THESE ODDS. The pool decides them rather than taste. `classics` holds
-- 4 common, 6 rare, 4 epic and 3 legendary, and the epic figure is SOLVED
-- rather than picked, so that the two routes to a legendary cost the same:
--
--     straight from a chest      1 / 0.04       = 25.0 opens
--     three epics, then combine  3 / 0.12       = 25.0 opens
--     twenty-seven commons       27 / 0.52      = 51.9 opens
--
-- The solution is `epic = 3 * legendary`, which falls straight out of needing
-- `COMBINE.need / epic == 1 / legendary`. The first pass had epic at 14 and
-- came out at 0.86 -- combining 14% cheaper than rolling, which is small and
-- is still the wrong side of 1.0: at any ratio under one, the top tier stops
-- being something you get and becomes something you assemble, and the chest
-- turns into a common dispenser. Above one the combine screen is decoration.
-- The bottom of the ladder being the slow route is correct and deliberate.
--
-- WHAT A WHOLE COLLECTION COSTS, simulated over 4,000 runs against these
-- exact odds and pools rather than reasoned about: 149 opens to complete
-- `classics` and 85 to complete `gear`. At the prices below that is 74.5M and
-- 29.8M, so about 104M of coins for every skin and every accessory in the
-- game -- roughly 9% of the 1.17B the whole economy contains. Note the number
-- that matters here is OPENS, not price: the odds are what gate a collection,
-- and the price only decides how much of the economy it drains on the way.
Config.CHESTS = {
	-- THE OG SHELF, WHICH IS THE OLD CLASSICS CRATE WITH NEON NIGHTS FOLDED
	-- INTO IT.
	--
	-- There are TWO skin collections now rather than three, and the second
	-- one is `animal`. Neon Nights was never a different KIND of thing from
	-- Classics -- both are the street's own skins rather than a costume of
	-- something else -- so it was a shelf split on palette, which is the one
	-- axis a nine-year-old cannot act on: nobody wants "a glowing one", they
	-- want a specific pig. Animal is a real category because it answers a
	-- question somebody actually asks.
	--
	-- THE ODDS LOST `epic` AND NOTHING ELSE MOVED. A skin is one of three
	-- tiers now, so the middle rung carries what two used to: 32 + 12 = 44.
	-- Legendary stays at 4, which is what holds the whole price ladder below
	-- still -- it is solved on COINS PER LEGENDARY, so touching that number
	-- reprices every crate at once.
	og = {
		name = "Piggy Originals",
		order = 1,
		kind = "skin",
		currency = "coins",
		cost = 500000,
		odds = { common = 52, rare = 44, legendary = 4 },
		colour = Color3.fromRGB(236, 138, 178),
		blurb = "The skins the street was built on, glow and all",
	},
	-- THE DRESS-UP CRATE IS RETIRED WITH THE ACCESSORIES IT HELD. Its pool was
	-- `Config.ACCESSORIES` and nothing else, so once that emptied this chest
	-- would have taken 350,000 coins and rolled over a pool with no stock in
	-- any tier -- `liveOdds` drops empty tiers, and with all four gone there
	-- is nothing left to hand over. This file's own rule is that the charge
	-- happens AFTER the outcome exists precisely so a chest can never do
	-- that, and an empty pool is the one way round it that the guard cannot
	-- see. Order 2 is free; the ladder sorts on `order` and does not mind a
	-- gap, as the jump from 2 to 5 already showed.
	-- ============================================================
	-- THE TIER LADDER
	-- ============================================================
	--
	-- WHY THESE EXIST: A FLAT PRICE STOPS BEING A PRICE.
	--
	-- Measured against the real curves, a 500,000-coin chest is THIRTEEN AND
	-- A HALF HOURS of idling at level 1 and FOUR SECONDS at level 40 rebirth
	-- 10 -- a spread of about 12,500 to one. So the permanent cosmetic track,
	-- which is the whole reason rebirth is worth pressing, is unreachable for
	-- the first ten levels and free after about level 25. That is the daily
	-- ladder's own rule arriving on the one place nobody applied it: a coin
	-- reward is denominated in SECONDS OF YOUR OWN INCOME, never in a flat
	-- number.
	--
	-- THE HONEST FIX IS A SHARE OF CAPACITY and it was refused on purpose --
	-- measured, it lands every chest at 2 to 6 minutes of idling at every
	-- point on the ladder. What is here instead is a PRICE LADDER, which
	-- fixes the top end and not the bottom: a Legendary Crate at six million
	-- is 33 minutes at level 20 and still 47 seconds at the very top. That
	-- residual is recorded rather than argued away, and the lever if it ever
	-- matters is `UPGRADE_COST_CEILING`'s own trick applied here.
	--
	-- AND THE TWO COIN SKIN CHESTS ABOVE ARE THE COMMON RUNG, which is why
	-- no crate here is called one. A themed crate and a tier crate answer
	-- different questions -- "I want animal skins" against "I want a good
	-- skin" -- and both are legible to a nine-year-old.
	--
	-- THE LADDER IS SOLVED ON COINS PER LEGENDARY, NOT PICKED. A tier crate
	-- has to be worth buying and must not be strictly better, and those pull
	-- opposite ways: value per coin is odds over price, so matching the cheap
	-- crate exactly would mean the top one costs `odds x 12.5M` and is
	-- therefore CHEAP. What a player actually buys up here is SPEED and a
	-- floor -- 2.9 opens to a legendary against 25, and never a common -- so
	-- the ladder carries a deliberate, measured premium for it:
	--
	--     crate           price    legendary   coins/legendary   opens
	--     themed (any)     500K        4%           12.5M         25.0
	--     Rare Crate       1.5M       10%           15.0M         10.0
	--     Legendary Crate  6.0M       35%           17.1M          2.9
	--
	-- 37% dearer at the top, for a route that is nine times faster and cannot
	-- pay out a skin you were not chasing. Anything that moves a price or an
	-- odds row has to re-run that table, or one rung silently becomes a trap.
	--
	-- STOCK, MEASURED THROUGH `chestPool` RATHER THAN COUNTED BY EYE -- and
	-- the difference mattered: eight skins carry no chest tag at all (the
	-- three rebirth drops, Solid Gold, Classic Pink, the alien skin and the
	-- two pass skins), so they are not in this economy and cannot be in a
	-- crate. ACROSS THE TWO SHELVES THE REAL FIGURES ARE 9 common, 20 rare
	-- and 7 legendary, so a `rare` floor stocks 27 items -- deep enough to
	-- be a pool rather than a coin flip. That is the check to re-run before
	-- adding a rung, and it is the one that catches a floor naming a tier
	-- nothing carries.
	rarecrate = {
		name = "Rare Crate",
		order = 5,
		kind = "skin",
		currency = "coins",
		cost = 1500000,
		-- EVERY SKIN IN THE COIN ECONOMY AT RARE OR BETTER, across all three
		-- themed pools -- which is the other thing this rung sells. A themed
		-- crate is the route to a theme; this is the route to a SPECIFIC skin
		-- whatever shelf it came off.
		floor = "rare",
		odds = { rare = 90, legendary = 10 },
		colour = Color3.fromRGB(64, 147, 230),
		blurb = "No commons. Rare or better, from every shelf",
	},
	legendarycrate = {
		name = "Legendary Crate",
		order = 6,
		kind = "skin",
		currency = "coins",
		cost = 6000000,
		-- ITS FLOOR WAS `epic` AND HAD TO COME DOWN TO `rare`, WHICH IS THE
		-- ONE PLACE DROPPING A TIER BROKE SOMETHING RATHER THAN SIMPLIFYING
		-- IT.
		--
		-- `chestPool` admits anything at or above the floor by RANK, and a
		-- legendary outranks an epic -- so a floor naming a tier no skin
		-- carries any more did not empty this crate, it left LEGENDARY as the
		-- only stocked tier. `liveOdds` then renormalises over what is in
		-- stock, so six million coins bought a GUARANTEED legendary. That is
		-- the failure the combine ladder is tuned against, arriving through
		-- the front door: a top tier you manufacture rather than get.
		--
		-- A floor that empties a crate is caught loudly. A floor that silently
		-- promotes it is not, and only the arithmetic says so.
		--
		-- WHAT IT COSTS: the two tier crates now stock the SAME 27 items and
		-- differ only in price and odds. The rung still sells what the table
		-- above says it sells -- 2.9 opens to a legendary against 10 -- and
		-- the coins-per-legendary column does not move, because 35% at six
		-- million is 17.1M either way.
		floor = "rare",
		odds = { rare = 65, legendary = 35 },
		colour = Color3.fromRGB(255, 203, 61),
		blurb = "The best odds on a Legendary anywhere",
	},

	-- ============================================================
	-- EVENT CHESTS
	-- ============================================================
	--
	-- BOUGHT WITH TOKENS, WHICH IS THE ONE THING COINS CANNOT DO.
	--
	-- Tokens were invented to carry the accessory roll away from purchasable
	-- coins. There is no coin pack any more, so that job is gone -- and this is
	-- the job they were always the right shape for. An event chest is themed on
	-- the event that pays for it, and no amount of money reaches it: you were
	-- either on the street when the saucer came, or you were not.
	--
	-- `kind = "set"` DRAWS ACROSS FIVE CATALOGUES, which is the whole reason a
	-- set is a view rather than a catalogue of its own. The alien pool is an
	-- accessory, a decoration, an effect, a skin and a ride, and `chestPool`
	-- resolves them through `Config.catalogueFor` exactly as SetService does.
	--
	-- MEDALS ARE NOT REPLACED, AND THAT IS DELIBERATE. Every set item still
	-- carries its medal price, so the guaranteed route survives -- which is the
	-- rule that says NOTHING IS EVER LOCKED BEHIND LUCK. Medals buy the item you
	-- want; this chest is the gamble that might save you the wait. Two routes
	-- out of one event, and bad luck still only ever costs time.
	alien = {
		name = "Alien Cache",
		order = 10,
		kind = "set",
		set = "alien",
		currency = "loot",
		cost = 6,
		-- Six items: one rare, four epic, one legendary. The odds follow the
		-- stock rather than the coin chests' ladder, because there is no common
		-- tier here at all -- an event pool is small and top-heavy by nature.
		odds = { rare = 30, epic = 55, legendary = 15 },
		colour = Color3.fromRGB(96, 255, 176),
		blurb = "Salvage from the invasion. Only turning up gets you these",
	},

	-- ADDED WITH THEIR SKINS, WHICH IS WHY THIS COMMENT USED TO SAY THEY WERE
	-- NOT HERE. A chest with no stock is a button that takes coins and returns
	-- nothing; `Config.chestPool` is the gate and `ChestService` refuses out
	-- loud rather than charging for an empty roll.
	--
	-- Both carry the same ladder as `classics` because both have the same
	-- shape of pool -- 4 common, 3 rare, 3 epic, 2 legendary -- so the solved
	-- `epic = 3 * legendary` relation that keeps combining and rolling level
	-- holds here unchanged.
	animal = {
		name = "Animal Kingdom",
		order = 3,
		kind = "skin",
		currency = "coins",
		cost = 500000,
		-- EIGHT PAINTED COATS AND ONE STORM WOLF: THIS SHELF HAS NO RARE TIER
		-- AT ALL, AND THE ODDS ROW SAYS SO RATHER THAN LEAVING IT TO
		-- `liveOdds`.
		--
		-- The tier ladder here is the TECHNIQUE ladder (see
		-- `docs/animal-crate-plan.md`): a painted coat is a common however good
		-- the painting is, and a legendary glows AND the glow moves. Every
		-- animal built so far is a coat. Only the Storm Wolf goes through the
		-- alpha pass, so it is the only thing above common on this shelf.
		--
		-- AUTHORING `rare = 44` WITH NO RARE IN STOCK WOULD NOT HAVE ERRORED,
		-- IT WOULD HAVE REPRICED THE CRATE. `liveOdds` drops a tier with no
		-- stock and renormalises what is left, so 52/44/4 over a pool with no
		-- rares resolves to 93% common and 7.1% LEGENDARY -- which is 7.0M per
		-- legendary against the 12.5M every other 500K crate charges, making
		-- this quietly the best value in the game. The whole tier ladder is
		-- solved on coins per legendary, so that is a repricing rather than a
		-- rounding.
		--
		-- 96/4 keeps legendary at the 4% the ladder is built on. When the first
		-- rare animal lands, this row goes back to 52/44/4 and the pool carries
		-- it -- and the number to check is that legendary is still 4.
		odds = { common = 96, legendary = 4 },
		colour = Color3.fromRGB(214, 158, 96),
		blurb = "Stripes, spots and fleece. Your piggy, as something else",
	},
	-- NEON NIGHTS IS RETIRED INTO `og`, and its eleven skins carry
	-- `chest = "og"` now. Circuit Board went entirely.
	--
	-- Order 4 is free. The ladder sorts on `order` and does not mind a gap,
	-- as the jump from 2 to 5 already showed when the dress-up crate went.

	--
	-- EFFECTS DO NOT HAVE A CHEST YET, AND MORE EFFECTS WOULD NOT FIX IT.
	--
	-- The obvious reading is that there are too few -- five real ones (Sparkles,
	-- Embers, Frost, Storm Cloud, Inferno) plus "none" and the alien Tractor
	-- Beam. That is not the blocker. The blocker is that they only span TWO
	-- TIERS: `rarityOf` reads their price, the dearest is Inferno at 600,000,
	-- and the epic band starts at 1,000,000 -- so there is no epic and no
	-- legendary effect for a chest to have a top end.
	--
	-- So the content this needs is not "more effects", it is EXPENSIVE ones, or
	-- explicit `rarity` tags on effects that are never meant to be bought. Until
	-- then a chest here would be a two-tier roll with nothing to chase, and they
	-- stay direct-purchase.
}

-- COMBINING: three of a tier for one of the next.
--
-- THREE, NOT TWO, AND THE ARITHMETIC IS THE WHOLE ARGUMENT. At 2:1 the ladder
-- compounds to about eight commons for a legendary -- roughly eleven chests,
-- which makes the top tier something you manufacture rather than something you
-- get, and drains the moment the chest exists to sell. At 3:1 it is 27, and
-- the two routes above cost the same.
--
-- THE SKIP CHANCE IS WHERE THE THRILL LIVES, so it is big enough to be seen.
-- A 97% "guaranteed next tier" is an exchange rate: the tension sits in a 3%
-- window most players never meet once. At 15% combined, a child who combines
-- ten times has probably jumped a tier and will tell somebody about it.
-- A DUPLICATE IS A SPARE COPY OF THE ITEM, NOT A SHARD OF ITS TIER, and that
-- reverses the rule this comment carried for the life of the chest system.
--
-- The old one read: shards are global per tier, because that answers the
-- question a chest system otherwise cannot -- what does an open give you once
-- you own everything in it? It did answer it, and it threw away the one thing
-- a duplicate is actually about, WHICH ITEM IT IS. A shard of "epic" is a
-- token with a number beside it; a second Bubblegum is a thing a nine-year-old
-- can look at and decide what to do with.
--
-- WHAT REPLACES IT KEEPS THE ANSWER AND DROPS THE ABSTRACTION. A spare can be
-- SOLD for coins or COMBINED, and combining still pools BY TIER -- three
-- spares of any commons make one rare roll -- so a spare out of a finished
-- collection is still fuel for one barely started and no open is ever wasted.
-- The word "shard" leaves the player's vocabulary entirely: there is no second
-- noun to teach, because the thing being combined is the skins they can see.
--
-- COMBINING STILL ONLY TARGETS COIN CHESTS. Event chests take tokens and
-- nothing else, or attendance would stop being the only route to event loot --
-- a rich player could grind coin chests and combine their way into the alien
-- set without ever turning up. Duplicates from an event chest are still real
-- spares, which is a small thank-you for attending, but the arrow only points
-- one way.
-- FIVE OF A TIER, NOT THREE, AND THE THIRD TIER COMING OUT IS WHY.
--
-- The old note read THREE, NOT TWO, and its arithmetic was right for FOUR
-- tiers: at 2:1 a legendary compounds out of about eight commons, which
-- makes the top tier something you manufacture rather than something you
-- get. What it did not survive is the ladder getting shorter.
--
-- THE PROPERTY IS THE RATIO BETWEEN THE TWO ROUTES, NOT THE NUMBER. Rolling
-- a legendary directly is 25 opens at 4%. Combining has always been quicker
-- than that and is supposed to be -- measured on the shipped four-tier
-- ladder it is 10.5 opens, so 2.4x. That gap is what makes spares worth
-- keeping without making the crate a common dispenser.
--
-- Dropping to three tiers moves the rung below legendary from 12% to 44%,
-- so the last hop gets dramatically cheaper and `need` has to absorb it.
-- Measured across the same odds:
--
--     need 3   4.9 opens   5.1x cheaper than rolling   -- a shortcut
--     need 4   7.0 opens   3.6x
--     need 5   9.2 opens   2.7x                        -- today's ratio
--     need 6  11.4 opens   2.2x
--
-- So 5 is where the ratio lands back on what the game already ships, and it
-- is derived from the odds rather than picked. ANYTHING THAT MOVES AN ODDS
-- ROW HAS TO RE-RUN THAT TABLE -- leaving this at 3 through the tier change
-- would have halved the cost of the top tier with nothing in any log.
Config.COMBINE = {
	need = 5,
	-- Tiers to climb, and the chance of each. Clamped at legendary, so
	-- combining epics is simply a legendary.
	odds = { [1] = 85, [2] = 12, [3] = 3 },
}

-- COIN AMOUNTS ARE FORMATTED IN ONE PLACE, because there were two and there
-- was about to be a third. `EconomyService.format` and ClientMain's own
-- `format` were byte-identical ladders over the same suffixes, and the sell
-- refusal below needs one on a service that can require neither. Config
-- requires nothing and is read by both ends, which makes it the only home
-- where a third copy is not the cheaper option.
local COIN_SUFFIXES = { "", "K", "M", "B", "T" }

function Config.formatCoins(value: number): string
	local n = math.floor(value)
	local tier = 1
	while n >= 1000 and tier < #COIN_SUFFIXES do
		n /= 1000
		tier += 1
	end
	if tier == 1 then
		return tostring(math.floor(n))
	end
	return ("%.1f%s"):format(n, COIN_SUFFIXES[tier])
end

-- WHAT A SPARE IS WORTH, AND WHY IT IS TWO NUMBERS RATHER THAN ONE.
--
-- The obvious rule is a value per TIER, derived from the drop weights that
-- already exist: 100 / 42 / 15 / 4 inverts to a ready-made 1 : 2.4 : 6.7 : 25
-- ladder. That is the right instrument, and it covers the whole catalogue --
-- the seventeen unpriced skins and all twelve accessories carry no `cost` at
-- all, so a fraction-of-price rule on its own could never have priced them.
--
-- MEASURED, THE TIER LADDER ALONE IS A MONEY PRINTER. Rarity is DERIVED from
-- the price for anything that has one and the bands are wide, so Bubblegum is
-- a common at 8,000 coins: a flat common value of 40,000 means buying it in
-- the shop and selling it straight back returns five times the money, forever,
-- with no chest involved anywhere. The tier says what something is worth in
-- general; the price says what THIS one is worth. Where they disagree the
-- price has to win, or the shop pays players to shop.
--
-- So `base` is the common's value, every tier climbs off it by the inverse
-- weight, and the result is capped at `priceFraction` of the item's own cost
-- where it has one. Measured across all four coin chests, an open that lands a
-- duplicate returns 21% to 35% of what the chest cost: always a real loss,
-- never nothing.
--
-- THE DRESS-UP CRATE IS THE ONE TO WATCH at 35%, and the reason is structural
-- rather than a tuning slip -- no accessory carries a coin price, so nothing
-- caps, and it is the cheapest chest at 350,000. Price an accessory and it
-- comes down on its own.
Config.SELL = {
	base = 40000,
	priceFraction = 0.25,
}

-- A FREE THING MAY NEVER BE SOLD, and this is the same three-source test
-- `isSkinUnlocked` already makes, from the other end.
--
-- "No cost" does not mean free: a drop-pool skin, an accessory and a set item
-- are all unpriced because they are not bought with coins at all, and each is
-- genuinely earned. What IS free is the costless-and-untagged class -- the
-- "none" effect every player owns from their first second -- and selling one of
-- those for a tier value would be a coin faucet with no source, which is the
-- exact `(nil or 0) <= 0` hole that once unlocked the Tractor Beam for the
-- whole server.
--
-- Nothing free is in a chest today, so this guards a door nobody can currently
-- reach. It is written anyway because the failure is silent: tagging a costless
-- skin into a chest would mint coins with nothing in the log to say so.
-- AND THE SECOND TEST IS WHETHER A CHEST COULD EVER HAVE DUPLICATED IT,
-- WHICH IS WHAT THE COST TEST WAS STANDING IN FOR AND GOT WRONG.
--
-- `(spec.cost or 0) > 0` admits anything with a coin price, and rides and
-- decorations have coin prices -- so the Inventory panel offered SELL on a
-- 90,000-coin BMX for 22.5K, and pressing it fired a genuine, un-refused
-- last-copy sale through the same `SetService.revoke` path a skin uses. No
-- chest in the game can produce a spare ride or a spare ornament, so that
-- was never a spare sale: it was a 75% refund on a purchase, offered in a
-- panel whose entire subject is duplicates.
--
-- IT WAS NOT AN EXPLOIT AND THAT IS WHY IT SURVIVED. `Config.SELL` caps
-- every payout at a fraction of the item's own price, so selling is always
-- a loss and there is no sell-and-rebuy loop to close. What there is, is a
-- nine-year-old refunding three quarters of the most expensive thing they
-- own, from a screen that exists to tell them spares are safe to sell.
--
-- SO THE RULE IS MEMBERSHIP OF A POOL RATHER THAN A PRICE. If no chest can
-- ever hand you a second one, there is no such thing as a spare of it, and
-- the sell control has nothing to be about. A ride or an ornament that is
-- put in a chest tomorrow becomes sellable that day with nothing here to
-- remember -- which is the same derivation `rarityOf` already uses, and the
-- reason neither can drift.
--
-- THE ALIEN SET IS WHY THIS IS NOT SIMPLY "skins, effects and
-- accessories". A set spans five catalogues, so the Hoverdisc is a RIDE
-- that a chest genuinely can duplicate. A rule written against catalogues
-- rather than against pools would have been wrong about exactly the items
-- the set economy exists to make special.
local function inAnyChestPool(kind: string, key: string): boolean
	for chestKey, chest in pairs(Config.CHESTS) do
		if chest.kind == "set" then
			local set = Config.SETS[chest.set]
			if set then
				for _, entry in ipairs(set.items) do
					if entry.kind == kind and entry.key == key then
						return true
					end
				end
			end
		elseif chest.kind == kind then
			local catalogue = Config.catalogueFor(kind)
			local spec = catalogue and catalogue[key]
			-- Mirrors `chestPool` exactly: an item earned somewhere other than
			-- the coin shop is never in a coin chest, even when its own
			-- catalogue is that chest's source table.
			if spec and spec.chest == chestKey and not Config.isEarnedElsewhere(spec) then
				return true
			end
		end
	end
	return false
end

function Config.isSellable(kind: string, key: string): boolean
	local catalogue = Config.catalogueFor(kind)
	local spec = catalogue and catalogue[key]
	if not spec then
		return false
	end

	-- THE FREE TEST STILL RUNS FIRST AND IS UNCHANGED. It is the one that
	-- guards a coin faucet rather than a bad refund, so it keeps its place
	-- at the top: a costless, untagged, unranked item is the "none" effect
	-- class, and selling one of those for a tier value mints coins from
	-- nothing.
	local earned = spec.rarity or spec.unlockRebirths or Config.isEarnedElsewhere(spec)
	if not earned and (spec.cost or 0) <= 0 then
		return false
	end

	return inAnyChestPool(kind, key)
end

-- WHAT A POOL ENTRY MEANS, AND IT LIVES HERE BECAUSE THERE ARE THREE
-- READERS NOW RATHER THAN ONE.
--
-- `chestPool` emits "kind:key" for a SET chest -- a set spans five catalogues,
-- so a bare key does not say which table to grant from -- and a bare key for
-- every other chest, where the chest's own `kind` answers it. ChestService has
-- owned that grammar since it was written and was the only thing that needed
-- it. The crates UI needs it too, to turn a pool into a strip of real item
-- previews, and the admin console needs it to seat a spare -- and a second
-- copy of a grammar is precisely what `RideSound` broke within the hour of
-- keeping one.
--
-- Config is the right home for the same reason `chestPool` itself is: it
-- requires nothing, both ends already read it, and the emitter and the reader
-- of a format belong next to each other.
--
-- It takes the chest KEY rather than the chest table, because a chest table
-- does not carry its own key and every caller already has one.
function Config.chestEntry(chestKey: string, entry: string): (string, string)
	local kind, key = entry:match("^(%a+):(.+)$")
	if kind and key then
		return kind, key
	end
	local chest = Config.CHESTS[chestKey]
	return (chest and chest.kind) or "skin", entry
end

-- What ONE spare of a thing sells for.
function Config.sellValue(kind: string, key: string): number
	local catalogue = Config.catalogueFor(kind)
	local spec = catalogue and catalogue[key]
	if not spec then
		return 0
	end
	local rarity = Config.RARITIES[Config.rarityOf(spec)]
	if not rarity then
		return 0
	end
	local value = Config.SELL.base * (Config.RARITIES.common.weight / rarity.weight)
	if type(spec.cost) == "number" and spec.cost > 0 then
		value = math.min(value, spec.cost * Config.SELL.priceFraction)
	end
	return math.floor(value)
end

-- The stock of a chest, grouped by tier, computed from the catalogues.
--
-- Returns a map of rarity -> sorted key list, and the total. Sorted because
-- `pairs` has no defined order and an unsorted pool makes the same random
-- number pick different items on different servers -- the same reason
-- `rollFrom` sorts, and the same reason a bad roll would otherwise be
-- impossible to reproduce when somebody reports one.
function Config.chestPool(chestKey: string): ({ [string]: { string } }, number)
	local chest = Config.CHESTS[chestKey]
	local pool: { [string]: { string } } = {}
	local total = 0
	if not chest then
		return pool, 0
	end

	-- A SET CHEST IS A DIFFERENT SHAPE, because a set spans five catalogues.
	-- It is resolved through the set's own item list rather than by scanning
	-- one table for a `chest` tag -- which also means a set item never needs
	-- tagging, and can never be in two chests at once.
	if chest.kind == "set" then
		local set = Config.SETS[chest.set]
		if not set then
			return pool, 0
		end
		for _, entry in ipairs(set.items) do
			local catalogue = Config.catalogueFor(entry.kind)
			local spec = catalogue and catalogue[entry.key]
			if spec then
				local tier = Config.rarityOf(spec)
				pool[tier] = pool[tier] or {}
				-- Kind AND key: a set spans catalogues, so a bare key does not
				-- say what it is or which table to grant it from.
				table.insert(pool[tier], entry.kind .. ":" .. entry.key)
				total += 1
			end
		end
		for _, keys in pairs(pool) do
			table.sort(keys)
		end
		return pool, total
	end

	local source = if chest.kind == "skin" then Config.SKINS
		elseif chest.kind == "accessory" then Config.ACCESSORIES
		elseif chest.kind == "effect" then Config.EFFECTS
		else nil
	if not source then
		return pool, 0
	end

	for key, spec in pairs(source) do
		-- `set` items are event loot and are never in a COIN chest: they are
		-- bought with event tokens in the themed chest above, which is the
		-- whole point of that currency. A PASS item is excluded by the same
		-- predicate and for a harder reason -- a chest that could hand over a
		-- paid exclusive is a paid exclusive with a coin price, which is the
		-- one thing the whole Robux position here rests on not happening.
		--
		-- Belt and braces, since a pass item carries no `chest` tag either.
		-- Stated anyway, because "it cannot reach here" is exactly what was
		-- true of the free-if-costless hole right up until it was not.
		-- TWO WAYS A CHEST CLAIMS AN ITEM, AND THE SECOND IS WHAT MAKES A
		-- RARITY TIER POSSIBLE WITHOUT RE-TAGGING THE CATALOGUE.
		--
		-- A THEMED chest names itself on each item (`chest = "animal"`), which
		-- is right for a pool that is a THEME: somebody has to decide that a
		-- zebra belongs with the fleece. A TIER chest cannot work that way --
		-- it would mean tagging every skin twice, and a skin whose price moved
		-- across a rarity band would have to be re-tagged by hand or quietly
		-- sit in the wrong crate forever, which is the failure `rarityOf`
		-- exists to make impossible.
		--
		-- So a chest carrying a `floor` takes EVERY item already in the coin
		-- crate economy at or above that tier, and the membership test is
		-- `spec.chest ~= nil` -- the same one `isStealableSkin` uses, and for
		-- the same reason: it is exactly the set that can be handed back.
		-- Adding a skin to any themed crate stocks the tier crates for free.
		local claimed = if chest.floor
			then spec.chest ~= nil
				and Config.rarityRank(Config.rarityOf(spec)) >= Config.rarityRank(chest.floor)
			else spec.chest == chestKey
		if claimed and not Config.isEarnedElsewhere(spec) then
			local tier = Config.rarityOf(spec)
			pool[tier] = pool[tier] or {}
			table.insert(pool[tier], key)
			total += 1
		end
	end
	for _, keys in pairs(pool) do
		table.sort(keys)
	end
	return pool, total
end

-- Where each slot hangs off the pig, in the same local space PiggyBank.build
-- uses -- so these move with the pig if its proportions ever change.
--
-- `anchors` is always a LIST. Three of the slots have exactly one attachment
-- point and the fourth has four, and a shoe slot that special-cased itself
-- everywhere it was read would be worse than one empty-looking loop.
--
-- AND THERE ARE TWO SETS, BECAUSE THERE ARE TWO PIGS. `anchors` is the
-- primitives piggy -- a 6-stud ball centred at y 8.5 with cylinder legs --
-- and `meshAnchors` is the generated body, which is a different animal: two
-- studs lower, four studs longer, and with its legs in different places.
-- `PiggyBank.applyAccessories` picks by whether the mesh actually stood up.
--
-- ONE SET WOULD HAVE BROKEN WHICHEVER PIG IT WAS NOT WRITTEN FOR, and the
-- failure is silent in both directions: a hat solved for the mesh sits two
-- studs inside the ball, and a hat solved for the ball floats two studs over
-- the mesh. The primitives piggy only stands when the mesh fails to load,
-- which is exactly the moment nobody is going to be checking hats.
--
-- EVERY MESH NUMBER HERE WAS MEASURED AGAINST THE SKIN RATHER THAN DERIVED
-- FROM THE BOX. A probe copy of the body at PreciseConvexDecomposition
-- collision was raycast from outside along each anchor's own direction --
-- the shipped body is Box fidelity on purpose, so raycasting the real one
-- answers with its bounding box and would put every one of these wrong.
Config.ACCESSORY_SLOTS = {
	hat = {
		order = 1, label = "HATS", empty = "Bare head",
		-- Where a hat's BRIM rests. The body is a 6-stud ball centred at y 8.5,
		-- so its top is 14.5; this sits a little into it so no gap opens under
		-- the brim. Every builder in this slot is authored with y=0 there.
		anchors = { Vector3.new(0, 14.15, 0) },
		-- AND THE Z IS THE HALF THAT MATTERED, WHICH ONLY A PICTURE SHOWED.
		-- On the ball pig z 0 IS the head, because the body is a sphere with a
		-- snout stuck on it. The generated body is four studs longer and z 0 is
		-- the middle of its BACK -- so a cap seated at the old anchor sat on
		-- the pig's shoulders, correct to the stud and obviously wrong to look
		-- at. Every anchor solved only in Y has this trap in it.
		--
		-- Swept along the spine, the crown runs y 5.22 at z 0, 5.69 at z +3,
		-- 5.38 at z +4 and 4.93 at z +5 in body-local terms: the head's own
		-- dome. The ears occupy z 3.81 to 6.40, so the cap goes at z 4 -- on
		-- the forehead, between them -- and 0.35 into a crown of 11.96, which
		-- is the same bite the ball pig's brim takes.
		-- Re-derived on the modelled body: the crown runs 11.484 at z 2,
		-- 11.305 at z 2.5 and 11.054 at z 3, and the ears occupy z 1.35 to
		-- 3.64 -- so the cap goes BETWEEN them at z 2.5, taking the same 0.35
		-- bite out of the crown that both earlier pigs took.
		-- Re-derived on the modelled body, and it goes BETWEEN THE EARS rather
		-- than dead centre because this pig's ears are 2.16 studs forward of
		-- the middle. That also keeps the brim off the coin slit, which starts
		-- roughly where the ears stop -- a hat that swallowed the slot would
		-- hide the one opening a player posts coins into.
		meshAnchors = { Vector3.new(0, 11.777, 1.856) },
	},
	eyes = {
		order = 2, label = "GLASSES", empty = "No glasses",
		-- Eye height, and far enough forward to clear the eyeballs themselves.
		-- The eyes are balls at (+/-2.35, 10.6, 4.9) whose front faces reach
		-- z 5.53, and the head's surface at that height is z 5.62 -- so a lens
		-- at 5.5 was inside both. Sits 0.28 proud of the head instead.
		anchors = { Vector3.new(0, 10.6, 5.9) },
		-- Same 0.28 proud, measured along this anchor's own direction from the
		-- mesh body's centre rather than guessed off the bounding box: the
		-- skin is 7.94 out there and the anchor is 8.22.
		-- Same 0.28 proud, measured along this anchor's own direction from
		-- the modelled body's centre: the skin is 5.773 out there.
		-- Same 0.28 proud, and solved along THIS pig's own eye line rather
		-- than the ball's, so the lenses land over the eyeballs instead of
		-- near where a different animal happened to keep them.
		meshAnchors = { Vector3.new(0, 9.134, 6.146) },
	},
	back = {
		order = 3, label = "BACKS", empty = "Nothing on the back",
		-- ON the back surface, not inside it. At y 11 the sphere's radius is
		-- 5.45, so z -5.6 sits a hair proud; -5.0 was 0.41 deep, which is why
		-- the jetpack came out of the middle of the pig.
		anchors = { Vector3.new(0, 11.0, -5.6) },
		-- A tenth proud of a skin measured at 7.91 along this direction. It
		-- still hangs over the vault hatch, which is the accepted cost this
		-- file already records: the player's own cape covers the game's tell.
		-- A tenth proud of a skin measured at 6.540 along this direction.
		-- It still hangs over the vault hatch, which is the accepted cost
		-- recorded above: the player's own cape covers the game's tell.
		-- RAISED OFF THE BALL'S OWN ANGLE UNTIL IT CLEARS THE TAIL, which was
		-- measured rather than nudged. The ball hangs a cape at 24 degrees
		-- above the horizontal and on this body that direction leaves the shell
		-- in the middle of the curl -- "a cape hung where the tail already is",
		-- which this project has recorded once. Swept upward, 48 degrees is the
		-- first that stands a clear 0.65 studs off every point of the tail.
		--
		-- It moved once already: the tail had to be raised off the vault door
		-- (it was crossing the hatch and every lock plate), and this angle is
		-- re-solved against where the tail ended up rather than kept. Anything
		-- that moves the tail again has to re-run that sweep.
		--
		-- It still hangs over the vault hatch, which is the accepted cost: the
		-- player's own cape covers the game's tell.
		meshAnchors = { Vector3.new(0, 11.191, -4.116) },
	},
	feet = {
		order = 4, label = "SHOES", empty = "Barefoot",
		-- One per leg. Legs stand at (+/-3.1, _, +/-3.1) and reach the ground
		-- at y 0.5, so a shoe centres just above that.
		-- ON THE LAWN (y 0.5 is the top of the plot slab), because both shoes
		-- are authored with y=0 as the point that touches the ground. Anchored
		-- at the middle of the shoe instead, the skates' wheels ended up under
		-- the grass.
		anchors = {
			Vector3.new(-3.1, 0.5, -3.1), Vector3.new(3.1, 0.5, -3.1),
			Vector3.new(-3.1, 0.5, 3.1), Vector3.new(3.1, 0.5, 3.1),
		},
		-- THE MESH'S LEGS ARE SOMEWHERE ELSE, and they were found by sweeping
		-- the underside rather than assumed: casting upward across the belly,
		-- the sole plane (body-local y -6.07, which is the lawn at y 0.507) is
		-- reached over x 1.8 to 3.6 and z -4.0 to -2.5 at the back and z 2.5
		-- to 4.0 at the front. So the legs centre on x 2.7 and z 3.4, not on
		-- the ball pig's 3.1 and 3.1.
		-- THE MODELLED BODY'S LEGS ARE SOMEWHERE ELSE AGAIN, and they were
		-- found the same way: casting upward across the belly, the sole plane
		-- is reached in two clusters centred on x 2.96, z 2.28 at the front
		-- and x 2.95, z -3.76 at the back. They are NOT symmetric in z --
		-- this pig's back legs sit further from the middle than its front
		-- ones -- so the four are not one number mirrored twice.
		-- STRAIGHT OFF THE MODEL'S OWN LEG CONSTANTS, so there is nothing to
		-- find by raycasting a belly: the legs are built at x +/-0.50 and y
		-- -0.48 / +0.54 in Blender, which is this at a scale of 6. They are
		-- still not symmetric front to back -- the back pair sits further out
		-- than the front -- so these are not one number mirrored twice.
		meshAnchors = {
			Vector3.new(-3.00, 0.5, -3.24), Vector3.new(3.00, 0.5, -3.24),
			Vector3.new(-3.00, 0.5, 2.88), Vector3.new(3.00, 0.5, 2.88),
		},
	},
}

-- ============================================================
-- ACCESSORIES -- RETIRED
-- ============================================================
--
-- The fourteen piggy accessories are out of the game. `PigGear.luau` is
-- UNTOUCHED and still builds every one of them, which is this file's own
-- retirement rule: a retired item loses its catalogue row and keeps its
-- builder, because a builder is the expensive half and a row is the cheap
-- one. Putting them back is re-adding rows here.
--
-- EMPTYING THE CATALOGUE IS THE SWITCH, AND THAT IS THE WHOLE REASON IT IS
-- CHEAP. Every reader in the game goes through `Config.ACCESSORIES` or
-- `Config.catalogueFor("accessory")` -- the shop grid, the inventory, the
-- wardrobe on the pig, the admin unlock, the set panel -- so an empty table
-- retires all of them at once with nothing to keep in step. `accessory` stays
-- in `COSMETIC_KINDS` and in `catalogueFor` for exactly that reason: the
-- generic machinery is what makes this reversible, and pulling the kind out
-- of it would be the change that has to be undone by hand later.
--
-- WHAT COULD NOT SURVIVE AN EMPTY CATALOGUE WENT WITH THEM, and each is
-- recorded where it was removed rather than only here:
--
--   * the Dress-Up Crate, whose entire pool was this table. A chest with an
--     empty pool takes 350,000 coins and hands over nothing, which is the one
--     failure this file calls theft rather than bad luck.
--   * the accessory ROLL, its price ladder and its loot cost. With nothing
--     rollable the button reads COLLECTION COMPLETE forever, which is a
--     control that does nothing wearing a finished state.
--   * the two ALIEN SET accessories. The set is four items now.
--   * the shop's accessory section, which would otherwise be a header over an
--     empty grid -- the exact thing the parked cars' retirement records as
--     reading like a catalogue that failed to load.
--
-- The type annotation is load-bearing under `--!strict`: a bare `{}` infers an
-- empty table type and every `Config.ACCESSORIES[key]` in the game stops
-- compiling.
Config.ACCESSORIES = {} :: { [string]: any }

-- ============================================================
-- THE ROLL CURRENCY
-- ============================================================
--
-- Acorns are the earned secondary currency. The persisted field stays
-- `data.loot`, preserving existing balances without a save migration.
-- The HUD and prices draw Theme.acorn; this table supplies their wording.
Config.ROLL_CURRENCY = {
	name = "Acorn",
	plural = "Acorns",
	-- Matches Theme.ACORN without introducing a UI dependency into Config.
	colour = Color3.fromRGB(164, 96, 49),
}

-- Phase 1 foundation for the tree's shake payout. Piggy deliveries never
-- call this. A nil victim rebirth count means a resident; zero is a player.
Config.ACORNS = {
	payout = { resident = 1, player = 5, perRebirthAbove = 1, revenge = 2 },
}

function Config.acornMultiplier(thief: number, victim: number?, revenge: boolean): number
	local payout = Config.ACORNS.payout
	if victim == nil then return payout.resident end
	local multiplier = payout.player + math.max(0, victim - thief) * payout.perRebirthAbove
	return multiplier * (if revenge then payout.revenge else 1)
end

-- Keep singular/plural wording consistent across prices and receipts.
function Config.lootWord(n: number): string
	return string.lower(if n == 1 then Config.ROLL_CURRENCY.name
		else Config.ROLL_CURRENCY.plural)
end

-- THE ROLL'S PRICE LADDER IS RETIRED WITH THE ROLL. `ROLL_BASE_COST`,
-- `ROLL_GROWTH`, `getRollCost`, `accessoryCount` and `rollableAccessoryCount`
-- all existed to price and pace the accessory collection, and there is no
-- collection to pace. `Config.ROLL_CURRENCY` and `Config.lootWord` above are
-- deliberately NOT part of this: they name the Acorn currency, which the
-- event chests still price in.


-- ============================================================
-- HOUSES
-- ============================================================
--
-- The house behind your plot is pure prestige. It confers no advantage of any
-- kind, and that is deliberate: the power balance is already a closed system
-- of speed, time and distance, and hanging a stat off a status symbol would
-- reopen every one of those decisions.
--
-- Like skins, a house SURVIVES REBIRTH. It is the long tail of the collection
-- track -- the thing a player who has bought everything else is still working
-- toward, and the thing visible from across the street that says how long
-- somebody has been playing.
--
-- Priced well above the skins so it stays the last thing anyone finishes.
-- Everything is a linear ladder, not a set to pick from: you own tier N and
-- buy tier N+1.
-- `width` is the MAIN BLOCK, not the footprint. Wings, gables and roof slabs
-- all overhang it, so the actual extent can be half as wide again -- the Manor
-- measured 65 studs against what was then a 51.2 fence interior, and its wings
-- stuck straight through the side fence. House.build now measures what it
-- actually built and seats it from that; these numbers are trimmed so the
-- measurement fits. (The interior is 67.2 now, and the widest STRUCTURE in the
-- catalogue is the Marble Palace at 49.0 -- measure with HouseFX excluded, or
-- a bounding box hands back an orbiting shard sixty studs up.)
--
-- Each tier also owns its DRIVEWAY surface. The house itself stands 70 studs
-- behind the plot, so from the road the driveway is what actually announces
-- how far along someone is -- dirt, then gravel, then brick, and so on.
Config.HOUSE_TIERS = {
	{
		name = "Starter Shack", style = "shack", cost = 0,
		drive = { colour = Color3.fromRGB(122, 98, 74), material = Enum.Material.Ground, edge = false },
		width = 18, depth = 14, storeys = 1,
		walls = Color3.fromRGB(168, 152, 130), roof = Color3.fromRGB(112, 104, 96),
		trim = Color3.fromRGB(126, 108, 86),
		blurb = "Four walls and a leaky roof. Everyone starts here",
	},
	{
		name = "Cosy Cottage", style = "cottage", cost = 35000,
		drive = { colour = Color3.fromRGB(158, 154, 146), material = Enum.Material.Pebble, edge = false },
		width = 26, depth = 20, storeys = 1,
		walls = Color3.fromRGB(232, 216, 190), roof = Color3.fromRGB(142, 78, 62),
		trim = Color3.fromRGB(120, 84, 58),
		blurb = "Low, wide, and warm. Steep tiled roof and a real chimney",
	},
	{
		name = "Brick Townhouse", style = "townhouse", cost = 120000,
		drive = { colour = Color3.fromRGB(158, 96, 78), material = Enum.Material.Brick, edge = true },
		width = 20, depth = 16, storeys = 3,
		walls = Color3.fromRGB(148, 92, 76), roof = Color3.fromRGB(74, 70, 78),
		trim = Color3.fromRGB(238, 234, 226),
		blurb = "Three floors stacked narrow. Bay window and a stoop",
	},
	{
		name = "Suburban Villa", style = "villa", cost = 400000,
		drive = { colour = Color3.fromRGB(196, 194, 188), material = Enum.Material.Concrete, edge = true },
		width = 33, depth = 24, storeys = 2,
		walls = Color3.fromRGB(236, 228, 210), roof = Color3.fromRGB(96, 104, 100),
		trim = Color3.fromRGB(198, 188, 168),
		blurb = "Sprawling, low and wide, with a double garage",
	},
	{
		name = "Stone Manor", style = "manor", cost = 1400000,
		drive = { colour = Color3.fromRGB(206, 202, 192), material = Enum.Material.Slate, edge = true },
		width = 34, depth = 28, storeys = 3,
		walls = Color3.fromRGB(214, 210, 200), roof = Color3.fromRGB(70, 66, 80),
		trim = Color3.fromRGB(188, 182, 170),
		blurb = "Symmetrical wings, stone columns, and far too many windows",
	},
	{
		name = "Midnight Modern", style = "modern", cost = 5000000,
		drive = { colour = Color3.fromRGB(32, 33, 38), material = Enum.Material.Asphalt, edge = true, lit = true },
		width = 44, depth = 32, storeys = 2,
		walls = Color3.fromRGB(26, 27, 32), roof = Color3.fromRGB(18, 19, 23),
		trim = Color3.fromRGB(240, 202, 110),
		-- The one tier that needs no deepening: the building is black, so a
		-- warm strip has the whole contrast range to itself. Stated anyway
		-- rather than left to fall back, because the fallback is what the
		-- palace and the castle both got wrong.
		fxGlow = Color3.fromRGB(255, 186, 66),
		blurb = "Blacked-out glass box. Cantilevered upper floor, rooftop terrace",
	},

	-- The three tiers above here are the endgame ladder, and they are built
	-- around one idea: HEIGHT IS THE FLEX.
	--
	-- The house stands 70 studs behind its own piggy, which is why the driveway
	-- has been carrying the announcement so far -- from the road a house is a
	-- distant shape. Anything under about three storeys is only ever seen by
	-- somebody already standing on the lawn. These three go up instead of out,
	-- so they clear the treeline and read from anywhere on the street, and
	-- they light up at night so they read in the dark too. That is the whole
	-- reward: everyone can see it without leaving their own plot.
	--
	-- They still confer nothing. Prestige only.
	{
		name = "Neon Tower", style = "tower", cost = 15000000,
		drive = { colour = Color3.fromRGB(44, 42, 58), material = Enum.Material.Asphalt, edge = true, lit = true },
		width = 24, depth = 22, storeys = 6,
		walls = Color3.fromRGB(30, 32, 44), roof = Color3.fromRGB(22, 23, 32),
		trim = Color3.fromRGB(96, 232, 246),
		glow = Color3.fromRGB(96, 232, 246),
		-- The tower's bands `cycle`, which overrides the hue every frame, so
		-- all this colour contributes is its SATURATION. At 0.61 it gives the
		-- vivid-but-not-searing wheel the rainbow wave actually wants; pushed
		-- to 1.0 the six storeys come out as pure primaries and read as a
		-- test pattern rather than as a building.
		fxGlow = Color3.fromRGB(96, 232, 246),
		blurb = "Six floors of glass with lit edges. Visible from the far end of the street",
	},
	{
		name = "Marble Palace", style = "palace", cost = 40000000,
		drive = { colour = Color3.fromRGB(228, 222, 206), material = Enum.Material.Marble, edge = true, lit = true },
		width = 46, depth = 30, storeys = 3,
		walls = Color3.fromRGB(244, 240, 230), roof = Color3.fromRGB(212, 176, 96),
		trim = Color3.fromRGB(246, 206, 108),
		-- Pulled back from (255, 226, 150), which was very nearly white and
		-- bloomed hard against marble walls of almost the same colour. This
		-- is the one tier where the glow and the building are the same
		-- brightness, so the lamp had nothing to read against.
		glow = Color3.fromRGB(232, 190, 120),
		-- Lower than the shared default as well, for the same reason.
		lanternBrightness = 0.6, lanternRange = 15,

		-- A SEPARATE, MUCH DEEPER COLOUR FOR THE ANIMATED NEON, and the note
		-- above is exactly why it has to exist. `glow` is a LANTERN colour,
		-- tuned pale on purpose so a soft lamp sits on white marble without
		-- flaring. Neon is not a lamp: it renders the colour flat out and the
		-- BloomEffect takes it from there, so the same pale cream that reads
		-- as a warm bulb reads as a hole cut in the building -- measured on
		-- the first build of the lit steps, which came out as one white blob
		-- across the whole frontage with nothing in it anybody could name.
		--
		-- What a saturated hue buys is that the effects still say GOLD at
		-- full brightness. The colonnade and the steps are white; only a
		-- colour a long way from white can be seen against them.
		fxGlow = Color3.fromRGB(255, 166, 24),
		blurb = "Gold dome, colonnade, and lantern-lit steps. Unsubtle on purpose",
	},
	{
		-- 80M AND NOT 100M, BECAUSE 100M WAS A PRICE NO WALLET COULD HOLD.
		-- The largest pig this game can produce is capacity level 40 at
		-- 96.9M, so the best house in the catalogue could not be bought by
		-- earning at any rebirth count, for any length of time -- it read as
		-- a buy button that never lights rather than as something expensive.
		-- Robbing overflows the cap and was the only route to it, which is
		-- not a route a solo player or a quiet server has. See
		-- Config.auditEconomy, which now says so at startup.
		--
		-- The ladder is 15M, 40M, 80M: a 2x step where the others are 2.7x
		-- and 2.5x, so the top rung got slightly closer rather than the whole
		-- curve moving. It is still 83% of the largest pig in the game and
		-- still the last thing anybody finishes.
		name = "Sky Castle", style = "castle", cost = 80000000,
		drive = { colour = Color3.fromRGB(126, 122, 130), material = Enum.Material.Cobblestone, edge = true, lit = true },
		width = 40, depth = 34, storeys = 5,
		walls = Color3.fromRGB(158, 156, 166), roof = Color3.fromRGB(92, 52, 128),
		trim = Color3.fromRGB(212, 74, 96),
		glow = Color3.fromRGB(196, 128, 255),
		-- Same split as the palace, milder cause. (196, 128, 255) is a pale
		-- lilac -- fine as a lamp on grey stone, and at Neon it bloomed the
		-- floating shards' undersides out to plain white, so the one thing
		-- meant to say "magic" said "lit from below" instead.
		fxGlow = Color3.fromRGB(198, 42, 255),
		blurb = "Four turrets, battlements and a banner. The last thing anyone buys",
	},
}

-- Level 0 is the Starter Shack, which everyone owns from the first second.
function Config.getHouseTier(level: number)
	return Config.HOUSE_TIERS[math.clamp(level + 1, 1, #Config.HOUSE_TIERS)]
end

function Config.getHouseUpgradeCost(level: number): number?
	local next_ = Config.HOUSE_TIERS[level + 2]
	return if next_ then next_.cost else nil
end

Config.MAX_HOUSE_LEVEL = #Config.HOUSE_TIERS - 1

-- Which house is STANDING, as opposed to which is the highest one bought.
--
-- A house is prestige, and prestige is a matter of taste: someone who liked
-- the look of the Beach Villa should not be forced to live in a Neon Tower
-- forever because they bought one. So the ladder and the display are two
-- different numbers -- `houseLevel` is the rung reached, and decides what is
-- for sale next; `houseShown` is what is actually built on the plot.
--
-- Clamped against the ladder, so a save that somehow carries a shown tier
-- above the owned one builds the owned one rather than a house nobody paid
-- for. Missing means "the newest", which is how every pre-schema-9 save reads.
function Config.getShownHouseLevel(data: any): number
	local owned = data.houseLevel or 0
	local shown = data.houseShown
	if type(shown) ~= "number" then
		return owned
	end
	return math.clamp(math.floor(shown), 0, owned)
end

-- ============================================================
-- ADMIN
-- ============================================================
--
-- Roblox UserIds allowed to use the admin panel. A UserId is public
-- information -- anyone can read it off a profile page -- so there is nothing
-- secret here and nothing is weakened by this file being public.
--
-- The security is NOT this list. It is that AdminService re-checks every
-- single request against it on the SERVER before doing anything. The client
-- panel only exists to save the admin some typing; hiding a button protects
-- nothing, because anyone can fire a RemoteEvent.
--
-- The place owner is also admitted automatically, in AdminService, so this
-- keeps working if the experience is republished under another account.
Config.ADMINS = {
	[1403296598] = true,
}

function Config.isAdminUserId(userId: number): boolean
	return Config.ADMINS[userId] == true
end

-- Bumped for `sinceLegendary`. DataService.reconcile fills it in on old saves.
-- ============================================================
-- LAWN DECORATIONS
-- ============================================================
--
-- Bought, then placed AUTOMATICALLY into the next free slot for their zone.
--
-- There is deliberately no placement mode and no prompts on the lawn. A plot
-- already carries a collect prompt and a steal prompt, and adding six more
-- would clutter exactly the ground an owner is trying to defend on. Buying it
-- and having it appear is also one tap instead of four, which matters for the
-- age group and on touch.
--
-- Every decoration is non-colliding scenery, so none of this can body-block a
-- defender, a thief, or the dog.
--
-- Slot offsets are plot-local with +Z toward the street. See DECOR_SLOTS for
-- what they avoid and why the spacing is what it is -- and note this comment
-- used to name a kennel at (14, 4) and a sign post at (0, 22), neither of
-- which is where those things are any more.
-- Where the road, verge and driveway sit between two facing rows.
--
-- Shared because PlotService now builds a per-house driveway and
-- NeighborhoodService still lays the road, and the two must agree exactly or
-- the driveway floats over the kerb. Returns plot-local Z distances measured
-- from a plot's own centre, with +Z toward the street.
-- Built once and handed out. `isOnStreet` runs on a tick for every player
-- with a ride, and a fresh table per call would be a hundred allocations a
-- second to answer a question about four constants. Treat the result as
-- read-only: everybody shares this table.
local streetCache: any = nil

function Config.streetMetrics()
	if streetCache then
		return streetCache
	end

	local streetHalf = Config.STREET_SPACING / 2
	-- THE FRONT LINE, NOT THE HALF WIDTH. These were the same number while the
	-- plot was square; they are not any more, and everything below this
	-- measures how far the verge reaches BACK from the road -- the ride gate's
	-- boundary, both boards and all four shop fronts. Taking the X half here
	-- would move all of them eight studs onto the carriageway side of where
	-- they belong. See PLOT_HALF_WIDTH.
	local fenceOffset = Config.PLOT_FRONT_LINE

	-- Where the street begins and ends along its own length. These used to
	-- live in NeighborhoodService, which is the file that draws them -- but
	-- RideService has to know where the street IS in order to keep vehicles on
	-- it, and a second copy of this arithmetic is exactly how the carriageway
	-- and the driveway drifted apart the last time. One source.
	local endX = Config.plotColumnX(Config.PLOTS_PER_ROW - 1)

	-- THE VERGE: the band between the kerb and the front fences, and the one
	-- piece of ground on this street that belongs to nobody and is wide enough
	-- to build on. Everything that is not a house stands here.
	local fenceLine = Config.STREET_SPACING / 2 - fenceOffset

	streetCache = {
		-- Street coordinates, measured from the road's centreline.
		roadHalfWidth = Config.ROAD_HALF_WIDTH,
		fenceLine = fenceLine,

		-- WHERE THINGS STAND ON THE VERGE, derived rather than written down
		-- twice. SocialService places the boards and NeighborhoodService the
		-- shops, and at 104 both had hardcoded numbers that only happened to
		-- fit -- the board's was measured against a tunnel bore it no longer
		-- stands at. Widen the street and these follow.
		--
		-- Boards mid-verge, so they read from the carriageway and from the
		-- pavement; shops set back against the fence, behind the lamp posts
		-- and bins that sit just off the kerb.
		boardZ = (Config.ROAD_HALF_WIDTH + fenceLine) / 2,
		-- 14 back from the fence line, not 12. At 12 the forecourt reached
		-- |z| 42.1 against a front ClimbZone that stands proud at 44.9 --
		-- 2.8 studs, measured, and the fence trigger is the thing to measure
		-- against rather than the fence LINE. 14 makes it 4.8 and still
		-- leaves ten studs of pavement between the forecourt and the kerb,
		-- which is where the lamp post and the bin stand at 9.8.
		shopZ = fenceLine - 14,

		-- Plot-local Z of the driveway's two ends: the fence, out to the kerb.
		driveNear = fenceOffset,
		driveFar = streetHalf - Config.ROAD_HALF_WIDTH,

		-- Centre of the outermost plot on each end of the row.
		endX = endX,

		-- THE ROAD IS SYMMETRIC NOW, because there is no longer a closed end.
		-- It used to run from the lip of the bulb at the west to a run-off
		-- past the last plot at the east; with the square in the middle both
		-- ends are the same thing, and the patrol drives in one hill and out
		-- of the other rather than reversing out of the one it arrived by.
		roadStartX = -(endX + Config.PLOT_SIZE.X / 2 + 60),
		roadEndX = endX + Config.PLOT_SIZE.X / 2 + 60,

		-- THE TUNNEL MOUTHS, at each end of the street.
		--
		-- The police car used to appear at the road end out of nothing and
		-- vanish the same way. It now drives out of a hillside at the open
		-- end and away into the one behind the plaza, so the patrol arrives
		-- from somewhere and leaves for somewhere.
		--
		-- These are the MOUTH FACES: the recess runs from here away from
		-- the street by tunnelDepth, and the car spawns inside it. They
		-- live here rather than in NeighborhoodService because two files
		-- need them -- the one that draws the tunnel and the one that
		-- drives through it -- and a second copy of this arithmetic is
		-- exactly how the carriageway and the driveway drifted apart.
		tunnelEastX = endX + Config.PLOT_SIZE.X / 2 + 60,
		tunnelWestX = -(endX + Config.PLOT_SIZE.X / 2 + 60),
		tunnelDepth = 22,
		tunnelHalfWidth = 11,
		tunnelHeight = 14,
	}
	return streetCache
end

-- Is this position out on the street?
--
-- "The street" is the public corridor BETWEEN the two rows of front fences,
-- the town square in the middle of it included. That is deliberately narrower
-- than "not
-- inside a yard": the woodland behind the plots and the twelve-stud alleys
-- between neighbouring yards are neither a garden nor a street, and a player
-- doing 33 studs a second through the trees behind somebody's house is not
-- what a ride is for.
--
-- Measured on the WORLD z axis rather than per plot, because the two rows are
-- symmetric about the road's centreline -- which is the one fact that makes
-- this a two-comparison test instead of a loop over twelve plots.
function Config.isOnStreet(position: Vector3): boolean
	local m = Config.streetMetrics()

	-- ONE TEST NOW. The square used to need a branch of its own because it
	-- sat OUTSIDE the corridor, off the west end past `roadStartX`. In the
	-- middle it is simply the street being wider for sixty studs, and its
	-- depth is sized to the corridor exactly so this covers it -- which is
	-- also why a ride does not switch off as somebody crosses the square.
	return math.abs(position.Z) <= m.fenceLine
		and position.X >= m.roadStartX
		and position.X <= m.roadEndX
end

-- The driveway is the one strip of ground outside the fence that must stay
-- usable at every tier, so the top-tier moat leaves a causeway across it.
-- Deliberately independent of the fence gate: a bridge can be wide while the
-- gate behind it stays narrow, so this costs the defender nothing.
-- 13 -> 17, BECAUSE IT DID NOT SCALE WHEN THE PLOT DID. The plot went 48 wide
-- to 64 and this stayed put, so the drive went from 27% of a frontage to 20%
-- and started reading as a path. 17 is the same proportion it always had.
--
-- Note this does NOT buy dry ground beside it at fence tier 5, which is the
-- obvious reason to reach for it and the wrong one -- see the note on the
-- verge slots in DECOR_SLOTS. The causeway is the paving plus one stud, so
-- widening the drive widens the bridge and moves the waterline with it.
Config.DRIVEWAY_WIDTH = 17

-- Every slot faces the ROAD, and none of them carries a yaw.
--
-- Plot-local +Z is the street on both rows -- the far row is built with a
-- half-turn already in its plot CFrame -- and every ornament is authored
-- facing +Z. So the slot rotation that used to scatter them by 20, 90, 155,
-- 200 degrees was rotating each one AWAY from the only angle it is ever
-- viewed from.
--
-- That scatter was meant to read as a garden arranged by hand rather than a
-- showroom, and on a plan view it did. From the pavement it did not: the two
-- back slots were turned past 90 degrees, so the trophy showed its blank
-- back, the drip statue faced its own house, and the shark -- whose entire
-- silhouette is its side profile -- was nose-on again, which is the exact
-- bug its builder was rewritten to fix. An ornament has one good angle and
-- the viewer only ever stands in one place, so pointing it anywhere else
-- spends the ornament to buy a variety nobody is standing where they could
-- see.
--
-- It also fixed a spacing problem rather than causing one. The tight pairs
-- on this ring are the three front slots, separated along X at 17 studs;
-- with every item now square to the street their long axes run along X too,
-- and the two widest -- the gnome at 12.5 across the fists and the shark at
-- 13.7 nose to tail -- still clear each other. The side pairs are separated
-- along Z at 15 to 16, against a depth of about 5. Facing everything forward
-- turned the deepest ornaments side-on to their nearest neighbour.
--
-- `Decor.build` still reads `slot.yaw`, so a future slot that genuinely
-- wants an angle can carry one. Nothing here does.
-- LAID OUT AS ROWS, NOT AS A RING, AND THE SPACING IS TWO NUMBERS THAT COVER
-- EVERY PAIR.
--
-- The old ring was seven positions 15 to 19 studs apart and it was BROKEN:
-- built and measured against every ornament, four of the seven put the widest
-- item through a side fence and two adjacent pairs overlapped outright.
--
-- Ornaments are shallower than they are wide, so two slots whose Z differs by
-- at least the deepest ornament CANNOT overlap whatever stands in them, and
-- two whose X differs by at least the widest cannot either. That is two
-- numbers covering EVERY pairing in the catalogue instead of a per-pair
-- clearance nobody will re-check when the next ornament lands.
--
-- THE COUNT USED TO BE WRITTEN OUT HERE AND IT DRIFTED, WHICH IS THE
-- SMALLEST POSSIBLE EXAMPLE OF THE THING THIS COMMENT IS ABOUT. It said
-- 324 -- eighteen lawn items squared -- and it was right the day it was
-- typed. Four trophies later there are twenty-two and the honest figure is
-- 484, and the same number sat stale at 196 in `docs/GAME.md` and still
-- does in CLAUDE.md's own post-mortem. Three copies of one DERIVED figure,
-- three different values, none of them erroring. The rule is what matters
-- and the count is `#items` squared for anybody who wants it.
-- Measured: widest 13.70
-- (Shark In Trainers), deepest 11.00 (Giant Rubber Duck). Columns are 16.5+
-- apart and rows 12, both with margin.
--
-- MEASURE ORNAMENTS PER PART, NEVER OFF `Model:GetBoundingBox`. That box is
-- oriented by the model's PIVOT, which inherits the rotation of whatever part
-- the builder happened to make first -- so any ornament whose first part is an
-- upright cylinder reports its width and height SWAPPED. Six of the eighteen
-- do. The first version of this grid was built on a "widest ornament" of 21.08
-- studs, which is the Wacky Waving Man's HEIGHT; it is 9.03 wide. The Sky
-- Castle's long-recorded 16.6-stud overhang was the same mistake.
--
-- The grid is 4 rows x 4 columns and seven of the sixteen are spoken for. The
-- piggy bank sits in the middle; the walk from the gate to it is the whole
-- centre for any row in FRONT of the piggy, and the gate is 24 wide so that
-- corridor is wider than the driveway outside it; the kennel holds the
-- front-right corner.
--
-- Offsets are plot-local with +Z toward the street. Verified by building every
-- lawn ornament in every slot at once: no overlaps, nothing through a fence.
Config.DECOR_SLOTS = {
	-- Back row. The only one that gets all four columns, because it is behind
	-- the piggy and there is no gate walk to keep clear back there.
	{ id = "lawnA", zone = "lawn", offset = Vector3.new(-25, 0, -20) },
	{ id = "lawnB", zone = "lawn", offset = Vector3.new(-8.5, 0, -20) },
	{ id = "lawnC", zone = "lawn", offset = Vector3.new(8.5, 0, -20) },
	{ id = "lawnD", zone = "lawn", offset = Vector3.new(25, 0, -20) },

	-- Middle rows, outer columns only: the inner pair is inside the piggy at
	-- z -8, and inside both the piggy and the gate walk at z +4.
	{ id = "lawnE", zone = "lawn", offset = Vector3.new(-25, 0, -8) },
	{ id = "lawnF", zone = "lawn", offset = Vector3.new(25, 0, -8) },
	{ id = "lawnG", zone = "lawn", offset = Vector3.new(-25, 0, 4) },
	{ id = "lawnH", zone = "lawn", offset = Vector3.new(25, 0, 4) },

	-- Front row, left only. The front-right corner is the kennel -- see the
	-- GuardDog.build call in PlotService.buildPlot.
	{ id = "lawnI", zone = "lawn", offset = Vector3.new(-25, 0, 16) },

	-- Outside the fence, and OUTBOARD OF THE MOAT rather than beside the gate.
	--
	-- THEY USED TO BE AT z 31, AND THEY WERE UNDERWATER. The comment here
	-- claimed this was "the ONLY ground out there that stays dry at every fence
	-- tier"; measured on a live tier-5 fence, both slots sat inside a MoatWater
	-- band. The dry causeway is `max(gate, DRIVEWAY_WIDTH + 1)` wide -- 14
	-- studs, so |x| < 7 -- and these were at +-9.5, two and a half studs into
	-- the water on each side.
	--
	-- WIDENING THE DRIVEWAY CANNOT FIX THAT, WHICH IS THE COUNTER-INTUITIVE
	-- PART. The causeway is defined as the paving plus one stud, so both edges
	-- move together and the dry strip beside the drive stays half a stud wide
	-- at ANY driveway width. Widening the causeway independently would work and
	-- is worse: fitting even a small ornament needs about 25 studs of bridge
	-- against a gate of 24, which makes the whole gate approach dry and stops
	-- tier 5's moat doing anything on the side people actually walk in from.
	--
	-- So they moved OUT instead of the water moving. The moat and its banks
	-- reach z 31.6 and the kerb is at 38.4, which leaves a band that is dry at
	-- every tier by construction and needs nothing widened. Measured across it
	-- at +-9.5: wet through z 32, dry from z 33 out. z 35 is the middle of it.
	--
	-- x +-22 RATHER THAN FLANKING THE DRIVE, because the plot sign is out here
	-- too and it is bigger than it looks: nine parts spanning x 8.9 to 17.5 and
	-- z 33.7 to 36.9, which is most of the right-hand half of this band. 22
	-- clears it by 4.5 and the driveway by 13.5.
	--
	-- THE ENVELOPE IS TIGHT AND IT IS THE BAND, NOT THE SLOT: an ornament here
	-- may be about 6.8 deep before it touches the moat behind or the kerb in
	-- front, and about 9 wide before the right-hand one reaches the sign. The
	-- lawn is where anything larger goes.
	{ id = "vergeL", zone = "verge", offset = Vector3.new(-22, 0, 35) },
	{ id = "vergeR", zone = "verge", offset = Vector3.new(22, 0, 35) },
}

Config.DECOR_ITEMS = {
	flowerbed = {
		name = "Flower Bed", zone = "lawn", style = "flowers", order = 1,
		cost = 15000, swatch = Color3.fromRGB(214, 96, 132),
		blurb = "A splash of colour by the fence",
	},
	picnic = {
		name = "Picnic Table", zone = "lawn", style = "picnic", order = 2,
		cost = 45000, swatch = Color3.fromRGB(168, 124, 82),
		blurb = "Bench, table, parasol. Very neighbourly",
	},
	hoop = {
		name = "Basketball Hoop", zone = "lawn", style = "hoop", order = 3,
		cost = 110000, swatch = Color3.fromRGB(226, 116, 54),
		blurb = "Backboard and rim, out by the drive",
	},
	topiary = {
		name = "Topiary Piggy", zone = "lawn", style = "topiary", order = 4,
		cost = 260000, swatch = Color3.fromRGB(96, 150, 84),
		blurb = "A hedge trimmed into a pig. Obviously",
	},
	fountain = {
		name = "Stone Fountain", zone = "lawn", style = "fountain", order = 5,
		cost = 600000, swatch = Color3.fromRGB(198, 198, 190),
		blurb = "Three tiers and real running water",
	},

	-- ------------------------------------------------------------
	-- The silly shelf
	-- ------------------------------------------------------------
	--
	-- The first five lawn items are things a real garden has. These are not,
	-- and that is the point: a fountain says you are rich, a shark in trainers
	-- says you are rich AND you thought this was funny. Only the second one
	-- gets talked about, and being talked about is what a status item is FOR.
	--
	-- They are priced above the sensible ornaments for the same reason. The
	-- joke is the expensive part.
	--
	-- Every one of these is an ORIGINAL shape rather than a copy of a specific
	-- meme character. That is a shipping requirement, not squeamishness: the
	-- named ones -- brands, cartoon characters, the big brainrot names -- are
	-- somebody's trademark or copyright, Roblox moderation removes them, and a
	-- takedown costs the whole experience rather than the one ornament. The
	-- genre travels fine without the name: an enormous rubber duck is funny on
	-- its own, and a shark wearing trainers does not need to be anyone's
	-- shark.
	bigduck = {
		name = "Giant Rubber Duck", zone = "lawn", style = "bigduck", order = 10,
		cost = 80000, swatch = Color3.fromRGB(248, 208, 48),
		blurb = "Bath toy. Wrong scale. No explanation",
	},
	buffgnome = {
		name = "Swole Gnome", zone = "lawn", style = "buffgnome", order = 11,
		cost = 220000, swatch = Color3.fromRGB(212, 74, 68),
		blurb = "The gnome, but he lifts. Arms bigger than the hat",
	},
	tubeman = {
		name = "Wacky Waving Man", zone = "lawn", style = "tubeman", order = 12,
		cost = 500000, swatch = Color3.fromRGB(248, 118, 42),
		blurb = "The inflatable one from the car dealership",
	},
	looguy = {
		name = "Loo Guy", zone = "lawn", style = "looguy", order = 13,
		cost = 900000, swatch = Color3.fromRGB(238, 240, 244),
		blurb = "A toilet. With a head in it. Grinning at the street",
	},
	sharkshoes = {
		name = "Shark In Trainers", zone = "lawn", style = "sharkshoes", order = 14,
		cost = 2000000, swatch = Color3.fromRGB(86, 138, 190),
		blurb = "A shark. Standing on three white trainers",
	},
	trophy = {
		name = "Best Yard Trophy", zone = "lawn", style = "trophy", order = 15,
		cost = 4000000, swatch = Color3.fromRGB(232, 190, 74),
		blurb = "Nobody gave you this. You bought it yourself",
	},
	dripstatue = {
		name = "Drip Statue", zone = "lawn", style = "dripstatue", order = 16,
		cost = 12000000, swatch = Color3.fromRGB(28, 28, 32),
		blurb = "Big head, bigger chain, designer bag. Solid gold plinth",
	},

	bracestatue = {
		name = "Brace Face", zone = "lawn", style = "bracestatue", order = 17,
		cost = 3000000, swatch = Color3.fromRGB(122, 154, 74),
		blurb = "A garden turtle with a full set of train tracks",
	},

	-- NO WHEELIE BINS HERE ANY MORE. They are PUBLIC street furniture now,
	-- built with the road by NeighborhoodService and enterable by anybody.
	-- Selling an identical-looking one as a decoration would put two objects
	-- on the same street that a player cannot tell apart, where one can be
	-- hidden in and one cannot -- which is a worse tell than no bin at all.
	-- The GEOMETRY is still here (builders.bins); only the purchase is gone.
	gnome = {
		name = "Garden Gnome", zone = "verge", style = "gnome", order = 7,
		cost = 180000, swatch = Color3.fromRGB(206, 68, 62),
		blurb = "Stands guard by the drive. Does nothing",
	},

	-- NO PARKED CARS EITHER, and with them the whole DRIVEWAY zone: they were
	-- the only two items that could ever stand in it, so the slot and the
	-- shop section went with them.

	-- ALIEN SET. Built by delegating to AlienModel.buildDrone, so the ornament
	-- on the lawn is LITERALLY the thing that was on your piggy bank -- one
	-- builder, and a trophy that cannot drift from what it commemorates.
	crashedDrone = {
		name = "Crashed Drone", zone = "lawn", style = "crashedDrone", order = 20,
		set = "alien", loot = 18, rarity = "rare", swatch = Color3.fromRGB(96, 255, 176),
		blurb = "One you knocked out of the sky, still smoking",
	},

	-- THE CANDY GARDEN. See the long note above `builders.slimepond` in
	-- Decor.luau for why these are shapes rather than jokes -- briefly, a meme
	-- dates and a gummy bear does not, and none of this is anybody's property.
	--
	-- The meme ornaments are NOT retired. They are built, priced and already on
	-- lawns, and with eight curated slots a mixed garden is the point.
	--
	-- `order` continues from the drone at 20. Prices fill the gaps in the
	-- existing 15K..12M ladder rather than extending it; the 200M+ giants are a
	-- separate tier and go UP rather than out, because the slot grid caps an
	-- ornament at 22 wide by 12 deep.
	jellycube = {
		name = "Jelly Cube", zone = "lawn", style = "jellycube", order = 21,
		cost = 150000, swatch = Color3.fromRGB(240, 176, 64),
		blurb = "Wobbles in the sun. Do not lick it",
	},
	gummybear = {
		name = "Gummy Bear", zone = "lawn", style = "gummybear", order = 22,
		cost = 700000, swatch = Color3.fromRGB(226, 82, 96),
		blurb = "Six feet of strawberry, staring at the street",
	},
	trampoline = {
		name = "Trampoline", zone = "lawn", style = "trampoline", order = 23,
		cost = 3500000, swatch = Color3.fromRGB(72, 138, 226),
		blurb = "This one actually bounces you",
	},
	slimepond = {
		name = "Slime Pond", zone = "lawn", style = "slimepond", order = 24,
		cost = 6000000, swatch = Color3.fromRGB(126, 222, 78),
		blurb = "Suspiciously green. Definitely bubbling",
	},

	-- ------------------------------------------------------------
	-- THE TROPHIES
	-- ------------------------------------------------------------
	--
	-- MONEY BUYS THE FRAME; ROBBERY BUYS THE PICTURE. These four are the
	-- only entries in this catalogue with NO `cost`, and that is the whole
	-- of what makes them trophies: nothing in the shop sells one, and the
	-- only thing that hands one over is the thing it is a record of.
	--
	-- THEY ARE ORDINARY DECOR ITEMS IN EVERY OTHER RESPECT, and that is
	-- the decision worth recording rather than the geometry. A trophy
	-- placed, put away, auto-slotted, rebuilt on a plot and rendered on a
	-- shop card is `data.decor` doing all five, unchanged -- so the whole
	-- feature cost one field here and one branch in `buyDecor`. The
	-- alternative was a parallel `data.trophies.placed` with its own slot
	-- grid, which is nine accessors with a decor-shaped hole under every
	-- one. WHEN A NEW THING HAS TO BEHAVE LIKE AN EXISTING THING IN
	-- TWENTY PLACES, MAKE IT ONE -- the same call the shops made.
	--
	-- IT ALSO MAKES THE SLOTS SCARCE BY CONSTRUCTION, which `docs/MASTER-PLAN.md`
	-- asks for in as many words: there are nine lawn slots, eighteen
	-- ornaments and now four trophies, so displaying what you have DONE
	-- costs a slot you were using to display what you BOUGHT. Choosing is
	-- the whole of what makes a shelf mean anything, and that argument
	-- does not survive giving trophies a grid of their own.
	--
	-- EVERY ONE CARRIES AN EXPLICIT `rarity`, and it is load-bearing rather
	-- than decoration: `Config.rarityOf` reads a PRICE when there is no
	-- explicit tier, so an unpriced trophy would border as `common` -- the
	-- exact trap the pass skins and the dog kennels each have a note about.
	--
	-- AND `Config.isEarnedElsewhere` NOW READS `trophy`, which is one line
	-- covering ten sites: no trophy can fall out of a chest, and none can
	-- be sold back for coins through the free-if-costless branch that once
	-- unlocked the Tractor Beam for an entire server.
	victimshelf = {
		name = "Victim Shelf", zone = "lawn", style = "victimshelf", order = 40,
		trophy = "victimshelf", rarity = "legendary",
		swatch = Color3.fromRGB(226, 138, 170),
		blurb = "A little pig for every skin you have robbed",
	},
	haulvault = {
		name = "The Haul", zone = "lawn", style = "haulvault", order = 41,
		trophy = "haulvault", rarity = "epic",
		swatch = Color3.fromRGB(226, 186, 86),
		blurb = "An open safe, and it fills up as you take more",
	},
	medalboard = {
		name = "Medal Board", zone = "lawn", style = "medalboard", order = 42,
		trophy = "medalboard", rarity = "epic",
		swatch = Color3.fromRGB(196, 72, 88),
		blurb = "One rosette for every thief stopped on your lawn",
	},
	sirenpost = {
		name = "Siren Post", zone = "lawn", style = "sirenpost", order = 43,
		trophy = "sirenpost", rarity = "rare",
		swatch = Color3.fromRGB(72, 132, 226),
		blurb = "A lamp for every patrol you have outrun",
	},
}

-- ============================================================
-- THE GARDEN
-- ============================================================
--
-- PLANTING IS EXPRESSION THAT DOES NOT SPEND A TROPHY SLOT, AND THAT IS THE
-- WHOLE REASON THESE ARE NOT ORNAMENTS.
--
-- There are nine lawn slots and twenty-odd things that want to stand in them,
-- and `docs/MASTER-PLAN.md` is explicit that the scarcity IS the feature:
-- choosing what to display is what makes the shelf mean anything, and that
-- argument does not survive adding slots to fit more things. A border of
-- plants added as ornaments would have cost a slot per plant, so a player who
-- wanted a garden would have had to clear their shelf to get one -- which is
-- the opposite of what a garden is for.
--
-- So a border, a path and a window box are PLOT-WIDE COSMETICS: one equipped
-- at a time out of its own catalogue, rendered along geometry the plot already
-- has, consuming no slot at all. Same shape as the dog's coat and kennel, and
-- for the same reason -- `DOG_COATS` is a wardrobe over an animal that exists,
-- and these are a wardrobe over a fence, a gate walk and a house that exist.
--
-- WHAT THEY MAY NEVER DO is the third rule `docs/MASTER-PLAN.md` sets and every
-- phase of it re-reads: A COSMETIC MAY NEVER IMPLY A TIER THAT HAS NOT BEEN
-- BOUGHT. Nothing here reaches `scale`, `shape`, a fence tier, a lock tier or
-- a dog tier; all three are colour and geometry on ground nobody prices a
-- robbery on. They are also `CanCollide` and `CanQuery` off like everything
-- else on a lawn, so none of them can body-block a thief, a defender or the
-- dog, and none can eat a raycast meant for a piggy.

-- HOW TALL A BORDER MAY STAND, AND IT IS DERIVED RATHER THAN TYPED.
--
-- `docs/MASTER-PLAN.md` states the cap in prose: "anything above roughly the
-- fence's own `decorTop` starts hiding the piggy from the pavement, which is
-- the object the whole decision is about." That is the right constraint and
-- "roughly" is the wrong way to ship it -- a pinned number describes the
-- fence ladder as it was on the day somebody typed it, which is exactly how
-- `SHOP_BANK_PIG_SECONDS` came to be wrong by 62% and how the vault opening
-- came to be sized against one of four lock tiers.
--
-- THE DERIVATION IS EXACT RATHER THAN APPROXIMATE, and that is worth stating
-- because it makes the guarantee provable instead of tasteful. A border
-- stands ON THE FENCE LINE. A plant of height H standing on the fence line
-- occludes precisely the sightline a fence of height H occludes -- same
-- ground, same distance from the viewer, same distance from the pig. So a
-- border clamped to `decorTop` HIDES NOTHING THE FENCE DOES NOT ALREADY HIDE,
-- by construction, at every tier and from every camera on the pavement. There
-- is no measurement to redo when a tier's height moves and no audit to write.
--
-- WHAT IT COSTS, STATED PLAINLY: YOUR FENCE TIER NOW SETS HOW TALL YOUR
-- GARDEN MAY BE. Rickety clamps to 4.2 and the Moat to 8.9, so the same
-- Sunflowers are a low run on a cheap fence and a full hedge behind an
-- expensive one. That is a real coupling between a defence purchase and a
-- cosmetic one, and it is the honest direction: the tall garden is available
-- to the player who has already paid to hide their own pig, and never to the
-- one who has not. A cosmetic that could out-reach the fence would be a
-- cosmetic implying a tier, which is the rule above.
-- AND IT IS INDEXED THE WAY `buildFence` INDEXES, WHICH IS NOT THE OBVIOUS
-- WAY AND COST THE WHOLE GUARANTEE FOR AN AFTERNOON.
--
-- `FENCE_TIERS` is 1-based and a level of 0 means NO FENCE, so the tier
-- standing at level N is `FENCE_TIERS[N]` and not `FENCE_TIERS[N + 1]`.
-- Written the obvious way this clamped against the tier ABOVE the one
-- actually built: measured on a live plot at level 2, a Sunflower border
-- stood at y 8.64 against a picket fence whose visible top is 5.10 -- three
-- and a half studs of garden over the top of the thing it is bounded by,
-- which is precisely what the derivation exists to make impossible.
--
-- NOTHING IN ANY PROBE COULD SEE IT, because every check compared the border
-- against `borderHeight`'s own answer and they agreed with each other
-- perfectly. It took a PHOTOGRAPH from the pavement -- which is this
-- project's own rule for anything whose whole purpose is being read from
-- there, and which had been skipped here in favour of numbers that were all
-- internally consistent and all measured against the wrong tier. A
-- MEASUREMENT AGAINST A MODEL OF A THING IS NOT A MEASUREMENT OF THE THING.
function Config.borderHeight(spec: any, fenceLevel: number): number
	local tier = Config.FENCE_TIERS[math.clamp(fenceLevel, 1, #Config.FENCE_TIERS)]
	-- `decorTop` and NOT `top`: the barrier is what a jump is measured against
	-- and the DECOR line is what a viewer actually sees, which is the pair
	-- `buildFence` already keeps apart and the pair this file records somebody
	-- confusing once. A border is a visual, so it takes the visual height.
	-- LESS `LAWN_LIFT`, BECAUSE THE FENCE AND THE GARDEN STAND ON DIFFERENT
	-- GROUND, AND THAT IS A TRAP THIS PROJECT HAS ALREADY PAID FOR ONCE.
	--
	-- A fence is built from `FENCE_BASE_Y`, the world ground; a border is
	-- planted on the LAWN, which is the plot slab a stud above it. So a plant
	-- clamped to the raw `decorTop` starts a stud higher than the fence does
	-- and finishes a stud above it -- measured on the live ladder, a Sunflower
	-- border stood at 4.45 / 5.68 against fences whose decoration tops out at
	-- 3.20 / 4.60.
	--
	-- This is the SAME asymmetry that made three fence tiers hoppable in one
	-- direction only: "a fence is a stud taller from the street than from the
	-- lawn", recorded when `BASE_JUMP_HEIGHT` was retuned. It bites here from
	-- the other side -- the lawn is the high ground, so anything standing on it
	-- gets a stud for free. Verified after: the cap lands on 3.20 / 4.60 / 7.90
	-- against measured visible fence tops of 3.20 / 4.60 / 7.90, which is the
	-- derivation being exact rather than approximately right.
	return math.min(spec.height, tier.decorTop - Config.LAWN_LIFT)
end

-- PLANTS ALONG THE FENCE LINE.
--
-- `height` is what the plant WANTS to be and is clamped by `borderHeight`
-- above, so a catalogue entry is authored at its natural size rather than at
-- whatever the cheapest fence happens to allow. `spacing` is how far apart
-- they stand along the run, and it is a PART BUDGET as much as a look: this
-- is the first thing in the game that repeats along the whole visible
-- perimeter of a plot, and the grass tufts are already 47% of every part in
-- the world. Only a plot whose owner has BOUGHT one carries any of this, so
-- the cost lands on up to eight plots rather than on all fourteen.
Config.BORDER_PLANTS = {
	lavender = {
		name = "Lavender Row", order = 1, cost = 40000,
		height = 2.6, spacing = 3.2, style = "spikes",
		leaf = Color3.fromRGB(108, 150, 96), bloom = Color3.fromRGB(150, 120, 206),
		swatch = Color3.fromRGB(150, 120, 206),
		blurb = "A low purple run along the fence",
	},
	boxhedge = {
		name = "Box Hedge", order = 2, cost = 120000,
		height = 4.2, spacing = 2.4, style = "hedge",
		leaf = Color3.fromRGB(78, 128, 68), bloom = Color3.fromRGB(96, 148, 84),
		swatch = Color3.fromRGB(78, 128, 68),
		blurb = "Clipped green, wall to wall",
	},
	roses = {
		name = "Rose Bushes", order = 3, cost = 350000,
		height = 5.0, spacing = 4.0, style = "bush",
		leaf = Color3.fromRGB(64, 118, 62), bloom = Color3.fromRGB(226, 74, 96),
		swatch = Color3.fromRGB(226, 74, 96),
		blurb = "Red heads on dark green",
	},
	sunflowers = {
		name = "Sunflowers", order = 4, cost = 900000,
		height = 8.4, spacing = 4.6, style = "tall",
		leaf = Color3.fromRGB(86, 140, 70), bloom = Color3.fromRGB(246, 200, 60),
		swatch = Color3.fromRGB(246, 200, 60),
		blurb = "As tall as your fence will let them grow",
	},
}

-- THE PATH FROM THE GATE TO THE PIG.
--
-- IT IS LAID FLAT AND THEREFORE COSTS NO SIGHTLINE AT ALL, which is what
-- makes it the one garden item with no cap on it. It also cannot be a surface
-- anybody stands on in the collision sense -- like every other decoration
-- here it is `CanCollide` and `CanQuery` off -- so it is a SUGGESTION about
-- where to walk rather than a claim on anybody's feet.
--
-- WHICH IS THE ONLY INTERESTING THING ABOUT IT: people follow paths. Where an
-- owner lays one nudges where a thief approaches from, and it does that with
-- no mechanical hold on the thief whatsoever -- no slow, no veto, no tell.
-- That is this project's preferred shape for influence, the same call the
-- guard-duty vest and the rob badge make: give the other player information
-- and let them decide what to do about it.
--
-- A SLAB IS PROUD OF THE LAWN, NEVER SUNK INTO IT. Nothing here can be dug --
-- the lawn is one solid Part -- so a path set below the grass simply
-- vanishes, which is the moat's own lesson at a twentieth of the scale.
Config.GARDEN_PATH_LIFT = 0.06

Config.GARDEN_PATHS = {
	gravel = {
		name = "Gravel Path", order = 1, cost = 25000,
		colour = Color3.fromRGB(188, 180, 164), material = Enum.Material.Slate,
		width = 4.0, slab = 1.6, gap = 0.35,
		swatch = Color3.fromRGB(188, 180, 164),
		blurb = "Crunchy, cheap, and it does the job",
	},
	stepping = {
		name = "Stepping Stones", order = 2, cost = 90000,
		colour = Color3.fromRGB(156, 158, 152), material = Enum.Material.Slate,
		width = 3.2, slab = 2.4, gap = 1.8,
		swatch = Color3.fromRGB(156, 158, 152),
		blurb = "One stone at a time, across the grass",
	},
	brick = {
		-- NOT "Red Brick", WHICH IS ALREADY A DOG KENNEL.
		--
		-- Both would have stood on the SAME shop tab a few sections apart --
		-- one a paving choice, one a kennel paint job -- with nothing but the
		-- header above them to tell a nine-year-old which was which. Found by
		-- sweeping every catalogue for duplicate display names rather than by
		-- noticing it: the shop renders 12 cards where 11 were expected, which
		-- is the only symptom a name collision has.
		--
		-- Two more survive that sweep and are older than this: "Midnight" is a
		-- kennel AND a skin, and "Solid Gold" is a kennel AND a skin. Both are
		-- cross-TAB, which is why nobody has tripped over them, and both are
		-- left alone here rather than renamed in passing.
		name = "Herringbone", order = 3, cost = 300000,
		colour = Color3.fromRGB(178, 88, 66), material = Enum.Material.SmoothPlastic,
		width = 4.4, slab = 1.2, gap = 0.25,
		swatch = Color3.fromRGB(178, 88, 66),
		blurb = "A proper laid walk up to your piggy",
	},
	marble = {
		name = "Marble Walk", order = 4, cost = 1200000,
		colour = Color3.fromRGB(238, 236, 230), material = Enum.Material.SmoothPlastic,
		width = 5.0, slab = 3.0, gap = 0.3,
		swatch = Color3.fromRGB(238, 236, 230),
		blurb = "The one your neighbours will mention",
	},
}

-- WINDOW BOXES, AND THEY ARE HUNG ON A HOUSE RATHER THAN BUILT INTO ONE.
--
-- Nine house tiers accept no decoration at all today, and the ladder is
-- flattest across the middle of it -- a townhouse and a villa are a different
-- silhouette and very nearly the same amount of building. A box under every
-- ground-floor window is the cheapest thing that distinguishes them.
--
-- IT IS A POST-PASS OVER THE BUILT MODEL, NOT AN ARGUMENT THREADED THROUGH
-- NINE BUILDERS. `LowPoly.framedWindow` names its ledge `Sill` and every
-- window in the game goes through it, so hanging a box means walking the
-- house for that name after it is parented -- which is what
-- `bindTrampolinesIn` already does for a mat. Threaded instead, it would be
-- one optional argument through `House.build`, nine tier builders and
-- `windowBand`: nine chances to leave it out, and a missing one reads as nil,
-- which is the silent EMPTY case this file records `signWord` and `setDecor`
-- both refusing.
--
-- GROUND FLOOR ONLY, WHICH IS AN ARGUMENT ALREADY WON RATHER THAN A NEW ONE.
-- `framedWindow`'s own comment records the measurement: a lit window is right
-- on the cottage's two and wrong on the manor's eleven, so the rule became
-- "the ground floor is lit and nothing above it is". Boxes take the identical
-- rule and inherit its reasoning for free -- warmth where somebody standing
-- on the lawn is looking, and a building that still reads by its walls above
-- that. It also stops the count running away on the tall tiers, where a box
-- per window over three storeys would be the row-of-white-holes failure
-- rendered in planters.
Config.WINDOW_BOXES = {
	geraniums = {
		name = "Geraniums", order = 1, cost = 60000,
		box = Color3.fromRGB(132, 92, 62), leaf = Color3.fromRGB(84, 132, 72),
		bloom = Color3.fromRGB(224, 72, 76),
		swatch = Color3.fromRGB(224, 72, 76),
		blurb = "Red heads under every downstairs window",
	},
	daisies = {
		name = "Daisies", order = 2, cost = 160000,
		box = Color3.fromRGB(228, 226, 218), leaf = Color3.fromRGB(96, 144, 80),
		bloom = Color3.fromRGB(248, 248, 238),
		swatch = Color3.fromRGB(248, 248, 238),
		blurb = "White and cheerful, in a painted box",
	},
	trailing = {
		name = "Trailing Ivy", order = 3, cost = 520000,
		box = Color3.fromRGB(72, 78, 74), leaf = Color3.fromRGB(66, 122, 62),
		bloom = Color3.fromRGB(88, 150, 78),
		swatch = Color3.fromRGB(66, 122, 62),
		blurb = "Green spilling down the brickwork",
	},
}

-- How hard a trampoline throws you, in studs per second of upward velocity.
--
-- 60 is an apex of about 9.2 studs against a normal jump's 7.2 -- enough to
-- read as a trampoline, not enough to be a movement system. It is VERTICAL
-- ONLY, exactly like the wheelie bin's exit hop: any horizontal component
-- would be the second, parallel way to move that Config.DODGE exists to rule
-- out, and every speed in this game is a multiplier inside `currentSpeed`.
--
-- It does not help at a fence. The ClimbZone snag spans y 5.5 to 10.5 and
-- catches a climber on the way UP whatever their apex, which is the measured
-- reason spring shoes were dropped rather than tuned.
Config.TRAMPOLINE_BOUNCE = 60

-- Per player, so one person cannot be launched repeatedly by standing still on
-- a mat, and so the bounce cannot be chained into a hover.
Config.TRAMPOLINE_COOLDOWN = 0.6

-- First free slot in the item's zone, or nil when that zone is full.
function Config.firstFreeDecorSlot(zone: string, placed: { [string]: string }): string?
	for _, slot in ipairs(Config.DECOR_SLOTS) do
		if slot.zone == zone and placed[slot.id] == nil then
			return slot.id
		end
	end
	return nil
end

-- ============================================================
-- TROPHIES
-- ============================================================
--
-- WHAT EACH TROPHY IS A RECORD OF, AND WHAT IT TAKES TO EARN ONE.
--
-- `count` names a number `TrophyService.counts` produces and NOTHING
-- ELSE: this table may not read a save, because Config requires nothing
-- and has to go on requiring nothing. The server owns the shape of the
-- data and this owns what the ladder is, which is the same split
-- `Config.GEAR` already draws against `data.gear.escapes`.
--
-- THREE OF THE FOUR NUMBERS ALREADY EXISTED AND WERE DISPLAYED NOWHERE.
-- `data.totalStolen` has been written on every delivery since the heist
-- system shipped, `data.gear.escapes` since the most-wanted gear did, and
-- neither has ever appeared on a screen -- so two thirds of this feature
-- is a readout for arithmetic the game was already doing. That is the
-- cheapest kind of content this design has, and it is the reason
-- the old roadmap put the trophies before the garden.
--
-- A TROPHY IS A READOUT, NOT A BADGE, which is what `need` and the growth
-- below are for. A thing that appears once and never changes again is
-- spent the moment it lands; one that visibly grows is worth walking past
-- for the rest of the account's life. The coin pile on the lawn has made
-- that argument since the first week of this project.
--
-- ONE IS OFFENCE, ONE IS DEFENCE, ONE IS THE POLICE AND ONE IS THE
-- COLLECTION, and that spread is deliberate rather than tidy. A yard that
-- only rewarded robbing would say "I rob" and offer nothing at all to a
-- player who spent their coins on fences, dogs and locks -- which is half
-- the catalogue and the half that never sees a reward for it.
Config.TROPHIES = {
	-- THE SLEEPER, and the only one that is a COLLECTION rather than a
	-- counter. It is driven purely by robbing, it is built on a builder
	-- that already exists, and it gives all 46 skins a second reason to be
	-- authored: today a skin is seen by its owner and by whoever happens to
	-- walk past their plot, and nothing else in the game ever shows one.
	--
	-- FIVE, NOT ONE. A shelf that arrives on your first robbery is a
	-- participation medal and holds one pig, which is not a collection --
	-- five is far enough in that the case is worth looking at when it lands
	-- and near enough that an evening reaches it.
	victimshelf = {
		count = "victims", need = 5,
		requirement = "Rob 5 different piggy skins",
	},

	-- OFFENCE. `data.totalStolen` measures what VICTIMS LOST rather than
	-- the doubled figure banked at home -- the same number the rap sheet
	-- and the weekly board rank on -- so the safe fills with coins that
	-- were actually taken out of somebody's pig rather than minted on the
	-- way back to yours.
	haulvault = {
		count = "stolen", need = 100000, coins = true,
		requirement = "Steal 100K coins from other pigs",
		-- IT DOUBLES RATHER THAN COUNTING, because this is the one figure
		-- here that spans the whole economy: a level-40 thief takes more in
		-- one delivery than a new one takes in an evening. A linear ladder
		-- would be full by the second hour and then say nothing for the rest
		-- of the account's life. Ten bars is 100K doubled nine times, which
		-- is 51.2M and comfortably past the end of the catalogue.
		double = true, max = 10,
	},

	-- DEFENCE, and the one number here that had to be invented. There was
	-- no count of thieves stopped anywhere in the save: `data.totalLost`
	-- tracks the INVERSE -- coins somebody took off you -- so building a
	-- defender's trophy on it would have been a prize for being robbed.
	--
	-- IT COUNTS A DOG'S CATCH AND A PLAYER'S NAB AND NOT AN ARREST. The
	-- patrol belongs to nobody, which is the whole point of it; crediting a
	-- plot owner for a car the street sent would be the first time anything
	-- in this game claimed the police as a defence upgrade.
	medalboard = {
		count = "caught", need = 3, max = 9,
		requirement = "Stop 3 thieves on your own lawn",
	},

	-- THE POLICE. `data.gear.escapes` is already the unlock ladder for the
	-- Most Wanted gear, so this is a SECOND readout of one number rather
	-- than a second counter -- which is what keeps the two from ever
	-- disagreeing about how many patrols somebody has outrun.
	--
	-- ONE, because escaping a most-wanted pursuit is already rare enough to
	-- be its own event: you have to be top of the board, be come for, and
	-- get away. A threshold above one would leave the lamp unlit for the
	-- players who have done the hardest thing in this list.
	sirenpost = {
		count = "escapes", need = 1, max = 5,
		requirement = "Escape one most-wanted patrol",
	},
}

-- How full a trophy is, from 0 (not earned) up to its own `max`.
--
-- ONE FUNCTION RATHER THAN A BRANCH IN EACH BUILDER, because the geometry
-- and the shop card have to agree about what "grade 4" means -- a case
-- standing four bars tall beside a plaque reading three is the kind of
-- disagreement nobody reports and everybody stops trusting.
--
-- The victim shelf takes no grade at all: it shows one pig per skin, so
-- its own list is the readout and a number derived from its length would
-- be a second answer to a question the list already answers exactly.
function Config.trophyGrade(key: string, have: number): number
	local spec = Config.TROPHIES[key]
	if not spec or have < spec.need then
		return 0
	end
	local max = spec.max or 1
	if spec.double then
		return math.clamp(math.floor(math.log(have / spec.need, 2)) + 1, 1, max)
	end
	return math.clamp(math.floor(have / spec.need), 1, max)
end

-- The line a locked card prints where a price would go.
--
-- Read out of the table rather than assembled from `count` and `need`,
-- for the reason `Config.gearRequirement` is a sentence rather than a
-- format string: "Steal 100000 stolen" is what a generated one says, and
-- the sentence is the one part of a trophy a nine-year-old actually reads.
function Config.trophyRequirement(key: string): string
	local spec = Config.TROPHIES[key]
	return if spec then spec.requirement else ""
end

-- ============================================================
-- THE FRAME
-- ============================================================
--
-- MONEY BUYS THE FRAME. Every trophy stands on a plinth, one purchase
-- restyles ALL of them, and nothing here can be earned -- which is the
-- exact inverse of the four above and is the whole economy of the shelf:
-- a rich player who has never robbed anybody has a row of beautiful empty
-- pedestals, and a thief with no coins has four trophies on bare concrete.
--
-- ONE LADDER FOR THE WHOLE YARD RATHER THAN A PLINTH PER TROPHY. Four
-- separate purchases would be four cards saying the same thing, and a yard
-- with a gilded safe next to a concrete shelf reads as unfinished rather
-- than as a choice. It also means the ladder can be priced as one thing.
--
-- THE ENGRAVING IS A RUNG, NOT A FREEBIE, and that is what makes the
-- middle of this ladder worth buying. `Marble` is where a trophy starts
-- SAYING its own number -- "482K STOLEN" on a brass plaque -- so the step
-- from `Stone` up is a step from an object to a readout. The top rung adds
-- the uplight, which is the only thing here that reads from the pavement.
--
-- NEON, NEVER A LIGHT. There is no night in this game -- `WorldService`
-- sets `ClockTime` to 14.5 exactly once and nothing ever moves it -- so a
-- PointLight at 14:30 is an invisible purchase. Every celebration in this
-- project is emissive geometry for the same reason.
--
-- A PLINTH CONFERS NOTHING, which is the line that lets it be sold for
-- coins at all. It repaints a base and adds a label; the trophy standing
-- on it is the same trophy, and no amount of money spent here changes a
-- single thing a thief reads off the lawn.
Config.TROPHY_PLINTHS = {
	stone = {
		name = "Dressed Stone", order = 1, cost = 40000,
		base = Color3.fromRGB(176, 172, 164), trim = Color3.fromRGB(138, 134, 126),
		material = Enum.Material.SmoothPlastic,
	},
	marble = {
		name = "White Marble", order = 2, cost = 400000,
		base = Color3.fromRGB(238, 236, 230), trim = Color3.fromRGB(198, 158, 78),
		material = Enum.Material.SmoothPlastic, plaque = true,
	},
	gilded = {
		name = "Gilded", order = 3, cost = 4000000,
		base = Color3.fromRGB(226, 186, 86), trim = Color3.fromRGB(150, 112, 40),
		material = Enum.Material.SmoothPlastic, plaque = true,
		-- The uplight, and it is DEEP AMBER rather than a pale cream for the
		-- reason the street lamp had to come down off (255, 240, 190): Neon
		-- renders a colour flat out and the BloomEffect takes it from there,
		-- so a pale tint is a white hole and a saturated one is a lamp.
		glow = Color3.fromRGB(226, 148, 40),
	},
}

-- The plain concrete every trophy stands on before anything is bought.
-- Not a row in the table above, because it is not for sale: a catalogue
-- entry with no price is a card that cannot be pressed.
Config.TROPHY_PLINTH_BASE = {
	name = "Plain Concrete",
	base = Color3.fromRGB(150, 148, 144), trim = Color3.fromRGB(120, 118, 114),
	material = Enum.Material.SmoothPlastic,
}

function Config.trophyPlinth(key: string?): any
	return (key and key ~= "" and Config.TROPHY_PLINTHS[key]) or Config.TROPHY_PLINTH_BASE
end

-- ============================================================
-- RIDES
-- ============================================================
--
-- SPEED IS THE CURRENCY, AND A RIDE MUST NOT SPEND IT.
--
-- BASE_WALK_SPEED (16) is the number the carry penalty, the dog speeds, the
-- fence snags and the getaway distance are all calibrated against, and the
-- rule above says anything that makes a player faster than 16 invalidates
-- several systems at once. Every one of these multipliers does exactly that,
-- so a ride is not allowed to be on when any of those systems is running.
--
-- RideService gates it. A ride works on PUBLIC GROUND ONLY -- outside every
-- fence -- and switches off while you are carrying loot, while someone is
-- carrying yours, and while a fence has you snagged. What is left is the
-- street, which is the part of this game that was pure walking:
--
--   * A thief cannot ride away. The 37-stud getaway is the entire risk half
--     of the trade, and at 33.6 studs/sec it would be a second and a half.
--   * A victim cannot ride after them. A defender doing 33.6 against a thief
--     doing 12 catches every robbery ever attempted, which kills the offence
--     tree outright.
--   * Nobody rides on a lawn. The lawn is the ground defence happens on, and
--     it is where the steal prompt, the dog and the fence all live.
--
-- So these numbers never meet the dog (12 / 14.5 / 17, and it never leaves
-- the yard), never meet the carry penalty, and never shorten a chase. They
-- buy back the walk between plots, and they are a moving flex, and that is
-- deliberately all they are -- houses confer nothing, and neither do these.
--
-- `style` names the builder in RideModel; `multiplier` is against
-- BASE_WALK_SPEED. Bought with COINS, like everything else purchasable here:
-- see the Robux rule above.
--
-- `stand` is how high off the ground the rider's FEET go: the deck of a
-- board, the pedals of the bike, the pegs of the scrambler. RideService adds
-- it to Humanoid.HipHeight, which is what actually lifts the character, and
-- seats the model on the real floor underneath. Without it every ride is
-- authored with its deck at ankle height and the rider stands shin-deep
-- through their own skateboard. Measure it to the TOP surface the feet land
-- on, not to the top of the model.
--
-- HOW A RIDER SITS OR STANDS IS `RidePose`, keyed on `style`.
--
-- This used to read "you stand up on all five, including the two with
-- saddles... it is the only pose that needs no seated animation". That was
-- true when the only mechanism anyone had tried was stopping the walk cycle
-- and letting the rig fall into its rest pose. It is not true now: a pose is
-- a KeyframeSequence built at runtime, the same as the dodge roll, so a
-- seated rider costs no uploaded asset either.
--
-- All five are posed. The BMX and the Volt Scrambler are seated with both
-- hands on the bars; the skateboard stands across the deck with the back
-- foot on the tail; the scooter stands along it, one foot forward, hands up;
-- the hoverboard stands square with the arms out to balance.
-- ============================================================
-- ROBUX PASSES
-- ============================================================
--
-- The only place in the game where a Robux product is named.
--
-- `id` IS 0 UNTIL SOMEBODY CREATES THE PASS. It cannot be guessed, derived,
-- or looked up from a username: a game pass does not exist until it is made
-- in the Creator Dashboard against this experience, and only then does it get
-- an id. While it is 0, everything the pass gates is FREE and the server says
-- so at startup -- see PassService for why that default is the safe one.
--
-- A ROBUX PURCHASE MAY GRANT AN ITEM, NEVER ITS COIN VALUE.
--
-- This is the line that keeps a paid product legal here, and it is a
-- different line from the one above the accessory roll. Coins buy rolls, so
-- coins must never be purchasable; but a purchase that hands over a NAMED
-- thing mints no coins, feeds no roll, and is an ordinary direct purchase.
-- Grant the ride. Never grant what the ride costs.
--
-- It also has to sell no power, and rides are the one purchasable that
-- obviously does not: a ride is switched off while carrying loot, while being
-- robbed, on a fence snag, and anywhere off the street. What is being sold is
-- the walk between plots.
Config.PASSES = {
	stylePack = {
		id = 0,
		name = "Style Pack",
		blurb = "A second way to ride every board and bike you own.",
		-- Display only. Roblox owns the real price; this is what the shop tile
		-- says so the offer can be read before the prompt opens. Keep the two
		-- in step by hand -- there is no API that makes this authoritative.
		robux = 99,

		-- THE FLOOR, AND IT IS NOT A BUNDLE.
		--
		-- A pass is buyable from the experience's store page, outside this
		-- game's UI, so there is no way to stop somebody buying this who owns
		-- no ride at all -- and a riding pose with nothing to sit on is a
		-- purchase that visibly does nothing. Every other rule here says a
		-- player must be able to SEE what happened, so the pack also grants a
		-- ride when the buyer owns none.
		--
		-- The CHEAPEST ride, never the one a pose is for. The rides run 25,000
		-- to 4,500,000 coins, so handing over the matching one would price a
		-- cosmetic above the largest coin sink in the game and delete the
		-- reason to go on earning. 25,000 is 0.5% of that and the weakest ride
		-- in the set.
		--
		-- Self-clearing, so there is nothing to record and no way to grant it
		-- twice: "owns the pass and owns no ride" stops being true the instant
		-- it fires.
		entryRide = "skateboard",

		-- ALREADY HAS A HOME, so the general offers shelf leaves it alone.
		--
		-- This one is sold on the RIDES tab, beside the stances it unlocks and
		-- under the same header -- which is a better place for it than a shelf
		-- of offers, because what it buys only means anything next to a board.
		-- Two cards for one pass would be the near-identical duplicate this
		-- file keeps recording, on the one screen where a player is deciding
		-- whether to spend real money.
		--
		-- A pass with no `soldWith` appears on the shelf, which is the right
		-- default: the failure it prevents is a paid product with no way to
		-- buy it from inside the game.
		soldWith = "rides",
	},

	-- ====================================================================
	-- VIP
	-- ====================================================================
	--
	-- WHAT VIP IS NOT, FIRST, BECAUSE THE THREE MOST COMMON VIP PERKS ON
	-- THIS PLATFORM ARE ALL ILLEGAL HERE AND THEY ARE THE FIRST THREE
	-- ANYBODY WILL SUGGEST.
	--
	-- NEVER CURRENCY. Coins are not purchasable with Robux at any price --
	-- the single rule keeping the entire chest catalogue outside
	-- paid-random-item regulation, and one that can only be broken once,
	-- because the day it goes every chest in the game becomes a regulated
	-- loot box retroactively. Loot is worse still: loot buys a roll, so
	-- Robux to loot is literally paying for a random outcome. That kills a
	-- daily free crate, a VIP-only chest and a monthly coin stipend.
	--
	-- NEVER A RATE, AND THIS ONE IS ARITHMETIC RATHER THAN POLICY. A
	-- 2x-income pass fails `Config.auditRobbery` on boot: the full-server
	-- figure goes 3.51x to 1.76x, straight through `ROBBERY_ADVANTAGE.min`
	-- of 3.0. Even a 1.25x pass lands at 2.81x and fails. The whole
	-- residents-and-shops programme exists because idling was out-earning
	-- robbing, and a rate pass reintroduces exactly that failure for paying
	-- players specifically -- which is the worst possible group to break it
	-- for.
	--
	-- SO IT IS NAMED THINGS AND A MARK ON THE STREET, which is the safest
	-- shape there is to put in front of an under-12 audience: a purchase
	-- that hands over a specific item mints no coins, feeds no chest, and
	-- is an ordinary direct purchase.
	--
	-- THE ITEMS ARE NOT LISTED HERE, AND THAT IS DELIBERATE. Anything in
	-- any catalogue carrying `pass = "vip"` is granted, so adding one is a
	-- row in the catalogue it belongs to and nothing else -- no second list
	-- to keep in step, which is the near-identical duplicate this file
	-- keeps recording as the thing that drifts. Today that is the Velvet
	-- Rope skin, the Spotlight aura and the Paparazzi catch effect.
	vip = {
		id = 0,
		name = "VIP",
		blurb = "A skin, an aura, a catch effect and your name in gold on the street.",
		-- Display only. Roblox owns the real price; this is what the shop
		-- tile prints so the offer can be read before the prompt opens, and
		-- the two are kept in step BY HAND -- there is no API that makes this
		-- authoritative.
		robux = 249,

		-- THE MARK ON THE PLOT SIGN, and it is the only physical boast
		-- surface this game has. It is a WORD as well as a colour, because
		-- colour alone separates things only for players who can see the
		-- difference -- the same two-channel rule the rarity borders already
		-- follow.
		signWord = "VIP",
		-- A DEEP ANTIQUE GOLD, AND THE FIRST VALUE WAS MEASURED AND
		-- REJECTED.
		--
		-- The obvious colour is the theme's own gold, (246, 206, 96). The
		-- plot sign's panel is cream (244, 236, 218), and that pairing
		-- measures 1.28:1 -- a name you can see is there and cannot read,
		-- which is the exact failure this project already recorded for raw
		-- gold on paper at 1.42:1. It would have made the one thing VIP buys
		-- on the street WORSE than not buying it.
		--
		-- (140, 96, 10) measures 4.71:1 on that panel, clearing the body
		-- floor rather than the 3.0 a scaled label could have settled for,
		-- and it still reads as gold against the plain name's brown (70, 46,
		-- 30) at 10.69. Anything that repaints `SignPanel` has to re-measure
		-- this pair.
		signColour = Color3.fromRGB(140, 96, 10),
	},

	-- ====================================================================
	-- THE STARTER PACK
	-- ====================================================================
	--
	-- A PASS RATHER THAN A DEVELOPER PRODUCT, which is the opposite of how
	-- every other game on this platform sells one, and the reason is the
	-- reason `PassService` exists at all: a pass is an entitlement held by
	-- ROBLOX and re-checkable forever, so a lost save gives the items back
	-- on the next join. A developer product's receipt arrives once, and if
	-- the write recording it fails the purchase is simply gone. That is not
	-- an acceptable failure for a nine-year-old who spent birthday Robux,
	-- and it is the likeliest purchase in the game to be somebody's first.
	--
	-- BE CAREFUL WITH CONSUMABLES, WHICH IS WHERE THE GENRE'S STARTER PACKS
	-- LIVE AND WHY THIS ONE HAS NONE. Ten Golden Bones is 300,000 coins of
	-- value in a trenchcoat, which is selling currency with extra steps --
	-- and the coins-are-not-purchasable rule does not care whether the
	-- currency arrives as a number or as a stack of things that number would
	-- have bought.
	--
	-- AND NO COUNTDOWN, NO FAKE DISCOUNT, NO "was 999 R$". Time-pressure
	-- selling aimed at nine-year-olds is a decision made here rather than a
	-- rules question, and the answer is no.
	--
	-- PRICED BELOW THE STYLE PACK'S 99, because it is the entry offer and
	-- the cheapest thing in the game should be the thing somebody buys
	-- first.
	starterPack = {
		id = 0,
		name = "Starter Pack",
		blurb = "A skin, an aura, and a board to get around on if you have none.",
		robux = 79,

		-- THE SAME FLOOR THE STYLE PACK CARRIES, and for the same reason: a
		-- pass is buyable from the experience's store page, outside this
		-- game's UI, so nothing may assume the buyer already owns anything.
		-- The CHEAPEST ride, never a matching one -- rides run 25,000 to
		-- 4,500,000 coins, and handing over an expensive one would price a
		-- cosmetic above the largest coin sink in the game and delete the
		-- reason to go on earning.
		--
		-- Self-clearing, so there is nothing to record and no way to grant it
		-- twice: "owns the pass and owns no ride" stops being true the
		-- instant it fires.
		entryRide = "skateboard",
	},
}

-- EVERY PASS-EXCLUSIVE ITEM IN EVERY CATALOGUE, derived rather than listed.
--
-- The alternative is a `grants` array on each pass row, which is a second
-- copy of a fact the catalogues already carry -- and the failure shape is
-- known and silent: an item tagged `pass = "vip"` but missing from the
-- list is excluded from every roll and granted by nothing, so it exists,
-- borders as legendary, and is unobtainable by any route. Deriving cannot
-- produce that state.
--
-- IT WALKS `Config.catalogueFor`'S OWN KINDS, so a seventh catalogue is
-- covered the moment it is added there rather than the session somebody
-- notices. Returns `{kind, key}` pairs, which is the grammar
-- `SetService.grant` already speaks.
function Config.passItems(passKey: string): { { kind: string, key: string } }
	local out = {}
	for _, kind in ipairs(Config.COSMETIC_KINDS) do
		local catalogue = Config.catalogueFor(kind)
		if catalogue then
			for key, spec in pairs(catalogue) do
				if type(spec) == "table" and spec.pass == passKey then
					table.insert(out, { kind = kind, key = key })
				end
			end
		end
	end
	-- Sorted, so a grant announces its items in the same order every time
	-- rather than in whatever order `pairs` happened to walk two tables.
	table.sort(out, function(a, b)
		if a.kind ~= b.kind then
			return a.kind < b.kind
		end
		return a.key < b.key
	end)
	return out
end

-- HOW FAST THE SIDEWAYS STANCE CATCHES UP TO A NEW HEADING, in degrees per
-- second, never applied instantly.
--
-- Only a ride with a `bodyYaw` turns the root at all -- see the note over
-- RIDE_YAW_ATTRIBUTE in RideService -- and today that is the skateboard alone.
-- The first version set the root's CFrame straight to the target heading
-- every frame, which is exactly right for WHERE to face and wrong for HOW to
-- get there: a keyboard's MoveDirection is not continuous, it is one of eight
-- fixed vectors that changes in a single frame the instant A becomes D, so the
-- board spun on the spot rather than carving into the new direction.
--
-- 420 completes a full reversal (A to D, 180 degrees) in just under half a
-- second -- fast enough to stay responsive in a chase, slow enough that
-- consecutive frames differ by a few degrees rather than by however far the
-- input happened to turn. ClientMain eases the ROOT toward this target at
-- this rate every frame; RideYaw itself is still the instant, published fact
-- of which way the deck is meant to sit.
Config.RIDE_STANCE_TURN_RATE = 420

Config.RIDES = {
	skateboard = {
		name = "Skateboard", style = "skateboard", order = 1,
		-- Urethane wheels on concrete, at the pitch it was recorded. This is
		-- the one ride the recording actually is, and the one range this
		-- retune left alone -- see the note over `bmx` for why the other
		-- four needed it and this one did not.
		--
		-- VOLUME IS MEASURED AGAINST THE SCORE, because those are the only
		-- two continuous sounds in the game and the rider hears both of them
		-- flat out. A one-shot is not the comparison: the alerts run 0.25 to
		-- 1.0 and the dog barks 0.42 to 0.75, but each is over in a second
		-- and none of them is playing while you cross the street. `Music` is
		-- deliberately quiet at 0.18 for exactly the reason this table now
		-- is -- it never stops. Measured on a live rider at full throttle,
		-- the ride loop sat at 0.340 against that 0.180, nearly twice the
		-- score, forever. These are roughly half what they were, which puts
		-- the loudest ride at full speed level with the music rather than
		-- over it, with the gaps between rides kept so a scrambler still
		-- reads as the big one.
		-- `eq` IS PER RIDE, because one cut cannot suit six machines. The
		-- board's grind lives in the mids; the top comes off for the
		-- resample. See RideSound for what the three bands are.
		--
		-- 0.18 -> 0.09 because this recording is the LOUDEST in the set and
		-- nothing here knew that. See the note over `volume` in the header:
		-- at 0.18 the board was running an effective 45 against the
		-- scrambler's 25.8, so the cheapest ride in the game was almost
		-- twice as loud as the flagship. That is most of why it kept being
		-- reported as obnoxious after two rounds of cutting the number.
		sound = { id = Config.SOUNDS.RIDE_ROLL, volume = 0.09, idle = 0,
			pitch = { 0.88, 1.12 }, range = 70,
			eq = { low = 0, mid = -3, high = -8 } },
		cost = 25000, multiplier = 1.35, stand = 0.85,
		-- 0.85, not the deck height of 1.05. `stand` sets how high the ROOT
		-- rides, and the pose bends the knees -- so seating the deck under a
		-- straight-legged rider left the bent feet hanging 0.2 studs above it.
		-- Measured: the posed feet sit 2.75 below the root, and 1.05 - 0.85
		-- is exactly the room those bent knees need.
		-- Turned across the deck: you ride a skateboard sideways, feet over the
		-- trucks, not facing the nose like a scooter. Applied to the body only
		-- (see RideService), so the board still points along travel and
		-- steering is untouched. Negate for a goofy stance.
		bodyYaw = 90,
		-- A manual: nose up, rolling on the back wheels. Purely a look -- no
		-- speed, no advantage, nothing to balance. Rides confer nothing and a
		-- trick on one confers less.
		-- `pivot` is the model-space z of the REAR contact patch, because a
		-- manual turns about the back wheels. Tipping about the model origin
		-- instead lifts the nose and drives the tail through the road.
		trick = { name = "Manual", pitch = 26, pivot = -1.22 },
		colour = Color3.fromRGB(206, 62, 78), trim = Color3.fromRGB(246, 214, 96),
		accent = Color3.fromRGB(246, 214, 96),
		blurb = "Kick, push, and never stop",
	},
	bmx = {
		name = "BMX Bike", style = "bmx", order = 2,
		-- A TYRE, WHICH IS WHAT A BMX ACTUALLY ROLLS ON. A BMX has no engine
		-- and must not sound like it has one -- what carries from the
		-- pavement is tyres, and a real pneumatic tyre is a far closer match
		-- than a skateboard's hard urethane. It shares the recording with
		-- the scrambler and is pitched clear below it, which is the shared
		-- source trick used the way it actually works: two machines that
		-- genuinely have the same part.
		--
		-- PLAYBACKSPEED IS A RAW RESAMPLE, NOT A PITCH SHIFT, which is why
		-- this ride spent three passes sounding wrong. A skateboard dragged
		-- down to 0.60, and then 0.74, was always going to read as a
		-- recording played at the wrong speed rather than as a bicycle:
		-- narrowing the range helps and can never finish, because the
		-- artifact IS the resample.
		--
		-- 0.76-0.90 on a tyre is a smaller shift than 0.74 on a board AND
		-- starts from the right object, so what is left of the resample is
		-- doing something honest -- a bigger, softer tyre than the
		-- scrambler's, which is exactly the difference between the two
		-- machines. It stays clear of the scrambler's 0.92-1.32 at every
		-- speed so the two never sound like the same vehicle.
		sound = { id = Config.SOUNDS.RIDE_TYRE, volume = 0.14, idle = 0,
			pitch = { 0.76, 0.90 }, range = 70,
			eq = { low = 0, mid = -3, high = -9 } },
		cost = 90000, multiplier = 1.5, stand = 0,
		-- ZERO, and that is not a missing value. `stand` lifts the rider by the
		-- height of the surface they STAND on, and a seated rider does not stand
		-- on anything -- they are held up by the saddle, which RideModel now
		-- places under the pelvis where it already is. Raising the rider here
		-- would lift them off the saddle they are sitting on.
		-- Pivot is the REAR CONTACT PATCH, so it tracks the rear axle: it moved
		-- from -2.15 to -1.62 when the bike was rescaled to the rider. Left at
		-- the old value the wheelie would turn about a point half a stud behind
		-- the wheel and drive the tyre through the road.
		trick = { name = "Wheelie", pitch = 30, pivot = -1.62 },
		colour = Color3.fromRGB(64, 116, 196), trim = Color3.fromRGB(226, 230, 238),
		accent = Color3.fromRGB(246, 138, 48),
		blurb = "Standing on the pedals the whole way",
	},
	scooter = {
		name = "E-Scooter", style = "scooter", order = 3,
		-- Above the board: small hard wheels, and more of them per stud.
		--
		-- `idle` is 0 even though this one is electric, because what it plays
		-- is a ROLL. A rolling sound out of a scooter standing still is a
		-- scooter that is moving, which is worse than one that is quiet.
		-- Trimmed the same direction as the other four, for the same reason:
		-- see the note over `bmx`. 1.34 was a 34% resample; 1.26 keeps the
		-- scooter reading noticeably higher and quicker than the board
		-- without being the loudest thing on the street to do it.
		-- The one ride the shared-recording trick genuinely suits, and the
		-- one nobody complained about: small hard wheels really do sit above
		-- a skateboard's, so pitching UP is describing the machine rather
		-- than faking a different one.
		-- 0.16 -> 0.08 for the reason the board dropped: it is on the same
		-- loud recording, and pitching UP made it louder still -- measured
		-- the loudest source in the whole set at 286.
		sound = { id = Config.SOUNDS.RIDE_ROLL, volume = 0.08, idle = 0,
			pitch = { 1.05, 1.26 }, range = 70,
			eq = { low = 0, mid = -2, high = -6 } },
		cost = 300000, multiplier = 1.65, stand = 0.80,
		-- Measured, not the deck height: the posed rider stands with one foot
		-- forward and both knees soft, so the soles sit 3.10 below the root
		-- rather than a straight-legged 3.23. See RidePose.
		colour = Color3.fromRGB(46, 50, 58), trim = Color3.fromRGB(200, 204, 212),
		accent = Color3.fromRGB(92, 232, 190),
		blurb = "Silent, and somehow always charged",
	},
	hoverboard = {
		name = "Hoverboard", style = "hoverboard", order = 4,
		-- Hums standing still, and `idle` is the highest here for a reason: a
		-- hoverboard is holding itself up whether or not it is going
		-- anywhere, so one that falls silent when you stop has landed. Pulled
		-- back from 0.45 all the same -- a hum that never stops is the one
		-- most likely to read as a drone in a crowded street, and it does not
		-- need to be loud to say the machine is still on.
		-- 0.17 -> 0.38, the one ride this normalisation made LOUDER. Its pod
		-- tone measures 63 against the board's 250, so an identical-looking
		-- volume was buying a quarter as much sound: effective 10.7 against
		-- the board's 45. A 1.2M-coin ride was the quietest thing on the
		-- street and the number gave no hint of it.
		sound = { id = Config.SOUNDS.RIDE_HOVER, volume = 0.38, idle = 0.35,
			pitch = { 0.85, 1.18 }, range = 70,
			-- Barely touched: a synth tone has no bearing grit to remove,
			-- and it is not resampled far. A drone wants to stay smooth.
			eq = { low = 0, mid = 0, high = -3 } },
		cost = 1200000, multiplier = 1.8, stand = 0.83,
		-- Down from 1.29 with the board itself, which shrank about a fifth --
		-- it was 5.4 studs wide, wider than the rider is tall.
		colour = Color3.fromRGB(38, 36, 52), trim = Color3.fromRGB(212, 216, 228),
		accent = Color3.fromRGB(124, 152, 255),
		blurb = "Two wheels, no handlebars. Lean and go",
	},
	-- An ORIGINAL, not the e-bike everyone means when they ask for one.
	--
	-- The one people name is a manufacturer's registered mark, and the lawn
	-- ornaments already settled this: Roblox moderation strips branded assets
	-- and the penalty lands on the EXPERIENCE, not the item. What carries it is
	-- the genre -- stubby frame, knobbly tyres, a slab of battery where an
	-- engine should be -- and a genre is not property.
	scrambler = {
		name = "Volt Scrambler", style = "scrambler", order = 5,
		-- The widest pitch range of the five, because this is the only ride
		-- whose sound is a MOTOR rather than a wheel -- and a motor is the
		-- thing that rises when you open it up. It idles quietly, since an
		-- electric bike standing still is still switched on, and it carries
		-- furthest: 85 studs against everything else's 70, which is the one
		-- place the range says outright that this is the 4.5-million-coin
		-- machine.
		--
		-- 1.55 WAS THE WORST OFFENDER IN THE FILE: a 55% resample, on the
		-- loudest sound here (0.44, a third louder than anything else) with
		-- the longest range (85). Loud, far-carrying and the most artifacted
		-- pitch in the set is exactly "obnoxious." The motor still climbs --
		-- 1.32 is still the highest ceiling of any ride -- it just does not
		-- climb into the range where PlaybackSpeed stops sounding like an
		-- engine and starts sounding like a damaged file. Volume comes down
		-- to sit with the pack instead of over it.
		-- 0.19 -> 0.22 so the flagship is actually the loudest ride, which
		-- it was not: at 0.19 on a 136 source it ran an effective 25.8
		-- against the starter board's 45.
		sound = { id = Config.SOUNDS.RIDE_TYRE, volume = 0.22, idle = 0.18,
			pitch = { 0.92, 1.32 }, range = 85,
			-- The widest resample left in the file, so it keeps the most
			-- top-end cut of the six.
			eq = { low = 0, mid = -2, high = -7 } },
		cost = 4500000, multiplier = 2.1, stand = 0,
		-- ZERO, like the BMX and for the same reason: a seated rider is held up
		-- by the saddle, not stood on the pegs, and RideModel puts the seat
		-- under the pelvis where it already is.
		-- Purple over lime, off the reference. `colour` is the bodywork --
		-- fenders, shrouds, side panels; `accent` is the perimeter frame, the
		-- fork lowers, the swingarm and the battery fins; `trim` is the wheel
		-- rim, which is nearly black on the real thing rather than silver.
		-- A dirt bike that could not pull a wheelie was the odd one out, and it
		-- costs one line now that the rider's lean is DERIVED from these two
		-- numbers rather than tuned against them -- see RidePose.trickDelta.
		-- Pivot is the rear axle, which is where BACK_Z puts it.
		trick = { name = "Wheelie", pitch = 28, pivot = -1.9 },
		colour = Color3.fromRGB(126, 58, 190), trim = Color3.fromRGB(74, 78, 88),
		accent = Color3.fromRGB(158, 232, 44),
		blurb = "Does not care that it is a bicycle",
	},

	-- ALIEN SET, and the long chase: 120 medals is most of a set on its own.
	--
	-- ITS OWN STYLE, WITH THE POSE ALIASED IN RidePose -- not a shared style.
	--
	-- Sharing "hoverboard" looked free and is a real bug: `rideForStyle`
	-- scans Config.RIDES with `pairs` and returns the FIRST ride whose style
	-- matches, so two rides on one style resolve non-deterministically and
	-- differently on different clients. It hands back the ride KEY that
	-- `phaseOf` uses to find the mounted model, so the wrong answer breaks
	-- tricks for whichever ride lost the coin toss.
	--
	-- `POSES.hoverdisc = POSES.hoverboard` gets the inheritance instead, with
	-- none of the ambiguity. That alias is only honest while the geometry
	-- keeps the hoverboard's measured contacts, so this deck stands at the
	-- same height and its pads sit at the same +-1.08 the posed feet land on.
	hoverdisc = {
		name = "Hoverdisc", style = "hoverdisc", order = 6,
		set = "alien", loot = 120, rarity = "legendary",
		-- ITS OWN RECORDING, WHICH THE SET IS THE REASON FOR. It shared the
		-- hoverboard's pod tone, which was defensible while both were "a
		-- machine that hovers" -- and it made the 120-medal legendary of the
		-- alien set sound like the 1.2M-coin board anybody can buy. The one
		-- ride in the game that is WON rather than bought should not be the
		-- one that sounds borrowed.
		--
		-- A deep power drone from the Spaceships shelf rather than another
		-- Pod cruising tone: the same shelf as the pod is the trap, since
		-- two takes from one session sound related however different their
		-- file names are. Deep also suits the complaint the rest of this
		-- pass was about -- there is nothing harsh in it to tame.
		sound = { id = Config.SOUNDS.RIDE_DISC, volume = 0.19, idle = 0.35,
			pitch = { 0.90, 1.15 }, range = 70,
			eq = { low = 0, mid = 0, high = -3 } },
		multiplier = 1.8, stand = 0.83,
		-- `accent` IS NOT OPTIONAL, and this ride shipped without one.
		--
		-- It is the speed streak's colour, and RideService reads it on every
		-- mount -- so a nil here is not a ride with no trail, it is
		-- ColorSequence.new(nil) throwing inside mount(). See the note over
		-- `mount` for what that cost: the gate polls ten times a second and
		-- every failed attempt raised HipHeight again, so a rider floated
		-- upward at 8.3 studs a second with no disc under them and no way
		-- down. The alien green, matching the underglow and the rim lamps,
		-- which is what this machine's streak should be.
		colour = Color3.fromRGB(46, 54, 72), trim = Color3.fromRGB(96, 255, 176),
		accent = Color3.fromRGB(96, 255, 176),
	},
}

function Config.getRide(key: string?)
	return if key and key ~= "" then Config.RIDES[key] else nil
end

-- Top speed a ride can reach, for the balance note above. Kept as a function
-- so it cannot drift from the table the way a written-down constant would.
function Config.maxRideSpeed(): number
	local best = Config.BASE_WALK_SPEED
	for _, ride in pairs(Config.RIDES) do
		best = math.max(best, Config.BASE_WALK_SPEED * ride.multiplier)
	end
	return best
end

-- ============================================================
-- DAILY REWARDS
-- ============================================================
--
-- One claim per day, on a seven-day cycle that repeats, and the whole ladder
-- is FIXED AND PUBLISHED -- you can see day 7 from day 1. That is not a
-- presentation choice, it is the wall: coins are sellable, and a random daily
-- reward would be a random outcome standing downstream of a coin purchase.
-- Every reward here is named before it is claimed.
--
-- COIN REWARDS ARE DENOMINATED IN SECONDS OF YOUR OWN INCOME, never in flat
-- numbers. A flat 5,000 is a gift on day one and an insult at 3,000 a second,
-- and a ladder that stops mattering at the exact point players have the habit
-- is worse than no ladder. `floor` catches the other end: a brand new player
-- earning 10 a second would otherwise get 3,000 for a week's attendance.
--
-- The bones are deliberate. Two of the seven days hand out offence, because
-- the thing this game most needs a returning player to do is go and rob
-- somebody -- a daily that only pays coins rewards standing still.
--
-- NO LOOT ON THIS LADDER, since the pivot. It used to pay the roll currency
-- on every rung, which made turning up a route to the collection. Loot is the
-- currency you go out and earn -- see Config.LOOT -- and a ladder that paid it
-- would let a player who never robs anybody finish the thief's collection.
--
-- `short` is the word the daily board prints on the card. It lives here
-- rather than in ClientMain, which used to keep its own seven-entry copy of
-- this ladder and would now be a copy that disagreed about the tokens.
Config.DAILY_CYCLE = {
	{ kind = "coins", seconds = 300, floor = 500,
		short = "COINS", label = "5 min of income" },
	{ kind = "boost", boost = "boost5",
		short = "2x BOOST", label = "2x for 5 min" },
	{ kind = "bone", bone = "bone", count = 2,
		short = "BONES", label = "2 Dog Bones" },
	{ kind = "coins", seconds = 900, floor = 2000,
		short = "COINS", label = "15 min of income" },
	{ kind = "boost", boost = "boost15",
		short = "2x BOOST", label = "2x for 15 min" },
	-- Day six is the Golden Bone now, moved down a rung to make room. It is
	-- still the second-best thing on the ladder and still the reason to come
	-- back on day five.
	{ kind = "golden", seconds = 1800, floor = 5000,
		short = "GOLDEN", label = "Golden Bone + 30 min" },
	-- DAY SEVEN IS A FREE CRATE, AND IT IS THE ONLY RUNG THAT PAYS SOMETHING
	-- PLAYING CANNOT.
	--
	-- This table's own comment has said "when crates ship this becomes a KEY"
	-- since it was written, and crates shipped. Every other rung -- coins
	-- denominated in your own income, a boost, a couple of bones -- hands over
	-- something a player would have earned anyway by turning up and playing
	-- for a few minutes, so the ladder was giving nobody a reason to return
	-- that the game did not already give them. A crate open lands on the
	-- PERMANENT COSMETIC TRACK, which is the one thing an hour of idling
	-- cannot buy.
	--
	-- `classics` rather than the dearest crate: it is the entry chest, the
	-- one a new player recognises, and at 500,000 coins it is still a real
	-- prize on day seven of somebody's first week. Note the pool is unowned-
	-- aware through `liveOdds`, so a player who has finished it gets a spare
	-- worth selling rather than nothing.
	{ kind = "crate", crate = "og",
		short = "CRATE", label = "A free Piggy Originals crate" },
}

-- Stored, never auto-applied.
--
-- The vault caps at capacity, so a boost handed to somebody sitting on a full
-- vault is worth exactly nothing -- and that is precisely the player most
-- likely to be logging in to claim a daily. Holding it in a pocket makes the
-- reward keep its value and turns "bank first, then boost" into a small real
-- decision.
--
-- Wall-clock from activation. It does NOT apply to offline accrual: a boost
-- is for playing, and one that ticks while you are logged off is just a worse
-- coin reward with extra steps.
Config.BOOSTS = {
	boost5 = { name = "2x Coins", multiplier = 2, seconds = 300, order = 1 },
	boost15 = { name = "2x Coins", multiplier = 2, seconds = 900, order = 2 },
}

-- Days are UTC day indices, never os.date -- a server's local timezone is not
-- a thing the save should depend on, and two servers in different regions
-- would disagree about what day it is.
function Config.dayIndex(when: number?): number
	return (when or os.time()) // 86400
end

-- Weeks are day indices divided down, for exactly the reason above: the only
-- question ever asked is WHICH WEEK, so no clock, timezone or daylight saving
-- can get between the save and the answer, and two servers in different
-- regions cannot disagree about it.
function Config.weekIndex(when: number?): number
	return Config.dayIndex(when) // 7
end

-- THE STREET'S LADDER OUTLIVES THE SERVER NOW, AND THAT IS THE ONLY SAFE WAY
-- TO MAKE A NINE-YEAR-OLD FEEL BEHIND.
--
-- This design has removed every form of loss on purpose and should keep it
-- that way: a plot is RELEASED when its owner logs off so nobody is ever
-- robbed while away, a robbery never costs progress, rebirth keeps every
-- cosmetic, and offline accrual runs eight hours and never decays. All four
-- are deliberate and none of them is negotiable for this audience.
--
-- What went with them, and was never a decision, is COMPARISON. There was not
-- one `OrderedDataStore` in the project: both boards read
-- `Players:GetPlayers()`, so every ranking in the game evaporated when the
-- server did. Nothing anybody did on Tuesday was visible on Wednesday, to them
-- or to anybody else.
--
-- **RANK IS THE ONE THING THAT CAN SAFELY DECAY, BECAUSE NOBODY EVER OWNED
-- IT.** Being overtaken costs a player nothing they had -- no coins, no
-- upgrade, no skin -- and it is the whole of what "I should get back on" feels
-- like. That is loss aversion with no loss in it, which is the only version of
-- it this game is allowed to have.
--
-- WEEKLY RATHER THAN LIFETIME, and that is the same argument the session rap
-- sheet already won. Most Wanted used to rank `data.totalStolen` and was
-- unwinnable -- whoever had played longest wore it forever, so the one status
-- that cannot be bought was also the one nobody could earn. A lifetime ladder
-- here would make exactly that mistake at a larger scale. A week is long
-- enough that a good session still shows on Thursday and short enough that
-- somebody starting today can win it.
Config.WEEKLY_HEIST = {
	-- Bumped only if the shape of what is stored changes; the week itself is
	-- part of the key, so a new week is a new page rather than a migration.
	store = "WeeklyHeist.v1",
	rows = 8,
	-- Seconds between reads of the sorted page. The write budget is
	-- 60 + 10 per player a minute and the sorted-read budget is 5 + 2 per
	-- player, so at six players this is nowhere near either -- it is set by
	-- how fast a board should react, not by the quota.
	refresh = 45,
}

-- ONE missed day is forgiven; two ends the streak.
--
-- A hard reset is the right rule for an audience that can choose to be here
-- every day. This audience cannot -- they are nine, and Tuesday is not their
-- decision. Losing a thirty-day streak to a school trip teaches them the
-- feature is a trap, and the player who feels trapped is the one who stops
-- opening the game at all.
Config.DAILY_GRACE_DAYS = 2

-- Where in the seven-day cycle a given streak lands. Streak 8 is day 1 again.
function Config.dailyReward(streak: number)
	local cycle = Config.DAILY_CYCLE
	local index = ((math.max(1, streak) - 1) % #cycle) + 1
	return Config.DAILY_CYCLE[index], index
end

-- Bumped for `daily` and the boost fields. DataService.reconcile fills them
-- in on existing saves.
-- ============================================================
-- MOST WANTED GEAR
-- ============================================================
--
-- The only cosmetic in this game worn by the PLAYER rather than by their piggy
-- bank, and the only one that cannot be bought at any price. It is the carrot
-- on the Most Wanted board: without one, topping that board is a tax on playing
-- well -- an officer comes for you every eight minutes and you get a label for
-- it. With one, the heat is something a player chooses to carry.
--
-- EARNED BY ESCAPING, NEVER BY BEING CAUGHT, and specifically by escaping a
-- MOST-WANTED pursuit rather than any pursuit at all. A thief who robs during a
-- patrol and outruns the officer has done something else -- they got away with
-- a robbery, which already pays in coins. This pays for the other thing: being
-- the name on the board and surviving the visit.
--
-- It is deliberately not hard. In a wanted pursuit you are carrying nothing, so
-- you run at BASE_WALK_SPEED against an officer at 14.5 and escaping is the
-- likely outcome -- which makes tier 1 a ceremony rather than a grind, and
-- leaves the difficulty for later rungs. The obvious next one is the same event
-- with one flag flipped: escape while CARRYING, at 12 against 14.5, where the
-- officer gains on you the whole way.
--
-- No stats, ever. Rides, houses and skins all confer nothing for the same
-- reason -- the power balance is a closed system of speed, time and distance,
-- and hanging an advantage off a status symbol reopens every one of those
-- decisions at the exact top of the ladder.
--
-- ORIGINAL, LIKE THE MEME ORNAMENTS AND THE PATROL CAR. The obvious reference
-- here is a specific sportswear brand's cold-weather hood, and its swoosh, its
-- wordmark and its product name are each registered. Moderation strips branded
-- assets and the penalty lands on the EXPERIENCE rather than on the one item,
-- which is a steep price for a hat. What carries it is the GARMENT, and a
-- garment is a genre: a tight hood over the head and neck, an eye opening, a
-- contrast crest and a breather panel.
Config.GEAR = {
	facemask = {
		name = "Face Mask",
		blurb = "Escaped the patrol while Most Wanted.",
		order = 1,

		-- How many most-wanted escapes it takes. See DataService `gear.escapes`.
		escapes = 1,

		-- Unbuyable, so `Config.rarityOf` has no price to read and would fall
		-- through to its free-if-costless branch. Every gear entry therefore
		-- carries an EXPLICIT rarity, the same way the ten drop-pool skins and
		-- all twelve accessories do -- they are not bought either, and what
		-- decides their tier is how hard they were to get.
		rarity = "epic",

		shell = Color3.fromRGB(38, 40, 48),
		trim = Color3.fromRGB(240, 196, 76),
		-- The logo. The piggy's own pink against the dark shell, so the snout
		-- reads as a snout at the distance somebody is actually standing.
		snout = Color3.fromRGB(232, 124, 152),
	},
}

-- Display order for the shop section, so a table with no array part still has
-- one. Adding a tier means adding it here too.
Config.GEAR_ORDER = { "facemask" }

-- What a player still has to do to earn this, in words. One place, because the
-- shop tile and the unlock toast must never be able to describe the same
-- requirement differently.
function Config.gearRequirement(key: string): string
	local spec = Config.GEAR[key]
	if not spec then
		return ""
	end
	local n = spec.escapes or 1
	if n == 1 then
		return "Escape a patrol while MOST WANTED"
	end
	return ("Escape %d patrols while MOST WANTED"):format(n)
end

-- Schema 18 replaces `shards` with `spares`: a duplicate is a spare copy of
-- the ITEM now rather than a shard of its tier, keyed "kind:key" so a skin and
-- an accessory that happen to share a name can never merge into one count.
--
-- THE RENAME RUNS AS A DELETION RATHER THAN A MIGRATION, and that is only
-- honest because it was done while it was free. There is no chest UI at all,
-- so the only shards that have ever existed were made by the admin console --
-- reconcile drops the field and nobody loses anything. The same change after
-- the tab ships needs a real payout, and a payout that runs on every join is a
-- money printer: a far worse bug than the one it would be fixing.
--
-- (17 was THE PIG IS THE WALLET -- `vault` folded into `coins`, `medals` and
-- `tokens` into `loot`. 16 added the shards this one retires.)
--
-- 19 IS `data.week`, AND IT IS THE FREE KIND OF CHANGE. A brand new table of
-- two numbers, both defaulting to zero, on a path `reconcile` already descends
-- -- so every existing save picks it up on its next join with no migration
-- branch, nothing to pay out and nothing that can run twice. The same free
-- ride `loot` and `spares` took, and the argument for doing it NOW rather than
-- after the board it feeds has an audience.
-- 20 ADDS `dogs`, THE DOG'S WARDROBE, AND IT IS THE SAME FREE RIDE AGAIN: a
-- new top-level table of an owned set and one equipped key, filled in by the
-- generic pass in `reconcile` with no migration branch, nothing to pay out and
-- nothing that can run twice.
--
-- LANDED BEFORE ANY UI READS IT, WHICH IS THE WHOLE REASON IT COST NOTHING.
-- The `shards` to `spares` change is the precedent from the other side: it was
-- free precisely because no chest tab existed yet, so reconcile could simply
-- drop the field. The same edit after a tab ships needs a real payout, and a
-- payout that runs on every join is a money printer -- a far worse bug than
-- the one being fixed. Anything else still carrying a placeholder shape wants
-- moving on that argument, while it is still free.
-- 21 ADDS `catch`, THE CATCH-EFFECT WARDROBE, AND IT IS THE FREE RIDE A
-- FOURTH TIME: a new top-level table of an owned set and one equipped key,
-- filled in by the generic pass in `reconcile`, with no migration branch,
-- nothing to pay out and nothing that can run twice.
--
-- LANDED IN THE SAME CHANGE AS THE CATALOGUE AND BEFORE ANY UI READ IT,
-- which is the rule the paragraph below sets and this is the first time it
-- has been followed deliberately rather than by luck.
-- SCHEMA 22: `daily.crate`, the chest a day-seven claim is still OWED.
--
-- The day-seven reward used to be opened inside the claim, so it landed
-- while the player was still looking at the daily board and the one rung
-- on that ladder which pays something playing cannot had no moment of its
-- own. It stands on the doorstep now, and the crate has to survive a
-- disconnect or a player would lose a week's streak to a dropped session.
--
-- A new field defaulting to an empty string, so `reconcile`'s generic pass
-- fills it in one level down inside `daily` with no migration branch,
-- nothing to pay out and nothing that can run twice.
-- THE DELIVERY VAN.
--
-- Traffic, and nothing else. It confers nothing, it cannot be reached,
-- called, bought, aimed or robbed, and nothing on it collides -- see
-- `VanModel`, where that is enforced rather than promised. What it buys is
-- that the street reads as somewhere people live rather than as a diorama
-- with one police car in it, and it is the world's own explanation for the
-- mailbox on every lawn and the crate on a seventh-day doorstep.
Config.DELIVERY = {
	-- SLOWER THAN THE PATROL, WHICH IS THE POINT RATHER THAN A SAVING. The
	-- car does 34 because it is answering an alarm; a van doing the same
	-- speed reads as a second emergency. It is also well under
	-- `BASE_WALK_SPEED`'s neighbours in every direction that matters --
	-- nothing here can catch, block or outrun anybody, because nothing here
	-- touches anybody at all.
	speed = 20,

	-- THE OPPOSITE LANE FROM THE PATROL'S, DERIVED SO THE TWO CANNOT DRIFT
	-- ONTO THE SAME LINE. Two vehicles sharing a centreline is a road with
	-- one lane on it; negating the police's own number keeps them on
	-- opposite sides by construction, and a retune of that lane moves both.
	lane = -Config.POLICE.lane,

	-- HOW LONG THE ROAD STAYS EMPTY BETWEEN RUNS, drawn between these two.
	--
	-- A van every thirty seconds is a motorway and a van every ten minutes
	-- is a van nobody ever sees. At 70 to 150 a player in a fifteen-minute
	-- session meets six or seven, which is often enough to read as a street
	-- and rare enough that one arriving is still worth looking up at.
	--
	-- Randomised rather than fixed for the reason the fireworks' launches
	-- are: an exactly regular arrival is a machine, and a player who can
	-- predict the next one has stopped noticing them.
	gapMin = 70,
	gapMax = 150,

	-- A FRESH SERVER GETS A BEAT BEFORE THE FIRST ONE. Somebody who has
	-- just loaded in is reading a HUD and finding their own plot, which is
	-- the same argument `Config.MUSIC.START_DELAY` makes for holding the
	-- first cue back.
	firstDelay = 45,
}

-- 23: `data.trophies`. A brand new TOP-LEVEL table, which is the free
-- case -- the generic pass in `DataService.reconcile` fills it in on every
-- existing save with no migration branch and nothing that can run twice.
-- Landed BEFORE anything reads it, which `docs/MASTER-PLAN.md` names as the only
-- window in which a schema change is free: the same move after a UI ships
-- needs a real payout, and a payout that runs on every join is a money
-- printer.
Config.SCHEMA_VERSION = 24

Config.AUTOSAVE_INTERVAL = 60

-- A session lock older than this is treated as a crashed server and stolen.
Config.LOCK_STALE_SECONDS = 30 * 60

-- ============================================================
-- DERIVED VALUES
-- ============================================================

-- `friendBonus` is a 0..0.5 fraction and is deliberately optional: offline
-- accrual passes nothing, because your friends weren't in the server while
-- you were asleep and paying you for their absence would be a lie.
-- THE CEILING IS A FUNCTION OF REBIRTHS, AND THAT IS THE KEYSTONE OF THE
-- WHOLE PROGRESSION REWORK.
--
-- It used to be two constants at 20, which is why rebirth made this game
-- SHORTER rather than longer: prestiging multiplied your income against a
-- catalogue that had not grown, so the reward for resetting was reaching the
-- end sooner. Measured before the change -- 19.8 hours to own everything at
-- rebirth 0, and 7.9 hours at rebirth 6.
--
-- Now every rebirth opens two levels that COULD NOT BE BOUGHT BEFORE AT ANY
-- PRICE, which is the only thing that makes a reset feel like progress rather
-- than a tax. Read the cap through here and never from a constant: the client
-- draws the ladder from this too, so both ends agree by construction.
function Config.maxLevel(rebirths: number): number
	return math.min(Config.ABSOLUTE_MAX_LEVEL,
		Config.BAND_TOP + Config.LEVELS_PER_REBIRTH * (rebirths or 0))
end

-- Band A below BAND_TOP, band B above it. Both are written as "band A all the
-- way to the top, then band B for the levels beyond" rather than as a branch
-- on two separate formulas, so the two curves cannot develop a step at the
-- seam -- level 21 is exactly level 20 times one band-B multiplier.
local function banded(base: number, growA: number, growB: number, level: number): number
	local top = Config.BAND_TOP
	if level <= top then
		return base * (growA ^ (level - 1))
	end
	return base * (growA ^ (top - 1)) * (growB ^ (level - top))
end

-- `friendBonus` is a 0..0.5 fraction and is deliberately optional: offline
-- accrual passes nothing, because your friends weren't in the server while
-- you were asleep and paying you for their absence would be a lie.
function Config.getIncomeRate(incomeLevel: number, rebirths: number, friendBonus: number?): number
	local base = banded(Config.BASE_INCOME, Config.INCOME_GROWTH,
		Config.INCOME_GROWTH_B, incomeLevel)
	return base * (1 + rebirths * Config.REBIRTH_MULTIPLIER) * (1 + (friendBonus or 0))
end

function Config.getCapacity(capacityLevel: number): number
	return math.floor(banded(Config.BASE_CAPACITY, Config.CAPACITY_GROWTH,
		Config.CAPACITY_GROWTH_B, capacityLevel))
end

-- Costs are indexed by the level you are LEAVING, so they run one behind the
-- value tables above -- `getIncomeCost(20)` is the price of reaching 21 and is
-- therefore the first band-B price.
--
-- BOTH ARE CLAMPED TO A SHARE OF THE PIG. See UPGRADE_COST_CEILING: the
-- geometric curve outruns capacity and used to cross it, which with a wallet
-- bounded by capacity is a rung nobody can ever pay for. `math.min` is the
-- whole enforcement -- the curve wins while it is the cheaper of the two and
-- the pig wins afterwards, so the invariant cannot be edited back out by
-- moving a growth number.
--
-- Measured against `getCapacity(currentLevel)` -- the pig you have BEFORE the
-- upgrade, which is the one the coins have to sit in.
function Config.getIncomeCost(currentLevel: number): number
	local curve = banded(Config.INCOME_BASE_COST, Config.INCOME_COST_GROWTH,
		Config.INCOME_COST_GROWTH_B, currentLevel)
	local ceiling = Config.UPGRADE_COST_CEILING.income * Config.getCapacity(currentLevel)
	return math.floor(math.min(curve, ceiling))
end

function Config.getCapacityCost(currentLevel: number): number
	local curve = banded(Config.CAPACITY_BASE_COST, Config.CAPACITY_COST_GROWTH,
		Config.CAPACITY_COST_GROWTH_B, currentLevel)
	local ceiling = Config.UPGRADE_COST_CEILING.capacity * Config.getCapacity(currentLevel)
	return math.floor(math.min(curve, ceiling))
end

-- What you must have BANKED to rebirth. See REBIRTH_CAPACITY_MULTIPLE.
--
-- Measured against the ceiling you can currently reach rather than the
-- capacity you happen to have bought, so the gate is the same for everybody at
-- a given rebirth count and cannot be lowered by declining to upgrade.
function Config.getRebirthThreshold(rebirths: number): number
	return math.floor(Config.getCapacity(Config.maxLevel(rebirths))
		* Config.REBIRTH_CAPACITY_MULTIPLE)
end

-- ============================================================
-- THE PRICE AUDIT
-- ============================================================

-- EVERY PRICE IN THIS GAME HAS TO FIT IN A PIG, AND NOTHING USED TO CHECK.
--
-- `UPGRADE_COST_CEILING` makes that true of the two trees by construction.
-- The CATALOGUES have no such clamp and should not have one -- a house price
-- is a design statement, not a derived number -- so they get an audit
-- instead, run at startup, naming anything nobody could ever hold. The Sky
-- Castle was 100M against a pig that maxes at 96.9M: not expensive, not slow,
-- IMPOSSIBLE, and indistinguishable in play from the buy button being broken.
--
-- Note this is a different question from "is it reachable in a reasonable
-- time", which is what the rule about `HEIST_PAYOUT` and `DROPOFF_RADIUS`
-- being the levers rather than the prices is about. That rule is still right.
-- A price above the largest wallet the game can produce is not slow pacing,
-- it is a purchase that cannot exist, and no payout multiplier fixes it --
-- robbing overflows the cap, so it is the one route past this, and a route
-- that needs a populated server is not a route a solo player has.
--
-- WARNS RATHER THAN THROWS, for the reason `Decor.prewarm` is pcalled: a
-- mispriced ornament may never stop the server starting. Returns the list so
-- a test can assert on it rather than reading the log.
function Config.auditEconomy(): { string }
	local problems = {}

	-- The two trees, over every level anybody can ever reach.
	for level = 0, Config.ABSOLUTE_MAX_LEVEL - 1 do
		local pig = Config.getCapacity(level)
		if Config.getIncomeCost(level) > pig then
			table.insert(problems, ("income rung %d costs %d into a pig holding %d")
				:format(level + 1, Config.getIncomeCost(level), pig))
		end
		if Config.getCapacityCost(level) > pig then
			table.insert(problems, ("capacity rung %d costs %d into a pig holding %d")
				:format(level + 1, Config.getCapacityCost(level), pig))
		end
	end

	-- The catalogues, against the largest pig the game can ever produce.
	local biggest = Config.getCapacity(Config.ABSOLUTE_MAX_LEVEL)
	local catalogues = {
		SKINS = Config.SKINS, EFFECTS = Config.EFFECTS,
		HOUSE_TIERS = Config.HOUSE_TIERS, DECOR_ITEMS = Config.DECOR_ITEMS,
		RIDES = Config.RIDES, ACCESSORIES = Config.ACCESSORIES,
		BONES = Config.BONES, GADGETS = Config.GADGETS,
		HOME_ITEMS = Config.HOME_ITEMS,
		-- The dog's two wardrobes. Added here the day the kennels landed, and
		-- the coats had been priced for a session without being audited --
		-- which is the same gap this whole function exists to close, arriving
		-- on a catalogue nobody thought of as one. Anything with a `cost` in
		-- it belongs in this table; the test is the FIELD, not whether it
		-- feels like a shop.
		DOG_COATS = Config.DOG_COATS,
		DOG_KENNELS = Config.DOG_KENNELS,
		DOG_TOYS = Config.DOG_TOYS,
		-- Priced in the same breath it was added, on the lesson directly
		-- above: the test for membership is whether an entry carries a
		-- `cost`. Its legendary is the dearest thing in this table after the
		-- houses, which is exactly the sort of number that wants a machine
		-- checking it against the pig rather than a person remembering to.
		CATCH_EFFECTS = Config.CATCH_EFFECTS,
		-- The trophy frames, priced in the same change that added them, on
		-- the lesson two entries up: the test is the FIELD. The four
		-- TROPHIES themselves are deliberately absent -- they carry no
		-- `cost` at all, so there is no price here for a pig to fail to
		-- hold.
		TROPHY_PLINTHS = Config.TROPHY_PLINTHS,
	}
	for name, catalogue in pairs(catalogues) do
		if type(catalogue) == "table" then
			for key, item in pairs(catalogue) do
				if type(item) == "table" and type(item.cost) == "number"
					and item.cost > biggest then
					table.insert(problems, ("%s.%s costs %d against a largest possible pig of %d")
						:format(name, tostring(key), item.cost, biggest))
				end
			end
		end
	end

	-- The rebirth gate, which is a price like any other: it is one full pig at
	-- the ceiling, so it is reachable exactly while the ceiling is.
	for rebirths = 0, 12 do
		local gate = Config.getRebirthThreshold(rebirths)
		local ceiling = Config.getCapacity(Config.maxLevel(rebirths))
		if gate > ceiling then
			table.insert(problems, ("rebirth %d gate is %d against a ceiling pig of %d")
				:format(rebirths, gate, ceiling))
		end
	end

	return problems
end


-- ============================================================
-- CASING
-- ============================================================

-- THE FIRST UPGRADE IN THIS GAME THAT HANDS OVER A VERB RATHER THAN A NUMBER.
--
-- Every rung in all seven trees is a multiplier: faster, more, cheaper,
-- slower for them. So NOTHING BOUGHT AT REBIRTH FIVE LETS A PLAYER DO
-- ANYTHING THEY COULD NOT DO AT MINUTE TEN -- a maxed player performs the
-- identical robbery to a new one with bigger figures on it, and that is the
-- deepest boredom source this design has. The crack fixed *a robbery has no
-- gameplay*; the spree fixed *a session has no shape*; neither touched *the
-- verbs never change*.
--
-- A MAXED LOCKPICK READS A LOCK FROM THE PAVEMENT. That is a capability
-- rather than a rate: it changes which pig you WALK TO, and it is one more
-- thing to understand rather than one more thing to press -- which is the
-- test this design set itself for anything added at this point.
--
-- IT SELLS BACK EXACTLY WHAT MOVING THE VAULT DIAL COST. The dial used to
-- carry its metal from the street, and the entry above about the hatch says
-- in as many words what the move gave up: *"a thief walks up from the STREET
-- and sees the face, so the metal tier no longer carries from out there."*
-- Casing is that reading restored, to the one player who has bought the right
-- to have it.
--
-- IT IS ADDED AT A RUNG, NEVER SWAPPED FOR ONE, and that is the answer to
-- "does converting a rung break the save of anybody who already owns it".
-- Nothing about what Lockpicks already does changes -- the windows are still
-- widened by `CRACK.pickWindowBonus` at every level -- so a player who maxed
-- it last week simply gains this, and there is no migration, no schema bump
-- and nothing to reconcile. ANY FUTURE VERB SHOULD BE ADDED THE SAME WAY.
Config.CASING = {
	-- DERIVED FROM THE RUNG COUNT RATHER THAN PINNED, so a Lockpicks tree
	-- that grows or shrinks moves this with it instead of stranding the verb
	-- at a level nobody can reach or handing it out early. Same argument as
	-- the Sneakers rung count being solved from `TIPTOE.max`.
	--
	-- The TOP rung specifically: a verb is the reward for finishing a tree,
	-- and a tree whose last rung is another few per cent is a tree nobody
	-- finishes.
	upgrade = "lockpicks",
}

-- Can this player read a lock from the pavement?
--
-- Takes the LEVEL rather than the player, because `Config` requires nothing
-- and must go on requiring nothing -- the same reason `getTiptoeMultiplier`
-- and `getCrackWindow` take numbers. Both ends read it: the rob badge to
-- decide whether to draw the row, and `UpgradeService` to word the shop card.
function Config.canCase(lockpickLevel: number): boolean
	local def = Config.UPGRADES[Config.CASING.upgrade]
	return def ~= nil and (lockpickLevel or 0) >= def.max
end

-- ============================================================
-- THE SPREE
-- ============================================================

-- ROBBERIES IN A ROW ARE WORTH MORE AND COST MORE, WHICH IS THE ONLY THING
-- IN THIS GAME THAT VARIES BETWEEN ROBBERIES RATHER THAN WITHIN ONE.
--
-- The crack made a single robbery a decision. It did nothing about the
-- shape of a SESSION: forty cracks in an hour are forty independent
-- transactions, and a run of five means exactly what five separate ones
-- mean. A spree is the structure that turns a sequence into a run.
--
-- IT IS NOT THE RAP SHEET, AND THE TWO MUST NEVER BE CONFLATED.
-- `SocialService`'s `heat` is the rap sheet: everything you have stolen this
-- session, it only ever goes UP, and it decides the Most Wanted board. A
-- SPREE is momentum -- it counts consecutive deliveries, it DECAYS when you
-- stop, and it is spent by being caught. One field carrying both meanings is
-- the `busyUntil`/`napUntil` bug this file already records, so they are two
-- fields with two names.
Config.SPREE = {
	-- How long after a delivery the next one still counts as consecutive.
	--
	-- MEASURED AGAINST THE ROUND TRIP RATHER THAN CHOSEN. A full five-slice
	-- robbery of the nearest resident is about 21 seconds door to door (see
	-- `robberyCycleSeconds`), so a window of 45 lets a thief working at a
	-- normal pace hold a spree with a little slack, and drops it if they stop
	-- to shop, bank, or wait out a patrol. Much shorter and it would demand
	-- perfect play; much longer and it would never cool down, which makes it
	-- a permanent bonus rather than a run.
	window = 45,

	-- How many consecutive deliveries reach the top.
	--
	-- Four, so the ladder is 1.00, 1.25, 1.50, 1.75, 2.00 -- the first step
	-- is felt immediately and the top is a full minute and a half of
	-- uninterrupted work away. A longer ladder makes the top unreachable in a
	-- fifteen-minute session, which is most of them.
	maxSteps = 4,

	-- What each step adds to the payout multiplier. `maxSteps * payoutPerStep`
	-- is deliberately 1.00, so a maxed spree DOUBLES what a delivery is worth
	-- and nothing about the arithmetic has to be remembered separately.
	--
	-- THE SIZE OF THIS IS PAID FOR BY `RESIDENTS.pigSeconds`, which came down
	-- from 400 to 200 in the same change: a cold thief earns 4.12x idling and
	-- a maxed one 8.25x, which is what EVERYBODY earned before. See that
	-- constant. Raising this without lowering that one is the two-curve
	-- mistake, and `auditRobbery` refuses it at startup.
	payoutPerStep = 0.25,

	-- What each step takes OFF the patrol's floor, as a fraction.
	--
	-- THE RISK HALF, AND IT IS THE EXISTING PATROL RATHER THAN A NEW HAZARD.
	-- `POLICE.wantedFloorSeconds` is how much a thief must have on their rap
	-- sheet before a patrol will come for them unprovoked, in seconds of
	-- their own income. A spree shortens it, so a thief on a run draws a
	-- records check sooner than the same thief taking their time -- and the
	-- rap sheet chip they are already watching turns red to say so.
	--
	-- At four steps the floor is 40% of its resting value, so a full spree
	-- roughly halves the takings needed to be hunted. That is a real cost and
	-- not a fatal one: the counter is to stop for forty-five seconds, which
	-- is the same decision the spree is asking about from the other side.
	floorDropPerStep = 0.15,
}

-- The payout multiplier at `steps` consecutive deliveries. 1.0 at zero.
function Config.getSpreePayout(steps: number): number
	local n = math.clamp(math.floor(steps or 0), 0, Config.SPREE.maxSteps)
	return 1 + n * Config.SPREE.payoutPerStep
end

-- What the patrol's floor is multiplied by at `steps`. Clamped at a fifth so
-- no ladder length can ever drive it to zero -- a floor of nothing would mean
-- a single small robbery draws a patrol, which is precisely the failure the
-- floor was introduced to fix.
function Config.getSpreeFloorScale(steps: number): number
	local n = math.clamp(math.floor(steps or 0), 0, Config.SPREE.maxSteps)
	return math.max(0.2, 1 - n * Config.SPREE.floorDropPerStep)
end

-- ============================================================
-- THE ROBBERY AUDIT
-- ============================================================

-- ROBBING HAS TO OUT-EARN STANDING STILL, AND THAT WAS NEVER CHECKED.
--
-- The whole diagnosis this economy was rebuilt on is that it was not true:
-- `LOSS_CAP` allows a victim to lose a quarter of their pig an hour across ALL
-- thieves, so the entire hourly theft budget of an eight-player server,
-- doubled by `HEIST_PAYOUT` and split eight ways, came to half a pig each --
-- measured at 7% of idle income at level 0 and 14% at level 20. The game was
-- named after an activity that was a rounding error, and standing on your own
-- lawn was the optimal way to play it.
--
-- Residents fixed it by moving the SUPPLY rather than either dial: a plot with
-- nobody on it has a neighbour on it, and a resident has no loss cap because
-- there is nobody behind one to protect. Neither `HEIST_PAYOUT` nor
-- `BASE_INCOME` was touched, and neither should be until this says otherwise.
--
-- THIS AUDIT IS WHAT STOPS THAT SILENTLY REGRESSING. Every number it reads
-- belongs to somebody else -- the crack's slices, the plot spacing, the carry
-- penalty, the payout, `pigSeconds` -- so any one of them can be retuned for a
-- good local reason and put the wall back with nothing in the log to say so.
-- That has already happened once and this audit is what found it: the crack
-- replaced a flat 8% take with a five-slice 21.9% one, and the ratio nobody
-- re-derived went from the 4.92x `pigSeconds` was solved for to 8.25x.
--
-- IT MEASURES THE RESIDENT CYCLE AND DELIBERATELY NOT THE PLAYER ONE. Robbing
-- a real child is capped by `LOSS_CAP` on purpose and always will be -- that is
-- the anti-bullying protection, it is not negotiable, and auditing it would
-- warn forever about a decision rather than about a mistake. Residents are the
-- uncapped supply and therefore the primary income by design, so they are what
-- the invariant is about.
Config.ROBBERY_ADVANTAGE = {
	-- A full clean crack of a resident, per hour, against idling for the same
	-- hour. Under the floor nobody rationally robs and this is the idle game it
	-- used to be; over the ceiling a resident is a faucet and the catalogue
	-- stops being a journey.
	--
	-- THE CEILING IS THE HALF THAT HAS ALREADY BITTEN. A resident's pig used to
	-- be a share of `getCapacity`, which grows 1.40 a level against income at
	-- 1.35, so the ratio drifted from 3.7x at level 1 to 12.3x at level 40 and
	-- the dearest house in the game became one hour of robbing. That is exactly
	-- what `pigSeconds` was introduced to pin.
	min = 3.0,
	max = 10.0,

	-- HOW FAR THE RATIO MAY MOVE ACROSS THE WHOLE GAME, and this is the sharp
	-- one. A constant ratio is the entire point of `pigSeconds`: prices can be
	-- set for whatever robbing is worth, but a ratio that MOVES means no single
	-- set of prices is right for both ends of the game, and the late game
	-- quietly becomes one where anybody who stops robbing stops progressing.
	-- Anything that reintroduces a curve -- a resident pig priced off capacity
	-- again, a take that scales with a level, a getaway that does -- shows up
	-- here as a spread instead of as a number somebody has to happen to notice.
	spread = 0.02,
}

-- THE ROUND TRIP IS DERIVED, NEVER PINNED, or this audit stops describing the
-- game the first time anything moves.
--
-- It is the SHORTEST robbery this game allows, with every slice landing: the
-- 53-stud run between adjacent plots (the same figure `STEAL_RANGE +
-- DROPOFF_RADIUS` against `PLOT_SPACING` is already reasoned about), out at a
-- walk and home under the carry penalty, with the crack's own open hold and
-- one sweep of the dial per slice.
--
-- SO IT IS AN UPPER BOUND ON OPTIMAL PLAY RATHER THAN AN EXPECTED RATE. No
-- dog, no miss, no tag, no patrol, and no walking past a resident to reach a
-- richer one. That asymmetry is what makes the two failures mean different
-- things: falling under `min` means even PERFECT robbing loses to standing
-- still, which is damning, while going over `max` means the best case is too
-- good, which is a warning about the ceiling rather than about the average.
function Config.robberyCycleSeconds(steps: number, run: number?): number
	local distance = run or (Config.PLOT_SPACING - Config.STEAL_RANGE - Config.DROPOFF_RADIUS)
	local approach = distance / Config.BASE_WALK_SPEED
	local getaway = distance / (Config.BASE_WALK_SPEED * Config.CARRY_SPEED_MULTIPLIER)
	local crack = Config.CRACK.openHold + steps * Config.CRACK.sweepSeconds
	return approach + crack + getaway
end

-- HOW FAR A THIEF CARRIES A SHOP VAULT'S COINS, and it is the number the
-- whole shop trade is priced against.
--
-- DERIVED FROM WHERE THE VAULT ACTUALLY STANDS rather than measured once and
-- written down, for the reason `robberyCycleSeconds` is derived: a pinned
-- figure describes the street as it was on the day somebody typed it, and
-- this one moves with `STREET_SPACING`, `PLOT_SPACING`, `SHOP_UNIT` and the
-- shop set-back all at once.
--
-- AND RE-DERIVING IT REVERSED THE PLAN THAT ASKED FOR IT, WHICH IS THE
-- ARGUMENT FOR DERIVING RATHER THAN ADJUSTING. `docs/MASTER-PLAN.md` says
-- the run home "grows by the shop's depth" when the target moves from the
-- forecourt to the back wall, and that is backwards: a shop's back faces the
-- HOUSES, and a drop-off is a thief's own plot behind the fence line. So
-- going inside moves the target 12.4 studs CLOSER to every drop-off on the
-- street. Measured, the carry falls 33.6 studs to 23.0.
--
-- The across term moved the other way and does not undo it. A till stood 16
-- studs off the gap centre, which leaned it toward one plot column and put
-- it 24 studs from it; a vault sits on the unit's own centre line less
-- `vaultX`, which is 36.3. Net, the straight line to the nearest drop-off is
-- 50.0 studs against the till's 60.6, against 80 between two houses.
--
-- THAT SHORTER RUN IS THE WHOLE REASON A SHOP IS WORTH LESS. See
-- `SHOP_VAULT_DISCOUNT`, which is solved against the ratio of the two cycles
-- so that coins per second come out at exactly that fraction and a thief
-- picks a shop for the shape of the job rather than for the money.
function Config.shopVaultRunStuds(): number
	local m = Config.streetMetrics()
	local u = Config.SHOP_UNIT
	-- `vaultZ` is NEGATIVE -- the unit's own frame faces the road on +Z, so
	-- the back wall is at -Z and the vault standing on it is further from the
	-- carriageway and nearer the fence line behind.
	local dz = Config.STREET_SPACING / 2 - (m.shopZ - u.vaultZ)
	local dx = Config.PLOT_SPACING / 2 - u.vaultX
	local straight = math.sqrt(dx * dx + dz * dz)
	return math.max(0, straight - Config.STEAL_RANGE - Config.DROPOFF_RADIUS)
end

-- Coins an hour from cycling non-player pigs at `incomeLevel` and `rebirths`,
-- against coins an hour from doing nothing at all. Both are returned so a
-- caller can print them rather than only their quotient.
--
-- A resident is seated at the AVERAGE income level of the humans in the
-- server, so a solo player robs a peer -- which is the case this measures, and
-- `pigSeconds` then cancels the rate out of the ratio entirely. THAT
-- CANCELLATION IS THE INVARIANT, and computing it the long way here rather
-- than asserting it is what lets the spread check see it break.
--
-- `houses` IS THE THIRD AXIS AND LEAVING IT OUT IS WHAT HID THE WORST BUG IN
-- THIS ECONOMY. This used to assume a thief robs back to back forever, which
-- is only true while there are enough targets that the per-victim cooldown
-- never binds. Residents are seated on UNCLAIMED plots, so how many there are
-- is a function of how busy the server is -- and at a cap equal to the plot
-- count a full server has none at all.
--
-- `shops` IS THE FOURTH, AND IT IS THE ONE THAT MAKES THE THIRD SURVIVABLE.
-- Shop vaults stand on plots nobody can claim, so their count does not move
-- with population at all -- see `Config.SHOPS`. Both default to the
-- floor, which is the worst case rather than the best one.
--
-- THE TWO CLASSES ARE AVERAGED RATHER THAN MODELLED SEPARATELY, and that is
-- an approximation with a stated direction. A shop is a smaller pig on a
-- shorter cycle and a house is a bigger pig on a longer one, so a thief
-- working the whole street earns the weighted mean of the two -- which is
-- what this computes. What it does NOT model is a thief who works ONLY the
-- shops, and that is deliberate: `SHOP_VAULT_DISCOUNT` is solved to make
-- the two rates equal, so the two strategies converge by construction and the
-- audit measuring the mean is measuring both. If that constant is ever moved
-- so the rates diverge, this function has to grow a per-class sweep and the
-- audit has to check the BETTER of the two rather than the average.
function Config.robberyRates(incomeLevel: number, rebirths: number, spreeSteps: number?,
	houses: number?, shops: number?): (number, number)
	local rate = Config.getIncomeRate(incomeLevel, rebirths)
	local payout = Config.HEIST_PAYOUT * Config.getSpreePayout(spreeSteps or 0)
	local take = Config.getCrackTotal(0) * payout

	local nHouses = houses or math.max(0, Config.PLOT_COUNT - Config.MAX_PLAYERS)
	local nShops = shops or Config.SHOP_COUNT
	local n = nHouses + nShops
	if n <= 0 then
		return 0, rate * 3600
	end

	local houseHaul = Config.RESIDENTS.pigSeconds * rate * take
	local shopHaul = Config.shopVaultPigSeconds() * rate * take
	local houseCycle = Config.robberyCycleSeconds(Config.CRACK.maxSteps)
	local shopCycle = Config.robberyCycleSeconds(Config.CRACK.maxSteps, Config.shopVaultRunStuds())

	local haul = (houseHaul * nHouses + shopHaul * nShops) / n
	local cycle = (houseCycle * nHouses + shopCycle * nShops) / n

	-- HAULS AN HOUR IS WHICHEVER OF TWO LIMITS BINDS FIRST: how fast one
	-- robbery can be performed, and how fast the same pig may be robbed
	-- twice. With N pigs a thief completes one every `cycle`, and revisits any
	-- given one every `N x cycle` -- so the cooldown only costs anything when
	-- that lap is shorter than it. Zero pigs is zero income, which is the case
	-- the old formula could not express.
	local perHour = 3600 * math.min(1 / cycle, n / Config.RESIDENTS.stealCooldown)
	return haul * perHour, rate * 3600
end

-- WARNS RATHER THAN THROWS, and returns the list so a test can assert on it
-- instead of reading the log -- the same shape as `auditEconomy` and
-- `auditFences`, for the same reason: a balance number may never stop the
-- server starting.
function Config.auditRobbery(): { string }
	local problems = {}
	local band = Config.ROBBERY_ADVANTAGE

	-- BOTH ENDS OF THE SPREE, because they answer different questions and a
	-- single measurement would miss one of them entirely.
	--
	-- COLD is a thief robbing without a run going, and it is what the FLOOR is
	-- about: nobody should be punished for playing at their own pace. HOT is a
	-- thief sustaining a full spree, and it is what the CEILING is about,
	-- because that is the best this game can be played and therefore the rate
	-- that decides whether a resident is a faucet. Measuring only one lets the
	-- other drift with nothing to say so -- which is exactly what a spree
	-- multiplying an unmeasured payout would have done.
	local function sweep(steps: number): (number, string, number, string)
		local lowest, highest = math.huge, 0
		local lowestAt, highestAt = "", ""
		for rebirths = 0, 10 do
			for level = 0, Config.maxLevel(rebirths) do
				local robbing, idling = Config.robberyRates(level, rebirths, steps)
				local ratio = robbing / idling
				local at = ("level %d rebirth %d"):format(level, rebirths)
				if ratio < lowest then
					lowest, lowestAt = ratio, at
				end
				if ratio > highest then
					highest, highestAt = ratio, at
				end
			end
		end
		return lowest, lowestAt, highest, highestAt
	end

	local coldLow, coldLowAt = sweep(0)
	local _, _, hotHigh, hotHighAt = sweep(Config.SPREE.maxSteps)
	local lowest, lowestAt, highest, highestAt = sweep(0)

	if coldLow < band.min then
		table.insert(problems, ("robbing with no spree returns only %.2fx idling at %s, under a floor of %.2fx: "):format(
			coldLow, coldLowAt, band.min)
			.. "standing on your own lawn is the better play there")
	end
	if hotHigh > band.max then
		table.insert(problems, ("a maxed spree returns %.2fx idling at %s, over a ceiling of %.2fx: "):format(
			hotHigh, hotHighAt, band.max)
			.. "a resident is a faucet, see RESIDENTS.pigSeconds and SPREE.payoutPerStep")
	end

	-- The constancy check. Expressed as a fraction of the smaller figure so it
	-- reads the same at level 0 as at level 40, which is the whole point of it.
	-- Run on the COLD sweep, because the spree is a flat multiplier and cannot
	-- introduce a curve the cold pass would not already show.
	local drift = (highest - lowest) / lowest
	if drift > band.spread then
		table.insert(problems, ("the advantage MOVES: %.2fx at %s up to %.2fx at %s, a spread of %.1f%% against %.1f%% allowed: "):format(
			lowest, lowestAt, highest, highestAt, drift * 100, band.spread * 100)
			.. "something is riding a curve again, see RESIDENTS.pigSeconds")
	end

	-- THE POPULATION SWEEP, WHICH IS THE ONE THAT WAS MISSING AND THE ONE THAT
	-- ACTUALLY BROKE. Everything above measures how the advantage moves with
	-- LEVEL and REBIRTH. It moves with SERVER POPULATION too, and far harder,
	-- because residents are seated on unclaimed plots -- so the supply is
	-- `PLOT_COUNT - players online` and the old audit measured exactly one
	-- point on that axis.
	--
	-- Swept at the busiest the street can be and every population under it,
	-- because the WORST case is a FULL server rather than an empty one, which
	-- is the opposite of what the level sweeps assume.
	for players = 1, Config.MAX_PLAYERS do
		local houses = math.max(0, Config.PLOT_COUNT - players)
		local robbing, idling = Config.robberyRates(20, 0, 0, houses, Config.SHOP_COUNT)
		local ratio = robbing / idling
		if ratio < band.min then
			table.insert(problems, ("with %d players there are %d resident houses and %d shop vaults, and robbing returns %.2fx idling against a floor of %.2fx: "):format(
				players, houses, Config.SHOP_COUNT, ratio, band.min)
				.. "the economy depends on how busy the server is, see MAX_PLAYERS, SHOPS and RESIDENT_FLOOR")
		end
	end

	-- AND THE FLOOR POPULATION MUST SATURATE, which is what makes the sweep
	-- above come out FLAT rather than merely passing. A thief working the
	-- fewest houses the street can ever hold should never be left waiting on a
	-- cooldown -- if they are, the advantage falls with every extra player and
	-- the ratio moves for the same reason `pigSeconds` exists to stop it
	-- moving with level.
	-- The lap at the floor. Measured on the SHOP cycle rather than the house
	-- one, because at a full server the shops are the entire floor -- so this
	-- is the fastest a thief can get round the fewest pigs the street ever
	-- holds, which is exactly the case that has to clear the cooldown.
	local floorLap = Config.RESIDENT_FLOOR
		* Config.robberyCycleSeconds(Config.CRACK.maxSteps, Config.shopVaultRunStuds())
	if Config.RESIDENT_FLOOR <= 0 then
		table.insert(problems, ("MAX_PLAYERS %d against PLOT_COUNT %d and %d shops leaves nothing to rob on a full server: "):format(
			Config.MAX_PLAYERS, Config.PLOT_COUNT, Config.SHOP_COUNT)
			.. "robbing stops paying exactly when the server fills up, see SHOPS")
	elseif floorLap < Config.RESIDENTS.stealCooldown then
		table.insert(problems, ("%d permanent pigs lap in %.1fs against a %ds cooldown: "):format(
			Config.RESIDENT_FLOOR, floorLap, Config.RESIDENTS.stealCooldown)
			.. "a thief on a full server waits on the cooldown, so the advantage falls as the street fills -- add a shop or shorten the cooldown")
	end

	-- A SHOP MAY PAY LESS THAN A HOUSE AND MAY NEVER PAY MORE, AND THE CHECK
	-- IS DIRECTIONAL BECAUSE THE DESIGN IS.
	--
	-- The two are not the same job: a shop has no dog and a carry home about
	-- 43% as long, so paying the same for it would make the houses pointless
	-- the moment a player worked out which was which.
	-- `Config.SHOP_VAULT_DISCOUNT` is that risk premium, and it is meant to
	-- come out BELOW parity -- so a symmetric skew check would fire on the
	-- design working correctly, which is the cry-wolf failure this file
	-- already records for the clipping checks.
	--
	-- WHAT IT IS ACTUALLY GUARDING IS `robberyRates`, which models a thief
	-- working the whole street and returns the weighted MEAN of the two
	-- classes. A mean is only a fair summary of a strategy while the two are
	-- close: let a shop pay more and a thief works shops exclusively, so every
	-- figure the sweeps above print describes a strategy nobody uses. Let a
	-- shop pay far less and the same is true from the other side -- nobody
	-- would walk to one, and the supply floor those shops are supposed to BE
	-- is fictional.
	--
	-- The floor case is the sharp one and it is already covered above: at a
	-- full server the shops are the entire supply, so a shop too cheap fails
	-- `ROBBERY_ADVANTAGE.min` in the population sweep before it fails here.
	do
		local houseRate = Config.RESIDENTS.pigSeconds
			/ Config.robberyCycleSeconds(Config.CRACK.maxSteps)
		local shopRate = Config.shopVaultPigSeconds()
			/ Config.robberyCycleSeconds(Config.CRACK.maxSteps, Config.shopVaultRunStuds())
		if shopRate > houseRate then
			table.insert(problems, ("a shop vault pays %.2f coins per pig-second of cycle against a house's %.2f: "):format(
				shopRate, houseRate)
				.. "a shop has no dog and a shorter carry, so paying MORE than a house makes every house on the street pointless -- see SHOP_VAULT_DISCOUNT")
		elseif shopRate / houseRate < 0.6 then
			table.insert(problems, ("a shop vault pays %.2f coins per pig-second of cycle against a house's %.2f, only %.0f%%: "):format(
				shopRate, houseRate, shopRate / houseRate * 100)
				.. "nobody would walk to one, so the supply floor they exist to be is fictional -- see SHOP_VAULT_DISCOUNT")
		end
	end

	-- A cap ABOVE the plot count is the older and louder failure: `Main` kicks
	-- anybody it cannot seat, so those players are turned away at the door.
	if Config.MAX_PLAYERS > Config.PLOT_COUNT then
		table.insert(problems, ("MAX_PLAYERS %d is above PLOT_COUNT %d: "):format(
			Config.MAX_PLAYERS, Config.PLOT_COUNT)
			.. "Main kicks anybody it cannot seat, so that many players are refused entry")
	end

	return problems
end

-- WHICH PER-VICTIM COOLDOWN APPLIES, in one place so the two can never be
-- asked separately and drift. See `RESIDENTS.stealCooldown` for why an empty
-- house does not need the protection a child does.
function Config.stealCooldownFor(isResident: boolean): number
	return if isResident then Config.RESIDENTS.stealCooldown else Config.STEAL_COOLDOWN
end


return Config
