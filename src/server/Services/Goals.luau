--!strict
-- The location's host character (Config/Goals): their goals, rewards and lines. Goals listen to
-- what the other services report (collecting, buying, catching a drop, fixing the speaker,
-- greeting a VIP, buying a track, booking a star DJ), count up where they need to, finish once
-- each and pay their reward. The host's lines go to the player through "Say": the intro when
-- they arrive at a location, one per goal, the event lines, and one after the location's last
-- button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Decks = require(script.Parent.Decks)
local Economy = require(script.Parent.Economy)
local Events = require(script.Parent.Events)
local GoalCheck = require(ReplicatedStorage.Shared.Economy.GoalCheck)
local GoalsConfig = require(ReplicatedStorage.Shared.Config.Goals)
local PlayerState = require(script.Parent.PlayerState)
local Progression = require(script.Parent.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(script.Parent.Shop)
local StarDjs = require(script.Parent.StarDjs)
local TrackShop = require(script.Parent.TrackShop)
local Travel = require(script.Parent.Travel)

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
	local before = table.clone(state.goalProgress)
	local finished = GoalCheck.advance(host, state.goalsDone, state.goalProgress, happening)
	for _, goal in finished do
		state.goalsDone[goal.id] = true
		state.goalProgress[goal.id] = nil
		Economy.reward(state, goal.reward)
		Remotes.event("GoalDone"):FireClient(state.player, goal.id, goal.reward)
		say(state, goal.line)
	end
	local counted = false
	for goalId, count in state.goalProgress do
		counted = counted or before[goalId] ~= count
	end
	if #finished > 0 or counted then
		PlayerState.mirror(state)
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
	Decks.caught:connect(function(state: PlayerState.State, grade: string)
		happen(state, { kind = "drop" })
		if grade == "perfect" then
			happen(state, { kind = "perfect" })
		end
	end)
	Events.started:connect(function(state: PlayerState.State, kind: string)
		local host = GoalsConfig[state.locationId]
		local line = if not host
			then nil
			elseif kind == "speaker" then host.lines.speakerBlown
			elseif kind == "vip" then host.lines.vip
			else host.lines.photographer
		if line then
			say(state, line)
		end
	end)
	Events.fixed:connect(function(state: PlayerState.State, kind: string)
		local host = GoalsConfig[state.locationId]
		if kind == "speaker" then
			happen(state, { kind = "fix" })
			if host then
				say(state, host.lines.speakerFixed)
			end
		elseif kind == "vip" then
			happen(state, { kind = "vip" })
		end
	end)
	TrackShop.bought:connect(function(state: PlayerState.State)
		happen(state, { kind = "tracks", tracksOwned = TrackShop.owned(state) })
	end)
	Progression.moved:connect(function(state: PlayerState.State)
		-- The new host says hello, and tracks owned already count for their goals.
		Goals.begin(state)
		happen(state, { kind = "tracks", tracksOwned = TrackShop.owned(state) })
	end)
	StarDjs.booked:connect(function(state: PlayerState.State, djId: string)
		happen(state, { kind = "book", djId = djId })
	end)
	Travel.locked:connect(function(state: PlayerState.State)
		local host = GoalsConfig[state.locationId]
		if host and host.lines.jetLocked then
			say(state, host.lines.jetLocked)
		end
	end)
end

return Goals
