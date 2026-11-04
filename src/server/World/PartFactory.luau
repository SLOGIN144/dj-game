--!strict
-- Builds one blockout Part from a PartSpec, placed relative to a plot's origin. A spec with
-- `terrain` fills its box with smooth terrain instead and leaves an invisible marker part, which
-- `clearTerrain` uses to take the terrain away again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local PartFactory = {}

-- The CFrame a spec's part sits at, for a plot whose origin is `origin`.
function PartFactory.place(spec: Types.PartSpec, origin: CFrame): CFrame
	local r = spec.rotation or Vector3.zero
	return origin * CFrame.new(spec.offset) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
end

local TERRAIN_MARKER = "TerrainFill"

-- Fills the spec's box with terrain; the marker part keeps where it is.
local function fillTerrain(spec: Types.PartSpec, material: Enum.Material, origin: CFrame, parent: Instance): Part
	local cframe = PartFactory.place(spec, origin)
	workspace.Terrain:FillBlock(cframe, spec.size, material)
	local marker = Instance.new("Part")
	marker.Name = TERRAIN_MARKER
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = spec.size
	marker.CFrame = cframe
	marker:SetAttribute(TERRAIN_MARKER, material.Name)
	marker.Parent = parent
	return marker
end

-- Takes away the terrain that parts built into `folder` filled (call before clearing it).
function PartFactory.clearTerrain(folder: Instance)
	for _, marker in folder:GetDescendants() do
		if marker:IsA("BasePart") and marker:GetAttribute(TERRAIN_MARKER) ~= nil then
			workspace.Terrain:FillBlock(marker.CFrame, marker.Size, Enum.Material.Air)
		end
	end
end

function PartFactory.build(spec: Types.PartSpec, origin: CFrame, parent: Instance): Part
	local terrain = spec.terrain
	if terrain then
		return fillTerrain(spec, terrain, origin, parent)
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = spec.size
	part.Color = spec.colour
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Shape = spec.shape or Enum.PartType.Block
	part.Transparency = spec.transparency or 0
	part.CanCollide = if spec.collide == nil then true else spec.collide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = PartFactory.place(spec, origin)

	local light = spec.light
	if light then
		local instance: Light
		if light.spot then
			local spotLight = Instance.new("SpotLight")
			spotLight.Face = Enum.NormalId.Front
			spotLight.Angle = light.spot
			spotLight.Range = light.range
			instance = spotLight
		else
			local pointLight = Instance.new("PointLight")
			pointLight.Range = light.range
			instance = pointLight
		end
		instance.Color = light.colour or spec.colour
		instance.Brightness = light.brightness
		instance.Shadows = false
		instance.Parent = part
	end

	if spec.lightRole then
		part:SetAttribute("LightRole", spec.lightRole)
	end
	if spec.fx then
		part:SetAttribute("Fx", spec.fx)
	end

	local beam = spec.beam
	if beam then
		-- From the front face out along the part's look direction, fading as it goes.
		local start = Instance.new("Attachment")
		start.Name = "BeamStart"
		start.Position = Vector3.new(0, 0, -spec.size.Z / 2)
		start.Parent = part
		local finish = Instance.new("Attachment")
		finish.Name = "BeamEnd"
		finish.Position = Vector3.new(0, 0, -spec.size.Z / 2 - beam.length)
		finish.Parent = part
		local ray = Instance.new("Beam")
		ray.Attachment0 = start
		ray.Attachment1 = finish
		ray.Color = ColorSequence.new(spec.colour)
		ray.Transparency = NumberSequence.new(0.7, 1)
		ray.Width0 = beam.width
		ray.Width1 = beam.width * 4
		ray.FaceCamera = true
		ray.LightEmission = 1
		ray.LightInfluence = 0
		ray.Segments = 1
		ray.Parent = part
	end

	local smoke = spec.smoke
	if smoke then
		local haze = Instance.new("Smoke")
		haze.Color = smoke.colour
		haze.Opacity = smoke.opacity
		haze.Size = smoke.size
		haze.RiseVelocity = smoke.rise
		haze.Parent = part
	end

	local text = spec.text
	if text then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text.text
		label.TextColor3 = text.colour
		label.TextScaled = true
		label.Font = Enum.Font.BuilderSansExtraBold
		label.Parent = gui
		gui.Parent = part
	end

	part.Parent = parent
	return part
end

return PartFactory
