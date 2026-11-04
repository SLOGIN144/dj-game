--!nocheck
-- Runs tests/*.spec.luau outside Studio (Lune), on a fake DataModel built from a Rojo sourcemap.
-- Usage: lune run runspecs.luau <repo> <sourcemap.json> [filter]
-- Only pure modules can run here: anything that touches real Roblox instances fails loudly.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local repo = process.args[1]
local sourcemapPath = process.args[2]
local filter = process.args[3]

local map = serde.decode("json", fs.readFile(sourcemapPath))

-- A fake Instance: name, class, children, parent and the file behind it.
local Node = {}

local function makeNode(entry, parent)
	local node = setmetatable({ _name = entry.name, _class = entry.className, _parent = parent, _children = {} }, Node)
	if entry.filePaths then
		for _, path in entry.filePaths do
			if string.match(path, "%.luau?$") then
				node._file = path
			end
		end
	end
	for _, child in entry.children or {} do
		table.insert(node._children, makeNode(child, node))
	end
	return node
end

local methods = {}

function methods:GetChildren()
	return table.clone(self._children)
end

function methods:FindFirstChild(name, recursive)
	for _, child in self._children do
		if child._name == name then
			return child
		end
	end
	if recursive then
		for _, child in self._children do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function methods:WaitForChild(name)
	local found = self:FindFirstChild(name)
	if not found then
		error("WaitForChild would wait forever: " .. self:GetFullName() .. "." .. name, 2)
	end
	return found
end

function methods:IsA(className)
	if className == "Instance" then
		return true
	end
	if className == "LuaSourceContainer" then
		return self._class == "ModuleScript" or self._class == "Script" or self._class == "LocalScript"
	end
	return self._class == className
end

function methods:GetFullName()
	local parts = {}
	local node = self
	while node and node._parent do
		table.insert(parts, 1, node._name)
		node = node._parent
	end
	return table.concat(parts, ".")
end

Node.__index = function(self, key)
	if type(key) == "string" and string.sub(key, 1, 1) == "_" then
		return nil -- internal fields that aren't set
	end
	if methods[key] then
		return methods[key]
	elseif key == "Name" then
		return self._name
	elseif key == "ClassName" then
		return self._class
	elseif key == "Parent" then
		return self._parent
	end
	local child = methods.FindFirstChild(self, key)
	if child then
		return child
	end
	error(string.format("%s is not a valid member of %s", tostring(key), self:GetFullName()), 2)
end
Node.__tostring = function(self)
	return self._name
end
Node.__type = "Instance"

local root = makeNode(map, nil)

-- Services that aren't in the sourcemap.
local function signal()
	return {
		Connect = function()
			return { Disconnect = function() end }
		end,
		Wait = function()
			error("can't wait on a signal outside Studio", 2)
		end,
	}
end

local stubs = {
	RunService = {
		IsStudio = function()
			return true
		end,
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
		Heartbeat = signal(),
		RenderStepped = signal(),
	},
	HttpService = {
		JSONEncode = function(_, value)
			return serde.encode("json", value)
		end,
		JSONDecode = function(_, text)
			return serde.decode("json", text)
		end,
		GenerateGUID = function()
			return "00000000-0000-0000-0000-000000000000"
		end,
	},
}

local game = {}
function game:GetService(name)
	return stubs[name] or root:FindFirstChild(name) or error("no service " .. name .. " in the harness", 2)
end
game.FindFirstChild = function(_, name)
	return root:FindFirstChild(name)
end

local cache = {}
local loading = {}
local baseEnv

local function load(node)
	assert(node._file, "no file behind " .. node:GetFullName())
	local source = fs.readFile(repo .. "/" .. node._file)
	-- Lune sets its own fallback metatable on the environment, so copy the globals in.
	local env = table.clone(baseEnv)
	env.script = node
	local fn = luau.load(source, { debugName = node._file, environment = env })
	return fn
end

local function requireNode(node)
	if type(node) ~= "table" or getmetatable(node) ~= Node then
		error("require expects a ModuleScript, got " .. typeof(node), 2)
	end
	if cache[node] ~= nil then
		return cache[node]
	end
	if loading[node] then
		error("cyclic require of " .. node:GetFullName(), 2)
	end
	loading[node] = true
	local result = load(node)()
	loading[node] = nil
	cache[node] = result
	return result
end

local function luauTypeof(value)
	if getmetatable(value) == Node then
		return "Instance"
	end
	return typeof(value)
end

baseEnv = {
	game = game,
	workspace = root:FindFirstChild("Workspace"),
	require = requireNode,
	task = task,
	typeof = luauTypeof,
	warn = function(...)
		print("WARN", ...)
	end,
	tick = os.clock,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	BrickColor = roblox.BrickColor,
	Rect = roblox.Rect,
}

-- Find and run every spec module (mirrors tests/RunTests.server.luau).
local tests = root:FindFirstChild("ServerScriptService"):FindFirstChild("Tests")
local specs = {}
for _, child in tests:GetChildren() do
	if child._class == "ModuleScript" and string.match(child._name, "%.spec$") then
		if not filter or string.find(child._name, filter, 1, true) then
			table.insert(specs, child)
		end
	end
end
table.sort(specs, function(a, b)
	return a._name < b._name
end)

local passed, failed = 0, 0
for _, module in specs do
	local ok, spec = pcall(requireNode, module)
	if not ok then
		failed += 1
		print(string.format("[Tests] %s failed to load: %s", module._name, tostring(spec)))
		continue
	end
	local names = {}
	for name in spec do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local okTest, err = pcall(spec[name])
		if okTest then
			passed += 1
		else
			failed += 1
			print(string.format("[Tests] FAIL %s > %s: %s", module._name, name, tostring(err)))
		end
	end
end

print(string.format("[Tests] %d passed, %d failed", passed, failed))
process.exit(if failed == 0 then 0 else 1)
