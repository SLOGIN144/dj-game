--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Bounds = require(Shared.Util.Bounds)
local Crowd = require(Shared.Economy.Crowd)
local Items = require(Shared.Config.Items)
local Locations = require(Shared.Config.Locations)
local Format = require(Shared.Util.Format)
local Income = require(Shared.Economy.Income)
local Pricing = require(Shared.Economy.Pricing)
local Register = require(Shared.Economy.Register)
local Unlocks = require(Shared.Economy.Unlocks)
local T = require(script.Parent.TestUtil)

-- The first `count` items of a location, as a bought set.
local function boughtFirst(locationId: string, count: number): { [string]: boolean }
	local bought = {}
	for index = 1, count do
		bought[Items[locationId][index].id] = true
	end
	return bought
end

return {
	-- Format
	["money reads short and never rounds up"] = function()
		T.equal(Format.money(0), "$0")
		T.equal(Format.money(950.7), "$950")
		T.equal(Format.money(1000), "$1K")
		T.equal(Format.money(1999), "$1.9K")
		T.equal(Format.money(250000), "$250K")
		T.equal(Format.money(3400000), "$3.4M")
	end,

	["income per second keeps one decimal while small"] = function()
		T.equal(Format.rate(1), "+$1/s")
		T.equal(Format.rate(1.32), "+$1.3/s")
		T.equal(Format.rate(12.8), "+$12/s")
		T.equal(Format.rate(1500), "+$1.5K/s")
	end,

	-- Pricing
	["every location's first item is free"] = function()
		for _, location in Locations do
			T.equal(Pricing.effects(location.id)[Items[location.id][1].id].cost, 0, location.id)
		end
	end,

	["costs round to two significant figures"] = function()
		T.equal(Pricing.roundCost(46.4), 46)
		T.equal(Pricing.roundCost(1234), 1200)
		T.equal(Pricing.roundCost(0.4), 1)
	end,

	["each button costs more than the one before"] = function()
		for _, location in Locations do
			local items = Items[location.id]
			local effects = Pricing.effects(location.id)
			for index = 3, #items do
				local previous = effects[items[index - 1].id].cost
				T.truthy(effects[items[index].id].cost > previous, items[index].id)
			end
		end
	end,

	["gear multiplies the income and everything else adds to it"] = function()
		for _, location in Locations do
			local effects = Pricing.effects(location.id)
			for _, item in Items[location.id] do
				local effect = effects[item.id]
				if item.kind == "gear" then
					T.truthy(effect.multiplier > 1 and effect.flat == 0, item.id)
				else
					T.truthy(effect.flat > 0 and effect.multiplier == 1, item.id)
				end
			end
		end
	end,

	["buying everything in order goes from the start to the end income"] = function()
		for _, location in Locations do
			local id, count = location.id, #Items[location.id]
			T.near(Income.perSecond(id, boughtFirst(id, 1)), Pricing.startIncome(id), 1e-6, id)
			local finish = Pricing.endIncome(id)
			T.near(Income.perSecond(id, boughtFirst(id, count)), finish, finish * 1e-9, id)
		end
	end,

	["saving for each location takes about its target time with active play"] = function()
		for _, location in Locations do
			local id, items = location.id, Items[location.id]
			local effects = Pricing.effects(id)
			local seconds = 0
			for index = 2, #items do
				local income = Income.perSecond(id, boughtFirst(id, index - 1))
				seconds += effects[items[index].id].cost / income
			end
			local target = Balance.Pricing.locations[id].minutes * 60
			T.near(seconds / Balance.Pricing.activeFactor, target, target * 0.05, id)
		end
	end,

	["moving on never feels like a step back"] = function()
		for index = 2, #Locations do
			local before, after = Locations[index - 1].id, Locations[index].id
			T.truthy(Pricing.startIncome(after) >= Pricing.endIncome(before) * 0.99, after)
		end
	end,

	["about ten hours from the dorm to a finished Ibiza"] = function()
		local minutes = 0
		for _, location in Locations do
			minutes += Balance.Pricing.locations[location.id].minutes
		end
		T.truthy(minutes >= 8 * 60 and minutes <= 12 * 60, tostring(minutes))
	end,

	["a new player can afford the first paid button"] = function()
		T.truthy(Pricing.effects("dorm")[Items.dorm[2].id].cost <= Balance.Start.cash)
	end,

	-- Register
	["the register fills with income up to its cap"] = function()
		T.near(Register.fill(0, 2, 5), 10)
		local cap = Register.capacity(2)
		T.near(cap, 2 * Balance.Register.capMinutes * 60)
		T.near(Register.fill(cap - 1, 2, 5), cap)
	end,

	["the register never loses money when income drops"] = function()
		T.near(Register.fill(5000, 1, 1), 5000)
	end,

	["the bigger register holds more"] = function()
		T.near(Register.capacity(2, true), Register.capacity(2) * Balance.Register.biggerCap)
		T.near(Register.fill(Register.capacity(2), 2, 5, true), Register.capacity(2) + 10)
	end,

	-- Unlocks
	["buttons show the next items not bought yet, in order"] = function()
		local shown = Unlocks.visible("dorm", boughtFirst("dorm", 2))
		T.equal(#shown, Balance.Buttons.visible)
		T.equal(shown[1].id, Items.dorm[3].id)
	end,

	["only a shown button can be bought"] = function()
		local bought = boughtFirst("dorm", 1)
		T.equal(Unlocks.canBuy("dorm", bought, Items.dorm[2].id), true)
		T.equal(Unlocks.canBuy("dorm", bought, Items.dorm[#Items.dorm].id), false)
		T.equal(Unlocks.canBuy("dorm", bought, Items.dorm[1].id), false)
	end,

	["bought tracks, boosts and a blown speaker change the income"] = function()
		local none = { tracksBought = 0, boost = 1, speakerBlown = false }
		T.near(Income.total(10, none), 10)
		T.near(Income.total(10, { tracksBought = 2, boost = 1, speakerBlown = false }), 11)
		T.near(Income.total(10, { tracksBought = 0, boost = 2, speakerBlown = false }), 20)
		T.near(Income.total(10, { tracksBought = 0, boost = 1, speakerBlown = true }), 7.5)
		T.near(Income.total(10, { tracksBought = 1, boost = 1.5, speakerBlown = true }), 10 * 1.05 * 1.5 * 0.75)
	end,

	-- Bounds (where imported art goes)
	["an imported model goes at the bottom centre of its blockout"] = function()
		local specs = {
			{ size = Vector3.new(2, 1, 2), offset = Vector3.new(0, 0.5, 0), colour = Color3.new() },
			{ size = Vector3.new(2, 2, 2), offset = Vector3.new(4, 3, 0), colour = Color3.new() },
		}
		local anchor = Bounds.anchor(specs)
		T.near(anchor.X, 2)
		T.near(anchor.Y, 0)
		T.near(anchor.Z, 0)
	end,

	-- Crowd
	["the crowd grows from none to the location's maximum as the dorm is built"] = function()
		T.equal(Crowd.count("dorm", 0), 0, "an empty room")
		T.equal(Crowd.count("dorm", Income.perSecond("dorm", boughtFirst("dorm", 1))), 0, "just the laptop")
		T.equal(Crowd.count("dorm", Income.perSecond("dorm", boughtFirst("dorm", #Items.dorm))), 5, "everything")
		local previous = 0
		for count = 1, #Items.dorm do
			local guests = Crowd.count("dorm", Income.perSecond("dorm", boughtFirst("dorm", count)))
			T.truthy(guests >= previous, "never fewer guests after a purchase")
			previous = guests
		end
		T.equal(Crowd.count("dorm", 1e9), 5, "capped at the range")
	end,

	["every location's crowd starts at its minimum and ends at its maximum"] = function()
		for _, location in Locations do
			local id = location.id
			T.equal(Crowd.count(id, Pricing.startIncome(id)), location.guests.min, id)
			T.equal(Crowd.count(id, Pricing.endIncome(id)), location.guests.max, id)
		end
	end,

	["a location is complete once every item is bought"] = function()
		T.equal(Unlocks.isComplete("dorm", boughtFirst("dorm", #Items.dorm - 1)), false)
		T.equal(Unlocks.isComplete("dorm", boughtFirst("dorm", #Items.dorm)), true)
		T.equal(Unlocks.nextLocation("dorm"), "house")
		T.equal(Unlocks.nextLocation("club"), "ibiza")
		T.equal(Unlocks.nextLocation("ibiza"), nil, "the world tour comes later")
	end,
}
