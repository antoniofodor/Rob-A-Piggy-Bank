--!strict
-- Native skin renders: assets/skins/animal/<tier>/<key>/shop-cards/<key>.png,
-- made by blender/shop/render_skin_images.py from each skin's own package.
-- Source blends, hashes and upload IDs: assets/shop-ui/skin-images.
--
-- WHY AN IMAGE AND NOT THE 3D PREVIEW EVERY OTHER SKIN GETS. Two reasons, both
-- reported, and one of them cannot be fixed on the model side at all:
--
--   * A ViewportFrame DOES NOT DRAW `SurfaceAppearance`. Every animal coat is a
--     texture pack, so in a crate well the giraffe, the leopard and the tiger
--     were a flat body-coloured pig -- the coat, which is the entire thing the
--     skin is, simply was not there.
--   * `ShopWidgets.preview` frames a model by its whole bounding SPHERE, so a
--     roughly cubic pig fills about half its well. The renders are cropped to
--     the animal, so they fill it.
--
-- The render is the real package -- the same meshes and the same coat maps the
-- lawn wears -- so the picture cannot promise a skin the game does not give.
-- A skin with no entry here keeps the 3D preview, which is right for the
-- paint-only skins that have no texture to lose.
local Cards = {}

-- BEGIN SKIN IMAGE IDS
Cards.images = {
	tiger = "rbxassetid://120311433092780",
	dragon = "rbxassetid://109836906184393",
	ladybird = "rbxassetid://119616262270164",
	cow = "rbxassetid://118214168454938",
	zebra = "rbxassetid://134406442403226",
	bee = "rbxassetid://125266920902816",
	giraffe = "rbxassetid://138838534726663",
	leopard = "rbxassetid://129271773951053",
	snowleopard = "rbxassetid://112167361610831",
	strawberrycow = "rbxassetid://129470418408323",
	cookiescream = "rbxassetid://126277155980258",
	watermelon = "rbxassetid://86426347641869",
	peppermint = "rbxassetid://119504778501327",
	glacier = "rbxassetid://93224357602594",
	bubblegumleopard = "rbxassetid://106032101636660",
	honeycomb = "rbxassetid://123072274802746",
	stormwolf = "rbxassetid://99604169685516",
	phoenix = "rbxassetid://78405426785417",
	rainbowtiger = "rbxassetid://77819354328927",
} :: { [string]: string }
-- END SKIN IMAGE IDS

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

-- HOW MUCH OF A ROUND WELL A PIG MAY TAKE. A picture fitted to the square and
-- then cropped to a circle loses its corners; 0.82 is the width of the square
-- that fits inside the circle (1/sqrt(2)) plus a little, since a pig's corners
-- are empty and a snout or an ear tip may sit in them.
local ROUND_FIT = 0.82

-- THE WELL IS THE TIER'S COLOUR, NOT ONLY ITS EDGE. The rarity border is a
-- 2px line a nine-year-old has to be taught to read; a whole well in gold says
-- LEGENDARY before anybody reads anything. The ground is the `Config.RARITIES`
-- colour itself -- the same one the border and the odds bar use -- so the
-- three can never disagree. A UIGradient multiplies, so the fill is authored
-- LIGHT and the ramp darkens it downward: lit from above, like the spotlight.
--
-- BOTH LAYERS SIT AT A NEGATIVE ZINDEX. The HUD is `ZIndexBehavior.Sibling`,
-- so a child only competes with its siblings -- and the thing it has to stay
-- under is whatever preview `iconFor` puts in the well afterwards (a baked
-- image, or a ViewportFrame at the default ZIndex). Two frames at the SAME
-- ZIndex draw in an order nothing promises; below zero they cannot lose.
--
-- Public because `iconFor` calls it for EVERY tiered item it draws -- houses,
-- rides and the paint-only skins as well as the baked animal cards -- so a
-- crate strip reads as one ladder rather than two gold wells and a dark one.
function Cards.backdrop(holder: GuiObject, tier: string)
	for _, name in ipairs({ "TierBackdrop", "Spotlight" }) do
		local old = holder:FindFirstChild(name)
		if old then old:Destroy() end
	end
	-- A well inside a card that is ALREADY wearing the tier (see `dressCard`)
	-- stays clear: a second ground inside the first reads as a box pasted on.
	if holder:GetAttribute("OnTierCard") then return end
	local rarity = Config.RARITIES[tier]
	if not rarity then return end
	local colour = rarity.colour
	local corner = holder:FindFirstChildOfClass("UICorner")

	local ground = Instance.new("Frame")
	ground.Name = "TierBackdrop"
	ground.BorderSizePixel = 0
	ground.Size = UDim2.fromScale(1, 1)
	ground.BackgroundColor3 = Color3.new(1, 1, 1)
	ground.ZIndex = -2
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(
		colour:Lerp(Color3.new(1, 1, 1), 0.15),
		colour:Lerp(Color3.new(0, 0, 0), 0.32)
	)
	shade.Parent = ground
	-- ClipsDescendants ignores a UICorner, so the ground carries its own or
	-- its square corners show through the well's rounded ones.
	if corner then corner:Clone().Parent = ground end
	ground.Parent = holder

	-- THE STREAK IS A GRADIENT, NOT A ROTATED BAR. A rotated GuiObject is not
	-- clipped by ClipsDescendants, so a tilted white strip would hang out of
	-- the well's corners. A diagonal transparency ramp over a full-size frame
	-- draws the same shaft of light and stays inside by construction: one
	-- broad beam through the middle and a thin one trailing it. The first pass
	-- peaked at 45% white and was invisible behind the pig in a screenshot;
	-- the core is near-solid now, because the pig covers most of it anyway.
	local light = Instance.new("Frame")
	light.Name = "Spotlight"
	light.BorderSizePixel = 0
	light.Size = UDim2.fromScale(1, 1)
	light.BackgroundColor3 = Color3.new(1, 1, 1)
	light.ZIndex = -1
	local beam = Instance.new("UIGradient")
	beam.Rotation = -55
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 1),
		NumberSequenceKeypoint.new(0.26, 1),
		NumberSequenceKeypoint.new(0.36, 0.45),
		NumberSequenceKeypoint.new(0.46, 0.12),
		NumberSequenceKeypoint.new(0.56, 0.45),
		NumberSequenceKeypoint.new(0.64, 1),
		NumberSequenceKeypoint.new(0.68, 1),
		NumberSequenceKeypoint.new(0.72, 0.35),
		NumberSequenceKeypoint.new(0.76, 1),
		NumberSequenceKeypoint.new(1.00, 1),
	})
	beam.Parent = light
	if corner then corner:Clone().Parent = light end
	light.Parent = holder
end

-- THE WHOLE CARD WEARS THE TIER, not only the picture well. The ground and
-- the spotlight go on the card itself, its edge takes a deeper shade of the
-- same colour so it frames the ramp rather than fighting it, and every well
-- listed is emptied to transparent and flagged so `iconFor` does not lay a
-- second ground inside it. Returns the colours a caller paints its labels
-- and pills with: `deep` is the edge, `colour` the tier itself.
function Cards.dressCard(card: GuiObject, tier: string, wells: { GuiObject }): { colour: Color3, deep: Color3 }?
	for _, well in ipairs(wells) do
		well:SetAttribute("OnTierCard", true)
		well.BackgroundTransparency = 1
		for _, name in ipairs({ "TierBackdrop", "Spotlight" }) do
			local old = well:FindFirstChild(name)
			if old then old:Destroy() end
		end
		local stroke = well:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Enabled = false end
	end
	local rarity = Config.RARITIES[tier]
	if not rarity then return nil end
	Cards.backdrop(card, tier)
	local deep = rarity.colour:Lerp(Color3.new(0, 0, 0), 0.45)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = deep end
	return { colour = rarity.colour, deep = deep }
end

-- Paper type with an ink edge: the one pairing that reads on all four tier
-- grounds, from the pale top of a common to the darkened foot of a rare.
function Cards.onTierText(label: TextLabel)
	label.TextColor3 = Color3.new(1, 1, 1)
	local edge = label:FindFirstChild("TierTextEdge") :: UIStroke?
	if not edge then
		edge = Instance.new("UIStroke")
		edge.Name = "TierTextEdge"
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		edge.Thickness = 1.5
		edge.Color = Color3.fromRGB(40, 26, 30)
		edge.Parent = label
	end
end

-- Mounts the render into `holder`, replacing any preview already there, and
-- returns it -- or nil when this skin has no render, so the caller falls back.
function Cards.mount(holder: GuiObject, key: string): ImageLabel?
	local asset = Cards.images[key]
	if not asset then return nil end
	for _, name in ipairs({ "ShopPreview", "ShopIcon", "SkinImage", "TierBackdrop", "Spotlight" }) do
		local old = holder:FindFirstChild(name)
		if old then old:Destroy() end
	end
	-- `makeModelIcon` leaves an unnamed ViewportFrame; clear those too, or a
	-- rebuild after the mesh warm-up stacks a flat pig behind the picture.
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("ViewportFrame") then child:Destroy() end
	end
	local spec = Config.SKINS[key]
	Cards.backdrop(holder, if spec then Config.rarityOf(spec) else "common")
	local image = Instance.new("ImageLabel")
	image.Name = "SkinImage"
	image:SetAttribute("SkinKey", key)
	image.BackgroundTransparency = 1
	-- Full bleed with a hair of inset: the renders already carry a 2% margin,
	-- and a rounded well's corners would otherwise clip an ear.
	--
	-- A ROUND WELL IS NOT A SQUARE ONE, and a card framed for a square loses
	-- its corners to the circle -- on the HUD portrait that clipped the snout
	-- off the right-hand side. A well that says `RoundWell` gets the picture
	-- pulled in to the circle instead. Same number in both drawers, so a baked
	-- animal and a live OG pig sit in the portrait at one size.
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(if holder:GetAttribute("RoundWell") then ROUND_FIT else 0.96,
		if holder:GetAttribute("RoundWell") then ROUND_FIT else 0.96)
	image.Image = asset
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = holder.ZIndex
	image.Parent = holder
	return image
end

-- THE PAINT-ONLY SKINS ARE SHOT THE WAY THE ANIMAL CARDS ARE. A skin with no
-- baked render is a live 3D pig, and it used to go through the generic item
-- preview: turned the OTHER way (snout to the left, where every card has it
-- to the right) and framed by the whole bounding sphere, so it filled about
-- half the well while the animal beside it filled all of it. On one crate
-- shelf the two read as two different sets of pictures.
--
-- So this matches the cards: three-quarter from above with the snout to the
-- RIGHT, and fitted to the pig's own corners with the card's 2% margin. The
-- facing is read off the model's Snout rather than assumed, so a pig built
-- turned round still comes out facing the same way as the renders.
function Cards.pigPreview(holder: GuiObject, model: Model): ViewportFrame
	for _, name in ipairs({ "ShopPreview", "ShopIcon", "SkinImage" }) do
		local old = holder:FindFirstChild(name)
		if old then old:Destroy() end
	end
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("ViewportFrame") then child:Destroy() end
	end
	local v = Instance.new("ViewportFrame")
	v.Name = "ShopPreview"
	v.BackgroundTransparency = 1
	v.AnchorPoint = Vector2.new(0.5, 0.5)
	v.Position = UDim2.fromScale(0.5, 0.5)
	v.Size = UDim2.fromScale(0.96, 0.96)
	v.Ambient = Color3.fromRGB(188, 184, 188)
	v.LightColor = Color3.fromRGB(255, 250, 242)
	v.ZIndex = holder.ZIndex
	v.Parent = holder
	model.Parent = v

	-- FITTED TO THE SHAPES, NOT TO THEIR BOUNDING BOXES. It used to fit the
	-- eight corners of every part's box, and a pig is round: seen three-quarter
	-- from above, a sphere's box corner stands about 1.4 times further out than
	-- the sphere does, so the OG pigs were framed round empty air and came out
	-- visibly smaller than the animal renders beside them, which are cropped to
	-- the animal. A ball or a mesh is measured as (a little over) the
	-- ellipsoid inside its box, since the generated body, ears and snout are
	-- rounded; anything else keeps
	-- its box. `reach(w)` is how far the pig extends along direction `w`.
	local shapes: { { cf: CFrame, h: Vector3, round: boolean } } = {}
	local snout: BasePart? = nil
	local centre = Vector3.zero
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			if p.Transparency < 1 then
				local round = p:IsA("MeshPart") or (p:IsA("Part") and p.Shape == Enum.PartType.Ball)
				table.insert(shapes, { cf = p.CFrame, h = p.Size / 2, round = round })
				centre += p.Position
			end
			if p.Name == "Snout" and not snout then snout = p end
		end
	end
	if #shapes == 0 then return v end
	centre /= #shapes

	local function reach(w: Vector3): number
		local best = -math.huge
		for _, s in ipairs(shapes) do
			local cf, h = s.cf, s.h
			local a, b, c = cf.RightVector:Dot(w) * h.X, cf.UpVector:Dot(w) * h.Y, cf.LookVector:Dot(w) * h.Z
			local box = math.abs(a) + math.abs(b) + math.abs(c)
			-- 8% over the ellipsoid, never past the box: a generated mesh is
			-- fuller than its own bounding ellipsoid (the pig's rump stands
			-- half a stud outside it), and an ear tip clipped by the well's
			-- edge is worse than a pig a hair small.
			local r = if s.round then math.min(box, 1.08 * math.sqrt(a * a + b * b + c * c)) else box
			best = math.max(best, cf.Position:Dot(w) + r)
		end
		return best
	end

	-- Forward is toward the snout, flattened; a model with no snout faces +Z.
	local forward = Vector3.zAxis
	if snout then
		local d = snout.Position - centre
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude > 1e-3 then forward = d.Unit end
	end
	local side = forward:Cross(Vector3.yAxis).Unit
	-- 40 degrees round from the front and 24 up, the cards' own angle. Of the
	-- two sides, take the one that puts the snout on the right of the screen.
	local az, el = math.rad(40), math.rad(24)
	local back = (forward * math.cos(az) + side * math.sin(az)) * math.cos(el) + Vector3.yAxis * math.sin(el)
	local right = (-back):Cross(Vector3.yAxis).Unit
	if forward:Dot(right) < 0 then
		back = (forward * math.cos(az) - side * math.sin(az)) * math.cos(el) + Vector3.yAxis * math.sin(el)
		right = (-back):Cross(Vector3.yAxis).Unit
	end
	back = back.Unit
	local up = right:Cross(-back).Unit
	v.LightDirection = -up * 1.0 + right * 0.45 - back * 0.6

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = v
	v.CurrentCamera = camera

	-- THE BODY ALONE, for the card rule below. Found by name: the mini pig and
	-- the mesh pig both call it `Body`.
	local body = model:FindFirstChild("Body", true)
	local bodyShape: { { cf: CFrame, h: Vector3, round: boolean } }? = nil
	if body and body:IsA("BasePart") then
		bodyShape = { { cf = body.CFrame, h = body.Size / 2, round = true } }
	end
	local function bodyReach(w: Vector3): number
		local list = bodyShape :: { { cf: CFrame, h: Vector3, round: boolean } }
		local s = list[1]
		local a, b, c = s.cf.RightVector:Dot(w) * s.h.X, s.cf.UpVector:Dot(w) * s.h.Y, s.cf.LookVector:Dot(w) * s.h.Z
		return s.cf.Position:Dot(w) + math.min(math.abs(a) + math.abs(b) + math.abs(c), 1.08 * math.sqrt(a * a + b * b + c * c))
	end

	local function fit()
		local size = v.AbsoluteSize
		local aspect = if size.Y > 0 then size.X / size.Y else 1
		local tanV = math.tan(math.rad(camera.FieldOfView / 2)) * 0.98
		local tanH = tanV * aspect
		-- Centre on the silhouette's middle rather than the part average, so a
		-- tail on one side does not push the pig off-centre.
		local maxX, minX = reach(right), -reach(-right)
		local maxY, minY = reach(up), -reach(-up)
		local target = right * (minX + maxX) / 2 + up * (minY + maxY) / 2
			+ back * back:Dot(centre)
		-- The camera sits `dist` back from the target; every edge of the pig
		-- has to land inside the frustum, which for a convex piece is one
		-- support query per side.
		local dist = 0
		for _, sgn in ipairs({ 1, -1 }) do
			local wx = back + right * (sgn / tanH)
			local wy = back + up * (sgn / tanV)
			dist = math.max(dist, reach(wx) - target:Dot(wx), reach(wy) - target:Dot(wy))
		end

		-- THEN THE CARD RULE, SO AN OG PIG SITS IN A WELL EXACTLY AS AN ANIMAL
		-- CARD DOES. Fitting the whole silhouette centred the BOX -- ears, tail
		-- and all -- so the pig itself sat off-centre and small, which a round
		-- well (the HUD's portrait) shows at once beside a baked animal.
		-- `blender/shop/render_skin_images.py` sizes by the BODY (BODY_FRACTION
		-- of the width), centres the body across, and stands the feet on the
		-- bottom margin; the whole silhouette may spill past the edge by SPILL
		-- at most, and past that it is fitted instead. Same three numbers here.
		-- A ROUND WELL CENTRES THE WHOLE PIG AND STANDS IT ON NOTHING. The
		-- card rule below puts the feet on the bottom edge and centres the
		-- BODY, which is right inside a square and wrong inside a circle: the
		-- corners are cut, so the snout went off the right-hand side and the
		-- pig sat low. Here the silhouette's own box is centred and fitted to
		-- the circle, `ROUND_FIT` of the well, exactly as the baked cards are.
		if holder:GetAttribute("RoundWell") then
			-- FITTED BY ITS WIDTH AND HEIGHT, NEVER BY ITS DIAGONAL, and that
			-- is what finally makes an OG pig the same size as a baked animal
			-- in the HUD portrait.
			--
			-- `mount` sizes the baked card to `ROUND_FIT` of the WELL and its
			-- own comment claims "the same number in both drawers, so a baked
			-- animal and a live OG pig sit in the portrait at one size". The
			-- number was the same and the MEASUREMENT was not: this branch
			-- fitted the silhouette's bounding CIRCLE inside `ROUND_FIT` while
			-- the image fits its WIDTH, and a circle drawn round a box is
			-- bigger than the box. So the pig was scaled down by the ratio of
			-- its own width to its diagonal -- about 0.80 on a pig roughly
			-- 1.35 times wider than it is tall -- and came out visibly smaller
			-- than every animal beside it. Reported twice, and the first fix
			-- corrected the SQUARE case and left this one.
			--
			-- THE TWO NOW LAND ON THE SAME NUMBER BY ARITHMETIC. The baked
			-- image is `ROUND_FIT` of the well carrying a 2% render margin, so
			-- the animal covers `ROUND_FIT * 0.96` of it; this viewport is
			-- 0.96 of the well and the pig covers `ROUND_FIT` of the viewport,
			-- which is the same product.
			--
			-- NOTHING CLIPS, because `reach` already measures the rounded parts
			-- as ellipsoids rather than boxes: the silhouette box is tight on a
			-- round animal, so its corners are empty air and the pig stays
			-- inside the circle. That is also why the diagonal was the wrong
			-- thing to fit -- it was reserving room for corners no pig reaches.
			local tanH0 = math.tan(math.rad(camera.FieldOfView / 2)) * aspect
			local tanV0 = math.tan(math.rad(camera.FieldOfView / 2))
			dist = math.max((maxX - minX) / 2 / tanH0, (maxY - minY) / 2 / tanV0) / ROUND_FIT
			camera.CFrame = CFrame.lookAt(target + back * dist, target, Vector3.yAxis)
			return
		end
		if bodyShape then
			local BODY_FRACTION, MARGIN, SPILL = 411 / 512, 0.02, 1.1
			local tanH0 = math.tan(math.rad(camera.FieldOfView / 2)) * aspect
			local tanV0 = math.tan(math.rad(camera.FieldOfView / 2))
			local bMax, bMin = bodyReach(right), -bodyReach(-right)
			local bodyDist = (bMax - bMin) / (2 * BODY_FRACTION * tanH0)
			local across = (bMin + bMax) / 2
			if bodyDist < dist / SPILL then
				bodyDist = dist / SPILL
				across = (minX + maxX) / 2
			end
			-- Feet on the bottom margin: the frame's lower edge at the pig's
			-- depth is `half` below the target.
			local half = bodyDist * tanV0
			local height = minY + half * (1 - 2 * MARGIN)
			target = right * across + up * height + back * back:Dot(centre)
			dist = bodyDist
		end
		camera.CFrame = CFrame.lookAt(target + back * dist, target, Vector3.yAxis)
	end
	v:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return v
end

return Cards
