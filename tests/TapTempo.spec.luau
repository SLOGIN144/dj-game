--!strict
local StarterPlayer = game:GetService("StarterPlayer")

local TapTempo = require(StarterPlayer.StarterPlayerScripts.TrackTagger.TapTempo)
local T = require(script.Parent.TestUtil)

-- Taps on every beat of a perfect grid, optionally with a repeating timing wobble (seconds).
local function gridTaps(bpm: number, start: number, count: number, wobble: { number }?): { number }
	local taps = {}
	for i = 0, count - 1 do
		local offset = if wobble then wobble[i % #wobble + 1] else 0
		table.insert(taps, start + i * 60 / bpm + offset)
	end
	return taps
end

return {
	["needs at least MIN_TAPS taps"] = function()
		T.equal(TapTempo.fit(gridTaps(124, 0.48, TapTempo.MIN_TAPS - 1), true), nil)
	end,

	["perfect taps give the exact BPM and phase"] = function()
		local fit = TapTempo.fit(gridTaps(124, 0.48, 16), true)
		assert(fit, "no fit")
		T.equal(fit.bpm, 124)
		T.near(fit.measuredBpm, 124, 1e-6)
		T.near(TapTempo.snapToGrid(fit, 0.5), 0.48, 1e-6)
		T.near(fit.maxErrorMs, 0, 1e-3)
	end,

	["wobbly taps round to the whole BPM"] = function()
		local fit = TapTempo.fit(gridTaps(124, 0.48, 32, { 0.012, -0.008, 0.004, -0.015, 0.009 }), true)
		assert(fit, "no fit")
		T.equal(fit.bpm, 124)
		T.near(fit.measuredBpm, 124, TapTempo.ROUND_WITHIN)
		T.near(TapTempo.snapToGrid(fit, 10), 0.48 + 20 * 60 / 124, 0.01)
	end,

	["rounding off keeps two decimals"] = function()
		local fit = TapTempo.fit(gridTaps(124, 0.48, 32, { 0.012, -0.008, 0.004, -0.015, 0.009 }), false)
		assert(fit, "no fit")
		T.near(fit.bpm, fit.measuredBpm, 0.005)
		T.near(fit.bpm * 100, math.round(fit.bpm * 100), 1e-6, "two decimals")
	end,

	["a BPM far from a whole number is not rounded"] = function()
		local fit = TapTempo.fit(gridTaps(122.5, 0.2, 16), true)
		assert(fit, "no fit")
		T.near(fit.bpm, 122.5, 1e-6)
	end,

	["a missed tap still gives the right BPM"] = function()
		local taps = gridTaps(128, 1, 16)
		table.remove(taps, 6)
		local fit = TapTempo.fit(taps, true)
		assert(fit, "no fit")
		T.equal(fit.bpm, 128)
		T.equal(fit.tapCount, 15)
	end,

	["an accidental double tap is ignored"] = function()
		local taps = gridTaps(128, 1, 16)
		table.insert(taps, 7, taps[6] + 0.04)
		local fit = TapTempo.fit(taps, true)
		assert(fit, "no fit")
		T.equal(fit.bpm, 128)
		T.equal(fit.tapCount, 16)
	end,

	["a constant tap delay shifts the phase, not the BPM"] = function()
		local fit = TapTempo.fit(gridTaps(124, 0.5, 16), true)
		assert(fit, "no fit")
		T.equal(fit.bpm, 124)
		T.near(TapTempo.snapToGrid(fit, 0.45), 0.5, 1e-6)
	end,
}
