--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Crossfade = require(Shared.Music.Crossfade)
local TimingJudge = require(Shared.Music.TimingJudge)
local TransitionPlanner = require(Shared.Music.TransitionPlanner)
local Types = require(Shared.Types)
local T = require(script.Parent.TestUtil)

local function track(id: string, bpm: number, genre: string, energy: number, sections: { Types.Section }): Types.Track
	return {
		id = id,
		assetId = 1,
		title = id,
		artist = "Test",
		genre = genre,
		bpm = bpm,
		firstBeat = 0,
		sections = sections,
		cuePoint = 0,
		energy = energy,
		tier = 1,
		price = 0,
	}
end

local CLUB = track("club", 124, "house", 3, {
	{ kind = "intro", startBeat = 0 },
	{ kind = "build", startBeat = 32 },
	{ kind = "drop", startBeat = 64 },
	{ kind = "breakdown", startBeat = 160 },
	{ kind = "build", startBeat = 192 },
	{ kind = "drop", startBeat = 224 },
	{ kind = "outro", startBeat = 320 },
})

local EARLY_DROP = track("early", 128, "tech house", 4, {
	{ kind = "intro", startBeat = 0 },
	{ kind = "drop", startBeat = 16 },
	{ kind = "breakdown", startBeat = 192 },
	{ kind = "build", startBeat = 224 },
	{ kind = "drop", startBeat = 256 },
})

return {
	-- TimingJudge
	["presses within 50 ms are Perfect"] = function()
		T.equal(TimingJudge.grade(0.03), "perfect")
		T.equal(TimingJudge.grade(-0.049), "perfect")
	end,

	["presses within 120 ms are Good, later ones Miss"] = function()
		T.equal(TimingJudge.grade(0.1), "good")
		T.equal(TimingJudge.grade(-0.2), "miss")
	end,

	-- Crossfade
	["the crossfader keeps the total loudness even"] = function()
		local a, b = Crossfade.gains(0)
		T.near(a, 1)
		T.near(b, 0)
		a, b = Crossfade.gains(0.5)
		T.near(a * a + b * b, 1, 1e-6)
	end,

	-- TransitionPlanner
	["an incoming track starts 8 bars before its drop"] = function()
		local start, drop = TransitionPlanner.entry(CLUB)
		T.equal(start, 32)
		T.equal(drop, 64)
	end,

	["an incoming track skips a drop too early to blend into"] = function()
		local start, drop = TransitionPlanner.entry(EARLY_DROP)
		T.equal(start, 224)
		T.equal(drop, 256)
	end,

	["a track mixes out on a phrase after playing its drop"] = function()
		T.equal(TransitionPlanner.mixOutBeat(CLUB, 64, 70, 500), 128)
		T.equal(TransitionPlanner.mixOutBeat(CLUB, 64, 120, 500), 160)
	end,

	["a short track mixes out before it ends"] = function()
		T.equal(TransitionPlanner.mixOutBeat(CLUB, 64, 70, 150), 116)
	end,
}
