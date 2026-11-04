--!strict
-- Every location's blockout, by location id.

local Types = require(script.Parent.Parent.Types)

local Blockouts: { [string]: Types.Blockout } = {
	dorm = require(script.Dorm),
	house = require(script.House),
	club = require(script.Club),
	ibiza = require(script.Ibiza),
}

return Blockouts
