-- Zone 1 · Sunny Meadows: the gentle tutorial zone.

local Decor = require(script.Parent.Parent.Decor)

local RGB = Color3.fromRGB
local Mat = Enum.Material

local Zone = {}

Zone.Theme = {
	Style = "island",
	Thick = 1.5,
	Floor = RGB(98, 190, 86),
	FloorMat = Mat.Grass,
	Body = RGB(134, 98, 72),
	BodyMat = Mat.Ground,
	Body2 = RGB(112, 90, 76),
	Plaza = RGB(222, 204, 170),
	PlazaMat = Mat.Cobblestone,
	Accent = RGB(255, 214, 64),
	Accent2 = RGB(255, 150, 60),
	Mover = RGB(232, 170, 84),
	MoverMat = Mat.WoodPlanks,
	Vanish = RGB(200, 160, 110),
	VanishMat = Mat.Cobblestone,
	Ladder = RGB(250, 205, 80),
	Hazard = RGB(255, 56, 66),
	Post = RGB(122, 86, 60),
	PostMat = Mat.Wood,
}

local Stages = {}
Zone.Stages = Stages

function Stages.FirstSteps(K)
	K:hop(4, 0, 7, 7)
	K:coin(0, 3.5, -3.5)
	K:hop(4, 1, 6, 6, { x = 3 })
	K:coin(3, 3.5, -3)
	K:hop(4.5, 1, 6, 6, { x = -3 })
	K:coin(-3, 3.5, -3)
	K:hop(5, 0, 6, 6, { x = 2 })
	K:hop(5, 1, 5, 5, { x = -2 })
	K:coin(-2, 3.5, -2.5)
	K:hop(5.5, 0, 5, 5)
	K:coin(0, 5.5, 2.5)
	K:fwd(4.5)
end

function Stages.LadderCliffs(K)
	K:floor(8, 8)
	K:ladder(10)
	K:floor(8, 8)
	K:coin(0, 3.5, -4)
	K:hop(4, 0, 6, 6)
	-- a hanging ladder: jump across and grab on
	K:fwd(3)
	K:truss(14, 0, -4, 1)
	K:coins(3, 2.6, 1, 1, 0, 3.5, 0)
	K:move(0, 10, 2)
	K:hop(3, 0, 7, 7)
	K:coin(0, 3.5, -3.5)
	K:hop(4.5, 0, 5, 8)
	K:ladder(16)
	K:floor(7, 8)
	K:coins(2, -3, 3.5, -3.5, 6, 0, 0)
	K:fwd(4)
end

function Stages.SlidingStones(K)
	K:floor(7, 8)
	-- a block sliding side to side
	K:fwd(3)
	K:mover(K:slab(6, 6, -7, 0, 3), 14, 0, 0, 5, 0)
	K:coin(0, 4, 3)
	K:fwd(6)
	K:hop(3, 0, 5, 6)
	-- a ferry across a wide gap
	K:fwd(2)
	K:mover(K:slab(6, 6, 0, 0, 3), 0, 0, 16, 6.5, 0, "hold")
	K:coins(3, 0, 4.5, 8, 0, 0, 5)
	K:fwd(22)
	K:hop(2, 0, 6, 6)
	-- a lift
	K:fwd(2)
	K:mover(K:slab(6, 6, 0, 0, 3), 0, 10, 0, 6.5, 0.5, "hold")
	K:move(0, 10, 6)
	K:hop(2, 0, 6, 8)
	K:coin(0, 3.5, -3)
	-- two sliders crossing each other
	K:fwd(3)
	K:mover(K:slab(5, 5, -6, 0, 2.5), 12, 0, 0, 4.5, 0)
	K:fwd(8)
	K:mover(K:slab(5, 5, 6, 0, 2.5), -12, 0, 0, 4.5, 0)
	K:coin(0, 4, 2.5)
	K:fwd(5)
	K:hop(3, 0, 5, 6)
	K:fwd(4)
end

function Stages.TurboRunway(K)
	K:floor(36, 8)
	for _, z in ipairs({ -28, -20, -12 }) do
		K:kill(8, 1.2, 1, 0, 0.6, z)
	end
	K:coins(3, 0, 5.5, -28, 0, 0, 8)
	K:powerup("Speed", 0, 3, -5)
	K:hop(13, 0, 10, 8)
	K:powerup("Speed", 0, 3, -5)
	K:coin(0, 6, -16.5)
	K:hop(13, 0, 9, 8)
	K:powerup("Speed", 0, 3, -4.5)
	K:hop(12, 1, 8, 8)
	K:coins(2, -2, 3.5, -4, 4, 0, 0)
	K:fwd(4)
end

function Stages.SpinCycle(K)
	local t = K.theme
	K:floor(5, 8)
	local specs = { { 1.5, false }, { -2, false }, { 1.3, true } }
	for _, spec in ipairs(specs) do
		K:fwd(4)
		K:cyl(16, 1.5, 0, -0.75, 8, t.Floor, t.FloorMat).Name = "Platform"
		K:decoCyl(12, 2.6, 0, -2.8, 8, t.Body, t.BodyMat)
		K:mark(8, 8)
		K:spinner(8, 15, spec[1], { cross = spec[2] })
		K:coin(5, 3.5, 8)
		K:coin(-5, 3.5, 8)
		K:fwd(16)
	end
	K:fwd(4)
end

function Stages.SkylineBeams(K)
	local wood = RGB(196, 140, 84)
	K:floor(5, 8)
	K:hop(2, 0, 18, 2, { bare = true, color = wood, material = Mat.WoodPlanks })
	K:coins(3, 0, 3.5, -14, 0, 0, 5)
	K:hop(3, 0, 5, 5)
	K:hop(2, 0, 14, 1.6, { bare = true, color = wood, material = Mat.WoodPlanks, x = -1.5 })
	K:floor(14, 1.6, { bare = true, color = wood, material = Mat.WoodPlanks, x = 1.5 })
	K:coin(1.5, 3.5, -7)
	K:hop(3, 0, 5, 5)
	-- a beam that slides sideways
	K:fwd(3)
	K:mover(K:slab(14, 2, -4, 0, 7, { color = wood, material = Mat.WoodPlanks }), 8, 0, 0, 5, 0)
	K:fwd(14)
	K:hop(3, 0, 6, 8)
	K:push()
	Decor.windmill(K, 26, -14, -30)
	K:pop()
	-- lift up to the next zone
	K:fwd(2)
	K:mover(K:slab(7, 7, 0, 0, 3.5), 0, 16, 0, 8, 0, "hold")
	K:move(0, 16, 7)
	K:fwd(2)
end

function Zone.Backdrop(K)
	local rng = K.rng
	-- lobby dressing
	Decor.islet(K, -24, -3, -4, 8)
	Decor.islet(K, 24, -2, -18, 9)
	local board = K:block(24, 8, 1, 0, 9, -30, RGB(150, 104, 66), Mat.WoodPlanks)
	board.Name = "WelcomeBoard"
	K:surfaceText(board, "BOBUX OBBY", RGB(255, 214, 64))
	K:deco(1, 10, 1, -10, 1, -30, RGB(122, 86, 60), Mat.Wood)
	K:deco(1, 10, 1, 10, 1, -30, RGB(122, 86, 60), Mat.Wood)
	for i = 1, 12 do
		local side = (i % 2 == 0) and 1 or -1
		Decor.cloud(K, side * rng:NextNumber(70, 220), rng:NextNumber(-50, 60), i * 50, rng:NextNumber(1.5, 3.5))
	end
	for i = 1, 4 do
		local side = (i % 2 == 0) and 1 or -1
		Decor.islet(K, side * rng:NextNumber(150, 210), rng:NextNumber(-30, 30), 60 + i * 120, rng:NextNumber(26, 40))
	end
end

function Zone.Scatter(K, x)
	local rng = K.rng
	Decor.islet(K, x, rng:NextNumber(-12, 3), 0, rng:NextNumber(5, 8))
	if rng:NextNumber() < 0.4 then
		Decor.cloud(K, x * 1.8, rng:NextNumber(-34, -16), rng:NextNumber(-10, 10), rng:NextNumber(0.8, 1.6))
	end
end

return Zone
