--!strict
-- The sky and light looks a location can have (GDD: visual style and lighting). The street and
-- the small locations use the night look the server sets (World/NightLook); a venue names its
-- own here, and the client (Controllers/Ambience) blends to it while the player is there.

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
