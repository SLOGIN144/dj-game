--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChallengeQueue = require(ReplicatedStorage.Shared.Set.ChallengeQueue)
local T = require(script.Parent.TestUtil)

local BEAT = 0.5 -- seconds per beat (120 BPM)

return {
	["a press on the target beat is Perfect"] = function()
		local queue = ChallengeQueue.new()
		ChallengeQueue.add(queue, "drop", 64)
		local result = ChallengeQueue.press(queue, 64.02, BEAT)
		assert(result, "no result")
		T.equal(result.grade, "perfect")
		T.equal(#queue.items, 0)
	end,

	["pressing along with the countdown is ignored"] = function()
		local queue = ChallengeQueue.new()
		ChallengeQueue.add(queue, "start", 64)
		T.equal(ChallengeQueue.press(queue, 62, BEAT), nil)
		T.equal(#queue.items, 1)
	end,

	["a press just before the target is graded"] = function()
		local queue = ChallengeQueue.new()
		ChallengeQueue.add(queue, "hit", 64)
		local result = ChallengeQueue.press(queue, 63.8, BEAT) -- 100 ms early
		assert(result, "no result")
		T.equal(result.grade, "good")
	end,

	["no prompt before the countdown starts"] = function()
		local queue = ChallengeQueue.new()
		ChallengeQueue.add(queue, "drop", 64)
		T.equal(ChallengeQueue.active(queue, 59), nil)
		T.truthy(ChallengeQueue.active(queue, 60), "active at the countdown")
	end,

	["an unanswered target becomes a Miss"] = function()
		local queue = ChallengeQueue.new()
		ChallengeQueue.add(queue, "drop", 64)
		T.equal(#ChallengeQueue.expire(queue, 64.1, BEAT), 0)
		local missed = ChallengeQueue.expire(queue, 64.5, BEAT)
		T.equal(#missed, 1)
		T.equal(missed[1].grade, "miss")
	end,

	["a release is held through the build and let go on the drop"] = function()
		local queue = ChallengeQueue.new()
		ChallengeQueue.add(queue, "release", 64, 48)
		T.equal(ChallengeQueue.press(queue, 48.2, BEAT), nil)
		T.equal(queue.items[1].holding, true)
		local result = ChallengeQueue.release(queue, 64.05, BEAT)
		assert(result, "no result")
		T.equal(result.grade, "perfect")
	end,

	["letting go of a release early is a Miss"] = function()
		local queue = ChallengeQueue.new()
		ChallengeQueue.add(queue, "release", 64, 48)
		ChallengeQueue.press(queue, 49, BEAT)
		local result = ChallengeQueue.release(queue, 55, BEAT)
		assert(result, "no result")
		T.equal(result.grade, "miss")
	end,

	["challenges come in order and a postponed transition moves its moments"] = function()
		local queue = ChallengeQueue.new()
		ChallengeQueue.add(queue, "drop", 160)
		ChallengeQueue.add(queue, "hit", 96)
		ChallengeQueue.add(queue, "start", 128)
		T.equal(queue.items[1].kind, "hit")
		ChallengeQueue.shift(queue, 128, 16)
		T.equal(queue.items[2].beat, 144)
		T.equal(queue.items[3].beat, 176)
		T.equal(queue.items[1].beat, 96)
	end,

	["the prompt counts down 4-3-2-1 and closes the ring"] = function()
		local challenge = { kind = "start" :: ChallengeQueue.Kind, beat = 64, holdFrom = nil, holding = false }
		local _, number, ring = ChallengeQueue.prompt(challenge, 60.5)
		T.equal(number, "4")
		T.near(ring, 3.5 / 4)
		_, number, ring = ChallengeQueue.prompt(challenge, 63.5)
		T.equal(number, "1")
		T.near(ring, 0.5 / 4)
	end,
}
