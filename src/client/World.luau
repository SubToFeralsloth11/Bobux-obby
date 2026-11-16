--[[
	World (client)
	Animates everything the server tagged: sliding platforms, spinners,
	blinking lasers, crumbling tiles, coins and power-up orbs. Positions are
	a pure function of the shared server clock, so every player sees the same
	thing, and each platform is given a matching velocity so that it carries
	whoever is standing on it.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Bus = require(script.Parent.Bus)

local World = {}

local player = Players.LocalPlayer
local TAU = math.pi * 2
local RANGE = 420 -- only animate things this close to the camera
local ZERO = Vector3.new(0, 0, 0)

local movers = {}
local rotors = {}
local blinkers = {}
local coins = {}
local orbs = {}
local lamps = {}
local vanishing = {}
local hiddenCoins = {}

----------------------------------------------------------------------
-- Easing: u is 0..1 through one full there-and-back cycle. Returns the
-- position 0..1 and its rate of change per unit u.
----------------------------------------------------------------------
local function ease(kind, u)
	if kind == "linear" then
		if u < 0.5 then
			return u * 2, 2
		end
		return 2 - u * 2, -2
	elseif kind == "hold" then
		local h = 0.15
		local span = 0.5 - h
		if u < h then
			return 0, 0
		elseif u < 0.5 then
			local s = (u - h) / span
			return s * s * (3 - 2 * s), 6 * s * (1 - s) / span
		elseif u < 0.5 + h then
			return 1, 0
		end
		local s = (u - 0.5 - h) / span
		return 1 - s * s * (3 - 2 * s), -6 * s * (1 - s) / span
	elseif kind == "slam" then
		if u < 0.45 then
			return 0, 0
		elseif u < 0.53 then
			local s = (u - 0.45) / 0.08
			return s * s, 2 * s / 0.08
		elseif u < 0.68 then
			return 1, 0
		end
		local s = (u - 0.68) / 0.32
		return 1 - s * s * (3 - 2 * s), -6 * s * (1 - s) / 0.32
	elseif kind == "loop" then
		return u, 1
	end
	return 0.5 - 0.5 * math.cos(TAU * u), math.pi * math.sin(TAU * u)
end

----------------------------------------------------------------------
-- Registration
----------------------------------------------------------------------

local function watch(tagName, list, build)
	local function add(part)
		if not part:IsA("BasePart") then
			return
		end
		local ok, entry = pcall(build, part)
		if ok and entry then
			entry.part = part
			list[part] = entry
		end
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(part)
		list[part] = nil
	end)
	for _, part in ipairs(CollectionService:GetTagged(tagName)) do
		add(part)
	end
end

local function buildMover(part)
	local p0, p1 = part:GetAttribute("P0"), part:GetAttribute("P1")
	if not p0 or not p1 then
		return nil
	end
	return {
		p0 = p0,
		delta = p1 - p0,
		period = part:GetAttribute("Period") or 4,
		phase = part:GetAttribute("Phase") or 0,
		ease = part:GetAttribute("Ease") or "sine",
		rot = part.CFrame - part.CFrame.Position,
		anchor = p0,
	}
end

local function buildRotor(part)
	local pivot, axis = part:GetAttribute("Pivot"), part:GetAttribute("Axis")
	if not pivot or not axis then
		return nil
	end
	local base = part.CFrame
	return {
		pivot = pivot,
		axis = axis,
		speed = part:GetAttribute("Speed") or 1,
		swing = part:GetAttribute("Swing"),
		period = part:GetAttribute("Period") or 3,
		phase = part:GetAttribute("Phase") or 0,
		upright = part:GetAttribute("Upright") == true,
		rel = CFrame.new(-pivot) * base,
		rot = base - base.Position,
		anchor = pivot,
	}
end

local function buildBlinker(part)
	return {
		on = part:GetAttribute("On") or 1,
		off = part:GetAttribute("Off") or 1,
		phase = part:GetAttribute("Phase") or 0,
		solid = part:GetAttribute("Solid") == true,
		alpha = part.Transparency,
		state = "",
		anchor = part.Position,
	}
end

local function buildSpinner(part)
	return { base = part.CFrame, anchor = part.Position, id = part:GetAttribute("Id") or 0, alpha = part.Transparency }
end

----------------------------------------------------------------------
-- Per-frame animation
----------------------------------------------------------------------

local function step()
	local t = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or ZERO

	for part, m in pairs(movers) do
		if (m.anchor - eye).Magnitude < RANGE then
			local a, rate = ease(m.ease, (t / m.period + m.phase) % 1)
			part.CFrame = CFrame.new(m.p0 + m.delta * a) * m.rot
			part.AssemblyLinearVelocity = m.delta * (rate / m.period)
		end
	end

	for part, r in pairs(rotors) do
		if (r.anchor - eye).Magnitude < RANGE then
			local angle, omega
			if r.swing then
				local w = TAU * (t / r.period + r.phase)
				angle = r.swing * math.sin(w)
				omega = r.swing * TAU / r.period * math.cos(w)
			else
				angle = (r.speed * t + r.phase * TAU) % TAU
				omega = r.speed
			end
			local turned = CFrame.new(r.pivot) * CFrame.fromAxisAngle(r.axis, angle) * r.rel
			local spin = r.axis * omega
			if r.upright then
				part.CFrame = CFrame.new(turned.Position) * r.rot
				part.AssemblyAngularVelocity = ZERO
			else
				part.CFrame = turned
				part.AssemblyAngularVelocity = spin
			end
			part.AssemblyLinearVelocity = spin:Cross(turned.Position - r.pivot)
		end
	end

	for part, b in pairs(blinkers) do
		if (b.anchor - eye).Magnitude < RANGE then
			local cycle = b.on + b.off
			local u = (t + b.phase * cycle) % cycle
			local state
			if b.solid then
				-- platform: warn before it disappears
				if u < b.on - 0.6 then
					state = "on"
				elseif u < b.on then
					state = "warn"
				else
					state = "off"
				end
			else
				-- hazard: warn before it switches on
				if u < b.on then
					state = "on"
				elseif u > cycle - 0.5 then
					state = "warn"
				else
					state = "off"
				end
			end
			if state == "warn" then
				local flicker = (math.floor(t * 14) % 2 == 0)
				if b.solid then
					part.Transparency = flicker and 0.55 or b.alpha
				else
					part.Transparency = flicker and 0.6 or 0.9
				end
			end
			if state ~= b.state then
				b.state = state
				if b.solid then
					part.CanCollide = state ~= "off"
					part.Transparency = (state == "off") and 0.88 or b.alpha
				else
					part.CanQuery = state == "on"
					part.Transparency = (state == "on") and b.alpha or ((state == "off") and 1 or 0.9)
				end
			end
		end
	end

	for part, c in pairs(coins) do
		if not hiddenCoins[c.id] and (c.anchor - eye).Magnitude < 220 then
			part.CFrame = c.base * CFrame.Angles(0, t * 2.4 + c.id, 0) + Vector3.new(0, math.sin(t * 2 + c.id) * 0.25, 0)
		end
	end

	for part, o in pairs(orbs) do
		if not o.pad and (o.anchor - eye).Magnitude < 220 then
			part.CFrame = o.base + Vector3.new(0, math.sin(t * 2.2 + o.id) * 0.4, 0)
		end
	end
end

----------------------------------------------------------------------
-- Things other modules trigger
----------------------------------------------------------------------

-- A crumbling tile: wobble, drop out, come back.
function World.vanish(part)
	if vanishing[part] then
		return
	end
	vanishing[part] = true
	Bus.fire("Sfx", "Crumble")
	task.spawn(function()
		local delayTime = part:GetAttribute("Delay") or 0.6
		local respawn = part:GetAttribute("Respawn") or 3
		local color = part.Color
		local started = os.clock()
		while os.clock() - started < delayTime do
			part.Color = (math.floor(os.clock() * 16) % 2 == 0) and Color3.fromRGB(255, 90, 70) or color
			task.wait()
		end
		part.Color = color
		part.CanCollide = false
		part.Transparency = 1
		task.wait(respawn)
		part.Transparency = 0.5
		task.wait(0.25)
		part.Transparency = 0
		part.CanCollide = true
		vanishing[part] = nil
	end)
end

-- Hide a power-up orb for a while after it is collected.
function World.hideOrb(part, seconds)
	local o = orbs[part]
	if not o or o.pad then
		return
	end
	part.Transparency = 1
	part.CanQuery = false
	local gui = part:FindFirstChildOfClass("BillboardGui")
	if gui then
		gui.Enabled = false
	end
	task.delay(seconds, function()
		part.Transparency = o.alpha
		part.CanQuery = true
		if gui then
			gui.Enabled = true
		end
	end)
end

local function refreshCoins()
	local mask = player:GetAttribute("CoinMask") or ""
	hiddenCoins = {}
	for i = 1, #mask do
		if string.sub(mask, i, i) == "1" then
			hiddenCoins[i] = true
		end
	end
	for part, c in pairs(coins) do
		local hidden = hiddenCoins[c.id] == true
		part.Transparency = hidden and 1 or 0
		part.CanQuery = not hidden
	end
end

function World.hideCoin(part)
	local c = coins[part]
	if c then
		hiddenCoins[c.id] = true
		part.Transparency = 1
		part.CanQuery = false
	end
end

local function refreshLamps()
	local reached = player:GetAttribute("MaxStage") or 1
	local stage = player:GetAttribute("Stage") or 1
	for part, lamp in pairs(lamps) do
		if lamp.stage == stage then
			part.Color = Color3.fromRGB(90, 255, 140)
		elseif lamp.stage <= reached then
			part.Color = Color3.fromRGB(60, 190, 110)
		else
			part.Color = Color3.fromRGB(255, 255, 255)
		end
	end
end

function World.start()
	watch("Mover", movers, buildMover)
	watch("Rotor", rotors, buildRotor)
	watch("Blinker", blinkers, buildBlinker)
	watch("Coin", coins, function(part)
		local entry = buildSpinner(part)
		task.defer(refreshCoins)
		return entry
	end)
	watch("PowerUp", orbs, function(part)
		local entry = buildSpinner(part)
		entry.pad = part:GetAttribute("Pad") == true
		return entry
	end)
	watch("CheckpointLight", lamps, function(part)
		task.defer(refreshLamps)
		return { stage = part:GetAttribute("Stage") or 0 }
	end)
	watch("Conveyor", {}, function(part)
		local velocity = part:GetAttribute("Velocity")
		if velocity then
			part.AssemblyLinearVelocity = velocity
		end
		return nil
	end)

	player:GetAttributeChangedSignal("CoinMask"):Connect(refreshCoins)
	player:GetAttributeChangedSignal("Stage"):Connect(refreshLamps)
	player:GetAttributeChangedSignal("MaxStage"):Connect(refreshLamps)
	refreshCoins()
	refreshLamps()

	RunService.Stepped:Connect(step)
end

return World
