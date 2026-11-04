--!strict
-- Street furniture and the two ends of the street (docs/concept/street.webp, model sheet
-- "Street"): trees, benches, bins and a crosswalk along the road; the leaderboard billboard at
-- one end; at the other, the closed airstrip gate with the private jet waiting behind it, the
-- big goal in sight from the start. Imported art from ServerStorage › Art › street replaces a
-- prop's blockout where it exists.

local Art = require(script.Parent.Art)
local Builder = require(script.Parent.Builder)

local StreetProps = {}

local rgb = Color3.fromRGB
local WOOD = rgb(138, 98, 68)
local IRON = rgb(46, 46, 58)
local LEAF = rgb(47, 94, 62)
local LEAF_LIGHT = rgb(55, 107, 70)
local CONCRETE = rgb(74, 74, 86)
local WHITE = rgb(236, 236, 244)
local PURPLE = rgb(150, 90, 255)

export type Layout = {
	length: number, -- the street's ground along X
	roadWidth: number,
	sidewalkWidth: number,
	sidewalkTop: number, -- y of the sidewalk surface
	airstripLength: number,
}

-- Uses the imported model for a prop if there is one, else builds the blockout.
local function prop(id: string, cframe: CFrame, parent: Instance, blockout: (Model) -> ())
	local art = Art.find("street", id)
	if art then
		Art.place(art, cframe, parent)
		return
	end
	local model = Instance.new("Model")
	model.Name = id
	blockout(model)
	model.Parent = parent
end

local function tree(cframe: CFrame, parent: Instance)
	prop("street_tree", cframe, parent, function(model)
		Builder.part("Planter", Vector3.new(3.4, 1.2, 3.4), cframe * CFrame.new(0, 0.6, 0), CONCRETE, model)
		Builder.part(
			"Trunk",
			Vector3.new(5, 0.8, 0.8),
			cframe * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
			rgb(90, 64, 48),
			model,
			{ shape = Enum.PartType.Cylinder }
		)
		Builder.part(
			"Crown",
			Vector3.new(6, 6, 6),
			cframe * CFrame.new(0, 8, 0),
			LEAF,
			model,
			{ shape = Enum.PartType.Ball }
		)
		Builder.part(
			"Crown",
			Vector3.new(4, 4, 4),
			cframe * CFrame.new(-1.8, 7, 0.8),
			LEAF_LIGHT,
			model,
			{ shape = Enum.PartType.Ball }
		)
		Builder.part(
			"Crown",
			Vector3.new(4.2, 4.2, 4.2),
			cframe * CFrame.new(1.8, 7.2, -0.6),
			LEAF_LIGHT,
			model,
			{ shape = Enum.PartType.Ball }
		)
	end)
end

-- A bench whose seat faces along the cframe's look direction.
local function bench(cframe: CFrame, parent: Instance)
	prop("street_bench", cframe, parent, function(model)
		Builder.part("Seat", Vector3.new(5, 0.3, 1.6), cframe * CFrame.new(0, 1.5, 0), WOOD, model, { collide = true })
		Builder.part("Back", Vector3.new(5, 1.2, 0.25), cframe * CFrame.new(0, 2.3, 0.75), WOOD, model)
		for _, x in { -2, 2 } do
			Builder.part("Leg", Vector3.new(0.3, 1.5, 1.4), cframe * CFrame.new(x, 0.75, 0), IRON, model)
		end
	end)
end

local function bin(cframe: CFrame, parent: Instance)
	prop("street_bin", cframe, parent, function(model)
		Builder.part(
			"Bin",
			Vector3.new(2.6, 1.6, 1.6),
			cframe * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
			rgb(51, 92, 72),
			model,
			{ shape = Enum.PartType.Cylinder, collide = true }
		)
		Builder.part("Lid", Vector3.new(1.8, 0.3, 1.8), cframe * CFrame.new(0, 2.7, 0), rgb(42, 74, 58), model)
	end)
end

local function billboard(cframe: CFrame, parent: Instance)
	prop("street_billboard", cframe, parent, function(model)
		for _, x in { -6, 6 } do
			Builder.part(
				"Post",
				Vector3.new(0.8, 7, 0.8),
				cframe * CFrame.new(x, 3.5, 0.4),
				IRON,
				model,
				{ collide = true }
			)
		end
		Builder.part("Frame", Vector3.new(19, 10.5, 1), cframe * CFrame.new(0, 12, 0.4), rgb(26, 26, 40), model)
		Builder.neon("Edge", Vector3.new(19.4, 0.3, 0.3), cframe * CFrame.new(0, 17.4, 0), rgb(60, 160, 255), model)
		Builder.neon("Edge", Vector3.new(19.4, 0.3, 0.3), cframe * CFrame.new(0, 6.6, 0), rgb(60, 160, 255), model)
		local screen =
			Builder.part("Screen", Vector3.new(18, 9.6, 0.2), cframe * CFrame.new(0, 12, -0.15), rgb(14, 14, 26), model)
		screen.Material = Enum.Material.SmoothPlastic
	end)
end

-- The gate across the road at the airstrip end. `cframe` looks towards the street, so the gate
-- spans its local X axis (across the road).
local function gate(cframe: CFrame, width: number, parent: Instance)
	prop("street_gate", cframe, parent, function(model)
		for _, x in { -width / 2 - 1.5, width / 2 + 1.5 } do
			Builder.part(
				"Pillar",
				Vector3.new(3, 9, 3),
				cframe * CFrame.new(x, 4.5, 0),
				rgb(84, 80, 92),
				model,
				{ collide = true }
			)
			Builder.part(
				"Lamp",
				Vector3.new(1.4, 1.4, 1.4),
				cframe * CFrame.new(x, 9.8, 0),
				rgb(255, 210, 160),
				model,
				{ material = Enum.Material.Neon, light = { colour = rgb(255, 200, 150), brightness = 1, range = 18 } }
			)
		end
		for _, side in { -1, 1 } do
			local leaf = Instance.new("Model")
			leaf.Name = if side < 0 then "GateLeft" else "GateRight"
			local centre = cframe * CFrame.new(side * width / 4, 0, 0)
			Builder.part("Rail", Vector3.new(width / 2, 0.5, 0.4), centre * CFrame.new(0, 7, 0), IRON, leaf)
			Builder.part("Rail", Vector3.new(width / 2, 0.5, 0.4), centre * CFrame.new(0, 1, 0), IRON, leaf)
			for bar = 0, 6 do
				local x = (bar - 3) * (width / 2) / 7
				Builder.part(
					"Bar",
					Vector3.new(0.3, 6.5, 0.3),
					centre * CFrame.new(x, 4, 0),
					IRON,
					leaf,
					{ collide = true }
				)
			end
			leaf.Parent = model
		end
		Builder.neon("Locked", Vector3.new(0.6, 1.6, 0.4), cframe * CFrame.new(0, 4, -0.4), rgb(255, 60, 90), model)
	end)
end

-- The private jet, nose towards -X, wheels on the ground at `cframe`.
local function jet(cframe: CFrame, parent: Instance)
	prop("street_jet", cframe, parent, function(model)
		local body = cframe * CFrame.new(0, 5, 0)
		Builder.part("Fuselage", Vector3.new(34, 5.6, 5.6), body, WHITE, model, { shape = Enum.PartType.Cylinder })
		Builder.part(
			"Nose",
			Vector3.new(5.6, 5.6, 5.6),
			body * CFrame.new(-17, 0, 0),
			WHITE,
			model,
			{ shape = Enum.PartType.Ball }
		)
		Builder.part(
			"TailCone",
			Vector3.new(6, 4.2, 4.2),
			body * CFrame.new(19, 0.4, 0),
			rgb(226, 226, 236),
			model,
			{ shape = Enum.PartType.Cylinder }
		)
		Builder.part(
			"Fin",
			Vector3.new(5, 7, 0.6),
			body * CFrame.new(19, 5, 0) * CFrame.Angles(0, 0, math.rad(-25)),
			rgb(220, 220, 232),
			model
		)
		Builder.part("Tailplane", Vector3.new(3.2, 0.4, 11), body * CFrame.new(21, 8, 0), rgb(220, 220, 232), model)
		for _, side in { -1, 1 } do
			Builder.part(
				"Wing",
				Vector3.new(6, 0.5, 14),
				body * CFrame.new(1, -1.6, side * 9) * CFrame.Angles(0, math.rad(side * 18), 0),
				rgb(224, 224, 234),
				model
			)
			Builder.part(
				"Engine",
				Vector3.new(5, 2.2, 2.2),
				body * CFrame.new(14, 1.6, side * 4),
				rgb(200, 200, 212),
				model,
				{ shape = Enum.PartType.Cylinder }
			)
			Builder.neon(
				"WingLight",
				Vector3.new(0.6, 0.6, 0.6),
				body * CFrame.new(3, -1.4, side * 16),
				if side < 0 then rgb(255, 60, 60) else rgb(60, 255, 120),
				model
			)
		end
		Builder.neon("Stripe", Vector3.new(30, 0.4, 5.7), body * CFrame.new(1, -0.8, 0), PURPLE, model)
		for i = 0, 6 do
			Builder.neon(
				"Window",
				Vector3.new(0.9, 0.9, 5.7),
				body * CFrame.new(-10 + i * 3.4, 1, 0),
				rgb(255, 214, 150),
				model
			)
		end
		Builder.part(
			"Airstair",
			Vector3.new(2.6, 0.4, 6.4),
			body * CFrame.new(-11, -4.4, -4.6) * CFrame.Angles(math.rad(40), 0, 0),
			rgb(200, 200, 210),
			model
		)
		for _, offset in { Vector3.new(-12, -3.6, 0), Vector3.new(4, -3.6, 2.4), Vector3.new(4, -3.6, -2.4) } do
			Builder.part("Gear", Vector3.new(1.4, 2.8, 0.6), body * CFrame.new(offset), IRON, model)
		end
	end)
end

local function airstrip(start: number, length: number, parent: Instance)
	local folder = Builder.folder("Airstrip", parent)
	local centre = start + length / 2
	Builder.part(
		"Apron",
		Vector3.new(length, 1, 90),
		CFrame.new(centre, -0.5, 0),
		rgb(30, 34, 30),
		folder,
		{ collide = true, material = Enum.Material.Grass }
	)
	Builder.part(
		"Runway",
		Vector3.new(length - 10, 0.2, 28),
		CFrame.new(centre, 0.1, 0),
		rgb(34, 34, 40),
		folder,
		{ collide = true, material = Enum.Material.Asphalt }
	)
	local x = start + 12
	while x < start + length - 10 do
		Builder.part("CentreLine", Vector3.new(6, 0.05, 0.5), CFrame.new(x, 0.23, 0), WHITE, folder)
		for _, z in { -13.5, 13.5 } do
			Builder.neon("EdgeLight", Vector3.new(0.5, 0.4, 0.5), CFrame.new(x, 0.4, z), rgb(120, 180, 255), folder)
		end
		x += 14
	end
	-- Fences along both sides of the airport.
	for _, z in { -44, 44 } do
		for _, y in { 2.2, 4.4 } do
			Builder.part("FenceRail", Vector3.new(length, 0.2, 0.2), CFrame.new(centre, y, z), IRON, folder)
		end
		local post = start + 4
		while post < start + length do
			Builder.part(
				"FencePost",
				Vector3.new(0.3, 5, 0.3),
				CFrame.new(post, 2.5, z),
				IRON,
				folder,
				{ collide = true }
			)
			post += 16
		end
	end
end

-- Builds the props for a street laid out as `layout` (road along X, centred on the origin).
function StreetProps.build(parent: Instance, layout: Layout)
	local folder = Builder.folder("Props", parent)
	local half = layout.length / 2
	local walk = layout.roadWidth / 2 + layout.sidewalkWidth * 0.75
	local top = layout.sidewalkTop

	for _, side in { 1, -1 } do
		local facingRoad = CFrame.Angles(0, if side == 1 then 0 else math.pi, 0)
		for _, x in { -half + 8, half - 22 } do
			tree(CFrame.new(x, top, side * walk), folder)
		end
		bench(CFrame.new(-half + 20, top, side * (walk + 0.4)) * facingRoad, folder)
		bin(CFrame.new(-half + 25, top, side * (walk + 0.6)), folder)
	end

	-- A crosswalk before the gate.
	for i = 0, 7 do
		local z = -layout.roadWidth / 2 + 2 + i * (layout.roadWidth - 4) / 7
		Builder.part("Crosswalk", Vector3.new(5, 0.05, 1.6), CFrame.new(half - 14, 0.23, z), WHITE, folder)
	end

	-- The leaderboard at the near end, facing down the street.
	billboard(CFrame.lookAt(Vector3.new(-half + 3, 0, 0), Vector3.new(0, 0, 0)), folder)

	-- The gate, the airstrip and the jet at the far end.
	local gateAt = CFrame.lookAt(Vector3.new(half - 3, 0, 0), Vector3.new(-1000, 0, 0))
	gate(gateAt, layout.roadWidth + 2, folder)
	airstrip(half, layout.airstripLength, folder)
	jet(CFrame.new(half + 48, 0.2, -2) * CFrame.Angles(0, math.rad(12), 0), folder)

	-- The prompt at the gate that flies an owner to their venue once they have one (Services/Travel
	-- checks; clients show it as locked until then).
	local anchor = Instance.new("Part")
	anchor.Name = "GatePrompt"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.CFrame = gateAt * CFrame.new(0, 4, -2)
	anchor.Parent = folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TravelPrompt"
	prompt.ActionText = "Fly to Ibiza"
	prompt.ObjectText = "Private jet"
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Travel", "venue")
	prompt.Parent = anchor
end

-- The private jet as a prop, nose towards -X, wheels on the ground at `cframe` (also used at
-- each venue's runway).
function StreetProps.jet(cframe: CFrame, parent: Instance)
	jet(cframe, parent)
end

-- The billboard's screen part, where the leaderboard draws.
function StreetProps.screen(parent: Instance): BasePart?
	local props = parent:FindFirstChild("Props")
	local board = if props then props:FindFirstChild("street_billboard") else nil
	local screen = if board then board:FindFirstChild("Screen", true) else nil
	return if screen and screen:IsA("BasePart") then screen else nil
end

return StreetProps
