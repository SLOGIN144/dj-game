--!strict
-- Each player's game state while they're in the server. The server owns every cash value; Cash,
-- Income, owned tracks and finished goals are mirrored as Player attributes so the client can
-- show them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Crowd = require(ReplicatedStorage.Shared.Economy.Crowd)
local Income = require(ReplicatedStorage.Shared.Economy.Income)

-- A drop boost: its income multiplier until `endsAt` (server time).
export type Boost = { multiplier: number, endsAt: number }

-- Counters kept for goals and, later, the save file.
export type Stats = { perfectDrops: number, goodDrops: number, eventsDone: number, playSeconds: number }

export type State = {
	player: Player,
	plot: Model,
	cash: number,
	locationId: string,
	bought: { [string]: boolean }, -- item ids bought at the current location
	ownedTracks: { [string]: boolean }, -- track ids in the plot's mix
	register: number, -- cash waiting in the plot's register
	baseIncome: number, -- cash per second from the bought items alone
	income: number, -- cash per second with every bonus, what the register fills with
	boost: Boost?,
	speakerBlown: boolean,
	goalsDone: { [string]: boolean }, -- the host character's goals finished
	stats: Stats,
}

local PlayerState = {}

local states: { [Player]: State } = {}

function PlayerState.create(player: Player, plot: Model): State
	local state: State = {
		player = player,
		plot = plot,
		cash = Balance.Start.cash,
		locationId = Balance.Start.locationId,
		bought = {},
		ownedTracks = {},
		register = 0,
		baseIncome = 0,
		income = 0,
		boost = nil,
		speakerBlown = false,
		goalsDone = {},
		stats = { perfectDrops = 0, goodDrops = 0, eventsDone = 0, playSeconds = 0 },
	}
	for _, trackId in Balance.Start.tracks do
		state.ownedTracks[trackId] = true
	end
	states[player] = state
	PlayerState.setCash(state, state.cash)
	PlayerState.updateIncome(state)
	PlayerState.mirror(state)
	return state
end

function PlayerState.get(player: Player): State?
	return states[player]
end

-- Every player with a plot, keyed by player.
function PlayerState.all(): { [Player]: State }
	return states
end

function PlayerState.remove(player: Player)
	states[player] = nil
end

function PlayerState.setCash(state: State, value: number)
	state.cash = value
	state.player:SetAttribute("Cash", value)
end

function PlayerState.setIncome(state: State, value: number)
	state.income = value
	state.player:SetAttribute("Income", value)
end

local function ids(set: { [string]: boolean }): string
	local list = {}
	for id in set do
		table.insert(list, id)
	end
	table.sort(list)
	return table.concat(list, ",")
end

-- Mirrors the owned tracks and finished goals as Player attributes (comma-separated ids) for the
-- track shop and the goal tracker.
function PlayerState.mirror(state: State)
	state.player:SetAttribute("OwnedTracks", ids(state.ownedTracks))
	state.player:SetAttribute("GoalsDone", ids(state.goalsDone))
end

-- Tracks the player bought in the shop (the starter tracks don't count for the bonus).
function PlayerState.tracksBought(state: State): number
	local count = 0
	for trackId in state.ownedTracks do
		if not table.find(Balance.Start.tracks, trackId) then
			count += 1
		end
	end
	return count
end

-- Recomputes the plot's income from what it has built and what's going on, and its guest count.
function PlayerState.updateIncome(state: State)
	state.baseIncome = Income.perSecond(state.locationId, state.bought)
	PlayerState.setIncome(
		state,
		Income.total(state.baseIncome, {
			tracksBought = PlayerState.tracksBought(state),
			boost = if state.boost then state.boost.multiplier else 1,
			speakerBlown = state.speakerBlown,
		})
	)
	state.plot:SetAttribute("Guests", Crowd.count(state.locationId, state.baseIncome))
end

return PlayerState
