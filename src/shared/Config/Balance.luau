--!strict
-- Every tuning number in the game. Starting values from the GDD; change them here, never in the
-- code that uses them.

local Balance = {}

-- How close a press has to be to its target beat, in seconds either side.
Balance.Timing = {
	perfectWindow = 0.05,
	goodWindow = 0.12,
	-- Added to every press to make up for the delay before the player hears a beat.
	-- Calibrated in Settings later; 0 until then.
	latencyOffset = 0,
}

-- How the game mixes one track into the next.
Balance.Transition = {
	blendBars = 8, -- length of the blend; the incoming track's drop lands at its end
	playDropBars = 16, -- how long a track plays from its drop before it mixes out
	phraseBeats = 16, -- transitions start on a multiple of this many beats
	leadBeats = 32, -- the next transition is planned at least this far ahead
	countdownBeats = 4, -- the 4-3-2-1 before a timed press
	bassSwapAt = 0.5, -- progress through the blend where the bass swaps decks
	tempoReturnBars = 16, -- after a blend, the new track eases back to its own tempo over this
	syncToleranceSeconds = 0.012, -- the incoming deck is nudged back when it drifts further than this
	tempoRange = 0.08, -- tracks within ±8% of each other's tempo get a synced blend
}

return Balance
