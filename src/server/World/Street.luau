--!strict
-- Builds the night street at server start: ground, road, sidewalks, street lamps and the plot
-- bases, with plots facing each other across the road. Returns the plots in order.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local PlotLayout = require(ReplicatedStorage.Shared.Config.PlotLayout)

local Street = {}

local ROAD_WIDTH = 30
local SIDEWALK_WIDTH = 6
local PLOT_GAP = 8 -- between neighbouring plots on the same side
local LAMP_SPACING = 30

local function part(name: string, size: Vector3, cframe: CFrame, colour: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function setNight()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(30, 30, 46)
	Lighting.OutdoorAmbient = Color3.fromRGB(50, 50, 80)
end

local function buildLamp(x: number, z: number, parent: Instance)
	part("LampPost", Vector3.new(0.6, 14, 0.6), CFrame.new(x, 7.6, z), Color3.fromRGB(40, 40, 48), parent)
	local head = part("LampHead", Vector3.new(2, 0.6, 2), CFrame.new(x, 14.6, z), Color3.fromRGB(255, 220, 170), parent)
	head.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 160)
	light.Brightness = 1.2
	light.Range = 26
	light.Shadows = false
	light.Parent = head
end

function Street.build(): { Model }
	setNight()

	local folder = Instance.new("Folder")
	folder.Name = "Street"
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = folder

	local plotSize = PlotLayout.size
	local columns = math.ceil(Balance.World.plotCount / 2)
	local length = columns * (plotSize.X + PLOT_GAP) + 60
	local depth = 2 * (ROAD_WIDTH / 2 + SIDEWALK_WIDTH + plotSize.Z) + 60

	part("Ground", Vector3.new(length, 1, depth), CFrame.new(0, -0.5, 0), Color3.fromRGB(24, 26, 30), folder)
	local road =
		part("Road", Vector3.new(length, 0.2, ROAD_WIDTH), CFrame.new(0, 0.1, 0), Color3.fromRGB(34, 34, 38), folder)
	road.Material = Enum.Material.Asphalt
	for x = -length / 2 + 6, length / 2 - 6, 12 do
		part("LaneMark", Vector3.new(5, 0.05, 0.4), CFrame.new(x, 0.22, 0), Color3.fromRGB(200, 200, 190), folder)
	end
	for _, side in { 1, -1 } do
		local z = side * (ROAD_WIDTH / 2 + SIDEWALK_WIDTH / 2)
		local sidewalk = part(
			"Sidewalk",
			Vector3.new(length, 0.6, SIDEWALK_WIDTH),
			CFrame.new(0, 0.3, z),
			Color3.fromRGB(70, 70, 76),
			folder
		)
		sidewalk.Material = Enum.Material.Concrete
		for x = -length / 2 + LAMP_SPACING / 2, length / 2, LAMP_SPACING do
			buildLamp(x, side * (ROAD_WIDTH / 2 + 1), folder)
		end
	end

	-- Odd plots on the +Z side, even ones across the road; local -Z of every plot faces the road.
	local plots = {}
	for index = 1, Balance.World.plotCount do
		local side = if index % 2 == 1 then 1 else -1
		local column = math.ceil(index / 2)
		local x = (column - 1 - (columns - 1) / 2) * (plotSize.X + PLOT_GAP)
		local z = side * (ROAD_WIDTH / 2 + SIDEWALK_WIDTH + plotSize.Z / 2)
		local facing = if side == 1 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
		local origin = CFrame.new(x, plotSize.Y, z) * facing

		local plot = Instance.new("Model")
		plot.Name = "Plot" .. index
		plot:SetAttribute("PlotIndex", index)
		local base =
			part("Base", plotSize, origin * CFrame.new(0, -plotSize.Y / 2, 0), Color3.fromRGB(46, 48, 56), plot)
		base.Material = Enum.Material.Concrete
		plot.PrimaryPart = base
		plot.WorldPivot = origin
		plot.Parent = plotsFolder
		table.insert(plots, plot)
	end

	folder.Parent = workspace
	return plots
end

return Street
