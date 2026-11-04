--!strict
-- The sky and light looks a location can have (GDD: visual style and lighting: a dark room with
-- one dominant colour per location). The street uses the night look the server sets
-- (World/NightLook); each location names its own here, and the client (Controllers/Ambience)
-- blends to it while the camera is inside the location's room, or at its venue.

local rgb = Color3.fromRGB

export type Sky = {
	clockTime: number,
	brightness: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	exposure: number,
	haze: { colour: Color3, decay: Color3, density: number, haze: number, glare: number, offset: number },
	grade: { tint: Color3, saturation: number, contrast: number },
}

local Skies: { [string]: Sky } = {
	-- The dorm: a dark student room, purple LED glow (docs/concept/dorm.webp).
	dormRoom = {
		clockTime = 0,
		brightness = 1,
		ambient = rgb(38, 28, 62),
		outdoorAmbient = rgb(54, 44, 92),
		exposure = 0.1,
		haze = {
			colour = rgb(96, 72, 156),
			decay = rgb(42, 28, 84),
			density = 0.32,
			haze = 1.5,
			glare = 0.1,
			offset = 0.1,
		},
		grade = { tint = rgb(246, 236, 255), saturation = 0.18, contrast = 0.12 },
	},
	-- The house party: warm lamps and party pinks (docs/concept/house-party.webp).
	houseParty = {
		clockTime = 0,
		brightness = 1,
		ambient = rgb(56, 34, 48),
		outdoorAmbient = rgb(84, 56, 72),
		exposure = 0.12,
		haze = {
			colour = rgb(156, 92, 116),
			decay = rgb(84, 40, 72),
			density = 0.3,
			haze = 1.4,
			glare = 0.1,
			offset = 0.1,
		},
		grade = { tint = rgb(255, 240, 230), saturation = 0.22, contrast = 0.12 },
	},
	-- The club: a dark basement in deep blue, haze thick enough for the beams (docs/concept/club.webp).
	clubBasement = {
		clockTime = 0,
		brightness = 1,
		ambient = rgb(16, 20, 46),
		outdoorAmbient = rgb(26, 32, 72),
		exposure = 0,
		haze = {
			colour = rgb(60, 82, 172),
			decay = rgb(20, 26, 82),
			density = 0.42,
			haze = 2.2,
			glare = 0.05,
			offset = 0.15,
		},
		grade = { tint = rgb(230, 238, 255), saturation = 0.2, contrast = 0.16 },
	},
	-- Ibiza: the sun going down over the sea, orange and magenta (docs/concept/ibiza.webp).
	sunset = {
		clockTime = 17.9,
		brightness = 2.4,
		ambient = rgb(78, 52, 70),
		outdoorAmbient = rgb(156, 104, 118),
		exposure = 0.05,
		haze = {
			colour = rgb(255, 168, 128),
			decay = rgb(196, 84, 132),
			density = 0.3,
			haze = 1.7,
			glare = 0.7,
			offset = 0.08,
		},
		grade = { tint = rgb(255, 238, 226), saturation = 0.22, contrast = 0.1 },
	},
}

return Skies
