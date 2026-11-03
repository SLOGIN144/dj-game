--!strict
-- Converts between track time (seconds) and beats using a track's tagged BPM and first downbeat.
-- The Track Tagger and the BeatClock both use this, so they always agree on where a beat is.

local BeatMath = {}

BeatMath.BEATS_PER_BAR = 4

-- Seconds per beat at the given BPM.
function BeatMath.beatLength(bpm: number): number
	return 60 / bpm
end

-- Beat position at a track time. Beat 0 is the first downbeat; earlier times give negative beats.
function BeatMath.timeToBeat(timePosition: number, bpm: number, firstBeat: number): number
	return (timePosition - firstBeat) * bpm / 60
end

-- Track time of a beat position.
function BeatMath.beatToTime(beat: number, bpm: number, firstBeat: number): number
	return firstBeat + beat * 60 / bpm
end

-- Nearest bar start (a multiple of 4 beats) to a beat position.
function BeatMath.snapToBar(beat: number): number
	return math.round(beat / BeatMath.BEATS_PER_BAR) * BeatMath.BEATS_PER_BAR
end

-- 1-based bar number and beat-in-bar (1..4), the way a DJ counts: bar 1 beat 1 is the first downbeat.
function BeatMath.barAndBeat(beat: number): (number, number)
	local whole = math.floor(beat)
	local bar = math.floor(whole / BeatMath.BEATS_PER_BAR)
	return bar + 1, whole - bar * BeatMath.BEATS_PER_BAR + 1
end

return BeatMath
