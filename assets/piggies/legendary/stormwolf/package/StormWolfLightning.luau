-- Client-side import helper for the six new Storm Wolf lightning meshes.
-- Place this ModuleScript beside your cosmetic animator and call start(model).
-- Returns a cleanup function. This file is delivered, not installed in-game.
local RunService = game:GetService("RunService")
local Lightning = {}
local EVENTS = {
    {{3, 1}, {4, 0}, {6, 0.55}, {7, 0}, {11, 1}, {12, 0}, {34, 1}, {35, 0.45}, {36, 0}, {53, 1}, {54, 0}},
    {{11, 1}, {12, 0}, {14, 0.7}, {15, 0}, {38, 1}, {39, 0}, {41, 0.5}, {42, 0}},
    {{11, 0.85}, {12, 0}, {22, 1}, {23, 0}, {25, 0.5}, {26, 0}, {44, 1}, {45, 0}},
    {{6, 1}, {7, 0}, {11, 0.8}, {12, 0}, {31, 1}, {32, 0.6}, {33, 0}, {55, 1}, {56, 0}},
    {{9, 1}, {10, 0}, {11, 0.65}, {12, 0}, {27, 0.9}, {28, 0}, {47, 1}, {48, 0}},
    {{11, 1}, {12, 0}, {18, 1}, {19, 0}, {20, 0.4}, {21, 0}, {50, 1}, {51, 0}}
}

function Lightning.start(model: Model, phaseOffset: number?)
    local groups = {}
    local originals = {}
    local bodyGlow = {}
    for _, object in model:GetDescendants() do
        if object:IsA("BasePart") then
            local index = tonumber(string.match(object.Name, "^Lightning_p(%d+)$"))
            if index and EVENTS[index + 1] then
                groups[index + 1] = object
                originals[object] = { object.Transparency, object.Color, object.Material }
            end
        elseif object:IsA("SurfaceAppearance") and object:GetAttribute("StormWolfBodyGlow") == true then
            -- Set the emissive mask in Studio, then mark only those prepared
            -- SurfaceAppearances. Never turn an unmasked body emissive.
            bodyGlow[object] = { object.EmissiveStrength, object.EmissiveTint }
        end
    end
    for index = 1, 6 do
        assert(groups[index], "Storm Wolf is missing Lightning_p" .. (index - 1))
    end
    for _, object in groups do
        object.Material = Enum.Material.Neon
        object.Transparency = 1
    end
    for surface in bodyGlow do
        surface.EmissiveTint = Color3.new(1, 1, 1)
        surface.EmissiveStrength = 0.35
    end
    local started = os.clock()
    local lastFrame = -1
    local stopped = false
    local heartbeat: RBXScriptConnection?
    local destroying: RBXScriptConnection?
    local function stop()
        if stopped then return end
        stopped = true
        if heartbeat then heartbeat:Disconnect() end
        if destroying then destroying:Disconnect() end
        for object, state in originals do
            if object.Parent then
                object.Transparency = state[1]
                object.Color = state[2]
                object.Material = state[3]
            end
        end
        for surface, state in bodyGlow do
            if surface.Parent then
                surface.EmissiveStrength = state[1]
                surface.EmissiveTint = state[2]
            end
        end
    end
    heartbeat = RunService.Heartbeat:Connect(function()
        local frame = math.floor(((os.clock() - started + (phaseOffset or 0)) % 2) * 30) + 1
        if frame == lastFrame then return end
        lastFrame = frame
        local peak = 0
        for index, object in groups do
            local strength = 0
            for _, event in EVENTS[index] do
                if event[1] > frame then break end
                strength = event[2]
            end
            -- Deliberate hard steps: quick strikes, double hits and black gaps.
            object.Transparency = if strength == 0 then 1 else 1 - math.min(1, strength * 1.25)
            object.Color = Color3.fromRGB(65, 205, 255):Lerp(Color3.fromRGB(220, 250, 255), strength)
            peak = math.max(peak, strength)
        end
        for surface in bodyGlow do
            surface.EmissiveStrength = 0.35 + 4.65 * peak
        end
    end)
    destroying = model.Destroying:Connect(stop)
    return stop
end

return Lightning
