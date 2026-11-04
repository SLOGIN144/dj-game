--!strict
-- A plot's income per second: what its bought items earn (`perSecond`), and what the track
-- bonus, an active drop boost and a blown speaker make of that (`total`).

local Balance = require(script.Parent.Parent.Config.Balance)
local Pricing = require(script.Parent.Pricing)

local Income = {}

-- What changes a plot's income on top of what it has built.
export type Modifiers = {
	tracksBought: number, -- tracks bought in the shop; each adds Balance.Tracks.bonusPerTrack
	boost: number, -- the active drop boost's multiplier, 1 without one
	speakerBlown: boolean, -- a blown speaker cuts income until it's fixed
}

-- Income from the items bought at the location: income items add, gear multiplies.
function Income.perSecond(locationId: string, bought: { [string]: boolean }): number
	local flat, multiplier = 0, 1
	for itemId, effect in Pricing.effects(locationId) do
		if bought[itemId] then
			flat += effect.flat
			multiplier *= effect.multiplier
		end
	end
	return flat * multiplier
end

function Income.total(base: number, modifiers: Modifiers): number
	local tracks = 1 + Balance.Tracks.bonusPerTrack * modifiers.tracksBought
	local speaker = if modifiers.speakerBlown then 1 - Balance.Events.speaker.incomeCut else 1
	return base * tracks * modifiers.boost * speaker
end

return Income
