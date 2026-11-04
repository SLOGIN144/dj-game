--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Booking = require(Shared.Economy.Booking)
local T = require(script.Parent.TestUtil)

local KIKO = Booking.find("dj_kiko") :: any
local MIRA = Booking.find("dj_mira") :: any

local function situation(overrides: { [string]: any })
	local base = {
		locationId = "house",
		hasBoard = true,
		cash = 1e12,
		playing = false,
		restUntil = nil,
		now = 1000,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base :: any
end

return {
	["a DJ is bookable from their own location on, never before"] = function()
		T.equal(Booking.isUnlocked(KIKO, "dorm"), false)
		T.equal(Booking.isUnlocked(KIKO, "house"), true)
		T.equal(Booking.isUnlocked(KIKO, "ibiza"), true, "they carry over")
		T.equal(Booking.isUnlocked(MIRA, "club"), false)
	end,

	["a booking goes ahead when nothing stands in the way"] = function()
		T.equal(Booking.refusal(KIKO, situation({})), nil)
	end,

	["each thing that stands in the way is named"] = function()
		T.equal(Booking.refusal(KIKO, situation({ locationId = "dorm" })), "locked")
		T.equal(Booking.refusal(KIKO, situation({ hasBoard = false })), "noBoard")
		T.equal(Booking.refusal(KIKO, situation({ playing = true })), "playing")
		T.equal(Booking.refusal(KIKO, situation({ restUntil = 1001 })), "resting")
		T.equal(Booking.refusal(KIKO, situation({ restUntil = 1000 })), nil, "rested exactly on time")
		T.equal(Booking.refusal(KIKO, situation({ cash = KIKO.price - 1 })), "cash")
	end,

	["the board explains a locked DJ with their location's name"] = function()
		T.equal(Booking.explain("locked", MIRA), "Unlocks at the Ibiza Beach Club")
	end,
}
