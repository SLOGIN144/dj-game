--!strict
-- Venue configs. Only the house party exists so far (Milestone 1 prototype); the GDD lists the
-- remaining fields (rendered NPC count, pay, rep, camera points, ...) for when they're needed.

export type Venue = {
	id: string,
	name: string,
	tier: number,
	preferredGenres: { string },
	startEnergy: number,
	setLengthSeconds: number,
	colour: Color3, -- the venue's dominant colour, used as the UI accent
}

local Venues: { [string]: Venue } = {
	house_party = {
		id = "house_party",
		name = "Friend's house party",
		tier = 1,
		preferredGenres = { "house", "dance-pop" },
		startEnergy = 30,
		setLengthSeconds = 240,
		colour = Color3.fromRGB(255, 170, 80),
	},
}

return Venues
