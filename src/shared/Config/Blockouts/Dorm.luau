--!strict
-- The dorm room blockout, laid out after docs/concept/dorm.webp: an open-front room (no front
-- wall or ceiling, so the camera sees in) with the bed along the left wall, the desk under a
-- night window, a door on the right wall and a rug for the dance floor. "Left" is as seen from
-- the street, which looks along +Z: the left wall is at +X and the right wall at -X. Each of the 10 items
-- adds simple parts; detailed art replaces them later (ServerStorage models named after the item).
-- The floor's top is at y = 0.2 and the desk's top at y = 3.4. The room spans x -12..12, z -6..14.

local Types = require(script.Parent.Parent.Parent.Types)

local v = Vector3.new
local rgb = Color3.fromRGB

local WALL = rgb(196, 186, 208)
local TRIM = rgb(70, 62, 84)
local WOOD = rgb(124, 88, 62)
local DARK_WOOD = rgb(88, 62, 48)
local DARK = rgb(26, 26, 32)
local PURPLE = rgb(150, 90, 255)
local PINK = rgb(255, 70, 200)
local NIGHT = rgb(26, 34, 82)
local CITY = rgb(14, 16, 34)
local WINDOW_LIGHT = rgb(255, 196, 120)
local LEAF = rgb(56, 124, 70)
local POT = rgb(170, 96, 70)

-- A lit window in the city outside, on the glass.
local function cityLight(x: number, y: number): Types.PartSpec
	return {
		size = v(0.25, 0.3, 0.05),
		offset = v(x, y, 13.74),
		colour = WINDOW_LIGHT,
		material = Enum.Material.Neon,
		collide = false,
	}
end

local Dorm: Types.Blockout = {
	shell = {
		-- Floor and walls
		{ size = v(24, 0.2, 20), offset = v(0, 0.1, 4), colour = WOOD, material = Enum.Material.WoodPlanks },
		{ size = v(26, 12, 1), offset = v(0, 6, 14.5), colour = WALL },
		{ size = v(1, 12, 20), offset = v(12.5, 6, 4), colour = WALL },
		{ size = v(1, 12, 20), offset = v(-12.5, 6, 4), colour = WALL },
		{ size = v(24, 0.4, 0.1), offset = v(0, 0.4, 13.95), colour = TRIM },
		{ size = v(0.1, 0.4, 20), offset = v(11.95, 0.4, 4), colour = TRIM },
		{ size = v(0.1, 0.4, 20), offset = v(-11.95, 0.4, 4), colour = TRIM },

		-- Window over the desk, with the night city outside
		{ size = v(9, 4.4, 0.2), offset = v(-1.5, 8, 13.9), colour = TRIM },
		{ size = v(8.4, 3.8, 0.1), offset = v(-1.5, 8, 13.82), colour = NIGHT, material = Enum.Material.Neon },
		{ size = v(1.6, 2.4, 0.05), offset = v(1.6, 7.0, 13.76), colour = CITY, collide = false },
		{ size = v(1.2, 3.0, 0.05), offset = v(-0.4, 7.3, 13.76), colour = CITY, collide = false },
		{ size = v(1.8, 1.8, 0.05), offset = v(-3.2, 6.7, 13.76), colour = CITY, collide = false },
		{ size = v(1.0, 2.8, 0.05), offset = v(-4.8, 7.2, 13.76), colour = CITY, collide = false },
		cityLight(1.9, 7.4),
		cityLight(1.3, 6.6),
		cityLight(-0.3, 8.0),
		cityLight(-0.6, 7.1),
		cityLight(-3, 7.0),
		cityLight(-4.7, 7.9),
		{ size = v(0.2, 3.8, 0.12), offset = v(-1.5, 8, 13.72), colour = TRIM },
		{ size = v(8.6, 0.5, 0.3), offset = v(-1.5, 10.0, 13.7), colour = rgb(64, 60, 74) },

		-- Bed along the left wall
		{ size = v(5, 1.2, 9), offset = v(9.2, 0.8, 9.3), colour = WOOD },
		{ size = v(5, 2.6, 0.4), offset = v(9.2, 1.5, 13.7), colour = WOOD },
		{ size = v(5, 1.6, 0.3), offset = v(9.2, 1.0, 4.95), colour = WOOD },
		{
			size = v(4.8, 0.6, 8.6),
			offset = v(9.2, 1.7, 9.3),
			colour = rgb(82, 78, 96),
			material = Enum.Material.Fabric,
		},
		{
			size = v(4.82, 0.62, 1.8),
			offset = v(9.2, 1.72, 11.4),
			colour = rgb(214, 210, 220),
			material = Enum.Material.Fabric,
		},
		{
			size = v(3, 0.5, 1.4),
			offset = v(9.2, 2.25, 12.7),
			colour = rgb(236, 234, 242),
			material = Enum.Material.Fabric,
		},
		{ size = v(3, 0.05, 6), offset = v(5.2, 0.225, 7), colour = rgb(84, 82, 94), material = Enum.Material.Fabric },

		-- The big rug: the dance floor
		{
			size = v(13, 0.05, 8.5),
			offset = v(-1, 0.225, -0.5),
			colour = rgb(96, 92, 104),
			material = Enum.Material.Fabric,
		},

		-- Desk under the window, with drawers on its right and a chair pushed aside
		{ size = v(8, 0.4, 3.6), offset = v(-1.5, 3.2, 12.0), colour = WOOD },
		{ size = v(0.4, 3, 0.4), offset = v(2.2, 1.5, 10.5), colour = WOOD },
		{ size = v(0.4, 3, 0.4), offset = v(2.2, 1.5, 13.5), colour = WOOD },
		{ size = v(2.4, 3, 3.4), offset = v(-4.2, 1.5, 12.0), colour = WOOD },
		{ size = v(2.2, 0.8, 0.1), offset = v(-4.2, 0.65, 10.27), colour = rgb(150, 112, 84) },
		{ size = v(2.2, 0.8, 0.1), offset = v(-4.2, 1.55, 10.27), colour = rgb(150, 112, 84) },
		{ size = v(2.2, 0.8, 0.1), offset = v(-4.2, 2.45, 10.27), colour = rgb(150, 112, 84) },
		{ size = v(2, 0.3, 2), offset = v(-5.2, 2.0, 7.9), rotation = v(0, -25, 0), colour = DARK, collide = false },
		{ size = v(2, 2.2, 0.3), offset = v(-5.6, 3.2, 8.7), rotation = v(0, -25, 0), colour = DARK, collide = false },
		{ size = v(0.3, 1.8, 0.3), offset = v(-5.2, 1.0, 7.9), colour = DARK, collide = false },
		-- A mug of hot chocolate (a cylinder's length runs along its X axis, so it's stood up)
		{
			size = v(0.6, 0.4, 0.4),
			offset = v(1.6, 3.7, 12.2),
			shape = Enum.PartType.Cylinder,
			rotation = v(0, 0, -90),
			colour = rgb(90, 50, 140),
		},
		{ size = v(0.5, 0.5, 0.5), offset = v(-5, 3.65, 12.9), colour = POT },
		{ size = v(1, 1, 1), offset = v(-5, 4.3, 12.9), shape = Enum.PartType.Ball, colour = LEAF, collide = false },

		-- Shelves with books
		{ size = v(0.8, 0.15, 3), offset = v(11.6, 7.6, 12.2), colour = WOOD },
		{ size = v(0.6, 1.1, 0.4), offset = v(11.6, 8.2, 11.2), colour = rgb(110, 60, 90) },
		{ size = v(0.6, 0.9, 0.35), offset = v(11.6, 8.1, 11.6), colour = rgb(60, 70, 120) },
		{ size = v(1, 1, 1), offset = v(11.6, 8.1, 13.0), shape = Enum.PartType.Ball, colour = LEAF, collide = false },
		{ size = v(0.8, 0.15, 3), offset = v(-11.6, 7.6, 11.5), colour = WOOD },
		{ size = v(0.6, 1.1, 0.4), offset = v(-11.6, 8.2, 10.6), colour = rgb(60, 80, 130) },
		{ size = v(0.6, 1.0, 0.35), offset = v(-11.6, 8.15, 11.0), colour = rgb(130, 70, 80) },
		{ size = v(0.6, 0.8, 0.35), offset = v(-11.6, 8.05, 11.4), colour = rgb(200, 180, 120) },

		-- Door on the right wall, where friends come in
		{ size = v(0.25, 7.2, 3.6), offset = v(-12, 3.8, -2.2), colour = DARK_WOOD },
		{ size = v(0.3, 7.6, 0.3), offset = v(-11.95, 3.8, -4.15), colour = TRIM },
		{ size = v(0.3, 7.6, 0.3), offset = v(-11.95, 3.8, -0.25), colour = TRIM },
		{ size = v(0.3, 0.3, 4.2), offset = v(-11.95, 7.55, -2.2), colour = TRIM },
		{
			size = v(0.3, 0.15, 0.6),
			offset = v(-11.8, 3.6, -0.9),
			colour = rgb(190, 190, 200),
			material = Enum.Material.Metal,
		},
		{ size = v(0.1, 0.5, 0.35), offset = v(-11.95, 4.2, 0.6), colour = rgb(230, 230, 236) },

		-- Plant in the front corner
		{ size = v(1.3, 1.3, 1.3), offset = v(10.8, 0.85, -4.6), colour = POT },
		{
			size = v(2.4, 2.4, 2.4),
			offset = v(10.8, 2.7, -4.6),
			shape = Enum.PartType.Ball,
			colour = LEAF,
			collide = false,
		},

		-- A dim ceiling light so the room reads at night before anything is bought
		{
			size = v(1, 1, 1),
			offset = v(0, 11, 4),
			colour = DARK,
			transparency = 1,
			collide = false,
			light = { colour = rgb(255, 210, 170), brightness = 0.6, range = 24 },
		},
	},

	items = {
		-- The DJ booth for now: the player's decks (ProximityPrompt "Play")
		dorm_laptop = {
			{ size = v(2.4, 0.12, 1.6), offset = v(-0.2, 3.46, 11.6), colour = rgb(60, 62, 70) },
			{
				size = v(2.4, 1.6, 0.1),
				offset = v(-0.2, 4.25, 12.45),
				rotation = v(15, 0, 0),
				colour = rgb(70, 110, 220),
				material = Enum.Material.Neon,
				lightRole = "screen",
			},
		},
		dorm_lamp = {
			{ size = v(0.8, 0.15, 0.8), offset = v(-4.4, 3.48, 13.0), colour = DARK },
			{ size = v(0.15, 2.2, 0.15), offset = v(-4.4, 4.6, 13.0), colour = DARK },
			{
				size = v(1, 0.5, 0.7),
				offset = v(-4.2, 5.7, 12.6),
				colour = rgb(255, 200, 130),
				material = Enum.Material.Neon,
				light = { colour = rgb(255, 200, 140), brightness = 1.5, range = 14 },
			},
		},
		-- Tall floor speaker between the bed and the desk; the blown speaker event happens here
		dorm_speaker = {
			{ size = v(1.9, 3.6, 1.8), offset = v(4.6, 2.0, 12.6), colour = DARK },
			{
				size = v(0.1, 1.4, 1.4),
				offset = v(4.6, 1.3, 11.68),
				rotation = v(0, -90, 0),
				shape = Enum.PartType.Cylinder,
				colour = PURPLE,
				material = Enum.Material.Neon,
				lightRole = "speaker",
			},
			{
				size = v(0.1, 1.1, 1.1),
				offset = v(4.6, 1.3, 11.64),
				rotation = v(0, -90, 0),
				shape = Enum.PartType.Cylinder,
				colour = rgb(40, 40, 48),
			},
			{
				size = v(0.1, 0.9, 0.9),
				offset = v(4.6, 2.95, 11.68),
				rotation = v(0, -90, 0),
				shape = Enum.PartType.Cylinder,
				colour = PURPLE,
				material = Enum.Material.Neon,
				lightRole = "speaker",
			},
			{
				size = v(0.1, 0.65, 0.65),
				offset = v(4.6, 2.95, 11.64),
				rotation = v(0, -90, 0),
				shape = Enum.PartType.Cylinder,
				colour = rgb(40, 40, 48),
			},
		},
		-- Purple strip along the top of the walls
		dorm_led = {
			{
				size = v(23.8, 0.25, 0.25),
				offset = v(0, 11.6, 13.85),
				colour = PURPLE,
				material = Enum.Material.Neon,
				light = { colour = PURPLE, brightness = 1, range = 18 },
				lightRole = "led",
			},
			{
				size = v(0.25, 0.25, 19.8),
				offset = v(11.85, 11.6, 4.1),
				colour = PURPLE,
				material = Enum.Material.Neon,
				light = { colour = PURPLE, brightness = 0.6, range = 14 },
				lightRole = "led",
			},
			{
				size = v(0.25, 0.25, 19.8),
				offset = v(-11.85, 11.6, 4.1),
				colour = PURPLE,
				material = Enum.Material.Neon,
				light = { colour = PURPLE, brightness = 0.6, range = 14 },
				lightRole = "led",
			},
		},
		-- A small DJ controller next to the laptop (gear: multiplies income)
		dorm_controller = {
			{ size = v(2.6, 0.2, 1.4), offset = v(-2.75, 3.5, 11.5), colour = rgb(40, 40, 46) },
			{
				size = v(0.1, 0.9, 0.9),
				offset = v(-2.15, 3.62, 11.55),
				rotation = v(0, 0, -90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(90, 90, 100),
			},
			{
				size = v(0.1, 0.9, 0.9),
				offset = v(-3.35, 3.62, 11.55),
				rotation = v(0, 0, -90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(90, 90, 100),
			},
			{
				size = v(2.6, 0.05, 0.1),
				offset = v(-2.75, 3.61, 10.85),
				colour = rgb(80, 220, 255),
				material = Enum.Material.Neon,
				lightRole = "screen",
			},
		},
		-- Three posters over the bed
		dorm_posters = {
			{ size = v(0.1, 3.2, 2.4), offset = v(11.95, 7, 3.6), colour = rgb(30, 28, 40) },
			{
				size = v(0.05, 1.8, 1.8),
				offset = v(11.88, 7.2, 3.6),
				shape = Enum.PartType.Cylinder,
				colour = rgb(230, 60, 110),
			},
			{ size = v(0.1, 3.2, 2.4), offset = v(11.95, 7, 6.6), colour = rgb(30, 28, 40) },
			{ size = v(0.05, 0.35, 1.9), offset = v(11.88, 7.8, 6.6), colour = rgb(140, 90, 220) },
			{ size = v(0.05, 0.35, 1.9), offset = v(11.88, 7.1, 6.6), colour = rgb(140, 90, 220) },
			{ size = v(0.05, 0.35, 1.9), offset = v(11.88, 6.4, 6.6), colour = rgb(140, 90, 220) },
			{ size = v(0.1, 3.2, 2.4), offset = v(11.95, 7, 9.6), colour = rgb(30, 28, 40) },
			{
				size = v(0.05, 1.6, 1.6),
				offset = v(11.88, 7.1, 9.6),
				rotation = v(45, 0, 0),
				colour = PINK,
			},
		},
		-- Two bean bags beside the dance floor
		dorm_beanbags = {
			{
				size = v(3, 3, 3),
				offset = v(-6, 0.9, 1.4),
				shape = Enum.PartType.Ball,
				colour = rgb(130, 70, 170),
				material = Enum.Material.Fabric,
			},
			{
				size = v(2.8, 2.8, 2.8),
				offset = v(-4.6, 0.8, -3.4),
				shape = Enum.PartType.Ball,
				colour = rgb(40, 38, 60),
				material = Enum.Material.Fabric,
			},
		},
		dorm_discoball = {
			{ size = v(0.1, 1.6, 0.1), offset = v(0, 11.2, 3), colour = DARK, collide = false },
			{
				size = v(1.6, 1.6, 1.6),
				offset = v(0, 9.6, 3),
				shape = Enum.PartType.Ball,
				colour = rgb(220, 220, 230),
				material = Enum.Material.Foil,
				collide = false,
				light = { colour = rgb(255, 255, 255), brightness = 1, range = 16 },
				lightRole = "disco",
			},
		},
		-- Two spot fixtures in the back corners, aimed at the dance floor
		dorm_partylights = {
			{ size = v(1, 1, 0.9), offset = v(10.4, 11.0, 13.2), rotation = v(-35, 30, 0), colour = DARK },
			{
				size = v(0.7, 0.7, 0.1),
				offset = v(10.15, 10.75, 12.85),
				rotation = v(-35, 30, 0),
				colour = PINK,
				material = Enum.Material.Neon,
				collide = false,
				light = { colour = PINK, brightness = 2, range = 24, spot = 50 },
				lightRole = "spot",
			},
			{ size = v(1, 1, 0.9), offset = v(-10.4, 11.0, 13.2), rotation = v(-35, -30, 0), colour = DARK },
			{
				size = v(0.7, 0.7, 0.1),
				offset = v(-10.15, 10.75, 12.85),
				rotation = v(-35, -30, 0),
				colour = rgb(60, 220, 255),
				material = Enum.Material.Neon,
				collide = false,
				light = { colour = rgb(60, 220, 255), brightness = 2, range = 24, spot = 50 },
				lightRole = "spot",
			},
		},
		dorm_neon = {
			{
				size = v(5, 1.6, 0.15),
				offset = v(8, 9.4, 13.9),
				colour = DARK,
				text = { text = "DROP IT", colour = PINK },
				light = { colour = PINK, brightness = 1, range = 10 },
				lightRole = "neon",
			},
		},
	},

	guests = {
		entrance = v(-10.6, 0.2, -2.2),
		spots = { v(0.8, 0.2, 2.6), v(-2.4, 0.2, 1.4), v(3.6, 0.2, -0.4), v(-0.8, 0.2, -1.6), v(2, 0.2, -3.8) },
		lookAt = v(-0.6, 0.2, 11.5),
	},

	decks = {
		itemId = "dorm_laptop",
		stand = v(-0.4, 0.2, 9.0),
		camera = v(-1.2, 9.6, 13.0),
		cameraLookAt = v(-0.4, 2.6, -1.5),
	},

	speakerItem = "dorm_speaker",
}

return Dorm
