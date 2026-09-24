--!strict
-- Own only these basin regions. Rebuilds restore their previous voxels, never Terrain:Clear().
local Config = require(script.Parent.Config)
local Water = {}
local terrain = workspace.Terrain
local saved: { any } = {}
local function region(lo: Vector3, hi: Vector3): Region3
	return Region3.new(lo, hi):ExpandToGrid(4)
end
local function remember(r: Region3)
	local materials, occupancy = terrain:ReadVoxels(r, 4)
	table.insert(saved, { region = r, materials = materials, occupancy = occupancy })
end
function Water.reset()
	for i = #saved, 1, -1 do
		local old = saved[i]
		terrain:WriteVoxels(old.region, 4, old.materials, old.occupancy)
	end
	table.clear(saved)
end
function Water.shape(pond: any, x: number, z: number): number
	local dx, dz = (x - pond.x) / pond.radius, (z - pond.z) / (pond.radius * .86)
	local a = math.atan2(dz, dx)
	return math.sqrt(dx * dx + dz * dz) / (1 + .10 * math.sin(a * 3 + pond.side))
end
-- Subtract axis-aligned rectangles exactly; shared edges meet without overlapping tops.
local function subtract(rects: { any }, hole: any): { any }
	local nextRects = {}
	for _, r in rects do
		local x0, x1 = math.max(r.x0, hole.x0), math.min(r.x1, hole.x1)
		local z0, z1 = math.max(r.z0, hole.z0), math.min(r.z1, hole.z1)
		if x0 >= x1 or z0 >= z1 then table.insert(nextRects, r) else
			for _, piece in {
				{ x0 = r.x0, x1 = x0, z0 = r.z0, z1 = r.z1 },
				{ x0 = x1, x1 = r.x1, z0 = r.z0, z1 = r.z1 },
				{ x0 = x0, x1 = x1, z0 = r.z0, z1 = z0 },
				{ x0 = x0, x1 = x1, z0 = z1, z1 = r.z1 },
			} do
				if piece.x1 - piece.x0 > .001 and piece.z1 - piece.z0 > .001 then table.insert(nextRects, piece) end
			end
		end
	end
	return nextRects
end
function Water.build(ponds: { any }, stream: any?)
	Water.reset()
	local holes = {}
	for _, pond in ponds do
		local r = pond.radius * 1.15 + 4
		table.insert(holes, { x0 = math.floor((pond.x-r)/4)*4, x1 = math.ceil((pond.x+r)/4)*4,
			z0 = math.floor((pond.z-r)/4)*4, z1 = math.ceil((pond.z+r)/4)*4 })
	end
	if stream then table.insert(holes, { x0 = math.floor((stream.x-stream.halfWidth-4)/4)*4, x1 = math.ceil((stream.x+stream.halfWidth+4)/4)*4,
		z0 = math.floor(stream.z0/4)*4, z1 = math.ceil(stream.z1/4)*4 }) end
	local rects = {{ x0 = -Config.GROUND_SIZE.X/2, x1 = Config.GROUND_SIZE.X/2,
		z0 = -Config.GROUND_SIZE.Y/2, z1 = Config.GROUND_SIZE.Y/2 }}
	for _, hole in holes do rects = subtract(rects, hole) end
	local world = assert(workspace:FindFirstChild("World"), "World must build before meadow basins")
	local old = world:FindFirstChild("Ground")
	local ground = Instance.new("Folder"); ground.Name = "Ground"
	for i, r in rects do
		local p = Instance.new("Part"); p.Name = "GroundSection_" .. i
		p.Size = Vector3.new(r.x1-r.x0, 8, r.z1-r.z0)
		p.CFrame = CFrame.new((r.x0+r.x1)/2, -4.5, (r.z0+r.z1)/2)
		p.Anchored = true; p.Material = Config.GRASS_MATERIAL.material
		p.MaterialVariant = Config.GRASS_MATERIAL.name; p.Color = Color3.fromRGB(82,114,60)
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth; p.Parent = ground
	end
	-- Build only within rectangular openings; adjacent slab sections stay intact.
	for _, hole in holes do
		local area = region(Vector3.new(hole.x0,-16,hole.z0),Vector3.new(hole.x1,4,hole.z1))
		remember(area)
		local materials, occupancy = terrain:ReadVoxels(area,4)
		local low = area.CFrame.Position-area.Size/2
		for ix = 1, #materials do
			for iy = 1, #materials[ix] do
				for iz = 1, #materials[ix][iy] do
					local x,z = low.X+(ix-.5)*4, low.Z+(iz-.5)*4
					local y0 = low.Y+(iy-1)*4
					-- Terrain's smoothed bank surface can rise above its occupancy height.
					-- Keep it beneath the authored shoreline instead of poking through it.
					local bottom = -4
					for _, pond in ponds do
						local d = Water.shape(pond,x,z)
						if d<1.15 then bottom = math.min(bottom,-.5-9*math.clamp((1.15-d)/.55,0,1)) end
					end
					if stream and z>=stream.z0 and z<=stream.z1 then
						bottom = math.min(bottom,-.5-5*math.clamp((stream.halfWidth+3-math.abs(x-stream.x))/3,0,1))
					end
					local solid = math.clamp((bottom-y0)/4,0,1)
					if solid>.45 then
						materials[ix][iy][iz] = if bottom> -2 then Enum.Material.Grass else Enum.Material.Ground
						occupancy[ix][iy][iz] = solid
					elseif bottom< -2 and y0 < -1.5 then
						materials[ix][iy][iz] = Enum.Material.Water
						occupancy[ix][iy][iz] = math.clamp((-1.5-y0)/4,0,1)
					else materials[ix][iy][iz] = Enum.Material.Air; occupancy[ix][iy][iz] = 0 end
				end
			end
		end
		terrain:WriteVoxels(area,4,materials,occupancy)
	end
	if old then old:Destroy() end
	ground.Parent = world
	terrain:SetMaterialColor(Enum.Material.Grass,Color3.fromRGB(82,114,60))
	terrain.WaterColor = Color3.fromRGB(24,87,108)
	terrain.WaterTransparency = .6; terrain.WaterReflectance = .15
	terrain.WaterWaveSize = .12; terrain.WaterWaveSpeed = 5
	return #rects
end
function Water.cascade(x: number, z: number, top: number, width: number)
	local area = region(Vector3.new(x-width/2-8,-4,z-8),Vector3.new(x+width/2+8,top+8,z+26))
	remember(area)
	-- A filled upper reservoir and an actual water column behind the flow effects.
	terrain:FillBlock(CFrame.new(x,top-5,z+14),Vector3.new(width+8,4,20),Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(x,top-2,z+12),Vector3.new(width,4,12),Enum.Material.Water)
	terrain:FillBlock(CFrame.new(x,top/2-1,z),Vector3.new(width-4,top+2,4),Enum.Material.Water)
	terrain:FillBlock(CFrame.new(x,top-2,z+6),Vector3.new(width,4,12),Enum.Material.Water)
end
return Water
