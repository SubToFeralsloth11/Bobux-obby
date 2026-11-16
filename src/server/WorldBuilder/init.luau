--[[
	WorldBuilder
	Builds the whole obby from code when the server starts.

	Want to edit the map by hand in Studio instead? Press Run, copy
	Workspace.Obby, press Stop and paste it into Workspace. On the next start
	the builder finds that folder and uses it rather than building a new one.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Kit)
local Decor = require(script.Decor)

local WorldBuilder = {}

local ZONE_MODULES = { "Meadows", "Magma", "Frost", "Neon", "Starlight" }

local function setupLighting()
	local zone = Config.Zones[1]
	for key, value in pairs(zone.Lighting) do
		Lighting[key] = value
	end
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local function ensure(className, name)
		local inst = Lighting:FindFirstChild(name)
		if not inst then
			inst = Instance.new(className)
			inst.Name = name
			inst.Parent = Lighting
		end
		return inst
	end

	local atmosphere = ensure("Atmosphere", "ObbyAtmosphere")
	for key, value in pairs(zone.Atmosphere) do
		atmosphere[key] = value
	end
	local cc = ensure("ColorCorrectionEffect", "ObbyColor")
	for key, value in pairs(zone.Color_Correction) do
		cc[key] = value
	end
	local bloom = ensure("BloomEffect", "ObbyBloom")
	for key, value in pairs(zone.Bloom) do
		bloom[key] = value
	end
	local rays = ensure("SunRaysEffect", "ObbySunRays")
	rays.Intensity = 0.08
	rays.Spread = 0.6
	local sky = ensure("Sky", "ObbySky")
	sky.StarCount = 5000
	sky.SunAngularSize = 16
	sky.MoonAngularSize = 12

	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = zone.Clouds.Cover
		clouds.Density = zone.Clouds.Density
		clouds.Color = zone.Clouds.Color
		clouds.Parent = terrain
	end
end

-- Use a map that was baked into the place file.
local function adopt(root)
	local checkpoints = {}
	for _, trigger in ipairs(CollectionService:GetTagged("Checkpoint")) do
		if trigger:IsDescendantOf(root) then
			local index = trigger:GetAttribute("Stage")
			local spawn = trigger.Parent:FindFirstChild("Spawn")
			if index and spawn then
				checkpoints[index] = { Index = index, Spawn = spawn, Trigger = trigger, CFrame = spawn.CFrame }
			end
		end
	end
	return {
		Root = root,
		Checkpoints = checkpoints,
		CoinCount = root:GetAttribute("CoinCount") or 0,
	}
end

function WorldBuilder.build()
	setupLighting()

	local existing = workspace:FindFirstChild("Obby")
	if existing then
		return adopt(existing)
	end

	local root = Instance.new("Folder")
	root.Name = "Obby"

	local zones = {}
	local themes = {}
	for i, name in ipairs(ZONE_MODULES) do
		zones[i] = require(script.Zones:FindFirstChild(name))
		themes[i] = zones[i].Theme
	end

	local K = Kit.new(root, CFrame.new(0, 120, 0), themes, 2024)
	local lastZone = 0
	for _, stage in ipairs(Config.Stages) do
		K:checkpoint()
		local zone = zones[stage.Zone]
		if stage.Zone ~= lastZone then
			lastZone = stage.Zone
			K:push()
			zone.Backdrop(K)
			K:pop()
		end
		local build = zone.Stages[stage.Key]
		if not build then
			error("No builder for stage " .. tostring(stage.Key))
		end
		build(K)
		Decor.scatter(K, zone.Scatter)
	end
	K:checkpoint()
	Decor.finish(K)

	root:SetAttribute("CoinCount", K.coinCount)
	root.Parent = workspace

	return {
		Root = root,
		Checkpoints = K.checkpoints,
		CoinCount = K.coinCount,
	}
end

return WorldBuilder
