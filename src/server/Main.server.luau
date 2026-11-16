-- Bobux Obby server entry point: build the world, then start the game rules.

local Server = script.Parent

local WorldBuilder = require(Server.WorldBuilder)
local Game = require(Server.Game)

local world = WorldBuilder.build()
Game.start(world)

print(string.format("[Bobux Obby] Ready: %d checkpoints, %d coins.", #world.Checkpoints, world.CoinCount))
