--!strict
--[[
	PatrolBanner -- the street's own banner for a police patrol and an event.

	Two frames at one anchor rather than one frame with a branch in it. A
	patrol is the street's heartbeat and an event is the thing a session gets
	built around, and sharing a widget was flattening the one distinction that
	row exists to draw. They can never both be live -- an event suppresses the
	patrol -- so exactly one is ever visible.

	The countdown is a bar AND a number, because they answer different
	questions: a draining bar is a thing you SEE and a figure is a thing you
	READ, and this is read by somebody who is running.

	EXTRACTED FROM `ClientMain` RATHER THAN REWRITTEN. That chunk is one
	Luau chunk against the 200-local register ceiling, and reaching it
	does not cost the feature being added -- it costs the WHOLE HUD, with
	an error naming a variable thousands of lines from the cause. This
	section borrowed nothing from the rest of the file and lent nothing
	to it, measured in both directions before it moved, so every line
	below is the original and only its home changed.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Announce = require(ReplicatedStorage.Shared.Announce)
local Config = require(ReplicatedStorage.Shared.Config)
local Music = require(ReplicatedStorage.Shared.Music)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PatrolBanner = {}

--
-- Two jobs, and both of them are the same job: making the patrol PUBLISHED.
-- The banner counts down the siren and then the patrol itself, and the light
-- bar flashes. A hidden patrol would cause an identical amount of trouble
-- while turning a decision into bad luck, and bad luck is not something a
-- nine year old can get better at.
--
-- Wrapped in a function because this chunk sits near Luau's 200-local-register
-- ceiling and the whole HUD -- not just this section -- fails to build if it
-- is crossed. A function body gets its own register file, so this costs the
-- chunk one local instead of eight.
function PatrolBanner.start(gui: Instance)

	-- UNDER THE WHOLE TOP-CENTRE STACK, and that is measured rather than
	-- chosen. This column is full, and it was already the documented way to
	-- break this HUD -- the rebirth button is what covered the accessory roll
	-- button the last time something was hung up here:
	--
	--     (free)          16 .. 90
	--     rebirth         96 .. 148
	--     carry banner   140 .. 192
	--     PATROL         200 .. 238
	--
	-- The top band opened up when the coin badge merged into the piggy bank
	-- panel, and the rebirth button was deliberately NOT moved up into it:
	-- shuffling a control a player already knows the position of, to close a
	-- gap nothing is drawn in, costs more than the gap does. It is the space
	-- for whatever wants this column next.
	--
	-- The carry banner is the one that settles it. It is on screen exactly
	-- when this one is -- a thief holding loot during a pursuit -- so the two
	-- have to stack rather than share, and this goes below it.
	-- ONE WIDGET FOR BOTH, TWO INSTANCES OF IT.
	--
	-- These were two hand-built frames at one anchor -- 38 tall with ink type
	-- and a hardcoded string for the patrol, 44 with a badge and a progress
	-- groove for the event -- and the note that used to sit here argued they
	-- had to stay separate because "an event is not a patrol" and because "the
	-- patrol's row is measured and verified, and every event feature would have
	-- to keep re-clearing that".
	--
	-- THAT ARGUMENT WAS ABOUT THE GEOMETRY, AND THE GEOMETRY IS SHARED NOW. Its
	-- second half is simply gone: there is one measured row in one file, so
	-- nothing has to re-clear anything. Its first half survives and is carried
	-- by the CONTENT rather than by the frame -- a patrol is blue with a car on
	-- it, an event is its own tone with its own icon -- which is how
	-- `Config.NOTIFY` already tells nine kinds of toast apart without nine
	-- widgets.
	--
	-- STILL TWO INSTANCES RATHER THAN ONE, because that is the rule this row
	-- already keeps: two things that can never both be live share a SLOT. The
	-- exclusivity is untouched -- `EventService.isEventLive` suppresses the
	-- patrol for an event's whole length -- and hiding the loser below is the
	-- same belt and braces it always was.
	local banner = Announce.new(gui, "StreetBanner", 200)
	local eventBanner = Announce.new(gui, "EventBanner", 200)

	-- ============================================================
	-- THE STANDING COUNTDOWN
	-- ============================================================
	--
	-- ALWAYS ON SCREEN WHILE THE STREET IS QUIET, counting down to the next
	-- event. Every other alert in this game reports something that has already
	-- happened or is happening; this is the only thing on the HUD that gives a
	-- player a reason to still be here in ten minutes.
	--
	-- IT NEEDED NO NEW SERVER STATE, which is worth saying because it looks
	-- like it should. `EventService` already sets the quiet stretch as a PHASE
	-- with its own deadline -- `setPhase("quiet", "", period - warning)` -- and
	-- already pushes seconds left and, since the banner wanted it, seconds
	-- total. The client was receiving the whole countdown and dropping it on
	-- the floor, because the render branch opened with `if phase ~= "quiet"`.
	--
	-- IN THE LEFT MENU RAIL, WHICH REVERSES WHERE THIS USED TO LIVE.
	--
	-- It sat under the piggy bank panel on the argument that a standing
	-- readout belongs with the other standing readout. That was right about
	-- what KIND of thing it is and wrong about which family it joins: the
	-- top-right corner is the BALANCE, and a second paper card hanging off
	-- the same right edge saying something unrelated to the balance is what
	-- made that column read as clutter rather than as a column. The rail
	-- below Shop / Stuff / Options is where this game keeps the things that
	-- are always there and are not about money, so the countdown is drawn in
	-- that vocabulary and takes the slot the boost token used to have.
	local nextEventChip = require(ReplicatedStorage.Shared.HUDWidgets).event(gui)

	-- The server sends seconds LEFT, never a deadline: os.clock() is a
	-- different number on every machine, so a timestamp would count down from
	-- somewhere random. Same reason the dodge cooldown is pushed as a duration.
	local patrol = { phase = "quiet", endsAt = 0 }

	-- THE EVENT SHARES THIS FRAME, it does not get a second one.
	--
	-- The top-centre column is full and measured -- coins 16, rebirth 96,
	-- carry 140..192, this 200..238 -- and a fourth row lands 35% of the way
	-- down a phone held sideways. Two controls that can never both be live
	-- share a slot, which is the rule the dodge and the trick button already
	-- follow, and `EventService.isEventLive` is what makes that true here:
	-- the patrol waits out any event, so there is never a frame where both
	-- want to say something.
	--
	-- The priority below is therefore belt and braces rather than a design:
	-- if the invariant ever breaks, the bigger news wins and nothing overlaps.
	local event = { phase = "quiet", name = "", next = "", endsAt = 0, total = 0 }

	Remotes.get("EventState").OnClientEvent:Connect(function(state)
		event.phase = state.phase
		event.name = state.event or ""
		-- The event the server has already rolled for the end of this quiet
		-- stretch, so the countdown can show what it is counting down to.
		-- Empty outside the quiet, and empty on a build whose server has not
		-- been updated -- which the chip renders as the generic bell rather
		-- than as a blank tile.
		event.next = state.nextEvent or ""
		event.endsAt = os.clock() + (state.secondsLeft or 0)
		-- Guarded against zero: this divides the bar, and a phase pushed
		-- without a total would put a nan into a UDim2 rather than erroring.
		event.total = math.max(state.secondsTotal or 0, 0.01)
		-- Ducked like the patrol, and for the same reason: a raid is published
		-- ahead precisely so staying out is a choice, and music over the top
		-- of the warning takes that choice back.
		if state.phase ~= "quiet" then
			Music.duck((state.secondsLeft or 0) + 3)
		end
	end)

	Remotes.get("PoliceState").OnClientEvent:Connect(function(state)
		patrol.phase = state.phase
		patrol.endsAt = os.clock() + (state.secondsLeft or 0)

		-- THE SCORE GETS OUT OF THE WAY OF THE PATROL. The siren is published
		-- fifteen seconds ahead precisely so a robbery during one is a choice,
		-- and music over the top of it takes that choice back. Ducked for the
		-- whole phase plus a moment, so it does not swell back up between the
		-- warning and the car arriving.
		if state.phase ~= "quiet" then
			Music.duck((state.secondsLeft or 0) + 3)
		end
	end)

	-- ONE TABLE RATHER THAN TWO LOCALS, because this chunk is at Luau's
	-- 200-register ceiling and has died there twice: once allocating
	-- `dayLabel` and once allocating `buildBustScene`, both naming a
	-- variable thousands of lines from the change and both taking the
	-- WHOLE HUD rather than the feature.
	-- REQUIRED INSIDE THIS FUNCTION FOR THE SAME REASON. A require at the top
	-- level costs the chunk a register it does not have; a function body gets
	-- its own file, so the whole cue system costs the top level nothing. Same
	-- call `HouseFX`, `AdminPanel` and `Wanted` already make.
	local SoundKit = require(ReplicatedStorage.Shared.SoundKit)

	local eventCue = { phase = "", tick = nil :: number? }
	RunService.Heartbeat:Connect(function()
		-- THE STANDING COUNTDOWN, while nothing is actually happening.
		--
		-- Gated on the quiet stretch being a REAL one rather than on the phase
		-- name alone, and that is not defensive tidiness -- it is two live
		-- cases. A client that has not received its first push yet has total 0
		-- and would render "0:00" as though an event were overdue. And the
		-- scheduler stamps a two-second `setPhase("quiet", "", 2)` on the way
		-- out of an event before the loop sets the real fifteen minutes, so
		-- for up to a frame the honest reading of the pushed state is "next
		-- event in 2s". Testing the SPAN against the warning window rules out
		-- both with one comparison.
		--
		-- THE PATROL TAKES THIS WIDGET WHILE IT RUNS. The sirens, the cruise
		-- and a pursuit used to draw their own ribbon in the middle of the
		-- screen; they draw here now (below), so for those forty-odd seconds
		-- the countdown steps aside and comes back when the car has gone. The
		-- same goes for an event's warning and run.
		local quietSpan = if event.phase == "quiet" then event.total else 0
		if quietSpan > Config.EVENTS.warning then
			local left = math.max(0, event.endsAt - os.clock())
			nextEventChip.Visible = true
			require(ReplicatedStorage.Shared.HUDWidgets).renderEvent(
				nextEventChip, left, event.total, left <= Config.EVENT_SOON, event.next)
		elseif nextEventChip.Visible then
			nextEventChip.Visible = false
		end

		-- The event owns the row whenever it has anything to say. The two are
		-- mutually exclusive by construction -- an event suppresses the patrol
		-- for its whole length -- so hiding the other one here is belt and
		-- braces: if that invariant ever breaks, the bigger news wins and
		-- nothing overlaps.
		--
		-- Drawn only for an event this build has a row for. A new event with
		-- no `Config.EVENT_UI` entry falls through to the patrol rather than
		-- rendering as an unnamed grey bar, which is the louder failure and
		-- the easier one to notice.
		local ui = if event.phase ~= "quiet" then Config.eventUI(event.name) else nil
		if ui then
			local left = math.max(0, event.endsAt - os.clock())

			-- THE ALARM FIRES ON THE TRANSITION, NEVER ON THE PHASE. This
			-- block runs every frame, so testing `phase == "warning"` would
			-- play a klaxon sixty times a second; what has to be detected is
			-- the phase CHANGING, which means remembering the last one. Same
			-- shape as the crack's slice click and for the same reason -- the
			-- server pushes a state, not an event.
			--
			-- IT IS PER VIEWER AND CLIENT-SIDE, like the moat and the animated
			-- skins: the server publishes the phase and its deadline and every
			-- machine decides for itself what to play. Nothing about a cue
			-- needs to replicate.
			if event.phase ~= eventCue.phase then
				if event.phase == "warning" then
					SoundKit.ui(Config.SOUNDS.EVENT_ALARM,
						{ name = "EventCue", volume = 0.45 })
				end
				eventCue.phase = event.phase
				eventCue.tick = nil
			end

			-- THE TICK IS THE LAST FEW SECONDS AND NOT THE WHOLE WARNING.
			-- `Config.EVENT_TICK_FROM` is five against a twenty-second warning,
			-- because a tick running the whole way is a metronome nobody can
			-- switch off -- the same argument the coin drip's own comment makes
			-- about anything louder becoming nagging.
			--
			-- ONE PER WHOLE SECOND, keyed on the ceiling of what is left rather
			-- than on a timer: the countdown the player is reading and the
			-- sound they are hearing then come off the same number and cannot
			-- disagree, which is what a separate clock would eventually do.
			if event.phase == "warning" and left <= Config.EVENT_TICK_FROM then
				local second = math.ceil(left)
				if second > 0 and second ~= eventCue.tick then
					eventCue.tick = second
					SoundKit.ui(Config.SOUNDS.CLICK,
						{ name = "EventTick", volume = 0.3, pitch = 1.15 })
				end
			end
			banner:set(nil)
			-- The roster is where an event's display name lives, so it is read
			-- rather than copied into EVENT_UI beside the glyph. It is read
			-- DEFENSIVELY though: the guard above is on EVENT_UI, so a row
			-- added to one table and not the other would index a nil here and
			-- take the whole HUD loop with it.
			local entry = Config.EVENTS.roster[event.name]
			local warning = event.phase == "warning"
			-- THE TOP WIDGET CARRIES THE EVENT NOW, not a ribbon in the middle
			-- of the screen. The designer's call: every timed announcement
			-- looks like the next-event countdown, which already sits at the
			-- top out of the way. WHAT IT IS in the name, HOW LONG on the clock,
			-- unfolded, and breathing only during the warning -- a live event is
			-- a standing readout and flashing for three minutes is wallpaper.
			eventBanner:set(nil)
			nextEventChip.Visible = true
			require(ReplicatedStorage.Shared.HUDWidgets).renderStatus(nextEventChip, {
				art = event.name,
				image = ui.icon,
				name = if warning then ((entry and entry.name) or event.name) else ui.live,
				seconds = left,
				tone = ui.tone,
				alert = true,
				pulse = warning,
			})
			return
		end
		eventBanner:set(nil)

		if patrol.phase == "quiet" then
			banner:set(nil)
			return
		end

		local left = math.max(0, patrol.endsAt - os.clock())

		-- THE THREE PHASES ARE THREE ROWS IN `Config.ANNOUNCE` NOW, not three
		-- branches each writing its own colour. What that bought beyond the
		-- tidying is a palette fix: the routine cruise used to draw in the same
		-- `Theme.STOP` red as a PURSUIT, so the street's heartbeat and somebody
		-- actually being hunted were one colour. This project's own palette rule
		-- reads "blue the police", so the car going past is blue, the sirens
		-- warning of one are orange, and only a pursuit is red.
		local key = if patrol.phase == "pursuit" then "pursuit"
			elseif patrol.phase == "warning" then "sirens"
			else "patrol"
		local row = Config.announce(key)
		if not row then
			-- A phase this build has no row for draws NOTHING rather than an
			-- unnamed grey bar, which is the louder failure and the easier one
			-- to notice. Same guard the event branch above makes on EVENT_UI.
			banner:set(nil)
			return
		end
		-- THE PATROL IS IN THE TOP WIDGET TOO, for the same reason as the
		-- event above: one place, one look, out of the middle of the screen.
		-- A beacon for the sirens and a pursuit, the car for the cruise; the
		-- two loud phases breathe and the routine cruise does not, because
		-- that one is on screen for forty-five seconds and is the street's own
		-- heartbeat. Written as what DOES pulse, so a renamed third phase
		-- cannot silently turn the cruise into an alarm.
		banner:set(nil)
		nextEventChip.Visible = true
		require(ReplicatedStorage.Shared.HUDWidgets).renderStatus(nextEventChip, {
			art = if key == "patrol" then "car" else "siren",
			image = if row.icon ~= "" then row.icon else nil,
			name = if key == "pursuit" then "LOSE THEM"
				elseif key == "sirens" then "PATROL INCOMING"
				else "PATROL",
			seconds = left,
			tone = row.tone,
			alert = true,
			pulse = patrol.phase == "pursuit" or patrol.phase == "warning",
		})
	end)

	-- The light bar, driven HERE rather than on the server.
	--
	-- Same rule as the animated skins and the moat: a flash is a colour and a
	-- transparency write per lamp per frame, and replicating that would be
	-- property updates every frame to say something every machine can work out
	-- from a clock and a phase offset. The server publishes the offset once,
	-- as an attribute, and nothing else.
	--
	-- Found by tag rather than collected at startup, because the car is built
	-- when a patrol begins and destroyed when it ends -- there is nothing to
	-- collect when this runs.
	local lamps: { [BasePart]: boolean } = {}

	local function watchLamp(part: Instance)
		if part:IsA("BasePart") then
			lamps[part] = true
		end
	end

	for _, part in ipairs(CollectionService:GetTagged("PoliceLamp")) do
		watchLamp(part)
	end
	CollectionService:GetInstanceAddedSignal("PoliceLamp"):Connect(watchLamp)
	CollectionService:GetInstanceRemovedSignal("PoliceLamp"):Connect(function(part)
		lamps[part :: BasePart] = nil
	end)

	RunService.Heartbeat:Connect(function()
		for part in pairs(lamps) do
			if not part.Parent then
				lamps[part] = nil
			else
				local offset = part:GetAttribute("Phase") or 0
				local tone = part:GetAttribute("Tone") or Color3.new(1, 1, 1)
				-- A short bright blip and a long dark gap, rather than an even
				-- flash: it is what makes red and blue alternate legibly at
				-- distance instead of blurring into one mauve smear.
				local on = ((os.clock() * 2.4 + offset) % 1) < 0.32
				part.Transparency = if on then 0 else 0.72
				part.Color = if on then tone else (tone :: Color3):Lerp(Color3.new(0, 0, 0), 0.6)
			end
		end
	end)
end

return PatrolBanner
