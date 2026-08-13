-- Easing curves. 9 styles x 3 directions, no state.
-- PreviewEngine calls these directly; Exporter just maps the names onto TweenInfo.EasingStyle.

local Easing = {}

local PI = math.pi

local function linear(t)
	return t
end

-- Quad
local function inQuad(t)
	return t * t
end
local function outQuad(t)
	return t * (2 - t)
end
local function inOutQuad(t)
	if t < 0.5 then
		return 2 * t * t
	end
	return -1 + (4 - 2 * t) * t
end

-- Cubic
local function inCubic(t)
	return t * t * t
end
local function outCubic(t)
	local u = t - 1
	return u * u * u + 1
end
local function inOutCubic(t)
	if t < 0.5 then
		return 4 * t * t * t
	end
	local u = -2 * t + 2
	return 1 - (u * u * u) / 2
end

-- Quart
local function inQuart(t)
	return t * t * t * t
end
local function outQuart(t)
	local u = t - 1
	return 1 - u * u * u * u
end
local function inOutQuart(t)
	if t < 0.5 then
		return 8 * t * t * t * t
	end
	local u = -2 * t + 2
	return 1 - (u * u * u * u) / 2
end

-- Quint
local function inQuint(t)
	return t * t * t * t * t
end
local function outQuint(t)
	local u = t - 1
	return 1 + u * u * u * u * u
end
local function inOutQuint(t)
	if t < 0.5 then
		return 16 * t * t * t * t * t
	end
	local u = -2 * t + 2
	return 1 - (u * u * u * u * u) / 2
end

-- Sine
local function inSine(t)
	return 1 - math.cos(t * PI / 2)
end
local function outSine(t)
	return math.sin(t * PI / 2)
end
local function inOutSine(t)
	return -(math.cos(PI * t) - 1) / 2
end

-- Back
local BACK_C1 = 1.70158
local BACK_C3 = BACK_C1 + 1
local BACK_C2 = BACK_C1 * 1.525
local function inBack(t)
	return BACK_C3 * t * t * t - BACK_C1 * t * t
end
local function outBack(t)
	local u = t - 1
	return 1 + BACK_C3 * u * u * u + BACK_C1 * u * u
end
local function inOutBack(t)
	if t < 0.5 then
		local u = 2 * t
		return (u * u * ((BACK_C2 + 1) * u - BACK_C2)) / 2
	end
	local u = 2 * t - 2
	return (u * u * ((BACK_C2 + 1) * u + BACK_C2) + 2) / 2
end

-- Elastic
local ELASTIC_C4 = (2 * PI) / 3
local ELASTIC_C5 = (2 * PI) / 4.5
local function inElastic(t)
	if t == 0 or t == 1 then
		return t
	end
	return -(2 ^ (10 * t - 10)) * math.sin((t * 10 - 10.75) * ELASTIC_C4)
end
local function outElastic(t)
	if t == 0 or t == 1 then
		return t
	end
	return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * ELASTIC_C4) + 1
end
local function inOutElastic(t)
	if t == 0 or t == 1 then
		return t
	end
	if t < 0.5 then
		return -(2 ^ (20 * t - 10) * math.sin((20 * t - 11.125) * ELASTIC_C5)) / 2
	end
	return (2 ^ (-20 * t + 10) * math.sin((20 * t - 11.125) * ELASTIC_C5)) / 2 + 1
end

-- Bounce
local BOUNCE_N1 = 7.5625
local BOUNCE_D1 = 2.75
local function outBounce(t)
	if t < 1 / BOUNCE_D1 then
		return BOUNCE_N1 * t * t
	elseif t < 2 / BOUNCE_D1 then
		t -= 1.5 / BOUNCE_D1
		return BOUNCE_N1 * t * t + 0.75
	elseif t < 2.5 / BOUNCE_D1 then
		t -= 2.25 / BOUNCE_D1
		return BOUNCE_N1 * t * t + 0.9375
	else
		t -= 2.625 / BOUNCE_D1
		return BOUNCE_N1 * t * t + 0.984375
	end
end
local function inBounce(t)
	return 1 - outBounce(1 - t)
end
local function inOutBounce(t)
	if t < 0.5 then
		return (1 - outBounce(1 - 2 * t)) / 2
	end
	return (1 + outBounce(2 * t - 1)) / 2
end

local CURVES = {
	Linear = { In = linear, Out = linear, InOut = linear },
	Quad = { In = inQuad, Out = outQuad, InOut = inOutQuad },
	Cubic = { In = inCubic, Out = outCubic, InOut = inOutCubic },
	Quart = { In = inQuart, Out = outQuart, InOut = inOutQuart },
	Quint = { In = inQuint, Out = outQuint, InOut = inOutQuint },
	Sine = { In = inSine, Out = outSine, InOut = inOutSine },
	Back = { In = inBack, Out = outBack, InOut = inOutBack },
	Elastic = { In = inElastic, Out = outElastic, InOut = inOutElastic },
	Bounce = { In = inBounce, Out = outBounce, InOut = inOutBounce },
}

Easing.Styles = { "Linear", "Quad", "Cubic", "Quart", "Quint", "Sine", "Back", "Elastic", "Bounce" }
Easing.Directions = { "In", "Out", "InOut" }

function Easing.Ease(style, direction, t)
	local curveSet = CURVES[style]
	assert(curveSet, ("unknown easing style '%s'"):format(tostring(style)))
	local curve = curveSet[direction]
	assert(curve, ("unknown easing direction '%s'"):format(tostring(direction)))
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return curve(t)
end

return Easing
