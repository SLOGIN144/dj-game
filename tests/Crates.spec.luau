--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Booking = require(Shared.Economy.Booking)
local CrateConfig = require(Shared.Config.Crates)
local Crates = require(Shared.Economy.Crates)
local SaveSchema = require(Shared.Data.SaveSchema)
local StarDjs = require(Shared.Config.StarDjs)
local T = require(script.Parent.TestUtil)

local STREET = Crates.find("street") :: CrateConfig.Crate
local GOLD = Crates.find("gold") :: CrateConfig.Crate

-- Dice that give the listed numbers in turn.
local function dice(...: number): () -> number
	local values = { ... }
	local index = 0
	return function()
		index += 1
		return values[index] or 0
	end
end

local function ids(list: { any }): string
	local result = {}
	for _, dj in list do
		table.insert(result, dj.id)
	end
	return table.concat(result, ",")
end

return {
	["each crate's odds add up to a hundred, so the percentages shown are real"] = function()
		for _, crate in CrateConfig do
			local sum = 0
			for _, chance in crate.odds do
				sum += chance
			end
			T.near(sum, 100, 1e-9, crate.id)
		end
	end,

	["a crate costs more further into the career, and the gold crate more than the street one"] = function()
		T.truthy(Crates.price(STREET, "house") < Crates.price(STREET, "club"))
		T.truthy(Crates.price(STREET, "club") < Crates.price(STREET, "ibiza"))
		T.truthy(Crates.price(STREET, "club") < Crates.price(GOLD, "club"))
	end,

	["a crate only gives DJs unlocked by the player's location"] = function()
		T.equal(ids(Crates.pool("dorm")), "")
		T.equal(ids(Crates.pool("house")), "dj_dusty", "the starter is not in the crates")
		T.truthy(#Crates.pool("ibiza") == #StarDjs - 1, "everyone but the starter by Ibiza")
	end,

	["the roll follows the odds: a low roll is common, a high one legendary"] = function()
		local pool = Crates.pool("ibiza")
		local common = Crates.roll(STREET, pool, dice(0, 0)) :: any
		T.equal(common.rarity, "common")
		local legendary = Crates.roll(STREET, pool, dice(0.9999, 0)) :: any
		T.equal(legendary.rarity, "legendary")
		local rare = Crates.roll(STREET, pool, dice(0.8, 0)) :: any
		T.equal(rare.rarity, "rare", "72 to 96 percent is rare in a street crate")
	end,

	["within a rarity the DJ is picked evenly"] = function()
		local pool = Crates.pool("ibiza")
		local first = Crates.roll(STREET, pool, dice(0.8, 0)) :: any -- a rare one
		local last = Crates.roll(STREET, pool, dice(0.8, 0.9999)) :: any
		T.equal(first.id, "dj_tamsin")
		T.equal(last.id, "dj_nova")
	end,

	["a rarity nothing is unlocked for rolls the next one down"] = function()
		-- At the house party only common DJs exist, so every roll is one of them.
		local pool = Crates.pool("house")
		local epic = Crates.roll(GOLD, pool, dice(0.9, 0)) :: any
		T.equal(epic.rarity, "common")
	end,

	["an empty pool gives nothing"] = function()
		T.equal(Crates.roll(STREET, {}, dice(0.5, 0.5)), nil)
	end,

	["a starter counts as owned, and a crate is refused once everyone here is owned"] = function()
		local pool = Crates.pool("house")
		T.equal(Crates.isOwned(Booking.find("dj_kiko") :: any, {}), true, "the starter")
		T.equal(Crates.isOwned(Booking.find("dj_dusty") :: any, {}), false)
		T.equal(Crates.hasNew(pool, {}), true)
		T.equal(Crates.hasNew(pool, { dj_dusty = true }), false)
	end,

	["a duplicate pays back its share of the price"] = function()
		T.equal(Crates.duplicateRefund(1000), math.floor(1000 * Balance.Crates.duplicateShare))
	end,

	["a booking needs the DJ to be owned"] = function()
		local kiko = Booking.find("dj_kiko") :: any
		local situation = {
			locationId = "house",
			hasBoard = true,
			owned = false,
			cash = 1e9,
			playing = false,
			restUntil = nil,
			now = 1000,
		}
		T.equal(Booking.refusal(kiko, situation), "notOwned")
		situation.owned = true
		T.equal(Booking.refusal(kiko, situation), nil)
	end,

	["version 2 saves load with no DJs from crates, and owned DJs survive a load"] = function()
		local old = SaveSchema.migrate({ version = 2, cash = 10, location = "house" })
		T.equal(#old.ownedDjs, 0)
		T.equal(old.version, SaveSchema.VERSION)
		local fresh = SaveSchema.migrate({ version = 3, ownedDjs = { "dj_dusty", "dj_nobody", "dj_dusty" } })
		T.equal(table.concat(fresh.ownedDjs, ","), "dj_dusty", "unknown and repeated ids are dropped")
	end,
}
