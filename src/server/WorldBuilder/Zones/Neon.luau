-- Zone 4 · Neon City: lasers, boost pads and spinning rides.

local Decor = require(script.Parent.Parent.Decor)

local RGB = Color3.fromRGB
local Mat = Enum.Material

local Zone = {}

Zone.Theme = {
	Style = "tech",
	Thick = 1.2,
	Floor = RGB(40, 42, 66),
	FloorMat = Mat.DiamondPlate,
	Body = RGB(20, 20, 34),
	BodyMat = Mat.Metal,
	Body2 = RGB(16, 16, 28),
	Plaza = RGB(52, 50, 84),
	PlazaMat = Mat.Metal,
	Accent = RGB(0, 240, 230),
	Accent2 = RGB(255, 0, 200),
	Mover = RGB(96, 70, 190),
	MoverMat = Mat.Metal,
	Vanish = RGB(255, 220, 60),
	VanishMat = Mat.Glass,
	Ladder = RGB(0, 240, 230),
	Hazard = RGB(255, 30, 70),
	Post = RGB(28, 28, 46),
	PostMat = Mat.Metal,
}

local Stages = {}
Zone.Stages = Stages

function Stages.LaserGrid(K)
	local t = K.theme
	K:floor(6, 8)
	K:floor(48, 12)
	for _, z in ipairs({ -40, -30, -20, -10 }) do
		K:kill(12.4, 0.5, 0.5, 0, 7.5, z, { Name = "HighLaser" })
		K:deco(0.6, 8.2, 0.6, -6.5, 4, z, t.Post, Mat.Metal)
		K:deco(0.6, 8.2, 0.6, 6.5, 4, z, t.Post, Mat.Metal)
	end
	K:mover(K:kill(12.4, 0.6, 0.6, 0, 0.8, -44, { Name = "SweepLaser" }), 0, 0, 18, 5, 0)
	K:mover(K:kill(12.4, 0.6, 0.6, 0, 0.8, -6, { Name = "SweepLaser" }), 0, 0, -18, 5.6, 0.3)
	K:mover(K:kill(1, 7, 1, -5, 3.5, -35, { Name = "Pylon" }), 10, 0, 0, 4, 0)
	K:mover(K:kill(1, 7, 1, 5, 3.5, -15, { Name = "Pylon" }), -10, 0, 0, 4.4, 0.5)
	K:coins(4, -3, 3, -35, 2, 0, 8)
	K:fwd(4)
end

function Stages.BoostBoulevard(K)
	K:floor(14, 8)
	K:boostPad(0, -7, "Speed", 2.5)
	for i = 1, 4 do
		K:hop(12.5 + ((i > 2) and 0.5 or 0), (i == 3) and 1 or 0, 14, 7)
		if i < 4 then
			K:boostPad(0, -7, "Speed", 2.5)
		end
		K:coin(0, 6, -20)
	end
	K:fwd(4)
end

function Stages.Carousel(K)
	local t = K.theme
	K:floor(6, 8)
	K:fwd(3)
	-- turntable with deadly posts riding on it
	local disc = K:cyl(26, 1.5, 0, -0.75, 13, t.Mover, t.MoverMat)
	disc.Name = "Turntable"
	K:rotor(disc, 0, -0.75, 13, 0, 1, 0, 0.7)
	K:mark(19, 13)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		local post = K:kill(1.6, 7, 1.6, math.sin(a) * 8, 3.5, 13 + math.cos(a) * 8)
		K:rotor(post, 0, 3.5, 13, 0, 1, 0, 0.7)
	end
	K:cyl(3, 3, 0, 1.5, 13, t.Post, Mat.Metal).Name = "Hub"
	K:coin(-6, 3.5, 13)
	K:coin(6, 3.5, 13)
	K:fwd(26)
	K:hop(3, 0, 5, 6)
	-- ring of orbiting platforms
	K:fwd(3)
	local R = 13
	local cz = 3.25 + R
	K:decoCyl(5, 34, 0, 2, cz, t.Post, Mat.Metal)
	K:decoCyl(6, 0.6, 0, 8, cz, t.Accent, Mat.Neon)
	K:decoCyl(6, 0.6, 0, 14, cz, t.Accent2, Mat.Neon)
	K:rotor(K:deco(0.6, 0.4, R * 2 - 6, 0, -1, cz, t.Accent, Mat.Neon), 0, -1, cz, 0, 1, 0, 0.55)
	K:rotor(K:deco(R * 2 - 6, 0.4, 0.6, 0, -1, cz, t.Accent, Mat.Neon), 0, -1, cz, 0, 1, 0, 0.55)
	for i = 0, 3 do
		local a = i * math.pi / 2
		local plat = K:cyl(6.5, 1.2, math.sin(a) * R, -0.6, cz - math.cos(a) * R, t.Mover, t.MoverMat)
		plat.Name = "OrbitPlatform"
		K:rotor(plat, 0, -0.6, cz, 0, 1, 0, 0.55)
	end
	K:mark(R + 4, cz)
	K:coin(0, 4, cz - R)
	K:coin(0, 4, cz + R)
	K:fwd(6.5 + R * 2)
	K:hop(3, 0, 6, 8)
	K:fwd(4)
end

function Stages.DoubleTrouble(K)
	K:floor(9, 8)
	K:powerup("DoubleJump", 0, 3, -4)
	K:hop(13, 0, 8, 7)
	K:powerup("DoubleJump", 0, 3, -4)
	K:coin(0, 8, -14.5)
	K:hop(13, 2, 8, 7)
	K:powerup("DoubleJump", 0, 3, -4)
	K:coin(0, 8, -14.5)
	K:hop(6, 8, 8, 7)
	K:powerup("DoubleJump", 0, 3, -4)
	K:hop(14, 0, 9, 8)
	K:coins(2, -2, 3.5, -4.5, 4, 0, 0)
	K:fwd(4)
end

function Stages.LadderLasers(K)
	local t = K.theme
	K:floor(6, 8)
	K:ladder(12)
	K:floor(7, 8)
	K:coin(0, 3.5, -3.5)
	K:ladder(18)
	for i, y in ipairs({ -13, -5 }) do
		K:laser(7, 0.5, 3.4, 0, y, -1.2, 1.2, 1.6, (i - 1) * 0.5)
		K:deco(0.8, 1, 1, -3.9, y, -1.2, t.Post, Mat.Metal)
		K:deco(0.8, 1, 1, 3.9, y, -1.2, t.Post, Mat.Metal)
	end
	K:floor(7, 8)
	K:fwd(3)
	K:truss(12, 0, -2, 1)
	K:move(0, 10, 2)
	K:fwd(3)
	K:truss(12, 0, -6, 1)
	K:coins(2, 2.6, -3, 1, 0, 4, 0)
	K:move(0, 6, 2)
	K:hop(3, 0, 7, 8)
	K:fwd(4)
end

function Stages.NeonRush(K)
	K:floor(6, 8)
	for i = 1, 5 do
		K:fwd(3)
		if i > 1 then
			K:laser(20, 6, 0.4, 0, 3, -1.5, 1, 2, (i * 0.31) % 1)
		end
		local dir = (i % 2 == 0) and 1 or -1
		K:mover(K:slab(5, 6, dir * 6, 0, 2.5), -dir * 12, 0, 0, 5, 0)
		if i % 2 == 1 then
			K:coin(0, 4, 2.5)
		end
		K:fwd(5)
	end
	K:hop(3, 0, 5, 6)
	for i = 1, 5 do
		K:fwd(3.5)
		K:vanish(4, 4, (i % 2 == 0) and 2 or -2, { delay = 0.7 })
	end
	K:hop(3.5, 0, 5, 6)
	K:fwd(4)
end

function Zone.Backdrop(K)
	local rng = K.rng
	for i = 1, 14 do
		local side = (i % 2 == 0) and 1 or -1
		Decor.building(K, side * rng:NextNumber(120, 200), rng:NextNumber(60, 200), i * 40, rng:NextNumber(26, 44), rng:NextNumber(26, 44))
	end
end

function Zone.Scatter(K, x)
	local rng = K.rng
	Decor.building(K, x + ((x > 0) and 4 or -4), rng:NextNumber(-6, 36), 0, rng:NextNumber(10, 17), rng:NextNumber(10, 17))
end

return Zone
