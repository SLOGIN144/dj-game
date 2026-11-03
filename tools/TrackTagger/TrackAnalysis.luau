--!strict
-- Everything the tagger works out from a track's audio on its own: beat grid, sections, cue
-- point, a starting energy rating and a waveform overview. Pure logic; AutoTag feeds it audio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioFeatures = require(script.Parent.AudioFeatures)
local GridDetect = require(script.Parent.GridDetect)
local SectionDetect = require(script.Parent.SectionDetect)
local Types = require(ReplicatedStorage.Shared.Types)

local TrackAnalysis = {}

TrackAnalysis.WAVEFORM_POINTS = 400 -- columns in the waveform overview
-- Starting energy rating from tempo: 120 BPM -> 2, 124 -> 3, 128 -> 4, 132+ -> 5.
-- A first guess only; it is content, so retune it per track in Tracks.luau if it feels wrong.
TrackAnalysis.ENERGY_BASE_BPM = 112
TrackAnalysis.ENERGY_BPM_PER_STEP = 4

export type Result = {
	grid: GridDetect.Grid,
	sections: { Types.Section },
	cuePoint: number,
	energy: number,
	waveform: { number }, -- WAVEFORM_POINTS peak levels (0..1) across the whole track
}

local function waveformOverview(peaks: { number }): { number }
	local points = table.create(TrackAnalysis.WAVEFORM_POINTS, 0)
	local perPoint = #peaks / TrackAnalysis.WAVEFORM_POINTS
	for point = 1, TrackAnalysis.WAVEFORM_POINTS do
		local loudest = 0
		for frame = math.floor((point - 1) * perPoint) + 1, math.floor(point * perPoint) do
			loudest = math.max(loudest, peaks[frame] or 0)
		end
		points[point] = loudest
	end
	return points
end

function TrackAnalysis.energyFor(bpm: number): number
	return math.clamp(math.round((bpm - TrackAnalysis.ENERGY_BASE_BPM) / TrackAnalysis.ENERGY_BPM_PER_STEP), 1, 5)
end

-- Returns nil when the track has no steady beat to lock onto.
function TrackAnalysis.analyse(features: AudioFeatures.Features): Result?
	local grid = GridDetect.detect(features)
	if not grid then
		return nil
	end
	local found = SectionDetect.detect(features, grid)
	return {
		grid = grid,
		sections = found.sections,
		cuePoint = found.cuePoint,
		energy = TrackAnalysis.energyFor(grid.bpm),
		waveform = waveformOverview(features.peaks),
	}
end

return TrackAnalysis
