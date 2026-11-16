--[[
	Touch (client)
	Decides what the local character is touching every frame: hazards,
	bounce pads, crumbling tiles, coins and power-ups, plus falling into the
	void. Doing this on the client (with exact box tests rather than Touched
	events) makes hits feel instant and fair even on a laggy connection.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Char = require(script.Parent.Char)
local Powers = require(script.Parent.Powers)
local World = require(script.Parent.World)

local Touch = {}

local player = Players.LocalPlayer
local remotes = nil

local kinds = {} -- [part] = "Kill" | "Bounce" | "Vanish" | "Coin" | "PowerUp"
local contactList, pickupList = {}, {}
local contactParams, pickupParams = OverlapParams.new(), OverlapParams.new()
local dirty = true
local checkpointY = {}
local dying = false
local lastBounce = 0
local bounceBoost = nil
local padCooldown = {}

local CONTACT = { Kill = true, Bounce = true, Vanish = true }

local function track(tagName)
	local isContact = CONTACT[tagName] == true
	local function add(part)
		if part:IsA("BasePart") and not kinds[part] then
			kinds[part] = tagName
			table.insert(isContact and contactList or pickupList, part)
			dirty = true
		end
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(add)
	for _, part in ipairs(CollectionService:GetTagged(tagName)) do
		add(part)
	end
end

----------------------------------------------------------------------
-- Exact overlap tests
----------------------------------------------------------------------

-- Oriented box vs oriented box (separating axis theorem).
local function boxesOverlap(cfA, sizeA, cfB, sizeB)
	local rel = cfA:ToObjectSpace(cfB)
	local t = rel.Position
	local ha, hb = sizeA / 2, sizeB / 2
	local a = { ha.X, ha.Y, ha.Z }
	local b = { hb.X, hb.Y, hb.Z }
	local axes = { rel.XVector, rel.YVector, rel.ZVector }
	local R, AbsR = {}, {}
	for i = 1, 3 do
		R[i], AbsR[i] = {}, {}
	end
	for j = 1, 3 do
		local v = axes[j]
		R[1][j], R[2][j], R[3][j] = v.X, v.Y, v.Z
		AbsR[1][j], AbsR[2][j], AbsR[3][j] = math.abs(v.X) + 1e-5, math.abs(v.Y) + 1e-5, math.abs(v.Z) + 1e-5
	end
	local tv = { t.X, t.Y, t.Z }
	for i = 1, 3 do
		if math.abs(tv[i]) > a[i] + b[1] * AbsR[i][1] + b[2] * AbsR[i][2] + b[3] * AbsR[i][3] then
			return false
		end
	end
	for j = 1, 3 do
		local proj = math.abs(tv[1] * R[1][j] + tv[2] * R[2][j] + tv[3] * R[3][j])
		if proj > a[1] * AbsR[1][j] + a[2] * AbsR[2][j] + a[3] * AbsR[3][j] + b[j] then
			return false
		end
	end
	for i = 1, 3 do
		local i1, i2 = i % 3 + 1, (i + 1) % 3 + 1
		for j = 1, 3 do
			local j1, j2 = j % 3 + 1, (j + 1) % 3 + 1
			local ra = a[i1] * AbsR[i2][j] + a[i2] * AbsR[i1][j]
			local rb = b[j1] * AbsR[i][j2] + b[j2] * AbsR[i][j1]
			if math.abs(tv[i2] * R[i1][j] - tv[i1] * R[i2][j]) > ra + rb then
				return false
			end
		end
	end
	return true
end

local function ballOverlaps(boxCF, boxSize, part)
	local p = boxCF:PointToObjectSpace(part.Position)
	local h = boxSize / 2
	local closest = Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z))
	return (p - closest).Magnitude <= part.Size.X / 2
end

local function touches(boxCF, boxSize, part)
	if part:IsA("Part") and part.Shape == Enum.PartType.Ball then
		return ballOverlaps(boxCF, boxSize, part)
	end
	return boxesOverlap(boxCF, boxSize, part.CFrame, part.Size)
end

----------------------------------------------------------------------
-- Reactions
----------------------------------------------------------------------

local function die(reason)
	if dying or not Char.alive() then
		return
	end
	dying = true
	Bus.fire("Sfx", "Death")
	Bus.fire("Death", Char.root.Position, reason)
	remotes.Died:FireServer()
	-- the client may always end its own character's life; this makes the
	-- reaction instant instead of waiting on the server
	Char.humanoid.Health = 0
end

local function bounce(part)
	local clock = os.clock()
	if clock - lastBounce < 0.3 then
		return
	end
	lastBounce = clock
	local power = part:GetAttribute("Power") or 80
	local root, humanoid = Char.root, Char.humanoid
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
	bounceBoost = { power = power, untilTime = clock + 0.06 }
	Bus.fire("Sfx", "Bounce")
	Bus.fire("Bounced", part)
end

local function collect(part, kind)
	if kind == "Coin" then
		World.hideCoin(part)
		remotes.Collect:FireServer(part)
		Bus.fire("Sfx", "Coin")
		Bus.fire("CoinGot", part.Position)
	else
		local clock = os.clock()
		if (padCooldown[part] or 0) > clock then
			return
		end
		local isPad = part:GetAttribute("Pad") == true
		padCooldown[part] = clock + (isPad and 0.6 or Config.PickupRespawn)
		local power = part:GetAttribute("Kind")
		Powers.grant(power, part:GetAttribute("Duration"))
		if not isPad then
			World.hideOrb(part, Config.PickupRespawn)
		end
		remotes.Collect:FireServer(part)
		Bus.fire("Sfx", "PowerUp")
		Bus.fire("PowerGot", power, part.Position)
	end
end

local function refreshCheckpoints()
	for _, trigger in ipairs(CollectionService:GetTagged("Checkpoint")) do
		local index = trigger:GetAttribute("Stage")
		if index then
			checkpointY[index] = trigger.Position.Y - 6
		end
	end
end

local function voidHeight()
	local stage = player:GetAttribute("Stage") or 1
	local a = checkpointY[stage]
	if not a then
		refreshCheckpoints()
		a = checkpointY[stage]
	end
	if not a then
		return -400
	end
	local b = checkpointY[stage + 1] or a
	return math.min(a, b) - Config.Physics.VoidMargin
end

local function step()
	if not Char.alive() then
		return
	end
	local root = Char.root
	if dirty then
		dirty = false
		contactParams.FilterType = Enum.RaycastFilterType.Include
		contactParams.FilterDescendantsInstances = contactList
		pickupParams.FilterType = Enum.RaycastFilterType.Include
		pickupParams.FilterDescendantsInstances = pickupList
	end

	if bounceBoost then
		if os.clock() < bounceBoost.untilTime then
			local v = root.AssemblyLinearVelocity
			if v.Y < bounceBoost.power * 0.8 then
				root.AssemblyLinearVelocity = Vector3.new(v.X, bounceBoost.power, v.Z)
			end
		else
			bounceBoost = nil
		end
	end

	if root.Position.Y < voidHeight() then
		die("void")
		return
	end

	-- the hitbox: a little wider than the body, reaching just below the feet
	local foot = Char.footOffset() + 0.2
	local top = 2.3
	local size = Vector3.new(2.2, foot + top, 1.2)
	local boxCF = root.CFrame * CFrame.new(0, (top - foot) / 2, 0)

	local near = workspace:GetPartBoundsInBox(boxCF, size + Vector3.new(1, 1, 1), contactParams)
	local shielded = Powers.has("Shield")
	for _, part in ipairs(near) do
		local kind = kinds[part]
		if touches(boxCF, size, part) then
			if kind == "Kill" then
				if not shielded then
					die("hazard")
					return
				end
			elseif kind == "Bounce" then
				bounce(part)
			elseif kind == "Vanish" then
				World.vanish(part)
			end
		end
	end

	local pickups = workspace:GetPartBoundsInRadius(root.Position, 4, pickupParams)
	for _, part in ipairs(pickups) do
		collect(part, kinds[part])
	end
end

function Touch.start()
	remotes = ReplicatedStorage:WaitForChild("Remotes")
	for _, tagName in ipairs({ "Kill", "Bounce", "Vanish", "Coin", "PowerUp" }) do
		track(tagName)
	end
	Bus.on("Spawned", function()
		dying = false
		bounceBoost = nil
	end)
	refreshCheckpoints()
	RunService.Heartbeat:Connect(step)
end

-- Respawn at the current checkpoint on request (R key / reset button).
function Touch.reset()
	die("reset")
end

return Touch
