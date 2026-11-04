--!strict
-- Drives every plot's bought lights on its mix's beat and section (GDD: light show): calm in the
-- intro and breakdown, rising through the build, full blast with a colour flip each bar on the
-- drop, and a white blast on the drop's first beat. It runs for every plot in view from the
-- replicated plan, so visitors see the same show. Parts are found by their "LightRole" attribute
-- (set from PartSpec.lightRole); lights a player hasn't bought don't exist, so they stay dark.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Locations = require(ReplicatedStorage.Shared.Config.Locations)
local MixTimeline = require(ReplicatedStorage.Shared.Music.MixTimeline)
local PlotArea = require(ReplicatedStorage.Shared.Util.PlotArea)
local PlotMixes = require(script.Parent.PlotMixes)
local TrackInfo = require(ReplicatedStorage.Shared.Music.TrackInfo)
local Types = require(ReplicatedStorage.Shared.Types)

local LightShow = {}

local VIEW_DISTANCE = 180 -- studs from the camera within which a plot's lights move
local DROP_BLAST_BEATS = 1.5 -- how long the white blast on a drop's first beat lasts
local FLASH_SECONDS = 0.8 -- the extra blast from a Perfect press
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local SECTION_INTENSITY: { [Types.SectionKind]: number } = {
	intro = 0.35,
	build = 0.5,
	drop = 1,
	breakdown = 0.25,
	outro = 0.35,
}

type LightPart = {
	part: BasePart,
	role: Types.LightRole,
	index: number, -- its place among the plot's parts with the same role
	colour: Color3, -- the part's own colour, as built
	light: Light?, -- the PointLight or SpotLight inside it
	brightness: number, -- the light's own brightness, as built
	foundAt: number,
	pivot: CFrame?, -- the disco ball's resting CFrame
}

type PlotLights = {
	parts: { LightPart },
	known: { [BasePart]: LightPart }, -- every part seen, so a rescan keeps what it looked like as built
	dirty: boolean,
	resting: boolean,
	flashAt: number,
	flashStrength: number,
}

local plots: { [Model]: PlotLights } = {}

local function scan(plot: Model, entry: PlotLights)
	entry.parts = {}
	entry.dirty = false
	local items = plot:FindFirstChild("Items")
	if not items then
		return
	end
	local counts: { [string]: number } = {}
	for _, descendant in items:GetDescendants() do
		local role = descendant:GetAttribute("LightRole")
		if descendant:IsA("BasePart") and typeof(role) == "string" then
			counts[role] = (counts[role] or 0) + 1
			local item = entry.known[descendant]
			if not item then
				local light = descendant:FindFirstChildWhichIsA("Light")
				item = {
					part = descendant,
					role = role :: Types.LightRole,
					index = 0,
					colour = descendant.Color,
					light = light,
					brightness = if light then light.Brightness else 0,
					foundAt = os.clock(),
				}
				entry.known[descendant] = item
			end
			local found = item :: LightPart
			found.index = counts[role]
			table.insert(entry.parts, found)
		end
	end
end

local function watch(plot: Model)
	local entry: PlotLights = {
		parts = {},
		known = setmetatable({}, { __mode = "k" }) :: any,
		dirty = true,
		resting = true,
		flashAt = -math.huge,
		flashStrength = 0,
	}
	plots[plot] = entry
	local items = plot:WaitForChild("Items", 10)
	if items then
		items.DescendantAdded:Connect(function()
			entry.dirty = true
		end)
		items.DescendantRemoving:Connect(function()
			entry.dirty = true
		end)
	end
end

local function palette(plot: Model): { Color3 }
	local locationId = plot:GetAttribute("LocationId")
	for _, location in Locations do
		if location.id == locationId then
			return location.lights
		end
	end
	return Locations[1].lights
end

-- Puts every light back to how it was built (no music on the plot).
local function rest(entry: PlotLights)
	if entry.resting then
		return
	end
	entry.resting = true
	for _, item in entry.parts do
		item.part.Color = item.colour
		if item.light then
			item.light.Brightness = item.brightness
		end
	end
end

local function glow(colour: Color3, amount: number): Color3
	return BLACK:Lerp(colour, math.clamp(amount, 0, 1))
end

local function drive(plot: Model, entry: PlotLights, now: number)
	local _, main = PlotMixes.at(plot, now)
	local mix = PlotMixes.get(plot)
	if not main or not mix then
		rest(entry)
		return
	end
	entry.resting = false

	local beat = main.beat
	local sections = main.track.sections
	local section = TrackInfo.sectionAt(main.track, beat)
	local kind: Types.SectionKind = section.kind
	local phase = beat % 1
	local kick = (1 - phase) ^ 3
	local bar = math.floor(beat / 4)
	local beatSeconds = 60 / (main.track.bpm * main.speed)

	-- How far through its section the mix is, for the build's rise.
	local sectionIndex = table.find(sections, section) or 1
	local sectionEnd = TrackInfo.sectionEnd(main.track, sectionIndex, section.startBeat + 64)
	local through = math.clamp((beat - section.startBeat) / math.max(1, sectionEnd - section.startBeat), 0, 1)

	local intensity = SECTION_INTENSITY[kind]
	if kind == "build" then
		intensity = 0.4 + 0.5 * through
		if through > 0.75 then
			kick = (1 - (beat * 2) % 1) ^ 3 -- eighth notes in the last stretch before the drop
		end
	end
	local boost = plot:GetAttribute("Boost")
	if typeof(boost) == "number" and boost > 1 then
		intensity = math.min(1.15, intensity + 0.15)
	end

	-- White blast on a drop's first beat, and a bigger one after a Perfect press.
	local blast = 0
	local last: MixTimeline.Drop? = nil
	for _, drop in mix.drops do
		if drop.time <= now then
			last = drop
		else
			break
		end
	end
	if last and now - last.time < DROP_BLAST_BEATS * beatSeconds then
		blast = 1 - (now - last.time) / (DROP_BLAST_BEATS * beatSeconds)
	end
	local sinceFlash = os.clock() - entry.flashAt
	if sinceFlash < FLASH_SECONDS then
		blast = math.max(blast, entry.flashStrength * (1 - sinceFlash / FLASH_SECONDS))
	end

	local colours = palette(plot)
	local colour = colours[1]
	if kind == "drop" then
		colour = colours[bar % #colours + 1]
	elseif kind == "breakdown" then
		colour = colours[1]:Lerp(colours[#colours], 0.5 + 0.5 * math.sin(beat * math.pi / 16))
	end

	for _, item in entry.parts do
		local amount, tint = 1, colour
		local role = item.role
		if role == "led" then
			amount = 0.35 + 0.65 * intensity * (0.6 + 0.4 * kick)
		elseif role == "speaker" then
			amount = 0.2 + 0.8 * kick * math.sqrt(intensity)
		elseif role == "spot" then
			tint = item.colour
			if kind == "drop" then
				local mine = (math.floor(beat) + item.index) % 2 == 0
				amount = if mine then 0.3 + 0.7 * kick else 0.12
				tint = item.colour:Lerp(WHITE, 0.4 * kick)
			elseif kind == "build" then
				amount = 0.25 + 0.6 * kick * intensity
			else
				amount = 0.15
			end
		elseif role == "disco" then
			tint = item.colour
			amount = if kind == "drop" then 0.6 + 0.4 * kick else 0.35
			-- Spin it once it has finished popping in.
			if os.clock() - item.foundAt > 1 then
				item.pivot = item.pivot or item.part.CFrame
				local pivot = item.pivot :: CFrame
				item.part.CFrame = pivot * CFrame.Angles(0, os.clock() * (0.5 + 1.5 * intensity), 0)
			end
		elseif role == "screen" then
			tint = item.colour
			amount = 0.6 + 0.4 * kick * intensity
		elseif role == "neon" then
			tint = item.colour
			amount = if kind == "drop" then 0.6 + 0.4 * kick else 0.75
		end

		local final = glow(tint, amount):Lerp(WHITE, blast * 0.8)
		item.part.Color = final
		local light = item.light
		if light then
			light.Color = tint:Lerp(WHITE, blast * 0.8)
			light.Brightness = item.brightness * (0.25 + amount) * (1 + 2 * blast)
		end
	end
end

-- An extra white blast on a plot, e.g. for a Perfect drop press.
function LightShow.flash(plot: Model, strength: number)
	local entry = plots[plot]
	if entry then
		entry.flashAt = os.clock()
		entry.flashStrength = math.clamp(strength, 0, 1.5)
	end
end

function LightShow.start()
	for _, plot in PlotMixes.plots() do
		task.spawn(watch, plot)
	end
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local now = PlotMixes.now()
		local eye = camera.CFrame.Position
		for plot, entry in plots do
			if PlotArea.distance(plot:GetPivot(), eye) > VIEW_DISTANCE then
				continue
			end
			if entry.dirty then
				scan(plot, entry)
			end
			drive(plot, entry, now)
		end
	end)
end

return LightShow
