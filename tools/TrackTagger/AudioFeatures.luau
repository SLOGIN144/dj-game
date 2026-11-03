--!strict
-- Turns raw audio samples into a few simple curves the analysis works on, FRAME_RATE values
-- per second: how loud the whole sound is, how loud the low end (kick and bass) is, how sharply
-- each of those rises (onsets), and the peak level for drawing a waveform.
-- Samples are pushed in chunks as they arrive, so a whole track never has to sit in memory.

local AudioFeatures = {}
AudioFeatures.__index = AudioFeatures

AudioFeatures.FRAME_RATE = 400 -- feature values per second (one per 2.5 ms)
AudioFeatures.LOW_CUTOFF = 150 -- Hz; below this is mostly kick and bass
-- The low end's loudness is measured over this many frames (25 ms), at least one full wave of
-- a 40 Hz bass, so it doesn't flicker with each wave.
AudioFeatures.LOW_WINDOW_FRAMES = 10

export type Features = {
	frameRate: number,
	duration: number, -- seconds of audio pushed
	fullLevel: { number }, -- loudness per frame in dB
	lowLevel: { number }, -- loudness of the low end (over the last LOW_WINDOW_FRAMES) in dB
	fullOnset: { number }, -- how sharply the loudness rises at each frame (0 when it falls)
	lowOnset: { number }, -- the same for the low end
	-- Rise of the low end's plain (not squashed) loudness. A kick rises by about the same amount
	-- in a quiet intro and in a drop full of bass, so this is the most reliable kick detector.
	lowRise: { number },
	peaks: { number }, -- loudest sample per frame (0..1)
}

type State = {
	_hop: number,
	_lowPassAmount: number,
	_lowPass1: number,
	_lowPass2: number,
	_sumFull: number,
	_sumLow: number,
	_peak: number,
	_count: number,
	_previousFull: number,
	_previousLow: number,
	_previousLowRms: number,
	_lowWindow: { number }, -- low-end energy of the last LOW_WINDOW_FRAMES frames, oldest first
	_lowWindowSum: number,
	_samples: number,
	_sampleRate: number,
	_features: Features,
}

export type Accumulator = typeof(setmetatable({} :: State, AudioFeatures))

-- Loudness on a squashed scale, so quiet and loud parts both show their rises.
local function squash(rms: number): number
	return math.log(1 + 100 * rms)
end

local function decibels(rms: number): number
	return 20 * math.log10(rms + 1e-5)
end

function AudioFeatures.new(sampleRate: number): Accumulator
	local hop = math.max(1, math.floor(sampleRate / AudioFeatures.FRAME_RATE))
	local state: State = {
		_hop = hop,
		-- One-pole low-pass strength for the cutoff; applied twice for a steeper slope.
		_lowPassAmount = 1 - math.exp(-2 * math.pi * AudioFeatures.LOW_CUTOFF / sampleRate),
		_lowPass1 = 0,
		_lowPass2 = 0,
		_sumFull = 0,
		_sumLow = 0,
		_peak = 0,
		_count = 0,
		_previousFull = 0,
		_previousLow = 0,
		_previousLowRms = 0,
		_lowWindow = table.create(AudioFeatures.LOW_WINDOW_FRAMES, 0),
		_lowWindowSum = 0,
		_samples = 0,
		_sampleRate = sampleRate,
		_features = {
			frameRate = sampleRate / hop,
			duration = 0,
			fullLevel = {},
			lowLevel = {},
			fullOnset = {},
			lowOnset = {},
			lowRise = {},
			peaks = {},
		},
	}
	return setmetatable(state, AudioFeatures)
end

function AudioFeatures.push(self: Accumulator, samples: { number })
	local hop, amount = self._hop, self._lowPassAmount
	local features = self._features
	for _, value in samples do
		self._lowPass1 += amount * (value - self._lowPass1)
		self._lowPass2 += amount * (self._lowPass1 - self._lowPass2)
		local low = self._lowPass2
		self._sumFull += value * value
		self._sumLow += low * low
		self._peak = math.max(self._peak, math.abs(value))
		self._count += 1

		if self._count == hop then
			local window = self._lowWindow
			self._lowWindowSum += self._sumLow - window[1]
			table.remove(window, 1)
			table.insert(window, self._sumLow)

			local fullRms = math.sqrt(self._sumFull / hop)
			local lowRms = math.sqrt(math.max(0, self._lowWindowSum) / (hop * #window))
			local full, lowSquashed = squash(fullRms), squash(lowRms)
			table.insert(features.fullLevel, decibels(fullRms))
			table.insert(features.lowLevel, decibels(lowRms))
			table.insert(features.fullOnset, math.max(0, full - self._previousFull))
			table.insert(features.lowOnset, math.max(0, lowSquashed - self._previousLow))
			table.insert(features.lowRise, math.max(0, lowRms - self._previousLowRms))
			table.insert(features.peaks, math.min(1, self._peak))
			self._previousFull, self._previousLow, self._previousLowRms = full, lowSquashed, lowRms
			self._sumFull, self._sumLow, self._peak, self._count = 0, 0, 0, 0
		end
	end
	self._samples += #samples
end

function AudioFeatures.finish(self: Accumulator): Features
	self._features.duration = self._samples / self._sampleRate
	return self._features
end

return AudioFeatures
