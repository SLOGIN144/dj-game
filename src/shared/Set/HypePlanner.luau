--!strict
-- Picks the hype challenges for the stretch of a track that plays between transitions:
--   * Release: on a build that leads into a drop, hold through the build and let go on the drop;
--   * Hit: one press on a phrase boundary inside a drop.
-- At most one challenge per section, kept apart so they never crowd each other.

local Balance = require(script.Parent.Parent.Config.Balance)
local TrackInfo = require(script.Parent.TrackInfo)
local Types = require(script.Parent.Parent.Types)

local HypePlanner = {}

export type Challenge = {
	kind: "hit" | "release",
	beat: number, -- the target beat (press for a Hit, let go for a Release)
	holdFrom: number?, -- Release only: the beat holding starts
}

-- Challenges whose holding and target both fall in [fromBeat, toBeat).
function HypePlanner.plan(track: Types.Track, fromBeat: number, toBeat: number): { Challenge }
	local hype = Balance.Hype
	local lastBeat = toBeat + hype.hitEveryBeats
	local found: { Challenge } = {}
	for i, section in track.sections do
		local nextSection = track.sections[i + 1]
		if section.kind == "build" and nextSection and nextSection.kind == "drop" then
			local holdFrom = nextSection.startBeat - hype.releaseHoldBeats
			if holdFrom >= fromBeat and nextSection.startBeat < toBeat then
				table.insert(found, { kind = "release", beat = nextSection.startBeat, holdFrom = holdFrom })
			end
		elseif section.kind == "drop" then
			local sectionEnd = TrackInfo.sectionEnd(track, i, lastBeat)
			local beat = section.startBeat + hype.hitEveryBeats
			while beat < sectionEnd and beat < toBeat do
				if beat >= fromBeat then
					table.insert(found, { kind = "hit", beat = beat })
					break
				end
				beat += hype.hitEveryBeats
			end
		end
	end

	table.sort(found, function(a, b)
		return a.beat < b.beat
	end)
	-- Keep challenges apart: drop any that starts within a bar or two of the previous one's target.
	local spaced: { Challenge } = {}
	for _, challenge in found do
		local previous = spaced[#spaced]
		local starts = challenge.holdFrom or challenge.beat
		if not previous or starts - previous.beat >= hype.quietAfterDropBeats then
			table.insert(spaced, challenge)
		end
	end
	return spaced
end

return HypePlanner
