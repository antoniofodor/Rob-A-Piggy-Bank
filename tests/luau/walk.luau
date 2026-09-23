-- The herd piggies' WALK: the curve Blender baked into Config, the sampler
-- that plays it, the stride that turns distance into phase, and the wiring
-- between the server that publishes distance and the client that poses from
-- it. Real Config; the two modules and ClientMain are read as SOURCE, because
-- a module nobody starts and an attribute nobody reads are the two failures
-- this project records more than any other and neither errors.
--
-- THE POSE ITSELF IS NOT VERIFIED HERE AND CANNOT BE. Whether a pet-sized
-- pig waddling across the band READS as walking is a live-only thing; what
-- this file can pin is that the numbers it waddles by are the ones Blender
-- authored, that they never put a foot through the grass, and that the two
-- ends agree about the name on the wire.
local Config, sources = ...
local checks = 0
local function check(ok, msg) assert(ok, msg); checks += 1 end

local W = Config.PIGGY_WALK
check(type(W) == "table", "Config.PIGGY_WALK exists")
check(type(Config.HERD_WALK_ATTRIBUTE) == "string" and #Config.HERD_WALK_ATTRIBUTE > 0,
	"the walk attribute has a name")

-- ---- THE CURVE ----------------------------------------------------------
local frames = W.frames
check(type(frames) == "table" and #frames >= 8, "the curve has samples")
check(frames[1].t == 0 and frames[#frames].t == 1, "the curve spans t = 0..1")
for i = 2, #frames do
	check(frames[i].t > frames[i - 1].t, ("samples are in order at %d"):format(i))
end
local a, z = frames[1], frames[#frames]
for _, k in ipairs({ "lift", "pitch", "roll", "yaw" }) do
	check(math.abs(a[k] - z[k]) < 1e-6, ("the loop closes on %s"):format(k))
end
check(a.lift == 0 and a.roll == 0 and a.yaw == 0, "the cycle starts on a plant: no lift, no sway, no swing")

-- Never below the ground, never a cartoon flip: the lift is in body radii and
-- the angles in degrees, so the bounds are the animal's own.
local peak = 0
for _, f in ipairs(frames) do
	check(f.lift >= -1e-9, "a foot never goes through the grass")
	check(f.lift <= 0.12, "the bob is a step, not a hop: under 12% of the body radius")
	check(math.abs(f.roll) <= 10 and math.abs(f.pitch) <= 5 and math.abs(f.yaw) <= 6,
		"the sway, the nod and the rear swing stay small")
	peak = math.max(peak, f.lift)
end
check(peak > 0.02, "and the bob is visible: over 2% of the radius")

-- ---- THE SAMPLER --------------------------------------------------------
local function at(u)
	local lift, pitch, roll, yaw = Config.piggyWalkSample(u)
	return { lift = lift, pitch = pitch, roll = roll, yaw = yaw }
end
local function close(x, y) return math.abs(x - y) < 1e-6 end

local r0, r1 = at(0), at(1)
check(close(r0.lift, 0) and close(r0.roll, 0), "u = 0 is the plant")
check(close(r1.lift, r0.lift) and close(r1.roll, r0.roll), "u = 1 is the plant again")
for _, u in ipairs({ 0.13, 0.25, 0.4, 0.77 }) do
	local here, wrapped, back = at(u), at(u + 1), at(u - 1)
	check(close(here.lift, wrapped.lift) and close(here.roll, wrapped.roll), ("the sampler wraps at %.2f"):format(u))
	check(close(here.lift, back.lift) and close(here.yaw, back.yaw), "and wraps backwards")
end
-- Two bobs a stride, one sway: the second half-stride lifts the same and
-- leans the other way, which is what makes it a waddle and not a limp.
for u = 0, 0.5, 0.01 do
	local h1, h2 = at(u), at(u + 0.5)
	check(close(h1.lift, h2.lift), ("the two steps lift alike at %.2f"):format(u))
	check(close(h1.pitch, h2.pitch), "and nod alike")
	check(close(h1.roll, -h2.roll), "and sway opposite ways")
	check(close(h1.yaw, -h2.yaw), "and swing the rear opposite ways")
end
-- Between samples it interpolates rather than stepping.
local m = frames[2].t / 2
local mid = at(m)
check(mid.lift > 0 and mid.lift < frames[2].lift, "half way to the second sample is half way up")

-- ---- THE STRIDE ---------------------------------------------------------
check(W.strideRadii > 0, "a stride has length")
check(close(Config.piggyWalkStride(1.1), W.strideRadii * 1.1), "the stride is in body radii")
check(Config.piggyWalkStride(6) > Config.piggyWalkStride(1.1), "a full pig strides further than a mini")
-- A herd mini's cadence at the pack's own speed: a trot, not a shuffle and
-- not a blur. MINI_R is 1.1 in PiggyModel; the plot pig's radius is 6.
local cadence = Config.herdSpeed() / Config.piggyWalkStride(1.1)
check(cadence >= 1.5 and cadence <= 5, ("a herd piggy steps %.1f times a second"):format(cadence))

-- The fades are seconds and small: a piggy that stops settles inside a
-- second, and the settle before the first capture is under one too.
check(W.fadeIn > 0 and W.fadeIn < 1 and W.fadeOut > 0 and W.fadeOut < 1, "the fades are fractions of a second")
check(W.hold > 0 and W.hold < 1, "the hold after the last publish is under a second")
check(W.settle > 0 and W.settle < 1, "the capture settle is under a second")
check(W.far > 40, "the cull distance is further than the catch range")

-- ---- THE BAKE IS THE TABLE ----------------------------------------------
-- Config's frames are pasted from `blender/pig/anim/walk_curve.lua`, which
-- says "do not hand-edit". Held to it row by row, so a nudge in one place
-- and not the other is caught here rather than on a lawn.
do
	local bake = assert(loadstring("return {" .. sources.Curve .. "}", "walk_curve"))()
	local baked = bake.frames
	check(#baked == #frames, ("Config carries every baked sample: %d vs %d"):format(#frames, #baked))
	for i, f in ipairs(frames) do
		local b = baked[i]
		for _, k in ipairs({ "t", "lift", "pitch", "roll", "yaw" }) do
			check(math.abs(f[k] - b[k]) < 1e-4, ("sample %d %s matches the bake"):format(i, k))
		end
	end
end

-- ---- THE WIRING ---------------------------------------------------------
local function has(src, needle) return src:find(needle, 1, true) ~= nil end
check(has(sources.HerdService, "SetAttribute(Config.HERD_WALK_ATTRIBUTE"),
	"HerdService publishes the distance under the Config name")
check(has(sources.HerdService, "walked += walked"), "and accumulates it rather than resetting it")
check(has(sources.PiggyWalk, "Config.HERD_WALK_ATTRIBUTE"), "PiggyWalk reads the same name")
check(has(sources.PiggyWalk, "GetAttributeChangedSignal(Config.HERD_WALK_ATTRIBUTE)"),
	"and watches it rather than polling")
check(has(sources.ClientMain, "require(ReplicatedStorage.Shared.PiggyWalk).start()"),
	"ClientMain starts the module in one statement")
check(not has(sources.ClientMain, "local PiggyWalk"), "and holds no local for it")
-- The pose is written just before the render, after replication lands;
-- written on Heartbeat it is overwritten every frame an update arrives.
check(has(sources.PiggyWalk, "RunService.PreRender:Connect"), "PiggyWalk poses on PreRender")
check(not has(sources.PiggyWalk, "Heartbeat:Connect"), "and never on Heartbeat")
-- The ONE `.Size =` in the file is the coin being made, once; no piggy part
-- is ever resized -- the pose is CFrame writes only.
check(select(2, sources.PiggyWalk:gsub("part%.Size =", "")) == 1, "it sizes exactly one part: the coin, at build")
check(not has(sources.PiggyWalk, "piece.part.Size =") and not has(sources.PiggyWalk, "body.Size ="),
	"and never resizes a piggy part")
check(not has(sources.PiggyWalk, ":PivotTo("), "and never pivots the model it does not own")
check(not has(sources.PiggyWalk, "CFrame.lookAt"), "and adds no second lookAt to the herd")
check(has(sources.PiggyWalk, "piggyWalkSample") and has(sources.PiggyWalk, "piggyWalkStride"),
	"the client plays Config's curve through Config's own functions")

-- ==========================================================================
-- THE DIG (Config.PIGGY_DIG, the dig half of PiggyWalk)
-- ==========================================================================
-- "Digging in the ground to find coins, just for visual." The clip is a
-- normalised 0..1 table sampled by SERVER time, layered on the walk in the
-- one place that writes the parts. What this file can pin: the clip closes,
-- the nose never goes through the grass on the real mini, the hop is a hop
-- and not a launch, the beats are where the header says, the coin pool is
-- bounded, the cull is the walk's own, and the two ends agree on the name.
local D = Config.PIGGY_DIG
check(type(D) == "table", "Config.PIGGY_DIG exists")
check(type(Config.HERD_DIG_ATTRIBUTE) == "string" and #Config.HERD_DIG_ATTRIBUTE > 0,
	"the dig attribute has a name")
check(type(Config.HERDS.dig) == "table" and Config.HERDS.dig.seconds > 0, "the server half names a dig length")

-- ---- THE CLIP -----------------------------------------------------------
local df = D.frames
check(type(df) == "table" and #df >= 20, "the dig clip has samples")
check(df[1].t == 0 and df[#df].t == 1, "the dig clip spans t = 0..1")
for i = 2, #df do
	check(df[i].t > df[i - 1].t, ("dig samples are in order at %d"):format(i))
end
for _, k in ipairs({ "lift", "pitch", "roll" }) do
	check(math.abs(df[1][k] - df[#df][k]) < 1e-6, ("the dig closes on %s"):format(k))
	check(math.abs(df[1][k]) < 1e-6,
		("and both ends are REST on %s, so a cut-off dig fades from a pose and a late clear reads as nothing"):format(k))
end

-- The mini's real numbers: body radius 1.1 (PiggyModel.MINI_R), centre 1.15
-- above the feet (PiggyModel.MINI_CENTRE), so the foot plane is 1.045 radii
-- below the body centre. The lawn pig (R 6, centre 6.62 over a slab at
-- 0.5) is 1.02. Both are swept: the clip has to be safe on either body.
local peakLift, peakPitch = 0, 0
for _, footDepth in ipairs({ 1.15 / 1.1, (6.62 - 0.5) / 6 }) do
	for i = 0, 200 do
		local u = i / 200
		local lift, pitch, roll = Config.piggyDigSample(u)
		check(lift >= -1e-9, "the dig never sinks the feet through the grass")
		check(lift <= D.maxLift, ("the hop is bounded: %.3f radii at %.3f"):format(lift, u))
		check(math.abs(pitch) <= D.maxPitch, "the pitch is a nosing, not a somersault")
		check(math.abs(roll) <= 6, "the scratch roll stays small")
		local nose = Config.piggyDigNoseHeight(pitch, lift, footDepth)
		check(nose >= D.noseClearance - 1e-9,
			("the nose stays above the foot plane at phase %.3f (%.3f radii)"):format(u, nose))
		-- And the runtime clamp would not bite on this body: the clip is
		-- authored INSIDE the clamp, so a clamped frame is a retune that
		-- somebody should hear about rather than a silent flattening.
		check(pitch <= Config.piggyDigMaxPitch(lift, footDepth) + 1e-6,
			("the clamp does not bite at %.3f"):format(u))
		peakLift = math.max(peakLift, lift)
		peakPitch = math.max(peakPitch, pitch)
	end
end
check(peakLift >= 0.15, "the recoil is a visible hop: at least 15% of the radius")
check(peakPitch >= 12 and peakPitch <= 16 + 4.5, "the dip is 12-16 degrees with the scratch rocking on it")
-- The clamp itself is honest: at rest the nose clears, and there IS a pitch
-- past which it would not, well above what the clip asks for.
check(Config.piggyDigNoseHeight(0, 0, 1.045) > 0.8, "at rest the nose stands well clear of the ground")
local maxAtRest = Config.piggyDigMaxPitch(0, 1.045)
check(maxAtRest > peakPitch and maxAtRest < 60,
	("the ground would bind at %.1f degrees, above the clip's %.1f"):format(maxAtRest, peakPitch))
check(math.abs(Config.piggyDigNoseHeight(maxAtRest, 0, 1.045) - D.noseClearance) < 1e-6,
	"and at exactly that pitch the nose sits on the clearance")
check(Config.piggyDigMaxPitch(0, 0.2) < Config.piggyDigMaxPitch(0, 1.045),
	"a body with its feet nearer its centre may dip less")

-- The sampler clamps rather than wraps: a dig does not loop.
do
	local l1, p1 = Config.piggyDigSample(1.7)
	local l0, p0 = Config.piggyDigSample(1)
	check(math.abs(l1 - l0) < 1e-9 and math.abs(p1 - p0) < 1e-9, "past the end is the rest pose, not a second dig")
	local lm, pm = Config.piggyDigSample(-0.3)
	check(math.abs(lm) < 1e-9 and math.abs(pm) < 1e-9, "before the start is rest too")
	local m = df[2].t / 2
	local _, pmid = Config.piggyDigSample(m)
	check(pmid > 0 and pmid < df[2].pitch, "between samples it interpolates")
end

-- ---- THE BEATS ----------------------------------------------------------
-- Ease in, scratch, recoil, settle: the shape the header describes, read off
-- the rows rather than off the prose.
do
	local dirtRows, coinRows = 0, 0
	local firstDirt, lastDirt, coinAt = 1, 0, nil
	for _, f in ipairs(df) do
		if (f.dirt or 0) > 0 then
			dirtRows += 1
			firstDirt = math.min(firstDirt, f.t)
			lastDirt = math.max(lastDirt, f.t)
			check(f.pitch >= 10, "dirt flies only while the nose is down")
		end
		if f.coin then
			coinRows += 1
			coinAt = f.t
		end
	end
	check(dirtRows >= 3 and dirtRows <= 6, ("a few strokes throw dirt: %d"):format(dirtRows))
	check(coinRows == 1, "exactly one coin beat")
	check(coinAt ~= nil and coinAt > lastDirt, "the coin comes AFTER the last scratch: it is found, not thrown")
	check(firstDirt > 0.1, "nothing flies during the ease-in")
	-- The coin pops on the way UP of the recoil hop.
	local liftAtCoin = Config.piggyDigSample(coinAt)
	local liftBefore = Config.piggyDigSample(coinAt - 0.02)
	check(liftAtCoin > liftBefore and liftAtCoin > 0.02, "the coin pops as the piggy recoils upward")
	-- The scratch cadence at the placeholder length: about 3 Hz.
	local strokeSpan = (lastDirt - firstDirt) / (dirtRows - 1) * Config.HERDS.dig.seconds
	check(strokeSpan > 0.2 and strokeSpan < 0.5, ("a stroke takes %.2fs at the shipped dig length"):format(strokeSpan))

	-- The scanner: what a frame crossed, exclusive of where it was.
	local flecks, coin = Config.piggyDigBeats(0, 1)
	check(flecks == dirtRows * 5 and coin == true, "a whole dig throws every fleck and one coin")
	local f2, c2 = Config.piggyDigBeats(coinAt, 1)
	check(f2 == 0 and c2 == false, "a client that first sees the dig at the coin beat never pops one")
	local f3, c3 = Config.piggyDigBeats(0.99, 1.5)
	check(f3 == 0 and c3 == false, "past the end there is nothing left")
	-- Two half-steps sum to the whole: frame rate cannot lose or double a beat.
	local fa, ca = Config.piggyDigBeats(0, 0.5)
	local fb, cb = Config.piggyDigBeats(0.5, 1)
	check(fa + fb == flecks and ((ca or cb) and not (ca and cb)), "beats split cleanly across frames")
end

-- ---- THE BUDGET ---------------------------------------------------------
check(D.coin.pool >= 3 and D.coin.pool <= 12, "the coin pool is a handful for the whole client, never one per piggy")
check(D.coin.seconds > 0.3 and D.coin.seconds < 1.5, "a coin is gone in well under two seconds")
-- The coin and the dirt are solved in studs of a scale-1 mini and multiplied
-- by the plinth's display factor, since a herd member stands at plinth size
-- (2026-09-22): so the bounds below are read in those units.
local disp = Config.PIGGY_PEDESTAL.display
check(D.coin.rise / disp >= 1 and D.coin.rise / disp <= 3, "and rises about two mini-studs")
check(D.dirt.lifetime.max <= 0.8, "a fleck is short-lived")
check(D.dirt.size / disp <= 0.3, "and small")
check(D.coin.size / disp > 0.3 and D.coin.size / disp < 0.8, "a coin is a coin at any body size")
check(D.nose.z > 1 and D.nose.z < 1.6 and math.abs(D.nose.y) < 0.4, "the nose sits ahead of the body, near centre height")
check(D.noseClearance > 0, "the nose is held OFF the ground, not on it")

-- ---- THE WIRING ---------------------------------------------------------
local PW = sources.PiggyWalk
check(has(PW, "Config.HERD_DIG_ATTRIBUTE"), "PiggyWalk reads the dig attribute by its Config name")
check(not has(PW, '"' .. Config.HERD_DIG_ATTRIBUTE .. '"'), "and never as a literal")
check(has(PW, "GetAttributeChangedSignal(Config.HERD_DIG_ATTRIBUTE)"), "and watches it rather than polling")
check(has(PW, "GetServerTimeNow"), "the dig phase is on the server's clock")
check(has(PW, "Config.HERDS.dig.seconds"), "over the server half's own dig length")
check(has(PW, "piggyDigSample") and has(PW, "piggyDigBeats") and has(PW, "piggyDigMaxPitch"),
	"the client samples, scans and clamps through Config's own functions")
-- ONE poser. The dig composes with the walk inside the walk's own PreRender
-- callback; a second writer on the same CFrames is the bug this guards.
local posers = select(2, PW:gsub("PreRender:Connect", ""))
check(posers == 1, ("exactly one PreRender poser: %d"):format(posers))
check(not has(PW, "Heartbeat:Connect") and not has(PW, "RenderStepped:Connect"), "and no other per-frame writer")
local placeCalls = select(2, PW:gsub("place%(entry, ", ""))
check(placeCalls == 2, ("the parts are written by `place` alone: rest and posed, %d call sites"):format(placeCalls))
check(has(PW, "entry.digLift * d") and has(PW, "entry.digPitch * d"), "the dig is SUMMED into the walk's motion")
-- The cull is the walk's own distance, not a second number.
check(has(PW, "walk.far"), "the dig is culled by PIGGY_WALK.far")
check(D.far == nil, "and PIGGY_DIG carries no far of its own")
check(has(PW, "entry.digSeen = u"), "a culled piggy still advances its beat scan")
-- The pool is bounded in the source as well as in the number.
local partNews = select(2, PW:gsub('Instance.new%("Part"%)', ""))
check(partNews == 1, ("one place makes a coin part: %d"):format(partNews))
check(has(PW, "#coins >= spec.pool"), "and it refuses past the pool size")
check(has(PW, "Theme.GOLD"), "the coin is the palette's gold")
check(has(PW, "Enum.Material.SmoothPlastic") and not has(PW, "Enum.Material.Metal"), "in SmoothPlastic, never Metal")
check(has(PW, "CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false"),
	"a coin has no body: no collide, no query, no touch, no shadow")
check(has(PW, "LightEmission = 0"), "dirt does not glow")
check(has(PW, "emitter.Rate = 0") and has(PW, ":Emit("), "dirt is a burst per stroke, never a running rate")
check(has(PW, "parkCoin(entry.coin)"), "a member destroyed mid-dig releases its coin")
check(has(sources.HerdService, "Config.HERD_DIG_ATTRIBUTE"), "HerdService publishes the dig under the same Config name")
check(not has(sources.ClientMain, "PiggyDig"), "no second module to start: the dig lives in PiggyWalk")

print(("walk: %d checks passed"):format(checks))
