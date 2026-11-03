--!strict
-- Runs the automatic analysis on the loaded track: streams its audio from Roblox into
-- AudioFeatures chunk by chunk, then hands the features to TrackAnalysis. Yields for several
-- seconds (about 1 s per 30 s of audio).

local AudioFeatures = require(script.Parent.AudioFeatures)
local TrackAnalysis = require(script.Parent.TrackAnalysis)
local TrackPlayer = require(script.Parent.TrackPlayer)

local AutoTag = {}

AutoTag.SAMPLE_RATE = 4000 -- plenty for kicks and bass; a higher rate only makes reading slower

-- Returns the analysis, or nil and a reason. `isCancelled` lets a newer load stop this one.
function AutoTag.run(
	track: TrackPlayer.TrackPlayer,
	onProgress: (number) -> (),
	isCancelled: () -> boolean
): (TrackAnalysis.Result?, string?)
	local accumulator = AudioFeatures.new(AutoTag.SAMPLE_RATE)
	local complete = track:streamWaveform(AutoTag.SAMPLE_RATE, function(samples, progress)
		AudioFeatures.push(accumulator, samples)
		onProgress(progress)
		return not isCancelled()
	end)
	if isCancelled() then
		return nil, "cancelled"
	elseif not complete then
		return nil, "Roblox didn't give us this track's audio"
	end
	local result = TrackAnalysis.analyse(AudioFeatures.finish(accumulator))
	if not result then
		return nil, "no steady beat found"
	end
	return result, nil
end

return AutoTag
