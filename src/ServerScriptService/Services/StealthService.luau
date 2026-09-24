--!strict
--[[
	StealthService

	The thief's one consumable -- the Raincoat -- and the public wheelie bins
	a player can climb into.

	THE DISGUISE KIT IS GONE. It had never worked: its `prop` named "bins",
	which is not a key in Config.DECOR_ITEMS, so Decor.buildOne returned nil
	and conceal refused SILENTLY -- a 4,000-coin item that did nothing and
	said nothing about it. What it was selling is delivered properly by the
	kerbside bins below, which are a real feature with a real prompt, so the
	consumable was a second, broken route to the same fantasy.

	These exist because the offence tree was left behind. Gadgets closed the
	maxed-boots hole and the Guard Duty Treat closed the cheap-bone hole, and
	both landed with nothing given back to the people they were aimed at.

	THE DISGUISE HIDES THE WAIT, NEVER THE GETAWAY.

	Worth being honest about what it is for. The guard dog does not watch an
	approach: GuardDog.chase only fires from HeistService.attemptSteal, after a
	completed steal. Walking up to somebody's piggy was never dangerous, so a
	sneaking tool would have been solving a problem this game does not have.

	It is a WAITING tool. You stand on a lawn as a wheelie bin while a vault
	fills, or while a sixty-second steal cooldown runs out, or through six
	minutes of guard duty until the collar stops glowing. That last one is the
	good one: it puts the treat and the disguise in an argument with each other
	rather than adding a number to either side.

	Two rules hold it in place, and the first is why it needs no timer worth
	tuning:

	  * STANDING STILL IS THE DISGUISE. Drift more than a few studs and it
	    drops. That is self-limiting by construction -- it cannot help you run
	    anywhere, because running is what ends it.
	  * IT BREAKS THE INSTANT LOOT IS PICKED UP. No exception, no grace. The
	    run home is the risk half of the entire trade and has to stay visible,
	    and a thief who could carry a piggy while looking like a bin would end
	    the chase before it started.

	It survives the LOCK HOLD on purpose, which is the joke: a wheelie bin
	quietly cracking somebody's piggy is worth four thousand coins on its own.
	The hold does not move you, so nothing special is needed to allow it.

	THE RAINCOAT MIRRORS THE GUARD DUTY TREAT.

	The two cheap gadgets slide off; the Zapper still lands. Same shape as the
	treat on the other side of the fight -- cheap counters bounce, the
	expensive one gets through -- and it does the same job, raising the price
	of stopping somebody from 1,500 to 22,000 rather than making them
	unstoppable.

	Neither of these touches SPEED, which stays capped at 16.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local HeldItemService = require(script.Parent.HeldItemService)
local HeistService = require(script.Parent.HeistService)
-- PlotService owns the fence, so it owns where a ladder can stand. No cycle:
-- it requires PiggyBank, GuardDog, House, Decor and ThiefModel, and none of
-- those reaches back here.
local PlotService = require(script.Parent.PlotService)
local Decor = require(ReplicatedStorage.Shared.Decor)

local StealthService = {}

type Hidden = {
	-- A public wheelie bin, which the game built and this service only
	-- borrows. There used to be a second route in here -- an ornament `prop`
	-- built per player by the Disguise Kit -- and it went with the item.
	bin: Model?,
	-- The character this hide belongs to. A respawn hands the player a NEW
	-- one, and everything else here -- the transparency list, the anchored
	-- root -- points at the old one. Comparing against it is a guard that
	-- depends on no signal firing, which is the point: see step().
	character: Model?,
	anchor: Vector3,
	until_: number,
	-- When the occupant is allowed to climb out (jump or push). See
	-- Config.BINS.settleSeconds: entry is instant, so the commitment lives
	-- here instead.
	canExitAt: number,
	-- WHICH WAY THEY WERE FACING WHEN THEY GOT IN, and it has to be captured
	-- because entering DESTROYS it: the root is seated with
	-- `CFrame.new(hatch.Position)`, which carries an identity rotation, so by
	-- the time anybody asks, every hider in the game is facing world +Z.
	--
	-- That was invisible while the exit was a move input -- a direction was
	-- always supplied, so the fallback never ran. With a button it is the
	-- common case, and without this a player pressing CLIMB OUT with no key
	-- held would pop out northward whichever side of the street they were on.
	facing: Vector3,
	hiddenParts: { { part: BasePart, transparency: number } },
	nameMode: Enum.HumanoidDisplayDistanceType?,
}

local hidden: { [Player]: Hidden } = {}

-- ============================================================
-- WHEELIE BINS
-- ============================================================
--
-- See the note over Config.BINS for why this replaced disguising AS an
-- ornament. The short version: a hiding PLACE needs no plausibility argument,
-- and a bin the game built on the kerb is always in the right zone and always
-- facing the right way.
--
-- The bins themselves belong to NeighborhoodService, with the road and the
-- lamp posts. This module owns only who is inside one.
local BIN_TAG = "HideBin"

type Lid = { part: BasePart, rest: CFrame, open: CFrame }
type Bin = {
	model: Model, hatch: BasePart, enter: ProximityPrompt, open: ProximityPrompt,
	lids: { Lid },
}

local bins: { [Model]: Bin } = {}
local binOf: { [Player]: Model } = {}
local occupant: { [Model]: Player } = {}

-- One bin per pursuit, kept on the PLAYER. See Config.BINS.cooldown.
local binReadyAt: { [Player]: number } = {}

-- THE LID IS THE ONLY PART OF THIS ANYBODY ELSE CAN SEE.
--
-- A hider is invisible and a vault out is over in a fifth of a second, so
-- without this a bin swallows and spits out players with no more animation
-- than a light switch. The lid flying up is what says a bin is a thing you
-- can be inside.
--
-- Thrown open fast and dropped shut slowly, because that is the order those
-- two things happen in: a symmetrical swing reads as a hatch opening rather
-- than as somebody bursting through it. Back easing on the way up overshoots
-- slightly, which is the whole of the effect.
--
-- Anchored parts, tweened on the SERVER, so every peer sees the same lid --
-- and it is two parts for a fraction of a second, not a per-frame write.
local function flapLid(bin: Bin)
	for _, lid in ipairs(bin.lids) do
		if lid.part.Parent then
			TweenService:Create(lid.part,
				TweenInfo.new(Config.BINS.lidOpen, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ CFrame = lid.open }):Play()
		end
	end
	task.delay(Config.BINS.lidOpen + 0.05, function()
		for _, lid in ipairs(bin.lids) do
			if lid.part.Parent then
				-- Always back to the REST CFrame that was recorded when the
				-- bin was wired, never by reversing whatever tween is running.
				-- Two hides in quick succession would otherwise leave a lid
				-- parked half open with nothing to put it back.
				TweenService:Create(lid.part,
					TweenInfo.new(Config.BINS.lidShut, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
					{ CFrame = lid.rest }):Play()
			end
		end
	end)
end

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

-- Shared with bones, gadgets and home items. Same reasoning every time: these
-- are things you hold a stock of and spend, the keys cannot collide, and
-- sharing means they inherit the rebirth rule for free.
local function stock(data: any): { [string]: number }
	if type(data.consumables) ~= "table" then
		data.consumables = {}
	end
	return data.consumables
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- ============================================================
-- THE DISGUISE
-- ============================================================

local function reveal(player: Player, why: string?)
	local state = hidden[player]
	if not state then
		return
	end
	hidden[player] = nil

	-- A prop was built for this player and is theirs to destroy. A bin was
	-- not: it is street furniture and outlives every hider, so it is only
	-- released.
	HeistService.setHidden(player, false)
	if state.bin then
		occupant[state.bin] = nil
		binOf[player] = nil
		local bin = bins[state.bin]
		if bin then
			bin.enter.Enabled = true
			bin.open.Enabled = false
			-- The deny half of the OPEN split goes back with it. Released HERE
			-- rather than in `exitBin`, because this is the one choke point
			-- every ending passes through -- jumping out, pushing out, being
			-- tipped out, the two-minute ceiling, dying in there, and quitting
			-- from inside.
			bin.open:SetAttribute(Config.PROMPT_DENY_OWNER_ATTRIBUTE, nil)
		end
		binReadyAt[player] = os.clock() + Config.BINS.cooldown
	end

	-- Restore the recorded value rather than setting 0. Some of what gets
	-- hidden was already partly transparent -- a jetpack's exhaust, a cape's
	-- cloth -- and forcing everything opaque would repaint accessories the
	-- player bought.
	for _, entry in ipairs(state.hiddenParts) do
		if entry.part.Parent then
			entry.part.Transparency = entry.transparency
		end
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and state.nameMode then
		humanoid.DisplayDistanceType = state.nameMode
	end

	-- Held still by the ROOT rather than by WalkSpeed, because WalkSpeed 0 is
	-- what the police stun uses and this must not be confused with it -- and
	-- because a stunned player still slides, where somebody inside a bin has
	-- to stay in the bin. Anchoring on the server replicates; on the client it
	-- famously does not.
	local root = getRoot(player)
	if root and state.bin then
		root.Anchored = false
	end

	if why then
		notify(player, why, "warn")
	end
	StealthService.push(player)
end


-- Hides a character and returns what has to be restored later. Shared by the
-- ornament disguise and the bin, because "make this player invisible" is the
-- same job either way and doing it twice is how the two would drift.
local function hideCharacter(player: Player): ({ { part: any, transparency: number } }, Enum.HumanoidDisplayDistanceType?)
	local character = player.Character
	local hiddenParts = {}
	if not character then
		return hiddenParts, nil
	end

	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(hiddenParts, { part = d, transparency = d.Transparency })
			d.Transparency = 1
		elseif d:IsA("Decal") then
			table.insert(hiddenParts, { part = d :: any, transparency = d.Transparency })
			d.Transparency = 1
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local nameMode = humanoid and humanoid.DisplayDistanceType
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return hiddenParts, nameMode
end

local function enterBin(player: Player, model: Model): boolean
	local bin = bins[model]
	local root = getRoot(player)
	local character = player.Character
	if not bin or not root or not character then
		return false
	end

	if hidden[player] then
		notify(player, "You're already hidden.", "warn")
		return false
	end
	if occupant[model] then
		notify(player, "Someone's already in there!", "warn")
		return false
	end

	-- Named, because a prompt that completes and does nothing is
	-- indistinguishable from a broken one -- and this is the rule a player is
	-- most likely to meet without being told it exists.
	local ready = binReadyAt[player]
	if ready and os.clock() < ready then
		notify(player, ("Catch your breath first: %ds."):format(
			math.ceil(ready - os.clock())), "warn")
		return false
	end

	-- The lid goes on the way IN as well. It is the same event from the
	-- street's point of view -- a bin that just did something -- and without
	-- it a player simply vanishes where they stood, which is the half of this
	-- a pursuer is actually looking at.
	flapLid(bin)

	-- THE PROP GOES AWAY BEFORE THE CHARACTER DOES, which is the same trap
	-- the rides hit from the other side. `hideCharacter` walks the descendants
	-- ONCE, so anything attached afterwards is not on its list -- a bone drawn
	-- inside a bin would hang in the air over the lid. Putting it away here
	-- means there is nothing to hide and nothing to restore, and the veto in
	-- `Main` is what stops one being drawn while the lid is shut.
	HeldItemService.putAway(player)

	local hiddenParts, nameMode = hideCharacter(player)

	-- READ BEFORE THE SEAT BELOW OVERWRITES IT. See `Hidden.facing`.
	local facing = root.CFrame.LookVector

	-- Parked AT the bin and anchored there. Being inside has to be spatially
	-- true, not just visually: a pursuer converging on the bin is converging
	-- on the player, and the catch radius has to agree with the picture.
	root.Anchored = true
	root.CFrame = CFrame.new(bin.hatch.Position)

	hidden[player] = {
		bin = model,
		character = character,
		anchor = bin.hatch.Position,
		until_ = os.clock() + Config.BINS.maxSeconds,
		canExitAt = os.clock() + Config.BINS.settleSeconds,
		facing = facing,
		hiddenParts = hiddenParts,
		nameMode = nameMode,
	}
	occupant[model] = player
	binOf[player] = model
	HeistService.setHidden(player, true)
	bin.enter.Enabled = false
	bin.open.Enabled = true

	-- The occupant is refused OPEN on their own screen (and every other
	-- prompt goes off too -- ClientMain switches ProximityPromptService off
	-- while disguised). The server re-checks on the trigger regardless.
	bin.open:SetAttribute(Config.PROMPT_DENY_OWNER_ATTRIBUTE, player.UserId)

	-- NAMED, because the way out is not a prompt: a hider sees no prompts at
	-- all. The on-screen hint (Shared/BinExitHint) says the same thing for as
	-- long as they are inside.
	notify(player, "In the bin. Jump or push any way to climb out.", "good")
	StealthService.push(player)
	return true
end

-- CLIMBING OUT IS A JUMP OR A FRESH PUSH, AND FOR ONE BUILD IT WAS A PROMPT
-- NOBODY COULD PRESS.
--
-- The exit was a move input (you push a way and come out that way), and that
-- broke the moment `enterHold` went to 0: a player reaches a bin RUNNING, so
-- the key already under their thumb threw them out on the next frame. The
-- fix was a CLIMB OUT ProximityPrompt -- and ClientMain switches
-- ProximityPromptService off for anybody in a bin, so the prompt never drew
-- and the only way out was the two-minute ceiling.
--
-- NOW: jump (Space, the touch jump button, gamepad A), a tap on the on-screen
-- hint, or a push of the move input that STARTED AFTER the lid shut -- a key
-- held through entry is ignored until it has been let go once. All of them
-- arrive through the `BinClimbOut` remote, which carries at most a direction.
-- `Config.BINS.settleSeconds` is still the commitment. The direction still
-- decides which way you break: the push you made, or for a jump the way the
-- camera is looking (a hider's own facing was flattened to world +Z on entry,
-- so it means nothing), falling back to the way you went in.
local function exitBin(player: Player, direction: Vector3?, why: string?)
	local state = hidden[player]
	local model = state and state.bin
	local bin = model and bins[model]
	local root = getRoot(player)
	if not state or not bin or not root then
		reveal(player, why)
		return
	end

	local out = direction
	if not out or out.Magnitude < 0.1 then
		out = root.CFrame.LookVector
	end
	out = Vector3.new(out.X, 0, out.Z)
	if out.Magnitude < 0.1 then
		out = Vector3.new(0, 0, 1)
	end
	out = out.Unit

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local lift = if humanoid then humanoid.HipHeight + root.Size.Y / 2 else 3

	-- DID THEY CHOOSE THIS? A direction with no message is somebody pushing
	-- their own way out; every other caller passes a reason and no direction
	-- -- the two-minute ceiling, and being tipped out by whoever found you.
	--
	-- Everything else here happens either way, because it is the BIN
	-- reacting and it reacted whoever opened it. The speed burst is the one
	-- thing that does not: it is paid for choosing your own moment, and
	-- handing it to somebody who has just been dug out would reward exactly
	-- the outcome that is meant to hurt.
	local vaulted = direction ~= nil and why == nil

	-- reveal() unanchors; the placement has to happen after it or the write is
	-- made on an anchored root and the character snaps back on the next step.
	reveal(player, why)

	root.CFrame = CFrame.lookAt(
		bin.hatch.Position + out * Config.BINS.exitPush
			+ Vector3.new(0, lift - 1.9, 0),
		bin.hatch.Position + out * (Config.BINS.exitPush + 8)
			+ Vector3.new(0, lift - 1.9, 0))

	flapLid(bin)

	-- VERTICAL ONLY. A horizontal component would be a second way to move
	-- that none of the speeds in HeistService know about, which is the thing
	-- Config.DODGE and Config.BINS.exitBurst both exist to rule out. Written
	-- AFTER the CFrame, or the placement lands on top of it.
	root.AssemblyLinearVelocity = Vector3.new(0, Config.BINS.exitHop, 0)

	-- THE SAME SOMERSAULT THE DODGE PLAYS, on its own attribute.
	--
	-- Reusing DodgeRoll's counter would have been one line fewer and wrong:
	-- that handler also DASHES the local player, driving their move direction
	-- for a quarter of a second -- a third way to move, stacked on the
	-- placement and the burst. A separate attribute gets the animation
	-- without the dash. The animation itself is genuinely the right one:
	-- tumbling out of a bin is the same gesture as rolling out of the way,
	-- and a second hand-built sequence would be the copy that drifts the
	-- first time either is touched.
	--
	-- A COUNTER, never a flag. A boolean set true twice fires one signal, so
	-- somebody using two bins in one chase would animate once.
	local character = player.Character
	if character then
		character:SetAttribute("BinExit", (character:GetAttribute("BinExit") or 0) + 1)
	end

	if vaulted then
		HeistService.giveBurst(player, Config.BINS.exitBurst.peak, Config.BINS.exitBurst.seconds)
	end
end

local function wireBin(model: Model)
	if bins[model] then
		return
	end
	local hatch = model:FindFirstChild("Hatch") :: BasePart?
	if not hatch then
		return
	end

	local enter = Instance.new("ProximityPrompt")
	enter.Name = "Enter"
	enter.ActionText = "Hide"
	Config.setPromptKind(enter, "hide")
	enter.ObjectText = "Litter Bin"
	enter.HoldDuration = Config.BINS.enterHold
	enter.MaxActivationDistance = Config.BINS.range
	enter.RequiresLineOfSight = false
	enter.Parent = hatch

	local open = Instance.new("ProximityPrompt")
	open.Name = "Open"
	open.ActionText = "Open It"
	Config.setPromptKind(open, "dig")
	open.ObjectText = "Litter Bin"
	open.HoldDuration = Config.BINS.openHold
	open.MaxActivationDistance = Config.BINS.range
	open.RequiresLineOfSight = false
	open.Enabled = false
	open.Parent = hatch


	-- COLLECTED BY WALKING THE MODEL, never by FindFirstChild: a bin prop is
	-- a PAIR of bins and both lids are called "Lid", so a lookup by name
	-- returns the same one twice and the other never moves. Same trap the
	-- castle's four Finials already recorded.
	--
	-- Each lid remembers its rest pose and its open pose, computed once here.
	-- The hinge is the lid's BACK edge -- local -Z, since every prop in this
	-- game is authored facing +Z -- so it tips up at the front like a real
	-- wheelie bin rather than rotating about its own middle.
	local lids: { Lid } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Lid" then
			local rest = d.CFrame
			local toHinge = CFrame.new(0, 0, -d.Size.Z / 2)
			table.insert(lids, {
				part = d,
				rest = rest,
				open = rest * toHinge
					* CFrame.Angles(-math.rad(Config.BINS.lidSwing), 0, 0)
					* toHinge:Inverse(),
			})
		end
	end

	local bin: Bin = {
		model = model, hatch = hatch, enter = enter, open = open,
		lids = lids,
	}
	bins[model] = bin

	enter.Triggered:Connect(function(player)
		enterBin(player, model)
	end)

	open.Triggered:Connect(function(player)
		local inside = occupant[model]
		if not inside then
			return
		end
		-- THE OCCUPANT IS ALREADY REFUSED THIS ON THEIR OWN SCREEN, by the
		-- deny attribute `enterBin` sets -- they are shown CLIMB OUT instead,
		-- which is the same bin and the right verb. This is the server half
		-- of that, kept because a client-side refusal is the client declining
		-- to ask and never the guard.
		--
		-- It also still answers the thing it was written for: being tipped
		-- out pays no speed burst and reads as being caught, so an occupant
		-- reaching this would be a strictly worse way out of their own bin.
		if inside == player then
			return
		end
		exitBin(inside, nil, "Found! Someone tipped you out.")
		notify(player, "Got them! They were in the bin.", "good")
	end)

end

-- Polled, for the reason the dog's patrol is: the four things that end a
-- disguise -- moving, grabbing loot, dying, running out the clock -- change
-- independently of each other and of anything this module could listen to.
local function step()
	for player, state in pairs(hidden) do
		local root = getRoot(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")

		-- THE CHARACTER CHECK IS THE SAFETY NET, and it caught a real leak.
		--
		-- Dying in a bin left it occupied for the full two-minute ceiling: the
		-- CharacterAdded hook that was supposed to clear it is connected
		-- inside PlayerAdded, which never fires for a player who was already
		-- in the game when the service started -- which is every player in a
		-- Play Solo session and the first player into any server. Measured:
		-- the bin was still refusing entry six seconds after a respawn.
		--
		-- The hook is fixed below, but this is what makes the class of bug
		-- impossible rather than that one instance of it. `not root` alone
		-- could never have caught it, because a respawned player HAS a root --
		-- just not the one that was put in the bin.
		if not root or player.Character ~= state.character then
			reveal(player, nil)
		elseif humanoid and humanoid.Health <= 0 then
			-- Released on death rather than on respawn, so the bin is free
			-- immediately instead of after the respawn delay.
			reveal(player, nil)
		elseif state.bin then
			-- A bin has no drift rule -- you are anchored inside it -- and no
			-- carry rule either, which is the reversal this whole rework
			-- turns on. What ends it is climbing out, being tipped out, or
			-- the ceiling.
			if os.clock() > state.until_ then
				exitBin(player, nil, "You can't sit in there all day.")
			end
		elseif HeistService.isCarrying(player) then
			-- Non-negotiable for the ornament disguise. The run home stays
			-- visible.
			reveal(player, "You grabbed the haul. Disguise blown!")
		elseif os.clock() > state.until_ then
			reveal(player, "Your disguise wore off.")
		end
	end
end

-- ============================================================
-- BUYING AND USING
-- ============================================================

function StealthService.buy(player: Player, key: string)
	local spec = Config.THIEF_KIT[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end

	if data.coins < spec.cost then
		notify(player, ("Need %d more coins for a %s."):format(spec.cost - data.coins, spec.name), "warn")
		return
	end

	data.coins -= spec.cost
	stock(data)[key] = (stock(data)[key] or 0) + 1

	notify(player, ("%s bought. You have %d."):format(spec.name, stock(data)[key]), "good")
	DataService.save(player)
	StealthService.push(player)
end

function StealthService.use(player: Player, key: string)
	local spec = Config.THIEF_KIT[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end

	-- YOU HAVE TO BE HOLDING IT. The prop in the hand is a tell other players
	-- read off the pavement, so a use that never drew anything would be a lie
	-- about the street. Named rather than silent: the fix is one keypress and
	-- a refusal nobody can read is indistinguishable from a broken item.
	if not HeldItemService.holding(player, key) then
		notify(player, ("Hold the %s out first."):format(spec.name), "warn")
		return
	end

	local held = stock(data)[key] or 0
	if held <= 0 then
		notify(player, ("You have no %s left."):format(spec.name), "warn")
		return
	end

	local used = false
	if spec.style == "ladder" then
		-- THE WORDING LIVES HERE AND THE PLACEMENT LIVES THERE. PlotService
		-- hands back a reason CODE rather than a sentence, the same split
		-- `CosmeticsService.awardTokens` draws with its optional `why`: the
		-- fence knows whether a ladder can stand, the item knows how to say
		-- so, and every one of these refusals names the fix rather than
		-- failing quietly with a consumable spent.
		local placed, why = PlotService.placeLadder(player)
		if placed then
			notify(player, ("Ladder up. %d seconds, either way over."):format(Config.LADDER.seconds), "good")
			used = true
		elseif why == "hoppable" then
			notify(player, "You can jump that fence. Save it for a taller one.", "warn")
		else
			notify(player, "Stand right by a fence to put it up.", "warn")
		end
	elseif spec.style == "raincoat" then
		if StealthService.isHidden(player) then
			notify(player, "Not from inside a bin.", "warn")
		elseif HeistService.isWarded(player) then
			notify(player, "You're already wearing one.", "warn")
		else
			HeistService.setWard(player, true)
			notify(player, "Raincoat on. The next plunger or gum slides off.", "good")
			used = true
		end
	end

	if not used then
		return
	end

	stock(data)[key] = held - 1
	DataService.save(player)
	StealthService.push(player)
	HeldItemService.revalidate(player)
end

-- ONE QUESTION, ASKED FROM SIX PLACES. Every service that can act on the
-- world checks this before doing anything, because a player in a bin may only
-- climb out of it.
function StealthService.isHidden(player: Player): boolean
	return hidden[player] ~= nil
end

-- Public so RideService can refuse to mount over a disguise. Without it a
-- board mounted AFTER concealing is not in the hidden-parts list, and the
-- result is a wheelie bin with a floating motorbike parked in it.
function StealthService.isDisguised(player: Player): boolean
	return hidden[player] ~= nil
end

function StealthService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local held = stock(data)
	local list = {}
	for key, spec in pairs(Config.THIEF_KIT) do
		list[key] = {
			name = spec.name,
			order = spec.order,
			cost = spec.cost,
			blurb = spec.blurb,
			detail = spec.detail,
			held = held[key] or 0,
		}
	end

	Remotes.get("StealthState"):FireClient(player, {
		items = list,
		disguised = hidden[player] ~= nil,
		warded = HeistService.isWarded(player),
	})
end

function StealthService.clear(player: Player)
	reveal(player, nil)
	HeistService.setWard(player, false)
	StealthService.push(player)
end

function StealthService.start()
	Remotes.get("StealthRequest").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		StealthService.buy(player, key)
	end)

	-- No target argument. Both of these act on the caller and nobody else.
	Remotes.get("StealthUse").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		StealthService.use(player, key)
	end)

	-- CLIMBING OUT UNDER YOUR OWN POWER: a jump, a tap on the hint, or a
	-- fresh push of the move input (see Shared/BinExitHint for the client
	-- half). It carries AT MOST A DIRECTION, never a position or an outcome:
	-- the server owns where you land, the settle, and whether you are in a
	-- bin at all. A malformed direction is not an error -- it falls back to
	-- the way the player went in, which is a legal exit.
	--
	-- THIS REPLACED A CLIMB OUT PROMPT THAT NOBODY COULD EVER PRESS.
	-- ClientMain turns ProximityPromptService off for a hider (so the bin's
	-- own OPEN, the next bin and every plot prompt go dark) and that switch
	-- took the CLIMB OUT prompt down with them -- the only way out was the
	-- two-minute ceiling. The exit is not a prompt any more, so that rule
	-- can stay exactly as it is.
	Remotes.get("BinClimbOut").OnServerEvent:Connect(function(player, direction)
		local state = hidden[player]
		if not state or not state.bin or occupant[state.bin] ~= player then
			return
		end
		-- The settle. The client waits it out before asking, so this only
		-- refuses a client written to ignore it.
		if os.clock() < state.canExitAt then
			return
		end
		local out: Vector3 = state.facing
		if typeof(direction) == "Vector3" then
			local flat = Vector3.new(direction.X, 0, direction.Z)
			local m = flat.Magnitude
			-- m == m rejects NaN; the cap rejects inf and nonsense.
			if m == m and m > 0.1 and m < 1e4 then
				out = flat / m
			end
		end
		-- A direction and no reason: the player chose this, so the burst is
		-- earned (see `vaulted` in exitBin).
		exitBin(player, out, nil)
	end)

	-- The ward is consumed inside HeistService, which owns the effect; this is
	-- how the HUD finds out it is gone.
	HeistService.onWardUsed(function(player, _spec)
		StealthService.push(player)
	end)

	-- EXISTING PLAYERS TOO. A PlayerAdded connection made inside start() has
	-- already missed anybody standing in the game, which in Play Solo is the
	-- only player there is -- so this hook silently did nothing every single
	-- test session.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			-- Dying drops both, the way it drops loot and a ride. Neither may
			-- survive onto a fresh character: the disguise's hidden-parts list
			-- points at a destroyed model, and a ward that outlived a respawn
			-- would be a free one every time you reset.
			reveal(player, nil)
			HeistService.setWard(player, false)
			task.defer(StealthService.push, player)
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	Players.PlayerRemoving:Connect(function(player)
		-- Through reveal(), not by dropping the entry. A bin is street
		-- furniture that OUTLIVES its occupant, so clearing the table alone
		-- would leave `occupant` set and the enter prompt disabled -- one
		-- player quitting mid-hide would kill that bin for the rest of the
		-- server's life, with nothing on screen to say why it stopped working.
		reveal(player, nil)
		binReadyAt[player] = nil
	end)

	for _, model in ipairs(CollectionService:GetTagged(BIN_TAG)) do
		wireBin(model)
	end
	CollectionService:GetInstanceAddedSignal(BIN_TAG):Connect(wireBin)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.15 then
			return
		end
		accumulator = 0
		step()
	end)
end

return StealthService
