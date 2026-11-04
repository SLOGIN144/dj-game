--!strict
-- The sky and light where the player is (GDD: visual style and lighting). The server sets the
-- street's night look for everyone (World/NightLook). While this client's camera is inside a
-- location's room (or the club a plot keeps on the street while its owner is away), or at a
-- venue, Lighting blends to that location's look (Config/Skies: the dorm's purple, the club's
-- deep blue, Ibiza's sunset), and back to the night on leaving. Lighting changes made on a
-- client only affect that client.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local Bounds = require(ReplicatedStorage.Shared.Util.Bounds)
local PlotMixes = require(script.Parent.PlotMixes)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local Skies = require(ReplicatedStorage.Shared.Config.Skies)

local Ambience = {}

local BLEND = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local VENUE_REACH = 700 -- studs from a venue's origin that count as being there (beach and sea too)
local CHECK_EVERY = 0.25
local ROOM_MARGIN = 1 -- studs around a room's walls that still count as inside

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

-- Each location's room as a box in plot space (its shell's bounds), worked out once.
local rooms: { [string]: { low: Vector3, high: Vector3 } } = {}
local function insideRoom(locationId: string, origin: CFrame, position: Vector3): boolean
	local room = rooms[locationId]
	if not room then
		local blockout = Blockouts[locationId]
		if not blockout then
			return false
		end
		local low, high = Bounds.ofSpecs(blockout.shell)
		room = { low = low, high = high }
		rooms[locationId] = room
	end
	local at = origin:PointToObjectSpace(position)
	return at.X >= room.low.X - ROOM_MARGIN
		and at.X <= room.high.X + ROOM_MARGIN
		and at.Z >= room.low.Z - ROOM_MARGIN
		and at.Z <= room.high.Z + ROOM_MARGIN
end

local function skyOf(locationId: string?): string?
	local location = PlotSpace.location(locationId)
	return if location then location.sky else nil
end

-- The look for where the camera is: a venue's, a room's, or nil for the street's night.
local function skyHere(position: Vector3): string?
	for _, plot in PlotMixes.plots() do
		local locationId = PlotSpace.locationId(plot)
		if not locationId then
			continue
		end
		if PlotSpace.away(plot) then
			if (position - PlotSpace.origin(plot).Position).Magnitude <= VENUE_REACH then
				return skyOf(locationId)
			end
			local shown = PlotSpace.showcaseFor(locationId)
			if shown and insideRoom(shown, plot:GetPivot(), position) then
				return skyOf(shown)
			end
		elseif insideRoom(locationId, plot:GetPivot(), position) then
			return skyOf(locationId)
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
