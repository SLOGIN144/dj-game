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

-- Fades the player's screen to `text`, runs `prepare` while it's dark (it returns where the
-- character goes, or nil to stay put), moves the character there and fades back in. Yields.
-- Returns false if the player is already on their way somewhere.
function Travel.move(player: Player, text: string, prepare: () -> CFrame?): boolean
	if busy[player] then
		return false
	end
	busy[player] = true
	local remote = Remotes.event("Travel")
	remote:FireClient(player, "out", text)
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

local function onPrompt(prompt: ProximityPrompt, player: Player)
	local where = prompt:GetAttribute("Travel")
	local state = PlayerState.get(player)
	if typeof(where) ~= "string" or not state then
		return
	end
	if where == "venue" then
		if not PlotSpace.away(state.plot) then
			Travel.locked:fire(state)
			return
		end
		local location = PlotSpace.location(state.locationId)
		local name = if location then location.name else "the venue"
		task.spawn(Travel.move, player, "Flying to " .. name .. "...", function()
			return Travel.spawnFrame(state.plot)
		end)
	elseif where == "street" and prompt:GetAttribute("OwnerUserId") == player.UserId then
		task.spawn(Travel.move, player, "Flying back to the city...", function()
			return Travel.streetFrame(state.plot)
		end)
	end
end

function Travel.start()
	ProximityPromptService.PromptTriggered:Connect(onPrompt)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return Travel
