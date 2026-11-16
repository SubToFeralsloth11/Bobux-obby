-- A small strict imitation of the Roblox API, enough to execute the game
-- scripts outside Roblox. Property and enum names are validated against
-- the real API definitions (API_CLASSES / API_ENUMS are injected by run.py).

local unpack = unpack or table.unpack
table.unpack = table.unpack or unpack
table.find = function(t, v) for i, x in ipairs(t) do if x == v then return i end end return nil end
table.clear = function(t) for k in pairs(t) do t[k] = nil end end
math.clamp = function(x, a, b) if x < a then return a elseif x > b then return b end return x end
math.round = function(x) return math.floor(x + 0.5) end
function warn(...) print("WARN", ...) end

---------------------------------------------------------------- value types
local function class(name)
	local c = { __type = name }
	c.__index = c
	return c
end

local V3 = class("Vector3")
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = t.Magnitude return v3(t.X / m, t.Y / m, t.Z / m) end
	local m = rawget(V3, k)
	if m == nil then error("Vector3 has no member " .. tostring(k), 2) end
	return m
end
function V3.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Lerp(a, b, t) return a + (b - a) * t end
Vector3 = { new = v3, zero = v3(), one = v3(1, 1, 1) }

local V2 = class("Vector2")
Vector2 = { new = function(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end }

local CF = class("CFrame")
local function cf(p, m) return setmetatable({ p = p, m = m }, CF) end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mmul(a, b)
	local r = {}
	for i = 0, 2 do for j = 0, 2 do
		r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
	end end
	return r
end
local function mvec(m, v) return v3(m[1] * v.X + m[2] * v.Y + m[3] * v.Z, m[4] * v.X + m[5] * v.Y + m[6] * v.Z, m[7] * v.X + m[8] * v.Y + m[9] * v.Z) end
local function mT(m) return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] } end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then return mvec(a.m, b) + a.p end
	return cf(mvec(a.m, b.p) + a.p, mmul(a.m, b.m))
end
CF.__add = function(a, v) return cf(a.p + v, a.m) end
CF.__sub = function(a, v) return cf(a.p - v, a.m) end
CF.__index = function(t, k)
	local m = t.m
	if k == "Position" then return t.p end
	if k == "X" then return t.p.X elseif k == "Y" then return t.p.Y elseif k == "Z" then return t.p.Z end
	if k == "XVector" or k == "RightVector" then return v3(m[1], m[4], m[7]) end
	if k == "YVector" or k == "UpVector" then return v3(m[2], m[5], m[8]) end
	if k == "ZVector" then return v3(m[3], m[6], m[9]) end
	if k == "LookVector" then return v3(-m[3], -m[6], -m[9]) end
	local f = rawget(CF, k)
	if f == nil then error("CFrame has no member " .. tostring(k), 2) end
	return f
end
function CF.Inverse(a) local t = mT(a.m) return cf(-mvec(t, a.p), t) end
function CF.ToObjectSpace(a, b) return a:Inverse() * b end
function CF.ToWorldSpace(a, b) return a * b end
function CF.PointToObjectSpace(a, v) return a:Inverse() * v end
function CF.PointToWorldSpace(a, v) return a * v end
function CF.VectorToWorldSpace(a, v) return mvec(a.m, v) end
function CF.VectorToObjectSpace(a, v) return mvec(mT(a.m), v) end
local function axisAngle(axis, angle)
	local u = axis.Unit
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return { t * x * x + c, t * x * y - s * z, t * x * z + s * y, t * x * y + s * z, t * y * y + c, t * y * z - s * x, t * x * z - s * y, t * y * z + s * x, t * z * z + c }
end
CFrame = {
	new = function(x, y, z)
		if x == nil then return cf(v3(), IDENT) end
		if getmetatable(x) == V3 then return cf(x, IDENT) end
		return cf(v3(x, y, z), IDENT)
	end,
	Angles = function(rx, ry, rz)
		return cf(v3(), mmul(mmul(axisAngle(v3(1, 0, 0), rx), axisAngle(v3(0, 1, 0), ry)), axisAngle(v3(0, 0, 1), rz)))
	end,
	fromAxisAngle = function(axis, angle) return cf(v3(), axisAngle(axis, angle)) end,
}

local C3 = class("Color3")
local function c3(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
function C3.Lerp(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b) return c3(r / 255, g / 255, b / 255) end,
	fromHSV = function(h, s, v) assert(h >= 0 and h <= 1, "hue out of range") return c3(v, v * (1 - s), h) end,
}

local function simple(name, ...)
	local fields = { ... }
	local c = class(name)
	return { new = function(...)
		local args = { ... }
		local o = {}
		for i, f in ipairs(fields) do o[f] = args[i] end
		o.args = args
		return setmetatable(o, c)
	end }
end
UDim = simple("UDim", "Scale", "Offset")
UDim2 = simple("UDim2", "XS", "XO", "YS", "YO")
NumberRange = simple("NumberRange", "Min", "Max")
NumberSequenceKeypoint = simple("NumberSequenceKeypoint", "Time", "Value")
ColorSequenceKeypoint = simple("ColorSequenceKeypoint", "Time", "Value")
NumberSequence = simple("NumberSequence")
ColorSequence = simple("ColorSequence")
PhysicalProperties = simple("PhysicalProperties")
TweenInfo = simple("TweenInfo")
OverlapParams = { new = function() return {} end }
Random = { new = function(seed)
	local state = seed or 1
	local r = {}
	local function nextf() state = (state * 1103515245 + 12345) % 2147483648 return state / 2147483648 end
	function r:NextNumber(a, b) if a == nil then return nextf() end return a + (b - a) * nextf() end
	function r:NextInteger(a, b) return a + math.floor(nextf() * (b - a + 1)) end
	return r
end }

---------------------------------------------------------------- enums
local EnumItemMT = class("EnumItem")
Enum = setmetatable({}, { __index = function(_, enumName)
	local items = API_ENUMS[enumName]
	if not items then error("Enum." .. tostring(enumName) .. " does not exist", 2) end
	local e = setmetatable({}, { __index = function(_, itemName)
		if not items[itemName] then error("Enum." .. enumName .. "." .. tostring(itemName) .. " does not exist", 2) end
		local it = setmetatable({ Name = itemName, EnumType = enumName, Value = items[itemName] }, EnumItemMT)
		rawset(_, itemName, it)
		return it
	end })
	rawset(Enum, enumName, e)
	return e
end })

function typeof(v)
	local t = type(v)
	if t ~= "table" then return t end
	local mt = getmetatable(v)
	return (mt and mt.__type) or "table"
end

---------------------------------------------------------------- scheduler
task = {}
MAIN = coroutine.running()
local deferred = {}
function task.spawn(f, ...)
	local co = coroutine.create(f)
	local ok, err = coroutine.resume(co, ...)
	if not ok then error("task.spawn: " .. tostring(err) .. "\n" .. debug.traceback(co), 0) end
	return co
end
function task.defer(f, ...) table.insert(deferred, { f, { ... } }) end
function task.delay(_, f, ...) table.insert(deferred, { f, { ... } }) end
function task.wait(t)
	if coroutine.running() ~= MAIN and coroutine.running() ~= nil and not ALLOW_WAIT then coroutine.yield() end
	return t or 0
end
function FLUSH()
	local guard = 0
	while #deferred > 0 and guard < 10000 do
		guard = guard + 1
		local job = table.remove(deferred, 1)
		task.spawn(job[1], unpack(job[2]))
	end
end

---------------------------------------------------------------- signals
local Signal = class("RBXScriptSignal")
local function newSignal() return setmetatable({ handlers = {} }, Signal) end
function Signal:Connect(f) table.insert(self.handlers, f) return { Disconnect = function() end } end
function Signal:Once(f) return self:Connect(f) end
function Signal:Wait() return nil end
function Signal:Fire(...) for _, f in ipairs(self.handlers) do task.spawn(f, ...) end end

---------------------------------------------------------------- instances
local Inst = {}
local methods = {}
local tags = {}
local tagSignals = {}
INSTANCE_COUNT = 0

local function apiMember(className, key)
	local c = API_CLASSES[className]
	while c do
		local kind = c.members[key]
		if kind then return kind end
		c = API_CLASSES[c.parent]
	end
	return nil
end
local function isA(className, target)
	local c = className
	while c do
		if c == target then return true end
		c = API_CLASSES[c] and API_CLASSES[c].parent
	end
	return false
end

Inst.__type = "Instance"
Inst.__index = function(self, key)
	local raw = rawget(self, "_")
	if key == "ClassName" then return raw.class end
	if key == "Parent" then return raw.parent end
	if key == "Name" then return raw.props.Name end
	local m = methods[key]
	local kind = apiMember(raw.class, key)
	if kind == "signal" or key == "OnServerEvent" or key == "OnClientEvent" then
		raw.signals[key] = raw.signals[key] or newSignal()
		return raw.signals[key]
	end
	if kind == "method" then return m or function() return nil end end
	if kind == "prop" then
		local v = raw.props[key]
		if v == nil and DEFAULTS[key] ~= nil then return DEFAULTS[key] end
		if key == "Position" and raw.props.CFrame then return raw.props.CFrame.Position end
		return v
	end
	for _, child in ipairs(raw.children) do
		if child.Name == key then return child end
	end
	error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), raw.class, tostring(raw.props.Name)), 2)
end
Inst.__newindex = function(self, key, value)
	local raw = rawget(self, "_")
	if key == "Parent" then
		if raw.parent then
			local list = rawget(raw.parent, "_").children
			for i, c in ipairs(list) do if c == self then table.remove(list, i) break end end
		end
		raw.parent = value
		if value then
			table.insert(rawget(value, "_").children, self)
			if rawget(value, "_").signals.ChildAdded then rawget(value, "_").signals.ChildAdded:Fire(self) end
		end
		return
	end
	local kind = apiMember(raw.class, key)
	if kind ~= "prop" then
		error(string.format("%s is not a settable property of %s", tostring(key), raw.class), 2)
	end
	if value == nil and key ~= "Adornee" and key ~= "SelectedObject" and key ~= "RespawnLocation" then
		error("assigning nil to " .. raw.class .. "." .. key, 2)
	end
	raw.props[key] = value
	if key == "Position" and raw.props.CFrame then raw.props.CFrame = CFrame.new(value) end
	local sig = raw.signals["prop:" .. key]
	if sig then sig:Fire() end
end
DEFAULTS = {
	Transparency = 0, CanCollide = true, CanQuery = true, CanTouch = true, Visible = true, Health = 100, Enabled = true,
	KeyboardEnabled = true, TouchEnabled = false, GamepadEnabled = false, HipHeight = 2, AssemblyMass = 10, FieldOfView = 70, WalkSpeed = 16, JumpPower = 50, Gravity = 196.2, TextTransparency = 0,
}

local function new(className, name)
	if not API_CLASSES[className] then error("Unknown class " .. tostring(className), 2) end
	INSTANCE_COUNT = INSTANCE_COUNT + 1
	local raw = { class = className, props = { Name = name or className }, children = {}, attrs = {}, signals = {} }
	local inst = setmetatable({ _ = raw }, Inst)
	if isA(className, "BasePart") then
		raw.props.CFrame = CFrame.new()
		raw.props.Size = Vector3.new(4, 1, 2)
		raw.props.AssemblyLinearVelocity = Vector3.new()
	end
	return inst
end
Instance = { new = function(className) return new(className) end }

function methods.IsA(self, name) return isA(self._.class, name) end
function methods.FindFirstChild(self, name) for _, c in ipairs(self._.children) do if c.Name == name then return c end end return nil end
function methods.WaitForChild(self, name)
	local c = methods.FindFirstChild(self, name)
	if not c then error("WaitForChild would hang: " .. tostring(name) .. " in " .. self.Name, 2) end
	return c
end
function methods.FindFirstChildOfClass(self, cn) for _, c in ipairs(self._.children) do if c._.class == cn then return c end end return nil end
function methods.FindFirstChildWhichIsA(self, cn) for _, c in ipairs(self._.children) do if isA(c._.class, cn) then return c end end return nil end
function methods.GetChildren(self) local t = {} for i, c in ipairs(self._.children) do t[i] = c end return t end
function methods.GetDescendants(self)
	local out = {}
	local function walk(n) for _, c in ipairs(n._.children) do table.insert(out, c) walk(c) end end
	walk(self)
	return out
end
function methods.IsDescendantOf(self, other)
	local p = self._.parent
	while p do if p == other then return true end p = p._.parent end
	return false
end
function methods.Destroy(self) self.Parent = nil end
function methods.SetAttribute(self, k, v)
	self._.attrs[k] = v
	local s = self._.signals["attr:" .. k]
	if s then s:Fire() end
end
function methods.GetAttribute(self, k) return self._.attrs[k] end
function methods.GetAttributeChangedSignal(self, k)
	self._.signals["attr:" .. k] = self._.signals["attr:" .. k] or newSignal()
	return self._.signals["attr:" .. k]
end
function methods.GetPropertyChangedSignal(self, k)
	if apiMember(self._.class, k) ~= "prop" then error("no property " .. k, 2) end
	self._.signals["prop:" .. k] = self._.signals["prop:" .. k] or newSignal()
	return self._.signals["prop:" .. k]
end
function methods.GetService(self, name) return SERVICES(name) end
function methods.GetServerTimeNow() return CLOCK end
function methods.PivotTo(self, c) end
function methods.GetState(self) return Enum.HumanoidStateType.Running end
function methods.FireServer(self, ...) if SERVER_REMOTE then SERVER_REMOTE(self, ...) end end
function methods.FireClient(self, player, ...) table.insert(CLIENT_EVENTS, { self.Name, ... }) end
function methods.Create(self, inst, info, goal)
	for k, v in pairs(goal) do inst[k] = v end -- validates property names and jumps to the goal
	return { Play = function() end, Cancel = function() end }
end
function methods.AddTag(self, inst, name)
	tags[name] = tags[name] or {}
	table.insert(tags[name], inst)
	if tagSignals[name] then tagSignals[name]:Fire(inst) end
end
function methods.GetTagged(self, name) local t = {} for i, c in ipairs(tags[name] or {}) do t[i] = c end return t end
function methods.HasTag(self, inst, name) for _, c in ipairs(tags[name] or {}) do if c == inst then return true end end return false end
function methods.GetInstanceAddedSignal(self, name) tagSignals[name] = tagSignals[name] or newSignal() return tagSignals[name] end
function methods.GetInstanceRemovedSignal(self, name) return newSignal() end
function methods.GetPlayers(self) return methods.GetChildren(self) end
function methods.GetPlayerFromCharacter(self, ch) for _, p in ipairs(self._.children) do if p._.props.Character == ch then return p end end return nil end
function methods.GetDataStore() error("DataStore unavailable in tests") end
function methods.BindToClose() end
function methods.BindAction() end
function methods.BindToRenderStep(self, name, prio, f) RENDER_STEP = f end
function methods.PlayLocalSound() end
function methods.Play() end
function methods.Emit() end
function methods.AddItem() end
function methods.IsStudio() return true end
function methods.LoadCharacter(self) if ON_LOAD_CHARACTER then ON_LOAD_CHARACTER(self) end end
function methods.ChangeState() end
function methods.GetPartBoundsInBox(self, c, size, params) return QUERY and QUERY(params, c.Position, size.Magnitude) or {} end
function methods.GetPartBoundsInRadius(self, pos, r, params) return QUERY and QUERY(params, pos, r) or {} end
TAGS = tags

local services = {}
game = new("DataModel", "game")
function SERVICES(name)
	if not services[name] then
		services[name] = new(name, name)
		services[name].Parent = game
	end
	return services[name]
end
workspace = SERVICES("Workspace")
CLOCK = 1000
CLIENT_EVENTS = {}
NEW = new
