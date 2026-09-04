--!strict
--[[
	PoliceModel

	The patrol car and the officer who gets out of it, built in code like
	everything else in this world.

	AN ORIGINAL, NEVER A REAL FORCE. This is the same rule the meme lawn
	ornaments follow and it matters more here, because a police car is the one
	prop somebody is most tempted to make accurate. A real force's wordmark,
	its crest and its chequered banding are each registered somewhere, Roblox
	moderation strips branded assets, and the penalty lands on the EXPERIENCE
	rather than on the one model -- an unshippable game is a steep price for a
	livery. What actually carries "police car" is the LAYOUT: a light bar, a
	two-tone body, a roundel on the door. A layout is a genre, not a property.
	So this one says PATROL over a snout roundel, in the game's own colours,
	and reads correctly from across the street.

	NOTHING HERE IS A WEAPON, and that is a shipping requirement rather than a
	taste one. The officer has no belt kit, no baton and no cuffs; the catch is
	a tag, exactly like a guard dog's. Roblox's maturity questionnaire is
	answered by what is actually in the model, and every one of those props
	would answer it differently for an under-12 audience.

	CONVENTIONS, both of which are load-bearing:

	  * Everything is authored FACING +Z, the same as the guard dog and the
	    mini piggy, so `CFrame.lookAt` needs its usual half-turn afterwards.
	  * Everything is authored with Y = 0 AT THE GROUND, the same as the
	    rides, so a model can be dropped on a road surface by its own origin
	    with no per-caller fudge.
]]

local CollectionService = game:GetService("CollectionService")

local PoliceModel = {}

-- Tagged so the client can find the lamps and flash them itself. The server
-- publishes nothing per frame here: the flash is a colour and a transparency
-- write per lamp per frame, which is exactly the shape of work the animated
-- skins and the moat already do client-side rather than replicate.
PoliceModel.LAMP_TAG = "PoliceLamp"

local NAVY = Color3.fromRGB(28, 42, 84)
local SHELL = Color3.fromRGB(238, 242, 250)
local TRIM = Color3.fromRGB(52, 74, 132)
local GLASS = Color3.fromRGB(96, 122, 158)
local RUBBER = Color3.fromRGB(26, 26, 30)
local CHROME = Color3.fromRGB(178, 186, 198)
local GOLD = Color3.fromRGB(238, 194, 72)
local SKIN = Color3.fromRGB(226, 178, 140)
local HIVIS = Color3.fromRGB(246, 206, 74)

type Bone = {
	name: string,
	size: Vector3,
	offset: Vector3,
	tone: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?,
	transparency: number?,

	-- Set on the pieces that swing when the officer runs. `hinge` is the Y
	-- the piece pivots about, in the officer's own authored space (y=0 at the
	-- ground) -- the shoulder at 4.00, the hip at 2.00. `swing` is the signed
	-- amplitude in radians, and the sign is what puts the left arm forward
	-- with the RIGHT leg, which is the difference between a run and a
	-- pantomime horse.
	hinge: number?,
	swing: number?,

	-- A foot: it TRAVELS with the swing but never tilts, and it is what the
	-- body's height is measured against. Both halves of that are load-bearing
	-- -- see poseOfficer.
	foot: boolean?,
}

-- ============================================================
-- THE CAR
-- ============================================================
--
-- Sized against the road, which is ROAD_HALF_WIDTH 8 either side of the
-- centreline: 6.2 across leaves a car comfortably inside one lane with room
-- to pass another on the far side, and 13 long is about a plot's driveway.
--
-- The wheels are the place this file could most easily go wrong. A Roblox
-- cylinder's axis is its X AXIS, so `Size.X` is the length along the axle and
-- the other two are the cross-section. A car authored facing +Z has its axles
-- running along X already, which means a wheel here needs NO rotation at all
-- -- written the other way round it becomes a disc as wide as the tyre was
-- tall, lying flat under the car. That mistake has now been made five times
-- in this project; this is the one place it is free to avoid.
local CAR: { Bone } = {
	-- Body first: `build` treats element one as the model's anchor part.
	{ name = "Body", size = Vector3.new(6.2, 1.0, 12.4), offset = Vector3.new(0, 1.6, 0), tone = SHELL },
	{ name = "Skirt", size = Vector3.new(6.0, 0.55, 11.4), offset = Vector3.new(0, 1.05, 0), tone = NAVY },
	{ name = "Bonnet", size = Vector3.new(5.8, 0.5, 3.6), offset = Vector3.new(0, 2.2, 4.4), tone = SHELL },
	{ name = "Boot", size = Vector3.new(5.8, 0.5, 2.8), offset = Vector3.new(0, 2.2, -4.8), tone = SHELL },

	-- The two-tone. A dark band along the flank at door height is what makes
	-- a white car read as a patrol car at fifty studs; the roundel below only
	-- resolves close up, the same way the vault dial's spokes do.
	{ name = "FlankL", size = Vector3.new(0.22, 0.9, 7.2), offset = Vector3.new(-3.12, 1.62, -0.3), tone = NAVY },
	{ name = "FlankR", size = Vector3.new(0.22, 0.9, 7.2), offset = Vector3.new(3.12, 1.62, -0.3), tone = NAVY },

	{ name = "Cabin", size = Vector3.new(5.0, 1.5, 5.4), offset = Vector3.new(0, 3.05, -0.5), tone = GLASS, transparency = 0.35 },
	{ name = "Roof", size = Vector3.new(5.1, 0.35, 5.5), offset = Vector3.new(0, 3.95, -0.5), tone = SHELL },
	{ name = "Pillar", size = Vector3.new(5.05, 1.55, 0.3), offset = Vector3.new(0, 3.05, -3.2), tone = SHELL },

	{ name = "BumperFront", size = Vector3.new(6.3, 0.75, 0.8), offset = Vector3.new(0, 1.55, 6.4), tone = CHROME },
	{ name = "BumperRear", size = Vector3.new(6.3, 0.75, 0.8), offset = Vector3.new(0, 1.55, -6.4), tone = CHROME },

	{ name = "WheelFL", size = Vector3.new(0.9, 2.3, 2.3), offset = Vector3.new(-2.95, 1.15, 3.9), tone = RUBBER, shape = Enum.PartType.Cylinder },
	{ name = "WheelFR", size = Vector3.new(0.9, 2.3, 2.3), offset = Vector3.new(2.95, 1.15, 3.9), tone = RUBBER, shape = Enum.PartType.Cylinder },
	{ name = "WheelBL", size = Vector3.new(0.9, 2.3, 2.3), offset = Vector3.new(-2.95, 1.15, -3.9), tone = RUBBER, shape = Enum.PartType.Cylinder },
	{ name = "WheelBR", size = Vector3.new(0.9, 2.3, 2.3), offset = Vector3.new(2.95, 1.15, -3.9), tone = RUBBER, shape = Enum.PartType.Cylinder },

	{ name = "HubFL", size = Vector3.new(0.94, 1.1, 1.1), offset = Vector3.new(-2.95, 1.15, 3.9), tone = CHROME, shape = Enum.PartType.Cylinder },
	{ name = "HubFR", size = Vector3.new(0.94, 1.1, 1.1), offset = Vector3.new(2.95, 1.15, 3.9), tone = CHROME, shape = Enum.PartType.Cylinder },
	{ name = "HubBL", size = Vector3.new(0.94, 1.1, 1.1), offset = Vector3.new(-2.95, 1.15, -3.9), tone = CHROME, shape = Enum.PartType.Cylinder },
	{ name = "HubBR", size = Vector3.new(0.94, 1.1, 1.1), offset = Vector3.new(2.95, 1.15, -3.9), tone = CHROME, shape = Enum.PartType.Cylinder },

	{ name = "LightBar", size = Vector3.new(3.8, 0.3, 1.05), offset = Vector3.new(0, 4.28, 0.5), tone = RUBBER },

	{ name = "HeadlampL", size = Vector3.new(1.2, 0.55, 0.35), offset = Vector3.new(-1.9, 2.32, 6.45), tone = Color3.fromRGB(255, 248, 224), material = Enum.Material.Neon },
	{ name = "HeadlampR", size = Vector3.new(1.2, 0.55, 0.35), offset = Vector3.new(1.9, 2.32, 6.45), tone = Color3.fromRGB(255, 248, 224), material = Enum.Material.Neon },
	{ name = "TailL", size = Vector3.new(1.1, 0.45, 0.35), offset = Vector3.new(-2.0, 2.4, -6.45), tone = Color3.fromRGB(226, 72, 64), material = Enum.Material.Neon },
	{ name = "TailR", size = Vector3.new(1.1, 0.45, 0.35), offset = Vector3.new(2.0, 2.4, -6.45), tone = Color3.fromRGB(226, 72, 64), material = Enum.Material.Neon },
}

-- The two flashing lamps, kept out of CAR because they are tagged and the
-- rest are not.
local LAMPS = {
	{ name = "LampRed", offset = Vector3.new(-1.0, 4.6, 0.5), tone = Color3.fromRGB(232, 62, 58), phase = 0 },
	{ name = "LampBlue", offset = Vector3.new(1.0, 4.6, 0.5), tone = Color3.fromRGB(58, 122, 246), phase = 0.5 },
}

-- ============================================================
-- THE OFFICER
-- ============================================================
--
-- Blocky and round-headed, matching the rest of the world, and deliberately
-- unthreatening: a big cap, a hi-vis sash and nothing on the belt. They are
-- the punchline of the patrol, not a menace.
--
-- THE GAIT. Arms swing much harder than legs, and that asymmetry is the whole
-- look: an arm has nothing to collide with, so it can windmill, while a leg
-- has to end up on the ground.
--
-- THE FEET DO NOT TILT. This is the one thing here that was got wrong first
-- and measured second. Swinging the shoe with its leg looks obviously right
-- and is not: a shoe is 1.4 studs long, and turning that much geometry 40
-- degrees dips its toe far below the sole line -- measured at 0.45 studs
-- THROUGH the grass at full stride, which no amount of dropping the body
-- fixes, because the sink scales with the shoe's LENGTH rather than the leg's.
-- A flat foot has no such term, it is what a blocky cartoon run looks like
-- anyway, and it stays exactly where the leg puts it: rotating a fixed point
-- about a fixed hinge preserves distance, so the foot cannot drift off the
-- ankle no matter how hard the leg swings.
--
-- Declared above the table that reads them. A `local` declared after its
-- reader silently becomes a nil global in Luau, and this project has lost
-- three bugs to exactly that.
local ARM_SWING = math.rad(64)
local LEG_SWING = math.rad(40)
local HIP_Y = 2.0

-- Radians of stride per stud travelled, so the legs are driven by DISTANCE
-- rather than by a clock. That is what makes the animation unable to desync
-- from the movement it depicts: an officer standing still has its legs
-- together by construction, with no "am I moving" test anywhere, and one
-- slowed or sped up would step in proportion without being told. At 1.05 a
-- full cycle is six studs, which at 14.5 studs a second is about five steps
-- a second -- fast, and meant to be.
local STRIDE_PER_STUD = 1.05
local OFFICER: { Bone } = {
	-- Torso first: it is the anchor part and the one everything else hangs off.
	{ name = "Torso", size = Vector3.new(2.2, 2.1, 1.15), offset = Vector3.new(0, 3.05, 0), tone = NAVY },
	{ name = "Sash", size = Vector3.new(2.26, 0.45, 1.21), offset = Vector3.new(0, 3.4, 0), tone = HIVIS },
	{ name = "Belt", size = Vector3.new(2.26, 0.35, 1.21), offset = Vector3.new(0, 2.15, 0), tone = RUBBER },
	{ name = "Badge", size = Vector3.new(0.42, 0.5, 0.14), offset = Vector3.new(-0.62, 3.85, 0.63), tone = GOLD },

	-- A hand carries its arm's hinge and its arm's swing, not its own: it is
	-- on the end of the limb, so it has to travel through the same arc from
	-- the same shoulder or it detaches and orbits. Same for a shoe.
	{ name = "LegL", size = Vector3.new(0.9, 2.0, 0.95), offset = Vector3.new(-0.6, 1.0, 0), tone = TRIM, hinge = HIP_Y, swing = -LEG_SWING },
	{ name = "LegR", size = Vector3.new(0.9, 2.0, 0.95), offset = Vector3.new(0.6, 1.0, 0), tone = TRIM, hinge = HIP_Y, swing = LEG_SWING },
	{ name = "ShoeL", size = Vector3.new(0.98, 0.4, 1.4), offset = Vector3.new(-0.6, 0.2, 0.22), tone = RUBBER, hinge = HIP_Y, swing = -LEG_SWING, foot = true },
	{ name = "ShoeR", size = Vector3.new(0.98, 0.4, 1.4), offset = Vector3.new(0.6, 0.2, 0.22), tone = RUBBER, hinge = HIP_Y, swing = LEG_SWING, foot = true },

	{ name = "ArmL", size = Vector3.new(0.72, 1.9, 0.9), offset = Vector3.new(-1.46, 3.05, 0), tone = NAVY, hinge = 4.0, swing = ARM_SWING },
	{ name = "ArmR", size = Vector3.new(0.72, 1.9, 0.9), offset = Vector3.new(1.46, 3.05, 0), tone = NAVY, hinge = 4.0, swing = -ARM_SWING },
	{ name = "HandL", size = Vector3.new(0.74, 0.5, 0.92), offset = Vector3.new(-1.46, 1.85, 0), tone = SKIN, hinge = 4.0, swing = ARM_SWING },
	{ name = "HandR", size = Vector3.new(0.74, 0.5, 0.92), offset = Vector3.new(1.46, 1.85, 0), tone = SKIN, hinge = 4.0, swing = -ARM_SWING },

	{ name = "Head", size = Vector3.new(1.6, 1.5, 1.5), offset = Vector3.new(0, 4.85, 0), tone = SKIN },
	-- Proud of the face, never flush with it. Two coplanar faces give the
	-- renderer nothing to sort by and it picks per pixel -- which is exactly
	-- how the guard dog's eyes came to flicker through its own head.
	{ name = "EyeL", size = Vector3.new(0.3, 0.32, 0.12), offset = Vector3.new(-0.4, 5.0, 0.76), tone = Color3.fromRGB(24, 24, 30) },
	{ name = "EyeR", size = Vector3.new(0.3, 0.32, 0.12), offset = Vector3.new(0.4, 5.0, 0.76), tone = Color3.fromRGB(24, 24, 30) },
	{ name = "Smile", size = Vector3.new(0.7, 0.14, 0.12), offset = Vector3.new(0, 4.55, 0.76), tone = Color3.fromRGB(148, 92, 72) },

	{ name = "CapCrown", size = Vector3.new(1.7, 0.6, 1.6), offset = Vector3.new(0, 5.85, 0), tone = NAVY },
	{ name = "CapBand", size = Vector3.new(1.74, 0.22, 1.64), offset = Vector3.new(0, 5.6, 0), tone = SHELL },
	{ name = "CapPeak", size = Vector3.new(1.6, 0.18, 0.8), offset = Vector3.new(0, 5.58, 1.05), tone = RUBBER },
	{ name = "CapBadge", size = Vector3.new(0.42, 0.42, 0.14), offset = Vector3.new(0, 5.86, 0.82), tone = GOLD },
}

-- ============================================================
-- BUILD
-- ============================================================
--
-- THE TWO Y CONVENTIONS IN THIS FILE ARE DIFFERENT, AND MIXING THEM SINKS
-- WHATEVER YOU ARE MOVING BY THE HEIGHT OF ITS OWN ANCHOR PART.
--
--   * `buildCar` / `buildOfficer` and `poseOfficer` take a GROUND origin.
--     Every bone is offset up from it, so a car handed the road surface
--     stands on the road.
--   * `Model:PivotTo` takes the PRIMARY PART's CFrame, which is the first
--     bone in each table and sits well above the ground -- the car's body at
--     1.6, the officer's torso at 3.05.
--
-- Only the CAR is moved with PivotTo now; the officer is posed part by part
-- so its limbs can swing, which sidesteps the trap entirely for that half.
--
-- Measured, both of them: driving the car by pivoting to the road surface put
-- it 1.6 studs into the tarmac with its wheels half buried, and easing the
-- officer's pivot toward the thief's FEET converged its torso on foot level
-- and left it walking with its shins through the lawn at -2.55.
--
-- So anything that moves one of these per frame must add the offset below.
-- Derived from the tables rather than written out again, so a change to the
-- geometry cannot silently leave a magic number behind.
PoliceModel.CAR_PIVOT_Y = CAR[1].offset.Y

local function makePart(bone: Bone, into: Instance, originCF: CFrame): Part
	local p = Instance.new("Part")
	p.Name = bone.name
	p.Size = bone.size
	p.Color = bone.tone
	p.Transparency = bone.transparency or 0
	p.Material = bone.material or Enum.Material.SmoothPlastic
	p.Anchored = true
	-- Never solid. A vehicle that could push a player would be a second,
	-- physical way to move somebody around during a chase, and every speed in
	-- this game is calibrated on the assumption that nothing does that.
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if bone.shape then
		p.Shape = bone.shape
	end
	p.CFrame = originCF * CFrame.new(bone.offset)
	p.Parent = into
	return p
end

-- The door roundel: PATROL beside a snout, drawn rather than built.
--
-- A print is flat and no arrangement of studs holds a legible word at three
-- studs across. Three things have bitten and all three apply here:
--
--   * The Face has to match which way the panel actually points. These are
--     the car's FLANKS, so Right and Left -- not the Back that every
--     street-facing sign in this game uses.
--   * The panel has to stand clear of the geometry it decorates, so it sits
--     just outside the flank stripe (which reaches x 3.23) rather than on it.
--   * IT HAS TO CONTRAST WITH WHAT IS BEHIND IT. Drawn first in navy, which
--     is right for a white car and wrong for this one: the flank stripe IS
--     navy, so the lettering came out dark on dark and was unreadable from
--     the pavement. White on the navy band is the version that reads -- and
--     it is the genre's own layout besides, which is the whole reason a
--     layout is safe to borrow where a wordmark is not.
--
-- Sized to the stripe rather than to the door: the band runs y 1.17 to 2.07,
-- so a panel any taller than that hangs off it into the white bodywork above
-- and the glass, and the print stops looking like it was applied to anything.
local function decal(car: Model, originCF: CFrame, side: number, face: Enum.NormalId)
	local panel = Instance.new("Part")
	panel.Name = "Roundel"
	panel.Size = Vector3.new(0.08, 0.86, 6.4)
	panel.Transparency = 1
	panel.Anchored = true
	panel.CanCollide = false
	panel.CanQuery = false
	panel.CanTouch = false
	panel.CFrame = originCF * CFrame.new(side * 3.28, 1.62, -0.3)
	panel.Parent = car

	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.MaxDistance = 140
	gui.Parent = panel

	local snout = Instance.new("Frame")
	snout.Size = UDim2.new(0, 42, 0, 42)
	snout.Position = UDim2.new(0, 10, 0.5, -21)
	snout.BackgroundColor3 = Color3.fromRGB(246, 176, 198)
	snout.BorderSizePixel = 0
	snout.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = snout

	for _, x in ipairs({ 12, 25 }) do
		local nostril = Instance.new("Frame")
		nostril.Size = UDim2.new(0, 5, 0, 10)
		nostril.Position = UDim2.new(0, x, 0.5, -5)
		nostril.BackgroundColor3 = Color3.fromRGB(196, 112, 140)
		nostril.BorderSizePixel = 0
		nostril.Parent = snout
		local r = Instance.new("UICorner")
		r.CornerRadius = UDim.new(1, 0)
		r.Parent = nostril
	end

	local word = Instance.new("TextLabel")
	word.Size = UDim2.new(0, 150, 0, 40)
	word.Position = UDim2.new(0, 60, 0.5, -20)
	word.BackgroundTransparency = 1
	word.Font = Enum.Font.FredokaOne
	-- White, because the band behind it is navy. See the note above.
	word.TextColor3 = SHELL
	word.TextScaled = true
	word.TextXAlignment = Enum.TextXAlignment.Left
	word.Text = "PATROL"
	word.Parent = gui
end

export type Car = {
	model: Model,
	body: Part,
	lamps: { Part },
	siren: Sound,
}

function PoliceModel.buildCar(originCF: CFrame, parent: Instance): Car
	local model = Instance.new("Model")
	model.Name = "PatrolCar"

	local body: Part? = nil
	for _, bone in ipairs(CAR) do
		local p = makePart(bone, model, originCF)
		p.CastShadow = false
		if not body then
			body = p
		end
	end
	local chassis = assert(body, "CAR must define at least the body")

	local lamps: { Part } = {}
	for _, spec in ipairs(LAMPS) do
		local p = makePart({
			name = spec.name,
			size = Vector3.new(1.6, 0.55, 0.95),
			offset = spec.offset,
			tone = spec.tone,
			material = Enum.Material.Neon,
		}, model, originCF)
		p.CastShadow = false
		p:SetAttribute("Phase", spec.phase)
		p:SetAttribute("Tone", spec.tone)
		CollectionService:AddTag(p, PoliceModel.LAMP_TAG)
		table.insert(lamps, p)
	end

	decal(model, originCF, -1, Enum.NormalId.Left)
	decal(model, originCF, 1, Enum.NormalId.Right)

	local siren = Instance.new("Sound")
	siren.Name = "Siren"
	siren.Looped = true
	siren.Volume = 0.4
	siren.RollOffMaxDistance = 260
	siren.RollOffMode = Enum.RollOffMode.InverseTapered
	siren.Parent = chassis

	model.PrimaryPart = chassis
	model.Parent = parent
	return { model = model, body = chassis, lamps = lamps, siren = siren }
end

export type Piece = {
	part: Part,
	offset: Vector3,
	hinge: number?,
	swing: number?,
	foot: boolean?,
}

export type Officer = {
	model: Model,
	body: Part,
	plate: TextLabel,
	pieces: { Piece },
}

function PoliceModel.buildOfficer(originCF: CFrame, parent: Instance): Officer
	local model = Instance.new("Model")
	model.Name = "Officer"

	local body: Part? = nil
	local pieces: { Piece } = {}
	for _, bone in ipairs(OFFICER) do
		local p = makePart(bone, model, originCF)
		table.insert(pieces, {
			part = p, offset = bone.offset, hinge = bone.hinge,
			swing = bone.swing, foot = bone.foot,
		})
		if not body then
			body = p
		end
	end
	local torso = assert(body, "OFFICER must define at least the torso")

	local head = model:FindFirstChild("Head") :: Part

	-- The tell. Same reasoning as the guard dog's collar: a state nobody can
	-- see is a state players will assume is broken, and a thief needs to read
	-- "this one is after ME" from across the street rather than by testing it.
	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.new(0, 132, 0, 32)
	plate.StudsOffset = Vector3.new(0, 2.2, 0)
	plate.AlwaysOnTop = true
	plate.MaxDistance = 200
	plate.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = NAVY
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(240, 246, 255)
	label.TextScaled = true
	label.Text = "PATROL"
	label.Parent = plate
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	model.PrimaryPart = torso
	model.Parent = parent
	return { model = model, body = torso, plate = label, pieces = pieces }
end

-- Places every part of the officer for one frame: `groundCF` is where the
-- feet are and which way the body faces, `stride` is how far it has run in
-- total.
--
-- THIS IS ON THE SERVER, and that looks like a violation of the rule that
-- sends the animated skins and the moat to the client. It is not, and the
-- reason is worth keeping: `Model:PivotTo` ALREADY writes every descendant's
-- CFrame every frame -- all twenty-two of them -- so posing the limbs
-- individually replicates exactly what dragging the model rigidly did. The
-- cost is zero, and there is at most one officer alive at a time for at most
-- thirty seconds. The client alternative is worse than free: the server owns
-- this position because the catch depends on it, so a client-side swing would
-- be overwritten by the server's next write, every frame, forever. The skins
-- rule is about work multiplied by twelve plots and running always; this is
-- one model, briefly, writing properties it was writing anyway.
--
-- Rebuilt from the authored offsets each time rather than nudged from the
-- last pose, so a dropped frame cannot accumulate into drift.
function PoliceModel.poseOfficer(officer: Officer, groundCF: CFrame, stride: number)
	local wave = math.sin(stride * STRIDE_PER_STUD)

	-- Where a piece sits, in body space, before the body has been dropped.
	local function swung(piece: Piece): CFrame
		-- The joint's Z is the BODY CENTRE, never the piece's own. A shoe is
		-- authored 0.22 forward (it is a foot, it points somewhere), and
		-- taking Z from the piece hung it on a hinge 0.22 in front of the hip
		-- its own leg swings from -- two limbs on two different arcs, which
		-- measured as 0.119 studs of the ankle pulling apart mid-stride. Its X
		-- does not matter, since a rotation about X leaves X alone, but the
		-- shoulder genuinely is out at the side so it is left honest.
		local joint = Vector3.new(piece.offset.X, piece.hinge :: number, 0)
		return CFrame.new(joint)
			* CFrame.Angles(wave * (piece.swing :: number), 0, 0)
			* CFrame.new(piece.offset - joint)
	end

	-- PASS ONE: plant the feet.
	--
	-- Swinging a leg about the hip raises the foot on the end of it, so the
	-- body has to come down by however much the LOWER foot rose or the
	-- officer runs on tiptoe above the grass. Measured off the feet
	-- themselves rather than computed from the swing angle: the first version
	-- derived it from the leg and was wrong by the length of a shoe. This
	-- version cannot be wrong about geometry it is reading.
	--
	-- It is also where the bob comes from, free and always exactly right --
	-- the body is tallest as the legs pass and lowest as they split, which is
	-- what a run looks like. Raise LEG_SWING and the bounce follows.
	-- Seeded at infinity, NOT at zero. Both feet rise when the legs split --
	-- cosine does not care which way a leg went -- so a zero seed is always
	-- the minimum and the body never comes down at all: measured as a flat
	-- 3.050 torso with the soles hovering 0.42 studs over the grass.
	local rise = math.huge
	for _, piece in ipairs(officer.pieces) do
		if piece.foot and piece.hinge and piece.swing then
			rise = math.min(rise, swung(piece).Position.Y - piece.offset.Y)
		end
	end
	if rise == math.huge then
		rise = 0
	end

	-- Down by however far the LOWER foot rose, which plants that one and
	-- leaves the other in the air -- which is what a stride is.
	local base = groundCF * CFrame.new(0, -rise, 0)

	-- PASS TWO: place everything.
	for _, piece in ipairs(officer.pieces) do
		if piece.hinge and piece.swing then
			if piece.foot then
				-- Travels with the leg, but stays flat. Taking the position
				-- out of the swung CFrame and discarding its rotation is the
				-- whole trick, and distance is preserved by the rotation, so
				-- the foot cannot come off the ankle.
				piece.part.CFrame = base * CFrame.new(swung(piece).Position)
			else
				-- About the JOINT, never about the limb's own centre: a part
				-- turned on its middle scissors through the body instead of
				-- swinging from the shoulder.
				piece.part.CFrame = base * swung(piece)
			end
		else
			piece.part.CFrame = base * CFrame.new(piece.offset)
		end
	end
end

return PoliceModel
