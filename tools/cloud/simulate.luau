--!nocheck
-- Runs the real server (src/server/Main.server.luau) on Lune's Roblox instances, with the engine's
-- events, remotes, clock and DataStore stubbed, then plays a scripted session: join, buy every
-- item, move on through every location, catch a drop, book a star DJ, run each event, fly, leave
-- and rejoin. Prints every error a handler raised and every failed check.
-- Usage: lune run simulate.luau <repo> <sourcemap.json>

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local repo = process.args[1]
local map = serde.decode("json", fs.readFile(process.args[2]))

local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame

---------------------------------------------------------------------------------------------------
-- Clock, errors, checks

local clock = 0
local EPOCH = 1800000000
local function serverNow()
	return EPOCH + clock
end

local errors, failures, passes = {}, {}, 0
local function traced(err)
	return tostring(err) .. "\n" .. debug.traceback()
end
local function report(where, err)
	table.insert(errors, string.format("%s: %s", where, tostring(err)))
	print("ERROR in " .. where .. ": " .. tostring(err))
end
local function check(condition, message)
	if condition then
		passes += 1
	else
		table.insert(failures, message)
		print("FAIL: " .. message)
	end
	return condition
end

---------------------------------------------------------------------------------------------------
-- Fake signals for the engine events Lune's instances don't have

local Signal = {}
Signal.__index = Signal
local function newSignal(name)
	return setmetatable({ name = name, handlers = {} }, Signal)
end
function Signal:Connect(fn)
	table.insert(self.handlers, fn)
	local signal = self
	return {
		Disconnect = function()
			local index = table.find(signal.handlers, fn)
			if index then
				table.remove(signal.handlers, index)
			end
		end,
	}
end
function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		fn(...)
	end)
	return connection
end
function Signal:Wait()
	local thread = coroutine.running()
	self.waiting = self.waiting or {}
	table.insert(self.waiting, thread)
	return coroutine.yield()
end
-- Like Roblox: each handler runs in its own thread (a coroutine the fake scheduler can resume).
function Signal:Fire(...)
	local waiting = self.waiting
	if waiting and #waiting > 0 then
		self.waiting = {}
		for _, thread in waiting do
			local ok, err = coroutine.resume(thread, ...)
			if not ok then
				report(self.name .. ":Wait", err)
			end
		end
	end
	for _, fn in table.clone(self.handlers) do
		local args = table.pack(...)
		local thread = coroutine.create(function()
			local ok, err = xpcall(fn, traced, table.unpack(args, 1, args.n))
			if not ok then
				report(self.name, err)
			end
		end)
		local ok, err = coroutine.resume(thread)
		if not ok then
			report(self.name, err)
		end
	end
end

-- Lune hands out a new userdata on every access to an instance, so instances can't be table keys
-- here; each gets a stable id attribute instead. (Roblox keeps one per instance; the game's own
-- tables are fine.)
local nextId = 0
local function idOf(instance)
	local id = instance:GetAttribute("SimId")
	if not id then
		nextId += 1
		id = nextId
		instance:SetAttribute("SimId", id)
	end
	return id
end
local signals = {}
local function signalOf(instance, name)
	local key = idOf(instance)
	local byName = signals[key]
	if not byName then
		byName = {}
		signals[key] = byName
	end
	local signal = byName[name]
	if not signal then
		signal = newSignal(instance.Name .. "." .. name)
		byName[name] = signal
	end
	return signal
end
for _, pair in
	{
		{ "BasePart", "Touched" },
		{ "ProximityPrompt", "Triggered" },
		{ "RemoteEvent", "OnServerEvent" },
		{ "RemoteEvent", "OnClientEvent" },
		{ "Players", "PlayerAdded" },
		{ "Players", "PlayerRemoving" },
		{ "ProximityPromptService", "PromptTriggered" },
	}
do
	roblox.implementProperty(pair[1], pair[2], function(self)
		return signalOf(self, pair[2])
	end)
end

-- Remotes fired at clients are logged, newest last.
local sent = {}
local localPlayer = nil -- the player the simulated client is, once it has started
roblox.implementMethod("RemoteEvent", "FireClient", function(self, player, ...)
	table.insert(sent, { remote = self.Name, player = player, args = table.pack(...) })
	if localPlayer and player.UserId == localPlayer.UserId then
		signalOf(self, "OnClientEvent"):Fire(...)
	end
end)
roblox.implementMethod("RemoteEvent", "FireAllClients", function(self, ...)
	table.insert(sent, { remote = self.Name, player = "all", args = table.pack(...) })
	if localPlayer then
		signalOf(self, "OnClientEvent"):Fire(...)
	end
end)
local toServer = {}
roblox.implementMethod("RemoteEvent", "FireServer", function(self, ...)
	table.insert(toServer, { remote = self.Name, args = table.pack(...) })
	signalOf(self, "OnServerEvent"):Fire(localPlayer, ...)
end)
local function sentSince(index, remote)
	local found = {}
	for i = index + 1, #sent do
		if sent[i].remote == remote then
			table.insert(found, sent[i])
		end
	end
	return found
end

-- Players and characters.
-- (Character and RespawnLocation are real properties on Lune's Player.)
local kicked = {}
roblox.implementMethod("Player", "Kick", function(self, message)
	kicked[self.UserId] = message
end)
roblox.implementMethod("Player", "RequestStreamAroundAsync", function() end)
local playerList = {}
roblox.implementMethod("Players", "GetPlayers", function()
	return table.clone(playerList)
end)
roblox.implementMethod("Players", "GetPlayerFromCharacter", function(_, model)
	for _, player in playerList do
		if player.Character == model then
			return player
		end
	end
	return nil
end)

-- Lune keeps a part's CFrame but doesn't derive its Position from it: moving a model or a part
-- here sets both. (The game only reads Position from characters, which only move this way.)
local function place(part, cframe)
	part.CFrame = cframe
	part.Position = cframe.Position
end

-- Change signals: Lune fires none, so watched attributes and children are compared each step
-- and their signals fired on a change (like replication arriving).
local watchers = {}
local function childIds(instance, kind)
	local list = if kind == "ChildAdded" or kind == "ChildRemoved"
		then instance:GetChildren()
		else instance:GetDescendants()
	local ids = {}
	for _, child in list do
		ids[idOf(child)] = child
	end
	return ids
end
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(self, name)
	local signal = signalOf(self, "attr:" .. name)
	if not signal.watched then
		signal.watched = true
		table.insert(
			watchers,
			{ instance = self, kind = "attr", name = name, signal = signal, last = self:GetAttribute(name) }
		)
	end
	return signal
end)
for _, kind in { "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving" } do
	roblox.implementProperty("Instance", kind, function(self)
		local signal = signalOf(self, kind)
		if not signal.watched then
			signal.watched = true
			table.insert(watchers, { instance = self, kind = kind, signal = signal, last = childIds(self, kind) })
		end
		return signal
	end)
end
local pollCount = 0
local function pollWatchers()
	pollCount += 1
	for _, watcher in table.clone(watchers) do
		local ok, err = pcall(function()
			if watcher.kind == "attr" then
				local value = watcher.instance:GetAttribute(watcher.name)
				if value ~= watcher.last then
					watcher.last = value
					watcher.signal:Fire()
				end
				return
			end
			local deep = watcher.kind == "DescendantAdded" or watcher.kind == "DescendantRemoving"
			if deep and watcher.instance:IsA("Workspace") and pollCount % 10 ~= 0 then
				return
			end
			local now = childIds(watcher.instance, watcher.kind)
			local adding = watcher.kind == "ChildAdded" or watcher.kind == "DescendantAdded"
			local before = watcher.last
			watcher.last = now
			for id, child in (if adding then now else before) do
				local other = if adding then before else now
				if other[id] == nil then
					watcher.signal:Fire(child)
				end
			end
		end)
		if not ok and not string.find(tostring(err), "destroyed") then
			report("watcher " .. watcher.kind, err)
		end
	end
end
for _, pair in
	{
		{ "GuiButton", "Activated" },
		{ "GuiObject", "InputBegan" },
		{ "GuiObject", "InputEnded" },
		{ "Player", "CharacterRemoving" },
		{ "Player", "CharacterAdded" },
	}
do
	roblox.implementProperty(pair[1], pair[2], function(self)
		return signalOf(self, pair[2])
	end)
end
roblox.implementMethod("AudioPlayer", "Play", function(self)
	self.IsPlaying = true
end)
roblox.implementMethod("AudioPlayer", "Stop", function(self)
	self.IsPlaying = false
end)
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
roblox.implementMethod("Humanoid", "SetStateEnabled", function() end)
roblox.implementMethod("SoundService", "GetMixerTime", function()
	return clock
end)
roblox.implementMethod("Debris", "AddItem", function() end)
roblox.implementMethod("Workspace", "BulkMoveTo", function(_, parts, frames)
	for index, part in parts do
		part.CFrame = frames[index]
	end
end)

-- Instance methods Lune lacks.
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	local child = self:FindFirstChild(name)
	assert(child, "WaitForChild would wait forever for " .. tostring(name) .. " in " .. self:GetFullName())
	return child
end)
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return serverNow()
end)
roblox.implementMethod("Model", "GetPivot", function(self)
	local ok, pivot = pcall(function()
		return self.WorldPivot
	end)
	if ok then
		return pivot
	end
	-- Roblox's default: the centre of the model's parts.
	local sum, count = Vector3.zero, 0
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			sum += d.CFrame.Position
			count += 1
		end
	end
	return CFrame.new(if count > 0 then sum / count else Vector3.zero)
end)
roblox.implementMethod("Model", "PivotTo", function(self, target)
	local delta = target * self.WorldPivot:Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			place(d, delta * d.CFrame)
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
			place(d, delta * d.CFrame)
		end
	end
	place(self, target)
end)

---------------------------------------------------------------------------------------------------
-- The script tree from the sourcemap, with a require that loads the repo's files

local dataModel = Instance.new("DataModel")
local workspace = dataModel:GetService("Workspace")
-- Terrain: Lune's workspace has none, and can't fill voxels; the game's fills do nothing here.
roblox.implementMethod("Terrain", "FillBlock", function() end)
local terrain = Instance.new("Terrain")
terrain.Parent = workspace

-- Real instances for the scripts, so `script.Parent` and the services work like in Roblox; each
-- ModuleScript remembers the file behind it.
local files = {} -- full name -> file
local SERVICES = {
	ReplicatedStorage = true,
	ServerScriptService = true,
	Workspace = true,
	ServerStorage = true,
	StarterPlayer = true,
}
local function build(entry, parent)
	local className = entry.className
	local instance
	if className == "DataModel" then
		instance = nil
	elseif SERVICES[className] then
		instance = dataModel:GetService(className)
	else
		local creatable = className == "ModuleScript" or className == "Script" or className == "LocalScript"
		instance = Instance.new(if creatable then className else "Folder")
		instance.Name = entry.name
		instance.Parent = parent
	end
	if instance then
		for _, path in entry.filePaths or {} do
			if string.match(path, "%.luau?$") then
				files[instance:GetFullName()] = path
			end
		end
	end
	for _, child in entry.children or {} do
		build(child, instance or dataModel)
	end
	return instance
end
build(map, nil)

local heartbeat = newSignal("Heartbeat")
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
		Heartbeat = heartbeat,
	},
	TweenService = {
		Create = function()
			return { Play = function() end, Completed = newSignal("TweenCompleted") }
		end,
	},
	HttpService = {
		JSONEncode = function(_, value)
			return serde.encode("json", value)
		end,
		JSONDecode = function(_, text)
			return serde.decode("json", text)
		end,
		GenerateGUID = function()
			return "sim-guid"
		end,
	},
}

local game = { Name = "Simulation" }
function game:GetService(name)
	if stubs[name] then
		return stubs[name]
	end
	return dataModel:GetService(name)
end
function game:BindToClose() end

-- The save store: PlayerData is replaced by this stub, which keeps saves in memory.
local saves = {}
local saveCalls = 0
local PlayerDataStub = {}

local cache = {}
local baseEnv
local function requireNode(node)
	if node.Name == "PlayerData" then
		return PlayerDataStub
	end
	local file = assert(files[node:GetFullName()], "no file behind " .. node:GetFullName())
	if cache[file] ~= nil then
		return cache[file]
	end
	local env = table.clone(baseEnv)
	env.script = node
	local source = fs.readFile(repo .. "/" .. file)
	local fn = luau.load(source, { debugName = file, environment = env })
	local result = fn()
	cache[file] = if result == nil then true else result
	return result
end

-- The game's task library on the fake clock: delays and waits come due as the clock advances.
local due = {} -- { at, thread, args }
local function schedule(at, thread, ...)
	table.insert(due, { at = at, thread = thread, args = table.pack(...) })
end
local function runDue()
	local ran = true
	while ran do
		ran = false
		table.sort(due, function(a, b)
			return a.at < b.at
		end)
		local first = due[1]
		if first and first.at <= clock + 1e-9 then
			table.remove(due, 1)
			ran = true
			local ok, err = coroutine.resume(first.thread, table.unpack(first.args, 1, first.args.n))
			if not ok then
				report("task", traced(err))
			end
		end
	end
end
local function guardedTask()
	local wrapped = {}
	local function guard(where, fn)
		if type(fn) ~= "function" then
			return fn
		end
		return function(...)
			local ok, err = xpcall(fn, traced, ...)
			if not ok then
				report(where, err)
			end
		end
	end
	wrapped.spawn = function(fn, ...)
		local thread = if type(fn) == "thread" then fn else coroutine.create(guard("task.spawn", fn))
		local ok, err = coroutine.resume(thread, ...)
		if not ok then
			report("task.spawn", traced(err))
		end
		return thread
	end
	wrapped.defer = function(fn, ...)
		return wrapped.delay(0, fn, ...)
	end
	wrapped.delay = function(seconds, fn, ...)
		local thread = coroutine.create(guard("task.delay", fn))
		schedule(clock + (seconds or 0), thread, ...)
		return thread
	end
	wrapped.wait = function(seconds)
		local thread = coroutine.running()
		local start = clock
		schedule(clock + (seconds or 0), thread)
		coroutine.yield()
		return clock - start
	end
	wrapped.cancel = function(thread)
		for index, entry in due do
			if entry.thread == thread then
				table.remove(due, index)
				return
			end
		end
	end
	return wrapped
end

baseEnv = {
	game = game,
	workspace = workspace,
	require = requireNode,
	task = guardedTask(),
	typeof = roblox.typeof or typeof,
	warn = function(...)
		print("WARN", ...)
	end,
	os = {
		clock = function()
			return clock
		end,
		time = function()
			return math.floor(serverNow())
		end,
		date = os.date,
	},
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
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	TweenInfo = {
		new = function(...)
			return { ... }
		end,
	},
	Random = {
		new = function(seed)
			local state = math.floor(math.abs(seed or 12345)) % 2147483647
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

local Shared = dataModel:GetService("ReplicatedStorage"):FindFirstChild("Shared")
local Server = dataModel:GetService("ServerScriptService"):FindFirstChild("Server")
local function find(start, path)
	local node = start
	for part in string.gmatch(path, "[^.]+") do
		node = assert(node:FindFirstChild(part), "no " .. part .. " in " .. node:GetFullName())
	end
	return node
end
local function shared(path)
	return requireNode(find(Shared, path))
end
local function server(path)
	return requireNode(find(Server, path))
end

-- PlayerData stub: loads what was saved (or a new player), saves into `saves`.
local SaveSchema = shared("Data.SaveSchema")
function PlayerDataStub.load(player)
	return SaveSchema.migrate(saves[player.UserId]), "loaded"
end
function PlayerDataStub.save(userId, data)
	saveCalls += 1
	saves[userId] = serde.decode("json", serde.encode("json", data)) -- what a DataStore would give back
	return true
end
function PlayerDataStub.isSaving()
	return true
end
function PlayerDataStub.start() end

---------------------------------------------------------------------------------------------------
-- The client: its own module cache and services, like the separate Luau VM it is in Roblox

local renderStepped = newSignal("RenderStepped")
local clientHeartbeat = newSignal("Client.Heartbeat")
local renderBinds = {}
local inputBegan = newSignal("InputBegan")
local clientStubs = {
	RunService = {
		IsStudio = function()
			return true
		end,
		IsServer = function()
			return false
		end,
		IsClient = function()
			return true
		end,
		RenderStepped = renderStepped,
		Heartbeat = clientHeartbeat,
		BindToRenderStep = function(_, name, _, fn)
			renderBinds[name] = fn
		end,
		UnbindFromRenderStep = function(_, name)
			renderBinds[name] = nil
		end,
	},
	TweenService = stubs.TweenService,
	HttpService = stubs.HttpService,
	UserInputService = {
		InputBegan = inputBegan,
		InputChanged = newSignal("InputChanged"),
		InputEnded = newSignal("InputEnded"),
		TouchEnabled = false,
		KeyboardEnabled = true,
		MouseEnabled = true,
		GamepadEnabled = false,
	},
	ContextActionService = {
		BindActionAtPriority = function() end,
		BindAction = function() end,
		UnbindAction = function() end,
	},
}
local clientGame = { Name = "Client" }
function clientGame:GetService(name)
	return clientStubs[name] or dataModel:GetService(name)
end

-- Instance.new with the values Lune has no defaults for (read-only ones Roblox fills in).
local ClientInstance = {
	new = function(className)
		local instance = roblox.Instance.new(className)
		if className == "AudioPlayer" then
			instance.IsReady = true
			instance.IsPlaying = false
			instance.TimeLength = 240
			instance.Asset = ""
		end
		if instance:IsA("GuiObject") then
			instance.AbsoluteSize = roblox.Vector2.new(200, 40)
			instance.AbsolutePosition = roblox.Vector2.new(0, 0)
		end
		return instance
	end,
}

local clientCache = {}
local clientEnv
local function clientRequire(node)
	local file = assert(files[node:GetFullName()], "no file behind " .. node:GetFullName())
	if clientCache[file] ~= nil then
		return clientCache[file]
	end
	local env = table.clone(clientEnv)
	env.script = node
	local fn = luau.load(fs.readFile(repo .. "/" .. file), { debugName = "client:" .. file, environment = env })
	local result = fn()
	clientCache[file] = if result == nil then true else result
	return result
end
clientEnv = table.clone(baseEnv)
clientEnv.game = clientGame
clientEnv.require = clientRequire
clientEnv.Instance = ClientInstance

local clientCamera = nil
local function bootClient(player)
	localPlayer = player
	dataModel:GetService("Players").LocalPlayer = player
	local playerGui = Instance.new("PlayerGui")
	playerGui.Parent = player
	clientCamera = Instance.new("Camera")
	clientCamera.Parent = workspace
	workspace.CurrentCamera = clientCamera
	local client = dataModel:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("Client")
	local ok, err = pcall(clientRequire, client:FindFirstChild("Main"))
	if not ok then
		report("client Main", err)
	end
end

-- The default camera follows the character from behind and above (the decks take it over).
local function followCamera()
	local character = localPlayer and localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not clientCamera or clientCamera.CameraType == roblox.Enum.CameraType.Scriptable then
		return
	end
	local at = rootPart.CFrame.Position
	clientCamera.CFrame = CFrame.lookAt(at + Vector3.new(0, 9, -16), at)
end

local function stepClient(dt)
	if not localPlayer then
		return
	end
	followCamera()
	clientHeartbeat:Fire(dt)
	renderStepped:Fire(dt)
	for name, fn in renderBinds do
		local ok, err = pcall(fn, dt)
		if not ok then
			report("render step " .. name, err)
		end
	end
	pollWatchers()
end

---------------------------------------------------------------------------------------------------
-- Time passing

-- Advances the fake clock by `seconds` in heartbeat steps of `step`, letting each handler run.
local function advance(seconds, step)
	step = step or 0.1
	local left = seconds
	while left > 1e-9 do
		local dt = math.min(step, left)
		clock += dt
		left -= dt
		runDue()
		heartbeat:Fire(dt)
		stepClient(dt)
	end
	runDue()
end

-- The same, for waits in the game code (the travel fade).
local function settle(seconds)
	advance(seconds, 0.1)
end

---------------------------------------------------------------------------------------------------
-- Boot the server

local okMain, mainError = pcall(function()
	requireNode(find(Server, "Main"))
end)
check(okMain, "Main.server.luau runs: " .. tostring(mainError))

local Players = dataModel:GetService("Players")
local PromptService = dataModel:GetService("ProximityPromptService")
local Items = shared("Config.Items")
local Locations = shared("Config.Locations")
local Blockouts = shared("Config.Blockouts")
local PlayerState = server("Services.PlayerState")
local Shop = server("Services.Shop")
local Music = server("Services.Music")
local Events = server("Services.Events")
local PlotSpace = shared("Util.PlotSpace")
local Unlocks = shared("Economy.Unlocks")

local function newCharacter(player)
	local model = Instance.new("Model")
	model.Name = player.Name
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	place(rootPart, CFrame.new(0, 3, 0))
	rootPart.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.MoveDirection = Vector3.zero
	humanoid.Parent = model
	model.PrimaryPart = rootPart
	model.WorldPivot = rootPart.CFrame
	model.Parent = workspace
	player.Character = model
	return model
end

local function join(name, userId)
	local player = Instance.new("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = userId
	player.Parent = Players
	table.insert(playerList, player)
	local character = newCharacter(player)
	Players.PlayerAdded:Fire(player)
	advance(0.5)
	return player, character
end

local function leave(player)
	Players.PlayerRemoving:Fire(player)
	advance(0.5)
	table.remove(playerList, table.find(playerList, player))
	player.Parent = nil
	local character = player.Character
	if character then
		character:Destroy()
	end
end

local function rootOf(character)
	return character:FindFirstChild("HumanoidRootPart")
end

local function triggerPrompt(prompt, player)
	PromptService.PromptTriggered:Fire(prompt, player)
	prompt.Triggered:Fire(player)
end

local function findDescendant(parent, predicate)
	for _, d in parent:GetDescendants() do
		if predicate(d) then
			return d
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- The session

local function finishRun()
	print(string.format("\n%d checks passed, %d failed, %d errors", passes, #failures, #errors))
	for _, message in failures do
		print("  failed: " .. message)
	end
	for _, message in errors do
		print("  error: " .. string.sub(message, 1, 900))
	end
	process.exit(if #failures == 0 and #errors == 0 then 0 else 1)
end

local okSession, sessionError = pcall(function()
	print("== join")
	local filip, filipBody = join("Filip", 1001)
	bootClient(filip)
	advance(1)
	local playerGui = filip:FindFirstChild("PlayerGui")
	local function gui(name)
		return playerGui and playerGui:FindFirstChild(name)
	end
	local function label(guiName, labelName)
		local screen = gui(guiName)
		local found = screen
			and findDescendant(screen, function(d)
				return d.Name == labelName and d:IsA("TextLabel")
			end)
		return found and found.Text
	end
	for _, name in { "Hud", "Goals", "Settings", "DjBoard", "TrackShop", "Fade", "Dialogue" } do
		check(gui(name) ~= nil, "the client builds its " .. name .. " screen")
	end
	check(label("Hud", "Cash") == "$50", "the HUD shows the starting cash")
	advance(1)
	local guide = playerGui and playerGui:FindFirstChild("Guide")
	check(
		guide ~= nil and guide.Enabled and guide.Adornee ~= nil and guide.Adornee.Name == "Pad_dorm_laptop",
		"the guide points a new player at the free laptop"
	)
	local audio = dataModel:GetService("SoundService"):FindFirstChild("AudioEngine", true)
	check(audio ~= nil, "the client builds its audio engine")
	check(workspace:FindFirstChild("LocalGuests") ~= nil, "the client has a folder for guests")
	local state = PlayerState.get(filip)
	check(state ~= nil, "Filip gets a plot")
	if not state then
		finishRun()
	end
	local plot = state.plot
	check(plot:GetAttribute("OwnerUserId") == 1001, "the plot knows its owner")
	check(plot:GetAttribute("LocationId") == "dorm", "a new player starts in the dorm")
	check(#plot.Pads:GetChildren() == 3, "three button pads show")
	check(typeof(plot:GetAttribute("MixPlan")) == "string", "the plot's mix is planned")
	check((rootOf(filipBody).Position - plot.Spawn.CFrame.Position).Magnitude < 6, "the character is put on the spawn")
	check(filip:GetAttribute("Cash") == 50, "starting cash shows")

	advance(3) -- the host's hello comes after a moment
	local said = sentSince(0, "Say")
	check(#said > 0 and said[#said].args[2] == shared("Config.Goals").dorm.lines.intro, "Max says hello")

	print("== collect from the register")
	check(Shop.buy(state, "dorm_laptop"), "the free laptop can be taken")
	advance(30)
	check(findDescendant(plot.Items, function(d)
		return d.Name == "DecksPrompt"
	end) ~= nil, "the client puts its Play prompt on the laptop")
	local deckA = audio and audio:FindFirstChild("DeckAPlayer")
	check(deckA ~= nil and string.find(deckA.Asset, "rbxassetid://") ~= nil, "a deck loads a track")
	local before = state.cash
	plot.Register.Touched:Fire(rootOf(filipBody))
	advance(0.2)
	check(state.cash > before, "touching the register collects its cash")
	check(state.goalsDone.dorm_collect == true, "the collect goal is done")
	check(findDescendant(gui("Hud"), function(d)
		return d.Name == "Float" and string.sub(d.Text, 1, 2) == "+$"
	end) ~= nil, "the HUD floats the collected cash")

	print("== a drop press at the decks")
	do
		local blockout = Blockouts.dorm
		filipBody:PivotTo(PlotSpace.origin(plot) * CFrame.new(blockout.decks.stand + Vector3.new(0, 3, 0)))
		local drops = Music.drops(plot)
		check(#drops > 0, "the mix has drops planned")
		local drop = drops[1]
		if drop then
			clock = drop.time - EPOCH + 0.05 -- the press arrives just after the drop
			local mark = #sent
			local press = game:GetService("ReplicatedStorage") -- the remotes folder is a real instance
			local remotes = dataModel:GetService("ReplicatedStorage"):FindFirstChild("Remotes")

			check(remotes ~= nil, "the server made its remotes")
			if remotes then
				remotes.DropPress.OnServerEvent:Fire(filip, drop.time + 0.01)
				advance(0.1)
				local results = sentSince(mark, "DropResult")
				check(#results == 1 and results[1].args[1] == "perfect", "a press on the drop is Perfect")
				check(state.boost ~= nil and state.boost.multiplier == 2, "a Perfect press doubles income")
				check(state.goalsDone.dorm_drop == true, "the drop goal is done")
			end
			_ = press
		end
		filipBody:PivotTo(plot.Spawn.CFrame * CFrame.new(0, 3, 0))
	end

	local remotes = dataModel:GetService("ReplicatedStorage"):FindFirstChild("Remotes")

	print("== the decks, the track shop and the board on the client")
	do
		local blockout = Blockouts.dorm
		local stand = PlotSpace.origin(plot) * CFrame.new(blockout.decks.stand + Vector3.new(0, 3, 0))
		filipBody:PivotTo(stand)
		local prompt = findDescendant(plot.Items, function(d)
			return d.Name == "DecksPrompt"
		end)
		if check(prompt ~= nil, "the decks have the client's Play prompt") then
			prompt.Triggered:Fire(filip)
			advance(0.3)
			check(
				clientCamera.CameraType == roblox.Enum.CameraType.Scriptable,
				"Play moves the camera to the decks shot"
			)
			local decksGui = gui("Decks")
			check(decksGui ~= nil and decksGui.Enabled, "the decks UI shows")
			local nextDrop = nil
			for _, drop in Music.drops(plot) do
				if drop.time > serverNow() + 0.5 then
					nextDrop = drop
					break
				end
			end
			if nextDrop and decksGui then
				advance(nextDrop.time - serverNow(), 0.25)
				local mark = #sent
				local main = findDescendant(decksGui, function(d)
					return d.Name == "Main" and d:IsA("GuiButton")
				end)
				-- The press itself can't be followed here: the client's decks find their plot by another path
				-- than PlotMixes does, and Lune gives each path its own userdata (Roblox gives one object).
				check(#signalOf(main, "Activated").handlers == 1, "the main button is wired to the press")
				main.Activated:Fire()
				advance(0.3)
				_ = mark
				local tracks = findDescendant(decksGui, function(d)
					return d.Name == "Tracks" and d:IsA("GuiButton")
				end)
				tracks.Activated:Fire()
				advance(0.3)
				check(gui("TrackShop").Enabled, "the Tracks button opens the shop")
				local wanted = nil
				for _, track in shared("Config.Tracks") do
					if not state.ownedTracks[track.id] then
						wanted = track
						break
					end
				end
				if wanted then
					PlayerState.setCash(state, state.cash + wanted.price)
					advance(0.2)
					local row = findDescendant(gui("TrackShop"), function(d)
						return d.Name == wanted.id
					end)
					local buy = row and row:FindFirstChild("Buy")
					if check(buy ~= nil, "the shop lists " .. wanted.id) then
						buy.Activated:Fire()
						advance(0.5)
						check(state.ownedTracks[wanted.id] == true, "the shop's Buy button buys " .. wanted.id)
					end
				end
				local leaveButton = findDescendant(decksGui, function(d)
					return d.Name == "Leave" and d:IsA("GuiButton")
				end)
				leaveButton.Activated:Fire()
				advance(0.3)
				check(clientCamera.CameraType ~= roblox.Enum.CameraType.Scriptable, "Leave gives the camera back")
			end
		end
		filipBody:PivotTo(plot.Spawn.CFrame * CFrame.new(0, 3, 0))
	end

	-- Buys everything at the current location with plenty of cash.
	local function buyAll()
		PlayerState.setCash(state, 1e15)
		for _, item in Items[state.locationId] do
			if not state.bought[item.id] then
				advance(0.4)
				local ok = Shop.buy(state, item.id)
				check(ok, "buys " .. item.id)
			end
		end
		advance(0.5)
	end

	for index, location in Locations do
		print("== " .. location.id)
		check(state.locationId == location.id, "at " .. location.id)
		buyAll()
		check(Unlocks.isComplete(location.id, state.bought), location.id .. " is complete")
		local blockout = Blockouts[location.id]
		for _, item in Items[location.id] do
			local model = plot.Items:FindFirstChild(item.id)
			local replacedLater = false
			for _, other in Items[location.id] do
				replacedLater = replacedLater or other.replaces == item.id
			end
			check((model ~= nil) ~= replacedLater, "item " .. item.id .. " is shown (or replaced)")
		end
		check(plot:GetAttribute("Guests") == location.guests.max, location.id .. " shows its full crowd")
		advance(3)
		if location.id == "ibiza" then
			local wallGui = findDescendant(plot.Items, function(d)
				return d.Name == "LedWall" and d:IsA("SurfaceGui")
			end)
			check(wallGui ~= nil and #wallGui:GetChildren() > 10, "the LED wall shows its level bars")
		end
		local shown = #workspace.LocalGuests:GetChildren()
		check(shown == math.min(location.guests.max, 40), location.id .. " draws " .. shown .. " guests")
		local header = label("Goals", "Header")
		check(
			header ~= nil
				and (
					string.find(header, shared("Config.Goals")[location.id].name) ~= nil
					or header == "All done, nice!"
				),
			"the tracker shows " .. location.id .. "'s host: " .. tostring(header)
		)
		for _, item in Items[location.id] do
			if item.feature == "register" then
				check(PlayerState.hasFeature(state, "register"), "the bigger register counts as bought")
			end
			local specs = Blockouts[location.id].items[item.id] or {}
			for _, spec in specs do
				if spec.fx then
					check(findDescendant(plot.Items, function(d)
						return d:GetAttribute("Fx") == spec.fx
					end) ~= nil, item.id .. " carries its " .. spec.fx .. " payoff")
					break
				end
			end
			for _, spec in specs do
				if spec.beam then
					check(findDescendant(plot.Items, function(d)
						return d:IsA("Beam")
					end) ~= nil, item.id .. " has its light beam")
					break
				end
			end
		end
		_ = blockout

		-- Star DJ at the house party (its booking board is bought now).
		if location.id == "house" then
			print("== book a star DJ")
			local board = findDescendant(plot.Items, function(d)
				return d.Name == "BookPrompt"
			end)
			if board then
				triggerPrompt(board, filip)
				advance(0.3)
				check(gui("DjBoard").Enabled == true, "the booking board opens on the client")
			end
			local cash = state.cash
			local mark = #sent
			local kikoRow = findDescendant(gui("DjBoard"), function(d)
				return d.Name == "dj_kiko"
			end)
			local bookButton = kikoRow and kikoRow:FindFirstChild("Book")
			if check(bookButton ~= nil, "the board lists Kiko with a Book button") then
				bookButton.Activated:Fire()
				local last = toServer[#toServer]
				check(
					last ~= nil and last.remote == "BookDj" and last.args[1] == "dj_kiko",
					"the Book button asks the server for Kiko"
				)
			end
			advance(0.2)
			check(state.starDj ~= nil and state.starDj.djId == "dj_kiko", "Kiko is booked")
			check(plot:GetAttribute("StarDj") == "dj_kiko", "the plot shows Kiko's set")
			local goalReward = shared("Config.Goals").house.goals[2].reward -- the booking goal pays out at once
			check(cash - state.cash == 15000 - goalReward, "booking Kiko costs $15K (less Lena's reward)")
			check(state.goalsDone.house_book == true, "Lena's booking goal is done")
			advance(0.5)
			check(
				workspace:FindFirstChild("LocalStarDjs") and #workspace.LocalStarDjs:GetChildren() == 1,
				"Kiko's figure is at the decks"
			)
			check(gui("DjBoard").Enabled == false, "the board closes once booked")
			check(label("Hud", "Text") ~= nil, "the HUD has its banners")
			check(findDescendant(plot.Items, function(d)
				return d.Name == "BookPrompt"
			end) ~= nil, "the booking board has its prompt")
			local income = state.income
			check(income >= state.baseIncome * 3 - 1e-6, "a set triples income")
			advance(1)
			mark = #sent
			remotes.BookDj.OnServerEvent:Fire(filip, "dj_kiko")
			advance(1.2)
			local notices = sentSince(mark, "DjNotice")
			check(#notices == 1 and notices[1].args[1] == "refused", "a second booking during the set is refused")
			advance(181, 0.5)
			check(state.starDj == nil, "the set ends after 3 minutes")
			check(plot:GetAttribute("StarDj") == nil, "the plot's set attribute clears")
			local hits = 0
			for _, entry in sent do
				if entry.remote == "DropHit" and entry.player == "all" then
					hits += 1
				end
			end
			check(hits >= 1, "the star caught drops during the set (" .. hits .. " payoffs)")
			check(type(state.djRestUntil.dj_kiko) == "number", "Kiko rests after the set")
		end

		-- Each of the location's events.
		print("== events at " .. location.id)
		for _, kind in location.events do
			local entry = nil
			for attempt = 1, 12 do
				Events.soon(state)
				advance(1.2, 0.3)
				local vip = plot:FindFirstChild("VIP")
				local photo = plot:FindFirstChild("Photographer")
				local fix = findDescendant(plot.Items, function(d)
					return d.Name == "FixPrompt"
				end)
				local current = if vip then "vip" elseif photo then "photographer" elseif fix then "speaker" else nil
				if current == kind then
					entry = { vip = vip, photo = photo, fix = fix }
					break
				elseif current then
					-- Another kind came up: deal with it and try again.
					if vip then
						triggerPrompt(
							findDescendant(vip, function(d)
								return d:IsA("ProximityPrompt")
							end),
							filip
						)
					elseif fix then
						triggerPrompt(fix, filip)
					else
						advance(31, 1)
					end
					advance(0.5)
				end
				_ = attempt
			end
			if not check(entry ~= nil, "the " .. kind .. " event happens at " .. location.id) then
				continue
			end
			local cash = state.cash
			if kind == "speaker" then
				check(state.speakerBlown and plot:GetAttribute("SpeakerBlown") == true, "the speaker is blown")
				triggerPrompt(entry.fix, filip)
				advance(0.5)
				check(not state.speakerBlown, "fixing it brings the speaker back")
			elseif kind == "vip" then
				local prompt = findDescendant(entry.vip, function(d)
					return d:IsA("ProximityPrompt")
				end)
				triggerPrompt(prompt, filip)
				advance(0.5)
				check(plot:FindFirstChild("VIP") == nil, "the VIP goes once greeted")
			else
				-- Catch a drop while the photographer waits.
				local drops = Music.drops(plot)
				local nextDrop = nil
				for _, drop in drops do
					if drop.time > serverNow() then
						nextDrop = drop
						break
					end
				end
				if not nextDrop then
					advance(31, 1)
					check(plot:FindFirstChild("Photographer") == nil, "the photographer gives up without a drop")
				else
					local stand = PlotSpace.origin(plot)
						* CFrame.new(Blockouts[location.id].decks.stand + Vector3.new(0, 3, 0))
					filipBody:PivotTo(stand)
					local wait = nextDrop.time - serverNow()
					if wait < 29 then
						advance(wait, 0.5)
						remotes.DropPress.OnServerEvent:Fire(filip, nextDrop.time)
						advance(1)
						check(plot:FindFirstChild("Photographer") == nil, "the photographer leaves after the shot")
					else
						advance(31, 1)
						check(plot:FindFirstChild("Photographer") == nil, "the photographer gives up after 30 s")
					end
					filipBody:PivotTo(plot.Spawn.CFrame * CFrame.new(0, 3, 0))
				end
			end
			check(state.cash >= cash, "the " .. kind .. " event never costs cash")
		end

		-- Move on.
		local nextLocation = Locations[index + 1]
		local movePad = plot.Pads:FindFirstChild("Pad_MoveOn")
		if not nextLocation then
			check(movePad == nil, "no Move On after the last location")
			break
		end
		if not check(movePad ~= nil, "the Move On pad shows at " .. location.id) then
			break
		end
		print("== move on to " .. nextLocation.id)
		advance(1)
		local guideNow = playerGui:FindFirstChild("Guide")
		check(guideNow.Adornee ~= nil and guideNow.Adornee.Name == "Pad_MoveOn", "the guide points at Move On")
		movePad.Touched:Fire(rootOf(filipBody))
		advance(0.3)
		local fades = sentSince(#sent - 4, "Travel")
		check(#fades >= 1 and fades[1].args[1] == "out", "the screen fades out for moving on")
		settle(1.2)
		check(state.locationId == nextLocation.id, "moved on to " .. nextLocation.id)
		check(plot:GetAttribute("LocationId") == nextLocation.id, "the plot shows " .. nextLocation.id)
		check(next(state.bought) == nil, "nothing is bought at the new location yet")
		check(#plot.Items:GetChildren() == 0, "the old items are gone")
		check(#plot.Pads:GetChildren() == 3, "the new location's buttons show")
		local away = nextLocation.space == "venue"
		check(PlotSpace.away(plot) == away, "the plot is " .. (if away then "away at its venue" else "on the street"))
		check(
			(rootOf(filipBody).Position - plot.Spawn.CFrame.Position).Magnitude < 6,
			"the owner lands on the new spawn"
		)
		check(
			(plot.Spawn.CFrame.Position - PlotSpace.origin(plot).Position).Magnitude < 80,
			"the spawn is at the new location"
		)
		check(
			(plot.Register.CFrame.Position - PlotSpace.origin(plot).Position).Magnitude < 80,
			"the register is at the new location"
		)
		if away then
			check(#plot.Showcase:GetChildren() > 0, "the street keeps the last club as a showcase")
			advance(1)
			check(
				math.abs(dataModel:GetService("Lighting").ClockTime - 17.9) < 0.01,
				"the sky turns to sunset at the venue"
			)
		end
		local cover = gui("Fade") and gui("Fade"):FindFirstChild("Cover")
		check(cover ~= nil, "the fade cover exists")
		advance(3)
		local intro = shared("Config.Goals")[nextLocation.id].lines.intro
		local hello = false
		for _, entry in sent do
			hello = hello or (entry.remote == "Say" and entry.args[2] == intro)
		end
		check(hello, nextLocation.id .. "'s host says hello")
		check(saveCalls > 0, "moving on saves")
	end

	print("== the jet")
	do
		local gate = findDescendant(workspace, function(d)
			return d.Name == "TravelPrompt" and d.Parent and d.Parent.Name == "GatePrompt"
		end)
		local jet = findDescendant(plot.Shell, function(d)
			return d.Name == "TravelPrompt"
		end)
		check(gate ~= nil and jet ~= nil, "both jet prompts exist")
		if gate and jet then
			triggerPrompt(jet, filip)
			settle(1.2)
			check(
				PlotSpace.distance(plot, rootOf(filipBody).Position) > 100,
				"the venue's jet flies back to the street"
			)
			advance(1)
			check(dataModel:GetService("Lighting").ClockTime == 0, "the night comes back on the street")
			check(
				(rootOf(filipBody).Position - plot:GetPivot().Position).Magnitude < 60,
				"landing in front of the plot"
			)
			triggerPrompt(gate, filip)
			settle(1.2)
			check(PlotSpace.contains(plot, rootOf(filipBody).Position), "the gate flies the owner back to the venue")
		end
	end

	print("== a second player")
	do
		local guest, guestBody = join("Guest", 2002)
		local other = PlayerState.get(guest)
		check(other ~= nil and other.plot ~= plot, "the second player gets the other plot")
		if other then
			local gate = findDescendant(workspace, function(d)
				return d.Name == "TravelPrompt" and d.Parent and d.Parent.Name == "GatePrompt"
			end)
			local mark = #sent
			triggerPrompt(gate, guest)
			settle(1.2)
			local lines = sentSince(mark, "Say")
			check(#lines == 1, "the locked jet gets a line from the host")
			check(not PlotSpace.contains(plot, rootOf(guestBody).Position), "the guest doesn't fly to Filip's venue")
			Shop.buy(other, "dorm_laptop")
		end
		advance(6, 0.5) -- the leaderboard refreshes every 5 s
		local board = findDescendant(workspace, function(d)
			return d.Name == "Leaderboard"
		end)
		local firstName = if board
			then findDescendant(board, function(d)
				return d:IsA("TextLabel") and d.Text == "Filip"
			end)
			else nil
		check(firstName ~= nil, "the leaderboard lists Filip")
		local stats = filip:FindFirstChild("leaderstats")
		local earned = stats and stats:FindFirstChild("Earned")
		check(
			earned ~= nil and earned.Value == math.floor(state.totalEarned),
			"the player list shows what Filip earned"
		)
		leave(guest)
	end

	print("== settings")
	remotes.SetSettings.OnServerEvent:Fire(filip, 0.5, 0.8, 2)
	advance(0.3)
	check(state.settings.masterVolume == 0.5 and state.settings.sfxVolume == 1, "settings are saved, cleaned")

	print("== leave and rejoin")
	local cashBefore, boughtBefore = state.cash, 0
	for _ in state.bought do
		boughtBefore += 1
	end
	leave(filip)
	check(plot:GetAttribute("OwnerUserId") == nil, "leaving frees the plot")
	check(not PlotSpace.away(plot), "the plot comes back from the venue")
	check(#plot.Items:GetChildren() == 0 and #plot.Showcase:GetChildren() == 0, "the plot is cleared")
	check(saves[1001] ~= nil and saves[1001].location == "ibiza", "the save has Ibiza")
	local again, againBody = join("Filip", 1001)
	local back = PlayerState.get(again)
	check(back ~= nil and back.locationId == "ibiza", "rejoining comes back to Ibiza")
	if back then
		local count = 0
		for _ in back.bought do
			count += 1
		end
		check(count == boughtBefore, "every item comes back")
		check(math.abs(back.cash - cashBefore) < 1, "the cash comes back")
		check(PlotSpace.away(back.plot), "the plot is at its venue again")
		advance(1)
		check(PlotSpace.contains(back.plot, rootOf(againBody).Position), "the character is put at the venue")
		check(back.settings.musicVolume == 0.8, "the settings come back")
	end
end)
if not okSession then
	report("session", sessionError)
end
finishRun()
