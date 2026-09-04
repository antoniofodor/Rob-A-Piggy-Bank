--!strict
--[[
	RideSound

	What a ride sounds like, and -- just as much the point -- what it stops
	sounding like.

	THE FOOTSTEPS WERE THE BUG.

	Roblox's own `RbxCharacterSounds` puts a looping `Running` sound in every
	character's HumanoidRootPart and plays it whenever the humanoid is moving
	under its own power. A rider IS moving under their own power as far as the
	Humanoid is concerned -- rides are a WalkSpeed multiplier and nothing else,
	which is the whole reason the gate can be a speed rule -- so a player on a
	skateboard doing 21 studs a second was jogging, audibly, the entire way
	down the street.

	Disabling the Animate script on mount (which RideService already does)
	does not touch this: the sounds are a separate script and a separate
	system. Nor can the server touch it, because those Sound instances are
	created on each CLIENT by a LocalScript that walks every player -- so they
	do not exist on the server at all.

	MUTE, DO NOT DESTROY, AND REMEMBER THE VALUE ON THE SOUND ITSELF.

	`RbxCharacterSounds` sets `Volume` exactly once, when it builds the sound,
	and afterwards only ever toggles `Playing`. So a volume of 0 sticks, which
	makes muting a one-property write rather than a fight. Destroying the
	sound instead would work until the script's own state machine next
	referenced it.

	The original volume is stashed as an ATTRIBUTE ON THE SOUND, not in a
	table keyed by it. A table keyed on an Instance is the trap documented at
	the top of RidePose -- weak, and the collector drops it while the engine
	still holds the object; strong, and it leaks every character that ever
	rode anything. An attribute lives and dies with the sound it describes,
	survives this module being reloaded, and cannot desync from it.

	THE LOOP IS CLIENT-SIDE, like the poses and the moat and the skins.

	Volume and pitch track speed, which means a property write per rider per
	frame. Done on the server that is a replicated write per rider per frame,
	for something every machine can work out for itself from a velocity it
	already has. So each client builds the sound, on every rider it can see.
]]

local Config = require(script.Parent.Config)

local RideSound = {}

-- The looping emitter this module owns, parented to the ride's own chassis so
-- it is positional and so it is destroyed with the model on dismount. That
-- teardown is free and total: there is no dismount path that keeps the model.
local LOOP_NAME = "RideLoop"

-- Roblox's footstep sound, and the attribute we park its volume in.
local FOOTSTEPS = "Running"
local MUTED_FROM = "RideMutedFrom"

-- WHAT IS ACTUALLY UNDER THEM, read off the mounted model rather than off the
-- published style string.
--
-- The obvious version of this looked up `Config.RIDES` by matching the
-- character's `RideStyle` attribute, and it broke within the hour: that
-- attribute is a KEY, not a style -- "bmx@onehand" once stances existed, and
-- "bmx#trick" in the pose tables -- so a plain equality test silently matched
-- nothing and every rider kept their footsteps. RidePose owns that grammar
-- and strips it correctly; a second copy here was one more thing to keep in
-- step, and it did not stay in step.
--
-- The model's own name needs no grammar. `Ride_<key>` is put there by
-- RideService when it welds the thing on, it names the ride that is really
-- mounted rather than a label describing it, and its mere presence is the
-- answer to "is this player riding" -- which is the only other question here.
local RIDE_PREFIX = "Ride_"

local function mountedRide(character: Instance): (any, BasePart?)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Model") and string.sub(child.Name, 1, #RIDE_PREFIX) == RIDE_PREFIX then
			local ride = Config.RIDES[string.sub(child.Name, #RIDE_PREFIX + 1)]
			if ride then
				return ride, child.PrimaryPart
			end
		end
	end
	return nil, nil
end

-- The engine may build these as `Sound` or, with the newer audio API enabled,
-- as `AudioPlayer`. Both carry `Volume`, and neither is worth branching on.
local function footstepsOf(character: Instance): any
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root:FindFirstChild(FOOTSTEPS) or nil
end

local function muteFootsteps(character: Instance, muted: boolean)
	local sound = footstepsOf(character)
	if not sound then
		-- RbxCharacterSounds has not built them yet. The caller polls, so
		-- this resolves itself on a later tick rather than needing a wait.
		return
	end

	if muted then
		if sound:GetAttribute(MUTED_FROM) == nil then
			sound:SetAttribute(MUTED_FROM, sound.Volume)
		end
		sound.Volume = 0
	else
		local was = sound:GetAttribute(MUTED_FROM)
		if type(was) == "number" then
			sound.Volume = was
			sound:SetAttribute(MUTED_FROM, nil)
		end
	end
end

-- Builds or removes the loop, and mutes or restores the footsteps. Cheap
-- enough to poll; it does nothing at all once the state matches.
--
-- Muting is keyed on being MOUNTED, not on there being a sound to replace it
-- with: footsteps are wrong on a skateboard whether or not a licensed roll
-- has been found for it yet. Silence is the honest failure here, the same
-- call `Config.SOUNDS.SIREN` already makes.
function RideSound.apply(character: Instance?)
	if not character then
		return
	end

	local ride, emitter = mountedRide(character)
	local spec = ride and ride.sound

	muteFootsteps(character, emitter ~= nil)

	if not emitter or not spec or spec.id == "" then
		return
	end
	if emitter:FindFirstChild(LOOP_NAME) then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = LOOP_NAME
	sound.SoundId = spec.id
	sound.Looped = true
	-- Starts silent and is faded up by update(), so a ride that appears under
	-- a stationary player does not crack.
	sound.Volume = 0
	sound.PlaybackSpeed = spec.pitch[1]
	-- THE RIDER IS ALWAYS INSIDE THIS BUBBLE, WHICH IS WHAT SPLITS THE ONE
	-- VOLUME NUMBER INTO TWO DIFFERENT LISTENERS.
	--
	-- The emitter is the chassis, welded to the rider's own body -- measured
	-- at 3.2 studs from their root. Inside RollOffMinDistance a Sound plays
	-- at its full `Volume` with no attenuation whatever, so the rider hears
	-- the raw number in Config and nothing else, permanently. Everybody else
	-- hears `Volume * min / distance`.
	--
	-- So the two are separable, which is not obvious and is the whole reason
	-- this is 14 rather than 8. Halving `Volume` to fix what the rider hears
	-- would otherwise have halved the street with it, and a Volt Scrambler
	-- you cannot hear coming is a worse game than a loud one. Raising `min`
	-- by the same factor puts the distant listener back where they were --
	-- (V/2) * (2m)/d is V*m/d -- while doing NOTHING to the rider, who was
	-- never on the falloff curve to begin with. Verified at 30 studs: 0.091
	-- before, 0.089 after.
	--
	-- Anything that changes a ride's `volume` has to decide which of those
	-- two listeners it meant.
	sound.RollOffMinDistance = 14
	sound.RollOffMaxDistance = spec.range or 70
	sound.Parent = emitter

	-- TAKES THE EDGE OFF WHAT PLAYBACKSPEED DOES TO A RECORDING, AND OFF THE
	-- RECORDING ITSELF.
	--
	-- Two different jobs, which is why the numbers live in Config now.
	--
	-- The first is the resample. PlaybackSpeed is not a pitch shift -- it has
	-- no formant-preserving algorithm, so pushing it away from 1.0 brightens
	-- the sample, and a cut in the top end is the standard fix for exactly
	-- that artifact. The further a ride is resampled the more `high` it wants.
	--
	-- The second is the SOURCE. A close-mic'd wheel recording is gritty
	-- before anything is done to it, and that grind sits in the mids -- so
	-- `mid` is the control for "this is harsh" while `high` is the control
	-- for "this is a resample". A synth drone has neither problem and gets
	-- almost nothing.
	--
	-- ONE CUT CANNOT SUIT SIX MACHINES, which is what the flat -4 was. It
	-- left the two wheel rides harsh (reported, twice) while spending the
	-- same cut on two drones that had no grit in them to remove. The default
	-- below is that old flat value, so a ride with no `eq` behaves exactly as
	-- it did before this existed.
	--
	-- EqualizerSoundEffect is free and client-side, and the bands are broadly
	-- low under ~250 Hz, mid ~250 Hz to 4 kHz, high above that. Gains are dB.
	local band = spec.eq or {}
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = "RideEQ"
	eq.LowGain = band.low or 0
	eq.MidGain = band.mid or 0
	eq.HighGain = band.high or -4
	eq.Parent = sound

	sound:Play()
end

-- Volume and pitch from how fast this rider is actually going.
--
-- Normalised against THIS RIDE'S own top speed rather than an absolute one.
-- A skateboard flat out is 21.6 studs a second and a Volt Scrambler is 33.6,
-- so a shared scale would leave the cheapest ride permanently quiet and
-- permanently low -- describing the price of the machine rather than what it
-- is doing. Each one reaches the top of its own range at its own top speed,
-- and the RANGE is what says a scrambler is quicker than a board.
function RideSound.update(character: Instance?, dt: number)
	if not character then
		return
	end
	local ride, emitter = mountedRide(character)
	local spec = ride and ride.sound
	if not spec or not emitter then
		return
	end
	local sound = emitter:FindFirstChild(LOOP_NAME) :: Sound?
	if not sound then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed = 0
	if root then
		local v = root.AssemblyLinearVelocity
		-- Flattened: falling off a kerb is not going faster.
		speed = Vector3.new(v.X, 0, v.Z).Magnitude
	end

	local top = Config.BASE_WALK_SPEED * (ride.multiplier or 1)
	local f = math.clamp(speed / math.max(top, 1), 0, 1)

	-- `idle` is what the machine makes standing still: nothing for the three
	-- that only roll, a real hum for the two that are powered. A hoverboard
	-- that goes silent when you stop is a hoverboard that has fallen over.
	local idle = spec.idle or 0
	local volume = (spec.volume or 0.3) * (idle + (1 - idle) * f)
	local pitch = spec.pitch[1] + (spec.pitch[2] - spec.pitch[1]) * f

	-- Eased rather than written. At 10Hz a stepped volume is audible as a
	-- zipper, and even per-frame the jump from a standing start is a click.
	local a = math.clamp(dt * 8, 0, 1)
	sound.Volume += (volume - sound.Volume) * a
	sound.PlaybackSpeed += (pitch - sound.PlaybackSpeed) * a
end

return RideSound
