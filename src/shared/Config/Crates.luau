--!strict
-- The crates a star DJ can be hatched from (decided with Filip, 2026-11-05). A crate is opened at
-- the location's booking board with in-game cash, never Robux, and never a way to skip anything
-- (GDD monetization rules: no paid random items). The price is a number of seconds of the
-- location's finished income (Economy/Crates), so it grows with the career. `odds` are the chances
-- of each rarity, shown to the player; a rarity with no DJ unlocked yet rolls the next one down.
-- A DJ already owned pays back `duplicateShare` of the price instead.

local Types = require(script.Parent.Parent.Types)

export type Crate = {
	id: string,
	name: string,
	seconds: number, -- price in seconds of the location's finished income
	odds: { [Types.Rarity]: number },
	colour: Color3,
}

local rgb = Color3.fromRGB

local Crates: { Crate } = {
	{
		id = "street",
		name = "Street Crate",
		seconds = 240,
		odds = { common = 72, rare = 24, epic = 3.7, legendary = 0.3 },
		colour = rgb(160, 170, 190),
	},
	{
		id = "gold",
		name = "Gold Crate",
		seconds = 900,
		odds = { common = 30, rare = 45, epic = 20, legendary = 5 },
		colour = rgb(255, 214, 90),
	},
}

return Crates
