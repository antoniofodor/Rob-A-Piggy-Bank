--!strict
--
-- THE NEIGHBOUR STANDING ON THE LAWN.
--
-- A plot with a resident on it had a name on the sign, a pig that fills and
-- a dog, and nobody at all to look at. Eight houses on a street and seven of
-- them visibly empty is the "abandoned game" half of the problem residents
-- were built to fix -- the coins half was fixed and the picture was not.
--
-- IT IS THE DRIP STATUE'S OWN GEOMETRY, NOT A SECOND HUMAN BUILT BESIDE IT.
-- That figure is the most characterful thing in this repo -- a face set INTO
-- the head rather than stuck on it, a nose that tapers over four balls, a
-- smirk that is one rotated bar rather than a staircase, hair cut with CSG
-- and a notch razored into it -- and every one of those decisions is written
-- up and measured. Building a second humanoid from scratch would be the
-- near-identical copy this project keeps recording as the thing that drifts,
-- and it would be worse.
--
-- WHAT CHANGES IS THREE THINGS: the plinth comes off (a resident is a person,
-- not a monument), it is scaled to human height, and it is recoloured per
-- plot so the street is seven different neighbours rather than seven of the
-- same one.
--
-- IT CANNOT BLOCK ANYBODY, and that is inherited rather than added. Every
-- part `Decor` builds is `CanCollide` and `CanQuery` off, because the lawn is
-- ground a defender defends and a thief runs across. A resident is scenery
-- that happens to have a face.
--
-- WHAT IT DELIBERATELY DOES NOT DO IS DEFEND. It has no behaviour at all
-- today: it does not see, walk, or raise an alarm. That is a real question
-- rather than an omission -- see the note in ResidentService about what a
-- visible occupant means once the guard dog starts asking whether anybody is
-- home -- and it is left open on purpose rather than answered by accident.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Decor = require(ReplicatedStorage.Shared.Decor)

local ResidentModel = {}

-- The statue stands about 14.6 studs from sole to crown once its plinth is
-- gone; a Roblox character is roughly five. Scaled to 5.6 the neighbour is
-- the same size as the player robbing them, which is the only height that
-- reads correctly next to a twelve-stud piggy bank.
local TARGET_HEIGHT = 5.6

-- Seven neighbours, seven looks. Indexed by plot so a house keeps the same
-- resident across an owner arriving and leaving, exactly as the NAME does.
local PALETTES = {
	{ shirt = Color3.fromRGB(206, 78, 92),  trousers = Color3.fromRGB(64, 76, 112), hair = Color3.fromRGB(58, 42, 32) },
	{ shirt = Color3.fromRGB(72, 132, 196), trousers = Color3.fromRGB(96, 84, 70),  hair = Color3.fromRGB(158, 116, 62) },
	{ shirt = Color3.fromRGB(238, 186, 74), trousers = Color3.fromRGB(70, 70, 78),  hair = Color3.fromRGB(38, 32, 30) },
	{ shirt = Color3.fromRGB(112, 168, 96), trousers = Color3.fromRGB(102, 82, 60), hair = Color3.fromRGB(190, 158, 96) },
	{ shirt = Color3.fromRGB(176, 118, 196), trousers = Color3.fromRGB(58, 62, 82), hair = Color3.fromRGB(112, 74, 48) },
	{ shirt = Color3.fromRGB(240, 140, 80), trousers = Color3.fromRGB(88, 92, 100), hair = Color3.fromRGB(72, 56, 44) },
	{ shirt = Color3.fromRGB(96, 186, 176), trousers = Color3.fromRGB(74, 66, 58),  hair = Color3.fromRGB(206, 186, 150) },
	{ shirt = Color3.fromRGB(226, 154, 178), trousers = Color3.fromRGB(66, 74, 66), hair = Color3.fromRGB(48, 44, 56) },
}

-- Which parts wear which colour. By NAME, because that is what the statue's
-- own builder names them, and a resident that silently stopped being
-- recoloured when a part was renamed would just look like every other one.
--
-- THE MATERIAL GOES TO `SmoothPlastic` WITH THE COLOUR, AND ONLY LOOKING AT
-- IT CAUGHT THAT. The statue authors its tee and jeans in `Fabric`, which is
-- correct there -- it is one figure and the weave reads. But this project
-- already has the rule written down from the tube man and the duffel bag:
-- *Fabric is a dark, noisy texture, not a colour.* Recoloured and left in
-- Fabric, a shirt set to (206, 78, 92) rendered as dark navy and one set to
-- blue rendered olive -- so seven neighbours who exist to be TOLD APART all
-- came out the same muddy brown, and every measurement said the colours had
-- been applied correctly, because they had.
--
-- Where colour carries identity, the material has to let the colour through.
local SHIRT = { Tee = true, Sleeve = true }
local TROUSERS = { Leg = true }
local HAIR = { Hair = true }

-- The vertical extent of a model, measured PER PART IN WORLD SPACE.
--
-- Never `Model:GetBoundingBox`. That is oriented by the model's pivot, and a
-- model with no PrimaryPart takes its pivot from whichever part the builder
-- happened to create first -- which for this figure is a rolled cylinder, so
-- the box comes back with its axes swapped. This project has lost two
-- separate decisions to exactly that: a house measured by its bounding box
-- reported its FX at altitude, and the "widest lawn ornament" turned out to
-- be a height.
local function verticalExtent(model: Model): (number, number)
	local low, high = math.huge, -math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local cf, s = d.CFrame, d.Size
			local halfY = math.abs(cf.RightVector.Y) * s.X / 2
				+ math.abs(cf.UpVector.Y) * s.Y / 2
				+ math.abs(cf.LookVector.Y) * s.Z / 2
			low = math.min(low, cf.Position.Y - halfY)
			high = math.max(high, cf.Position.Y + halfY)
		end
	end
	return low, high
end

-- Builds one neighbour with their feet on `groundY`, standing at `at` and
-- facing whatever `at` faces. Every builder in this repo authors facing +Z
-- and plot-local +Z is the street on both rows, so an unrotated plot CFrame
-- puts them looking out at the pavement with nothing to remember.
function ResidentModel.build(plotIndex: number, at: CFrame, groundY: number, parent: Instance): Model?
	-- Built DETACHED and parented at the end. The statue's hair is a CSG
	-- subtract, and while `Decor.prewarm` caches the template at server start
	-- the very first call can still yield -- so a model assembled straight
	-- into the world could be seen at the origin for a frame.
	local staging = Instance.new("Folder")
	local model = Decor.buildOne("dripstatue", CFrame.new(), staging)
	if not model then
		staging:Destroy()
		return nil
	end
	model.Name = ("Resident_%d"):format(plotIndex)

	local palette = PALETTES[((plotIndex - 1) % #PALETTES) + 1]
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			-- A RESIDENT IS A PERSON, NOT A MONUMENT. The plinth is what
			-- makes the ornament a statue; on a lawn it would read as the
			-- neighbours having erected one of themselves.
			if d.Name == "Plinth" or d.Name == "PlinthCap" then
				d:Destroy()
			elseif SHIRT[d.Name] then
				d.Color = palette.shirt
				d.Material = Enum.Material.SmoothPlastic
			elseif TROUSERS[d.Name] then
				d.Color = palette.trousers
				d.Material = Enum.Material.SmoothPlastic
			elseif HAIR[d.Name] then
				d.Color = palette.hair
			end
		end
	end

	local low, high = verticalExtent(model)
	if high <= low then
		staging:Destroy()
		return nil
	end
	model:ScaleTo(TARGET_HEIGHT / (high - low))

	-- Re-measured AFTER scaling rather than divided through. `ScaleTo` scales
	-- about the model's pivot, and the pivot is not the feet -- so where the
	-- soles end up is a fact to read back, not one to predict.
	local newLow = select(1, verticalExtent(model))
	local pivot = model:GetPivot()
	local feetBelowPivot = pivot.Position.Y - newLow

	-- THE PLOT'S ROTATION HAS TO COME ALONG, and dropping it is the bug this
	-- line exists to avoid. The far row's plot CFrame carries a half turn --
	-- which is exactly what makes plot-local +Z the street on BOTH rows --
	-- so a resident placed with position only would stand on four of the
	-- eight plots with their back to the pavement, facing their own house.
	-- The same trap the wheelie bin prop fell into, where 2 of 6 parts
	-- changed sides between the rows and nobody noticed for a session.
	--
	-- Safe to apply after the vertical measurement because the turn is about
	-- Y, and a Y rotation cannot change how far the soles sit below the pivot.
	model:PivotTo(CFrame.new(at.Position.X, groundY + feetBelowPivot, at.Position.Z)
		* at.Rotation)

	model.Parent = parent
	staging:Destroy()
	return model
end

return ResidentModel
