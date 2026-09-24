--!nocheck
-- THE LASSO'S SEVEN CHARACTER ANIMATIONS (Shared/LassoPose).
--
-- The runner's CFrame is an inert stub, so this suite brings its own: a real
-- rotation-and-translation CFrame composed the way Roblox composes one
-- (CFrame.Angles is Rx * Ry * Rz). With it the BUILT sequences can be walked
-- joint by joint, which is what proves the leg solver's sign conventions
-- agree with the CFrame the engine will actually apply -- the feet land where
-- each frame says they do -- rather than restating the solver's own
-- arithmetic back at it.
--
-- What this cannot see is the live rig: the leg lengths are the module's own
-- estimates, and a photograph is still the only thing that says a pose reads.
local Config, inputs = ...

local failures = 0
local function check(ok, message)
	if not ok then
		failures += 1
		print("FAIL: " .. message)
	end
end

-- ============================================================
-- A real CFrame
-- ============================================================

local CF = {}
CF.__index = CF
local function mk(r, x, y, z)
	return setmetatable({ r = r, x = x, y = y, z = z }, CF)
end
local I3 = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mm(a, b)
	local o = {}
	for i = 0, 2 do
		for j = 0, 2 do
			o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return o
end
local function mv(r, x, y, z)
	return r[1] * x + r[2] * y + r[3] * z, r[4] * x + r[5] * y + r[6] * z, r[7] * x + r[8] * y + r[9] * z
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		local x, y, z = mv(a.r, b.x, b.y, b.z)
		return mk(mm(a.r, b.r), a.x + x, a.y + y, a.z + z)
	end
	local x, y, z = mv(a.r, b.X, b.Y, b.Z)
	return { X = a.x + x, Y = a.y + y, Z = a.z + z }
end
local function rx(t) local c, s = math.cos(t), math.sin(t) return { 1, 0, 0, 0, c, -s, 0, s, c } end
local function ry(t) local c, s = math.cos(t), math.sin(t) return { c, 0, s, 0, 1, 0, -s, 0, c } end
local function rz(t) local c, s = math.cos(t), math.sin(t) return { c, -s, 0, s, c, 0, 0, 0, 1 } end
local CFrameReal = {
	new = function(x, y, z) return mk(I3, x or 0, y or 0, z or 0) end,
	Angles = function(a, b, c) return mk(mm(mm(rx(a or 0), ry(b or 0)), rz(c or 0)), 0, 0, 0) end,
	-- CarryPose builds its hand seats with this at load; YXZ order.
	fromOrientation = function(a, b, c) return mk(mm(mm(ry(b or 0), rx(a or 0)), rz(c or 0)), 0, 0, 0) end,
}
local function near(a, b, tol)
	for i = 1, 9 do
		if math.abs(a.r[i] - b.r[i]) > tol then return false end
	end
	return math.abs(a.x - b.x) <= tol and math.abs(a.y - b.y) <= tol and math.abs(a.z - b.z) <= tol
end
local IDENTITY = CFrameReal.new()

-- ============================================================
-- A tiny instance tree
-- ============================================================

local function newInstance(class)
	local obj = { ClassName = class, Name = class, _children = {}, _markers = {} }
	return setmetatable(obj, {
		__index = function(self, k)
			if k == "Parent" then return rawget(self, "_parent") end
			if k == "GetChildren" then return function(s) return s._children end end
			if k == "FindFirstChild" then
				return function(s, name)
					for _, c in ipairs(s._children) do if c.Name == name then return c end end
					return nil
				end
			end
			if k == "AddMarker" then
				return function(s, m) table.insert(s._markers, m); m._parent = s end
			end
			return nil
		end,
		__newindex = function(self, k, v)
			if k == "Parent" then
				rawset(self, "_parent", v)
				if v then table.insert(v._children, self) end
			else
				rawset(self, k, v)
			end
		end,
	})
end

local warnings = {}
local registerOk = true
local registered = 0
local services = {
	KeyframeSequenceProvider = {
		RegisterKeyframeSequence = function(_, seq)
			if not registerOk then error("refused live") end
			registered += 1
			return "hash://" .. seq.Name
		end,
	},
	ReplicatedStorage = { Shared = { Config = "Config" } },
	Players = {}, RunService = {},
}
local modules = { Config = Config }
local env = setmetatable({
	CFrame = CFrameReal,
	Instance = { new = newInstance },
	Enum = setmetatable({}, { __index = function(_, g)
		return setmetatable({}, { __index = function(_, n) return g .. "." .. n end })
	end }),
	game = { GetService = function(_, name) return services[name] end },
	script = { Parent = { Config = "Config", CarryPose = "CarryPose" } },
	require = function(name) return modules[name] end,
	warn = function(msg) table.insert(warnings, msg) end,
}, { __index = getfenv() })
local function load(name)
	local run = assert(loadstring(inputs[name], name))
	setfenv(run, env)
	modules[name] = run()
	return modules[name]
end
load("CarryPose")
local LassoPose = load("LassoPose")

-- ============================================================
-- The contract
-- ============================================================

local WANT = { "lassoTwirl", "lassoThrow", "lassoPull", "lassoWin", "lassoSnap", "knockedLoose", "scoopUp" }
check(#LassoPose.KEYS == #WANT, "KEYS holds the seven lasso keys")
local listed = {}
for _, k in ipairs(Config.animationKeys({})) do listed[k] = true end
for i, key in ipairs(WANT) do
	check(LassoPose.KEYS[i] == key, "KEYS[" .. i .. "] is " .. key)
	check(Config.ANIMATIONS[key] ~= nil, key .. " has a Config.ANIMATIONS row")
	check(listed[key], key .. " is in Config.animationKeys, so animdump builds it")
end
check(LassoPose.buildSequence("nope") == nil, "an unknown key builds nothing")

local UPPER = { lassoTwirl = true, lassoThrow = true }
local LOOP = { lassoTwirl = true, lassoPull = true }
local LENGTH = { lassoTwirl = 1.0, lassoThrow = 0.4, lassoPull = 0.6, lassoWin = 0.8, lassoSnap = 1.4, knockedLoose = 0.6, scoopUp = 0.5 }
local ARM = { "UpperArm", "LowerArm", "Hand" }
local LEG = { "UpperLeg", "LowerLeg", "Foot" }

local function child(p, name) return p:FindFirstChild(name) end

-- Walk the chain the engine does: a child joint's frame is its parent's frame,
-- times the joint's offset, times the pose. Offsets are the module's own leg
-- rig and a rough upper body (shoulders and arm lengths) that only the loose
-- arm checks below read.
local R = LassoPose.RIG
local function fk(keyframe, side)
	local sign = if side == "Left" then -1 else 1
	local root = child(keyframe, "HumanoidRootPart")
	local lower = child(root, "LowerTorso")
	local pelvisFrame = CFrameReal.new(0, R.rootJointY, 0) * lower.CFrame
	local out = { pelvis = pelvisFrame }
	local upperLeg = child(lower, side .. "UpperLeg")
	if upperLeg then
		local hip = pelvisFrame * CFrameReal.new(sign * R.hipX, -R.hipDown, 0) * upperLeg.CFrame
		local lowerLeg = child(upperLeg, side .. "LowerLeg")
		local knee = hip * CFrameReal.new(0, -R.thigh, 0) * lowerLeg.CFrame
		local foot = child(lowerLeg, side .. "Foot")
		local ankle = knee * CFrameReal.new(0, -R.shin, 0) * foot.CFrame
		out.ankle = ankle
	end
	local upper = child(lower, "UpperTorso")
	local chest = pelvisFrame * CFrameReal.new(0, 0.2, 0) * upper.CFrame
	local upperArm = child(upper, side .. "UpperArm")
	local shoulder = chest * CFrameReal.new(sign * 0.65, 0.95, 0) * upperArm.CFrame
	local lowerArm = child(upperArm, side .. "LowerArm")
	local elbow = shoulder * CFrameReal.new(0, -0.95, 0) * lowerArm.CFrame
	out.shoulder = shoulder * { X = 0, Y = 0, Z = 0 }
	-- The head's centre: the neck sits on top of the upper torso and a head
	-- is about 1.2 tall, so its middle is about 1.6 above the chest joint.
	out.head = chest * { X = 0, Y = 1.6, Z = 0 }
	out.elbowAt = elbow * { X = 0, Y = 0, Z = 0 }
	out.hand = elbow * { X = 0, Y = -1.0, Z = 0 }
	out.upperArmDir = { X = shoulder.r[2] * -1, Y = shoulder.r[5] * -1, Z = shoulder.r[8] * -1 }
	return out
end

for _, key in ipairs(WANT) do
	local def = LassoPose.DEFS[key]
	local seq = LassoPose.buildSequence(key)
	check(seq ~= nil and seq.ClassName == "KeyframeSequence", key .. " builds a KeyframeSequence")
	check(seq.Name == key, key .. " is named after its Config row")
	check(seq.Loop == (LOOP[key] == true), key .. " loops exactly when it should")
	local want = if key == "lassoTwirl" then "AnimationPriority.Movement" else "AnimationPriority.Action"
	check(seq.Priority == want, key .. " plays at " .. want .. " (the twirl yields to a dodge)")
	local frames = seq._children
	local last = 0
	for i, kf in ipairs(frames) do
		check(kf.Time >= last, key .. " keyframes run forward in time")
		last = kf.Time
		local root = child(kf, "HumanoidRootPart")
		check(root ~= nil and near(root.CFrame, IDENTITY, 1e-9), key .. " frame " .. i .. ": no root motion")
		local lower = child(root, "LowerTorso")
		check(lower ~= nil, key .. " frame " .. i .. ": the LowerTorso is on the path")
		local upper = child(lower, "UpperTorso")
		check(upper and child(upper, "Head"), key .. " frame " .. i .. ": torso and head posed")
		for _, side in ipairs({ "Left", "Right" }) do
			local p = upper
			for _, part in ipairs(ARM) do
				p = p and child(p, side .. part)
			end
			check(p ~= nil, key .. " frame " .. i .. ": " .. side .. " arm posed to the hand")
			local q = lower
			for _, part in ipairs(LEG) do
				q = q and child(q, side .. part)
			end
			if UPPER[key] then
				check(q == nil, key .. " frame " .. i .. ": no " .. side .. " leg, so the run keeps it")
			else
				check(q ~= nil, key .. " frame " .. i .. ": " .. side .. " leg posed to the foot")
			end
		end
		if UPPER[key] then
			check(root.Weight == 0 and lower.Weight == 0 and near(lower.CFrame, IDENTITY, 1e-9),
				key .. " frame " .. i .. ": path joints at identity and Weight 0")
		end
	end
	check(math.abs(last - LENGTH[key]) < 1e-9, key .. " is " .. LENGTH[key] .. "s long")
	check(math.abs(last - def.length) < 1e-9, key .. " ends at its declared length")

	-- JOINT LIMITS, on the authored arms and the solved legs.
	for i, frame in ipairs(def.frames) do
		for _, arm in ipairs({ frame.left or {}, frame.right or {} }) do
			local e = arm.elbow or 0
			check(e >= 0 and e <= 150, key .. " frame " .. i .. ": elbow " .. e .. " inside 0..150")
		end
		if not UPPER[key] then
			for _, s in ipairs({ -1, 1 }) do
				local leg = LassoPose.solveLeg(frame, s)
				check(leg.knee <= 1e-6 and leg.knee >= -150, key .. " frame " .. i .. ": knee " .. leg.knee .. " never hyperextends")
				check(leg.hipFlex > -60 and leg.hipFlex < 120, key .. " frame " .. i .. ": hip " .. leg.hipFlex .. " in range")
				check(leg.knee == leg.knee and leg.hipFlex == leg.hipFlex, key .. " frame " .. i .. ": solver gave numbers")
			end
		end
	end

	-- THE FEET LAND WHERE THE FRAME SAYS, walked through the real CFrame.
	if not UPPER[key] then
		for i, kf in ipairs(frames) do
			local frame = def.frames[i]
			for _, side in ipairs({ "Left", "Right" }) do
				local sign = if side == "Left" then -1 else 1
				local foot = ((frame.feet or {})[string.lower(side)]) or {}
				local want = {
					X = sign * (R.hipX + (foot.out or 0)),
					Y = R.rootJointY - R.hipDown - R.thigh - R.shin + (foot.up or 0),
					Z = -(foot.f or 0),
				}
				local ankle = fk(kf, side).ankle
				local err = math.sqrt((ankle.x - want.X) ^ 2 + (ankle.y - want.Y) ^ 2 + (ankle.z - want.Z) ^ 2)
				check(err < 0.01, ("%s frame %d: %s ankle lands on its target (off by %.3f)"):format(key, i, side, err))
				-- The foot is flat: its up axis is the world's.
				check(ankle.r[5] > math.cos(math.rad(8)), ("%s frame %d: %s foot level (%.3f)"):format(key, i, side, ankle.r[5]))
			end
		end
	end
end

-- ============================================================
-- Per-animation reads
-- ============================================================

-- The loops have no seam: the last keyframe is the first pose.
for _, key in ipairs({ "lassoTwirl", "lassoPull" }) do
	local frames = LassoPose.buildSequence(key)._children
	local a, b = frames[1], frames[#frames]
	for _, side in ipairs({ "Left", "Right" }) do
		local ha, hb = fk(a, side).hand, fk(b, side).hand
		check(math.abs(ha.X - hb.X) + math.abs(ha.Y - hb.Y) + math.abs(ha.Z - hb.Z) < 1e-6,
			key .. ": " .. side .. " hand ends the loop where it began")
	end
end

-- The twirl: the right arm is raised, the hand is above the shoulder on every
-- frame and goes somewhere different on each (the circle the client's spinning
-- loop rides on); the UPPER ARM moves too; and neither the fist nor the elbow
-- ever comes near the head (the designer's clipping report).
local function dist(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2 + (a.Z - b.Z) ^ 2) end
do
	local frames = LassoPose.buildSequence("lassoTwirl")._children
	local seen, dirs = {}, {}
	local nearest = math.huge
	for i = 1, #frames - 1 do
		local f = fk(frames[i], "Right")
		check(f.upperArmDir.Y > 0.4, ("twirl frame %d: right upper arm raised (%.2f)"):format(i, f.upperArmDir.Y))
		check(f.hand.Y - f.shoulder.Y > 0.6, ("twirl frame %d: hand above the shoulder (%.2f)"):format(i, f.hand.Y - f.shoulder.Y))
		check(f.hand.X > f.shoulder.X - 0.1, ("twirl frame %d: the fist stays out beside the head, never over it (x %.2f vs shoulder %.2f)"):format(i, f.hand.X, f.shoulder.X))
		nearest = math.min(nearest, dist(f.hand, f.head), dist(f.elbowAt, f.head))
		for _, other in ipairs(seen) do
			local d = math.sqrt((f.hand.X - other.X) ^ 2 + (f.hand.Z - other.Z) ^ 2)
			check(d > 0.25, "twirl: the hand moves round between frames")
		end
		table.insert(seen, f.hand)
		table.insert(dirs, f.upperArmDir)
	end
	check(nearest > 1.0, ("twirl: fist and elbow keep clear of the head (nearest %.2f)"):format(nearest))
	local spread = 0
	for i = 1, #dirs do
		for j = i + 1, #dirs do
			spread = math.max(spread, dist(dirs[i], dirs[j]))
		end
	end
	check(spread > 0.3, ("twirl: the upper arm moves too, not only the forearm (spread %.2f)"):format(spread))
	print(("lassoTwirl: nearest approach to the head %.2f, upper-arm sweep %.2f"):format(nearest, spread))
end

-- The throw: one Release marker, on the keyframe `releaseTime` names; the arm
-- is back behind the shoulder before it and out in front at it.
do
	local frames = LassoPose.buildSequence("lassoThrow")._children
	local count, at, which = 0, nil, nil
	for i, kf in ipairs(frames) do
		for _, m in ipairs(kf._markers) do
			if m.Name == "Release" then count += 1; at = kf.Time; which = i end
		end
	end
	check(count == 1, "the throw carries exactly one Release marker")
	check(at == LassoPose.releaseTime(), "releaseTime() is the Release keyframe's time")
	check(at and at > 0 and at < 0.4, "the release falls inside the throw")
	local wind, release = fk(frames[which - 1], "Right"), fk(frames[which], "Right")
	check(wind.hand.Z > wind.shoulder.Z, "throw wind-up: the hand is cocked BEHIND the shoulder")
	check(release.hand.Z < release.shoulder.Z - 0.8, "throw release: the hand is out in front")
end

-- The pull: both hands forward of and below the shoulders.
for i, kf in ipairs(LassoPose.buildSequence("lassoPull")._children) do
	for _, side in ipairs({ "Left", "Right" }) do
		local f = fk(kf, side)
		check(f.hand.Z < f.shoulder.Z - 0.6, ("pull frame %d: %s hand forward"):format(i, side))
		check(f.hand.Y < f.shoulder.Y, ("pull frame %d: %s hand low"):format(i, side))
	end
end

-- The win: the right fist goes straight up at the pump.
do
	local frames = LassoPose.buildSequence("lassoWin")._children
	local top = -math.huge
	for _, kf in ipairs(frames) do
		local f = fk(kf, "Right")
		top = math.max(top, f.hand.Y - f.shoulder.Y)
	end
	check(top > 1.5, ("win: the fist goes up (%.2f above the shoulder)"):format(top))
end

-- The scoop reaches the ground and ends ON the hug CarryPose is holding.
do
	local frames = LassoPose.buildSequence("scoopUp")._children
	local low = math.huge
	for _, kf in ipairs(frames) do
		low = math.min(low, fk(kf, "Right").hand.Y)
	end
	local sole = R.rootJointY - R.hipDown - R.thigh - R.shin - 0.15
	check(low - sole < 0.9, ("scoop: the hands come down near the grass (%.2f above it)"):format(low - sole))
	local hug = modules.CarryPose.KINDS.hug.spec
	local lastKf = frames[#frames]
	local upper = child(child(child(lastKf, "HumanoidRootPart"), "LowerTorso"), "UpperTorso")
	check(near(upper.CFrame, CFrameReal.Angles(math.rad(hug.torso), 0, 0), 1e-9), "scoop ends on the hug's torso")
	check(near(child(upper, "Head").CFrame, CFrameReal.Angles(math.rad(hug.head), 0, 0), 1e-9), "scoop ends on the hug's head")
	for _, side in ipairs({ "Left", "Right" }) do
		local s = hug[string.lower(side)]
		local arm = child(upper, side .. "UpperArm")
		check(near(arm.CFrame, CFrameReal.Angles(math.rad(s.armPitch), math.rad(s.armYaw), math.rad(s.armRoll)), 1e-9),
			"scoop ends on the hug's " .. side .. " upper arm")
		check(near(child(arm, side .. "LowerArm").CFrame, CFrameReal.Angles(math.rad(s.elbow), 0, 0), 1e-9),
			"scoop ends on the hug's " .. side .. " elbow")
	end
end

-- The knock: the arms open outward from the hug.
do
	local frames = LassoPose.buildSequence("knockedLoose")._children
	local first, open = fk(frames[1], "Left").hand, fk(frames[3], "Left").hand
	check(open.X < first.X - 0.6, "knocked loose: the left hand flies outward")
	local firstR, openR = fk(frames[1], "Right").hand, fk(frames[3], "Right").hand
	check(openR.X > firstR.X + 0.6, "knocked loose: the right hand flies outward")
end

-- ============================================================
-- Playing
-- ============================================================

local function newAnimator()
	local animator = { playing = {}, loads = 0 }
	animator.AncestryChanged = { Connect = function() end }
	function animator:IsDescendantOf() return true end
	function animator:GetPlayingAnimationTracks()
		local list = {}
		for _, t in ipairs(self.playing) do if t.IsPlaying then table.insert(list, t) end end
		return list
	end
	function animator:LoadAnimation(animation)
		self.loads += 1
		local track = { Name = animation.Name, AnimationId = animation.AnimationId, IsPlaying = false, Speed = 1 }
		local owner = self
		function track:Play(_, weight, speed)
			assert(weight ~= 0, "never played at weight 0")
			self.IsPlaying = true; self.Speed = speed or 1; self.plays = (self.plays or 0) + 1
			if not table.find(owner.playing, self) then table.insert(owner.playing, self) end
		end
		function track:Stop() self.IsPlaying = false end
		function track:AdjustSpeed(s) self.Speed = s end
		return track
	end
	return animator
end

do
	local animator = newAnimator()
	local twirl = LassoPose.play(animator, "lassoTwirl")
	check(twirl ~= nil and twirl.IsPlaying, "play starts the twirl")
	check(twirl.Looped == true and twirl.Priority == "AnimationPriority.Movement", "the twirl loops at Movement, under a dodge")
	check(LassoPose.play(animator, "lassoTwirl", { speed = 1.5 }) == twirl, "replaying a running loop keeps it")
	check(twirl.Speed == 1.5 and twirl.plays == 1, "and re-speeds it rather than restarting it")
	LassoPose.play(animator, "lassoTwirl")
	check(twirl.Speed == 1.5, "a replay with no speed leaves the speed alone")
	local throw = LassoPose.play(animator, "lassoThrow")
	check(throw and throw.IsPlaying and not twirl.IsPlaying, "a throw replaces the twirl: one lasso track at a time")
	check(throw.Looped == false, "the throw is a one-shot")
	check(LassoPose.isPlaying(animator, "lassoThrow") and not LassoPose.isPlaying(animator, "lassoTwirl"), "isPlaying reads the animator")
	local pull = LassoPose.play(animator, "lassoPull")
	LassoPose.setSpeed(animator, "lassoPull", 2.25)
	check(pull.Speed == 2.25, "setSpeed changes the pull's speed")
	LassoPose.setSpeed(animator, "lassoPull", -3)
	check(pull.Speed == 0, "a negative speed is clamped to a pause")
	LassoPose.stop(animator)
	check(#animator:GetPlayingAnimationTracks() == 0, "stop with no key stops every lasso track")
	local again = LassoPose.play(animator, "lassoThrow")
	check(again == throw and throw.plays == 2, "a one-shot replays on its cached track")
	check(animator.loads == 3, "one track loaded per key per animator")
	-- A foreign track on the same animator is never touched.
	local foreign = { Name = "CarryPose", IsPlaying = true, Stop = function(t) t.IsPlaying = false end }
	table.insert(animator.playing, foreign)
	LassoPose.stop(animator)
	check(foreign.IsPlaying, "stop leaves non-lasso tracks alone")
end

-- LIVE: registration refused and no uploaded row -> one warning per key, then
-- quiet nils. A second load of the module, so its id cache starts empty.
do
	registerOk = false
	table.clear(warnings)
	local fresh = load("LassoPose")
	local animator = newAnimator()
	check(fresh.play(animator, "lassoWin") == nil, "live with no upload: play returns nil")
	check(fresh.play(animator, "lassoWin") == nil, "and again")
	check(fresh.play(animator, "lassoSnap") == nil, "for another key too")
	check(#warnings == 2, "one warning per key, not per call (" .. #warnings .. ")")
	-- An uploaded row is used before registration is ever tried.
	local saved = Config.ANIMATIONS.scoopUp
	Config.ANIMATIONS.scoopUp = "123456"
	local track = fresh.play(animator, "scoopUp")
	check(track and track.AnimationId == "rbxassetid://123456", "an uploaded id wins")
	Config.ANIMATIONS.scoopUp = saved
	registerOk = true
end

-- ============================================================
-- The angles, printed for review
-- ============================================================

for _, key in ipairs(WANT) do
	local def = LassoPose.DEFS[key]
	for i, frame in ipairs(def.frames) do
		local line = ("%-13s %.2f"):format(key, frame.at)
		if not UPPER[key] then
			local l, r = LassoPose.solveLeg(frame, -1), LassoPose.solveLeg(frame, 1)
			line ..= (" | L hip %5.1f knee %6.1f ankle %5.1f roll %5.1f | R hip %5.1f knee %6.1f ankle %5.1f roll %5.1f")
				:format(l.hipFlex, l.knee, l.ankle, l.legRoll, r.hipFlex, r.knee, r.ankle, r.legRoll)
		end
		print(line)
	end
end

print(if failures == 0 then "lassopose: all checks passed" else ("lassopose: %d FAILED"):format(failures))
if failures > 0 then
	error("lassopose suite failed")
end
