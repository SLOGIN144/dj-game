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

Balance.Start = {
	cash = 50, -- enough for the first paid button right away
	locationId = "dorm",
}

-- Pacing per location. Buying a location's items in order takes its income from startIncome to
-- startIncome × incomeGrowth, and saving for all of them takes about `minutes` of active play.
-- Only the first location sets startIncome; later ones start from the previous one's end.
Balance.Pricing = {
	activeFactor = 1.3, -- active play (drops, events) earns this much more than idling
	timeGrowth = 1.15, -- each button takes this much longer to save for than the one before
	carryOver = 1.0, -- a location's free first item earns this share of the previous location's end income
	locations = {
		dorm = { minutes = 10, startIncome = 1, incomeGrowth = 12 },
	} :: { [string]: { minutes: number, incomeGrowth: number, startIncome: number? } },
}

Balance.Register = {
	capMinutes = 10, -- the register stops filling at this many minutes of income
}

Balance.Buttons = {
	visible = 3, -- how many of the next items show as buttons
}

Balance.World = {
	plotCount = 2, -- 6 at launch; 2 for the prototype's two-player test
}

return Balance
