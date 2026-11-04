--!strict
-- Builds one blockout Part from a PartSpec, placed relative to a plot's origin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local PartFactory = {}

-- The CFrame a spec's part sits at, for a plot whose origin is `origin`.
function PartFactory.place(spec: Types.PartSpec, origin: CFrame): CFrame
	local r = spec.rotation or Vector3.zero
	return origin * CFrame.new(spec.offset) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
end

function PartFactory.build(spec: Types.PartSpec, origin: CFrame, parent: Instance): Part
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
