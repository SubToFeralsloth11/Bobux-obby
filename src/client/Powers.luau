--[[
	Powers (client)
	Temporary power-ups. The client owns its character's physics, so effects
	are applied here the instant an orb is touched (no waiting on the
	server), and cleared when they run out or the player respawns.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Char = require(script.Parent.Char)

local Powers = {
	active = {}, -- [kind] = { expires = os.clock time, duration = seconds }
}

local usedAirJump = false
local lastJump = 0
local floatForce = nil

function Powers.has(kind)
	local entry = Powers.active[kind]
	return entry ~= nil and entry.expires > os.clock()
end

function Powers.grant(kind, duration)
	local cfg = Config.PowerUps[kind]
	if not cfg then
		return
	end
	duration = duration or cfg.Duration
	local entry = Powers.active[kind]
	local expires = os.clock() + duration
	if entry and entry.expires > expires then
		return -- already have a longer one
	end
	Powers.active[kind] = { expires = expires, duration = duration }
	Bus.fire("PowerChanged", kind, true)
end

function Powers.clear()
	for kind in pairs(Powers.active) do
		Powers.active[kind] = nil
		Bus.fire("PowerChanged", kind, false)
	end
end

local function setFloat(on)
	local root = Char.root
	if on and root and not floatForce then
		local attachment = Instance.new("Attachment")
		attachment.Name = "MoonBoots"
		attachment.Parent = root
		local force = Instance.new("VectorForce")
		force.Name = "MoonBootsForce"
		force.Attachment0 = attachment
		force.ApplyAtCenterOfMass = true
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * (1 - Config.PowerUps.Feather.GravityScale), 0)
		force.Parent = root
		floatForce = { force = force, attachment = attachment }
	elseif not on and floatForce then
		floatForce.force:Destroy()
		floatForce.attachment:Destroy()
		floatForce = nil
	end
end

local function update()
	local clock = os.clock()
	for kind, entry in pairs(Powers.active) do
		if entry.expires <= clock then
			Powers.active[kind] = nil
			Bus.fire("PowerChanged", kind, false)
			Bus.fire("Sfx", "PowerDown")
		end
	end
	if not Char.alive() then
		return
	end
	local humanoid = Char.humanoid
	local speed = Powers.has("Speed") and Config.PowerUps.Speed.WalkSpeed or Config.Physics.WalkSpeed
	local jump = Powers.has("Jump") and Config.PowerUps.Jump.JumpPower or Config.Physics.JumpPower
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
	if humanoid.JumpPower ~= jump then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = jump
	end
	setFloat(Powers.has("Feather"))
end

local function onJumpRequest()
	if not Powers.has("DoubleJump") or usedAirJump or not Char.alive() then
		return
	end
	local humanoid = Char.humanoid
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall and os.clock() - lastJump > 0.18 then
		usedAirJump = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		Bus.fire("Sfx", "DoubleJump")
		Bus.fire("AirJump", Char.root.Position)
	end
end

function Powers.start()
	Bus.on("Spawned", function(_, humanoid)
		floatForce = nil
		usedAirJump = false
		Powers.clear()
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.Climbing then
				usedAirJump = false
			elseif new == Enum.HumanoidStateType.Jumping then
				lastJump = os.clock()
			end
		end)
	end)
	Bus.on("Died", function()
		floatForce = nil
		Powers.clear()
	end)
	UserInputService.JumpRequest:Connect(onJumpRequest)
	RunService.Heartbeat:Connect(update)
end

return Powers
