--!strict
-- The Ibiza beach club blockout, laid out after docs/concept/ibiza.webp (model sheet "Ibiza beach
-- club"): an open-air venue of its own, away from the street, reached by the jet. Positions are
-- relative to the venue's origin; -Z faces the arrival airstrip and +Z the sea. Seen from the
-- entrance the left side is +X: a pool with loungers, cabanas and the VIP deck on the left, a pool,
-- the juice bar and the merch shop on the right, the dance deck in the middle and the stage with
-- its truss and LED wall at the back. Juice and water only.

local Types = require(script.Parent.Parent.Parent.Types)

local v = Vector3.new
local rgb = Color3.fromRGB

local STONE = rgb(230, 220, 204)
local SAND = rgb(224, 198, 150)
local WHITE = rgb(240, 234, 224)
local TEAK = rgb(168, 122, 82)
local DARK = rgb(42, 38, 48)
local ORANGE = rgb(255, 122, 60)
local MAGENTA = rgb(255, 60, 168)
local VIOLET = rgb(160, 90, 255)
local TURQUOISE = rgb(60, 220, 230)
local LEAF = rgb(62, 138, 80)
local TRUNK = rgb(138, 106, 74)
local WARM = rgb(255, 200, 110)
local STEEL = rgb(170, 170, 184)

local function list(...: { Types.PartSpec }): { Types.PartSpec }
	local all = {}
	for _, group in { ... } do
		for _, spec in group do
			table.insert(all, spec)
		end
	end
	return all
end

local function palm(x: number, z: number, lean: number): { Types.PartSpec }
	local top = v(x + lean * 0.2, 14, z)
	local specs: { Types.PartSpec } = {
		{
			size = v(14, 1.2, 1.2),
			offset = v(x + lean * 0.1, 7, z),
			rotation = v(0, 0, 90 + lean),
			shape = Enum.PartType.Cylinder,
			colour = TRUNK,
		},
		{
			size = v(0.6, 0.4, 0.6),
			offset = v(x, 0.3, z),
			colour = WARM,
			material = Enum.Material.Neon,
			light = { colour = WARM, brightness = 1, range = 12 },
		},
	}
	for k = 0, 4 do
		table.insert(specs, {
			size = v(6.5, 0.3, 1.8),
			offset = top,
			rotation = v(0, k * 72, -22),
			colour = if k % 2 == 0 then LEAF else rgb(52, 120, 68),
			collide = false,
		})
	end
	return specs
end

local function pool(x: number): { Types.PartSpec }
	return {
		{ size = v(24, 1, 14), offset = v(x, 0.5, 0), colour = WHITE, material = Enum.Material.Limestone },
		{
			size = v(22, 0.9, 12),
			offset = v(x, 0.6, 0),
			colour = TURQUOISE,
			material = Enum.Material.Neon,
			transparency = 0.25,
			collide = false,
			light = { colour = TURQUOISE, brightness = 0.8, range = 18 },
		},
	}
end

local function lounger(x: number, z: number): { Types.PartSpec }
	return {
		{ size = v(2, 0.6, 5.4), offset = v(x, 0.8, z), colour = TEAK },
		{ size = v(1.8, 0.3, 3.6), offset = v(x, 1.25, z + 0.8), colour = WHITE, material = Enum.Material.Fabric },
		{
			size = v(1.8, 0.3, 2),
			offset = v(x, 1.9, z - 1.7),
			rotation = v(40, 0, 0),
			colour = WHITE,
			material = Enum.Material.Fabric,
		},
	}
end

local function parasol(x: number, z: number): { Types.PartSpec }
	return {
		{ size = v(0.3, 6, 0.3), offset = v(x, 3, z), colour = TEAK },
		{
			size = v(0.4, 5.6, 5.6),
			offset = v(x, 6, z),
			rotation = v(0, 0, 90),
			shape = Enum.PartType.Cylinder,
			colour = WHITE,
			material = Enum.Material.Fabric,
			collide = false,
		},
	}
end

local function lantern(x: number, z: number): { Types.PartSpec }
	return {
		{ size = v(0.4, 6, 0.4), offset = v(x, 3, z), colour = rgb(40, 36, 44) },
		{
			size = v(1, 1.2, 1),
			offset = v(x, 6.4, z),
			colour = WARM,
			material = Enum.Material.Neon,
			light = { colour = WARM, brightness = 0.8, range = 14 },
			lightRole = "led",
		},
	}
end

local function cabana(x: number, z: number): { Types.PartSpec }
	local specs: { Types.PartSpec } = {
		{ size = v(7.4, 0.4, 7.4), offset = v(x, 7.2, z), colour = WHITE },
		{ size = v(5, 1, 4.5), offset = v(x, 0.7, z), colour = WHITE, material = Enum.Material.Fabric },
		{
			size = v(0.6, 0.6, 0.6),
			offset = v(x, 6.6, z),
			colour = WARM,
			material = Enum.Material.Neon,
			light = { colour = WARM, brightness = 0.6, range = 10 },
		},
	}
	for _, dx in { -3.2, 3.2 } do
		for _, dz in { -3.2, 3.2 } do
			table.insert(specs, { size = v(0.4, 7, 0.4), offset = v(x + dx, 3.5, z + dz), colour = WHITE })
		end
		table.insert(specs, {
			size = v(0.1, 6.5, 2.4),
			offset = v(x + dx, 3.6, z - 2.4),
			colour = rgb(255, 255, 255),
			material = Enum.Material.Fabric,
			transparency = 0.3,
			collide = false,
		})
	end
	return specs
end

local function lineArray(x: number): { Types.PartSpec }
	local specs: { Types.PartSpec } = {
		{ size = v(0.8, 18, 0.8), offset = v(x, 9, 27.5), colour = STEEL, material = Enum.Material.Metal },
	}
	for i, y in { 15.5, 13.4, 11.3, 9.2 } do
		table.insert(
			specs,
			{ size = v(4, 2, 3), offset = v(x, y, 26), rotation = v(-3 * i, 0, 0), colour = rgb(26, 26, 32) }
		)
		table.insert(specs, {
			size = v(3.6, 0.15, 0.1),
			offset = v(x, y - 0.2, 24.45),
			colour = MAGENTA,
			material = Enum.Material.Neon,
			lightRole = "speaker",
		})
	end
	return specs
end

local function movingHead(x: number, colour: Color3): { Types.PartSpec }
	return {
		{ size = v(1.6, 0.4, 1.2), offset = v(x, 24.8, 35), colour = rgb(26, 26, 32) },
		{ size = v(1.2, 1.4, 1.2), offset = v(x, 23.9, 35), rotation = v(-50, 0, 0), colour = rgb(26, 26, 32) },
		{
			size = v(0.8, 0.8, 0.1),
			offset = v(x, 23.4, 34.58),
			rotation = v(-50, 0, 0),
			colour = colour,
			material = Enum.Material.Neon,
			collide = false,
			light = { colour = colour, brightness = 3, range = 60, spot = 25 },
			beam = { length = 34, width = 0.8 },
			lightRole = "spot",
		},
	}
end

local function launcher(x: number): Types.PartSpec
	return { size = v(2, 1.4, 2), offset = v(x, 0.7, 52), colour = rgb(48, 44, 56), fx = "fireworks" }
end

local function sub(x: number): Types.PartSpec
	return { size = v(4, 3.4, 3.4), offset = v(x, 2.3, 19), colour = rgb(26, 26, 32) }
end

local function shell(): { Types.PartSpec }
	local specs: { Types.PartSpec } = {
		-- The beach and grass the venue stands on, the plaza and the sea
		{ size = v(300, 1, 220), offset = v(0, -0.6, 0), colour = SAND, material = Enum.Material.Sand },
		{ size = v(110, 1, 70), offset = v(0, -0.5, 5), colour = STONE, material = Enum.Material.Limestone },
		{ size = v(700, 1, 420), offset = v(0, -1.2, 320), colour = rgb(40, 96, 168) },
		{ size = v(700, 0.2, 3), offset = v(0, -0.7, 110), colour = rgb(250, 250, 255), collide = false },
		-- Low white walls, open at the entrance and towards the beach
		{ size = v(47, 3, 1), offset = v(31.5, 1.5, -30), colour = WHITE },
		{ size = v(47, 3, 1), offset = v(-31.5, 1.5, -30), colour = WHITE },
		{ size = v(1, 3, 70), offset = v(55, 1.5, 5), colour = WHITE },
		{ size = v(1, 3, 70), offset = v(-55, 1.5, 5), colour = WHITE },
		-- The path from the airstrip to the entrance
		{ size = v(8, 0.1, 30), offset = v(0, 0.05, -45), colour = STONE, material = Enum.Material.Limestone },
		-- Headlands framing the bay
		{
			size = v(60, 40, 50),
			offset = v(150, 10, 120),
			rotation = v(0, 25, 0),
			colour = rgb(96, 104, 84),
			material = Enum.Material.Rock,
		},
		{
			size = v(50, 30, 40),
			offset = v(-150, 6, 130),
			rotation = v(0, -20, 0),
			colour = rgb(100, 106, 88),
			material = Enum.Material.Rock,
		},
		-- The arrival runway
		{ size = v(160, 0.2, 26), offset = v(0, 0.1, -72), colour = rgb(40, 40, 46), material = Enum.Material.Asphalt },
	}
	for x = -72, 72, 16 do
		table.insert(specs, { size = v(6, 0.05, 0.5), offset = v(x, 0.23, -72), colour = WHITE, collide = false })
		for _, z in { -84.5, -59.5 } do
			table.insert(specs, {
				size = v(0.5, 0.4, 0.5),
				offset = v(x, 0.4, z),
				colour = rgb(255, 170, 110),
				material = Enum.Material.Neon,
				collide = false,
			})
		end
	end
	return specs
end

local function guestSpots(): { Vector3 }
	local spots = {}
	for _, z in { -1, 3.5, 8, 12.5 } do
		for _, x in { -15, -10, -5, 0, 5, 10, 15 } do
			table.insert(spots, v(x + (z % 2) * 0.6, 0.6, z))
		end
	end
	for _, x in { -12.5, -7.5, -2.5, 2.5, 7.5, 12.5 } do
		table.insert(spots, v(x, 0.6, 15.5))
		table.insert(spots, v(x * 1.2, 0.6, -5.5))
	end
	-- The closest rows to the stage come first, so a small crowd gathers at the front.
	table.sort(spots, function(a, b)
		if a.Z ~= b.Z then
			return a.Z > b.Z
		end
		return math.abs(a.X) < math.abs(b.X)
	end)
	return spots
end

local Ibiza: Types.Blockout = {
	shell = shell(),

	items = {
		ibiza_stage = {
			{ size = v(32, 3, 16), offset = v(0, 1.5, 30), colour = DARK },
			{
				size = v(32, 0.3, 0.3),
				offset = v(0, 2.9, 21.9),
				colour = MAGENTA,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{ size = v(10, 3.8, 3), offset = v(0, 4.9, 26), colour = WHITE },
			{
				size = v(9.6, 0.3, 0.1),
				offset = v(0, 4.6, 24.45),
				colour = ORANGE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
		},
		ibiza_speakers = list(lineArray(18), lineArray(-18)),
		ibiza_dancedeck = {
			{ size = v(40, 0.6, 24), offset = v(0, 0.3, 8), colour = TEAK, material = Enum.Material.WoodPlanks },
			{
				size = v(40, 0.2, 0.2),
				offset = v(0, 0.62, -4),
				colour = ORANGE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{
				size = v(0.2, 0.2, 24),
				offset = v(20, 0.62, 8),
				colour = ORANGE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{
				size = v(0.2, 0.2, 24),
				offset = v(-20, 0.62, 8),
				colour = ORANGE,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
		},
		ibiza_palms = list(
			palm(40, -20, 6),
			palm(-40, -20, -6),
			palm(50, 12, 8),
			palm(-50, 12, -8),
			palm(36, 44, 5),
			palm(-36, 44, -5)
		),
		ibiza_mixer = {
			{ size = v(1.8, 0.6, 2), offset = v(0, 7.1, 25.8), colour = rgb(60, 58, 66) },
			{
				size = v(1.4, 0.05, 0.3),
				offset = v(0, 7.42, 25.1),
				colour = ORANGE,
				material = Enum.Material.Neon,
				lightRole = "screen",
			},
		},
		ibiza_pool = pool(36),
		ibiza_loungers = list(
			lounger(28, -12),
			lounger(33, -12),
			lounger(39, -12),
			lounger(44, -12),
			lounger(-28, -12),
			lounger(-33, -12),
			lounger(-39, -12),
			lounger(-44, -12)
		),
		ibiza_umbrellas = list(
			parasol(30.5, -17),
			parasol(36.5, -17),
			parasol(42.5, -17),
			parasol(-30.5, -17),
			parasol(-36.5, -17),
			parasol(-42.5, -17)
		),
		ibiza_bar = {
			{ size = v(16, 3.6, 3), offset = v(-40, 1.8, 30), colour = WHITE },
			{ size = v(16.4, 0.3, 3.4), offset = v(-40, 3.75, 30), colour = TEAK },
			{
				size = v(15.6, 0.25, 0.1),
				offset = v(-40, 0.6, 28.45),
				colour = WARM,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
			{ size = v(0.6, 7, 0.6), offset = v(-48.5, 3.5, 27.5), colour = TEAK },
			{ size = v(0.6, 7, 0.6), offset = v(-31.5, 3.5, 27.5), colour = TEAK },
			{ size = v(0.6, 7, 0.6), offset = v(-48.5, 3.5, 33.5), colour = TEAK },
			{ size = v(0.6, 7, 0.6), offset = v(-31.5, 3.5, 33.5), colour = TEAK },
			{
				size = v(19, 0.8, 7.4),
				offset = v(-40, 7.4, 30.5),
				colour = rgb(200, 168, 112),
				material = Enum.Material.Fabric,
			},
			{
				size = v(0.8, 0.8, 0.8),
				offset = v(-44, 4.3, 30),
				shape = Enum.PartType.Ball,
				colour = rgb(255, 150, 40),
			},
			{
				size = v(0.8, 0.8, 0.8),
				offset = v(-43, 4.3, 30.4),
				shape = Enum.PartType.Ball,
				colour = rgb(120, 200, 70),
			},
			{
				size = v(0.8, 0.8, 0.8),
				offset = v(-42.2, 4.3, 29.8),
				shape = Enum.PartType.Ball,
				colour = rgb(255, 220, 60),
			},
			{
				size = v(1.2, 0.7, 0.7),
				offset = v(-38, 4.5, 30),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = ORANGE,
				transparency = 0.3,
			},
			{
				size = v(1.2, 0.7, 0.7),
				offset = v(-36.6, 4.5, 30.3),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(255, 210, 80),
				transparency = 0.3,
			},
		},
		ibiza_lanterns = list(
			lantern(52, -22),
			lantern(52, -6),
			lantern(52, 10),
			lantern(52, 26),
			lantern(-52, -22),
			lantern(-52, -6),
			lantern(-52, 10),
			lantern(-52, 26),
			lantern(11, -28),
			lantern(-11, -28)
		),
		ibiza_ledwall = {
			{ size = v(27, 14, 1.2), offset = v(0, 11.5, 37.6), colour = rgb(16, 14, 20) },
			{
				size = v(26, 13, 0.2),
				offset = v(0, 11.5, 36.9),
				colour = VIOLET,
				material = Enum.Material.Neon,
				light = { colour = VIOLET, brightness = 1.5, range = 40 },
				lightRole = "screen",
			},
		},
		ibiza_truss = {
			{ size = v(1.6, 22, 1.6), offset = v(17, 14, 35), colour = STEEL, material = Enum.Material.DiamondPlate },
			{ size = v(1.6, 22, 1.6), offset = v(-17, 14, 35), colour = STEEL, material = Enum.Material.DiamondPlate },
			{ size = v(36, 1.6, 1.6), offset = v(0, 25.8, 35), colour = STEEL, material = Enum.Material.DiamondPlate },
		},
		ibiza_movingheads = list(
			movingHead(-14, VIOLET),
			movingHead(-8.4, rgb(255, 255, 255)),
			movingHead(-2.8, VIOLET),
			movingHead(2.8, rgb(255, 255, 255)),
			movingHead(8.4, VIOLET),
			movingHead(14, rgb(255, 255, 255))
		),
		ibiza_pool2 = list(pool(-36), {
			{ size = v(3, 3, 3), offset = v(-32, 0.2, 2), shape = Enum.PartType.Ball, colour = SAND },
			{
				size = v(4, 0.5, 0.5),
				offset = v(-32, 3.2, 2),
				rotation = v(0, 0, 84),
				shape = Enum.PartType.Cylinder,
				colour = TRUNK,
			},
			{ size = v(3, 0.2, 1), offset = v(-31.8, 5.2, 2), rotation = v(0, 0, -20), colour = LEAF, collide = false },
			{
				size = v(3, 0.2, 1),
				offset = v(-31.8, 5.2, 2),
				rotation = v(0, 120, -20),
				colour = LEAF,
				collide = false,
			},
			{
				size = v(3, 0.2, 1),
				offset = v(-31.8, 5.2, 2),
				rotation = v(0, 240, -20),
				colour = LEAF,
				collide = false,
			},
		}),
		ibiza_cabanas = list(cabana(45, 14), cabana(45, 22), cabana(-46, 17)),
		ibiza_4deck = {
			{ size = v(9, 0.8, 1.8), offset = v(0, 7.2, 25.2), colour = WHITE },
			{
				size = v(0.1, 1, 1),
				offset = v(-3.5, 7.65, 25.2),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(154, 148, 140),
			},
			{
				size = v(0.1, 1, 1),
				offset = v(-1.4, 7.65, 25.2),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(154, 148, 140),
			},
			{
				size = v(0.1, 1, 1),
				offset = v(1.4, 7.65, 25.2),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(154, 148, 140),
			},
			{
				size = v(0.1, 1, 1),
				offset = v(3.5, 7.65, 25.2),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(154, 148, 140),
			},
			{
				size = v(8.6, 0.05, 0.3),
				offset = v(0, 7.62, 24.45),
				colour = ORANGE,
				material = Enum.Material.Neon,
				lightRole = "screen",
			},
		},
		ibiza_fireworks = { launcher(-40), launcher(-20), launcher(20), launcher(40) },
		ibiza_carpet = {
			{ size = v(3, 12, 4), offset = v(8, 6, -30), colour = WHITE },
			{ size = v(3, 12, 4), offset = v(-8, 6, -30), colour = WHITE },
			{ size = v(19, 2.6, 4), offset = v(0, 13.3, -30), colour = WHITE },
			{
				size = v(1.2, 0.8, 0.3),
				offset = v(8, 9, -32.15),
				colour = WARM,
				material = Enum.Material.Neon,
				light = { colour = WARM, brightness = 1, range = 14 },
			},
			{
				size = v(1.2, 0.8, 0.3),
				offset = v(-8, 9, -32.15),
				colour = WARM,
				material = Enum.Material.Neon,
				light = { colour = WARM, brightness = 1, range = 14 },
			},
			{
				size = v(6, 0.05, 30),
				offset = v(0, 0.13, -45),
				colour = rgb(200, 50, 70),
				material = Enum.Material.Fabric,
			},
			{
				size = v(0.3, 2.2, 0.3),
				offset = v(3.6, 1.1, -52),
				colour = rgb(200, 180, 120),
				material = Enum.Material.Metal,
			},
			{
				size = v(0.3, 2.2, 0.3),
				offset = v(-3.6, 1.1, -52),
				colour = rgb(200, 180, 120),
				material = Enum.Material.Metal,
			},
			{
				size = v(0.3, 2.2, 0.3),
				offset = v(3.6, 1.1, -40),
				colour = rgb(200, 180, 120),
				material = Enum.Material.Metal,
			},
			{
				size = v(0.3, 2.2, 0.3),
				offset = v(-3.6, 1.1, -40),
				colour = rgb(200, 180, 120),
				material = Enum.Material.Metal,
			},
		},
		ibiza_lasers = {
			{
				size = v(2, 1.2, 2),
				offset = v(17, 27.4, 35),
				rotation = v(-18, 12, 0),
				colour = rgb(60, 255, 120),
				material = Enum.Material.Neon,
				beam = { length = 60, width = 0.25 },
				lightRole = "spot",
			},
			{
				size = v(2, 1.2, 2),
				offset = v(-17, 27.4, 35),
				rotation = v(-18, -12, 0),
				colour = rgb(60, 255, 120),
				material = Enum.Material.Neon,
				beam = { length = 60, width = 0.25 },
				lightRole = "spot",
			},
		},
		ibiza_booking = {
			{ size = v(0.4, 3, 0.4), offset = v(-16.5, 1.5, -24), colour = TEAK },
			{ size = v(0.4, 3, 0.4), offset = v(-11.5, 1.5, -24), colour = TEAK },
			{ size = v(6.4, 4.4, 0.2), offset = v(-14, 5, -23.9), colour = ORANGE, material = Enum.Material.Neon },
			{ size = v(6, 4, 0.4), offset = v(-14, 5, -24.1), colour = WHITE, lightRole = "screen" },
		},
		ibiza_merch = {
			{ size = v(8, 4, 4), offset = v(-44, 2, -22), colour = WHITE },
			{ size = v(8.6, 0.4, 2), offset = v(-44, 4.9, -24.6), colour = ORANGE },
			{ size = v(1.6, 2, 0.1), offset = v(-46, 2.6, -24.05), colour = MAGENTA },
			{ size = v(1.6, 2, 0.1), offset = v(-43, 2.6, -24.05), colour = TURQUOISE },
			{ size = v(1.2, 0.6, 0.1), offset = v(-40.6, 3.2, -24.05), colour = rgb(255, 200, 60) },
		},
		ibiza_co2 = {
			{ size = v(1, 1.6, 1), offset = v(-14, 3.8, 22.6), colour = rgb(26, 26, 32), fx = "co2" },
			{ size = v(1, 1.6, 1), offset = v(-6, 3.8, 22.6), colour = rgb(26, 26, 32), fx = "co2" },
			{ size = v(1, 1.6, 1), offset = v(6, 3.8, 22.6), colour = rgb(26, 26, 32), fx = "co2" },
			{ size = v(1, 1.6, 1), offset = v(14, 3.8, 22.6), colour = rgb(26, 26, 32), fx = "co2" },
		},
		ibiza_subs = { sub(-14), sub(-10), sub(-6), sub(-2), sub(2), sub(6), sub(10), sub(14) },
		ibiza_vip = {
			{ size = v(18, 3, 12), offset = v(39, 1.5, 32), colour = TEAK, material = Enum.Material.WoodPlanks },
			{ size = v(18, 1.2, 0.2), offset = v(39, 3.6, 26.1), colour = rgb(190, 230, 240), transparency = 0.5 },
			{ size = v(6, 1.2, 2.4), offset = v(35, 3.6, 34), colour = WHITE, material = Enum.Material.Fabric },
			{ size = v(6, 1.2, 2.4), offset = v(43, 3.6, 34), colour = WHITE, material = Enum.Material.Fabric },
			{
				size = v(18, 0.2, 0.2),
				offset = v(39, 0.3, 25.9),
				colour = MAGENTA,
				material = Enum.Material.Neon,
				lightRole = "led",
			},
		},
		ibiza_sign = {
			{
				size = v(24, 8, 1.5),
				offset = v(40, 4.5, 48),
				rotation = v(0, 20, 0),
				colour = rgb(250, 246, 240),
				text = { text = "SOL", colour = ORANGE },
				light = { colour = ORANGE, brightness = 1.2, range = 24 },
				lightRole = "neon",
			},
		},
	},

	guests = {
		entrance = v(0, 0.2, -32),
		spots = guestSpots(),
		lookAt = v(0, 3, 29),
	},

	decks = {
		itemId = "ibiza_stage",
		stand = v(0, 3, 29),
		camera = v(0, 13, 37),
		cameraLookAt = v(0, 3, -2),
	},

	speakerItem = "ibiza_speakers",

	layout = {
		buttonSlots = { v(-7, 0, -16), v(0, 0, -16), v(7, 0, -16) },
		register = v(16, 0, -24),
		spawn = v(0, 0, -50),
	},
}

return Ibiza
