--!strict
--[[
	CatchFX

	The burst that goes off on a thief when somebody pulls the loot back out
	of their hands.

	THE FOURTH CLIENT-SIDE ANIMATOR, and it is here for the same reason the
	animated skins, the moat and `HouseFX` are: the server decides, publishes
	two attributes, and never touches it again; every client renders what it
	can see for itself. Driving it server-side would replicate a particle
	system's worth of property writes to say something one string already
	says -- and it would say it only to whoever happened to be subscribed,
	where an attribute reaches the whole street for nothing.

	IT IS A MODULE RATHER THAN A `do` BLOCK IN ClientMain, AND THAT IS THE
	200-LOCAL CEILING RATHER THAN A STYLE NOTE. That chunk has hit it eight
	times, and every time it cost the ENTIRE HUD rather than the feature being
	added -- the chunk never compiles, so nothing gets built and the error
	names an innocent variable two thousand lines away. A function body gets
	its own register file, so this whole feature costs ClientMain one local,
	and it is required and started in a single statement holding none at all.

	WHAT IT MAY NOT DO, restated here because this is the file that could
	break it:

	  * NOTHING IT BUILDS COLLIDES OR ANSWERS A QUERY. A catch effect may
	    never change an outcome, and the way that is guaranteed is that there
	    is nothing here with a body -- an Attachment, a ParticleEmitter and at
	    most a PointLight. The same rule every lawn ornament follows, and for
	    the same reason: a purchase must not be able to body-block a chase.

	  * NOTHING IT BUILDS IS ON THE SCREEN. No ScreenGui, no camera write, no
	    full-screen tint. The burst is in the WORLD at the thief's own feet,
	    so it is loudest to everybody watching and quietest to the person it
	    landed on -- which is the only arrangement that keeps a cosmetic sold
	    to one child from making another child's screen worse.

	  * IT EXPIRES WITH `Config.STUN_SECONDS`, derived rather than pinned. The
	    nab holds a thief still for exactly that long; an effect outliving it
	    would follow somebody who is already running again, which reads as a
	    tag rather than as a flourish.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local CatchFX = {}

local started = false

-- Characters this client has already wired, so a re-parent or a second
-- CharacterAdded cannot leave two listeners on one body and fire a burst
-- twice. Weak-keyed on the INSTANCE is exactly what this file must not do --
-- the engine holds a reference the Lua collector cannot see, so the entry
-- would be dropped while the character is alive -- so entries are removed
-- explicitly when the character goes.
local wired: { [Model]: boolean } = {}

-- HOW LONG THE LIGHT LIVES, and it is deliberately far shorter than the
-- particles. A PointLight is the one thing here that can be seen through a
-- wall, so it is a FLASH that says "over there, something happened" rather
-- than a lamp somebody is now standing under. The particles carry the rest.
local LIGHT_SECONDS = 0.55

local function playBurst(character: Model, key: string)
	local spec = Config.CATCH_EFFECTS[key]
	-- A burst with no particles in it is the `none` row, and it is a real
	-- member of the catalogue rather than an error: it is how a player turns
	-- a catch effect OFF. Nothing to draw, nothing to warn about.
	if not spec or not spec.texture or not spec.color then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "CatchFX"
	attachment.Parent = root

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = spec.texture
	emitter.Color = spec.color
	emitter.Speed = spec.speed
	emitter.Lifetime = spec.lifetime
	emitter.Drag = spec.drag or 0
	emitter.Acceleration = spec.accel or Vector3.zero
	emitter.SpreadAngle = Vector2.new(spec.spread or 0, spec.spread or 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.size or 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	local spin = spec.rotSpeed or 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-spin, spin)
	-- RATE ZERO, AND THE WHOLE DIFFERENCE FROM `Config.EFFECTS` IS THIS LINE.
	-- An aura is an emitter that runs forever at a rate; this is one that goes
	-- off once at a count. `Emit` is what makes it a burst, and leaving Rate
	-- above zero would turn a 12,000,000-coin one-shot into a permanent
	-- Thunderclap following somebody around the street.
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(spec.burst or 20)

	if spec.light then
		local light = Instance.new("PointLight")
		light.Color = spec.light.colour
		light.Brightness = spec.light.brightness
		light.Range = spec.light.range
		-- Off, so it cannot cast a shadow the thief has to walk out of and
		-- cannot darken anything. The same call the piggy's own coin lamp
		-- makes, and for the same measured reason.
		light.Shadows = false
		light.Parent = attachment
		TweenService:Create(light, TweenInfo.new(LIGHT_SECONDS), { Brightness = 0 }):Play()
	end

	-- THE CEILING, DERIVED FROM THE STUN IT SITS INSIDE. The longest lifetime
	-- in the catalogue is 2.2 seconds against a stun of 4, so nothing is ever
	-- cut off mid-flight -- and if the stun is ever retuned DOWN, this follows
	-- it rather than being a number somebody has to remember to move.
	Debris:AddItem(attachment, Config.STUN_SECONDS)
end

local function wire(character: Model)
	if wired[character] then
		return
	end
	wired[character] = true

	-- THE COUNTER IS WHAT IS WATCHED AND THE KEY IS WHAT IS READ, in that
	-- order, because the server writes them in that order. Watching the KEY
	-- instead would miss every repeat -- two nabs with the same effect write
	-- the same string and fire one changed signal, which is the exact trap
	-- `DodgeRoll` is a counter to avoid.
	character:GetAttributeChangedSignal(Config.CATCH_COUNT_ATTRIBUTE):Connect(function()
		local key = character:GetAttribute(Config.CATCH_ATTRIBUTE)
		if type(key) == "string" then
			playBurst(character, key)
		end
	end)

	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			wired[character] = nil
		end
	end)
end

local function follow(player: Player)
	if player.Character then
		wire(player.Character)
	end
	player.CharacterAdded:Connect(wire)
end

function CatchFX.start()
	if started then
		return
	end
	started = true

	-- EVERY PLAYER, NOT ONLY THE LOCAL ONE. A catch effect is bought to be
	-- watched by the person who fired it and by everybody standing near --
	-- wiring only `LocalPlayer` would mean the one player who cannot see
	-- their own purchase is the one who bought it.
	--
	-- `PlayerAdded` never fires for anybody already in the game when this
	-- runs, which on a client is usually every other player in the server --
	-- the trap the wheelie bin's `CharacterAdded` hook recorded. So the list
	-- is walked first and the signal only covers arrivals.
	for _, player in ipairs(Players:GetPlayers()) do
		follow(player)
	end
	Players.PlayerAdded:Connect(follow)
end

return CatchFX
