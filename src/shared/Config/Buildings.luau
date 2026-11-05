--!strict
-- The building behind each plot's room, one stage per location (GDD: plots): it grows with its
-- owner's career, so anyone on the street can see how far a player has come. A free plot shows the
-- first stage with only a few windows lit. Positions are plot-relative; the front face sits just
-- behind the room's back wall. Model sheet: "Street" (building_dorm, building_apartment,
-- building_tower).

export type Stage = {
	floors: number,
	floorHeight: number,
	width: number, -- along X
	depth: number, -- along Z
	frontZ: number, -- the front face, just behind the room
	roomHeight: number, -- the room's walls hide the building below this
	colour: Color3,
	trim: Color3,
	neon: Color3?, -- roof edge and corner strips
	sign: string?, -- a neon sign on the roof
	litShare: number, -- share of windows that are lit
}

local rgb = Color3.fromRGB

local Buildings: { [string]: Stage } = {
	free = {
		floors = 3,
		floorHeight = 9,
		width = 40,
		depth = 26,
		frontZ = -16,
		roomHeight = 0, -- no room in front of it: the whole facade shows
		colour = rgb(88, 82, 92),
		trim = rgb(62, 58, 68),
		litShare = 0.12, -- a few neighbours home, so the street never looks dead
	},
	dorm = {
		floors = 3,
		floorHeight = 9,
		width = 40,
		depth = 26,
		frontZ = -16,
		roomHeight = 0, -- no room in front of it: the whole facade shows
		colour = rgb(118, 104, 112),
		trim = rgb(82, 72, 82),
		litShare = 0.35,
	},
	house = {
		floors = 5,
		floorHeight = 9,
		width = 44,
		depth = 17,
		frontZ = 22,
		roomHeight = 14,
		colour = rgb(100, 92, 112),
		trim = rgb(70, 64, 84),
		neon = rgb(255, 70, 200),
		litShare = 0.45,
	},
	club = {
		floors = 10,
		floorHeight = 8.5,
		width = 56,
		depth = 8,
		frontZ = 31.5,
		roomHeight = 16,
		colour = rgb(58, 60, 84),
		trim = rgb(40, 42, 60),
		neon = rgb(60, 120, 255),
		sign = "BASEMENT",
		litShare = 0.5,
	},
	ibiza = {
		floors = 12,
		floorHeight = 8.5,
		width = 56,
		depth = 8,
		frontZ = 31.5,
		roomHeight = 16,
		colour = rgb(64, 58, 84),
		trim = rgb(44, 40, 60),
		neon = rgb(255, 120, 60),
		sign = "SOL",
		litShare = 0.6,
	},
}

return Buildings
