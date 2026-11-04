--!strict
-- Checks that the content config fits together: every location has its items, room, host,
-- pacing and building, and every id points at something real.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Blockouts = require(Shared.Config.Blockouts)
local Buildings = require(Shared.Config.Buildings)
local Goals = require(Shared.Config.Goals)
local Items = require(Shared.Config.Items)
local Locations = require(Shared.Config.Locations)
local Skies = require(Shared.Config.Skies)
local StarDjs = require(Shared.Config.StarDjs)
local T = require(script.Parent.TestUtil)

local function itemIndex(locationId: string, itemId: string): number?
	for index, item in Items[locationId] do
		if item.id == itemId then
			return index
		end
	end
	return nil
end

return {
	["every location has items, a room, a host, pacing and a building"] = function()
		local seen = {}
		for _, location in Locations do
			local id = location.id
			T.truthy(not seen[id], "unique location " .. id)
			seen[id] = true
			T.truthy(Items[id] and #Items[id] > 0, "items for " .. id)
			T.truthy(Blockouts[id], "a blockout for " .. id)
			T.truthy(Goals[id], "a host for " .. id)
			T.truthy(Balance.Pricing.locations[id], "pacing for " .. id)
			T.truthy(Buildings[id], "a building stage for " .. id)
			T.truthy(#location.lights > 0 and location.lights[1] == location.colour, "lights start with the colour")
			T.truthy(location.guests.min <= location.guests.max, "guest range")
			T.truthy(#location.events > 0, "at least one event")
			T.truthy(location.sky == nil or Skies[location.sky] ~= nil, "a real look for " .. id)
		end
	end,

	["item ids are unique and carry their location's prefix"] = function()
		local seen = {}
		for _, location in Locations do
			for _, item in Items[location.id] do
				T.truthy(not seen[item.id], "unique item " .. item.id)
				seen[item.id] = true
				T.equal(string.sub(item.id, 1, #location.id + 1), location.id .. "_", item.id)
				T.equal(item.feature ~= nil, item.kind == "feature", "features say what they switch on: " .. item.id)
			end
		end
	end,

	["an item only replaces an earlier one of its own location"] = function()
		for _, location in Locations do
			for index, item in Items[location.id] do
				if item.replaces then
					local replaced = itemIndex(location.id, item.replaces)
					T.truthy(replaced and replaced < index, item.id .. " replaces " .. item.replaces)
				end
			end
		end
	end,

	["every item has parts in its location's room"] = function()
		for _, location in Locations do
			local blockout = Blockouts[location.id]
			for _, item in Items[location.id] do
				local specs = blockout.items[item.id]
				T.truthy(specs and #specs > 0, "parts for " .. item.id)
			end
			for itemId in blockout.items do
				T.truthy(itemIndex(location.id, itemId), "a blockout entry for a real item: " .. itemId)
			end
		end
	end,

	["the decks are each location's free first item, and the speaker is a real item"] = function()
		for _, location in Locations do
			local blockout = Blockouts[location.id]
			T.equal(blockout.decks.itemId, Items[location.id][1].id, location.id)
			if blockout.speakerItem then
				T.truthy(itemIndex(location.id, blockout.speakerItem), "speaker item of " .. location.id)
			end
			T.truthy(#blockout.guests.spots >= math.min(location.guests.max, Balance.Guests.renderBudget), location.id)
		end
	end,

	["a location's own layout has a slot for every visible button"] = function()
		for _, location in Locations do
			local layout = Blockouts[location.id].layout
			if layout then
				T.truthy(#layout.buttonSlots >= Balance.Buttons.visible, location.id)
			end
			T.truthy(location.space == "plot" or layout ~= nil, "a venue sets its own layout: " .. location.id)
		end
	end,

	["each star DJ is unlocked by a real location and costs more than the last"] = function()
		local seen, lastPrice, lastOrder = {}, 0, 0
		for _, dj in StarDjs do
			T.truthy(not seen[dj.id], "unique DJ " .. dj.id)
			seen[dj.id] = true
			local order = nil
			for index, location in Locations do
				if location.id == dj.location then
					order = index
				end
			end
			T.truthy(order, dj.id .. " unlocks at a real location")
			T.truthy((order :: number) >= lastOrder, "listed in unlock order")
			T.truthy(dj.price > lastPrice and dj.multiplier > 1, dj.id)
			lastPrice, lastOrder = dj.price, order :: number
		end
	end,

	["every location with a booking board unlocks a DJ by then"] = function()
		for index, location in Locations do
			local hasBoard = false
			for _, item in Items[location.id] do
				hasBoard = hasBoard or item.feature == "booking"
			end
			if hasBoard then
				local any = false
				for _, dj in StarDjs do
					for earlier = 1, index do
						any = any or Locations[earlier].id == dj.location
					end
				end
				T.truthy(any, location.id)
			end
		end
	end,
}
