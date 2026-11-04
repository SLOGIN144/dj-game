--!strict
-- Every tuning number in the game. Starting values from the GDD; change them here, never in the
-- code that uses them.

local Balance = {}

-- How close a press has to be to its target beat, in seconds either side. Wider than a rhythm
-- game's, since the drop press is a bonus, not a test.
Balance.Timing = {
	perfectWindow = 0.06,
	goodWindow = 0.14,
	-- Added to every press to make up for the delay before the player hears a beat.
	-- Calibrated in Settings later; 0 until then.
	latencyOffset = 0,
}

-- How the game mixes one track into the next.
Balance.Transition = {
	blendBars = 8, -- length of the blend; the incoming track's drop lands at its end
	playDropBars = 32, -- how long a track plays from its drop before it mixes out (about one drop every 1-2 minutes)
	phraseBeats = 16, -- transitions start on a multiple of this many beats
	leadBeats = 32, -- the next transition is planned at least this far ahead
	countdownBeats = 4, -- the 4-3-2-1 before a timed press
	bassSwapAt = 0.5, -- progress through the blend where the bass swaps decks
	tempoReturnBars = 16, -- after a blend, the new track eases back to its own tempo over this
	syncToleranceSeconds = 0.012, -- the incoming deck is nudged back when it drifts further than this
	tempoRange = 0.08, -- tracks within ±8% of each other's tempo get a synced blend
	fadeBars = 2, -- tracks further apart: the outgoing one fades out over this, then the next one starts
}

-- How the server plans and publishes each plot's mix.
Balance.Mix = {
	startDelay = 3, -- seconds from planning a plot's first track to it starting, so clients can load it
	planAheadSeconds = 60, -- the next transition is always planned at least this far ahead
	recentTracks = 2, -- a track doesn't come back while it's among the last this many played, if there's a choice
}

-- How a plot's mix sounds on each client, and how tightly the decks follow the plan.
Balance.Music = {
	streetVolume = 0.35, -- a plot's mix heard from the street, before it fades with distance
	hearDistance = 60, -- studs from a plot's edge where its mix has faded out completely
	muffleHz = 700, -- the low-pass on a mix heard from outside its plot
	switchMargin = 4, -- studs another plot must be closer by before the music switches to it
	seekThreshold = 0.25, -- seconds: a deck this far off the plan jumps back into place
	correctionSeconds = 2, -- a smaller drift is pulled back by nudging the speed over this long
	maxNudge = 0.01, -- the most a nudge changes a deck's speed
	scheduleLead = 0.5, -- seconds before a planned start that a deck is scheduled on the mixer clock
	loadTimeout = 10, -- seconds a track gets to load before the deck tries again later
	retrySeconds = 5,
	blownVolume = 0.5, -- music volume while the plot's speaker is blown
}

Balance.Start = {
	cash = 50, -- enough for the first paid button right away
	locationId = "dorm",
	tracks = { "until_sunrise", "london_loves" }, -- the tracks a new player owns
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

-- The drop bonus at the decks. A new boost replaces a weaker one; boosts never stack.
Balance.Boost = {
	perfect = { multiplier = 2, seconds = 30 },
	good = { multiplier = 1.5, seconds = 20 },
	lagAllowance = 0.4, -- seconds the server allows between a press and its message arriving
	decksRange = 8, -- studs from the DJ spot within which the owner counts as at the decks
}

Balance.Tracks = {
	bonusPerTrack = 0.05, -- each track bought in the shop adds this share to the plot's income, for good
}

-- Club events, one at a time. The prototype has only the blown speaker.
Balance.Events = {
	minSeconds = 180, -- seconds of the owner being on their plot between two events
	maxSeconds = 300,
	speaker = {
		incomeCut = 0.25, -- income lost while the speaker is blown
		holdSeconds = 2, -- holding E this long fixes it
		tipSeconds = 30, -- the tip for fixing it, in seconds of income
	},
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
