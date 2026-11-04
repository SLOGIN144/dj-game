--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GoalCheck = require(Shared.Economy.GoalCheck)
local Goals = require(Shared.Config.Goals)
local Items = require(Shared.Config.Items)
local Locations = require(Shared.Config.Locations)
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
		T.equal(ids(GoalCheck.finished(DORM, {}, { kind = "collect" })), "dorm_collect")
	end,

	["buying only counts for the goal's own item"] = function()
		T.equal(ids(GoalCheck.finished(DORM, {}, { kind = "buy", itemId = "dorm_lamp" })), "")
		T.equal(ids(GoalCheck.finished(DORM, {}, { kind = "buy", itemId = "dorm_speaker" })), "dorm_speaker")
	end,

	["catching a drop finishes the drop goal"] = function()
		T.equal(ids(GoalCheck.finished(DORM, {}, { kind = "drop" })), "dorm_drop")
	end,

	["a finished goal never pays twice"] = function()
		T.equal(ids(GoalCheck.finished(DORM, { dorm_collect = true }, { kind = "collect" })), "")
	end,

	["the dorm is done once all of Max's goals are"] = function()
		T.equal(GoalCheck.allDone(DORM, { dorm_collect = true, dorm_speaker = true }), false)
		T.equal(GoalCheck.allDone(DORM, { dorm_collect = true, dorm_speaker = true, dorm_drop = true }), true)
	end,
}
