--!strict
-- People built from parts for the event characters the server places (the VIP at the door, the
-- photographer by the decks), so everyone sees the same ones. They stand still; once there are
-- rigs and animation IDs, the art pass replaces them (model sheet "Characters").

local Builder = require(script.Parent.Builder)

local Figures = {}

export type Look = {
	skin: Color3,
	top: Color3,
	legs: Color3,
	hair: Color3?,
}

local DARK = Color3.fromRGB(20, 20, 26)

-- A standing person with their feet at `at`, facing along its look vector.
function Figures.person(name: string, at: CFrame, look: Look, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	local torso = Builder.part("Torso", Vector3.new(2, 2, 1), at * CFrame.new(0, 3, 0), look.top, model)
	Builder.part(
		"Head",
		Vector3.new(1.25, 1.25, 1.25),
		at * CFrame.new(0, 4.6, 0),
		look.skin,
		model,
		{ shape = Enum.PartType.Ball }
	)
	if look.hair then
		Builder.part("Hair", Vector3.new(1.3, 0.45, 1.3), at * CFrame.new(0, 5.15, 0.05), look.hair, model)
	end
	for _, side in { -1, 1 } do
		Builder.part("Arm", Vector3.new(0.8, 1.8, 0.8), at * CFrame.new(side * 1.4, 3.1, 0), look.top, model)
		Builder.part("Leg", Vector3.new(0.9, 2, 0.9), at * CFrame.new(side * 0.5, 1, 0), look.legs, model)
	end
	model.PrimaryPart = torso
	model.Parent = parent
	return model
end

-- A VIP: gold jacket, dark trousers and sunglasses.
function Figures.vip(at: CFrame, parent: Instance): Model
	local model = Figures.person("VIP", at, {
		skin = Color3.fromRGB(214, 160, 120),
		top = Color3.fromRGB(240, 196, 70),
		legs = DARK,
		hair = Color3.fromRGB(30, 24, 22),
	}, parent)
	Builder.part("Sunglasses", Vector3.new(1.1, 0.25, 0.1), at * CFrame.new(0, 4.75, -0.62), DARK, model)
	return model
end

-- A photographer with a camera held up to their face, its flash on top.
function Figures.photographer(at: CFrame, parent: Instance): (Model, BasePart)
	local model = Figures.person("Photographer", at, {
		skin = Color3.fromRGB(236, 190, 150),
		top = Color3.fromRGB(60, 64, 80),
		legs = Color3.fromRGB(40, 44, 60),
		hair = Color3.fromRGB(150, 96, 52),
	}, parent)
	local camera = Builder.part("Camera", Vector3.new(1, 0.7, 0.5), at * CFrame.new(0, 4.6, -0.95), DARK, model)
	Builder.part(
		"Lens",
		Vector3.new(0.5, 0.45, 0.45),
		at * CFrame.new(0, 4.6, -1.35) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(46, 50, 60),
		model,
		{ shape = Enum.PartType.Cylinder }
	)
	local flash = Builder.neon(
		"Flash",
		Vector3.new(0.4, 0.25, 0.3),
		at * CFrame.new(0.2, 5.05, -0.95),
		Color3.new(1, 1, 1),
		model
	)
	camera.Name = "Camera"
	return model, flash
end

return Figures
