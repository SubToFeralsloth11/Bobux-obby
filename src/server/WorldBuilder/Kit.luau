--[[
	Kit
	The obby construction toolkit. A Kit owns a "cursor": a CFrame sitting on
	the walking surface at the front edge of the last thing that was built,
	looking down the course. Every helper builds relative to the cursor using
	(right, up, forward) offsets, so the whole course can bend and climb
	without any stage needing to know where in the world it is.

	Moving things are NOT animated by the server. Parts are tagged (Mover,
	Rotor, Blinker, ...) and given attributes; every client animates them
	locally from the shared server clock, which keeps movement perfectly
	smooth and lets platforms carry players without rubber-banding.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Kit = {}
Kit.__index = Kit

local V3 = Vector3.new
local RGB = Color3.fromRGB
local rad = math.rad
local Mat = Enum.Material

local WHITE = RGB(255, 255, 255)
local DARK = RGB(34, 36, 50)
local GOLD = RGB(255, 200, 40)

local function tag(inst, name)
	CollectionService:AddTag(inst, name)
end

local function apply(inst, props)
	if props then
		for key, value in pairs(props) do
			inst[key] = value
		end
	end
	return inst
end

local function make(className, props, parent)
	local inst = Instance.new(className)
	apply(inst, props)
	if parent then
		inst.Parent = parent
	end
	return inst
end

Kit.make = make
Kit.tag = tag

function Kit.new(root, origin, themes, seed)
	local self = setmetatable({}, Kit)
	self.root = root
	self.folder = root
	self.cf = origin
	self.themes = themes
	self.theme = themes[1]
	self.rng = Random.new(seed or 1337)
	self.stage = 0
	self.coinCount = 0
	self.pickupCount = 0
	self.checkpoints = {}
	self.trail = {}
	self.stack = {}
	return self
end

----------------------------------------------------------------------
-- Cursor
----------------------------------------------------------------------

-- Local (right, up, forward) offset -> world CFrame.
function Kit:w(x, y, z)
	return self.cf * CFrame.new(x or 0, y or 0, -(z or 0))
end

function Kit:wp(x, y, z)
	return self:w(x, y, z).Position
end

-- Local (right, up, forward) direction -> world vector.
function Kit:wv(x, y, z)
	return self.cf:VectorToWorldSpace(V3(x, y, -z))
end

function Kit:move(x, y, z)
	self.cf = self:w(x, y, z)
end

function Kit:fwd(distance)
	self.cf = self:w(0, 0, distance)
end

function Kit:up(height)
	self.cf = self:w(0, height, 0)
end

-- Positive degrees turn the course to the right.
function Kit:turn(degrees)
	self.cf = self.cf * CFrame.Angles(0, -rad(degrees), 0)
end

function Kit:push()
	table.insert(self.stack, self.cf)
end

function Kit:pop()
	self.cf = table.remove(self.stack)
end

-- Remember a point on the path (used later to scatter scenery around it).
function Kit:mark(clearance, z)
	table.insert(self.trail, { cf = self:w(0, 0, z or 0), clear = clearance })
end

----------------------------------------------------------------------
-- Primitive parts
----------------------------------------------------------------------

function Kit:newPart(className, props)
	local part = Instance.new(className)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	apply(part, props)
	part.Parent = self.folder
	return part
end

-- Solid block centred at the local offset.
function Kit:block(sx, sy, sz, x, y, z, color, material, extra)
	local part = self:newPart("Part", {
		Size = V3(sx, sy, sz),
		CFrame = self:w(x, y, z),
		Color = color,
		Material = material or Mat.SmoothPlastic,
	})
	return apply(part, extra)
end

local function ghost(part)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end
Kit.ghost = ghost

-- Decorative block: no collisions, never blocks the camera.
function Kit:deco(sx, sy, sz, x, y, z, color, material, extra)
	local part = ghost(self:block(sx, sy, sz, x, y, z, color, material))
	part.Name = "Deco"
	return apply(part, extra)
end

-- Upright cylinder (its round faces point up and down).
function Kit:cyl(diameter, height, x, y, z, color, material, extra)
	local part = self:newPart("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = V3(height, diameter, diameter),
		CFrame = self:w(x, y, z) * CFrame.Angles(0, 0, rad(90)),
		Color = color,
		Material = material or Mat.SmoothPlastic,
	})
	return apply(part, extra)
end

function Kit:ball(diameter, x, y, z, color, material, extra)
	local part = self:newPart("Part", {
		Shape = Enum.PartType.Ball,
		Size = V3(diameter, diameter, diameter),
		CFrame = self:w(x, y, z),
		Color = color,
		Material = material or Mat.SmoothPlastic,
	})
	return apply(part, extra)
end

function Kit:decoCyl(diameter, height, x, y, z, color, material, extra)
	local part = ghost(self:cyl(diameter, height, x, y, z, color, material))
	part.Name = "Deco"
	return apply(part, extra)
end

function Kit:decoBall(diameter, x, y, z, color, material, extra)
	local part = ghost(self:ball(diameter, x, y, z, color, material))
	part.Name = "Deco"
	return apply(part, extra)
end

function Kit:light(parent, color, range, brightness)
	return make("PointLight", {
		Color = color,
		Range = range or 12,
		Brightness = brightness or 1.5,
		Shadows = false,
	}, parent)
end

----------------------------------------------------------------------
-- Text
----------------------------------------------------------------------

function Kit:billboard(parent, widthStuds, heightStuds, offsetY, maxDistance)
	return make("BillboardGui", {
		Name = "Billboard",
		Size = UDim2.new(widthStuds, 0, heightStuds, 0),
		StudsOffsetWorldSpace = V3(0, offsetY or 0, 0),
		MaxDistance = maxDistance or 200,
		LightInfluence = 0,
		ResetOnSpawn = false,
	}, parent)
end

function Kit:label(parent, text, color, position, size, font)
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Position = position or UDim2.new(0, 0, 0, 0),
		Size = size or UDim2.new(1, 0, 1, 0),
		Text = text,
		TextScaled = true,
		TextColor3 = color or WHITE,
		Font = font or Config.UI.Font,
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = RGB(10, 12, 24),
	}, parent)
	return label
end

-- Text painted on the front and back faces of a part.
function Kit:surfaceText(part, text, color)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = make("SurfaceGui", {
			Name = "Sign",
			Face = face,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 24,
			LightInfluence = 0,
			ResetOnSpawn = false,
		}, part)
		self:label(gui, text, color)
	end
end

----------------------------------------------------------------------
-- Floors
----------------------------------------------------------------------

-- Themed underside so platforms look like chunky floating scenery instead
-- of flat tiles. (x, y, zc) is the centre of the platform's bottom face.
function Kit:underside(wid, len, x, y, zc)
	local t = self.theme
	local style = t.Style
	local big = wid >= 5 and len >= 5
	if style == "island" then
		self:block(wid - 0.6, 2.2, len - 0.6, x, y - 1.1, zc, t.Body, t.BodyMat).Name = "Soil"
		if big then
			self:deco(wid * 0.62, 2, len * 0.62, x, y - 3.2, zc, t.Body2, t.BodyMat)
			self:deco(wid * 0.3, 1.6, len * 0.3, x, y - 5, zc, t.Body2, t.BodyMat)
		end
	elseif style == "basalt" then
		self:block(wid - 0.5, 2.4, len - 0.5, x, y - 1.2, zc, t.Body, t.BodyMat).Name = "Rock"
		self:deco(wid + 0.12, 0.3, len + 0.12, x, y - 0.7, zc, t.Accent, Mat.Neon)
		if big then
			self:deco(wid * 0.6, 2.2, len * 0.6, x, y - 3.5, zc, t.Body2, t.BodyMat)
		end
	elseif style == "ice" then
		self:block(wid - 0.4, 2, len - 0.4, x, y - 1, zc, t.Body, t.BodyMat, { Transparency = 0.15 }).Name = "Glacier"
		if big then
			for _ = 1, 2 do
				local h = self.rng:NextNumber(1.5, 3.2)
				local ix = x + self.rng:NextNumber(-0.3, 0.3) * wid
				local iz = zc + self.rng:NextNumber(-0.3, 0.3) * len
				self:deco(0.9, h, 0.9, ix, y - 2 - h / 2, iz, t.Body2, Mat.Ice, { Transparency = 0.2 })
			end
		end
	elseif style == "tech" then
		self:block(wid - 0.6, 0.8, len - 0.6, x, y - 0.4, zc, t.Body, t.BodyMat).Name = "Chassis"
		self:deco(0.25, 0.4, len, x - wid / 2 - 0.12, y + t.Thick / 2, zc, t.Accent, Mat.Neon)
		self:deco(0.25, 0.4, len, x + wid / 2 + 0.12, y + t.Thick / 2, zc, t.Accent2, Mat.Neon)
	elseif style == "crystal" then
		self:deco(wid * 0.6, 0.5, len * 0.6, x, y - 0.3, zc, t.Accent, Mat.Neon)
		if big then
			local shard = self:deco(wid * 0.34, 2.6, len * 0.34, x, y - 1.9, zc, t.Body, t.BodyMat, { Transparency = 0.1 })
			shard.CFrame = shard.CFrame * CFrame.Angles(0, rad(45), 0)
		end
	end
end

--[[
	Lay a platform starting at the cursor and move the cursor to its far edge.
	options: x (sideways shift), thick, color, material, bare (no underside),
	stay (don't move the cursor), name
]]
function Kit:floor(len, wid, o)
	o = o or {}
	local t = self.theme
	local x = o.x or 0
	local thick = o.thick or t.Thick
	local top = self:block(wid, thick, len, x, -thick / 2, len / 2, o.color or t.Floor, o.material or t.FloorMat)
	top.Name = o.name or "Platform"
	if not o.bare then
		self:underside(wid, len, x, -thick, len / 2)
	end
	local marks = math.max(1, math.floor(len / 14 + 0.5))
	for i = 1, marks do
		self:mark(math.abs(x) + wid / 2, len * (i - 0.5) / marks)
	end
	if not o.stay then
		self:fwd(len)
	end
	return top
end

-- Leave a gap, change height, then lay a platform.
function Kit:hop(gap, rise, len, wid, o)
	self:move(0, rise, gap)
	return self:floor(len, wid, o)
end

-- A plain single-part platform (used for anything that moves). Its top
-- surface is at local height y and it is centred at (x, zc).
function Kit:slab(len, wid, x, y, zc, o)
	o = o or {}
	local t = self.theme
	local part = self:block(wid, 1.2, len, x, y - 0.6, zc, o.color or t.Mover, o.material or t.MoverMat)
	part.Name = o.name or "MovingPlatform"
	self:mark(math.abs(x) + wid / 2 + 6, zc)
	return part
end

-- Slippery floor.
function Kit:ice(len, wid, o)
	o = o or {}
	o.color = RGB(160, 225, 255)
	o.material = Mat.Ice
	o.name = "Ice"
	local part = self:floor(len, wid, o)
	part.CustomPhysicalProperties = PhysicalProperties.new(0.9, 0.02, 0, 100, 1)
	part.Transparency = 0.08
	return part
end

-- A tile that crumbles shortly after the player steps on it.
function Kit:vanish(len, wid, x, o)
	o = o or {}
	local t = self.theme
	x = x or 0
	local part = self:block(wid, 1, len, x, -0.5, len / 2, t.Vanish, t.VanishMat)
	part.Name = "CrumbleTile"
	part:SetAttribute("Delay", o.delay or 0.55)
	part:SetAttribute("Respawn", o.respawn or 3)
	tag(part, "Vanish")
	self:mark(math.abs(x) + wid / 2, len / 2)
	self:fwd(len)
	return part
end

-- Conveyor belt. (vx, vz) is the push in studs/second: right and forward.
function Kit:conveyor(len, wid, vx, vz)
	local t = self.theme
	local belt = self:block(wid, 1.2, len, 0, -0.6, len / 2, RGB(44, 48, 62), Mat.DiamondPlate)
	belt.Name = "Conveyor"
	local velocity = self:wv(vx, 0, vz)
	belt.AssemblyLinearVelocity = velocity
	belt:SetAttribute("Velocity", velocity)
	tag(belt, "Conveyor")
	self:deco(0.5, 0.6, len, -(wid / 2 + 0.25), -0.3, len / 2, t.Accent, Mat.Neon)
	self:deco(0.5, 0.6, len, wid / 2 + 0.25, -0.3, len / 2, t.Accent, Mat.Neon)
	-- sliding arrows show which way the belt pushes
	if math.abs(vz) >= math.abs(vx) then
		local count = math.max(2, math.floor(len / 6))
		local travel = len - 1
		for i = 1, count do
			local z0 = (vz > 0) and 0.5 or (len - 0.5)
			local arrow = self:deco(wid * 0.55, 0.08, 0.7, 0, 0.05, z0, t.Accent, Mat.Neon)
			self:mover(arrow, 0, 0, (vz > 0) and travel or -travel, travel / math.abs(vz), (i - 1) / count, "loop")
		end
	else
		local count = math.max(2, math.floor(wid / 3))
		local travel = wid - 1
		for i = 1, count do
			local x0 = (vx > 0) and -(wid / 2 - 0.5) or (wid / 2 - 0.5)
			local arrow = self:deco(0.7, 0.08, len * 0.6, x0, 0.05, len / 2, t.Accent, Mat.Neon)
			self:mover(arrow, (vx > 0) and travel or -travel, 0, 0, travel / math.abs(vx), (i - 1) / count, "loop")
		end
	end
	self:mark(wid / 2, len / 2)
	self:fwd(len)
	return belt
end

-- A sheer wall. The cursor ends up on top of it, ready for a floor.
function Kit:cliff(height, wid)
	local t = self.theme
	wid = wid or 10
	local wallHeight = height + 3 - t.Thick
	self:block(wid - 0.4, wallHeight, 3, 0, (height - t.Thick - 3) / 2, 1.5, t.Body, t.BodyMat).Name = "Cliff"
	self:up(height)
end

-- A free-standing climbable truss. Heights must be even numbers.
function Kit:truss(height, x, y0, z, color)
	local part = self:newPart("TrussPart", {
		Size = V3(2, height, 2),
		CFrame = self:w(x, y0 + height / 2, z),
		Color = color or self.theme.Ladder,
		Material = Mat.Metal,
	})
	part.Name = "Ladder"
	return part
end

-- A ladder up a cliff face. The cursor ends up at the top of the cliff.
function Kit:ladder(height, wid)
	local t = self.theme
	wid = wid or 8
	self:block(wid, t.Thick, 2, 0, -t.Thick / 2, 1, t.Floor, t.FloorMat).Name = "LadderStep"
	local truss = self:truss(height, 0, 0, 1)
	local wallHeight = height + 3 - t.Thick
	self:block(wid - 0.4, wallHeight, 2.5, 0, (height - t.Thick - 3) / 2, 3.25, t.Body, t.BodyMat).Name = "Cliff"
	self:mark(wid / 2, 1)
	self:move(0, height, 2)
	return truss
end

----------------------------------------------------------------------
-- Motion (animated on each client, see client/World)
----------------------------------------------------------------------

--[[
	Slide a part back and forth between where it is now and an offset.
	ease: "sine" (default), "linear", "hold" (pauses at each end),
	"slam" (crusher), "loop" (one-way, snaps back)
]]
function Kit:mover(part, dx, dy, dz, period, phase, ease)
	local p0 = part.Position
	part:SetAttribute("P0", p0)
	part:SetAttribute("P1", p0 + self:wv(dx, dy, dz))
	part:SetAttribute("Period", period)
	part:SetAttribute("Phase", phase or 0)
	if ease then
		part:SetAttribute("Ease", ease)
	end
	tag(part, "Mover")
	return part
end

--[[
	Rotate a part around a pivot point. The axis is given in local
	(right, up, forward) terms. options: swing (radians, makes it a
	pendulum), period, phase, upright (orbit without tilting)
]]
function Kit:rotor(part, px, py, pz, ax, ay, az, speed, o)
	part:SetAttribute("Pivot", self:wp(px, py, pz))
	part:SetAttribute("Axis", self:wv(ax, ay, az).Unit)
	part:SetAttribute("Speed", speed)
	if o then
		if o.swing then
			part:SetAttribute("Swing", o.swing)
			part:SetAttribute("Period", o.period or 3)
		end
		if o.phase then
			part:SetAttribute("Phase", o.phase)
		end
		if o.upright then
			part:SetAttribute("Upright", true)
		end
	end
	tag(part, "Rotor")
	return part
end

-- Switch a part on and off on a timer. Solid blinkers are platforms that
-- phase in and out; the rest are hazards that only hurt while "on".
function Kit:blink(part, onTime, offTime, phase, solid)
	part:SetAttribute("On", onTime)
	part:SetAttribute("Off", offTime)
	part:SetAttribute("Phase", phase or 0)
	if solid then
		part:SetAttribute("Solid", true)
	end
	tag(part, "Blinker")
	return part
end

----------------------------------------------------------------------
-- Hazards
----------------------------------------------------------------------

function Kit:kill(sx, sy, sz, x, y, z, extra)
	local part = self:block(sx, sy, sz, x, y, z, self.theme.Hazard, Mat.Neon)
	part.Name = "Hazard"
	part.CanCollide = false
	part.CastShadow = false
	tag(part, "Kill")
	return apply(part, extra)
end

function Kit:killBall(diameter, x, y, z)
	local part = self:ball(diameter, x, y, z, self.theme.Hazard, Mat.Neon)
	part.Name = "Hazard"
	part.CanCollide = false
	part.CastShadow = false
	tag(part, "Kill")
	return part
end

-- A glowing deadly floor far below the path.
function Kit:lavaSea(len, wid, depth)
	local sea = self:block(wid, 2, len, 0, -depth - 1, len / 2 - 6, self.theme.Lava or self.theme.Hazard, Mat.Neon)
	sea.Name = "Lava"
	sea.CanCollide = false
	sea.CastShadow = false
	tag(sea, "Kill")
	return sea
end

-- A blinking beam of death.
function Kit:laser(sx, sy, sz, x, y, z, onTime, offTime, phase)
	local beam = self:kill(sx, sy, sz, x, y, z, { Name = "Laser" })
	self:blink(beam, onTime, offTime, phase)
	return beam
end

-- A flame jet across the path at forward offset z.
function Kit:jet(z, wid, onTime, offTime, phase)
	local t = self.theme
	self:deco(wid, 0.2, 2.4, 0, 0.1, z, DARK, Mat.Metal)
	self:deco(wid - 1, 0.1, 0.6, 0, 0.22, z, t.Accent, Mat.Neon)
	local flame = self:kill(wid, 7, 1.6, 0, 3.7, z, { Name = "FireJet", Transparency = 0.2, Color = RGB(255, 130, 30) })
	self:blink(flame, onTime, offTime, phase)
	return flame
end

--[[
	A spinning bar hazard centred at forward offset z.
	options: high (bar at head height: don't jump), cross (two bars),
	x (sideways shift)
]]
function Kit:spinner(z, len, speed, o)
	o = o or {}
	local t = self.theme
	local x = o.x or 0
	local y = o.high and 7.6 or 1.1
	local thick = o.high and 0.8 or 1
	local hubHeight = y + 0.9
	if not o.noHub then
		self:cyl(2.2, hubHeight, x, hubHeight / 2, z, t.Post, Mat.Metal).Name = "Hub"
	end
	local bar = self:kill(len, thick, thick, x, y, z, { Name = "SpinnerBar" })
	self:rotor(bar, x, y, z, 0, 1, 0, speed)
	if o.cross then
		local bar2 = self:kill(thick, thick, len, x, y, z, { Name = "SpinnerBar" })
		self:rotor(bar2, x, y, z, 0, 1, 0, speed)
	end
	return bar
end

-- A swinging blade over the path at forward offset z.
function Kit:pendulum(z, o)
	o = o or {}
	local t = self.theme
	local arm = o.arm or 13
	local pivotY = arm + 2
	local base = o.base or -8
	local span = o.span or 7.5
	local postHeight = pivotY - base + 0.6
	self:deco(0.9, postHeight, 0.9, -span, base + postHeight / 2, z, t.Post, Mat.Metal)
	self:deco(0.9, postHeight, 0.9, span, base + postHeight / 2, z, t.Post, Mat.Metal)
	self:deco(span * 2 + 0.9, 0.9, 0.9, 0, pivotY + 0.3, z, t.Post, Mat.Metal)
	local swing = { swing = o.amp or rad(55), period = o.period or 3.2, phase = o.phase or 0 }
	local rod = self:deco(0.5, arm, 0.5, 0, pivotY - arm / 2, z, t.Post, Mat.Metal)
	self:rotor(rod, 0, pivotY, z, 0, 0, 1, 0, swing)
	local blade = self:kill(5, 3.2, 1, 0, pivotY - arm, z, { Name = "Blade" })
	self:rotor(blade, 0, pivotY, z, 0, 0, 1, 0, swing)
	return blade
end

-- A block that slams down on the path at forward offset z.
function Kit:crusher(z, o)
	o = o or {}
	local t = self.theme
	local wid = o.wid or 8
	local len = o.len or 5
	local height = 7
	local clearance = 9
	local centreY = clearance + height / 2
	local drop = -(clearance - 0.4)
	local period = o.period or 3.4
	local phase = o.phase or 0
	local body = self:block(wid, height, len, 0, centreY, z, t.Post, Mat.Metal, { CanCollide = false })
	body.Name = "Crusher"
	tag(body, "Kill")
	self:mover(body, 0, drop, 0, period, phase, "slam")
	local plate = self:kill(wid + 0.3, 0.7, len + 0.3, 0, clearance + 0.2, z, { Name = "CrusherPlate" })
	self:mover(plate, 0, drop, 0, period, phase, "slam")
	local stripe = self:deco(wid + 0.2, 0.6, len + 0.2, 0, centreY + 1, z, GOLD, Mat.Neon)
	self:mover(stripe, 0, drop, 0, period, phase, "slam")
	for _, side in ipairs({ -1, 1 }) do
		self:deco(0.7, 20, 0.7, side * (wid / 2 + 0.7), 9, z, t.Post, Mat.Metal)
	end
	return body
end

----------------------------------------------------------------------
-- Pickups
----------------------------------------------------------------------

function Kit:coin(x, y, z)
	self.coinCount = self.coinCount + 1
	local coin = self:newPart("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = V3(0.35, 2.4, 2.4),
		CFrame = self:w(x, y, z),
		Color = GOLD,
		Material = Mat.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	coin.Name = "Coin"
	coin:SetAttribute("Id", self.coinCount)
	tag(coin, "Coin")
	return coin
end

-- A row of coins starting at (x, y, z) and stepping by (dx, dy, dz).
function Kit:coins(count, x, y, z, dx, dy, dz)
	for i = 0, count - 1 do
		self:coin(x + (dx or 0) * i, y + (dy or 0) * i, z + (dz or 0) * i)
	end
end

-- A floating power-up orb.
function Kit:powerup(kind, x, y, z)
	local cfg = Config.PowerUps[kind]
	self.pickupCount = self.pickupCount + 1
	self:deco(4.4, 0.2, 4.4, x, y - 2.9, z, cfg.Color, Mat.Neon, { Transparency = 0.45, CastShadow = false })
	local orb = self:ball(3, x, y, z, cfg.Color, Mat.Neon, {
		Transparency = 0.2,
		CanCollide = false,
		CastShadow = false,
	})
	orb.Name = "PowerUp_" .. kind
	orb:SetAttribute("Kind", kind)
	orb:SetAttribute("Id", self.pickupCount)
	tag(orb, "PowerUp")
	self:light(orb, cfg.Color, 14, 1.6)
	local gui = self:billboard(orb, 5, 3.4, 3.6, 140)
	self:label(gui, cfg.Icon, WHITE, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.62, 0))
	self:label(gui, cfg.Name, cfg.Color, UDim2.new(0, 0, 0.64, 0), UDim2.new(1, 0, 0.36, 0))
	return orb
end

-- A floor pad that gives a short burst of a power-up every time you cross it.
function Kit:boostPad(x, z, kind, duration)
	local cfg = Config.PowerUps[kind]
	self.pickupCount = self.pickupCount + 1
	local pad = self:block(5, 0.3, 4, x, 0.15, z, cfg.Color, Mat.Neon, { CanCollide = false, CastShadow = false })
	pad.Name = "BoostPad"
	pad:SetAttribute("Kind", kind)
	pad:SetAttribute("Id", self.pickupCount)
	pad:SetAttribute("Duration", duration or 2.5)
	pad:SetAttribute("Pad", true)
	tag(pad, "PowerUp")
	for i = -1, 1 do
		self:deco(3.4, 0.1, 0.5, x, 0.34, z + i * 1.2, WHITE, Mat.Neon)
	end
	return pad
end

-- A trampoline pad that launches the player upward.
function Kit:bounce(x, z, power, diameter)
	diameter = diameter or 5
	self:cyl(diameter + 0.8, 0.2, x, 0.1, z, DARK, Mat.Metal).Name = "BounceBase"
	local pad = self:cyl(diameter, 0.3, x, 0.35, z, RGB(255, 80, 170), Mat.Neon)
	pad.Name = "BouncePad"
	pad:SetAttribute("Power", power)
	tag(pad, "Bounce")
	return pad
end

----------------------------------------------------------------------
-- Checkpoints
----------------------------------------------------------------------

-- An archway over a checkpoint announcing the zone (or the finish line).
function Kit:gate(radius, text, color)
	local t = self.theme
	local span = radius + 2.5
	for _, side in ipairs({ -1, 1 }) do
		self:block(2.6, 19, 2.6, side * span, 8.5, 0, t.Post, t.PostMat or Mat.Metal).Name = "GatePillar"
		self:deco(2.9, 0.5, 2.9, side * span, 15.5, 0, color, Mat.Neon)
		self:deco(2.9, 0.5, 2.9, side * span, 3, 0, color, Mat.Neon)
	end
	local beam = self:block(span * 2 + 6, 3.6, 2.4, 0, 19.6, 0, t.Post, t.PostMat or Mat.Metal)
	beam.Name = "GateSign"
	self:surfaceText(beam, text, color)
	self:deco(span * 2 + 6.4, 0.4, 2.7, 0, 21.6, 0, color, Mat.Neon)
	self:deco(span * 2 + 6.4, 0.4, 2.7, 0, 17.6, 0, color, Mat.Neon)
end

--[[
	Build the next checkpoint: a round dais with a spawn pad, a trigger that
	the server listens to, lamps that light up once it has been reached, and
	a floating sign. Afterwards the cursor sits on the far rim, turned to face
	the next stage.
]]
function Kit:checkpoint(o)
	o = o or {}
	self.stage = self.stage + 1
	local index = self.stage
	local info = Config.Stages[index]
	local isFinish = index == Config.FinishIndex
	local zoneIndex = Config.zoneOf(index)
	local zone = Config.Zones[zoneIndex]
	local previous = Config.Stages[index - 1]
	local newZone = index == 1 or (previous ~= nil and previous.Zone ~= zoneIndex)

	self.theme = self.themes[zoneIndex]
	local t = self.theme
	self.folder = make("Folder", { Name = string.format("Stage%02d", index) }, self.root)
	self.trail = {}

	local radius = o.radius or ((newZone or isFinish) and 13 or 8)
	local centre = self:w(0, 0, radius - 1)
	local turn = (info and info.Turn) or 0
	local facing = centre * CFrame.Angles(0, -rad(turn), 0)

	self:push()
	self.cf = centre

	-- the dais (its top is 0.2 above the path so nothing z-fights)
	local dais = self:cyl(radius * 2, 1.7, 0, -0.65, 0, t.Plaza or t.Floor, t.PlazaMat or t.FloorMat)
	dais.Name = "Checkpoint"
	self:decoCyl(radius * 2 + 0.7, 0.5, 0, -0.75, 0, zone.Color, Mat.Neon)
	self:decoCyl(radius * 1.5, 2.4, 0, -2.7, 0, t.Body, t.BodyMat)
	self:decoCyl(radius * 0.8, 2.2, 0, -5, 0, t.Body2 or t.Body, t.BodyMat)

	-- glowing pad the player spawns on
	local pad = self:cyl(7, 0.2, 0, 0.3, 0, WHITE, Mat.Neon, { CanCollide = false, CastShadow = false })
	pad.Name = "Pad"
	pad:SetAttribute("Stage", index)
	tag(pad, "CheckpointLight")

	self.cf = facing
	local spawn = self:newPart("SpawnLocation", {
		Size = V3(5, 0.2, 5),
		CFrame = self:w(0, 0.5, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Neutral = true,
		Duration = 0,
		Enabled = true,
	})
	spawn.Name = "Spawn"
	self.cf = centre

	-- trigger volume
	local trigger = self:block(radius * 2 - 1, 12, radius * 2 - 1, 0, 6.2, 0, WHITE, Mat.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = true,
		CastShadow = false,
	})
	trigger.Name = "Trigger"
	trigger:SetAttribute("Stage", index)
	tag(trigger, "Checkpoint")

	-- lamp posts
	for _, side in ipairs({ -1, 1 }) do
		self:block(0.8, 7.4, 0.8, side * (radius - 1.4), 3.9, 0, t.Post, t.PostMat or Mat.Metal).Name = "LampPost"
		local orb = self:ball(1.8, side * (radius - 1.4), 8.2, 0, WHITE, Mat.Neon, { CanCollide = false, CastShadow = false })
		orb.Name = "Lamp"
		orb:SetAttribute("Stage", index)
		tag(orb, "CheckpointLight")
		self:light(orb, zone.Color, 16, 1.2)
	end

	-- floating sign
	local gui = self:billboard(pad, 16, 8, 12, 260)
	local title
	if isFinish then
		title = "🏁 FINISH"
	elseif index == 1 then
		title = "START"
	else
		title = tostring(index)
	end
	self:label(gui, title, zone.Color, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.56, 0))
	if info then
		self:label(gui, info.Name, WHITE, UDim2.new(0, 0, 0.56, 0), UDim2.new(1, 0, 0.24, 0))
		self:label(gui, info.Tip, RGB(200, 210, 240), UDim2.new(0, 0, 0.82, 0), UDim2.new(1, 0, 0.18, 0), Config.UI.FontBody)
	else
		self:label(gui, "You beat " .. Config.GameName .. "!", WHITE, UDim2.new(0, 0, 0.58, 0), UDim2.new(1, 0, 0.26, 0))
	end

	if isFinish then
		self:gate(radius, "🏆  FINISH  🏆", GOLD)
	elseif newZone then
		self:gate(radius, "ZONE " .. zoneIndex .. "  ·  " .. string.upper(zone.Name), zone.Color)
	end

	self:pop()

	self.checkpoints[index] = {
		Index = index,
		Spawn = spawn,
		Trigger = trigger,
		CFrame = facing,
		Radius = radius,
		Folder = self.folder,
	}

	-- step out to the rim (just inside it, a touch lower) facing the next stage
	self.cf = facing * CFrame.new(0, 0, -(radius - 1))
	self:mark(radius, -(radius - 1))
	return self.checkpoints[index]
end

return Kit
