--!strict
-- The street's night look (GDD: visual style and lighting): a dark sky, soft purple haze, bloom on
-- the neon and a little extra contrast and colour. Game scripts can't write the lighting mode
-- (LightingStyle, PrioritizeLightingQuality), so it lives in the place. A new place's template
-- brings its own effects, and two Atmospheres or Blooms fight, so those go.

local Lighting = game:GetService("Lighting")

local NightLook = {}

local rgb = Color3.fromRGB

local OURS = { NightHaze = true, NeonBloom = true, NightGrade = true }

local function removeTemplateEffects()
	for _, child in Lighting:GetChildren() do
		if (child:IsA("PostEffect") or child:IsA("Atmosphere")) and not OURS[child.Name] then
			child:Destroy()
		end
	end
end

local function effect<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return (existing :: any) :: T
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return (created :: any) :: T
end

function NightLook.apply()
	removeTemplateEffects()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = rgb(26, 24, 42)
	Lighting.OutdoorAmbient = rgb(48, 46, 84)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ExposureCompensation = 0.15
	Lighting.GlobalShadows = true

	local atmosphere = effect("Atmosphere", "NightHaze") :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.12
	atmosphere.Color = rgb(78, 66, 128)
	atmosphere.Decay = rgb(36, 28, 76)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1.4

	local bloom = effect("BloomEffect", "NeonBloom") :: BloomEffect
	bloom.Intensity = 0.7
	bloom.Size = 26
	bloom.Threshold = 1.5 -- only the brightest neon blooms

	local grade = effect("ColorCorrectionEffect", "NightGrade") :: ColorCorrectionEffect
	grade.Brightness = 0
	grade.Contrast = 0.1
	grade.Saturation = 0.15
	grade.TintColor = rgb(255, 246, 255)
end

return NightLook
