--!strict
-- The dorm room blockout: an open-front room (no front wall or ceiling, so the camera sees in)
-- with a bed and a desk, and simple parts for each of its 10 items. Detailed art replaces these
-- later; the floor's top is at y = 0.2 and the desk's top at y = 3.4.

local Types = require(script.Parent.Parent.Parent.Types)

local v = Vector3.new
local rgb = Color3.fromRGB

local WALL = rgb(38, 40, 58)
local WOOD = rgb(110, 78, 56)
local DARK = rgb(28, 28, 34)
local PURPLE = rgb(150, 90, 255)

local Dorm: Types.Blockout = {
	shell = {
		{ size = v(24, 0.2, 20), offset = v(0, 0.1, 4), colour = rgb(58, 50, 72), material = Enum.Material.Fabric },
		{ size = v(26, 12, 1), offset = v(0, 6, 14.5), colour = WALL },
		{ size = v(1, 12, 20), offset = v(-12.5, 6, 4), colour = WALL },
		{ size = v(1, 12, 20), offset = v(12.5, 6, 4), colour = WALL },
		-- Window with the night outside
		{ size = v(6, 3.5, 0.1), offset = v(6, 8, 13.95), colour = rgb(18, 26, 60), material = Enum.Material.Neon },
		-- Bed
		{ size = v(5, 1.2, 9), offset = v(-8.5, 0.8, 9), colour = WOOD },
		{
			size = v(4.8, 0.6, 8.8),
			offset = v(-8.5, 1.7, 9),
			colour = rgb(200, 200, 210),
			material = Enum.Material.Fabric,
		},
		{
			size = v(3, 0.5, 1.6),
			offset = v(-8.5, 2.25, 12.6),
			colour = rgb(235, 235, 240),
			material = Enum.Material.Fabric,
		},
		-- Desk and chair
		{ size = v(8, 0.4, 3.6), offset = v(6, 3.2, 11.8), colour = WOOD },
		{ size = v(0.4, 3, 0.4), offset = v(2.3, 1.7, 10.3), colour = WOOD },
		{ size = v(0.4, 3, 0.4), offset = v(9.7, 1.7, 10.3), colour = WOOD },
		{ size = v(0.4, 3, 0.4), offset = v(2.3, 1.7, 13.3), colour = WOOD },
		{ size = v(0.4, 3, 0.4), offset = v(9.7, 1.7, 13.3), colour = WOOD },
		{ size = v(2, 0.3, 2), offset = v(6, 2, 8.4), colour = DARK },
		{ size = v(2, 2.4, 0.3), offset = v(6, 3.3, 7.5), colour = DARK },
		{ size = v(0.3, 1.8, 0.3), offset = v(6, 1.05, 8.4), colour = DARK },
		-- A dim room light so the room reads at night before anything is bought
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
		dorm_laptop = {
			{ size = v(2.4, 0.12, 1.6), offset = v(6, 3.46, 11.6), colour = rgb(60, 62, 70) },
			{
				size = v(2.4, 1.6, 0.1),
				offset = v(6, 4.25, 12.45),
				rotation = v(15, 0, 0),
				colour = rgb(70, 110, 220),
				material = Enum.Material.Neon,
			},
		},
		dorm_lamp = {
			{ size = v(0.8, 0.15, 0.8), offset = v(9.2, 3.48, 12.8), colour = DARK },
			{ size = v(0.15, 2.2, 0.15), offset = v(9.2, 4.6, 12.8), colour = DARK },
			{
				size = v(1, 0.5, 0.7),
				offset = v(9, 5.7, 12.5),
				colour = rgb(255, 200, 130),
				material = Enum.Material.Neon,
				light = { colour = rgb(255, 200, 140), brightness = 1.5, range = 14 },
			},
		},
		dorm_speaker = {
			{ size = v(1.8, 3, 1.8), offset = v(11, 1.7, 8.5), colour = DARK },
			{
				size = v(0.1, 1.2, 1.2),
				offset = v(11, 2.2, 7.55),
				rotation = v(0, 90, 0),
				shape = Enum.PartType.Cylinder,
				colour = rgb(70, 70, 80),
			},
		},
		dorm_led = {
			{
				size = v(23.8, 0.25, 0.25),
				offset = v(0, 11.6, 13.85),
				colour = PURPLE,
				material = Enum.Material.Neon,
				light = { colour = PURPLE, brightness = 1, range = 18 },
			},
			{
				size = v(0.25, 0.25, 19.8),
				offset = v(-11.85, 11.6, 4.1),
				colour = PURPLE,
				material = Enum.Material.Neon,
			},
			{
				size = v(0.25, 0.25, 19.8),
				offset = v(11.85, 11.6, 4.1),
				colour = PURPLE,
				material = Enum.Material.Neon,
			},
		},
		dorm_controller = {
			{ size = v(2.6, 0.2, 1.4), offset = v(3.4, 3.5, 11.2), colour = rgb(40, 40, 46) },
			{
				size = v(0.1, 0.9, 0.9),
				offset = v(2.8, 3.62, 11.25),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(90, 90, 100),
			},
			{
				size = v(0.1, 0.9, 0.9),
				offset = v(4, 3.62, 11.25),
				rotation = v(0, 0, 90),
				shape = Enum.PartType.Cylinder,
				colour = rgb(90, 90, 100),
			},
			{
				size = v(2.6, 0.05, 0.1),
				offset = v(3.4, 3.61, 10.55),
				colour = rgb(80, 220, 255),
				material = Enum.Material.Neon,
			},
		},
		dorm_posters = {
			{ size = v(0.1, 3, 2.2), offset = v(-11.95, 7, 6), colour = rgb(255, 80, 120) },
			{ size = v(0.1, 3, 2.2), offset = v(-11.95, 7, 9.2), colour = rgb(80, 200, 255) },
			{ size = v(0.1, 3, 2.2), offset = v(-11.95, 7, 12.4), colour = rgb(255, 200, 60) },
		},
		dorm_beanbags = {
			{
				size = v(3, 1.6, 3),
				offset = v(-3, 1, 1),
				rotation = v(0, 20, 0),
				colour = rgb(200, 60, 70),
				material = Enum.Material.Fabric,
			},
			{
				size = v(2.8, 1.5, 2.8),
				offset = v(1.5, 0.95, 0),
				rotation = v(0, -15, 0),
				colour = rgb(40, 160, 160),
				material = Enum.Material.Fabric,
			},
		},
		dorm_discoball = {
			{ size = v(0.1, 1.6, 0.1), offset = v(0, 11.2, 4), colour = DARK, collide = false },
			{
				size = v(1.6, 1.6, 1.6),
				offset = v(0, 9.6, 4),
				shape = Enum.PartType.Ball,
				colour = rgb(220, 220, 230),
				material = Enum.Material.Foil,
				collide = false,
				light = { colour = rgb(255, 255, 255), brightness = 1, range = 16 },
			},
		},
		dorm_partylights = {
			{
				size = v(1, 0.8, 1),
				offset = v(-10.8, 10.8, 12.8),
				colour = rgb(255, 60, 200),
				material = Enum.Material.Neon,
				light = { colour = rgb(255, 60, 200), brightness = 1.5, range = 16 },
			},
			{
				size = v(1, 0.8, 1),
				offset = v(10.8, 10.8, 12.8),
				colour = rgb(60, 220, 255),
				material = Enum.Material.Neon,
				light = { colour = rgb(60, 220, 255), brightness = 1.5, range = 16 },
			},
		},
		dorm_neon = {
			{
				size = v(5, 1.6, 0.15),
				offset = v(-6.5, 8.6, 13.9),
				colour = DARK,
				text = { text = "DROP IT", colour = rgb(255, 90, 200) },
				light = { colour = rgb(255, 90, 200), brightness = 1, range = 10 },
			},
		},
	},
}

return Dorm
