--[[
	Config
	Every tunable number, colour, name and asset id for Bobux Obby lives here.
	Server and client both read this module, so changing a value in one place
	changes it everywhere.
]]

local Config = {}

local RGB = Color3.fromRGB

Config.GameName = "BOBUX OBBY"
Config.Tagline = "30 stages. 5 worlds. One epic climb."
Config.DataStoreName = "BobuxObby_v1"

----------------------------------------------------------------------
-- Movement
----------------------------------------------------------------------
Config.Physics = {
	WalkSpeed = 16,
	JumpPower = 50,
	RespawnTime = 1.1,
	VoidMargin = 45, -- how far below a stage you can fall before respawning
}

----------------------------------------------------------------------
-- Temporary power-ups
----------------------------------------------------------------------
Config.PowerUps = {
	Speed = {
		Name = "TURBO",
		Icon = "⚡",
		Desc = "Run super fast",
		Duration = 8,
		Color = RGB(255, 208, 40),
		WalkSpeed = 30,
	},
	Jump = {
		Name = "MEGA JUMP",
		Icon = "🚀",
		Desc = "Leap over tall walls",
		Duration = 8,
		Color = RGB(80, 230, 120),
		JumpPower = 85,
	},
	DoubleJump = {
		Name = "DOUBLE JUMP",
		Icon = "✨",
		Desc = "Jump again in mid-air",
		Duration = 12,
		Color = RGB(255, 110, 220),
	},
	Feather = {
		Name = "MOON BOOTS",
		Icon = "🌙",
		Desc = "Float through the air",
		Duration = 10,
		Color = RGB(150, 190, 255),
		GravityScale = 0.35,
	},
	Shield = {
		Name = "SHIELD",
		Icon = "🛡",
		Desc = "Hazards can't hurt you",
		Duration = 6,
		Color = RGB(70, 220, 255),
	},
}
Config.PowerUpOrder = { "Speed", "Jump", "DoubleJump", "Feather", "Shield" }
Config.PickupRespawn = 3.5 -- seconds before a collected orb comes back (per player)

----------------------------------------------------------------------
-- Rewards
----------------------------------------------------------------------
Config.Rewards = {
	Coin = 1,
	Checkpoint = 5,
	Win = 100,
}

----------------------------------------------------------------------
-- Trails (cosmetics bought with coins)
----------------------------------------------------------------------
Config.Trails = {
	{ Id = "None", Name = "No Trail", Price = 0 },
	{ Id = "Spark", Name = "Spark", Price = 20, A = RGB(255, 240, 150), B = RGB(255, 170, 40) },
	{ Id = "Meadow", Name = "Meadow", Price = 45, A = RGB(170, 255, 120), B = RGB(40, 190, 110) },
	{ Id = "Ember", Name = "Ember", Price = 80, A = RGB(255, 200, 60), B = RGB(255, 50, 20) },
	{ Id = "Frost", Name = "Frost", Price = 120, A = RGB(230, 250, 255), B = RGB(80, 170, 255) },
	{ Id = "Neon", Name = "Neon", Price = 170, A = RGB(0, 255, 230), B = RGB(255, 0, 200) },
	{ Id = "Galaxy", Name = "Galaxy", Price = 240, A = RGB(190, 120, 255), B = RGB(60, 40, 200) },
	{ Id = "Rainbow", Name = "Rainbow", Price = 350, Rainbow = true },
}

----------------------------------------------------------------------
-- Zones (worlds). Lighting values are tweened on the client when a
-- player reaches a new zone.
----------------------------------------------------------------------
Config.Zones = {
	{
		Name = "Sunny Meadows",
		Tagline = "Warm up those legs!",
		Color = RGB(110, 220, 90),
		Music = 1843404009, -- "Happy Song"
		Particles = "Pollen",
		Lighting = {
			ClockTime = 14,
			Brightness = 3,
			Ambient = RGB(92, 96, 110),
			OutdoorAmbient = RGB(150, 155, 165),
			ColorShift_Top = RGB(255, 240, 215),
			ExposureCompensation = 0.1,
		},
		Atmosphere = {
			Density = 0.3,
			Offset = 0.25,
			Color = RGB(205, 225, 255),
			Decay = RGB(120, 150, 190),
			Glare = 0.25,
			Haze = 1.3,
		},
		Color_Correction = { TintColor = RGB(255, 252, 244), Saturation = 0.18, Contrast = 0.06, Brightness = 0.02 },
		Bloom = { Intensity = 0.55, Size = 26, Threshold = 1.5 },
		Clouds = { Cover = 0.58, Density = 0.6, Color = RGB(255, 255, 255) },
	},
	{
		Name = "Magma Caverns",
		Tagline = "The floor is lava. Literally.",
		Color = RGB(255, 120, 40),
		Music = 1845149698, -- "Seek & Destroy"
		Particles = "Embers",
		Lighting = {
			ClockTime = 18.6,
			Brightness = 1.6,
			Ambient = RGB(88, 44, 36),
			OutdoorAmbient = RGB(120, 62, 48),
			ColorShift_Top = RGB(255, 150, 90),
			ExposureCompensation = 0.05,
		},
		Atmosphere = {
			Density = 0.42,
			Offset = 0.1,
			Color = RGB(150, 62, 36),
			Decay = RGB(70, 22, 12),
			Glare = 0.1,
			Haze = 2.4,
		},
		Color_Correction = { TintColor = RGB(255, 232, 216), Saturation = 0.12, Contrast = 0.14, Brightness = 0 },
		Bloom = { Intensity = 1, Size = 30, Threshold = 1.1 },
		Clouds = { Cover = 0.72, Density = 0.8, Color = RGB(90, 50, 44) },
	},
	{
		Name = "Frostbite Peaks",
		Tagline = "Careful... it's slippery up here.",
		Color = RGB(130, 215, 255),
		Music = 1841460294, -- "Celestial Aurora"
		Particles = "Snow",
		Lighting = {
			ClockTime = 10.3,
			Brightness = 2.6,
			Ambient = RGB(120, 136, 160),
			OutdoorAmbient = RGB(160, 176, 200),
			ColorShift_Top = RGB(220, 238, 255),
			ExposureCompensation = 0.12,
		},
		Atmosphere = {
			Density = 0.36,
			Offset = 0.3,
			Color = RGB(220, 236, 255),
			Decay = RGB(160, 190, 230),
			Glare = 0.2,
			Haze = 1.9,
		},
		Color_Correction = { TintColor = RGB(232, 244, 255), Saturation = -0.04, Contrast = 0.05, Brightness = 0.02 },
		Bloom = { Intensity = 0.6, Size = 26, Threshold = 1.4 },
		Clouds = { Cover = 0.7, Density = 0.5, Color = RGB(240, 246, 255) },
	},
	{
		Name = "Neon City",
		Tagline = "Lights on. Lasers on. Good luck.",
		Color = RGB(0, 240, 230),
		Music = 1842976958, -- "Arcade Weekend"
		Particles = "Glitch",
		Lighting = {
			ClockTime = 0,
			Brightness = 1.2,
			Ambient = RGB(58, 46, 100),
			OutdoorAmbient = RGB(74, 62, 130),
			ColorShift_Top = RGB(150, 120, 255),
			ExposureCompensation = 0.25,
		},
		Atmosphere = {
			Density = 0.3,
			Offset = 0.1,
			Color = RGB(70, 36, 120),
			Decay = RGB(24, 12, 56),
			Glare = 0,
			Haze = 1.4,
		},
		Color_Correction = { TintColor = RGB(238, 228, 255), Saturation = 0.28, Contrast = 0.16, Brightness = 0.02 },
		Bloom = { Intensity = 1.3, Size = 32, Threshold = 0.9 },
		Clouds = { Cover = 0.35, Density = 0.4, Color = RGB(60, 40, 110) },
	},
	{
		Name = "Starlight Sanctum",
		Tagline = "Almost there. Reach for the stars!",
		Color = RGB(190, 150, 255),
		Music = 9045934037, -- "The Night Sky - Underscore"
		Particles = "Stars",
		Lighting = {
			ClockTime = 2.4,
			Brightness = 1.4,
			Ambient = RGB(60, 62, 112),
			OutdoorAmbient = RGB(84, 88, 150),
			ColorShift_Top = RGB(190, 180, 255),
			ExposureCompensation = 0.3,
		},
		Atmosphere = {
			Density = 0.14,
			Offset = 0,
			Color = RGB(46, 44, 96),
			Decay = RGB(14, 12, 40),
			Glare = 0,
			Haze = 0.4,
		},
		Color_Correction = { TintColor = RGB(240, 236, 255), Saturation = 0.22, Contrast = 0.12, Brightness = 0.02 },
		Bloom = { Intensity = 1.1, Size = 30, Threshold = 1 },
		Clouds = { Cover = 0.2, Density = 0.3, Color = RGB(70, 60, 130) },
	},
}

----------------------------------------------------------------------
-- Stages. Stage N is the stretch of obby between checkpoint N and
-- checkpoint N + 1. "Turn" bends the course (in degrees, + is right)
-- at the checkpoint where the stage begins.
----------------------------------------------------------------------
Config.Stages = {
	-- Zone 1 · Sunny Meadows
	{ Zone = 1, Key = "FirstSteps", Name = "First Steps", Turn = 0, Tip = "Jump from stone to stone!" },
	{ Zone = 1, Key = "LadderCliffs", Name = "Ladder Cliffs", Turn = 20, Tip = "Walk into a ladder to climb it." },
	{ Zone = 1, Key = "SlidingStones", Name = "Sliding Stones", Turn = -30, Tip = "Moving blocks carry you along." },
	{ Zone = 1, Key = "TurboRunway", Name = "Turbo Runway", Turn = 0, Tip = "Grab the ⚡ and clear the big gaps!" },
	{ Zone = 1, Key = "SpinCycle", Name = "Spin Cycle", Turn = 30, Tip = "Hop over the spinning bars." },
	{ Zone = 1, Key = "SkylineBeams", Name = "Skyline Beams", Turn = -20, Tip = "Keep your balance!" },
	-- Zone 2 · Magma Caverns
	{ Zone = 2, Key = "HotFeet", Name = "Hot Feet", Turn = 60, Tip = "Don't touch the lava." },
	{ Zone = 2, Key = "CrumbleBridge", Name = "Crumble Bridge", Turn = -25, Tip = "Cracked tiles fall. Keep moving!" },
	{ Zone = 2, Key = "MegaJumpCliffs", Name = "Mega Jump Cliffs", Turn = 0, Tip = "The 🚀 lets you jump HUGE walls." },
	{ Zone = 2, Key = "FireJets", Name = "Fire Jets", Turn = 25, Tip = "Run when the flames go out." },
	{ Zone = 2, Key = "LavaFerry", Name = "Lava Ferry", Turn = 0, Tip = "Ride the ferry. Dodge everything red." },
	{ Zone = 2, Key = "PendulumPass", Name = "Pendulum Pass", Turn = -25, Tip = "Time your run between the blades." },
	-- Zone 3 · Frostbite Peaks
	{ Zone = 3, Key = "SlipNSlide", Name = "Slip 'n Slide", Turn = -60, Tip = "Ice is slippery. Brake early!" },
	{ Zone = 3, Key = "ConveyorChaos", Name = "Conveyor Chaos", Turn = 20, Tip = "The arrows show where belts push you." },
	{ Zone = 3, Key = "IcicleGauntlet", Name = "Icicle Gauntlet", Turn = 0, Tip = "Grab the 🛡 and sprint through!" },
	{ Zone = 3, Key = "BouncyGlaciers", Name = "Bouncy Glaciers", Turn = -20, Tip = "Bounce pads launch you sky high." },
	{ Zone = 3, Key = "CrusherHall", Name = "Crusher Hall", Turn = 0, Tip = "Wait for the crusher to rise." },
	{ Zone = 3, Key = "SpikeballAlley", Name = "Spikeball Alley", Turn = 20, Tip = "Watch both sides!" },
	-- Zone 4 · Neon City
	{ Zone = 4, Key = "LaserGrid", Name = "Laser Grid", Turn = -60, Tip = "Jump low lasers. Never jump under high ones." },
	{ Zone = 4, Key = "BoostBoulevard", Name = "Boost Boulevard", Turn = -20, Tip = "Hit the boost pad, then jump late." },
	{ Zone = 4, Key = "Carousel", Name = "Carousel", Turn = 0, Tip = "Ride the ring halfway round." },
	{ Zone = 4, Key = "DoubleTrouble", Name = "Double Trouble", Turn = 20, Tip = "With ✨ press jump again in mid-air." },
	{ Zone = 4, Key = "LadderLasers", Name = "Ladder Lasers", Turn = 0, Tip = "Climb between the laser pulses." },
	{ Zone = 4, Key = "NeonRush", Name = "Neon Rush", Turn = 25, Tip = "Line up the sliders, then go!" },
	-- Zone 5 · Starlight Sanctum
	{ Zone = 5, Key = "MoonBoots", Name = "Moon Boots", Turn = 60, Tip = "The 🌙 makes you floaty. Jump far!" },
	{ Zone = 5, Key = "StarWheel", Name = "Star Wheel", Turn = -20, Tip = "Ride the wheel over the top." },
	{ Zone = 5, Key = "PhaseTiles", Name = "Phase Tiles", Turn = 0, Tip = "Tiles flicker before they vanish." },
	{ Zone = 5, Key = "SpinnerGauntlet", Name = "Spinner Gauntlet", Turn = 20, Tip = "Low bar: jump. High bar: stay down." },
	{ Zone = 5, Key = "PowerTrip", Name = "Power Trip", Turn = 0, Tip = "Every power-up, one after another!" },
	{ Zone = 5, Key = "TheAscent", Name = "The Ascent", Turn = -20, Tip = "The final climb. You've got this!" },
}

Config.StageCount = #Config.Stages -- playable stages
Config.FinishIndex = Config.StageCount + 1 -- the last checkpoint is the finish line

-- Zone a checkpoint index belongs to (the finish counts as the last zone).
function Config.zoneOf(stageIndex)
	local stage = Config.Stages[stageIndex]
	if stage then
		return stage.Zone
	end
	if stageIndex >= Config.FinishIndex then
		return #Config.Zones
	end
	return 1
end

----------------------------------------------------------------------
-- Audio. All ids were checked against the Roblox Creator Store and are
-- published by Roblox / APM Music, so they are free to use in any
-- experience. Swap them for your own if you like.
----------------------------------------------------------------------
Config.Audio = {
	MusicVolume = 0.32,
	SfxVolume = 0.6,
	Music = {
		Title = 1845756489, -- "Town Talk"
		Win = 1839902860, -- "Victory Fanfare (b)"
	},
	Sfx = {
		Click = { Id = 15675059323, Volume = 0.7 },
		Hover = { Id = 15675032796, Volume = 0.35 },
		Open = { Id = 15675024286, Volume = 0.6 },
		Close = { Id = 15675028888, Volume = 0.5 },
		Pop = { Id = 15675055424, Volume = 0.7 },
		Error = { Id = 15675075163, Volume = 0.6 },
		Checkpoint = { Id = 17208361335, Volume = 0.9 },
		Coin = { Id = 17208319162, Volume = 0.55 },
		Buy = { Id = 127645268874265, Volume = 0.8 },
		PowerUp = { Id = 15675043410, Volume = 0.9 },
		PowerDown = { Id = 15675062723, Volume = 0.6 },
		Zone = { Id = 15675046931, Volume = 0.9 },
		Death = { Id = 12222046, Volume = 0.55 },
		Bounce = { Id = 12222124, Volume = 0.7 },
		DoubleJump = { Id = 12222200, Volume = 0.7 },
		Crumble = { Id = 12222140, Volume = 0.5 },
		Shield = { Id = 12221990, Volume = 0.5 },
		Win = { Id = 12222253, Volume = 0.9 },
		Fanfare = { Id = 1836473422, Volume = 0.8 },
	},
}

----------------------------------------------------------------------
-- UI palette
----------------------------------------------------------------------
Config.UI = {
	Font = Enum.Font.FredokaOne,
	FontBody = Enum.Font.GothamBold,
	Panel = RGB(20, 24, 44),
	PanelLight = RGB(36, 42, 74),
	Stroke = RGB(8, 10, 22),
	Text = RGB(255, 255, 255),
	SubText = RGB(176, 186, 220),
	Yellow = RGB(255, 208, 40),
	Green = RGB(70, 220, 120),
	Red = RGB(255, 78, 96),
	Blue = RGB(70, 170, 255),
	Pink = RGB(255, 110, 200),
	Locked = RGB(70, 76, 104),
}

return Config
