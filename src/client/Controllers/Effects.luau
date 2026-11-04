--!strict
-- Drop payoffs every client sees. The server's DropHit (a Good or Perfect press, for any plot)
-- gives a light blast and the guests jumping, plus confetti over the dance floor and a cheer on a
-- Perfect one. Feature items fire their own payoff on every drop of the plot's mix, pressed or
-- not (GDD: confetti and CO2 are payoffs on drops, never constant decoration): parts with an "Fx"
-- attribute burst confetti, blast CO2 or launch fireworks. Everything here is made on this client
-- and cleans itself up; particles use the ParticleEmitter's built-in texture.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local Guests = require(script.Parent.Guests)
local LightShow = require(script.Parent.LightShow)
local Locations = require(ReplicatedStorage.Shared.Config.Locations)
local PlotMixes = require(script.Parent.PlotMixes)
local PlotMusic = require(script.Parent.PlotMusic)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local Preferences = require(script.Parent.Preferences)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Sfx)

local Effects = {}

local CONFETTI_PER_COLOUR = 28
local CONFETTI_HEIGHT = 9 -- studs above the dance floor
local VIEW_DISTANCE = 220 -- studs within which a plot's drop payoffs fire
local LATE = 0.4 -- seconds after a drop it still fires (a frame hitch shouldn't skip it)
local FX_FOLDERS = { "Items", "Showcase" }
local WHITE = Color3.new(1, 1, 1)
local ROCKET = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LOW_SHARE = 0.4 -- particles drawn with low graphics, as a share of the full count

local folder: Folder
local lastDrop: { [Model]: number } = {} -- per plot, the time of the last drop that fired its payoffs

local function palette(plot: Model): { Color3 }
	local location = PlotSpace.location(PlotSpace.locationId(plot))
	return if location then location.lights else Locations[1].lights
end

-- An invisible anchored part to emit from, removed after `seconds`.
local function holder(name: string, cframe: CFrame, size: Vector3, seconds: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	part.Parent = folder
	Debris:AddItem(part, seconds)
	return part
end

local function confettiBurst(at: Part, colours: { Color3 }, count: number, speed: NumberRange)
	if Preferences.lowGraphics() then
		count = math.ceil(count * LOW_SHARE)
	end
	for _, colour in colours do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 0
		emitter.Color = ColorSequence.new(colour)
		emitter.LightEmission = 0.5
		emitter.Size = NumberSequence.new(0.28)
		emitter.Lifetime = NumberRange.new(2.2, 3.4)
		emitter.Speed = speed
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = Vector3.new(0, -9, 0)
		emitter.Drag = 1.4
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-220, 220)
		emitter.Parent = at
		emitter:Emit(count)
	end
end

-- Confetti over the plot's dance floor (a Perfect press).
function Effects.confetti(plot: Model)
	local locationId = PlotSpace.locationId(plot)
	local blockout = if locationId then Blockouts[locationId] else nil
	if not blockout or #blockout.guests.spots == 0 then
		return
	end
	local centre = Vector3.zero
	for _, spot in blockout.guests.spots do
		centre += spot
	end
	centre /= #blockout.guests.spots
	local cframe = PlotSpace.origin(plot) * CFrame.new(centre + Vector3.new(0, CONFETTI_HEIGHT, 0))
	local colours = table.clone(palette(plot))
	table.insert(colours, WHITE)
	confettiBurst(
		holder("Confetti", cframe, Vector3.new(10, 0.2, 7), 5),
		colours,
		CONFETTI_PER_COLOUR,
		NumberRange.new(4, 10)
	)
end

-- A popper on the floor shoots confetti up.
local function popper(part: BasePart, colours: { Color3 })
	local at = holder("Popper", part.CFrame * CFrame.new(0, part.Size.Y / 2, 0), Vector3.new(1, 0.2, 1), 5)
	confettiBurst(at, colours, 18, NumberRange.new(18, 26))
end

-- A CO2 jet: a white column straight up for a moment.
local function co2(part: BasePart)
	local at = holder("CO2", part.CFrame * CFrame.new(0, part.Size.Y / 2, 0), Vector3.new(0.6, 0.2, 0.6), 3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = if Preferences.lowGraphics() then 140 * LOW_SHARE else 140
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 240, 255))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 4.5) })
	emitter.Lifetime = NumberRange.new(0.6, 0.9)
	emitter.Speed = NumberRange.new(30, 40)
	emitter.SpreadAngle = Vector2.new(6, 6)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Drag = 3
	emitter.LightEmission = 0.3
	emitter.Parent = at
	task.delay(1.1, function()
		emitter.Enabled = false
	end)
end

-- A firework: a glowing rocket rises, then bursts into sparks with a flash of light (and a bang,
-- when `audible`).
local function firework(part: BasePart, colour: Color3, audible: boolean)
	local start = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
	local rocket = holder("Rocket", start, Vector3.new(0.4, 0.4, 0.4), 4)
	rocket.Transparency = 0
	rocket.Material = Enum.Material.Neon
	rocket.Color = colour
	rocket.Shape = Enum.PartType.Ball
	local trail = Instance.new("ParticleEmitter")
	trail.Rate = 60
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 210, 150))
	trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	trail.Lifetime = NumberRange.new(0.3, 0.5)
	trail.Speed = NumberRange.new(0.5, 1)
	trail.LightEmission = 1
	trail.Parent = rocket
	local peak = start * CFrame.new(math.random(-6, 6), 38 + math.random() * 10, math.random(-4, 4))
	TweenService:Create(rocket, ROCKET, { CFrame = peak }):Play()
	task.delay(ROCKET.Time, function()
		if not rocket.Parent then
			return
		end
		rocket.Transparency = 1
		trail.Enabled = false
		local sparks = Instance.new("ParticleEmitter")
		sparks.Rate = 0
		sparks.Color = ColorSequence.new(colour, WHITE)
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		sparks.Lifetime = NumberRange.new(1.2, 1.8)
		sparks.Speed = NumberRange.new(16, 22)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Acceleration = Vector3.new(0, -6, 0)
		sparks.Drag = 1.5
		sparks.Parent = rocket
		sparks:Emit(if Preferences.lowGraphics() then math.ceil(90 * LOW_SHARE) else 90)
		if audible then
			Sfx.play("firework", 0.6)
		end
		local flash = Instance.new("PointLight")
		flash.Color = colour
		flash.Range = 60
		flash.Brightness = 6
		flash.Parent = rocket
		TweenService:Create(flash, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	end)
end

-- Fires every feature payoff the plot has bought (and its street showcase), for one drop. Their
-- sounds only play for the club whose music you hear.
local function dropPayoffs(plot: Model)
	local here = PlotMusic.listening() == plot
	local played: { [string]: boolean } = {}
	local function sound(name: string)
		if here and not played[name] then
			played[name] = true
			Sfx.play(name)
		end
	end
	local colours = table.clone(palette(plot))
	table.insert(colours, WHITE)
	local rockets = 0
	for _, name in FX_FOLDERS do
		local items = plot:FindFirstChild(name)
		if not items then
			continue
		end
		for _, part in items:GetDescendants() do
			local fx = part:GetAttribute("Fx")
			if not part:IsA("BasePart") or typeof(fx) ~= "string" then
				continue
			end
			if fx == "confetti" then
				popper(part, colours)
			elseif fx == "co2" then
				co2(part)
				sound("co2")
			elseif fx == "fireworks" then
				rockets += 1
				local colour = colours[rockets % #colours + 1]
				task.delay(rockets * 0.15, firework, part, colour, here)
			end
		end
	end
end

-- Watches each plot in view for its mix's next drop.
local function watchDrops()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local now = PlotMixes.now()
	for _, plot in PlotMixes.plots() do
		local mix = PlotMixes.get(plot)
		if not mix or PlotSpace.hearingDistance(plot, eye) > VIEW_DISTANCE then
			continue
		end
		local latest = nil
		for _, drop in mix.drops do
			if drop.time <= now then
				latest = drop.time
			end
		end
		local seen = lastDrop[plot]
		if seen == nil then
			lastDrop[plot] = latest or -math.huge -- drops before this client saw the plot don't fire
		elseif latest and latest > seen then
			lastDrop[plot] = latest
			if now - latest <= LATE then
				dropPayoffs(plot)
			end
		end
	end
end

local function onHit(plot: unknown, grade: unknown)
	if typeof(plot) ~= "Instance" or not plot:IsA("Model") or typeof(grade) ~= "string" then
		return
	end
	local perfect = grade == "perfect"
	LightShow.flash(plot, if perfect then 1.2 else 0.6)
	Guests.cheer(plot)
	if perfect then
		Effects.confetti(plot)
		if PlotMusic.listening() == plot then
			Sfx.play("cheer")
		end
	end
end

function Effects.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalEffects"
	folder.Parent = workspace
	Remotes.event("DropHit").OnClientEvent:Connect(onHit)
	RunService.Heartbeat:Connect(watchDrops)
end

return Effects
