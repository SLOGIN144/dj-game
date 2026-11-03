--!strict
-- Which items a plot shows as buttons next, and when its location is finished.

local Balance = require(script.Parent.Parent.Config.Balance)
local Items = require(script.Parent.Parent.Config.Items)
local Locations = require(script.Parent.Parent.Config.Locations)
local Types = require(script.Parent.Parent.Types)

local Unlocks = {}

-- The first few items not bought yet, in unlock order.
function Unlocks.visible(locationId: string, bought: { [string]: boolean }): { Types.Item }
	local shown = {}
	for _, item in Items[locationId] do
		if not bought[item.id] then
			table.insert(shown, item)
			if #shown == Balance.Buttons.visible then
				break
			end
		end
	end
	return shown
end

function Unlocks.canBuy(locationId: string, bought: { [string]: boolean }, itemId: string): boolean
	for _, item in Unlocks.visible(locationId, bought) do
		if item.id == itemId then
			return true
		end
	end
	return false
end

function Unlocks.isComplete(locationId: string, bought: { [string]: boolean }): boolean
	return #Unlocks.visible(locationId, bought) == 0
end

-- The location after this one, or nil after the last.
function Unlocks.nextLocation(locationId: string): string?
	for index, location in Locations do
		if location.id == locationId then
			local following = Locations[index + 1]
			return if following then following.id else nil
		end
	end
	return nil
end

return Unlocks
