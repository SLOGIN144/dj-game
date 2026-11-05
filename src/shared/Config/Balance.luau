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
		house = { minutes = 40, incomeGrowth = 15 },
		club = { minutes = 150, incomeGrowth = 20 },
		ibiza = { minutes = 330, incomeGrowth = 25 },
	} :: { [string]: { minutes: number, incomeGrowth: number, startIncome: number? } },
}

-- The drop bonus at the decks. A new boost replaces a weaker one; boosts never stack.
Balance.Boost = {
	perfect = { multiplier = 2, seconds = 30 },
	good = { multiplier = 1.5, seconds = 20 },
	lagAllowance = 0.4, -- seconds the server allows between a press and its message arriving
	clockSlack = 0.15, -- a client's copy of the server clock may run this far ahead
	pressWindow = 0.5, -- seconds either side of a drop within which a press is for that drop
	decksRange = 8, -- studs from the DJ spot within which the owner counts as at the decks
}

Balance.Tracks = {
	bonusPerTrack = 0.05, -- each track bought in the shop adds this share to the plot's income, for good
}

-- Club events, one at a time (which ones can happen where is in Config/Locations). Tips are in
-- seconds of the plot's income from what it has built.
Balance.Events = {
	minSeconds = 180, -- seconds of the owner being at their club between two events
	maxSeconds = 300,
	speaker = {
		incomeCut = 0.25, -- income lost while the speaker is blown
		holdSeconds = 2, -- holding E this long fixes it
		tipSeconds = 30, -- the tip for fixing it
	},
	vip = {
		waitSeconds = 60, -- how long the VIP waits at the entrance to be greeted
		tipSeconds = 120, -- the VIP's big tip
	},
	photographer = {
		waitSeconds = 30, -- how long the photographer waits for a caught drop
		tipSeconds = 180, -- the bonus for the shot
	},
}

-- Star DJ guest sets (Config/StarDjs has each DJ's price and multiplier).
Balance.StarDjs = {
	setSeconds = 180, -- a guest set lasts this long
	restSeconds = 900, -- then the DJ rests this long before they can be booked again
	crowdBonus = 0.25, -- a set draws this share more guests
}

-- Saving (Services/PlayerData).
Balance.Save = {
	autosaveSeconds = 60,
	staleSeconds = 300, -- another server's claim older than this is taken over (that server died)
	lockRetries = 6, -- tries to claim a club another server still holds (it may be saving right now)
	lockRetrySeconds = 3,
}

Balance.Register = {
	capMinutes = 10, -- the register stops filling at this many minutes of income
	biggerCap = 2, -- the Bigger Register feature multiplies the cap by this
}

-- Guests drawn on this client across every plot in view (GDD: about 40 on PC, 15 on mobile).
Balance.Guests = {
	renderBudget = 40,
	renderBudgetMobile = 15,
}

Balance.Buttons = {
	visible = 3, -- how many of the next items the phone lists to order
}

-- DJ crates (Config/Crates, Economy/Crates).
Balance.Crates = {
	duplicateShare = 0.4, -- a DJ you already have pays back this share of the crate's price
}

-- Guest wishes (Config/Wishes, Services/Wishes): one at a time, while the owner is in their club.
Balance.Wishes = {
	minSeconds = 70, -- seconds in the club between a granted or lapsed wish and the next
	maxSeconds = 130,
	waitSeconds = 75, -- how long a wish stays up
	tipSeconds = 45, -- the tip, in seconds of the plot's base income
	minTip = 5,
	minGuests = 2, -- wishes only start once this many friends are there
	collectSeconds = 12, -- a "collect" wish asks for the register once it holds this many seconds of income
}

-- Phone orders and the delivery truck (docs/superpowers/specs/2026-11-05-truck-delivery-design.md).
Balance.Delivery = {
	maxItems = 3, -- items in one order, so never more than this many boxes
	baseSeconds = 12, -- from ordering to the truck stopping at the kerb, for one item
	perExtraSeconds = 3, -- more for each further item in the order
	truckSpeed = 55, -- studs per second on the street
	unloadSeconds = 2.5, -- the truck waits at the kerb after the boxes are down
	pickupRange = 16, -- studs from a box within which the owner can pick it up
	placeRange = 22, -- studs from an outline within which a carried box can be placed
}

Balance.World = {
	plotCount = 2, -- 6 at launch; 2 for the prototype's two-player test
}

return Balance
