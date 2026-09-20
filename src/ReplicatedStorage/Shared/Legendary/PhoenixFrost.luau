-- Client companion for Ice Phoenix. Install separately after Studio import.
-- Play the supplied idle FBX via Animator; this animates masked emission only.
-- Crystal Crown atlas selects feather veins, tips and delicate face frost.
local RunService = game:GetService("RunService")
local Frost = {}
local PHASES = {
    ["Body"] = 0,
    ["Snout"] = 0,
    ["Ears"] = 0,
    ["Legs"] = 0,
    ["Tail"] = 0.43,
    ["Eyes"] = 0,
    ["Phoenix_Mantle_R_Feathers"] = 0.29,
    ["Phoenix_Mantle_L_Feathers"] = 0.22,
    ["Phoenix_BackMantle_Feathers"] = 0,
    ["Phoenix_Root_Feathers"] = 0,
    ["Phoenix_BackCover_Feathers"] = 0,
    ["Phoenix_Ruff_L_Feathers"] = 0.06,
    ["Phoenix_Ruff_R_Feathers"] = 0.12,
    ["Phoenix_Crest_0_Feathers"] = 0,
    ["Phoenix_Crest_1_Feathers"] = 0.09,
    ["Phoenix_Crest_2_Feathers"] = 0.17,
    ["Phoenix_Tail_Feathers"] = 0.43,
    ["Phoenix_Leg_LF_Feathers"] = 0,
    ["Phoenix_Leg_LB_Feathers"] = 0,
    ["Phoenix_Leg_RF_Feathers"] = 0,
    ["Phoenix_Leg_RB_Feathers"] = 0,
    ["Phoenix_VaultBlend_Feathers"] = 0,
}

function Frost.start(model: Model, phaseOffset: number?)
    local surfaces = {}
    for _, object in model:GetDescendants() do
        if object:IsA("SurfaceAppearance") and object:GetAttribute("PhoenixFrostGlow") == true then
            -- Assign phoenix_emissive.png before enabling this attribute.
            local parent = object.Parent
            local phase = if parent then PHASES[parent.Name] or 0 else 0
            surfaces[object] = { object.EmissiveStrength, object.EmissiveTint, phase }
        end
    end
    for surface in surfaces do surface.EmissiveTint = Color3.new(1, 1, 1) end
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
    end
    heartbeat = RunService.Heartbeat:Connect(function()
        local time = os.clock() - started + (phaseOffset or 0)
        for surface, state in surfaces do
            local theta = 2 * math.pi * (time / 4 - state[3])
            surface.EmissiveStrength = 1.1 + 4.4 * (0.5 - 0.5 * math.cos(theta)) ^ 2
                + 0.15 * math.sin(3 * theta)
        end
    end)
    destroying = model.Destroying:Connect(stop)
    return stop
end

return Frost
