--!strict
-- Whether a player can book a star DJ right now (GDD: star DJs), and why not. Pure, so the server
-- (Services/StarDjs) and the booking board (UI/DjBoard) agree, and it's tested.

local Locations = require(script.Parent.Parent.Config.Locations)
local StarDjs = require(script.Parent.Parent.Config.StarDjs)
local Types = require(script.Parent.Parent.Types)

local Booking = {}

-- Why a booking can't happen: the DJ isn't unlocked yet, the location has no booking board, the
-- player doesn't have the DJ (they come from crates), a set is playing, the DJ is resting, or the
-- player can't afford them.
export type Refusal = "locked" | "noBoard" | "notOwned" | "playing" | "resting" | "cash"

export type Situation = {
	locationId: string,
	hasBoard: boolean, -- the location's booking board is bought
	owned: boolean, -- the player has this DJ (a starter, or one from a crate)
	cash: number,
	playing: boolean, -- a star DJ's set is on right now
	restUntil: number?, -- when this DJ can be booked again (os.time)
	now: number, -- os.time()
}

local function order(locationId: string): number
	for index, location in Locations do
		if location.id == locationId then
			return index
		end
	end
	return math.huge
end

function Booking.find(djId: string): Types.StarDj?
	for _, dj in StarDjs do
		if dj.id == djId then
			return dj
		end
	end
	return nil
end

-- A DJ stays bookable from the location that unlocks them onwards.
function Booking.isUnlocked(dj: Types.StarDj, locationId: string): boolean
	return order(dj.location) <= order(locationId)
end

-- Nil when the booking can go ahead, else why not.
function Booking.refusal(dj: Types.StarDj, situation: Situation): Refusal?
	if not Booking.isUnlocked(dj, situation.locationId) then
		return "locked"
	elseif not situation.hasBoard then
		return "noBoard"
	elseif not situation.owned then
		return "notOwned"
	elseif situation.playing then
		return "playing"
	elseif situation.restUntil and situation.now < situation.restUntil then
		return "resting"
	elseif situation.cash < dj.price then
		return "cash"
	end
	return nil
end

-- What the board says for a refusal.
function Booking.explain(refusal: Refusal, dj: Types.StarDj): string
	if refusal == "locked" then
		local location = Locations[order(dj.location)]
		return "Unlocks at the " .. (if location then location.name else dj.location)
	elseif refusal == "noBoard" then
		return "Buy this location's booking board first"
	elseif refusal == "notOwned" then
		return "Not yet yours: open crates to find " .. dj.name
	elseif refusal == "playing" then
		return "A guest set is on right now"
	elseif refusal == "resting" then
		return dj.name .. " is resting"
	end
	return "Not enough cash yet"
end

return Booking
