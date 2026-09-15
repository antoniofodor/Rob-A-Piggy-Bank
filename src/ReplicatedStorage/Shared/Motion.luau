--!strict
--[[
	Motion

	The bit of character that a static HUD has none of: icons that float above
	their buttons, bob, and drop when you press them.

	WHY IT IS NOT IN `Theme`. That file is the vocabulary -- colours, corners,
	outlines and drawn parts -- and it is required by the SERVER, because
	`SocialService` builds the street boards out of it. An animator has no
	business being loaded there, and this project already draws that line:
	`HouseFX`, `RobBadge` and `SpinWheel` are all client modules over a Shared
	palette. This is another one.

	ONE HEARTBEAT FOR EVERY FLOATING ICON, not one per button. There are six
	controls on this HUD and a connection each would be six closures doing
	identical arithmetic; the loop walks a list instead and drops entries whose
	icon has been destroyed, which is also what stops it leaking when the HUD
	is rebuilt.

	THE LOOP OWNS THE POSITION, AND NOTHING ELSE MAY TWEEN IT. A press could
	have been a `TweenService` call and it is a spring in the same loop
	instead, for the reason the ride pose reads the machine rather than a
	clock: two things writing one property at two rates is the wheelie's
	one-frame sawtooth, and this is the same shape with a Position instead of
	a weight. One writer, one frame, no fight.

	WHAT "FLOATING" ACTUALLY MEANS HERE. The icon's authored Position is where
	it RESTS on the card. Floating lifts it `rise` pixels above that and bobs
	it a little around the lifted point, so at rest it overhangs the button's
	top edge -- which is the whole look. Pressing releases the lift, so the
	icon falls onto the card and springs back up when the finger comes off.
	That is the press feedback as well: no scale anywhere.

	AND NO SCALE IS THE LOAD-BEARING PART OF THAT. The obvious press effect is
	a `UIScale` on the button, and it is wrong here: these buttons sit in
	UIListLayouts, a UIScale changes AbsoluteSize, and a layout re-flows on
	AbsoluteSize -- so pressing SHOP would shove OPTIONS and STUFF sideways.
	Moving a CHILD cannot do that, because a layout only ever writes its
	direct children's positions.

	THE SHADOW IS WHAT SELLS IT. An icon that merely sits higher reads as an
	icon that was placed higher; one with a shadow that shrinks and fades as
	it rises reads as an icon off the surface. It is a squashed rounded frame
	rather than an image, for the reason everything else here is drawn: an
	upload is a third-party asset that can be moderated away.
]]

local RunService = game:GetService("RunService")

local Motion = {}

-- How fast the press spring converges, per second. High enough that the drop
-- is immediate and the return reads as a snap rather than a drift.
local SPRING = 16

type Floater = {
	icon: GuiObject,
	shadow: GuiObject?,
	baseY: number,
	baseX: UDim,
	rise: number,
	bob: number,
	spin: number,
	speed: number,
	phase: number,
	-- 1 while floating, 0 while held down. The spring runs between them.
	lift: number,
	down: boolean,
}

local floaters: { Floater } = {}
local loop: RBXScriptConnection? = nil
-- Phases are handed out in order so that two icons built in the same frame do
-- not bob in lockstep. Three controls rising and falling as one reads as one
-- mechanism; offset, they read as three separate things that are alive.
local handed = 0

local function step(dt: number)
	local t = os.clock()
	for i = #floaters, 1, -1 do
		local f = floaters[i]
		if not f.icon.Parent then
			table.remove(floaters, i)
			continue
		end

		local want = if f.down then 0 else 1
		f.lift += (want - f.lift) * math.min(dt * SPRING, 1)

		local wave = math.sin(t * f.speed + f.phase)
		local up = (f.rise + f.bob * wave) * f.lift
		f.icon.Position = UDim2.new(f.baseX.Scale, f.baseX.Offset, 0, f.baseY - up)
		f.icon.Rotation = f.spin * wave * f.lift

		local shadow = f.shadow
		if shadow then
			-- Higher icon, smaller and fainter shadow. `up` can exceed `rise`
			-- at the top of the bob, so the ratio is clamped rather than
			-- trusted -- an unclamped one goes negative on the way down and
			-- inverts the whole effect.
			local h = math.clamp(up / math.max(f.rise, 1), 0, 1.4)
			shadow.BackgroundTransparency = 0.58 + 0.22 * h
			local w = 1 - 0.18 * h
			shadow.Size = UDim2.new(0, math.floor(f.rise * 2.4 * w), 0, 5)
		end
	end

	if #floaters == 0 and loop then
		loop:Disconnect()
		loop = nil
	end
end

local function ensureLoop()
	if loop or not RunService:IsClient() then
		return
	end
	loop = RunService.Heartbeat:Connect(step)
end

--[[
	Make `icon` float above where it was placed, and make `button` drop it
	when held.

	`rise` is how far above its authored position the icon sits at rest, which
	is what decides how much of it overhangs the button's top edge. Everything
	else is derived from it, so one number tunes a control.

	Returns the shadow, or nil where one was not asked for.
]]
function Motion.lift(button: GuiObject, icon: GuiObject, rise: number, shadow: boolean?): GuiObject?
	if not RunService:IsClient() then
		-- The server has no HUD and no Heartbeat worth spending. Leaving the
		-- icon exactly where the caller put it is the honest degrade: a
		-- static icon rather than a missing one.
		return nil
	end

	local shade: GuiObject? = nil
	if shadow then
		local s = Instance.new("Frame")
		s.Name = "IconShadow"
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		-- On the icon's OWN resting line, so the shadow stays put while the
		-- icon moves off it. Parented to the button rather than to the icon,
		-- or it would ride up with the thing casting it.
		-- The icon's AUTHORED height rather than its `AbsoluteSize`. Every
		-- drawn icon in this game is built in pixels, so `Size.Y.Offset` is
		-- the number that was meant -- and it is right on the frame the icon
		-- is created, where a measured size is a bet on the layout having run.
		local h = if icon.Size.Y.Offset > 0 then icon.Size.Y.Offset else icon.AbsoluteSize.Y
		s.Position = UDim2.new(icon.Position.X.Scale, icon.Position.X.Offset,
			0, icon.Position.Y.Offset + h * 0.5 + 4)
		s.Size = UDim2.fromOffset(math.floor(rise * 2.4), 5)
		s.BackgroundColor3 = Color3.new(0, 0, 0)
		s.BackgroundTransparency = 0.62
		s.BorderSizePixel = 0
		s.ZIndex = math.max(icon.ZIndex - 1, 1)
		s.Parent = button
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = s
		shade = s
	end

	handed += 1
	table.insert(floaters, {
		icon = icon,
		shadow = shade,
		baseY = icon.Position.Y.Offset,
		baseX = icon.Position.X,
		rise = rise,
		-- Proportional to the rise, so a small in-place bob and a big
		-- overhanging float are the same control turned to different values.
		bob = math.max(rise * 0.22, 1.2),
		spin = math.min(rise * 0.3, 4),
		-- About a third of a hertz. Slow enough to read as breathing rather
		-- than as a fault, and nowhere near anything that could be called a
		-- flash.
		speed = 2.0 + (handed % 3) * 0.18,
		phase = handed * 1.7,
		lift = 1,
		down = false,
	})
	ensureLoop()

	-- BOTH INPUT KINDS, AND `InputEnded` ON THE BUTTON IS NOT ENOUGH.
	--
	-- A finger or a mouse that leaves the control while held never fires
	-- `InputEnded` on it, so the icon would stay dropped for good -- the
	-- button would look permanently pressed. `MouseLeave` covers the pointer
	-- and `InputEnded` covers the release; a touch that slides off fires
	-- neither, which is why the loop also releases on `Parent` going away
	-- rather than trusting the pair.
	local entry = floaters[#floaters]
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			entry.down = true
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			entry.down = false
		end
	end)
	button.MouseLeave:Connect(function()
		entry.down = false
	end)

	return shade
end

--[[
	Drop an icon and let it spring back, without a pointer.

	THE KEYBOARD PRESSES THESE CONTROLS TOO, and until this existed the button
	only reacted to a finger. B opens the shop, I opens the bag, Q dodges and
	C sneaks -- so on a keyboard the loudest controls on the HUD did nothing
	visible when they were used, which is the same "looks available, does
	nothing" fault this project already fixed on the number row. A key press
	and a tap should look identical, because they ARE the same action.

	It is also the only way the drop can be exercised from a script. The
	pointer path goes through `GuiObject.InputBegan`, which nothing in this
	toolchain can raise -- the MCP mouse tool timed out on every call in the
	session this was written and delivered input exactly once in five
	attempts, which is the wall this project already records for pointer
	gestures. A public entry point means the mechanism is testable by driving
	it rather than by pressing something and hoping.
]]
function Motion.tap(icon: GuiObject, hold: number?)
	for _, f in ipairs(floaters) do
		if f.icon == icon then
			f.down = true
			task.delay(hold or 0.12, function()
				f.down = false
			end)
			return
		end
	end
end

return Motion
