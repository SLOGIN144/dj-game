--!strict
-- The city around the street: dark towers with a few lit windows, neon roof edges and red aircraft
-- lights, far enough out that they're only ever backdrop (docs/concept/street.webp). The same
-- seed builds the same skyline on every server.

local Builder = require(script.Parent.Builder)

local Skyline = {}

local SEED = 2026
local WARM = Color3.fromRGB(255, 200, 130)
local COOL = Color3.fromRGB(150, 190, 255)
local NEON = { Color3.fromRGB(255, 80, 200), Color3.fromRGB(60, 160, 255), Color3.fromRGB(150, 90, 255) }
local RED = Color3.fromRGB(255, 50, 60)

-- One tower whose street-facing side looks along `facing` (a unit vector on the ground).
local function tower(random: Random, base: Vector3, facing: Vector3, parent: Instance)
	local width = random:NextNumber(16, 34)
	local depth = random:NextNumber(16, 30)
	local height = random:NextNumber(50, 150)
	local shade = random:NextInteger(16, 32)
	local frame = CFrame.lookAt(base, base + facing) * CFrame.new(0, height / 2, 0)
	local body = Builder.part(
		"Tower",
		Vector3.new(width, height, depth),
		frame,
		Color3.fromRGB(shade, shade + 2, shade + 14),
		parent
	)

	-- A few lit windows on the side facing the street.
	local front = frame * CFrame.new(0, 0, -depth / 2 - 0.05)
	for _ = 1, random:NextInteger(4, 9) do
		local x = random:NextNumber(-width / 2 + 2, width / 2 - 2)
		local y = random:NextNumber(-height / 2 + 6, height / 2 - 4)
		local colour = if random:NextNumber() < 0.75 then WARM else COOL
		Builder.neon("Window", Vector3.new(1.6, 2.2, 0.1), front * CFrame.new(x, y, 0), colour, body)
	end
	-- A neon edge on some roofs, a red light on the tallest.
	if random:NextNumber() < 0.35 then
		local colour = NEON[random:NextInteger(1, #NEON)]
		Builder.neon("RoofEdge", Vector3.new(width, 0.5, 0.5), front * CFrame.new(0, height / 2 - 0.3, 0), colour, body)
	end
	if height > 120 then
		Builder.neon("AircraftLight", Vector3.new(0.8, 0.8, 0.8), frame * CFrame.new(0, height / 2 + 0.4, 0), RED, body)
	end
end

-- Towers in a band around the street's ground (`length` along X, `depth` along Z, centred on
-- the origin), plus a farther band past the airstrip at +X.
function Skyline.build(parent: Instance, length: number, depth: number, airstripEnd: number)
	local folder = Builder.folder("Skyline", parent)
	local random = Random.new(SEED)
	local halfLength, halfDepth = length / 2, depth / 2

	for _, side in { 1, -1 } do
		local x = -halfLength - 120
		while x < airstripEnd + 60 do
			local z = side * (halfDepth + random:NextNumber(30, 90))
			tower(random, Vector3.new(x, 0, z), Vector3.new(0, 0, -side), folder)
			x += random:NextNumber(26, 40)
		end
	end
	local z = -halfDepth
	while z < halfDepth do
		tower(random, Vector3.new(-halfLength - random:NextNumber(40, 100), 0, z), Vector3.new(1, 0, 0), folder)
		tower(random, Vector3.new(airstripEnd + random:NextNumber(60, 140), 0, z), Vector3.new(-1, 0, 0), folder)
		z += random:NextNumber(28, 42)
	end
end

return Skyline
