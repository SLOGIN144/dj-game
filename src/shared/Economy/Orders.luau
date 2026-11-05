--!strict
-- Phone orders (docs/superpowers/specs/2026-11-05-truck-delivery-design.md), as pure rules: what
-- a cart may hold, what the delivery costs in time, and the life of each box from the order to its
-- outline. The server's Delivery service runs the trucks and boxes; this decides what is allowed.

local Balance = require(script.Parent.Parent.Config.Balance)
local Types = require(script.Parent.Parent.Types)
local Unlocks = require(script.Parent.Unlocks)

local Orders = {}

-- ordered: paid, the truck is on its way; delivered: the box lies on the pavement; carried: in the
-- owner's hands; placed: the item is built and earning.
export type BoxState = "ordered" | "delivered" | "carried" | "placed"

export type Order = {
	items: { string }, -- in unlock order
	costs: { [string]: number },
	total: number,
	states: { [string]: BoxState },
}

-- Why a cart was refused.
export type Refusal = "empty" | "size" | "repeat" | "locked" | "cash"

-- A box goes forward one step at a time; a carried box can also be put back on the pavement
-- (the carrier died or left the plot).
local NEXT: { [BoxState]: { BoxState } } = {
	ordered = { "delivered" },
	delivered = { "carried" },
	carried = { "placed", "delivered" },
	placed = {},
}

-- The cart a client asked for, checked against what is shown to order (Unlocks.visible) and the
-- player's cash. Returns the item ids in unlock order, or nil and why not. `requested` comes
-- straight off a remote, so it can be anything.
function Orders.validate(
	locationId: string,
	bought: { [string]: boolean },
	cash: number,
	requested: unknown,
	effects: { [string]: Types.ItemEffect }
): ({ string }?, Refusal?)
	if typeof(requested) ~= "table" then
		return nil, "empty"
	end
	local ids = requested :: { unknown }
	if #ids == 0 then
		return nil, "empty"
	end
	if #ids > Balance.Delivery.maxItems then
		return nil, "size"
	end
	local wanted: { [string]: boolean } = {}
	for _, id in ids do
		if typeof(id) ~= "string" then
			return nil, "locked"
		end
		if wanted[id] then
			return nil, "repeat"
		end
		wanted[id] = true
	end
	local cart: { string } = {}
	local total = 0
	for _, item in Unlocks.visible(locationId, bought) do
		if wanted[item.id] then
			table.insert(cart, item.id)
			total += effects[item.id].cost
			wanted[item.id] = nil
		end
	end
	if next(wanted) ~= nil then
		return nil, "locked" -- an id that isn't on the shelf right now
	end
	if total > cash then
		return nil, "cash"
	end
	return cart, nil
end

-- Seconds from ordering until the truck stops at the kerb.
function Orders.deliverySeconds(count: number): number
	return Balance.Delivery.baseSeconds + Balance.Delivery.perExtraSeconds * math.max(0, count - 1)
end

-- A fresh order for a validated cart: every box starts as ordered.
function Orders.new(cart: { string }, effects: { [string]: Types.ItemEffect }): Order
	local order: Order = { items = table.clone(cart), costs = {}, total = 0, states = {} }
	for _, id in cart do
		order.costs[id] = effects[id].cost
		order.total += effects[id].cost
		order.states[id] = "ordered"
	end
	return order
end

-- Moves a box to `to` if that is a legal step. Returns whether it moved.
function Orders.advance(order: Order, itemId: string, to: BoxState): boolean
	local from = order.states[itemId]
	if not from or not table.find(NEXT[from], to) then
		return false
	end
	order.states[itemId] = to
	return true
end

-- Boxes in a given state.
function Orders.count(order: Order, state: BoxState): number
	local count = 0
	for _, current in order.states do
		if current == state then
			count += 1
		end
	end
	return count
end

-- The item being carried, if any (only one box at a time).
function Orders.carried(order: Order): string?
	for _, id in order.items do
		if order.states[id] == "carried" then
			return id
		end
	end
	return nil
end

function Orders.isDone(order: Order): boolean
	return Orders.count(order, "placed") == #order.items
end

-- Cash paid for boxes that haven't been placed yet: what a saved game keeps for the player.
function Orders.unplacedCost(order: Order): number
	local sum = 0
	for id, state in order.states do
		if state ~= "placed" then
			sum += order.costs[id]
		end
	end
	return sum
end

return Orders
