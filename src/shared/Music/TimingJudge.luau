--!strict
-- Grades a timed press: how far it was from its target beat, in seconds.

local Balance = require(script.Parent.Parent.Config.Balance)

local TimingJudge = {}

export type Grade = "perfect" | "good" | "miss"

-- `errorSeconds` is press time minus target time (negative = early).
function TimingJudge.grade(errorSeconds: number): Grade
	local off = math.abs(errorSeconds - Balance.Timing.latencyOffset)
	if off <= Balance.Timing.perfectWindow then
		return "perfect"
	elseif off <= Balance.Timing.goodWindow then
		return "good"
	end
	return "miss"
end

-- True once a target is so far in the past that no press can still count.
function TimingJudge.isExpired(secondsSinceTarget: number): boolean
	return secondsSinceTarget - Balance.Timing.latencyOffset > Balance.Timing.goodWindow
end

return TimingJudge
