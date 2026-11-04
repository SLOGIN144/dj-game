--!strict
-- The underground club blockout, laid out after docs/concept/club.webp (model sheet "Underground
-- club"): Rosa's basement, 44 x 36 with 16-stud walls, open at the front. Seen from the street the
-- left wall is at +X: the entrance stairs and the lounge on the left, the soda bar on the right, the
-- booth on a riser at the back with the DJ behind it, a truss of moving heads and strobes above an
-- LED dance floor. One dominant blue, white beams through haze. The bar serves soda only.

local Types = require(script.Parent.Parent.Parent.Types)

local v = Vector3.new
local rgb = Color3.fromRGB

local CONCRETE = rgb(74, 76, 86)
local FLOOR = rgb(52, 54, 62)
local BRICK = rgb(110, 58, 52)
local DARK = rgb(28, 28, 36)
local BLUE = rgb(60, 100, 255)
local PALE = rgb(140, 180, 255)
local WHITE = rgb(255, 255, 255)
local STEEL = rgb(154, 154, 170)
local LEATHER = rgb(30, 30, 40)

local function list(...: { Types.PartSpec }): { Types.PartSpec }
	local all = {}
	for _, group in { ... } do
		for _, spec in group do
			table.insert(all, spec)
		end
	end
	return all
end

local function ring(x: number, y: number, z: number, outer: number): { Types.PartSpec }
	return {
		{
			size = v(0.1, outer, outer),
			offset = v(x, y, z),
			rotation = v(0, 90, 0),
			shape = Enum.PartType.Cylinder,
			colour = BLUE,
			material = Enum.Material.Neon,
			lightRole = "speaker",
		},
		{
			size = v(0.1, outer * 0.75, outer * 0.75),
			offset = v(x, y, z - 0.04),
			rotation = v(0, 90, 0),
			shape = Enum.PartType.Cylinder,
			colour = rgb(40, 40, 50),
		},
	}
end

local function stack(x: number): { Types.PartSpec }
	return list({
		{ size = v(4, 4, 3.5), offset = v(x, 3.4, 25), colour = DARK },
		{ size = v(4, 4, 3.5), offset = v(x, 7.45, 25), colour = DARK },
	}, ring(x, 3.4, 23.2, 2.6), ring(x, 7.45, 23.2, 2.6))
end

local function stool(z: number): { Types.PartSpec }
	return {
		{
			size = v(0.3, 1.4, 1.4),
			offset = v(-15, 3.2, z),
			rotation = v(0, 0, 90),
			shape = Enum.PartType.Cylinder,
			colour = LEATHER,
		},
		{ size = v(0.25, 3, 0.25), offset = v(-15, 1.7, z), colour = STEEL, material = Enum.Material.Metal },
		{
			size = v(0.1, 1.1, 1.1),
			offset = v(-15, 0.25, z),
			rotation = v(0, 0, 90),
			shape = Enum.PartType.Cylinder,
			colour = STEEL,
			material = Enum.Material.Metal,
		},
	}
end

local function sofa(z: number): { Types.PartSpec }
	return {
		{ size = v(3.5, 1.6, 7), offset = v(19.8, 1, z), colour = LEATHER, material = Enum.Material.Fabric },
		{ size = v(1, 2.6, 7), offset = v(21.4, 2.3, z), colour = LEATHER, material = Enum.Material.Fabric },
		{ size = v(2, 0.3, 2), offset = v(16.4, 2.4, z), colour = rgb(42, 42, 52) },
		{ size = v(0.4, 2.2, 0.4), offset = v(16.4, 1.2, z), colour = rgb(42, 42, 52) },
		{
			size = v(0.6, 0.4, 0.4),
			offset = v(16.4, 2.85, z),
			rotation = v(0, 0, 90),
			shape = Enum.PartType.Cylinder,
			colour = BLUE,
			material = Enum.Material.Neon,
			light = { colour = BLUE, brightness = 0.6, range = 8 },
		},
	}
end

-- A moving head hanging from the truss at `x`, aimed down at the dance floor.
local function movingHead(x: number): { Types.PartSpec }
	return {
		{ size = v(1.6, 0.4, 1.2), offset = v(x, 12.6, 21), colour = DARK },
		{ size = v(1.2, 1.4, 1.2), offset = v(x, 11.6, 21), rotation = v(-55, 0, 0), colour = DARK },
		{
			size = v(0.8, 0.8, 0.1),
			offset = v(x, 11.07, 20.63),
			rotation = v(-55, 0, 0),
			colour = WHITE,
			material = Enum.Material.Neon,
			collide = false,
			light = { colour = WHITE, brightness = 3, range = 45, spot = 25 },
			beam = { length = 22, width = 0.6 },
			lightRole = "spot",
		},
	}
end

local function tile(x: number, z: number, bright: boolean): Types.PartSpec
	return {
		size = v(3.8, 0.2, 3.8),
		offset = v(x, 0.3, z),
		colour = if bright then rgb(170, 200, 255) else BLUE,
		material = Enum.Material.Neon,
		lightRole = "led",
	}
end

local function dancefloor(): { Types.PartSpec }
	local tiles = {}
	for column, x in { -6, -2, 2, 6 } do
		for row, z in { 6, 10, 14 } do
			table.insert(tiles, tile(x, z, (column + row) % 2 == 0))
		end
	end
	return tiles
end

local function bottles(y: number): { Types.PartSpec }
	local colours = {
		rgb(70, 200, 120),
		rgb(255, 200, 60),
		rgb(60, 220, 255),
		rgb(240, 80, 80),
		rgb(255, 70, 200),
		rgb(255, 150, 60),
	}
	local specs: { Types.PartSpec } = {}
	for i, colour in colours do
		table.insert(specs, {
			size = v(1, 0.5, 0.5),
			offset = v(-21.6, y, 2 + i * 1.8),
			rotation = v(0, 0, 90),
			shape = Enum.PartType.Cylinder,
			colour = colour,
		})
	end
	return specs
end

local function stairs(): { Types.PartSpec }
	local specs: { Types.PartSpec } = {}
	for i = 0, 7 do
		local height = 0.75 * (i + 1)
		table.insert(specs, {
			size = v(5, height, 1.2),
			offset = v(19.5, 0.2 + height / 2, 3.4 - i * 1.2),
			colour = rgb(84, 86, 96),
			material = Enum.Material.Concrete,
		})
	end
	table.insert(specs, {
		size = v(5, 6.2, 1.6),
		offset = v(19.5, 3.3, -5.2),
		colour = rgb(84, 86, 96),
		material = Enum.Material.Concrete,
	})
	table.insert(specs, {
		size = v(0.3, 0.6, 1),
		offset = v(21.9, 8, -4.8),
		colour = rgb(255, 210, 160),
		material = Enum.Material.Neon,
		light = { colour = rgb(255, 210, 160), brightness = 0.8, range = 12 },
	})
	return specs
end

local Club: Types.Blockout = {
	shell = list({
		{ size = v(44, 0.2, 36), offset = v(0, 0.1, 12), colour = FLOOR, material = Enum.Material.Concrete },
		{ size = v(46, 16, 1), offset = v(0, 8, 30.5), colour = BRICK, material = Enum.Material.Brick },
		{ size = v(1, 16, 36), offset = v(22.5, 8, 12), colour = CONCRETE, material = Enum.Material.Concrete },
		{ size = v(1, 16, 36), offset = v(-22.5, 8, 12), colour = CONCRETE, material = Enum.Material.Concrete },
		-- Pipes under the ceiling line
		{
			size = v(44, 0.8, 0.8),
			offset = v(0, 15, 29.4),
			shape = Enum.PartType.Cylinder,
			colour = rgb(90, 92, 104),
			material = Enum.Material.Metal,
		},
		{
			size = v(36, 0.6, 0.6),
			offset = v(21.6, 15.2, 12),
			rotation = v(0, 90, 0),
			shape = Enum.PartType.Cylinder,
			colour = rgb(90, 92, 104),
			material = Enum.Material.Metal,
		},
		-- The booth riser with a cold edge light
		{ size = v(18, 1.4, 9), offset = v(0, 0.7, 25), colour = rgb(34, 34, 42) },
		{ size = v(18, 0.2, 0.2), offset = v(0, 1.35, 20.45), colour = BLUE, material = Enum.Material.Neon },
		-- A dim blue room light
		{
			size = v(1, 1, 1),
			offset = v(0, 15, 12),
			colour = DARK,
			transparency = 1,
			collide = false,
			light = { colour = rgb(70, 100, 210), brightness = 0.5, range = 40 },
		},
	}, stairs()),

	items = {
		club_booth = {
			{ size = v(12, 3.8, 3), offset = v(0, 3.3, 23), colour = DARK },
			{ size = v(12.4, 0.2, 3.2), offset = v(0, 5.3, 23), colour = rgb(40, 40, 50) },
			{
				size = v(11.6, 0.3, 0.1),
				offset = v(0, 3, 21.45),
				colour = BLUE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
		},
		club_speakers = list(stack(11.5), stack(-11.5)),
		club_ledstrips = {
			{
				size = v(44, 0.3, 0.3),
				offset = v(0, 15.4, 29.9),
				colour = BLUE,
				material = Enum.Material.Neon,
				light = { colour = BLUE, brightness = 1.2, range = 30 },
				lightRole = "led",
			},
			{
				size = v(0.3, 6, 0.3),
				offset = v(21.9, 8, 2),
				colour = BLUE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{
				size = v(0.3, 6, 0.3),
				offset = v(21.9, 8, 12),
				colour = BLUE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{
				size = v(0.3, 6, 0.3),
				offset = v(21.9, 8, 22),
				colour = BLUE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{
				size = v(0.3, 6, 0.3),
				offset = v(-21.9, 8, 2),
				colour = BLUE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{
				size = v(0.3, 6, 0.3),
				offset = v(-21.9, 8, 12),
				colour = BLUE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{
				size = v(0.3, 6, 0.3),
				offset = v(-21.9, 8, 22),
				colour = BLUE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
		},
		club_bar = list({
			{ size = v(3, 3.8, 14), offset = v(-17.5, 1.9, 8), colour = DARK },
			{ size = v(3.4, 0.3, 14.4), offset = v(-17.5, 3.95, 8), colour = rgb(70, 72, 84) },
			{
				size = v(0.1, 0.25, 13.6),
				offset = v(-15.95, 0.5, 8),
				colour = BLUE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{ size = v(0.6, 0.2, 14), offset = v(-21.6, 5, 8), colour = rgb(60, 60, 70) },
			{ size = v(0.6, 0.2, 14), offset = v(-21.6, 7.4, 8), colour = rgb(60, 60, 70) },
			{
				size = v(0.1, 0.15, 14),
				offset = v(-21.25, 4.85, 8),
				colour = BLUE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{ size = v(3, 7, 3), offset = v(-20.5, 3.7, 17.2), colour = DARK },
			{
				size = v(2.6, 6.4, 0.1),
				offset = v(-20.5, 3.7, 15.65),
				colour = rgb(40, 80, 180),
				material = Enum.Material.Neon,
			},
		}, bottles(5.6), bottles(8)),
		club_mixer = {
			{ size = v(5, 0.8, 1.8), offset = v(0, 5.8, 23.1), colour = rgb(42, 42, 50) },
			{
				size = v(0.1, 1.2, 1.2),
				offset = v(-1.6, 6.25, 23.1),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(80, 80, 92),
			},
			{
				size = v(0.1, 1.2, 1.2),
				offset = v(1.6, 6.25, 23.1),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(80, 80, 92),
			},
			{
				size = v(4.6, 0.05, 0.3),
				offset = v(0, 6.22, 22.35),
				colour = PALE,
				material = Enum.Material.Neon,
				lightRole = "screen",
			},
		},
		club_stools = list(stool(3), stool(8), stool(13)),
		club_lounge = list(sofa(9), sofa(17.5)),
		club_dancefloor = dancefloor(),
		club_truss = {
			{ size = v(32, 1.5, 1.5), offset = v(0, 13.5, 21), colour = STEEL, material = Enum.Material.DiamondPlate },
			{ size = v(0.2, 2, 0.2), offset = v(-12, 15.2, 21), colour = STEEL },
			{ size = v(0.2, 2, 0.2), offset = v(12, 15.2, 21), colour = STEEL },
		},
		club_movingheads = list(movingHead(-12), movingHead(-4), movingHead(4), movingHead(12)),
		club_haze = {
			{
				size = v(2, 1.4, 1.4),
				offset = v(10.5, 2.1, 21.8),
				colour = DARK,
				smoke = { colour = rgb(120, 140, 210), opacity = 0.06, size = 14, rise = 0.4 },
			},
			{ size = v(0.6, 0.5, 0.5), offset = v(10.5, 2.1, 21), colour = rgb(50, 50, 60) },
		},
		club_subwoofers = list({
			{ size = v(5, 3, 3), offset = v(7, 1.7, 18.8), colour = DARK },
			{ size = v(5, 3, 3), offset = v(-7, 1.7, 18.8), colour = DARK },
		}, ring(7, 1.7, 17.25, 2.4), ring(-7, 1.7, 17.25, 2.4)),
		club_co2 = {
			{ size = v(1, 1.6, 1), offset = v(8.4, 2.2, 21), colour = DARK, fx = "co2" },
			{ size = v(1, 1.6, 1), offset = v(-8.4, 2.2, 21), colour = DARK, fx = "co2" },
		},
		club_merch = {
			{ size = v(2.4, 2.6, 6), offset = v(-20.2, 1.5, -3.5), colour = rgb(42, 42, 52) },
			{ size = v(0.2, 0.2, 6), offset = v(-21.2, 6, -3.5), colour = STEEL },
			{ size = v(0.1, 2.2, 1.8), offset = v(-21.1, 4.7, -5.5), colour = BLUE },
			{ size = v(0.1, 2.2, 1.8), offset = v(-21.1, 4.7, -3.5), colour = rgb(244, 242, 250) },
			{ size = v(0.1, 2.2, 1.8), offset = v(-21.1, 4.7, -1.5), colour = DARK },
		},
		club_booking = {
			{ size = v(6.4, 4.4, 0.2), offset = v(16, 7, 29.95), colour = BLUE, material = Enum.Material.Neon },
			{ size = v(6, 4, 0.3), offset = v(16, 7, 29.85), colour = rgb(18, 20, 38), lightRole = "screen" },
		},
		club_neon = {
			{
				size = v(14, 3, 0.3),
				offset = v(0, 11.6, 29.8),
				colour = rgb(22, 18, 26),
				text = { text = "BASEMENT", colour = BLUE },
				light = { colour = BLUE, brightness = 1.2, range = 16 },
				lightRole = "neon",
			},
		},
		club_strobes = {
			{
				size = v(2.4, 0.8, 0.6),
				offset = v(-14, 12.6, 20.1),
				colour = WHITE,
				material = Enum.Material.Neon,
				lightRole = "spot",
			},
			{
				size = v(2.4, 0.8, 0.6),
				offset = v(-6, 12.6, 20.1),
				colour = WHITE,
				material = Enum.Material.Neon,
				lightRole = "spot",
			},
			{
				size = v(2.4, 0.8, 0.6),
				offset = v(6, 12.6, 20.1),
				colour = WHITE,
				material = Enum.Material.Neon,
				lightRole = "spot",
			},
			{
				size = v(2.4, 0.8, 0.6),
				offset = v(14, 12.6, 20.1),
				colour = WHITE,
				material = Enum.Material.Neon,
				lightRole = "spot",
			},
		},
		-- Next to the plot's register kiosk, at the front of the plot
		club_register = {
			{ size = v(3, 3.4, 2.4), offset = v(15.4, 1.7, -22), colour = rgb(34, 38, 46) },
			{
				size = v(2.4, 0.8, 0.1),
				offset = v(15.4, 2.9, -23.25),
				colour = rgb(120, 255, 160),
				material = Enum.Material.Neon,
			},
		},
		club_vip = {
			{
				size = v(0.3, 2.2, 0.3),
				offset = v(14.5, 1.3, 20.8),
				colour = rgb(200, 180, 120),
				material = Enum.Material.Metal,
			},
			{
				size = v(0.3, 2.2, 0.3),
				offset = v(14.5, 1.3, 28),
				colour = rgb(200, 180, 120),
				material = Enum.Material.Metal,
			},
			{ size = v(0.15, 0.15, 7), offset = v(14.5, 2.1, 24.4), colour = rgb(140, 40, 70) },
			{
				size = v(2.8, 1.6, 7.5),
				offset = v(20.4, 1, 24.4),
				colour = rgb(42, 30, 90),
				material = Enum.Material.Fabric,
			},
			{
				size = v(0.8, 2.6, 7.5),
				offset = v(21.7, 2.3, 24.4),
				colour = rgb(42, 30, 90),
				material = Enum.Material.Fabric,
			},
			{
				size = v(0.4, 0.4, 0.4),
				offset = v(17.5, 0.4, 24.4),
				colour = BLUE,
				material = Enum.Material.Neon,
				light = { colour = BLUE, brightness = 1, range = 10 },
			},
		},
		club_4deck = {
			{ size = v(10, 0.8, 1.8), offset = v(0, 5.8, 23.1), colour = rgb(42, 42, 50) },
			{
				size = v(0.1, 1.1, 1.1),
				offset = v(-3.9, 6.25, 23.1),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(80, 80, 92),
			},
			{
				size = v(0.1, 1.1, 1.1),
				offset = v(-1.6, 6.25, 23.1),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(80, 80, 92),
			},
			{
				size = v(0.1, 1.1, 1.1),
				offset = v(1.6, 6.25, 23.1),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(80, 80, 92),
			},
			{
				size = v(0.1, 1.1, 1.1),
				offset = v(3.9, 6.25, 23.1),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(80, 80, 92),
			},
			{
				size = v(9.6, 0.05, 0.3),
				offset = v(0, 6.22, 22.35),
				colour = PALE,
				material = Enum.Material.Neon,
				lightRole = "screen",
			},
		},
	},

	guests = {
		entrance = v(19.5, 6.4, -5.2),
		spots = {
			v(-4.5, 0.2, 7),
			v(0, 0.2, 7.5),
			v(4.5, 0.2, 7),
			v(-2.2, 0.2, 10.5),
			v(2.2, 0.2, 11),
			v(-6.5, 0.2, 11),
			v(6.5, 0.2, 11.5),
			v(0, 0.2, 14),
			v(-4.5, 0.2, 14.5),
			v(4.5, 0.2, 14.5),
			v(-9, 0.2, 7.5),
			v(9, 0.2, 8),
			v(-2.2, 0.2, 3.5),
			v(2.2, 0.2, 4),
			v(-8.5, 0.2, 14),
			v(8.5, 0.2, 14),
			v(-6, 0.2, 3.5),
			v(6, 0.2, 3.5),
			v(0, 0.2, 0.5),
			v(-4, 0.2, 0),
			v(4, 0.2, 0),
			v(-10.5, 0.2, 3),
			v(10.5, 0.2, 3.5),
			v(-1, 0.2, -3),
			-- A packed night: the edges of the floor, by the bar and the lounge
			v(-12.5, 0.2, 10),
			v(12.5, 0.2, 10),
			v(-2, 0.2, 17),
			v(2, 0.2, 17),
			v(-12.5, 0.2, 15),
			v(12, 0.2, 15),
			v(-7, 0.2, -2.5),
			v(7, 0.2, -2.5),
			v(-13, 0.2, 5.5),
			v(13, 0.2, 6),
			v(-11, 0.2, -1.5),
			v(11, 0.2, -1),
			v(2.5, 0.2, -4.5),
			v(-4, 0.2, -4.5),
			v(-12.5, 0.2, 18.5),
			v(12.5, 0.2, 18.5),
		},
		lookAt = v(0, 1.4, 26.2),
	},

	decks = {
		itemId = "club_booth",
		stand = v(0, 1.4, 26.2),
		camera = v(0, 11, 29.6),
		cameraLookAt = v(0, 3, 2),
	},

	speakerItem = "club_speakers",
}

return Club
