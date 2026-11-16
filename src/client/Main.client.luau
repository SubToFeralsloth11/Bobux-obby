-- Bobux Obby client entry point.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent
local player = Players.LocalPlayer

-- wait for the server to build the world and load our save
workspace:WaitForChild("Obby")
ReplicatedStorage:WaitForChild("Remotes")
while not player:GetAttribute("Ready") do
	task.wait(0.1)
end

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Bus = require(Client.Bus)
local Char = require(Client.Char)
local Sound = require(Client.Sound)
local World = require(Client.World)
local Powers = require(Client.Powers)
local Touch = require(Client.Touch)
local Fx = require(Client.Fx)
local Ambience = require(Client.Ambience)
local UI = require(Client.UI)

Sound.start()
Bus.on("Sfx", Sound.play)
World.start()
Powers.start()
Touch.start()
Fx.start()
Ambience.start()
UI.start()
Char.start()

Sound.music(Config.Audio.Music.Title)
