--!strict
-- Each player's game state while they're in the server. The server owns every cash value; Cash,
-- Income, owned tracks and finished goals are mirrored as Player attributes so the client can
-- show them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crowd = require(ReplicatedStorage.Shared.Economy.Crowd)
local Income = require(ReplicatedStorage.Shared.Economy.Income)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local SaveSchema = require(ReplicatedStorage.Shared.Data.SaveSchema)

-- A drop boost: its income multiplier until `endsAt` (server time).
export type Boost = { multiplier: number, endsAt: number }

-- Counters kept for goals and, later, the save file.
export type Stats = { perfectDrops: number, goodDrops: number, eventsDone: number, playSeconds: number }

export type State = {
	player: Player,
	plot: Model,
	cash: number,
	totalEarned: number, -- every bit of cash ever earned (for the leaderboard later)
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

-- The player's state on their plot, from their save (Data/SaveSchema; a new player's is the default).
function PlayerState.create(player: Player, plot: Model, saved: SaveSchema.SaveData): State
	local function set(ids: { string }): { [string]: boolean }
		local result = {}
		for _, id in ids do
			result[id] = true
		end
		return result
	end
	local state: State = {
		player = player,
		plot = plot,
		cash = saved.cash,
		totalEarned = saved.totalEarned,
		locationId = saved.location,
		bought = set(saved.boughtItems),
		ownedTracks = set(saved.ownedTracks),
		register = saved.register,
		baseIncome = 0,
		income = 0,
		boost = nil,
		speakerBlown = false,
		goalsDone = set(saved.goalsDone),
		stats = table.clone(saved.stats),
	}
	states[player] = state
	PlayerState.setCash(state, state.cash)
	PlayerState.updateIncome(state)
	PlayerState.mirror(state)
	return state
end

-- The state as a save file (Data/SaveSchema).
function PlayerState.snapshot(state: State): SaveSchema.SaveData
	local function list(set: { [string]: boolean }): { string }
		local ids = {}
		for id in set do
			table.insert(ids, id)
		end
		table.sort(ids)
		return ids
	end
	return {
		version = SaveSchema.VERSION,
		cash = state.cash,
		totalEarned = state.totalEarned,
		location = state.locationId,
		boughtItems = list(state.bought),
		ownedTracks = list(state.ownedTracks),
		goalsDone = list(state.goalsDone),
		register = state.register,
		stats = table.clone(state.stats),
	}
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

-- Adds earned cash (collected, goal rewards, tips), which also counts towards totalEarned.
function PlayerState.earn(state: State, amount: number)
	state.totalEarned += amount
	PlayerState.setCash(state, state.cash + amount)
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
