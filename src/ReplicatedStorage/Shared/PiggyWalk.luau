--!strict
--[[
	PiggyWalk

	A roaming herd piggy WALKS instead of sliding, and DIGS when it stops.
	The server drives every member's placement with `PivotTo` on anchored
	minis (HerdService); this module, on each client, lays a waddle over
	that placement -- a bob, a sway, a nod and a rear swing about the
	animal's own feet -- so the thing the server slides across the grass
	reads as something walking across it. And when the server says a member
	is digging, it lays the dig over the same feet: a nose-down scratch, a
	burst of dirt, a coin that pops up and fades. Visual only.

	-------------------------------------------------------------------
	WHY A WHOLE-MODEL WADDLE AND NOT LEGS.
	-------------------------------------------------------------------

	A herd mini is `PiggyModel.build`: a `Body` MeshPart, ONE merged `Trim`
	(ears, snout, legs and tail welded into a single mesh) and two `Eye`s.
	There is no leg to swing and no ear to flap -- `PiggyIdle` records the
	same measurement. And a MeshPart built at run time by
	`CreateMeshPartAsync` does not deform under bones (measured twice), so
	the only route to real legs is an IMPORTED skinned rig, which is a manual
	upload under the developer's own account. That rig is prepared in
	`blender/pig/anim/` and not taken; what ships is the rigid curve baked
	out of the same Blender cycle, which needs no asset and works live.

	-------------------------------------------------------------------
	DRIVEN BY DISTANCE, NEVER BY A CLOCK -- the officer's rule.
	-------------------------------------------------------------------

	`HerdService` publishes `Config.HERD_WALK_ATTRIBUTE` on each member: the
	studs it has walked since it was built. The stride PHASE is that number
	divided by the stride length, so a piggy that stops mid-step stops
	mid-step, one that hurries steps in proportion, and the animation cannot
	desync from the motion it depicts because it IS a function of it. The
	only clock here decides how fast the waddle FADES when the attribute
	stops changing, so a grazing piggy settles rather than freezing tilted.

	-------------------------------------------------------------------
	THE DIG IS DRIVEN BY SERVER TIME, AND IT LAYERS ON THE WALK.
	-------------------------------------------------------------------

	The server sets `Config.HERD_DIG_ATTRIBUTE` to `GetServerTimeNow()` when
	a member starts digging and clears it when the dig ends
	(`Config.HERDS.dig`). The dig PHASE is `(now - stamp) / dig.seconds` on
	that same clock, so every client is on the same frame of the same dig
	and the coin pops at the same instant on every screen. A digging member
	does not move and `Walked` does not advance, so the waddle fades out on
	its own and the dig pose lands on a still base -- the two are SUMMED,
	each under its own amplitude, and written by the one `place` below.
	Two writers on one CFrame a frame is the bug this file exists not to
	have, so there is exactly one `PreRender` poser and the dig is inside it.

	THE BEATS ARE SCANNED, NOT TIMED. The clip rows in `Config.PIGGY_DIG`
	carry `dirt` and `coin` marks; each frame the phase the client last saw
	and the phase it sees now are handed to `Config.piggyDigBeats`, which
	returns what was crossed. So a client at ten frames a second throws the
	same dirt as one at sixty, a client that first sees a dig already past
	the coin never pops one, and a culled piggy advances its phase without
	firing anything.

	THE NOSE IS CLAMPED AGAINST THE GROUND EVERY FRAME. The clip is authored
	in body radii and degrees; `Config.piggyDigMaxPitch` solves the largest
	nose-down pitch that keeps the measured nose above the captured foot
	plane at this frame's lift, and the sampled pitch is clamped to it. The
	suite holds the clip under it for the mini; the clamp is what holds it
	on a body the clip was not authored for.

	THE COIN IS A POOL, NOT A PART PER PIGGY. `Config.PIGGY_DIG.coin.pool`
	gold discs for the whole client, handed out at the recoil beat and
	returned when they fade; with the pool empty the beat is skipped. The
	dirt is one emitter per model, built lazily on the Body the first time
	that model digs in range, fired as a burst per stroke, and destroyed
	with the model. A member caught mid-dig releases its coin on the same
	`Destroying` hook that forgets it.

	-------------------------------------------------------------------
	THE BASE IS THE SERVER'S OWN PLACEMENT, AND IT HAS TO BE TOLD APART
	FROM THIS MODULE'S.
	-------------------------------------------------------------------

	`Model.WorldPivot` is NOT replicated, so the client cannot read the
	pivot the server moved. What replicates is every part's CFrame, and
	this module overwrites those same parts. So the Body's CFrame is read
	each frame and compared against the value this module last wrote: if it
	differs, the server moved the animal and that is the new base; if it
	matches, it is this module's own pose and the base stands. Every other
	part is placed off the base through the rest offset captured on first
	sight, which also makes a mini MORE rigid than raw replication -- a
	part whose update lands a frame late is put where the body says.

	IT RUNS ON `PreRender`, and that is load-bearing rather than a choice.
	Incoming replication is applied AFTER Heartbeat, so a pose written there
	is overwritten before the next render on every frame an update lands
	-- a walking piggy would flicker between posed and unposed. Written
	just before the render, after replication, it does not. (`PiggyIdle`
	can use Heartbeat because nothing moves its displays but itself.)

	-------------------------------------------------------------------
	THE RULES IT KEEPS
	-------------------------------------------------------------------

	  * NOTHING ACCUMULATES. Every frame is composed from the server's base
	    and rest offsets captured once, so a server up for a week cannot
	    walk a piggy off its own feet.
	  * THE FEET STAY PLANTED. The pose pivots about the FOOT PLANE, not the
	    body centre -- a roll about the centre swings the feet sideways.
	  * NOTHING IS RESIZED and nothing collides; it is CFrame writes only
	    on the piggy, and the coin and the dirt have no body of their own.
	  * FOUND BY NAME, NEVER BY TAG, for the shop-door reason: a tag set
	    before parenting never fires its added signal on the peer.
	  * CULLED BY CAMERA DISTANCE, the walk and the dig by the SAME `far`.
	    A six-degree sway across the street is not a thing anybody can see,
	    and neither is a half-stud coin.
	  * ONE STATEMENT IN ClientMain, holding no local.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)

local PiggyWalk = {}

-- Names this module is coupled to, stated so the coupling greps. The folder
-- and the model name are `HerdService.ensureFolder` / `buildMember`'s.
local FOLDER_NAME = "Herds"
local MODEL_NAME = "HerdPiggy"
local BODY_NAME = "Body"
-- What this module builds of its own, so a probe can find it.
local DIRT_NAME = "DigDirt"
local COIN_FOLDER_NAME = "PiggyDigCoins"
local COIN_NAME = "DigCoin"

type Piece = { part: BasePart, rest: CFrame }
type Coin = {
	part: BasePart,
	-- Nil while the coin is in the pool.
	startedAt: number?,
	origin: CFrame,
}
type Entry = {
	model: Model,
	seenAt: number,
	-- Filled on capture, after the model has had a beat to replicate whole.
	body: BasePart?,
	pieces: { Piece },
	base: CFrame,
	lastWritten: CFrame?,
	-- Undoes the mesh body's half turn, so the pose axes are the MODEL's
	-- (+Z snout, +Y up) whichever way the part itself is authored.
	unturn: CFrame,
	-- The foot plane, below the body centre, in the model frame.
	footY: number,
	radius: number,
	walked: number,
	walkedAt: number,
	amp: number,
	posed: boolean,
	-- THE DIG. The server's stamp (server seconds) or nil; the dig pose's
	-- own amplitude, so a cleared stamp fades rather than snaps; the phase
	-- last scanned for beats, nil until the first frame of a dig; the last
	-- sampled pose, held while fading out; the dirt emitter, built lazily;
	-- and the coin this piggy has in the air, if any.
	digStamp: number?,
	digAmp: number,
	digSeen: number?,
	digLift: number,
	digPitch: number,
	digRoll: number,
	dirt: ParticleEmitter?,
	coin: Coin?,
}

-- NOT a weak table: the collector cannot see the DataModel's reference to an
-- Instance, and a dropped entry would re-capture a rest pose off a body that
-- is mid-waddle. `RidePose` and `PiggyIdle` both record that failure.
local live: { [Model]: Entry } = {}

-- The coin pool, for the whole client. Parts are made on demand up to
-- `Config.PIGGY_DIG.coin.pool` and never beyond it.
local coins: { Coin } = {}
local coinFolder: Folder? = nil

-- Two CFrames are "the same write" when they agree to well under anything
-- the pose ever adds. A position match alone is not enough: at rest the
-- pose is a pure rotation of zero size, so the vectors are compared too.
local function sameWrite(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 1e-3
		and a.LookVector:Dot(b.LookVector) > 0.999999
		and a.UpVector:Dot(b.UpVector) > 0.999999
end

-- ============================================================
-- THE COIN POOL
-- ============================================================

local function parkCoin(coin: Coin)
	coin.startedAt = nil
	coin.part.Transparency = 1
end

local function ensureCoinFolder(): Folder
	if coinFolder and coinFolder.Parent then
		return coinFolder
	end
	local f = Instance.new("Folder")
	f.Name = COIN_FOLDER_NAME
	f.Parent = Workspace
	coinFolder = f
	return f
end

-- A free coin, or nil when every one in the pool is in the air. The pool
-- is filled lazily so a client that never watches a dig owns no parts.
local function takeCoin(): Coin?
	for _, coin in ipairs(coins) do
		if not coin.startedAt and coin.part.Parent then
			return coin
		end
	end
	local spec = Config.PIGGY_DIG.coin
	if #coins >= spec.pool then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = COIN_NAME
	-- A cylinder's axis is its X, so the disc's face points along X and a
	-- spin about Y turns the face past the viewer: a coin flipping.
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(spec.thickness, spec.size, spec.size)
	part.Color = Theme.GOLD
	-- SmoothPlastic and not Metal, which shades this gold to olive.
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	part.Massless = true
	part.Transparency = 1
	part.Parent = ensureCoinFolder()
	local coin: Coin = { part = part, startedAt = nil, origin = CFrame.identity }
	table.insert(coins, coin)
	return coin
end

-- Pops a coin at `origin` (world; +Y up). Returns it, or nil if the pool
-- was empty -- in which case the beat is simply skipped.
local function popCoin(origin: CFrame): Coin?
	local coin = takeCoin()
	if not coin then
		return nil
	end
	coin.origin = origin
	coin.startedAt = os.clock()
	coin.part.CFrame = origin
	coin.part.Transparency = 0
	return coin
end

-- One frame of every coin in the air: rise fast then hang (an ease-out),
-- spin about the vertical, fade late. Back to the pool at the end.
local function stepCoins(now: number)
	local spec = Config.PIGGY_DIG.coin
	for _, coin in ipairs(coins) do
		local startedAt = coin.startedAt
		if startedAt then
			local t = (now - startedAt) / spec.seconds
			if t >= 1 or not coin.part.Parent then
				parkCoin(coin)
			else
				local up = 1 - (1 - t) * (1 - t)
				local yaw = t * spec.seconds * spec.spin * math.pi * 2
				coin.part.CFrame = coin.origin * CFrame.new(0, spec.rise * up, 0) * CFrame.Angles(0, yaw, 0)
				coin.part.Transparency = t * t
			end
		end
	end
end

-- ============================================================
-- THE DIRT
-- ============================================================

-- The emitter on this piggy's Body, built the first time it is asked for.
-- Placed in the MODEL frame through `unturn`, so the flecks come from just
-- ahead of the snout whichever way the mesh part itself is authored.
local function ensureDirt(entry: Entry): ParticleEmitter?
	if entry.dirt and entry.dirt.Parent then
		return entry.dirt
	end
	local body = entry.body
	if not body then
		return nil
	end
	local spec = Config.PIGGY_DIG.dirt
	local attachment = Instance.new("Attachment")
	attachment.Name = DIRT_NAME
	attachment.CFrame = entry.unturn * CFrame.new(0, spec.at.y * entry.radius, spec.at.z * entry.radius)
	attachment.Parent = body

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = DIRT_NAME
	emitter.Color = ColorSequence.new(spec.colour)
	-- Dirt, not an effect: lit by the scene, no glow.
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Speed = NumberRange.new(spec.speed.min, spec.speed.max)
	emitter.Lifetime = NumberRange.new(spec.lifetime.min, spec.lifetime.max)
	emitter.SpreadAngle = Vector2.new(spec.spread, spec.spread)
	emitter.Acceleration = Vector3.new(0, -spec.gravity, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.size),
		NumberSequenceKeypoint.new(1, spec.size * 0.6),
	})
	emitter.Rotation = NumberRange.new(0, 360)
	-- A burst per stroke, never a rate: nothing emits between strokes, and
	-- a piggy nobody can see emits nothing at all.
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = attachment
	entry.dirt = emitter
	return emitter
end

-- ============================================================
-- THE ENTRIES
-- ============================================================

local function forget(model: Model)
	local entry = live[model]
	if entry and entry.coin then
		-- A member caught mid-dig takes its coin with it rather than
		-- leaving one hanging over the grass where nothing stands.
		parkCoin(entry.coin)
	end
	live[model] = nil
end

local function register(inst: Instance)
	if not inst:IsA("Model") or inst.Name ~= MODEL_NAME or live[inst] then
		return
	end
	local model = inst :: Model
	local entry: Entry = {
		model = model,
		seenAt = os.clock(),
		body = nil,
		pieces = {},
		base = CFrame.identity,
		lastWritten = nil,
		unturn = CFrame.identity,
		footY = 0,
		radius = 1,
		walked = 0,
		walkedAt = -math.huge,
		amp = 0,
		posed = false,
		digStamp = nil,
		digAmp = 0,
		digSeen = nil,
		digLift = 0,
		digPitch = 0,
		digRoll = 0,
		dirt = nil,
		coin = nil,
	}
	local function readWalked()
		local v = model:GetAttribute(Config.HERD_WALK_ATTRIBUTE)
		if type(v) == "number" and v ~= entry.walked then
			entry.walked = v
			entry.walkedAt = os.clock()
		end
	end
	readWalked()
	-- A member that already has distance on it when this client first sees
	-- it is mid-walk, not fresh: it should not read as moving until the
	-- number actually moves again.
	entry.walkedAt = -math.huge
	model:GetAttributeChangedSignal(Config.HERD_WALK_ATTRIBUTE):Connect(readWalked)

	local function readDig()
		local v = model:GetAttribute(Config.HERD_DIG_ATTRIBUTE)
		local stamp = if type(v) == "number" then v else nil
		if stamp ~= entry.digStamp then
			entry.digStamp = stamp
			-- A new dig scans its beats from wherever the phase is when it
			-- is first seen; a cleared one has nothing left to scan.
			entry.digSeen = nil
		end
	end
	readDig()
	model:GetAttributeChangedSignal(Config.HERD_DIG_ATTRIBUTE):Connect(readDig)

	model.Destroying:Once(function()
		forget(model)
	end)
	live[model] = entry
end

-- Capture the rest pose: every part's offset from the Body, the foot plane
-- and the radius. Called once, on the first frame after the settle window,
-- so the whole model has replicated and nothing here has been posed yet.
local function capture(entry: Entry): boolean
	local body = entry.model:FindFirstChild(BODY_NAME)
	if not body or not body:IsA("BasePart") then
		return false
	end
	local base = body.CFrame
	-- The mesh body carries the importer's half turn (`Config.PIGGY_MESH`);
	-- the primitives fallback is an unrotated Ball. The class says which.
	local unturn = CFrame.identity
	if body:IsA("MeshPart") then
		for _, row in ipairs(Config.PIGGY_MESH) do
			if row.part == BODY_NAME and row.rot then
				unturn = (row.rot :: CFrame):Inverse()
			end
		end
	end
	local modelFrame = base * unturn
	local footY = math.huge
	local pieces: { Piece } = {}
	for _, d in ipairs(entry.model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(pieces, { part = d, rest = base:ToObjectSpace(d.CFrame) })
			-- The lowest thing is the feet, on both branches. Size.Y is the
			-- vertical extent on every part here: the only rotation any of
			-- them carries is about Y.
			local bottom = modelFrame:PointToObjectSpace(d.Position).Y - d.Size.Y / 2
			if bottom < footY then
				footY = bottom
			end
		end
	end
	if #pieces == 0 or footY == math.huge then
		return false
	end
	entry.body = body
	entry.base = base
	entry.unturn = unturn
	entry.footY = footY
	entry.radius = math.max(body.Size.X / 2, 0.05)
	entry.pieces = pieces
	return true
end

-- THE ONE WRITER. Every part CFrame this module ever sets is set here.
local function place(entry: Entry, motion: CFrame)
	-- The foot point, in the model's own axes. The pose is applied THERE,
	-- as a world-space transform about that point, on top of the server's
	-- rigid placement of every part.
	local foot = entry.base * entry.unturn * CFrame.new(0, entry.footY, 0)
	local world = foot * motion * foot:Inverse()
	for _, piece in ipairs(entry.pieces) do
		piece.part.CFrame = world * entry.base * piece.rest
	end
	entry.lastWritten = world * entry.base
end

-- A point in the model frame (radii from the body centre) on the POSED
-- body, in world space: where the snout actually is this frame.
local function modelPoint(entry: Entry, y: number, z: number): CFrame
	local body = entry.lastWritten or entry.base
	return body * entry.unturn * CFrame.new(0, y * entry.radius, z * entry.radius)
end

-- ============================================================
-- START
-- ============================================================

function PiggyWalk.start()
	if not RunService:IsClient() then
		return
	end

	local function watchFolder(folder: Instance)
		for _, child in ipairs(folder:GetChildren()) do
			register(child)
		end
		folder.ChildAdded:Connect(register)
	end
	-- The folder is made lazily by the server on the first spawn, which may
	-- be before or after this client arrived. Both are covered: whatever is
	-- there now, and whatever lands later.
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		watchFolder(existing)
	end
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == FOLDER_NAME and child ~= existing then
			existing = child
			watchFolder(child)
		end
	end)

	local walk = Config.PIGGY_WALK
	local dig = Config.PIGGY_DIG
	RunService.PreRender:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local now = os.clock()
		-- The dig's clock is the server's, read once a frame: every client
		-- samples the same dig at the same phase.
		local serverNow = Workspace:GetServerTimeNow()
		local digSeconds = Config.HERDS.dig.seconds

		stepCoins(now)

		for model, entry in pairs(live) do
			-- Dropped here as well as on `Destroying`: a model reparented
			-- out rather than destroyed never fires that signal.
			if not model.Parent then
				forget(model)
				continue
			end
			if not entry.body then
				if now - entry.seenAt < walk.settle or not capture(entry) then
					continue
				end
			end
			local body = entry.body :: BasePart

			-- THE BASE. Anything that is not this module's own last write is
			-- the server having moved the animal.
			local cf = body.CFrame
			if not entry.lastWritten or not sameWrite(cf, entry.lastWritten) then
				entry.base = cf
				entry.lastWritten = nil
			end

			-- THE DIG PHASE, before the cull: a piggy out of range still
			-- advances its scan point, so coming back into range does not
			-- fire every beat it missed at once.
			local digStamp = entry.digStamp
			local u = -1
			if digStamp and digSeconds > 0 then
				-- Floored at 0: a stamp that lands a hair ahead of this
				-- client's synced clock is the first frame, not no dig.
				u = math.max(0, (serverNow - digStamp) / digSeconds)
			end

			if (entry.base.Position - eye).Magnitude > walk.far then
				if u >= 0 then
					entry.digSeen = u
				end
				continue
			end

			-- AMPLITUDE: on while the distance is moving, easing off once it
			-- stops. The phase itself never comes from this clock.
			local moving = now - entry.walkedAt < walk.hold
			local target = if moving then 1 else 0
			local rate = if moving then walk.fadeIn else walk.fadeOut
			local step = if rate > 0 then dt / rate else 1
			entry.amp = entry.amp + math.clamp(target - entry.amp, -step, step)

			-- THE DIG'S AMPLITUDE: full while the stamp stands (the clip
			-- carries its own ease in and out), fading at the walk's own
			-- rate once it is cleared, so a dig the server cuts short
			-- settles rather than snaps.
			local digging = u >= 0
			local dtarget = if digging then 1 else 0
			local drate = if digging then walk.fadeIn else walk.fadeOut
			local dstep = if drate > 0 then dt / drate else 1
			entry.digAmp = entry.digAmp + math.clamp(dtarget - entry.digAmp, -dstep, dstep)

			if digging then
				-- THE BEATS, scanned over the phase crossed since last frame.
				local seen = entry.digSeen
				if seen ~= nil then
					local flecks, coin = Config.piggyDigBeats(seen, u)
					if flecks > 0 then
						local emitter = ensureDirt(entry)
						if emitter then
							emitter:Emit(flecks)
						end
					end
					if coin and not entry.coin then
						entry.coin = popCoin(modelPoint(entry, dig.coin.at.y, dig.coin.at.z))
					end
				end
				entry.digSeen = u

				local lift, pitch, roll = Config.piggyDigSample(u)
				-- THE GROUND. The nose may never go through it, whatever
				-- the clip says and whatever body this is on.
				local footDepth = -entry.footY / entry.radius
				pitch = math.min(pitch, Config.piggyDigMaxPitch(lift, footDepth))
				entry.digLift, entry.digPitch, entry.digRoll = lift, pitch, roll
			end
			if entry.coin and not entry.coin.startedAt then
				entry.coin = nil
			end

			if entry.amp <= 0.002 and entry.digAmp <= 0.002 then
				if entry.posed then
					-- Put every part back exactly where the server has it.
					place(entry, CFrame.identity)
					entry.posed = false
				end
				continue
			end

			-- THE POSE: the walk and the dig SUMMED about the same foot,
			-- each under its own amplitude, and written once.
			local stride = Config.piggyWalkStride(entry.radius)
			local su = if stride > 0 then (entry.walked / stride) % 1 else 0
			local wLift, wPitch, wRoll, wYaw = Config.piggyWalkSample(su)
			local a, d = entry.amp, entry.digAmp
			local motion = CFrame.new(0, (wLift * a + entry.digLift * d) * entry.radius, 0)
				* CFrame.Angles(
					math.rad(wPitch * a + entry.digPitch * d),
					math.rad(wYaw * a),
					math.rad(wRoll * a + entry.digRoll * d))
			place(entry, motion)
			entry.posed = true
		end
	end)
end

return PiggyWalk
