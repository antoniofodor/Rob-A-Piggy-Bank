--!strict
-- THE DAILY REWARD IS A PLACE YOU WALK TO, AND THIS IS WHAT MAKES IT ONE.
--
-- The board used to open ITSELF, 1.5 seconds after you joined, whenever there
-- was something to claim -- so the reward was a modal that appeared over the
-- world before the player had done anything, and the mailbox standing on their
-- own verge with the flag up was decoration nobody had a reason to walk to.
-- The flag, the prompt and the whole delivery fiction were already built; the
-- one thing the board did was get in front of them.
--
-- So: no auto-open (see the `DailyState` handler in ClientMain), and the
-- mailbox advertises itself instead -- flag up, sparkles out of the lid, and a
-- card over it reading DAILY REWARD. Walking over and pressing is the claim.
--
-- EVERY PIECE OF THIS IS BUILT ON THE CLIENT, WHICH IS THE LOAD-BEARING
-- DECISION. A BillboardGui and a ParticleEmitter made on the server replicate
-- to everybody, so a street of ten plots would hang ten DAILY REWARD signs and
-- ten sparkle plumes on every screen -- nine of them over post nobody present
-- can open. Built here, exactly one exists and it is over the reader's own
-- box. Same shape as the animated skins, the moat and HouseFX: the server
-- publishes a fact and each machine draws its own picture of it.
--
-- IT INVENTS NO STATE. The two facts it needs are already on the prompt and
-- already have one writer each -- `PlotService.setMail` owns `Enabled` ("there
-- is something in it") and `setMailOwner` owns the owner attribute ("whose").
-- A third copy of "is a reward waiting" is the near-identical duplicate this
-- project keeps recording, and `setMail`'s own comment says why it is one
-- call: two setters are two states that can disagree.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)

local MailCall = {}
local me: Player? = nil
local calls: { [Instance]: any } = {}

-- HOW FAR THE CARD READS FROM. There is only ever one of these on screen, so
-- this can be generous where the rob badge's cannot -- the whole point is to
-- be seen from wherever the player happens to be standing when they join.
-- Capped rather than unlimited all the same: a card legible from the far end
-- of a 351-stud street is a label floating over the world, which is the
-- argument the shop's own name plaques already settled.
local REACH = Config.STREET_SPACING + Config.PLOT_SPACING

-- 210 x 46, with a gold star at each end and "Daily Reward" between them at
-- up to 26px. Scaled with a floor as well, because these labels truncate
-- SILENTLY and a measurement is only true of the string it was taken on.
local CARD_W, CARD_H = 210, 46
local TweenService = game:GetService("TweenService")

local function build(body: BasePart): any
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee = "MailCall", body
	gui.Size = UDim2.fromOffset(CARD_W, CARD_H)
	-- Clear of the lid, which stands 0.99 proud of a body 1.5 tall.
	gui.StudsOffset = Vector3.new(0, 3.6, 0)
	gui.MaxDistance = REACH
	-- NOT ALWAYS ON TOP, for both reasons this project has recorded: a card
	-- that punches through the house behind it reads as a HUD element rather
	-- than as something standing on the lawn, AND the always-on-top pass is
	-- composited after `screen_capture` takes its frame, so a flagged one
	-- would be invisible to every screenshot ever taken of it.
	gui.AlwaysOnTop = false
	gui.Enabled = false
	gui.Parent = body

	-- NO CARD: bare white type with an ink stroke, floating over the box.
	-- It reads over grass, road and houses alike, and costs the lawn no
	-- rectangle. The stroke is Contextual (the default), so it outlines the
	-- letters rather than the label's invisible box.
	local text = Instance.new("TextLabel")
	text.Name, text.BackgroundTransparency = "Label", 1
	text.Font, text.TextColor3 = Theme.FONT, Color3.new(1, 1, 1)
	text.Text = "Daily Reward"
	text.Position, text.Size = UDim2.fromOffset(4, 3), UDim2.new(1, -8, 0, CARD_H - 6)
	text.TextScaled = true
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Parent = Theme.INK, 3, text
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize, limit.Parent = 14, 32, text

	-- A slow bob, so the card reads as something calling for attention
	-- rather than a label nailed to the air. Client-side, one tween.
	local bob = TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut, -1, true), { StudsOffset = Vector3.new(0, 4.1, 0) })
	bob:Play()

	-- SPARKLES OUT OF THE LID, ON AN ATTACHMENT RATHER THAN THE PART.
	--
	-- Parented to a BasePart an emitter fills the part's whole VOLUME, so the
	-- box would fizz all over rather than posting anything out of itself. An
	-- attachment is a point, and this one sits on top of the lid pointing up.
	-- 1.85 ABOVE THE BODY'S CENTRE, WHICH IS MEASURED RATHER THAN EYEBALLED.
	-- `Decor.buildMailbox` puts the lid's crown 0.99 proud of the body's top
	-- face, and the body is 1.5 tall -- so the highest point of the box is
	-- 1.74 above its centre and this clears it by 0.11. At the 0.9 it went in
	-- at, the emitter sat INSIDE the lid and the sparkles would have been born
	-- under the thing they are supposed to be coming out of.
	local spout = Instance.new("Attachment")
	spout.Name = "MailSpout"
	spout.Position = Vector3.new(0, body.Size.Y / 2 + 1.10, 0)
	spout.Parent = body

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "MailSparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Theme.GOLD, Theme.PAPER)
	-- SIZED TO SURVIVE THE DISTANCE IT IS READ FROM, and that is the rebirth
	-- fireworks' lesson rather than a taste call: a small particle at range is
	-- a few pixels, what survives is its texture's bright CORE, and at a high
	-- `LightEmission` that blends fully additive and clips every channel to
	-- white. Big enough to keep its gold, and dim enough not to bloom.
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.3, 1.0),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.LightEmission = 0.45
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Lifetime = NumberRange.new(0.9, 1.5)
	sparks.Rate = 22
	sparks.Speed = NumberRange.new(2.5, 4.5)
	sparks.SpreadAngle = Vector2.new(22, 22)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-70, 70)
	-- Thrown up and falling back, so it reads as coming OUT of the box rather
	-- than as a column standing on it.
	sparks.Acceleration = Vector3.new(0, -5, 0)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Enabled = false
	sparks.Parent = spout

	-- AND A TWINKLE ALL ROUND THE BOX, not only the fountain out of the lid:
	-- slow stars drifting off in every direction from the body's middle, so
	-- the whole mailbox glitters when there is something in it.
	local halo = Instance.new("Attachment")
	halo.Name = "MailHalo"
	halo.Parent = body
	local twinkle = Instance.new("ParticleEmitter")
	twinkle.Name = "MailTwinkle"
	twinkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	twinkle.Color = ColorSequence.new(Theme.PAPER, Theme.GOLD)
	twinkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0.85),
		NumberSequenceKeypoint.new(1, 0),
	})
	twinkle.LightEmission = 0.45
	twinkle.Lifetime = NumberRange.new(0.8, 1.4)
	twinkle.Rate = 18
	twinkle.Speed = NumberRange.new(1.8, 3.2)
	twinkle.SpreadAngle = Vector2.new(180, 180)
	twinkle.Rotation = NumberRange.new(0, 360)
	twinkle.RotSpeed = NumberRange.new(-90, 90)
	twinkle.Enabled = false
	twinkle.Parent = halo

	-- A soft gold glow on the box itself, which a still screenshot and a
	-- player at range both see even between sparkles.
	local glow = Instance.new("PointLight")
	glow.Name = "MailGlow"
	glow.Color = Theme.GOLD
	glow.Brightness = 1.8
	glow.Range = 9
	glow.Shadows = false
	glow.Enabled = false
	glow.Parent = spout

	return { gui = gui, sparks = sparks, twinkle = twinkle, glow = glow, spout = spout, halo = halo }
end

-- WHETHER THIS READER HAS POST WAITING. Both halves are the server's and this
-- only ever reads them -- the same split PromptUI's owner rule makes, where a
-- client decides what to SHOW and never what is allowed.
function MailCall.waiting(prompt: ProximityPrompt, viewerId: number): boolean
	local owner = prompt:GetAttribute(Config.PROMPT_OWNER_ATTRIBUTE)
	return prompt.Enabled and owner == viewerId
end

local function attach(plot: Instance)
	if calls[plot] then
		return
	end
	-- A shop plot has no mailbox at all -- nobody can move in, so there is
	-- nobody to hand a reward to -- and `WaitForChild` with no timeout would
	-- sit on four of them forever. The plot leaving the world is the other
	-- end of the same wait, which `plot.Parent` catches.
	-- THE PROMPT IS ON THE MAILBOX'S BODY, NOT ON THE PLOT. `WaitForChild`
	-- only looks at direct children, so asking the plot for `MailPrompt`
	-- timed out on every plot and none of this was ever built -- no card,
	-- no sparkles, for as long as this file existed. The body is the direct
	-- child (`Decor.buildMailbox` parents its parts flat into the plot).
	local mailBody = plot:WaitForChild("MailBody", 20)
	local prompt = mailBody and mailBody:WaitForChild("MailPrompt", 10)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	local body = prompt.Parent
	if not body or not body:IsA("BasePart") or not plot.Parent or calls[plot] then
		return
	end

	local call = build(body)
	calls[plot] = call
	local function paint()
		local on = MailCall.waiting(prompt :: ProximityPrompt, (me :: Player).UserId)
		call.gui.Enabled = on
		call.sparks.Enabled = on
		call.twinkle.Enabled = on
		call.glow.Enabled = on
	end
	paint()
	-- WATCHED, NEVER READ ONCE, and both signals are needed for a reason.
	-- `Enabled` moves when the reward is claimed or a streak lapses; the owner
	-- attribute moves when a plot changes hands, which on this street happens
	-- every time somebody joins or leaves.
	prompt:GetPropertyChangedSignal("Enabled"):Connect(paint)
	prompt:GetAttributeChangedSignal(Config.PROMPT_OWNER_ATTRIBUTE):Connect(paint)
end

function MailCall.start(player: Player)
	if me then
		return
	end
	me = player
	task.spawn(function()
		local plots = workspace:WaitForChild("Plots", 30)
		if not plots then
			return
		end
		for _, plot in ipairs(plots:GetChildren()) do
			task.spawn(attach, plot)
		end
		plots.ChildAdded:Connect(function(plot)
			task.spawn(attach, plot)
		end)
		plots.ChildRemoved:Connect(function(plot)
			local call = calls[plot]
			if call then
				call.gui:Destroy()
				call.spout:Destroy()
				call.halo:Destroy()
				calls[plot] = nil
			end
		end)
	end)
end

return MailCall
