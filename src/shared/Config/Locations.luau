--!strict
-- The career's locations, in order (GDD: locations). A new location is one more entry here, its
-- items in Items.luau, its pacing in Balance.Pricing, its room in Blockouts/, its host in
-- Goals.luau and its building stage in Buildings.luau. Small locations are built on the plot by
-- the street; Ibiza is a venue of its own, reached by the private jet.

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Locations: { Types.Location } = {
	{
		id = "dorm",
		name = "Dorm Room",
		colour = rgb(150, 90, 255),
		lights = { rgb(150, 90, 255), rgb(255, 70, 200), rgb(80, 120, 255) },
		guests = { min = 0, max = 5 },
		space = "venue",
		door = true,
		spaceSize = Vector3.new(80, 40, 80),
		events = { "speaker" },
		sky = "dormRoom",
	},
	{
		id = "house",
		name = "House Party",
		colour = rgb(255, 170, 90),
		lights = { rgb(255, 170, 90), rgb(255, 70, 200), rgb(60, 220, 255) },
		guests = { min = 10, max = 25 },
		space = "plot",
		spaceSize = Vector3.new(80, 40, 80),
		events = { "speaker", "photographer" },
		sky = "houseParty",
	},
	{
		id = "club",
		name = "Underground Club",
		colour = rgb(60, 100, 255),
		lights = { rgb(60, 100, 255), rgb(140, 180, 255), rgb(255, 255, 255) },
		guests = { min = 30, max = 80 },
		space = "plot",
		spaceSize = Vector3.new(80, 40, 80),
		events = { "speaker", "vip", "photographer" },
		sky = "clubBasement",
	},
	{
		id = "ibiza",
		name = "Ibiza Beach Club",
		colour = rgb(255, 122, 60),
		lights = { rgb(255, 122, 60), rgb(255, 60, 168), rgb(160, 90, 255) },
		guests = { min = 100, max = 140 },
		space = "venue",
		spaceSize = Vector3.new(140, 60, 140),
		events = { "speaker", "vip", "photographer" },
		sky = "sunset",
	},
}

return Locations
