--!strict
-- Finds a track's beat grid (exact BPM and first downbeat) from its audio features. Pure logic.
--
-- 1. Tempo: take every sharp onset in the whole track (mostly kicks) and find the beat length
--    at which they all line up best, first in coarse steps across the whole tempo range, then
--    finely. Over a whole track this is very precise, because a wrong tempo makes the onsets
--    drift apart by the end.
-- 2. Where the beat falls: fold the whole track's onset strength onto one beat length and take
--    the strongest point. Kick attacks pile up there; their ring-out spreads after it.
-- 3. Downbeat, from two clues: sections change on the "1" of a bar (the beat where loudness
--    jumps most often), and DJ tracks bring their kick in on a "1". When the clues disagree,
--    the first kick wins unless the section changes are very clear.

local AudioFeatures = require(script.Parent.AudioFeatures)

local GridDetect = {}

GridDetect.MIN_BPM = 100 -- search range; covers house, tech house and techno
GridDetect.MAX_BPM = 150
GridDetect.COARSE_STEP = 0.05 -- BPM; narrower than the line-up peak of even a 1-minute track
GridDetect.MIN_FIT = 0.15 -- below this line-up score there is no steady beat to lock onto
GridDetect.WHOLE_WITHIN = 0.1 -- an exact tempo this close to a whole number is snapped to it...
GridDetect.WHOLE_MIN_FIT = 0.9 -- ...if the whole number lines the onsets up at least this well
GridDetect.ONSET_THRESHOLD = 1.5 -- an onset counts when it is this many standard deviations above average
-- One kick shows up as several onsets while it rings out. Onsets within this time of the first
-- count as one, so ringing kicks don't outweigh short ones.
GridDetect.MERGE_SECONDS = 0.1
GridDetect.KICK_START_SHARE = 0.4 -- a beat has a real kick at this share of a typical strong kick
GridDetect.TRUST_SECTIONS_CLARITY = 0.6 -- section changes overrule the first kick only when this clear

export type Grid = {
	bpm: number,
	firstBeat: number, -- seconds to the first downbeat
	beatConfidence: number, -- 0..1, how tightly the onsets line up with the grid
	downbeatConfidence: number, -- 0..1, how clearly section changes point at one beat as the "1"
	downbeatMethod: string, -- which clue decided the "1", for checking results
	driftMs: number, -- how far the grid fitted to the first half is from the second half
}

type Onset = { time: number, weight: number }

local function meanAndDeviation(values: { number }): (number, number)
	local mean, square = 0, 0
	for _, value in values do
		mean += value
		square += value * value
	end
	mean /= #values
	return mean, math.sqrt(math.max(0, square / #values - mean * mean))
end

-- Onset strength per frame: mostly the plain rise of the low end (kicks), with a little of the
-- whole sound's onsets for tracks with a soft kick. Nil for silence.
local function onsetStrength(features: AudioFeatures.Features): { number }?
	local _, lowDeviation = meanAndDeviation(features.lowRise)
	local _, fullDeviation = meanAndDeviation(features.fullOnset)
	if lowDeviation <= 0 or fullDeviation <= 0 then
		return nil
	end
	local values = table.create(#features.lowRise, 0)
	for i = 1, #values do
		values[i] = features.lowRise[i] / lowDeviation + 0.25 * features.fullOnset[i] / fullDeviation
	end
	return values
end

-- The sharpest onsets: local peaks well above average, one per kick.
local function strongOnsets(values: { number }, frameRate: number): { Onset }
	local mean, deviation = meanAndDeviation(values)
	local threshold = mean + GridDetect.ONSET_THRESHOLD * deviation
	local onsets: { Onset } = {}
	for i = 2, #values - 1 do
		local value = values[i]
		if value > threshold and value >= values[i - 1] and value >= values[i + 1] then
			local time = (i - 1) / frameRate
			local previous = onsets[#onsets]
			if previous and time - previous.time < GridDetect.MERGE_SECONDS then
				previous.weight += value
			else
				table.insert(onsets, { time = time, weight = value })
			end
		end
	end
	return onsets
end

-- Where in each beat the onsets are strongest, in seconds from the start of the track's first
-- beat-length (0 .. beatLength).
local function beatPhase(values: { number }, frameRate: number, beatLength: number): number
	local bins = math.max(8, math.floor(beatLength * frameRate))
	local folded = table.create(bins, 0)
	for i, value in values do
		local bin = math.floor((((i - 1) / frameRate) % beatLength) / beatLength * bins) + 1
		folded[bin] += value
	end
	local best, bestScore = 1, -math.huge
	for bin = 1, bins do
		-- Include the neighbouring bins (wrapping around) so one noisy frame can't win.
		local score = folded[bin] + 0.5 * (folded[(bin - 2) % bins + 1] + folded[bin % bins + 1])
		if score > bestScore then
			best, bestScore = bin, score
		end
	end
	return (best - 1) / bins * beatLength
end

-- How well the onsets line up with a beat of `bpm` (0..1), and the grid's phase angle.
local function lineUp(onsets: { Onset }, bpm: number, from: number?, to: number?): (number, number)
	local angularSpeed = 2 * math.pi * bpm / 60
	local cosine, sine, total = 0, 0, 0
	for _, onset in onsets do
		if (not from or onset.time >= from) and (not to or onset.time < to) then
			local angle = angularSpeed * onset.time
			cosine += onset.weight * math.cos(angle)
			sine += onset.weight * math.sin(angle)
			total += onset.weight
		end
	end
	if total <= 0 then
		return 0, 0
	end
	return math.sqrt(cosine * cosine + sine * sine) / total, math.atan2(sine, cosine)
end

local function bestBpm(onsets: { Onset }, from: number, to: number, step: number): number
	local best, bestFit = from, -1
	local bpm = from
	while bpm <= to + step / 2 do
		local fit = lineUp(onsets, bpm)
		if fit > bestFit then
			best, bestFit = bpm, fit
		end
		bpm += step
	end
	return best
end

-- Average loudness (low end and whole sound, in dB) of each beat on the grid.
local function beatLevels(
	features: AudioFeatures.Features,
	beatLength: number,
	origin: number
): ({ number }, { number })
	local low, full = {}, {}
	local rate = features.frameRate
	local beat = 0
	while origin + (beat + 1) * beatLength <= features.duration do
		local first = math.floor((origin + beat * beatLength) * rate) + 1
		local last = math.floor((origin + (beat + 1) * beatLength) * rate)
		local sumLow, sumFull, count = 0, 0, 0
		for frame = math.max(1, first), math.min(#features.lowLevel, last) do
			sumLow += features.lowLevel[frame]
			sumFull += features.fullLevel[frame]
			count += 1
		end
		table.insert(low, if count > 0 then sumLow / count else -100)
		table.insert(full, if count > 0 then sumFull / count else -100)
		beat += 1
	end
	return low, full
end

-- Which of the four beats is the "1": the one where loudness jumps most (squared, so big
-- section changes count more than small wobbles). Returns the offset 0..3 and a confidence.
local function downbeatOffset(features: AudioFeatures.Features, beatLength: number, origin: number): (number, number)
	local low, full = beatLevels(features, beatLength, origin)
	local scores = { 0, 0, 0, 0 }
	for beat = 2, #low do
		local change = math.abs(low[beat] - low[beat - 1]) + math.abs(full[beat] - full[beat - 1])
		local offset = (beat - 1) % 4
		scores[offset + 1] += change * change
	end
	local bestOffset, best, second = 0, -1, -1
	for offset = 0, 3 do
		local score = scores[offset + 1]
		if score > best then
			second, best, bestOffset = best, score, offset
		elseif score > second then
			second = score
		end
	end
	return bestOffset, if best > 0 then (best - math.max(second, 0)) / best else 0
end

-- Beat offset (0..3) of the first steady kick: the first beat with a strong kick that keeps
-- playing on most of the next four beats. Nil if the track never settles into a kick.
local function firstKickOffset(features: AudioFeatures.Features, beatLength: number, origin: number): number?
	local rate = features.frameRate
	local before, after = math.ceil(0.005 * rate), math.ceil(0.03 * rate)
	local strengths = {}
	local beat = 0
	while origin + (beat + 1) * beatLength <= features.duration do
		local frame = math.floor((origin + beat * beatLength) * rate) + 1
		local sum = 0
		for f = math.max(1, frame - before), math.min(#features.lowRise, frame + after) do
			sum += features.lowRise[f]
		end
		table.insert(strengths, sum)
		beat += 1
	end
	if #strengths < 8 then
		return nil
	end
	local sorted = table.clone(strengths)
	table.sort(sorted)
	local strong = sorted[math.max(1, math.floor(#sorted * 0.9))] * GridDetect.KICK_START_SHARE
	for i = 1, #strengths - 4 do
		if strengths[i] >= strong then
			local following = 0
			for j = i + 1, i + 4 do
				if strengths[j] >= strong then
					following += 1
				end
			end
			if following >= 3 then
				return (i - 1) % 4
			end
		end
	end
	return nil
end

-- Picks the "1" from the two clues. Returns the beat offset (0..3) and which clue decided it.
function GridDetect.chooseDownbeat(sectionOffset: number, clarity: number, kickOffset: number?): (number, string)
	if kickOffset == nil then
		return sectionOffset, "section changes (no steady kick found)"
	elseif kickOffset == sectionOffset then
		return sectionOffset, "section changes and first kick agree"
	elseif clarity >= GridDetect.TRUST_SECTIONS_CLARITY then
		return sectionOffset, "section changes (first kick disagrees)"
	end
	return kickOffset, "first kick (section changes unclear)"
end

local function wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- Returns nil when the track has no steady beat to lock onto (silence, ambient pieces).
function GridDetect.detect(features: AudioFeatures.Features): Grid?
	local strength = onsetStrength(features)
	if not strength then
		return nil
	end
	local onsets = strongOnsets(strength, features.frameRate)
	if #onsets < 16 then
		return nil
	end

	-- Coarse steps across the whole range, then fine steps around the best one.
	local step = GridDetect.COARSE_STEP
	local coarse = bestBpm(onsets, GridDetect.MIN_BPM, GridDetect.MAX_BPM, step)
	local exact = bestBpm(onsets, coarse - step, coarse + step, 0.001)
	if lineUp(onsets, exact) < GridDetect.MIN_FIT then
		return nil
	end

	local bpm = math.round(exact * 100) / 100
	local whole = math.round(exact)
	if
		math.abs(exact - whole) <= GridDetect.WHOLE_WITHIN
		and lineUp(onsets, whole) >= GridDetect.WHOLE_MIN_FIT * lineUp(onsets, exact)
	then
		bpm = whole
	end

	local beatLength = 60 / bpm
	local fit = lineUp(onsets, bpm)
	local origin = beatPhase(strength, features.frameRate, beatLength)

	local middle = features.duration / 2
	local _, firstHalf = lineUp(onsets, bpm, nil, middle)
	local _, secondHalf = lineUp(onsets, bpm, middle, nil)
	local driftMs = math.abs(wrapAngle(secondHalf - firstHalf)) / (2 * math.pi) * beatLength * 1000

	local sectionOffset, downbeatConfidence = downbeatOffset(features, beatLength, origin)
	local offset, method =
		GridDetect.chooseDownbeat(sectionOffset, downbeatConfidence, firstKickOffset(features, beatLength, origin))
	local barLength = beatLength * 4
	local downbeat = origin + offset * beatLength
	return {
		bpm = bpm,
		firstBeat = downbeat - math.floor(downbeat / barLength) * barLength,
		beatConfidence = fit,
		downbeatConfidence = downbeatConfidence,
		downbeatMethod = method,
		driftMs = driftMs,
	}
end

return GridDetect
