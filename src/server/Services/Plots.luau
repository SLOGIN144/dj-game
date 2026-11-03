--!strict
-- Builds the street, gives each joining player a free plot and spawns them on it, and clears the
-- plot when they leave.

local Players = game:GetService("Players")

local PlayerState = require(script.Parent.PlayerState)
local PlotView = require(script.Parent.Parent.World.PlotView)
local Street = require(script.Parent.Parent.World.Street)

local Plots = {}

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
	local plot = freePlot()
	if not plot then
		warn(string.format("[Plots] no free plot for %s", player.Name))
		return
	end

	PlotView.setOwner(plot, player)
	player:SetAttribute("PlotIndex", plot:GetAttribute("PlotIndex"))
	local spawn = PlotView.spawn(plot)
	player.RespawnLocation = spawn

	local state = PlayerState.create(player, plot)
	PlotView.setShell(plot, state.locationId)
	onAssigned(state)

	-- A character that already spawned somewhere else is moved onto the plot.
	local character = player.Character
	if character then
		character:PivotTo(spawn.CFrame * CFrame.new(0, 4, 0))
	end
end

local function release(player: Player)
	local state = PlayerState.get(player)
	if not state then
		return
	end
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

-- Starts handing out plots; `onAssigned` runs once a player owns a plot.
function Plots.start(onAssigned: (PlayerState.State) -> ())
	Players.PlayerAdded:Connect(function(player)
		assign(player, onAssigned)
	end)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		if not PlayerState.get(player) then
			assign(player, onAssigned)
		end
	end
end

return Plots
