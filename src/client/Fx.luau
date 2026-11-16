-- Fx (client): particles, camera shake and field-of-view kicks.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Bus = require(script.Parent.Bus)
local Char = require(script.Parent.Char)
local Powers = require(script.Parent.Powers)

local Fx = {}

local shake = 0
local BASE_FOV = 70

-- A one-shot burst of sparkles at a world position.
function Fx.burst(position, color, count, speed, size, lifetime)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.9), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new((lifetime or 0.8) * 0.6, lifetime or 0.8)
	emitter.Speed = NumberRange.new((speed or 16) * 0.5, speed or 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Drag = 2
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count or 20)
	Debris:AddItem(holder, (lifetime or 0.8) + 0.5)
end

-- An expanding ring (double jump, bounce pads, checkpoints).
function Fx.ring(position, color, size)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.25, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	Util.tween(ring, 0.45, { Size = Vector3.new(0.1, size or 10, size or 10), Transparency = 1 })
	Debris:AddItem(ring, 0.6)
end

function Fx.shake(amount)
	shake = math.max(shake, amount)
end

local function render(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if shake > 0.01 then
		local offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake
		camera.CFrame = camera.CFrame * CFrame.new(offset)
		shake = shake * math.max(0, 1 - dt * 9)
	end
	local target = BASE_FOV + (Powers.has("Speed") and 12 or 0)
	local fov = camera.FieldOfView
	if math.abs(fov - target) > 0.05 then
		camera.FieldOfView = fov + (target - fov) * math.min(1, dt * 6)
	end
end

function Fx.start()
	Bus.on("Death", function(position)
		Fx.burst(position, Config.UI.Red, 40, 26, 1.2, 0.9)
		Fx.shake(1.2)
	end)
	Bus.on("CoinGot", function(position)
		Fx.burst(position, Config.UI.Yellow, 10, 10, 0.6, 0.5)
	end)
	Bus.on("PowerGot", function(kind, position)
		local color = Config.PowerUps[kind].Color
		Fx.burst(position, color, 26, 18, 1, 0.8)
		Fx.ring(position - Vector3.new(0, 2, 0), color, 14)
	end)
	Bus.on("AirJump", function(position)
		Fx.ring(position - Vector3.new(0, 2.6, 0), Config.PowerUps.DoubleJump.Color, 9)
	end)
	Bus.on("Bounced", function(part)
		Fx.ring(part.Position, Color3.fromRGB(255, 80, 170), 12)
		Fx.shake(0.4)
	end)
	Bus.on("CheckpointFx", function()
		if Char.root then
			local position = Char.root.Position
			Fx.ring(position - Vector3.new(0, 2.6, 0), Config.UI.Green, 20)
			Fx.burst(position + Vector3.new(0, 2, 0), Config.UI.Green, 36, 22, 1, 1.1)
		end
	end)
	Bus.on("WinFx", function()
		for i = 1, 8 do
			task.delay(i * 0.35, function()
				if Char.root then
					local offset = Vector3.new(math.random(-14, 14), math.random(8, 18), math.random(-14, 14))
					Fx.burst(Char.root.Position + offset, Color3.fromHSV(math.random(), 0.8, 1), 50, 30, 1.4, 1.4)
				end
			end)
		end
	end)
	RunService:BindToRenderStep("ObbyFx", Enum.RenderPriority.Camera.Value + 1, render)
end

return Fx
