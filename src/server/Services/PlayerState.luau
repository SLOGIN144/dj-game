--!strict
-- Each player's game state while they're in the server. The server owns every cash value; Cash
-- and Income are mirrored as Player attributes so the client can show them. Nothing is saved yet
-- (saving is build step 7).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

export type State = {
	player: Player,
	plot: Model,
	cash: number,
	locationId: string,
	bought: { [string]: boolean }, -- item ids bought at the current location
	register: number, -- cash waiting in the plot's register
	income: number, -- cash per second
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
		register = 0,
		income = 0,
	}
	states[player] = state
	PlayerState.setCash(state, state.cash)
	PlayerState.setIncome(state, state.income)
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

return PlayerState
