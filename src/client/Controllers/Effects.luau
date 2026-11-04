--!strict
-- Drop payoffs every client sees, fired by the server's DropHit for any plot: a light blast and
-- the guests jumping on a Good or Perfect press, plus confetti over the dance floor and a cheer
-- on a Perfect one. Confetti uses the ParticleEmitter's built-in texture, coloured per location.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local Guests = require(script.Parent.Guests)
local LightShow = require(script.Parent.LightShow)
local Locations = require(ReplicatedStorage.Shared.Config.Locations)
local PlotMusic = require(script.Parent.PlotMusic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Sfx)

local Effects = {}

local CONFETTI_PER_COLOUR = 28
local CONFETTI_HEIGHT = 9 -- studs above the dance floor

local function palette(plot: Model): { Color3 }
	local locationId = plot:GetAttribute("LocationId")
	for _, location in Locations do
		if location.id == locationId then
			return location.lights
		end
	end
	return Locations[1].lights
end

function Effects.confetti(plot: Model)
	local locationId = plot:GetAttribute("LocationId")
	local blockout = if typeof(locationId) == "string" then Blockouts[locationId] else nil
	if not blockout or #blockout.guests.spots == 0 then
		return
	end
	local centre = Vector3.zero
	for _, spot in blockout.guests.spots do
		centre += spot
	end
	centre /= #blockout.guests.spots

	local holder = Instance.new("Part")
	holder.Name = "Confetti"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(10, 0.2, 7)
	holder.CFrame = plot:GetPivot() * CFrame.new(centre + Vector3.new(0, CONFETTI_HEIGHT, 0))
	holder.Parent = workspace

	local colours = table.clone(palette(plot))
	table.insert(colours, Color3.new(1, 1, 1))
	for _, colour in colours do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 0
		emitter.Color = ColorSequence.new(colour)
		emitter.LightEmission = 0.5
		emitter.Size = NumberSequence.new(0.28)
		emitter.Lifetime = NumberRange.new(2.2, 3.4)
		emitter.Speed = NumberRange.new(4, 10)
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = Vector3.new(0, -9, 0)
		emitter.Drag = 1.4
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-220, 220)
		emitter.Parent = holder
		emitter:Emit(CONFETTI_PER_COLOUR)
	end
	Debris:AddItem(holder, 5)
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
	Remotes.event("DropHit").OnClientEvent:Connect(onHit)
end

return Effects
