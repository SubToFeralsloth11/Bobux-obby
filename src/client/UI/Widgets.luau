-- Widgets: small factory functions that give every piece of UI the same look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Bus = require(script.Parent.Parent.Bus)

local Widgets = {}

local C = Config.UI
local make = Util.make

function Widgets.corner(parent, radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

function Widgets.stroke(parent, thickness, color, transparency)
	return make("UIStroke", {
		Thickness = thickness or 3,
		Color = color or C.Stroke,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function Widgets.gradient(parent, top, bottom, rotation)
	return make("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 }, parent)
end

function Widgets.frame(parent, props)
	local frame = make("Frame", {
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
	}, nil)
	for key, value in pairs(props or {}) do
		frame[key] = value
	end
	frame.Parent = parent
	return frame
end

-- A rounded dark panel with an outline.
function Widgets.panel(parent, props, radius)
	local frame = Widgets.frame(parent, props)
	Widgets.corner(frame, radius or 16)
	Widgets.stroke(frame, 3)
	return frame
end

function Widgets.label(parent, text, props)
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Text = text,
		Font = C.Font,
		TextColor3 = C.Text,
		TextScaled = true,
		TextWrapped = true,
	}, nil)
	for key, value in pairs(props or {}) do
		label[key] = value
	end
	label.Parent = parent
	-- an outline keeps text readable over any background
	make("UIStroke", { Thickness = 2, Color = C.Stroke, Transparency = 0.15 }, label)
	return label
end

--[[
	A chunky button that grows on hover, squashes on press and clicks.
	Works the same for mouse, touch and gamepad (Activated covers all three).
]]
function Widgets.button(parent, text, color, props, onClick)
	local button = make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color or C.Blue,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.new(0, 160, 0, 48),
	}, nil)
	for key, value in pairs(props or {}) do
		button[key] = value
	end
	button.Parent = parent
	Widgets.corner(button, 14)
	Widgets.stroke(button, 3)
	Widgets.gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205))
	local scale = make("UIScale", { Scale = 1 }, button)
	local label = Widgets.label(button, text, {
		Name = "Label",
		Position = UDim2.new(0.08, 0, 0.14, 0),
		Size = UDim2.new(0.84, 0, 0.72, 0),
	})
	button.MouseEnter:Connect(function()
		Util.tween(scale, 0.12, { Scale = 1.06 })
		Bus.fire("Sfx", "Hover")
	end)
	button.MouseLeave:Connect(function()
		Util.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Util.tween(scale, 0.06, { Scale = 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		Util.tween(scale, 0.1, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		Bus.fire("Sfx", "Click")
		if onClick then
			onClick()
		end
	end)
	return button, label
end

-- Pop an element in with a springy scale.
function Widgets.pop(guiObject)
	local scale = guiObject:FindFirstChildOfClass("UIScale") or make("UIScale", { Scale = 1 }, guiObject)
	scale.Scale = 0.6
	Util.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

return Widgets
