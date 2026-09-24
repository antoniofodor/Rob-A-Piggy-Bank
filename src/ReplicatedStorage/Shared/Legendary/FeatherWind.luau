--!strict
-- A soft gust bends the feathers back, with faster ripples strongest in the
-- gust. Delays carry it from crown to mantle to tail. Angles are in radians;
-- authored strength/flutter values are degrees. Integer harmonics loop cleanly.
local FeatherWind = {}

function FeatherWind.angle(phase: number, wind: { strength: number, delay: number, flutter: number }): number
	local w = phase - 2 * math.pi * wind.delay
	local gust = (0.5 - 0.5 * math.cos(w)) ^ 2
	local ripple = 0.65 * math.sin(5 * w) + 0.35 * math.sin(9 * w + 0.6)
	return math.rad(wind.strength * gust + wind.flutter * (0.15 + 0.85 * gust) * ripple)
end

return FeatherWind
