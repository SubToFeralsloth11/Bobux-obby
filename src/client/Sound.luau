-- Sound: sound effects and cross-fading music.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local Sound = {
	musicOn = true,
	sfxOn = true,
}

local sfx = {}
local folder = nil
local current = nil -- currently playing music Sound
local currentId = nil

function Sound.start()
	folder = Instance.new("Folder")
	folder.Name = "ObbySounds"
	folder.Parent = SoundService
	for name, info in pairs(Config.Audio.Sfx) do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = "rbxassetid://" .. info.Id
		sound.Volume = info.Volume * Config.Audio.SfxVolume
		sound.Parent = folder
		sfx[name] = sound
	end
end

function Sound.play(name, pitch)
	local sound = sfx[name]
	if not sound or not Sound.sfxOn then
		return
	end
	sound.PlaybackSpeed = pitch or 1
	-- PlayLocalSound lets the same effect overlap itself
	SoundService:PlayLocalSound(sound)
end

function Sound.music(id)
	if id == currentId then
		return
	end
	currentId = id
	local old = current
	if old then
		Util.tween(old, 1.2, { Volume = 0 })
		task.delay(1.3, function()
			old:Destroy()
		end)
	end
	if not id then
		current = nil
		return
	end
	local track = Instance.new("Sound")
	track.Name = "Music"
	track.SoundId = "rbxassetid://" .. id
	track.Looped = true
	track.Volume = 0
	track.Parent = folder
	track:Play()
	current = track
	Util.tween(track, 1.6, { Volume = Sound.musicOn and Config.Audio.MusicVolume or 0 })
end

function Sound.setMusic(on)
	Sound.musicOn = on
	if current then
		Util.tween(current, 0.4, { Volume = on and Config.Audio.MusicVolume or 0 })
	end
end

function Sound.setSfx(on)
	Sound.sfxOn = on
end

return Sound
