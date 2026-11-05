--!strict
-- A star DJ at the decks during their guest set (GDD: star DJs), on every client: a figure in
-- their look (Config/StarDjs: colours and a signature hat) behind the plot's booth, headphones on,
-- nodding on the beat of the plot's mix with a hand on the decks and the other one up on drops.
-- It's built from parts on this client like the guests; the art pass replaces it with a rig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local Booking = require(ReplicatedStorage.Shared.Economy.Booking)
local PlotMixes = require(script.Parent.PlotMixes)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local TrackInfo = require(ReplicatedStorage.Shared.Music.TrackInfo)
local Types = require(ReplicatedStorage.Shared.Types)

local StarDjView = {}

local VIEW_DISTANCE = 220

-- A part that rides on the head (hair, headphones, a hat), placed relative to the head's centre.
type Worn = { part: BasePart, offset: CFrame }

type Figure = {
	djId: string,
	locationId: string,
	model: Model,
	parts: { BasePart }, -- torso, head, left arm, right arm, left leg, right leg
	worn: { Worn },
}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis (X) to vertical
local STRAW = Color3.fromRGB(226, 196, 132)

local figures: { [Model]: Figure } = {}
local folder: Folder

local function part(model: Model, name: string, size: Vector3, colour: Color3, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = model
	return p
end

local function build(plot: Model, dj: Types.StarDj, locationId: string): Figure
	local look = dj.look
	local model = Instance.new("Model")
	model.Name = plot.Name .. "_" .. dj.id
	local cup = Vector3.new(0.35, 0.7, 0.7)
	local parts = {
		part(model, "Torso", Vector3.new(2, 2, 1), look.top),
		part(model, "Head", Vector3.new(1.25, 1.25, 1.25), look.skin, Enum.PartType.Ball),
		part(model, "LeftArm", Vector3.new(0.8, 1.8, 0.8), look.top),
		part(model, "RightArm", Vector3.new(0.8, 1.8, 0.8), look.top),
		part(model, "LeftLeg", Vector3.new(0.9, 2, 0.9), Color3.fromRGB(30, 30, 40)),
		part(model, "RightLeg", Vector3.new(0.9, 2, 0.9), Color3.fromRGB(30, 30, 40)),
	}
	local worn: { Worn } = {
		{ part = part(model, "Hair", Vector3.new(1.3, 0.45, 1.3), look.hair), offset = CFrame.new(0, 0.55, 0.05) },
		{ part = part(model, "Band", Vector3.new(1.5, 0.2, 0.3), look.accent), offset = CFrame.new(0, 0.62, 0) },
		{ part = part(model, "LeftCup", cup, look.accent), offset = CFrame.new(-0.72, 0, 0) },
		{ part = part(model, "RightCup", cup, look.accent), offset = CFrame.new(0.72, 0, 0) },
	}
	local function wear(name: string, size: Vector3, colour: Color3, offset: CFrame, shape: Enum.PartType?)
		table.insert(worn, { part = part(model, name, size, colour, shape), offset = offset })
	end
	if look.hat == "bucket" then
		wear("Brim", Vector3.new(0.12, 1.9, 1.9), look.top, CFrame.new(0, 0.5, 0) * UPRIGHT, Enum.PartType.Cylinder)
		wear("Crown", Vector3.new(0.55, 1.35, 1.35), look.top, CFrame.new(0, 0.78, 0) * UPRIGHT, Enum.PartType.Cylinder)
		wear(
			"HatBand",
			Vector3.new(0.14, 1.4, 1.4),
			look.accent,
			CFrame.new(0, 0.6, 0) * UPRIGHT,
			Enum.PartType.Cylinder
		)
	elseif look.hat == "sun" then
		wear("Brim", Vector3.new(0.1, 2.7, 2.7), STRAW, CFrame.new(0, 0.5, 0) * UPRIGHT, Enum.PartType.Cylinder)
		wear("Crown", Vector3.new(0.5, 1.3, 1.3), STRAW, CFrame.new(0, 0.76, 0) * UPRIGHT, Enum.PartType.Cylinder)
		wear(
			"HatBand",
			Vector3.new(0.14, 1.34, 1.34),
			look.accent,
			CFrame.new(0, 0.58, 0) * UPRIGHT,
			Enum.PartType.Cylinder
		)
	elseif look.hat == "visor" then
		local visor = part(model, "Visor", Vector3.new(1.3, 0.24, 0.16), look.accent)
		visor.Material = Enum.Material.Neon
		table.insert(worn, { part = visor, offset = CFrame.new(0, 0.12, -0.6) })
	end
	local glow = Instance.new("PointLight")
	glow.Color = dj.colour
	glow.Range = 10
	glow.Brightness = 1.5
	glow.Parent = worn[2].part
	model.Parent = folder
	return { djId = dj.id, locationId = locationId, model = model, parts = parts, worn = worn }
end

local function animate(plot: Model, figure: Figure, blockout: Types.Blockout, parts: { BasePart }, frames: { CFrame })
	local origin = PlotSpace.origin(plot)
	local stand = origin * blockout.decks.stand
	local floor = origin * blockout.decks.cameraLookAt
	local root = CFrame.lookAt(stand, Vector3.new(floor.X, stand.Y, floor.Z))

	local nod, drop, beat = 0, false, os.clock() * 2
	local _, main = PlotMixes.at(plot, PlotMixes.now())
	if main then
		beat = main.beat
		local section = TrackInfo.sectionAt(main.track, beat)
		drop = section.kind == "drop"
		nod = (1 - beat % 1) ^ 2
	end

	local body = root * CFrame.new(0, -0.15 * nod, 0)
	local head = body * CFrame.new(0, 4.6, 0) * CFrame.Angles(math.rad(-14 * nod), 0, 0)
	-- One hand on the decks, riding the mix; the other one up on drops.
	local mixing = math.sin(beat * math.pi / 2) * math.rad(8)
	local free = if drop then math.rad(165) + math.sin(beat * math.pi) * math.rad(10) else math.rad(70)
	table.insert(frames, body * CFrame.new(0, 3, 0))
	table.insert(frames, head)
	table.insert(
		frames,
		body * CFrame.new(-1.4, 3.9, 0) * CFrame.Angles(math.rad(70) + mixing, 0, -0.1) * CFrame.new(0, -0.9, 0)
	)
	table.insert(frames, body * CFrame.new(1.4, 3.9, 0) * CFrame.Angles(free, 0, 0.12) * CFrame.new(0, -0.9, 0))
	table.insert(frames, root * CFrame.new(-0.5, 1, 0))
	table.insert(frames, root * CFrame.new(0.5, 1, 0))
	for _, p in figure.parts do
		table.insert(parts, p)
	end
	for _, item in figure.worn do
		table.insert(parts, item.part)
		table.insert(frames, head * item.offset)
	end
end

function StarDjView.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalStarDjs"
	folder.Parent = workspace

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		for _, plot in PlotMixes.plots() do
			local djId = plot:GetAttribute("StarDj")
			local dj = if typeof(djId) == "string" then Booking.find(djId) else nil
			local locationId = PlotSpace.locationId(plot)
			local blockout = if locationId then Blockouts[locationId] else nil
			local figure: Figure? = figures[plot]
			if figure and (not dj or figure.djId ~= dj.id or figure.locationId ~= locationId) then
				figure.model:Destroy()
				figures[plot] = nil
				figure = nil
			end
			if dj and blockout and locationId and not figure then
				figure = build(plot, dj, locationId)
				figures[plot] = figure
			end
			if figure and blockout and PlotSpace.distance(plot, eye) <= VIEW_DISTANCE then
				animate(plot, figure, blockout, parts, frames)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return StarDjView
