--!strict
-- Opening a crate (Config/Crates): what it costs at a location, which DJs it can give there, and
-- the roll itself. Pure, with the dice passed in, so the server (Services/Crates) and the board
-- (UI/DjBoard) agree and it's tested.

local Balance = require(script.Parent.Parent.Config.Balance)
local Booking = require(script.Parent.Booking)
local CrateConfig = require(script.Parent.Parent.Config.Crates)
local Pricing = require(script.Parent.Pricing)
local StarDjs = require(script.Parent.Parent.Config.StarDjs)
local Types = require(script.Parent.Parent.Types)

local Crates = {}

-- Worst to best; a rarity with no DJ steps down this list, then up if nothing lower exists.
local RARITIES: { Types.Rarity } = { "common", "rare", "epic", "legendary" }

function Crates.find(crateId: string): CrateConfig.Crate?
	for _, crate in CrateConfig do
		if crate.id == crateId then
			return crate
		end
	end
	return nil
end

-- What the crate costs while the player is at `locationId`.
function Crates.price(crate: CrateConfig.Crate, locationId: string): number
	return Pricing.roundCost(Pricing.endIncome(locationId) * crate.seconds)
end

-- The DJs that can come out of a crate at `locationId`: everyone unlocked by then except the starter,
-- who is already theirs.
function Crates.pool(locationId: string): { Types.StarDj }
	local pool = {}
	for _, dj in StarDjs do
		if Booking.isUnlocked(dj, locationId) and not dj.starter then
			table.insert(pool, dj)
		end
	end
	return pool
end

-- Whether the player already has this DJ (a starter always counts).
function Crates.isOwned(dj: Types.StarDj, owned: { [string]: boolean }): boolean
	return dj.starter == true or owned[dj.id] == true
end

-- Whether any DJ in the pool is still missing.
function Crates.hasNew(pool: { Types.StarDj }, owned: { [string]: boolean }): boolean
	for _, dj in pool do
		if not Crates.isOwned(dj, owned) then
			return true
		end
	end
	return false
end

-- Cash back for a DJ the player already has.
function Crates.duplicateRefund(price: number): number
	return math.floor(price * Balance.Crates.duplicateShare)
end

-- The DJ a roll gives: the rarity by the crate's odds, then one of that rarity's DJs in the pool.
-- `rand` returns a number in [0, 1). Nil only if the pool is empty.
function Crates.roll(crate: CrateConfig.Crate, pool: { Types.StarDj }, rand: () -> number): Types.StarDj?
	local byRarity: { [Types.Rarity]: { Types.StarDj } } = {}
	for _, dj in pool do
		local bucket = byRarity[dj.rarity] or {}
		table.insert(bucket, dj)
		byRarity[dj.rarity] = bucket
	end
	local total = 0
	for _, rarity in RARITIES do
		total += crate.odds[rarity] or 0
	end
	if total <= 0 then
		return nil
	end
	local pick = rand() * total
	local chosen = RARITIES[#RARITIES]
	for _, rarity in RARITIES do
		pick -= crate.odds[rarity] or 0
		if pick < 0 then
			chosen = rarity
			break
		end
	end
	-- A rarity nothing is unlocked for rolls the next one down, or up if there's nothing lower.
	local start = table.find(RARITIES, chosen) :: number
	local bucket = byRarity[chosen]
	local step = start - 1
	while not bucket and step >= 1 do
		bucket = byRarity[RARITIES[step]]
		step -= 1
	end
	step = start + 1
	while not bucket and step <= #RARITIES do
		bucket = byRarity[RARITIES[step]]
		step += 1
	end
	if not bucket then
		return nil
	end
	return bucket[math.min(#bucket, math.floor(rand() * #bucket) + 1)]
end

return Crates
