-- Char: keeps track of the local player's current character.

local Players = game:GetService("Players")

local Bus = require(script.Parent.Bus)

local Char = {
	character = nil,
	humanoid = nil,
	root = nil,
}

local player = Players.LocalPlayer

local function onCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end
	Char.character = character
	Char.humanoid = humanoid
	Char.root = root
	Bus.fire("Spawned", character, humanoid, root)
	humanoid.Died:Connect(function()
		if Char.humanoid == humanoid then
			Bus.fire("Died")
		end
	end)
end

function Char.alive()
	local humanoid = Char.humanoid
	return humanoid ~= nil and Char.root ~= nil and Char.root.Parent ~= nil and humanoid.Health > 0
end

-- Distance from the middle of the root part down to the soles of the feet.
function Char.footOffset()
	local humanoid = Char.humanoid
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + Char.root.Size.Y / 2
	end
	return 3
end

function Char.start()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return Char
