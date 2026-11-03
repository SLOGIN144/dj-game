--!strict
-- The timed challenges waiting in a set, in order: the three transition moments (start, drop;
-- the blend is judged separately) and the hype challenges (hit, release). Turns presses, releases
-- and the passing of time into grades. Pure logic: beats in, grades out.

local Balance = require(script.Parent.Parent.Config.Balance)
local TimingJudge = require(script.Parent.TimingJudge)

local ChallengeQueue = {}

export type Kind = "start" | "drop" | "hit" | "release"

export type Challenge = {
	kind: Kind,
	beat: number, -- the target beat (press for start/drop/hit, let go for release)
	holdFrom: number?, -- release only: when holding starts
	holding: boolean,
}

export type Queue = { items: { Challenge } }

export type Result = { challenge: Challenge, grade: TimingJudge.Grade }

-- A press more than this many beats before its target is ignored (pressing along with the countdown).
local IGNORE_EARLY_BEATS = 0.75

function ChallengeQueue.new(): Queue
	return { items = {} }
end

function ChallengeQueue.add(queue: Queue, kind: Kind, beat: number, holdFrom: number?)
	table.insert(queue.items, { kind = kind, beat = beat, holdFrom = holdFrom, holding = false })
	table.sort(queue.items, function(a, b)
		return a.beat < b.beat
	end)
end

function ChallengeQueue.clear(queue: Queue)
	table.clear(queue.items)
end

-- Moves every challenge at or after `fromBeat` later by `beats` (a postponed transition).
function ChallengeQueue.shift(queue: Queue, fromBeat: number, beats: number)
	for _, challenge in queue.items do
		if challenge.beat >= fromBeat then
			challenge.beat += beats
			if challenge.holdFrom then
				challenge.holdFrom += beats
			end
		end
	end
end

-- The challenge whose prompt is showing at `beat`, if any: the next one, once its countdown starts.
function ChallengeQueue.active(queue: Queue, beat: number): Challenge?
	local challenge = queue.items[1]
	if challenge and beat >= (challenge.holdFrom or challenge.beat) - Balance.Transition.countdownBeats then
		return challenge
	end
	return nil
end

local function finish(queue: Queue, challenge: Challenge, grade: TimingJudge.Grade): Result
	local index = table.find(queue.items, challenge)
	if index then
		table.remove(queue.items, index)
	end
	return { challenge = challenge, grade = grade }
end

-- The main button went down at `beat`. `beatSeconds` is the playing deck's real beat length.
function ChallengeQueue.press(queue: Queue, beat: number, beatSeconds: number): Result?
	local challenge = ChallengeQueue.active(queue, beat)
	if not challenge then
		return nil
	end
	if challenge.kind == "release" then
		if beat >= (challenge.holdFrom or challenge.beat) - 1 then
			challenge.holding = true
		end
		return nil
	end
	if beat - challenge.beat < -IGNORE_EARLY_BEATS then
		return nil
	end
	return finish(queue, challenge, TimingJudge.grade((beat - challenge.beat) * beatSeconds))
end

-- The main button came up at `beat`.
function ChallengeQueue.release(queue: Queue, beat: number, beatSeconds: number): Result?
	local challenge = ChallengeQueue.active(queue, beat)
	if not challenge or challenge.kind ~= "release" or not challenge.holding then
		return nil
	end
	challenge.holding = false
	-- Letting go long before the drop is a Miss; around it, it's graded like a press.
	if beat - challenge.beat < -1 then
		return finish(queue, challenge, "miss")
	end
	return finish(queue, challenge, TimingJudge.grade((beat - challenge.beat) * beatSeconds))
end

-- Challenges whose target passed without an answer become Misses. Call every frame.
function ChallengeQueue.expire(queue: Queue, beat: number, beatSeconds: number): { Result }
	local missed = {}
	while queue.items[1] and TimingJudge.isExpired((beat - queue.items[1].beat) * beatSeconds) do
		table.insert(missed, finish(queue, queue.items[1], "miss"))
	end
	return missed
end

-- What the prompt shows at `beat`: a short instruction, the countdown number, how far the ring
-- still has to close (1 -> 0), and how full the hold meter is (release only).
function ChallengeQueue.prompt(challenge: Challenge, beat: number): (string, string, number, number)
	local countdown = Balance.Transition.countdownBeats
	local toTarget = challenge.beat - beat
	local number = if toTarget > 0 then tostring(math.clamp(math.ceil(toTarget), 1, countdown)) else "!"
	local ring = math.clamp(toTarget / countdown, 0, 1)
	if challenge.kind == "release" then
		local holdFrom = challenge.holdFrom or challenge.beat
		local fill = math.clamp((beat - holdFrom) / math.max(1, challenge.beat - holdFrom), 0, 1)
		if beat < holdFrom then
			return "GET READY: HOLD SPACE THROUGH THE BUILD", tostring(math.ceil(holdFrom - beat)), 1, 0
		elseif challenge.holding then
			return "HOLD... LET GO ON THE DROP!", number, ring, fill
		end
		return "HOLD SPACE NOW!", number, ring, 0
	end
	local text = if challenge.kind == "start"
		then "START: PRESS ON THE 1"
		elseif challenge.kind == "drop" then "DROP: PRESS ON THE DROP!"
		else "HIT ON THE 1!"
	return text, number, ring, 0
end

return ChallengeQueue
