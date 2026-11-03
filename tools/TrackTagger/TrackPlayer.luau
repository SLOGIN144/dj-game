--!strict
-- Plays one track through the Audio API: AudioPlayer -> Wire -> AudioDeviceOutput.
-- Wraps loading, play/pause and seeking so the rest of the tagger never touches audio instances.

local TrackPlayer = {}
TrackPlayer.__index = TrackPlayer

export type TrackPlayer = typeof(setmetatable({} :: { _folder: Folder, _audio: AudioPlayer }, TrackPlayer))

function TrackPlayer.new(parent: Instance): TrackPlayer
	local folder = Instance.new("Folder")
	folder.Name = "TaggerAudio"

	local audio = Instance.new("AudioPlayer")
	audio.Name = "Track"
	audio.Parent = folder

	local output = Instance.new("AudioDeviceOutput")
	output.Parent = folder

	local wire = Instance.new("Wire")
	wire.SourceInstance = audio
	wire.TargetInstance = output
	wire.Parent = folder

	folder.Parent = parent
	return setmetatable({ _folder = folder, _audio = audio }, TrackPlayer)
end

-- Loads an asset and waits until it can play. Returns false and a reason on failure.
function TrackPlayer.load(self: TrackPlayer, assetId: number, timeoutSeconds: number): (boolean, string?)
	local audio = self._audio
	audio:Stop()
	audio.Asset = string.format("rbxassetid://%d", assetId)
	audio.TimePosition = 0
	task.wait()

	local started = os.clock()
	while not (audio.IsReady and audio.TimeLength > 0) do
		if os.clock() - started > timeoutSeconds then
			return false, "the track didn't load. Check the ID, and that this audio is allowed in your experience."
		end
		task.wait(0.1)
	end
	return true, nil
end

function TrackPlayer.isPlaying(self: TrackPlayer): boolean
	return self._audio.IsPlaying
end

function TrackPlayer.play(self: TrackPlayer)
	self._audio:Play()
end

-- Stops playback but keeps the playhead where it is.
function TrackPlayer.pause(self: TrackPlayer)
	local position = self._audio.TimePosition
	self._audio:Stop()
	self._audio.TimePosition = position
end

function TrackPlayer.getPosition(self: TrackPlayer): number
	return self._audio.TimePosition
end

function TrackPlayer.getLength(self: TrackPlayer): number
	return self._audio.TimeLength
end

-- GetWaveformAsync returns at most this many samples per call (measured Nov 2026).
local MAX_SAMPLES_PER_CALL = 8192

-- Streams the whole track's raw samples (-1..1) to `onChunk`, in order and in the largest chunks
-- Roblox allows. `onChunk` also gets how far through the track the chunk reaches (0..1) and returns
-- false to stop early. Returns true when the whole track was read. Yields.
function TrackPlayer.streamWaveform(
	self: TrackPlayer,
	sampleRate: number,
	onChunk: ({ number }, number) -> boolean
): boolean
	local audio = self._audio
	local length = audio.TimeLength
	local secondsPerCall = math.max(1, math.floor(MAX_SAMPLES_PER_CALL / sampleRate))
	local from = 0
	while length - from >= 1 / sampleRate do
		local seconds = math.min(secondsPerCall, length - from)
		local count = math.floor(seconds * sampleRate)
		local ok, chunk = pcall(function()
			return audio:GetWaveformAsync(NumberRange.new(from, from + count / sampleRate), count)
		end)
		if not ok or type(chunk) ~= "table" or #chunk == 0 then
			return false
		end
		from += count / sampleRate
		if not onChunk(chunk, from / length) then
			return false
		end
	end
	return true
end

function TrackPlayer.seek(self: TrackPlayer, time: number)
	self._audio.TimePosition = math.clamp(time, 0, math.max(0, self._audio.TimeLength - 0.05))
end

return TrackPlayer
