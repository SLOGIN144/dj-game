--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeatMath = require(ReplicatedStorage.Shared.Util.BeatMath)
local T = require(script.Parent.TestUtil)

return {
	["beat 0 is the first downbeat"] = function()
		T.near(BeatMath.timeToBeat(0.48, 124, 0.48), 0)
	end,

	["one beat length later is beat 1"] = function()
		T.near(BeatMath.timeToBeat(0.48 + 60 / 124, 124, 0.48), 1)
	end,

	["times before the first downbeat give negative beats"] = function()
		T.near(BeatMath.timeToBeat(0, 120, 0.5), -1)
	end,

	["beatToTime undoes timeToBeat"] = function()
		local time = BeatMath.beatToTime(96, 124, 0.48)
		T.near(BeatMath.timeToBeat(time, 124, 0.48), 96)
	end,

	["snapToBar rounds to the nearest multiple of 4"] = function()
		T.equal(BeatMath.snapToBar(5.9), 4)
		T.equal(BeatMath.snapToBar(6.1), 8)
		T.equal(BeatMath.snapToBar(0.4), 0)
	end,

	["barAndBeat counts from bar 1 beat 1"] = function()
		local bar, beat = BeatMath.barAndBeat(0)
		T.equal(bar, 1, "bar")
		T.equal(beat, 1, "beat")
		bar, beat = BeatMath.barAndBeat(5.5)
		T.equal(bar, 2, "bar")
		T.equal(beat, 2, "beat")
	end,
}
