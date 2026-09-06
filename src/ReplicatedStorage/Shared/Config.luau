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
	SIREN = "",
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
Config.LOSS_CAP = {
	fraction = 0.25,
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
	loot = 1,
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

-- Tagging a thief: anyone nearby can do it, including bystanders.
Config.TAG_HOLD = 0.4
Config.TAG_DISTANCE = 14
Config.STUN_SECONDS = 4

-- How close a thief must get to their own piggy to bank the loot.
--
-- Sized against PLOT_SPACING deliberately. STEAL_RANGE + DROPOFF_RADIUS must
-- stay well under the spacing, or a thief could stand in their own drop-off
-- zone and rob a neighbour without ever running -- and the run is the entire
-- risk half of the trade. At 11 + 16 against a spacing of 80 the shortest
-- possible getaway is 53 studs, about 4.4 seconds at carry speed -- it was 37
-- studs and 3.1 seconds before the plot was widened, and this is the number
-- that moved with it.
--
-- SO THIS IS THE LEVER IF ROBBING EVER READS AS TOO HARD. A drop-off radius is
-- a fraction of your own plot rather than an absolute distance, so it can grow
-- with the plot and hand the run back without touching PLOT_SPACING, which the
-- alley and the row length both depend on. Measured over the longer run, an
-- alerted Titan at 17 closes 22.1 studs on a carrying thief against 15.5
-- before.
Config.DROPOFF_RADIUS = 16

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
		blurb = "Chases thieves and tags them for you",
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
		blurb = "Run faster while carrying loot",
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
	-- 2.0, 2.8, 3.9, 5.5 and 7.7 per cent, so a full clean run takes 21.9%
	-- against a LOSS_CAP of 25% -- a greedy thief can empty a victim's whole
	-- hourly allowance in one attempt and no further, which is the shape
	-- that stops a plot being farmed by inches. At six steps the run reaches
	-- 28.9% and the last slice is silently clamped to nothing, which reads
	-- as the minigame being broken rather than as a cap being reached.
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
-- still be tagged by anybody who spots them. What a silent crack buys is
-- that nobody was TOLD -- it is stealth of the alarm, never stealth of the
-- getaway, and the run home is as public as it ever was.
Config.CRACK_ALARM_ON_MISS = true

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

	-- Seconds between accrual ticks. Matches EconomyService's own cadence so
	-- a resident's pile climbs at visibly the same rate a player's does.
	tickRate = 1,

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
		boneResist = 0.6,
		fur = Color3.fromRGB(58, 56, 64),
		furDark = Color3.fromRGB(32, 31, 37),
		collar = Color3.fromRGB(246, 198, 52),
		glow = true,
		blurb = "Runs down fully booted thieves. Nothing leaves this plot",
	},
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
-- THE IMMUNITY IS THE POINT. For half a second you cannot be tagged, caught by
-- a dog, or hit by a gadget. TAG_HOLD is 0.4s, so a defender who eats a dodge
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
	-- tagged -- TAG_HOLD is 0.4, so a 1.2 entry cannot be won from contact.
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
-- the SAME speed as the person chasing them. Tagging becomes impossible
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
-- carrying loot -- and it has been deliberately dropped. It is worth being
-- exact about what it was protecting, because the protection is kept and only
-- the refusal is gone.
--
-- It was never about the tree's balance. It was that a gadget pointable at
-- anybody is a harassment toy handed to under-twelves. But what makes a toy
-- harassment is the EFFECT, not the aim: being able to take somebody's
-- movement away, repeatedly, at will. So the aim opens and the effect is what
-- gets held down. A hit on somebody who is not carrying anything is a PRANK:
--
--   * It lasts GADGET_FUN.duration, a fraction of the real one, and the
--     zapper's dead stop is capped at GADGET_FUN.stunCap. Long enough to be
--     funny, too short to stop anybody getting anywhere.
--   * One target may only be pranked once every GADGET_FUN.targetCooldown
--     seconds, by ANYBODY. The cooldown is on the person being hit rather
--     than on the thrower, which is the only version that stops six players
--     taking turns on one child.
--   * It costs the same coins as a real throw, so it is never free.
--   * It never touches the raincoat. Burning a coat somebody bought to
--     survive a chase with a 1,500-coin joke would be the grief this whole
--     block exists to prevent.
--   * Nothing is stolen, dropped or lost by it, ever. It cannot be used to
--     start, help or finish a robbery, because the SERIOUS effect still
--     requires the target to be carrying.
--
-- A carrier is still found FIRST, at every range, so nothing about a real
-- chase changes: a gadget only looks around for somebody to prank when there
-- is nobody to stop.
--
-- The three differ in KIND rather than just in magnitude -- reach, denial,
-- finisher -- which is what stops the cheap two being dead weight once the
-- expensive one is affordable.
--
-- The arithmetic each was tuned against, worst case: thief at 16 (boots
-- maxed), defender at 16, both running in a straight line, TAG_DISTANCE 14.
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

-- Same flight time and cooldown as a bone: these are the same gesture, and
-- two different throw feels in one hand would be worse than one.
Config.GADGET_THROW_COOLDOWN = 1.5
Config.GADGET_FLIGHT = 0.45

-- WHAT A GADGET DOES TO SOMEBODY WHO IS NOT CARRYING ANYTHING.
--
-- The whole of "you may throw one at anyone" lives in these three numbers,
-- and they are what keep an open aim from being a harassment toy. See the
-- long note over Config.GADGETS.
--
-- `duration` is about a third of the shortest real one (the zapper's 1.2s)
-- and a quarter of the longest, so a prank is a wobble and a hit on a robber
-- is still the thing that closes a gap. `stunCap` is the important half of
-- that: a stun is zero WalkSpeed AND zero JumpHeight, which is the one effect
-- that takes control away rather than just slowing somebody down, so the
-- zapper's 0.6 comes down to a blink.
--
-- `targetCooldown` is on the PERSON BEING HIT, never on the thrower. A
-- thrower cooldown would be no protection at all: six players with plungers
-- would simply take turns, and the one child in the middle would never get
-- to move. Because it is on the target, the worst anybody can do to them --
-- however many people are throwing, however rich -- is 0.9 seconds in every
-- 6, and even that costs somebody 1,500 coins a go.
Config.GADGET_FUN = {
	duration = 0.9,
	stunCap = 0.3,
	targetCooldown = 6,
}

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
		title = "LOOT", glyph = ICON.MONEYBAG, tone = Color3.fromRGB(255, 203, 61),
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
-- ROBBING IS ITS FIRST SOURCE, and the daily ladder pays none: loot is the
-- currency you go out and earn. Events pay the old medal shape when they
-- return -- everything under `event` is what Config.MEDALS used to be.
Config.LOOT = {
	-- Per delivery of a robbery. One, so the price ladder on the roll reads as
	-- "how many robberies", which is the honest unit for it.
	delivery = 1,
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
		items = {
			{ kind = "accessory", key = "antenna" },
			{ kind = "accessory", key = "abductor" },
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
function Config.catalogueFor(kind: string)
	return (({
		skin = Config.SKINS,
		effect = Config.EFFECTS,
		accessory = Config.ACCESSORIES,
		decor = Config.DECOR_ITEMS,
		ride = Config.RIDES,
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

	-- Catching a thief who is carrying. Amber, matching the chase alert: this
	-- is the one prompt that appears ON another player and disappears again in
	-- seconds, so it wants to be seen from across a lawn.
	tag = {
		glyph = ICON.SIREN, tone = Color3.fromRGB(230, 147, 64),
		verb = "TAG THIEF",
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

Config.SKINS = {
	classic = {
		name = "Classic Pink", order = 1, cost = 0,
		body = Color3.fromRGB(244, 168, 194), trim = Color3.fromRGB(214, 122, 148),
		material = Enum.Material.SmoothPlastic, transparency = 0,
	},
	bubblegum = {
		chest = "classics",
		name = "Bubblegum", order = 2, cost = 8000,
		body = Color3.fromRGB(255, 132, 190), trim = Color3.fromRGB(206, 78, 148),
		material = Enum.Material.SmoothPlastic, transparency = 0,
	},
	mint = {
		chest = "classics",
		name = "Mint Choc", order = 3, cost = 20000,
		body = Color3.fromRGB(148, 226, 190), trim = Color3.fromRGB(88, 62, 52),
		material = Enum.Material.SmoothPlastic, transparency = 0,
	},
	sunset = {
		chest = "classics",
		name = "Sunset", order = 4, cost = 45000,
		body = Color3.fromRGB(255, 158, 92), trim = Color3.fromRGB(206, 92, 108),
		material = Enum.Material.SmoothPlastic, transparency = 0,
	},
	midnight = {
		chest = "classics",
		name = "Midnight", order = 5, cost = 90000,
		body = Color3.fromRGB(78, 84, 156), trim = Color3.fromRGB(44, 48, 96),
		material = Enum.Material.Glass, transparency = 0,
	},
	lava = {
		chest = "classics",
		name = "Lava", order = 6, cost = 200000,
		body = Color3.fromRGB(232, 92, 48), trim = Color3.fromRGB(58, 30, 26),
		material = Enum.Material.Neon, transparency = 0,
	},
	galaxy = {
		chest = "classics",
		name = "Galaxy", order = 7, cost = 500000,
		body = Color3.fromRGB(126, 82, 200), trim = Color3.fromRGB(52, 34, 92),
		material = Enum.Material.Neon, transparency = 0,
	},
	pearl = {
		chest = "classics",
		name = "Pearl", order = 8, cost = 1200000,
		body = Color3.fromRGB(248, 244, 236), trim = Color3.fromRGB(206, 198, 220),
		material = Enum.Material.Glass, transparency = 0,
	},

	-- Earned by rebirthing rather than paid for, so the collection has two
	-- routes into it and a rebirth still hands you something to show off.
	bronze = {
		name = "Bronze", order = 20, unlockRebirths = 1,
		body = Color3.fromRGB(196, 132, 74), trim = Color3.fromRGB(150, 96, 50),
		material = Enum.Material.Metal, transparency = 0,
	},
	goldleaf = {
		name = "Gold Leaf", order = 21, unlockRebirths = 3,
		body = Color3.fromRGB(238, 190, 78), trim = Color3.fromRGB(198, 148, 44),
		material = Enum.Material.Metal, transparency = 0,
	},
	diamond = {
		name = "Diamond", order = 22, unlockRebirths = 6,
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
		chest = "classics",
		name = "Ember Glow", order = 30, rarity = "rare",
		body = Color3.fromRGB(226, 104, 52), trim = Color3.fromRGB(120, 44, 30),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "pulse", speed = 1.4, palette = {
			Color3.fromRGB(226, 104, 52), Color3.fromRGB(255, 176, 84),
		} },
	},
	frostbite = {
		chest = "classics",
		name = "Frostbite", order = 31, rarity = "rare",
		body = Color3.fromRGB(186, 232, 248), trim = Color3.fromRGB(120, 176, 208),
		material = Enum.Material.Glass, transparency = 0,
		anim = { kind = "pulse", speed = 0.8, palette = {
			Color3.fromRGB(186, 232, 248), Color3.fromRGB(246, 252, 255),
		} },
	},
	toxic = {
		chest = "classics",
		name = "Toxic Ooze", order = 32, rarity = "rare",
		body = Color3.fromRGB(140, 226, 84), trim = Color3.fromRGB(66, 122, 40),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "cycle", speed = 0.7, palette = {
			Color3.fromRGB(140, 226, 84), Color3.fromRGB(96, 190, 70), Color3.fromRGB(196, 240, 110),
		} },
	},
	candyswirl = {
		chest = "classics",
		name = "Candy Swirl", order = 33, rarity = "rare",
		body = Color3.fromRGB(255, 150, 200), trim = Color3.fromRGB(255, 236, 244),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		anim = { kind = "cycle", speed = 1.1, palette = {
			Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 244, 250), Color3.fromRGB(150, 210, 255),
		} },
	},

	aurora = {
		chest = "classics",
		name = "Aurora", order = 40, rarity = "epic",
		body = Color3.fromRGB(96, 226, 190), trim = Color3.fromRGB(60, 110, 150),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "cycle", speed = 0.55, glow = 1.6, palette = {
			Color3.fromRGB(96, 226, 190), Color3.fromRGB(84, 160, 238),
			Color3.fromRGB(178, 118, 236), Color3.fromRGB(96, 226, 190),
		} },
	},
	magma = {
		chest = "classics",
		name = "Magma Core", order = 41, rarity = "epic",
		body = Color3.fromRGB(210, 58, 30), trim = Color3.fromRGB(52, 20, 16),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "flicker", speed = 9, glow = 2.2, palette = {
			Color3.fromRGB(150, 32, 18), Color3.fromRGB(255, 148, 44),
		} },
	},
	voidsilk = {
		chest = "classics",
		name = "Void Silk", order = 42, rarity = "epic",
		body = Color3.fromRGB(46, 30, 72), trim = Color3.fromRGB(22, 14, 36),
		material = Enum.Material.Glass, transparency = 0,
		anim = { kind = "pulse", speed = 0.5, glow = 1.4, palette = {
			Color3.fromRGB(46, 30, 72), Color3.fromRGB(140, 78, 220),
		} },
	},

	supernova = {
		chest = "classics",
		name = "Supernova", order = 50, rarity = "legendary",
		body = Color3.fromRGB(255, 230, 150), trim = Color3.fromRGB(232, 128, 40),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "cycle", speed = 2.2, glow = 4.0, palette = {
			Color3.fromRGB(255, 248, 220), Color3.fromRGB(255, 196, 72),
			Color3.fromRGB(255, 110, 40), Color3.fromRGB(255, 248, 220),
		} },
	},
	stormcaller = {
		chest = "classics",
		name = "Stormcaller", order = 51, rarity = "legendary",
		body = Color3.fromRGB(120, 176, 255), trim = Color3.fromRGB(40, 52, 92),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "flicker", speed = 14, glow = 4.5, palette = {
			Color3.fromRGB(64, 96, 176), Color3.fromRGB(232, 246, 255),
		} },
	},
	prismatic = {
		chest = "classics",
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
		name = "Ladybird", order = 100, cost = 25000,
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
		name = "Dairy Cow", order = 101, cost = 35000,
		-- The trim stays PINK rather than going black with the blotches. It
		-- paints the snout, and a cow's muzzle is the one part of it that is
		-- pink -- so the two channels each say something instead of both
		-- saying "Holstein".
		body = Color3.fromRGB(246, 244, 238), trim = Color3.fromRGB(226, 158, 168),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- Few and LARGE, with heavy size jitter, because a cow is blotches
		-- rather than dots -- the difference between this and the dalmatian
		-- below is entirely `count` against `size`.
		pattern = {
			kind = "spots", seed = 11,
			colour = Color3.fromRGB(34, 32, 38),
			count = 11, size = 0.30, vary = 0.40,
		},
	},
	sheep = {
		chest = "animal",
		name = "Woolly Sheep", order = 102, cost = 60000,
		body = Color3.fromRGB(238, 232, 220), trim = Color3.fromRGB(48, 44, 46),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- THE ONLY `bump` IN THE CATALOGUE, and the one place a ball beats a
		-- disc. A fleece is not a marking, it is a texture -- what says sheep
		-- is that the silhouette has gone lumpy -- and a flat disc cannot be
		-- lumpy at any size. `bump` therefore keeps clear of the hat anchor by
		-- construction; see CROWN_LIMIT in PiggyModel.
		pattern = {
			kind = "spots", seed = 5, bump = true, proud = 0.55,
			colour = Color3.fromRGB(250, 246, 238),
			count = 32, size = 0.24, vary = 0.28,
			material = Enum.Material.SmoothPlastic, transparency = 0,
		},
	},
	dalmatian = {
		chest = "animal",
		name = "Dalmatian", order = 103, cost = 90000,
		body = Color3.fromRGB(248, 246, 242), trim = Color3.fromRGB(44, 42, 48),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		pattern = {
			kind = "spots", seed = 7,
			colour = Color3.fromRGB(30, 28, 34),
			count = 27, size = 0.10, vary = 0.40,
		},
	},

	zebra = {
		chest = "animal",
		name = "Zebra", order = 110, cost = 250000,
		body = Color3.fromRGB(244, 242, 236), trim = Color3.fromRGB(36, 34, 38),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- Bands run ACROSS the spine, which is the only orientation the
		-- builder draws and the only one a zebra wears. `wobble` jitters each
		-- band's position and width off the even spacing, because seven
		-- identical bands at identical intervals is a barcode.
		pattern = {
			kind = "stripes", seed = 13,
			colour = Color3.fromRGB(30, 28, 32),
			count = 7, width = 0.15, spread = 0.70, arc = 195, wobble = 0.35,
		},
	},
	bee = {
		chest = "animal",
		name = "Bumblebee", order = 111, cost = 400000,
		body = Color3.fromRGB(250, 198, 40), trim = Color3.fromRGB(40, 36, 34),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- FOUR FAT BANDS AND NO WOBBLE, which is the whole difference from the
		-- zebra: a bee is regular and a zebra is not, and both come out of the
		-- same three numbers.
		pattern = {
			kind = "stripes", seed = 2,
			colour = Color3.fromRGB(34, 30, 28),
			count = 4, width = 0.20, spread = 0.62, arc = 230, wobble = 0,
		},
	},
	cheetah = {
		chest = "animal",
		name = "Cheetah", order = 112, cost = 900000,
		body = Color3.fromRGB(226, 178, 102), trim = Color3.fromRGB(150, 106, 54),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- Many small solid dots, against the leopard's fewer larger ones. That
		-- is the real difference between the two animals and it is the only
		-- one this builder can draw: a rosette is a ring, and a ring needs a
		-- second mark per spot, which doubles the part count of a skin that
		-- twelve piggies might be wearing at once.
		pattern = {
			kind = "spots", seed = 17,
			colour = Color3.fromRGB(58, 42, 30),
			count = 32, size = 0.085, vary = 0.30,
		},
	},

	giraffe = {
		chest = "animal",
		name = "Giraffe", order = 120, cost = 1800000,
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
		name = "Leopard", order = 121, cost = 2400000,
		body = Color3.fromRGB(232, 186, 110), trim = Color3.fromRGB(128, 86, 44),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		pattern = {
			kind = "spots", seed = 23,
			colour = Color3.fromRGB(46, 32, 24),
			count = 22, size = 0.13, vary = 0.45,
		},
	},
	orca = {
		chest = "animal",
		name = "Orca", order = 122, cost = 4000000,
		-- The one inverted animal in the bucket: pale marks on a dark body
		-- rather than the other way round, which is most of why it reads as a
		-- different creature and not as another cow.
		body = Color3.fromRGB(32, 34, 42), trim = Color3.fromRGB(240, 244, 248),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		pattern = {
			kind = "spots", seed = 29,
			colour = Color3.fromRGB(244, 248, 252),
			count = 10, size = 0.28, vary = 0.30,
		},
	},

	-- CHEST-ONLY. An explicit `rarity` and no `cost`, which is what keeps them
	-- out of the shop's coin grid and stops the free-if-costless fallback in
	-- `Config.isSkinUnlocked` handing them to everybody. Note this also puts
	-- them in the REBIRTH DROP POOL, exactly as the classics' drop skins are:
	-- `Config.getSkinsOfRarity` selects on `rarity` and excludes only `set`.
	tiger = {
		chest = "animal",
		name = "Bengal Tiger", order = 130, rarity = "legendary",
		body = Color3.fromRGB(238, 132, 36), trim = Color3.fromRGB(250, 240, 228),
		material = Enum.Material.SmoothPlastic, transparency = 0,
		-- The most bands of anything here, the thinnest, and the most wobble:
		-- nine narrow uneven stripes is what separates a tiger from a zebra at
		-- a glance, and the arc is wider so they carry down both flanks.
		pattern = {
			kind = "stripes", seed = 31,
			colour = Color3.fromRGB(32, 24, 22),
			count = 8, width = 0.11, spread = 0.76, arc = 190, wobble = 0.55,
		},
	},
	snowleopard = {
		chest = "animal",
		name = "Snow Leopard", order = 131, rarity = "legendary",
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

	-- ============================================================
	-- THE NEON BUCKET
	-- ============================================================
	--
	-- `chest = "neon"`. Every body here is Neon and every body here is DEEP,
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
		chest = "neon",
		name = "Cyber Lime", order = 200, cost = 12000,
		body = Color3.fromRGB(110, 200, 20), trim = Color3.fromRGB(48, 92, 10),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "pulse", speed = 1.2, palette = {
			Color3.fromRGB(110, 200, 20), Color3.fromRGB(150, 232, 56),
		} },
	},
	neonmint = {
		chest = "neon",
		name = "Neon Mint", order = 201, cost = 40000,
		body = Color3.fromRGB(36, 196, 146), trim = Color3.fromRGB(16, 92, 72),
		material = Enum.Material.Neon, transparency = 0,
		anim = { kind = "pulse", speed = 0.9, palette = {
			Color3.fromRGB(36, 196, 146), Color3.fromRGB(64, 226, 176),
		} },
	},
	hotwire = {
		chest = "neon",
		name = "Hot Wire", order = 202, cost = 75000,
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
	circuit = {
		chest = "neon",
		name = "Circuit Board", order = 203, cost = 96000,
		body = Color3.fromRGB(22, 96, 62), trim = Color3.fromRGB(10, 44, 30),
		material = Enum.Material.Neon, transparency = 0,
		pattern = {
			kind = "stripes", seed = 43,
			colour = Color3.fromRGB(196, 246, 120),
			count = 6, width = 0.07, spread = 0.74, arc = 195,
			transparency = 0,
		},
		anim = { kind = "pulse", speed = 0.6, palette = {
			Color3.fromRGB(22, 96, 62), Color3.fromRGB(38, 140, 86),
		} },
	},

	laserdream = {
		chest = "neon",
		name = "Laser Grid", order = 210, cost = 220000,
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
		chest = "neon",
		name = "Plasma Ball", order = 211, cost = 480000,
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
		chest = "neon",
		name = "Vaporwave", order = 212, cost = 850000,
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
		chest = "neon",
		name = "Synthwave Sun", order = 220, cost = 1600000,
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
		chest = "neon",
		name = "Ultraviolet", order = 221, cost = 3200000,
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
		chest = "neon",
		name = "Gridrunner", order = 222, cost = 6000000,
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
		chest = "neon",
		name = "Hyperdrive", order = 230, cost = 14000000,
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
		chest = "neon",
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
}

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
}

function Config.getSkin(key: string)
	return Config.SKINS[key] or Config.SKINS[Config.DEFAULT_SKIN]
end

function Config.getEffect(key: string)
	return Config.EFFECTS[key] or Config.EFFECTS[Config.DEFAULT_EFFECT]
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
-- A SET SKIN IS NEVER A DROP. Set items carry a rarity like everything else,
-- because the shop borders every card with one -- but rarity is also what
-- puts a skin in this pool, so the Martian would have started falling out of
-- rebirths for players who had never seen an invasion. `set` is the
-- exclusion, and this is one of exactly two places it has to be honoured.
function Config.getSkinsOfRarity(rarity: string): { string }
	local out = {}
	for key, skin in pairs(Config.SKINS) do
		if skin.rarity == rarity and not skin.set then
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
	-- `set` is here for the same reason and stated separately rather than
	-- leaning on `rarity`: a set skin is priced in MEDALS, so it also has no
	-- `cost`, and a future set item authored without a rarity would fall
	-- straight through to the free branch.
	if skin.rarity or skin.set then
		return owned[key] == true
	end
	return (skin.cost or 0) <= 0 or owned[key] == true
end

-- ============================================================
-- PLOTS
-- ============================================================

-- Two rows of six facing each other across a street, not a solid block.
--
-- The block was quietly unfair: in a 4x3 grid the two interior plots had four
-- adjacent neighbours and the corners had two, so how often you got robbed
-- was decided by what time you happened to log in. Facing rows give every
-- plot the same exposure -- two beside, one across -- and put a full piggy
-- permanently in your eyeline, which is the read the whole game runs on.
-- FOUR A SIDE, AND EIGHT PLAYERS.
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
Config.PLOTS_PER_ROW = 4

-- DERIVED, AND IT HAS TO BE. These were two independent constants, and
-- `plotCFrame` puts row 0 at -z and EVERYTHING ELSE at +z -- so setting the
-- per-row count without the total would have built plots 9..12 silently on
-- top of 5..8, in the same place, with nothing in the log to say so.
Config.PLOT_COUNT = Config.PLOTS_PER_ROW * 2

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

-- Derived the moment its source exists, never before it. See the fence
-- section above for what this is and why it is the slab's own thickness.
Config.LAWN_LIFT = Config.PLOT_SIZE.Y

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
	["hoverboard@crossed"] = "78348588466887",
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
-- The offsets and sizes are measured against the shipped landmark contract
-- rather than chosen: lawn y 0.500, crown y 14.256, width 11.870, tail reach
-- z -7.220. Twelve accessories, the vault dial and the coin pile all measure
-- against those, so they are the thing that must not move.
Config.PIGGY_MESH = {
	{
		part = "Body",
		trim = false,
		id = "82135918153310",
		offset = Vector3.new(0.0000, 7.3223, 0.0488),
		size = Vector3.new(11.8700, 13.6447, 12.0634),
	},
	{
		part = "Ear",
		trim = true,
		id = "104941738279878",
		offset = Vector3.new(-0.0089, 11.8276, 3.7980),
		size = Vector3.new(11.6009, 4.8568, 2.1506),
	},
	{
		part = "Snout",
		trim = true,
		id = "83872101529583",
		offset = Vector3.new(0.0037, 7.0822, 6.3384),
		size = Vector3.new(4.0700, 4.5150, 1.5231),
	},
	{
		part = "Tail",
		trim = true,
		id = "73112501514345",
		offset = Vector3.new(0.0000, 9.7000, -6.0300),
		size = Vector3.new(2.3500, 2.0538, 0.4700),
		-- THE ONLY PART THAT CARRIES A TURN, and it is the difference between
		-- a tail and a screw. The shape is generated lying in its own XY
		-- plane with its LONG axis on X; the turn stands it in the pig's SIDE
		-- plane and points that long axis backward, which is the curl you see
		-- walking past on the pavement rather than edge-on.
		--
		-- IT IS A HOOK RATHER THAN A COIL, AND THAT IS THE SECOND ATTEMPT.
		-- A corkscrew read as a drill bit screwed into the rump; a coil lying
		-- flat down the back read as a spring bolted on. A single smooth bend
		-- is what a cartoon pig tail actually is.
		--
		-- AND IT IS SMOOTH BECAUSE THE PROMPT FOUGHT FOR IT. Two earlier
		-- generations came back as a STRAND OF PEARLS -- a chain of separate
		-- blobs, the exact failure this project already records for the
		-- turtle's headband -- because the generator models a small tube as a
		-- string of spheres. Naming the failure ("no bumps, no balls, no
		-- beads, no segments") and asking at a LARGER size is what produced
		-- one unbroken surface.
		rot = CFrame.Angles(0, math.rad(90), 0),
	},
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
Config.PIGGY_SLOT = {
	width = 0.55,   -- across the pig, the slit's narrow axis
	length = 3.00,  -- along the spine
	floor = 13.25,  -- the bottom of the cut, against a crown of 14.14
}

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
Config.PIGGY_VAULT = {
	radius = 2.10,
	floor = -0.60,
}

-- Nil unless EVERY part has an id, because a partial mesh piggy is worse than
-- none: the body would arrive smooth with the old wedge ears and cylinder
-- snout still stuck to it, which reads as a broken model rather than as an
-- unfinished setting. All or nothing is the honest state.
function Config.piggyMesh(): { any }?
	local out = {}
	for _, entry in ipairs(Config.PIGGY_MESH) do
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

	-- Not generated yet; each falls back to its primitive decorator until it
	-- is. `moat` is deliberately absent rather than blank -- see below.
	rickety = nil,
	barbed = nil,
	electric = nil,
}

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
	local keys = { "dodgeRoll" }
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
-- PIG ACCESSORIES
-- ============================================================
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
	classics = {
		name = "Piggy Classics",
		order = 1,
		kind = "skin",
		currency = "coins",
		cost = 500000,
		odds = { common = 52, rare = 32, epic = 12, legendary = 4 },
		colour = Color3.fromRGB(236, 138, 178),
		blurb = "Every piggy skin the street started with",
	},
	gear = {
		name = "Dress-Up Crate",
		order = 2,
		kind = "accessory",
		currency = "coins",
		cost = 350000,
		odds = { common = 52, rare = 32, epic = 12, legendary = 4 },
		colour = Color3.fromRGB(150, 96, 190),
		blurb = "Hats, glasses, capes and shoes for your piggy",
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
		odds = { common = 52, rare = 32, epic = 12, legendary = 4 },
		colour = Color3.fromRGB(214, 158, 96),
		blurb = "Stripes, spots and fleece. Your piggy, as something else",
	},
	neon = {
		name = "Neon Nights",
		order = 4,
		kind = "skin",
		currency = "coins",
		cost = 500000,
		odds = { common = 52, rare = 32, epic = 12, legendary = 4 },
		colour = Color3.fromRGB(120, 232, 255),
		blurb = "Glow that carries from the far end of the street",
	},
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
Config.COMBINE = {
	need = 3,
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
function Config.isSellable(kind: string, key: string): boolean
	local catalogue = Config.catalogueFor(kind)
	local spec = catalogue and catalogue[key]
	if not spec then
		return false
	end
	if spec.rarity or spec.set or spec.unlockRebirths then
		return true
	end
	return (spec.cost or 0) > 0
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
		-- whole point of that currency.
		if spec.chest == chestKey and not spec.set then
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
Config.ACCESSORY_SLOTS = {
	hat = {
		order = 1, label = "HATS", empty = "Bare head",
		-- Where a hat's BRIM rests. The body is a 6-stud ball centred at y 8.5,
		-- so its top is 14.5; this sits a little into it so no gap opens under
		-- the brim. Every builder in this slot is authored with y=0 there.
		anchors = { Vector3.new(0, 14.15, 0) },
	},
	eyes = {
		order = 2, label = "GLASSES", empty = "No glasses",
		-- Eye height, and far enough forward to clear the eyeballs themselves.
		-- The eyes are balls at (+/-2.35, 10.6, 4.9) whose front faces reach
		-- z 5.53, and the head's surface at that height is z 5.62 -- so a lens
		-- at 5.5 was inside both. Sits 0.28 proud of the head instead.
		anchors = { Vector3.new(0, 10.6, 5.9) },
	},
	back = {
		order = 3, label = "BACKS", empty = "Nothing on the back",
		-- ON the back surface, not inside it. At y 11 the sphere's radius is
		-- 5.45, so z -5.6 sits a hair proud; -5.0 was 0.41 deep, which is why
		-- the jetpack came out of the middle of the pig.
		anchors = { Vector3.new(0, 11.0, -5.6) },
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
	},
}

Config.ACCESSORIES = {
	-- HATS
	cap = {
		chest = "gear",
		name = "Ball Cap", slot = "hat", rarity = "common", order = 1,
		colour = Color3.fromRGB(198, 72, 68), trim = Color3.fromRGB(240, 238, 230),
		blurb = "Worn backwards by absolutely everyone",
	},
	tophat = {
		chest = "gear",
		name = "Top Hat", slot = "hat", rarity = "rare", order = 2,
		colour = Color3.fromRGB(32, 32, 40), trim = Color3.fromRGB(196, 46, 62),
		blurb = "For a pig with a portfolio",
	},
	crown = {
		chest = "gear",
		name = "Gold Crown", slot = "hat", rarity = "epic", order = 3,
		colour = Color3.fromRGB(246, 198, 52), trim = Color3.fromRGB(226, 62, 88),
		blurb = "Rules over one lawn, absolutely",
	},
	halo = {
		chest = "gear",
		name = "Halo", slot = "hat", rarity = "legendary", order = 4,
		colour = Color3.fromRGB(255, 238, 158), trim = Color3.fromRGB(255, 250, 220),
		blurb = "Innocent. Definitely never robbed anybody",
	},

	-- GLASSES
	nerd = {
		chest = "gear",
		name = "Round Specs", slot = "eyes", rarity = "common", order = 5,
		colour = Color3.fromRGB(38, 34, 32), trim = Color3.fromRGB(198, 226, 240),
		blurb = "Has read the whole rulebook",
	},
	shades = {
		chest = "gear",
		name = "Shades", slot = "eyes", rarity = "common", order = 6,
		colour = Color3.fromRGB(24, 24, 28), trim = Color3.fromRGB(52, 58, 72),
		blurb = "Did not see you there. Does not care",
	},
	visor = {
		chest = "gear",
		name = "Cyber Visor", slot = "eyes", rarity = "epic", order = 7,
		colour = Color3.fromRGB(28, 30, 40), trim = Color3.fromRGB(88, 244, 226),
		blurb = "Scanning your piggy bank. Probably",
	},

	-- BACKS
	cape = {
		chest = "gear",
		name = "Hero Cape", slot = "back", rarity = "rare", order = 8,
		-- Puts the collar ON the shoulder surface; the flare does the rest.
		offset = Vector3.new(0, 1.8, 1.1),
		colour = Color3.fromRGB(196, 46, 62), trim = Color3.fromRGB(246, 198, 52),
		blurb = "Billows even indoors",
	},
	jetpack = {
		chest = "gear",
		name = "Jetpack", slot = "back", rarity = "epic", order = 9,
		-- Stands off the back and rides high, clear of the tail ball.
		offset = Vector3.new(0, 1.0, -0.7),
		colour = Color3.fromRGB(188, 190, 198), trim = Color3.fromRGB(255, 146, 58),
		blurb = "Purely decorative. The pig is not going anywhere",
	},
	wings = {
		chest = "gear",
		name = "Angel Wings", slot = "back", rarity = "legendary", order = 10,
		offset = Vector3.new(0, 0.4, -0.3),
		colour = Color3.fromRGB(252, 250, 244), trim = Color3.fromRGB(226, 236, 250),
		blurb = "Suspiciously well earned",
	},

	-- SHOES
	boots = {
		chest = "gear",
		name = "Work Boots", slot = "feet", rarity = "common", order = 11,
		colour = Color3.fromRGB(124, 84, 52), trim = Color3.fromRGB(58, 44, 34),
		blurb = "Four of them. Obviously",
	},
	skates = {
		chest = "gear",
		name = "Roller Skates", slot = "feet", rarity = "rare", order = 12,
		colour = Color3.fromRGB(240, 240, 246), trim = Color3.fromRGB(226, 62, 120),
		blurb = "Does not make the pig any faster",
	},

	-- ALIEN SET, both carrying `set` so neither can ever come out of the coin
	-- accessory roll. Without that an alien hat would be handed to players who
	-- have never seen an invasion, and the set would stop meaning attendance.
	antenna = {
		name = "Antenna Headband", slot = "hat", rarity = "epic", order = 13,
		set = "alien", loot = 12, style = "antenna",
		colour = Color3.fromRGB(64, 72, 92), trim = Color3.fromRGB(96, 255, 176),
	},
	abductor = {
		name = "Abductor Visor", slot = "eyes", rarity = "epic", order = 14,
		set = "alien", loot = 12, style = "abductor",
		colour = Color3.fromRGB(44, 52, 68), trim = Color3.fromRGB(96, 255, 176),
	},
}

-- ============================================================
-- THE ROLL CURRENCY
-- ============================================================
--
-- THE NAME IS A PLACEHOLDER AND IS DELIBERATELY ONE LINE TO CHANGE. What this
-- is finally called has not been decided; what it IS has been. Everything
-- player-facing reads `Config.ROLL_CURRENCY`, so renaming it is this table and
-- nothing else.
--
-- THE SAVE FIELD IS `data.tokens` AND IS HARDCODED ON PURPOSE, exactly as
-- `data.vault` stays `vault` while the HUD says PIGGY BANK. Routing every read
-- through a Config string would buy a rename that nobody needs and cost the
-- type checker, every grep, and the ability to see at a glance who spends it.
-- Renaming the FIELD is a schema migration and should have to look like one.
--
-- EARNED ONLY, AND THE TWO SOURCES ARE THE POINT. Both are attendance: a
-- daily claim, and being on the street when an event resolves. Neither can be
-- hurried with coins, so no amount of money moves the collection along -- which
-- is what takes the roll out of the paid-random-item rule entirely rather than
-- merely inside it. Anything added as a third source has to clear the same
-- bar. See Config.TOKENS for the amounts.
Config.ROLL_CURRENCY = {
	name = "Loot",
	plural = "Loot",
	-- Purple, matching the roll button it is spent on, so the number and the
	-- thing it buys read as one system rather than as two.
	colour = Color3.fromRGB(186, 140, 236),
}

-- Where tokens come from. Both entries are ATTENDANCE and neither scales with
-- how rich or how skilled the player is.
--
-- Event tokens deliberately do NOT pay per drone, which is the one place this
-- table differs in shape from Config.MEDALS. Medals already reward the work of
-- knocking drones down; if tokens did too, a raid that happened to spawn ten
-- would pay out several rolls at once and the pacing would come from how many
-- drones a random event chose rather than from how often somebody turns up.
-- "+1 tokens" is the sort of thing an adult skims past and a nine-year-old
-- reads. One helper rather than a ternary at each of the four sites that
-- format an amount, because the fourth is always the one that gets missed.
function Config.lootWord(n: number): string
	return string.lower(if n == 1 then Config.ROLL_CURRENCY.name
		else Config.ROLL_CURRENCY.plural)
end

-- What a roll costs at `owned` accessories already collected.
--
-- Small integers, because a currency earned one and two at a time has to be
-- countable on a card. Climbs on purpose: the first roll is affordable from a
-- single day-one daily claim so that everybody tries it, and the last is a
-- fortnight of turning up.
--
-- The whole twelve comes to 102 tokens. Against the two sources -- about 17 a
-- week from the daily ladder and roughly 20 from events at two hours a day --
-- that is close to three weeks to finish the collection: slower than either
-- upgrade tree, faster than a stack of rebirths, and paced by ATTENDANCE
-- rather than by whoever has the deepest vault. That was already the intent
-- of the old coin ladder and it was never true of it.
-- One, not two: at one loot per delivery the ladder reads as "how many
-- robberies", and the first roll is the first robbery -- somebody who installs
-- this game today robs a neighbour and rolls an accessory today.
Config.ROLL_BASE_COST = 1
Config.ROLL_GROWTH = 1.25

function Config.getRollCost(owned: number): number
	-- Never below one. A free roll is a button that hands out random items for
	-- nothing, which is a worse shape than an expensive one.
	return math.max(1, math.floor(Config.ROLL_BASE_COST
		* (Config.ROLL_GROWTH ^ math.max(0, owned))))
end

function Config.accessoryCount(): number
	local n = 0
	for _ in pairs(Config.ACCESSORIES) do
		n += 1
	end
	return n
end

-- HOW MANY ACCESSORIES THE ROLL CAN ACTUALLY RETURN, which is NOT how many
-- exist -- and the difference is a real bug the token rework surfaced rather
-- than caused.
--
-- Set accessories are earned by attending events and bought with medals, so
-- `rollFrom` has always excluded them. But the roll's PRICE and its "have you
-- finished" test both counted the whole catalogue, so with two alien items in
-- ACCESSORIES the collection could never read complete from rolling alone: a
-- player who had rolled all twelve was told they had 12 of 14, charged the
-- thirteenth price, and then refused with "Nothing left to roll." It ran the
-- other way too -- buying an alien hat with medals pushed the coin roll's
-- price up a rung, so a set purchase silently made rolling more expensive.
--
-- Both ends now measure the same pool: what a roll can give you.
function Config.rollableAccessoryCount(): number
	local n = 0
	for _, spec in pairs(Config.ACCESSORIES) do
		if not spec.set then
			n += 1
		end
	end
	return n
end

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
-- numbers covering all 324 pairings instead of a per-pair clearance nobody
-- will re-check when the twentieth ornament lands. Measured: widest 13.70
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
	},
}

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
	{ kind = "bone", bone = "steak", count = 2,
		short = "STEAKS", label = "2 Juicy Steaks" },
	-- Day seven is the streak payoff and the reason to come back on day six.
	-- When crates ship this becomes a KEY -- see the plan -- and the Golden
	-- Bone moves to day six.
	{ kind = "golden", seconds = 1800, floor = 5000,
		short = "GOLDEN", label = "Golden Bone + 30 min" },
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
Config.SCHEMA_VERSION = 18

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
function Config.robberyCycleSeconds(steps: number): number
	local run = Config.PLOT_SPACING - Config.STEAL_RANGE - Config.DROPOFF_RADIUS
	local approach = run / Config.BASE_WALK_SPEED
	local getaway = run / (Config.BASE_WALK_SPEED * Config.CARRY_SPEED_MULTIPLIER)
	local crack = Config.CRACK.openHold + steps * Config.CRACK.sweepSeconds
	return approach + crack + getaway
end

-- Coins an hour from cycling residents at `incomeLevel` and `rebirths`,
-- against coins an hour from doing nothing at all. Both are returned so a
-- caller can print them rather than only their quotient.
--
-- A resident is seated at the AVERAGE income level of the humans in the
-- server, so a solo player robs a peer -- which is the case this measures, and
-- `pigSeconds` then cancels the rate out of the ratio entirely. THAT
-- CANCELLATION IS THE INVARIANT, and computing it the long way here rather
-- than asserting it is what lets the spread check see it break.
function Config.robberyRates(incomeLevel: number, rebirths: number, spreeSteps: number?): (number, number)
	local rate = Config.getIncomeRate(incomeLevel, rebirths)
	local pig = Config.RESIDENTS.pigSeconds * rate
	local payout = Config.HEIST_PAYOUT * Config.getSpreePayout(spreeSteps or 0)
	local haul = pig * Config.getCrackTotal(0) * payout
	local cycle = Config.robberyCycleSeconds(Config.CRACK.maxSteps)
	return haul * (3600 / cycle), rate * 3600
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

	-- A THIEF MAY NOT LAP THE STREET FASTER THAN THE COOLDOWN, or every figure
	-- above is optimistic by however far they overshoot. `STEAL_COOLDOWN` is
	-- per victim, so a thief working every resident in turn is held up by
	-- whichever of the two is slower, and this model only holds while that is
	-- the lap. Note it tightens as the street gets SHORTER or the crack gets
	-- QUICKER, so it is exactly the kind of thing a good local retune breaks.
	local residents = Config.PLOT_COUNT - 1
	local lap = residents * Config.robberyCycleSeconds(Config.CRACK.maxSteps)
	if lap < Config.STEAL_COOLDOWN then
		table.insert(problems, ("%d residents lap in %.1fs against a %ds STEAL_COOLDOWN: "):format(
			residents, lap, Config.STEAL_COOLDOWN)
			.. "a thief runs out of targets, so the advantage measured above is optimistic")
	end

	return problems
end


return Config
