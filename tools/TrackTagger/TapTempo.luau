--!strict
-- Turns taps (track times in seconds, one per beat) into a BPM and a beat grid.
-- Each tap is first matched to a whole beat number, so a missed tap or an accidental double tap
-- doesn't break the result. Then a least-squares line through (beat number, time) gives the beat length.

local TapTempo = {}

TapTempo.MIN_TAPS = 4
-- A measured BPM this close to a whole number is rounded to it (most electronic tracks use whole BPMs).
TapTempo.ROUND_WITHIN = 0.3

export type Fit = {
	bpm: number, -- tempo the grid uses (rounded)
	measuredBpm: number, -- tempo straight from the taps
	anchor: number, -- track time (seconds) of one beat on the grid
	tapCount: number, -- taps used after dropping double taps
	maxErrorMs: number, -- worst tap's distance from the grid
}

local function median(values: { number }): number
	local sorted = table.clone(values)
	table.sort(sorted)
	local middle = #sorted // 2
	if #sorted % 2 == 1 then
		return sorted[middle + 1]
	end
	return (sorted[middle] + sorted[middle + 1]) / 2
end

-- Gives each tap a beat number, counting whole beats between neighbours. Taps less than
-- half a beat after the previous one are dropped as double taps.
local function assignBeats(taps: { number }): ({ number }, { number })
	local intervals = {}
	for i = 2, #taps do
		table.insert(intervals, taps[i] - taps[i - 1])
	end
	local typical = median(intervals)

	local times, beats = { taps[1] }, { 0 }
	for i = 2, #taps do
		local steps = math.round((taps[i] - times[#times]) / typical)
		if steps >= 1 then
			table.insert(times, taps[i])
			table.insert(beats, beats[#beats] + steps)
		end
	end
	return times, beats
end

-- Fits a beat grid to the taps. Returns nil until there are enough usable taps.
function TapTempo.fit(taps: { number }, roundToWhole: boolean): Fit?
	if #taps < TapTempo.MIN_TAPS then
		return nil
	end
	local sorted = table.clone(taps)
	table.sort(sorted)

	local times, beats = assignBeats(sorted)
	local n = #times
	if n < TapTempo.MIN_TAPS then
		return nil
	end

	local meanBeat, meanTime = 0, 0
	for i = 1, n do
		meanBeat += beats[i] / n
		meanTime += times[i] / n
	end
	local covariance, variance = 0, 0
	for i = 1, n do
		covariance += (beats[i] - meanBeat) * (times[i] - meanTime)
		variance += (beats[i] - meanBeat) ^ 2
	end
	local measuredBpm = 60 / (covariance / variance)

	local bpm = math.round(measuredBpm * 100) / 100
	if roundToWhole and math.abs(measuredBpm - math.round(measuredBpm)) <= TapTempo.ROUND_WITHIN then
		bpm = math.round(measuredBpm)
	end

	-- With the BPM fixed, the best grid position is the average of each tap minus its beat offset.
	local beatLength = 60 / bpm
	local anchor = 0
	for i = 1, n do
		anchor += (times[i] - beats[i] * beatLength) / n
	end

	local maxError = 0
	for i = 1, n do
		maxError = math.max(maxError, math.abs(times[i] - (anchor + beats[i] * beatLength)))
	end

	return {
		bpm = bpm,
		measuredBpm = measuredBpm,
		anchor = anchor,
		tapCount = n,
		maxErrorMs = maxError * 1000,
	}
end

-- The grid beat closest to a track time.
function TapTempo.snapToGrid(fit: Fit, time: number): number
	local beatLength = 60 / fit.bpm
	return fit.anchor + math.round((time - fit.anchor) / beatLength) * beatLength
end

return TapTempo
