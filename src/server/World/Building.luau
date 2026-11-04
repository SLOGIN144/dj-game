--!strict
-- Builds a plot's building for a stage (Config/Buildings): a block behind the room with floor
-- bands, windows (some lit), a roof with parapet and machinery, and for later stages neon edges
-- and a rooftop sign. Imported art from ServerStorage › Art › street (building_<stage>) replaces
-- the blockout, pivoted at the bottom centre of its front face.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(script.Parent.Art)
local Builder = require(script.Parent.Builder)
local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)

local Building = {}

local WARM = Color3.fromRGB(255, 206, 140)
local GLASS = Color3.fromRGB(28, 32, 50)
local WINDOW = Vector3.new(3, 4, 0.2)
local SPACING = 6

-- Windows along one face. `face` is a CFrame at the face's bottom centre looking outwards, so
-- local X runs along the face.
local function windows(face: CFrame, span: number, stage: Buildings.Stage, random: Random, parent: Instance)
	local columns = math.max(1, math.floor((span - 2) / SPACING))
	local first = -(columns - 1) * SPACING / 2
	for floor = 0, stage.floors - 1 do
		local y = floor * stage.floorHeight + stage.floorHeight / 2 + 0.5
		if y - WINDOW.Y / 2 < stage.roomHeight - 1 then
			continue -- hidden behind the room
		end
		for column = 0, columns - 1 do
			local lit = random:NextNumber() < stage.litShare
			local pane = Builder.part(
				"Window",
				WINDOW,
				face * CFrame.new(first + column * SPACING, y, -0.12),
				if lit then WARM else GLASS,
				parent,
				{ material = if lit then Enum.Material.Neon else Enum.Material.Glass }
			)
			if not lit then
				pane.Transparency = 0.15
			end
		end
	end
end

local function blockout(origin: CFrame, stage: Buildings.Stage, seed: number, parent: Instance)
	local random = Random.new(seed)
	local height = stage.floors * stage.floorHeight
	local front = origin * CFrame.new(0, 0, stage.frontZ)
	local centre = front * CFrame.new(0, height / 2, stage.depth / 2)
	Builder.part(
		"Body",
		Vector3.new(stage.width, height, stage.depth),
		centre,
		stage.colour,
		parent,
		{ collide = true, material = Enum.Material.Concrete }
	)

	-- Faces looking out: the front (its look direction is already the street side, -Z) and both sides.
	windows(front, stage.width, stage, random, parent)
	for _, side in { -1, 1 } do
		local sideFace = front
			* CFrame.new(side * stage.width / 2, 0, stage.depth / 2)
			* CFrame.Angles(0, -side * math.pi / 2, 0)
		windows(sideFace, stage.depth, stage, random, parent)
	end

	-- Floor bands on the front.
	for floor = 1, stage.floors - 1 do
		local y = floor * stage.floorHeight
		if y > stage.roomHeight then
			Builder.part(
				"Band",
				Vector3.new(stage.width + 0.4, 0.5, 0.4),
				front * CFrame.new(0, y, -0.1),
				stage.trim,
				parent
			)
		end
	end

	-- Roof: parapet, machinery and, later, neon and a sign.
	local roof = front * CFrame.new(0, height, stage.depth / 2)
	Builder.part(
		"Parapet",
		Vector3.new(stage.width, 1.2, 0.6),
		roof * CFrame.new(0, 0.6, -stage.depth / 2 + 0.3),
		stage.trim,
		parent
	)
	Builder.part(
		"Parapet",
		Vector3.new(stage.width, 1.2, 0.6),
		roof * CFrame.new(0, 0.6, stage.depth / 2 - 0.3),
		stage.trim,
		parent
	)
	Builder.part(
		"AirCon",
		Vector3.new(3, 2, 2.4),
		roof * CFrame.new(-stage.width / 4, 1, 0),
		Color3.fromRGB(150, 150, 160),
		parent
	)
	if stage.depth >= 12 then
		Builder.part(
			"WaterTank",
			Vector3.new(4, 3.4, 3.4),
			roof * CFrame.new(stage.width / 4, 2.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(96, 80, 70),
			parent,
			{ shape = Enum.PartType.Cylinder }
		)
	end
	local neon = stage.neon
	if neon then
		Builder.neon(
			"RoofEdge",
			Vector3.new(stage.width, 0.4, 0.4),
			front * CFrame.new(0, height + 0.2, -0.3),
			neon,
			parent
		)
		for _, side in { -1, 1 } do
			Builder.neon(
				"CornerStrip",
				Vector3.new(0.4, height - stage.roomHeight, 0.4),
				front
					* CFrame.new(
						side * (stage.width / 2 - 0.2),
						stage.roomHeight + (height - stage.roomHeight) / 2,
						-0.3
					),
				neon,
				parent
			)
		end
	end
	local sign = stage.sign
	if sign then
		local board = Builder.part(
			"RoofSign",
			Vector3.new(math.min(stage.width - 6, #sign * 5 + 6), 7, 0.6),
			roof * CFrame.new(0, 4.5, -stage.depth / 2 + 1),
			Color3.fromRGB(16, 16, 24),
			parent
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Brightness = 3
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = sign
		text.TextScaled = true
		text.TextColor3 = neon or WARM
		text.Font = Enum.Font.BuilderSansExtraBold
		text.Parent = gui
		gui.Parent = board -- its Front face looks along the plot's -Z, at the street
	end
end

-- Replaces the plot's building with the one for `stageId` (a location id or "free").
function Building.show(plot: Model, stageId: string, seed: number)
	local folder = plot:FindFirstChild("Building")
	if not folder then
		folder = Builder.folder("Building", plot)
	end
	(folder :: Instance):ClearAllChildren()
	local stage = Buildings[stageId] or Buildings.free
	local origin = plot:GetPivot()
	local art = Art.find("street", "building_" .. stageId)
	if art then
		Art.place(art, origin * CFrame.new(0, 0, stage.frontZ), folder :: Instance)
		return
	end
	blockout(origin, stage, seed, folder :: Instance)
end

return Building
