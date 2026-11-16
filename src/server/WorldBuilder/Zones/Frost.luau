-- Zone 3 · Frostbite Peaks: ice, conveyors, bounce pads and crushers.

local Decor = require(script.Parent.Parent.Decor)

local RGB = Color3.fromRGB
local Mat = Enum.Material

local Zone = {}

Zone.Theme = {
	Style = "ice",
	Thick = 1.5,
	Floor = RGB(238, 246, 255),
	FloorMat = Mat.Snow,
	Body = RGB(140, 195, 235),
	BodyMat = Mat.Glacier,
	Body2 = RGB(120, 180, 230),
	Plaza = RGB(214, 230, 246),
	PlazaMat = Mat.Marble,
	Accent = RGB(120, 220, 255),
	Accent2 = RGB(200, 240, 255),
	Mover = RGB(90, 150, 215),
	MoverMat = Mat.Ice,
	Vanish = RGB(190, 220, 240),
	VanishMat = Mat.Ice,
	Ladder = RGB(90, 200, 255),
	Hazard = RGB(255, 50, 100),
	Post = RGB(70, 90, 120),
	PostMat = Mat.Metal,
}

local Stages = {}
Zone.Stages = Stages

function Stages.SlipNSlide(K)
	K:floor(5, 8)
	K:ice(20, 7)
	K:coins(3, 0, 3.5, -15, 0, 0, 5)
	K:fwd(4)
	K:ice(14, 6, { x = 2 })
	K:fwd(4.5)
	K:ice(12, 5, { x = -2 })
	K:coin(-2, 3.5, -6)
	K:fwd(4.5)
	K:ice(10, 4.5, { x = 1 })
	K:fwd(5)
	K:ice(8, 4)
	K:coin(0, 3.5, -4)
	K:hop(4, 0, 5, 6)
	K:fwd(4)
end

function Stages.ConveyorChaos(K)
	K:floor(5, 8)
	K:conveyor(22, 6, 0, -9)
	K:coins(3, 0, 3.5, -17, 0, 0, 6)
	K:hop(3, 0, 4, 6)
	K:conveyor(20, 8, 9, 0)
	K:kill(0.8, 2.5, 20, 4.9, 1.25, -10)
	K:coin(-2, 3.5, -10)
	K:hop(3, 0, 4, 6)
	K:conveyor(20, 8, -9, 0)
	K:kill(0.8, 2.5, 20, -4.9, 1.25, -10)
	K:kill(8, 1, 1, 0, 0.6, -13)
	K:kill(8, 1, 1, 0, 0.6, -6)
	K:hop(3, 0, 4, 6)
	K:conveyor(18, 6, 0, 13)
	K:coins(2, 0, 3.5, -12, 0, 0, 6)
	K:hop(6.5, 0, 6, 8)
	K:fwd(4)
end

function Stages.IcicleGauntlet(K)
	local t = K.theme
	K:floor(9, 8)
	K:powerup("Shield", 0, 3, -3)
	K:floor(34, 6)
	for i = 0, 8 do
		local z = -31 + i * 3.5
		K:kill(6, 6.5, 0.5, 0, 3.25, z, { Transparency = 0.35, Name = "IceCurtain" })
		K:deco(0.6, 7, 0.8, -3.3, 3.5, z, t.Post, Mat.Metal)
		K:deco(0.6, 7, 0.8, 3.3, 3.5, z, t.Post, Mat.Metal)
	end
	K:floor(7, 8)
	K:coins(3, -2.5, 3.5, -3.5, 2.5, 0, 0)
	K:fwd(4)
end

function Stages.BouncyGlaciers(K)
	K:floor(8, 8)
	K:bounce(0, -3, 90)
	K:cliff(14, 8)
	K:floor(8, 8)
	K:coin(0, 3.5, -4)
	for i = 1, 3 do
		K:fwd((i == 1) and 5 or 8)
		K:floor(5, 5, { stay = true })
		K:bounce(0, 2.5, 75, 4.6)
		K:coin(0, 12, 2.5)
		K:fwd(5)
	end
	K:fwd(8)
	K:floor(8, 8)
	K:bounce(0, -3, 95)
	K:cliff(16, 8)
	K:floor(8, 8)
	K:coins(2, -2, 3.5, -4, 4, 0, 0)
	K:fwd(4)
end

function Stages.CrusherHall(K)
	K:floor(6, 8)
	K:floor(46, 8)
	for i = 1, 4 do
		K:crusher(-38 + (i - 1) * 9.5, { phase = (i - 1) * 0.23 + 0.1, period = 3.4 })
	end
	K:coins(3, 0, 3, -33.25, 0, 0, 9.5)
	K:fwd(4)
end

function Stages.SpikeballAlley(K)
	local t = K.theme
	K:floor(6, 8)
	K:floor(20, 4.5)
	K:ice(24, 4.5)
	K:floor(20, 4.5)
	for i = 1, 6 do
		local z = -57 + (i - 1) * 10
		local ball = K:killBall(4.6, -10, 2.4, z)
		K:mover(ball, 20, 0, 0, 2.6 + (i % 3) * 0.5, (i * 0.37) % 1)
		K:deco(24, 0.2, 0.8, 0, -0.1, z, t.Accent, Mat.Neon, { Transparency = 0.5 })
		if i < 6 then
			K:coin(0, 3.5, z + 5)
		end
	end
	K:fwd(4)
end

function Zone.Backdrop(K)
	local snow = RGB(232, 240, 250)
	Decor.peak(K, -200, -160, 140, 170, 280, snow, Mat.Snow)
	Decor.peak(K, 210, -170, 330, 190, 320, snow, Mat.Snow)
	Decor.peak(K, -190, -150, 520, 150, 250, snow, Mat.Snow)
	-- aurora ribbons
	for i = 1, 3 do
		local anchor = K:deco(1, 1, 1, 0, 150 + i * 14, 80 + i * 150, snow, Mat.SmoothPlastic, { Transparency = 1 })
		local a0 = K.make("Attachment", { Position = Vector3.new(-260, 0, 0) }, anchor)
		local a1 = K.make("Attachment", { Position = Vector3.new(260, 0, 0) }, anchor)
		K.make("Beam", {
			Attachment0 = a0,
			Attachment1 = a1,
			Width0 = 70,
			Width1 = 70,
			CurveSize0 = 90,
			CurveSize1 = -90,
			Segments = 24,
			FaceCamera = true,
			LightEmission = 1,
			Color = ColorSequence.new(RGB(80, 255, 170), RGB(160, 110, 255)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, anchor)
	end
end

function Zone.Scatter(K, x)
	local rng = K.rng
	Decor.iceIslet(K, x, rng:NextNumber(-12, 3), 0, rng:NextNumber(5, 8))
end

return Zone
