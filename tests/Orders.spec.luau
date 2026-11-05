--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Orders = require(Shared.Economy.Orders)
local Pricing = require(Shared.Economy.Pricing)
local T = require(script.Parent.TestUtil)
local Unlocks = require(Shared.Economy.Unlocks)

local effects = Pricing.effects("dorm")
local shelf = Unlocks.visible("dorm", {})
local FIRST, SECOND, THIRD = shelf[1].id, shelf[2].id, shelf[3].id
local RICH = 1e9

local function validate(requested: unknown, cash: number?, bought: { [string]: boolean }?)
	return Orders.validate("dorm", bought or {}, cash or RICH, requested, effects)
end

return {
	["the free first item can be ordered with no cash at all"] = function()
		local cart, why = validate({ FIRST }, 0)
		T.equal(why, nil)
		T.equal(#(cart :: { string }), 1)
		T.equal((cart :: { string })[1], FIRST)
	end,

	["a cart comes back in unlock order whatever order it was asked in"] = function()
		local cart = validate({ THIRD, FIRST, SECOND })
		T.equal(table.concat(cart :: { string }, ","), table.concat({ FIRST, SECOND, THIRD }, ","))
	end,

	["an empty or non-list cart is refused"] = function()
		T.equal(select(2, validate({})), "empty")
		T.equal(select(2, validate(nil)), "empty")
		T.equal(select(2, validate("dorm_laptop")), "empty")
	end,

	["a cart is at most as big as the delivery allows"] = function()
		local ids = {}
		for index = 1, Balance.Delivery.maxItems + 1 do
			ids[index] = "dorm_item_" .. index
		end
		T.equal(select(2, validate(ids)), "size")
	end,

	["an item can't be in the cart twice"] = function()
		T.equal(select(2, validate({ FIRST, FIRST })), "repeat")
	end,

	["only what the shelf shows can be ordered"] = function()
		T.equal(select(2, validate({ "dorm_not_a_thing" })), "locked")
		T.equal(select(2, validate({ 7 })), "locked")
		local later = Unlocks.visible("dorm", { [FIRST] = true, [SECOND] = true, [THIRD] = true })[1].id
		T.equal(select(2, validate({ later })), "locked", "an item further down the list")
		T.equal(select(2, validate({ FIRST }, RICH, { [FIRST] = true })), "locked", "already built")
	end,

	["the whole cart has to be affordable"] = function()
		local price = effects[SECOND].cost
		T.truthy(price > 0, "the second item costs something")
		T.equal(select(2, validate({ FIRST, SECOND }, price - 1)), "cash")
		T.equal(select(2, validate({ FIRST, SECOND }, price)), nil)
	end,

	["delivery takes a little longer for each extra item"] = function()
		T.equal(Orders.deliverySeconds(1), Balance.Delivery.baseSeconds)
		T.equal(Orders.deliverySeconds(3), Balance.Delivery.baseSeconds + 2 * Balance.Delivery.perExtraSeconds)
	end,

	["a new order totals the cart and starts every box as ordered"] = function()
		local order = Orders.new({ FIRST, SECOND }, effects)
		T.equal(order.total, effects[FIRST].cost + effects[SECOND].cost)
		T.equal(Orders.count(order, "ordered"), 2)
		T.equal(Orders.isDone(order), false)
	end,

	["a box moves forward one step at a time"] = function()
		local order = Orders.new({ FIRST }, effects)
		T.equal(Orders.advance(order, FIRST, "carried"), false, "can't skip the delivery")
		T.equal(Orders.advance(order, FIRST, "placed"), false)
		T.equal(Orders.advance(order, FIRST, "delivered"), true)
		T.equal(Orders.advance(order, FIRST, "carried"), true)
		T.equal(Orders.carried(order), FIRST)
		T.equal(Orders.advance(order, FIRST, "placed"), true)
		T.equal(Orders.isDone(order), true)
		T.equal(Orders.advance(order, FIRST, "delivered"), false, "a placed item stays placed")
	end,

	["a carried box can go back to the pavement, and an unknown item moves nowhere"] = function()
		local order = Orders.new({ FIRST }, effects)
		Orders.advance(order, FIRST, "delivered")
		Orders.advance(order, FIRST, "carried")
		T.equal(Orders.advance(order, FIRST, "delivered"), true)
		T.equal(Orders.carried(order), nil)
		T.equal(Orders.advance(order, "dorm_nothing", "delivered"), false)
	end,

	["cash for unplaced boxes is what a save keeps for the player"] = function()
		local order = Orders.new({ FIRST, SECOND, THIRD }, effects)
		T.equal(Orders.unplacedCost(order), order.total)
		Orders.advance(order, SECOND, "delivered")
		Orders.advance(order, SECOND, "carried")
		Orders.advance(order, SECOND, "placed")
		T.equal(Orders.unplacedCost(order), order.total - effects[SECOND].cost)
	end,
}
