--!strict
-- Reads a deck's playhead smoothly. AudioPlayer.TimePosition updates in ~16 ms steps and sometimes
-- stalls for a few frames, so between updates the position is carried forward with the clock.

local BeatClock = {}
BeatClock.__index = BeatClock

-- Snap back to the reported position when the estimate wanders further than this (a seek).
local RESYNC_SECONDS = 0.08

export type BeatClock = typeof(setmetatable({} :: { _reported: number, _base: number, _baseClock: number }, BeatClock))

function BeatClock.new(): BeatClock
	return setmetatable({ _reported = -1, _base = 0, _baseClock = os.clock() }, BeatClock)
end

-- Call once per frame with the deck's reported TimePosition. Returns the smoothed position.
function BeatClock.update(self: BeatClock, reported: number, playing: boolean, speed: number): number
	local now = os.clock()
	if not playing then
		self._reported, self._base, self._baseClock = reported, reported, now
		return reported
	end
	if reported ~= self._reported then
		self._reported = reported
		local estimate = self._base + (now - self._baseClock) * speed
		-- Follow small corrections gently; jump on big ones (seeks).
		if math.abs(estimate - reported) > RESYNC_SECONDS then
			self._base = reported
		else
			self._base = estimate + (reported - estimate) * 0.2
		end
		self._baseClock = now
	end
	return self._base + (now - self._baseClock) * speed
end

-- Forget the history, e.g. right after seeking.
function BeatClock.reset(self: BeatClock, position: number)
	self._reported, self._base, self._baseClock = position, position, os.clock()
end

return BeatClock
