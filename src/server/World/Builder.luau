--!strict
-- Small helpers for building world decoration from code: anchored parts that by default don't
-- collide, cast no shadow and can't be touched, so scenery costs as little as possible.

local Builder = {}

export type Options = {
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	collide: boolean?, -- false when nil
	shadow: boolean?, -- false when nil
	light: { colour: Color3, brightness: number, range: number }?,
}

function Builder.part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	parent: Instance,
	options: Options?
): Part
	local settings: Options = options or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Material = settings.material or Enum.Material.SmoothPlastic
	p.Shape = settings.shape or Enum.PartType.Block
	p.Transparency = settings.transparency or 0
	p.CanCollide = settings.collide == true
	p.CanTouch = false
	p.CanQuery = settings.collide == true
	p.CastShadow = settings.shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local light = settings.light
	if light then
		local pointLight = Instance.new("PointLight")
		pointLight.Color = light.colour
		pointLight.Brightness = light.brightness
		pointLight.Range = light.range
		pointLight.Shadows = false
		pointLight.Parent = p
	end
	p.Parent = parent
	return p
end

-- A glowing part.
function Builder.neon(name: string, size: Vector3, cframe: CFrame, colour: Color3, parent: Instance): Part
	return Builder.part(name, size, cframe, colour, parent, { material = Enum.Material.Neon })
end

function Builder.folder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

return Builder
