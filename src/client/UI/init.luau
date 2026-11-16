--[[
	UI (client)
	The whole interface, built from code: title screen, HUD (stage, progress,
	coins, timer, power-ups), toasts, zone cards, and the Stages / Trails /
	Settings menus. Everything scales to the screen, so it is comfortable on
	a phone, a tablet, a laptop or a TV, with mouse, touch, keyboard or
	gamepad.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Client = script.Parent
local Bus = require(Client.Bus)
local Sound = require(Client.Sound)
local Powers = require(Client.Powers)
local Touch = require(Client.Touch)
local Ambience = require(Client.Ambience)
local W = require(script.Widgets)

local UI = {}

local C = Config.UI
local make = Util.make
local player = Players.LocalPlayer
local remotes = nil

local gui, rootScale
local stageTitle, stageName, stageBadge, progressFill
local coinLabel, timerLabel
local tray, trayTiles = nil, {}
local toast, toastScale
local zoneCard, zoneTitle, zoneSub, zoneBar
local flash
local modal, modalTitle, pages, openPage = nil, nil, {}, nil
local stageButtons, trailRows = {}, {}
local hints = {}
local titleScreen, blur
local restartArmed = 0

local function attr(name, default)
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

----------------------------------------------------------------------
-- Layout scaling and device detection
----------------------------------------------------------------------

local function isTouch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function rescale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	local scale = math.min(size.X / 1280, size.Y / 720)
	if isTouch() then
		scale = scale * 1.25 -- fingers need bigger targets than a mouse
	end
	rootScale.Scale = math.clamp(scale, 0.5, 1.4)
end

local function refreshHints()
	local show = UserInputService.KeyboardEnabled and not isTouch()
	for _, hint in ipairs(hints) do
		hint.Visible = show
	end
end

----------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------

local function buildStagePill()
	local pill = W.panel(gui, {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 380, 0, 58),
		BackgroundTransparency = 0.1,
	}, 18)
	stageBadge = W.frame(pill, { Position = UDim2.new(0, 7, 0, 7), Size = UDim2.new(0, 44, 0, 44), BackgroundColor3 = C.Green })
	W.corner(stageBadge, 22)
	W.stroke(stageBadge, 2)
	W.label(stageBadge, "1", { Name = "Number", Position = UDim2.new(0.12, 0, 0.12, 0), Size = UDim2.new(0.76, 0, 0.76, 0) })
	stageTitle = W.label(pill, "STAGE 1 / 30", {
		Position = UDim2.new(0, 60, 0, 5),
		Size = UDim2.new(1, -70, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	stageName = W.label(pill, "", {
		Position = UDim2.new(0, 60, 0, 29),
		Size = UDim2.new(1, -70, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.SubText,
		Font = C.FontBody,
	})
	local bar = W.frame(pill, { Position = UDim2.new(0, 60, 1, -11), Size = UDim2.new(1, -72, 0, 6), BackgroundColor3 = C.PanelLight })
	W.corner(bar, 3)
	progressFill = W.frame(bar, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.Green })
	W.corner(progressFill, 3)
end

local function buildStats()
	local coins = W.panel(gui, { Name = "Coins", Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(0, 150, 0, 40), BackgroundTransparency = 0.1 }, 14)
	W.label(coins, "🪙", { Position = UDim2.new(0, 6, 0, 5), Size = UDim2.new(0, 30, 0, 30) })
	coinLabel = W.label(coins, "0", {
		Position = UDim2.new(0, 42, 0, 6),
		Size = UDim2.new(1, -50, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Yellow,
	})
	local timer = W.panel(gui, { Name = "Timer", Position = UDim2.new(0, 10, 0, 54), Size = UDim2.new(0, 150, 0, 40), BackgroundTransparency = 0.1 }, 14)
	W.label(timer, "⏱", { Position = UDim2.new(0, 6, 0, 5), Size = UDim2.new(0, 30, 0, 30) })
	timerLabel = W.label(timer, "0:00.0", {
		Position = UDim2.new(0, 42, 0, 6),
		Size = UDim2.new(1, -50, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function buildSideButtons()
	local column = W.frame(gui, {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 102),
		Size = UDim2.new(0, 60, 0, 250),
	})
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, column)
	local specs = {
		{ "🗺", C.Blue, "M", function() UI.toggle("Stages") end },
		{ "✨", C.Pink, "T", function() UI.toggle("Trails") end },
		{ "⚙", C.PanelLight, "P", function() UI.toggle("Settings") end },
		{ "↺", C.Red, "R", function() Touch.reset() end },
	}
	for i, spec in ipairs(specs) do
		local button = W.button(column, spec[1], spec[2], { Size = UDim2.new(0, 54, 0, 54), LayoutOrder = i }, spec[4])
		local hint = W.label(button, spec[3], {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 4, 1, 4),
			Size = UDim2.new(0, 20, 0, 20),
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Stroke,
			Font = C.FontBody,
		})
		W.corner(hint, 6)
		table.insert(hints, hint)
	end
end

local function buildTray()
	tray = W.frame(gui, {
		Name = "PowerUps",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(0, 700, 0, 56),
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
	}, tray)
	for _, kind in ipairs(Config.PowerUpOrder) do
		local cfg = Config.PowerUps[kind]
		local tile = W.panel(tray, { Name = kind, Size = UDim2.new(0, 150, 0, 56), Visible = false, BackgroundTransparency = 0.05 }, 14)
		W.label(tile, cfg.Icon, { Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(0, 34, 0, 34) })
		W.label(tile, cfg.Name, {
			Position = UDim2.new(0, 46, 0, 6),
			Size = UDim2.new(1, -54, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = cfg.Color,
		})
		local bar = W.frame(tile, { Position = UDim2.new(0, 46, 0, 34), Size = UDim2.new(1, -56, 0, 10), BackgroundColor3 = C.PanelLight })
		W.corner(bar, 5)
		local fill = W.frame(bar, { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = cfg.Color })
		W.corner(fill, 5)
		trayTiles[kind] = { tile = tile, fill = fill }
	end
end

local function buildToast()
	toast = W.label(gui, "", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.new(0, 560, 0, 44),
		TextColor3 = C.Green,
		Visible = false,
	})
	toastScale = make("UIScale", { Scale = 1 }, toast)

	zoneCard = W.frame(gui, {
		Name = "ZoneCard",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.34, 0),
		Size = UDim2.new(0, 760, 0, 150),
		Visible = false,
	})
	zoneSub = W.label(zoneCard, "ZONE 1", { Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.SubText })
	zoneTitle = W.label(zoneCard, "", { Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 76) })
	zoneBar = W.frame(zoneCard, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 110), Size = UDim2.new(0, 0, 0, 6) })
	W.corner(zoneBar, 3)
	W.label(zoneCard, "", { Name = "Tagline", Position = UDim2.new(0, 0, 0, 120), Size = UDim2.new(1, 0, 0, 26), Font = C.FontBody })

	flash = W.frame(gui, {
		Name = "Flash",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = C.Red,
		BackgroundTransparency = 1,
		ZIndex = 20,
	})
end

function UI.toast(text, color)
	toast.Text = text
	toast.TextColor3 = color or C.Green
	toast.TextTransparency = 0
	toast.Visible = true
	toastScale.Scale = 0.5
	Util.tween(toastScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	local stamp = os.clock()
	toast:SetAttribute("Stamp", stamp)
	task.delay(1.8, function()
		if toast:GetAttribute("Stamp") == stamp then
			toast.Visible = false
		end
	end)
end

local function showZone(zoneIndex)
	local zone = Config.Zones[zoneIndex]
	zoneSub.Text = "ZONE " .. zoneIndex
	zoneTitle.Text = string.upper(zone.Name)
	zoneTitle.TextColor3 = zone.Color
	zoneCard.Tagline.Text = zone.Tagline
	zoneBar.BackgroundColor3 = zone.Color
	zoneBar.Size = UDim2.new(0, 0, 0, 6)
	zoneCard.Visible = true
	W.pop(zoneCard)
	Util.tween(zoneBar, 0.6, { Size = UDim2.new(0, 520, 0, 6) })
	Sound.play("Zone")
	task.delay(3.2, function()
		zoneCard.Visible = false
	end)
end

----------------------------------------------------------------------
-- Menus
----------------------------------------------------------------------

function UI.close()
	if openPage then
		openPage = nil
		modal.Visible = false
		Sound.play("Close")
		GuiService.SelectedObject = nil
	end
end

function UI.toggle(name)
	if openPage == name then
		UI.close()
		return
	end
	openPage = name
	for pageName, page in pairs(pages) do
		page.Visible = pageName == name
	end
	modalTitle.Text = string.upper(name)
	modal.Visible = true
	W.pop(modal.Window)
	Sound.play("Open")
	UI.refreshMenus()
end

local function buildModal()
	modal = W.frame(gui, {
		Name = "Modal",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		Active = true,
		ZIndex = 10,
	})
	local window = W.panel(modal, {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 600, 0, 460),
		ZIndex = 11,
	}, 22)
	modalTitle = W.label(window, "MENU", { Position = UDim2.new(0, 24, 0, 12), Size = UDim2.new(1, -110, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 })
	W.button(window, "✕", C.Red, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.new(0, 46, 0, 46), ZIndex = 12 }, UI.close)

	local function page(name, scrolling)
		local frame
		if scrolling then
			frame = make("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 8,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(0, 0, 0, 0),
			}, nil)
		else
			frame = make("Frame", { BackgroundTransparency = 1 }, nil)
		end
		frame.Name = name
		frame.Position = UDim2.new(0, 20, 0, 66)
		frame.Size = UDim2.new(1, -40, 1, -84)
		frame.Visible = false
		frame.ZIndex = 12
		frame.Parent = window
		pages[name] = frame
		return frame
	end

	-- Stages: jump to any checkpoint you have already reached
	local stages = page("Stages", true)
	make("UIGridLayout", { CellSize = UDim2.new(0, 100, 0, 62), CellPadding = UDim2.new(0, 8, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, stages)
	for index, info in ipairs(Config.Stages) do
		local zone = Config.Zones[info.Zone]
		local button, label = W.button(stages, tostring(index), zone.Color, { LayoutOrder = index, ZIndex = 13 }, function()
			if index <= attr("MaxStage", 1) then
				remotes.Teleport:FireServer(index)
				UI.close()
			else
				Sound.play("Error")
			end
		end)
		label.ZIndex = 14
		stageButtons[index] = { button = button, label = label, color = zone.Color }
	end

	-- Trails
	local trails = page("Trails", true)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, trails)
	for i, info in ipairs(Config.Trails) do
		local row = W.frame(trails, { Size = UDim2.new(1, -14, 0, 58), BackgroundColor3 = C.PanelLight, LayoutOrder = i, ZIndex = 13 })
		W.corner(row, 12)
		local swatch = W.frame(row, { Position = UDim2.new(0, 10, 0, 14), Size = UDim2.new(0, 90, 0, 30), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 14 })
		W.corner(swatch, 8)
		if info.Rainbow then
			local points = {}
			for k = 0, 6 do
				points[k + 1] = ColorSequenceKeypoint.new(k / 6, Color3.fromHSV(k / 6.001, 0.9, 1))
			end
			make("UIGradient", { Color = ColorSequence.new(points) }, swatch)
		elseif info.A then
			make("UIGradient", { Color = ColorSequence.new(info.A, info.B) }, swatch)
		else
			swatch.BackgroundColor3 = C.Locked
		end
		W.label(row, info.Name, { Position = UDim2.new(0, 112, 0, 12), Size = UDim2.new(0, 200, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 14 })
		local button, label = W.button(row, "", C.Green, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 170, 0, 42),
			ZIndex = 14,
		}, function()
			local owned = string.find("," .. attr("OwnedTrails", "None") .. ",", "," .. info.Id .. ",", 1, true) ~= nil
			if owned then
				remotes.Shop:FireServer("Equip", info.Id)
			elseif attr("Coins", 0) >= info.Price then
				remotes.Shop:FireServer("Buy", info.Id)
				Sound.play("Buy")
			else
				Sound.play("Error")
				UI.toast("Not enough coins!", C.Red)
			end
		end)
		label.ZIndex = 15
		trailRows[i] = { info = info, button = button, label = label }
	end

	-- Settings
	local settings = page("Settings", false)
	local function toggleRow(y, text, get, set)
		W.label(settings, text, { Position = UDim2.new(0, 6, 0, y), Size = UDim2.new(0, 300, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 })
		local button, label
		button, label = W.button(settings, "ON", C.Green, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, y), Size = UDim2.new(0, 130, 0, 42), ZIndex = 13 }, function()
			set(not get())
			label.Text = get() and "ON" or "OFF"
			button.BackgroundColor3 = get() and C.Green or C.Locked
		end)
		label.ZIndex = 14
	end
	toggleRow(4, "Music", function() return Sound.musicOn end, Sound.setMusic)
	toggleRow(58, "Sound effects", function() return Sound.sfxOn end, Sound.setSfx)
	W.label(settings, "Start a fresh run from Stage 1 (keeps coins and trails)", {
		Position = UDim2.new(0, 6, 0, 118),
		Size = UDim2.new(1, -160, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = C.FontBody,
		TextColor3 = C.SubText,
		ZIndex = 13,
	})
	local restart, restartLabel
	restart, restartLabel = W.button(settings, "RESTART", C.Red, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 118), Size = UDim2.new(0, 130, 0, 42), ZIndex = 13 }, function()
		if os.clock() - restartArmed < 3 then
			restartArmed = 0
			restartLabel.Text = "RESTART"
			remotes.Restart:FireServer()
			UI.close()
		else
			restartArmed = os.clock()
			restartLabel.Text = "SURE?"
		end
	end)
	restartLabel.ZIndex = 14
	W.label(settings, "CONTROLS\nKeyboard: WASD / arrows to move, Space to jump, Shift for mouse lock, R to respawn\nTouch: thumbstick to move, jump button to jump\nGamepad: left stick to move, A to jump", {
		Position = UDim2.new(0, 6, 0, 180),
		Size = UDim2.new(1, -12, 0, 180),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = C.FontBody,
		TextColor3 = C.SubText,
		TextScaled = false,
		TextSize = 18,
		ZIndex = 13,
	})

	-- Win
	local win = page("Finished", false)
	W.label(win, "🏆", { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 90), ZIndex = 13 })
	W.label(win, "YOU BEAT " .. Config.GameName .. "!", { Position = UDim2.new(0, 0, 0, 96), Size = UDim2.new(1, 0, 0, 50), TextColor3 = C.Yellow, ZIndex = 13 })
	W.label(win, "", { Name = "Time", Position = UDim2.new(0, 0, 0, 152), Size = UDim2.new(1, 0, 0, 40), ZIndex = 13 })
	W.label(win, "", { Name = "Detail", Position = UDim2.new(0, 0, 0, 196), Size = UDim2.new(1, 0, 0, 30), Font = C.FontBody, TextColor3 = C.SubText, ZIndex = 13 })
	local again, againLabel = W.button(win, "PLAY AGAIN", C.Green, { Position = UDim2.new(0.5, -210, 0, 262), Size = UDim2.new(0, 200, 0, 56), ZIndex = 13 }, function()
		remotes.Restart:FireServer()
		UI.close()
	end)
	againLabel.ZIndex = 14
	local keep, keepLabel = W.button(win, "KEEP EXPLORING", C.Blue, { Position = UDim2.new(0.5, 10, 0, 262), Size = UDim2.new(0, 200, 0, 56), ZIndex = 13 }, UI.close)
	keepLabel.ZIndex = 14
	local _ = again, keep
end

function UI.refreshMenus()
	local maxStage = attr("MaxStage", 1)
	local stage = attr("Stage", 1)
	for index, entry in ipairs(stageButtons) do
		local unlocked = index <= maxStage
		entry.button.BackgroundColor3 = unlocked and entry.color or C.Locked
		entry.label.Text = unlocked and ((index == stage) and ("▶ " .. index) or tostring(index)) or "🔒"
	end
	local owned = "," .. attr("OwnedTrails", "None") .. ","
	local equipped = attr("Trail", "None")
	for _, row in ipairs(trailRows) do
		local id = row.info.Id
		if id == equipped then
			row.label.Text = "EQUIPPED"
			row.button.BackgroundColor3 = C.Locked
		elseif string.find(owned, "," .. id .. ",", 1, true) then
			row.label.Text = "EQUIP"
			row.button.BackgroundColor3 = C.Blue
		else
			row.label.Text = "🪙 " .. row.info.Price
			row.button.BackgroundColor3 = (attr("Coins", 0) >= row.info.Price) and C.Green or C.Red
		end
	end
end

----------------------------------------------------------------------
-- Title screen
----------------------------------------------------------------------

local function buildTitle()
	blur = Instance.new("BlurEffect")
	blur.Name = "ObbyTitleBlur"
	blur.Size = 18
	blur.Parent = Lighting

	titleScreen = W.frame(gui, {
		Name = "Title",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(10, 12, 28),
		BackgroundTransparency = 0.35,
		Active = true,
		ZIndex = 30,
	})
	local logo = W.label(titleScreen, Config.GameName, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		Size = UDim2.new(0, 820, 0, 150),
		ZIndex = 31,
	})
	W.gradient(logo, C.Yellow, Color3.fromRGB(255, 120, 60))
	W.label(titleScreen, Config.Tagline, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.46, 0),
		Size = UDim2.new(0, 700, 0, 34),
		TextColor3 = C.SubText,
		Font = C.FontBody,
		ZIndex = 31,
	})
	local play, playLabel
	play, playLabel = W.button(titleScreen, "PLAY", C.Green, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.64, 0),
		Size = UDim2.new(0, 280, 0, 84),
		ZIndex = 31,
	}, function()
		Util.tween(blur, 0.5, { Size = 0 })
		Util.tween(titleScreen, 0.4, { BackgroundTransparency = 1 })
		for _, item in ipairs(titleScreen:GetChildren()) do
			item.Visible = false
		end
		task.delay(0.5, function()
			titleScreen.Visible = false
			blur.Enabled = false
		end)
		Ambience.unlockMusic()
		showZone(Config.zoneOf(attr("Stage", 1)))
	end)
	playLabel.ZIndex = 32
	local hintText = "WASD + Space to play"
	if isTouch() then
		hintText = "Use the thumbstick and jump button"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		hintText = "Left stick to move, A to jump"
	end
	W.label(titleScreen, hintText, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.8, 0),
		Size = UDim2.new(0, 600, 0, 26),
		TextColor3 = C.SubText,
		Font = C.FontBody,
		ZIndex = 31,
	})
	-- a gentle pulse on the play button
	task.spawn(function()
		local scale = play:FindFirstChildOfClass("UIScale")
		while titleScreen.Visible and scale do
			Util.tween(scale, 0.7, { Scale = 1.07 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(0.7)
			Util.tween(scale, 0.7, { Scale = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(0.7)
		end
	end)
	GuiService.SelectedObject = (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled) and play or nil
end

----------------------------------------------------------------------
-- State updates
----------------------------------------------------------------------

local function refreshStage()
	local stage = attr("Stage", 1)
	local shown = math.min(stage, Config.StageCount)
	local info = Config.Stages[shown]
	local zone = Config.Zones[Config.zoneOf(stage)]
	if stage >= Config.FinishIndex then
		stageTitle.Text = "FINISHED!"
		stageName.Text = "You beat every stage"
		stageBadge.Number.Text = "🏁"
	else
		stageTitle.Text = "STAGE " .. shown .. " / " .. Config.StageCount
		stageName.Text = info.Name .. "  ·  " .. zone.Name
		stageBadge.Number.Text = tostring(shown)
	end
	stageBadge.BackgroundColor3 = zone.Color
	progressFill.BackgroundColor3 = zone.Color
	Util.tween(progressFill, 0.5, { Size = UDim2.new((stage - 1) / Config.StageCount, 0, 1, 0) })
	UI.refreshMenus()
end

local function refreshCoins()
	coinLabel.Text = Util.formatNumber(attr("Coins", 0))
	if openPage then
		UI.refreshMenus()
	end
end

local function tick()
	-- timer
	if attr("Finished", false) then
		timerLabel.Text = Util.formatTime(attr("RunTime", 0))
		timerLabel.TextColor3 = C.Yellow
	else
		timerLabel.Text = Util.formatTime(workspace:GetServerTimeNow() - attr("RunStart", workspace:GetServerTimeNow()))
		timerLabel.TextColor3 = C.Text
	end
	-- power-up tray
	local clock = os.clock()
	for kind, entry in pairs(trayTiles) do
		local active = Powers.active[kind]
		if active and active.expires > clock then
			local left = active.expires - clock
			entry.tile.Visible = true
			entry.fill.Size = UDim2.new(math.clamp(left / active.duration, 0, 1), 0, 1, 0)
			-- blink when nearly out
			entry.tile.BackgroundTransparency = (left < 2 and math.floor(clock * 8) % 2 == 0) and 0.5 or 0.05
		else
			entry.tile.Visible = false
		end
	end
end

local function onNotify(kind, data)
	if kind == "Checkpoint" then
		if data.New then
			UI.toast("CHECKPOINT!  +" .. data.Reward .. " 🪙", C.Green)
			Sound.play("Checkpoint")
			Bus.fire("CheckpointFx")
		end
	elseif kind == "Win" then
		Sound.play("Win")
		Sound.play("Fanfare")
		Bus.fire("WinFx")
		local page = pages.Finished
		page.Time.Text = "Time  " .. Util.formatTime(data.Time)
		page.Detail.Text = (data.Best and "New personal best!  " or "") .. "+" .. data.Reward .. " coins"
		UI.toggle("Finished")
	elseif kind == "Shop" then
		if data.Ok then
			UI.toast("Trail unlocked!", C.Pink)
		else
			UI.toast("Not enough coins!", C.Red)
		end
	end
end

local function bind(name, callback, ...)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin and not titleScreen.Visible then
			callback()
		end
		return Enum.ContextActionResult.Pass
	end, false, ...)
end

function UI.start()
	remotes = ReplicatedStorage:WaitForChild("Remotes")
	gui = make("ScreenGui", {
		Name = "ObbyHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
	}, nil)
	rootScale = make("UIScale", { Scale = 1 }, gui)

	buildStagePill()
	buildStats()
	buildSideButtons()
	buildTray()
	buildToast()
	buildModal()
	buildTitle()
	gui.Parent = player:WaitForChild("PlayerGui")

	rescale()
	refreshHints()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	UserInputService.LastInputTypeChanged:Connect(function()
		rescale()
		refreshHints()
	end)

	for _, name in ipairs({ "Stage", "MaxStage", "Trail", "OwnedTrails" }) do
		player:GetAttributeChangedSignal(name):Connect(refreshStage)
	end
	player:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
	refreshStage()
	refreshCoins()

	remotes.Notify.OnClientEvent:Connect(onNotify)
	Bus.on("ZoneEntered", showZone)
	Bus.on("Death", function()
		flash.BackgroundTransparency = 0.45
		Util.tween(flash, 0.6, { BackgroundTransparency = 1 })
	end)
	Bus.on("PowerGot", function(kind)
		local cfg = Config.PowerUps[kind]
		UI.toast(cfg.Icon .. " " .. cfg.Name .. "!  " .. cfg.Desc, cfg.Color)
	end)

	bind("ObbyReset", Touch.reset, Enum.KeyCode.R, Enum.KeyCode.DPadDown)
	bind("ObbyStages", function() UI.toggle("Stages") end, Enum.KeyCode.M, Enum.KeyCode.DPadUp)
	bind("ObbyTrails", function() UI.toggle("Trails") end, Enum.KeyCode.T, Enum.KeyCode.DPadLeft)
	bind("ObbySettings", function() UI.toggle("Settings") end, Enum.KeyCode.P, Enum.KeyCode.DPadRight)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed = elapsed + dt
		if elapsed >= 0.05 then
			elapsed = 0
			tick()
		end
	end)
end

return UI
