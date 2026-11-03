--!strict
-- The career's locations, in order. A new location is one more entry here, its items in
-- Items.luau, its pacing in Balance.Pricing and its blockout in Blockouts/.

local Types = require(script.Parent.Parent.Types)

local Locations: { Types.Location } = {
	{ id = "dorm", name = "Dorm Room", colour = Color3.fromRGB(150, 90, 255), guests = { min = 0, max = 5 } },
}

return Locations
