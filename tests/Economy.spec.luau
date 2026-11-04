--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Crowd = require(Shared.Economy.Crowd)
local Items = require(Shared.Config.Items)
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
	["a location's first item is free"] = function()
		T.equal(Pricing.effects("dorm")[Items.dorm[1].id].cost, 0)
	end,

	["costs round to two significant figures"] = function()
		T.equal(Pricing.roundCost(46.4), 46)
		T.equal(Pricing.roundCost(1234), 1200)
		T.equal(Pricing.roundCost(0.4), 1)
	end,

	["each button costs more than the one before"] = function()
		local effects = Pricing.effects("dorm")
		for index = 3, #Items.dorm do
			local previous = effects[Items.dorm[index - 1].id].cost
			T.truthy(effects[Items.dorm[index].id].cost > previous, Items.dorm[index].id)
		end
	end,

	["gear multiplies the income and everything else adds to it"] = function()
		local effects = Pricing.effects("dorm")
		for _, item in Items.dorm do
			local effect = effects[item.id]
			if item.kind == "gear" then
				T.truthy(effect.multiplier > 1 and effect.flat == 0, item.id)
			else
				T.truthy(effect.flat > 0 and effect.multiplier == 1, item.id)
			end
		end
	end,

	["buying everything in order goes from the start to the end income"] = function()
		T.near(Income.perSecond("dorm", boughtFirst("dorm", 1)), Pricing.startIncome("dorm"))
		T.near(Income.perSecond("dorm", boughtFirst("dorm", #Items.dorm)), Pricing.endIncome("dorm"), 1e-6)
	end,

	["saving for the whole dorm takes about its target time with active play"] = function()
		local effects = Pricing.effects("dorm")
		local seconds = 0
		for index = 2, #Items.dorm do
			local income = Income.perSecond("dorm", boughtFirst("dorm", index - 1))
			seconds += effects[Items.dorm[index].id].cost / income
		end
		local target = Balance.Pricing.locations.dorm.minutes * 60
		T.near(seconds / Balance.Pricing.activeFactor, target, target * 0.05)
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

	["a location is complete once every item is bought"] = function()
		T.equal(Unlocks.isComplete("dorm", boughtFirst("dorm", #Items.dorm - 1)), false)
		T.equal(Unlocks.isComplete("dorm", boughtFirst("dorm", #Items.dorm)), true)
		T.equal(Unlocks.nextLocation("dorm"), nil)
	end,
}
