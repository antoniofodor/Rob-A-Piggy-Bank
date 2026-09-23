-- Import companion, not installed in-game. Play dragon-idle.fbx through an
-- Animator separately; this module supplies material glow that FBX cannot carry.
local RunService = game:GetService("RunService")
local DragonGlow = {}

function DragonGlow.start(model: Model, phaseOffset: number?)
    local surfaces = {}
    local embers = {}
    for _, object in model:GetDescendants() do
        if object:IsA("SurfaceAppearance") and object:GetAttribute("DragonGlow") == true then
            -- Assign the appropriate body/trim emissive mask in Studio first.
            surfaces[object] = { object.EmissiveStrength, object.EmissiveTint }
        elseif object:IsA("BasePart") and string.match(object.Name, "^Dragon_.*_Ember$") then
            embers[object] = { object.Material, object.Color }
        end
    end
    for surface in surfaces do surface.EmissiveTint = Color3.new(1, 1, 1) end
    for part in embers do part.Material = Enum.Material.Neon end
    local started = os.clock()
    local stopped = false
    local heartbeat: RBXScriptConnection?
    local destroying: RBXScriptConnection?
    local function stop()
        if stopped then return end
        stopped = true
        if heartbeat then heartbeat:Disconnect() end
        if destroying then destroying:Disconnect() end
        for surface, state in surfaces do
            if surface.Parent then
                surface.EmissiveStrength = state[1]
                surface.EmissiveTint = state[2]
            end
        end
        for part, state in embers do
            if part.Parent then part.Material = state[1]; part.Color = state[2] end
        end
    end
    heartbeat = RunService.Heartbeat:Connect(function()
        local phase = (os.clock() - started + (phaseOffset or 0)) / 4
        local pulse = (0.5 - 0.5 * math.cos(2 * math.pi * phase)) ^ 2
        for surface in surfaces do surface.EmissiveStrength = 0.35 + 1.85 * pulse end
        for part in embers do
            part.Color = Color3.fromRGB(168, 55, 10):Lerp(Color3.fromRGB(255, 174, 58), pulse)
        end
    end)
    destroying = model.Destroying:Connect(stop)
    return stop
end

return DragonGlow
