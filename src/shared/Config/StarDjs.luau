--!strict
-- The fictional star DJs the booking board lists (GDD: star DJs; model sheet "Characters"). Each
-- location unlocks one or two, pricier and stronger; they stay bookable after moving on. Names,
-- looks and styles are made up: never real DJs. Set length and rest time are in Balance.StarDjs.

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local StarDjs: { Types.StarDj } = {
	{
		id = "dj_kiko",
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
		id = "dj_tamsin",
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
		id = "dj_ondra",
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
		id = "dj_mira",
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
}

return StarDjs
