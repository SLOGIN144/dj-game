--!strict
-- The location's host character (Config/Goals): their goals, rewards and lines. Goals listen to
-- what the other services report (collecting, buying, catching a drop, fixing the speaker, buying a
-- track), finish once each and pay their reward. The host's lines go to the player through "Say":
-- the intro for a new player, one per goal, the event lines, and "more is coming" after the
-- location's last button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Decks = require(script.Parent.Decks)
local Economy = require(script.Parent.Economy)
local Events = require(script.Parent.Events)
local GoalCheck = require(ReplicatedStorage.Shared.Economy.GoalCheck)
local GoalsConfig = require(ReplicatedStorage.Shared.Config.Goals)
local PlayerState = require(script.Parent.PlayerState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(script.Parent.Shop)
local TrackShop = require(script.Parent.TrackShop)

local Goals = {}

local INTRO_DELAY = 2 -- seconds after getting a plot before the host says hello

local function say(state: PlayerState.State, text: string)
	Remotes.event("Say"):FireClient(state.player, state.locationId, text)
end

local function happen(state: PlayerState.State, happening: GoalCheck.Happening)
	if not PlayerState.get(state.player) then
		return -- they left
	end
	local host = GoalsConfig[state.locationId]
	if not host then
		return
	end
	for _, goal in GoalCheck.finished(host, state.goalsDone, happening) do
		state.goalsDone[goal.id] = true
		PlayerState.mirror(state)
		Economy.reward(state, goal.reward)
		Remotes.event("GoalDone"):FireClient(state.player, goal.id, goal.reward)
		say(state, goal.line)
	end
end

-- Runs once a player has a plot: items they already own count for their goals, and a new
-- player gets the host's hello.
function Goals.begin(state: PlayerState.State)
	for itemId in state.bought do
		happen(state, { kind = "buy", itemId = itemId })
	end
	local host = GoalsConfig[state.locationId]
	if host and next(state.bought) == nil then
		task.delay(INTRO_DELAY, function()
			if PlayerState.get(state.player) == state then
				say(state, host.lines.intro)
			end
		end)
	end
end

function Goals.start()
	Economy.collected:connect(function(state: PlayerState.State)
		happen(state, { kind = "collect" })
	end)
	Shop.bought:connect(function(state: PlayerState.State, itemId: string)
		happen(state, { kind = "buy", itemId = itemId })
	end)
	Shop.completed:connect(function(state: PlayerState.State)
		local host = GoalsConfig[state.locationId]
		if host then
			say(state, host.lines.done)
		end
	end)
	Decks.caught:connect(function(state: PlayerState.State)
		happen(state, { kind = "drop" })
	end)
	Events.started:connect(function(state: PlayerState.State)
		local host = GoalsConfig[state.locationId]
		if host then
			say(state, host.lines.speakerBlown)
		end
	end)
	Events.fixed:connect(function(state: PlayerState.State)
		happen(state, { kind = "fix" })
		local host = GoalsConfig[state.locationId]
		if host then
			say(state, host.lines.speakerFixed)
		end
	end)
	TrackShop.bought:connect(function(state: PlayerState.State)
		happen(state, { kind = "tracks", tracksOwned = TrackShop.owned(state) })
	end)
end

return Goals
