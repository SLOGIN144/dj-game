--!strict
-- Every plot's mix plan on this client, decoded from the plot's "MixPlan" attribute (set by the
-- server's Music service), with its drops. The music, lights, guests and the decks UI all read a
-- plot's mix through here, so they agree on every beat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MixPlanner = require(ReplicatedStorage.Shared.Music.MixPlanner)
local MixTimeline = require(ReplicatedStorage.Shared.Music.MixTimeline)
local TrackInfo = require(ReplicatedStorage.Shared.Music.TrackInfo)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local Types = require(ReplicatedStorage.Shared.Types)

local PlotMixes = {}

PlotMixes.tracks = TrackInfo.byId(Tracks)

export type Entry = {
	plan: { Types.MixSegment },
	drops: { MixTimeline.Drop },
}

local entries: { [Model]: Entry } = {}
local plotList: { Model } = {}

local function watch(plot: Instance)
	if not plot:IsA("Model") then
		return
	end
	table.insert(plotList, plot)
	local function update()
		local text = plot:GetAttribute("MixPlan")
		local plan = if typeof(text) == "string" then MixPlanner.decode(text) else nil
		if plan and #plan > 0 then
			entries[plot] = { plan = plan, drops = MixTimeline.drops(plan, PlotMixes.tracks) }
		else
			entries[plot] = nil
		end
	end
	plot:GetAttributeChangedSignal("MixPlan"):Connect(update)
	update()
end

function PlotMixes.start()
	local plots = workspace:WaitForChild("Street"):WaitForChild("Plots")
	plots.ChildAdded:Connect(watch)
	for _, plot in plots:GetChildren() do
		watch(plot)
	end
end

-- Every plot on the street, with or without a mix.
function PlotMixes.plots(): { Model }
	return plotList
end

function PlotMixes.get(plot: Model): Entry?
	return entries[plot]
end

-- The plot's audible segments at `time` and the one in charge (see MixTimeline.at).
function PlotMixes.at(plot: Model, time: number): ({ MixTimeline.Layer }, MixTimeline.Layer?)
	local entry = entries[plot]
	if not entry then
		return {}, nil
	end
	return MixTimeline.at(entry.plan, PlotMixes.tracks, time)
end

-- The current server time, which every plan is written against.
function PlotMixes.now(): number
	return workspace:GetServerTimeNow()
end

return PlotMixes
