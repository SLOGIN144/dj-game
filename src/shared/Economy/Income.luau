--!strict
-- A plot's income per second from the items bought at its current location.

local Pricing = require(script.Parent.Pricing)

local Income = {}

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

return Income
