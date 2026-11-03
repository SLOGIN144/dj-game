--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local TaggerState = require(StarterPlayer.StarterPlayerScripts.TrackTagger.TaggerState)
local T = require(script.Parent.TestUtil)

local BPM = 124
local BEAT = 60 / BPM
local FIRST = 0.48

-- A state with 16 perfect taps at 124 BPM starting on the first downbeat.
local function tapped(): TaggerState.State
	local state = TaggerState.new()
	for i = 0, 15 do
		TaggerState.addTap(state, FIRST + i * BEAT)
	end
	return state
end

local function withDownbeat(): TaggerState.State
	local state = tapped()
	TaggerState.markDownbeat(state, FIRST + 0.01)
	return state
end

local META: TaggerState.Meta = {
	id = "deep_sunrise",
	assetId = 1234567,
	title = "Deep Sunrise",
	artist = "Test Artist",
	genre = "house",
	energy = 3,
	tier = 1,
	price = 250,
}

return {
	["taps produce a BPM"] = function()
		local state = tapped()
		assert(state.fit, "no fit")
		T.equal(state.fit.bpm, BPM)
	end,

	["a tap after a seek starts a fresh tap session"] = function()
		local state = tapped()
		TaggerState.endTapSession(state)
		TaggerState.addTap(state, 100)
		T.equal(#state.taps, 1)
		T.equal(state.fit, nil)
	end,

	["the downbeat needs a BPM first"] = function()
		local state = TaggerState.new()
		T.equal(TaggerState.markDownbeat(state, 1), false)
		T.equal(state.firstBeat, nil)
	end,

	["the downbeat snaps to the tapped grid"] = function()
		local state = withDownbeat()
		T.near(state.firstBeat, FIRST, 1e-6)
	end,

	["a downbeat marked later moves back to the first bar"] = function()
		local state = tapped()
		TaggerState.markDownbeat(state, FIRST + 32 * BEAT - 0.02)
		T.near(state.firstBeat, FIRST, 1e-6)
	end,

	["nudging moves the downbeat in seconds"] = function()
		local state = withDownbeat()
		TaggerState.nudgeDownbeat(state, 0.005)
		T.near(state.firstBeat, FIRST + 0.005, 1e-9)
	end,

	["sections snap to the nearest bar"] = function()
		local state = withDownbeat()
		TaggerState.markSection(state, "drop", FIRST + 95.3 * BEAT)
		T.equal(state.sections[1].startBeat, 96)
	end,

	["marking the same bar again replaces the kind"] = function()
		local state = withDownbeat()
		TaggerState.markSection(state, "build", FIRST + 64 * BEAT)
		TaggerState.markSection(state, "drop", FIRST + 64.4 * BEAT)
		T.equal(#state.sections, 1)
		T.equal(state.sections[1].kind, "drop")
	end,

	["sections stay sorted by beat"] = function()
		local state = withDownbeat()
		TaggerState.markSection(state, "drop", FIRST + 96 * BEAT)
		TaggerState.markSection(state, "intro", FIRST)
		TaggerState.markSection(state, "build", FIRST + 64 * BEAT)
		T.equal(state.sections[1].kind, "intro")
		T.equal(state.sections[2].kind, "build")
		T.equal(state.sections[3].kind, "drop")
	end,

	["removeSectionAt removes the section under the playhead"] = function()
		local state = withDownbeat()
		TaggerState.markSection(state, "intro", FIRST)
		TaggerState.markSection(state, "build", FIRST + 64 * BEAT)
		TaggerState.removeSectionAt(state, FIRST + 80 * BEAT)
		T.equal(#state.sections, 1)
		T.equal(state.sections[1].kind, "intro")
	end,

	["the cue point snaps to a bar"] = function()
		local state = withDownbeat()
		TaggerState.setCue(state, FIRST + 31 * BEAT)
		T.equal(state.cuePoint, 32)
	end,

	["arrow jumps land on the next bar line"] = function()
		local state = withDownbeat()
		T.near(TaggerState.jumpTarget(state, FIRST + 29.3 * BEAT, 1, false), FIRST + 32 * BEAT, 1e-6)
		T.near(TaggerState.jumpTarget(state, FIRST + 29.3 * BEAT, -1, false), FIRST + 24 * BEAT, 1e-6)
	end,

	["fine arrow jumps land on the next beat"] = function()
		local state = withDownbeat()
		T.near(TaggerState.jumpTarget(state, FIRST + 10.2 * BEAT, -1, true), FIRST + 9 * BEAT, 1e-6)
	end,

	["there is no jump target without a beat grid"] = function()
		T.equal(TaggerState.jumpTarget(TaggerState.new(), 5, 1, false), nil)
	end,

	["toTrack needs a BPM and a downbeat"] = function()
		T.equal(TaggerState.toTrack(tapped(), META), nil)
	end,

	["toTrack builds the full entry"] = function()
		local state = withDownbeat()
		TaggerState.markSection(state, "intro", FIRST)
		local track = TaggerState.toTrack(state, META)
		assert(track, "no track")
		T.equal(track.bpm, BPM)
		T.near(track.firstBeat, FIRST, 1e-6)
		T.equal(track.assetId, 1234567)
		T.equal(#track.sections, 1)
	end,
}
