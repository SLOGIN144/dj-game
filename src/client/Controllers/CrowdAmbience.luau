--!strict
-- The crowd you hear in a club (GDD: sound effects: crowd ambience by guest count): a looping bed
-- of chatter and whoops whose volume follows the guests of the plot whose music is playing, a
-- little louder on drops. It stays silent until the "crowd" sound has an ID (Config/Sounds).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Locations = require(ReplicatedStorage.Shared.Config.Locations)
local MixTimeline = require(ReplicatedStorage.Shared.Music.MixTimeline)
local PlotMixes = require(script.Parent.PlotMixes)
local PlotMusic = require(script.Parent.PlotMusic)
local Sfx = require(script.Parent.Sfx)

local CrowdAmbience = {}

local FULL_CROWD = 40 -- guests at which the bed plays at full volume
local MAX_VOLUME = 0.55
local DROP_LIFT = 1.4 -- how much louder it gets for a few seconds after a drop
local DROP_SECONDS = 4
local EASE = 1.5 -- how fast the volume follows, per second

local function biggestCrowd(): number
	local most = 0
	for _, location in Locations do
		most = math.max(most, location.guests.max)
	end
	return most
end

function CrowdAmbience.start()
	local bed = Sfx.loop("crowd")
	if not bed then
		return -- no sound chosen yet
	end
	local full = math.min(FULL_CROWD, biggestCrowd())
	local volume = 0
	bed:Play()
	RunService.Heartbeat:Connect(function(dt: number)
		local plot = PlotMusic.listening()
		local target = 0
		if plot then
			local guests = plot:GetAttribute("Guests")
			target = MAX_VOLUME * math.clamp((if typeof(guests) == "number" then guests else 0) / full, 0, 1)
			local mix = PlotMixes.get(plot)
			if mix then
				local drop, offset = MixTimeline.nearestDrop(mix.drops, PlotMixes.now())
				if drop and offset >= 0 and offset < DROP_SECONDS then
					target *= 1 + (DROP_LIFT - 1) * (1 - offset / DROP_SECONDS)
				end
			end
		end
		volume += (target - volume) * math.min(1, dt * EASE)
		bed.Volume = volume
	end)
end

return CrowdAmbience
