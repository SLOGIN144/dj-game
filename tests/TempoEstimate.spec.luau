--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local TempoEstimate = require(StarterPlayer.StarterPlayerScripts.TrackTagger.TempoEstimate)
local T = require(script.Parent.TestUtil)

local SAMPLE_RATE = 8000

-- Fake audio: a short decaying 60 Hz "kick" on every beat, plus quiet deterministic noise.
-- With `offbeats`, a quieter hi-hat-like click sits halfway between the kicks.
local function kicks(bpm: number, seconds: number, offbeats: boolean?): { number }
	local samples = table.create(seconds * SAMPLE_RATE, 0)
	local noise = 12345
	for i = 1, #samples do
		noise = (noise * 1103515245 + 12345) % 2147483648
		samples[i] = (noise / 2147483648 - 0.5) * 0.02
	end
	local beat = 60 / bpm
	local function hit(time: number, amplitude: number, frequency: number)
		local first = math.floor(time * SAMPLE_RATE) + 1
		for n = 0, 400 do
			local index = first + n
			if index <= #samples then
				samples[index] += amplitude * math.sin(2 * math.pi * frequency * n / SAMPLE_RATE) * math.exp(-n / 80)
			end
		end
	end
	local time = 0.1
	while time < seconds do
		hit(time, 0.9, 60)
		if offbeats then
			hit(time + beat / 2, 0.3, 3000)
		end
		time += beat
	end
	return samples
end

return {
	["finds the tempo of a steady kick"] = function()
		local estimate = TempoEstimate.fromSamples(kicks(124, 12), SAMPLE_RATE)
		assert(estimate, "no estimate")
		T.near(estimate.bpm, 124, 0.5)
	end,

	["finds a faster tempo too"] = function()
		local estimate = TempoEstimate.fromSamples(kicks(128, 12), SAMPLE_RATE)
		assert(estimate, "no estimate")
		T.near(estimate.bpm, 128, 0.5)
	end,

	["off-beat hats don't double the tempo"] = function()
		local estimate = TempoEstimate.fromSamples(kicks(122, 12, true), SAMPLE_RATE)
		assert(estimate, "no estimate")
		T.near(estimate.bpm, 122, 0.5)
	end,

	["a steady kick is a confident estimate"] = function()
		local estimate = TempoEstimate.fromSamples(kicks(124, 12), SAMPLE_RATE)
		assert(estimate, "no estimate")
		T.truthy(estimate.confidence > TempoEstimate.MIN_CONFIDENCE, "confidence " .. estimate.confidence)
	end,

	["silence gives no estimate"] = function()
		T.equal(TempoEstimate.fromSamples(table.create(12 * SAMPLE_RATE, 0), SAMPLE_RATE), nil)
	end,

	["checkTaps is quiet when taps match the estimate"] = function()
		T.equal(TempoEstimate.checkTaps(124, { bpm = 125.2, confidence = 0.5 }), nil)
	end,

	["checkTaps spots tapping every other beat"] = function()
		local hint = TempoEstimate.checkTaps(62, { bpm = 124.3, confidence = 0.5 })
		T.truthy(hint and string.find(hint, "every other beat", 1, true), tostring(hint))
	end,

	["checkTaps spots tapping twice per beat"] = function()
		local hint = TempoEstimate.checkTaps(248, { bpm = 124.3, confidence = 0.5 })
		T.truthy(hint and string.find(hint, "twice", 1, true), tostring(hint))
	end,

	["checkTaps names the estimate when they just disagree"] = function()
		local hint = TempoEstimate.checkTaps(118, { bpm = 124.3, confidence = 0.5 })
		T.truthy(hint and string.find(hint, "~124", 1, true), tostring(hint))
	end,

	["best picks the most confident estimate"] = function()
		local best = TempoEstimate.best({
			{ bpm = 120, confidence = 0.2 },
			{ bpm = 125, confidence = 0.6 },
			{ bpm = 131, confidence = 0.3 },
		})
		assert(best, "no best")
		T.equal(best.bpm, 125)
		T.equal(TempoEstimate.best({}), nil)
	end,
}
