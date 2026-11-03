--!strict
-- Every tuning number for the set minigame. Starting values from the GDD ("The DJ set");
-- change them here, never in the code that uses them.

local Balance = {}

-- How close a press has to be to its target beat, in seconds either side.
Balance.Timing = {
	perfectWindow = 0.05,
	goodWindow = 0.12,
	-- Added to every press to make up for the delay before the player hears a beat.
	-- Calibrated in Settings later; 0 until then.
	latencyOffset = 0,
}

Balance.Transition = {
	blendBars = 8, -- length of the blend; the incoming track's drop lands at its end
	playDropBars = 16, -- how long a track plays from its drop before it mixes out
	phraseBeats = 16, -- transitions start on a multiple of this many beats
	countdownBeats = 4, -- the 4-3-2-1 before a timed press
	missOffsetBeats = 0.25, -- how far off the beat a missed start sounds, for one bar
	tempoReturnBars = 16, -- after a blend, the new track eases back to its own tempo over this
	syncToleranceSeconds = 0.012, -- the incoming deck is nudged back when it drifts further than this
}

Balance.Blend = {
	zoneWidth = 0.3, -- share of the crossfader the green zone covers
	perfectShare = 0.9, -- share of the blend spent in the zone for a Perfect
	goodShare = 0.6,
	bassSwapAt = 0.5, -- progress through the blend where the bass swaps decks
	keySpeed = 0.35, -- crossfader travel per second while ← or → is held
}

Balance.Hype = {
	releaseHoldBeats = 16, -- a Release challenge is held for this many beats before the drop
	hitEveryBeats = 16, -- Hit challenges sit on phrase boundaries this far apart inside a drop
	quietAfterDropBeats = 8, -- no hype challenge this soon after a Drop moment
	quietBeforeCardsBeats = 8, -- nor this close to the track cards
}

Balance.Energy = {
	driftPerBeat = 0.02, -- share of the gap to the section's pull closed every beat
	-- Where the music alone takes the crowd. Kept modest so that everything above ~55 has to be
	-- earned with timing: idle play ends around a D or F, clean play near an S.
	sectionPull = { intro = 25, build = 40, drop = 55, breakdown = 35, outro = 30 },
	moment = { perfect = 6, good = 3, miss = -4 }, -- Start and Blend
	drop = { perfect = 12, good = 5, miss = -4 },
	hype = { perfect = 3, good = 1, miss = -1 },
	wishMet = 5,
	genreMatch = 1.2, -- multiplier on gains when the track's genre suits the venue
}

-- Combo multipliers, one step up per Perfect, back to the first on a Miss.
Balance.Combo = { 1, 1.5, 2, 3 }

Balance.Score = {
	averageWeight = 0.6,
	peakWeight = 0.25,
	perPerfectDrop = 4,
	perMiss = 3,
}

-- Highest grade first; a score at or above `min` earns the grade.
Balance.Grades = {
	{ grade = "S", min = 90 },
	{ grade = "A", min = 80 },
	{ grade = "B", min = 65 },
	{ grade = "C", min = 50 },
	{ grade = "D", min = 35 },
	{ grade = "F", min = -math.huge },
}

Balance.Cards = {
	count = 3,
	showBeforeBeats = 32, -- cards appear this many beats before a transition starts
	autoPickBeforeBeats = 12, -- if nothing is picked by then, the first card is taken
	tempoRange = 0.08, -- starter gear syncs tracks within ±8% of the current tempo
	wishChance = 0.5, -- chance that the crowd asks for something before a transition
}

Balance.Set = {
	outroFadeBars = 8, -- the last track fades over this many bars when the set ends
}

return Balance
