--!strict
--[[
	Remotes

	Single place where every client/server channel is declared, so there's
	one list to audit when checking what a client is allowed to ask for.

	The server creates the instances; the client waits for them. Any new
	remote goes in DEFINITIONS and nowhere else.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS = {
	-- Client asks to buy an upgrade: ("income"). "capacity" was the other
	-- track and is retired with the pig's ceiling; the server ignores it.
	PurchaseRequest = "RemoteEvent",

	-- Server pushes the authoritative snapshot of a player's own state.
	StateUpdate = "RemoteEvent",

	-- Server tells a client something worth a toast ("Banked 4,210 coins").
	Notify = "RemoteEvent",

	-- How much loot the player is currently carrying (0 when empty-handed),
	-- what is in the haul, and whether they are standing close enough to
	-- the selected home/victim drop-off to settle it.
	--
	-- THE RANGE FLAG RIDES THIS PUSH RATHER THAN A CHANNEL OF ITS OWN, and
	-- rather than being worked out on the client. It is the same argument the
	-- haul list makes one line up: the server already polls every carrier
	-- four times a second to answer exactly this question, and it is the side
	-- that has to answer it anyway, because arriving is
	-- the delivery and is settled there. A client computing its own distance would be a second
	-- implementation of the one number that decides whether a robbery pays.
	-- Trailing options: action (keep/return), canKeep/canReturn, victim,
	-- ownReturn, keepWorth and bounty; clients show both named destinations.
	CarryUpdate = "RemoteEvent",

	-- Private recovery objectives; client sends an empty subscribe request.
	-- No client claim, timer or price is accepted.
	RecoveryObjective = "RemoteEvent",

	-- Server tells ONE thief that one victim is on cooldown for them, as
	-- (victimUserId, expiresAtServerTime). Fired on a completed grab and on
	-- nothing else, because a completed grab is the only thing that starts one.
	--
	-- Per client, because this cooldown is per THIEF per victim: two players
	-- standing at the same piggy can genuinely disagree about whether it can be
	-- robbed, so there is no shared answer to broadcast.
	StealCooldown = "RemoteEvent",

	-- Client asks to buy a defence or offence upgrade, by key.
	UpgradeRequest = "RemoteEvent",
	-- Server pushes the player's upgrade levels, costs and caps.
	UpgradeState = "RemoteEvent",

	-- Client asks to rebirth; server pushes rebirth count and readiness.
	RebirthRequest = "RemoteEvent",
	RebirthState = "RemoteEvent",

	-- Sent only to a robbery's victim: which plot to go and hit back.
	RevengeMarker = "RemoteEvent",

	-- The session arc, pushed per player: their own rap sheet, the floor it
	-- has to clear before a patrol comes looking, and who is leading the
	-- board.
	--
	-- PER CLIENT RATHER THAN BROADCAST, because two of the four fields are
	-- about the RECIPIENT and not about the street -- the same reason
	-- `StealCooldown` is per client. A thief's floor is seconds of their OWN
	-- income, so two players standing side by side genuinely have different
	-- ones, and there is no shared answer to broadcast.
	WantedState = "RemoteEvent",

	-- Client buys or equips a skin/effect; server pushes the collection.
	CosmeticRequest = "RemoteEvent",
	CosmeticState = "RemoteEvent",

	-- Client buys a bone; server pushes how many of each the player holds.
	GearRequest = "RemoteEvent",
	GearState = "RemoteEvent",

	-- Client asks to draw an item, or to put one away with nil. THE KEY AND
	-- NOTHING ELSE, like every other request on this bar: the server checks
	-- the stock, decides, welds the prop and publishes what it decided on the
	-- character. Selecting spends nothing, so there is nothing here to forge
	-- that is worth forging -- but it is validated anyway, because what a
	-- player is holding is a TELL other players act on.
	-- Server says a shop door was used, and which TAB it sells. A door is
	-- built at server startup, so a client cannot reliably find one itself --
	-- see the note in ShopFront. Carries a name, never an index: tab order is
	-- a fact about ClientMain's rail.
	ShopDoor = "RemoteEvent",

	EquipRequest = "RemoteEvent",

	-- Client asks to throw a bone. It sends the BONE KEY AND NOTHING ELSE --
	-- no position, no target. The server picks the dog from its own
	-- authoritative positions, so there is no coordinate here to forge.
	BoneThrow = "RemoteEvent",

	-- Client asks to dodge. Carries NOTHING -- not even a direction: the
	-- server rolls you along your own movement by raising WalkSpeed, so there
	-- is no vector here to forge into a longer one.
	DodgeRequest = "RemoteEvent",
	DodgeState = "RemoteEvent",

	-- Client asks to start or stop tiptoeing. Carries ONE BOOLEAN and nothing
	-- else -- no speed, no multiplier. What a tiptoe is worth is decided by
	-- `Config.TIPTOE` on the server and applied inside `currentSpeed`, so
	-- there is no number here to forge into a faster sneak.
	--
	-- The server also refuses it outright while carrying loot, which is what
	-- keeps the ordering that makes the whole mechanic safe: a tiptoe is
	-- always below a guard dog's `notice` and a carry is always above it, so
	-- you can sneak IN and you can never sneak the money OUT.
	TiptoeRequest = "RemoteEvent",
	-- Server tells one client whether it is actually tiptoeing, because the
	-- server can refuse or drop it (a grab, a ride, a stun) and a button that
	-- says ON while the character is walking normally is the client lying
	-- about state it does not own.
	TiptoeState = "RemoteEvent",

	-- THE CRACK. Four channels, and the split between them is the whole of
	-- what keeps a timing minigame server-authoritative.
	--
	-- `CrackState` is the server describing the attempt: which pig, what is
	-- in it, what each remaining slice is worth, where the zone sits on the
	-- dial and WHEN the sweep began, stamped in `workspace:GetServerTimeNow`
	-- so both ends read one clock. It is fired again after every landed
	-- slice, and with nil to close the panel.
	--
	-- `CrackTap` CARRIES NOTHING AT ALL, which is the load-bearing half. The
	-- obvious build has the client say "I hit it" or send the marker position
	-- it saw, and both are a claim about money that the client got to make.
	-- An empty tap is the same decision `BoneThrow` and `placeLadder` already
	-- record: the click means "now", never "now, and here is the outcome".
	-- The server reads its own clock at the moment the tap arrives, works out
	-- where the marker really is, and decides.
	--
	-- `CrackStop` is the player walking away with what they have banked --
	-- the push-your-luck half, and the only input in this game whose whole
	-- purpose is to stop early.
	CrackState = "RemoteEvent",
	RobberyLoot = "RemoteEvent", -- server-selected discovery; presentation only
	CrackTap = "RemoteEvent",
	CrackStop = "RemoteEvent",

	-- WHAT A DELIVERY WAS WORTH, sent to the thief the moment it lands.
	--
	-- The delivery has always fired a `Notify` -- one line of text, six
	-- seconds, gone -- for the single biggest payoff moment in the game. That
	-- was fine while a delivery was only ever coins. It is not fine now that
	-- a robbery can carry a COSMETIC home: an item arriving in a save with a
	-- sentence about it in a toast is the reward equivalent of a receipt.
	--
	-- A SECOND CHANNEL RATHER THAN A RICHER TOAST, because the two are
	-- different objects. `Notify` is a stack of things that just happened and
	-- is deliberately transient; this is one summary of one event, it wants
	-- to animate, and it wants to be able to send you somewhere (the bag).
	-- The toast survives alongside it for the reason the arrest scene's does:
	-- the summary is the part that could fail to build, and a payout the
	-- player cannot see is indistinguishable from a broken feature.
	HeistDelivered = "RemoteEvent",

	-- Sent to ONE player: they have just been arrested, and this carries the
	-- numbers their mugshot card needs. Targeted rather than broadcast
	-- because a mugshot is yours -- the street already saw the arrest happen.
	PoliceBust = "RemoteEvent",

	-- Server broadcasts the patrol's phase to EVERY client: the phase name
	-- and how many seconds are left of it. Broadcast rather than targeted
	-- because a patrol is a fact about the street, not about a player -- the
	-- whole point is that everyone can see it coming and decide.
	--
	-- No positions. The car is a real model that replicates itself; this
	-- carries only what the HUD counts down.
	PoliceState = "RemoteEvent",

	-- Client buys, or uses, a thief consumable. StealthUse carries a key and
	-- NO target: both of these act on the caller and nobody else.
	StealthRequest = "RemoteEvent",
	StealthUse = "RemoteEvent",
	StealthState = "RemoteEvent",
	-- A hider climbing out of a wheelie bin (jump, tap, or a fresh push).
	-- Carries at most a DIRECTION, which the server flattens, validates and
	-- falls back from; never a position. See StealthService.
	BinClimbOut = "RemoteEvent",

	-- Client buys, or uses, an item on their OWN plot. HomeUse carries a key
	-- and NO target: the server acts on the caller's own plot or on nothing,
	-- so there is no player here that could be named.
	HomeRequest = "RemoteEvent",
	HomeUse = "RemoteEvent",
	HomeState = "RemoteEvent",

	-- Client buys a gadget; server pushes how many of each they hold.
	GadgetRequest = "RemoteEvent",
	GadgetState = "RemoteEvent",

	-- Client asks to throw a gadget, and sends a KEY AND AN AIM DIRECTION.
	--
	-- IT USED TO SEND THE KEY AND NOTHING ELSE, like BoneThrow still does,
	-- and the note here said the server picked the target itself so there
	-- was "no position to forge, no range check to defeat, and no way to
	-- name a victim". A gadget is aimed now, and once the throw acquired a
	-- DROP the aim had to carry pitch -- which a Roblox character cannot
	-- express, so there was nothing on the server to read it from.
	--
	-- WHAT THE OLD RULE PROTECTED SURVIVES, AND IT IS WORTH BEING EXACT.
	-- A direction is not a position. The server still owns the origin (its
	-- own copy of the root), the speed, the gravity, the horizontal range
	-- cap, the hit radius and every step of the simulation, and
	-- `Config.throwClampDirection` is the single gate every aim passes
	-- through. Forging a direction lets a client aim wherever it likes,
	-- which is the feature; at best it buys a perfect lead-and-drop every
	-- time, which is also what a good player gets, on an item that costs
	-- coins per throw and only slows somebody down. The same argument this
	-- file's crack already makes: there is no jackpot here to protect.
	--
	-- A nil or malformed direction is not an error. The server falls back to
	-- the thrower's own facing, which is a legal flat throw.
	GadgetThrow = "RemoteEvent",

	-- Client starts (true) or abandons (false) cocking the gadget it holds.
	-- Carries a boolean and nothing else. It exists so the wind-up can be
	-- HELD and seen by everybody, and so the server can time the release
	-- from when the arm actually went back -- see Shared/ThrowPose.
	GadgetCock = "RemoteEvent",

	-- Server tells every client a gadget has left a hand: who, what, from
	-- where, with what velocity, at what server time, under what id. Each
	-- client flies its OWN copy along `Config.throwPointAt` -- a projectile
	-- the server moves every frame replicates in lurches. `GadgetFlightEnd`
	-- (id, position) stops every copy where the server's real one stopped.
	-- Presentation only: the server alone decides what it hit.
	GadgetFlight = "RemoteEvent",
	GadgetFlightEnd = "RemoteEvent",

	-- Server tells every client the zapper fired: who, from where, to where.
	-- Each client draws the arc. Presentation only.
	GadgetZap = "RemoteEvent",

	-- Server tells ONE client they were knocked down by a gadget: which way
	-- (horizontal), for how long, and how hard. The client plays the fall,
	-- because a server write to a player's velocity is discarded -- the same
	-- split as `FenceKnockback`. The stun itself is already server-side.
	GadgetKnock = "RemoteEvent",

	-- Client buys or puts away a ride; server pushes what they own and
	-- whether they are on one right now. There is no "mount" request: getting
	-- on is decided by the server from where the player is standing, so there
	-- is no message here that could ask to be riding somewhere they may not.
	RideRequest = "RemoteEvent",
	RideState = "RemoteEvent",

	-- Client holds or releases the trick button: a manual on the board, a
	-- wheelie on the bike. Carries a boolean and nothing else -- the server
	-- knows what they are riding and whether that ride has a trick at all.
	RideTrick = "RemoteEvent",

	-- How the rider sits on a ride they already own. Cosmetic only: it writes
	-- no speed and no gate, so it is separate from RideRequest -- which is a
	-- TOGGLE, and would have put the ride away every time somebody changed
	-- how they sat on it.
	RideStance = "RemoteEvent",

	-- Client asks to claim today's daily reward. It sends NOTHING -- which
	-- day it is, and which rung of the ladder that is worth, are both read
	-- from the server's own clock and the server's own save.
	DailyRequest = "RemoteEvent",
	DailyState = "RemoteEvent",
	-- Opens the daily board on one client. Server to client only, and it
	-- carries nothing: the board is already rendered from `DailyState`, so
	-- this is the mailbox saying "look at what you already have" rather
	-- than a second copy of the state.
	DailyOpen = "RemoteEvent",

	-- Client activates a boost it already holds, by key. Acts on the caller
	-- and nobody else, like the other consumable uses.
	BoostUse = "RemoteEvent",

	-- Client asks to change one of ITS OWN preferences, by key and value; the
	-- server pushes the whole settings table back. The key is checked against
	-- an allowlist server-side before anything is written -- a client naming
	-- a field in its own save is exactly how a save gets arbitrary junk in it.
	SettingRequest = "RemoteEvent",
	SettingState = "RemoteEvent",

	-- Server broadcasts the current session event to EVERY client: which one,
	-- what phase, and how many seconds are left of it. Broadcast rather than
	-- targeted for exactly the reason PoliceState is -- an event is a fact
	-- about the street, not about a player, and the whole point is that
	-- everybody can see it coming and decide what to do.
	--
	-- No positions and no targets. The saucer and its drones are real models
	-- that replicate themselves; this carries only what the HUD counts down.
	EventState = "RemoteEvent",

	-- Server tells ONE player they have won a set item from an event, and
	-- carries the pool and the odds it was drawn from so the client can show
	-- an honest wheel. Targeted, not broadcast: a drop is yours.
	--
	-- THE SERVER PICKS THE WINNER AND THE CLIENT ONLY ANIMATES LANDING ON IT.
	-- The pool is sent so the wheel has slices to draw and percentages to
	-- print, never so the client can choose -- a client that decided its own
	-- prize is a client that decided its own prize.
	EventDrop = "RemoteEvent",

	-- THERE IS NO `LootBuy`. It bought a set item with the retired second
	-- currency; the Alien Cache is the route to one now.

	-- Server pushes every set's contents and progress.
	SetState = "RemoteEvent",

	-- Admin console. Every request is re-authorised server-side against the
	-- allowlist; the existence of this channel grants nobody anything.
	AdminRequest = "RemoteEvent",

	-- THERE IS NO `ChestOpen`. A crate is earned rather than bought, so no
	-- client channel opens one: `ChestService.grantFree` is reached from the
	-- daily ladder, a rebirth and events and from nowhere on the wire.
	--
	-- Buy back one claimed skin; only the skin key crosses the wire.
	SkinBuyback = "RemoteEvent",

	-- Client asks to spend three spares of a tier. Carries the tier and the
	-- chest to roll in, and OPTIONALLY the three entries to consume -- both
	-- lists are checked server-side against the real catalogues and the
	-- player's own spares, because a client naming a field is how a save gets
	-- arbitrary keys in it. Omit the entries and the server picks.
	ChestCombine = "RemoteEvent",

	-- Client asks to sell spare copies. Carries "kind:key" and a count, and
	-- NEITHER A PRICE NOR A CURRENCY: the server re-derives what the thing is
	-- worth from Config.sellValue. The
	-- one thing a client could usefully forge here would be the payout, so it
	-- is not on the wire.
	SpareSell = "RemoteEvent",

	-- Server tells ONE client what a chest gave them, and the odds it actually
	-- used -- renormalised over the tiers that had stock, so the reel prints
	-- the numbers the roll was really made with rather than the table's.
	ChestResult = "RemoteEvent",

	-- Server pushes every stocked chest, what it costs, what the player owns of
	-- it, and every spare they hold with what each one is worth sold.
	ChestState = "RemoteEvent",

	-- THE COMBINE MACHINE ON THE VERGE (designer, 2026-09-23): the combine
	-- moved out of the shop and onto a machine you walk up to.
	--
	-- Server -> ONE client, when that player finishes the hold on the
	-- station's prompt. IT CARRIES NOTHING, the same call `BoneThrow`,
	-- `placeLadder` and `CrackTap` all make: the hold means "open it", never
	-- "open it with this in it". Everything the panel draws is already on the
	-- client in `ChestState`, which is the server's own arithmetic -- so
	-- there is no second copy of a spare count to go stale, and nothing on
	-- this wire to forge.
	CombineOpen = "RemoteEvent",

	-- Server -> ONE client: what is in THAT PLAYER'S press hopper.
	--
	-- PER PLAYER AND NEVER BROADCAST, which is the whole reason the hopper
	-- is a save field rather than a table in `CombineService` (designer,
	-- 2026-09-23: "it should be a player store not a server store"). Two
	-- players at one press have two hoppers and cannot see or spend each
	-- other's, so the machine needs no queue, no lock and no owner -- the
	-- shared thing is the MODEL, and the state is in each player's save.
	-- Same split the crack panel already makes on a shared piggy.
	--
	-- It carries counts and the piggy KEYS, because the panel answers "what
	-- did I put in" and a bare count cannot.
	PressState = "RemoteEvent",

	-- Client -> server: combine, as (kind, chestKey, tier, entries?).
	--
	-- NO PRICE AND NO OUTCOME ON THE WIRE. The inputs ARE the price, the
	-- server re-counts them against the save, and `ChestService.combine`
	-- rolls the climb on `Config.COMBINE.odds` -- so the best a forged
	-- payload can name is a combine the player could already have asked for
	-- through the machine's own panel. `entries` is optional and is rebuilt
	-- from known-good parts by `validatePick` before a single spare moves.
	CombineRequest = "RemoteEvent",

	-- Server tells ONE client to bounce itself off a trampoline. It carries
	-- NOTHING -- not a height, not a direction: the server has already decided
	-- that this player, on this mat, is allowed to bounce, and the height is a
	-- Config constant both sides read.
	--
	-- IT HAS TO BE THE CLIENT THAT APPLIES IT, and that is measured rather than
	-- assumed. A character's physics are owned by its own client, so the
	-- server writing AssemblyLinearVelocity on somebody's HumanoidRootPart is
	-- discarded -- tested three ways on a live rig (raw write, and with
	-- ChangeState to Jumping and to Freefall first) and the character reached
	-- exactly its drop height, 5.00 studs, on all three. Same split as the
	-- dodge, where the server decides and the client drives.
	TrampolineBounce = "RemoteEvent",

	-- Server -> client. Carries the direction to throw somebody who has just
	-- been shocked off a fence, for the same reason TrampolineBounce carries
	-- nothing: a server-side write to a player's AssemblyLinearVelocity is
	-- discarded, because the client owns its own physics.
	--
	-- It carries a direction where the trampoline does not, and that is safe
	-- for the one reason that matters: the SERVER computes it. The client is
	-- being told which way it was thrown, not asked. See PlotService's
	-- firePenalty, which rejects a climber to whichever side of the fence
	-- they were already on so it can never carry anybody across.
	FenceKnockback = "RemoteEvent",
	-- A guard dog throwing a caught thief out of its yard. Carries the LANDING
	-- point, computed by the server; the client only flies the arc there,
	-- because a server write to a player's velocity or CFrame mid-flight is
	-- fought by the client that owns the physics. The server teleports anybody
	-- still inside the yard afterwards, so the client cannot opt out.
	DogKnockout = "RemoteEvent",
	-- Server tells ONE player to cover the screen: they have just walked
	-- through a front door. Carries a WAY ("in" or "out") and nothing else --
	-- not a position, not a destination, not a room.
	--
	-- THE CLIENT DRAWS THE COVER AND THE SERVER MAKES THE MOVE, which is the
	-- opposite split from the trampoline and for the opposite reason. There
	-- the server cannot write a character's velocity, so the client applies
	-- it; here the server CAN write a character's CFrame and must, because an
	-- interior is a real place and where somebody is standing is not a thing
	-- a client gets to claim. All this channel buys is that the screen is
	-- black before the world changes.
	--
	-- Timed from `Config.HOUSE_DOOR`, which both ends read: the server waits
	-- `maskLead` before teleporting and the client holds and fades on the two
	-- numbers beside it, so the cover cannot drift off either side of the move
	-- it exists to hide.
	DoorCross = "RemoteEvent",

	-- A PACK IS DROPPING (designer, 2026-09-23: "a banner saying PIGGIES
	-- INCOMING! ... big funky text at the top of the screen"). Fired to
	-- every client when `HerdService` releases a batch or the boot wave, with
	-- `{ id, count, zone }`; `Shared/DropBanner` shows the splash. It
	-- replaced the OBSERVER toast rather than joining it: two announcements
	-- of one drop is noise, and the neon shaft on the spot is the half that
	-- says WHERE.
	HerdDrop = "RemoteEvent",

	-- THE LASSO (docs/LASSO-PLAN.md; numbers in `Config.LASSO`).
	--
	-- `LassoThrow(targetId)`: the client's lock-on names a piggy by its
	-- `Config.LASSO_TARGET_ATTRIBUTE` id and NOTHING ELSE -- no position, no
	-- tier, no chance. The server reads which lasso is in hand from
	-- `HeldItemService`, re-checks range, state and room, and refuses before
	-- anything is spent. A target id is safe to accept because it only picks
	-- WHICH valid piggy; everything about whether it may be thrown at is
	-- decided server-side.
	LassoThrow = "RemoteEvent",
	-- `LassoTap()` carries nothing, like `CrackTap`: the server counts it
	-- against its own clock and caps the rate at `Config.LASSO.tapRate`.
	LassoTap = "RemoteEvent",
	-- Server -> every client: `{ id, thrower (UserId), key, rarity, phase,
	-- startedAt, endsAt }`, phase one of "flight", "struggle", "caught",
	-- "snapped". Everybody draws the rope; only the thrower gets the TAP bar.
	LassoState = "RemoteEvent",
	-- Server -> one client: `{ stock = { [key] = n }, prices = { [key] =
	-- coins or nil }, rebirths = n, elite = { allowed = bool, productId = n }
	-- }`. Prices are the server's own `Config.lassoPrice` for THIS player.
	LassoStock = "RemoteEvent",
	-- `LassoBuy(key, count?)`: a coin lasso. The Elite tier is bought through
	-- `ProductService`, never here.
	LassoBuy = "RemoteEvent",

	-- (THE STREET LEADERBOARD had a channel here and does not need one: it is
	-- Roblox's own player list now, and `leaderstats` replicates itself. See
	-- `LobbyBoardService`.)

	AdminState = "RemoteEvent",
}

local Remotes = {}

local folder: Folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for name, className in pairs(DEFINITIONS) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.get(name: string): RemoteEvent
	assert(DEFINITIONS[name], ("Unknown remote '%s' -- add it to Remotes.DEFINITIONS"):format(name))
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
