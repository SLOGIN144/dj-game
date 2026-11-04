--!strict
-- Where a plot's planned mix is at any moment: each segment's beat, playback speed, gain and bass,
-- and when its drops land, all against the server clock. Pure, so the server (drop checks) and
-- every client (audio, lights, guests) agree on the same numbers.
--
-- A segment's tempo has three pieces: it blends in at `speed` (the outgoing track's tempo) until
-- its drop, then eases linearly back to its own tempo over Balance.Transition.tempoReturnBars,
-- then plays at its own tempo.

local Balance = require(script.Parent.Parent.Config.Balance)
local Crossfade = require(script.Parent.Crossfade)
local TrackInfo = require(script.Parent.TrackInfo)
local Types = require(script.Parent.Parent.Types)

local MixTimeline = {}

export type Tracks = { [string]: Types.Track }

-- One audible segment at a moment.
export type Layer = {
	segment: Types.MixSegment,
	track: Types.Track,
	beat: number, -- beats from the track's first downbeat
	speed: number, -- playback speed
	gain: number, -- 0..1, equal-power during blends and fades
	bass: number, -- 1 = full bass, 0 = cut (the bass swap)
}

-- A drop moment in the mix.
export type Drop = {
	time: number,
	n: number, -- the segment it belongs to
	beat: number,
}

local function easeSeconds(segment: Types.MixSegment, track: Types.Track): number
	if segment.speed == 1 then
		return 0
	end
	return Balance.Transition.tempoReturnBars * 4 * 60 / track.bpm
end

-- Beats per second at the track's own tempo.
local function nativeRate(track: Types.Track): number
	return track.bpm / 60
end

function MixTimeline.dropTime(segment: Types.MixSegment, track: Types.Track): number
	return segment.startTime + (segment.dropBeat - segment.fromBeat) / (nativeRate(track) * segment.speed)
end

-- Beats the ease back to the track's own tempo takes.
local function easeBeats(segment: Types.MixSegment, track: Types.Track): number
	return nativeRate(track) * easeSeconds(segment, track) * (segment.speed + 1) / 2
end

function MixTimeline.beatAt(segment: Types.MixSegment, track: Types.Track, time: number): number
	local dropTime = MixTimeline.dropTime(segment, track)
	if time <= dropTime then
		return segment.fromBeat + (time - segment.startTime) * nativeRate(track) * segment.speed
	end
	local into = time - dropTime
	local ease = easeSeconds(segment, track)
	if into < ease then
		local s0 = segment.speed
		return segment.dropBeat + nativeRate(track) * (s0 * into + (1 - s0) * into * into / (2 * ease))
	end
	return segment.dropBeat + easeBeats(segment, track) + (into - ease) * nativeRate(track)
end

function MixTimeline.timeAt(segment: Types.MixSegment, track: Types.Track, beat: number): number
	local dropTime = MixTimeline.dropTime(segment, track)
	if beat <= segment.dropBeat then
		return segment.startTime + (beat - segment.fromBeat) / (nativeRate(track) * segment.speed)
	end
	local into = beat - segment.dropBeat
	local ease = easeSeconds(segment, track)
	local eased = easeBeats(segment, track)
	if into < eased then
		-- Solve rate * (s0 τ + (1 - s0) τ² / (2 ease)) = into for τ, in the form that stays stable
		-- when the speed hardly changes.
		local a = nativeRate(track) * (1 - segment.speed) / (2 * ease)
		local b = nativeRate(track) * segment.speed
		return dropTime + 2 * into / (b + math.sqrt(math.max(0, b * b + 4 * a * into)))
	end
	return dropTime + ease + (into - eased) / nativeRate(track)
end

function MixTimeline.speedAt(segment: Types.MixSegment, track: Types.Track, time: number): number
	local into = time - MixTimeline.dropTime(segment, track)
	if into <= 0 then
		return segment.speed
	end
	local ease = easeSeconds(segment, track)
	if into < ease then
		return segment.speed + (1 - segment.speed) * into / ease
	end
	return 1
end

-- The beat the segment stops at: set when the next one is planned, else the track's safe end.
function MixTimeline.endBeat(segment: Types.MixSegment, track: Types.Track): number
	return segment.endBeat or TrackInfo.safeEndBeat(track)
end

function MixTimeline.endTime(segment: Types.MixSegment, track: Types.Track): number
	return MixTimeline.timeAt(segment, track, MixTimeline.endBeat(segment, track))
end

function MixTimeline.outTime(segment: Types.MixSegment, track: Types.Track): number
	return MixTimeline.timeAt(segment, track, segment.outBeat)
end

-- Seconds into the audio file at a beat.
function MixTimeline.trackTime(track: Types.Track, beat: number): number
	return track.firstBeat + beat * 60 / track.bpm
end

local function progress(time: number, from: number, to: number): number
	if to <= from then
		return if time >= to then 1 else 0
	end
	return math.clamp((time - from) / (to - from), 0, 1)
end

-- Every segment audible at `time`, oldest first, and the one in charge of the moment (it has the
-- bass): lights, guests, drops and the track title follow it.
function MixTimeline.at(plan: { Types.MixSegment }, tracks: Tracks, time: number): ({ Layer }, Layer?)
	local layers: { Layer } = {}
	local main: Layer? = nil
	local swapAt = Balance.Transition.bassSwapAt
	for index, segment in plan do
		local track = tracks[segment.trackId]
		if not track or time < segment.startTime or time >= MixTimeline.endTime(segment, track) then
			continue
		end
		local gain, bass = 1, 1

		-- Coming in on a blend: equal-power gain up, bass in at the swap.
		if segment.mixIn == "sync" then
			local p = progress(time, segment.startTime, MixTimeline.dropTime(segment, track))
			if p < 1 then
				local _, incoming = Crossfade.gains(p)
				gain = incoming
				bass = if p >= swapAt then 1 else 0
			end
		end

		-- Going out: down with the next segment's blend, or a short fade before it starts.
		local following = plan[index + 1]
		local followingTrack = if following then tracks[following.trackId] else nil
		if following and followingTrack then
			local outTime = MixTimeline.outTime(segment, track)
			if time >= outTime then
				local q = if following.mixIn == "sync"
					then progress(time, following.startTime, MixTimeline.dropTime(following, followingTrack))
					else progress(time, outTime, MixTimeline.endTime(segment, track))
				local outgoing = Crossfade.gains(q)
				gain *= outgoing
				if following.mixIn == "sync" and q >= swapAt then
					bass = 0
				end
			end
		end

		local layer: Layer = {
			segment = segment,
			track = track,
			beat = MixTimeline.beatAt(segment, track, time),
			speed = MixTimeline.speedAt(segment, track, time),
			gain = gain,
			bass = bass,
		}
		table.insert(layers, layer)
		if bass > 0 then
			main = layer
		end
	end
	if not main then
		main = layers[#layers]
	end
	return layers, main
end

-- Every drop in the plan, in order: the drop each segment comes in on, plus any later drop it
-- plays before it mixes out.
function MixTimeline.drops(plan: { Types.MixSegment }, tracks: Tracks): { Drop }
	local drops: { Drop } = {}
	for _, segment in plan do
		local track = tracks[segment.trackId]
		if not track then
			continue
		end
		for _, section in track.sections do
			if
				section.kind == "drop"
				and section.startBeat >= segment.dropBeat
				and section.startBeat <= segment.outBeat
			then
				table.insert(drops, {
					time = MixTimeline.timeAt(segment, track, section.startBeat),
					n = segment.n,
					beat = section.startBeat,
				})
			end
		end
	end
	table.sort(drops, function(a, b)
		return a.time < b.time
	end)
	return drops
end

-- The first drop at or after `time`.
function MixTimeline.nextDrop(drops: { Drop }, time: number): Drop?
	for _, drop in drops do
		if drop.time >= time then
			return drop
		end
	end
	return nil
end

-- The drop closest to `time`, and how far from it `time` is (positive = after the drop).
function MixTimeline.nearestDrop(drops: { Drop }, time: number): (Drop?, number)
	local best: Drop? = nil
	local bestOffset = math.huge
	for _, drop in drops do
		local offset = time - drop.time
		if math.abs(offset) < math.abs(bestOffset) then
			best, bestOffset = drop, offset
		end
	end
	return best, bestOffset
end

return MixTimeline
