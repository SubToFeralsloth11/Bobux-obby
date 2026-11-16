--[[
	Util
	Small helpers shared by the server and the client.
]]

local TweenService = game:GetService("TweenService")

local Util = {}

-- Create an instance, set its properties, then parent it.
function Util.make(className, props, parent)
	local inst = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			inst[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Play a tween and return it.
function Util.tween(inst, duration, goal, style, direction, delayTime)
	local info = TweenInfo.new(
		duration,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out,
		0,
		false,
		delayTime or 0
	)
	local tween = TweenService:Create(inst, info, goal)
	tween:Play()
	return tween
end

-- 83.42 -> "1:23.4"
function Util.formatTime(seconds)
	if seconds == nil or seconds < 0 then
		seconds = 0
	end
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	local whole = math.floor(rest)
	local tenths = math.floor((rest - whole) * 10)
	return string.format("%d:%02d.%d", minutes, whole, tenths)
end

-- 12345 -> "12,345"
function Util.formatNumber(n)
	local s = tostring(math.floor(n + 0.5))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return s .. out
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

return Util
