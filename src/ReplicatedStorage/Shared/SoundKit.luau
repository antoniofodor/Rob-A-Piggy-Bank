--!strict
--[[
	SoundKit -- one-shot sounds, in one place.

	WHY THIS EXISTS AT ALL: three server services and three client surfaces all
	needed the same eight lines -- build a Sound, point it at an id, play it
	once, clean it up -- and writing those eight lines six times is the
	near-identical duplicate this project keeps recording as the thing that
	drifts the first time either copy is touched. `GuardDog.play` and
	`PiggyBank.addSound` are deliberately NOT replaced by this: both hold a
	Sound for the life of the model because they fire it repeatedly on the same
	object, which is a different job from a one-shot at a moment.

	AN EMPTY ID IS A NO-OP AND NEVER AN ERROR, which is the rule every sound
	player in this game already keeps and the reason `Config.SOUNDS.SIREN` was
	able to ship as "" for as long as it did. A missing sound has to degrade to
	silence, because the alternative is that one unreplaceable asset takes down
	the feature it belongs to -- and every id in `Config.SOUNDS` is a
	third-party asset that can be moderated away without warning.

	IT DOES NOT DECIDE ANYTHING. No cooldowns, no throttling, no "is this
	player nearby" -- those are questions the caller already has the answer to,
	and a sound helper that starts making them is a second place gameplay
	lives.
]]

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local SoundKit = {}

export type Opts = {
	volume: number?,
	pitch: number?,
	distance: number?,
	name: string?,
}

-- Long enough that nothing in this game is cut off, short enough that a
-- forgotten Sound cannot accumulate. Every cue here is under three seconds.
local MAX_LIFE = 12

local function finish(sound: Sound)
	-- ENDED **AND** A DEBRIS BACKSTOP, because `Ended` never fires for a
	-- sound that failed to load -- which is exactly the case a moderated
	-- asset produces, and exactly the case where a leak would go unnoticed.
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, MAX_LIFE)
end

--[[
	A one-shot AT a part, positional, so the street hears it from where it
	happened. Prefer this wherever the caller already holds the thing the
	sound is about -- a thief's root, the fence segment that shocked
	somebody, the character that caught a plunger. No part is created and
	there is nothing to clean up but the Sound itself.
]]
function SoundKit.on(part: BasePart?, id: string?, opts: Opts?): Sound?
	if not part or not id or id == "" then
		return nil
	end

	local o = opts or {}
	local sound = Instance.new("Sound")
	sound.Name = o.name or "OneShot"
	sound.SoundId = id
	sound.Volume = o.volume or 0.5
	sound.PlaybackSpeed = o.pitch or 1
	sound.RollOffMaxDistance = o.distance or 90
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = part
	sound:Play()
	finish(sound)
	return sound
end

--[[
	A one-shot at a POSITION, for the callers that have no part to hang it on.

	THIS EXISTS BECAUSE A RESIDENT HAS NO BODY, and that is the whole
	justification for creating a part here when `.on` deliberately does not.
	`HeistService`'s target type is `Player | Resident`, and a Resident's
	figure is OPTIONAL decoration -- if it fails to build, the plot still
	works and the neighbour is simply not standing there. So the only handle
	every target is guaranteed to have is a Vector3, and a gadget landing on
	a neighbour has to make the same noise as one landing on a person.

	The emitter is anchored, non-colliding and non-query, which is the rule
	every decorative part in this game already keeps: it sits on ground a
	chase runs across, so it may never body-block anybody or eat a raycast
	meant for a piggy. It is destroyed with its Sound.
]]
function SoundKit.at(position: Vector3?, id: string?, opts: Opts?): Sound?
	if not position or not id or id == "" then
		return nil
	end

	local emitter = Instance.new("Part")
	emitter.Name = "SoundEmitter"
	emitter.Size = Vector3.new(0.2, 0.2, 0.2)
	emitter.Position = position
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.CastShadow = false
	emitter.Transparency = 1
	emitter.Parent = workspace

	local sound = SoundKit.on(emitter, id, opts)
	if not sound then
		emitter:Destroy()
		return nil
	end

	-- The emitter outlives the Sound by nothing: `.on` already destroys the
	-- Sound on Ended with a Debris backstop, and the part follows on the
	-- same backstop rather than waiting for a signal that may never fire.
	Debris:AddItem(emitter, MAX_LIFE)
	return sound
end

--[[
	A one-shot with no position -- a UI cue, heard flat by the one player it is
	about. Parented to SoundService, which is where the notification voices
	already live.

	THIS IS THE ONE TO REACH FOR ON A CLIENT SURFACE, and the distinction is
	the same one the chase alert already draws: a bark on the dog falls off
	with distance, which is right for the street and useless for the person
	being chased, so they hear their own copy flat.
]]
function SoundKit.ui(id: string?, opts: Opts?): Sound?
	if not id or id == "" then
		return nil
	end

	local o = opts or {}
	local sound = Instance.new("Sound")
	sound.Name = o.name or "Cue"
	sound.SoundId = id
	sound.Volume = o.volume or 0.4
	sound.PlaybackSpeed = o.pitch or 1
	sound.Parent = SoundService
	sound:Play()
	finish(sound)
	return sound
end

return SoundKit
