--!strict
-- Moving on (GDD: locations). Once every button of a location is bought, the Move On pad appears
-- (Services/Shop); stepping on it opens the next location: the building grows to its next stage,
-- the next room opens on the plot (or the venue opens, for Ibiza) and building starts again with
-- pricier parts that pay more. Cash, tracks, star DJs and finished goals carry over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
local PlayerState = require(script.Parent.PlayerState)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local PlotView = require(script.Parent.Parent.World.PlotView)
local Shop = require(script.Parent.Shop)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Travel = require(script.Parent.Travel)
local Unlocks = require(ReplicatedStorage.Shared.Economy.Unlocks)

local Progression = {}

-- Fires (state) just before a plot moves on, so events and guest sets can end, and
-- (state, fromLocationId) once it stands at its new location.
Progression.leaving = Signal.new()
Progression.moved = Signal.new()

local moving: { [Player]: boolean } = {}

-- Moves the owner's plot on to the next location, if this one is finished. Yields.
function Progression.moveOn(state: PlayerState.State)
	local player = state.player
	local fromId = state.locationId
	local nextId = Unlocks.nextLocation(fromId)
	local location = PlotSpace.location(nextId)
	if moving[player] or not nextId or not location or not Unlocks.isComplete(fromId, state.bought) then
		return
	end
	moving[player] = true
	local text = if location.space == "venue"
		then "Flying to " .. location.name .. "..."
		else "Moving on to the " .. location.name .. "..."
	Travel.move(player, text, function(): CFrame?
		if PlayerState.get(player) ~= state then
			return nil -- they left while the screen faded
		end
		Progression.leaving:fire(state)
		state.locationId = nextId
		state.bought = {}
		state.goalProgress = {}
		state.speakerBlown = false
		PlotView.setLocation(state.plot, nextId)
		PlayerState.updateIncome(state)
		PlayerState.mirror(state)
		Shop.refresh(state)
		Progression.moved:fire(state, fromId)
		task.spawn(PlayerData.save, player.UserId, PlayerState.snapshot(state), false)
		return Travel.spawnFrame(state.plot)
	end, if location.space == "venue" then "jet" else "moveOn")
	moving[player] = nil
end

function Progression.start()
	Shop.moveOnPressed:connect(function(state: PlayerState.State)
		task.spawn(Progression.moveOn, state)
	end)
end

return Progression
