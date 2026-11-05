--!strict
-- Moving an owner's character between the street and their location (GDD: plots). The gate at
-- the end of the street flies an owner whose location is a venue (Ibiza) there, and the jet at the
-- venue flies them back; moving on also lands them at the new location. While the character
-- moves, their screen fades (client UI/Fade), so a room appearing or a jump far away isn't seen.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(script.Parent.PlayerState)
local PlotLayout = require(ReplicatedStorage.Shared.Config.PlotLayout)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Travel = {}

-- Fires (state) when someone without a venue asks the jet to fly them (their host says why).
Travel.locked = Signal.new()

local FADE_SECONDS = 0.7 -- the client's fade to dark; the character moves once it's dark
local STREAM_TIMEOUT = 6 -- seconds to wait for the destination to stream in, with streaming on

local busy: { [Player]: boolean } = {}

-- Where a character lands at the plot's location: on its spawn, facing the room.
function Travel.spawnFrame(plot: Model): CFrame
	local spawn = plot:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame * CFrame.new(0, 3.2, 0)
	end
	return PlotSpace.origin(plot) * CFrame.new(0, 4, 0)
end

-- Where a character lands on the street: in front of the plot, facing its building.
function Travel.streetFrame(plot: Model): CFrame
	return plot:GetPivot() * CFrame.new(PlotLayout.spawn + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, math.pi, 0)
end

-- Where a character lands inside the plot's current floor behind the door: its arrival spot, facing
-- the room.
function Travel.floorFrame(plot: Model): CFrame
	local layout = PlotSpace.layout(PlotSpace.locationId(plot))
	return PlotSpace.origin(plot) * CFrame.new(layout.spawn + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, math.pi, 0)
end

-- Where the owner lands after moving on: inside a floor behind the door, else on the plot's spawn.
function Travel.landingFrame(plot: Model): CFrame
	if PlotSpace.isDoor(PlotSpace.locationId(plot)) then
		return Travel.floorFrame(plot)
	end
	return Travel.spawnFrame(plot)
end

-- The plot with this index, if the street has it.
local function plotByIndex(index: unknown): Model?
	local street = workspace:FindFirstChild("Street")
	local plots = if street then street:FindFirstChild("Plots") else nil
	local plot = if plots and typeof(index) == "number" then plots:FindFirstChild("Plot" .. index) else nil
	return if plot and plot:IsA("Model") then plot else nil
end

-- Whether `player` stands within `range` studs of the prompt's part.
local function near(player: Player, prompt: ProximityPrompt, range: number): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local part = prompt.Parent
	if part and part:IsA("Attachment") then
		part = part.Parent
	end
	return root ~= nil
		and root:IsA("BasePart")
		and part ~= nil
		and part:IsA("BasePart")
		and (root.Position - part.Position).Magnitude <= range
end

-- Moves the player's character to `target` straight away, once the place has streamed in. Yields.
function Travel.place(player: Player, target: CFrame)
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, STREAM_TIMEOUT)
	end)
	local character = player.Character
	if character and player.Parent then
		character:PivotTo(target)
	end
end

-- Fades the player's screen to `text` with an optional `sound` (Config/Sounds), runs `prepare`
-- while it's dark (it returns where the character goes, or nil to stay put), moves the character
-- there and fades back in. Yields. Returns false if the player is already on their way somewhere.
function Travel.move(player: Player, text: string, prepare: () -> CFrame?, sound: string?): boolean
	if busy[player] then
		return false
	end
	busy[player] = true
	local remote = Remotes.event("Travel")
	remote:FireClient(player, "out", text, sound)
	task.wait(FADE_SECONDS)
	local ok, target = pcall(prepare)
	if not ok then
		warn("[Travel] " .. tostring(target))
		target = nil
	end
	if target and player.Parent then
		Travel.place(player, target)
	end
	if player.Parent then
		remote:FireClient(player, "in", text)
	end
	busy[player] = nil
	return true
end

-- Moves everyone but `except` who is inside the plot's floor out to the street in front of the
-- building, before the floor is cleared (the owner moves on or leaves). Yields until they're out.
function Travel.ejectVisitors(plot: Model, except: Player?)
	if not PlotSpace.away(plot) then
		return -- the room is on the plot itself: nobody is inside anything
	end
	local pending = 0
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if other ~= except and root and root:IsA("BasePart") and PlotSpace.contains(plot, root.Position) then
			pending += 1
			task.spawn(function()
				Travel.place(other, Travel.streetFrame(plot))
				pending -= 1
			end)
		end
	end
	local began = os.clock()
	while pending > 0 and os.clock() - began < STREAM_TIMEOUT + 2 do
		task.wait(0.1)
	end
end

-- The street door and a floor's exit door: anyone may use them while the plot has an owner whose
-- floor is behind the door.
local function onDoor(prompt: ProximityPrompt, player: Player): boolean
	local enter = prompt:GetAttribute("Enter")
	local exit = prompt:GetAttribute("Exit")
	if typeof(enter) ~= "number" and typeof(exit) ~= "number" then
		return false
	end
	local plot = plotByIndex(if typeof(enter) == "number" then enter else exit)
	if not plot or not near(player, prompt, 20) then
		return true
	end
	if typeof(enter) == "number" then
		local function open(): boolean
			return plot:GetAttribute("OwnerUserId") ~= nil and PlotSpace.isDoor(PlotSpace.locationId(plot))
		end
		if open() then
			task.spawn(Travel.move, player, "Going inside...", function()
				-- The owner may have left while the screen faded.
				return if open() then Travel.floorFrame(plot) else Travel.streetFrame(plot)
			end, "moveOn")
		end
	else
		task.spawn(Travel.move, player, "Back to the street...", function()
			return Travel.streetFrame(plot)
		end, "moveOn")
	end
	return true
end

local function onPrompt(prompt: ProximityPrompt, player: Player)
	if onDoor(prompt, player) then
		return
	end
	local where = prompt:GetAttribute("Travel")
	local state = PlayerState.get(player)
	if typeof(where) ~= "string" or not state then
		return
	end
	if where == "venue" then
		if not PlotSpace.jetAway(state.plot) then
			Travel.locked:fire(state)
			return
		end
		local location = PlotSpace.location(state.locationId)
		local name = if location then location.name else "the venue"
		task.spawn(Travel.move, player, "Flying to " .. name .. "...", function()
			return Travel.spawnFrame(state.plot)
		end, "jet")
	elseif where == "street" and prompt:GetAttribute("OwnerUserId") == player.UserId then
		task.spawn(Travel.move, player, "Flying back to the city...", function()
			return Travel.streetFrame(state.plot)
		end, "jet")
	end
end

function Travel.start()
	ProximityPromptService.PromptTriggered:Connect(onPrompt)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return Travel
