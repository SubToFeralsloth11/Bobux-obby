-- Zone 2 · Magma Caverns: lava floors, crumbling tiles and fire.

local Decor = require(script.Parent.Parent.Decor)

local RGB = Color3.fromRGB
local Mat = Enum.Material

local Zone = {}

Zone.Theme = {
	Style = "basalt",
	Thick = 1.5,
	Floor = RGB(70, 64, 70),
	FloorMat = Mat.Basalt,
	Body = RGB(46, 42, 48),
	BodyMat = Mat.Slate,
	Body2 = RGB(36, 32, 38),
	Plaza = RGB(88, 78, 80),
	PlazaMat = Mat.Cobblestone,
	Accent = RGB(255, 130, 30),
	Accent2 = RGB(255, 200, 60),
	Mover = RGB(150, 96, 70),
	MoverMat = Mat.CorrodedMetal,
	Vanish = RGB(170, 110, 70),
	VanishMat = Mat.CrackedLava,
	Ladder = RGB(255, 170, 60),
	Hazard = RGB(255, 50, 40),
	Lava = RGB(255, 96, 20),
	Post = RGB(40, 38, 46),
	PostMat = Mat.Metal,
}

local Stages = {}
Zone.Stages = Stages

function Stages.HotFeet(K)
	local t = K.theme
	K:floor(5, 8)
	K:lavaSea(106, 56, 5)
	local hops = {
		{ 4, 0, 5, 0 },
		{ 4.5, 1, 4, 3 },
		{ 4.5, 1, 4, -2 },
		{ 5, -1, 4, 2 },
		{ 5, 0, 4, -3 },
		{ 5, 1, 4, 0 },
		{ 5.5, 0, 3.5, 3 },
		{ 5, -1, 4, -1 },
		{ 4, 0, 6, 0 },
	}
	for i, h in ipairs(hops) do
		K:hop(h[1], h[2], h[3], h[3], { x = h[4] })
		K:deco(h[3] - 1.4, 9, h[3] - 1.4, h[4], -8.5, -h[3] / 2, t.Body2, t.BodyMat)
		if i % 2 == 0 then
			K:coin(h[4], 3.5, -h[3] / 2)
		end
	end
	K:fwd(4)
end

function Stages.CrumbleBridge(K)
	K:floor(5, 8)
	K:lavaSea(136, 56, 6)
	for i = 1, 8 do
		K:fwd(0.5)
		K:vanish(5, 6, 0)
		if i % 3 == 0 then
			K:coin(0, 3.5, -2.5)
		end
	end
	K:hop(3, 0, 5, 6)
	for i = 1, 6 do
		K:fwd(4)
		local x = (i % 2 == 0) and 2.5 or -2.5
		K:vanish(4.5, 4.5, x, { delay = 0.8 })
		if i % 2 == 0 then
			K:coin(x, 3.5, -2.25)
		end
	end
	K:hop(4, 0, 5, 6)
	K:fwd(4)
end

function Stages.MegaJumpCliffs(K)
	K:floor(12, 10)
	K:powerup("Jump", 0, 3, -5)
	for _ = 1, 3 do
		K:cliff(13, 10)
		K:floor(11, 10)
		K:powerup("Jump", 0, 3, -4)
		K:coin(-3, 3.5, -8)
		K:coin(3, 3.5, -8)
	end
	K:fwd(4)
end

function Stages.FireJets(K)
	K:floor(6, 8)
	K:lavaSea(84, 56, 6)
	K:floor(58, 6)
	for i = 1, 7 do
		local z = -52 + (i - 1) * 7.5
		K:jet(z, 6, 1.3, 1.7, (-(i - 1) * 0.14) % 1)
		if i < 7 then
			K:coin(0, 3.5, z + 3.75)
		end
	end
	K:fwd(4)
end

function Stages.LavaFerry(K)
	K:floor(7, 10)
	K:lavaSea(114, 56, 6)
	K:fwd(2)
	K:mover(K:slab(8, 8, 0, 0, 4), 0, 0, 66, 24, 0, "hold")
	K:kill(10, 1, 1, 0, 0.9, 16)
	K:kill(5.5, 6, 1, -2.75, 3, 27)
	K:kill(5.5, 6, 1, 2.75, 3, 37)
	K:kill(10, 1, 1, 0, 0.9, 47)
	K:kill(5.5, 6, 1, -2.75, 3, 56)
	K:kill(10, 1, 1, 0, 0.9, 64)
	K:coin(2.5, 4, 27)
	K:coin(-2.5, 4, 37)
	K:coin(0, 6.5, 47)
	K:coin(2.5, 4, 56)
	K:fwd(74)
	K:hop(2, 0, 8, 10)
	K:fwd(4)
end

function Stages.PendulumPass(K)
	K:floor(6, 8)
	K:lavaSea(92, 56, 8)
	K:floor(50, 5)
	for i = 1, 4 do
		K:pendulum(-42 + (i - 1) * 10, { phase = (i - 1) * 0.27, base = -8 })
	end
	K:coins(3, 0, 3.5, -37, 0, 0, 10)
	K:ladder(14, 8)
	K:floor(8, 8)
	K:coin(0, 3.5, -4)
	K:fwd(4)
end

function Zone.Backdrop(K)
	local rock = RGB(44, 38, 42)
	Decor.peak(K, -190, -130, 160, 150, 230, rock, Mat.Basalt, RGB(255, 110, 20))
	Decor.peak(K, 200, -150, 380, 170, 260, rock, Mat.Basalt, RGB(255, 110, 20))
	Decor.peak(K, -170, -140, 560, 130, 200, rock, Mat.Basalt, RGB(255, 110, 20))
end

function Zone.Scatter(K, x)
	local rng = K.rng
	Decor.spire(K, x, -14, 0, rng:NextNumber(5, 9), rng:NextNumber(16, 34))
end

return Zone
