--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Boost = require(Shared.Economy.Boost)
local MixTimeline = require(Shared.Music.MixTimeline)
local T = require(script.Parent.TestUtil)

local DROPS: { MixTimeline.Drop } = {
	{ time = 100, n = 1, beat = 64 },
	{ time = 178, n = 2, beat = 64 },
}

return {
	["a Perfect drop doubles income for 30 s and a Good one gives x1.5 for 20 s"] = function()
		local perfect = Boost.forGrade("perfect", 10) :: Boost.Boost
		T.equal(perfect.multiplier, Balance.Boost.perfect.multiplier)
		T.equal(perfect.endsAt, 10 + Balance.Boost.perfect.seconds)
		local good = Boost.forGrade("good", 10) :: Boost.Boost
		T.equal(good.multiplier, Balance.Boost.good.multiplier)
		T.equal(Boost.forGrade("miss", 10), nil)
	end,

	["a stronger boost replaces a weaker one, never the other way round"] = function()
		local good = Boost.forGrade("good", 0)
		local perfect = Boost.forGrade("perfect", 5)
		T.equal(Boost.combine(good, perfect, 5), perfect)
		T.equal(Boost.combine(perfect, Boost.forGrade("good", 6), 6), perfect)
	end,

	["boosts never stack; an equal one only extends the time"] = function()
		local first = Boost.forGrade("perfect", 0)
		local second = Boost.forGrade("perfect", 10) :: Boost.Boost
		local combined = Boost.combine(first, second, 10) :: Boost.Boost
		T.equal(combined.multiplier, Balance.Boost.perfect.multiplier)
		T.equal(combined.endsAt, second.endsAt)
	end,

	["an expired boost counts for nothing"] = function()
		local good = Boost.forGrade("good", 0)
		T.equal(Boost.multiplier(good, 1), Balance.Boost.good.multiplier)
		T.equal(Boost.multiplier(good, Balance.Boost.good.seconds + 1), 1)
		local later = Boost.forGrade("good", 100)
		T.equal(Boost.combine(Boost.forGrade("perfect", 0), later, 100), later)
	end,

	["the server grades a press from its time, not the client's word"] = function()
		local used = {}
		local grade, drop = Boost.judgePress(DROPS, 100.04, 100.1, used)
		T.equal(grade, "perfect")
		T.equal(drop, DROPS[1])
		T.equal((Boost.judgePress(DROPS, 177.9, 178.0, used)), "good")
		T.equal((Boost.judgePress(DROPS, 140, 140.05, {})), "miss", "far from any drop")
	end,

	["each drop counts once"] = function()
		local used = {}
		T.equal((Boost.judgePress(DROPS, 99.7, 99.8, used)), "miss", "too early, but it was the press for that drop")
		T.equal((Boost.judgePress(DROPS, 100.0, 100.1, used)), "miss", "no second try")
	end,

	["a press that arrives too late or impossibly early is refused"] = function()
		T.equal((Boost.judgePress(DROPS, 100.0, 100.0 + Balance.Boost.lagAllowance + 0.1, {})), "miss")
		T.equal((Boost.judgePress(DROPS, 100.0, 100.0 - Balance.Boost.clockSlack - 0.1, {})), "miss")
	end,
}
