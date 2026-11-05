--!strict
-- The fictional star DJs the booking board lists (GDD: star DJs; model sheet "Characters"). Each
-- location unlocks one or two, pricier and stronger; they stay bookable after moving on. A DJ is
-- found in crates (Config/Crates), except a starter, who is owned from the start. Booking a set
-- costs `price`. Names, looks and styles are made up: never real DJs, and Filip checks each name
-- against real artists before launch. Set length and rest time are in Balance.StarDjs. Keep the list
-- in unlock order with rising prices (a spec checks it).

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local StarDjs: { Types.StarDj } = {
	{
		id = "dj_kiko",
		rarity = "common",
		starter = true,
		name = "Kiko Wavelength",
		style = "Feel-good house",
		location = "house",
		price = 15000,
		multiplier = 3,
		colour = rgb(60, 220, 200),
		look = {
			skin = rgb(224, 172, 130),
			hair = rgb(40, 30, 26),
			top = rgb(60, 220, 200),
			accent = rgb(255, 80, 170),
			hat = "bucket",
		},
	},
	{
		id = "dj_dusty",
		rarity = "common",
		name = "Dusty Reel",
		style = "Warm, crackly house",
		location = "house",
		price = 24000,
		multiplier = 3,
		colour = rgb(214, 170, 96),
		look = {
			skin = rgb(190, 132, 96),
			hair = rgb(92, 56, 36),
			top = rgb(214, 170, 96),
			accent = rgb(96, 60, 40),
		},
	},
	{
		id = "dj_tamsin",
		rarity = "rare",
		name = "Tamsin Flux",
		style = "Driving tech house",
		location = "club",
		price = 200000,
		multiplier = 3.5,
		colour = rgb(180, 184, 200),
		look = {
			skin = rgb(240, 200, 170),
			hair = rgb(236, 232, 214),
			top = rgb(180, 184, 200),
			accent = rgb(24, 24, 30),
		},
	},
	{
		id = "dj_nova",
		rarity = "rare",
		name = "Nova Quill",
		style = "Bright, bouncy tech house",
		location = "club",
		price = 300000,
		multiplier = 3.5,
		colour = rgb(255, 214, 90),
		look = {
			skin = rgb(236, 190, 150),
			hair = rgb(255, 120, 60),
			top = rgb(255, 214, 90),
			accent = rgb(40, 30, 80),
			hat = "visor",
		},
	},
	{
		id = "dj_ondra",
		rarity = "epic",
		name = "Ondra Voltz",
		style = "Dark, punchy tech house",
		location = "club",
		price = 450000,
		multiplier = 4,
		colour = rgb(60, 160, 255),
		look = {
			skin = rgb(150, 100, 70),
			hair = rgb(20, 20, 24),
			top = rgb(26, 26, 32),
			accent = rgb(60, 160, 255),
			hat = "visor",
		},
	},
	{
		id = "dj_lux",
		rarity = "epic",
		name = "Lux Meridian",
		style = "Lush, rolling house",
		location = "ibiza",
		price = 2000000,
		multiplier = 4.5,
		colour = rgb(180, 120, 255),
		look = {
			skin = rgb(210, 160, 120),
			hair = rgb(250, 240, 255),
			top = rgb(180, 120, 255),
			accent = rgb(255, 255, 255),
		},
	},
	{
		id = "dj_mira",
		rarity = "legendary",
		name = "Mira Sundial",
		style = "Sunset house",
		location = "ibiza",
		price = 8000000,
		multiplier = 5,
		colour = rgb(255, 122, 60),
		look = {
			skin = rgb(198, 140, 100),
			hair = rgb(60, 36, 24),
			top = rgb(255, 122, 60),
			accent = rgb(255, 60, 168),
			hat = "sun",
		},
	},
	{
		id = "dj_zed",
		rarity = "legendary",
		name = "Zed Quartz",
		style = "Cosmic, crystal-clear techno",
		location = "ibiza",
		price = 12000000,
		multiplier = 6,
		colour = rgb(120, 255, 230),
		look = {
			skin = rgb(120, 90, 70),
			hair = rgb(20, 24, 40),
			top = rgb(120, 255, 230),
			accent = rgb(255, 255, 255),
			hat = "visor",
		},
	},
}

return StarDjs
