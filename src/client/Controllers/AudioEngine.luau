--!strict
-- Two decks and a master bus on the Audio API, following the GDD signal chain:
--   AudioPlayer -> AudioEqualizer -> AudioFilter -> AudioFader (channel) -> AudioFader (xfade) --+
--   AudioFader (master) <-------------------------------------------------------------------------+
--   -> AudioCompressor (limiter) -> AudioDeviceOutput
-- The set code only talks to this module, never to audio instances directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local BlendJudge = require(ReplicatedStorage.Shared.Set.BlendJudge)

local AudioEngine = {}
AudioEngine.__index = AudioEngine

local KILL_DB = -40 -- an EQ band at this gain is effectively off
local FILTER_LOWEST = 20 -- Hz; the high-pass filter's frequency with no sweep
local FILTER_HIGHEST = 1500 -- Hz; at a full sweep

type Deck = {
	player: AudioPlayer,
	equalizer: AudioEqualizer,
	filter: AudioFilter,
	channel: AudioFader,
	crossfade: AudioFader,
}

export type AudioEngine = typeof(setmetatable(
	{} :: { _folder: Folder, _decks: { Deck }, _master: AudioFader },
	AudioEngine
))

local function wire(parent: Instance, from: Instance, to: Instance)
	local link = Instance.new("Wire")
	link.SourceInstance = from
	link.TargetInstance = to
	link.Parent = parent
end

local function create<T>(className: string, name: string, parent: Instance): T
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return (instance :: any) :: T
end

function AudioEngine.new(parent: Instance): AudioEngine
	local folder = Instance.new("Folder")
	folder.Name = "AudioEngine"

	local master = create("AudioFader", "Master", folder) :: AudioFader
	local limiter = create("AudioCompressor", "Limiter", folder) :: AudioCompressor
	limiter.Threshold = -3
	limiter.Ratio = 20
	limiter.Attack = 0.003
	limiter.Release = 0.1
	local output = create("AudioDeviceOutput", "Output", folder) :: AudioDeviceOutput
	wire(folder, master, limiter)
	wire(folder, limiter, output)

	local decks: { Deck } = {}
	for index = 1, 2 do
		local prefix = if index == 1 then "DeckA" else "DeckB"
		local deck: Deck = {
			player = create("AudioPlayer", prefix .. "Player", folder) :: AudioPlayer,
			equalizer = create("AudioEqualizer", prefix .. "EQ", folder) :: AudioEqualizer,
			filter = create("AudioFilter", prefix .. "Filter", folder) :: AudioFilter,
			channel = create("AudioFader", prefix .. "Channel", folder) :: AudioFader,
			crossfade = create("AudioFader", prefix .. "Crossfade", folder) :: AudioFader,
		}
		deck.filter.FilterType = Enum.AudioFilterType.Highpass12dB
		deck.filter.Frequency = FILTER_LOWEST
		deck.filter.Bypass = true
		wire(folder, deck.player, deck.equalizer)
		wire(folder, deck.equalizer, deck.filter)
		wire(folder, deck.filter, deck.channel)
		wire(folder, deck.channel, deck.crossfade)
		wire(folder, deck.crossfade, master)
		decks[index] = deck
	end

	folder.Parent = parent
	local engine = setmetatable({ _folder = folder, _decks = decks, _master = master }, AudioEngine)
	engine:setCrossfader(0)
	return engine
end

-- Loads an asset onto a deck and waits until it can play. Returns false if it didn't load in time.
function AudioEngine.load(self: AudioEngine, deck: number, assetId: number, timeoutSeconds: number): boolean
	local player = self._decks[deck].player
	player:Stop()
	player.Asset = string.format("rbxassetid://%d", assetId)
	player.TimePosition = 0
	player.PlaybackSpeed = 1
	task.wait()
	local started = os.clock()
	while not (player.IsReady and player.TimeLength > 0) do
		if os.clock() - started > timeoutSeconds then
			return false
		end
		task.wait(0.05)
	end
	return true
end

function AudioEngine.isReady(self: AudioEngine, deck: number): boolean
	local player = self._decks[deck].player
	return player.IsReady and player.TimeLength > 0
end

function AudioEngine.play(self: AudioEngine, deck: number)
	self._decks[deck].player:Play()
end

-- Starts a deck `delay` seconds from now on the audio mixer's clock, so it lands sample-accurately
-- on a beat instead of on the next frame. Falls back to a timer if the mixer clock isn't available.
function AudioEngine.playAt(self: AudioEngine, deck: number, delay: number)
	local player = self._decks[deck].player
	local scheduled = pcall(function()
		player:Play(SoundService:GetMixerTime() + delay)
	end)
	if not scheduled then
		task.delay(delay, function()
			player:Play()
		end)
	end
end

function AudioEngine.stop(self: AudioEngine, deck: number)
	self._decks[deck].player:Stop()
end

function AudioEngine.isPlaying(self: AudioEngine, deck: number): boolean
	return self._decks[deck].player.IsPlaying
end

function AudioEngine.position(self: AudioEngine, deck: number): number
	return self._decks[deck].player.TimePosition
end

function AudioEngine.seek(self: AudioEngine, deck: number, seconds: number)
	local player = self._decks[deck].player
	player.TimePosition = math.clamp(seconds, 0, math.max(0, player.TimeLength - 0.05))
end

function AudioEngine.length(self: AudioEngine, deck: number): number
	return self._decks[deck].player.TimeLength
end

function AudioEngine.speed(self: AudioEngine, deck: number): number
	return self._decks[deck].player.PlaybackSpeed
end

function AudioEngine.setSpeed(self: AudioEngine, deck: number, speed: number)
	self._decks[deck].player.PlaybackSpeed = speed
end

-- 0 = deck A only, 1 = deck B only, equal-power in between.
function AudioEngine.setCrossfader(self: AudioEngine, position: number)
	local gainA, gainB = BlendJudge.gains(position)
	self._decks[1].crossfade.Volume = gainA
	self._decks[2].crossfade.Volume = gainB
end

-- Low EQ band: 1 = full bass, 0 = bass killed.
function AudioEngine.setBass(self: AudioEngine, deck: number, amount: number)
	self._decks[deck].equalizer.LowGain = (1 - math.clamp(amount, 0, 1)) * KILL_DB
end

-- High-pass filter sweep: 0 = off, 1 = most of the low end filtered out (the build-up sound).
function AudioEngine.setSweep(self: AudioEngine, deck: number, amount: number)
	local filter = self._decks[deck].filter
	local sweep = math.clamp(amount, 0, 1)
	filter.Bypass = sweep <= 0.001
	filter.Frequency = FILTER_LOWEST * (FILTER_HIGHEST / FILTER_LOWEST) ^ sweep
end

function AudioEngine.setMasterVolume(self: AudioEngine, volume: number)
	self._master.Volume = math.clamp(volume, 0, 1)
end

function AudioEngine.destroy(self: AudioEngine)
	self._folder:Destroy()
end

return AudioEngine
