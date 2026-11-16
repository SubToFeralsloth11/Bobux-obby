--[[
	Game
	Server rules: spawning, checkpoints, coins, power-up validation, trails,
	stage teleporting, winning and saving.

	Player state is exposed to clients through attributes on the Player:
	Stage, MaxStage, Coins, Wins, BestTime, RunStart, RunTime, Finished,
	CoinMask, Trail, OwnedTrails.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)

local Game = {}

local world = nil
local sessions = {} -- [Player] = { data, loaded, runStart, lastTeleport, pickups, dirty }
local remotes = {}

local function now()
	return workspace:GetServerTimeNow()
end

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes.Folder
	remotes[name] = remote
	return remote
end

----------------------------------------------------------------------
-- Replicated state
----------------------------------------------------------------------

local function coinMask(data)
	local owned = {}
	for _, id in ipairs(data.CoinIds) do
		owned[id] = true
	end
	local chars = {}
	for i = 1, world.CoinCount do
		chars[i] = owned[i] and "1" or "0"
	end
	return table.concat(chars)
end

local function publish(player)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.data
	player:SetAttribute("Stage", data.Stage)
	player:SetAttribute("MaxStage", data.MaxStage)
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Wins", data.Wins)
	player:SetAttribute("BestTime", data.BestTime)
	player:SetAttribute("Finished", data.Finished)
	player:SetAttribute("RunStart", session.runStart)
	player:SetAttribute("RunTime", data.Elapsed)
	player:SetAttribute("Trail", data.Trail)
	player:SetAttribute("OwnedTrails", table.concat(data.Trails, ","))
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Stage.Value = math.min(data.MaxStage, Config.StageCount)
		stats.Coins.Value = data.Coins
		stats.Wins.Value = data.Wins
	end
	session.dirty = true
end

----------------------------------------------------------------------
-- Characters
----------------------------------------------------------------------

local function applyTrail(player, character)
	local session = sessions[player]
	local root = character:FindFirstChild("HumanoidRootPart")
	if not session or not root then
		return
	end
	local old = root:FindFirstChild("ObbyTrail")
	if old then
		old:Destroy()
	end
	local info = nil
	for _, trail in ipairs(Config.Trails) do
		if trail.Id == session.data.Trail then
			info = trail
		end
	end
	if not info or info.Id == "None" then
		return
	end
	local a0 = root:FindFirstChild("TrailTop") or Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, 0.9, 0)
	a0.Parent = root
	local a1 = root:FindFirstChild("TrailBottom") or Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, -0.9, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "ObbyTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.7
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	if info.Rainbow then
		local points = {}
		for i = 0, 6 do
			points[i + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6.001, 0.9, 1))
		end
		trail.Color = ColorSequence.new(points)
	else
		trail.Color = ColorSequence.new(info.A, info.B)
	end
	trail.Parent = root
end

local function spawnPlayer(player)
	local session = sessions[player]
	if not session or player.Parent ~= Players then
		return
	end
	local checkpoint = world.Checkpoints[session.data.Stage] or world.Checkpoints[1]
	player.RespawnLocation = checkpoint.Spawn
	session.spawning = true
	local ok = pcall(function()
		player:LoadCharacter()
	end)
	session.spawning = false
	if not ok then
		return
	end
	-- safety net: make sure the character really is on its checkpoint
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - checkpoint.Spawn.Position).Magnitude > 20 then
		character:PivotTo(checkpoint.Spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.UseJumpPower = true
	humanoid.WalkSpeed = Config.Physics.WalkSpeed
	humanoid.JumpPower = Config.Physics.JumpPower
	character:WaitForChild("HumanoidRootPart", 10)
	applyTrail(player, character)
	humanoid.Died:Connect(function()
		task.wait(Config.Physics.RespawnTime)
		if player.Character == character then
			spawnPlayer(player)
		end
	end)
end

----------------------------------------------------------------------
-- Checkpoints
----------------------------------------------------------------------

local function reachCheckpoint(player, index)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.data
	if index <= data.Stage or index > data.MaxStage + 1 then
		return
	end
	data.Stage = index
	player.RespawnLocation = world.Checkpoints[index].Spawn
	local isNew = index > data.MaxStage
	local reward = 0
	if isNew then
		data.MaxStage = index
		reward = Config.Rewards.Checkpoint
	end
	if index == Config.FinishIndex and not data.Finished then
		data.Finished = true
		data.Elapsed = now() - session.runStart
		data.Wins = data.Wins + 1
		reward = reward + Config.Rewards.Win
		local best = false
		if data.BestTime <= 0 or data.Elapsed < data.BestTime then
			data.BestTime = data.Elapsed
			best = true
		end
		data.Coins = data.Coins + reward
		publish(player)
		remotes.Notify:FireClient(player, "Win", { Time = data.Elapsed, Best = best, Reward = reward })
		return
	end
	data.Coins = data.Coins + reward
	publish(player)
	remotes.Notify:FireClient(player, "Checkpoint", { Stage = index, New = isNew, Reward = reward })
end

----------------------------------------------------------------------
-- Remote handlers
----------------------------------------------------------------------

local function characterRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root, humanoid, character
	end
	return nil
end

local function onDied(player)
	local _, humanoid = characterRoot(player)
	if humanoid then
		humanoid.Health = 0
	end
end

local function onCollect(player, part)
	local session = sessions[player]
	local root = characterRoot(player)
	if not session or not root or typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return
	end
	if not part:IsDescendantOf(world.Root) then
		return
	end
	if CollectionService:HasTag(part, "Coin") then
		local id = part:GetAttribute("Id")
		if type(id) ~= "number" or (root.Position - part.Position).Magnitude > 30 then
			return
		end
		if session.coins[id] then
			return
		end
		session.coins[id] = true
		table.insert(session.data.CoinIds, id)
		session.data.Coins = session.data.Coins + Config.Rewards.Coin
		player:SetAttribute("CoinMask", coinMask(session.data))
		publish(player)
	elseif CollectionService:HasTag(part, "PowerUp") then
		-- Effects are simulated by the client that owns the character; the
		-- server records them so everyone else can see the glow.
		local kind = part:GetAttribute("Kind")
		local cfg = Config.PowerUps[kind]
		if not cfg then
			return
		end
		local duration = part:GetAttribute("Duration") or cfg.Duration
		player:SetAttribute("PU_" .. kind, now() + duration)
		if kind == "Shield" then
			local _, _, character = characterRoot(player)
			local old = character:FindFirstChild("ObbyShield")
			if old then
				old:Destroy()
			end
			local field = Instance.new("ForceField")
			field.Name = "ObbyShield"
			field.Visible = true
			field.Parent = character
			task.delay(duration, function()
				if field.Parent then
					field:Destroy()
				end
			end)
		end
	end
end

local function onTeleport(player, index)
	local session = sessions[player]
	if not session or type(index) ~= "number" then
		return
	end
	index = math.floor(index)
	if index < 1 or index > session.data.MaxStage or not world.Checkpoints[index] then
		return
	end
	if now() - session.lastTeleport < 1 then
		return
	end
	session.lastTeleport = now()
	session.data.Stage = index
	publish(player)
	spawnPlayer(player)
end

local function onRestart(player)
	local session = sessions[player]
	if not session or now() - session.lastTeleport < 1 then
		return
	end
	session.lastTeleport = now()
	local data = session.data
	data.Stage = 1
	data.MaxStage = 1
	data.Finished = false
	data.Elapsed = 0
	data.CoinIds = {}
	session.coins = {}
	session.runStart = now()
	player:SetAttribute("CoinMask", coinMask(data))
	publish(player)
	spawnPlayer(player)
end

local function onShop(player, action, id)
	local session = sessions[player]
	if not session or type(id) ~= "string" then
		return
	end
	local info = nil
	for _, trail in ipairs(Config.Trails) do
		if trail.Id == id then
			info = trail
		end
	end
	if not info then
		return
	end
	local data = session.data
	local owned = table.find(data.Trails, id) ~= nil
	if action == "Buy" and not owned then
		if data.Coins < info.Price then
			remotes.Notify:FireClient(player, "Shop", { Ok = false, Id = id })
			return
		end
		data.Coins = data.Coins - info.Price
		table.insert(data.Trails, id)
		owned = true
		remotes.Notify:FireClient(player, "Shop", { Ok = true, Id = id })
	end
	if owned then
		data.Trail = id
		publish(player)
		if player.Character then
			applyTrail(player, player.Character)
		end
	end
end

----------------------------------------------------------------------
-- Joining and leaving
----------------------------------------------------------------------

local function save(player)
	local session = sessions[player]
	if not session or not session.loaded or not session.dirty then
		return
	end
	if not session.data.Finished then
		session.data.Elapsed = now() - session.runStart
	end
	session.dirty = false
	PlayerData.save(player.UserId, session.data)
end

local function onPlayerAdded(player)
	if sessions[player] then
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in ipairs({ "Stage", "Coins", "Wins" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player

	local data, loaded = PlayerData.load(player.UserId)
	if player.Parent ~= Players then
		return
	end
	-- repair anything odd in old saves
	if type(data.CoinIds) ~= "table" then
		data.CoinIds = {}
	end
	if type(data.Trails) ~= "table" then
		data.Trails = { "None" }
	end
	data.MaxStage = math.clamp(data.MaxStage or 1, 1, Config.FinishIndex)
	data.Stage = math.clamp(data.Stage or 1, 1, data.MaxStage)

	local session = {
		data = data,
		loaded = loaded,
		runStart = now() - (data.Elapsed or 0),
		lastTeleport = 0,
		coins = {},
		dirty = false,
	}
	for _, id in ipairs(data.CoinIds) do
		session.coins[id] = true
	end
	sessions[player] = session

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player:SetAttribute("CoinMask", coinMask(data))
	publish(player)
	player:SetAttribute("Ready", true)
	spawnPlayer(player)
end

local function onPlayerRemoving(player)
	save(player)
	sessions[player] = nil
end

function Game.start(builtWorld)
	world = builtWorld

	Players.CharacterAutoLoads = false
	Players.RespawnTime = Config.Physics.RespawnTime
	StarterPlayer.CharacterUseJumpPower = true
	StarterPlayer.CharacterWalkSpeed = Config.Physics.WalkSpeed
	StarterPlayer.CharacterJumpPower = Config.Physics.JumpPower
	StarterPlayer.CameraMaxZoomDistance = 60
	StarterPlayer.EnableMouseLockOption = true

	remotes.Folder = Instance.new("Folder")
	remotes.Folder.Name = "Remotes"
	makeRemote("Notify")
	makeRemote("Died").OnServerEvent:Connect(onDied)
	makeRemote("Collect").OnServerEvent:Connect(onCollect)
	makeRemote("Teleport").OnServerEvent:Connect(onTeleport)
	makeRemote("Restart").OnServerEvent:Connect(onRestart)
	makeRemote("Shop").OnServerEvent:Connect(onShop)
	remotes.Folder.Parent = ReplicatedStorage

	for index, checkpoint in pairs(world.Checkpoints) do
		checkpoint.Trigger.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				reachCheckpoint(player, index)
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- autosave + watchdog that revives anyone left without a character
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(3)
			ticks = ticks + 1
			for player, session in pairs(sessions) do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local alive = character and character.Parent and humanoid and humanoid.Health > 0
				if alive or session.spawning then
					session.missing = 0
				else
					session.missing = (session.missing or 0) + 1
					if session.missing >= 2 then
						session.missing = 0
						task.spawn(spawnPlayer, player)
					end
				end
				if ticks % 30 == 0 then
					task.spawn(save, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for player in pairs(sessions) do
			save(player)
		end
	end)
end

return Game
