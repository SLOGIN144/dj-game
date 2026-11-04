--!strict
-- Plans the nonstop mix of every owned plot (Shared/Music/MixPlanner) and publishes it on the
-- plot as the "MixPlan" attribute, which every client plays and lights from. The server keeps the
-- same plan to check drop presses. A plot's mix starts when it gets an owner and stops when they
-- leave; tracks the owner buys join it from the next transition on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local MixPlanner = require(ReplicatedStorage.Shared.Music.MixPlanner)
local MixTimeline = require(ReplicatedStorage.Shared.Music.MixTimeline)
local PlayerState = require(script.Parent.PlayerState)
local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local TrackInfo = require(ReplicatedStorage.Shared.Music.TrackInfo)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local Types = require(ReplicatedStorage.Shared.Types)

local Music = {}

local TRACKS = TrackInfo.byId(Tracks)
local CHECK_EVERY = 1 -- seconds between plan updates

type Mix = {
	state: PlayerState.State,
	plan: { Types.MixSegment },
	drops: { MixTimeline.Drop },
	rng: Rng.Rng,
}

local mixes: { [Model]: Mix } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- The owner's tracks in Config/Tracks order, so a plan never depends on table order.
local function owned(state: PlayerState.State): { Types.Track }
	local list = {}
	for _, track in Tracks do
		if state.ownedTracks[track.id] then
			table.insert(list, track)
		end
	end
	return list
end

local function publish(plot: Model, mix: Mix)
	mix.drops = MixTimeline.drops(mix.plan, TRACKS)
	plot:SetAttribute("MixPlan", MixPlanner.encode(mix.plan))
end

local function update(plot: Model, mix: Mix)
	local tracks = owned(mix.state)
	if #tracks == 0 then
		return
	end
	local time = now()
	local trimmed = MixPlanner.trim(mix.plan, TRACKS, time)
	local added = MixPlanner.extend(mix.plan, TRACKS, tracks, mix.rng, time + Balance.Mix.planAheadSeconds)
	if trimmed or added then
		publish(plot, mix)
	end
end

-- Starts the owner's mix on their plot, a moment from now so every client can load the track.
function Music.begin(state: PlayerState.State)
	local tracks = owned(state)
	if #tracks == 0 then
		warn(string.format("[Music] %s owns no tracks", state.player.Name))
		return
	end
	local rng = Rng.new(Random.new():NextInteger(1, 2 ^ 30))
	local first = MixPlanner.chooseNext(nil, tracks, {}, rng)
	local mix: Mix = {
		state = state,
		plan = { MixPlanner.start(first, now() + Balance.Mix.startDelay) },
		drops = {},
		rng = rng,
	}
	MixPlanner.extend(mix.plan, TRACKS, tracks, rng, now() + Balance.Mix.planAheadSeconds)
	mixes[state.plot] = mix
	publish(state.plot, mix)
end

function Music.stop(plot: Model)
	mixes[plot] = nil
	plot:SetAttribute("MixPlan", nil)
end

-- The plot's planned drops, oldest first (empty without a mix).
function Music.drops(plot: Model): { MixTimeline.Drop }
	local mix = mixes[plot]
	return if mix then mix.drops else {}
end

-- The segment in charge of the plot's mix right now, and its track.
function Music.current(plot: Model): (Types.MixSegment?, Types.Track?)
	local mix = mixes[plot]
	if not mix then
		return nil, nil
	end
	local _, main = MixTimeline.at(mix.plan, TRACKS, now())
	if not main then
		return nil, nil
	end
	return main.segment, main.track
end

function Music.start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_EVERY then
			return
		end
		elapsed = 0
		for plot, mix in mixes do
			update(plot, mix)
		end
	end)
end

return Music
