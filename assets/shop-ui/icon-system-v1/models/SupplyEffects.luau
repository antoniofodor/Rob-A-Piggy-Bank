--!strict
-- Optional local visual effects for the exported supply models. No gameplay logic.
local Definitions = require(script.Parent.SupplyDefinitions)
local SupplyEffects = {}

function SupplyEffects.attach(model: Model, root: BasePart, key: string, worldEffects: boolean?)
 local spec = Definitions[key]
 assert(spec, "Unknown supply model")
 assert(root:IsDescendantOf(model), "Effect root must belong to the supply model")
 local attachments: {Attachment} = {}
 local emitters: {ParticleEmitter} = {}
 local lights: {PointLight} = {}
 local disposed = false
 local connection: RBXScriptConnection? = nil
 local function destroy()
  if disposed then return end
  disposed = true
  if connection then connection:Disconnect() end
  for _, attachment in attachments do attachment:Destroy() end
 end
 if worldEffects then
  for name, point in spec.attachments do
   local a = Instance.new("Attachment"); a.Name = "SupplyFX_" .. name
   assert(not root:FindFirstChild(a.Name), "Supply effects already attached; destroy the previous controller first")
   a.Position = Vector3.new(point[1],point[2],point[3]); a.Parent = root; table.insert(attachments,a)
   local e = Instance.new("ParticleEmitter"); e.Name = if key == "golden-bone" then "GoldenGlints" else "FuseSparks"
   e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
   e.Color = ColorSequence.new(Color3.fromRGB(255,207,90),Color3.fromRGB(255,251,220))
   e.LightEmission = 1; e.LightInfluence = 0
   e.Rate = if key == "golden-bone" then 2 else 5
   e.Lifetime = NumberRange.new(.25,.65); e.Speed = NumberRange.new(.10,.35)
   e.SpreadAngle = Vector2.new(70,70); e.Rotation = NumberRange.new(0,360)
   e.RotSpeed = NumberRange.new(-30,30)
   local size = if key == "golden-bone" then .22 else .12
   e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.25,size),NumberSequenceKeypoint.new(1,0)})
   e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,0),NumberSequenceKeypoint.new(1,1)})
   e.Parent = a; table.insert(emitters,e)
   if key == "bubblegum-bomb" then
    local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255,184,71)
    light.Brightness = .25; light.Range = 2; light.Shadows = false; light.Parent = a; table.insert(lights,light)
   end
  end
  connection = model.Destroying:Connect(destroy)
 end
 return {
  setEnabled = function(enabled: boolean)
   if disposed then return end
   for _, e in emitters do e.Enabled = enabled; if not enabled then e:Clear() end end
   for _, light in lights do light.Enabled = enabled end
  end,
  destroy = destroy,
 }
end
return SupplyEffects
