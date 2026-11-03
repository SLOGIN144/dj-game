--!strict
-- Turns a location's pacing numbers (Balance.Pricing) into each item's cost and effect.
-- Bought in order, the items take the plot's income from startIncome to startIncome × incomeGrowth
-- in even steps, and saving for each one takes a little longer than for the one before.

local Balance = require(script.Parent.Parent.Config.Balance)
local Items = require(script.Parent.Parent.Config.Items)
local Locations = require(script.Parent.Parent.Config.Locations)
local Types = require(script.Parent.Parent.Types)

local Pricing = {}

local function pacing(locationId: string)
	local found = Balance.Pricing.locations[locationId]
	assert(found, "no pacing for location " .. locationId)
	return found
end

-- Two significant figures, so prices read cleanly; never below $1.
function Pricing.roundCost(value: number): number
	if value < 10 then
		return math.max(1, math.floor(value + 0.5))
	end
	local scale = 10 ^ (math.floor(math.log10(value)) - 1)
	return math.floor(value / scale + 0.5) * scale
end

-- Income per second with only the location's free first item.
function Pricing.startIncome(locationId: string): number
	local start = pacing(locationId).startIncome
	if start then
		return start
	end
	for index, location in Locations do
		if location.id == locationId then
			assert(index > 1, "the first location needs a startIncome")
			return Pricing.endIncome(Locations[index - 1].id) * Balance.Pricing.carryOver
		end
	end
	error("unknown location " .. locationId)
end

-- Income per second once every item of the location is bought.
function Pricing.endIncome(locationId: string): number
	return Pricing.startIncome(locationId) * pacing(locationId).incomeGrowth
end

-- Seconds of active play spent saving for each paid item (index 2 onward), summing to the
-- location's minutes.
local function saveTimes(locationId: string, count: number): { [number]: number }
	local weights, sum = {}, 0
	for index = 2, count do
		weights[index] = Balance.Pricing.timeGrowth ^ (index - 2)
		sum += weights[index]
	end
	local times = {}
	for index = 2, count do
		times[index] = pacing(locationId).minutes * 60 * weights[index] / sum
	end
	return times
end

-- Every item of the location with what it costs and does, keyed by item id.
function Pricing.effects(locationId: string): { [string]: Types.ItemEffect }
	local items = Items[locationId]
	assert(items and #items > 0, "no items for location " .. locationId)
	assert(items[1].kind == "income", "a location's first item must be an income item")

	local start, growth = Pricing.startIncome(locationId), pacing(locationId).incomeGrowth
	local times = saveTimes(locationId, #items)
	local effects = {}
	local flatSum, multiplier = 0, 1
	for index, item in items do
		local before = flatSum * multiplier
		local after = if #items == 1 then start else start * growth ^ ((index - 1) / (#items - 1))
		local cost = if index == 1 then 0 else Pricing.roundCost(before * Balance.Pricing.activeFactor * times[index])
		local effect: Types.ItemEffect = { cost = cost, flat = 0, multiplier = 1 }
		if item.kind == "gear" then
			effect.multiplier = after / before
			multiplier *= effect.multiplier
		else
			effect.flat = after / multiplier - flatSum
			flatSum += effect.flat
		end
		effects[item.id] = effect
	end
	return effects
end

return Pricing
