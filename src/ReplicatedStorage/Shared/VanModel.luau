--!strict
--[[
	VanModel

	The delivery van that drives the street, built in code like everything
	else in this world.

	IT CONFERS NOTHING AND IS NOT A SECOND THING TO ROB. That is the whole
	brief. The patrol car is a hazard, the shop vaults are targets and the
	guard dog is a defence; this is traffic. Nothing on it collides, nothing
	answers a query, nothing carries a prompt, and no player can reach, call,
	buy or aim it. What it buys is that the street looks like somewhere people
	live rather than a diorama with one police car in it.

	AND IT IS THE WORLD'S EXPLANATION FOR TWO THINGS THAT ALREADY EXIST. Every
	plot has a mailbox with a flag on it and, on a seventh day, a crate on the
	doorstep -- and until now nothing in the world said where either came
	from. A post van is that answer, and it costs nothing to make: the fiction
	does not have to be wired to the mechanic to read as connected. It is
	deliberately NOT wired to it, because a van that had to arrive before a
	crate could would put a player's reward behind a timer they cannot see.

	AN ORIGINAL, NEVER A REAL POSTAL SERVICE, which is the rule the patrol car
	and the meme lawn ornaments already follow. A real operator's wordmark,
	its crest and its livery are each registered somewhere, moderation strips
	branded assets, and the penalty lands on the EXPERIENCE rather than on the
	one prop. Red and cream is a GENRE and nobody owns it; PIGGY POST over a
	snout roundel is this game's own.

	AND THE RED AND CREAM ARE THE MAILBOX'S OWN COLOURS, taken from
	`PlotService`'s box rather than chosen: a van painted like the thing on
	every lawn is the cheapest way to say the two belong together, and it
	means a repaint of one has an obvious place to follow.

	CONVENTIONS, both load-bearing and both the same as `PoliceModel`:

	  * Authored FACING +Z, so `CFrame.lookAt` needs its usual half-turn
	    afterwards -- four bugs in this project have come from forgetting it.
	  * Authored with Y = 0 AT THE GROUND, so the model can be dropped on a
	    road surface by its own origin with no per-caller fudge. `PivotTo`
	    then aims the PRIMARY PART rather than that origin, which is why
	    `VAN_PIVOT_Y` exists and is derived rather than typed.
]]

local VanModel = {}

-- The mailbox's own pair, and the flag's red. Kept as literals here rather
-- than reached for out of PlotService: this module is Shared and that one is
-- a server service, and a shared file may not require a service.
local CREAM = Color3.fromRGB(210, 205, 192)
local POST_RED = Color3.fromRGB(196, 58, 54)
local DARK = Color3.fromRGB(74, 66, 62)
local GLASS = Color3.fromRGB(96, 122, 158)
local RUBBER = Color3.fromRGB(26, 26, 30)
local CHROME = Color3.fromRGB(178, 186, 198)
local LAMP = Color3.fromRGB(252, 224, 150)

type Bone = {
	name: string,
	size: Vector3,
	offset: Vector3,
	tone: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?,
	transparency: number?,
}

-- SIZED AGAINST THE ROAD, not against a real van. `Config.ROAD_HALF_WIDTH` is
-- 8 either side of the centreline and the patrol car is 6.2 across, so 6.0
-- keeps the two comparable and leaves a van comfortably inside one lane with
-- room for the other to pass.
--
-- IT IS TALLER THAN IT IS WIDE, WHICH IS THE ENTIRE SILHOUETTE. A patrol car
-- and a delivery van built to the same box read as two cars with different
-- paint -- the four-identical-shops mistake on wheels. A high square cargo
-- body over a low stubby cab is what says VAN from the far end of the street,
-- before a colour or a word is resolved. The bore through the hills is 14
-- studs, so 6.2 of van goes through with room to spare.
--
-- THE WHEELS NEED NO ROTATION. A Roblox cylinder's axis is its X, so a
-- vehicle authored facing +Z already has its axles running along X. Written
-- the other way round a wheel becomes a disc as wide as the tyre was tall,
-- lying flat under the van -- a mistake this project has made five times, and
-- one `PoliceModel` records at this exact spot for the same reason.
local VAN: { Bone } = {
	-- Chassis first: `buildVan` treats element one as the model's anchor part,
	-- and `VAN_PIVOT_Y` is read off it.
	{ name = "Chassis", size = Vector3.new(6.0, 0.9, 12.4), offset = Vector3.new(0, 1.5, 0), tone = DARK },

	-- The cargo box, which is the shape doing the work.
	{ name = "Cargo", size = Vector3.new(6.0, 4.0, 8.0), offset = Vector3.new(0, 3.95, -2.0), tone = CREAM },
	{ name = "CargoRoof", size = Vector3.new(6.16, 0.32, 8.16), offset = Vector3.new(0, 6.05, -2.0), tone = CREAM },

	-- The cab: lower and shorter, so the box behind it reads as a load rather
	-- than as the whole vehicle.
	{ name = "Cab", size = Vector3.new(5.8, 2.7, 4.2), offset = Vector3.new(0, 3.2, 4.2), tone = CREAM },
	-- NARROWER AND HIGHER THAN THE CAB, and both by measurement rather than
	-- by eye. Authored at the cab's own width and its own floor, the two
	-- shared BOTH side planes and their bottom plane -- three coplanar
	-- surfaces running the whole length of the join, which is the strobing
	-- seam the house rebuild fixed at a hundred sites and the exact family
	-- the audit caught here.
	{ name = "Nose", size = Vector3.new(5.6, 1.1, 1.2), offset = Vector3.new(0, 2.46, 6.5), tone = CREAM },
	{ name = "Screen", size = Vector3.new(5.2, 1.5, 0.28), offset = Vector3.new(0, 3.7, 6.25), tone = GLASS, transparency = 0.35 },
	{ name = "SideGlassL", size = Vector3.new(0.24, 1.2, 2.2), offset = Vector3.new(-2.94, 3.7, 4.4), tone = GLASS, transparency = 0.35 },
	{ name = "SideGlassR", size = Vector3.new(0.24, 1.2, 2.2), offset = Vector3.new(2.94, 3.7, 4.4), tone = GLASS, transparency = 0.35 },

	-- THE RED BAND, and it is what makes a cream box read as a POST van at
	-- fifty studs. The roundel below it only resolves close up, exactly the
	-- way the patrol car's does and the vault dial's spokes do.
	--
	-- Sunk 0.06 into the flank rather than laid on it: two faces at one depth
	-- is the coplanar flicker this project has fixed at a hundred sites.
	{ name = "BandL", size = Vector3.new(0.2, 1.5, 8.06), offset = Vector3.new(-2.97, 3.3, -2.0), tone = POST_RED },
	{ name = "BandR", size = Vector3.new(0.2, 1.5, 8.06), offset = Vector3.new(2.97, 3.3, -2.0), tone = POST_RED },
	-- THE BACK DOORS, WHICH IS WHERE A DELIVERY COMES OUT OF, AND THE FIRST
	-- BUILD OF THEM WAS INVISIBLE.
	--
	-- They were two cream panels standing 0.02 proud of a cream box, on the
	-- reasoning that the SEAM between them is the tell. It is -- and a seam
	-- between two surfaces of the same colour at the same depth is not a
	-- seam, it is one surface. Photographed from behind, the rear read as a
	-- plain box with a red stripe on it and no doors at all.
	--
	-- IT IS THE MOAT'S OWN RULE ARRIVING ON A VAN: a recess is made by
	-- standing something PROUD around the dark, never by sinking the dark,
	-- because the eye takes the highest line as the surface. So the panels
	-- stand a tenth proud, the GAP between them is left open, and a dark
	-- strip sits at the bottom of that gap where a shut line would be.
	-- The seam is SHORTER than the panels either side of it and sits at its
	-- own depth: authored to the doors' own height and depth it shared their
	-- top, bottom and outer planes, which is three more of the same fault.
	{ name = "DoorSeam", size = Vector3.new(0.3, 3.2, 0.14), offset = Vector3.new(0, 3.9, -6.04), tone = DARK },
	{ name = "DoorL", size = Vector3.new(2.75, 3.4, 0.18), offset = Vector3.new(-1.48, 3.9, -6.09), tone = CREAM },
	{ name = "DoorR", size = Vector3.new(2.75, 3.4, 0.18), offset = Vector3.new(1.48, 3.9, -6.09), tone = CREAM },

	-- The band crosses the doors rather than sitting behind them, which is
	-- where paint goes. Two hundredths of a stud clear of the panel face:
	-- enough that nothing is coplanar, far too little to read as a ledge.
	{ name = "BandBack", size = Vector3.new(5.9, 1.5, 0.08), offset = Vector3.new(0, 3.3, -6.24), tone = POST_RED },

	-- Two handles either side of the shut line rather than one across it,
	-- because one bar spanning both doors says they cannot open.
	{ name = "HandleL", size = Vector3.new(0.16, 0.9, 0.16), offset = Vector3.new(-0.48, 4.5, -6.3), tone = CHROME },
	{ name = "HandleR", size = Vector3.new(0.16, 0.9, 0.16), offset = Vector3.new(0.48, 4.5, -6.3), tone = CHROME },

	{ name = "BumperFront", size = Vector3.new(6.1, 0.7, 0.8), offset = Vector3.new(0, 1.75, 6.9), tone = DARK },
	{ name = "BumperRear", size = Vector3.new(6.1, 0.7, 0.8), offset = Vector3.new(0, 1.75, -6.4), tone = DARK },

	{ name = "LampL", size = Vector3.new(1.0, 0.5, 0.3), offset = Vector3.new(-2.1, 2.5, 7.05), tone = LAMP, material = Enum.Material.Neon },
	{ name = "LampR", size = Vector3.new(1.0, 0.5, 0.3), offset = Vector3.new(2.1, 2.5, 7.05), tone = LAMP, material = Enum.Material.Neon },

	{ name = "WheelFL", size = Vector3.new(0.9, 2.3, 2.3), offset = Vector3.new(-2.95, 1.15, 4.2), tone = RUBBER, shape = Enum.PartType.Cylinder },
	{ name = "WheelFR", size = Vector3.new(0.9, 2.3, 2.3), offset = Vector3.new(2.95, 1.15, 4.2), tone = RUBBER, shape = Enum.PartType.Cylinder },
	{ name = "WheelBL", size = Vector3.new(0.9, 2.3, 2.3), offset = Vector3.new(-2.95, 1.15, -3.8), tone = RUBBER, shape = Enum.PartType.Cylinder },
	{ name = "WheelBR", size = Vector3.new(0.9, 2.3, 2.3), offset = Vector3.new(2.95, 1.15, -3.8), tone = RUBBER, shape = Enum.PartType.Cylinder },

	{ name = "HubFL", size = Vector3.new(0.94, 1.1, 1.1), offset = Vector3.new(-2.95, 1.15, 4.2), tone = CHROME, shape = Enum.PartType.Cylinder },
	{ name = "HubFR", size = Vector3.new(0.94, 1.1, 1.1), offset = Vector3.new(2.95, 1.15, 4.2), tone = CHROME, shape = Enum.PartType.Cylinder },
	{ name = "HubBL", size = Vector3.new(0.94, 1.1, 1.1), offset = Vector3.new(-2.95, 1.15, -3.8), tone = CHROME, shape = Enum.PartType.Cylinder },
	{ name = "HubBR", size = Vector3.new(0.94, 1.1, 1.1), offset = Vector3.new(2.95, 1.15, -3.8), tone = CHROME, shape = Enum.PartType.Cylinder },
}

-- HOW FAR THE ANCHOR PART SITS ABOVE THE GROUND ORIGIN, derived from the
-- table rather than written out again.
--
-- `Model:PivotTo` aims the PRIMARY PART, and this builder takes a GROUND
-- origin. Those two read as if they take the same thing and do not: driving
-- the patrol car by pivoting it to the road surface put it 1.6 studs into the
-- tarmac with its wheels half buried, for a whole release, and neither errored
-- nor looked wrong in a still. Anything that moves this model per frame has to
-- add this.
VanModel.VAN_PIVOT_Y = VAN[1].offset.Y

-- The van's overall reach forward and back from its origin, so a caller can
-- put it fully inside a tunnel bore rather than guessing at a clearance.
VanModel.HALF_LENGTH = 7.3

local function makePart(bone: Bone, into: Instance, originCF: CFrame): Part
	local p = Instance.new("Part")
	p.Name = bone.name
	p.Size = bone.size
	p.Color = bone.tone
	p.Transparency = bone.transparency or 0
	p.Material = bone.material or Enum.Material.SmoothPlastic
	p.Anchored = true
	-- NEVER SOLID, and this is the line that keeps a van from being a
	-- mechanic. A vehicle that could push a player would be a second,
	-- physical way to move somebody during a chase, and every speed in this
	-- game is calibrated on the assumption that nothing does that.
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if bone.shape then
		p.Shape = bone.shape
	end
	p.CFrame = originCF * CFrame.new(bone.offset)
	p.Parent = into
	return p
end

-- PIGGY POST beside a snout, drawn rather than built -- a print is flat and no
-- arrangement of studs holds a legible word at three studs across.
--
-- Three things the patrol car's roundel already paid for, all of which apply:
--
--   * The `Face` has to match which way the panel actually points. These are
--     FLANKS, so Left and Right -- not the Back that every street-facing sign
--     in this game uses.
--   * The panel stands clear of the geometry it decorates rather than on it,
--     so it sits just outside the red band.
--   * IT HAS TO CONTRAST WITH WHAT IS BEHIND IT. The band is red, so the
--     lettering is cream: the patrol car shipped its own roundel in navy on a
--     navy stripe first and it was unreadable from the pavement.
local function decal(van: Model, originCF: CFrame, side: number, face: Enum.NormalId)
	local panel = Instance.new("Part")
	panel.Name = "Roundel"
	panel.Size = Vector3.new(0.08, 1.42, 7.2)
	panel.Transparency = 1
	panel.Anchored = true
	panel.CanCollide = false
	panel.CanQuery = false
	panel.CanTouch = false
	panel.CastShadow = false
	panel.Material = Enum.Material.SmoothPlastic
	panel.CFrame = originCF * CFrame.new(side * 3.12, 3.3, -2.0)
	panel.Parent = van

	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	-- Capped for the reason the shop plaques are: eight of these legible from
	-- anywhere on a 350-stud street is a wall of text over the world.
	gui.MaxDistance = 160
	gui.Parent = panel

	local snout = Instance.new("Frame")
	snout.Size = UDim2.new(0, 52, 0, 52)
	snout.Position = UDim2.new(0, 14, 0.5, -26)
	snout.BackgroundColor3 = Color3.fromRGB(246, 176, 198)
	snout.BorderSizePixel = 0
	snout.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = snout

	for _, x in ipairs({ 15, 31 }) do
		local nostril = Instance.new("Frame")
		nostril.Size = UDim2.new(0, 6, 0, 12)
		nostril.Position = UDim2.new(0, x, 0.5, -6)
		nostril.BackgroundColor3 = Color3.fromRGB(196, 112, 140)
		nostril.BorderSizePixel = 0
		nostril.Parent = snout
		local r = Instance.new("UICorner")
		r.CornerRadius = UDim.new(1, 0)
		r.Parent = nostril
	end

	local word = Instance.new("TextLabel")
	word.Size = UDim2.new(0, 260, 0, 46)
	word.Position = UDim2.new(0, 78, 0.5, -23)
	word.BackgroundTransparency = 1
	word.Font = Enum.Font.FredokaOne
	-- Cream, because the band behind it is red. See the note above.
	word.TextColor3 = CREAM
	word.TextScaled = true
	word.TextXAlignment = Enum.TextXAlignment.Left
	word.Text = "PIGGY POST"
	word.Parent = gui
end

export type Van = {
	model: Model,
	body: Part,
}

function VanModel.buildVan(originCF: CFrame, parent: Instance): Van
	local model = Instance.new("Model")
	model.Name = "DeliveryVan"

	local body: Part? = nil
	for _, bone in ipairs(VAN) do
		local p = makePart(bone, model, originCF)
		if not body then
			body = p
		end
	end
	local chassis = assert(body, "VAN must define at least the chassis")

	decal(model, originCF, -1, Enum.NormalId.Left)
	decal(model, originCF, 1, Enum.NormalId.Right)

	model.PrimaryPart = chassis
	model.Parent = parent
	return { model = model, body = chassis }
end

return VanModel
