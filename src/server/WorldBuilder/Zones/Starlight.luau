-- Zone 5 · Starlight Sanctum: the finale among the stars.

local Decor = require(script.Parent.Parent.Decor)

local RGB = Color3.fromRGB
local Mat = Enum.Material

local Zone = {}

Zone.Theme = {
	Style = "crystal",
	Thick = 1.2,
	Floor = RGB(196, 178, 255),
	FloorMat = Mat.Glass,
	Body = RGB(96, 76, 170),
	BodyMat = Mat.Glass,
	Body2 = RGB(70, 56, 140),
	Plaza = RGB(120, 100, 200),
	PlazaMat = Mat.Marble,
	Accent = RGB(255, 226, 120),
	Accent2 = RGB(130, 220, 255),
	Mover = RGB(120, 200, 255),
	MoverMat = Mat.Glass,
	Vanish = RGB(255, 170, 230),
	VanishMat = Mat.Glass,
	Ladder = RGB(255, 226, 120),
	Hazard = RGB(255, 50, 90),
	Post = RGB(50, 44, 96),
	PostMat = Mat.Marble,
}

local Stages = {}
Zone.Stages = Stages

function Stages.MoonBoots(K)
	K:floor(9, 8)
	K:powerup("Feather", 0, 3, -4)
	local hops = { { 18, 2 }, { 19, 4 }, { 18, -2 }, { 16, 8 } }
	for i, h in ipairs(hops) do
		K:hop(h[1], h[2], 9, 8)
		K:coin(0, 9, -9 - h[1] / 2)
		if i < #hops then
			K:powerup("Feather", 0, 3, -4)
		end
	end
	K:fwd(4)
end

function Stages.StarWheel(K)
	local t = K.theme
	K:floor(6, 8)
	K:fwd(3)
	local R = 14
	local cz = 3 + R
	local speed = -0.45
	local hub = K:newPart("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 5, 5),
		CFrame = K:w(0, -0.6, cz),
		Color = t.Accent,
		Material = Mat.Neon,
	})
	hub.Name = "Deco"
	K.ghost(hub)
	K:deco(1, 60, 1, -1.6, -30.6, cz, t.Post, Mat.Marble)
	K:deco(1, 60, 1, 1.6, -30.6, cz, t.Post, Mat.Marble)
	for i = 0, 2 do
		local spoke = K:deco(0.5, 0.5, R * 2, 0, -0.6, cz, t.Accent2, Mat.Neon, { Transparency = 0.3 })
		spoke.CFrame = spoke.CFrame * CFrame.Angles(i * math.pi / 3, 0, 0)
		K:rotor(spoke, 0, -0.6, cz, 1, 0, 0, speed)
	end
	for i = 0, 5 do
		local a = i * math.pi / 3
		local plat = K:slab(6, 6, 0, math.sin(a) * R, cz - math.cos(a) * R, { name = "WheelPlatform" })
		K:rotor(plat, 0, -0.6, cz, 1, 0, 0, speed, { upright = true })
	end
	K:mark(9, cz)
	K:coin(0, R + 4, cz)
	K:fwd(6 + R * 2)
	K:hop(3, 0, 6, 8)
	K:hop(5, 1, 5, 5, { x = 2 })
	K:coin(2, 3.5, -2.5)
	K:hop(5, 1, 5, 5, { x = -2 })
	K:coin(-2, 3.5, -2.5)
	K:fwd(4)
end

function Stages.PhaseTiles(K)
	local t = K.theme
	K:floor(6, 8)
	local xs = { 0, 3, 0, -3, 0, 3, 0, -3 }
	for i = 1, 8 do
		K:fwd(3)
		local tile = K:slab(6, 6, xs[i], 0, 3, { name = "PhaseTile", color = t.Accent2 })
		K:blink(tile, 2.2, 1.8, (i % 2 == 0) and 0.5 or 0, true)
		if i % 2 == 0 then
			K:coin(xs[i], 3.5, 3)
		end
		K:fwd(6)
	end
	K:hop(3, 0, 5, 6)
	K:fwd(4)
end

function Stages.SpinnerGauntlet(K)
	K:floor(6, 8)
	K:floor(88, 8)
	local specs = {
		{ speed = 1.6 },
		{ speed = -2 },
		{ speed = 1.5, high = -1.1 },
		{ speed = 1.4, cross = true },
		{ speed = 2.1, high = -1.3, highCross = true },
	}
	for i, s in ipairs(specs) do
		local z = -78 + (i - 1) * 17
		K:spinner(z, 16, s.speed, { cross = s.cross, noHub = s.high ~= nil })
		if s.high then
			K:spinner(z, 16, s.high, { high = true, cross = s.highCross })
		end
		if i < #specs then
			K:coin(0, 3.5, z + 8.5)
		end
	end
	K:fwd(4)
end

function Stages.PowerTrip(K)
	K:floor(9, 8)
	K:powerup("Speed", 0, 3, -4)
	K:hop(13, 0, 10, 8)
	K:powerup("Jump", 0, 3, -5)
	K:cliff(13, 8)
	K:floor(10, 8)
	K:powerup("Shield", 0, 3, -3)
	K:floor(26, 6)
	for i = 0, 6 do
		K:kill(6, 6.5, 0.5, 0, 3.25, -24 + i * 3.5, { Transparency = 0.35, Name = "Curtain" })
	end
	K:floor(9, 8)
	K:powerup("DoubleJump", 0, 3, -4)
	K:coin(0, 3.5, -7)
	K:hop(13, 1, 9, 8)
	K:powerup("Feather", 0, 3, -4)
	K:hop(19, 3, 9, 8)
	K:coins(2, -2, 3.5, -4.5, 4, 0, 0)
	K:fwd(4)
end

function Stages.TheAscent(K)
	local t = K.theme
	K:floor(6, 8)
	-- crystal spire in the middle of the spiral
	local sx, sz = -16.8, 4.5
	K:decoCyl(12, 40, sx, -10, sz, t.Body2, Mat.Glass, { Transparency = 0.1 })
	K:decoCyl(8, 40, sx, 30, sz, t.Body, Mat.Glass, { Transparency = 0.1 })
	K:decoCyl(4, 30, sx, 65, sz, t.Accent2, Mat.Neon, { Transparency = 0.2 })
	for i = 0, 3 do
		K:decoCyl(14 - i * 2.5, 0.8, sx, i * 20, sz, t.Accent, Mat.Neon)
		local shard = K:deco(1.4, 5, 1.4, sx + 10, 10 + i * 18, sz, t.Accent2, Mat.Neon, { Transparency = 0.2 })
		K:rotor(shard, sx, 10 + i * 18, sz, 0, 1, 0, 0.5 + i * 0.15, { phase = i * 0.25 })
	end
	local kinds = { [4] = "truss", [10] = "truss", [15] = "truss", [6] = "lift", [12] = "lift", [8] = "vanish", [14] = "vanish" }
	for i = 1, 18 do
		local kind = kinds[i]
		if kind == "truss" then
			K:fwd(2)
			K:truss(8, 0, -2, 1)
			K:move(0, 6, 2)
			K:floor(5, 5)
		elseif kind == "lift" then
			K:fwd(4)
			K:mover(K:slab(5, 5, 0, 0, 2.5), 0, 5, 0, 5, 0, "hold")
			K:move(0, 5, 5)
		elseif kind == "vanish" then
			K:move(0, 2.5, 4)
			K:vanish(5, 5, 0, { delay = 0.8 })
		else
			K:hop(4, 2.5, 5, 5)
			if i % 2 == 1 then
				K:coin(0, 3.5, -2.5)
			end
		end
		K:turn(-30)
	end
	K:turn(90)
	K:hop(4, 2, 10, 6)
	K:fwd(3)
end

function Zone.Backdrop(K)
	Decor.planet(K, -230, 90, 200, 110, RGB(230, 150, 90), RGB(255, 220, 160))
	Decor.planet(K, 260, 20, 420, 150, RGB(90, 120, 220), nil)
	Decor.planet(K, -200, 180, 600, 70, RGB(190, 110, 220), RGB(160, 230, 255))
	Decor.planet(K, 170, 220, 120, 40, RGB(230, 230, 240), nil)
end

function Zone.Scatter(K, x)
	local rng = K.rng
	local y = rng:NextNumber(-14, 8)
	if rng:NextNumber() < 0.5 then
		Decor.rock(K, x, y, 0, rng:NextNumber(4, 8), RGB(84, 74, 120), Mat.Slate)
	end
	Decor.crystals(K, x, y + 2, 0, rng:NextNumber(4, 7), Color3.fromHSV(rng:NextNumber(0.55, 0.85), 0.5, 1))
end

return Zone
