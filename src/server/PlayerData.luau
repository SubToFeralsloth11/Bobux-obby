--[[
	PlayerData
	Loads and saves player progress with DataStoreService. Everything is
	wrapped in pcall so the game still works in Studio with API access off
	(progress just won't persist there).
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerData = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)

function PlayerData.default()
	return {
		Stage = 1,
		MaxStage = 1,
		Coins = 0,
		Wins = 0,
		BestTime = 0,
		Elapsed = 0,
		Finished = false,
		CoinIds = {},
		Trails = { "None" },
		Trail = "None",
	}
end

-- Returns data, loadedOk. When loadedOk is false the data must not be saved
-- (so a DataStore outage can never wipe real progress).
function PlayerData.load(userId)
	local data = PlayerData.default()
	if not store then
		return data, false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync("p_" .. userId)
		end)
		if ok then
			if type(result) == "table" then
				for key, value in pairs(result) do
					data[key] = value
				end
			end
			return data, true
		end
		task.wait(attempt)
	end
	return data, false
end

function PlayerData.save(userId, data)
	if not store then
		return false
	end
	local ok = pcall(function()
		store:SetAsync("p_" .. userId, data)
	end)
	return ok
end

return PlayerData
