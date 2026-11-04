--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local MixPlanner = require(Shared.Music.MixPlanner)
local MixTimeline = require(Shared.Music.MixTimeline)
local Rng = require(Shared.Util.Rng)
local TrackInfo = require(Shared.Music.TrackInfo)
local Tracks = require(Shared.Config.Tracks)
local Types = require(Shared.Types)
local T = require(script.Parent.TestUtil)

local function track(id: string, bpm: number, sections: { Types.Section }): Types.Track
	return {
		id = id,
		assetId = 1,
		title = id,
		artist = "Test",
		genre = "house",
		bpm = bpm,
		firstBeat = 0.25,
		sections = sections,
		cuePoint = 0,
		energy = 3,
		tier = 1,
		price = 0,
	}
end

local function sections(drops: { number }, length: number): { Types.Section }
	local list: { Types.Section } = { { kind = "intro", startBeat = 0 } }
	for _, drop in drops do
		table.insert(list, { kind = "build", startBeat = drop - 32 })
		table.insert(list, { kind = "drop", startBeat = drop })
	end
	table.insert(list, { kind = "outro", startBeat = length })
	return list
end

local A = track("a", 124, sections({ 64, 224 }, 320))
local B = track("b", 128, sections({ 64, 192 }, 352))
local C = track("c", 122, sections({ 96 }, 288))
local FAR = track("far", 140, sections({ 64 }, 320)) -- 13% faster than A: no synced blend
local TEST_TRACKS = TrackInfo.byId({ A, B, C, FAR })
local REAL_TRACKS = TrackInfo.byId(Tracks)

local NOW = 1000
local PHASE_LIMIT = 1 / 16 -- acceptance criterion: mixes stay within 1/16 beat
local BLEND = Balance.Transition.blendBars * 4

-- How far apart two beat positions are in phase, in beats (0..0.5).
local function phaseError(a: number, b: number): number
	local diff = (a - b) % 1
	return math.min(diff, 1 - diff)
end

local function realTracks(ids: { string }?): { Types.Track }
	local list = {}
	for _, entry in Tracks do
		if not ids or table.find(ids, entry.id) then
			table.insert(list, entry)
		end
	end
	return list
end

-- A plan covering `seconds` of the given owned tracks.
local function longPlan(owned: { Types.Track }, seed: number, seconds: number): { Types.MixSegment }
	local rng = Rng.new(seed)
	local plan = { MixPlanner.start(MixPlanner.chooseNext(nil, owned, {}, rng), NOW) }
	MixPlanner.extend(plan, REAL_TRACKS, owned, rng, NOW + seconds)
	return plan
end

return {
	-- Rng
	["seeded random numbers repeat and stay in range"] = function()
		local first, second = Rng.new(42), Rng.new(42)
		for _ = 1, 50 do
			local value = first:nextInt(7)
			T.equal(value, second:nextInt(7))
			T.truthy(value >= 1 and value <= 7, "in range")
		end
	end,

	-- Choosing the next track
	["the playing track never comes straight back when there's another"] = function()
		local rng = Rng.new(1)
		for _ = 1, 20 do
			T.equal(MixPlanner.chooseNext(A, { A, B }, {}, rng).id, "b")
		end
		T.equal(MixPlanner.chooseNext(A, { A }, {}, rng).id, "a", "a single track repeats")
	end,

	["recently played tracks wait when there's a choice"] = function()
		local rng = Rng.new(3)
		for _ = 1, 20 do
			T.equal(MixPlanner.chooseNext(A, { A, B, C }, { "b", "a" }, rng).id, "c")
		end
	end,

	["tracks in tempo range are preferred"] = function()
		local rng = Rng.new(5)
		for _ = 1, 20 do
			T.equal(MixPlanner.chooseNext(A, { A, FAR, B }, {}, rng).id, "b")
		end
	end,

	-- Planning
	["the first track starts 8 bars before its first usable drop"] = function()
		local segment = MixPlanner.start(A, NOW)
		T.equal(segment.fromBeat, 32)
		T.equal(segment.dropBeat, 64)
		T.equal(segment.speed, 1)
		T.equal(segment.mixIn, "start")
		T.near(MixTimeline.dropTime(segment, A), NOW + 32 * 60 / 124, 1e-6)
		T.equal(segment.outBeat % Balance.Transition.phraseBeats, 0, "mixes out on a phrase")
		T.truthy(segment.outBeat >= segment.dropBeat + Balance.Transition.playDropBars * 4, "plays its drop first")
	end,

	["a track in tempo range starts on the outgoing phrase at the outgoing tempo"] = function()
		local first = MixPlanner.start(A, NOW)
		local second = MixPlanner.follow(first, A, B)
		T.equal(second.mixIn, "sync")
		T.equal(second.n, 2)
		T.near(second.startTime, MixTimeline.outTime(first, A), 0.001)
		T.near(second.speed, 124 / 128, 1e-6)
		T.equal(first.endBeat, first.outBeat + BLEND)
	end,

	["the incoming drop lands exactly as the 8-bar blend ends"] = function()
		local first = MixPlanner.start(A, NOW)
		local second = MixPlanner.follow(first, A, B)
		local blendEnd = MixTimeline.outTime(first, A) + BLEND * 60 / 124
		T.near(MixTimeline.dropTime(second, B), blendEnd, 0.002)
		T.near(MixTimeline.endTime(first, A), blendEnd, 0.002, "the outgoing track stops as the drop lands")
	end,

	["both decks stay on the same beat through the blend"] = function()
		local first = MixPlanner.start(A, NOW)
		local second = MixPlanner.follow(first, A, B)
		local from, to = second.startTime, MixTimeline.dropTime(second, B)
		for step = 0, 20 do
			local time = from + (to - from) * step / 20
			local err = phaseError(MixTimeline.beatAt(first, A, time), MixTimeline.beatAt(second, B, time))
			T.truthy(err < 0.01, string.format("phase error %.4f beats at step %d", err, step))
		end
	end,

	["after its drop the new track eases back to its own tempo"] = function()
		local first = MixPlanner.start(A, NOW)
		local second = MixPlanner.follow(first, A, B)
		local drop = MixTimeline.dropTime(second, B)
		local ease = Balance.Transition.tempoReturnBars * 4 * 60 / B.bpm
		T.near(MixTimeline.speedAt(second, B, drop - 1), second.speed, 1e-9)
		T.near(MixTimeline.speedAt(second, B, drop + ease / 2), (second.speed + 1) / 2, 1e-9)
		T.near(MixTimeline.speedAt(second, B, drop + ease + 1), 1, 1e-9)
		-- The beat position has no jumps where the pieces meet.
		for _, edge in { drop, drop + ease } do
			local before = MixTimeline.beatAt(second, B, edge - 1e-4)
			local after = MixTimeline.beatAt(second, B, edge + 1e-4)
			T.near(after - before, 2e-4 * B.bpm / 60 * MixTimeline.speedAt(second, B, edge), 1e-4)
		end
	end,

	["beats and times convert back and forth in every piece of a segment"] = function()
		local first = MixPlanner.start(A, NOW)
		local second = MixPlanner.follow(first, A, B)
		for beat = second.fromBeat, second.outBeat + BLEND, 3.5 do
			local time = MixTimeline.timeAt(second, B, beat)
			T.near(MixTimeline.beatAt(second, B, time), beat, 1e-6, "beat " .. beat)
		end
	end,

	["a track too far apart in tempo fades in after a short fade out"] = function()
		local first = MixPlanner.start(A, NOW)
		local second = MixPlanner.follow(first, A, FAR)
		T.equal(second.mixIn, "fade")
		T.equal(second.speed, 1)
		T.equal(first.endBeat, first.outBeat + Balance.Transition.fadeBars * 4)
		T.near(second.startTime, MixTimeline.endTime(first, A), 0.001)
	end,

	["blends are equal-power and swap the bass halfway"] = function()
		local first = MixPlanner.start(A, NOW)
		local second = MixPlanner.follow(first, A, B)
		local plan = { first, second }
		local from, to = second.startTime, MixTimeline.dropTime(second, B)

		local layers, main = MixTimeline.at(plan, TEST_TRACKS, from + 0.01)
		T.equal(#layers, 2)
		T.near(layers[1].gain, 1, 0.01)
		T.near(layers[2].gain, 0, 0.01)
		T.equal(layers[2].bass, 0)
		T.equal((main :: MixTimeline.Layer).segment.n, 1)

		local swap = from + (to - from) * Balance.Transition.bassSwapAt
		layers, main = MixTimeline.at(plan, TEST_TRACKS, swap - 0.01)
		T.near(layers[1].gain ^ 2 + layers[2].gain ^ 2, 1, 1e-6, "equal power")
		T.equal((main :: MixTimeline.Layer).segment.n, 1, "the outgoing track leads until the swap")
		layers, main = MixTimeline.at(plan, TEST_TRACKS, swap + 0.01)
		T.equal(layers[1].bass, 0)
		T.equal(layers[2].bass, 1)
		T.equal((main :: MixTimeline.Layer).segment.n, 2, "the incoming track leads after the swap")

		layers, main = MixTimeline.at(plan, TEST_TRACKS, to + 0.01)
		T.equal(#layers, 1)
		T.near(layers[1].gain, 1, 1e-9)
		T.equal((main :: MixTimeline.Layer).segment.n, 2)
	end,

	-- Long plans with the real tagged tracks
	["the music never stops and every blend stays on the beat"] = function()
		local plan = longPlan(realTracks(), 11, 1800)
		local last = plan[#plan]
		T.truthy(MixTimeline.outTime(last, REAL_TRACKS[last.trackId]) >= NOW + 1800, "covers the time asked")
		for time = NOW, NOW + 1800, 0.5 do
			local layers = MixTimeline.at(plan, REAL_TRACKS, time)
			T.truthy(#layers > 0, "silence at " .. time)
			if #layers == 2 then
				local err = phaseError(layers[1].beat, layers[2].beat)
				T.truthy(err < PHASE_LIMIT, string.format("phase error %.4f beats at %.1f", err, time))
			end
		end
	end,

	["every track is done before its tagged sections run out"] = function()
		local plan = longPlan(realTracks(), 5, 3600)
		for index, segment in plan do
			T.equal(segment.n, index, "segments are numbered in order")
			local trackData = REAL_TRACKS[segment.trackId]
			if segment.endBeat then
				T.truthy(segment.endBeat <= TrackInfo.safeEndBeat(trackData), segment.trackId)
			end
			T.truthy(segment.speed >= 1 - Balance.Transition.tempoRange, "speed in range")
			T.truthy(segment.speed <= 1 + Balance.Transition.tempoRange, "speed in range")
		end
	end,

	["drops come about once every 1-2 minutes"] = function()
		for _, owned in { realTracks(), realTracks(Balance.Start.tracks) } do
			local plan = longPlan(owned, 9, 1800)
			local drops = MixTimeline.drops(plan, REAL_TRACKS)
			T.truthy(drops[1].time - NOW < 20, "the first drop comes within 20 s")
			local longest, total = 0, 0
			for index = 2, #drops do
				local gap = drops[index].time - drops[index - 1].time
				T.truthy(gap > 20, "drops aren't bunched up")
				longest = math.max(longest, gap)
				total += gap
			end
			local average = total / (#drops - 1)
			T.truthy(average >= 40 and average <= 100, string.format("average gap %.0f s", average))
			T.truthy(longest <= 120, string.format("longest gap %.0f s", longest))
		end
	end,

	["the nearest drop is found from either side"] = function()
		local plan = longPlan(realTracks(Balance.Start.tracks), 2, 300)
		local drops = MixTimeline.drops(plan, REAL_TRACKS)
		local drop, offset = MixTimeline.nearestDrop(drops, drops[2].time - 0.05)
		T.equal(drop, drops[2])
		T.near(offset, -0.05, 1e-9)
		T.equal(MixTimeline.nextDrop(drops, drops[2].time + 0.01), drops[3])
	end,

	["finished segments are trimmed but the newest finished one stays"] = function()
		local plan = longPlan(realTracks(), 4, 600)
		local count = #plan
		local third = plan[3]
		local endOfThird = MixTimeline.endTime(third, REAL_TRACKS[third.trackId])
		T.truthy(MixPlanner.trim(plan, REAL_TRACKS, endOfThird + 1))
		T.equal(plan[1].n, 3)
		T.equal(#plan, count - 2)
	end,

	["a plan survives the trip through a plot attribute"] = function()
		local plan = longPlan(realTracks(), 8, 300)
		local decoded = MixPlanner.decode(MixPlanner.encode(plan))
		T.truthy(decoded, "decodes")
		T.equal(#(decoded :: { Types.MixSegment }), #plan)
		for index, segment in plan do
			local copy = (decoded :: { Types.MixSegment })[index]
			T.equal(copy.trackId, segment.trackId)
			T.equal(copy.startTime, segment.startTime)
			T.equal(copy.speed, segment.speed)
			T.equal(copy.mixIn, segment.mixIn)
			T.equal(copy.endBeat, segment.endBeat)
		end
		T.equal(MixPlanner.decode("not json"), nil)
		T.equal(MixPlanner.decode('[{"n":1}]'), nil)
	end,
}
