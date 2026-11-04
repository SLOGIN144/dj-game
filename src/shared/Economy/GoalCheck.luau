--!strict
-- Which of a host's goals something that just happened finishes (pure, so it's tested). Goals
-- that count up ("Catch 3 Perfect drops") keep their count in a progress table, by goal id; owning
-- tracks is counted from what the player owns, so it needs none.

local Types = require(script.Parent.Parent.Types)

local GoalCheck = {}

-- What just happened: its kind, the item bought ("buy"), the star DJ booked ("book") and how
-- many tracks the player owns ("tracks").
export type Happening = { kind: Types.GoalKind, itemId: string?, djId: string?, tracksOwned: number? }

-- How many times a goal has to happen (or how many tracks to own).
function GoalCheck.needed(goal: Types.Goal): number
	return math.max(1, goal.count or 1)
end

-- Whether `happening` is the kind of thing `goal` counts.
local function matches(goal: Types.Goal, happening: Happening): boolean
	if goal.kind ~= happening.kind then
		return false
	elseif goal.kind == "buy" then
		return goal.target == happening.itemId
	elseif goal.kind == "book" then
		return goal.target == nil or goal.target == happening.djId
	end
	return true
end

-- Counts `happening` towards the host's unfinished goals and returns the ones it finishes. Counted
-- goals move on in `progress` (changed in place); finished goals aren't marked done here.
function GoalCheck.advance(
	host: Types.Host,
	done: { [string]: boolean },
	progress: { [string]: number },
	happening: Happening
): { Types.Goal }
	local finished = {}
	for _, goal in host.goals do
		if done[goal.id] or not matches(goal, happening) then
			continue
		end
		local needed = GoalCheck.needed(goal)
		if goal.kind == "tracks" then
			if (happening.tracksOwned or 0) < needed then
				continue
			end
		elseif needed > 1 then
			local count = math.min(needed, (progress[goal.id] or 0) + 1)
			progress[goal.id] = count
			if count < needed then
				continue
			end
		end
		table.insert(finished, goal)
	end
	return finished
end

-- How far along a goal is, for the tracker ("1/3"): its count, or the tracks owned.
function GoalCheck.count(goal: Types.Goal, progress: { [string]: number }, tracksOwned: number): number
	if goal.kind == "tracks" then
		return math.min(tracksOwned, GoalCheck.needed(goal))
	end
	return progress[goal.id] or 0
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
