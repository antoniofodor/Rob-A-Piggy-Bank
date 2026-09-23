--!strict
-- ============================================================
-- CARRYING A PIGGY: OFF A PLINTH, ACROSS THE STREET, ONTO ANOTHER
-- ============================================================
--
-- Plan docs/PIGGY-COLLECTION-PLAN.md §3 and §5, and it is the verb the six
-- pedestals were built without. Until this, the only way a piggy ever reached
-- a slot was a crate placing it front to back -- so the two routes §3 calls
-- the point of the collection ("a piggy you went and got... is placed by hand
-- into any free slot") could not happen at all.
--
-- THREE VERBS AND EXACTLY ONE OF THEM COSTS ANYBODY ANYTHING:
--
--   TAKE    lift one of your own off your own plinth. Free, near-instant,
--           undone by walking four studs and pressing again.
--   SNATCH  lift somebody else's off theirs. Their slot empties in that
--           second; the piggy is not YOURS yet.
--   PLACE   put one you are holding down on an empty slot of your own.
--
-- AND THE FOURTH THING, WHICH IS WHAT THE WHOLE FEATURE TURNS ON: a SNATCHED
-- piggy is secured by STANDING with it, on your own ground, with somewhere to
-- put it, for `Config.PIGGY_HAUL.secureSeconds`. Not by pressing anything.
-- See `secureStep` for why that is a dwell rather than a prompt.
--
-- ------------------------------------------------------------
-- WHY THIS IS NOT `HeistService.Carry`
-- ------------------------------------------------------------
--
-- It nearly was, and the plan says "carrying is already built" in as many
-- words. What is already built is the PICTURE -- the welded miniature, the
-- two-handed pose, the carry speed penalty -- and every one of those is
-- reused here rather than rewritten.
--
-- What is NOT reusable is the accounting. A `Carry` is about coins: an
-- amount, a victim's balance, `LOSS_CAP`, `HEIST_PAYOUT`, the spree
-- multiplier, the revenge window, the keep share, the return bounty, the
-- delivery rings and the bail an arrest charges against it. A piggy haul has
-- none of those and never will, because it moves an OBJECT -- so folding it
-- in would have meant a `kind` branch inside `deliver`, `nab`, `confiscate`,
-- `dropAction`, `carryOptions` and `pushCarryState`: six functions each
-- learning about a thing none of them is about.
--
-- THE RULE THIS PROJECT KEEPS CUTS THE OTHER WAY TOO -- "when a new thing has
-- to behave like an existing thing in twenty places, make it one" -- and the
-- measurement is what settles which applies. A piggy haul has to behave like
-- a coin haul in exactly FIVE places, every one of them about the WEIGHT of a
-- getaway rather than about money: the carry speed, the ride refusal, the
-- disguise breaking, the dog hearing a loaded thief, and being catchable.
-- `HeistService.haulingAnything` is the one line that covers all five.
--
-- ------------------------------------------------------------
-- WHAT IS DELIBERATELY NOT HERE
-- ------------------------------------------------------------
--
-- `LOSS_CAP`'S PIGGY CLAUSE (plan §8) IS NOT BUILT, and that is a gap rather
-- than an omission. `PIGGY_HAUL.victimCooldown` bounds one THIEF against one
-- victim; nothing bounds a whole street taking turns, which is precisely the
-- hole `LOSS_CAP` was written to close for coins. It is also, from the other
-- end, the cap on how fast anybody can BUILD a collection by stealing -- two
-- curves that multiply, which is the failure shape this repo records more
-- often than any other -- so it wants the §8 economy re-derivation behind it
-- rather than a number typed here. Flagged in the build order.
--
-- THE PEDESTAL GUARD (plan §12) IS STAGE 2. A snatch wakes nothing today
-- beyond the dog watcher's ordinary footstep rule, so a well-defended lawn
-- defends its pedestals exactly as well as it defends its grass and no
-- better.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)
local CarryPose = require(ReplicatedStorage.Shared.CarryPose)
local Theme = require(ReplicatedStorage.Shared.Theme)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ResidentService = require(script.Parent.ResidentService)
local CosmeticsService = require(script.Parent.CosmeticsService)
local EconomyService = require(script.Parent.EconomyService)
local HeistService = require(script.Parent.HeistService)
local SocialService = require(script.Parent.SocialService)

local PiggyHaulService = {}

-- WHAT IS IN SOMEBODY'S ARMS.
--
-- `ownerPlot` IS A PLOT AND NOT A PLAYER, which is the widening
-- `attemptSteal` already made and for the same reason: half the lawns on this
-- street belong to residents, and a haul that could only remember a Player
-- would have no way to put a neighbour's piggy back. `ownerPlayer` is the
-- person when there is one and nil when the lawn is a neighbour's, and every
-- branch that cares asks which rather than assuming.
type Haul = {
	key: string,
	-- Lifted off the carrier's OWN plinth. The difference decides everything:
	-- an own haul goes down with one press and a stolen one has to be stood
	-- with.
	own: boolean,
	ownerPlot: any,
	ownerPlayer: Player?,
	-- The slot it came off, so putting it back puts it back WHERE IT WAS. A
	-- recovered piggy landing on whatever slot happened to be free first
	-- would reshuffle a victim's lawn every time somebody failed to rob them,
	-- which is a cost the victim pays for winning.
	slot: number,
	model: Model,
	body: BasePart,
	label: TextLabel,
	-- os.clock() when the carrier last stepped onto ground that could take
	-- this piggy, or nil the moment they left it. See `secureStep`.
	secureFrom: number?,
}

local hauling: { [Player]: Haul } = {}

-- WHEN EACH THIEF MAY NEXT TAKE FROM EACH LAWN, keyed thief then victim.
-- Per-victim and never per-thief-alone, which is the shape `STEAL_COOLDOWN`
-- already has: a thief working six lawns in turn is held up by the lap rather
-- than by a timer, and one camping a single plot is held up by the timer.
local cooldown: { [Player]: { [string]: number } } = {}

-- AND THE SAME CLOCK FOR A NEIGHBOUR THIEF, keyed by their PLOT INDEX rather
-- than by the resident record: a record is replaced whenever a plot frees
-- up, and a cooldown keyed to the table would be forgotten the moment the
-- neighbour moved out -- the same reason `victimKey` keys a resident VICTIM
-- by plot. Two tables rather than one keyed `Player | number`, because the
-- player one is cleared on `PlayerRemoving` and nothing ever leaves this
-- one: a plot index is permanent.
local residentCooldown: { [number]: { [string]: number } } = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

-- WHOSE LAWN THIS IS, as a string both kinds of victim can be keyed by. A
-- player is their UserId; a resident is their PLOT, because a resident record
-- is replaced whenever a plot frees up and a cooldown keyed to the table
-- would be forgotten the moment somebody moved out.
local function victimKey(plot: any): string
	if plot.owner then
		return "p" .. tostring((plot.owner :: Player).UserId)
	end
	return "r" .. tostring(plot.index)
end

local function nameOf(key: string): string
	local skin = Config.getSkin(key)
	return (skin and skin.name) or key
end

-- THE SAVE A PLOT'S COLLECTION LIVES IN, whoever lives there.
--
-- `Config.piggySlots`, `Config.removePiggy` and `Config.placePiggy` take a
-- table with a `piggies` field and nothing else, so a Resident record answers
-- them exactly as a save does. That is what lets one snatch path serve both
-- kinds of lawn instead of two that can drift -- the same duck-typing
-- `ResidentService` already relies on when it reads `Config.getIncomeRate`
-- for a neighbour rather than inventing a parallel curve.
local function collectionOf(plot: any): any?
	if plot.owner then
		return DataService.get(plot.owner :: Player)
	end
	return ResidentService.get(plot)
end

-- MAKE THE LAWN MATCH THE SAVE, for whoever owns it.
--
-- A player's goes through `CosmeticsService.applyToPlot`, which is the ONE
-- door this project keeps for "make the plot match the data" -- so a snatch
-- picks up the six pedestals, their buffers and everything else a repaint
-- owes without this file knowing what any of it is. A resident has no such
-- door and needs only the two calls that door makes for the lawn.
local function repaint(plot: any)
	local owner = plot.owner :: Player?
	if owner then
		CosmeticsService.applyToPlot(owner)
		-- THE HUD AS WELL AS THE GRASS. What a collection EARNS is on the
		-- piggy bank panel, and a slot emptying changes it -- so a repaint
		-- that stopped at the lawn would leave a player's own rate reading
		-- what it was before they were robbed, which is the world and the
		-- server disagreeing with the server being right.
		EconomyService.push(owner)
		return
	end
	local resident = ResidentService.get(plot)
	PlotService.setPiggySlots(plot, resident)
	PlotService.setPiggyBuffers(plot, resident)
end

-- ============================================================
-- WHAT A CARRIED PIGGY LOOKS LIKE
-- ============================================================

-- THE MODEL IS NAMED `Config.LOOT_MODEL_NAME` AND THAT IS NOT A COINCIDENCE.
--
-- `CarryPose` decides whether to hold a character in two hands by asking
-- whether their character has a child of that name -- deliberately, so the
-- pig and the pose are one fact rather than two that can disagree. Parenting
-- this there buys the whole two-handed carry with no second implementation
-- and no flag, and `PiggyModel.build` already names its output that.
--
-- WELDED TO THE ROOT, NEVER TO A LIMB, and the offset is `CarryPose.HOLD`
-- rather than a number chosen here. The root is the one part of a character
-- that does not animate, so the weld captures the offset that was intended
-- rather than whatever phase of a run cycle happened to be replicating at
-- that instant -- and HOLD is where a pig has to BE for the measured hands to
-- be on it. A number typed here would be a second opinion about one
-- measurement, and the pose would lose, because an arm cannot reach a
-- position somebody else chose for it.
local function attach(player: Player, key: string): (Model?, BasePart?, TextLabel?)
	local character = player.Character
	local root = if character
		then character:FindFirstChild("HumanoidRootPart") :: BasePart?
		else nil
	if not character or not root then
		return nil, nil, nil
	end

	local ok, built = pcall(PiggyModel.build, key)
	if not ok or not built then
		warn("[PiggyHaul] could not build " .. key .. ": " .. tostring(built))
		return nil, nil, nil
	end
	local model = built :: Model
	local body = PiggyModel.bodyOf(model)
	if not body then
		model:Destroy()
		return nil, nil, nil
	end

	model:PivotTo(root.CFrame * CarryPose.HOLD)
	model.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Name = "HaulWeld"
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body

	-- WHAT IS IN THEIR ARMS, OVER THEIR HEAD, FOR EVERYBODY.
	--
	-- `AlwaysOnTop`, which is the one place in this file that flag is the
	-- right call: this is the tell a victim chases, so it has to read through
	-- the house they are running around. It also means no screenshot will
	-- ever contain it -- the always-on-top pass is composited after
	-- `screen_capture` takes its frame -- so anything here that has to be
	-- LOOKED at needs the throwaway-clone trick rather than a capture.
	--
	-- 1.8 studs is the height `HeistService.attachLoot`'s own label settled on
	-- after the pig came UP when thieves started holding it rather than towing
	-- it. Matched rather than re-derived: the two labels hang off the same
	-- object at the same place, and a second number would drift.
	local label = Instance.new("BillboardGui")
	label.Name = "HaulLabel"
	label.Size = UDim2.new(0, 200, 0, 40)
	label.StudsOffset = Vector3.new(0, 1.8, 0)
	label.AlwaysOnTop = true
	label.LightInfluence = 0
	label.Parent = body

	local text = Instance.new("TextLabel")
	text.Name = "What"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Theme.FONT
	text.TextScaled = true
	text.TextColor3 = Theme.PAPER
	text.TextStrokeColor3 = Theme.INK
	-- OPAQUE STROKE, which is the rule the piggy NAMES on the plinths already
	-- turn on: this label is read against grass, a road, a hedge and a house
	-- inside ten seconds, so what carries it is the outline rather than the
	-- fill.
	text.TextStrokeTransparency = 0.1
	text.Parent = label

	-- ANYBODY NEARBY CAN TAKE IT BACK, not only the person it was taken from.
	-- Bystanders joining the chase is the half that turns a robbery into a
	-- story, and it is the coin nab's own argument arriving on the object.
	--
	-- ON THE BODY, so it travels with the piggy, and `PromptUI` hides it from
	-- the carrier themselves under the rule that a prompt on your own body is
	-- never for you.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NabPrompt"
	prompt.ActionText = "Nab Thief!"
	Config.setPromptKind(prompt, "nab")
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = Config.PIGGY_HAUL.nabHold
	prompt.MaxActivationDistance = Config.NAB.distance
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(nabber: Player)
		PiggyHaulService.nab(nabber, player)
	end)

	return model, body, text
end

-- TAKE IT OUT OF THEIR ARMS AND HAND THE RECORD BACK.
--
-- The model is destroyed here and nowhere else, which is what keeps
-- `CarryPose` honest: the pose is a function of the model's presence, so a
-- record cleared without the model going would leave a thief hugging thin air
-- for the rest of that character's life.
local function detach(player: Player): Haul?
	local haul = hauling[player]
	if not haul then
		return nil
	end
	hauling[player] = nil
	if haul.model.Parent then
		haul.model:Destroy()
	end
	local character = player.Character
	if character then
		character:SetAttribute(Config.PIGGY_HAUL_ATTRIBUTE, nil)
	end
	-- EMPTY HANDS CANNOT SWAP. An own haul is the only kind that ever lit the
	-- bank's swap prompt, and this is the one place every haul ends, so the
	-- offer comes off here and cannot be left lit by an ending somebody
	-- forgot -- a nab, a dog, a death, a disconnect, a placement.
	if haul.own then
		PlotService.setSwapOffer(haul.ownerPlot, nil)
	end
	-- THE SPEED COMES BACK THROUGH `HeistService`, never by writing WalkSpeed
	-- here. That function owns the stun, the snag, the ride, the tiptoe, the
	-- climb, the dodge and the burst as well as the carry penalty, and a
	-- write from out here would be a second answer that loses to whichever of
	-- those fires next.
	HeistService.haulChanged(player)
	return haul
end

-- ============================================================
-- PUTTING ONE DOWN
-- ============================================================

-- WHERE IT GOES BACK TO, and it tries its own slot first.
--
-- Returns true if it landed. A lawn with no room at all is very nearly
-- unreachable -- the slot this piggy left is free by construction unless its
-- owner filled it inside the twenty seconds of a getaway, and a crate is
-- refused on a full lawn -- but it is not impossible, so it is answered
-- rather than assumed.
local function putBackKey(ownerPlot: any, key: string, slot: number): boolean
	local data = collectionOf(ownerPlot)
	if not data then
		return false
	end
	if Config.placePiggy(data, key, slot) then
		return true
	end
	local free = Config.firstFreePiggySlot(data)
	return free ~= nil and Config.placePiggy(data, key, free :: number)
end

local function putBack(haul: Haul): boolean
	return putBackKey(haul.ownerPlot, haul.key, haul.slot)
end

-- HOME AGAIN: the piggy goes back to whoever it belongs to and the thief is
-- left with nothing. Every ending that is not a successful secure comes
-- through here -- a nab, a dog, an arrest, a death, a disconnect -- so there
-- is one place that knows what "you did not get away with it" means.
--
-- SPLIT IN TWO because a NEIGHBOUR'S haul is not a `Haul`: it has no model,
-- body or label on a character (`ResidentService` carries its own), so what
-- it shares with a player's is exactly the plot, the key and the slot --
-- `settleHome` takes those three and `returnHome` is the `Haul` reading of
-- it. One place still knows what "you did not get away with it" means; two
-- kinds of thief arrive at it.
local function settleHome(ownerPlot: any, key: string, landed: boolean, tellOwner: string?)
	repaint(ownerPlot)
	local owner = ownerPlot.owner :: Player?
	if owner and owner.Parent then
		if landed then
			if tellOwner then
				notify(owner, tellOwner, "good")
			end
		else
			-- SAID RATHER THAN SWALLOWED. A piggy that could not be put back
			-- is a piggy that is GONE, and a loss nobody was told about is
			-- indistinguishable from a bug -- which is the one failure this
			-- project refuses above all others.
			notify(owner, ("Your %s came back and there was no room for it.")
				:format(nameOf(key)), "warn")
		end
		DataService.save(owner)
	end
end

local function returnHome(haul: Haul, tellOwner: string?)
	settleHome(haul.ownerPlot, haul.key, putBack(haul), tellOwner)
end

-- ============================================================
-- THE THREE VERBS
-- ============================================================

-- WHICH PEDESTAL THIS IS, RE-READ ON THE SERVER.
--
-- The slot is closed over in the connection rather than sent, which is the
-- "the click means now, never now and here" decision `BoneThrow`,
-- `placeLadder`, `CrackTap` and the collect pads all make -- so there is no
-- index on the wire to forge. What is checked here is everything else: that
-- the presser is alive and standing at the plinth this prompt belongs to.
--
-- AGAINST THE PLINTH RATHER THAN THE PLOT, because that is the part the
-- prompt is on and a prompt measures to its own part's centre. The slack is
-- the crack's own range-binding shape: a press must not fail because somebody
-- shuffled on the spot between the hold starting and it finishing.
local function reach(player: Player, plot: any, slot: number): boolean
	local character = player.Character
	local root = if character
		then character:FindFirstChild("HumanoidRootPart") :: BasePart?
		else nil
	local humanoid = if character
		then character:FindFirstChildOfClass("Humanoid")
		else nil
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local pedestal = plot.pedestals and plot.pedestals[slot]
	if not pedestal then
		return false
	end
	return (root.Position - pedestal.plinth.Position).Magnitude
		<= Config.COLLECT_RANGE + 2
end

-- YOUR OWN, OFF YOUR OWN PLINTH.
function PiggyHaulService.take(player: Player, plot: any, slot: number)
	if plot.owner ~= player then
		return
	end
	local data = DataService.get(player)
	if not data or not reach(player, plot, slot) then
		return
	end
	if hauling[player] or HeistService.isCarrying(player) then
		notify(player, "Your hands are full already.", "warn")
		return
	end
	local entry = Config.piggySlots(data)[slot]
	local key = entry and entry.key
	if key == nil then
		notify(player, "There is nothing on that pedestal.", "warn")
		return
	end

	-- THE COUNT COMES DOWN WITH IT, which reads wrong for your own piggy and
	-- is right. Placement IS ownership under the six-slot lawn, so a piggy in
	-- your arms is one standing nowhere -- and leaving `owned` up would let a
	-- crate refuse to open while the lawn had a visibly free plinth on it,
	-- which is the collection total and the grass disagreeing with nothing to
	-- explain it. `place` and every `returnHome` path put it straight back.
	if Config.removePiggy(data, slot) == nil then
		return
	end
	local model, body, label = attach(player, key)
	if not model or not body or not label then
		-- PUT IT BACK RATHER THAN LOSING IT. The save was written before the
		-- model was built, so a failure here would otherwise delete a piggy
		-- with nothing in any log.
		Config.placePiggy(data, key, slot)
		repaint(plot)
		return
	end
	hauling[player] = {
		key = key, own = true, ownerPlot = plot, ownerPlayer = player,
		slot = slot, model = model, body = body, label = label,
	}
	label.Text = nameOf(key)
	local character = player.Character
	if character then
		character:SetAttribute(Config.PIGGY_HAUL_ATTRIBUTE, "own")
	end
	HeistService.haulChanged(player)
	-- AND THE BANK OFFERS TO TAKE IT. A piggy of your own in your arms is the
	-- only state the swap prompt is live in.
	PlotService.setSwapOffer(plot, key)
	repaint(plot)
	DataService.save(player)
end

-- ============================================================
-- THE TILL
-- ============================================================

-- WHERE THE OWNER STANDS TO SWAP: at the bank, which is at the plot centre
-- rather than on a plinth. The same slack `reach` gives a plinth press, for
-- the same reason.
local function reachBank(player: Player, plot: any): boolean
	local character = player.Character
	local root = if character
		then character:FindFirstChild("HumanoidRootPart") :: BasePart?
		else nil
	local humanoid = if character
		then character:FindFirstChildOfClass("Humanoid")
		else nil
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local bank = plot.piggy and plot.piggy.body
	if not bank then
		return false
	end
	return (root.Position - bank.Position).Magnitude <= Config.COLLECT_RANGE + 2
end

-- THE ONE COUNT MOVE `Config` HAS NO DOOR FOR. `placePiggy` and `removePiggy`
-- bump `owned` for a SLOT; the till is slot 0 and neither reaches it, and
-- this file may not grow Config. Written once, in the shape `removePiggy`
-- uses -- clamped at zero and nil'd at zero, so `owned` never carries a dead
-- key -- rather than inline at the two sites that need it.
local function adjustOwned(data: any, key: string, delta: number)
	local piggies = data.piggies
	piggies.owned = piggies.owned or {}
	local owned = piggies.owned
	local n = math.max(0, (owned[key] or 0) + delta)
	owned[key] = if n > 0 then n else nil
end

-- SWAP THE PIGGY IN YOUR ARMS FOR THE ONE ON YOUR BANK (designer decision
-- 2026-09-22): "a pig must be on the bank till at all times so in order to
-- move one off the player will have to swap another piggy onto it by
-- carrying one of their other piggies or a freshly caught one up to the till
-- and holding the swap button."
--
-- A PIG IS ON THE TILL AT ALL TIMES BY CONSTRUCTION. There is no "take from
-- till" verb -- this is the only thing that changes `piggies.till`, and it
-- always writes a key in the same breath it lifts one off. What goes onto
-- the till decides what the bank EARNS (`EconomyService.slotRate` at slot 0
-- reads the key), what it WEARS (`CosmeticsService.applyToPlot` dresses the
-- bank from it) and what the SIGN boasts; all three follow the one field
-- through the one repaint below, so none of them can be a swap behind.
--
-- ONLY A PIGGY OF YOUR OWN, and that refusal is the five seconds again. A
-- stolen piggy pressed straight onto the till on arrival would be a snatch
-- that can never be interrupted on the thief's own lawn -- the exact hole
-- the `place` prompt refuses, refused here for the same reason with the same
-- sentence. A "freshly caught" herd piggy lands on a pedestal by itself, so
-- the route for one is take-then-swap, which is an own haul like any other.
--
-- THE BOOKS. `take` already took the carried copy out of `owned` (a piggy in
-- your arms stands nowhere); putting it on the till counts it again, and the
-- till's old copy leaving for your arms uncounts that one. Net, `owned` is
-- exactly what it was before the take once the old till piggy is placed --
-- verified in `tests/luau/piggies.luau` -- so `piggystate` goes on reading
-- "owned matches standing".
--
-- THE CARRY IS THE OLD TILL PIGGY AND IT IS AN OWN HAUL, built through the
-- same `attach` a take uses, with the incoming piggy's origin slot as its
-- own: that slot is free by construction (the incoming piggy came off it),
-- so a nab, a death or a disconnect puts the old till piggy down there
-- through the one `returnHome` every losing ending shares.
function PiggyHaulService.swap(player: Player, plot: any)
	if plot.owner ~= player then
		-- SAID, because a resident's bank carries no prompt and a neighbour's
		-- is refused to everybody but them on the client -- so reaching this
		-- at all means a forged trigger or a race, and either wants a reason.
		notify(player, "That is not your piggy bank.", "warn")
		return
	end
	local data = DataService.get(player)
	if not data or not reachBank(player, plot) then
		return
	end
	local haul = hauling[player]
	if not haul then
		if HeistService.isCarrying(player) then
			notify(player,
				"That is a bag of coins, not a piggy. Only a piggy goes on the till.", "warn")
		else
			notify(player,
				"You are not carrying a piggy. Take one off a pedestal first.", "warn")
		end
		return
	end
	if not haul.own then
		notify(player, ("Hold %s on your own plot for %d seconds to make it yours first.")
			:format(nameOf(haul.key), Config.PIGGY_HAUL.secureSeconds), "warn")
		return
	end

	local incoming = haul.key
	local outgoing = Config.piggyKeyAt(data, 0)
	local slot = haul.slot

	-- THE OLD TILL PIGGY GOES INTO YOUR ARMS BEFORE ANYTHING IS WRITTEN, so a
	-- carry that cannot be built (no character, no root) leaves the save
	-- exactly as a failed `take` leaves it: the incoming piggy back on the
	-- slot it came off, and the till untouched.
	detach(player)
	local model, body, label = attach(player, outgoing)
	if not model or not body or not label then
		if not Config.placePiggy(data, incoming, slot) then
			local free = Config.firstFreePiggySlot(data)
			if free == nil or not Config.placePiggy(data, incoming, free :: number) then
				notify(player, ("Your %s could not be put back and there was no room for it.")
					:format(nameOf(incoming)), "warn")
			end
		end
		repaint(plot)
		DataService.save(player)
		return
	end

	adjustOwned(data, incoming, 1)
	adjustOwned(data, outgoing, -1)
	data.piggies.till = incoming

	hauling[player] = {
		key = outgoing, own = true, ownerPlot = plot, ownerPlayer = player,
		slot = slot, model = model, body = body, label = label,
	}
	label.Text = nameOf(outgoing)
	local character = player.Character
	if character then
		character:SetAttribute(Config.PIGGY_HAUL_ATTRIBUTE, "own")
	end
	HeistService.haulChanged(player)
	-- STILL CARRYING, SO STILL OFFERED -- now naming the old till piggy, so
	-- the card over the bank says which piggy a second hold would put back.
	PlotService.setSwapOffer(plot, outgoing)
	-- THE BANK IS RE-DRESSED, RE-RATED AND RE-SIGNED IN ONE REPAINT.
	-- `CosmeticsService.applyToPlot` dresses the bank from the till, which
	-- republishes the model's `SkinKey` for the client animator; the sign
	-- takes the same key; `EconomyService.push` re-reads the slot-0 rate.
	repaint(plot)
	DataService.save(player)
	notify(player, ("%s is on your piggy bank now. You are holding %s.")
		:format(nameOf(incoming), nameOf(outgoing)), "good")
end

-- SOMEBODY ELSE'S.
function PiggyHaulService.snatch(thief: Player, plot: any, slot: number)
	if plot.owner == thief then
		return
	end
	local data = DataService.get(thief)
	if not data or not reach(thief, plot, slot) then
		return
	end
	if hauling[thief] or HeistService.isCarrying(thief) then
		notify(thief, "Your hands are full already.", "warn")
		return
	end
	local victimData = collectionOf(plot)
	if not victimData then
		return
	end
	local entry = Config.piggySlots(victimData)[slot]
	local key = entry and entry.key
	if key == nil then
		notify(thief, "There is nothing on that pedestal.", "warn")
		return
	end

	-- HOW OFTEN ONE LAWN MAY BE PICKED OVER. Per thief per victim, at
	-- `STEAL_COOLDOWN`'s own number -- it is what stops a thief standing on
	-- one plot and emptying six plinths in six seconds, and it is
	-- deliberately NOT a bound on what a victim can lose to a whole street.
	-- See the note in `Config.PIGGY_HAUL`.
	local now = os.clock()
	local mine = cooldown[thief]
	if not mine then
		mine = {}
		cooldown[thief] = mine
	end
	local vkey = victimKey(plot)
	local ready = (mine :: any)[vkey] or 0
	if now < ready then
		notify(thief, ("Wait %ds before taking from here again.")
			:format(math.ceil(ready - now)), "warn")
		return
	end

	-- THE SHIELD IS THE COIN ROBBERY'S SHIELD, asked through the one function
	-- that owns it. A player whose first session has not ended yet may not be
	-- robbed of coins, and being robbed of an object they own outright is
	-- strictly worse -- so a second answer to "is this person protected"
	-- would be exactly the second implementation `HeistService` keeps one of.
	local owner = plot.owner :: Player?
	if owner then
		local why = HeistService.whyCannotSnatch(thief, owner)
		if why then
			notify(thief, why, "warn")
			return
		end
	end

	if Config.removePiggy(victimData, slot) == nil then
		return
	end
	local model, body, label = attach(thief, key)
	if not model or not body or not label then
		Config.placePiggy(victimData, key, slot)
		repaint(plot)
		return
	end
	(mine :: any)[vkey] = now + Config.PIGGY_HAUL.victimCooldown
	hauling[thief] = {
		key = key, own = false, ownerPlot = plot, ownerPlayer = owner,
		slot = slot, model = model, body = body, label = label,
	}
	label.Text = nameOf(key)
	local character = thief.Character
	if character then
		character:SetAttribute(Config.PIGGY_HAUL_ATTRIBUTE, "stolen")
	end
	-- DROPS THE FIRST-SESSION SHIELD ON THE GRAB, exactly as a coin crack
	-- does and for the same reason: *nobody can touch your piggy until you
	-- take somebody else's* is one sentence carrying the rule, the theme and
	-- the trade, and the moment you decided to be a thief is the grab rather
	-- than the delivery.
	HeistService.dropShield(thief)
	HeistService.haulChanged(thief)
	repaint(plot)
	DataService.save(thief)

	-- THE VICTIM IS TOLD AT THE GRAB AND NOT AT THE SECURE, and that ordering
	-- IS the recovery mechanic. Five seconds of dwell is worth nothing if the
	-- one person who could interrupt it does not know it is running -- and
	-- their own plinth going bare is a tell they have to be looking at their
	-- own lawn to read.
	if owner and owner.Parent then
		notify(owner, ("%s is running off with your %s!")
			:format(thief.DisplayName, nameOf(key)), "alarm")
		DataService.save(owner)
	end
end

-- ============================================================
-- A NEIGHBOUR'S SNATCH
-- ============================================================
--
-- THE SAME VERB WITH A RESIDENT ON THE THIEF END, and it is the `snatch`
-- above with the CHARACTER taken out: no reach test (a neighbour walks to
-- the plinth through its own route and stands on the pad), no hands-full
-- test (its record is one job at a time), no attach (it carries its own
-- miniature -- `ResidentService.attachHaul`), no shield to drop and no rap
-- sheet. What is LEFT is everything that is a rule about the VICTIM'S LAWN:
-- the per-victim cooldown, the first-session shield, the slot emptying
-- through `Config.removePiggy`, the repaint, and the alarm naming who --
-- and that is exactly the set a second copy over in `ResidentService` would
-- have drifted on. Same split as `HeistService.residentTake`, which is the
-- coin crack with the character taken out, and the same reason it lives in
-- the file that owns the accounting.
--
-- `Config.LOSS_CAP`'S PIGGY CLAUSE IS STILL NOT BUILT (see the header), so
-- nothing here bounds what a lawn loses to a whole street of neighbours
-- taking turns either -- what bounds it today is the per-victim cooldown,
-- `RESIDENTS.walk.maxOut` and the snatch weights in `RESIDENTS.snatch`.
--
-- Returns the piggy's key on success, nil on a refusal. Silent on a refusal:
-- there is nobody to tell.
function PiggyHaulService.residentSnatch(thief: any, plot: any, slot: number): string?
	if plot.index == thief.plot.index then
		return nil
	end
	local victimData = collectionOf(plot)
	if not victimData then
		return nil
	end
	local entry = Config.piggySlots(victimData)[slot]
	local key = entry and entry.key
	if key == nil then
		return nil
	end

	local now = os.clock()
	local mine = residentCooldown[thief.plot.index]
	if not mine then
		mine = {}
		residentCooldown[thief.plot.index] = mine
	end
	local vkey = victimKey(plot)
	if now < ((mine :: any)[vkey] or 0) then
		return nil
	end

	-- THE SHIELD, READ OFF THE ATTRIBUTE `HeistService` PUBLISHES for the
	-- rob badge -- its own stamp, in its own clock -- because
	-- `whyCannotSnatch` takes a Player thief and a neighbour is not one.
	-- `ResidentService.pickVictim` already refuses a shielded plot on the
	-- same attribute; this is the re-check at the moment of the grab, the
	-- shape every cooldown and range in this file takes.
	local owner = plot.owner :: Player?
	if owner then
		local until_ = owner:GetAttribute(Config.PLAYER_SHIELD_ATTRIBUTE)
		if typeof(until_) == "number" and until_ > Workspace:GetServerTimeNow() then
			return nil
		end
	end

	if Config.removePiggy(victimData, slot) == nil then
		return nil
	end
	(mine :: any)[vkey] = now + Config.PIGGY_HAUL.victimCooldown
	repaint(plot)
	if owner and owner.Parent then
		notify(owner, ("%s is running off with your %s!")
			:format(tostring(thief.name), nameOf(key)), "alarm")
		DataService.save(owner)
	end
	return key
end

-- THE OTHER HALF: a neighbour nabbed, evicted or unable to pick the piggy up
-- puts it back where it was, through the one ending a player's lost haul
-- takes. `ResidentService.registerPiggyReturn` is how it arrives.
function PiggyHaulService.residentReturn(plot: any, key: string, slot: number)
	settleHome(plot, key, putBackKey(plot, key, slot),
		("%s is back on your lawn."):format(nameOf(key)))
end

-- PUTTING ONE DOWN ON AN EMPTY SLOT OF YOUR OWN.
function PiggyHaulService.place(player: Player, plot: any, slot: number)
	if plot.owner ~= player then
		return
	end
	local data = DataService.get(player)
	if not data or not reach(player, plot, slot) then
		return
	end
	local haul = hauling[player]
	if not haul then
		-- THE REFUSAL THAT TEACHES THE VERB. An empty plinth of your own
		-- advertises PLACE to you whether or not your hands are full, because
		-- a client rule may only ever turn a prompt OFF and one refused for
		-- empty hands could never come back when they were not. So the press
		-- answers out loud, and names what to do instead.
		notify(player,
			"You are not carrying a piggy. Take one off a pedestal first.", "warn")
		return
	end
	if not haul.own then
		-- A STOLEN ONE CANNOT BE PRESSED INTO PLACE, and refusing it here is
		-- what makes the five seconds mean anything: a prompt is instant, so
		-- a thief who could press one on arrival would never be catchable on
		-- their own lawn. The refusal names the RULE rather than the
		-- restriction, because the rule is the mechanic.
		notify(player, ("Hold %s on your own plot for %d seconds to make it yours.")
			:format(nameOf(haul.key), Config.PIGGY_HAUL.secureSeconds), "warn")
		return
	end
	local entry = Config.piggySlots(data)[slot]
	if entry and entry.key ~= nil then
		notify(player, "There is already a piggy on that pedestal.", "warn")
		return
	end
	if not Config.placePiggy(data, haul.key, slot) then
		return
	end
	detach(player)
	repaint(plot)
	DataService.save(player)
end

-- ============================================================
-- THE FIVE SECONDS
-- ============================================================

-- WHERE A STOLEN PIGGY BECOMES YOURS.
--
-- A ROOM WITH AN EMPTY PEDESTAL IN IT, and today there is exactly one room:
-- the lawn. `PlotService.yardContaining` is the rectangle the fence encloses,
-- and it is the same one the ride gate and the fence penalty already test
-- against -- so "am I home" cannot disagree with "whose yard is this", which
-- is the reason that function exists rather than a second rectangle here.
--
-- WHEN INTERIORS LAND (plan §6) THIS IS THE ONE PREDICATE THAT CHANGES. A
-- house becomes a second room with its own free-shelf test, and the dwell,
-- the countdown, the interruption and the landing are all untouched. That is
-- why the question is asked as "is there a room here that could take it"
-- rather than as "am I standing on my lawn".
local function roomFor(player: Player): (any?, number?)
	local character = player.Character
	local root = if character
		then character:FindFirstChild("HumanoidRootPart") :: BasePart?
		else nil
	if not root then
		return nil, nil
	end
	local plot = PlotService.getPlot(player)
	if not plot or PlotService.yardContaining(root.Position) ~= plot then
		return nil, nil
	end
	local data = DataService.get(player)
	if not data then
		return nil, nil
	end

	-- THE CLOSEST FREE SLOT, which is what the dwell lands on. Closest to the
	-- PLAYER rather than first free, because the five seconds are spent
	-- standing somewhere and the piggy should appear where they stood -- one
	-- that teleports to the front of the lawn after a chase reads as the game
	-- deciding for you.
	local slots = Config.piggySlots(data)
	local best: number? = nil
	local bestDist: number? = nil
	for i = 1, Config.PIGGY_LAWN_SLOT_COUNT do
		if slots[i].key == nil then
			local pedestal = plot.pedestals and plot.pedestals[i]
			if pedestal then
				local d = (root.Position - pedestal.plinth.Position).Magnitude
				if bestDist == nil or d < bestDist then
					best, bestDist = i, d
				end
			end
		end
	end
	if best == nil then
		return nil, nil
	end
	return plot, best
end

-- ONE POLL FOR EVERYBODY CARRYING, rather than a timer per haul.
--
-- A timer would have to be cancelled by every interruption there is -- a nab,
-- a dog, an arrest, a death, a step off the lawn, a lawn that filled up while
-- somebody stood on it -- which is six cancellations and a seventh nobody
-- remembers. A poll asks the only question that matters on every tick and
-- there is nothing to cancel, because the state IS the answer.
--
-- AND THE COUNTDOWN IS ON THE LABEL OVER THE PIGGY rather than on the
-- carrier's HUD, deliberately. It is the one number in this getaway the
-- VICTIM most needs, and they are behind the thief looking at their back -- so
-- a HUD element would be showing it to the only person who does not need
-- telling.
local function secureStep(player: Player, haul: Haul, now: number)
	if haul.own then
		return
	end
	local plot, slot = roomFor(player)
	if not plot or not slot then
		if haul.secureFrom ~= nil then
			haul.secureFrom = nil
			haul.label.Text = nameOf(haul.key)
			haul.label.TextColor3 = Theme.PAPER
		end
		return
	end
	if haul.secureFrom == nil then
		haul.secureFrom = now
		haul.label.TextColor3 = Theme.GOLD
	end
	local left = Config.PIGGY_HAUL.secureSeconds - (now - (haul.secureFrom :: number))
	if left > 0 then
		-- WRITTEN ONLY WHEN IT CHANGED, the guard every label that runs off a
		-- loop in this project carries: a `Text` write is a property
		-- replication to every client in range, and this one runs at
		-- Heartbeat.
		local shown = ("SAFE IN %.1fs"):format(left)
		if haul.label.Text ~= shown then
			haul.label.Text = shown
		end
		return
	end

	local data = DataService.get(player)
	if not data or not Config.placePiggy(data, haul.key, slot :: number) then
		return
	end
	detach(player)
	repaint(plot)
	DataService.save(player)
	notify(player, ("%s is yours."):format(nameOf(haul.key)), "good")

	-- ONE MORE ON THE RAP SHEET, AND IT IS COUNTED HERE RATHER THAN AT THE
	-- GRAB.
	--
	-- `SocialService.recordSteal` has been waiting for this since Most Wanted
	-- was re-pointed at the value of PIGGIES stolen: its own note says the
	-- coin path still feeds it only because "the snatch that replaces it does
	-- not exist yet", and that a board counting zero for everybody is the
	-- failure that killed the season ladder.
	--
	-- AT THE SECURE, WHICH IS THIS PROJECT'S OWN RULE RATHER THAN A CHOICE:
	-- loot nabbed out of your hands was never stolen, you were caught. The
	-- coin path counts on the DELIVERY for the same reason, and a snatch that
	-- counted at the grab would put a thief on the poster for a robbery a
	-- guard dog undid four seconds later.
	--
	-- `Config.piggyWorth` IS THE UNIT, which is what keeps the board and the
	-- sell prompt from drifting: it is the one coin figure this game gives an
	-- animal, so a rap sheet and a sale agree about what a Pearl is worth by
	-- construction. A resident counts exactly as a player does -- robbing an
	-- empty house has always put you on Most Wanted, and it is what makes the
	-- police loop work in a one-player server.
	SocialService.recordSteal(player, Config.piggyWorth(haul.key))
	-- AND ONE MORE ON THE LIFETIME COUNT the street leaderboard prints,
	-- at the same moment and for the same reason: a piggy nabbed, returned
	-- or confiscated on the way home was never robbed. A player counter --
	-- `residentSnatch` runs a resident's haul and touches no save.
	data.piggiesStolen = (tonumber(data.piggiesStolen) or 0) + 1
end

-- ============================================================
-- LOSING IT
-- ============================================================

-- TAKEN OFF A THIEF BY SOMEBODY WHO CAUGHT THEM.
--
-- The `nab` seam: a player pressing the prompt on the piggy, a guard dog, or
-- a shopkeeper -- all through `HeistService.nab`, which is what makes this one
-- ending rather than three.
--
-- THE NABBER GETS THE THANKS AND NOTHING ELSE, deliberately. The coin nab
-- pays a keep share precisely because coins are fungible and a piggy is not,
-- and handing a bystander somebody else's Pearl for pressing a button would
-- make nabbing a better way to collect than stealing. The piggy goes home.
function PiggyHaulService.nab(nabber: Player, thief: Player,
	byDog: boolean?, catcher: string?): boolean
	local haul = hauling[thief]
	if not haul or nabber == thief then
		return false
	end
	-- A DODGE BUYS A MOMENT AND NEVER AN ESCAPE, the same line the coin nab
	-- draws: the catcher loses their whole hold and has to start again, and
	-- for a dog "start again" is the chase carrying on and another lunge a
	-- moment later.
	if HeistService.isDodgeImmune(thief) then
		if not byDog then
			notify(nabber, ("%s dodged!"):format(thief.DisplayName), "warn")
			notify(thief, "Dodged!", "good")
		end
		return false
	end
	-- RANGE IS RE-CHECKED FOR A PLAYER AND WAIVED FOR A DOG, which is the coin
	-- nab's own rule: a dog's `catchRadius` has already decided it, and asking
	-- `NAB.distance` a second time would let a thief who took one more step in
	-- the same frame walk out of a catch that already happened.
	if not byDog then
		local a = if nabber.Character
			then nabber.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			else nil
		local b = if thief.Character
			then thief.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			else nil
		if not a or not b
			or (a.Position - b.Position).Magnitude > Config.NAB.distance + 6 then
			return false
		end
	end

	detach(thief)
	local name = nameOf(haul.key)
	local who = catcher or (if byDog then "A guard dog" else nabber.DisplayName)
	notify(thief, ("%s got you! You dropped %s."):format(who, name), "chase")
	if not byDog then
		notify(nabber, ("Nice nab! %s went home."):format(name), "good")
	end
	returnHome(haul, ("%s is back on your lawn."):format(name))
	return true
end

-- TAKEN BY THE PATROL. No thanks, no nabber and no bail -- see the note in
-- `HeistService.confiscate` for why an object cannot be charged for.
function PiggyHaulService.confiscate(thief: Player)
	local haul = hauling[thief]
	if not haul then
		return
	end
	detach(thief)
	local name = nameOf(haul.key)
	notify(thief, ("The patrol took %s off you."):format(name), "police")
	returnHome(haul, ("The patrol brought your %s back."):format(name))
end

-- DIED, RESPAWNED, OR LEFT. A piggy may not go with them.
--
-- THIS IS THE ENDING THAT CANNOT BE FORGOTTEN, because it is the only one
-- with nobody on the other side of it to notice. Every other loss has a
-- catcher who is told what happened; a disconnect mid-getaway has nothing,
-- and a piggy left in a departed player's record is a piggy deleted from the
-- game with the victim's collection permanently one short.
local function lost(player: Player)
	local haul = hauling[player]
	if not haul then
		return
	end
	detach(player)
	returnHome(haul, ("Your %s found its way home."):format(nameOf(haul.key)))
end

function PiggyHaulService.isHauling(player: Player): boolean
	return hauling[player] ~= nil
end

-- ============================================================
-- WIRING
-- ============================================================

function PiggyHaulService.start()
	-- NO CUSTOM REMOTE. `ProximityPrompt.Triggered` already replicates
	-- client-to-server on its own -- the native channel `steal`, `smash`, the
	-- collect pads and the sell prompt all use -- and the slot is closed over
	-- in the connection rather than sent, so there is no index on the wire.
	--
	-- CONNECTED HERE, WHERE THE PLOTS EXIST, rather than per claim: a plinth
	-- and its prompts outlive every owner a plot ever has (`dress` rebuilds
	-- the display and never the prompts on it), so one connection per pedestal
	-- for the life of the server is correct and a re-wire on claim would leak.
	for _, plot in ipairs(PlotService.getAll()) do
		for index, pedestal in ipairs(plot.pedestals or {}) do
			-- ONE PROMPT PER VERB, so a forged trigger reaches exactly the
			-- function that prompt is FOR and every guard in it. Deciding
			-- take-or-place from the save inside a shared handler would work
			-- and would put the branch in the one place a reader would not
			-- think to check it.
			pedestal.takePrompt.Triggered:Connect(function(who: Player)
				PiggyHaulService.take(who, plot, index)
			end)
			pedestal.placePrompt.Triggered:Connect(function(who: Player)
				PiggyHaulService.place(who, plot, index)
			end)
			pedestal.snatchPrompt.Triggered:Connect(function(who: Player)
				PiggyHaulService.snatch(who, plot, index)
			end)
		end
		-- AND THE BANK'S SWAP, closed over the plot for the reason the slot
		-- is above. A shop vault carries none, so the guard is the field.
		local swapPrompt = plot.piggy and plot.piggy.swapPrompt
		if swapPrompt then
			swapPrompt.Triggered:Connect(function(who: Player)
				PiggyHaulService.swap(who, plot)
			end)
		end
	end

	local function follow(player: Player)
		player.CharacterRemoving:Connect(function()
			lost(player)
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		follow(player)
	end
	Players.PlayerAdded:Connect(follow)
	Players.PlayerRemoving:Connect(function(player)
		lost(player)
		cooldown[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, haul in pairs(hauling) do
			-- A CHARACTER THAT WENT WITHOUT `CharacterRemoving` FIRING is what
			-- this catches: the model is parented to the character, so a
			-- character destroyed under it takes the piggy with it and the
			-- record would go on describing something that no longer exists.
			if haul.model.Parent == nil or player.Parent == nil then
				-- THROUGH `detach` RATHER THAN CLEARING THE TABLE, so the
				-- carry attribute comes off and the speed is recomputed. A
				-- record dropped on its own would leave a living player
				-- walking at carry pace with nothing in their arms.
				local dropped = detach(player)
				if dropped then
					returnHome(dropped, nil)
				end
			else
				secureStep(player, haul, now)
			end
		end
	end)
end

return PiggyHaulService
