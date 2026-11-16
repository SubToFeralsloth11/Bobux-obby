-- Drives the game inside the mock: builds the world, plays a fake player
-- through every checkpoint, then runs the client for a few hundred frames.

local loaded = {}
local function run(inst)
	local entry = SOURCES[inst]
	if not entry then error("no source for " .. tostring(inst.Name)) end
	local chunk, err = loadstring(entry[1], "@" .. entry[2])
	if not chunk then error("SYNTAX: " .. err, 0) end
	local env = setmetatable({ script = inst, require = function(m)
		if loaded[m] == nil then loaded[m] = { run(m) } end
		return loaded[m][1]
	end }, { __index = _G })
	setfenv(chunk, env)
	return chunk()
end

-- every file must at least compile
local count = 0
for inst, entry in pairs(SOURCES) do
	local chunk, err = loadstring(entry[1], "@" .. entry[2])
	if not chunk then error("SYNTAX: " .. err, 0) end
	count = count + 1
end
print("compiled " .. count .. " scripts")

local Players = SERVICES("Players")
local RS = SERVICES("ReplicatedStorage")
local RunService = SERVICES("RunService")
local terrain = NEW("Terrain", "Terrain")
terrain.Parent = workspace

---------------------------------------------------------------- server
run(SERVICES("ServerScriptService").Server.Main)
FLUSH()
local obby = workspace.Obby
print("instances created: " .. INSTANCE_COUNT)

local function aabb(part)
	local c, s = part.CFrame, part.Size
	local m = c.m
	local ex = math.abs(m[1]) * s.X + math.abs(m[2]) * s.Y + math.abs(m[3]) * s.Z
	local ey = math.abs(m[4]) * s.X + math.abs(m[5]) * s.Y + math.abs(m[6]) * s.Z
	local ez = math.abs(m[7]) * s.X + math.abs(m[8]) * s.Y + math.abs(m[9]) * s.Z
	local p = c.Position
	return p.X - ex / 2, p.Y - ey / 2, p.Z - ez / 2, p.X + ex / 2, p.Y + ey / 2, p.Z + ez / 2
end

local stages = {}
local parts, solid = 0, 0
for _, folder in ipairs(obby:GetChildren()) do
	local box = { 1e9, 1e9, 1e9, -1e9, -1e9, -1e9 }
	local list = {}
	for _, p in ipairs(folder:GetChildren()) do
		if p:IsA("BasePart") then
			parts = parts + 1
			local s = p.Size
			assert(s.X > 0 and s.Y > 0 and s.Z > 0, "bad size on " .. p.Name .. " in " .. folder.Name)
			assert(p.CFrame.Position.X == p.CFrame.Position.X, "NaN position")
			if p.CanCollide and p.Name ~= "Trigger" and p.Name ~= "GatePillar" and p.Name ~= "GateSign" then
				solid = solid + 1
				local b = { aabb(p) }
				table.insert(list, b)
				for i = 1, 3 do box[i] = math.min(box[i], b[i]) box[i + 3] = math.max(box[i + 3], b[i + 3]) end
			end
		end
	end
	table.insert(stages, { name = folder.Name, box = box, list = list })
end
print(string.format("parts: %d (%d solid) in %d stage folders, coins: %d", parts, solid, #stages, obby:GetAttribute("CoinCount")))

local function hit(a, b) return a[1] < b[4] and b[1] < a[4] and a[2] < b[5] and b[2] < a[5] and a[3] < b[6] and b[3] < a[6] end
local clashes = 0
for i = 1, #stages do
	for j = i + 2, #stages do
		if hit(stages[i].box, stages[j].box) then
			for _, a in ipairs(stages[i].list) do
				for _, b in ipairs(stages[j].list) do
					if hit(a, b) then clashes = clashes + 1 end
				end
			end
		end
	end
end
print("solid parts overlapping between non-neighbouring stages: " .. clashes)

local world = {}
for _, trig in ipairs(TAGS.Checkpoint) do world[trig:GetAttribute("Stage")] = trig end
local minY, maxY = 1e9, -1e9
for i, trig in ipairs(world) do
	local p = trig.Position
	minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
	if i % 6 == 1 then print(string.format("  checkpoint %2d at (%7.1f, %6.1f, %7.1f)", i, p.X, p.Y - 6.2, p.Z)) end
end
print(string.format("checkpoints: %d, height range %.0f..%.0f", #world, minY, maxY))
assert(#world == 31, "expected 31 checkpoints")

-- the star wheel must lift riders up and over, not drag them underneath
for _, p in ipairs(TAGS.Rotor) do
	if p.Name == "WheelPlatform" and not WHEEL_CHECKED then
		local pivot, axis = p:GetAttribute("Pivot"), p:GetAttribute("Axis")
		local rel = p.Position - pivot
		if math.abs(rel.Y) < 0.01 then
			WHEEL_CHECKED = true
			local moved = CFrame.fromAxisAngle(axis, p:GetAttribute("Speed") * 0.2) * rel
			local toward = (world[26].Position - pivot):Dot(rel) > 0
			print(string.format("star wheel: platform on the %s side moves %s", toward and "entry" or "exit", moved.Y > 0 and "UP" or "DOWN"))
		end
	end
end

---------------------------------------------------------------- a player
local player = NEW("Player", "Tester")
player.UserId = 1
ON_LOAD_CHARACTER = function(p)
	local ch = NEW("Model", "Tester")
	local hum = NEW("Humanoid", "Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.Parent = ch
	local root = NEW("Part", "HumanoidRootPart")
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = p.RespawnLocation.CFrame + Vector3.new(0, 3, 0)
	root.Parent = ch
	ch.Parent = workspace
	p.Character = ch
	p.CharacterAdded:Fire(ch)
end
player.Parent = Players
Players.PlayerAdded:Fire(player)
FLUSH()
assert(player:GetAttribute("Ready"), "player never became ready")
assert(player.Character, "no character spawned")
local remotes = RS.Remotes

local function touch(i) world[i].Touched:Fire(player.Character.HumanoidRootPart) end
touch(5)
assert(player:GetAttribute("Stage") == 1, "skipping checkpoints must not work")
for i = 2, 31 do
	CLOCK = CLOCK + 20
	touch(i)
	assert(player:GetAttribute("Stage") == i, "checkpoint " .. i .. " not accepted")
end
assert(player:GetAttribute("Finished") == true and player:GetAttribute("Wins") == 1, "win not recorded")
print("server: reached all 31 checkpoints, coins = " .. player:GetAttribute("Coins") .. ", run time = " .. player:GetAttribute("RunTime"))
local coin = TAGS.Coin[1]
player.Character.HumanoidRootPart.CFrame = coin.CFrame
remotes.Collect.OnServerEvent:Fire(player, coin)
remotes.Collect.OnServerEvent:Fire(player, coin)
assert(string.sub(player:GetAttribute("CoinMask"), 1, 1) == "1", "coin not recorded")
local before = player:GetAttribute("Coins")
remotes.Shop.OnServerEvent:Fire(player, "Buy", "Spark")
assert(player:GetAttribute("Trail") == "Spark" and player:GetAttribute("Coins") == before - 20, "trail purchase failed")
remotes.Shop.OnServerEvent:Fire(player, "Buy", "Rainbow")
remotes.Collect.OnServerEvent:Fire(player, TAGS.PowerUp[1])
CLOCK = CLOCK + 5
remotes.Teleport.OnServerEvent:Fire(player, 12)
assert(player:GetAttribute("Stage") == 12, "teleport failed")
CLOCK = CLOCK + 5
remotes.Died.OnServerEvent:Fire(player)
FLUSH()
remotes.Restart.OnServerEvent:Fire(player)
assert(player:GetAttribute("Stage") == 1 and player:GetAttribute("MaxStage") == 1, "restart failed")
FLUSH()
print("server: coins, shop, teleport, death and restart OK")

---------------------------------------------------------------- client
Players.LocalPlayer = player
NEW("PlayerGui", "PlayerGui").Parent = player
local camera = NEW("Camera", "Camera")
camera.CFrame = CFrame.new(0, 130, 0)
camera.ViewportSize = Vector2.new(1280, 720)
camera.Parent = workspace
workspace.CurrentCamera = camera
QUERY = function(params, pos, radius)
	local out = {}
	for _, p in ipairs(params.FilterDescendantsInstances or {}) do
		if p.CanQuery and (p.Position - pos).Magnitude < radius + 6 then table.insert(out, p) end
	end
	return out
end
SERVER_REMOTE = function(remote, ...) remote.OnServerEvent:Fire(player, ...) end

run(SERVICES("StarterPlayer").StarterPlayerScripts.Client.Main)
FLUSH()
local hud = player.PlayerGui.ObbyHUD
print("client: started, HUD has " .. #hud:GetDescendants() .. " objects")

local deaths = 0
local function frames(n)
	for _ = 1, n do
		CLOCK = CLOCK + 1 / 60
		local ch = player.Character
		if ch and ch.Humanoid.Health <= 0 then
			deaths = deaths + 1
			ON_LOAD_CHARACTER(player)
		end
		RunService.Stepped:Fire(CLOCK, 1 / 60)
		RunService.Heartbeat:Fire(1 / 60)
		if RENDER_STEP then RENDER_STEP(1 / 60) end
		FLUSH()
	end
end
frames(30)
-- walk the character through every tagged thing in the world
local visited = 0
for _, tagName in ipairs({ "Coin", "PowerUp", "Bounce", "Vanish", "Kill", "Mover", "Rotor", "Blinker" }) do
	for i, part in ipairs(TAGS[tagName]) do
		if i % 3 == 1 then
			local ch = player.Character
			ch.HumanoidRootPart.CFrame = CFrame.new(part.Position + Vector3.new(0, 1, 0))
			camera.CFrame = CFrame.new(part.Position + Vector3.new(0, 10, 20))
			frames(2)
			visited = visited + 1
		end
	end
end
print(string.format("client: visited %d objects over many frames, died %d times, coins now %d", visited, deaths, player:GetAttribute("Coins")))
assert(deaths > 20, "hazards never killed the test character")

-- menus and notifications
local UI = loaded[SERVICES("StarterPlayer").StarterPlayerScripts.Client.UI][1]
for _, page in ipairs({ "Stages", "Trails", "Settings", "Finished" }) do UI.toggle(page) end
UI.close()
remotes.Notify.OnClientEvent:Fire("Checkpoint", { Stage = 2, New = true, Reward = 5 })
remotes.Notify.OnClientEvent:Fire("Win", { Time = 321.5, Best = true, Reward = 105 })
remotes.Notify.OnClientEvent:Fire("Shop", { Ok = true, Id = "Spark" })
for i = 2, 31 do touch(i) frames(1) end
frames(20)
print("client: menus, notifications and all five zone transitions OK")
print("ALL CHECKS PASSED")
