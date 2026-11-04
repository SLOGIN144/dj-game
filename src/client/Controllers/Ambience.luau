--!strict
-- The sky and light where the player is (GDD: visual style and lighting). The server sets the
-- street's night look for everyone (World/NightLook); while this client's camera is at a venue
-- whose location has a sky of its own (Config/Skies: Ibiza's sunset), Lighting blends to it, and
-- back to the night on leaving. Lighting changes made on a client only affect that client.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PlotMixes = require(script.Parent.PlotMixes)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local Skies = require(ReplicatedStorage.Shared.Config.Skies)

local Ambience = {}

local BLEND = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local VENUE_REACH = 700 -- studs from a venue's origin that count as being there (beach and sea too)
local CHECK_EVERY = 0.25

type Look = { lighting: { [string]: any }, haze: { [string]: any }, grade: { [string]: any } }

local current: string? = nil -- the sky shown now; nil for the night
local night: Look

local function snapshot(haze: Atmosphere?, grade: ColorCorrectionEffect?): Look
	return {
		lighting = {
			ClockTime = Lighting.ClockTime,
			Brightness = Lighting.Brightness,
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			ExposureCompensation = Lighting.ExposureCompensation,
		},
		haze = if haze
			then {
				Color = haze.Color,
				Decay = haze.Decay,
				Density = haze.Density,
				Haze = haze.Haze,
				Glare = haze.Glare,
				Offset = haze.Offset,
			}
			else {},
		grade = if grade
			then { TintColor = grade.TintColor, Saturation = grade.Saturation, Contrast = grade.Contrast }
			else {},
	}
end

local function lookFor(sky: Skies.Sky): Look
	return {
		lighting = {
			ClockTime = sky.clockTime,
			Brightness = sky.brightness,
			Ambient = sky.ambient,
			OutdoorAmbient = sky.outdoorAmbient,
			ExposureCompensation = sky.exposure,
		},
		haze = {
			Color = sky.haze.colour,
			Decay = sky.haze.decay,
			Density = sky.haze.density,
			Haze = sky.haze.haze,
			Glare = sky.haze.glare,
			Offset = sky.haze.offset,
		},
		grade = { TintColor = sky.grade.tint, Saturation = sky.grade.saturation, Contrast = sky.grade.contrast },
	}
end

local function blend(look: Look, haze: Atmosphere?, grade: ColorCorrectionEffect?)
	-- The time of day jumps (a tween from midnight to dusk would pass through noon); the travel
	-- fade covers it. Everything else blends.
	local lighting = table.clone(look.lighting)
	Lighting.ClockTime = lighting.ClockTime
	lighting.ClockTime = nil
	TweenService:Create(Lighting, BLEND, lighting):Play()
	if haze and next(look.haze) then
		TweenService:Create(haze, BLEND, look.haze):Play()
	end
	if grade and next(look.grade) then
		TweenService:Create(grade, BLEND, look.grade):Play()
	end
end

-- The sky of the venue the camera is at, if any.
local function skyHere(position: Vector3): string?
	for _, plot in PlotMixes.plots() do
		if PlotSpace.away(plot) then
			local location = PlotSpace.location(PlotSpace.locationId(plot))
			local origin = PlotSpace.origin(plot)
			if location and location.sky and (position - origin.Position).Magnitude <= VENUE_REACH then
				return location.sky
			end
		end
	end
	return nil
end

function Ambience.start()
	task.spawn(function()
		local haze = Lighting:WaitForChild("NightHaze", 10) :: Atmosphere?
		local grade = Lighting:WaitForChild("NightGrade", 10) :: ColorCorrectionEffect?
		night = snapshot(haze, grade)
		local elapsed = 0
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed < CHECK_EVERY then
				return
			end
			elapsed = 0
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			local wanted = skyHere(camera.CFrame.Position)
			if wanted == current then
				return
			end
			current = wanted
			local sky = if wanted then Skies[wanted] else nil
			blend(if sky then lookFor(sky) else night, haze, grade)
		end)
	end)
end

return Ambience
