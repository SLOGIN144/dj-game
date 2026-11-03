--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local TrackExport = require(StarterPlayer.StarterPlayerScripts.TrackTagger.TrackExport)
local Types = require(ReplicatedStorage.Shared.Types)
local T = require(script.Parent.TestUtil)

local function sampleTrack(): Types.Track
	return {
		id = "deep_sunrise",
		assetId = 1234567,
		title = "Deep Sunrise",
		artist = "Test Artist",
		genre = "house",
		bpm = 124,
		firstBeat = 0.48,
		sections = {
			{ kind = "intro", startBeat = 0 },
			{ kind = "build", startBeat = 64 },
			{ kind = "drop", startBeat = 96 },
		},
		cuePoint = 0,
		energy = 3,
		tier = 1,
		price = 250,
	}
end

local EXPECTED = table.concat({
	"{",
	'\tid = "deep_sunrise",',
	"\tassetId = 1234567,",
	'\ttitle = "Deep Sunrise",',
	'\tartist = "Test Artist",',
	'\tgenre = "house",',
	"\tbpm = 124,",
	"\tfirstBeat = 0.48,",
	"\tsections = {",
	'\t\t{ kind = "intro", startBeat = 0 },',
	'\t\t{ kind = "build", startBeat = 64 },',
	'\t\t{ kind = "drop", startBeat = 96 },',
	"\t},",
	"\tcuePoint = 0,",
	"\tenergy = 3,",
	"\ttier = 1,",
	"\tprice = 250,",
	"},",
}, "\n")

return {
	["toLua writes the Tracks.luau entry format"] = function()
		T.equal(TrackExport.toLua(sampleTrack()), EXPECTED)
	end,

	["toLua keeps up to 2 BPM decimals and 3 offset decimals"] = function()
		local track = sampleTrack()
		track.bpm = 122.5
		track.firstBeat = 0.1234
		local text = TrackExport.toLua(track)
		T.truthy(string.find(text, "bpm = 122.5,", 1, true), "bpm")
		T.truthy(string.find(text, "firstBeat = 0.123,", 1, true), "firstBeat")
	end,

	["toLua escapes quotes in titles"] = function()
		local track = sampleTrack()
		track.title = 'Say "Hey"'
		T.truthy(string.find(TrackExport.toLua(track), 'title = "Say \\"Hey\\"",', 1, true))
	end,

	["makeId turns a title into snake_case"] = function()
		T.equal(TrackExport.makeId("Deep Sunrise (Original Mix)"), "deep_sunrise_original_mix")
		T.equal(TrackExport.makeId("  Café 2000!  "), "caf_2000")
	end,

	["a complete track has no warnings"] = function()
		T.equal(#TrackExport.validate(sampleTrack()), 0)
	end,

	["validate lists what is missing or off"] = function()
		local track = sampleTrack()
		track.assetId = 0
		track.sections = { { kind = "intro", startBeat = 2 } }
		track.energy = 7
		local warnings = TrackExport.validate(track)
		local text = table.concat(warnings, "\n")
		T.truthy(string.find(text, "assetId", 1, true), "assetId warning")
		T.truthy(string.find(text, "beat 0", 1, true), "first section warning")
		T.truthy(string.find(text, "not on a bar", 1, true), "bar warning")
		T.truthy(string.find(text, "drop", 1, true), "drop warning")
		T.truthy(string.find(text, "energy", 1, true), "energy warning")
	end,
}
