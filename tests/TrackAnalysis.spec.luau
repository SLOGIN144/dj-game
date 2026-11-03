--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local Tagger = StarterPlayer.StarterPlayerScripts.TrackTagger
local AudioFeatures = require(Tagger.AudioFeatures)
local GridDetect = require(Tagger.GridDetect)
local SectionDetect = require(Tagger.SectionDetect)
local TrackAnalysis = require(Tagger.TrackAnalysis)
local SyntheticTrack = require(script.Parent.SyntheticTrack)
local T = require(script.Parent.TestUtil)

local RATE = SyntheticTrack.SAMPLE_RATE

local function analyse(samples: { number }): TrackAnalysis.Result?
	local accumulator = AudioFeatures.new(RATE)
	-- Push in uneven chunks, the way the tagger receives audio from Roblox.
	local position = 1
	while position <= #samples do
		local chunk = table.move(samples, position, math.min(position + 7999, #samples), 1, {})
		AudioFeatures.push(accumulator, chunk)
		position += 8000
	end
	return TrackAnalysis.analyse(AudioFeatures.finish(accumulator))
end

-- A typical club track: 124 BPM, first kick 0.37 s in, intro / build / drop / breakdown / build / drop / outro.
local CLUB = analyse(SyntheticTrack.render(124, 0.37, {
	{ kind = "intro", bars = 16 },
	{ kind = "build", bars = 8 },
	{ kind = "drop", bars = 16 },
	{ kind = "breakdown", bars = 16 },
	{ kind = "build", bars = 8 },
	{ kind = "drop", bars = 16 },
	{ kind = "outro", bars = 8 },
}))

-- A track with a non-whole tempo and a later first beat.
local ODD = analyse(SyntheticTrack.render(127.5, 1.1, {
	{ kind = "intro", bars = 8 },
	{ kind = "drop", bars = 16 },
	{ kind = "breakdown", bars = 8 },
	{ kind = "drop", bars = 8 },
}))

return {
	["finds a whole-number BPM exactly"] = function()
		assert(CLUB, "no analysis")
		T.equal(CLUB.grid.bpm, 124)
	end,

	["finds the first downbeat within 12 ms"] = function()
		assert(CLUB, "no analysis")
		T.near(CLUB.grid.firstBeat, 0.37, 0.012)
	end,

	["the grid does not drift over the track"] = function()
		assert(CLUB, "no analysis")
		T.truthy(CLUB.grid.driftMs < 10, "drift " .. CLUB.grid.driftMs .. " ms")
	end,

	["finds the sections"] = function()
		assert(CLUB, "no analysis")
		local found = {}
		for _, section in CLUB.sections do
			table.insert(found, section.kind .. " " .. section.startBeat)
		end
		T.equal(table.concat(found, ", "), "intro 0, build 64, drop 96, breakdown 160, build 224, drop 256, outro 320")
	end,

	["sets the cue on the first kick and energy from the tempo"] = function()
		assert(CLUB, "no analysis")
		T.equal(CLUB.cuePoint, 0)
		T.equal(CLUB.energy, 3)
	end,

	["draws a waveform overview"] = function()
		assert(CLUB, "no analysis")
		T.equal(#CLUB.waveform, TrackAnalysis.WAVEFORM_POINTS)
		T.truthy(math.max(table.unpack(CLUB.waveform)) > 0.5, "waveform too quiet")
	end,

	["keeps two decimals for a non-whole BPM"] = function()
		assert(ODD, "no analysis")
		T.near(ODD.grid.bpm, 127.5, 0.02)
		T.near(ODD.grid.firstBeat, 1.1, 0.012)
	end,

	["both downbeat clues agree on the club track"] = function()
		assert(CLUB, "no analysis")
		T.equal(CLUB.grid.downbeatMethod, "section changes and first kick agree")
	end,

	["the first kick decides the downbeat when section changes are unclear"] = function()
		local offset = GridDetect.chooseDownbeat(3, 0.38, 0)
		T.equal(offset, 0)
	end,

	["clear section changes overrule the first kick"] = function()
		local offset = GridDetect.chooseDownbeat(2, 0.8, 0)
		T.equal(offset, 2)
		T.equal((GridDetect.chooseDownbeat(1, 0.2, nil)), 1)
	end,

	["a short dip inside a drop stays part of the drop"] = function()
		local loud = { kick = true, level = -10 }
		local groove = { kick = true, level = -20 }
		local quiet = { kick = false, level = -25 }
		local labels =
			SectionDetect.labelBlocks({ groove, groove, quiet, quiet, loud, loud, groove, loud, loud, groove })
		T.equal(table.concat(labels, " "), "intro intro build build drop drop drop drop drop outro")
	end,

	["single loud blocks in a breakdown don't join it to the drops"] = function()
		local loud = { kick = true, level = -10 }
		local groove = { kick = true, level = -20 }
		local quiet = { kick = false, level = -25 }
		local labels =
			SectionDetect.labelBlocks({ groove, loud, loud, quiet, loud, quiet, loud, quiet, loud, loud, groove })
		T.equal(table.concat(labels, " "), "intro drop drop breakdown breakdown breakdown build build drop drop outro")
	end,

	["silence gives no analysis"] = function()
		local accumulator = AudioFeatures.new(RATE)
		AudioFeatures.push(accumulator, table.create(RATE * 30, 0))
		T.equal(TrackAnalysis.analyse(AudioFeatures.finish(accumulator)), nil)
	end,
}
