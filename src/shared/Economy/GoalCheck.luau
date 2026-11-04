--!strict
-- Which of a host's goals something that just happened finishes (pure, so it's tested).

local Types = require(script.Parent.Parent.Types)

local GoalCheck = {}

-- What just happened: its kind, the item bought (for "buy") and how many tracks the player owns.
export type Happening = { kind: Types.GoalKind, itemId: string?, tracksOwned: number? }

function GoalCheck.finished(host: Types.Host, done: { [string]: boolean }, happening: Happening): { Types.Goal }
	local finished = {}
	for _, goal in host.goals do
		if done[goal.id] or goal.kind ~= happening.kind then
			continue
		end
		if goal.kind == "buy" and goal.target ~= happening.itemId then
			continue
		end
		if goal.kind == "tracks" and (happening.tracksOwned or 0) < (goal.count or 1) then
			continue
		end
		table.insert(finished, goal)
	end
	return finished
end

function GoalCheck.allDone(host: Types.Host, done: { [string]: boolean }): boolean
	for _, goal in host.goals do
		if not done[goal.id] then
			return false
		end
	end
	return true
end

return GoalCheck
