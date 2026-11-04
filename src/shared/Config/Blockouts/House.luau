--!strict
-- The house party blockout, laid out after docs/concept/house-party.webp (model sheet "House
-- party"): Lena's living room, 34 x 26 with 14-stud walls, open at the front. Seen from the street
-- (looking along +Z) the left wall is at +X: sofa, posters and the lounge corner on the left, the
-- kitchen and the front door on the right, the DJ table at the back between two speakers, with the
-- DJ behind it facing the room. Floor top at y = 0.2. Soda cans, never cups.

local Types = require(script.Parent.Parent.Parent.Types)

local v = Vector3.new
local rgb = Color3.fromRGB

local WALL = rgb(216, 200, 190)
local TRIM = rgb(84, 70, 66)
local OAK = rgb(150, 108, 72)
local WOOD = rgb(106, 84, 70)
local DARK = rgb(38, 36, 44)
local VELVET = rgb(74, 58, 114)
local PURPLE = rgb(180, 90, 255)
local PINK = rgb(255, 70, 200)
local CYAN = rgb(60, 220, 255)
local WARM = rgb(255, 200, 110)
local LEAF = rgb(56, 124, 70)
local NIGHT = rgb(26, 34, 82)
local CITY = rgb(14, 16, 34)

local function list(...: { Types.PartSpec }): { Types.PartSpec }
	local all = {}
	for _, group in { ... } do
		for _, spec in group do
			table.insert(all, spec)
		end
	end
	return all
end

-- A strand of warm bulbs along X at height `y` and depth `z`; every third bulb lights the room.
local function strand(y: number, z: number): { Types.PartSpec }
	local specs: { Types.PartSpec } = {
		{ size = v(33, 0.08, 0.08), offset = v(0, y + 0.3, z), colour = DARK, collide = false },
	}
	for i = 0, 10 do
		table.insert(specs, {
			size = v(0.5, 0.5, 0.5),
			offset = v(-15 + i * 3, y, z),
			shape = Enum.PartType.Ball,
			colour = WARM,
			material = Enum.Material.Neon,
			collide = false,
			light = if i % 3 == 1 then { colour = WARM, brightness = 0.6, range = 12 } else nil,
			lightRole = "led",
		})
	end
	return specs
end

-- A tall party speaker at `x`, its rings facing the room.
local function speaker(x: number): { Types.PartSpec }
	return {
		{ size = v(2.6, 6.5, 2.4), offset = v(x, 3.45, 15.6), colour = DARK },
		{
			size = v(0.1, 2, 2),
			offset = v(x, 2.4, 14.36),
			rotation = v(0, 90, 0),
			shape = Enum.PartType.Cylinder,
			colour = PURPLE,
			material = Enum.Material.Neon,
			lightRole = "speaker",
		},
		{
			size = v(0.1, 1.5, 1.5),
			offset = v(x, 2.4, 14.32),
			rotation = v(0, 90, 0),
			shape = Enum.PartType.Cylinder,
			colour = rgb(44, 44, 54),
		},
		{
			size = v(0.1, 1.2, 1.2),
			offset = v(x, 5.2, 14.36),
			rotation = v(0, 90, 0),
			shape = Enum.PartType.Cylinder,
			colour = PURPLE,
			material = Enum.Material.Neon,
			lightRole = "speaker",
		},
		{
			size = v(0.1, 0.85, 0.85),
			offset = v(x, 5.2, 14.32),
			rotation = v(0, 90, 0),
			shape = Enum.PartType.Cylinder,
			colour = rgb(44, 44, 54),
		},
	}
end

local function stool(z: number): { Types.PartSpec }
	return {
		{
			size = v(0.3, 1.4, 1.4),
			offset = v(-7.6, 3, z),
			rotation = v(0, 0, 90),
			shape = Enum.PartType.Cylinder,
			colour = rgb(90, 64, 48),
		},
		{ size = v(0.25, 2.7, 0.25), offset = v(-7.6, 1.55, z), colour = DARK },
		{
			size = v(0.1, 1, 1),
			offset = v(-7.6, 0.35, z),
			rotation = v(0, 0, 90),
			shape = Enum.PartType.Cylinder,
			colour = DARK,
		},
	}
end

local function plant(x: number, z: number): { Types.PartSpec }
	return {
		{ size = v(1.6, 1.6, 1.6), offset = v(x, 1, z), colour = rgb(226, 220, 214) },
		{ size = v(2.6, 2.6, 2.6), offset = v(x, 3, z), shape = Enum.PartType.Ball, colour = LEAF, collide = false },
		{
			size = v(2, 2, 2),
			offset = v(x + 0.4, 4.6, z),
			shape = Enum.PartType.Ball,
			colour = rgb(47, 94, 62),
			collide = false,
		},
	}
end

local function poster(z: number, colour: Color3, shape: string): { Types.PartSpec }
	local specs: { Types.PartSpec } = { { size = v(0.1, 5, 3.4), offset = v(16.95, 8.5, z), colour = rgb(30, 28, 40) } }
	if shape == "circle" then
		table.insert(specs, {
			size = v(0.05, 2.2, 2.2),
			offset = v(16.88, 9, z),
			shape = Enum.PartType.Cylinder,
			colour = colour,
		})
	elseif shape == "waves" then
		for i = 0, 2 do
			table.insert(specs, { size = v(0.05, 0.4, 2.6), offset = v(16.88, 9.6 - i * 1, z), colour = colour })
		end
	else
		table.insert(
			specs,
			{ size = v(0.05, 1.8, 1.8), offset = v(16.88, 8.8, z), rotation = v(45, 0, 0), colour = colour }
		)
	end
	return specs
end

-- Fairy lights around the balcony door (x -13..-5, up to y 10.5), on the back wall.
local function fairyLights(): { Types.PartSpec }
	local specs: { Types.PartSpec } = {}
	local function bulb(x: number, y: number)
		table.insert(specs, {
			size = v(0.4, 0.4, 0.4),
			offset = v(x, y, 19.7),
			shape = Enum.PartType.Ball,
			colour = WARM,
			material = Enum.Material.Neon,
			collide = false,
			lightRole = "led",
		})
	end
	for x = -13, -5 do
		bulb(x, 10.8)
	end
	for y = 1.5, 9.5, 1.6 do
		bulb(-13.3, y)
		bulb(-4.7, y)
	end
	table.insert(specs, {
		size = v(8, 0.15, 0.15),
		offset = v(-9, 3.5, 19.72),
		colour = WARM,
		material = Enum.Material.Neon,
		collide = false,
		light = { colour = WARM, brightness = 0.8, range = 14 },
		lightRole = "led",
	})
	return specs
end

local function cityLight(x: number, y: number): Types.PartSpec
	return {
		size = v(0.25, 0.3, 0.05),
		offset = v(x, y, 19.74),
		colour = rgb(255, 196, 120),
		material = Enum.Material.Neon,
		collide = false,
	}
end

local House: Types.Blockout = {
	shell = list({
		-- Floor and walls
		{ size = v(34, 0.2, 26), offset = v(0, 0.1, 7), colour = OAK, material = Enum.Material.WoodPlanks },
		{ size = v(36, 14, 1), offset = v(0, 7, 20.5), colour = WALL },
		{ size = v(1, 14, 26), offset = v(17.5, 7, 7), colour = WALL },
		{ size = v(1, 14, 26), offset = v(-17.5, 7, 7), colour = WALL },
		{ size = v(34, 0.4, 0.1), offset = v(0, 0.4, 19.95), colour = TRIM },
		{ size = v(0.1, 0.4, 26), offset = v(16.95, 0.4, 7), colour = TRIM },
		{ size = v(0.1, 0.4, 26), offset = v(-16.95, 0.4, 7), colour = TRIM },

		-- Glass balcony door, back right, with the city behind it
		{ size = v(8.6, 10.6, 0.2), offset = v(-9, 5.5, 19.9), colour = TRIM },
		{ size = v(8, 10, 0.1), offset = v(-9, 5.5, 19.82), colour = NIGHT, material = Enum.Material.Neon },
		{ size = v(1.8, 4, 0.05), offset = v(-11.5, 4.6, 19.76), colour = CITY, collide = false },
		{ size = v(1.4, 6, 0.05), offset = v(-8.6, 5.6, 19.76), colour = CITY, collide = false },
		{ size = v(2, 3.4, 0.05), offset = v(-6.4, 4.3, 19.76), colour = CITY, collide = false },
		cityLight(-11.8, 5.6),
		cityLight(-11.2, 4.2),
		cityLight(-8.4, 7.4),
		cityLight(-8.9, 5.2),
		cityLight(-6.2, 5.1),
		{ size = v(0.2, 10, 0.12), offset = v(-9, 5.5, 19.72), colour = TRIM },

		-- Shelves with books, back left
		{ size = v(5, 0.3, 1.2), offset = v(10, 9.5, 19.4), colour = WOOD },
		{ size = v(5, 0.3, 1.2), offset = v(10, 6.8, 19.4), colour = WOOD },
		{ size = v(0.5, 1.4, 1), offset = v(8.2, 10.35, 19.4), colour = rgb(122, 60, 94) },
		{ size = v(0.5, 1.2, 1), offset = v(8.8, 10.25, 19.4), colour = rgb(60, 74, 122) },
		{ size = v(0.5, 1.3, 1), offset = v(9.4, 10.3, 19.4), colour = rgb(200, 180, 120) },
		{
			size = v(1.2, 1.2, 1.2),
			offset = v(11.6, 7.55, 19.4),
			shape = Enum.PartType.Ball,
			colour = LEAF,
			collide = false,
		},

		-- Kitchen on the right wall
		{
			size = v(3, 7.4, 3),
			offset = v(-15.4, 3.9, 17.6),
			colour = rgb(200, 204, 212),
			material = Enum.Material.Metal,
		},
		{ size = v(3, 3.4, 8), offset = v(-15.9, 1.9, 10.5), colour = WOOD },
		{ size = v(3.2, 0.3, 8.2), offset = v(-15.9, 3.75, 10.5), colour = rgb(224, 216, 208) },
		{ size = v(1.6, 3, 8), offset = v(-16.6, 9, 10.5), colour = WOOD },
		{ size = v(0.2, 0.15, 7.6), offset = v(-15.8, 7.4, 10.5), colour = WARM, material = Enum.Material.Neon },

		-- Front door on the right wall
		{ size = v(0.25, 7.6, 3.8), offset = v(-17, 4, -2.5), colour = rgb(96, 70, 56) },
		{ size = v(0.3, 8, 0.3), offset = v(-16.95, 4, -4.55), colour = TRIM },
		{ size = v(0.3, 8, 0.3), offset = v(-16.95, 4, -0.45), colour = TRIM },
		{ size = v(0.3, 0.3, 4.4), offset = v(-16.95, 8, -2.5), colour = TRIM },
		{
			size = v(0.3, 0.15, 0.6),
			offset = v(-16.8, 3.8, -1.2),
			colour = rgb(190, 190, 200),
			material = Enum.Material.Metal,
		},

		-- Lounge corner, front left: rug, coffee table with soda cans, ottoman
		{
			size = v(12, 0.05, 9),
			offset = v(10.5, 0.225, 4.5),
			colour = rgb(90, 62, 106),
			material = Enum.Material.Fabric,
		},
		{ size = v(3, 0.4, 6), offset = v(10.5, 1.6, 4.5), colour = rgb(64, 46, 36) },
		{ size = v(0.4, 1.2, 0.4), offset = v(9.4, 0.8, 2), colour = rgb(64, 46, 36) },
		{ size = v(0.4, 1.2, 0.4), offset = v(11.6, 0.8, 2), colour = rgb(64, 46, 36) },
		{ size = v(0.4, 1.2, 0.4), offset = v(9.4, 0.8, 7), colour = rgb(64, 46, 36) },
		{ size = v(0.4, 1.2, 0.4), offset = v(11.6, 0.8, 7), colour = rgb(64, 46, 36) },
		{
			size = v(0.6, 0.35, 0.35),
			offset = v(10.2, 2.1, 3.6),
			rotation = v(0, 0, 90),
			shape = Enum.PartType.Cylinder,
			colour = rgb(60, 122, 220),
		},
		{
			size = v(0.6, 0.35, 0.35),
			offset = v(10.8, 2.1, 4.6),
			rotation = v(0, 0, 90),
			shape = Enum.PartType.Cylinder,
			colour = rgb(230, 70, 70),
		},
		{
			size = v(0.6, 0.35, 0.35),
			offset = v(10.3, 2.1, 5.6),
			rotation = v(0, 0, 90),
			shape = Enum.PartType.Cylinder,
			colour = rgb(70, 200, 120),
		},
		{ size = v(3, 2, 3), offset = v(6.5, 1.2, -3), colour = rgb(58, 48, 72), material = Enum.Material.Fabric },

		-- A dim warm ceiling light so the room reads before anything is bought
		{
			size = v(1, 1, 1),
			offset = v(0, 13, 7),
			colour = DARK,
			transparency = 1,
			collide = false,
			light = { colour = rgb(255, 210, 170), brightness = 0.6, range = 32 },
		},
	}),

	items = {
		house_djtable = {
			{ size = v(7, 3.4, 2.8), offset = v(0, 1.9, 15), colour = DARK },
			{ size = v(7.4, 0.2, 3), offset = v(0, 3.7, 15), colour = rgb(56, 52, 62) },
			{
				size = v(6.6, 0.25, 0.1),
				offset = v(0, 2.6, 13.55),
				colour = rgb(255, 170, 90),
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{ size = v(1.8, 0.12, 1.3), offset = v(-2.6, 3.86, 15.2), colour = rgb(60, 62, 70) },
			{
				size = v(1.8, 1.3, 0.1),
				offset = v(-2.6, 4.5, 14.6),
				rotation = v(-15, 0, 0),
				colour = rgb(70, 110, 220),
				material = Enum.Material.Neon,
				lightRole = "screen",
			},
		},
		house_speakers = list(speaker(6.5), speaker(-6.5)),
		house_stringlights = list(strand(12.6, 2), strand(12.6, 8), strand(12.6, 14)),
		house_sofa = {
			{ size = v(4, 1.6, 10), offset = v(14.8, 1, 4.5), colour = VELVET, material = Enum.Material.Fabric },
			{
				size = v(3, 0.6, 9.6),
				offset = v(14.4, 2.1, 4.5),
				colour = rgb(84, 66, 126),
				material = Enum.Material.Fabric,
			},
			{ size = v(1, 2.6, 10), offset = v(16.5, 2.5, 4.5), colour = VELVET, material = Enum.Material.Fabric },
			{ size = v(4, 2.4, 0.9), offset = v(14.8, 1.4, -0.05), colour = VELVET, material = Enum.Material.Fabric },
			{ size = v(4, 2.4, 0.9), offset = v(14.8, 1.4, 9.05), colour = VELVET, material = Enum.Material.Fabric },
		},
		house_controller = {
			{ size = v(4.5, 0.4, 1.6), offset = v(0.9, 4, 15.1), colour = rgb(40, 40, 48) },
			{
				size = v(0.1, 1, 1),
				offset = v(-0.5, 4.25, 15.2),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(90, 90, 100),
			},
			{
				size = v(0.1, 1, 1),
				offset = v(0.9, 4.25, 15.2),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(90, 90, 100),
			},
			{
				size = v(0.1, 1, 1),
				offset = v(2.3, 4.25, 15.2),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(90, 90, 100),
			},
			{
				size = v(4.2, 0.05, 0.3),
				offset = v(0.9, 4.23, 14.45),
				colour = PINK,
				material = Enum.Material.Neon,
				lightRole = "screen",
			},
		},
		house_posters = list(
			poster(1, rgb(255, 106, 60), "circle"),
			poster(4.6, rgb(154, 90, 255), "waves"),
			poster(8.2, PINK, "diamond")
		),
		house_floorlamp = {
			{ size = v(1.2, 0.2, 1.2), offset = v(15, 0.3, -4.5), colour = DARK },
			{ size = v(0.3, 5, 0.3), offset = v(15, 2.9, -4.5), colour = DARK },
			{
				size = v(2, 1.6, 1.6),
				offset = v(15, 6.2, -4.5),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(255, 210, 140),
				material = Enum.Material.Neon,
				light = { colour = rgb(255, 200, 140), brightness = 1.4, range = 16 },
			},
		},
		house_counter = {
			{ size = v(3, 3.4, 8), offset = v(-10, 1.9, 6), colour = WOOD },
			{ size = v(3.6, 0.3, 8.6), offset = v(-10, 3.75, 6), colour = rgb(224, 216, 208) },
			{
				size = v(0.6, 0.35, 0.35),
				offset = v(-10, 4.2, 3.4),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(60, 122, 220),
			},
			{
				size = v(0.6, 0.35, 0.35),
				offset = v(-10.3, 4.2, 4.4),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(230, 70, 70),
			},
			{
				size = v(0.6, 0.35, 0.35),
				offset = v(-9.7, 4.2, 5.3),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(70, 200, 120),
			},
			{
				size = v(0.6, 0.35, 0.35),
				offset = v(-10.2, 4.2, 6.3),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(255, 200, 60),
			},
			{
				size = v(0.5, 1.4, 1.4),
				offset = v(-10, 4.15, 8.4),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(230, 160, 80),
			},
		},
		house_stools = list(stool(4), stool(8)),
		house_partylights = {
			{ size = v(1.2, 1.2, 1), offset = v(14.6, 13, 19.2), rotation = v(-35, 30, 0), colour = DARK },
			{
				size = v(0.8, 0.8, 0.1),
				offset = v(14.35, 12.75, 18.85),
				rotation = v(-35, 30, 0),
				colour = PINK,
				material = Enum.Material.Neon,
				collide = false,
				light = { colour = PINK, brightness = 2.2, range = 30, spot = 55 },
				lightRole = "spot",
			},
			{ size = v(1.2, 1.2, 1), offset = v(-14.6, 13, 19.2), rotation = v(-35, -30, 0), colour = DARK },
			{
				size = v(0.8, 0.8, 0.1),
				offset = v(-14.35, 12.75, 18.85),
				rotation = v(-35, -30, 0),
				colour = CYAN,
				material = Enum.Material.Neon,
				collide = false,
				light = { colour = CYAN, brightness = 2.2, range = 30, spot = 55 },
				lightRole = "spot",
			},
		},
		house_popper = {
			{ size = v(1.2, 1.4, 1.2), offset = v(4.8, 0.9, 13.4), colour = DARK },
			{
				size = v(2.2, 0.8, 0.8),
				offset = v(4.8, 2.7, 13.4),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(232, 232, 240),
			},
			{
				size = v(0.15, 0.95, 0.95),
				offset = v(4.8, 3.85, 13.4),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = PINK,
				material = Enum.Material.Neon,
				lightRole = "neon",
			},
		},
		house_plants = list(plant(-4, 18.4), plant(-14, 18.4)),
		house_booking = {
			{
				size = v(0.1, 3.8, 5.4),
				offset = v(-16.97, 6, 2.5),
				colour = rgb(255, 170, 90),
				material = Enum.Material.Neon,
			},
			{ size = v(0.2, 3.4, 5), offset = v(-16.9, 6, 2.5), colour = rgb(160, 120, 80) },
			{ size = v(0.05, 1.4, 1), offset = v(-16.78, 6.3, 1), colour = rgb(244, 242, 250) },
			{ size = v(0.05, 1.4, 1), offset = v(-16.78, 6.1, 2.5), colour = rgb(244, 242, 250) },
			{ size = v(0.05, 1.4, 1), offset = v(-16.78, 6.4, 4), colour = rgb(244, 242, 250) },
		},
		house_neon = {
			{
				size = v(7, 2, 0.2),
				offset = v(0, 10.5, 19.85),
				colour = rgb(22, 22, 30),
				text = { text = "PARTY", colour = PINK },
				light = { colour = PINK, brightness = 1, range = 12 },
				lightRole = "neon",
			},
		},
		house_balcony = fairyLights(),
	},

	guests = {
		entrance = v(-15.6, 0.2, -2.5),
		spots = {
			v(-3, 0.2, 4),
			v(1, 0.2, 5),
			v(4.5, 0.2, 3.5),
			v(-1.5, 0.2, 8.5),
			v(2.5, 0.2, 9),
			v(-4.5, 0.2, 11),
			v(0.5, 0.2, 11.5),
			v(5, 0.2, 10.5),
			v(-3.5, 0.2, 0.5),
			v(2, 0.2, 1),
			v(-5.5, 0.2, 7),
			v(6, 0.2, 7),
			v(-0.5, 0.2, -2),
			v(4, 0.2, -1.5),
			-- The rest of a full party, round the edges of the room
			v(-3.5, 0.2, 12.5),
			v(-5.8, 0.2, 3),
			v(6.8, 0.2, 5.2),
			v(-2.5, 0.2, -4.8),
			v(3, 0.2, -4.5),
			v(6.5, 0.2, 1.5),
			v(7.8, 0.2, 9.5),
			v(-6.8, 0.2, 11),
			v(-7.2, 0.2, -2.5),
			v(10, 0.2, -2),
			v(-9, 0.2, 0),
		},
		lookAt = v(0, 0.2, 17.8),
	},

	decks = {
		itemId = "house_djtable",
		stand = v(0, 0.2, 17.8),
		camera = v(0, 9, 19.6),
		cameraLookAt = v(0, 2.6, 0),
	},

	speakerItem = "house_speakers",
}

return House
