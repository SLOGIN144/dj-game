--!strict
-- Small questions about a tagged track's sections.

local Types = require(script.Parent.Parent.Types)

local TrackInfo = {}

-- The section playing at `beat` (the first one before the track's first section).
function TrackInfo.sectionAt(track: Types.Track, beat: number): Types.Section
	local current = track.sections[1]
	for _, section in track.sections do
		if section.startBeat <= beat then
			current = section
		else
			break
		end
	end
	return current
end

-- The first drop starting at or after `beat`.
function TrackInfo.firstDropFrom(track: Types.Track, beat: number): number?
	for _, section in track.sections do
		if section.kind == "drop" and section.startBeat >= beat then
			return section.startBeat
		end
	end
	return nil
end

-- Where section `index` ends: the next section's start, or `lengthBeats` for the last one.
function TrackInfo.sectionEnd(track: Types.Track, index: number, lengthBeats: number): number
	local nextSection = track.sections[index + 1]
	return if nextSection then nextSection.startBeat else lengthBeats
end

return TrackInfo
