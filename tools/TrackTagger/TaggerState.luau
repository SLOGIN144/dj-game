--!strict
-- Everything the tagger knows about the track being tagged: taps, the beat grid, sections and cue.
-- Pure logic with no Roblox instances, so it can be tested without audio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeatMath = require(ReplicatedStorage.Shared.Util.BeatMath)
local TapTempo = require(script.Parent.TapTempo)
local Types = require(ReplicatedStorage.Shared.Types)

local TaggerState = {}

export type State = {
	taps: { number },
	tapping: boolean, -- false after a seek: the next tap starts a fresh tap session
	roundBpm: boolean,
	fit: TapTempo.Fit?,
	firstBeat: number?, -- seconds to the first downbeat
	sections: { Types.Section },
	cuePoint: number, -- beats
}

-- The parts of a track entry typed into the tagger's text boxes.
export type Meta = {
	id: string,
	assetId: number,
	title: string,
	artist: string,
	genre: string,
	energy: number,
	tier: number,
	price: number,
}

function TaggerState.new(): State
	return {
		taps = {},
		tapping = false,
		roundBpm = true,
		fit = nil,
		firstBeat = nil,
		sections = {},
		cuePoint = 0,
	}
end

local function refit(state: State)
	state.fit = TapTempo.fit(state.taps, state.roundBpm)
end

function TaggerState.addTap(state: State, time: number)
	if not state.tapping then
		state.taps = {}
		state.tapping = true
	end
	table.insert(state.taps, time)
	refit(state)
end

-- Seeking breaks the run of beats, so taps after a seek replace the old ones. The current BPM stays.
function TaggerState.endTapSession(state: State)
	state.tapping = false
end

function TaggerState.resetTaps(state: State)
	state.taps = {}
	state.tapping = false
	state.fit = nil
end

function TaggerState.toggleRounding(state: State)
	state.roundBpm = not state.roundBpm
	refit(state)
end

-- Where beat 0 sits: the marked downbeat, or the tap grid until a downbeat is marked.
function TaggerState.gridOrigin(state: State): number?
	if state.firstBeat then
		return state.firstBeat
	end
	return if state.fit then state.fit.anchor else nil
end

function TaggerState.beatAt(state: State, time: number): number?
	local fit, origin = state.fit, TaggerState.gridOrigin(state)
	if not fit or not origin then
		return nil
	end
	return BeatMath.timeToBeat(time, fit.bpm, origin)
end

-- Marks the downbeat nearest `time` on the tap grid, then moves it back by whole bars
-- to the first downbeat in the track. Returns false when there is no BPM yet.
function TaggerState.markDownbeat(state: State, time: number): boolean
	local fit = state.fit
	if not fit then
		return false
	end
	local downbeat = TapTempo.snapToGrid(fit, time)
	local barLength = BeatMath.beatLength(fit.bpm) * BeatMath.BEATS_PER_BAR
	state.firstBeat = downbeat - math.floor(downbeat / barLength) * barLength
	return true
end

function TaggerState.nudgeDownbeat(state: State, seconds: number)
	if state.firstBeat then
		state.firstBeat = math.max(0, state.firstBeat + seconds)
	end
end

-- Where an arrow-key jump lands: snapped to the beat grid, then one bar (or one beat when `fine`)
-- earlier or later. Returns nil when there is no grid yet.
function TaggerState.jumpTarget(state: State, time: number, direction: number, fine: boolean): number?
	local fit, origin = state.fit, TaggerState.gridOrigin(state)
	if not fit or not origin then
		return nil
	end
	local beat = BeatMath.timeToBeat(time, fit.bpm, origin)
	local target = if fine
		then math.round(beat) + direction
		else BeatMath.snapToBar(beat) + direction * BeatMath.BEATS_PER_BAR
	return BeatMath.beatToTime(target, fit.bpm, origin)
end

-- The bar start nearest `time`, in beats, or nil before the grid is set.
local function barAt(state: State, time: number): number?
	if not state.firstBeat then
		return nil
	end
	local beat = TaggerState.beatAt(state, time)
	return if beat then math.max(0, BeatMath.snapToBar(beat)) else nil
end

-- Marks a section on the bar nearest `time`. Marking a bar that already has a section changes its kind.
function TaggerState.markSection(state: State, kind: Types.SectionKind, time: number): boolean
	local bar = barAt(state, time)
	if not bar then
		return false
	end
	for _, section in state.sections do
		if section.startBeat == bar then
			section.kind = kind
			return true
		end
	end
	table.insert(state.sections, { kind = kind, startBeat = bar })
	table.sort(state.sections, function(a, b)
		return a.startBeat < b.startBeat
	end)
	return true
end

-- Removes the section the playhead is in (the last one starting at or before the nearest bar).
function TaggerState.removeSectionAt(state: State, time: number): boolean
	local bar = barAt(state, time)
	if not bar then
		return false
	end
	for i = #state.sections, 1, -1 do
		if state.sections[i].startBeat <= bar then
			table.remove(state.sections, i)
			return true
		end
	end
	return false
end

function TaggerState.setCue(state: State, time: number): boolean
	local bar = barAt(state, time)
	if not bar then
		return false
	end
	state.cuePoint = bar
	return true
end

-- The finished entry, or nil until there is a BPM and a downbeat.
function TaggerState.toTrack(state: State, meta: Meta): Types.Track?
	local fit, firstBeat = state.fit, state.firstBeat
	if not fit or not firstBeat then
		return nil
	end
	return {
		id = meta.id,
		assetId = meta.assetId,
		title = meta.title,
		artist = meta.artist,
		genre = meta.genre,
		bpm = fit.bpm,
		firstBeat = firstBeat,
		sections = table.clone(state.sections),
		cuePoint = state.cuePoint,
		energy = meta.energy,
		tier = meta.tier,
		price = meta.price,
	}
end

return TaggerState
