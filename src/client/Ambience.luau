--[[
	Ambience (client)
	Blends lighting, fog, post-processing, clouds, music and drifting
	particles to match whichever zone the local player has reached.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Bus = require(script.Parent.Bus)
local Sound = require(script.Parent.Sound)

local Ambience = {}

local player = Players.LocalPlayer
local currentZone = 0
local musicLocked = true -- the title screen plays its own track first
local emitters = {}
local holder = nil

local PARTICLES = {
	Pollen = { Color = Color3.fromRGB(255, 250, 200), Rate = 10, Size = 0.35, Speed = 2, Life = 7, Accel = Vector3.new(0, 0.3, 0) },
	Embers = { Color = Color3.fromRGB(255, 140, 40), Rate = 26, Size = 0.4, Speed = 5, Life = 5, Accel = Vector3.new(0, 4, 0) },
	Snow = { Color = Color3.fromRGB(255, 255, 255), Rate = 60, Size = 0.3, Speed = 6, Life = 6, Accel = Vector3.new(0, -5, 0) },
	Glitch = { Color = Color3.fromRGB(0, 240, 230), Rate = 12, Size = 0.3, Speed = 3, Life = 5, Accel = Vector3.new(0, 1, 0) },
	Stars = { Color = Color3.fromRGB(220, 210, 255), Rate = 18, Size = 0.4, Speed = 1, Life = 8, Accel = Vector3.new(0, 0, 0) },
}

local function child(className, name)
	local inst = Lighting:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	return inst
end

local function apply(zoneIndex, duration)
	local zone = Config.Zones[zoneIndex]
	if not zone then
		return
	end
	Util.tween(Lighting, duration, zone.Lighting, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	Util.tween(child("Atmosphere", "ObbyAtmosphere"), duration, zone.Atmosphere, Enum.EasingStyle.Sine)
	Util.tween(child("ColorCorrectionEffect", "ObbyColor"), duration, zone.Color_Correction, Enum.EasingStyle.Sine)
	Util.tween(child("BloomEffect", "ObbyBloom"), duration, zone.Bloom, Enum.EasingStyle.Sine)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		Util.tween(clouds, duration, zone.Clouds, Enum.EasingStyle.Sine)
	end
	for name, emitter in pairs(emitters) do
		emitter.Enabled = name == zone.Particles
	end
	if not musicLocked then
		Sound.music(zone.Music)
	end
end

local function refresh(instant)
	local zoneIndex = Config.zoneOf(player:GetAttribute("Stage") or 1)
	if zoneIndex == currentZone then
		return
	end
	local first = currentZone == 0
	currentZone = zoneIndex
	apply(zoneIndex, (instant or first) and 0.1 or 3)
	if not first then
		Bus.fire("ZoneEntered", zoneIndex)
	end
end

-- Called when the title screen closes.
function Ambience.unlockMusic()
	musicLocked = false
	local zone = Config.Zones[math.max(currentZone, 1)]
	Sound.music(zone.Music)
end

function Ambience.start()
	holder = Instance.new("Part")
	holder.Name = "AmbientParticles"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(90, 1, 90)
	holder.Parent = workspace
	for name, info in pairs(PARTICLES) do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = name
		emitter.Color = ColorSequence.new(info.Color)
		emitter.LightEmission = 0.8
		emitter.Size = NumberSequence.new(info.Size)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.3),
			NumberSequenceKeypoint.new(0.8, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(info.Life * 0.6, info.Life)
		emitter.Speed = NumberRange.new(info.Speed * 0.5, info.Speed)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = info.Accel
		emitter.Rate = info.Rate
		emitter.Enabled = false
		emitter.Parent = holder
		emitters[name] = emitter
	end

	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			holder.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 14, 0))
		end
	end)

	player:GetAttributeChangedSignal("Stage"):Connect(function()
		refresh(false)
	end)
	refresh(true)
end

return Ambience
