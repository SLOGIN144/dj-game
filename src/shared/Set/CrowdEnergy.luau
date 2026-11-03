--!strict
-- The crowd's energy (0..100), the combo, and the set's final score and grade.

local Balance = require(script.Parent.Parent.Config.Balance)
local TimingJudge = require(script.Parent.TimingJudge)
local Types = require(script.Parent.Parent.Types)

local CrowdEnergy = {}

export type Kind = "moment" | "drop" | "hype"

export type State = {
	energy: number,
	comboStep: number, -- index into Balance.Combo
	peak: number,
	total: number, -- sum of energy over beats, for the average
	beats: number,
	perfectDrops: number,
	misses: number,
}

function CrowdEnergy.new(startEnergy: number): State
	return {
		energy = startEnergy,
		comboStep = 1,
		peak = startEnergy,
		total = 0,
		beats = 0,
		perfectDrops = 0,
		misses = 0,
	}
end

local function change(state: State, amount: number): number
	local before = state.energy
	state.energy = math.clamp(before + amount, 0, 100)
	state.peak = math.max(state.peak, state.energy)
	return state.energy - before
end

function CrowdEnergy.comboMultiplier(state: State): number
	return Balance.Combo[state.comboStep]
end

-- One beat of the crowd living with the music: energy eases toward the section's pull.
function CrowdEnergy.drift(state: State, section: Types.SectionKind)
	local pull = Balance.Energy.sectionPull[section]
	change(state, (pull - state.energy) * Balance.Energy.driftPerBeat)
	state.total += state.energy
	state.beats += 1
end

-- Applies a graded challenge. Gains are multiplied by the combo in effect before this grade and
-- by `genreMultiplier`; losses aren't. Returns the energy change.
function CrowdEnergy.applyGrade(state: State, kind: Kind, grade: TimingJudge.Grade, genreMultiplier: number): number
	local values = Balance.Energy[kind]
	local amount = values[grade]
	if amount > 0 then
		amount *= CrowdEnergy.comboMultiplier(state) * genreMultiplier
	end

	if grade == "perfect" then
		state.comboStep = math.min(state.comboStep + 1, #Balance.Combo)
		if kind == "drop" then
			state.perfectDrops += 1
		end
	elseif grade == "miss" then
		state.comboStep = 1
		state.misses += 1
	end
	return change(state, amount)
end

-- A flat bonus, such as meeting a crowd wish.
function CrowdEnergy.applyBonus(state: State, amount: number, genreMultiplier: number): number
	return change(state, amount * genreMultiplier)
end

function CrowdEnergy.score(state: State): number
	local score = Balance.Score
	local average = if state.beats > 0 then state.total / state.beats else state.energy
	return math.clamp(
		score.averageWeight * average
			+ score.peakWeight * state.peak
			+ score.perPerfectDrop * state.perfectDrops
			- score.perMiss * state.misses,
		0,
		100
	)
end

function CrowdEnergy.letter(score: number): string
	for _, entry in Balance.Grades do
		if score >= entry.min then
			return entry.grade
		end
	end
	return "F"
end

return CrowdEnergy
