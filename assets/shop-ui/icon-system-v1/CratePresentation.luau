--!strict
-- Review-stage handoff. Require from a LocalScript after importing the approved crates.
-- root is a non-colliding, invisible BasePart at the exported BOTTOM-CENTER origin.
-- Keep the authored model orientation: front +Z, up +Y, scale 1 unit = 1 stud.
-- Shop context creates no particles, lights, update connections or glow tweens.
local TweenService = game:GetService("TweenService")
local Definitions = require(script.Parent.CrateDefinitions)
local Presentation = {}

function Presentation.attach(model: Model, tier: string, root: BasePart, context: string)
 assert(context == "world" or context == "shop", "Choose world or shop context")
 local spec = Definitions[tier]
 assert(spec, "Unknown crate tier")
 assert(root:IsDescendantOf(model), "Crate root must belong to the model")
 local previous = root:FindFirstChild("TierPresentation")
 assert(not previous, "Destroy the previous presentation controller before attaching again")
 local owned = Instance.new("Folder"); owned.Name = "TierPresentation"; owned.Parent = root
 local emitters: {ParticleEmitter} = {}
 local attachments: {Attachment} = {}
 local lights: {PointLight} = {}
 local tweens: {Tween} = {}
 local connections: {RBXScriptConnection} = {}
 local disposed = false
 local worldEnabled = context == "world"
 local motion: Tween? = nil
 local openingValue: NumberValue? = nil
 local openingConnection: RBXScriptConnection? = nil

 local function destroy()
  if disposed then return end
  disposed = true
  if motion then motion:Cancel() end
  if openingConnection then openingConnection:Disconnect() end
  if openingValue then openingValue:Destroy() end
  for _, tween in tweens do tween:Cancel() end
  for _, connection in connections do connection:Disconnect() end
  for _, attachment in attachments do attachment:Destroy() end
  owned:Destroy()
 end

 if context == "world" then
  local colour = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
  for name, coordinates in spec.attachments do
   local a = Instance.new("Attachment"); a.Name = "CrateFX_" .. name
   a.Position = Vector3.new(coordinates[1], coordinates[2], coordinates[3]); a.Parent = root
   table.insert(attachments, a)
   local e = Instance.new("ParticleEmitter"); e.Name = "TierMotes"
   e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
   e.Color = ColorSequence.new(colour, Color3.fromRGB(255,244,211))
   e.Rate = spec.rate / 3; e.Lifetime = NumberRange.new(.7,1.5)
   e.Speed = NumberRange.new(.2,.65); e.Acceleration = Vector3.new(0,.5,0)
   e.SpreadAngle = Vector2.new(45,45); e.Rotation = NumberRange.new(0,360)
   e.RotSpeed = NumberRange.new(-35,35); e.LightEmission = .8; e.LightInfluence = 0
   e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.2,spec.sparkSize),NumberSequenceKeypoint.new(1,0)})
   e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.15,.08),NumberSequenceKeypoint.new(.7,.2),NumberSequenceKeypoint.new(1,1)})
   e.Enabled = true; e.Parent = a; table.insert(emitters,e)
   if name == "Seal" and tier ~= "common" then
    local light = Instance.new("PointLight"); light.Color = colour
    light.Range = if tier == "legendary" then 8 else 5; light.Brightness = .3
    light.Shadows = false; light.Parent = a; table.insert(lights,light)
    local pulse = TweenService:Create(light,TweenInfo.new(1.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Brightness=if tier == "legendary" then 1.2 else .65})
    pulse:Play(); table.insert(tweens,pulse)
   end
   if name == "Aura" and tier == "legendary" then
    local mist = e:Clone(); mist.Name = "VioletWisps"
    mist.Texture = "rbxasset://textures/particles/smoke_main.dds"; mist.Rate = 3
    mist.Lifetime = NumberRange.new(1.1,1.8); mist.Speed = NumberRange.new(.25,.45)
    mist.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(.55,2.5),NumberSequenceKeypoint.new(1,3.3)})
    mist.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.87),NumberSequenceKeypoint.new(1,1)})
    mist.Parent = a; table.insert(emitters,mist)
   end
  end
 end
 table.insert(connections,model.Destroying:Connect(destroy))
 local controller = {}
 function controller.setEnabled(enabled: boolean)
  if disposed or context == "shop" then return end
  worldEnabled = enabled
  for _, emitter in emitters do emitter.Enabled = enabled; if not enabled then emitter:Clear() end end
  for _, light in lights do light.Enabled = enabled end
  for _, tween in tweens do if enabled then tween:Play() else tween:Pause() end end
 end
 function controller.burst()
  if disposed or not worldEnabled then return end
  for _, emitter in emitters do if emitter.Name == "TierMotes" then emitter:Emit(spec.burst) end end
 end
 function controller.open(lid: PVInstance)
  if disposed or openingValue then return end
  assert(lid:IsDescendantOf(model), "Lid must belong to the crate model")
  local p = spec.hinge
  local hinge = CFrame.new(p[1],p[2],p[3])
  local closed = root.CFrame:ToObjectSpace(lid:GetPivot())
  local angle = Instance.new("NumberValue"); angle.Name = "OpeningAngle"; angle.Parent = owned
  openingValue = angle
  openingConnection = angle.Changed:Connect(function(value)
   lid:PivotTo(root.CFrame * hinge * CFrame.Angles(-math.rad(value),0,0) * hinge:Inverse() * closed)
  end)
  motion = TweenService:Create(angle,TweenInfo.new(.65,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Value=100})
  motion:Play(); controller.burst()
 end
 controller.destroy = destroy
 return controller
end
return Presentation
