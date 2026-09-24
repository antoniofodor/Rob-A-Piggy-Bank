--!strict
--[[
	SkinAnimator -- every animated piggy skin on the map, driven on the client.

	The server publishes a `SkinKey` attribute on each piggy and nothing
	else; every machine computes the colours itself. Doing it server-side
	would mean a Color write per animated piggy per frame, replicated to
	everyone -- roughly 700 property updates a second across twelve plots,
	to say something each client could have worked out from a single string.

	ONE Heartbeat drives every piggy on the map rather than one loop each.

	EXTRACTED FROM `ClientMain` RATHER THAN REWRITTEN. That chunk was 9,629
	lines against Luau's 200-local ceiling with 32 registers left, and this
	section held five of them while borrowing nothing from the rest of the
	file and lending nothing to it -- measured in both directions before it
	moved. Every line below is the original, so the behaviour this file
	describes is the behaviour that shipped; only its home changed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local SkinAnimator = {}

--
-- Runs entirely on the client. The server publishes a SkinKey attribute on
-- each piggy and nothing else; every machine computes the colours itself.
--
-- Doing this server-side would mean a Color write per animated piggy per
-- frame, replicated to everyone -- roughly 700 property updates a second
-- across twelve plots, to say something each client could have worked out
-- from a single string.
--
-- One Heartbeat loop drives every piggy on the map rather than one loop each.

-- "Trim" IS THE MESH PIGGY'S WHOLE TRIM ON ONE PART, and it has to be in
-- this list or an animated skin drives the body and leaves the ears, muzzle,
-- hooves and tail on their static colour -- forever, on 23 skins, with
-- nothing in the log. The four primitive names stay beside it because an
-- empty mesh id is still a supported state.
local ANIMATED_TRIM = { "Trim", "Snout", "Tail", "Ear", "Leg" }

-- THE `patch` FIELD IS RETIRED WITH THE PART IT PAINTED. It capped a socket
-- the generator left in the old body's back, and was a field of its own
-- rather than a name in ANIMATED_TRIM because it took the BODY colour --
-- left off, it held a static colour while the pig cycled, which on the 23
-- animated skins was a coin-sized spot that did not match the animal. The
-- regenerated body seats every part on its own socket, so there is no cap and
-- nothing to keep in step.
local animatedPiggies: {
	{
		model: Instance, body: BasePart, trim: { BasePart },
		glow: PointLight?, auraLight: PointLight?,
	}
} = {}

local function paletteAt(palette: { Color3 }, t: number): Color3
	-- Wraps, so a palette is a loop rather than a ramp that snaps at the end.
	local span = #palette
	local scaled = (t % 1) * span
	local index = math.floor(scaled)
	local frac = scaled - index
	local a = palette[(index % span) + 1]
	local b = palette[((index + 1) % span) + 1]
	return a:Lerp(b, frac)
end

local function skinColourAt(anim: any, clock: number, seed: number): Color3?
	local kind = anim.kind
	local speed = anim.speed or 1

	if kind == "rainbow" then
		return Color3.fromHSV((clock * speed + seed) % 1, anim.sat or 0.72, anim.value or 1)
	elseif kind == "cycle" then
		return paletteAt(anim.palette, clock * speed * 0.25 + seed)
	elseif kind == "pulse" then
		local t = (math.sin(clock * speed * math.pi * 2 + seed * 6) + 1) / 2
		return anim.palette[1]:Lerp(anim.palette[2], t)
	elseif kind == "flicker" then
		-- Deliberately not smooth: fire and lightning read as unsteady, so this
		-- stacks two out-of-phase waves to avoid an obvious pulse rhythm.
		local a = math.sin(clock * speed + seed * 5)
		local b = math.sin(clock * speed * 2.7 + seed * 11)
		local t = math.clamp((a + b) / 2 * 0.5 + 0.5, 0, 1)
		return anim.palette[1]:Lerp(anim.palette[2], t * t)
	end
	return nil
end

local function collectAnimated(piggy: Instance)
	local body = piggy:FindFirstChild("Body") :: BasePart?
	if not body then
		return
	end
	local trim: { BasePart } = {}
	for _, child in ipairs(piggy:GetChildren()) do
		if child:IsA("BasePart") and table.find(ANIMATED_TRIM, child.Name) then
			table.insert(trim, child)
		end
	end
	table.insert(animatedPiggies, {
		model = piggy,
		body = body,
		trim = trim,
		glow = body:FindFirstChild("Glow") :: PointLight?,
		auraLight = body:FindFirstChild("AuraLight") :: PointLight?,
	})
end

function SkinAnimator.start()
	task.spawn(function()
		local plots = workspace:WaitForChild("Plots", 30)
		if not plots then
			return
		end
		for _, plot in ipairs(plots:GetChildren()) do
			local piggy = plot:FindFirstChild("PiggyBank")
			if piggy then
				collectAnimated(piggy)
			end
		end

		-- THE MINIS FEED IT NOW: every pedestal display, every herd member and
		-- every carried piggy, found BY NAME the way `LegendaryFX` finds its
		-- folders -- a model parented whole is seen by a scan and by
		-- DescendantAdded both, where a CollectionService tag's added signal
		-- does not fire for an instance that replicates already tagged. They
		-- carry `SkinKey` from `PiggyModel.build`, so an `anim` skin cycles on a
		-- plinth exactly as it does on the till. Designer, 2026-09-21: "we need
		-- the minis to look exactly like they were built".
		--
		-- PRUNED ON `Destroying`, which is what the shop previews below could not
		-- have and the reason they stay out: a display is destroyed by the next
		-- dress, a herd member by its catch or its exit, a carry by delivery, and
		-- each takes its entry with it. The trim is collected by the `Trim`
		-- attribute as well as by name, because the mesh mini's whole trim is one
		-- part called `Trim` and the primitives fallback still names four.
		local MINI_NAMES = { Display = true, HerdPiggy = true, [Config.LOOT_MODEL_NAME] = true }
		local collected: { [Instance]: boolean } = {}
		local function collectMini(inst: Instance)
			if not inst:IsA("Model") or type(inst:GetAttribute("SkinKey")) ~= "string" then
				return
			end
			if collected[inst] then
				return
			end
			collected[inst] = true
			-- WAITED FOR, NOT LOOKED UP. A replicated model raises DescendantAdded
			-- the moment IT arrives, and its children follow in later packets --
			-- so a `FindFirstChild("Body")` here answered nil for every display
			-- that came in after the first scan, and the plinths sat static while
			-- every property on them read right. Bounded, so a model that never
			-- gets a body (a shop's own "Display" case carries no SkinKey and is
			-- refused above anyway) costs one wait and no entry.
			local body = inst:WaitForChild("Body", 10) :: BasePart?
			if not body or not inst.Parent then
				collected[inst] = nil
				return
			end
			local trim: { BasePart } = {}
			for _, child in ipairs(inst:GetChildren()) do
				if child:IsA("BasePart") and child ~= body
					and (child:GetAttribute("Trim") == true or table.find(ANIMATED_TRIM, child.Name)) then
					table.insert(trim, child)
				end
			end
			local entry = { model = inst, body = body, trim = trim, glow = nil, auraLight = nil }
			table.insert(animatedPiggies, entry)
			inst.Destroying:Once(function()
				local at = table.find(animatedPiggies, entry)
				if at then
					table.remove(animatedPiggies, at)
				end
			end)
		end
		for _, d in ipairs(workspace:GetDescendants()) do
			if MINI_NAMES[d.Name] then
				task.spawn(collectMini, d)
			end
		end
		workspace.DescendantAdded:Connect(function(d)
			if MINI_NAMES[d.Name] then
				task.spawn(collectMini, d)
			end
		end)

		-- THE SHOP NO LONGER FEEDS THIS LIST. `watchShopPiggy` existed so that a
		-- skin tile cycled in the catalogue as well as on the lawn, and the skins
		-- tab has gone -- so the plot piggies above are the whole of it.
		--
		-- The crate reel, the bag and the haul summary all build a real piggy
		-- through `iconFor` and deliberately do NOT register it here: this list is
		-- never pruned, and those models are created and destroyed constantly, so
		-- feeding them in would leak a Heartbeat entry per preview. Animating them
		-- wants a cleanup pass first, and it has never been wired.

		RunService.Heartbeat:Connect(function()
			local clock = os.clock()
			for index, entry in ipairs(animatedPiggies) do
				local key = entry.model:GetAttribute("SkinKey")
				local skin = if type(key) == "string" then Config.SKINS[key] else nil
				local anim = skin and skin.anim

				if anim then
					-- Seeded per plot so twelve animated piggies are not all
					-- pulsing in lockstep, which reads as one effect rather than
					-- twelve separate players.
					local colour = skinColourAt(anim, clock, index * 0.137)
					if colour then
						entry.body.Color = colour
						for _, p in ipairs(entry.trim) do
							p.Color = colour:Lerp(skin.trim, 0.55)
						end
					end
					if anim.glow and entry.glow then
						-- Left alone otherwise: EconomyService drives this light to
						-- show vault fill, and stomping it every frame would erase
						-- that signal.
						entry.glow.Color = entry.body.Color
					end
				end

				-- Effect light. Storm strikes; Inferno breathes.
				local light = entry.auraLight
				if light and light.Enabled then
					local kind = entry.model:GetAttribute("LightKind")
					local seed = index * 0.61
					if kind == "strike" then
						-- Mostly dark with occasional sharp flashes, so it reads as
						-- lightning rather than as a lamp someone left on.
						local wave = math.sin(clock * 1.7 + seed) * math.sin(clock * 0.53 + seed * 3)
						local flash = math.max(0, wave) ^ 8
						light.Brightness = 0.6 + flash * 14
					elseif kind == "flicker" then
						local a = math.sin(clock * 11 + seed * 5)
						local b = math.sin(clock * 27 + seed * 13)
						light.Brightness = 7 + (a + b) * 1.6
					end
				end
			end
		end)
	end)
end

return SkinAnimator
