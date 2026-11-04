--!strict
-- Plays the mix of the plot the player is at (see Shared/Music/MixTimeline) through the
-- AudioEngine's two decks. Segments take turns on deck A and B by their number. A deck loads its
-- next track early, starts on the mixer clock exactly when the plan says (AudioPlayer:Play(atTime)),
-- and is nudged back whenever it drifts from the plan. The mix is full on the plot and quieter and
-- muffled from the street; a blown speaker makes it quieter still.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local AudioEngine = require(script.Parent.AudioEngine)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BeatClock = require(script.Parent.BeatClock)
local MixTimeline = require(ReplicatedStorage.Shared.Music.MixTimeline)
local PlotArea = require(ReplicatedStorage.Shared.Util.PlotArea)
local PlotMixes = require(script.Parent.PlotMixes)
local Types = require(ReplicatedStorage.Shared.Types)

local PlotMusic = {}

local SPEED_STEP = 2e-4 -- speed changes smaller than this aren't worth setting
local DRIFT_SMOOTHING = 0.15 -- how fast the measured drift follows each new reading

type DeckState = {
	segment: Types.MixSegment?, -- what this deck has loaded or is loading
	ready: boolean,
	scheduled: boolean, -- started, or scheduled to start on the mixer clock
	running: boolean, -- its first playing frame has passed, so the clock can be trusted
	failedAt: number?, -- os.clock() of the last failed load
	token: {}?, -- the current load; an older one that finishes late is ignored
	clock: BeatClock.BeatClock,
	drift: number, -- smoothed distance from the plan, in track seconds (positive = ahead)
}

-- What the debug overlay shows.
export type DeckReport =
	{ n: number?, trackId: string?, ready: boolean, playing: boolean, drift: number, speed: number }

local engine: AudioEngine.AudioEngine
local decks: { DeckState } = {}
local listening: Model? = nil

local function newDeck(): DeckState
	return { ready = false, scheduled = false, running = false, clock = BeatClock.new(), drift = 0 }
end

local function deckFor(n: number): number
	return (n - 1) % 2 + 1
end

local function sameSegment(a: Types.MixSegment?, b: Types.MixSegment?): boolean
	return a ~= nil and b ~= nil and a.n == b.n and a.trackId == b.trackId and a.startTime == b.startTime
end

local function listenerPosition(): Vector3
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

-- The plot with a mix nearest to the listener, sticking with the current one unless another is
-- clearly closer. Nil when every mix is out of earshot.
local function choosePlot(position: Vector3): (Model?, number)
	local best: Model? = nil
	local bestDistance = math.huge
	local currentDistance = math.huge
	for _, plot in PlotMixes.plots() do
		if PlotMixes.get(plot) then
			local distance = PlotArea.distance(plot:GetPivot(), position)
			if distance < bestDistance then
				best, bestDistance = plot, distance
			end
			if plot == listening then
				currentDistance = distance
			end
		end
	end
	if listening and currentDistance - bestDistance < Balance.Music.switchMargin then
		best, bestDistance = listening, currentDistance
	end
	if bestDistance > Balance.Music.hearDistance then
		return nil, bestDistance
	end
	return best, bestDistance
end

local function resetDecks()
	for index = 1, 2 do
		engine:stop(index)
		engine:setDeckGain(index, 0)
		decks[index] = newDeck()
	end
end

-- The segment a deck should hold now: its earliest one that hasn't finished.
local function wantedSegment(plan: { Types.MixSegment }, deck: number, time: number): Types.MixSegment?
	for _, segment in plan do
		local track = PlotMixes.tracks[segment.trackId]
		if track and deckFor(segment.n) == deck and MixTimeline.endTime(segment, track) > time then
			return segment
		end
	end
	return nil
end

local function load(index: number, segment: Types.MixSegment, track: Types.Track)
	local deck = newDeck()
	deck.segment = segment
	local token = {}
	deck.token = token
	decks[index] = deck
	task.spawn(function()
		local ok = engine:load(index, track.assetId, Balance.Music.loadTimeout)
		if deck.token ~= token or decks[index] ~= deck then
			return
		end
		if ok then
			deck.ready = true
		else
			deck.failedAt = os.clock()
			warn(string.format("[PlotMusic] %s (%d) didn't load", track.id, track.assetId))
		end
	end)
end

local function setSpeed(index: number, speed: number)
	if math.abs(engine:speed(index) - speed) > SPEED_STEP then
		engine:setSpeed(index, speed)
	end
end

-- Loads, schedules, starts, stops and corrects one deck against the plan.
local function syncDeck(index: number, segment: Types.MixSegment?, time: number)
	local deck = decks[index]
	if not segment then
		if deck.segment then
			engine:stop(index)
			decks[index] = newDeck()
		end
		return
	end
	local track = PlotMixes.tracks[segment.trackId]
	if not track then
		return
	end

	if not sameSegment(deck.segment, segment) then
		load(index, segment, track)
		return
	end
	deck.segment = segment -- a newer copy of the plan may know where it ends
	if not deck.ready then
		if deck.failedAt and os.clock() - deck.failedAt > Balance.Music.retrySeconds then
			load(index, segment, track)
		end
		return
	end

	-- Coming up: schedule the start on the mixer clock just before it's due.
	if time < segment.startTime then
		local untilStart = segment.startTime - time
		if not deck.scheduled and untilStart <= Balance.Music.scheduleLead then
			engine:seek(index, MixTimeline.trackTime(track, segment.fromBeat))
			engine:setSpeed(index, segment.speed)
			engine:playAt(index, untilStart)
			deck.scheduled = true
		end
		return
	end

	local expected = MixTimeline.trackTime(track, MixTimeline.beatAt(segment, track, time))
	local planned = MixTimeline.speedAt(segment, track, time)

	-- Late (joined mid-track, or the track loaded late): jump straight to where the plan is.
	if not deck.scheduled or not engine:isPlaying(index) then
		engine:seek(index, expected)
		engine:setSpeed(index, planned)
		engine:play(index)
		deck.scheduled = true
		deck.running = false
		return
	end

	-- The first frame it's playing: start the clock from the plan.
	if not deck.running then
		deck.running = true
		deck.clock:reset(expected)
		deck.drift = 0
		return
	end

	local position = deck.clock:update(engine:position(index), true, engine:speed(index))
	deck.drift += (position - expected - deck.drift) * DRIFT_SMOOTHING
	if math.abs(position - expected) > Balance.Music.seekThreshold then
		engine:seek(index, expected)
		deck.clock:reset(expected)
		deck.drift = 0
		engine:setSpeed(index, planned)
	elseif math.abs(deck.drift) > Balance.Transition.syncToleranceSeconds then
		local nudge =
			math.clamp(-deck.drift / Balance.Music.correctionSeconds, -Balance.Music.maxNudge, Balance.Music.maxNudge)
		setSpeed(index, planned + nudge)
	else
		setSpeed(index, planned)
	end
end

local function update()
	local position = listenerPosition()
	local plot, distance = choosePlot(position)
	if plot ~= listening then
		listening = plot
		resetDecks()
	end
	local entry = if plot then PlotMixes.get(plot) else nil
	if not plot or not entry then
		engine:setMasterVolume(0)
		return
	end

	local time = PlotMixes.now()
	local gains, bass = { 0, 0 }, { 1, 1 }
	local layers = MixTimeline.at(entry.plan, PlotMixes.tracks, time)
	for _, layer in layers do
		local deck = deckFor(layer.segment.n)
		gains[deck], bass[deck] = layer.gain, layer.bass
	end
	for index = 1, 2 do
		syncDeck(index, wantedSegment(entry.plan, index, time), time)
		engine:setDeckGain(index, gains[index])
		engine:setBass(index, bass[index])
	end

	local volume = if distance <= 0
		then 1
		else Balance.Music.streetVolume * math.clamp(1 - distance / Balance.Music.hearDistance, 0, 1)
	if plot:GetAttribute("SpeakerBlown") == true then
		volume *= Balance.Music.blownVolume
	end
	engine:setMasterVolume(volume)
	engine:setMuffle(math.clamp(distance / 4, 0, 1), Balance.Music.muffleHz)
end

-- The plot whose mix is playing, if any.
function PlotMusic.listening(): Model?
	return listening
end

-- Each deck's state, for the debug overlay. Positions are measured from the audio itself.
function PlotMusic.report(): { DeckReport }
	local reports = {}
	for index, deck in decks do
		local segment = deck.segment
		table.insert(reports, {
			n = if segment then segment.n else nil,
			trackId = if segment then segment.trackId else nil,
			ready = deck.ready,
			playing = engine:isPlaying(index),
			drift = deck.drift,
			speed = engine:speed(index),
		})
	end
	return reports
end

-- Where each deck really is, in beats of its track (from the smoothed audio playhead).
function PlotMusic.heardBeat(deck: number): number?
	local state = decks[deck]
	local segment = state and state.segment
	local track = if segment then PlotMixes.tracks[segment.trackId] else nil
	if not track or not state.running then
		return nil
	end
	local position = state.clock:update(engine:position(deck), engine:isPlaying(deck), engine:speed(deck))
	return (position - track.firstBeat) * track.bpm / 60
end

function PlotMusic.start()
	engine = AudioEngine.new(SoundService)
	engine:setMasterVolume(0)
	resetDecks()
	RunService.Heartbeat:Connect(update)
end

return PlotMusic
