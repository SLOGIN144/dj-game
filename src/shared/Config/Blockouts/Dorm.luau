--!strict
-- The dorm room blockout, laid out after the dorm model sheet (docs/concept/dorm.webp and Filip's
-- reference of 2026-11-05): an open-front room, 36 x 32 studs, with two low wall stubs at the front,
-- the night window and desk on the back wall, Max's bed and desk on the left wall and a beanbag
-- corner, fridge, window and till on the right. "Left" is as seen from the street, which looks along
-- +Z: the left wall is at +X and the right wall at -X. The room spans x -18..18, z -4..28, floor top
-- at y = 0.2, walls 14 high. The shell is what's always there (the first bed, the desk Max has
-- given you, the bookshelf); each of the 16 items is ordered on the phone, delivered by the truck
-- and placed on its outline. Detailed art replaces the parts later (ServerStorage models named
-- after the item).

local Types = require(script.Parent.Parent.Parent.Types)

local v = Vector3.new
local rgb = Color3.fromRGB

local WALL = rgb(190, 168, 214)
local TRIM = rgb(70, 62, 84)
local WOOD = rgb(150, 106, 86)
local DARK_WOOD = rgb(96, 66, 52)
local LIGHT_WOOD = rgb(186, 140, 112)
local DARK = rgb(26, 26, 32)
local PURPLE = rgb(150, 90, 255)
local PINK = rgb(255, 70, 200)
local NIGHT = rgb(26, 34, 82)
local CITY = rgb(14, 16, 34)
local WINDOW_LIGHT = rgb(255, 196, 120)
local LEAF = rgb(56, 124, 70)
local POT = rgb(200, 200, 212)
local FABRIC = Enum.Material.Fabric

-- One part spec, with optional fields.
local function part(size: Vector3, offset: Vector3, colour: Color3, extra: { [string]: any }?): Types.PartSpec
	local spec: any = { size = size, offset = offset, colour = colour }
	if extra then
		for key, value in extra do
			spec[key] = value
		end
	end
	return spec :: Types.PartSpec
end

local function append(into: { Types.PartSpec }, from: { Types.PartSpec })
	for _, spec in from do
		table.insert(into, spec)
	end
end

-- A skyline of dark towers with lit windows, drawn on a night-blue pane `width` wide and `height`
-- tall whose centre is `centre`. `axis` is "z" for a window in the back wall and "x" for one in a
-- side wall; the lights sit a hair in front of the towers, towards the room.
local function skyline(centre: Vector3, width: number, height: number, axis: string, seed: number): { Types.PartSpec }
	local random = Random.new(seed)
	local specs: { Types.PartSpec } = {}
	local x = -width / 2 + 0.6
	while x < width / 2 - 1.2 do
		local w = random:NextNumber(1.2, 2.2)
		local h = random:NextNumber(height * 0.35, height * 0.8)
		local along = x + w / 2
		local base = centre.Y - height / 2
		local size = if axis == "z" then v(w, h, 0.05) else v(0.05, h, w)
		local offset = if axis == "z"
			then v(centre.X + along, base + h / 2, centre.Z)
			else v(centre.X, base + h / 2, centre.Z + along)
		table.insert(specs, part(size, offset, CITY, { collide = false }))
		for _ = 1, random:NextInteger(1, 3) do
			local lh = base + random:NextNumber(0.5, h - 0.4)
			local la = along + random:NextNumber(-w / 2 + 0.3, w / 2 - 0.3)
			local lsize = if axis == "z" then v(0.25, 0.3, 0.05) else v(0.05, 0.3, 0.25)
			local loffset = if axis == "z"
				then v(centre.X + la, lh, centre.Z + (if centre.Z > 0 then -0.03 else 0.03))
				else v(centre.X + (if centre.X > 0 then -0.03 else 0.03), lh, centre.Z + la)
			table.insert(specs, part(lsize, loffset, WINDOW_LIGHT, { material = Enum.Material.Neon, collide = false }))
		end
		x += w + random:NextNumber(0.2, 0.7)
	end
	return specs
end

-- A bed with its long side along Z, the headboard `head` (+1 or -1) along Z from its centre.
local function bed(cx: number, cz: number, head: number, blanket: Color3, pillow: Color3): { Types.PartSpec }
	return {
		part(v(6, 1.2, 9), v(cx, 0.8, cz), WOOD),
		part(v(6, 2.6, 0.4), v(cx, 1.5, cz + head * 4.3), WOOD),
		part(v(6, 1.6, 0.3), v(cx, 1.0, cz - head * 4.35), WOOD),
		part(v(5.8, 0.6, 8.6), v(cx, 1.7, cz), blanket, { material = FABRIC }),
		part(v(3.2, 0.5, 1.5), v(cx, 2.25, cz + head * 3.2), pillow, { material = FABRIC }),
	}
end

-- A potted plant standing on the floor.
local function plant(x: number, z: number, scale: number): { Types.PartSpec }
	return {
		part(v(1.3, 1.3, 1.3) * scale, v(x, 0.2 + 0.65 * scale, z), POT),
		part(
			v(2.4, 2.4, 2.4) * scale,
			v(x, 0.2 + 2.0 * scale, z),
			LEAF,
			{ shape = Enum.PartType.Ball, collide = false }
		),
	}
end

local shell: { Types.PartSpec } = {
	-- Floor and walls (the front is open, with a low stub of wall each side of the entrance)
	part(v(37, 0.2, 33), v(0, 0.1, 12.5), LIGHT_WOOD, { material = Enum.Material.WoodPlanks }),
	part(v(38, 14, 1), v(0, 7, 28.5), WALL),
	part(v(1, 14, 33), v(18.5, 7, 12), WALL),
	part(v(1, 14, 33), v(-18.5, 7, 12), WALL),
	part(v(14, 2.2, 1), v(11.5, 1.1, -4.5), WALL),
	part(v(14, 2.2, 1), v(-11.5, 1.1, -4.5), WALL),
	part(v(14.4, 0.3, 1.2), v(11.5, 2.35, -4.5), TRIM),
	part(v(14.4, 0.3, 1.2), v(-11.5, 2.35, -4.5), TRIM),
	part(v(36, 0.4, 0.1), v(0, 0.4, 27.95), TRIM),
	part(v(0.1, 0.4, 32), v(17.95, 0.4, 12), TRIM),
	part(v(0.1, 0.4, 32), v(-17.95, 0.4, 12), TRIM),
	-- The welcome mat in the entrance
	part(v(6, 0.05, 2.6), v(0, 0.225, -2.4), rgb(96, 60, 150), { material = FABRIC, collide = false }),

	-- The night window over the desk, with the city outside
	part(v(14.4, 6.2, 0.2), v(-2, 8.6, 27.9), TRIM),
	part(v(13.6, 5.4, 0.1), v(-2, 8.6, 27.82), NIGHT, { material = Enum.Material.Neon }),
	part(v(0.25, 5.4, 0.12), v(-2, 8.6, 27.7), TRIM),
	part(v(15, 0.5, 0.4), v(-2, 5.5, 27.6), rgb(64, 60, 74)),

	-- Bed along the left wall, by the back wall, with its night stand and lamp
	part(v(2.2, 2.4, 2.2), v(16.8, 1.4, 17.3), DARK_WOOD),
	part(v(0.8, 0.15, 0.8), v(16.8, 2.67, 17.3), DARK),
	part(
		v(1.3, 1.1, 1.3),
		v(16.8, 3.4, 17.3),
		rgb(255, 214, 160),
		{ material = Enum.Material.Neon, light = { colour = rgb(255, 200, 140), brightness = 0.9, range = 18 } }
	),

	-- The desk under the window, with drawers on its left and a chair pushed aside
	part(v(10, 0.4, 4), v(-2, 3.2, 26), WOOD),
	part(v(0.4, 3, 0.4), v(2.6, 1.7, 24.4), WOOD),
	part(v(0.4, 3, 0.4), v(2.6, 1.7, 27.6), WOOD),
	part(v(2.8, 3, 3.6), v(-5.6, 1.7, 26), WOOD),
	part(v(2.4, 0.8, 0.1), v(-5.6, 0.75, 24.15), LIGHT_WOOD),
	part(v(2.4, 0.8, 0.1), v(-5.6, 1.65, 24.15), LIGHT_WOOD),
	part(v(2.4, 0.8, 0.1), v(-5.6, 2.55, 24.15), LIGHT_WOOD),
	part(v(9.6, 0.15, 0.2), v(-2, 2.85, 24.1), PURPLE, { material = Enum.Material.Neon }),
	part(v(2, 0.3, 2), v(-8.1, 2.0, 21.9), DARK, { rotation = v(0, -25, 0), collide = false }),
	part(v(2, 2.2, 0.3), v(-8.5, 3.2, 22.7), DARK, { rotation = v(0, -25, 0), collide = false }),
	part(v(0.3, 1.8, 0.3), v(-8.1, 1.0, 21.9), DARK, { collide = false }),
	-- A mug of hot chocolate (a cylinder's length runs along its X axis, so it's stood up)
	part(v(0.6, 0.4, 0.4), v(2.0, 3.7, 26.6), rgb(90, 50, 140), {
		shape = Enum.PartType.Cylinder,
		rotation = v(0, 0, -90),
	}),

	-- The bookshelf in the front-left corner, with a plant on top
	part(v(2, 9, 5), v(17, 4.7, -1.5), DARK_WOOD),
	part(v(0.2, 1, 4.4), v(15.95, 2.0, -1.5), rgb(110, 60, 90)),
	part(v(0.2, 1, 4.4), v(15.95, 4.4, -1.5), rgb(60, 70, 120)),
	part(v(0.2, 1, 4.4), v(15.95, 6.8, -1.5), rgb(200, 180, 120)),
	part(v(1, 1, 1), v(17, 9.7, -1.5), LEAF, { shape = Enum.PartType.Ball, collide = false }),

	-- A dim ceiling light so the room reads at night before anything is bought
	part(v(1, 1, 1), v(0, 12, 12), DARK, {
		transparency = 1,
		collide = false,
		light = { colour = rgb(255, 210, 170), brightness = 1.1, range = 45 },
	}),
	part(v(1, 1, 1), v(0, 12, 23), DARK, {
		transparency = 1,
		collide = false,
		light = { colour = rgb(255, 210, 170), brightness = 0.8, range = 36 },
	}),
}

append(shell, skyline(v(-2, 8.6, 27.7), 13.4, 5.2, "z", 11))
-- Floor plants in the front-right corner and by the bed
append(shell, plant(-16.4, -2.8, 1))
append(shell, plant(16.6, 26.2, 1.2))
append(shell, bed(14.5, 23.5, 1, rgb(110, 70, 190), rgb(214, 210, 220)))

-- The night window on the right wall, with curtains: part of the curtains item.
local curtains: { Types.PartSpec } = {
	part(v(0.2, 6.2, 9.4), v(-17.9, 8.6, 14), TRIM),
	part(v(0.1, 5.4, 8.6), v(-17.82, 8.6, 14), NIGHT, { material = Enum.Material.Neon }),
	part(v(0.12, 5.4, 0.25), v(-17.7, 8.6, 14), TRIM),
	part(v(0.4, 0.5, 10), v(-17.5, 11.9, 14), rgb(64, 60, 74)),
	part(v(0.5, 7.4, 2.4), v(-17.4, 8.2, 9.6), rgb(150, 60, 200), { material = FABRIC }),
	part(v(0.5, 7.4, 2.4), v(-17.4, 8.2, 18.4), rgb(150, 60, 200), { material = FABRIC }),
}
append(curtains, skyline(v(-17.74, 8.6, 14), 8.4, 5.2, "x", 23))

local Dorm: Types.Blockout = {
	shell = shell,

	items = {
		-- The DJ booth: the player's decks (ProximityPrompt "Play"), on the desk under the window
		dorm_laptop = {
			part(v(3, 0.12, 2), v(-2.2, 3.46, 25.4), rgb(60, 62, 70)),
			part(v(3, 2, 0.1), v(-2.2, 4.5, 26.6), rgb(70, 110, 220), {
				rotation = v(15, 0, 0),
				material = Enum.Material.Neon,
				lightRole = "screen",
			}),
		},
		dorm_lamp = {
			part(v(0.8, 0.15, 0.8), v(-5.4, 3.48, 27.1), DARK),
			part(v(0.15, 2.2, 0.15), v(-5.4, 4.6, 27.1), DARK),
			part(v(1, 0.5, 0.7), v(-5.2, 5.7, 26.7), rgb(255, 200, 130), {
				material = Enum.Material.Neon,
				light = { colour = rgb(255, 200, 140), brightness = 1.5, range = 16 },
			}),
		},
		-- Max's desk against the left wall, in front of his bed
		dorm_desk = {
			part(v(4, 0.4, 5.8), v(15.8, 3.2, 4.1), WOOD),
			part(v(0.4, 3, 0.4), v(14.2, 1.7, 1.5), WOOD),
			part(v(0.4, 3, 0.4), v(14.2, 1.7, 6.7), WOOD),
			part(v(2.2, 3, 2.6), v(16.6, 1.7, 2.5), WOOD),
			part(v(0.1, 0.8, 2.2), v(15.45, 1.65, 2.5), LIGHT_WOOD),
			part(v(2, 0.3, 2), v(11.0, 2.0, 4.1), DARK, { collide = false }),
			part(v(0.3, 2.2, 2), v(10.0, 3.2, 4.1), DARK, { collide = false }),
			part(v(0.3, 1.8, 0.3), v(11.0, 1.0, 4.1), DARK, { collide = false }),
			part(v(0.6, 0.4, 0.4), v(14.6, 3.6, 5.2), rgb(220, 90, 140), {
				shape = Enum.PartType.Cylinder,
				rotation = v(0, 0, -90),
			}),
		},
		-- The big rug in the middle of the room: the dance floor
		dorm_rug = {
			part(v(14, 0.05, 10), v(-2, 0.225, 10), rgb(150, 112, 214), { material = FABRIC, collide = false }),
			part(v(12.4, 0.06, 8.4), v(-2, 0.23, 10), rgb(196, 160, 250), { material = FABRIC, collide = false }),
		},
		-- Tall floor speaker beside the desk; the blown speaker event happens here
		dorm_speaker = {
			part(v(1.9, 3.6, 1.8), v(6.4, 2.0, 26.4), DARK),
			part(v(0.1, 1.4, 1.4), v(6.4, 1.3, 25.48), PURPLE, {
				rotation = v(0, -90, 0),
				shape = Enum.PartType.Cylinder,
				material = Enum.Material.Neon,
				lightRole = "speaker",
			}),
			part(v(0.1, 1.1, 1.1), v(6.4, 1.3, 25.44), rgb(40, 40, 48), {
				rotation = v(0, -90, 0),
				shape = Enum.PartType.Cylinder,
			}),
			part(v(0.1, 0.9, 0.9), v(6.4, 2.95, 25.48), PURPLE, {
				rotation = v(0, -90, 0),
				shape = Enum.PartType.Cylinder,
				material = Enum.Material.Neon,
				lightRole = "speaker",
			}),
			part(v(0.1, 0.65, 0.65), v(6.4, 2.95, 25.44), rgb(40, 40, 48), {
				rotation = v(0, -90, 0),
				shape = Enum.PartType.Cylinder,
			}),
		},
		-- Three posters over Max's bed
		dorm_posters = {
			part(v(0.1, 3.2, 2.4), v(17.95, 8, 8.6), rgb(30, 28, 40)),
			part(v(0.05, 1.8, 1.8), v(17.88, 8.2, 8.6), rgb(230, 60, 110), { shape = Enum.PartType.Cylinder }),
			part(v(0.1, 3.2, 2.4), v(17.95, 8, 11.6), rgb(30, 28, 40)),
			part(v(0.05, 0.35, 1.9), v(17.88, 8.8, 11.6), rgb(140, 90, 220)),
			part(v(0.05, 0.35, 1.9), v(17.88, 8.1, 11.6), rgb(140, 90, 220)),
			part(v(0.05, 0.35, 1.9), v(17.88, 7.4, 11.6), rgb(140, 90, 220)),
			part(v(0.1, 3.2, 2.4), v(17.95, 8, 14.6), rgb(30, 28, 40)),
			part(v(0.05, 1.6, 1.6), v(17.88, 8.1, 14.6), PINK, { rotation = v(45, 0, 0) }),
		},
		-- Max's bed along the left wall, between the desk and the night stand
		dorm_bed = bed(14.5, 11.6, 1, rgb(70, 110, 220), rgb(236, 234, 242)),
		-- A purple strip along the top of the walls
		dorm_led = {
			part(v(35.6, 0.25, 0.25), v(0, 13.2, 27.85), PURPLE, {
				material = Enum.Material.Neon,
				light = { colour = PURPLE, brightness = 1, range = 20 },
				lightRole = "led",
			}),
			part(v(0.25, 0.25, 31.6), v(17.85, 13.2, 12), PURPLE, {
				material = Enum.Material.Neon,
				light = { colour = PURPLE, brightness = 0.6, range = 16 },
				lightRole = "led",
			}),
			part(v(0.25, 0.25, 31.6), v(-17.85, 13.2, 12), PURPLE, {
				material = Enum.Material.Neon,
				light = { colour = PURPLE, brightness = 0.6, range = 16 },
				lightRole = "led",
			}),
		},
		-- Two beanbags in the right-hand corner
		dorm_beanbags = {
			part(v(3.2, 3.2, 3.2), v(-13.4, 1.3, 7.2), rgb(130, 70, 170), {
				shape = Enum.PartType.Ball,
				material = FABRIC,
			}),
			part(v(2.8, 2.8, 2.8), v(-10.8, 1.1, 3.6), rgb(40, 38, 60), {
				shape = Enum.PartType.Ball,
				material = FABRIC,
			}),
		},
		-- A mini fridge of soda against the right wall, door to the room
		dorm_fridge = {
			part(v(3.4, 6, 3.2), v(-16.2, 3.2, 21.2), rgb(232, 232, 240)),
			part(v(0.15, 5.2, 2.6), v(-14.45, 3.2, 21.2), rgb(120, 200, 255), {
				material = Enum.Material.Neon,
				transparency = 0.55,
				collide = false,
			}),
			part(v(0.2, 0.9, 0.5), v(-14.4, 4.7, 20.6), rgb(255, 80, 120), { collide = false }),
			part(v(0.2, 0.9, 0.5), v(-14.4, 4.7, 21.4), rgb(80, 160, 255), { collide = false }),
			part(v(0.2, 0.9, 0.5), v(-14.4, 3.2, 20.6), rgb(255, 170, 60), { collide = false }),
			part(v(0.2, 0.9, 0.5), v(-14.4, 3.2, 21.4), rgb(255, 80, 120), { collide = false }),
			part(v(0.2, 0.9, 0.5), v(-14.4, 1.7, 20.6), rgb(80, 160, 255), { collide = false }),
			part(v(0.2, 0.9, 0.5), v(-14.4, 1.7, 21.4), rgb(255, 170, 60), { collide = false }),
		},
		-- The window on the right wall and its curtains
		dorm_curtains = curtains,
		-- A small DJ controller next to the laptop (gear: multiplies income)
		dorm_controller = {
			part(v(2.6, 0.2, 1.4), v(0.9, 3.5, 25.0), rgb(40, 40, 46)),
			part(v(0.1, 0.9, 0.9), v(1.5, 3.62, 25.05), rgb(90, 90, 100), {
				rotation = v(0, 0, -90),
				shape = Enum.PartType.Cylinder,
			}),
			part(v(0.1, 0.9, 0.9), v(0.3, 3.62, 25.05), rgb(90, 90, 100), {
				rotation = v(0, 0, -90),
				shape = Enum.PartType.Cylinder,
			}),
			part(v(2.6, 0.05, 0.1), v(0.9, 3.61, 24.35), rgb(80, 220, 255), {
				material = Enum.Material.Neon,
				lightRole = "screen",
			}),
		},
		-- The cash register on a little counter in the front-right corner: the register holds more
		dorm_register = {
			part(v(4, 2.8, 2.4), v(-15, 1.6, 1.0), rgb(50, 52, 62)),
			part(v(4.4, 0.3, 2.8), v(-15, 3.15, 1.0), rgb(86, 90, 104)),
			part(v(1.8, 0.8, 1.4), v(-15, 3.7, 1.0), rgb(40, 42, 50)),
			part(v(1.6, 1.0, 0.1), v(-14.2, 4.5, 1.0), rgb(30, 34, 40), { rotation = v(0, 0, 18), collide = false }),
			part(v(1.3, 0.7, 0.05), v(-14.25, 4.5, 1.0), rgb(120, 255, 160), {
				rotation = v(0, 0, 18),
				material = Enum.Material.Neon,
				collide = false,
			}),
		},
		dorm_discoball = {
			part(v(0.1, 2.4, 0.1), v(-2, 12.9, 10), DARK, { collide = false }),
			part(v(1.8, 1.8, 1.8), v(-2, 11.2, 10), rgb(220, 220, 230), {
				shape = Enum.PartType.Ball,
				material = Enum.Material.Foil,
				collide = false,
				light = { colour = rgb(255, 255, 255), brightness = 1, range = 22 },
				lightRole = "disco",
			}),
		},
		-- Two spot fixtures in the back corners, aimed at the rug
		dorm_partylights = {
			part(v(1, 1, 0.9), v(15.6, 12.4, 26.9), DARK, { rotation = v(-35, 30, 0) }),
			part(v(0.7, 0.7, 0.1), v(15.35, 12.15, 26.55), PINK, {
				rotation = v(-35, 30, 0),
				material = Enum.Material.Neon,
				collide = false,
				light = { colour = PINK, brightness = 2, range = 36, spot = 50 },
				lightRole = "spot",
			}),
			part(v(1, 1, 0.9), v(-15.6, 12.4, 26.9), DARK, { rotation = v(-35, -30, 0) }),
			part(v(0.7, 0.7, 0.1), v(-15.35, 12.15, 26.55), rgb(60, 220, 255), {
				rotation = v(-35, -30, 0),
				material = Enum.Material.Neon,
				collide = false,
				light = { colour = rgb(60, 220, 255), brightness = 2, range = 36, spot = 50 },
				lightRole = "spot",
			}),
		},
		dorm_neon = {
			part(v(5, 1.6, 0.15), v(-13.2, 9.4, 27.9), DARK, {
				text = { text = "DROP IT", colour = PINK },
				light = { colour = PINK, brightness = 1, range = 12 },
				lightRole = "neon",
			}),
		},
	},

	guests = {
		entrance = v(0, 0.2, -3.4),
		spots = { v(-4.5, 0.2, 8), v(0.5, 0.2, 12), v(-2, 0.2, 5), v(2.6, 0.2, 8.5), v(-6.5, 0.2, 12.5) },
		lookAt = v(-2.2, 0.2, 25),
	},

	decks = {
		itemId = "dorm_laptop",
		stand = v(-2, 0.2, 22.5),
		camera = v(-1.7, 10.4, 27),
		cameraLookAt = v(-2.2, 2.6, 10),
	},

	speakerItem = "dorm_speaker",

	-- Where an ordered item's outline goes when its parts spread over the room.
	placements = {
		dorm_led = { at = v(0, 12.9, 27.4), size = v(35.6, 0.8, 0.8) },
		dorm_partylights = { at = v(15.6, 11.6, 26.4), size = v(2, 1.6, 2) },
	},
}

return Dorm
