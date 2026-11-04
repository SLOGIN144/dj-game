--!strict
-- Builds the street, loads each joining player's club (Services/PlayerData), gives them a free
-- plot with everything they had bought, and spawns them on it. When they leave, their club is
-- saved and the plot is cleared.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Config.Items)
local PlayerData = require(script.Parent.PlayerData)
local PlayerState = require(script.Parent.PlayerState)
local PlotView = require(script.Parent.Parent.World.PlotView)
local Street = require(script.Parent.Parent.World.Street)
local Travel = require(script.Parent.Travel)
local Types = require(ReplicatedStorage.Shared.Types)

local Plots = {}

local LOCKED_MESSAGE = "Your club is still being saved on another server. Please rejoin in a minute."
local FAILED_MESSAGE = "We couldn't load your club right now. Please rejoin in a minute."

local plots: { Model } = {}

local function freePlot(): Model?
	for _, plot in plots do
		if plot:GetAttribute("OwnerUserId") == nil then
			return plot
		end
	end
	return nil
end

local function assign(player: Player, onAssigned: (PlayerState.State) -> ())
	local saved, result = PlayerData.load(player)
	if result == "locked" then
		player:Kick(LOCKED_MESSAGE)
		return
	elseif result == "failed" then
		player:Kick(FAILED_MESSAGE)
		return
	end
	if not player.Parent then
		PlayerData.save(player.UserId, saved, true) -- they left while it loaded: let go of the club
		return
	end

	local plot = freePlot()
	if not plot then
		warn(string.format("[Plots] no free plot for %s", player.Name))
		PlayerData.save(player.UserId, saved, true)
		return
	end

	PlotView.setOwner(plot, player)
	player:SetAttribute("PlotIndex", plot:GetAttribute("PlotIndex"))
	player.RespawnLocation = PlotView.spawn(plot)

	local state = PlayerState.create(player, plot, saved)
	PlotView.setLocation(plot, state.locationId)
	-- Rebuild what they had bought, in unlock order, without the pop-in.
	local items: { Types.Item } = Items[state.locationId] or {}
	for _, item in items do
		if state.bought[item.id] then
			PlotView.showItem(plot, state.locationId, item.id, false)
		end
	end
	onAssigned(state)

	-- A character that already spawned somewhere else is moved to their location.
	if player.Character then
		task.spawn(Travel.place, player, Travel.spawnFrame(plot))
	end
end

local function release(player: Player, onReleased: (PlayerState.State) -> ())
	local state = PlayerState.get(player)
	if not state then
		return
	end
	local snapshot = PlayerState.snapshot(state)
	task.spawn(PlayerData.save, player.UserId, snapshot, true)
	onReleased(state)
	PlotView.clear(state.plot)
	PlotView.setOwner(state.plot, nil)
	PlayerState.remove(player)
end

-- Builds the street and the empty plots. Call once, before `start`.
function Plots.build(): { Model }
	plots = Street.build()
	for _, plot in plots do
		PlotView.setup(plot)
	end
	return plots
end

-- Starts handing out plots; `onAssigned` runs once a player owns a plot, `onReleased` just before
-- their plot is cleared. Also starts saving every owner's club.
function Plots.start(onAssigned: (PlayerState.State) -> (), onReleased: (PlayerState.State) -> ())
	PlayerData.start(function()
		local snapshots = {}
		for player, state in PlayerState.all() do
			snapshots[player.UserId] = PlayerState.snapshot(state)
		end
		return snapshots
	end)
	Players.PlayerAdded:Connect(function(player)
		assign(player, onAssigned)
	end)
	Players.PlayerRemoving:Connect(function(player)
		release(player, onReleased)
	end)
	for _, player in Players:GetPlayers() do
		if not PlayerState.get(player) then
			task.spawn(assign, player, onAssigned)
		end
	end
end

return Plots
