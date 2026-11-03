--!strict
-- Guesses a track's tempo from raw audio samples, so the tagger can show a starting BPM and
-- catch tapping mistakes (like tapping every other beat). It is a rough guess: taps stay the
-- source of truth for the beat grid.
--
-- How: turn the audio into an "onset envelope" (how sharply the loudness rises, sampled
-- ENVELOPE_RATE times a second), then find the beat length at which the envelope best
-- lines up with itself (autocorrelation). Kicks on every beat make that line-up strong.

local TempoEstimate = {}

TempoEstimate.ENVELOPE_RATE = 400 -- envelope values per second
TempoEstimate.MIN_BPM = 100 -- search range; covers house, tech house and techno
TempoEstimate.MAX_BPM = 150
-- Below this, the guess is too unsure to show. Clear four-to-the-floor tracks score 0.2 to 0.9.
TempoEstimate.MIN_CONFIDENCE = 0.1
-- Tapped and estimated tempos this close (BPM) count as agreeing; the estimate is only rough.
TempoEstimate.MATCH_WITHIN = 3

export type Estimate = {
	bpm: number,
	confidence: number, -- 0..1, how strongly the audio repeats at that tempo
}

-- Loudness rises per envelope step: log-compressed RMS, keeping only increases.
local function onsetEnvelope(samples: { number }, sampleRate: number): { number }
	local hop = math.max(1, math.floor(sampleRate / TempoEstimate.ENVELOPE_RATE))
	local envelope = {}
	local previous = 0
	for frame = 0, #samples // hop - 1 do
		local sum = 0
		for i = frame * hop + 1, frame * hop + hop do
			sum += samples[i] * samples[i]
		end
		local loudness = math.log(1 + 100 * math.sqrt(sum / hop))
		table.insert(envelope, math.max(0, loudness - previous))
		previous = loudness
	end
	return envelope
end

local function withoutMean(values: { number }): { number }
	local mean = 0
	for _, value in values do
		mean += value / #values
	end
	local centred = table.create(#values, 0)
	for i, value in values do
		centred[i] = value - mean
	end
	return centred
end

local function autocorrelation(envelope: { number }, lag: number): number
	local sum = 0
	for i = 1, #envelope - lag do
		sum += envelope[i] * envelope[i + lag]
	end
	return sum
end

-- Estimates the tempo of a stretch of audio (a few seconds of a section with a beat works best).
-- Returns nil for silence or audio too short to judge.
function TempoEstimate.fromSamples(samples: { number }, sampleRate: number): Estimate?
	return TempoEstimate.fromEnvelope(onsetEnvelope(samples, sampleRate), TempoEstimate.ENVELOPE_RATE)
end

-- Same, from an onset envelope (loudness rises) with `rate` values per second.
function TempoEstimate.fromEnvelope(onsets: { number }, rate: number): Estimate?
	local envelope = withoutMean(onsets)
	local shortestLag = math.floor(60 * rate / TempoEstimate.MAX_BPM)
	local longestLag = math.ceil(60 * rate / TempoEstimate.MIN_BPM)
	local energy = autocorrelation(envelope, 0)
	if energy <= 1e-9 or #envelope < longestLag * 4 then
		return nil
	end

	-- Score each beat length, adding half the score of a two-beat lag so the true beat wins
	-- over lags that only line up once.
	local scores: { [number]: number } = {}
	local bestLag, bestScore = shortestLag, -math.huge
	for lag = shortestLag - 1, longestLag + 1 do
		scores[lag] = autocorrelation(envelope, lag) + 0.5 * autocorrelation(envelope, 2 * lag)
		if lag >= shortestLag and lag <= longestLag and scores[lag] > bestScore then
			bestLag, bestScore = lag, scores[lag]
		end
	end

	-- Fit a parabola through the best score and its neighbours for a finer-than-one-step lag.
	local before, at, after = scores[bestLag - 1], scores[bestLag], scores[bestLag + 1]
	local curve = before - 2 * at + after
	local shift = if curve ~= 0 then (before - after) / (2 * curve) else 0
	shift = math.clamp(shift, -1, 1)

	return {
		bpm = 60 * rate / (bestLag + shift),
		confidence = math.clamp(bestScore / energy, 0, 1),
	}
end

-- A plain-English hint when the tapped tempo disagrees with the estimate, or nil when they agree.
function TempoEstimate.checkTaps(tappedBpm: number, estimate: Estimate): string?
	if math.abs(tappedBpm - estimate.bpm) <= TempoEstimate.MATCH_WITHIN then
		return nil
	end
	local ratio = tappedBpm / estimate.bpm
	if math.abs(ratio - 0.5) < 0.04 then
		return "Looks like you tapped every other beat. Press R and tap on every beat."
	elseif math.abs(ratio - 2) < 0.08 then
		return "Looks like you tapped twice per beat. Press R and tap once per beat."
	end
	return string.format(
		"The estimate says ~%d BPM. Listen again and re-tap (R), or ignore this if you're sure.",
		math.round(estimate.bpm)
	)
end

-- The most confident of several estimates (for example from different parts of a track).
function TempoEstimate.best(estimates: { Estimate }): Estimate?
	local best: Estimate? = nil
	for _, estimate in estimates do
		if not best or estimate.confidence > best.confidence then
			best = estimate
		end
	end
	return best
end

return TempoEstimate
