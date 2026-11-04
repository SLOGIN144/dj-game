--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GoalCheck = require(Shared.Economy.GoalCheck)
local Goals = require(Shared.Config.Goals)
local Items = require(Shared.Config.Items)
local Locations = require(Shared.Config.Locations)
local StarDjs = require(Shared.Config.StarDjs)
local T = require(script.Parent.TestUtil)

local DORM = Goals.dorm

local function ids(goals: { any }): string
	local list = {}
	for _, goal in goals do
		table.insert(list, goal.id)
	end
	return table.concat(list, ",")
end

return {
	["every location has a host with goals that make sense"] = function()
		local seen = {}
		for _, location in Locations do
			local host = Goals[location.id]
			T.truthy(host, "a host for " .. location.id)
			T.truthy(#host.goals >= 3 and #host.goals <= 5, "3-5 goals")
			for _, goal in host.goals do
				T.truthy(not seen[goal.id], "unique id " .. goal.id)
				seen[goal.id] = true
				T.truthy(goal.reward > 0, "a reward")
				T.truthy(#goal.line > 0 and #goal.text > 0, "text and a line")
				if goal.kind == "book" and goal.target then
					local found = false
					for _, dj in StarDjs do
						found = found or dj.id == goal.target
					end
					T.truthy(found, "book goal targets a real DJ: " .. goal.target)
				end
				if goal.kind == "buy" then
					local found = false
					for _, item in Items[location.id] do
						found = found or item.id == goal.target
					end
					T.truthy(found, "buy goal targets a real item: " .. tostring(goal.target))
				end
			end
		end
	end,

	["collecting finishes the collect goal"] = function()
		T.equal(ids(GoalCheck.advance(DORM, {}, {}, { kind = "collect" })), "dorm_collect")
	end,

	["buying only counts for the goal's own item"] = function()
		T.equal(ids(GoalCheck.advance(DORM, {}, {}, { kind = "buy", itemId = "dorm_lamp" })), "")
		T.equal(ids(GoalCheck.advance(DORM, {}, {}, { kind = "buy", itemId = "dorm_speaker" })), "dorm_speaker")
	end,

	["catching a drop finishes the drop goal"] = function()
		T.equal(ids(GoalCheck.advance(DORM, {}, {}, { kind = "drop" })), "dorm_drop")
	end,

	["a finished goal never pays twice"] = function()
		T.equal(ids(GoalCheck.advance(DORM, { dorm_collect = true }, {}, { kind = "collect" })), "")
	end,

	["the dorm is done once all of Max's goals are"] = function()
		T.equal(GoalCheck.allDone(DORM, { dorm_collect = true, dorm_speaker = true }), false)
		T.equal(GoalCheck.allDone(DORM, { dorm_collect = true, dorm_speaker = true, dorm_drop = true }), true)
	end,

	["counted goals finish on their last count and show how far along they are"] = function()
		local progress = {}
		local perfect = Goals.house.goals[1]
		T.equal(perfect.id, "house_perfect")
		T.equal(ids(GoalCheck.advance(Goals.house, {}, progress, { kind = "perfect" })), "")
		T.equal(ids(GoalCheck.advance(Goals.house, {}, progress, { kind = "perfect" })), "")
		T.equal(GoalCheck.count(perfect, progress, 0), 2)
		T.equal(ids(GoalCheck.advance(Goals.house, {}, progress, { kind = "perfect" })), "house_perfect")
		T.equal(GoalCheck.count(perfect, progress, 0), 3)
	end,

	["owning tracks counts what the player owns, not purchases"] = function()
		local club = Goals.club
		T.equal(ids(GoalCheck.advance(club, {}, {}, { kind = "tracks", tracksOwned = 4 })), "")
		T.equal(ids(GoalCheck.advance(club, {}, {}, { kind = "tracks", tracksOwned = 5 })), "club_tracks")
		T.equal(GoalCheck.count(club.goals[2], {}, 7), 5, "never past the goal")
	end,

	["booking counts any DJ, or only the goal's own one"] = function()
		T.equal(ids(GoalCheck.advance(Goals.house, {}, {}, { kind = "book", djId = "dj_kiko" })), "house_book")
		T.equal(ids(GoalCheck.advance(Goals.ibiza, {}, {}, { kind = "book", djId = "dj_kiko" })), "")
		T.equal(ids(GoalCheck.advance(Goals.ibiza, {}, {}, { kind = "book", djId = "dj_mira" })), "ibiza_book")
	end,
}
