--!strict
-- Plans a plot's nonstop mix from the tagged track data: which owned track plays next, when it
-- starts and how it comes in. The next track starts 8 bars before its drop and blends in over
-- those 8 bars, so its drop lands as the blend ends. Tracks within ±8% tempo blend in sync (the
-- incoming one plays at the outgoing tempo, then eases back); tracks further apart get a short
-- fade instead. Pure and seeded: the server plans, clients only read the plan.

local Balance = require(script.Parent.Parent.Config.Balance)
local MixTimeline = require(script.Parent.MixTimeline)
local Rng = require(script.Parent.Parent.Util.Rng)
local TrackInfo = require(script.Parent.TrackInfo)
local TransitionPlanner = require(script.Parent.TransitionPlanner)
local Types = require(script.Parent.Parent.Types)

local MixPlanner = {}

-- Plans are replicated as text, so times are kept to the millisecond and speeds to 1e-6.
local function roundTime(time: number): number
	return math.round(time * 1000) / 1000
end

local function roundSpeed(speed: number): number
	return math.round(speed * 1e6) / 1e6
end

function MixPlanner.inTempoRange(fromBpm: number, toBpm: number): boolean
	return math.abs(fromBpm / toBpm - 1) <= Balance.Transition.tempoRange
end

-- The next track to play after `current`: never the same one twice in a row when there's another,
-- preferably none of the `recent` ones, and preferably one in tempo range so it can blend in sync.
function MixPlanner.chooseNext(
	current: Types.Track?,
	owned: { Types.Track },
	recent: { string },
	rng: Rng.Rng
): Types.Track
	assert(#owned > 0, "a mix needs at least one track")
	local pool = {}
	for _, track in owned do
		if not current or track.id ~= current.id then
			table.insert(pool, track)
		end
	end
	if #pool == 0 then
		return owned[1]
	end

	local fresh = {}
	for _, track in pool do
		if not table.find(recent, track.id) then
			table.insert(fresh, track)
		end
	end
	if #fresh > 0 then
		pool = fresh
	end

	if current then
		local inRange = {}
		for _, track in pool do
			if MixPlanner.inTempoRange(current.bpm, track.bpm) then
				table.insert(inRange, track)
			end
		end
		if #inRange > 0 then
			pool = inRange
		end
	end

	return pool[rng:nextInt(#pool)]
end

-- Where a segment mixes out: on a phrase once it has played its drop for a while, and early
-- enough that its blend out ends before the track does.
local function outBeat(track: Types.Track, fromBeat: number, dropBeat: number): number
	local beat = TransitionPlanner.mixOutBeat(track, dropBeat, fromBeat, TrackInfo.safeEndBeat(track))
	return math.max(beat, dropBeat)
end

-- A plot's first track: it starts 8 bars before its first usable drop, at its own tempo.
function MixPlanner.start(track: Types.Track, startTime: number): Types.MixSegment
	local fromBeat, dropBeat = TransitionPlanner.entry(track)
	return {
		n = 1,
		trackId = track.id,
		startTime = roundTime(startTime),
		fromBeat = fromBeat,
		dropBeat = dropBeat,
		speed = 1,
		mixIn = "start",
		outBeat = outBeat(track, fromBeat, dropBeat),
	}
end

-- The segment after `previous`, playing `nextTrack`. Also sets where `previous` stops.
function MixPlanner.follow(
	previous: Types.MixSegment,
	previousTrack: Types.Track,
	nextTrack: Types.Track
): Types.MixSegment
	local fromBeat, dropBeat = TransitionPlanner.entry(nextTrack)
	local outTime = MixTimeline.outTime(previous, previousTrack)
	local outTempo = previousTrack.bpm * MixTimeline.speedAt(previous, previousTrack, outTime)

	local segment: Types.MixSegment = {
		n = previous.n + 1,
		trackId = nextTrack.id,
		startTime = 0,
		fromBeat = fromBeat,
		dropBeat = dropBeat,
		speed = 1,
		mixIn = "sync",
		outBeat = outBeat(nextTrack, fromBeat, dropBeat),
	}
	if MixPlanner.inTempoRange(outTempo, nextTrack.bpm) then
		-- Blend in sync: the incoming track starts on the outgoing one's phrase at its tempo.
		previous.endBeat = previous.outBeat + TransitionPlanner.blendBeats()
		segment.startTime = roundTime(outTime)
		segment.speed = roundSpeed(outTempo / nextTrack.bpm)
	else
		-- Too far apart to blend: fade the outgoing track out, then start the next one.
		previous.endBeat = previous.outBeat + Balance.Transition.fadeBars * 4
		segment.startTime = roundTime(MixTimeline.endTime(previous, previousTrack))
		segment.mixIn = "fade"
	end
	return segment
end

-- The track ids of the last `count` segments, newest last.
local function recentIds(plan: { Types.MixSegment }, count: number): { string }
	local ids = {}
	for index = math.max(1, #plan - count + 1), #plan do
		table.insert(ids, plan[index].trackId)
	end
	return ids
end

-- Adds segments until the last planned transition starts at or after `untilTime`. Returns whether
-- anything was added. `owned` must be in a stable order (the order of Config/Tracks).
function MixPlanner.extend(
	plan: { Types.MixSegment },
	tracks: MixTimeline.Tracks,
	owned: { Types.Track },
	rng: Rng.Rng,
	untilTime: number
): boolean
	local added = false
	while #plan > 0 do
		local last = plan[#plan]
		local lastTrack = tracks[last.trackId]
		if not lastTrack or MixTimeline.outTime(last, lastTrack) >= untilTime then
			break
		end
		local nextTrack = MixPlanner.chooseNext(lastTrack, owned, recentIds(plan, Balance.Mix.recentTracks), rng)
		table.insert(plan, MixPlanner.follow(last, lastTrack, nextTrack))
		added = true
	end
	return added
end

-- Drops segments that finished before `time`, keeping the newest finished one so the next choice
-- still knows what played. Returns whether anything was removed.
function MixPlanner.trim(plan: { Types.MixSegment }, tracks: MixTimeline.Tracks, time: number): boolean
	local removed = false
	while #plan > 2 do
		local second = plan[2]
		local secondTrack = tracks[second.trackId]
		if not secondTrack or MixTimeline.endTime(second, secondTrack) >= time then
			break
		end
		table.remove(plan, 1)
		removed = true
	end
	return removed
end

-- The plan as text for a plot attribute, and back. `decode` returns nil for anything malformed.
function MixPlanner.encode(plan: { Types.MixSegment }): string
	local HttpService = game:GetService("HttpService")
	return HttpService:JSONEncode(plan)
end

local MIX_INS = { start = true, sync = true, fade = true }

function MixPlanner.decode(text: string): { Types.MixSegment }?
	local HttpService = game:GetService("HttpService")
	local ok, value = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if not ok or typeof(value) ~= "table" then
		return nil
	end
	local plan: { Types.MixSegment } = {}
	for _, entry in value :: { any } do
		if
			typeof(entry) ~= "table"
			or typeof(entry.n) ~= "number"
			or typeof(entry.trackId) ~= "string"
			or typeof(entry.startTime) ~= "number"
			or typeof(entry.fromBeat) ~= "number"
			or typeof(entry.dropBeat) ~= "number"
			or typeof(entry.speed) ~= "number"
			or entry.speed <= 0
			or typeof(entry.outBeat) ~= "number"
			or not MIX_INS[entry.mixIn]
			or (entry.endBeat ~= nil and typeof(entry.endBeat) ~= "number")
		then
			return nil
		end
		table.insert(plan, {
			n = entry.n,
			trackId = entry.trackId,
			startTime = entry.startTime,
			fromBeat = entry.fromBeat,
			dropBeat = entry.dropBeat,
			speed = entry.speed,
			mixIn = entry.mixIn,
			outBeat = entry.outBeat,
			endBeat = entry.endBeat,
		})
	end
	return plan
end

return MixPlanner
