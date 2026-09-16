-- Companion for the imported Phoenix. Call attach(model) on the client after
-- inserting the full, scaled Phoenix model. Returns cleanup. Animation playback
-- is separate: import Phoenix_Idle.fbx and play its published AnimationId in a loop.
local Effects = {}
function Effects.attach(model: Model): () -> ()
    local created: {Instance} = {}
    local body = model:FindFirstChild("Body", true)
    assert(body and body:IsA("BasePart"), "Phoenix import needs its Body mesh")
    local unit = body.Size.X / 2 -- source body width = 2 Blender units
    local function remember(ob: Instance): Instance
        table.insert(created, ob)
        return ob
    end
    for _, ob in model:GetDescendants() do
        if ob:IsA("BasePart") and string.find(ob.Name, "_Glow", 1, true) then
            ob.Material = Enum.Material.Neon
            ob.Color = Color3.fromRGB(255, 206, 49)
        end
    end
    for _, name in {"Crest_1", "TailFan_2"} do
        local bone: Bone? = nil
        for _, ob in model:GetDescendants() do
            if ob:IsA("Bone") and ob.Name == name then bone = ob; break end
        end
        assert(bone, "Phoenix import is missing feather bone " .. name)
        local tip = remember(Instance.new("Attachment")) :: Attachment
        tip.Name = "PhoenixFlameTip"
        -- Blender bone +Z is FBX bone local +Y; move toward the feather tip.
        tip.Position = Vector3.new(0, .58 * unit, 0)
        tip.Parent = bone
        local flame = remember(Instance.new("ParticleEmitter")) :: ParticleEmitter
        flame.Name = "PhoenixFlames"
        flame.Texture = "rbxasset://textures/particles/fire_main.dds"
        flame.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255,224,91)), ColorSequenceKeypoint.new(.4,Color3.fromRGB(255,130,18)), ColorSequenceKeypoint.new(1,Color3.fromRGB(220,43,11))})
        flame.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(.55,.45),NumberSequenceKeypoint.new(1,1)})
        flame.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,.16*unit),NumberSequenceKeypoint.new(.35,.25*unit),NumberSequenceKeypoint.new(1,0)})
        flame.Rate = 9; flame.Lifetime = NumberRange.new(.3,.65)
        flame.Speed = NumberRange.new(.12*unit,.25*unit)
        flame.Acceleration = Vector3.new(0,.45*unit,0)
        flame.SpreadAngle = Vector2.new(12,12); flame.LightEmission = 1
        flame.Rotation = NumberRange.new(-15,15); flame.RotSpeed = NumberRange.new(-20,20)
        flame.LockedToPart = false; flame.Parent = tip
        local ember = remember(Instance.new("ParticleEmitter")) :: ParticleEmitter
        ember.Name = "PhoenixEmbers"; ember.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        ember.Color = ColorSequence.new(Color3.fromRGB(255,178,34))
        ember.Size = NumberSequence.new(.025*unit)
        ember.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,.15),NumberSequenceKeypoint.new(.6,.25),NumberSequenceKeypoint.new(1,1)})
        ember.Rate = 3; ember.Lifetime = NumberRange.new(.7,1.3)
        ember.Speed = NumberRange.new(.12*unit,.32*unit); ember.Acceleration = Vector3.new(0,.2*unit,0)
        ember.SpreadAngle = Vector2.new(35,35); ember.LightEmission = 1; ember.Parent = tip
        local light = remember(Instance.new("PointLight")) :: PointLight
        light.Color = Color3.fromRGB(255,145,32); light.Brightness = .45
        light.Range = unit*.65; light.Shadows = false; light.Parent = tip
    end
    return function() for _, ob in created do ob:Destroy() end end
end
return Effects
