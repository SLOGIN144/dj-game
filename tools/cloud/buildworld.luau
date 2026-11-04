--!nocheck
-- Builds the game's world with the real server code (Street, PlotView, Building...) on Lune's
-- Roblox instances, then dumps every part as JSON for the renderer.
-- Usage: lune run buildworld.luau <repo> <sourcemap.json> <out.json> [locationId]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local repo = process.args[1]
local map = serde.decode("json", fs.readFile(process.args[2]))
local outPath = process.args[3]
local locationId = process.args[4] or "dorm"

-- Methods Lune's instances don't have.
roblox.implementMethod("Model", "GetPivot", function(self)
	return self.WorldPivot
end)
roblox.implementMethod("Model", "PivotTo", function(self, target)
	local delta = target * self.WorldPivot:Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
	self.WorldPivot = target
end)
roblox.implementMethod("BasePart", "GetPivot", function(self)
	return self.CFrame
end)
roblox.implementMethod("BasePart", "PivotTo", function(self, target)
	local delta = target * self.CFrame:Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
	self.CFrame = target
end)

local dataModel = roblox.Instance.new("DataModel")
local realWorkspace = dataModel:GetService("Workspace")

-- The fake script tree from the sourcemap (for require), as in runspecs.luau.
local Node = {}
local methods = {}
local function makeNode(entry, parent)
	local node = setmetatable({ _name = entry.name, _class = entry.className, _parent = parent, _children = {} }, Node)
	for _, path in entry.filePaths or {} do
		if string.match(path, "%.luau?$") then
			node._file = path
		end
	end
	for _, child in entry.children or {} do
		table.insert(node._children, makeNode(child, node))
	end
	return node
end
function methods:FindFirstChild(name)
	for _, child in self._children do
		if child._name == name then
			return child
		end
	end
	return nil
end
function methods:GetFullName()
	local parts = {}
	local node = self
	while node and rawget(node, "_parent") do
		table.insert(parts, 1, node._name)
		node = node._parent
	end
	return table.concat(parts, ".")
end
Node.__index = function(self, key)
	if type(key) == "string" and string.sub(key, 1, 1) == "_" then
		return nil
	end
	if methods[key] then
		return methods[key]
	elseif key == "Name" then
		return self._name
	elseif key == "Parent" then
		return self._parent
	end
	local child = methods.FindFirstChild(self, key)
	if child then
		return child
	end
	error(string.format("%s is not a valid member of %s", tostring(key), self:GetFullName()), 2)
end
local root = makeNode(map, nil)

local function signal()
	return {
		Connect = function()
			return { Disconnect = function() end }
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
		Heartbeat = signal(),
	},
	TweenService = {
		Create = function()
			return { Play = function() end, Completed = signal() }
		end,
	},
	HttpService = {
		JSONEncode = function(_, v)
			return serde.encode("json", v)
		end,
		JSONDecode = function(_, t)
			return serde.decode("json", t)
		end,
		GenerateGUID = function()
			return "guid"
		end,
	},
}

local game = {}
function game:GetService(name)
	if stubs[name] then
		return stubs[name]
	end
	local node = root:FindFirstChild(name)
	if node and (name == "ReplicatedStorage" or name == "ServerScriptService") then
		return node
	end
	return dataModel:GetService(name)
end

local cache = {}
local baseEnv
local function requireNode(node)
	if cache[node] ~= nil then
		return cache[node]
	end
	local env = table.clone(baseEnv)
	env.script = node
	local fn = luau.load(fs.readFile(repo .. "/" .. node._file), { debugName = node._file, environment = env })
	local result = fn()
	cache[node] = result
	return result
end

baseEnv = {
	game = game,
	workspace = realWorkspace,
	require = requireNode,
	task = task,
	typeof = typeof,
	warn = function(...)
		print("WARN", ...)
	end,
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	ColorSequence = roblox.ColorSequence,
	TweenInfo = {
		new = function(...)
			return { ... }
		end,
	},
	Random = {
		new = function(seed)
			local state = math.floor(math.abs(seed or 1)) % 2147483647
			if state == 0 then
				state = 1
			end
			local r = {}
			function r:NextNumber(a, b)
				state = (state * 48271) % 2147483647
				local t = state / 2147483647
				if a == nil then
					return t
				end
				return a + (b - a) * t
			end
			function r:NextInteger(a, b)
				state = (state * 48271) % 2147483647
				return a + state % (b - a + 1)
			end
			return r
		end,
	},
}

local server = root:FindFirstChild("ServerScriptService"):FindFirstChild("Server")
local Street = requireNode(server:FindFirstChild("World"):FindFirstChild("Street"))
local PlotView = requireNode(server:FindFirstChild("World"):FindFirstChild("PlotView"))
local Items = requireNode(
	root:FindFirstChild("ReplicatedStorage"):FindFirstChild("Shared"):FindFirstChild("Config"):FindFirstChild("Items")
)

local plots = Street.build()
for _, plot in plots do
	PlotView.setup(plot)
end
-- Plot 1 gets a finished room at the location; the others stay free.
PlotView.setLocation(plots[1], locationId)
for _, item in Items[locationId] or {} do
	PlotView.showItem(plots[1], locationId, item.id, false)
end

if process.args[5] == "check" then
	-- Walks plot 1 through every location and back to free, checking what PlotView leaves behind.
	local Locations = requireNode(
		root:FindFirstChild("ReplicatedStorage")
			:FindFirstChild("Shared")
			:FindFirstChild("Config")
			:FindFirstChild("Locations")
	)
	local plot = plots[1]
	local function count(name)
		return #plot:FindFirstChild(name):GetDescendants()
	end
	PlotView.setOwner(plot, nil)
	for _, location in Locations do
		PlotView.setLocation(plot, location.id)
		assert(count("Items") == 0, "items cleared on " .. location.id)
		for _, item in Items[location.id] do
			PlotView.showItem(plot, location.id, item.id, false)
		end
		local origin = plot:GetAttribute("SpaceOrigin")
		local register = plot:FindFirstChild("Register")
		local spawn = plot:FindFirstChild("Spawn")
		local screen = register:FindFirstChild("Screen")
		print(
			string.format(
				"%-6s shell %4d items %4d showcase %4d origin %s register %s (screen %.1f away) spawn %s look %s",
				location.id,
				count("Shell"),
				count("Items"),
				count("Showcase"),
				if origin then tostring(origin.Position) else "plot",
				tostring(register.CFrame.Position),
				(screen.CFrame.Position - register.CFrame.Position).Magnitude,
				tostring(spawn.CFrame.Position),
				tostring(spawn.CFrame.LookVector)
			)
		)
		-- Replaced items are gone.
		for _, item in Items[location.id] do
			if item.replaces then
				assert(plot.Items:FindFirstChild(item.replaces) == nil, item.replaces .. " replaced by " .. item.id)
			end
		end
	end
	local Figures = requireNode(server:FindFirstChild("World"):FindFirstChild("Figures"))
	local vip = Figures.vip(roblox.CFrame.new(0, 1, 0), plot)
	local photographer, flash = Figures.photographer(roblox.CFrame.new(5, 1, 0), plot)
	print(
		string.format(
			"figures: vip %d parts, photographer %d parts, flash %s",
			#vip:GetChildren(),
			#photographer:GetChildren(),
			flash.Name
		)
	)
	vip:Destroy()
	photographer:Destroy()
	PlotView.clear(plot)
	print(
		string.format(
			"cleared: shell %d items %d showcase %d origin %s register %s spawn %s",
			count("Shell"),
			count("Items"),
			count("Showcase"),
			tostring(plot:GetAttribute("SpaceOrigin")),
			tostring(plot.Register.CFrame.Position),
			tostring(plot.Spawn.CFrame.Position)
		)
	)
	return
end

local parts = {}
for _, d in realWorkspace:GetDescendants() do
	if d:IsA("BasePart") then
		local cf = d.CFrame
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		local light = d:FindFirstChildWhichIsA("Light")
		table.insert(parts, {
			name = d.Name,
			path = d:GetFullName(),
			shape = if d:IsA("Part") then d.Shape.Name else "Block",
			size = { d.Size.X, d.Size.Y, d.Size.Z },
			cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			color = { d.Color.R, d.Color.G, d.Color.B },
			material = d.Material.Name,
			transparency = d.Transparency,
			light = if light then { light.Color.R, light.Color.G, light.Color.B, light.Range } else nil,
		})
	end
end
local spaceOrigin = plots[1]:GetAttribute("SpaceOrigin")
local space = if typeof(spaceOrigin) == "CFrame" then { spaceOrigin:GetComponents() } else nil
fs.writeFile(
	outPath,
	serde.encode("json", {
		parts = parts,
		space = space,
		plots = (function()
			local list = {}
			for _, plot in plots do
				local cf = plot.WorldPivot
				table.insert(list, { cf:GetComponents() })
			end
			return list
		end)(),
	})
)
print(string.format("built %d parts", #parts))
