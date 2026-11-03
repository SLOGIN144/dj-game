--!strict
-- Decides where transitions happen, from the tagged track data:
--   * an incoming track starts one blend before a drop, so the drop lands as the blend ends;
--   * an outgoing track mixes out on a phrase once it has played its drop for a while.

local Balance = require(script.Parent.Parent.Config.Balance)
local TrackInfo = require(script.Parent.TrackInfo)
local Types = require(script.Parent.Parent.Types)

local TransitionPlanner = {}

function TransitionPlanner.blendBeats(): number
	return Balance.Transition.blendBars * 4
end

-- The beat an incoming track starts from, and the drop that lands at the end of the blend.
-- Drops too early to blend into are skipped; a track with no usable drop lands on beat `blend`.
function TransitionPlanner.entry(track: Types.Track): (number, number)
	local blend = TransitionPlanner.blendBeats()
	local drop = TrackInfo.firstDropFrom(track, blend) or blend
	return drop - blend, drop
end

-- The beat on the outgoing track where the next transition starts (the Start moment).
-- `enteredAt` is the drop it came in on; `nowBeat` is where it is now; `lengthBeats` is its end.
function TransitionPlanner.mixOutBeat(
	track: Types.Track,
	enteredAt: number,
	nowBeat: number,
	lengthBeats: number
): number
	local drop = TrackInfo.firstDropFrom(track, enteredAt) or enteredAt
	local earliest = math.max(nowBeat + Balance.Cards.showBeforeBeats, drop + Balance.Transition.playDropBars * 4)
	local phrase = Balance.Transition.phraseBeats
	local onPhrase = math.ceil(earliest / phrase) * phrase
	local latest = math.floor((lengthBeats - TransitionPlanner.blendBeats()) / 4) * 4
	return math.min(onPhrase, latest)
end

return TransitionPlanner
