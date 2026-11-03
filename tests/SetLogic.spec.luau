--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local BlendJudge = require(Shared.Set.BlendJudge)
local CrowdEnergy = require(Shared.Set.CrowdEnergy)
local HypePlanner = require(Shared.Set.HypePlanner)
local TimingJudge = require(Shared.Set.TimingJudge)
local TrackChoice = require(Shared.Set.TrackChoice)
local TransitionPlanner = require(Shared.Set.TransitionPlanner)
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

	-- BlendJudge
	["the blend zone travels from one deck to the other"] = function()
		T.near(BlendJudge.zoneCentre(0, true), 0)
		T.near(BlendJudge.zoneCentre(0.5, true), 0.5)
		T.near(BlendJudge.zoneCentre(1, true), 1)
		T.near(BlendJudge.zoneCentre(0, false), 1)
	end,

	["the crossfader counts as in the zone within half its width"] = function()
		T.equal(BlendJudge.inZone(0.1, 0, true), true)
		T.equal(BlendJudge.inZone(0.5, 0, true), false)
	end,

	["time in the zone decides the blend grade"] = function()
		T.equal(BlendJudge.grade(0.95), "perfect")
		T.equal(BlendJudge.grade(0.7), "good")
		T.equal(BlendJudge.grade(0.3), "miss")
	end,

	["the crossfader keeps the total loudness even"] = function()
		local a, b = BlendJudge.gains(0)
		T.near(a, 1)
		T.near(b, 0)
		a, b = BlendJudge.gains(0.5)
		T.near(a * a + b * b, 1, 1e-6)
	end,

	-- CrowdEnergy
	["each Perfect raises the combo, which multiplies the next gain"] = function()
		local state = CrowdEnergy.new(50)
		T.near(CrowdEnergy.applyGrade(state, "moment", "perfect", 1), 6)
		T.near(CrowdEnergy.applyGrade(state, "moment", "perfect", 1), 6 * Balance.Combo[2])
		T.near(state.energy, 50 + 6 + 6 * Balance.Combo[2])
	end,

	["the combo tops out and a Miss resets it"] = function()
		local state = CrowdEnergy.new(10)
		for _ = 1, 10 do
			CrowdEnergy.applyGrade(state, "hype", "perfect", 1)
		end
		T.equal(CrowdEnergy.comboMultiplier(state), Balance.Combo[#Balance.Combo])
		CrowdEnergy.applyGrade(state, "hype", "miss", 1)
		T.equal(CrowdEnergy.comboMultiplier(state), 1)
	end,

	["the combo multiplies gains but not losses"] = function()
		local state = CrowdEnergy.new(50)
		CrowdEnergy.applyGrade(state, "moment", "perfect", 1)
		CrowdEnergy.applyGrade(state, "moment", "good", 1) -- keeps the combo
		T.near(CrowdEnergy.applyGrade(state, "drop", "miss", 1), Balance.Energy.drop.miss)
	end,

	["energy stays between 0 and 100"] = function()
		local state = CrowdEnergy.new(98)
		CrowdEnergy.applyGrade(state, "drop", "perfect", 1)
		T.equal(state.energy, 100)
		state = CrowdEnergy.new(2)
		CrowdEnergy.applyGrade(state, "drop", "miss", 1)
		T.equal(state.energy, 0)
	end,

	["energy drifts toward the section's pull every beat"] = function()
		local state = CrowdEnergy.new(35)
		CrowdEnergy.drift(state, "drop")
		T.near(state.energy, 35 + (Balance.Energy.sectionPull.drop - 35) * Balance.Energy.driftPerBeat)
	end,

	["the score follows the GDD formula"] = function()
		local state = CrowdEnergy.new(70)
		state.total, state.beats, state.peak = 700, 10, 90
		state.perfectDrops, state.misses = 2, 1
		T.near(CrowdEnergy.score(state), 0.6 * 70 + 0.25 * 90 + 2 * 4 - 3)
		T.equal(CrowdEnergy.letter(CrowdEnergy.score(state)), "B")
		T.equal(CrowdEnergy.letter(95), "S")
		T.equal(CrowdEnergy.letter(10), "F")
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

	-- HypePlanner
	["hype challenges sit on builds and inside drops"] = function()
		local found = {}
		for _, challenge in HypePlanner.plan(CLUB, 72, 260) do
			table.insert(found, challenge.kind .. " " .. challenge.beat)
		end
		T.equal(table.concat(found, ", "), "hit 80, release 224, hit 240")
	end,

	["a Release is held for 16 beats before the drop"] = function()
		local plan = HypePlanner.plan(CLUB, 0, 100)
		T.equal(plan[1].kind, "release")
		T.equal(plan[1].holdFrom, 64 - Balance.Hype.releaseHoldBeats)
	end,

	-- TrackChoice
	["cards only offer tracks within the gear's tempo range"] = function()
		local far = track("far", 140, "techno", 5, CLUB.sections)
		local near = track("near", 129, "tech house", 4, CLUB.sections)
		local offered = TrackChoice.candidates({ CLUB, far, near }, "club", 124, {}, 3, Random.new(1))
		T.equal(#offered, 1)
		T.equal(offered[1].id, "near")
	end,

	["played tracks come back only when too few fresh ones fit"] = function()
		local a = track("a", 124, "house", 3, CLUB.sections)
		local b = track("b", 124, "house", 3, CLUB.sections)
		local offered = TrackChoice.candidates({ CLUB, a, b }, "club", 124, { a = true }, 3, Random.new(3))
		T.equal(#offered, 2)
		T.equal(offered[1].id, "b")
	end,

	["cards never offer more than asked"] = function()
		local pool = {}
		for i = 1, 6 do
			table.insert(pool, track("t" .. i, 124, "house", 3, CLUB.sections))
		end
		T.equal(#TrackChoice.candidates(pool, "none", 124, {}, 3, Random.new(2)), 3)
	end,

	["a crowd wish is always one a card can meet"] = function()
		local cards = { CLUB, EARLY_DROP }
		for seed = 1, 20 do
			local wish = TrackChoice.makeWish(cards, CLUB, Random.new(seed), 1)
			assert(wish, "no wish")
			local met = false
			for _, card in cards do
				met = met or TrackChoice.matches(card, wish)
			end
			T.truthy(met, "seed " .. seed)
		end
	end,
}
