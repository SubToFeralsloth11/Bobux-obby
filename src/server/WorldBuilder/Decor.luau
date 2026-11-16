--[[
	Decor
	Scenery builders. Everything here is non-colliding decoration placed
	relative to the Kit cursor with (right, up, forward) offsets.
]]

local Decor = {}

local RGB = Color3.fromRGB
local rad = math.rad
local Mat = Enum.Material

local function spin(part, rx, ry, rz)
	part.CFrame = part.CFrame * CFrame.Angles(rad(rx), rad(ry), rad(rz))
	return part
end

function Decor.tree(K, x, y, z, s)
	s = s or 1
	K:decoCyl(1.3 * s, 5 * s, x, y + 2.5 * s, z, RGB(122, 86, 60), Mat.Wood)
	local leaf = RGB(70, 170, 70)
	K:decoBall(6.4 * s, x, y + 6.4 * s, z, leaf, Mat.Grass)
	K:decoBall(4.6 * s, x + 1.7 * s, y + 5.2 * s, z + 0.9 * s, RGB(92, 190, 80), Mat.Grass)
	K:decoBall(4.8 * s, x - 1.5 * s, y + 5.5 * s, z - 1 * s, RGB(58, 150, 66), Mat.Grass)
end

function Decor.pine(K, x, y, z, s)
	s = s or 1
	K:decoCyl(1.1 * s, 3 * s, x, y + 1.5 * s, z, RGB(96, 70, 54), Mat.Wood)
	local sizes = { 6.5, 5, 3.4, 1.8 }
	for i, d in ipairs(sizes) do
		local h = y + (2.4 + i * 1.9) * s
		K:decoCyl(d * s, 1.9 * s, x, h, z, RGB(46, 110, 86), Mat.Grass)
		K:decoCyl(d * s * 0.8, 0.4 * s, x, h + 1.1 * s, z, RGB(240, 248, 255), Mat.Snow)
	end
end

function Decor.rock(K, x, y, z, s, color, material)
	local rng = K.rng
	for _ = 1, 2 do
		local p = K:deco(
			s * rng:NextNumber(0.7, 1.2),
			s * rng:NextNumber(0.6, 1),
			s * rng:NextNumber(0.7, 1.2),
			x + rng:NextNumber(-0.3, 0.3) * s,
			y + s * 0.3,
			z + rng:NextNumber(-0.3, 0.3) * s,
			color,
			material
		)
		spin(p, rng:NextNumber(-20, 20), rng:NextNumber(0, 90), rng:NextNumber(-20, 20))
	end
end

function Decor.cloud(K, x, y, z, s)
	local white = RGB(255, 255, 255)
	local extra = { Transparency = 0.12, CastShadow = false }
	K:decoBall(12 * s, x, y, z, white, Mat.SmoothPlastic, extra)
	K:decoBall(9 * s, x + 7 * s, y - 1 * s, z + 2 * s, white, Mat.SmoothPlastic, extra)
	K:decoBall(8 * s, x - 7 * s, y - 1.5 * s, z - 1 * s, white, Mat.SmoothPlastic, extra)
	K:decoBall(7 * s, x + 2 * s, y + 3 * s, z - 3 * s, white, Mat.SmoothPlastic, extra)
end

-- A little floating grass island with a tree or rocks on top.
function Decor.islet(K, x, y, z, r)
	local rng = K.rng
	K:decoCyl(r * 2, 1.2, x, y, z, RGB(98, 190, 86), Mat.Grass)
	K:decoCyl(r * 1.5, 2.6, x, y - 1.9, z, RGB(134, 98, 72), Mat.Ground)
	K:decoCyl(r * 0.8, 2.2, x, y - 4.3, z, RGB(112, 90, 76), Mat.Ground)
	if rng:NextNumber() < 0.7 then
		Decor.tree(K, x, y + 0.6, z, rng:NextNumber(0.8, 1.3) * math.min(1.4, r / 6))
	else
		Decor.rock(K, x, y + 0.6, z, r * 0.5, RGB(150, 150, 158), Mat.Slate)
	end
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local fx, fz = x + math.cos(a) * r * 0.7, z + math.sin(a) * r * 0.7
		K:decoBall(0.9, fx, y + 1.3, fz, Color3.fromHSV(rng:NextNumber(), 0.6, 1), Mat.Neon, { CastShadow = false })
	end
end

-- A jagged basalt spire with a glowing crack.
function Decor.spire(K, x, y, z, w, h)
	local rng = K.rng
	local rock = RGB(48, 44, 50)
	spin(K:deco(w, h * 0.5, w, x, y + h * 0.25, z, rock, Mat.Basalt), 0, rng:NextNumber(0, 90), 0)
	spin(K:deco(w * 0.68, h * 0.35, w * 0.68, x, y + h * 0.66, z, rock, Mat.Basalt), 4, rng:NextNumber(0, 90), 4)
	spin(K:deco(w * 0.4, h * 0.25, w * 0.4, x, y + h * 0.92, z, RGB(36, 32, 38), Mat.Basalt), -6, rng:NextNumber(0, 90), 6)
	K:deco(w * 0.72, 0.4, w * 0.72, x, y + h * 0.5, z, RGB(255, 120, 30), Mat.Neon, { CastShadow = false })
end

function Decor.iceIslet(K, x, y, z, r)
	local rng = K.rng
	K:decoCyl(r * 2, 1.2, x, y, z, RGB(240, 248, 255), Mat.Snow)
	K:decoCyl(r * 1.4, 3, x, y - 2.1, z, RGB(140, 195, 235), Mat.Glacier, { Transparency = 0.1 })
	K:decoCyl(r * 0.6, 3, x, y - 5, z, RGB(120, 180, 230), Mat.Glacier, { Transparency = 0.15 })
	if rng:NextNumber() < 0.6 then
		Decor.pine(K, x, y + 0.6, z, rng:NextNumber(0.8, 1.3))
	else
		Decor.crystals(K, x, y + 0.6, z, r * 0.8, RGB(150, 225, 255))
	end
end

-- A cluster of glowing crystal shards.
function Decor.crystals(K, x, y, z, s, color)
	local rng = K.rng
	for i = 1, 3 do
		local h = s * rng:NextNumber(0.8, 1.6)
		local p = K:deco(s * 0.3, h, s * 0.3, x + (i - 2) * s * 0.3, y + h * 0.4, z + rng:NextNumber(-0.2, 0.2) * s, color, Mat.Neon, {
			Transparency = 0.25,
			CastShadow = false,
		})
		spin(p, rng:NextNumber(-22, 22), 45, rng:NextNumber(-22, 22))
	end
end

-- A skyscraper whose roof is at height y.
function Decor.building(K, x, y, z, w, d)
	local rng = K.rng
	local bottom = -150
	local h = y - bottom
	K:deco(w, h, d, x, bottom + h / 2, z, RGB(20, 20, 34), Mat.Metal, { CastShadow = false })
	local colors = { RGB(0, 240, 230), RGB(255, 0, 200), RGB(255, 220, 40), RGB(120, 90, 255) }
	local color = colors[rng:NextInteger(1, #colors)]
	for i = 1, 4 do
		K:deco(w + 0.3, 0.7, d + 0.3, x, y - 4 - (i - 1) * 9, z, color, Mat.Neon, { CastShadow = false })
	end
	K:deco(0.5, 8, 0.5, x, y + 4, z, RGB(60, 60, 80), Mat.Metal)
	K:decoBall(1.4, x, y + 8.4, z, RGB(255, 40, 60), Mat.Neon, { CastShadow = false })
end

function Decor.planet(K, x, y, z, d, color, ring)
	K:decoBall(d, x, y, z, color, Mat.SmoothPlastic, { CastShadow = false })
	if ring then
		local p = K:decoCyl(d * 1.9, 0.5, x, y, z, ring, Mat.Neon, { Transparency = 0.45, CastShadow = false })
		spin(p, 0, 0, 24)
	end
end

-- A tall stacked cone (volcano / mountain). top glows if given.
function Decor.peak(K, x, y, z, baseDiameter, height, color, material, top)
	local layers = 5
	for i = 1, layers do
		local f = (i - 1) / layers
		K:decoCyl(baseDiameter * (1 - f * 0.82), height / layers + 0.5, x, y + height * (f + 0.5 / layers), z, color, material, {
			CastShadow = false,
		})
	end
	if top then
		K:decoCyl(baseDiameter * 0.2, 2, x, y + height + 0.6, z, top, Mat.Neon, { CastShadow = false })
	end
end

-- A windmill with turning sails at the given spot.
function Decor.windmill(K, x, y, z)
	K:decoCyl(8, 12, x, y + 6, z, RGB(236, 224, 200), Mat.Brick)
	K:decoCyl(6, 8, x, y + 16, z, RGB(236, 224, 200), Mat.Brick)
	K:decoCyl(7.5, 2, x, y + 21, z, RGB(170, 70, 60), Mat.Slate)
	for i = 0, 1 do
		local sail = K:deco(1.2, 22, 0.4, x, y + 17, z - 4, RGB(250, 245, 230), Mat.Fabric)
		spin(sail, 0, 0, i * 90)
		K:rotor(sail, x, y + 17, z - 4, 0, 0, 1, 0.6)
	end
end

-- Trophy and fireworks beyond the finish line.
function Decor.finish(K)
	local gold = RGB(255, 200, 40)
	K:decoCyl(10, 1.2, 0, -0.4, 9, RGB(60, 50, 110), Mat.Marble)
	K:decoCyl(5, 1.4, 0, 0.9, 9, gold, Mat.Metal)
	K:decoCyl(1.6, 4, 0, 3.6, 9, gold, Mat.Metal)
	K:decoBall(6, 0, 8, 9, gold, Mat.Metal, { Reflectance = 0.3 })
	K:decoCyl(7, 1, 0, 10.6, 9, gold, Mat.Metal)
	local star = K:decoBall(2.4, 0, 13.4, 9, RGB(255, 245, 170), Mat.Neon)
	K:light(star, gold, 30, 2.5)
	local hues = { 0, 0.33, 0.6, 0.85 }
	for i, hue in ipairs(hues) do
		local a = (i - 1) * math.pi / 2 + math.pi / 4
		local emitterPart = K:decoBall(1, math.cos(a) * 12, 1, 9 + math.sin(a) * 12, gold, Mat.Neon, { Transparency = 1 })
		local color = Color3.fromHSV(hue, 0.8, 1)
		K.make("ParticleEmitter", {
			Name = "Firework",
			Color = ColorSequence.new(color, RGB(255, 255, 255)),
			LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(1.2, 2.2),
			Speed = NumberRange.new(26, 40),
			SpreadAngle = Vector2.new(18, 18),
			Acceleration = Vector3.new(0, -24, 0),
			Rate = 22,
			EmissionDirection = Enum.NormalId.Top,
		}, emitterPart)
	end
end

--[[
	Scatter scenery along the path that was just built. fn(K, x, side) is
	called with the cursor on a path point and x a safe sideways distance.
]]
function Decor.scatter(K, fn)
	local rng = K.rng
	local saved = K.cf
	for i, point in ipairs(K.trail) do
		if i % 2 == 1 or rng:NextNumber() < 0.3 then
			local side = (rng:NextNumber() < 0.5) and -1 or 1
			K.cf = point.cf
			fn(K, side * (point.clear + 13 + rng:NextNumber(0, 14)), side)
		end
	end
	K.cf = saved
end

return Decor
