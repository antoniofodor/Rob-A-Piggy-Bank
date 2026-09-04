--!strict
--[[
	Music

	The background score, and the two rules that keep it from being the thing
	players mute the game to escape.

	IT PLAYS ONCE AND THEN STOPS FOR A WHILE.

	A looping track is the mistake, however good the track is. Nothing here
	loops: a cue plays through, the street goes quiet for a minute or two, and
	then a different cue starts. That silence is not a gap in the feature, it
	IS the feature -- it is what stops a nine-year-old hearing the same eight
	bars four hundred times in a session, and it is why `Config.MUSIC.TRACKS`
	holds long production cues rather than short loops.

	IT MUST NEVER COVER THE SIREN.

	The patrol is published on purpose: the siren sounds fifteen seconds before
	the car appears so that robbing during a patrol is a decision rather than
	bad luck, and bad luck is not something a nine-year-old can get better at.
	Music loud enough to bury that quietly undoes the design. So anything that
	needs to be heard calls `duck`, and the score drops under it.

	The sharper version of the same argument is why the volume is low and why
	there is a toggle at all: a player who mutes the game because of the music
	also mutes the siren, the dog and the ride they paid for. Losing the score
	is fine. Losing the soundscape with it is not.

	CLIENT-SIDE AND SINGLETON, unlike anything else in Shared.

	Music is per-listener -- one player's preference cannot be another's -- so
	there is nothing here to replicate and nothing for the server to own. A
	Sound parented to SoundService plays flat and global on this machine only.
]]

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Music = {}

-- One table rather than eight loose upvalues, the same shape the HUD's own
-- sections use: this module is small now and the state is the part that grows.
local state = {
	enabled = false,
	started = false,
	sound = nil :: Sound?,
	startedAt = 0,
	nextAt = 0,
	duckUntil = 0,
	-- Indices not yet drawn this cycle. See `draw`.
	bag = {} :: { number },
	last = 0,
}

-- A SHUFFLED BAG, not a random pick.
--
-- Drawing at random independently means the same cue can come up twice in a
-- row and another can go unheard for an hour. Drawing WITHOUT replacement
-- means every track is heard once before any is heard twice, which is the
-- same shape as the accessory roll refusing to return something you already
-- own -- and for the same reason: a guaranteed spread is what a player
-- actually wants from something that is nominally random.
--
-- Refilling excludes whatever just played, so the seam between one bag and
-- the next cannot produce a repeat either. That is the case the obvious
-- version misses.
local function draw(): { id: string, name: string }?
	local tracks = Config.MUSIC.TRACKS
	if #tracks == 0 then
		return nil
	end
	if #state.bag == 0 then
		for i = 1, #tracks do
			if i ~= state.last or #tracks == 1 then
				table.insert(state.bag, i)
			end
		end
	end
	local at = math.random(1, #state.bag)
	local index = state.bag[at]
	table.remove(state.bag, at)
	state.last = index
	return tracks[index]
end

local function gap(): number
	local range = Config.MUSIC.GAP
	return range[1] + math.random() * (range[2] - range[1])
end

local function stopNow()
	if state.sound then
		state.sound:Destroy()
		state.sound = nil
	end
end

local function startNext()
	local track = draw()
	if not track or track.id == "" then
		-- No licensed id yet. Ships silent rather than shipping a placeholder,
		-- the same call Config.SOUNDS.SIREN makes.
		state.nextAt = os.clock() + gap()
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. track.name
	sound.SoundId = track.id
	sound.Looped = false
	-- Silent on arrival and faded up by step(), so a track never cracks in.
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()

	state.sound = sound
	state.startedAt = os.clock()
end

-- POLLED, NEVER SLEPT THROUGH.
--
-- The gap between cues runs to nearly two minutes, and a flat `task.wait` of
-- that length is a state machine that ignores the world -- the exact bug the
-- guard dog's patrol pause turned out to be. Muting during a gap, or a duck
-- landing mid-fade, has to be noticed now rather than whenever the sleep
-- happens to expire.
local function step(dt: number)
	local music = Config.MUSIC
	local sound = state.sound

	-- Where the volume WANTS to be, this frame.
	local target = 0
	if state.enabled and sound then
		target = music.VOLUME
		if os.clock() < state.duckUntil then
			target *= music.DUCK
		end
	end

	if sound then
		-- HOW FAST depends on WHY it is moving, and the three reasons want
		-- three different speeds. A track fading in or out is musical and
		-- takes its time; a duck is reacting to something already making
		-- noise; and a mute is a button somebody just pressed, which has to
		-- feel like a mute rather than like a slow leak -- at the musical
		-- rate it was still audible five seconds after the press, measured.
		local seconds = music.FADE
		if not state.enabled then
			seconds = music.OFF_FADE
		elseif os.clock() < state.duckUntil then
			seconds = music.DUCK_FADE
		end
		local a = math.clamp(dt / math.max(seconds, 0.01), 0, 1)
		sound.Volume += (target - sound.Volume) * a

		-- FINISHED, OR NEVER STARTED. Both end the same way, on purpose: an
		-- id that fails to load leaves IsPlaying false forever, and without
		-- the grace window that would silently end the music for the session
		-- rather than moving on to the next cue.
		local alive = os.clock() - state.startedAt
		if not sound.IsPlaying and alive > 3 then
			stopNow()
			state.nextAt = os.clock() + gap()
		elseif not state.enabled and sound.Volume < 0.005 then
			-- Faded out under a toggle. Dropped rather than paused: coming
			-- back should be a fresh cue, not the middle of the one that was
			-- playing when they switched it off.
			--
			-- A SHORT wait, not a full gap. The gap is what follows a cue that
			-- FINISHED; a cue that was cut off never earned one, and pressing
			-- play and getting up to two minutes of nothing reads as a broken
			-- button rather than as restraint.
			stopNow()
			state.nextAt = os.clock() + music.RESUME_DELAY
		end
		return
	end

	if state.enabled and os.clock() >= state.nextAt then
		startNext()
	end
end

-- Turns the score on or off. The OFF path fades rather than cutting, which
-- costs a couple of seconds and is the difference between a setting and a
-- glitch.
function Music.setEnabled(on: boolean)
	if on == state.enabled then
		return
	end
	state.enabled = on
	if on and not state.sound then
		-- Never PULLS the next cue forward, only pushes it back. That one
		-- word is what lets this be the same call on joining and on a button
		-- press: the join path has already scheduled START_DELAY and keeps
		-- it, while a press made much later finds a deadline in the past and
		-- gets the short resume instead.
		state.nextAt = math.max(state.nextAt, os.clock() + Config.MUSIC.RESUME_DELAY)
	end
end

function Music.isEnabled(): boolean
	return state.enabled
end

-- Drops the score for `seconds`, for anything that has to be heard over it.
-- Extends an existing duck rather than replacing it, so two overlapping
-- events cannot leave the music coming back up during the second one.
function Music.duck(seconds: number)
	state.duckUntil = math.max(state.duckUntil, os.clock() + seconds)
end

function Music.start()
	if state.started then
		return
	end
	state.started = true
	state.nextAt = os.clock() + Config.MUSIC.START_DELAY
	RunService.Heartbeat:Connect(step)
end

return Music
