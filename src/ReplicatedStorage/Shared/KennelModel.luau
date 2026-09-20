--!strict
-- Kennel geometry and palette shared by the lawn model and asset previews.
-- Colors always come from the current guardian; legacy skins are dormant.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local GuardRig = require(ReplicatedStorage.Shared.GuardRig)

local KennelModel = {}

-- Kennel geometry remains separate from the imported guard rig.
KennelModel.BONES = {
	{ name = "Base", size = Vector3.new(6.20, 0.50, 6.60), offset = Vector3.new(0, 0.25, 0), tone = "trim" },
	{ name = "Floor", size = Vector3.new(5.30, 0.40, 5.44), offset = Vector3.new(0, 0.66, 0), tone = "wood" },
	-- NO TWO OF THESE SHARE A FACE PLANE, and every one of the differences is
	-- deliberate rather than spare. Sized to match -- which is the obvious way
	-- to build a box -- the floor, the back wall and both side walls agree on
	-- their side planes and their tops, which is four coplanar pairs on an
	-- object twelve plots carry.
	{ name = "BackWall", size = Vector3.new(5.50, 3.90, 0.46), offset = Vector3.new(0, 2.72, -2.58), tone = "wood" },
	{ name = "SideWall", size = Vector3.new(0.44, 3.80, 5.74), offset = Vector3.new(-2.60, 2.72, 0), tone = "wood" },
	{ name = "SideWall", size = Vector3.new(0.44, 3.80, 5.74), offset = Vector3.new(2.60, 2.72, 0), tone = "wood" },
	{ name = "DoorPost", size = Vector3.new(0.70, 3.30, 0.70), offset = Vector3.new(-2.40, 2.52, 2.60), tone = "trim" },
	{ name = "DoorPost", size = Vector3.new(0.70, 3.30, 0.70), offset = Vector3.new(2.40, 2.52, 2.60), tone = "trim" },
	{ name = "Lintel", size = Vector3.new(6.00, 1.00, 0.50), offset = Vector3.new(0, 4.15, 2.76), tone = "trim" },
	-- THE NAME BOARD, over the door. A dog with its name painted on its own
	-- house is a dog somebody OWNS, and that is the cheapest way to say so
	-- from the pavement -- the nameplate is a `MaxDistance` 90 billboard and
	-- small at that range, so the board is the half that carries.
	--
	-- SET INTO THE LINTEL RATHER THAN LAID ON IT. The board's back face sits
	-- at z 2.97 against a lintel front at 3.01, so it is embedded by four
	-- hundredths and shares no plane with anything. A board sized to sit
	-- exactly on that face is the coplanar flicker the comment at the top of
	-- this table already lists four instances of.
	--
	-- `wood` rather than `trim`, so it reads as a separate plaque against the
	-- darker lintel behind it -- and NOT `roof`, which follows the coat: a
	-- board that took the coat colour would put white text on the Shadow
	-- coat's near-black and lose the one thing it exists to show.
	{ name = "NameBoard", size = Vector3.new(4.20, 0.90, 0.18), offset = Vector3.new(0, 4.15, 3.06), tone = "wood" },
	{
		name = "RoofPanel", size = Vector3.new(3.70, 0.40, 7.10), offset = Vector3.new(-1.50, 5.30, 0),
		tone = "roof", rot = CFrame.Angles(0, 0, math.rad(28)),
	},
	{
		name = "RoofPanel", size = Vector3.new(3.70, 0.40, 7.10), offset = Vector3.new(1.50, 5.30, 0),
		tone = "roof", rot = CFrame.Angles(0, 0, math.rad(-28)),
	},
	-- ONE part called Ridge, and the sleep puff hangs off it. The old emitter
	-- was parented to `FindFirstChild("Roof")` against TWO parts named Roof,
	-- so it hung off the left panel -- the castle-finial bug, in miniature,
	-- sitting in this file the whole time.
	{ name = "Ridge", size = Vector3.new(0.95, 0.55, 7.30), offset = Vector3.new(0, 6.02, 0), tone = "trim" },
	{ name = "Eave", size = Vector3.new(0.45, 0.55, 7.20), offset = Vector3.new(-3.36, 4.42, 0), tone = "trim" },
	{ name = "Eave", size = Vector3.new(0.45, 0.55, 7.20), offset = Vector3.new(3.36, 4.42, 0), tone = "trim" },
	-- NO FOOD BOWL. The kennel used to carry one on its right-hand side, two
	-- cylinders, with its rim on the `roof` tone -- so it took the collar
	-- colour and read as a red dish sitting on the grass beside the doghouse,
	-- which is exactly what it was reported as. It went with the dog toys
	-- rather than being repainted: the water bowl it was easily mistaken for
	-- is retired, and a second bowl nobody bought is the same clutter one
	-- catalogue entry along.
}

-- Match the authored body/trim and collar, or the creature's belly accent.
function KennelModel.tones(coatKey: string?, level: number?): { [string]: Color3 }
	local key = GuardRig.key(level or Config.DOG_LEVEL, coatKey)
	local tones = GuardRig.tones(key or "shepherd", coatKey)
	return {
		wood = tones.fur, trim = tones.dark,
		roof = if GuardRig.isCreature(coatKey) then tones.light else tones.collar,
	}
end

-- Inert reference geometry. The server builds the scaled, placed kennel.
function KennelModel.build(coatKey: string?, level: number?, parent: Instance?): Model
	local tones = KennelModel.tones(coatKey, level)
	local model = Instance.new("Model")
	model.Name = "Kennel"
	for _, bone in ipairs(KennelModel.BONES) do
		local part = Instance.new("Part")
		part.Name = bone.name
		part.Size = bone.size
		part.CFrame = CFrame.new(bone.offset) * (bone.rot or CFrame.identity)
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.CastShadow = false
		-- SmoothPlastic, not WoodPlanks. A textured material is the single
		-- biggest thing that makes something in this game read as old Roblox,
		-- and the kennel and its roof were the last two carrying one.
		part.Material = Enum.Material.SmoothPlastic
		part.Color = tones[bone.tone] or tones.wood
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end
	model.Parent = parent
	return model
end

return KennelModel
