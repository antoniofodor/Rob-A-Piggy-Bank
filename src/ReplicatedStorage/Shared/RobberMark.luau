--!strict
--
-- SOMEBODY IS RUNNING OFF WITH YOUR COINS -- said to the one player it is
-- about, and to nobody else.
--
-- IT REPLACES A HIGHLIGHT THAT WAS CORRECT AND STILL WRONG. A carrying thief
-- wore a gold Highlight visible through walls, on the rule that a thief must
-- never be able to hide. That is right for a player thief on an eight-player
-- street, and it stopped being right the moment residents started robbing
-- each other: `RESIDENTS.walk.maxOut` neighbours are out at any moment, every
-- one of them carrying, so the whole row glowed permanently. A signal that is
-- on all the time is one nobody reads -- and almost none of it concerned the
-- person looking at it, because a neighbour robbing another neighbour is not
-- that player's business.
--
-- So the mark is PER VIEWER and it fires on one condition: those are YOUR
-- coins. `Config.CARRY_VICTIM_ATTRIBUTE` on the carrier carries the UserId of
-- the plot owner being robbed, and this draws over exactly the carriers whose
-- value is the local player's own id. Everyone else's street is quiet.
--
-- ONE READER FOR BOTH KINDS OF THIEF, which is why the attribute lives on the
-- CARRIER rather than on the victim. A player's Character and a resident's
-- Model are both Instances in `workspace` and both replicate their attributes,
-- so a neighbour walking off with your coins is marked by the same code that
-- marks a person -- no branch, and no second thing to remember when a third
-- kind of thief is invented.
--
-- IT STILL SHOWS THROUGH WALLS, and that is the half of the old rule worth
-- keeping. "A thief must never be able to hide" is load-bearing -- the whole
-- risk half of the trade is that the run home is visible. What was wrong was
-- WHO it was shown to, not that it pierced geometry. The victim keeps the
-- x-ray; the street loses the noise.
--
-- WHAT IT COSTS: A BYSTANDER CAN NO LONGER SEE A ROBBERY THROUGH A WALL.
-- `HeistService.attachLoot` argues for exactly that -- "anyone nearby can tag,
-- not just the victim. Bystanders joining the chase is the bit that turns a
-- robbery into a story." Nabbing is UNCHANGED and still open to anybody: the
-- nab prompt sits on the loot, at the same range, for everyone. What a
-- bystander loses is the x-ray, not the verb -- and they can still see a thief
-- they can actually see, who is carrying a labelled miniature of somebody
-- else's piggy bank over their head.
--
-- A MODULE, NOT A SECTION OF ClientMain, for the reason RobBadge, HouseFX,
-- HotBar and AdminPanel are: that chunk is at Luau's 200-local ceiling, and
-- the locals this wants would take the ENTIRE HUD down rather than this
-- feature -- the chunk fails to compile, nothing is built, and the error names
-- some innocent variable thousands of lines away. A module body gets its own
-- register file, so this costs ClientMain nothing: it is required and started
-- in one statement holding no local at all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)

local RobberMark = {}

-- POLLED RATHER THAN SIGNALLED, and the reason is the same one RobBadge
-- records. The set of things that can carry loot is tiny -- at most eight
-- characters and twelve resident models -- while the set of SIGNALS is not:
-- an attribute-changed connection per candidate has to be made and unmade as
-- characters respawn, residents are seated and evicted, and plots are rebuilt
-- on rebirth. Asking is free at this size and cannot go stale.
local TICK = 0.2

-- The badge floats at this many studs, breathing between the two. A pulse is
-- what makes it catch an eye that is looking at the WORLD rather than at the
-- HUD, which is the whole situation this thing exists for.
--
-- 0.8 cycles a second, comfortably under the three-flashes-a-second
-- accessibility ceiling `HouseFX` holds the whole game to -- and it is a
-- FLOAT rather than a flash, so it never crosses the luminance step that
-- ceiling is actually about.
local BOB = 0.35
local BOB_RATE = 0.8

-- Gold, which in this palette means MONEY -- and that is the right answer
-- here rather than a collision with it. Every other alert tone is about
-- danger to the person reading it (`WARN` is a refusal, `STOP` is an alarm);
-- this one is about somebody carrying COINS out of your pig, so the colour
-- says what is at stake rather than how frightened to be.
--
-- IT IS THE GLYPH THAT IS GOLD NOW, AND THERE IS NO DISC BEHIND IT. The mark
-- was an ink "!" on a gold circle, which is the shape every CHIP in this
-- game is -- and that was the fault rather than the style: a character in a
-- coloured disc reads as a HUD element that has escaped onto the street,
-- where a bare mark reads as something drawn over the world. It is also less
-- to see past. What has to carry from the pavement is one stroke of colour,
-- and a filled circle around it is area competing with the thing it frames.
local GLYPH = Theme.GOLD

-- WHITE, AND THIS IS THE ONE PLACE THAT DELIBERATELY BREAKS THE INK-OUTLINE
-- RULE. "A hard dark line round every surface" is what makes this game read
-- as drawn, and it is right for everything sitting on a card. This is not on
-- a card. It is a lone glyph over a MOVING character, seen against sunlit
-- grass, a fence, a house wall or the sky, and it has to hold against all
-- four -- so the edge cannot be dark, because ink on gold is a dark line on
-- a dark backdrop and disappears at exactly the moment somebody runs past a
-- fence. White is the far side of every one of those grounds.
--
-- `PAPER` rather than pure white so it stays on the palette's warm axis: at
-- stroke width the two are indistinguishable, and a cold white among this
-- game's warm neutrals is the tell `Theme` already warns about.
local OUTLINE = Theme.PAPER

-- One badge per carrier, keyed on the model it is over, so a thief who is
-- marked, delivers, and robs again gets one badge rather than a pile.
local marks: { [Instance]: BillboardGui } = {}

-- The part to hang it over. A player's Character and a resident's Model are
-- different rigs with different part names, so this asks for the head and
-- falls back rather than assuming either -- a mark over the wrong part is
-- still a mark, and no mark at all is the failure this replaces a Highlight
-- to avoid.
local function anchorOf(model: Instance): BasePart?
	if not model:IsA("Model") then
		return nil
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function build(model: Instance): BillboardGui?
	local anchor = anchorOf(model)
	if not anchor then
		return nil
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "RobberMark"
	gui.Adornee = anchor
	-- Sized to a "!" rather than to the disc that used to sit behind it. The
	-- glyph is narrow and tall and `TextScaled` fits to whichever axis binds
	-- first, so a SQUARE box spent most of its height on nothing and drew a
	-- smaller mark than the same pixels could carry. Taller reads bigger from
	-- the pavement at no extra width.
	gui.Size = UDim2.fromOffset(46, 62)
	gui.StudsOffsetWorldSpace = Vector3.new(0, Config.ROBBER_MARK_HEIGHT, 0)
	-- THROUGH WALLS, deliberately: see the header. The victim keeps the x-ray
	-- the old Highlight gave everybody.
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = math.huge
	-- Parented to the ADORNEE rather than to the PlayerGui, so it dies with
	-- the character or the resident it is about. A mark outliving its carrier
	-- is a "!" hanging in the air over nothing, and it is exactly what a
	-- respawn or an eviction would produce otherwise.
	gui.Parent = anchor

	local bang = Instance.new("TextLabel")
	bang.Name = "Bang"
	bang.Size = UDim2.fromScale(1, 1)
	bang.BackgroundTransparency = 1
	bang.Font = Enum.Font.FredokaOne
	bang.TextScaled = true
	bang.TextColor3 = GLYPH
	-- A PLAIN ASCII "!", never an emoji. This project's rule is that an emoji
	-- renders from the colour font and IGNORES `TextColor3` -- it would come
	-- out as a smudge here at any size, and there would be no way to recolour
	-- it. An exclamation mark needs no glyph check and no fallback.
	bang.Text = "!"
	-- Straight onto the BillboardGui: with the disc gone there is nothing
	-- left to sit between the two, and a wrapper Frame kept out of habit
	-- would be an invisible rectangle for a later UIStroke to attach itself
	-- to by accident -- which is precisely the shape this change removed.
	bang.Parent = gui

	-- ON THE GLYPH, NOT ROUND A BOX, and that distinction is the whole reason
	-- a bare "!" works at all. `ApplyStrokeMode` is left at its default
	-- `Contextual`, which on a TextLabel strokes THE CHARACTER ITSELF; the
	-- alternative, `Border`, would outline the label's invisible rectangle
	-- and put a floating white box back over the street. It is not written
	-- out explicitly BECAUSE the default is the wanted answer -- but anything
	-- editing this line should know those two words are the difference
	-- between a marked thief and a rectangle.
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = OUTLINE
	stroke.Parent = bang

	return gui
end

-- Everything that could be carrying: the players' characters, and the
-- residents standing on the plots. Rebuilt per tick rather than cached,
-- because both sets change underneath this constantly -- a respawn, a plot
-- claimed, a resident evicted -- and a cache would be a second answer to
-- "who is on the street" that can disagree with the street.
local function candidates(): { Instance }
	local out: { Instance } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			table.insert(out, character)
		end
	end
	local plots = workspace:FindFirstChild("Plots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			for _, child in ipairs(plot:GetChildren()) do
				-- Asked by ATTRIBUTE rather than by name. A resident model is
				-- called `Resident_<index>` today and this must not be the
				-- second place that knows so -- the same argument `RideSound`
				-- lost by keeping its own copy of the ride-key grammar.
				if child:IsA("Model") and child:GetAttribute(Config.CARRY_VICTIM_ATTRIBUTE) ~= nil then
					table.insert(out, child)
				end
			end
		end
	end
	return out
end

function RobberMark.start()
	local me = Players.LocalPlayer

	task.spawn(function()
		while true do
			local wanted: { [Instance]: boolean } = {}

			for _, model in ipairs(candidates()) do
				local victim = model:GetAttribute(Config.CARRY_VICTIM_ATTRIBUTE)
				-- MINE, AND NOT MY OWN ROBBERY. A thief carrying their own
				-- coins is impossible today, but the test costs nothing and
				-- the alternative is a "!" over your own head the first time
				-- anything lets you rob yourself.
				if victim == me.UserId and model ~= me.Character then
					wanted[model] = true
					if not (marks[model] and marks[model].Parent) then
						local gui = build(model)
						if gui then
							marks[model] = gui
						end
					end
				end
			end

			for model, gui in pairs(marks) do
				if not wanted[model] then
					gui:Destroy()
					marks[model] = nil
				end
			end

			task.wait(TICK)
		end
	end)

	-- The bob, on its own loop, because it runs per FRAME and the search does
	-- not. Doing both at `TICK` would give a mark that jumps four times a
	-- second instead of floating.
	RunService.Heartbeat:Connect(function()
		local t = os.clock() * BOB_RATE * math.pi * 2
		local lift = Config.ROBBER_MARK_HEIGHT + math.sin(t) * BOB
		for _, gui in pairs(marks) do
			if gui.Parent then
				gui.StudsOffsetWorldSpace = Vector3.new(0, lift, 0)
			end
		end
	end)
end

return RobberMark
