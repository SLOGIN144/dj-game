--!strict
-- How many guests a plot shows: its location's guest range, filled in step with the plot's income
-- on a log scale, so every button brings friends at an even pace. Boosts don't count, so the
-- crowd doesn't flicker; only what the plot has built does.

local Locations = require(script.Parent.Parent.Config.Locations)
local Pricing = require(script.Parent.Pricing)

local Crowd = {}

function Crowd.count(locationId: string, baseIncome: number): number
	local range = nil
	for _, location in Locations do
		if location.id == locationId then
			range = location.guests
		end
	end
	assert(range, "unknown location " .. locationId)
	if baseIncome <= 0 then
		return 0
	end
	local start, finish = Pricing.startIncome(locationId), Pricing.endIncome(locationId)
	local progress = math.clamp(math.log(baseIncome / start) / math.log(finish / start), 0, 1)
	return range.min + math.floor(progress * (range.max - range.min) + 0.5)
end

return Crowd
